-- posix.pwd

local errno = require("posix.errno")
local checkArg = require("checkArg")

local lib = {}

local FILE = "/etc/passwd"

local field_names = {
  -- extension: return pw_passwd
  "pw_name", "pw_passwd",
  "pw_uid", "pw_gid",
  -- extension: return pw_gecos
  "pw_gecos", "pw_dir",
  "pw_shell"
}

local function to_fields(line)
  local fields = {""}
  for c in line:gmatch(".") do
    if c == ":" then
      fields[#fields+1] = ""

    else
      fields[#fields] = fields[#fields] .. c
    end
  end

  local ret = {}

  for i=1, #fields, 1 do
    ret[field_names[i]] = tonumber(fields[i]) or fields[i]
  end

  return ret
end

-- handle initialized by setpwent
local hand

function lib.setpwent()
  if hand then hand:close() end
  hand = assert(io.open(FILE, "r"))
end

function lib.getpwent()
  if not hand then lib.setpwent() end
  local line = hand:read("l")
  if not line then return end
  return to_fields(line)
end

function lib.endpwent()
  if hand then hand:close() end
  hand = nil
end

local function search(field, value)
  lib.setpwent()
  for entry in lib.getpwent do
    if entry[field] == value then
      lib.endpwent()
      return entry
    end
  end
  lib.endpwent()
end

function lib.getpwnam(name)
  checkArg(1, name, "string")
  return search("pw_name", name)
end

function lib.getpwuid(uid)
  checkArg(1, uid, "number")
  return search("pw_uid", uid)
end

-- extension: update_passwd
function lib.update_passwd(passwd)
  checkArg(1, passwd, "table")
  checkArg("passwd.pw_name", passwd.pw_name, "string")
  checkArg("passwd.pw_passwd", passwd.pw_passwd, "string")
  checkArg("passwd.pw_uid", passwd.pw_uid, "number")
  checkArg("passwd.pw_gid", passwd.pw_gid, "number")
  checkArg("passwd.pw_gecos", passwd.pw_gecos, "string", "nil")
  checkArg("passwd.pw_dir", passwd.pw_dir, "string")
  checkArg("passwd.pw_shell", passwd.pw_shell, "string", "nil")

  if hand then
    return nil, errno.errno(errno.EBUSY), errno.EBUSY
  end

  local entries, added = {}, false
  for entry in lib.getpwent do
    if entry.pw_uid == passwd.pw_uid then
      entries[#entries+1] = passwd
      added = true

    else
      entries[#entries+1] = entry
    end
  end

  lib.endpwent()

  if not added then entries[#entries+1] = passwd end

  local handle, err = io.open(FILE, "w")
  if not handle then
    return nil, err
  end

  for i=1, #entries, 1 do
    local fields = {}
    for j=1, #field_names, 1 do
      fields[j] = tostring(entries[i][field_names[j]] or "")
    end

    handle:write(table.concat(fields, ":").."\n")
  end

  handle:close()

  return true
end

return lib
