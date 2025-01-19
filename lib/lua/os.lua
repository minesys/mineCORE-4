-- os library bits

local sys = require("syscalls")
local checkArg = require("checkArg")

function os.getenv(k)
  checkArg(1, k, "string")
  return sys.environ()[k]
end

function os.exit(n)
  checkArg(1, n, "number", "nil")
  sys.exit(n or 0)
end

-- TODO: support more shells, maybe?
function os.execute(cmd)
  checkArg(1, cmd, "string", "nil")

  if not cmd then
    return not not sys.stat("/bin/sh.lua")

  else
    local pid = sys.fork(function()
      sys.execve("/bin/sh.lua", {[0]="sh", "-c", cmd})
    end)

    local status, exit = sys.wait(pid)
    return exit == 0, status, exit
  end
end

function os.remove(file)
  checkArg(1, file, "string")

  os.execute("rm " .. file)
end
