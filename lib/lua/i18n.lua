--- Manages system localization.
-- Locale maps are loaded from `/etc` and must be Lua tables.  See the included `en_US` map for details.
-- @module i18n
-- @alias lib

local lib = {}
local checkArg = require("checkArg")

local mapcache = {}

-- find a locale e.g. `/etc/lang/en_US.lua`
local function findmap(lang)
  return package.searchpath(lang, os.getenv("LC_PATH") or
    "/usr/share/lang/?.lua;/etc/lang/?.lua", ".", "/")
end

local function loadmap()
  local lang = os.getenv("LC_LOCALE") or "en_US"

  if mapcache[lang] then return mapcache[lang] end

  local path, err = findmap(lang)
  if not path then
    io.stderr:write(err, "\n")
    return nil, err
  end

  local fd
  fd, err = io.open(path, "r")
  if not fd then
    io.stderr:write(("%s: errno %d\n"):format(path, err))
    return nil, err
  end

  local data = fd:read("a")
  fd:close()

  local call
  call, err = load("return " .. data, "="..path, "t", {})
  if not call then
    io.stderr:write(err, "\n")
    return nil, err
  end

  local suc, ret = pcall(call)
  if not suc then
    io.stderr:write(ret, "\n")
    return nil, ret
  end

  mapcache[lang] = ret

  return ret
end

--- Fetch a localized string using a key.
-- @tparam string key The key to look up
-- @treturn string|nil The localized string
function lib.fetch(key)
  checkArg(1, key, "string")
  local lmap = loadmap()
  return lmap[key]
end

return lib
