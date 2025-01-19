#!/usr/bin/env lua
-- uptb - the UPT Build Tool

local upt = require("upt")
local arg = require("argcompat")
local getopt = require("getopt")

local options, usage, condense = getopt.build {
  { "Be verbose", false, "V", "verbose" },
  { "\tBe colorful", false, "c", "color" },
  { "Show UPT version", false, "v", "version" },
  { "\tDisplay this help message", false, "h", "help" },
}

local _, opts = getopt.getopt({
  options = options,
  exit_on_bad_opt = true,
  help_message = "pass '--help' for help\n"
}, arg.command("uptb", ...))

condense(opts)

require("upt.logger").setColored(opts.c)

if opts.h then
  io.stderr:write(([[
usage: uptb [options]
Builds UPT packages according to uptbuild.conf in the current working directory.

Prints the appropriate package list entry on success.

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

local ok, err = upt.build_package(opts.V)
if not ok then
  upt.throw(err)
end
print(ok)
