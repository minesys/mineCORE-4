--!lua

local sys = require("syscalls")
local errno = require("posix.errno")

local options, usage, condense = require("getopt").build {
  { "\t\tClear the kernel ring buffer",       false,  "C", "clear" },
  { "\tPrint, then clear, the ring buffer",   false,  "c", "read-clear" },
  { "Set the console log level",              "LEVEL","n", "console-level" },
  { "\tEnable logging to the console",        false,  "E", "console-on" },
  { "\tDisable logging to the console",       false,  "D", "console-off" },
  { "\tFollow until interrupted",             false,  "w", "follow"},
  { "\tLike -w, but prints only new messages",false,  "W", "follow-new"},
  { "\t\tShow this help message",             false,  "h", "help" },
}

local _, opts = require("getopt").getopt({
  options = options,
  exit_on_bad_opt = true,
  help_message = "pass '--help' for help\n"
}, ...)

condense(opts)

local function showusage()
  io.stderr:write(string.format([[
usage: dmesg [options]

options:
%s

Options are mutually exclusive.

Copyright (c) 2025 mineSYS under the GNU GPLv3.
]], usage))
  os.exit(1)
end

if opts.h or (opts.n and not tonumber(opts.n)) then
  showusage()
end

local nsel = 0 + (opts.C and 1 or 0) + (opts.c and 1 or 0) +
  (opts.n and 1 or 0) + (opts.E and 1 or 0) + (opts.D and 1 or 0)

if nsel > 1 then showusage() end
if nsel == 0 then opts.c = true end

local function do_syslog(...)
  local res, err = sys.klogctl(...)
  if not res then
    io.stderr:write(string.format("dmesg: %s\n", errno.errno(err)))
    os.exit(1)
  end

  if type(res) == "table" then
    for i=1, #res, 1 do
      print(res[i])
    end
  end
end

if opts.C then
  do_syslog("clear")

elseif opts.c then
  do_syslog("read_clear")

elseif opts.n then
  do_syslog("console_level", tonumber(opts.n))

elseif opts.E then
  do_syslog("console_on")

elseif opts.D then
  do_syslog("console_off")

elseif opts.w or opts.W then
  if opts.W then
    do_syslog("clear")
  end

  while true do
    do_syslog("read")
  end
end
