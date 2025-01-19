--- File tree related utilities.
-- @module treeutil
-- @alias lib

local checkArg = require("checkArg")
local stdlib = require("posix.stdlib")
local dirent = require("posix.dirent")
local stat = require("posix.sys.stat")

local lib = {}

--- Create a tree of file names.
-- Recursively traverse a directory structure, generating a tree of all filenames.
-- @tparam string path The path to build a tree from.
-- @tparam[opt] table modify A table to add entries to.
-- @tparam[opt] function foreach A function to call with each file path as its argument.
-- @treturn table A table of file paths
function lib.tree(path, modify, foreach)
  checkArg(1, path, "string")
  checkArg(2, modify, "table", "nil")
  checkArg(3, foreach, "function", "nil")

  local tree = modify or {}
  local abs, err = stdlib.realpath(path)
  if not abs then return nil, err end

  local files, _err = dirent.dir(abs)
  if not files then
    return nil, _err
  end

  for i=1, #files, 1 do
    if files[i] ~= "." and files[i] ~= ".." then
      local full = abs .. "/" .. files[i]
      local info, __err = stat.stat(full)
      if not info then
        return nil, __err
      end

      tree[#tree+1] = path .. "/" .. files[i]

      if foreach then
        -- passing info here
        foreach(tree[#tree], info)
      end

      if stat.S_ISDIR(info.st_mode) ~= 0 then
        local ok, ___err = lib.tree(tree[#tree], tree, foreach)
        if not ok then
          return nil, ___err
        end
      end
    end
  end

  return tree
end

return lib
