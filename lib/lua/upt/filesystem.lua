--- UPT filesystem utilities.
-- @module upt.filesystem
-- @alias lib

local checkArg = require("checkArg")
local dirent = require("posix.dirent")
local errno = require("posix.errno")
local stat = require("posix.sys.stat")

local lib = {}

--- Check for file existence.
function lib.exists(file)
  checkArg(1, file, "string")
  return not not stat.stat(file)
end

--- Check if a file is a directory.
-- Returns false, and an error message, if the file does not exist.
function lib.isDirectory(file)
  checkArg(1, file, "string")

  local sx, err = stat.stat(file)
  if not sx then return nil, err end

  return stat.S_ISDIR(sx.st_mode) ~= 0
end

--- Create a directory, recursively.
-- Optionally performs some action when directories are newly created.
function lib.makeDirectory(file, on_new)
  checkArg(1, file, "string")
  local path = file:sub(1,1) == "/" and "/" or "./"

  for segment in file:gmatch("[^/\\]+") do
    path = path .. segment .. "/"
    local ok, err, eno = stat.mkdir(path, 0x1FF)
    if not ok and eno ~= errno.EEXIST then
      return ok, err, eno
    elseif on_new then
      pcall(on_new, path)
    end
  end

  return true
end

function lib.list(dir)
  checkArg(1, dir, "string")
  local files = dirent.dir(dir)
  table.sort(files)
  if files[1] == "." then table.remove(files, 1) end
  if files[1] == ".." then table.remove(files, 1) end
  return files
end

--- Combine file paths
function lib.combine(...)
  return (table.concat({...}, "/"):gsub("[/\\]+", "/"))
end

return lib
