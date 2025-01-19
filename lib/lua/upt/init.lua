--- UPT's core library
--@module upt
--@alias lib

-- This module loads other submodules from the `upt.*` namespace as-needed for speed reasons, and only natively provides a few common functions.  Otherwise loading the module would be quite slow.

local logger = require("upt.logger")

local lib = {
  _VERSION = "1.0.0-beta.5"
}

function lib.throw(...)
  logger.fail(...)
  os.exit(1)
end

--- Trigger a package build.
function lib.build_package(verbose)
  local build = require("upt.tools.build")
  local config = require("upt.config")

  verbose = not not verbose

  local bconf = config.load("uptbuild.conf")
  return build.build(bconf)
end

return lib
