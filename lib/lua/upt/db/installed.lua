--- UPT installed package database

local dirent = require("posix.dirent")
local checkArg = require("checkArg")
local meta = require("upt.meta")
local fs = require("upt.filesystem")

local lib = {}

local dbo = {}

function dbo:all()
  local files = {}

  for file in dirent.files(fs.combine(self.root, "/etc/upt/db")) do
    if file ~= "." and file ~= ".." then files[#files+1] = file end
  end

  return files
end

function dbo:retrieve(search, match, full)
  checkArg(1, search, "string")
  checkArg(2, match, "boolean", "nil")
  checkArg(3, full, "boolean", "nil")

  local matches = {}

  local dir = fs.combine(self.root, "/etc/upt/db")
  for file in dirent.files(dir) do
    if search == file or (match and file:match(search)) then
      local hand = assert(io.open(fs.combine(dir, file), "r"))
      local first = hand:read("l")
      hand:close()

      local version, authors, depends, license, repo, desc =
        table.unpack(meta.split(first))

      if depends == "" then depends = {} end
      if type(depends) == "string" then depends = {depends} end

      if authors == "" then authors = {} end
      if type(authors) == "string" then authors = {authors} end

      local files = {}
      if full then
        for line in hand:lines() do
          files[#files+1] = line
        end
      end

      matches[#matches+1] = table.pack(
        file, version, authors, depends, license, repo, desc, files
      )
    end
  end

  if #matches > 0 then
    return matches
  end

  return nil, "no package found"
end

-- only adds metadata, not files.
function dbo:add(name, version, authors, depends, license, repo, desc)
  checkArg(1, name, "string")
  checkArg(2, version, "string")
  checkArg(3, authors, "table")
  checkArg(4, depends, "table", "nil")
  checkArg(5, license, "string", "nil")
  checkArg(6, repo, "string")
  checkArg(7, desc, "string", "nil")

  depends = depends or {}
  license = license or ""
  desc = desc or ""

  local path = fs.combine(self.root, "/etc/upt/db", name)

  if fs.exists(path) then
    return nil, "entry already exists"
  end

  local handle, oerr = io.open(path, "w")
  if not handle then
    return nil, oerr
  end

  handle:write(meta.assemble(version, authors, depends,
    license, repo, desc).."\n")

  handle:close()

  return true, path
end

-- does not remove package files from the disk, only removes db entries.
function dbo:remove(name)
  checkArg(1, name, "string")
  local path = fs.combine(self.root, "/etc/upt/db", name)
  if fs.exists(path) then
    os.remove(path)
  end
end

function dbo:close()
end

function lib.load(root)
  checkArg(1, root, "string", "nil")

  fs.makeDirectory(fs.combine(root or "/", "/etc/upt/db"))
  return setmetatable({root=root or "/"}, {__index = dbo})
end

return lib
