#!/usr/bin/env lua
-- uptl - update package lists

local upt = require("upt")
local arg = require("argcompat")
local getopt = require("getopt")
local logger = require("upt.logger")
local versions = require("upt.versions")

local options, usage, condense = getopt.build {
  { "Be verbose", false, "V", "verbose" },
  { "\tBe colorful", false, "c", "color" },
  { "Alternative root filesystem", "PATH", "r", "root" },
  { "\tAlso update package lists", false, "l", "lists" },
  {"Show UPT version", false, "v", "version" },
  {"\tDisplay this help message", false, "h", "help"}
}

local args, opts = getopt.getopt({
  options = options,
  exit_on_bad_opt = true,
  help_message = "pass '--help' for help\n"
}, arg.command("uptu", ...))

condense(opts)

logger.setColored(opts.c)

if opts.v then
  print("UPT " .. upt._VERSION)
  os.exit(0)
end

if opts.h then
  io.stderr:write(([[
usage: uptu [repo ...]
Updates all installed packages.

options:
%s

Copyright (c) 2025 mineSYS under the GNU GPLv3.
]]):format(usage))
  os.exit(1)
end

if opts.l then
  logger.ok("Updating package lists")
  local list = require("upt.tools.list")
  local ok, err = list.update(opts.r, args)
  if not ok and err then
    upt.throw(err)
  end
end

local installed = require("upt.db.installed").load(opts.r)
local results, err = installed:retrieve(".+", true)
installed:close()

if not results then
  upt.throw("database query failed: " .. err)
end

local lists = require("upt.db.lists").load(opts.r)
local packages = {}
for i=1, #results do
  local name, ver = results[i][1], results[i][2]
  local entry = lists:retrieve(name, false)
  if not entry then
    logger.warn(
      "package '"..name.."' is not in the package registry - skipping")
  else
    local newver = entry[1][3]
    if versions.compare(versions.parse(newver), versions.parse(ver)) then
      packages[#packages+1] = name
    end
  end
end
lists:close()

local installer = require("upt.tools.install")
for i=1, #packages do
  installer.install_repo(packages[i], opts.r, 2)
end
