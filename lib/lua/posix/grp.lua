-- posix.grp
-- very similar to posix.pwd

local errno = require("posix.errno")
local checkArg = require("checkArg")

local lib = {}

local FILE = "/etc/group"

local field_names = {
  -- extension: return gr_passwd if present
  "gr_name", "gr_passwd", "gr_gid", "gr_mem"
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
    if fields[i]:find(",") then
      local val = {}

      for name in fields[i]:gmatch("[^,]+") do
        val[#val+1] = name
      end

      ret[field_names[i]] = val

    else
      ret[field_names[i]] = tonumber(fields[i]) or fields[i]
    end
  end

  return ret
end

-- handle initialized by setgrent
local hand

function lib.setgrent()
  if hand then hand:close() end
  hand = assert(io.open(FILE, "r"))
end

function lib.getgrent()
  if not hand then lib.setgrent() end
  local line = hand:read("l")
  if not line then return end
  return to_fields(line)
end

function lib.endgrent()
  if hand then hand:close() end
  hand = nil
end

local function search(field, value)
  lib.setgrent()

  for entry in lib.getgrent do
    if entry[field] == value then
      lib.endgrent()
      return entry
    end
  end

  lib.endgrent()
end

function lib.getgrnam(name)
  checkArg(1, name, "string")
  return search("gr_name", name)
end

function lib.getgrgid(gid)
  checkArg(1, gid, "number")
  return search("gr_gid", gid)
end

-- extension: update_group
function lib.update_group(group)
  checkArg(1, group, "table")
  checkArg("group.gr_name", group.gr_name, "string")
  checkArg("group.gr_gid", group.gr_gid, "number")
  checkArg("group.gr_mem", group.gr_mem, "table")

  for i=1, #group.gr_mem, 1 do
    checkArg(string.format("group.gr_mem[%d]", i), group.gr_mem[i], "string")
  end

  if hand then
    return nil, errno.errno(errno.EBUSY), errno.EBUSY
  end

  local entries, added = {}, false
  for entry in lib.getgrent do
    if entry.gr_gid == group.gr_gid then
      entries[#entries+1] = group
      added = true

    else
      entries[#entries+1] = entry
    end
  end
  lib.endgrent()

  if not added then entries[#entries+1] = group end

  local handle, err = io.open(FILE, "w")
  if not handle then
    return nil, err
  end

  for i=1, #entries, 1 do
    local fields = {}

    for j=1, #field_names, 1 do
      if type(entries[i][field_names[j]]) == "table" then
        fields[j] = table.concat(entries[i][field_names[j]], ",")

      else
        fields[j] = tostring(entries[i][field_names[j]] or "")
      end
    end
    handle:write(table.concat(fields, ":").."\n")
  end

  handle:close()

  return true
end

return lib
