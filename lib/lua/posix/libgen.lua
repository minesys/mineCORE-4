-- posix.libgen implementation

local checkArg = require("checkArg")

local function segments(path)
  local dir, base = path:match("^(.-)/?([^/]+)/?$")
  dir = (dir and #dir > 0 and dir) or (path:sub(1,1) == "/" and "/" or ".")
  base = (base and #base > 0 and base) or "."
  return dir, base
end

local lib = {}

function lib.basename(path)
  checkArg(1, path, "string")
  return select(2, segments(path))
end

function lib.dirname(path)
  checkArg(1, path, "string")
  return (segments(path))
end

return lib
