--- Barebones table serialization and deserialization.
-- @module serialization
-- @alias lib

local function ser(va, seen)
  if type(va) ~= "table" then
    if type(va) == "string" then return string.format("%q", tostring(va))
    else return tostring(va) end end

  if seen[va] then return "{recursed}" end
  seen[va] = true

  local ret = "{"
  for k, v in pairs(va) do
    k = ser(k, seen)
    v = ser(v, seen)

    if k and v then
      ret = ret .. string.format("[%s]=%s,", k, v)
    end
  end

  return ret .. "}"
end

local lib = {}

local checkArg = require("checkArg")

--- Serialize a table.
-- @tparam table tab Table to serialize
-- @treturn string The serialized table
function lib.serialize(tab)
  checkArg(1, tab, "table")
  return ser(tab, {})
end

--- Deserialize a table.
-- @tparam string str The text to try to deserialize
-- @treturn table The deserialized table
function lib.deserialize(str)
  checkArg(1, str, "string")

  local ok, err = load("return " .. str, "=(deserialize)", "t", {})
  if not ok then return nil, err end
  return ok()
end

return lib
