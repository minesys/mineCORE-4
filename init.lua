-- CLDR 2

local write = ... or function() end

-- Menus

local gpu = component.proxy((component.list("gpu", true)()))
local screen = component.list("screen", true)()
local menu = function(_,_,a) return a end

if gpu and screen then
  gpu.bind(screen)

  local w, h = gpu.maxResolution()
  gpu.setResolution(w, h)

  local hw = math.floor(w / 2)

  local function draw(title, opts, sel)
    gpu.setForeground(0xFFFFFF)
    gpu.setBackground(0x000000)

    local version = "mineCORE Loader 1.0 (Alpha)"
    gpu.set(hw - math.floor(#version / 2), 2, version)
    gpu.set(hw - math.floor(#title / 2), h - #opts - 2, title)

    for i=#opts, 1, -1 do
      gpu.setForeground(i == sel and 0 or 0xFFFFFF)
      gpu.setBackground(i == sel and 0xFFFFFF or 0)
      gpu.fill(1, h - (#opts - i + 1), w, 1, " ")
      gpu.set(hw - math.floor(#opts[i] / 2), h - (#opts - i + 1), opts[i])
    end
  end

  menu = function(title, opts, default, timeout)
    local selected = default or 1
    local time = computer.uptime()
    timeout = timeout or math.huge
    local maxtime = time + timeout

    gpu.setForeground(0xFFFFFF)
    gpu.setBackground(0)
    gpu.fill(1, 1, w, h, " ")
    gpu.set(w, h, tostring(math.floor(maxtime - time + 0.5)))

    while true do
      draw(title, opts, selected)

      time = computer.uptime()
      local sig, _, char, code = computer.pullSignal(0.5)

      if sig == "key_down" then
        maxtime = math.huge

        if char == 13 then
          return selected

        elseif code == 200 then
          selected = math.max(1, selected - 1)

        elseif code == 208 then
          selected = math.min(#opts, selected + 1)
        end

      elseif time >= maxtime then
        gpu.setForeground(0xFFFFFF)
        gpu.setBackground(0)
        gpu.fill(1, 1, w, h, " ")
        return selected

      else
        gpu.setForeground(0xFFFFFF)
        gpu.setBackground(0)
        gpu.set(w, h, tostring(maxtime - time))
      end
    end
  end
end
-- Abstract filesystem support

local fs = {filesystems = {}, partitions = {}}

-- create partition cover object for unmanaged drives
-- code taken directly from Cynosure 2
function fs.create_subdrive(drive, start, size)
  local sub = {}
  local sector, byte = start, (start - 1) * drive.getSectorSize()
  local byteSize = size * drive.getSectorSize()
  function sub.readSector(n)
    if n < 1 or n > size then
      error("invalid offset, not in a usable sector", 0)
    end
    return drive.readSector(sector + n - 1)
  end
  function sub.writeSector(n, d)
    if n < 1 or n > size then
      error("invalid offset, not in a usable sector", 0)
    end
    return drive.writeSector(sector + n - 1, d)
  end
  function sub.readByte(n)
    if n < 1 or n > byteSize then return 0 end
    return drive.readByte(n + byteOffset)
  end
  function sub.writeByte(n, i)
    if n < 1 or n > byteSize then return 0 end
    return drive.writeByte(n + byteOffset, i)
  end
  sub.getSectorSize = drive.getSectorSize
  function sub.getCapacity()
    return drive.getSectorSize() * size
  end
  sub.type = "drive"
  return sub
end

function fs.detect(component)
  local partitions = {component}

  for pt, partition in pairs(fs.partitions) do
    local result = partition(component)
    if result then
      partitions = result
      break
    end
  end

  local results = {}
  for i=1, #partitions do
    local part = partitions[i]
    for name, reader in pairs(fs.filesystems) do
      local result = reader(part)
      if result then
        results[#results+1] = {
          name = name, proxy = result, index = part.index }
        break
      end
    end
  end

  return results
end

-- partitions
-- recognize OSDI disks

do
  local pattern = "<I4I4c8I3c13"
  local magic = "OSDI\xAA\xAA\x55\x55"
  function fs.partitions.osdi(drive)
    if drive.type ~= "drive" then return end

    local sector = drive.readSector(1)
    local meta = {pattern:unpack(sector)}
    if meta[1] ~= 1 or meta[2] ~= 0 or meta[3] ~= magic then return end
    local partitions = {}

    local index = 0
    repeat
      index = index + 1
      sector = sector:sub(33)
      meta = {pattern:unpack(sector)}
      meta[3] = meta[3]:gsub("\0", "")
      meta[5] = meta[5]:gsub("\0", "")
      if #meta[5] > 0 then
        write("found " .. meta[5])
        partitions[#partitions+1] = fs.create_subdrive(drive, meta[1], meta[2])
        partitions[#partitions].index = index
      end
    until #sector <= 32

    return partitions
  end
end
-- filesystems
-- Managed fs support

do
  local _node = {}
  function _node:read_file(f)
    local fd, err = self.fs.open(f, "r")
    if not fd then error(err) end
    local data = ""

    for chunk in function()return self.fs.read(fd, math.huge) end do
      data = data .. chunk
    end

    self.fs.close(fd)
    return data
  end

  function _node:exists(f)
    return self.fs.exists(f)
  end

  function fs.filesystems.managed(comp)
    if comp.type == "filesystem" then
      return setmetatable({
        fs = comp,
        index = 1,
        label = comp.getLabel(),
      }, {__index = _node})
    end
  end
end
-- SimpleFS support
-- simple, pared back, read-only driver
do
  local _node = {}

  local structures = {
    superblock = {
      pack = "<c4BBI2I2I3I3",
      names = {"signature", "flags", "revision", "nl_blocks", "blocksize", "blocks", "blocks_used"}
    },
    nl_entry = {
      pack = "<I2I2I2I2I2I4I8I8I2I2c94",
      names = {"flags", "datablock", "next_entry", "last_entry", "parent", "size", "created", "modified", "uid", "gid", "fname"}
    },
  }

  local function split(path)
    local segments = {}
    for piece in path:gmatch("[^/\\]+") do
      if piece == ".." then
        segments[#segments] = nil

      elseif piece ~= "." then
        segments[#segments+1] = piece
      end
    end

    return segments
  end

  local function unpack(name, data)
    local struct = structures[name]
    local ret = {}
    local fields = table.pack(string.unpack(struct.pack, data))
    for i=1, #struct.names do
      ret[struct.names[i]] = fields[i]
      if fields[i] == nil then
        error("unpack:structure " .. name .. " missing field " .. struct.names[i
])
      end
    end
    return ret
  end

  function _node:readBlock(n)
    local data = ""
    for i=1, self.bstosect do
      data = data .. self.drive.readSector(i+n*self.bstosect)
    end
    return data
  end

  function _node:readSuperblock()
    self.sblock = unpack("superblock", self.drive.readSector(1))
    self.sect = self.drive.getSectorSize()
    self.bstosect = self.sblock.blocksize / self.sect
  end

  function _node:readNamelistEntry(n)
    local offset = n * 128 % self.sblock.blocksize + 1
    local block = math.floor(n/8)
    local blockData = self:readBlock(block+2)
    local namelistEntry = blockData:sub(offset, offset + 127)
    local ent = unpack("nl_entry", namelistEntry)
    ent.fname = ent.fname:gsub("\0", "")
    return ent
  end

  function _node:getNext(ent)
    if (not ent) or ent.next_entry == 0 then return nil end
    return self:readNamelistEntry(ent.next_entry), ent.next_entry
  end

  function _node:resolve(path)
    local segments = split(path)
    local dir = self:readNamelistEntry(0)
    local current, cid = dir, 0
    for i=1, #segments do
      current,cid = self:readNamelistEntry(current.datablock), current.datablock
      while current and current.fname ~= segments[i] do
        current, cid = self:getNext(current)
      end
      if not current then
        return nil, "no such file or directory"
      end
    end
    return current, cid
  end

  function _node:getBlocks(ent)
    local blocks = {ent.datablock}
    local current = ent.datablock
    while true do
      local data = self:readBlock(current)
      local nxt = ("<I3"):unpack(data:sub(-3))
      if nxt == 0 then break end
      current = nxt
      blocks[#blocks+1] = nxt
    end
    return blocks
  end

  function _node:read_file(f)
    local ent, eid = self:resolve(f)
    if not ent then return nil, eid end

    local blocks = self:getBlocks(ent)

    local data = ""
    for i=1, #blocks do
      data = data .. self:readBlock(blocks[i]):sub(1,-4):gsub("\0", "")
    end

    return data
  end

  function _node:exists(f)
    return not not self:resolve(f)
  end

  function fs.filesystems.simplefs(drive)
    if drive.type ~= "drive" then return end
    if unpack("superblock", drive.readSector(1)).signature == "\x1bSFS" then
      local node = setmetatable({
        drive = drive,
        sblock = {},
      }, {__index = _node})
      node:readSuperblock()
      return node
    end
  end
end

do
  local detected = {}
  for addr, ctype in component.list() do
    if ctype == "filesystem" or ctype == "drive" then
      write("detect " .. addr)
      local partitions = fs.detect(component.proxy(addr))
      write(#partitions .. " partition(s) are bootable")
      for i=1, #partitions do
        local fstype, interface = partitions[i].name, partitions[i].proxy
        if interface:exists("/boot/cldr.cfg") then
          detected[#detected+1] = {
            address=addr,
            interface=interface,
            type=fstype,
            index=partitions[i].index,
            label=(interface.label or addr)..","..i}
        end
      end
    end
  end

  write("found " .. #detected .. " partition(s) with configuration")

  if #detected == 0 then
    error("no boot filesystems found!")
  end

  local opt = 1
  if #detected > 1 then
    local names = {}
    table.sort(detected, function(a,b) return a.label<b.label end)
    for i=1, #detected do
      names[i] = detected[i].type .. " from " .. detected[i].label
    end
    opt = menu("Select a boot device:", names, 1, 5)
  end
  fs.read_file = function(f) return detected[opt].interface:read_file(f) end
  fs.exists = function(f) return detected[opt].interface:exists(f) end

  -- supposedly this function is "deprecated," but everybody still uses it
  if detected[opt].type == "managed" then
    function computer.getBootAddress()
      return detected[opt].address
    end
  else
    function computer.getBootAddress()
      return detected[opt].address..","..detected[opt].index
    end
  end
end
-- Common config parsing bits

local function to_words(str)
  local words = {}

  for word in str:gmatch("[^ ]+") do
    words[#words+1] = word
  end

  return words
end

local function to_lines(str)
  local lines = {}
  for line in str:gmatch("[^\n]+") do
    if line:sub(1,1) ~= "#" then
      lines[#lines+1] = line
    end
  end

  local i = 0
  return function()
    i = i + 1
    return lines[i]
  end
end

local arch_aliases = {
  lua52 = "Lua 5.2",
  lua53 = "Lua 5.3"
}

local function parse_config(str)
  local entries = {}
  local names = {}
  local entry = {}
  local default = 1
  local timeout = math.huge

  for line in to_lines(str) do
    local words = to_words(line)

    if line:sub(1,2) ~= "  " then
      if words[1] == "entry" then
        entry = {}
        entries[#entries+1] = entry
        names[#names+1] = table.concat(words, " ", 2)

      elseif words[1] == "default" then
        default = tonumber(words[2]) or default

      elseif words[1] == "timeout" then
        timeout = tonumber(words[2]) or timeout
      end

    elseif words[1] == "flags" then
      entry.flags = table.pack(table.unpack(words, 2))

    elseif words[1] == "boot" then
      entry.boot = words[2]

    elseif words[1] == "arch" then
      entry.arch = arch_aliases[words[2]]

    elseif words[1] == "reboot" then
      entry.reboot = true
    end
  end

  local opt = menu("Select a boot option:", names, default, timeout)

  local selected = entries[opt]
  if selected.arch then computer.setArchitecture(selected.arch) end
  if selected.reboot then computer.shutdown(true) end

  return selected
end

local entry = parse_config(fs.read_file("/boot/cldr.cfg"))
local data = assert(fs.read_file(entry.boot))
assert(load(data, "="..entry.boot, "bt", _G))(table.unpack(entry.flags))
while true do coroutine.yield() end
