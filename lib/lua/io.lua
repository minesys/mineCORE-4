-- io library implementation.
-- Due to how Cynosure 2 implements file streams,
-- this is a lot simpler than most OpenComputers
-- implementations of this library.

local sys = require("syscalls")
local errno = require("posix.errno")
local checkArg = require("checkArg")
local get_err = errno.errno

local lib = {}

local _iost = {
  read = function(self, ...)
    if self.closed then return nil, get_err(errno.EBADF) end

    local args = table.pack(...)
    if args.n == 0 then args[1] = "l"; args.n = 1 end

    local results = {}
    for i, format in ipairs(args) do
      results[i] = sys.read(self.fd, format)
    end

    return table.unpack(results, 1, args.n)
  end,

  lines = function(self, fmt)
    if self.closed then return nil, get_err(errno.EBADF) end

    return function()
      return self:read(fmt or "l")
    end
  end,

  write = function(self, ...)
    if self.closed then return nil, get_err(errno.EBADF) end
    local to_write = table.pack(...)

    for _, data in ipairs(to_write) do
      sys.write(self.fd, tostring(data))
    end
    return self
  end,

  seek = function(self, whence, offset)
    if self.closed then return nil, get_err(errno.EBADF) end
    return sys.seek(self.fd, whence, offset)
  end,

  flush = function(self)
    if self.closed then return nil, get_err(errno.EBADF) end
    return sys.flush(self.fd)
  end,

  close = function(self)
    if self.closed then return nil, get_err(errno.EBADF) end
    local _, closed = sys.close(self.fd)
    self.closed = self.closed or closed
    return true
  end,

  setvbuf = function(self, mode)
    if self.closed then return nil, get_err(errno.EBADF) end
    local ok, err = sys.ioctl(self.fd, "setvbuf", mode)
    if not ok then return nil, get_err(err) end

    return ok
  end,
}

local function mkiost(fd)
  checkArg(1, fd, "number")
  return setmetatable({fd=fd}, {__index=_iost})
end

lib._mkiost = mkiost

lib.stdin = mkiost(0)
lib.stdout = mkiost(1)
lib.stderr = mkiost(2)

function lib.open(path, mode)
  checkArg(1, path, "string")
  checkArg(2, mode, "string", "nil")

  mode = mode or "r"

  local fd, err = sys.open(path, mode)
  if not fd then
    return nil, path .. ": " .. get_err(err)
  end

  return mkiost(fd)
end

function lib.read(...)
  return lib.stdin:read(...)
end

function lib.write(...)
  return lib.stdout:write(...)
end

function lib.flush()
  return lib.stdout:flush()
end

local function check(file)
  checkArg(1, file, "table")
  if not file.fd then error("bad argument #1 (bad file descriptor)", 2) end
  return true
end

function lib.input(file)
  if file then
    if type(file) == "string" then file = assert(io.open(file, "r")) end
    check(file)
    lib.stdin:close()
    lib.stdin = file
  end

  return lib.stdin
end

function lib.output(file)
  if file then
    if type(file) == "string" then file = assert(io.open(file, "w")) end
    check(file)
    lib.stdout:close()
    lib.stdout = file
  end

  return lib.stdout
end

function lib.lines(file, ...)
  checkArg(1, file, "string", "nil")

  local handle = io.stdin
  if file then handle = assert(io.open(file, "r")) end

  local mode = table.pack(...)
  if mode.n == 0 then mode = {"l", n = 1} end

  return function()
    local result = table.pack(handle:read(table.unpack(mode, 1, mode.n)))
    if not result[1] then handle:close() end
    return table.unpack(result, 1, result.n)
  end
end

function lib.popen(command, mode)
  checkArg(1, command, "string")
  checkArg(2, mode, "string")
  local infd, outfd = sys.pipe()
  sys.fork(function()
    if mode == "r" then
      sys.dup2(1, infd)

    else
      sys.dup2(0, outfd)
    end

    local tokens = require("sh").split(command)
    tokens[0] = table.remove(tokens, 1)
    local resolved, failed = require("sh").resolve(tokens[0])
    if not resolved then io.stderr:write("sh: ", failed, "\n") return end
    sys.execve(require("sh").resolve(tokens[0]), tokens)
  end)
end

function _G.print(...)
  local args = table.pack(...)

  for i=1, args.n, 1 do
    args[i] = tostring(args[i])
  end

  lib.stdout:write(table.concat(args, "\t"), "\n")

  return true
end

return lib
