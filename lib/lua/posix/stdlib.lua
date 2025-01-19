-- posix.stdlib

local sys = require("syscalls")
local errno = require("posix.errno")
local checkArg = require("checkArg")

local lib = {}

function lib.getenv(var)
  checkArg(1, var, "string", "nil")

  local env = sys.environ()
  if var then return env[var] end

  local copy = {}
  for k,v in pairs(env) do copy[k]=v end
  return copy
end

local function segments(path)
  local segs = {}

  for seg in path:gmatch("[^/\\]+") do
    if seg == ".." then segs[#segs] = nil
    elseif seg ~= "." then segs[#segs+1] = seg end
  end

  return segs
end

lib._segments = segments

function lib.realpath(path)
  checkArg(1, path, "string")

  if path:sub(1,1) ~= "/" then path = sys.getcwd() .. "/" .. path end
  path = "/" .. table.concat(segments(path), "/")
  local ok, _errno = sys.stat(path)
  if not ok then return nil, errno.errno(_errno), _errno end

  return path
end

function lib.setenv(name, value, overwrite)
  checkArg(1, name, "string")
  checkArg(2, value, "string", "nil")

  overwrite = overwrite ~= nil
  local env = sys.environ()
  if env[name] and overwrite then return 0 end
  env[name] = value
  return 0
end

return lib
