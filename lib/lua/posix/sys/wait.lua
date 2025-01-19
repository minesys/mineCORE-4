-- posix.sys.wait

local lib = {
  WNOHANG = 1,
  WUNTRACED = 2
}

local sys = require("syscalls")
local errno = require("posix.errno")
local checkArg = require("checkArg")

function lib.wait(pid, options)
  checkArg(1, pid, "number", "nil")
  checkArg(2, options, "number", "nil")

  pid = pid or -1
  options = options or 0

  local reason, status
  if pid == -1 then
    pid, reason, status = sys.waitany(options & lib.WNOHANG == 0,
      options & lib.WUNTRACED ~= 0)

  else
    reason, status = sys.wait(pid, options & lib.WNOHANG ~= 0,
      options & lib.WUNTRACED ~= 0)
  end

  if not reason then
    return nil, errno.errno(status), status
  end

  return pid, reason == "signal" and "killed" or reason, status
end

return lib
