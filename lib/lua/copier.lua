--- A table copier.
-- This module provides one function for obtaining a complete copy of a table.
-- @module copier
-- @alias lib

local lib = {}
local checkArg = require("checkArg")

local function deepcopy(orig, copies)
  copies = copies or {}
  local orig_type = type(orig)
  local copy

  if orig_type == 'table' then
    if copies[orig] then
      copy = copies[orig]

    else
      copy = {}
      copies[orig] = copy

      for orig_key, orig_value in next, orig, nil do
        copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
      end

      setmetatable(copy, deepcopy(getmetatable(orig), copies))
    end

  else -- number, string, boolean, etc
    copy = orig
  end

  return copy
end

--- Create a complete copy of a table.
-- Also copies metatables.  The implementation is from https://lua-users.org/wiki/CopyTable.
-- @tparam table tab The table to copy
-- @treturn table The new table
function lib.copy(tab)
  checkArg(1, tab, "table")
  return deepcopy(tab)
end

return lib
