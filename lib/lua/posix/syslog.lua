-- posix.syslog

local syscalls = require("syscalls")
local checkArg = require("checkArg")
local klogctl = syscalls.klogctl
local getpid = syscalls.getpid

local lib = {
  LOG_KERN = 0,
  LOG_USER = 1,
  LOG_MAIL = 2,
  LOG_DAEMON = 3,
  LOG_AUTH = 4,
  LOG_SYSLOG = 5,
  LOG_LPR = 6,
  LOG_NEWS = 7,
  LOG_UUCP = 8,
  LOG_CRON = 9,
  LOG_AUTHPRIV = 10,
  LOG_FTP = 11,
}

for i=0, 7, 1 do
  lib["LOG_LOCAL"..tostring(i)] = 16 + i
end

for k, v in pairs(lib) do lib[k] = v << 3 end

function lib.LOG_MASK(priority)
  checkArg(1, priority, "number")
  return 1 << priority
end

-- map of { [pid] = { attributes } }
local opened = {}

function lib.closelog()
  opened[getpid()] = nil
end

-- TODO: do something with `facility`
function lib.openlog(ident, option, facility)
  checkArg(1, ident, "string")
  checkArg(2, option, "number", "nil")
  checkArg(3, facility, "number", "nil")

  opened[getpid()] = {id = ident, opt = option, facility = facility}
end

function lib.setlogmask(mask)
  checkArg(1, mask, "number")

  return 0
end

local function read(f)
  local h = io.open(f, "r")
  return h:read("a"), h:close()
end

function lib.syslog(priority, message)
  checkArg(1, priority, "number")
  checkArg(2, message, "string")

  local opts = opened[getpid()] or {id = read("/proc/self/cmdline/0"),
    opt = lib.LOG_PID, facility = 1}

  local begin = opts.id

  if (opts.opt & lib.LOG_PID) ~= 0 then
    begin = begin .. "[" .. tostring(getpid()) .. "]"
  end

  begin = begin .. ": %s"

  klogctl("log", priority | opts.facility, begin, message)
end

return lib
