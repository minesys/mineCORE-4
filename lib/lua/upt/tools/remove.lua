-- UPT package removal

local installed = require("upt.db.installed")
local checkArg = require("checkArg")
local fs = require("upt.filesystem")

local lib = {}

-- TODO: check dependencies and whatnot
function lib.remove(name, root)
  checkArg(1, name, "string")
  root = root or "/"

  local db = installed.load(root)
  local entries, err = db:retrieve(name, false, true)

  if not entries then
    return nil, err

  elseif #entries > 1 then
    return nil, "more than one package found"
  end

  local entry = entries[1]

  os.remove(entry[1])

  local files = entry[#entry]

  for i=1, #files do
    if (not fs.isDirectory(files[i])) or #fs.list(files[i]) == 0 then
      os.execute("rm -rf " .. files[i])
    end
  end

  return true
end

return lib
