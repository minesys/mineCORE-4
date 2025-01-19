#!/usr/bin/env lua
-- uptl - update package lists

local upt = require("upt")
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
}, arg.command("uptl", ...))

condense(opts)

require("upt.logger").setColored(opts.c)

if opts.v then
  print("UPT " .. upt._VERSION)
  os.exit(0)
end

if opts.h then
  io.stderr:write(([[
usage: uptl [repo ...]
Update the package lists for one or more repositories.  If no repository is
given, uptl will update all package lists.

options:
%s

Copyright (c) 2025 mineSYS under the GNU GPLv3.
]]):format(usage))
  os.exit(1)
end

local list = require("upt.tools.list")
local ok, err = list.update(opts.r, args)
if not ok and err then
  upt.throw(err)
end
