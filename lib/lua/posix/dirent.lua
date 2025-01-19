-- posix.dirent compatibility

local sys = require("syscalls")
local errno = require("posix.errno").errno
local checkArg = require("checkArg")

local lib = {}

function lib.files(path)
  checkArg(1, path, "string")

  local dirfd, err = sys.opendir(path)
  if not dirfd then
    error("Bad argument #1 to 'files' (" .. errno(err) .. ")")
  end

  return function()
    local ent = sys.readdir(dirfd)

    if not ent then
      sys.close(dirfd)
      return nil
    end

    return ent.name
  end
end

function lib.dir(path)
  checkArg(1, path, "string")

  local files = {}

  for file in lib.files(path) do
    files[#files+1] = file
  end

  return files
end

return lib
