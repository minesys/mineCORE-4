-- posix.sys.utsname

local sys = require("syscalls")

local lib = {}

function lib.uname()
  return sys.uname()
end

return lib
