--- Common package metadata stuff.

local lib = {}

local function split_on(str, c)
  str = str:gsub("%" .. c .. "%" .. c, c .. "!#!" .. c)
  local parts = {}
  for part in str:gmatch("[^%"..c.."]+") do
    if part == "!#!" then part = "" end
    parts[#parts+1] = part
  end
  return parts
end

lib.split_on = split_on

local defs = {
  package_list = {"name", "version", "size", "authors",
    "depends", "license", "description"},
  package = {"name", "version", "authors",
    "depends", "license", "description"},
  installed = {"version", "authors", "depends",
    "license", "repo", "description"}
}

function lib.split(meta, names)
  local split = split_on(meta, ":")

  for i=1, #split do
    if split[i]:find(",", nil, true) and i < #split then
      split[i] = split_on(split[i], ",")
    end
  end

  if names and defs[names] then
    local named = {}
    for i=1, #defs[names] do
      named[defs[names][i]] = split[i]
    end
    return named
  else
    return split
  end
end

function lib.assemble(...)
  local args = table.pack(...)

  for i=1, args.n do
    if type(args[i]) == "table" then
      args[i] = table.concat(args[i], ",")

    elseif not args[i] then
      args[i] = ""
    end
  end

  return table.concat(args, ":")
end

return lib
