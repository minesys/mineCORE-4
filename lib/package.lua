-- An implementation of Lua's package library.
-- This should be loaded by init, by the init
-- process (NOT a separate process), as the very
-- first thing init does, so that the package API
-- will propagate to all child processes.

_G.package = {}

package.config = "/\n;\n?\n!\n-"
package.cpath = "/lib/?.csl;/usr/lib/?.csl;./?.csl"
package.path = "/lib/lua/?.lua;/lib/lua/?/init.lua;" ..
  "/usr/lib/lua/?.lua;/usr/lib/lua/?/init.lua;./?.lua;./?/init.lua"

local loaded = {checkArg = checkArg}
_G.checkArg = nil
local checkArg = loaded.checkArg
package.loaded = setmetatable({}, {__index = function(_, k)
  if _G[k] then
    return _G[k]
  else
    return loaded[k]
  end
end, __newindex = function() end})

package.preload = {}

local function loadlib(_)
  error("loadlib is not implemented yet")
end

package.searchers = {
  -- package.preload
  function(mod)
    if package.preload[mod] then
      return package.preload[mod]

    else
      return nil, "no field package.preload['"..mod.."']"
    end
  end,

  -- lua library
  function(mod)
    local path, err = package.searchpath(mod, package.path)
    if not path then
      return nil, err
    end

    local func, lerr = loadfile(path)
    if not func then
      return nil, lerr
    end

    return func(), path
  end,

  -- Cynosure Shared Library
  function(mod)
    local path, err = package.searchpath(mod, package.cpath)
    if not path then
      return nil, err
    end

    local lib, lerr = loadlib(path)
    if not lib then
      return nil, lerr
    end

    return lib, path
  end
}

local function syscall(...)
  local res, err = coroutine.yield("syscall", ...)
  if type(err) == "string" then
    error(err)
  end

  return res, err
end

function package.searchpath(name, path, sep, rep)
  checkArg(1, name, "string")
  checkArg(2, path, "string")
  checkArg(3, sep, "string", "nil")
  checkArg(4, rep, "string", "nil")

  sep = "%" .. (sep or ".")
  rep = rep or package.config:sub(1,1)

  name = name:gsub(sep, rep)
  local emsg = ""

  for search in path:gmatch("[^"..package.config:sub(3,3).."]+") do
    search = search:gsub("%"..package.config:sub(5,5), name)
    local stat = syscall("stat", search)
    if stat and (stat.mode & 0x4000) == 0 then
      return search

    else
      if #emsg > 0 then emsg = emsg .. "\n  " end
      emsg = emsg .. "no file '"..search.."'"
    end
  end

  return nil, emsg
end

function _G.loadfile(path, mode, env)
  checkArg(1, path, "string")
  checkArg(2, mode, "string", "nil")
  checkArg(3, env, "table", "nil")
  local fd, err = syscall("open", path, "r")
  if not fd then
    return nil, err
  end

  local data = syscall("read", fd, "a")
  syscall("close", fd)

  if data:sub(1,2) == "#!" then data = data:gsub("^(.-)\n", "") end

  return load(data, "="..path, mode, env or _G)
end

function _G.dofile(path)
  checkArg(1, path, "string")
  return assert(loadfile(path))()
end

function _G.require(mod)
  checkArg(1, mod, "string")

  if loaded[mod] then
    return loaded[mod]
  end

  local emsg = "module '"..mod.."' not found:"
  for _, searcher in ipairs(package.searchers) do
    local result, err = searcher(mod)
    if result then
      loaded[mod] = result
      return result

    else
      emsg = emsg .. "\n  " .. err
    end
  end

  error(emsg, 2)
end

-- Load io here too
_G.io = require("io")
dofile("/lib/lua/os.lua")
