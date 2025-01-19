-- posix.stdio

local lib = {}
local checkArg = require("checkArg")

lib.fdopen = io._mkiost

function lib.fileno(file)
  checkArg(1, file, "table")
  checkArg(1, file.fd, "number")
  return file.fd
end

return lib
