--- UPT package list databases

local fs = require("upt.filesystem")
local meta = require("upt.meta")
local dirent = require("posix.dirent")
local checkArg = require("checkArg")

local lib = {}

local dbo = {}

function dbo:names()
  local infos = self:retrieve(".+", true)
  local ret = {}

  if infos then
    for i=1, #infos, 1 do
      ret[#ret+1] = infos[i][2]
    end
  end

  return ret
end

function dbo:retrieve(search, match)
  checkArg(1, search, "string")
  checkArg(2, match, "boolean", "nil")

  local matches = {}

  local dir = fs.combine(self.root, "/etc/upt/lists")
  for file in dirent.files(dir) do
    if file ~= "." and file ~= ".." then
      for line in io.lines(fs.combine(dir, file)) do
        local name, version, size, authors, depends, license, desc =
          table.unpack(meta.split(line))

        if depends == "" then depends = {} end
        if type(depends) == "string" then depends = {depends} end

        if authors == "" then authors = {} end
        if type(authors) == "string" then authors = {authors} end

        if search == name or (match and name:match(search)) then
          matches[#matches+1] = table.pack(
            file, name, version, size, authors, depends, license, desc
          )
        end
      end
    end
  end

  if #matches > 0 then return matches end

  return nil, "entry not found"
end

function dbo:add()
  return nil, "operation not supported"
end

function dbo:remove()
  return nil, "operation not supported"
end

function dbo:close()
end

function lib.load(root)
  root = root or "/"

  fs.makeDirectory(fs.combine(root, "/etc/upt/lists"))
  local files = fs.list(fs.combine(root, "/etc/upt/lists"))

  return setmetatable({root = root, files = files}, {__index = dbo})
end

return lib
