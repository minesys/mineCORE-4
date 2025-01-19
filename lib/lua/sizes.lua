--- Some utility functions for formatting of data sizes i.e. file sizes.
-- @module sizes
-- @alias lib

local lib = {}

local checkArg = require("checkArg")

local suffix = {
  [0]="b", "K", "M", "G", "T", "P"
}

--- Format a size with the given base.
-- This function returns a string with the last character set accordingly.  For example, `sizes.format(2048)` returns `"2K"`.  `base` defaults to 1024.  The resulting size is always rounded to the nearest whole number.
-- @tparam number size The size to format
-- @tparam[opt=1024] number base What to divide `size` by if it is larger than `base`
-- @tparam[opt=""] string ssuffix A suffix to concatenate if `size >= base`
-- @treturn string The formatted size
function lib.format(size, base, ssuffix)
  checkArg(1, size, "number")
  checkArg(2, base, "number", "nil")
  checkArg(3, ssuffix, "string", "nil")

  base = base or 1024
  ssuffix = ssuffix or ""
  local i = 0

  while size > base do
    i = i + 1
    size = size / base
  end

  return string.format("%d%s%s", math.floor(size + 0.5), suffix[i],
    i > 0 and ssuffix or (" "):rep(#ssuffix))
end

--- Format a size in base 10.
-- Equivalent to `sizes.format(size, 1000, "i")`.  `format10(4096)` returns `4Ki`.
-- @tparam number size The size to format
-- @treturn string The formatted size
function lib.format10(size)
  return lib.format(size, 1000, "i")
end

return lib
