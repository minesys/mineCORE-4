--- UPT's logger
--@module upt.logger
--@alias lib

local lib = {}

local prefixes = {
  ok   = {
    color = "\27[92m*\27[97m ",
    standard = "* "
  },
  warn = {
    color = "\27[93m!\27[97m ",
    standard = "! "
  },
  fail = {
    color = "\27[91mX\27[97m ",
    standard = "X "
  },
}

local color = false
for k, v in pairs(prefixes) do
  lib[k] = function(...)
    io.stderr:write(color and v.color or v.standard, string.format(...), "\n")
  end
end

function lib.setColored(b)
  color = not not b
  return not color
end

return lib
