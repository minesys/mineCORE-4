--
local k = {}
do
k.cmdline = {}
local _args = table.pack(...)
k.original_cmdline = table.concat(_args, " ", 1, _args.n)
for _, arg in ipairs(_args) do
local key, val = arg, true
if arg:find("=") then
key, val = arg:match("^(.-)=(.+)$")
if val == "true" then val = true
elseif val == "false" then val = false
else val = tonumber(val) or val end
end
local ksegs = {}
for ent in key:gmatch("[^%.]+") do
ksegs[#ksegs+1] = ent
end
local cur = k.cmdline
for i=1, #ksegs-1, 1 do
k.cmdline[ksegs[i]] = k.cmdline[ksegs[i]] or {}
cur = k.cmdline[ksegs[i]]
end
cur[ksegs[#ksegs]] = val
end
end
do  local gpu, screen
for addr in component.list("gpu") do
screen = component.invoke(addr, "getScreen")
if screen then
gpu = component.proxy(addr)
break
end
end
if not gpu then
gpu = component.list("gpu")()
screen = component.list("screen")()
end
if gpu then
if type(gpu) == "string" then gpu = component.proxy(gpu) end
gpu.bind(screen)
local w, h = gpu.getResolution()
gpu.fill(1, 1, w, h, " ")
local current_line = 0
function k.log_to_screen(lines)
lines = lines:gsub("\t", "  ")
for message in lines:gmatch("[^\n]+") do
while #message > 0 do
local line = message:sub(1, w)
message = message:sub(#line + 1)
current_line = current_line + 1
if current_line > h then
gpu.copy(1, 1, w, h, 0, -1)
gpu.fill(1, h, w, 1, " ")
end
gpu.set(1, current_line, line)
end
end
end
else
k.log_to_screen = function() end
end  local log_buffer = {}
k.log_buffer = log_buffer
local sandbox = component.list("sandbox")()
local function log_to_buffer(message)
log_buffer[#log_buffer + 1] = message
if sandbox then component.invoke(sandbox, "log", message) end
if #log_buffer > computer.totalMemory() / 1024 then
table.remove(log_buffer, 1)
end
end
k.L_SYSTEM  = -1
k.L_EMERG   = 0
k.L_ALERT   = 1
k.L_CRIT    = 2
k.L_ERROR   = 3
k.L_WARNING = 4
k.L_NOTICE  = 5
k.L_INFO    = 6
k.L_DEBUG   = 7
k.cmdline.loglevel = tonumber(k.cmdline.loglevel) or 8
local reverse = {}
for name,v in pairs(k) do
if name:sub(1,2) == "L_" then
reverse[v] = name:sub(3)
end
end  function _G.printk(level, fmt, ...)
local message = string.format("[%08.02f] %s: ", computer.uptime(),
reverse[level]) .. string.format(fmt, ...)
if level <= k.cmdline.loglevel then
k.log_to_screen(message)
end
log_to_buffer(message)
end
local pullSignal = computer.pullSignal  function _G.panic(reason)
printk(k.L_EMERG, "#### stack traceback ####")
for line in debug.traceback():gmatch("[^\n]+") do
if line ~= "stack traceback:" then
printk(k.L_EMERG, "%s", line)
end
end
printk(k.L_EMERG, "#### end traceback ####")
printk(k.L_EMERG, "kernel panic - not syncing: %s", reason)
while true do pullSignal() end
end
end
printk(k.L_INFO, "checkArg")
do
function _G.checkArg(n, have, ...)
have = type(have)
local function check(want, ...)
if not want then
return false
else
return have == want or check(...)
end
end
if type(n) == "number" then n = string.format("#%d", n)
else n = "'"..tostring(n).."'" end
if not check(...) then
local name = debug.getinfo(3, 'n').name
local msg
if name then
msg = string.format("bad argument %s to '%s' (%s expected, got %s)",
n, name, table.concat(table.pack(...), " or "), have)
else
msg = string.format("bad argument %s (%s expected, got %s)", n,
table.concat(table.pack(...), " or "), have)
end
error(debug.traceback(msg, 2), 2)
end
end
end
printk(k.L_INFO, "errno")
do
k.errno = {
EPERM = 1,
ENOENT = 2,
ESRCH = 3,
ENOEXEC = 8,
EBADF = 9,
ECHILD = 10,
EACCES = 13,
ENOTBLK = 15,
EBUSY = 16,
EEXIST = 17,
EXDEV = 18,
ENODEV = 19,
ENOTDIR = 20,
EISDIR = 21,
EINVAL = 22,
ENOTTY = 25,
ENOSYS = 38,
ENOTEMPTY = 39,
ELOOP = 40,
EUNATCH = 49,
ELIBEXEC = 83,
ENOPROTOOPT = 92,
ENOTSUP = 95,
}
end--
printk(k.L_INFO, "buffer")
do  local bufsize = tonumber(k.cmdline["io.bufsize"])
or tonumber("1024")
local buffer = {}
local buffers = {}  function buffer:readline()    if self.bufmode == "none" then      if self.stream.readline then
return self.stream:readline()
else        local dat = ""
repeat
local n = self.stream:read(1)
dat = dat .. (n or "")
until n == "\n" or not n
if #dat == 0 then return nil end
return dat
end
else      while not self.rbuf:match("\n") do
local chunk = self.stream:read(bufsize)
if not chunk then break end
self.rbuf = self.rbuf .. chunk
end
if #self.rbuf == 0 then return nil end      local n = self.rbuf:find("\n") or #self.rbuf
local dat = self.rbuf:sub(1, n)
self.rbuf = self.rbuf:sub(n + 1)
return dat
end
end  function buffer:readnum()
local dat = ""
if self.bufmode == "none" then      error(
"bad argument to 'read' (format 'n' not supported in unbuffered mode)",
0)
end    local breakonwhitespace = false
while true do
local ch = self:readn(1)
if not ch then        break
end
if ch:match("[%s]") then        if breakonwhitespace then          self.rbuf = ch .. self.rbuf
break
end
else        breakonwhitespace = true        if not tonumber(dat .. ch .. "0") then
self.rbuf = ch .. self.rbuf
break
end
dat = dat .. ch
end
end    return tonumber(dat)
end  function buffer:readn(n)    while #self.rbuf < n do
local chunk = self.stream:read(n - #self.rbuf)      if not chunk then        if #self.rbuf == 0 then return nil end
break
end      self.rbuf = self.rbuf .. chunk
end    n = math.min(n, #self.rbuf)    local data = self.rbuf:sub(1, n)
self.rbuf = self.rbuf:sub(#data + 1)    return data
end
function buffer:readfmt(fmt)
if type(fmt) == "number" then      return self:readn(fmt)
else      fmt = fmt:gsub("%*", "")
if fmt == "a" then        return self:readn(math.huge)
elseif fmt == "l" then        local line = self:readline()
if not line then return nil end
return line:gsub("\n$", "")
elseif fmt == "L" then        return self:readline()
elseif fmt == "n" then        return self:readnum()
else        error("bad argument to 'read' (format '"..fmt.."' not supported)", 0)
end
end
end
local function chvarargs(...)
local args = table.pack(...)
for i=1, args.n, 1 do
checkArg(i, args[i], "string", "number")
end
return args
end
function buffer:read(...)
local args = chvarargs(...)
local ret = {}
for i=1, args.n, 1 do
ret[#ret+1] = self:readfmt(args[i])
end
return table.unpack(ret, 1, args.n)
end
function buffer:write(...)
local args = chvarargs(...)
for i=1, args.n, 1 do
self.wbuf = self.wbuf .. tostring(args[i])
end
local dat
if self.bufmode == "full" then      if #self.wbuf <= bufsize then
return self
end
dat = self.wbuf
self.wbuf = ""
elseif self.bufmode == "line" then      local lastnl = #self.wbuf - (self.wbuf:reverse():find("\n") or 0)
dat = self.wbuf:sub(1, lastnl)
self.wbuf = self.wbuf:sub(lastnl + 1)
else      dat = self.wbuf
self.wbuf = ""
end    self.stream:write(dat)
return self
end
function buffer:seek(whence, offset)
checkArg(1, whence, "string", "nil")
checkArg(2, offset, "number", "nil")
self:flush()
if self.stream.seek then
return self.stream:seek(whence or "cur", offset or 0)
end
return nil, k.errno.EBADF
end
function buffer:flush()
if #self.wbuf > 0 then
self.stream:write(self.wbuf)
self.wbuf = ""
end
if self.stream.flush then
self.stream:flush()
end
return true
end
function buffer:close()
self.closed = true
buffers[self] = nil
if self.stream.close then
self.stream:close()
end
end
local modes = { full = true, line = true, none = true }
function buffer:ioctl(op, mode, ...)
checkArg(1, op, "string")
if op ~= "setvbuf" or (self.stream.proxy
and self.stream.proxy.override_setvbuf) then
if self.stream.proxy and self.stream.proxy.ioctl then
return self.stream.proxy.ioctl(self.stream.fd, op, mode, ...)
elseif self.stream.ioctl then
return self.stream.ioctl(self.stream, op, mode, ...)
else
return nil, k.errno.ENOSYS
end
end
checkArg(2, mode, "string")
if not modes[mode] then return nil, k.errno.EINVAL end
self.bufmode = mode
return true
end
local function split_chars(s)
local cs = {}
for c in s:gmatch(".") do cs[c] = true end
return cs
end
function k.buffer_from_stream(stream, mode)
checkArg(1, stream, "table")
checkArg(2, mode, "string")
local buf = setmetatable({
stream = stream,
mode = split_chars(mode),
rbuf = "",
wbuf = "",
bufmode = stream.proxy and stream.proxy.override_setvbuf
and "none" or "full"
}, {__index = buffer})
buffers[buf] = true
return buf
end
function k.sync_buffers()
for buffer in pairs(buffers) do
buffer:flush()
end
end
end
printk(k.L_INFO, "filedesc")
do
local function fread(self, n)
if not self.proxy.read then return nil, k.errno.ENOTSUP end
return self.proxy:read(self.fd, n)
end
local function fwrite(self, d)
if not self.proxy.write then return nil, k.errno.ENOTSUP end
return self.proxy:write(self.fd, d)
end
local function fseek(self, w, o)
if not self.proxy.seek then return nil, k.errno.ENOTSUP end
return self.proxy:seek(self.fd, w, o)
end

local function fflush(self)
if not self.proxy.flush then return nil, k.errno.ENOTSUP end
return self.proxy:flush(self.fd)
end
local function fclose(self)
if not self.proxy.close then return nil, k.errno.ENOTSUP end
return self.proxy:close(self.fd)
end  function k.fd_from_node(proxy, fd, mode)
checkArg(1, proxy, "table")    checkArg(2, fd, "table", "userdata")
checkArg(3, mode, "string")
local new = k.buffer_from_stream({
read = fread, write = fwrite, seek = fseek,
flush = fflush, close = fclose,
fd = fd, proxy = proxy
}, mode)
return new
end
local function ebadf()
return nil, k.errno.EBADF
end  function k.fd_from_rwf(read, write, close)
checkArg(1, read, "function", write and "nil")
checkArg(2, write, "function", read and "nil")
checkArg(3, close, "function", "nil")
return {
read = read or ebadf, write = write or ebadf,
close = close or function() end
}
end
end
printk(k.L_INFO, "signals")
do
local handlers = {}
function k.add_signal_handler(name, callback)
checkArg(1, name, "string")
checkArg(2, callback, "function")
local id
repeat id = math.random(100000, 999999) until not handlers[id]
handlers[id] = {signal = name, callback = callback}
return id
end
function k.remove_signal_handler(id)
checkArg(1, id, "number")
local success = not not handlers[id]
handlers[id] = nil
return success
end
local pullsignal = computer.pullSignal
local pushsignal = computer.pushSignal
function k.handle_signal(sig)
for id, handler in pairs(handlers) do
if handler.signal == sig[1] then
local success, err = pcall(handler.callback,
table.unpack(sig, 1, sig.n))
if not success and err then
printk(k.L_WARNING,
"error in signal handler %d while handling signal %s: %s", id,
sig[1], err)
end
end
end
end
local push_blacklist = {}
function k.blacklist_signal(signal)
checkArg(1, signal, "string")
push_blacklist[signal] = true
return true
end
function k.pushSignal(sig, ...)
assert(sig ~= nil,
"bad argument #1 to 'pushSignal' (value expected, got nil)")
if push_blacklist[sig] then
return nil, k.errno.EACCES
end
pushsignal(sig, ...)
return true
end
function k.pullSignal(timeout)
local sig = table.pack(pullsignal(timeout))
if sig.n == 0 then return end
k.handle_signal(sig)
return table.unpack(sig, 1, sig.n)
end
end
printk(k.L_INFO, "shutdown")
do
k.blacklist_signal("shutdown")
function k.shutdown()
k.handle_signal { "shutdown" }
end
end--
printk(k.L_INFO, "scheduler/thread")
do  local sysyield_string = ""
for i=1, math.random(3, 5), 1 do
sysyield_string = sysyield_string .. string.format("%02x",
math.random(0, 255))
end
local function rand_char()
local area = math.random(1, 3)
if area == 1 then      return string.char(math.random(48, 57))
elseif area == 2 then      return string.char(math.random(65, 90))
elseif area == 3 then      return string.char(math.random(97, 122))
end
end  for i=1, math.random(3, 5), 1 do
sysyield_string = sysyield_string .. rand_char()
end
k.sysyield_string = sysyield_string  local thread = {}
function thread:resume(sig, ...)
if sig and #self.queue < 256 then
table.insert(self.queue, table.pack(sig, ...))
end
local resume_args    if self.status == "w" then
if computer.uptime() <= self.deadline and #self.queue == 0 then return end
if #self.queue > 0 then
resume_args = table.remove(self.queue, 1)
end    elseif self.status == "s" then
return false
end
local result
self.status = "r"
if resume_args then
result = table.pack(coroutine.resume(self.coro, table.unpack(resume_args,
1, resume_args.n)))
else
result = table.pack(coroutine.resume(self.coro))
end    if type(result[1]) == "boolean" then
table.remove(result, 1)
result.n = result.n - 1
end
if coroutine.status(self.coro) == "dead" then
if k.cmdline.log_process_deaths then
printk(k.L_DEBUG, "thread died: %s", result[1])
end
return 1
end    if result[1] == sysyield_string then
self.status = "y"
elseif result.n == 0 then
self.deadline = math.huge
self.status = "w"
elseif type(result[1]) == "number" then
self.deadline = computer.uptime() + result[1]
self.status = "w"
else
self.deadline = math.huge
self.status = "w"
end    return true
end
local thread_mt = { __index = thread }  function k.thread_from_function(func)
checkArg(1, func, "function")
return setmetatable({
coro = coroutine.create(func),
queue = {},
status = "w",
deadline = 0,    }, thread_mt)
end
end
printk(k.L_INFO, "scheduler/process")
do
local sigtonum = {
SIGEXIST  = 0,
SIGHUP    = 1,
SIGINT    = 2,
SIGQUIT   = 3,
SIGKILL   = 9,
SIGPIPE   = 13,
SIGTERM   = 15,
SIGCHLD   = 17,
SIGCONT   = 18,
SIGSTOP   = 19,
SIGTSTP   = 20,
SIGTTIN   = 21,
SIGTTOU   = 22
}
k.sigtonum = {}
for key,v in pairs(sigtonum) do
k.sigtonum[key] = v
k.sigtonum[v] = key
end  k.default_signal_handlers = setmetatable({
SIGTSTP = function(p)
p.stopped = true
end,
SIGSTOP = function(p)
p.stopped = true
end,
SIGCONT = function(p)
p.stopped = false
end,
SIGTTIN = function(p)
printk(k.L_DEBUG, "process %d (%s) got SIGTTIN", p.pid, p.cmdline[0])
p.stopped = true
end,
SIGTTOU = function(p)
printk(k.L_DEBUG, "process %d (%s) got SIGTTOU", p.pid, p.cmdline[0])
p.stopped = true
end}, {__index = function(t, sig)
t[sig] = function(p)
p.threads = {}
p.thread_count = 0
end
return t[sig]
end})  local process = {}
local default = {n = 0}
function process:resume(sig, ...)    while #self.sigqueue > 0 do
local psig = table.remove(self.sigqueue, 1)
if sigtonum[psig] then
self.status = sigtonum[psig]
self:signal(psig)
end
end
if self.stopped then return end
sig = table.pack(sig, ...)
local resumed = false
if sig and #sig > 0 and #self.queue < 256 then
self.queue[#self.queue + 1] = sig
end
local signal = default
if #self.queue > 0 then
signal = table.remove(self.queue, 1)
elseif self:deadline() > computer.uptime() then
return
end
for i, thread in pairs(self.threads) do
self.current_thread = i
local result = thread:resume(table.unpack(signal, 1, signal.n))
resumed = resumed or not not result
if result == 1 then
self.threads[i] = nil
self.thread_count = self.thread_count - 1
table.insert(self.queue, {"thread_died", i})
end
end
return resumed
end
function process:add_thread(thread)
self.threads[self.pid + self.thread_count] = thread
self.thread_count = self.thread_count + 1
end
function process:deadline()
local deadline = math.huge
for _, thread in pairs(self.threads) do
if thread.deadline < deadline then
deadline = thread.deadline
end
if thread.status == "y" then
return -1
end
if thread.status == "w" and #self.queue > 0 then
return -1
end
end
return deadline
end
function process:signal(sig, imm)
if self.signal_handlers[sig] then
printk(k.L_DEBUG, "%d: using custom signal handler for %s", self.pid, sig)
pcall(self.signal_handlers[sig], sigtonum[sig])
else
printk(k.L_DEBUG, "%d: using default signal handler for %s", self.pid, sig)
pcall(k.default_signal_handlers[sig], self)
end
if self.thread_count == 0 then
self.reason = "signal"
end
if imm and (self.stopped or self.thread_count == 0) then
coroutine.yield(0)
end
end
local process_mt = { __index = process }
local default_parent = {handles = {}, _G = {}, pid = 0,
environ = {TERM = "cynosure-2"}}
local function t(T) return type(T) == "table" end  local function istty(T)
return T and T.fd and t(T.fd.stream) and T.fd.stream.fd and
T.fd.stream.fd.fd and T.fd.stream.fd.fd.fd
end
function k.create_process(pid, parent)
parent = parent or default_parent
local new = setmetatable({      queue = {},      stopped = false,      threads = {},      thread_count = 0,      current_thread = 0,      cmdline = {[0]=parent.cmdline and parent.cmdline[0] or "nil"},      status = 0,      reason = "exit",      pid = pid,      ppid = parent.pid,      pgid = parent.pgid or 0,      sid = parent.sid or 0,      uid = parent.uid or 0,      gid = parent.gid or 0,      euid = parent.euid or 0,
egid = parent.egid or 0,      suid = parent.uid or 0,
sgid = parent.gid or 0,      cwd = parent.cwd or "/",      root = parent.root or "/",      fds = {},      handlers = {},      signal_handlers = {},      sigqueue = {},      env = k.create_env(parent.env),
umask = parent.umask or 0,      environ = setmetatable({}, {__index=parent.environ,
__pairs = function(tab)
local t = {}
for k, v in pairs(parent.environ) do
t[k] = v
end
for k,v in next, tab, nil do
t[k] = v
end
return next, t, nil
end, __metatable = {}})
}, process_mt)    if parent.fds then
for k, v in pairs(parent.fds) do
new.fds[k] = v
v.refs = v.refs + 1
end
end
local e, o, i = new.fds[0], new.fds[1], new.fds[2]
new.tty = istty(i) or istty(o) or istty(e)
return new
end
end
printk(k.L_INFO, "scheduler/loop")
do
local processes = {}
local pid = 0
local current = 0  function k.is_sid(id)
return not not (processes[id] and processes[id].sid == id)
end  function k.is_pgroup(id)
return not not (processes[id] and processes[id].pgid == id)
end  function k.pgroup_pids(id)
local result = {}
if not k.is_pgroup(id) then return result end
for pid, proc in pairs(processes) do
if proc.pgid == id then
result[#result+1] = pid
end
end
return result
end  function k.pgroup_sid(id)
if k.is_pgroup(id) then
return processes[id].sid
end
return 0
end
function collectgarbage()
local missed = {}
for i=1, 10, 1 do
local sig = table.pack(computer.pullSignal(0.05))
if sig.n > 0 then missed[#missed+1] = sig end
end
for i=1, #missed, 1 do
computer.pushSignal(table.unpack(missed[i], 1, missed[i].n))
end
end
local default = {n=0}
function k.scheduler_loop()
local last_yield = 0
while processes[1] do
local deadline = math.huge
for _, process in pairs(processes) do
local proc_deadline = process:deadline()
if proc_deadline < deadline then
deadline = proc_deadline
if deadline < 0 then break end
end
end
local signal = default
if deadline < 0 then
if computer.uptime() - last_yield > 4 then
last_yield = computer.uptime()
signal = table.pack(k.pullSignal(0))
end
else
last_yield = computer.uptime()
signal = table.pack(k.pullSignal(deadline - computer.uptime()))
end
for cpid, process in pairs(processes) do
if not process.is_dead then
current = cpid
local stop = process.stopped
if computer.uptime() >= process:deadline() or #signal > 0 then
process:resume(table.unpack(signal, 1, signal.n))
if not next(process.threads) then
process.is_dead = true              for _, fd in pairs(process.fds) do
k.close(fd)
end              for id in pairs(process.handlers) do
k.remove_signal_handler(id)
end
if cpid > 1 then                table.insert(processes[process.ppid].queue, {"proc_dead", cpid})
else
processes[cpid] = nil
end
end
end
if stop ~= process.stopped and cpid > 1 then            table.insert(processes[process.ppid].queue, {"proc_stopped", cpid})
end
else
if not processes[process.ppid] then
process.ppid = 1
end
end
end      if computer.freeMemory() < 1024 then
printk(k.L_DEBUG, "low free memory - collecting garbage")
collectgarbage()
end
end
end
function k.add_process()
pid = pid + 1
processes[pid] = k.create_process(pid, processes[current])
return pid
end
local default_proc = { uid = 0, gid = 0, euid = 0, egid = 0 }
function k.current_process()
return processes[current] or default_proc
end
function k.get_process(rpid)
checkArg(1, rpid, "number")
return processes[rpid]
end
function k.remove_process(pid)
checkArg(1, pid, "number")
processes[pid] = nil
return true
end
function k.get_pids()
local procs = {}
for ppid in pairs(processes) do
procs[#procs + 1] = ppid
end
return procs
end
end
printk(k.L_INFO, "scheduler/preempt")
do
local sys = "a"..k.sysyield_string
local patterns = {    { "([%);\n ])do([ \n%(])", "%1do%2"..sys.."() "},
{ "([%);\n ])repeat([ \n%(])", "%1repeat%2"..sys.."() " },    { "function ([a-zA-Z0-9_]+ *%([^)]*%))", "function %1"..sys.."()" },
{ "function( *%([^)]*%))", "function %1"..sys.."()" },    { "::([a-zA-Z0-9_])::", "::%1::"..sys.."()" }
}
local template = ("local %s = ...;return function(...)")
:format(sys, sys, sys)
local function gsub(s)
for i=1, #patterns, 1 do
s = s:gsub(patterns[i][1], patterns[i][2])
end
return s
end
local last_yield = computer.uptime()
function k._yield()
if computer.uptime() - last_yield > 4 then
last_yield = computer.uptime()
k.pullSignal(0)
end
end
local function wrap(code)
local wrapped = template
local in_str = false
while #code > 0 do
local next_quote = math.min(code:find('"', nil, true) or math.huge,
code:find("'", nil, true) or math.huge,
code:find("[", nil, true) or math.huge)
if next_quote == math.huge then
wrapped = wrapped .. gsub(code)
break
end
k._yield()
local chunk, quote = code:sub(1, next_quote-1),
code:sub(next_quote, next_quote)
if not quote then
wrapped = wrapped .. gsub(code)
break
end
code = code:sub(#chunk + 2)
if quote == '"' or quote == "'" then
if in_str == quote then
in_str = false
wrapped = wrapped .. chunk .. quote
elseif not in_str then
in_str = quote
wrapped = wrapped .. gsub(chunk) .. quote
else
wrapped = wrapped .. gsub(chunk) .. quote
end
elseif quote == "[" then
local prefix = "%]"
if code:sub(1,1) == "[" then
prefix = "%]%]"
code = code:sub(2)
wrapped = wrapped .. gsub(chunk) .. quote .. "["
elseif code:sub(1,1) == "=" then
local pch = code:find("(=-%[)")
if not pch then            return wrapped .. chunk .. quote .. code
end
local e = code:sub(1, pch)
prefix = prefix .. e .. "%]"
code = code:sub(pch+#e+1)
wrapped = wrapped .. gsub(chunk) .. "[" .. e .. "["
else
wrapped = wrapped .. gsub(chunk) .. quote
end
if #prefix > 2 then
local strend = code:match(".-"..prefix)
code = code:sub(#strend+1)
wrapped = wrapped .. strend
end
end
end
return wrapped .. ";end"
end
local function sysyield()
local proc = k.current_process()
proc.last_yield = proc.last_yield or computer.uptime()
local last_yield = proc.last_yield
if computer.uptime() - last_yield >= 0.1 then
if pcall(coroutine.yield, k.sysyield_string) then
proc.last_yield = computer.uptime()
end
end
end
function k.load(chunk, name, mode, env)
chunk = wrap(chunk)
if k.cmdline.debug_load then
local fd = k.open("/load.txt", "a") or k.open("/load.txt", "w")
if fd then
k.write(fd, "== LOAD ==\n" .. chunk)
k.close(fd)
end
end
local func, err = load(chunk, name, mode, env)
if not func then
return nil, err
else
local result = table.pack(pcall(func, sysyield))
if not result[1] then
return nil, result[2]
else
return table.unpack(result, 2, result.n)
end
end
end
end
printk(k.L_INFO, "components/main")
printk(k.L_INFO, "components/carddock")
do
for addr in component.list("carddock") do
printk(k.L_INFO, "component: binding component from carddock %s", addr)
component.invoke(addr, "bindComponent")
end
end
printk(k.L_INFO, "fs/main")--
printk(k.L_INFO, "fs/permissions")
do
local order = {
0x001,
0x002,
0x004,
0x008,
0x010,
0x020,
0x040,
0x080,
0x100,
}  function k.perm_string_to_bitmap(permstr)
checkArg(1, permstr, "string")
if not permstr:match("[r%-][w%-][x%-][r%-][w%-][x%-][r%-][w%-][x%-]") then
return nil, k.errno.EINVAL
end
local bitmap = 0
for i=#order, 1, -1 do
local index = #order - i + 1
if permstr:sub(index, index) ~= "-" then
bitmap = (bitmap | order[i])
end
end
return bitmap
end  function k.has_permission(ogo, mode, perm)
checkArg(1, ogo, "number")
checkArg(2, mode, "number")
checkArg(3, perm, "string")
local val_check = 0
local base_index = ogo * 3
for c in perm:gmatch(".") do
if c == "r" then
val_check = (val_check | order[base_index])
elseif c == "w" then
val_check = (val_check | order[base_index - 1])
elseif c == "x" then
val_check = (val_check | order[base_index - 2])
end
end
return (mode & val_check) == val_check
end
function k.process_has_permission(proc, stat, perm)
checkArg(1, proc, "table")
checkArg(2, stat, "table")
checkArg(3, perm, "string")    if proc.euid == 0 and perm ~= "x" then return true end
local ogo = (proc.euid == stat.uid and 3) or (proc.egid == stat.gid and 2)
or 1
return k.has_permission(ogo, stat.mode, perm)
end
end
do  k.fstypes = {}  k.FS_FIFO   = 0x1000  k.FS_CHRDEV = 0x2000  k.FS_DIR    = 0x4000  k.FS_BLKDEV = 0x6000  k.FS_REG    = 0x8000  k.FS_SYMLNK = 0xA000  k.FS_SOCKET = 0xC000
k.FS_SETUID = 0x0800  k.FS_SETGID = 0x0400  k.FS_STICKY = 0x0200  function k.register_fstype(name, recognizer)
checkArg(1, name, "string")
checkArg(2, recognizer, "function")
if k.fstypes[name] then
panic("attempted to double-register fstype " .. name)
end
k.fstypes[name] = recognizer
return true
end
local function recognize_filesystem(component)
for fstype, recognizer in pairs(k.fstypes) do
local fs = recognizer(component)
if fs then fs.mountType = fstype return fs end
end
return nil
end
local mounts = {}
function k.split_path(path)
checkArg(1, path, "string")
local segments = {}
for piece in path:gmatch("[^/\\]+") do
segments[#segments+1] = piece
end
return segments
end
function k.clean_path(path)
checkArg(1, path, "string")
return "/" .. table.concat(k.split_path(path), "/")
end
function k.check_absolute(path)
checkArg(1, path, "string")
local current = k.current_process()
local root = current and current.root or "/"
local cwd = current and current.cwd or "/"
if path:sub(1, 1) == "/" then
return "/" .. table.concat(k.split_path(root .. "/" .. path), "/")
else
return "/" .. table.concat(k.split_path(cwd .. "/" .. path), "/")
end
end
local function path_to_node(path)
local mnt, rem = "/", path
for m in pairs(mounts) do
if path:sub(1, #m) == m and #m > #mnt then
mnt, rem = m, path:sub(#m+1)
end
end
if #rem == 0 then rem = "/" end
return mounts[mnt], rem or "/"
end  local function resolve_path(path, symlink)
local lookup = "/"
local current = k.current_process()
if current then
if path:sub(1,1) ~= "/" then
lookup = current.cwd or lookup
else
lookup = current.root or lookup
end
end
local segments = k.split_path(path)
local i = 0
while i < #segments do
i = i + 1
local node, rem = path_to_node(lookup)
local stat = node:stat(rem)
if not stat then
return nil, k.errno.ENOENT
end
if stat.mode & 0xF000 ~= k.FS_DIR then
return nil, k.errno.ENOTDIR
end      if current and not k.process_has_permission(current, stat, "x") then
printk(k.L_DEBUG, "EACCES at %q", lookup)
return nil, k.errno.EACCES
end
if lookup == "/" then
lookup = lookup .. segments[i]
else
lookup = lookup .. "/" .. segments[i]
end
local node, rem = path_to_node(lookup)
stat = node:stat(rem)
if i < #segments and not stat then
return nil, k.errno.ENOENT
elseif stat then
if stat.mode & 0xF000 == k.FS_SYMLNK then
if nosymlink then
return nil, k.errno.ENOTDIR
else
local new_path = node:islink(rem)
if new_path:sub(1,1) == "/" then
lookup = new_path
else
lookup = lookup:gsub("/?[^/]*$", "")
for j=i, #segments do segments[j] = nil end
for j, segment in ipairs(k.split_path(new_path)) do
segments[i+j] = segment[j]
end
end
end
end      end
if i == #segments then        return node, rem, not not stat, stat and (stat.mode & 0xF000 == k.FS_SYMLNK)
end
end
local node, rem = path_to_node(lookup)
return node, rem, true, false
end
k.lookup_file = resolve_path
local default_proc = {euid = 0, gid = 0}
local function cur_proc()
return k.current_process and k.current_process() or default_proc
end
local empty = {}  function k.mount(node, path)
checkArg(1, node, "table", "string")
checkArg(2, path, "string")
if cur_proc().euid ~= 0 then return nil, k.errno.EACCES end
if path ~= "/" then
local stat = k.stat(path)
if (not stat) then
return nil, k.errno.ENOENT
elseif (stat.mode & 0xF000) ~= 0x4000 then
return nil, k.errno.ENOTDIR
end
end
path = k.check_absolute(path)
if mounts[path] then
return nil, k.errno.EBUSY
end
local proxy = node
if type(node) == "string" then
if node:find("/", nil, true) then
local absolute = k.check_absolute(node)
local node, rem = k.lookup_file(node)
if (not node) then
return nil, k.errno.ENOENT
elseif (node.address ~= "devfs") then
return nil, k.errno.ENODEV
end
local dentry, drem = k.devfs.lookup(rem)
if (not dentry) then
return nil, drem
end
if dentry.address == "components" then
local hand, err = dentry:open(drem)
if not hand then
return nil, err
end
if hand.proxy.type ~= "filesystem" and
hand.proxy.type ~= "drive" then
return nil, k.errno.ENOTBLK
end
proxy = recognize_filesystem(hand.proxy)
elseif dentry.type == "blkdev" then
proxy = dentry.fs
else
return nil, k.errno.ENOTBLK
end
if proxy then proxy = recognize_filesystem(proxy) end
if not proxy then return nil, k.errno.EUNATCH end
else
node = component.proxy(node) or k.devfs.lookup(node) or node
if node.type == "blkdev" and node.fs then node = node.fs end
proxy = recognize_filesystem(node)
if not proxy then return nil, k.errno.EUNATCH end
end
end
if not node then return nil, k.errno.ENODEV end
proxy.mountType = proxy.mountType or "managed"
mounts[path] = proxy
if proxy.mount then proxy:mount(path) end
return true
end  function k.unmount(path)
checkArg(1, path, "string")
if cur_proc().euid ~= 0 then return nil, k.errno.EACCES end
path = k.clean_path(path)
if not mounts[path] then
return nil, k.errno.EINVAL
end
local node = mounts[path]
if node.unmount then node:unmount(path) end
mounts[path] = nil
return true
end
local opened = {}
local function count(t)
local n = 0
for _ in pairs(t) do n = n + 1 end
return n
end
function k.open(file, mode)
checkArg(1, file, "string")
checkArg(2, mode, "string")
local node, remain = resolve_path(file)
if not node then return nil, remain end
if not node.open then return nil, k.errno.ENOSYS end
local exists = node:exists(remain)
if mode ~= "w" and mode ~= "a" and not exists then
return nil, k.errno.ENOENT
end
local segs = k.split_path(remain)
local dir = "/" .. table.concat(segs, "/", 1, #segs - 1)
local base = segs[#segs]
local stat, err
if not exists then
stat, err = node:stat(dir)
else
stat, err = node:stat(remain)
end
if not stat then
return nil, err
end
if not k.process_has_permission(cur_proc(), stat, mode) then
return nil, k.errno.EACCES
end
local umask = (cur_proc().umask or 0) ~ 511
local fd, err = node:open(remain, mode, stat.mode & umask)
if not fd then return nil, err end
local stream = k.fd_from_node(node, fd, mode)
if node.default_mode then
stream:ioctl("setvbuf", node.default_mode)
end
if type(fd) == "table" and fd.default_mode then
stream:ioctl("setvbuf", fd.default_mode)
end
local ret = { fd = stream, node = stream, refs = 1 }
opened[ret] = true
return ret
end
local function verify_fd(fd, dir)
checkArg(1, fd, "table")
if not (fd.fd and fd.node) then
error("bad argument #1 (file descriptor expected)", 2)
end    if (not not fd.dir) ~= (not not dir) then
error("bad argument #1 (cannot supply dirfd where fd is required, or vice versa)", 2)
end
end
function k.ioctl(fd, op, ...)
verify_fd(fd)
checkArg(2, op, "string")
if op == "setcloexec" then
fd.cloexec = not not ...
return true
end
if not fd.node.ioctl then return nil, k.errno.ENOSYS end
return fd.node.ioctl(fd.fd, op, ...)
end
function k.read(fd, fmt)
verify_fd(fd)
checkArg(2, fmt, "string", "number")
if not fd.node.read then return nil, k.errno.ENOSYS end
return fd.node.read(fd.fd, fmt)
end
function k.write(fd, data)
verify_fd(fd)
checkArg(2, data, "string")
if not fd.node.write then return nil, k.errno.ENOSYS end
return fd.node.write(fd.fd, data)
end
function k.seek(fd, whence, offset)
verify_fd(fd)
checkArg(2, whence, "string")
checkArg(3, offset, "number")
return fd.node.seek(fd.fd, whence, offset)
end
function k.flush(fd)
if fd.dir then return end    verify_fd(fd)
if not fd.node.flush then return nil, k.errno.ENOSYS end
return fd.node.flush(fd.fd)
end
function k.opendir(path)
checkArg(1, path, "string")
path = k.check_absolute(path)
local node, remain = resolve_path(path)
if not node then return nil, remain end
if not node.opendir then return nil, k.errno.ENOSYS end
if not node:exists(remain) then return nil, k.errno.ENOENT end
local stat = node:stat(remain)
if not k.process_has_permission(cur_proc(), stat, "r") then
return nil, k.errno.EACCES
end
local fd, err = node:opendir(remain)
if not fd then return nil, err end
local ret = { fd = fd, node = node, dir = true, refs = 1 }
opened[ret] = true
return ret
end
function k.readdir(dirfd)
verify_fd(dirfd, true)
if not dirfd.node.readdir then return nil, k.errno.ENOSYS end
return dirfd.node:readdir(dirfd.fd)
end
function k.close(fd)
verify_fd(fd, fd.dir)
fd.refs = fd.refs - 1
if fd.node.flush then fd.node:flush(fd.fd) end
if fd.refs <= 0 then
opened[fd] = nil
if not fd.node.close then return nil, k.errno.ENOSYS end
if fd.dir then return fd.node:close(fd.fd) end
return fd.node.close(fd.fd)
end
end
local stat_defaults = {
dev = -1, ino = -1, mode = 0x81FF, nlink = 1,
uid = 0, gid = 0, rdev = -1, size = 0, blksize = 2048,
atime = 0, ctime = 0, mtime = 0
}
function k.stat(path)
checkArg(1, path, "string")
local node, remain = resolve_path(path)
if not node then return nil, remain end
if not node.stat then return nil, k.errno.ENOSYS end
local statx, errno = node:stat(remain)
if not statx then return nil, errno end
for key, val in pairs(stat_defaults) do
statx[key] = statx[key] or val
end
return statx
end
function k.mkdir(path, mode)
checkArg(1, path, "string")
checkArg(2, mode, "number", "nil")
local node, remain = resolve_path(path)
if not node then return nil, remain end
if not node.mkdir then return nil, k.errno.ENOSYS end
if node:exists(remain) then return nil, k.errno.EEXIST end
local segments = k.split_path(remain)
local parent = "/" .. table.concat(segments, "/", 1, #segments - 1)
local stat = node:stat(parent)
if not stat then return nil, k.errno.ENOENT end
if not k.process_has_permission(cur_proc(), stat, "w") then
return nil, k.errno.EACCES
end
local umask = (cur_proc().umask or 0) ~ 511
local done, failed = node:mkdir(remain, (mode or stat.mode) & umask)
if not done then return nil, failed end
return not not done
end
function k.link(source, dest)
checkArg(1, source, "string")
checkArg(2, dest, "string")
local node, sremain = resolve_path(source)
if not node then return nil, sremain end
local _node, dremain = resolve_path(dest)
if not _node then return nil, dremain end
if _node ~= node then return nil, k.errno.EXDEV end
if not node.link then return nil, k.errno.ENOSYS end
if node:exists(dremain) then return nil, k.errno.EEXIST end
local segments = k.split_path(dremain)
local parent = "/" .. table.concat(segments, "/", 1, #segments - 1)
local stat = node:stat(parent)
if not k.process_has_permission(cur_proc(), stat, "w") then
return nil, k.errno.EACCES
end
return node:link(sremain, dremain)
end
function k.symlink(target, linkpath)
checkArg(1, target, "string")
checkArg(2, linkpath, "string")
local node, remain = resolve_path(file)
if not node then return nil, remain end
if not node.symlink then return nil, k.errno.ENOSYS end
if not node:exists(remain) then return nil, k.errno.ENOENT end
local segs = k.split_path(remain)
local dir = "/" .. table.concat(segs, "/", 1, #segs - 1)
local base = segs[#segs]
local stat, err = node:stat(dir)
if not stat then
return nil, err
end
if not k.process_has_permission(cur_proc(), stat, mode) then
return nil, k.errno.EACCES
end
local umask = (cur_proc().umask or 0) ~ 511
return node:symlink(remain, mode, stat.mode & umask)
end
function k.unlink(path)
checkArg(1, path, "string")
local node, remain = resolve_path(path)
if not node then return nil, remain end
if not node.unlink then return nil, k.errno.ENOSYS end
if not node:exists(remain) then return nil, k.errno.ENOENT end    local stat = node:stat(remain)
if not k.process_has_permission(cur_proc(), stat, "w") then
return nil, k.errno.EACCES
end
return node:unlink(remain)
end
function k.chmod(path, mode)
checkArg(1, path, "string")
checkArg(2, mode, "number")
local node, remain = resolve_path(path)
if not node then return nil, remain end
if not node.chmod then return nil, k.errno.ENOSYS end
if not node:exists(remain) then return nil, k.errno.ENOENT end
local stat = node:stat(remain)
if not k.process_has_permission(cur_proc(), stat, "w") then
return nil, k.errno.EACCES
end    mode = (mode & 0xFFF)
return node:chmod(remain, mode)
end
function k.chown(path, uid, gid)
checkArg(1, path, "string")
checkArg(2, uid, "number")
checkArg(3, gid, "number")
local node, remain = resolve_path(path)
if not node then return nil, remain end
if not node.chown then return nil, k.errno.ENOSYS end
if not node:exists(remain) then return nil, k.errno.ENOENT end
local stat = node:stat(remain)
if not k.process_has_permission(cur_proc(), stat, "w") then
return nil, k.errno.EACCES
end
return node:chown(remain, uid, gid)
end
function k.mounts()
return mounts
end
function k.sync_fs()
for _, node in pairs(mounts) do
if node.sync then node:sync("dummy") end
end
end
k.add_signal_handler("shutdown", function()
k.sync_buffers()
k.sync_fs()
for fd in pairs(opened) do
fd.refs = 1
k.close(fd)
end
for path in pairs(mounts) do
k.unmount(path)
end
end)
end
printk(k.L_INFO, "fs/devfs")
do
local provider = {}  local devices = {}  local handlers = {}
k.devfs = {}
function k.devfs.register_device_handler(devtype, registrar, deregistrar)
checkArg(1, devtype, "string")
checkArg(2, registrar, "function")
checkArg(3, deregistrar, "function")
handlers[devtype] = handlers[devtype] or {}
local id = math.random(0, 999999)
handlers[devtype][id] = {register = registrar, deregister = deregistrar}
return id
end
function k.devfs.register_device(path, device)
checkArg(1, path, "string")
checkArg(2, device, "table")
local segments = k.split_path(path)
if #segments > 1 then
error("cannot register device in subdirectory '"..path.."' of devfs", 2)
end
if not device.type then
printk(k.L_WARNING, "device '%s' has no 'type' field!", path)
device.type = "unknown"
end
devices[path] = device
if handlers[device.type] then
for _, handler in pairs(handlers[device.type]) do
handler.register(path, device)
end
end
if path:sub(1,1) ~= "/" then path = "/" .. path end
printk(k.L_INFO, "devfs: registered device at %s type=%s", path,
device.type)
end
function k.devfs.unregister_device(path)
checkArg(1, path, "string")
local segments = k.split_path(path)
if #segments > 1 then
error("cannot unregister device in subdirectory '"..path.."' of devfs", 2)
end
devices[path] = nil
if path:sub(1,1) ~= "/" then path = "/" .. path end
printk(k.L_INFO, "devfs: unregistered device at %s", path)
end
k.devfs.register_device("/", {
opendir = function()
local devs = {}
for k in pairs(devices) do if k ~= "/" then devs[#devs+1] = k end end
return { devs = devs, i = 0 }
end,
readdir = function(_, fd)
fd.i = fd.i + 1
if fd.devs and fd.devs[fd.i] then
return { inode = -1, name = fd.devs[fd.i] }
else
fd.devs = nil
end
end,
stat = function()
return { dev = -1, ino = -1, mode = 0x41ED, nlink = 1,
uid = 0, gid = 0, rdev = -1, size = 0, blksize = 2048,
atime = 0, ctime = 0, mtime = 0 }
end
})
local function path_to_node(path)
local segments = k.split_path(path)
if path == "/" or path == "" then
return devices[path]
end
if not devices[segments[1]] then
return nil, k.errno.ENOENT
else
return devices[segments[1]], table.concat(segments, "/", 2, segments.n)
end
end
k.devfs.lookup = path_to_node  function k.devfs.get_by_type(dtype)
checkArg(1, dtype, "string")
local matches = {}
for path, dev in pairs(devices) do
if dev.type == dtype then
matches[#matches+1] = {path=path, device=dev}
end
end
return matches
end
function provider:exists(path)
checkArg(1, path, "string")
return not not path_to_node(path)
end  local function autocall(calling, pathorfd, ...)
checkArg(1, pathorfd, "string", "table")
if type(pathorfd) == "string" then
local device, path = path_to_node(pathorfd)
if not device then return nil, k.errno.ENOENT end
if not device[calling] then return nil, k.errno.ENOSYS end
local result, err = device[calling](device, path, ...)
if not result then return nil, err end
if result and (calling == "open" or calling == "opendir") then
return { node = device, fd = result,
default_mode = result.default_mode }
else
return result, err
end
else
if not (pathorfd.node and pathorfd.fd) then
return nil, k.errno.EBADF
end
local device, fd = pathorfd.node, pathorfd.fd
local result, err
if calling == "ioctl" and (...) == "reregister" then
if handlers[device.type] then
for _, handler in pairs(handlers[device.type]) do
handler.deregister(path, device)
end
for _, handler in pairs(handlers[device.type]) do
handler.register(path, device)
end
result = true
end
else
if not device[calling] then return nil, k.errno.ENOSYS end
if calling == "ioctl" and not device.is_dev then
result, err = device[calling](fd, ...)
else
result, err = device[calling](device, fd, ...)
end
end
return result, err
end
end
provider.default_mode = "none"
setmetatable(provider, {__index = function(_, k)
if k ~= "ioctl" then
return function(_, ...)
return autocall(k, ...)
end
else
return function(...)
return autocall(k, ...)
end
end
end})
provider.address = "devfs"
provider.type = "root"
k.register_fstype("devfs", function(x)
return x == "devfs" and provider
end)
end-- devfs/blockdev registers block devices.  alternative is extra logic.--
printk(k.L_INFO, "fs/partition/main")
do
k.partition_types = {}
function k.register_partition_type(name, reader)
checkArg(1, name, "string")
checkArg(2, reader, "function")
if k.partition_types[name] then
panic("attempted to double-register partition type " .. name)
end
k.partition_types[name] = reader
return true
end  local drives = {}
local function read_partitions(drive)
for name, reader in pairs(k.partition_types) do
local partitions = reader(drive)
if partitions then return partitions end
end
end
local function create_subdrive(drive, start, size)
local sub = {}
local sector, byteOffset = start, (start - 1) * drive.getSectorSize()
local byteSize = size * drive.getSectorSize()
function sub.readSector(n)
if n < 1 or n > size then
error("invalid offset, not in a usable sector", 0)
end
return drive.readSector(sector + n - 1)
end
function sub.writeSector(n, d)
if n < 1 or n > size then
error("invalid offset, not in a usable sector", 0)
end
return drive.writeSector(sector + n - 1, d)
end
function sub.readByte(n)
if n < 1 or n > byteSize then return 0 end
return drive.readByte(n + byteOffset)
end
function sub.writeByte(n, i)
if n < 1 or n > byteSize then return 0 end
return drive.writeByte(n + byteOffset, i)
end
sub.getSectorSize = drive.getSectorSize
function sub.getCapacity()
return drive.getSectorSize() * size
end
sub.type = "drive"
return sub
end
k.devfs.register_device_handler("blkdev",
function(path, device)      if not device.fs then return end
local drive = device.fs
local partitions = read_partitions(drive)
if (not partitions) or #partitions == 0 then return end
drives[drive] = {address=device.address,count=#partitions}
for i=1, #partitions do
local spec = partitions[i]
local subdrive = create_subdrive(drive, spec.start, spec.size)
local _, subdevice = k.devfs.get_blockdev_handlers()
.drive.init(subdrive, true)
subdevice.address = device.address..i
subdevice.type = "blkdev"
k.devfs.register_device(device.address..i, subdevice)
end
end,
function(path, device)      if not device.fs then return end
local drive = device.fs
local info = drives[drive]
if info then
for i=1, info.count do
k.devfs.unregister_device(device.address..i)
end
end
drives[drive] = nil
end)
end
printk(k.L_INFO, "fs/partition/osdi")
do
local magic = "OSDI\xAA\xAA\x55\x55"
local format = "<I4I4c8c3c13"
k.register_partition_type("osdi", function(drive)
local sector = drive.readSector(1)
local meta = {format:unpack(sector)}    if meta[1] ~= 1 or meta[2] ~= 0 or meta[3] ~= magic then return end
local partitions = {}
repeat
sector = sector:sub(33)
meta = {format:unpack(sector)}
meta[3] = meta[3]:gsub("\0", "")
meta[5] = meta[5]:gsub("\0", "")
if #meta[5] > 0 then
partitions[#partitions+1] = {start=meta[1], size=meta[2]}
end
until #sector <= 32
return partitions
end)
end
printk(k.L_INFO, "fs/partition/mtpt")
do
local format = "c20c4>I4>I4"
k.register_partition_type("mtpt", function(drive)
local sector = drive.readSector(drive.getCapacity()/drive.getSectorSize())
local meta = {format:unpack(sector)}
if meta[2] ~= "mtpt" then return end    local partitions = {}
repeat
sector = sector:sub(33)
meta = {format:unpack(sector)}
meta[1] = meta[1]:gsub("\0", "")
if #meta[1] > 0 then
partitions[#partitions+1] = {start = meta[3], size = meta[4]}
end
until #sector <= 32
return partitions
end)
end
printk(k.L_INFO, "disciplines/main")
do
k.disciplines = {}end
printk(k.L_INFO, "disciplines/null")
do
local discipline = {}
function discipline.wrap(obj)
return setmetatable({obj=obj}, {__index=discipline})
end
function discipline:read(n)
checkArg(1, n, "number")
if self.obj.read then return self.obj:read(n) end
return nil, k.errno.ENOSYS
end
function discipline:write(data)
checkArg(1, data, "string")
if self.obj.write then return self.obj:write(data) end
return nil, k.errno.ENOSYS
end
function discipline:flush() end
function discipline:close() end
k.disciplines.null = discipline
end
printk(k.L_INFO, "disciplines/tty")
do
local discipline = { default_mode = "line" }
local eolpat = "\n[^\n]-$"
function discipline.wrap(obj)
checkArg(1, obj, "table")
local new
if obj.discipline then
new = obj.discipline
else
new = setmetatable({
obj = obj,
mode = "line", rbuf = "", wbuf = "",
erase = "\8", intr = "\3", kill = "\21",
quit = "\28", start = "\19", stop = "\17",
susp = "\26", eof = "\4", raw = false,
stopped = false, echo = true,
override_setvbuf = true
}, {__index=discipline})
obj.discipline = new
new.eofpat = string.format("%%%s[^%%%s]-$", new.eof, new.eof)
end
local proc = k.current_process()
if proc and not new.session and not proc.tty then
proc.tty = new
new.session = proc.sid
new.pgroup = proc.pgroup
end
return new
end
local sub32_lookups = {
[0]   = " ",
[27]  = "[",
[28]  = "\\",
[29]  = "]",
[30]  = "~",
[31]  = "?"
}
local sub32_lookups_notraw = {
[10] = "\n"
}
for i=1, 26, 1 do sub32_lookups[i] = string.char(64 + i) end
local function send(obj, sig)
local pids = k.get_pids()
printk(k.L_DEBUG, "sending %s to pgroup %d", sig, obj.pgroup or -1)
for i=1, #pids, 1 do
local proc = k.get_process(pids[i])
if proc.pgid == obj.pgroup then
printk(k.L_DEBUG, "sending %s to %d", sig, pids[i])
table.insert(proc.sigqueue, sig)
end
end
end
local function pchar(self, c)
if self.echo then
local byte = string.byte(c)
if (not self.raw) and sub32_lookups_notraw[byte] then
self.obj:write(sub32_lookups_notraw[byte])
elseif sub32_lookups[byte] then
self.obj:write("^"..sub32_lookups[byte])
elseif byte < 126 then
self.obj:write(c)
end
end
end
local function wchar(self, c)
if (not self.raw) and c == "\r" then c = "\n" end
self.rbuf = self.rbuf .. c
pchar(self, c)
end  function discipline:processInput(inp)
self:flush()
for c in inp:gmatch(".") do
if not self.raw then
if c == self.erase then
if #self.rbuf > 0 then
local last = self.rbuf:sub(-1)
if last ~= self.eol and last ~= self.eof then
if self.echo then
if last:byte() < 32 then
self.obj:write("\27[2D  \27[2D")
else
self.obj:write("\27[D \27[D")
end
end
self.rbuf = self.rbuf:sub(1, -2)
end
end
elseif c == self.eof then
wchar(self, c)
elseif c == self.intr then
send(self, "SIGINT")
pchar(self, self.intr)
elseif c == self.quit then
send(self, "SIGQUIT")
pchar(self, self.quit)
elseif c == self.start then
self.stopped = false
elseif c == self.stop then
self.stopped = true
elseif c == self.susp then
send(self, "SIGSTOP")
pchar(self, self.susp)
else
wchar(self, c)
end
else
wchar(self, c)
end
end
end
local function s(se,k,v)
se[k] = v[k] or se[k]
end
function discipline:ioctl(method, args)
if method == "stty" then
checkArg(2, args, "table")
s(self, "eol", args)
s(self, "erase", args)
s(self, "intr", args)
s(self, "kill", args)
s(self, "quit", args)
s(self, "start", args)
s(self, "stop", args)
s(self, "susp", args)      if args.echo ~= nil then self.echo = not not args.echo end
if args.raw ~= nil then self.raw = not not args.raw end
self.eofpat = string.format("%%%s[^%%%s]-$", self.eof, self.eof)
return true
elseif method == "getattrs" then
return {
eol = self.eol,
erase = self.erase,
intr = self.intr,
kill = self.kill,
quit = self.quit,
start = self.start,
stop = self.stop,
susp = self.susp,
echo = self.echo,
raw = self.raw
}
elseif method == "setpg" then
local current = k.current_process()
if self.pgroup and current.pgid ~= self.pgroup then
current:signal("SIGTTOU", true)
end
self.pgroup = args
return true
elseif method == "getpg" then
return self.pgroup or math.huge
elseif method == "ttyname" then
return self.obj.name
elseif method == "setvbuf" then
if args == "line" or args == "none" then
self.mode = args
else
return nil, k.errno.EINVAL
end
elseif method == "setlogin" then
checkArg(3, args, "number")
self.login = args
elseif method == "getlogin" then
return self.login
else
return nil, k.errno.ENOSYS
end
end
function discipline:read(n)
checkArg(1, n, "number")
self:flush()
local current = k.current_process()
if self.pgroup and current.pgid ~= self.pgroup and
k.is_pgroup(self.pgroup) then
current:signal("SIGTTIN", true)
end
while #self.rbuf < n do
coroutine.yield()
if self.rbuf:find(self.eof, nil, true) and not self.raw then break end
end
if self.mode == "line" then
while (self.rbuf:find(eolpat) or 0) < n do
coroutine.yield()
if self.rbuf:find(self.eof, nil, true) and not self.raw then break end
end
end
if not self.raw then
local eof = self.rbuf:find(self.eof, nil, true)
n = math.min(n, eof or math.huge)
end
local data = self.rbuf:sub(1, n)
self.rbuf = self.rbuf:sub(#data + 1)
if not self.raw then
if data == self.eof then return nil end
if data:sub(-1) == self.eof then return data:sub(1, -2) end
end
return data
end
function discipline:write(text)
checkArg(1, text, "string")
while self.stopped and #self.wbuf >= 1024 do
coroutine.yield()
end
self.wbuf = self.wbuf .. text
local last_eol = self.wbuf:find(eolpat)
if last_eol then
local data = self.wbuf:sub(1, last_eol)
self.wbuf = self.wbuf:sub(#data + 1)
self.obj:write(data)
end
return true
end
function discipline:flush()
if #self.wbuf == 0 then return end
local data = self.wbuf
self.wbuf = ""
self.obj:write(data)
end
function discipline:close()
local proc = k.current_process()
if proc.tty == self then
proc.tty = false
end
return true
end
k.disciplines.tty = discipline
end
printk(k.L_INFO, "fs/devfs_chardev")
do
local chardev = {}
function chardev.new(stream, discipline)
checkArg(1, stream, "table")
checkArg(2, discipline, "string")
if not k.disciplines[discipline] then
error("no line discipline '"..discipline.."'")
end
local new = setmetatable({
stream = stream, discipline = discipline, type="chardev"},
{__index = chardev})
return new
end
function chardev:open(path)
if #path > 0 then return nil, k.errno.ENOTDIR end
return { fd = k.disciplines[self.discipline].wrap(self.stream),
default_mode = k.disciplines[self.discipline].default_mode or "none" }
end
function chardev:stat()
return { dev = -1, ino = -1, mode = 0x2000 + (self.stream.perms or 0x1A4),
nlink = 1, uid = 0, gid = 0, rdev = -1, size = 0, blksize = 2048,
atime = 0, ctime = 0, mtime = 0 }
end
function chardev:read(fd, n)
return fd.fd:read(n)
end
function chardev:write(fd, data)
return fd.fd:write(data)
end
function chardev:seek()
return nil, k.errno.ENOSYS
end
function chardev:flush(fd)
if fd.fd.flush then fd.fd:flush() end
return true
end
function chardev.ioctl(fd, ...)
if fd.fd.ioctl then return fd.fd:ioctl(...) end
return nil, k.errno.ENOSYS
end
function chardev:close(fd)
return fd.fd:close()
end
k.chardev = chardev  k.devfs.register_device("random", k.chardev.new({read=function(_,n)
local dat = ""
for _=1, math.min(n,2048), 1 do
dat = dat .. string.char(math.random(0, 255))
end
return dat
end, write = function() end, perms = 0x1B6}, "null"))
k.devfs.register_device("null", k.chardev.new({read=function()return nil end,
write=function()end, perms=0x1B6}, "null"))
k.devfs.register_device("zero", k.chardev.new({read=function(_,n)
return ("\0"):rep(math.min(n,2048))
end, write = function() end, perms = 0x1B6}, "null"))
end
printk(k.L_INFO, "fs/devfs_blockdev")
do
local handlers = {}
function k.devfs.register_blockdev(devtype, callbacks)
printk(k.L_DEBUG, "registered block device type %s", devtype)
handlers[devtype] = callbacks
end
function k.devfs.get_blockdev_handlers()
return handlers
end
local function comp_added(_, addr, t)
printk(k.L_DEBUG, "component_added: %s %s", addr, t)
if handlers[t] then
printk(k.L_DEBUG, "intializing device %s", addr)
local name, device = handlers[t].init(addr)
device.type = device.type or "blkdev"
if name then
k.devfs.register_device(name, device)
end
end
end
local function comp_removed(_, addr, t)
printk(k.L_DEBUG, "component_removed: %s %s", addr, t)
if handlers[t] then
local name = handlers[t].destroy(addr)
if name then
k.devfs.unregister_device(name)
end
end
end
printk(k.L_INFO, "blockdev/eeprom")
do
local present = false
k.devfs.register_blockdev("eeprom", {
init = function(addr)
if not present then
present = true
local eeprom = component.proxy(addr)
local romdata = eeprom.get()
local romsize = eeprom.getSize()
return "eeprom", {
stat = function()
return {
dev = -1,
ino = -1,
mode = 0x6000 | k.perm_string_to_bitmap("rw-rw----"),
nlink = 1,
uid = 0,
gid = 0,
rdev = -1,
size = romsize,
blksize = 4096,
atime = 0,
ctime = 0,
mtime = 0
}
end,
open = function(_, _, mode)
local pos = 0
if mode == "w" then
romdata = ""
end
return {pos = pos, mode = mode}
end,
read = function(_, fd, len)            if fd.pos < romsize then
local data = romdata:sub(fd.pos+1, math.min(romsize, fd.pos+len))
fd.pos = fd.pos + len
return data
else
return nil
end
end,
write = function(_, fd, data)
if fd.mode == "w" then
romdata = (romdata .. data):sub(1, romsize)
eeprom.set(romdata)
end
end,
}
end
end,
destroy = function(_)
if present then
present = false
return "eeprom"
end
end,
})
end
printk(k.L_INFO, "blockdev/drive")
do
local drives = {}
local byaddress = {}
k.devfs.register_blockdev("drive", {
init = function(addr, noindex)
local index = 0
while drives[index] do
index = index + 1
end
local letter = string.char(string.byte("a") + index)
local proxy = noindex and addr or component.proxy(addr)
if not noindex then drives[index] = true end
if not noindex then byaddress[addr] = index end
local size = proxy.getCapacity()
return "hd"..letter, {
fs = proxy,
address = "hd"..letter,
stat = function()
return {
dev = -1,
ino = -1,
mode = 0x6000 | k.perm_string_to_bitmap("rw-rw----"),
nlink = 1,
uid = 0,
gid = 0,
rdev = -1,
size = size,
blksize = 512,
atime = 0,
ctime = 0,
mtime = 0
}
end,
open = function(_, _, mode)
return { pos = 0, mode = mode }
end,
read = function(_, fd, len)
if not fd.mode:match("[ra]") then
return nil, k.errno.EBADF
end
if fd.pos < size then
len = math.min(len, size - fd.pos)
local offset = fd.pos % 512 + 1
local data = ""
repeat
local sectorID = math.ceil((fd.pos+1) / 512)
local sector = proxy.readSector(sectorID)
local read = sector:sub(offset, offset+len-1)
data = data .. read
fd.pos = fd.pos + #read
offset = fd.pos % 512 + 1
len = len - #read
until len <= 0
return data
end
end,
write = function(_, fd, data)
if not fd.mode:match("[wa]") then
return nil, k.errno.EBADF
end
local offset = fd.pos % 512
repeat
local sectorID = math.ceil((fd.pos+1) / 512)
if sectorID > size/512 then return end
local sector = proxy.readSector(sectorID)
local write = data:sub(1, 512 - offset)
data = data:sub(#write + 1)
fd.pos = fd.pos + #write
if #write == #sector then
sector = write
else
sector = sector:sub(0, offset) .. write ..
sector:sub(offset + #write + 1)
end
offset = (offset + #write + 0) % 512
proxy.writeSector(sectorID, sector)
until #data == 0
return true
end,
seek = function(_, fd, whence, offset)
whence = (whence == "set" and 0) or (whence == "cur" and fd.pos)
or (whence == "end" and size)
fd.pos = math.max(0, math.min(size, whence + offset))
return fd.pos
end
}
end,
destroy = function(addr)
local letter = string.char(string.byte("a") + byaddress[addr])
drives[byaddress[addr]] = nil
byaddress[addr] = nil
return ("hd%s"):format(letter)
end,
})
end
k.blacklist_signal("component_added")
k.blacklist_signal("component_removed")
k.add_signal_handler("component_added", comp_added)
k.add_signal_handler("component_removed", comp_removed)
for addr, ctype in component.list() do
comp_added(nil, addr, ctype)
end
end--
printk(k.L_INFO, "fs/managed")
do
local _node = {}  local function load_attributes(data)
local attributes = {}
for line in data:gmatch("[^\n]+") do
local key, val = line:match("^(.-):(.+)$")
attributes[key] = tonumber(val)
end
return attributes
end  local function dump_attributes(attributes)
local data = ""
for key, val in pairs(attributes) do
data = data .. key .. ":" .. math.floor(val) .. "\n"
end
return data
end  local function is_attribute(path)
checkArg(1, path, "string")
return not not path:match("%.[^/]+%.attr$")
end
local function attr_path(path)
local segments = k.split_path(path)
if #segments == 0 then return "/.attr" end
return "/" .. table.concat(segments, "/", 1, #segments - 1) .. "/." ..
segments[#segments] .. ".attr"
end  function _node:lastModified(file)
local last = self.fs.lastModified(file)
if last > 9999999999 then
return math.floor(last / 1000)
end
return last
end  function _node:get_attributes(file)
checkArg(1, file, "string")
if is_attribute(file) then return nil, k.errno.EACCES end
local isdir = self.fs.isDirectory(file)
local fd = self.fs.open(attr_path(file), "r")
if not fd then      return {
uid = k.syscalls and k.syscalls.geteuid() or 0,
gid = k.syscalls and k.syscalls.getegid() or 0,
mode = isdir and 0x41ED or 0x81A4,
created = self:lastModified(file)
}
end
local data = self.fs.read(fd, 2048)
self.fs.close(fd)
local attributes = load_attributes(data or "")
attributes.uid = attributes.uid or 0
attributes.gid = attributes.gid or 0    attributes.mode = attributes.mode or
(isdir and 0x4000 or 0x8000) + (0x1FF ~ k.current_process().umask)    if (isdir and (attributes.mode & 0x4000 == 0)) then      attributes.mode = attributes.mode | 0x4000
if attributes.mode & 0x8000 ~= 0 then
attributes.mode = attributes.mode ~ 0x8000
end
elseif (not isdir) and (attributes.mode & 0x4000 ~= 0) then      attributes.mode = attributes.mode ~ 0x4000
if attributes.mode & 0x4000 ~= 0 then
attributes.mode = attributes.mode ~ 0x4000
end
end
attributes.created = attributes.created or self:lastModified(file)
return attributes
end  function _node:set_attributes(file, attributes)
checkArg(1, file, "string")
checkArg(2, attributes, "table")
if is_attribute(file) then return nil, k.errno.EACCES end
local fd = self.fs.open(attr_path(file), "w")
if not fd then return nil, k.errno.EROFS end
self.fs.write(fd, dump_attributes(attributes))
self.fs.close(fd)
return true
end  function _node:islink(path)
checkArg(1, path, "string")
if is_attribute(path) then return nil, k.errno.EACCES end
if not self:exists(path) then return nil, k.errno.ENOENT end
local attributes = self:get_attributes(path)
if attributes.mode & 0xF000 == k.FS_SYMLNK then
return attributes.symtarget
end
end  function _node:exists(path)
checkArg(1, path, "string")    return self.fs.exists(path)
end  function _node:stat(path)
checkArg(1, path, "string")
if is_attribute(path) then return nil, k.errno.EACCES end
if not self:exists(path) then return nil, k.errno.ENOENT end
local attributes = self:get_attributes(path)    local stat = {
dev = -1,
ino = -1,
mode = attributes.mode,
nlink = 1,
uid = attributes.uid,
gid = attributes.gid,
rdev = -1,
size = self.fs.isDirectory(path) and 512 or self.fs.size(path),
blksize = 2048,
ctime = attributes.created,
atime = math.floor(computer.uptime() * 1000),
mtime = self:lastModified(path)*1000
}
stat.blocks = math.ceil(stat.size / 512)
return stat
end
function _node:chmod(path, mode)
checkArg(1, path, "string")
checkArg(2, mode, "number")
if is_attribute(path) then return nil, k.errno.EACCES end
if not self:exists(path) then return nil, k.errno.ENOENT end
local attributes = self:get_attributes(path)    attributes.mode = ((attributes.mode & 0xF000) | (mode & 0xFFF))
return self:set_attributes(path, attributes)
end
function _node:chown(path, uid, gid)
checkArg(1, path, "string")
checkArg(2, uid, "number")
checkArg(3, gid, "number")
if is_attribute(path) then return nil, k.errno.EACCES end
if not self:exists(path) then return nil, k.errno.ENOENT end
local attributes = self:get_attributes(path)
attributes.uid = uid
attributes.gid = gid
return self:set_attributes(path, attributes)
end
function _node:link()    return nil, k.errno.ENOTSUP
end
function _node:symlink(target, linkpath, mode)
checkArg(1, target, "string")
checkArg(2, linkpath, "string")
if self:exists(linkpath) then return nil, k.errno.EEXIST end
self.fs.close(self.fs.open(linkpath, "w"))
local attributes = {}
attributes.mode = (k.FS_SYMLNK | (mode & 0xFFF))
attributes.uid = k.syscalls and k.syscalls.geteuid() or 0
attributes.gid = k.syscalls and k.syscalls.getegid() or 0
attributes.symtarget = target
self:set_attributes(linkpath, attributes)
return true
end
function _node:unlink(path)
checkArg(1, path, "string")
if is_attribute(path) then return nil, k.errno.EACCES end
if not self:exists(path) then return nil, k.errno.ENOENT end
self.fs.remove(path)
self.fs.remove(attr_path(path))
return true
end
function _node:mkdir(path, mode)
checkArg(1, path, "string")
checkArg(2, mode, "number")
local result = (not is_attribute(path)) and self.fs.makeDirectory(path)
if not result then return result end
local attributes = {}
attributes.mode = (k.FS_DIR | (mode & 0xFFF))
attributes.uid = k.syscalls and k.syscalls.geteuid() or 0
attributes.gid = k.syscalls and k.syscalls.getegid() or 0
self:set_attributes(path, attributes)
return result
end
function _node:opendir(path)
checkArg(1, path, "string")
if is_attribute(path) then return nil, k.errno.EACCES end
if not self:exists(path) then return nil, k.errno.ENOENT end
if not self.fs.isDirectory(path) then return nil, k.errno.ENOTDIR end
local files = self.fs.list(path)
for i=#files, 1, -1 do
if is_attribute(files[i]) then table.remove(files, i) end
end
return { index = 0, files = files }
end
function _node:readdir(dirfd)
checkArg(1, dirfd, "table")
if not (dirfd.index and dirfd.files) then
error("bad argument #1 to 'readdir' (expected dirfd)")
end
dirfd.index = dirfd.index + 1
if dirfd.files and dirfd.files[dirfd.index] then
return { inode = -1, name = dirfd.files[dirfd.index]:gsub("/", "") }
end
end
function _node:open(path, mode, permissions)
checkArg(1, path, "string")
checkArg(2, mode, "string")
if is_attribute(path) then return nil, k.errno.EACCES end
if self.fs.isDirectory(path) then
return nil, k.errno.EISDIR
end
local fd = self.fs.open(path, mode)
if not fd then
return nil, k.errno.ENOENT
else
if mode == "w" then
local attributes = {}
attributes.mode = (k.FS_REG | (permissions & 0xFFF))
attributes.uid = k.syscalls and k.syscalls.geteuid() or 0
attributes.gid = k.syscalls and k.syscalls.getegid() or 0
self:set_attributes(path, attributes)
end
return fd
end
end
function _node:read(fd, count)
checkArg(1, fd, "table")
checkArg(2, count, "number")
return self.fs.read(fd, count)
end
function _node:write(fd, data)
checkArg(1, fd, "table")
checkArg(2, data, "string")
return self.fs.write(fd, data)
end
function _node:seek(fd, whence, offset)
checkArg(1, fd, "table")
checkArg(2, whence, "string")
checkArg(3, offset, "number")
return self.fs.seek(fd, whence, offset)
end  function _node:flush() end
function _node:close(fd)
checkArg(1, fd, "table")
if fd.index then return true end
return self.fs.close(fd)
end
local fs_mt = { __index = _node }  k.register_fstype("managed", function(comp)
if type(comp) == "table" and comp.type == "filesystem" then
return setmetatable({fs = comp,
address = comp.address:sub(1,8)}, fs_mt)
elseif type(comp) == "string" and component.type(comp) == "filesystem" then
return setmetatable({fs = component.proxy(comp),
address = comp:sub(1,8)}, fs_mt)
end
end)
k.register_fstype("tmpfs", function(t)
if t == "tmpfs" then
local node = k.fstypes.managed(computer.tmpAddress())
node.address = "tmpfs"
return node
end
end)
end--
printk(k.L_INFO, "fs/simplefs")
do
local _node = {}
local structures = {
superblock = {
pack = "<c4BBI2I2I3I3c19",
names = {"signature", "flags", "revision", "nl_blocks", "blocksize", "blocks", "blocks_used", "label"}
},
nl_entry = {
pack = "<I2I2I2I2I2I4I8I8I2I2c94",
names = {"flags", "datablock", "next_entry", "last_entry", "parent", "size", "created", "modified", "uid", "gid", "fname"}
},
}
local constants = {
superblock = 0,
blockmap = 1,
namelist = 2,
F_TYPE = 0xF000,
SB_MOUNTED = 0x1
}
local function pack(name, data)
local struct = structures[name]
local fields = {}
for i=1, #struct.names do
fields[i] = data[struct.names[i]]
if fields[i] == nil then
error("pack:structure " .. name .. " missing field " .. struct.names[i])
end
end
return string.pack(struct.pack, table.unpack(fields))
end
local function unpack(name, data)
local struct = structures[name]
local ret = {}
local fields = table.pack(string.unpack(struct.pack, data))
for i=1, #struct.names do
ret[struct.names[i]] = fields[i]
if fields[i] == nil then
error("unpack:structure " .. name .. " missing field " .. struct.names[i])
end
end
return ret
end  local function time()    return math.floor((os.time() * 1000/60/60 - 6000) * 50)
end
local null = "\0"
local split = k.split_path  function _node:readBlock(n)
local data = ""
for i=1, self.bstosect do
data = data .. self.drive.readSector(i+n*self.bstosect)
end
return data
end
function _node:writeBlock(n, d)
for i=1, self.bstosect do
local chunk = d:sub(self.sect*(i-1)+1,self.sect*i)
self.drive.writeSector(i+n*self.bstosect, chunk)
end
end
function _node:readSuperblock()
self.sblock = unpack("superblock", self.drive.readSector(1))
self.sect = self.drive.getSectorSize()
self.bstosect = self.sblock.blocksize / self.sect
end
function _node:writeSuperblock()
self:writeBlock(constants.superblock, pack("superblock", self.sblock))
end
function _node:readBlockMap()
local data = self:readBlock(constants.blockmap)
self.bmap = {}
local x = 0
for c in data:gmatch(".") do
c = c:byte()
for i=0, 7 do
self.bmap[x] = (c & 2^i ~= 0) and 1 or 0
x = x + 1
end
end
end
function _node:writeBlockMap()
local data = ""
for i=0, #self.bmap, 8 do
local c = 0
for j=0, 7 do
c = c | (2^j)*self.bmap[i+j]
end
data = data .. string.char(c)
end
self:writeBlock(constants.blockmap, data)
end
function _node:allocateBlocks(count)
local index = 0
local blocks = {}
for i=1, count do
repeat
index = index + 1
until self.bmap[index] == 0 or not self.bmap[index]
blocks[#blocks+1] = index
self.bmap[index] = 1
self:writeBlock(index, null:rep(self.sblock.blocksize))
end
if index > #self.bmap then error("out of space") end
self.sblock.blocks_used = self.sblock.blocks_used + #blocks
return blocks
end
function _node:freeBlocks(blocks)
for i=1, #blocks do
self.sblock.blocks_used = self.sblock.blocks_used - self.bmap[blocks[i]]
self.bmap[blocks[i]] = 0
end
end
function _node:readNamelistEntry(n)
local offset = n * 128 % self.sblock.blocksize + 1
local block = math.floor(n/8)    local blockData = self:readBlock(block+constants.namelist)
local namelistEntry = blockData:sub(offset, offset + 127)
local ent = unpack("nl_entry", namelistEntry)
ent.fname = ent.fname:gsub("\0", "")
return ent
end
function _node:writeNamelistEntry(n, ent)
local data = pack("nl_entry", ent)
local offset = n * 128 % self.sblock.blocksize
local block = math.floor(n/8)    local blockData = self:readBlock(block+constants.namelist)
blockData = blockData:sub(0, offset)..data..blockData:sub(offset + 129)
self:writeBlock(block+constants.namelist, blockData)
end
function _node:allocateNamelistEntry()
for i=1, self.maxKnown do
if not self.knownNamelist[i] then
self.knownNamelist[i] = true
return i
end
end
local blockData
local lastBlock = 0
for n=0, self.sblock.nl_blocks*8 do
local offset = n * 128 % self.sblock.blocksize + 1
local block = math.floor(n/8)
if block ~= lastBlock then blockData = nil end
blockData = blockData or self:readBlock(block+constants.namelist)
local namelistEntry = blockData:sub(offset, offset + 127)
local v = unpack("nl_entry", namelistEntry)
self.knownNamelist[n] = true
self.maxKnown = math.max(self.maxKnown, n)
if v.flags == 0 then
return n
end
end
error("no free namelist entries")
end
function _node:freeNamelistEntry(n, evenifdir)
local entry = self:readNamelistEntry(n)
if entry.flags & constants.F_TYPE == k.FS_DIR then
if entry.datablock ~= 0 then
return nil, k.errno.ENOTEMPTY
elseif not evenifdir then
return nil, k.errno.EISDIR
end
end
self.knownNamelist[n] = false
entry.flags = 0    if entry.next_entry ~= 0 then
local nextEntry = self:readNamelistEntry(entry.next_entry)
nextEntry.last_entry = entry.last_entry
self:writeNamelistEntry(entry.next_entry, nextEntry)
end
if entry.last_entry ~= 0 then
local nextEntry = self:readNamelistEntry(entry.last_entry)
nextEntry.next_entry = entry.next_entry
self:writeNamelistEntry(entry.last_entry, nextEntry)
end    local parent = self:readNamelistEntry(entry.parent)
if parent.datablock == n then
parent.datablock = entry.next_entry
self:writeNamelistEntry(entry.parent, parent)
end
local db = entry.datablock
entry.datablock = 0
self:writeNamelistEntry(n, entry)
entry.datablock = db
if not self.opened[n] then
self:freeDataBlocks(n, entry)
else
self.removing[n] = entry
end
return true
end
function _node:freeDataBlocks(n, entry)    local datablock = entry.datablock
local final, blocks = self:getBlock(entry, 0xFFFFFF, false, true, {})
blocks[#blocks+1] = final
self:freeBlocks(blocks)
end
function _node:getNext(ent)
if (not ent) or ent.next_entry == 0 then
return nil
end
return self:readNamelistEntry(ent.next_entry), ent.next_entry
end
function _node:getLast(ent)
if (not ent) or ent.last_entry == 0 then
return nil
end
return self:readNamelistEntry(ent.last_entry), ent.last_entry
end
function _node:resolve(path, offset, startdirdb)
offset = offset or 0
startdirdb = startdirdb or 0
local segments = split(path)
local dir = self:readNamelistEntry(startdirdb)
local current, cid = dir, startdirdb
if #segments == offset then return current, cid end
for i=1, #segments - offset do
current, cid = self:readNamelistEntry(current.datablock), current.datablock
while current and current.fname ~= segments[i] do
current, cid = self:getNext(current)
end
if not current then
return nil, k.errno.ENOENT
end
end
return current, cid
end
function _node:mkfileentry(name, flags, uid, gid)
local segments = split(name)
local insurance = self:resolve(name)
if insurance then
return nil, k.errno.EEXIST
end
local parent, pid = self:resolve(name, 1)
if not parent then return nil, pid end
if parent.flags & constants.F_TYPE ~= k.FS_DIR then
return nil, k.errno.ENOTDIR
end
local last_entry = 0
local n = self:allocateNamelistEntry()
if parent.datablock == 0 then
parent.datablock = n
self:writeNamelistEntry(pid, parent)
else
local first = self:readNamelistEntry(parent.datablock)
local last, index = first, parent.datablock
repeat
local next_entry, next_index = self:getNext(last)
if next_entry then last, index = next_entry, next_index end
until not next_entry
last.next_entry = n
last_entry = index
self:writeNamelistEntry(index, last)
end
local entry = {
flags = flags,
datablock = 0,
next_entry = 0,
last_entry = last_entry,
parent = pid,
size = 0,
created = time(),
modified = time(),
uid = uid or 0,
gid = gid or 0,
fname = segments[#segments]
}
self:writeNamelistEntry(n, entry)
return entry, n
end
function _node:getBlock(ent, pos, create, get_all, blocks)
local current = ent.datablock
local count = math.ceil((pos+1) / (self.sblock.blocksize-3))
local all = {}
for i=1, count-1 do
local nxt, data = blocks[current]
if not nxt then
data = self:readBlock(current)
nxt = ("<I3"):unpack(data:sub(-3))
end
if nxt == 0 then
if create then
nxt = self:allocateBlocks(1)[1]
data = data:sub(1, self.sblock.blocksize-3)..("<I3"):pack(nxt)
self:writeBlock(current, data)
blocks[current] = nxt
else
blocks[current] = nxt
if get_all then return current, all end
return current
end
end
all[#all+1] = current
blocks[current] = nxt
current = nxt
end
if get_all then return current, all end
return current
end
function _node:exists(path)
checkArg(1, path, "string")
return not not self:resolve(path)
end
function _node:stat(path)
checkArg(1, path, "string")
local entry, eid = self:resolve(path)
if not entry then return nil, eid end
return {
dev = -1,
ino = eid,
mode = entry.flags,
nlink = 1,
uid = entry.uid,
gid = entry.gid,
rdev = -1,
size = entry.size,
blksize = self.sblock.blocksize,
ctime = entry.created,
atime = time(),
mtime = entry.modified,
}
end
function _node:chmod(path, mode)
checkArg(1, path, "string")
checkArg(2, mode, "number")
local entry, eid = self:resolve(path)
if not entry then return nil, eid end
entry.flags = (entry.flags & constants.F_TYPE) | (mode & 0xFFF)
self:writeNamelistEntry(eid, entry)
return true
end
function _node:chown(path, uid, gid)
checkArg(1, path, "string")
checkArg(2, uid, "number")
checkArg(3, gid, "number")
local entry, eid = self:resolve(path)
if not entry then return nil, eid end
entry.uid = uid
entry.gid = gid
self:writeNamelistEntry(eid, entry)
return true
end  function _node:unlink(name)
checkArg(1, name, "string")
local segments = split(name)
local entry, eid = self:resolve(name)
if not entry then return nil, k.errno.enoent end
printk(k.L_DEBUG, "rm %d", eid)
return self:freeNamelistEntry(eid, true)
end
function _node:mkdir(path, mode)
checkArg(1, path, "string")
checkArg(2, mode, "number")
local uid = k.syscalls and k.syscalls.geteuid() or 0
local gid = k.syscalls and k.syscalls.getegid() or 0
return self:mkfileentry(path, k.FS_DIR | mode, uid, gid)
end
function _node:opendir(path)
checkArg(1, path, "string")
local entry, eid = self:resolve(path)
if not entry then return nil, eid end
if entry.flags & constants.F_TYPE ~= k.FS_DIR then
return nil, k.errno.ENOTDIR
end
local current, cid = self:readNamelistEntry(entry.datablock),entry.datablock
local fd = {
entry = entry, eid = eid, dir = true, current = current, cid = cid,
}
self.opened[eid] = (self.opened[eid] or 0) + 1
self.fds[fd] = true
return fd
end
function _node:readdir(dirfd)
checkArg(1, dirfd, "table")
if dirfd.closed then return nil, k.errno.EBADF end
if not (dirfd.dir) then
error("bad argument #1 to 'readdir' (expected dirfd)")
end
local old, oldid = dirfd.current, dirfd.cid
dirfd.current, dirfd.cid = self:getNext(dirfd.current)
if (not old) or #old.fname == 0 then return end
return { inode = oldid, name = old.fname }
end
function _node:open(file, mode, numeric)
local entry, eid = self:resolve(file)
if not entry then
if mode == "w" then
local uid = k.syscalls and k.syscalls.geteuid() or 0
local gid = k.syscalls and k.syscalls.getegid() or 0
entry, eid = self:mkfileentry(file, k.FS_REG | numeric,
uid, gid)
end
if not entry then
return nil, eid
end
end
if entry.flags & constants.F_TYPE == k.FS_DIR then
return nil, k.errno.EISDIR
end
local pos = 0
if mode == "w" then
local final, blocks = self:getBlock(entry, 0xFFFFFF, false, true, {})
blocks[#blocks+1] = final
self:freeBlocks(blocks)
entry.datablock = self:allocateBlocks(1)[1]
entry.size = 0
elseif mode == "a" then
pos = entry.size
end
local fd = {
entry = entry, eid = eid, pos = 0, mode = mode, blocks = {}
}
self.opened[fd.eid] = (self.opened[fd.eid] or 0) + 1
self.fds[fd] = true
return fd
end
function _node:read(fd, len)
checkArg(1, fd, "table")
checkArg(2, len, "number")
if fd.closed then return nil, k.errno.EBADF end
if fd.dir then error("bad argument #1 to 'read' (got dirfd)") end
if fd.pos < fd.entry.size then
len = math.min(len, fd.entry.size - fd.pos)
local offset = fd.pos % (self.sblock.blocksize-3) + 1
local data = ""
repeat
local blockID = self:getBlock(fd.entry, fd.pos, nil, nil,
fd.blocks)
local block = self:readBlock(blockID)
local read = block:sub(offset, math.min(#block-3, offset+len-1))
data = data .. read
fd.pos = fd.pos + #read
offset = fd.pos % (self.sblock.blocksize-3) + 1
len = len - #read
until len <= 0
return data
end
end
function _node:write(fd, data)
checkArg(1, fd, "table")
checkArg(2, data, "string")
if fd.closed then return nil, k.errno.EBADF end
if fd.dir then error("bad argument #1 to 'write' (got dirfd)") end
local offset = fd.pos % (self.sblock.blocksize-3)
repeat
local blockID = self:getBlock(fd.entry, fd.pos, true, nil,
fd.blocks)
local block = self:readBlock(blockID)
local write = data:sub(1, (self.sblock.blocksize-3) - offset)
data = data:sub(#write+1)
fd.pos = fd.pos + #write
fd.entry.size = math.max(fd.entry.size, fd.pos)
if #write == self.sblock.blocksize-3 then
block = write .. block:sub(-3)
else
block = block:sub(0, offset) .. write ..
block:sub(offset + #write + 1)
end
self:writeBlock(blockID, block)
offset = fd.pos % (self.sblock.blocksize-3)
until #data == 0
return true
end
function _node:seek(fd, whence, offset)
checkArg(1, fd, "table")
checkArg(2, whence, "string")
checkArg(3, offset, "number")
if fd.closed then return nil, k.errno.EBADF end
if fd.dir then error("bad argument #1 to 'seek' (got dirfd)") end
local pos =
((whence == "set" and 0) or
(whence == "cur" and fd.pos) or
(whence == "end" and fd.entry.size)) + offset
if fd.mode == "w" then
fd.entry.size = math.max(0, math.min(fd.entry.size, pos))
self:getBlock(fd.entry, pos, true, nil, fd.blocks)
end
fd.pos = math.max(0, math.min(fd.entry.size, pos))
return fd.pos
end  function _node:flush() end
function _node:close(fd)
checkArg(1, fd, "table")
if fd.closed then return nil, k.errno.EBADF end
fd.closed = true
self.fds[fd] = nil
self.opened[fd.eid] = self.opened[fd.eid] - 1
if self.opened[fd.eid] <= 0 and self.removing[fd.eid] then
self:freeDataBlocks(fd.eid, self.removing[fd.eid])
self.removing[fd.eid] = nil
else
if fd.mode == "w" then
fd.entry.modified = time()
self:writeNamelistEntry(fd.eid, fd.entry)
end
end
if self.opened[fd.eid] <= 0 then self.opened[fd.eid] = nil end
return true
end
function _node:sync()
self:writeSuperblock()
self:writeBlockMap()
for fd in pairs(self.fds) do
self:writeNamelistEntry(fd.eid, fd.entry)
end
end
function _node:mount()
if self.mounts == 0 then
self:readSuperblock()
if self.sblock.flags & constants.SB_MOUNTED ~= 0 then
printk(k.L_WARNING, "simplefs: filesystem was not cleanly unmounted")
end
self.sblock.flags = self.sblock.flags | constants.SB_MOUNTED
self.address = self.sblock.label:gsub(null, "")
if #self.address == 0 then self.address = self.drive.address:sub(1,8) end
self:writeSuperblock()
self:readBlockMap()
end
self.mounts = self.mounts + 1
end
function _node:unmount()
self.mounts = self.mounts - 1
if self.mounts == 0 then
self.sblock.flags = self.sblock.flags ~ constants.SB_MOUNTED
end
self:writeSuperblock()
self:writeBlockMap()
end
local function newnode(drive)
return setmetatable({
mounts = 0,
opened = {},
fds = {},
removing = {},
sblock = {},
bmap = {},
knownNamelist = {},
drive = drive,
maxKnown = 0,}, {__index = _node})
end
k.register_fstype("simplefs", function(comp)
if type(comp) == "string" and component.type(comp) == "drive" then
comp = component.proxy(comp)
end
if type(comp) == "table" and comp.type == "drive" then
local sblock = unpack("superblock",comp.readSector(1))
if sblock.signature == "\x1bSFS" then
return newnode(comp)
end
end
end)
end
printk(k.L_INFO, "fs/rootfs")
do
local function panic_with_err(dev, err)
panic("Cannot mount root filesystem from " .. tostring(dev)
.. ": " .. ((err == k.errno.ENODEV and "No such device") or
(err == k.errno.EUNATCH and "Protocol driver not attached") or
"Unknown error " .. tostring(err)))
end
local address  if k.cmdline.root then
address = k.cmdline.root
elseif computer.getBootAddress then    address = computer.getBootAddress()
else    local mounted
for addr in component.list("filesystem") do
if addr ~= computer.tmpAddress() then
address = addr
mounted = true
break
end
end
if not mounted then
for addr in component.list("drive") do
address = addr
break
end
end
end
if not address then
panic("No valid root filesystem found")
end  if address:sub(-2,-2) == "," then
local addr, part = address:sub(1, -3), address:sub(-1)
local matches = k.devfs.get_by_type("blkdev")
for i=1, #matches do
local match = matches[i]
if match.device.fs and match.device.fs.address and
match.device.fs.address:sub(1,#addr) == addr then        address = match.device.address..part
printk(k.L_NOTICE, "resolved rootfs=%s from %s",
match.device.address..part, address)
break
end
end
end
if address == "mtar" then
address = k.fstypes.managed(_G.mtarfs)
_G.mtarfs = nil
end
local success, err = k.mount(address, "/")
if not success then
panic_with_err((component.type(address) or "unknown").." "..address, err)
end
end
printk(k.L_INFO, "fs/tty")
do
local ttyn = 1  function k.init_ttys()
local usedScreens = {}
local gpus, screens = {}, {}
for gpu in component.list("gpu", true) do
gpus[#gpus+1] = gpu
end
for screen in component.list("screen", true) do
screens[#screens+1] = screen
end
table.sort(gpus)
table.sort(screens)
for _, gpu in ipairs(gpus) do
for _, screen in ipairs(screens) do
if not usedScreens[screen] then
usedScreens[screen] = true
printk(k.L_DEBUG, "registering tty%d on %s,%s", ttyn,
gpu:sub(1,6), screen:sub(1,6))
local cdev = k.chardev.new(k.open_tty(gpu, screen), "tty")
cdev.stream.name = string.format("tty%d", ttyn)
k.devfs.register_device(string.format("tty%d", ttyn), cdev)
ttyn = ttyn + 1
break
end
end
end
end
end
printk(k.L_INFO, "fs/component")
do  local provider = {}  local function resolve_address(addr, ctype)
if not addr then return end
for check in component.list(ctype, true) do
if check:sub(1, #addr) == addr then
return check
end
end
end
function provider:exists(path)
checkArg(1, path, "string")
local ctype, caddr = table.unpack(k.split_path(path))
if caddr then
return not not component.list(ctype,
true)[resolve_address(caddr) or caddr]
elseif ctype then
return not not component.list(ctype, true)()
else
return true
end
end
function provider:stat(path)
checkArg(1, path, "string")
local ctype, caddr = table.unpack(k.split_path(path))
if (not caddr) and component.list(ctype, true)() or not ctype then
return {
dev=-1, ino=-1, mode=0x41ED, nlink=1, uid=0, gid=0,
rdev=-1, size=0, blksize=2048, mtime=0, atime=0, ctime=0,
}
end
if component.list(ctype, true)[resolve_address(caddr) or caddr] then
return {
dev=-1, ino=-1, mode=0x61A4, nlink=1, uid=0, gid=0,
rdev=-1, size=0, blksize=2048, mtime=0, atime=0, ctime=0
}
end
return nil, k.errno.ENOENT
end  function provider:open(path)
checkArg(1, path, "string")
local ctype, caddr = table.unpack(k.split_path(path))
if not (ctype and caddr) then return nil, k.errno.ENOENT end
local proxy = component.proxy(resolve_address(caddr) or caddr)
if (not proxy) or proxy.type ~= ctype then
return nil, k.errno.ENOENT
end
return { proxy = proxy }
end
local ioctls = {}
function ioctls.doc(fd, method)
checkArg(3, method, "string")
return component.doc(fd.proxy.address, method)
end
function ioctls.invoke(fd, call, ...)
checkArg(3, call, "string")
if not fd.proxy[call] then
return nil, k.errno.EINVAL
end
return fd.proxy[call](...)
end
function ioctls.methods(fd)
return component.methods(fd.proxy.address)
end
function ioctls.type(fd)
return fd.proxy.type
end
function ioctls.slot(fd)
return fd.proxy.slot
end
function ioctls.fields(fd)
return component.fields(fd.proxy.address)
end
function ioctls.address(fd)
return fd.proxy.address
end
function provider.ioctl(fd, method, ...)
checkArg(1, fd, "table")
checkArg(2, method, "string")
if fd.iterator then return nil, k.errno.EBADF end
if ioctls[method] then
return ioctls[method](fd, ...)
else
return nil, k.errno.ENOTTY
end
end
function provider:opendir(path)
checkArg(1, path, "string")
local segments = k.split_path(path)
if #segments > 1 then return nil, k.errno.ENOENT end
if #segments == 0 then
local types, _types = {}, {}
for _, ctype in component.list() do
if type(ctype) == "string" then _types[ctype] = true end
end
for ctype in pairs(_types) do types[#types+1] = ctype end
local i = 0
return { iterator = function()
i = i + 1
return types[i]
end }
else
local iter = component.list(segments[1], true)
return { iterator = function()
local addr = iter()
if addr then return addr:sub(1, 8) end
end }
end
end
function provider:readdir(dirfd)
checkArg(1, dirfd, "table")
if not dirfd.iterator then return nil, k.errno.EBADF end
local name = dirfd.iterator()
if name then
return { inode = -1, name = name }
end
end
function provider:close() end
provider.address = "components"
provider.type = "directory"
k.devfs.register_device("components", provider)
end
printk(k.L_INFO, "fs/proc")
do
local provider = {}
local files = {self = true}
files.meminfo = { data = function()
local avgfree = 0
for i=1, 10, 1 do avgfree = avgfree + computer.freeMemory() end
avgfree = avgfree / 10
local total, free = math.floor(computer.totalMemory() / 1024),
math.floor(avgfree / 1024)
local used = total - free
return string.format(
"MemTotal: %d kB\nMemUsed: %d kB\nMemAvailable: %d kB\n",
total, used, free)
end }
files.filesystems = { data = function()
local result = {}
for fs, rec in pairs(k.fstypes) do
if rec(fs) then fs = fs .. " (nodev)" end
result[#result+1] = fs
end
return table.concat(result, "\n") .. "\n"
end }
files.cmdline = { data = k.original_cmdline .. "\n" }
files.uptime = { data = function()
return tostring(computer.uptime()) .. "\n"
end }
files.mounts = { data = function()
local result = {}
for path, node in pairs(k.mounts()) do
result[#result+1] = string.format("%s %s %s", node.address, path,
node.mountType)
end
return table.concat(result, "\n") .. "\n"
end }
files.config = { data = [==[COMPONENT_TUNNEL=n
COMPONENT_TRACTORBEAM=n
DEFAULT_HOSTNAME=localhost
MEM_THRESHOLD=1024
COMPONENT_TRANSPOSER=n
NET_MTEL=n
COMPONENT_INTERNET=y
COMPONENT_CARDDOCK=y
NET_HTTP=y
PER_PROC_SANDBOX=n
PART_ENABLE=y
BUFFER_SIZE=1024
FS_MANAGED=y
TTY_ENABLE_GPU=y
COMPONENT_ACCESSPOINT=n
COMPONENT_CRAFTING=n
NET_GERT=n
NET_TCP=y
NET_ENABLE=y
COMPONENT_INVENTORYCONTROLLER=n
PROCFS_EVENT=y
FS_SFS=y
PART_OSDI=y
COMPONENT_DATABASE=n
FS_COMPONENT=y
COMPONENT_EXPERIENCE=n
COMPONENT_NETSPLITTER=n
COMPONENT_DRIVE=y
PREEMPT_MODE=fast
COMPONENT_PISTON=n
FS_PROC=y
PART_MTPT=y
COMPONENT_HOLOGRAM=n
BIT32=n
COMPONENT_3DPRINTER=n
COMPONENT_WORLDSENSOR=n
COMPONENT_ROBOT=n
COMPONENT_MODEM=n
COMPONENT_CHUNKLOADER=n
COMPONENT_LEASH=n
COMPONENT_FILESYSTEM=y
EXEC_LUA=y
EXEC_SHEBANG=y
EXEC_CLE=n
COMPONENT_MOTIONSENSOR=n
COMPONENT_SIGN=n
COMPONENT_TANKCONTROLLER=n
COMPONENT_GEOLYZER=n
COMPONENT_DATACARD=y
PROCFS_CONFIG=y
COMPONENT_DEBUG=n
COMPONENT_MICROCONTROLLER=n
COMPONENT_NAVIGATION=n
COMPONENT_EEPROM=y
PROCFS_BINFMT=n
COMPONENT_GENERATOR=n
COMPONENT_REDSTONE=n
]==] }
files.events = {
data = function() return "" end,
ioctl = function(method, sig, a, ...)
if method == "register" then
local proc = k.current_process()
local id = k.add_signal_handler(sig, a)
proc.handlers[id] = true
return id
elseif method == "deregister" then
local proc = k.current_process()
if not proc.handlers[sig] then
return nil, k.errno.EINVAL
end
proc.handlers[sig] = nil
k.remove_signal_handler(sig)
return true
elseif method == "push" then
return k.pushSignal(sig, a, ...)
elseif method == "send" then
checkArg(2, sig, "number")
checkArg(3, a, "string")
local proc = k.get_process(sig)
local current = k.current_process()
if not proc then
return nil, k.errno.EINVAL
end
if current.euid ~= proc.uid and current.egid ~= proc.gid
and current.euid ~= 0 then
return nil, k.errno.EPERM
end
proc.queue[#proc.queue+1] = table.pack(a, ...)
return true
else
return nil, k.errno.ENOTTY
end
end
}
local function path_to_node(path, narrow)
local segments = k.split_path(path)
if #segments == 0 then
local flist = {}
for _, pid in pairs(k.get_pids()) do
flist[#flist+1] = pid
end
for k in pairs(files) do
flist[#flist+1] = k
end
return flist
end
if segments[1] == "self" then
segments[1] = k.current_process().pid
end    if segments[2] == "fds" then
if #segments > 3 then
return nil, k.errno.ENOENT
elseif #segments == 3 then
if narrow == 1 then return nil, k.errno.ENOTDIR end
end
end
if files[segments[1]] then
if narrow == 1 then return nil, k.errno.ENOTDIR end
if #segments > 1 then return nil, k.errno.ENOENT end
return files[segments[1]], nil, true
elseif tonumber(segments[1]) then
local proc = k.get_process(tonumber(segments[1]))
local field = proc
for i=2, #segments, 1 do
field = field[tonumber(segments[i]) or segments[i]]
if field == nil then return nil, k.errno.ENOENT end
end
return field, proc
end
return nil, k.errno.ENOENT
end
function provider:exists(path)
checkArg(1, path, "string")
return path_to_node(path) ~= nil
end
function provider:stat(path)
checkArg(1, path, "string")
local node, proc, isf = path_to_node(path)
if node == nil then return nil, proc end
if type(node) == "table" and not isf then
return {
dev = -1, ino = -1, mode = 0x41ED, nlink = 1, uid = 0, gid = 0,
rdev = -1, size = 0, blksize = 2048
}
end
return {
dev = -1, ino = -1, mode = 0x61A4, nlink = 1,
uid = proc and proc.uid or 0, gid = proc and proc.gid or 0,
rdev = -1, size = 0, blksize = 2048
}
end
local function to_fd(dat)
dat = tostring(dat)
local idx = 0
return k.fd_from_rwf(function(_, n)
local nidx = math.min(#dat + 1, idx + n)
local chunk = dat:sub(idx, nidx)
idx = nidx
return #chunk > 0 and chunk
end)
end
function provider:open(path)
checkArg(1, path, "string")
local node, proc = path_to_node(path, 0)
if node == nil then return nil, proc end
if (not proc) and type(node) == "table" and node.data then
local data = type(node.data) == "function" and node.data() or node.data
return { file = to_fd(data), ioctl = node.ioctl }
elseif type(node) ~= "table" then
return { file = to_fd(node), ioctl = function()end }
else
return nil, k.errno.EISDIR
end
end
function provider:opendir(path)
checkArg(1, path, "string")
local node, proc = path_to_node(path, 1)
if node == nil then return nil, proc end
if type(node) == "table" then
if not proc then return { i = 0, files = node } end
local flist = {}
for k in pairs(node) do
flist[#flist+1] = tostring(k)
end
return { i = 0, files = flist }
else
return nil, k.errno.ENOTDIR
end
end
function provider:readdir(dirfd)
checkArg(1, dirfd, "table")
if dirfd.closed then return nil, k.errno.EBADF end
if not (dirfd.i and dirfd.files) then return nil, k.errno.EBADF end
dirfd.i = dirfd.i + 1
if dirfd.files[dirfd.i] then
return { inode = -1, name = tostring(dirfd.files[dirfd.i]) }
end
end
function provider:read(fd, n)
checkArg(1, fd, "table")
checkArg(1, n, "number")
if fd.closed then return nil, k.errno.EBADF end
if not fd.file then return nil, k.errno.EBADF end
return fd.file:read(n)
end
function provider:close(fd)
checkArg(1, fd, "table")
fd.closed = true
end
function provider.ioctl(fd, method, ...)
checkArg(1, fd, "table")
checkArg(2, method, "string")
if fd.closed then return nil, k.errno.EBADF end
if not fd.file then return nil, k.errno.EBADF end
if not fd.ioctl then return nil, k.errno.ENOSYS end
return fd.ioctl(method, ...)
end
provider.address = "procfs"
k.register_fstype("procfs", function(x)
return x == "procfs" and provider
end)
end
printk(k.L_INFO, "net/main")
do
local hostname = "localhost"
k.protocols = {}
function k.gethostname()
return hostname
end
function k.sethostname(name)
checkArg(1, name, "string")
hostname = name
return hostname
end
local function separate(path)
local proto = path:match("([^:/]+)://")
if not proto then return end
local segments = { proto }
for part in path:sub(#proto+3):gmatch("[^/]+") do
segments[#segments+1] = part
end
return segments
end  function k.request(path)
checkArg(1, path, "string")
local parts = separate(path)
if not parts then
return nil, k.errno.EINVAL
end
local protocol = k.protocols[parts[1]]
if not protocol then
return nil, k.errno.ENOPROTOOPT
end
local request, errno, detail = protocol(parts)
if not request then
return nil, errno, detail
end
local stream = k.buffer_from_stream(request, "rw")
return { fd = stream, node = stream, refs = 1 }
end
end--@[{depend("Minitel/GERTi support", "COMPONENT_MODEM", "NET_MTEL", "NET_GERT")}]
printk(k.L_INFO, "net/http")
do
local protocol = {}
local request = {}
function request:read(n)
local data = self.fd.read(n)
if not data then
return nil, k.errno.EBADF
end
return data
end
function request:write()
return nil, k.errno.EBADF
end
function request:close()
self.fd.close()
end
function protocol.request(parts)
local http = table.remove(parts, 1)
local url = http .. "://" .. table.concat(parts, "/")
local internet = component.list("internet")()
if not internet then
return nil, k.errno.ENODEV
end
printk(k.L_DEBUG, url)
local handle, err = component.invoke(internet, "request", url)
if not handle then
return nil, k.errno.ENOENT, err
end
while not handle.finishConnect() do
coroutine.yield(0)
end
return setmetatable({fd = handle}, {__index = request})
end
k.protocols.http = protocol.request
k.protocols.https = protocol.request
end
printk(k.L_INFO, "net/tcp")
do
local protocol = {}
local request = {}
function request:read(n)
local data = self.fd.read(n)
if not data then
return nil, k.errno.EBADF
end
return data
end
function request:write(data)
if not self.fd.write(data) then
return nil, k.errno.EBADF
end
return true
end
function request:close()
self.fd.close()
end
function protocol.request(parts)
table.remove(parts, 1)    local url = "https://" .. table.concat(parts, "/")
local internet = component.list("internet")()
if not internet then
return nil, k.errno.ENODEV
end
local handle = component.invoke(internet, "request", url)
while not handle.finishConnect() do
coroutine.yield(0)
end
return setmetatable({fd = handle}, {__index = request})
end
k.protocols.tcp = protocol
end--
printk(k.L_INFO, "tty")
do  local NUL = '\x00'
local BEL = '\x07'
local BS  = '\x08'
local HT  = '\x09'
local LF  = '\x0a'
local VT  = '\x0b'
local FF  = '\x0c'
local CR  = '\x0d'  local SO  = '\x0e'
local SI  = '\x0f'
local CAN = '\x18'
local SUB = '\x1a'
local ESC = '\x1b'  local DEL = '\x7f'  local CSI = '\x9B'
local MODE_NORMAL = 0
local MODE_ESC = 1
local MODE_CSI = 2
local MODE_DSAT = 3
local MODE_CHARSET = 4
local MODE_G0 = 5
local MODE_G1 = 6
local MODE_OSC = 7
local control_chars = {
[NUL] = true,
[BEL] = true,
[BS] = true,
[HT] = true,
[LF] = true,
[VT] = true,
[FF] = true,
[CR] = true,
[SO] = true,
[SI] = true,
[CAN] = true,
[SUB] = true,
[ESC] = true,
[DEL] = true,
[CSI] = true,
}
local scancode_lookups = {
[200] = "A",
[208] = "B",
[205] = "C",
[203] = "D"
}
local colors = {
0x000000,
0xaa0000,
0x00aa00,
0xaaaa00,
0x0000aa,
0xaa00aa,
0x00aaaa,
0xaaaaaa,    0x555555,
0xff5555,
0x55ff55,
0xffff55,
0x5555ff,
0xff55ff,
0x55ffff,
0xffffff
}  local MAX_GMATCH = 500
local gmatch, sub = string.gmatch, string.sub
local function get_iter(str)
if #str < MAX_GMATCH then
return gmatch(str, "()(.)")
else
local n, len = 0, #str
return function()
n = n + 1
if n <= len then return n, sub(str, n, n) end
end
end
end
function k.open_tty(gpu, screen)
checkArg(1, gpu, "string", "table")
checkArg(2, screen, "string", "nil")
if type(gpu) == "string" then gpu = component.proxy(gpu) end
if screen then gpu.bind(screen) end
local w, h = gpu.getResolution()
local mode = MODE_NORMAL
local seq = {}
local wbuf, rbuf = "", ""
local tab_width = 8
local question = false
local autocr, reverse, insert, display, mousereport, cursor, altcursor, autowrap
= true, false, false, false, false, true, false, true
local cx, cy, scx, scy = 1, 1
local st, sb = 1, h
local fg, bg = colors[8], colors[1]
local save = {fg = fg, bg = bg, autocr = autocr, reverse = reverse, display = display, insert = insert,
mousereport = mousereport, altcursor = altcursor, cursor = cursor, autowrap = autowrap}
local cursorvisible = false
local shouldchange = false
local keyboards = {}
local new = {}
for _, kbaddr in pairs(component.invoke(gpu.getScreen(), "getKeyboards")) do
keyboards[kbaddr] = true
end
local function setcursor(v)
if cursorvisible ~= v then
shouldchange = true
cursorvisible = v
local c, cfg, cbg = gpu.get(cx, cy)
gpu.setBackground(cfg)
gpu.setForeground(cbg)
gpu.set(cx, cy, c)
end
end
local function scroll(n)
if n < 0 then
gpu.copy(1, st, w, sb+n, 0, -n)
gpu.fill(1, 1, w, -n, " ")
else
gpu.copy(1, st+n, w, sb, 0, -n)
gpu.fill(1, sb - n + 1, w, n, " ")
end
end
local function corral()
cx = math.max(1, cx)
if cx > w and autowrap then
cx = 1
cy = cy + 1
end
if cy > sb then
scroll(cy - sb)
cy = sb
elseif cy < st then
scroll(-(st - cy))
cy = st
end
end
local function clamp()
cx, cy = math.min(w, math.max(1, cx)), math.min(h, math.max(1, cy))
end
local function flush()
gpu.setForeground(reverse and bg or fg)
gpu.setBackground(reverse and fg or bg)
repeat
local towrite = sub(wbuf, 1, w-cx+1)
wbuf = sub(wbuf, #towrite+1)
if insert then
gpu.copy(cx, cy, w, 1, #towrite, 0)
end
gpu.set(cx, cy, towrite)
cx = cx + #towrite
corral()
until #wbuf == 0 or not autowrap
if new.discipline and #rbuf > 0 then
new.discipline:processInput(rbuf)
rbuf = ""
end
end
local function write(_, str)
if #str == 0 then return end
setcursor(false)
if shouldchange then
gpu.setForeground(reverse and bg or fg)
gpu.setBackground(reverse and fg or bg)
end
local pi = 1
for i, c in get_iter(str) do
if control_chars[c] then
if pi > 0 then
wbuf = wbuf .. sub(str, pi, i-1)
flush()
pi = -1
end          if c == BEL then
computer.beep()
elseif c == BS then
cx = cx - 1
corral()
elseif c == HT then
cx = tab_width * math.floor((cx + tab_width + 1) / tab_width) - 1
corral()
elseif c == LF or c == VT or c == FF then
if autocr then cx = 1 end
cy = cy + 1
corral()
elseif c == CR then
cx = 1
elseif c == CAN or c == SUB then
mode = MODE_NORMAL
elseif c == ESC then            seq = {}
mode = MODE_ESC
elseif c == CSI then            seq = {}
question = false
mode = MODE_CSI
end
elseif mode == MODE_ESC then
if c == "[" then
mode = MODE_CSI
question = false
elseif c == "c" then            fg, bg = colors[8], colors[1]
autocr, reverse, insert, display, mousereport, cursor, altcursor, autowrap
= false, false, false, false, false, true, false, true
elseif c == "D" then            cy = cy + 1
corral()
elseif c == "E" then            cy = cy + 1
cx = 1
corral()
elseif c == "F" then            cx, cy = 1, h
elseif c == "H" then            error("TODO: ESC H")
elseif c == "M" then            cy = cy - 1
corral()
elseif c == "Z" then            rbuf = rbuf .. ESC .. "[?6c"
elseif c == "7" then            save = {fg = fg, bg = bg, autocr = autocr, reverse = reverse, display = display, insert = insert,
mousereport = mousereport, altcursor = altcursor, cursor = cursor, autowrap = autowrap}
elseif c == "8" then            fg, bg = save.fg, save.bg
autocr, reverse, display, insert = save.autocr, save.reverse, save.display, save.insert
mousereport, altcursor, cursor, autowrap = save.mousereport, save.altcursor, save.cursor, save.autowrap
elseif c == "%" then            mode = MODE_CHARSET
elseif c == "#" then            mode = MODE_DSAT
elseif c == "(" then            mode = MODE_G0          elseif c == ")" then            mode = MODE_G1          elseif c == ">" then          elseif c == "=" then          elseif c == "]" then            mode = MODE_OSC
end
elseif mode == MODE_CSI then
if c == "?" then
if #seq > 0 or question then
mode = MODE_NORMAL
question = false
else
question = true
end
elseif c == "@" then            if seq[1] and seq[1] > 0 then
gpu.copy(cx, cy, w, 1, seq[1], 0)
gpu.fill(cx, cy, seq[1], 1, " ")
end
elseif c == "A" then            cy = cy - (seq[1] or 1)
clamp()
elseif c == "B" or c == "e" then            cy = cy + (seq[1] or 1)
clamp()
elseif c == "C" or c == "a" then            cx = cx + (seq[1] or 1)
clamp()
elseif c == "D" then            cx = cx - (seq[1] or 1)
clamp()
elseif c == "E" then            cx = 1
cy = cy - (seq[1] or 1)
clamp()
elseif c == "F" then            cx = 1
cy = cy + (seq[1] or 1)
clamp()
elseif c == "G" or c == "`" then            cx = (seq[1] or 1)
clamp()
elseif c == "H" or c == "f" then            cy, cx = seq[1] or 1, seq[3] or 1
clamp()
elseif c == "J" then            local m = seq[1] or 0
if m == 0 then              gpu.fill(cx, cy, w, 1, " ")
gpu.fill(1, cy+1, w, h, " ")
elseif m == 1 then              gpu.fill(1, 1, w, cy-1, " ")
gpu.fill(1, cy, cx, 1, " ")
elseif m == 2 or m == 3 then              gpu.fill(1, 1, w, h, " ")
end
elseif c == "K" then            local m = seq[1] or 0
if m == 0 then              gpu.fill(cx, cy, w, 1, " ")
elseif m == 1 then              gpu.fill(1, cy, cx, 1, " ")
elseif m == 2 then              gpu.fill(1, cy, w, 1, " ")
end
elseif c == "L" then            local n = seq[1] or 1
gpu.copy(1, cy, w, h, 0, n)
gpu.fill(1, cy, w, n, " ")
elseif c == "M" then            local n = seq[1] or 1
gpu.copy(1, cy, w, h, 0, -n)
gpu.fill(1, h-n, w, n, " ")
elseif c == "P" then            local n = seq[1] or 1
gpu.copy(cx, cy, w, 1, -n, 0)
elseif c == "S" then            scroll(seq[1] or 1)
elseif c == "T" then            scroll(-(seq[1] or 1))
elseif c == "X" then            local n = seq[1] or 1
gpu.fill(cx, cy, n, 1, " ")          elseif c == "c" then            rbuf = rbuf .. ESC .. "?6c"
elseif c == "d" then            cy = seq[1] or 1
clamp()          elseif c == "g" then          elseif c == "h" or c == "l" then            local set = c == "h"
if question then              for i=1, #seq, 2 do
if seq[i] == 1 then                  altcursor = set                elseif seq[i] == 6 then                elseif seq[i] == 7 then                  autowrap = set
elseif seq[i] == 9 then                  mousereport = set and 1 or 0
elseif seq[i] == 25 then                  cursor = set
elseif seq[i] == 1000 then                  mousereport = set and 2 or 0
end
end
else              for i=1, #seq, 2 do
if seq[i] == 3 then                  display = set
elseif seq[i] == 4 then                  insert = set
elseif seq[i] == 20 then                  autocr = set
end
end
end
elseif c == "m" then            if not seq[1] then seq[1] = 0 end
for i=1, #seq, 2 do              if seq[i] == 0 then                fg, bg = colors[8], colors[1]
reverse = false
elseif seq[i] == 7 then                reverse = true
elseif seq[i] == 27 then                reverse = false
elseif seq[i] > 29 and seq[i] < 38 then                fg = colors[seq[i] - 29]
shouldchange = true
elseif seq[i] > 39 and seq[i] < 48 then                bg = colors[seq[i] - 39]
shouldchange = true              elseif seq[i] == 39 then                fg = colors[8]
shouldchange = true
elseif seq[i] == 49 then                bg = colors[1]
shouldchange = true
elseif seq[i] > 89 and seq[i] < 98 then                fg = colors[seq[i] - 81]
shouldchange = true
elseif seq[i] > 99 and seq[i] < 108 then                bg = colors[seq[i] - 91]
shouldchange = true
end
end
elseif c == "n" then            for i=1, #seq, 2 do
if seq[i] == 5 then                rbuf = rbuf .. ESC .. "[0n"              elseif seq[i] == 6 then                rbuf = rbuf .. string.format("%s[%d;%dR", ESC, cy, cx)
end
end          elseif c == "r" then            st, sb = seq[1] or 1, seq[2] or h
elseif c == "s" then            scx, scy = cx, cy
elseif c == "u" then            cx, cy = scx or cx, scy or cy          elseif c == "[" then
seq = "["
elseif seq == "[" then
mode = MODE_NORMAL
elseif c == ";" then
if seq[#seq] == ";" then
seq[#seq+1] = 0
end
seq[#seq+1] = ";"
elseif tonumber(c) then
if seq[#seq] == ";" then
seq[#seq+1] = tonumber(c)
else
seq[math.max(1, #seq)] = (seq[#seq] or 0) * 10 + tonumber(c)
end
end
if c ~= ";" and c ~= "?" and not tonumber(c) then
mode = MODE_NORMAL
end
elseif mode == MODE_NORMAL then
if pi < 1 then
pi = i
end
elseif mode == MODE_OSC then          mode = MODE_NORMAL
elseif mode == MODE_G0 then
mode = MODE_NORMAL
elseif mode == MODE_G1 then
mode = MODE_NORMAL
elseif mode == MODE_CHARSET then
mode = MODE_NORMAL
elseif mode == MODE_DSAT then
if c == "8" then
gpu.fill(1, 1, w, h, "E")
end
mode = MODE_NORMAL
end
end
if pi > 0 then
wbuf = wbuf .. sub(str, pi, #str)
end
flush()
if mode == MODE_NORMAL and cursor then
setcursor(true)
end
end
new.write = write
new.flush = function() end
new.khid = k.add_signal_handler("key_down", function(_, kbd, char, code)
if not keyboards[kbd] then return end
if not new.discipline then return end
local to_buffer
if scancode_lookups[code] then
local c = scancode_lookups[code]
local interim = altcursor and "O" or "["
to_buffer = ESC .. interim .. c
elseif char > 0 then
to_buffer = string.char(char)
end
if to_buffer then
new.discipline:processInput(to_buffer)
end
end)
return new
end
k.init_ttys()
end
printk(k.L_INFO, "ttyprintk")
do
local devfs = k.fstypes.devfs("devfs")
local console, err = devfs:open("/tty1", "w")
if not console then
panic("cannot open console: " .. err)
end
console = k.fd_from_node(devfs, console, "w")
console = { fd = console, node = console, refs = 1 }
k.console = console
k.ioctl(console, "setvbuf", "line")
k.write(console, "\27[39;49m\27[2J")
function k.log_to_screen(message)
k.write(console, message.."\n")
end
for i=1, #k.log_buffer do
k.log_to_screen(k.log_buffer[i])
end
end
printk(k.L_INFO, "user/sandbox")
do  local function deepcopy(orig, copies)
copies = copies or {}
local orig_type = type(orig)
local copy
if orig_type == 'table' then
if copies[orig] then
copy = copies[orig]
else
copy = {}
copies[orig] = copy
for orig_key, orig_value in next, orig, nil do
copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
end
setmetatable(copy, deepcopy(getmetatable(orig), copies))
end
else      copy = orig
end
return copy
end
local blacklist = {
k = true, component = true, computer = true, printk = true, panic = true
}
k.max_proc_time = tonumber(k.cmdline.max_proc_time or "3") or 3
function k.create_env(base)
checkArg(1, base, "table", "nil")
if base then return base end
local new = deepcopy(base or _G)
for key in pairs(blacklist) do
new[key] = nil
end
new.load = function(a, b, c, d)
return k.load(a, b, c, d or k.current_process().env)
end
local yield = new.coroutine.yield
new.coroutine.yield = function(request, ...)
local proc = k.current_process()
local last_yield = proc.last_yield or computer.uptime()
if request == "syscall" then
if computer.uptime() - last_yield > k.max_proc_time then
coroutine.yield(k.sysyield_string)
proc.last_yield = computer.uptime()
end
return k.perform_system_call(...)
end
proc.last_yield = computer.uptime()
return yield(request, ...)
end
if new.coroutine.resume == coroutine.resume then
local resume = new.coroutine.resume
function new.coroutine.resume(co, ...)
local result
repeat
result = table.pack(resume(co, ...))
if result[2] == k.sysyield_string then
yield(k.sysyield_string)
end
until result[2] ~= k.sysyield_string or not result[1]
return table.unpack(result, 1, result.n)
end
end
return new
end
end
printk(k.L_INFO, "exec/main")
do
local formats = {}  function k.register_executable_format(name, recognizer, loader)
checkArg(1, name, "string")
checkArg(2, recognizer, "function")
checkArg(3, loader, "function")
if formats[name] then
return nil, k.errno.EEXIST
end
formats[name] = { recognizer = recognizer, loader = loader }
return true
end
function k.load_executable(path, env)
checkArg(1, path, "string")
checkArg(2, env, "table")
local stat, err = k.stat(path)
if not stat then return nil, err end
if not k.process_has_permission(k.current_process(), stat, "x") then
return nil, k.errno.EACCES
end
local fd, err = k.open(path, "r")
if not fd then
return nil, err
end
local header = k.read(fd, 128)
k.seek(fd, "set", 0)
local extension = path:match("%.([^/]-)$")
for _, format in pairs(formats) do
if format.recognizer(header, extension) then
return format.loader(fd, env, path)
end
end
k.close(fd)
return nil, k.errno.ENOEXEC
end
end--
printk(k.L_INFO, "exec/shebang")
do
k.register_executable_format("shebang", function(header)
return header:sub(1, 2) == "#!"
end, function(fd, env, path)
local shebang = k.read(fd, "l")
k.close(fd)
local words = {}
for word in shebang:sub(3):gmatch("[^ ]+") do
words[#words+1] = word
end
local interp = words[1]
words[0] = interp
words[1], words[2] = words[2], path
local func, err = k.load_executable(interp, env)
if not func then
return nil, err
end
return function(args)
for i=1, #args, 1 do
words[#words+1] = args[i]
end
return func(words)
end
end)
end
printk(k.L_INFO, "exec/lua")
do
k.register_executable_format("lua", function(header)--, extension)
return header:sub(1, 6) == "--!lua"-- or extension == "lua"
end, function(fd, env, name)
local data = k.read(fd, math.huge)
k.close(fd)
local chunk, err = k.load(data, "="..name, "t", env)
if not chunk then
printk(k.L_DEBUG, "load failed - %s", tostring(err))
return nil, k.errno.ENOEXEC
end
return function(args)
local result = table.pack(xpcall(chunk, debug.traceback, args))
if not result[1] then
printk(k.L_NOTICE, "Lua error: %s", result[2])
k.syscalls.exit(1)
else
k.syscalls.exit(0)
end
end
end)
end--- System calls.-- @alias k.syscalls
printk(k.L_INFO, "syscalls")
do
k.syscalls = {}
function k.perform_system_call(name, ...)
checkArg(1, name, "string")
if not k.syscalls[name] then
return nil, k.errno.ENOSYS
end
local result = table.pack(pcall(k.syscalls[name], ...))
return table.unpack(result, result[1] and 2 or 1, result.n)
end  function k.syscalls.open(file, mode)
checkArg(1, file, "string")
checkArg(2, mode, "string")
local fd, err = k.open(file, mode)
if not fd then
return nil, err
end
local current = k.current_process()
local n = #current.fds + 1
current.fds[n] = fd
return n
end
if k.request then    function k.syscalls.request(path)
checkArg(1, path, "string")
local fd, err, detail = k.request(path)
if not fd then
return nil, err, detail
end
local current = k.current_process()
local n = #current.fds + 1
current.fds[n] = fd
return n
end
end  function k.syscalls.ioctl(fd, operation, ...)
checkArg(1, fd, "number")
checkArg(2, operation, "string")
local current = k.current_process()
if current.fds[fd] and current.fds[fd].refs <= 0 then
current.fds[fd] = nil
end
if not current.fds[fd] then
return nil, k.errno.EBADF
end
return k.ioctl(current.fds[fd], operation, ...)
end  function k.syscalls.read(fd, fmt)
checkArg(1, fd, "number")
checkArg(2, fmt, "string", "number")
local current = k.current_process()
if current.fds[fd] and current.fds[fd].refs <= 0 and not current.fds[fd].pipe then
current.fds[fd] = nil
end
if not current.fds[fd] then
return nil, k.errno.EBADF
end
return k.read(current.fds[fd], fmt)
end  function k.syscalls.write(fd, data)
checkArg(1, fd, "number")
checkArg(2, data, "string")
local current = k.current_process()
if current.fds[fd] and current.fds[fd].refs <= 0 then
current.fds[fd] = nil
end
if not current.fds[fd] then
return nil, k.errno.EBADF
end
local ok, err = k.write(current.fds[fd], data)
return not not ok, err
end  function k.syscalls.seek(fd, whence, offset)
checkArg(1, fd, "number")
checkArg(2, whence, "string")
checkArg(3, offset, "number", "nil")
local current = k.current_process()
if current.fds[fd] and current.fds[fd].refs <= 0 then
current.fds[fd] = nil
end
if not current.fds[fd] then
return nil, k.errno.EBADF
end
return k.seek(current.fds[fd], whence, offset or 0)
end  function k.syscalls.flush(fd)
checkArg(1, fd, "number")
local current = k.current_process()
if current.fds[fd] and current.fds[fd].refs <= 0 then
current.fds[fd] = nil
end
if not current.fds[fd] then
return nil, k.errno.EBADF
end
return k.flush(current.fds[fd])
end  function k.syscalls.opendir(file)
checkArg(1, file, "string")
local fd, err = k.opendir(file)
if not fd then return nil, err end
local current = k.current_process()
local n = #current.fds + 1
current.fds[n] = fd
return n
end  function k.syscalls.readdir(fd)
checkArg(1, fd, "number")
local current = k.current_process()
if current.fds[fd] and current.fds[fd].refs <= 0 then
current.fds[fd] = nil
end
if not current.fds[fd] then
return nil, k.errno.EBADF
end
return k.readdir(current.fds[fd])
end  function k.syscalls.close(fd)
checkArg(1, fd, "number")
local current = k.current_process()
if not current.fds[fd] then
return nil, k.errno.EBADF
end
k.close(current.fds[fd])
if current.fds[fd] and current.fds[fd].refs <= 0 then
current.fds[fd] = nil
end
return true, not current.fds[fd]
end  function k.syscalls.isatty(fd)
checkArg(1, fd, "number")
local current = k.current_process()
if current.fds[fd] and current.fds[fd].refs <= 0 then
current.fds[fd] = nil
end
if not current.fds[fd] then
return nil, k.errno.EBADF
end
local fdt = current.fds[fd]
return not not (
fdt.fd.stream and
fdt.fd.stream.proxy and
fdt.fd.stream.proxy.eofpat
)
end  function k.syscalls.dup(fd)
checkArg(1, fd, "number")
local current = k.current_process()
if current.fds[fd] and current.fds[fd].refs <= 0 then
current.fds[fd] = nil
end
if not current.fds[fd] then
return nil, k.errno.EBADF
end
local nfd = #current.fds + 1
current.fds[nfd] = current.fds[fd]
current.fds[fd].refs = current.fds[fd].refs + 1
return nfd
end  function k.syscalls.dup2(fd, nfd)
checkArg(1, fd, "number")
checkArg(2, nfd, "number")
local current = k.current_process()
if current.fds[fd] and current.fds[fd].refs <= 0 then
current.fds[fd] = nil
end
if not current.fds[fd] then
return nil, k.errno.EBADF
end
if fd == nfd then return nfd end
if current.fds[nfd] then
k.syscalls.close(nfd)
end
current.fds[nfd] = current.fds[fd]
current.fds[fd].refs = current.fds[fd].refs + 1
return nfd
end  k.syscalls.mkdir = k.mkdir  k.syscalls.stat = k.stat  k.syscalls.link = k.link  k.syscalls.symlink = k.symlink  k.syscalls.unlink = k.unlink  k.syscalls.chmod = k.chmod  k.syscalls.chown = k.chown  function k.syscalls.chroot(path)
checkArg(1, path, "string")
if k.current_process().euid ~= 0 then
return nil, k.errno.EPERM
end
local clean = k.check_absolute(path)
local stat, err = k.stat(clean)
if not stat then
return nil, err
elseif (stat.mode & 0xF000) ~= 0x4000 then
return nil, k.errno.ENOTDIR
end
clean = k.clean_path(k.current_process().root .. "/" .. clean)
k.current_process().root = clean .. "/"
return true
end  k.syscalls.mount = k.mount  k.syscalls.unmount = k.unmount  function k.syscalls.sync()
k.sync_buffers()
k.sync_fs()
return true
end  function k.syscalls.fork(func)
checkArg(1, func, "function")
local proc = k.get_process(k.add_process())
proc:add_thread(k.thread_from_function(func))
return proc.pid
end  function k.syscalls.execve(path, args, env)
checkArg(1, path, "string")
checkArg(2, args, "table")
checkArg(3, env, "table", "nil")
args[0] = args[0] or path
local current = k.current_process()
local func, err = k.load_executable(path, current.env)
if not func then return nil, err end
local stat = k.stat(path)
if (stat.mode & k.FS_SETUID) ~= 0 then
current.euid = stat.uid
current.suid = stat.uid
end
if (stat.mode & k.FS_SETGID) ~= 0 then
current.egid = stat.egid
current.sgid = stat.egid
end
current.threads = {}
current.thread_count = 0
current.environ = env or current.environ
current.cmdline = args
current:add_thread(k.thread_from_function(function()
return func(args)
end))
for f, v in pairs(current.fds) do
if f > 2 and v.cloexec then
k.close(v)
v.refs = v.refs - 1
current.fds[k] = nil
end
end
coroutine.yield()
return true
end  function k.syscalls.wait(pid, nohang, untraced)
checkArg(1, pid, "number")
checkArg(2, nohang, "boolean", "nil")
checkArg(3, untraced, "boolean", "nil")
if not k.get_process(pid) then
return nil, k.errno.ESRCH
end
if k.get_process(pid).ppid ~= k.current_process().pid then
return nil, k.errno.ECHILD
end
local process = k.get_process(pid)
if not ((process.stopped and untraced) or nohang or process.is_dead) then
repeat
local sig, id = coroutine.yield()
until ((sig == "proc_stopped" and untraced) or sig == "proc_dead") and id == pid
end
if process.stopped and untraced then
return "stopped", proc.status
end
local reason, status = process.reason, process.status or 0
if k.cmdline.log_process_deaths then
printk(k.L_DEBUG, "process died: %d, %s, %d", pid, reason, status or 0)
end
k.remove_process(pid)
return reason, status
end  function k.syscalls.waitany(block, untraced)
checkArg(1, block, "boolean", "nil")
checkArg(2, untraced, "boolean", "nil")
local cur = k.current_process().pid
repeat
for _, pid in ipairs(k.get_pids()) do
local process = k.get_process(pid)
if process.is_dead and process.ppid == cur then
return pid, k.syscalls.wait(pid)
end
end
if block then
repeat
local sig = coroutine.yield()
until sig == "proc_dead"
end
until not block
return nil
end  function k.syscalls.exit(status)
checkArg(1, status, "number")
local current = k.current_process()
current.status = status
current.threads = {}
current.thread_count = 0
current.is_dead = true
coroutine.yield()
end  function k.syscalls.getcwd()
return k.current_process().cwd
end  function k.syscalls.chdir(path)
checkArg(1, path, "string")
path = k.check_absolute(path)
local stat, err = k.stat(path)
if not stat then
return nil, err
end
if (stat.mode & 0xF000) ~= k.FS_DIR then
return nil, k.errno.ENOTDIR
end
local current = k.current_process()
current.cwd = path
return true
end  function k.syscalls.setuid(uid)
checkArg(1, uid, "number")
local current = k.current_process()
if current.euid == 0 then
current.suid = uid
current.euid = uid
current.uid = uid
return true
elseif uid==current.uid or uid==current.euid or uid==current.suid then
current.euid = uid
return true
else
return nil, k.errno.EPERM
end
end  function k.syscalls.seteuid(uid)
checkArg(1, uid, "number")
local current = k.current_process()
if current.euid == 0 then
current.euid = uid
current.suid = 0
elseif uid==current.uid or uid==current.euid or uid==current.suid then
current.euid = uid
else
return nil, k.errno.EPERM
end
end  function k.syscalls.getuid()
local cur = k.current_process()
return cur and cur.uid or 0
end  function k.syscalls.geteuid()
local cur = k.current_process()
return cur and cur.euid or 0
end  function k.syscalls.setgid(gid)
checkArg(1, gid, "number")
local current = k.current_process()
if current.egid == 0 then
current.sgid = gid
current.egid = gid
current.gid = gid
elseif gid==current.gid or gid==current.egid or gid==current.sgid then
current.egid = gid
else
return nil, k.errno.EPERM
end
end  function k.syscalls.setegid(gid)
checkArg(1, gid, "number")
local current = k.current_process()
if current.egid == 0 then
current.sgid = gid
current.egid = gid
elseif gid==current.gid or gid==current.egid or gid==current.sgid then
current.egid = gid
else
return nil, k.errno.EPERM
end
end  function k.syscalls.getgid()
local cur = k.current_process()
return cur and cur.gid or 0
end  function k.syscalls.getegid()
local cur = k.current_process()
return cur and cur.egid or 0
end  function k.syscalls.getpid()
return k.current_process().pid
end  function k.syscalls.getppid()
return k.current_process().ppid
end  function k.syscalls.setsid()
local current = k.current_process()
if current.pgid == current.pid then
return nil, k.errno.EPERM
end
current.pgid = current.pid
current.sid = current.pid
if current.tty then
current.tty.session = current.sid
current.tty.pgroup = current.pgid
end
return current.sid
end  function k.syscalls.getsid(pid)
checkArg(1, pid, "number", "nil")
if pid == 0 or not pid then
return k.current_process().sid
end
local proc = k.get_process(pid)
if not proc then
return nil, k.errno.ESRCH
end
return proc.sid
end  function k.syscalls.setpgrp(pid, pg)
checkArg(1, pid, "number")
checkArg(2, pg, "number")
local current = k.current_process()
if pid == 0 then pid = current.pid end
if pg  == 0 then pg  = pid end
local proc = k.get_process(pid)
if proc.pid ~= current.pid and proc.ppid ~= current.pid then
return nil, k.errno.EPERM
end
if pg ~= proc.pid and not k.is_pgroup(pg) then
return nil, k.errno.EPERM
end
if k.is_pgroup(pg) and k.pgroup_sid(pg) ~= proc.sid then
return nil, k.errno.EPERM
end
proc.pgid = pg
return true
end  function k.syscalls.getpgrp(pid)
checkArg(1, pid, "number", "nil")
if pid == 0 or not pid then
return k.current_process().pgid
end
local proc = k.get_process(pid)
if not proc then
return nil, k.errno.ESRCH
end
return proc.pgid
end
k.syscalls.setpgid = k.syscalls.setpgrp
k.syscalls.getpgid = k.syscalls.getpgrp  local valid_signals = {
SIGHUP  = true,
SIGINT  = true,
SIGQUIT = true,
SIGKILL = false,
SIGPIPE = true,
SIGTERM = true,
SIGCONT = false,
SIGTSTP = true,
SIGSTOP = false,
SIGTTIN = true,
SIGTTOU = true
}  function k.syscalls.sigaction(name, handler)
checkArg(1, name, "string")
checkArg(2, handler, "function", "nil")
if not valid_signals[name] then return nil, k.errno.EINVAL end
local current = k.current_process()
printk(k.L_DEBUG, "%d (%s): replacing signal handler for %s with %s",
current.pid, current.cmdline[0], name, tostring(handler))
local old = current.signal_handlers[name]
current.signal_handlers[name] = handler or k.default_signal_handlers[name]
return old
end  function k.syscalls.kill(pid, name)
checkArg(1, pid, "number")
checkArg(2, name, "string")
local current = k.current_process()
local pids
if pid > 0 then
pids = {pid}
elseif pid == 0 then
pids = k.pgroup_pids(current.pgid)
elseif pid == -1 then
pids = k.get_pids()
elseif pid < -1 then
if not k.is_pgroup(-pid) then
return nil, k.errno.ESRCH
end
pids = k.pgroup_pids(-pid)
end
if valid_signals[name] == nil and name ~= "SIGEXIST" then
return nil, k.errno.EINVAL
end
local signaled = 0
for i=1, #pids, 1 do
local proc = k.get_process(pids[i])
if (not proc) and #pids == 1 then
return nil, k.errno.ESRCH
else
if current.uid == 0 or current.euid == 0 or current.uid == proc.uid or
current.euid == proc.uid or current.uid == proc.suid or
current.euid == proc.suid then
signaled = signaled + 1
if name ~= "SIGEXIST" then
table.insert(proc.sigqueue, name)
end
end
end
end
if signaled == 0 then
return nil, k.errno.EPERM
end
return true
end  function k.syscalls.gethostname()
return k.gethostname and k.gethostname() or
"localhost"
end  function k.syscalls.sethostname(name)
checkArg(1, name, "string")
return k.sethostname and k.sethostname(name)
end  function k.syscalls.environ()
return k.current_process().environ
end  function k.syscalls.umask(num)
checkArg(1, num, "number")
local cur = k.current_process()
local old = cur.umask
if tonumber(num) then
cur.umask = (math.floor(num) & 511)
end
return old
end  function k.syscalls.pipe()
local buf = ""
local closed = false
local instream = k.fd_from_rwf(function(_, _, n)
while #buf < n and not closed do coroutine.yield(0) end
local data = buf:sub(1, math.min(n, #buf))
buf = buf:sub(#data + 1)
if #data == 0 and closed then
k.syscalls.kill(0, "SIGPIPE")
return nil, k.errno.EBADF
end
return data
end, nil, function() closed = true end)
local outstream = k.fd_from_rwf(nil, function(_, _, data)
if closed then
k.syscalls.kill(0, "SIGPIPE")
return nil, k.errno.EBADF
end
buf = buf .. data
return true
end, function() closed = true end)
local into, outof = k.fd_from_node(instream, instream, "r"),
k.fd_from_node(outstream, outstream, "w")
into:ioctl("setvbuf", "none")
outof:ioctl("setvbuf", "none")
local current = k.current_process()
local infd = #current.fds + 1
current.fds[infd] = { fd = into, node = into, refs = 1, pipe = true }
local outfd = #current.fds + 1
current.fds[outfd] = { fd = outof, node = outof, refs = 1, pipe = true }
return infd, outfd
end  function k.syscalls.reboot(cmd)
checkArg(1, cmd, "string")
if k.current_process().euid ~= 0 then
return nil, k.errno.EPERM
end
if cmd == "halt" then
k.shutdown()
printk(k.L_SYSTEM, "System halted.")
while true do
computer.pullSignal()
end
elseif cmd == "poweroff" then
printk(k.L_SYSTEM, "Power down.")
k.shutdown()
computer.shutdown()
elseif cmd == "restart" then
printk(k.L_SYSTEM, "Restarting system.")
k.shutdown()
computer.shutdown(true)
end
return nil, k.errno.EINVAL
end  function k.syscalls.uname()
return {
sysname = "mineCORE",
nodename = k.syscalls.gethostname() or "localhost",
release = "4.0.0-alpha1",
version = "2025-20-01",
machine = "oc-".._VERSION:match("Lua (.+)")
}
end  function k.syscalls.uptime()
return computer.uptime()
end
local saved_loglevel  function k.syscalls.klogctl(action, second, format, ...)
checkArg(1, action, "string")
local ret = {}
if k.current_process().euid ~= 0 and action ~= "read_all" then
return nil, k.errno.EPERM
end
if action == "read" then
checkArg(2, second, "number")
while #k.log_buffer == 0 do coroutine.yield() end
for i=1, second, 1 do
ret[i] = table.remove(k.log_buffer, i)
end
elseif action == "read_all" then
for i=1, #k.log_buffer, 1 do
ret[i] = k.log_buffer[i]
end
elseif action == "read_clear" then
for i=1, #k.log_buffer, 1 do
ret[i] = k.log_buffer[i]
k.log_buffer[i] = nil
end
elseif action == "clear" then
for i=1, #k.log_buffer, 1 do
k.log_buffer[i] = nil
end
elseif action == "console_off" then
saved_loglevel = saved_loglevel or k.cmdline.loglevel
k.cmdline.loglevel = 1
elseif action == "console_on" then
k.cmdline.loglevel = saved_loglevel or 7
saved_loglevel = nil
elseif action == "console_level" then
checkArg(2, second, "number")
k.cmdline.loglevel = math.max(1, math.min(8, second))
elseif action == "log" then
checkArg(2, second, "number")
checkArg(3, format, "string")
printk(math.max(1, math.min(8, second)), format, ...)
return true
else
return nil, k.errno.EINVAL
end
return ret
end
end
printk(k.L_INFO, "user/load_init")
do
local init_paths = {
"/bin/init",
"/bin/sh",
"/bin/init.lua",
"/bin/sh.lua",
}
local function panic_with_error(err)
panic("No working init found (" ..
((err == k.errno.ENOEXEC and "Exec format error")
or (err == k.errno.ELIBEXEC and "Cannot execute a shared library")
or (err == k.errno.ENOENT and "No such file or directory")
or (err == k.errno.EISDIR and "Is a directory")
or err)
..") - Please specify a working one")
end
local func, err
local proc = k.get_process(k.add_process())  if k.cmdline.init then
func, err = k.load_executable(k.cmdline.init, proc.env)
proc.cmdline[0] = k.cmdline.init
else    for _, path in ipairs(init_paths) do
func, err = k.load_executable(path, proc.env)
if func then
proc.cmdline[0] = path
break
elseif err ~= k.errno.ENOENT then
panic_with_error(err)
end
end
end
if not func then
panic_with_error(err)
end
proc:add_thread(k.thread_from_function(func))
local iofd = k.console
if iofd then
iofd.refs = 3
proc.fds[0] = iofd
proc.fds[1] = iofd
proc.fds[2] = iofd
end
end
k.scheduler_loop()
panic("init exited")
