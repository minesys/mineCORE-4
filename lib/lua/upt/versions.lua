--- UPT version parser
-- Can parse versions like:
--  - 0.2.2 and 0.6.2.4.5
--  - 0.4-dev1 and 0.5.1-alpha4
-- Version format is more or less:
--   Real.Version.Info.Numbers-BuildInformation

local checkArg = require("checkArg")

local lib = {}

--- Parse a version string
-- @treturn table The version information, as a table of numbers
-- @treturn[opt] string The build information string
function lib.parse(ver)
  checkArg(1, ver, "string")

  local components
  if ver:match("-") then
    components = {ver:match("([^%-]+)%-(.+)")}
  else
    components = {ver}
  end

  local c1 = {}
  for num in components[1]:gmatch("[^%.]+") do
    if not tonumber(num) then
      return nil, "invalid number '"..num.."' in version string component 1"
    end
    c1[#c1+1] = tonumber(num)
  end

  setmetatable(c1, {__info = components[2]})

  components[1] = c1

  return table.unpack(components)
end

-- returns whether version v1 is GREATER than version v2
-- compared by first numbers back, so:
-- 0.2 > 0.1
-- 4.0.1 > 4.0
-- 4.5 > 4.0.1
-- 6.3.4 > 6.2.8.7
function lib.compare(v1, v2)
  for i=1, math.min(#v1, #v2) do
    if v1[i] > v2[i] then return true end
    if v1[i] < v2[i] then return false end
  end
  return #v1 > #v2 or getmetatable(v1).__info > getmetatable(v2).__info
end

return lib
