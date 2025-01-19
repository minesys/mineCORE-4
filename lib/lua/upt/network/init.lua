-- check OS and return appropriate networking functions

local uname = require("posix.sys.utsname").uname()

if uname.sysname ~= "Cynosure" then
  return require("upt.network.socket")
end

return require("upt.network.ulos2")
