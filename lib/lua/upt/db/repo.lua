--- UPT repository database interactions
-- @module upt.db.repo
-- @alias lib

local fs = require("upt.filesystem")
local upt = require("upt")
local tree = require("treeutil").tree
local logger = require("upt.logger")
local checkArg = require("checkArg")

local lib = {}

local dbo = {}

-- this function acts like the user adding a db entry, and adds only to the
-- root file.
-- packages adding repository entries should do so through repos.d/someName.
function dbo:add(name, url)
  checkArg(1, name, "string")
  checkArg(2, url, "string")

  for i=1, #self.data.repos + 1 do
    if self.data.repos[i] then
      if self.data.repos[i][2] == url then
        return true
      end
    else
      self.data.repos[i] = {name, url}
      return true
    end
  end

  return nil, "operation failed for some reason"
end

function dbo:remove(name)
  checkArg(1, name, "string")
  local data = self.data.repos

  for i=1, data, 1 do
    if data[i][1] == name then
      table.remove(data, i)
      return true
    end
  end
end

function dbo:retrieve(name)
  checkArg(1, name, "string")

  for db, data in pairs(self.data) do
    for i=1, #data, 1 do
      if data[i][1] == name then
        return { { db, data[i][1], data[i][2], n = 3 } }
      end
    end
  end

  return nil, "no matching repositories"
end

function dbo:names()
  local repos = {}

  for _, data in pairs(self.data) do
    for i=1, #data do
      repos[#repos+1] = data[i][1]
    end
  end

  return repos
end

function dbo:close()
  local hand, err = io.open(self.repos, "w")
  if not hand then
    return nil, "error saving databases - " .. err
  end

  for i=1, #self.data.repos do
    local ent = self.data.repos[i]
    hand:write("repo " .. ent[1] .. " " .. ent[2] .. "\n")
  end

  hand:close()
end

local function loadRepoFile(f)
  local data = {}

  for line in io.lines(f) do
    local name, url = line:match("repo ([^ ]+) ([^ ]+)")
    if line:sub(1,1) ~= "#" then
      if not name then
        logger.warn("invalid repo entry: " .. line)
      else
        data[#data+1] = {name, url}
      end
    end
  end

  return data
end

function lib.load(root)
  local r = fs.combine(root or "/", "/etc/upt/repos")
  local rd = r .. ".d"

  local data = {repos = loadRepoFile(r)}

  if fs.isDirectory(rd) then
    tree(rd, nil, function(path)
      local name = path:match("([^/]+)/?$")
      if data[name] then
        return nil, "identical repository db filenames - " .. name
      end
      data[name] = loadRepoFile(path)
    end)
  end

  return setmetatable({repos = r, data = data}, {__index = dbo})
end

return lib
