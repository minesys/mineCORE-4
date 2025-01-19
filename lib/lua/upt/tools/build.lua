-- UPT build code
-- this is not so much intended as a real library as it is a way to organize
-- UPT's code somewhat cleanly.

local checkArg = require("checkArg")
local versions = require("upt.versions")
local unistd = require("posix.unistd")
local stat = require("posix.sys.stat")
local tree = require("treeutil").tree
local meta = require("upt.meta")
local mtar = require("libmtar")
local fs = require("upt.filesystem")

local valid = {
  name = true,
  authors = true,
  version = true,
  depends = true,
  license = true,
  description = true,
  srcdir = true,
  preproc = true,
  prebuild = true,
  post = true
}

local optional = {
  depends = true,
  license = true,
  preproc = true,
  prebuild = true,
  post = true
}

local function verify_string(x)
  return type(x) == "string" and #x > 0
end

local function relative_exists(x)
  return fs.exists("./" .. x)
end

local verifiers = {
  name = verify_string,
  authors = verify_string,
  version = versions.parse,
  depends = function(x) return type(x) == "string" end,
  license = function(_) return true end,
  description = verify_string,
  srcdir = function(_) return true end,--relative_exists,
  prebuild = relative_exists,
  preproc = relative_exists,
  post = relative_exists
}

local lib = {}

function lib.verify(options)
  checkArg(1, options, "table")

  for k, v in pairs(options) do
    k, v = tostring(k), tostring(v)
    if not valid[k] then
      return nil, string.format("invalid build config key - '%s'", k)
    end

    if not verifiers[k](v) then
      return nil, string.format(
        "invalid build config value - '%s' is invalid for %s", v, k)
    end
  end

  for k in pairs(valid) do
    if not (options[k] or optional[k]) then
      return nil, string.format("missing build config key - '%s'", k)
    end
  end

  return true
end

function lib.build(options)
  local ok, verr = lib.verify(options)
  if not ok then
    return nil, verr
  end

  if options.preproc then
    fs.makeDirectory("./temp")
  end

  if options.prebuild then
    os.execute(options.prebuild)
  end

  if not relative_exists(options.srcdir) then
    return nil, "options.srcdir is invalid"
  end

  -- bundle all the files into an MTAR
  local out, err = io.open(options.name .. "-"
    .. options.version .. ".mtar", "w")
  if not out then
    return nil, err
  end

  local writer = mtar.writer(out)

  local files = tree("./" .. options.srcdir)
  for i=1, #files do
    local file = files[i]
    local base = file:sub(#options.srcdir + 3)

    if options.preproc and files[i]:sub(-4) == ".lua" then
      os.execute(options.preproc .. " " .. files[i] .. " ./temp/tmp.lua")
      file = "./temp/tmp.lua"

      local og = stat.stat(files[i])
      stat.chmod(file, og.st_mode)
      unistd.chown(file, og.st_uid, og.st_gid)
    end

    writer:add(file, fs.combine("/files/", base))
  end

  if options.post then
    local posts = tree("./" .. options.post)
    for i=1, #posts do
      local file = posts[i]
      local base = file:sub(#options.post + 3)
      writer:add(file, fs.combine("/post/", base))
    end
  end

  local pkg_mdata = meta.assemble(
    options.name, options.version, options.authors,
    options.depends or "", options.license or "", options.description)

  writer:create({
    name = "/meta",
    tags = {
      mtime = os.time(),
      -- mode r--r--r--
      mode  = stat.S_IFREG |
              stat.S_IRUSR |
              stat.S_IRGRP |
              stat.S_IROTH
      }
    }, #pkg_mdata)
  out:write(pkg_mdata)

  local size = out:seek("cur")
  local mdata = meta.assemble(
    options.name, options.version, size, options.authors,
    options.depends or "", options.license or "", options.description)

  writer:close()

  if options.preproc then
    os.execute("rm -r ./temp")
  end

  return mdata
end

return lib
