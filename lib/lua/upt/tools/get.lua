-- upt.get

local unistd = require("posix.unistd")
local lists = require("upt.db.lists")
local repos = require("upt.db.repo")
local net = require("upt.network")
local fs = require("upt.filesystem")

local lib = {}

function lib.get(name, dest, root)
  dest = dest or (root and "/") or unistd.getcwd()
  root = root or "/"

  local dbL = lists.load(root)
  local entries, err = dbL:retrieve(name)

  if not entries then
    return nil, err

  elseif #entries > 1 then
    return nil, "TODO: handle multiple identical package entries"
  end

  local repo, pkgname, pkgver = entries[1][1], entries[1][2], entries[1][3]
  dest = fs.combine(root, dest, pkgname .. "-" .. pkgver .. ".mtar")

  -- get package URL
  local dbR = repos.load(root)
  local repoent = dbR:retrieve(repo)

  if not repoent then
    return nil, "repository not present for given package"
  end

  local baseurl = repoent[1][3]

  local ok, nerr = net.retrieve(
    baseurl .. "/" .. pkgname .. "-" .. pkgver .. ".mtar", dest)

  if not ok or ok ~= tonumber(entries[1][4]) then
    return nil, nerr or "Invalid package size ("..ok.." vs "..entries[1][4]..")"
  end

  return dest
end

return lib
