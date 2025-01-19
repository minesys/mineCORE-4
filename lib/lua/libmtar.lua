--- Library for reading and writing MTAR v2 files.
-- @module libmtar
-- @alias lib

-- only supports mtar v2 files
-- TODO: maybe move to its own package?

local lib = {}
local checkArg = require("checkArg")
local stat = require("posix.sys.stat")

local HEADER = "\xFF\xFF\x02M"

local function readint(handle, size)
  return string.unpack("<I"..math.floor(size), handle:read(size))
end

local function readFileTags(handle, tagsize)
  local have_read = 0
  local tags = {}

  while have_read < tagsize do
    local tagspec_length = readint(handle, 2)
    local tag_name_length = readint(handle, 1)
    local tag_name = handle:read(tag_name_length)
    local tag_data_length = readint(handle, 2)
    local tag_data = handle:read(tag_data_length)

    if tagspec_length ~= tag_name_length + tag_data_length + 5 then
      error(string.format("mismatched tagspec length (specified %d, got %d)",
        tagspec_length, tag_name_length + tag_data_length + 5))
    end

    have_read = have_read + tagspec_length
    tags[tag_name] = tag_data
  end

  if tags.mtime then
    tags.mtime = string.unpack("<I"..#tags.mtime, tags.mtime)
  end

  if tags.mode then
    tags.mode = string.unpack("<I"..#tags.mode, tags.mode)
  end

  return tags
end

local function readFileRecord(handle)
  local recsize = pcall(readint, handle, 8)
  if not recsize then return end
  local name_length = readint(handle, 1)
  local name = handle:read(name_length)
  local tagsize = readint(handle, 2)
  local tags = readFileTags(handle, tagsize)
  local datasize = readint(handle, 8)
  return recsize, name, tags, datasize
end

local reader = {}

function reader:verify_header()
  self.stream:seek("set", 0)

  local header = self.stream:read(4)
  if header ~= HEADER then
    error(string.format(
      "bad MTAR v2 header (expected 0xFFFF024D, got %08x)",
      string.unpack("<I8", header)))
  end
end

--- Seek to a specific MTAR file record.
function reader:seek(file)
  checkArg(1, file, "string")

  for rec, name, tag, dat in self:iterate() do
    if name == file then
      return rec, name, tag, dat
    end

    self.stream:seek("cur", dat)
  end
end

--- Iterate over all MTAR file records in the reader's stream.
-- The stream must be compatible with the functions provided in standard `io` library streams.
-- The returned iterator expects the calling program to read all file data (or seek forward `datsize` bytes) before calling it again.
function reader:iterate()
  self:verify_header()
  return function()
    return readFileRecord(self.stream)
  end
end

function lib.reader(stream)
  return setmetatable({stream=stream}, {__index = reader})
end

------
-- Writer object returned by @{writeto}.
-- @type Writer
local writer = {}

local function bytes(n)
  local b = 0
  while n > 0 do n = n << 8 b = b + 1 end
  return b
end

local function verifyRecord(r)
  checkArg(1, r, "table")
  checkArg("name", r.name, "string")
  checkArg("tags", r.tags, "table")
  for k, v in pairs(r.tags) do
    checkArg("tags[?]", k, "string")
    checkArg("tags["..k.."]", v, "string", "number")
    if type(v) == "number" then r.tags[k] = string.pack("<I"..bytes(v), v) end
  end
end

--- add a file from disk to the output
-- throws on invalid file
-- streams data in chunks so as to not over-fill RAM
---@tparam string file The file to add
---@tparam string path The path to which that file will be extracted
function writer:add(file, path)
  checkArg(1, file, "string")
  checkArg(2, path, "string")

  local statx, err = stat.stat(file)
  if not statx then
    error("add " .. file .. ": " .. err)
  end

  local record = {
    name = path,
    tags = {
      mtime = statx.st_mtime,
      mode = statx.st_mode,
    },
  }

  if stat.S_ISDIR(statx.st_mode) ~= 0 then
    self:create(record, 0)
  else

    self:create(record, statx.st_size)

    local handle, oerr = io.open(file, "r")
    if not handle then
      error("add " .. file .. ": " .. oerr)
    end

    repeat
      local data = handle:read(statx.st_blksize)
      if data then self.stream:write(data) end
    until not data

    handle:close()
  end

  return true
end

local function countBytes(number)
  for i=0, 32 do
    if 2^i > number then
      return i
    end
  end

  error("number exceeded 32 bytes in size - this situation should never occur")
end

--- add a custom file to the output
function writer:create(record, datsize)
  verifyRecord(record)

  local tags = ""
  for k, v in pairs(record.tags) do
    if type(v) == "number" then
      v = string.pack("<I"..bytes(v), v)
    end

    local tag = string.pack("<s1s2", k, v)
    tags = tags .. string.pack("<I2", #tag + 2) .. tag
  end

  self.stream:write(string.pack("<I8s1s2I8",
    8 + 1 + #record.name + 2 + #tags + 8 + datsize,
    record.name, tags, datsize))

  return true
end

function writer:close()
  pcall(self.stream.close, self.stream)
end

--- Write MTAR data to a stream.
-- This function expects to be given a valid file stream, such as what io.open
-- returns.
function lib.writer(stream)
  stream:write(HEADER)
  return setmetatable({stream=stream}, {__index=writer})
end

return lib
