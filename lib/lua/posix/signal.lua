-- posix.signal

local sys = require("syscalls")
local errno = require("posix.errno")
local checkArg = require("checkArg")

local lib = {}

local lookup = {}

for k, v in pairs({ SIGEXIST = 0, SIGHUP = 1, SIGINT = 2, SIGQUIT = 3,
    SIGKILL = 9, SIGPIPE = 13, SIGTERM = 15, SIGCHLD = 17, SIGCONT = 18,
    SIGSTOP = 19, SIGTSTP = 20, SIGTTIN = 21, SIGTTOU = 22}) do
  lookup[k] = v
  lookup[v] = k
  lib[k] = v
end

function lib.SIG_IGN() end

function lib.kill(pid, opt)
  checkArg(1, pid, "number")
  checkArg(2, opt, "number", "nil")
  opt = opt or lib.SIGTERM

  if not lookup[opt] then
    return nil, errno.errno(errno.EINVAL), errno.EINVAL
  end

  local yes, eno = sys.kill(pid, lookup[opt])
  if not yes then
    return nil, errno.errno(eno), eno
  end

  return 0
end

function lib.killpg(pgrp, sig)
  checkArg(1, pgrp, "number")
  checkArg(2, sig, "number", "nil")
  sig = sig or lib.SIGTERM

  if not lookup[sig] then
    return nil, errno.errno(errno.EINVAL), errno.EINVAL
  end

  local yes, eno = sys.kill(-pgrp. lookup[sig])
  if not yes then
    return nil, errno.errno(eno), eno
  end

  return 0
end

function lib.raise(sig)
  checkArg(1, sig, "number")
  return lib.kill(0, sig)
end

-- TODO: do something with `flags`
function lib.signal(signum, handler)
  checkArg(1, signum, "number")
  checkArg(2, handler, "function", "nil")

  if not lookup[signum] then
    return nil, errno.errno(errno.EINVAL), errno.EINVAL
  end

  return sys.sigaction(lookup[signum], handler)
end

return lib
