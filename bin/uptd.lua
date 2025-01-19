#!/usr/bin/env lua
-- uptd - query UPT databases

local upt = require("upt")
local arg = require("argcompat")
local sizes = require("sizes")
local getopt = require("getopt")

local options, usage, condense = getopt.build {
  { "Be verbose", false, "V", "verbose" },
  { "\tBe colorful", false, "c", "color" },
  { "\tUse 'item' as a pattern", false, "f", "fuzzy" },
  { "Alternative root filesystem", "PATH", "r", "root" },
  { "Level of detail", "LEVEL", "m", "mode" },
  { "Show UPT version", false, "v", "version" },
  { "\tDisplay this help message", false, "h", "help" }
}

local args, opts = getopt.getopt({
  options = options,
  exit_on_bad_opt = true,
  help_message = "pass '--help' for help\n"
}, arg.command("uptd", ...))

condense(opts)

require("upt.logger").setColored(opts.c)

local function showUsage()
  io.stderr:write(([[
usage: uptd <db> <query> <item>
Searches or manipulates the given UPT database.

The given database 'db' may be one of:
  i, inst, install, installed - installed packages
  l, list, package, pkglist   - all package lists
  r, repo, repository         - repository lists

The following queries are supported:
  a, c, cr, add, create - add an entry to the database.  Only supported for
                          repository lists for usability's sake.
  r, rm, remove         - remove an entry from the database
  s, sh, show           - print an entry from the database to stdout

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

if #args < 3 or opts.h then
  showUsage()
end

-- map of database aliases to database module names
local accepted = {
  i = "installed",
  inst = "installed",
  install = "installed",
  installed = "installed",
  l = "lists",
  list = "lists",
  package = "lists",
  pkglist = "lists",
  r = "repo",
  repo = "repo",
  repository = "repo"
}

-- map of command query names to database object commands
local queries = {
  a = "add", c = "add", cr = "add", add = "add", create = "add",
  r = "remove", rm = "remove", remove = "remove",
  s = "retrieve", sh = "retrieve", show = "retrieve",
}

-- data formatters for the various database modules
local formats = {
  installed = function(mode, name, version, authors, depends,
      license, repo, desc)
    if mode == 1 then
      return string.format("%s/%s %s\n  %s",
        repo, name, version, desc)
    elseif mode == 2 then
      return string.format(
        "%s/%s %s\n  %s\n  author(s): %s\n  license: %s\n  depends: %s",
        repo, name, version, desc,
        table.concat(authors, ", "), license,
        table.concat(depends, ", "))
    end
  end,

  lists = function(mode, repo, name, version, size, authors,
      depends, license, desc)
    if mode == 1 then
      return string.format("%s/%s %s\n  %s", repo, name, version, desc)
    elseif mode == 2 then
      return string.format(
        "%s/%s %s\n  %s\n  size: %s\n  author(s): %s\n" ..
        "  license: %s\n  depends: %s\n",
        repo, name, version, desc, sizes.format(size),
        table.concat(authors, ", "), license,
        table.concat(depends, ", "))
    end
  end,

  repo = function(_, db, repo, url)
    return string.format("in %s: repo %s = %s", db, repo, url)
  end,
}

if not accepted[args[1]] then
  showUsage()
end

if not queries[args[2]] then
  showUsage()
end

local database = accepted[args[1]]
local query = queries[args[2]]
local format = formats[database]
if accepted[args[1]] ~= "repo" and query == "add" then
  upt.throw("this tool does not support using 'add' on that database")
end


local db = require("upt.db." .. accepted[args[1]]).load(opts.r)

local result, err = db[query](db, args[3], opts.f)

db:close()

if not result then
  upt.throw("database query failed: " .. err)
end

if type(result) == "table" then
  for i=1, #result do
    print(format(tonumber(opts.m) or 1,
      table.unpack(result[i], 1, result[i].n)))
  end
end
