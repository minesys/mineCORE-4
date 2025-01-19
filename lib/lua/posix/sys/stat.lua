-- posix.sys.stat --

local sys = require("syscalls")
local errno = require("posix.errno")
local checkArg = require("checkArg")

-- constants, as per LuaPosix docs
local lib = {
  S_IFMT = 0xF000, -- file type mode bitmask
  S_IFBLK = 0x6000,
  S_IFCHR = 0x2000,
  S_IFDIR = 0x4000,
  S_IFIFO = 0x1000,
  S_IFLNK = 0xA000,
  S_IFREG = 0x8000,
  S_IFSOCK = 0xC000,

  S_IRWXU = 448, -- S_IRUSR | S_IWUSR | S_IXUSER
  S_IRUSR = 0x100,
  S_IWUSR = 0x80,
  S_IXUSR = 0x40,

  S_IRWXG = 56, -- S_IRGRP | S_IWGRP | S_IXGRP
  S_IRGRP = 0x20,
  S_IWGRP = 0x10,
  S_IXGRP = 0x8,

  S_IRWXO = 7, -- S_IROTH | S_IWOTH | S_IXOTH
  S_IROTH = 0x4,
  S_IWOTH = 0x2,
  S_IXOTH = 0x1,

  S_ISGID = 0x400,
  S_ISUID = 0x800,
}

-- helper testing functions
local inverse = {
  S_ISBLK = lib.S_IFBLK,
  S_ISCHR = lib.S_IFCHR,
  S_ISDIR = lib.S_IFDIR,
  S_ISFIFO = lib.S_IFIFO,
  S_ISLNK = lib.S_IFLNK,
  S_ISREG = lib.S_IFREG,
  S_ISSOCK = lib.S_IFSOCK
}

for k, v in pairs(inverse) do
  lib[k] = function(num)
    checkArg(1, num, "number")
    return (num & lib.S_IFMT) == v and 1 or 0
  end
end

function lib.fstat()
  return nil, errno.errno(errno.ENOTSUP), errno.ENOTSUP
end

function lib.lstat(path)
  checkArg(1, path, "string")

  local statx, eno = sys.stat(path)
  if not statx then
    return nil, errno.errno(eno), eno
  end

  return {
    st_dev = statx.dev,
    st_ino = statx.ino,
    st_mode = statx.mode,
    st_nlink = statx.nlink,
    st_uid = statx.uid,
    st_gid = statx.gid,
    st_rdev = statx.rdev,
    st_size = statx.size,
    st_atime = statx.atime,
    st_mtime = statx.mtime,
    st_ctime = statx.ctime,
    st_blksize = statx.blksize,
    st_blocks = math.ceil(statx.size / statx.blksize)
  }
end

lib.stat = lib.lstat

function lib.mkdir(path, mode)
  checkArg(1, path, "string")
  checkArg(2, mode, "number")

  local done, eno = sys.mkdir(path, mode or 511)
  if not done then
    return nil, errno.errno(eno), eno
  end
  return 0
end

function lib.chmod(path, mode)
  checkArg(1, path, "string")
  checkArg(2, mode, "number")

  local done, eno = sys.chmod(path, mode)
  if not done then
    return nil, errno.errno(eno), eno
  end

  return 0
end

function lib.umask(mode)
  checkArg(1, mode, "number")
  return sys.umask(mode)
end

return lib
