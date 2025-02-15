--!lua

local argv = table.pack(...)
if type(argv[1]) == "table" then argv = argv[1] end
argv[0] = argv[0] or "ls"

local permissions = require("permissions")
local dirent = require("posix.dirent")
local unistd = require("posix.unistd")
local sizes = require("sizes")
local errno = require("posix.errno")
local stat = require("posix.sys.stat")
local pwd = require("posix.pwd")
local grp = require("posix.grp")

local args, opts = require("getopt").getopt({
  options = {
    help = false,
    a = false, all = false,
    A = false, ["almost-all"] = false,
    nocolor = false, color = false,
    d = false, directory = false,
    f = false, G = false, h = false,
    ["human-readable"] = false,
    si = false, hide = true,
    i = false, inode = false,
    l = false,
    n = false, ["numeric-uid-gid"] = false,
    r = false, reverse = false,
    S = false, U = false,
    ["1"] = false,
  },
  exit_on_bad_opt = true,
  help_message = "see '" .. argv[0] .. " --help' for more information\n",
}, argv)

-- make it so, for the most part, we only have to index short options
opts.a = opts.a or opts.all
opts.A = opts.A or opts["almost-all"]
opts.d = opts.d or opts.directory
opts.f = opts.f or opts.U
opts.h = opts.h or opts["human-readable"]
opts.i = opts.i or opts.inode
opts.n = opts.n or opts["numeric-uid-gid"]
opts.r = opts.r or opts.reverse
opts.one = opts["1"]
if not opts.color then opts.nocolor = unistd.isatty(1) ~= 1 end

if opts.help then
  io.stderr:write(([[
usage: %s [OPTION]... [FILE]...
List information about FILEs.  If no FILEs are specified, defaults to the
current directory.  Sorts entries alphabetically if none of -frU is specified.

If a long option requires an argument, then so does its short form.
  -a, --all             Do not omit entries beginning with a .
  -A, --almost-all      Like -a, but omit the implied . and ..
  -d, --directory       Show information about directories rather than listing
                        their contents
  -f                    Do not sort entries
  -h, --human-readable  Print human-readable sizes
      --si              Use 1000, not 1024, as the base for sizes
      --hide=PATTERN    Omit entries matching Lua pattern PATTERN (overridden
                        by -a or -A)
  -i, --inode           Show inode number of each file (with -l)
  -l                    Show various information about each file
  -n, --numeric-uid-gid Use numeric UID and GID
      --nocolor         Do not color output
      --color           Always color output
  -r, --reverse         Reverse-sort entries before listing
  -U                    Same as -f
  -1                    One file per line
      --help            Print this help message

Copyright (c) 2025 mineSYS under the GNU GPLv3.
]]):format(argv[0]))
  os.exit(0)
end

local width = require("termio").getTermSize()

args[1] = args[1] or "."

local colors = {
  ["-"] = 37,
  d = 94,
  e = 92,
  c = 93,
  b = 93,
  f = 93,
  l = 36,
  ["?"] = 91,
}

-- executable permissions bitmap
local exec = permissions.strtobmp("--x--x--x")

local totalx = 0
local function list(base, file, pad)
  pad = pad or 0

  local sx, eno = stat.lstat(base..(file and ("/"..file) or ""))
  file = file or base
  if not sx then
    io.stderr:write(argv[0], ": ", file, ": ", errno.errno(eno), "\n")
    os.exit(1)
  end

  local color = 37
  local ftc = "-"

  if not opts.nocolor then
    if stat.S_ISREG(sx.st_mode) ~= 0 and (sx.st_mode & exec) ~= 0 then
      color = colors.e

    else
      ftc = (stat.S_ISDIR(sx.st_mode) ~= 0 and "d"
        or stat.S_ISREG(sx.st_mode) ~= 0 and "-"
        or stat.S_ISCHR(sx.st_mode) ~= 0 and "c"
        or stat.S_ISBLK(sx.st_mode) ~= 0 and "b"
        or stat.S_ISLNK(sx.st_mode) ~= 0 and "l"
        or stat.S_ISFIFO(sx.st_mode) ~= 0 and "f"
        or "?")
      color = colors[ftc]
    end
  end

  local line = ""
  if opts.l then
    local uinfo = pwd.getpwuid(sx.st_uid)
    local ginfo = grp.getgrgid(sx.st_gid)
    local uname, ugroup

    if uinfo then uname = uinfo.pw_name end
    if ginfo then ugroup = ginfo.gr_name end

    line = line .. string.format("%s%s%s %d %s %s\t%5s\t%s ",
      -- inode
      opts.i and string.format("%d\t", sx.st_ino) or "",
      -- filetype char, e.g. "-" "d" "c" "b"
      ftc,
      -- permissions
      permissions.bmptostr(sx.st_mode),
      -- how many links?
      sx.st_nlink,
      -- owner
      uname or sx.st_uid,
      -- group
      ugroup or sx.st_gid,
      -- size
      opts.h and (opts.si and sizes.format10 or sizes.format)(sx.st_size)
        or math.floor(sx.st_size),
      -- last modified
      os.date("%Y-%m-%d %H:%M:%S", math.floor(sx.st_mtime / 1000)))
  end

  if totalx + #file >= width and not (opts.l or opts.one) then
    line = line .. "\n"
    totalx = 0
  end

  totalx = totalx + #file
  if totalx >= width and line:sub(-1) ~= "\n" and not (opts.l or opts.one) then
    line = line .. "\n"
    totalx = 0
  end

  line = line .. string.format("\27[%dm%s\27[37m", color, file)
  if opts.l or opts.one then
    line = line .. "\n"

  else
    totalx = totalx + pad - #file
    if totalx >= width then
      line = line .. "\n"
      totalx = 0

    else
      line = line .. (" "):rep(pad - #file)
    end
  end

  return line
end

for i=1, #args, 1 do
  if #args > 1 and not opts.l then print(args[i]..":") end
  local statx, eno = stat.lstat(args[i])

  if not statx then
    io.stderr:write(argv[0], ": ", eno, "\n")
    os.exit(1)

  elseif stat.S_ISDIR(statx.st_mode) == 0 or opts.d then
    io.write(list(args[i]))
    if i==#args and not opts.l then totalx=totalx+#args[i] end

  else
    local files = {}
    if opts.a and not opts.A then
      files[1] = "."
      files[2] = ".."
    end

    for file in dirent.files(args[i]) do
      if (file:sub(1,1) ~= "." and not (opts.hide and file:match(opts.hide)))
          or opts.a then
        files[#files+1] = file
      end
    end

    local maxwidth = 0
    for j=1, #files, 1 do
      maxwidth = math.max(maxwidth, #files[j]+2)
    end

    if not opts.f then
      if opts.r then
        table.sort(files, function(a, b) return b < a end)

      else
        table.sort(files)
      end
    end

    for _, file in ipairs(files) do
      io.write(list(args[i], file, maxwidth))
    end
  end

  io.write("\27[39;49m")
  if (i < #args or totalx > 0) and not opts.l then io.write("\n") end
  totalx = 0
end

