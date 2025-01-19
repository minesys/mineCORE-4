#!/usr/bin/env lua
-- uptr - remove UPT packages

local getopt = require("getopt")
local arg = require("argcompat")
local upt = require("upt")

local options, usage, condense = getopt.build {
  { "Be verbose", false, "V", "verbose" },
  { "\tBe colorful", false, "c", "color" },
  { "Skip dependency checks (no-op)", false, "D", "nodepcheck" },
  { "Show UPT version", false, "v", "version" },
  { "\tDisplay this help message", false, "h", "help" }
}

local args, opts = getopt.getopt({
  options = options,
  exit_on_bad_opt = true,
  help_message = "pass '--help' for help\n"
}, arg.command("upti", ...))

condense(opts)

if opts.v then
  print("UPT " .. upt._VERSION)
  os.exit(0)
end

if #args == 0 or opts.h then
  io.stderr:write(([[
usage: uptr <package ...>
Removes one or more packages from the system.

options:
%s

Copyright (c) 2025 mineSYS under the GNU GPLv3.
]]):format(usage))
  os.exit(1)
end

local remover = require("upt.tools.remove")

for i=1, #args do
  local ok, err = remover.remove(args[i])
  if not ok then
    upt.throw(err)
  end
end
