-- some of posix.termio
-- this is a rather lackluster implementation

error("posix.termio is not currently supported", 0)

local lib = {
  -- no iflag constants present

  -- oflag
  ONLCR = 0x1,

  -- lflag
  ECHO  = 0x2,
  ISIG  = 0x4,
}

local sys = require("syscalls")
local errno = require("posix.errno")

function lib.tcdrain() return 0 end
local function enotsup() return -1, errno.errno(errno.ENOTSUP),
    errno.ENOTSUP end

lib.tcflow = enotsup
lib.tcflush = enotsup
lib.tcsendbreak = enotsup

local ccs = {
 intr   = 0,
 quit   = 1,
 erase  = 2,
 kill   = 3,
 eof    = 4,
 eol    = 5,
 start  = 9,
 stop   = 10,
 susp   = 11,
}

for k, v in pairs(ccs) do
  lib["V"..k:upper()] = v
end

function lib.tcgetattr(fd)
  checkArg(1, fd, "number")

  local attrs, err = sys.ioctl(fd, "getattrs")
  if not attrs then
    return nil, errno.errno(err), err
  end

  local ret = {cc={}, ispeed=50, ospeed=9600, iflag=0, oflag=0, lflag=0}

  for k, v in pairs(ccs) do ret.cc[v] = attrs[k] end

  return ret
end

function lib.tcsetattr(_, _, _)
  error("tcsetattr not implemented")
end

return lib
