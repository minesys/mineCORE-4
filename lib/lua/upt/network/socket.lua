-- LuaSocket networking module

local checkArg = require("checkArg")
local http = require("socket.http")

local lib = {}

function lib.retrieve(url, file)
  checkArg(1, url, "string")
  checkArg(2, file, "string")

  local data, code = http.request(url)
  if code < 200 or code > 299 then
    return nil, "HTTP error " .. tostring(code)
  end

  local handle, werr = io.open(file, "w")
  if not handle then
    return nil, werr
  end

  handle:write(data):close()

  return #data
end

return lib
