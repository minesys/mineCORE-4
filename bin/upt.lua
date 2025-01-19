#!/usr/bin/env lua
-- upt - wrapper for all the UPT functionality

local upt = require("upt")
local arg = require("argcompat")
local unistd = require("posix.unistd")

local function usage() 
  io.stderr:write([[
Welcome to UPT (Universal Package Tool)!
  Usage: upt <subcommand> [options] [...]
   or: upt --help

Valid subcommands are:
  db          Query databases, like uptd
  i, install  Install packages
  u, update   Update installed packages
  r, remove   Remove packages
  g, get      Retrieve package .mtar files
  b, build    Build packages from uptbuild.conf in the current directory
  l, lists    Update a package list or lists

General options:
  -V, --verbose   Be verbose
  -c, --color     Be colorful
  -v, --version   Show UPT version
  -h, --help      Display this help message

Options and usage information specific to a given subcommand may be viewed by
passing `--help' to that subcommand.

Copyright (c) 2025 mineSYS under the GNU GPLv3.
]])
  os.exit(1)
end

local valid_commands = {
  db = true,
  i = true, install = true,
  r = true, remove = true,
  g = true, get = true,
  b = true, build = true,
  l = true, lists = true,
  u = true, update = true
}

local first = select(1, ...)

if first == "-v" or first == "--version" then
  print("UPT " .. upt._VERSION)
  os.exit(0)
end

if not valid_commands[first] then
  usage()
end

local cmdline = table.pack(select(2, ...))
cmdline[0] = "upt " .. first

-- this is nice
-- the subcommand to invoke is determined by its first letter
local cmd = "upt"..first:sub(1,1)
local ok, err = unistd.execp(cmd, cmdline)
if not ok then
  io.stderr:write("upt: ", err, "\n")
  os.exit(1)
end
