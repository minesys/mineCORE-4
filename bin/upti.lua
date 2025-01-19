#!/usr/bin/env lua
-- upti - install UPT packages

local getopt = require("getopt")
local arg = require("argcompat")
local upt = require("upt")
local fs = require("upt.filesystem")

local options, usage, condense = getopt.build {
  { "Be verbose", false, "V", "verbose" },
  { "\tBe colorful", false, "c", "color" },
  { "Only do dependency checks", false, "d", "depcheck" },
  { "Assume dependencies are installed", false, "D", "nodepcheck" },
  { "Invoke 'uptl' before attempting installation", false, "l", "lists" },
  { "Alternative root filesystem", "PATH", "r", "rootfs" },
  { "Show UPT version", false, "v", "version" },
  { "\tDisplay this help message", false, "h", "help" }
}

local args, opts = getopt.getopt({
  options = options,
  exit_on_bad_opt = true,
  help_message = "pass '--help' for help\n",
}, arg.command("upti", ...))

condense(opts)

require("upt.logger").setColored(opts.c)

local function showUsage()
  io.stderr:write(([[
usage: upti <file ...>
Installs given packages.  Arguments may be repository packages or local files.

options:
%s

Copyright (c) 2025 mineSYS under the GNU GPLv3.
]]):format(usage))
  os.exit(1)
end

if opts.v then
  print("UPT " .. upt._VERSION)
  os.exit(0)
end

if opts.d and opts.D then
  return upt.throw("-d and -D are mutually exclusive")
end

if #args == 0 or opts.h then
  showUsage()
end

if opts.l then
  require("upt.tools.list").update(opts.r, {})
end

local installer = require("upt.tools.install")

for i=1, #args do
  local func
  if args[i]:sub(-5) == ".mtar" and fs.exists(args[i]) then
    func = installer.install_local
  else
    func = installer.install_repo
  end

  local result, err = func(args[i], opts.r,
      (opts.d and 1) or (opts.D and 2) or 0)

  if not result then
    return upt.throw(err)
  end

  if type(result) == "table" then
    print("package " .. args[i] .. " requires:\n  ",
      table.concat(result, "\n  "))
  end
end
