#!/usr/bin/env lua
-- uptg - download packages

local upt = require("upt")
local get = require("upt.tools.get")

local fs = require("upt.filesystem")
local arg = require("argcompat")
local getopt = require("getopt")

local options, usage, condense = getopt.build {
  { "Be verbose", false, "V", "verbose" },
  { "\tBe colorful", false, "c", "color" },
  { "Alternative root filesystem", "PATH", "r", "root" },
  {"Show UPT version", false, "v", "version" },
  {"\tDisplay this help message", false, "h", "help"}
}

local args, opts = getopt.getopt({
  options = options,
  exit_on_bad_opt = true,
  help_message = "pass '--help' for help\n"
}, arg.command("uptg", ...))

condense(opts)

require("upt.logger").setColored(opts.c)

if opts.v then
  print("UPT " .. upt._VERSION)
  os.exit(0)
end

if #args == 0 or opts.h then
  io.stderr:write(([[
usage: uptg <pkgname> [dest]
Downloads the given package.  If DEST is provided and points to a folder, uptg
will place the downloaded archive there;  DEST defaults to the current working
directory.

options:
%s

Copyright (c) 2025 mineSYS under the GNU GPLv3.
]]):format(usage))
  os.exit(1)
end

local dest

if args[2] then
  if fs.isDirectory(args[2]) then
    dest = args[2]
  else
    upt.throw(args[2] .. ": not a directory")
  end
end

local ok, err = get.get(args[1], dest, opts.r)
if not ok then upt.throw(err) end
