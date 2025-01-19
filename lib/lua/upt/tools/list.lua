-- UPT package list management

local logger = require("upt.logger")
local repo = require("upt.db.repo")
local net = require("upt.network")
local fs = require("upt.filesystem")

local lib = {}

local function update(root, db, name)
  local info = db:retrieve(name)[1]
  local url = info[3]
  fs.makeDirectory(fs.combine(root, "/etc/upt/lists"))
  local fpath = fs.combine(root, "/etc/upt/lists/", name)
  local pkgurl = url .. "/packages.upl"
  return net.retrieve(pkgurl, fpath)
end

function lib.update(root, list)
  local db = repo.load(root)

  local repos
  if type(list) == "table" and #list > 0 then
    repos = list
  elseif type(list) == "string" then
    repos = { list }
  else
    repos = db:names()
  end

  for i=1, #repos do
    local ok, err = update(root or "/", db, repos[i])
    if not ok then
      logger.fail(err)
    end
  end
end

return lib
