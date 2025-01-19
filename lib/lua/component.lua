-- for when you really need component access

local files = require("posix.dirent").files
local syscalls = require("syscalls")
local checkArg = require("checkArg")
local open = syscalls.open
local close = syscalls.close
local ioctl = syscalls.ioctl

local component = {}

local components = "/dev/components/"

local function is(ctype, want, exact)
  if not want then return true end

  if exact then
    return ctype:sub(0, #want) == want

  else
    return not not ctype:match(want)
  end
end

local map = {}

function component.list(ctype, exact)
  checkArg(1, ctype, "string", "nil")
  checkArg(2, exact, "boolean", "nil")
  local ret = {}

  map = {}

  for comptype in files(components) do
    if is(comptype, ctype, exact) then
      for comp in files(components..comptype) do
        local fd = open(components..comptype.."/"..comp, "r")
        local address = ioctl(fd, "address")
        close(fd)

        map[address] = {id=comp, type=comptype, slot=ioctl(fd, "slot")}
        ret[address] = comptype
      end
    end
  end

  local k
  setmetatable(ret, {__call = function()
    k = next(ret, k)

    if k then return k, ret[k], string.format("%s%s/%s", components,
      map[k].type, map[k].id) end
  end})

  return ret
end

local function get(address)
  if not map[address] then
    component.list()
  end

  if not map[address] then
    return nil, "no such component"
  end

  return map[address]
end

local function invoke(address, ...)
  local entry, err = get(address)
  if not entry then
    return nil, err
  end

  local fd = open(components..entry.type.."/"..entry.id, "r")
  local result = table.pack(ioctl(fd, "invoke", ...))
  close(fd)

  return table.unpack(result, 1, result.n)
end

function component.proxy(address)
  checkArg(1, address, "string")

  local entry, err = get(address)
  if not entry then
    return nil, err
  end

  local fd = open(components..entry.type.."/"..entry.id, "r")
  local methods = ioctl(fd, "methods")

  local proxy = {slot = entry.slot, type = entry.type, address = address}
  for method, direct in pairs(methods) do
    if direct then
      local doc = ioctl(fd, "doc", method)

      -- TODO: is there a less leaky way of doing this better?
      proxy[method] = setmetatable({}, {__call = function(_, ...)
        return invoke(address, method, ...)
        --ioctl(fd, "invoke", method, ...)
      end, __tostring = function() return doc end})
    end
  end

  close(fd)

  return proxy
end

local function field(address, key)
  local entry, err = get(address)
  if not entry then
    return nil, err
  end

  return entry[key]
end

function component.invoke(address, method, ...)
  checkArg(1, address, "string")
  checkArg(2, method, "string")

  return invoke(address, method, ...)
end

function component.doc(address, method)
  checkArg(1, address, "string")
  checkArg(2, method, "string")

  return invoke(address, "doc", method)
end

function component.methods(address)
  checkArg(1, address, "string")

  return invoke(address, "methods")
end

function component.type(address)
  checkArg(1, address, "string")

  return field(address, "type")
end

function component.slot(address)
  checkArg(1, address, "string")

  return field(address, "slot")
end

function component.fields(address)
  checkArg(1, address, "string")

  return invoke(address, "fields")
end

function component.get(addr, ctype)
  checkArg(1, addr, "string")
  checkArg(2, ctype, "string", "nil")

  for address in component.list(ctype, true) do
    if address:sub(1, #addr) == addr then
      return address
    end
  end

  return nil, "no such component"
end

return component
