--- Provides utilities for working with file permissions.
-- @module permissions
-- @alias lib

local order = {
  0x001,
  0x002,
  0x004,
  0x008,
  0x010,
  0x020,
  0x040,
  0x080,
  0x100,
}

local reverse = {
  "x",
  "w",
  "r",
  "x",
  "w",
  "r",
  "x",
  "w",
  "r",
}

local lib = {}

local errno = require("posix.errno")
local checkArg = require("checkArg")

--- Convert a string representation to a binary one.
-- Takes a string in a form similar to that output by `ls`, and returns a number with the appropriate bits set.  The string must be exactly nine characters long and in the format `rwxrwxrwx`, where any `r`, `w`, or `x` may be replaced by a `-`.
-- For example, `rwxrw-r--`, `r-xr-xr-x`, and `rw--wx--w-` are all valid, but `rwrwrw` is not.
-- @tparam string permstr The string to process
-- @treturn number A numerical representation of the input string
function lib.strtobmp(permstr)
  checkArg(1, permstr, "string")

  if not permstr:match("[r%-][w%-][xs%-][r%-][w%-][x%-][r%-][w%-][x%-]") then
    return nil, errno.errno(errno.EINVAL)
  end

  local bitmap = 0

  for i=#order, 1, -1 do
    local index = #order - i + 1
    if permstr:sub(index, index) ~= "-" then
      bitmap = bitmap | order[i]
    end
  end

  return bitmap
end

--- Convert a bitmap representation to a string.
-- The bitmap must be in the same format as a POSIX file mode - the same as that returned by @{strtobmp}.
-- @tparam number bitmap The permissions to process
-- @treturn string A string representation, in the same form as passed to @{strtobmp}.
function lib.bmptostr(bitmap)
  checkArg(1, bitmap, "number")

  local ret = ""

  for i=#order, 1, -1 do
    if (bitmap & order[i]) ~= 0 then
      -- TODO: this is a bit hacky, is there a cleaner way to do it?
      if i == 7 and (bitmap & 0x800) ~= 0 then -- setuid
        ret = ret .. "s"
      elseif i == 4 and (bitmap & 0x400) ~= 0 then -- setgid
        ret = ret .. "s"
      else
        ret = ret .. reverse[i]
      end

    else
      ret = ret .. "-"
    end
  end

  return ret
end

--- Check if a permission is set.
-- Checks if the given permission string, when ANDed with the given `mode`, is exactly returned.  Relatively inflexible.
-- @tparam number mode The file mode to check against
-- @tparam string perm The permissions to check
-- @treturn boolean Whether the given permission is set
function lib.has_permission(mode, perm)
  checkArg(1, mode, "number")
  checkArg(2, perm, "string")

  local val_check = lib.strtobmp(perm)

  return (mode & val_check) == val_check
end

return lib
