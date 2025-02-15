--!lua
-- diskinfo - read disk/partition information

local sizes = require("sizes")

local args, opts, usage = require("getopt").process {
  {"Show this help message", false, "h", "help"},
  exit_on_bad_opt = true,
  args = ...
}

local function showusage()
  io.stderr:write(([[
usage: diskinfo [VOLUME]...
Show information about the given volumes.

options:
%s

Copyright (c) 2025 mineSYS under the GNU GPLv3.
]]):format(usage))
  os.exit(1)
end

if #args == 0 or opts.h then showusage() end

local function read(hand, n, start, _size)
  start = start or 0
  _size = _size or math.huge
  if n == 0 then error"bad sector offset: 0" end
  if n < 0 then
    local size = hand:seek("end")/512
    n = (math.min(start+_size-1, size) + n)*512
  else
    n = (n-1+start-1)*512
  end
  hand:seek("set",n)
  return hand:read(512)
end

local function fix(t)
  for i=1, #t do
    if type(t[i]) == "string" then
      t[i] = t[i]:gsub("\0","")
    end
  end
  return t
end

local disk_formats = {
  mtpt = {
    true, -- describes partition, not filesystem
    -1, -- sector offset, negative = from end of disk
    "c20c4>I4>I4", -- unpack pattern
    3, -- start
    4, -- size
    2, -- type
    1, -- name
    function(m)return m[2]=="mtpt"end, -- validate first entry
    function(m)return#m[1]>0 end -- validate future entries
  },
  osdi = {true, 1, "<I4I4c8c3c13", 1, 2, 3, 5,
    function(m)return m[1]==1 and m[2]==0 and m[3]=="OSDI\xAA\xAA\x55\x55"end,
    function(m)return #m[5]>0 end},
  simplefs = {
    false, -- describes filesystem
    1, -- sector offset
    "<c4I1I1I2I2I3I3c19", -- unpack pattern
    function(m) -- recognizer
      return m[1] == "\x1bSFS"
    end,
    function(m) -- formatter
      return ("type=simplefs, label='%s', files=%d, free=%s")
        :format(m[8], m[4]*(m[5]/64), sizes.format((m[6]-m[7])*m[5]))
    end
  },
}

local function recognize(d, hand, start, size)
  local found = false
  for name, info in pairs(disk_formats) do
    local sector = read(hand, info[2], start, size)
    local data = fix({info[3]:unpack(sector)})
    if info[1] then
      if info[8](data) then
        found = true
        local partitions = {}
        repeat
          sector = sector:sub(string.packsize(info[3])+1)
          local meta = fix({info[3]:unpack(sector)})
          if info[9](meta) then
            partitions[#partitions+1] = {
              name = meta[info[7]],
              type = meta[info[6]],
              start = meta[info[4]],
              size = meta[info[5]]
            }
          end
        until #sector <= string.packsize(info[3])
        print(string.format("%s: %s, table=%s, name=%s", d, sizes.format(size), name, data[info[7]]))
        for i=1, #partitions do
          io.write("  ")
          recognize(d..i, hand,
            partitions[i].start-1, partitions[i].size)
        end
        break
      end
    else
      if info[4](data) then
        found = true
        print(d..": "..sizes.format(size)..", "..info[5](data))
        break
      end
    end
  end
  if not found then
    print(d..": "..sizes.format(size*512)..", unrecognized")
  end
end

for i=1, #args do
  local hand, err = io.open(args[i], "r")
  if not hand then
    io.stderr:write("diskinfo: ", err, "\n")
    os.exit(1)
  end
  local size = hand:seek("end")
  hand:seek("set")
  recognize(args[i], hand, nil, size)
  hand:close()
end

