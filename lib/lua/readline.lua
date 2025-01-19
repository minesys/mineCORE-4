--- A Readline implementation.
-- Provides a fairly complete readline function.  It supports line editing, history, and obfuscation.
-- Loading this with `require` will provide only a single function, @{readline}.
-- @module readline

local gen = require("posix.libgen")
local dent = require("posix.dirent")
local stat = require("posix.sys.stat")
local termio = require("termio")
local checkArg = require("checkArg")

local rlid = 0

------
-- Readline options.  All fields in this table are optional.
-- @tfield string prompt A prompt to display
-- @tfield table history A table of history
-- @tfield boolean noexit Do not exit on `^D`
-- @tfield function exit A function to call instead of `os.exit` when `^D` is pressed, unless `noexit` is set
-- @tfield function complete A function that takes a buffer and cursor index, and returns a table of valid completions.  A single completion result will be inserted into the buffer;  otherwise multiple results will be tabulated.
-- @table rlopts

local empty = {}

local function defaultComplete(buffer, cpos)
  if cpos ~= #buffer then return end
  -- find the last space
  local idx = #buffer - (buffer:reverse():find(" ") or (#buffer - 1))
  local path = buffer:sub(idx+2)
  local base = gen.basename(path)
  local dir = gen.dirname(path)

  if path:sub(-1) == "/" then dir = path; base = "" end
  local hidden = base:sub(1,1) == "."
  local results = {}

  if stat.stat(dir) then
    for file in dent.files(dir) do
      if (file:sub(1,1) ~= "." or hidden) and file:sub(1, #base) == base then
        local full = dir.."/"..file
        local sx = stat.lstat(full)

        if stat.S_ISDIR(sx.st_mode) ~= 0 then
          file = file .. "/"
        end

        results[#results+1] = file:sub(#base+1)
      end
    end
  end

  return results, base
end

local function tabulate(text, w, add)
  local lines = {""}
  add = add or ""
  local max = 0
  table.sort(text)
  for i=1, #text, 1 do max = math.max(max, #add + #text[i]) end

  for i=1, #text, 1 do
    if #lines[#lines] + max > w then
      lines[#lines+1] = add .. text[i] .. (" "):rep(max - (#add + #text[i]))

    else
      lines[#lines] = lines[#lines] .. add .. text[i]
    end

    if #lines[#lines] + 2 > w then
      lines[#lines+1] = ""
    else

      lines[#lines] = lines[#lines] .. "  "
    end
  end

  return lines
end

--- Read a line of input.
-- @function readline
-- @tparam[opt] @{rlopts} opts Readline options
-- @treturn string The input that was read
local function readline(opts)
  checkArg(1, opts, "table", "nil")

  local uid = rlid + 1
  rlid = uid
  opts = opts or {}
  if opts.prompt then io.write(opts.prompt) end

  local history = opts.history or {}
  history[#history+1] = ""
  local hidx = #history

  local buffer = ""
  local cpos = 0

  local complete = opts.complete or defaultComplete

  local w, h = termio.getTermSize()

  while true do
    local key, flags = termio.readKey()
    flags = flags or {}

    if not (flags.ctrl or flags.alt) then
      if key == "up" then
        if hidx > 1 then
          if hidx == #history then
            history[#history] = buffer
          end

          hidx = hidx - 1
          local olen = #buffer - cpos
          cpos = 0
          buffer = history[hidx]

          if olen > 0 then io.write(string.format("\27[%dD", olen)) end
          local _, cy = termio.getCursor()

          if cy < h then
            io.write(string.format("\27[K\27[B\27[J\27[A%s", buffer))

          else
            io.write(string.format("\27[K%s", buffer))
          end
        end

      elseif key == "down" then
        if hidx < #history then
          hidx = hidx + 1
          local olen = #buffer - cpos
          cpos = 0
          buffer = history[hidx]

          if olen > 0 then io.write(string.format("\27[%dD", olen)) end
          local _, cy = termio.getCursor()

          if cy < h then
            io.write(string.format("\27[K\27[B\27[J\27[A%s", buffer))

          else
            io.write(string.format("\27[K%s", buffer))
          end
        end

      elseif key == "left" then
        if cpos < #buffer then
          cpos = cpos + 1
          io.write("\27[D")
        end

      elseif key == "right" then
        if cpos > 0 then
          cpos = cpos - 1
          io.write("\27[C")
        end

      elseif key == "backspace" then
        if cpos == 0 and #buffer > 0 then
          buffer = buffer:sub(1, -2)
          io.write("\27[D \27[D")

        elseif cpos < #buffer then
          buffer = buffer:sub(0, #buffer - cpos - 1) ..
            buffer:sub(#buffer - cpos + 1)

          local tw = buffer:sub((#buffer - cpos) + 1)
          io.write(string.format("\27[D%s \27[%dD", tw, cpos + 1))
        end

      elseif #key == 1 then
        local wr = true

        if cpos == 0 then
          buffer = buffer .. key
          io.write(key)
          wr = false

        elseif cpos == #buffer then
          buffer = key .. buffer

        else
          buffer = buffer:sub(1, #buffer - cpos) .. key ..
            buffer:sub(#buffer - cpos + 1)
        end

        if wr then
          local tw = buffer:sub(#buffer - cpos)
          io.write(string.format("%s\27[%dD", tw, #tw - 1))
        end
      end

    elseif flags.ctrl then
      if key == "m" then -- enter
        if cpos > 0 then io.write(string.format("\27[%dC", cpos)) end
        io.write("\n\27[J")
        io.flush()
        break

      elseif key == "a" and cpos < #buffer then
        io.write(string.format("\27[%dD", #buffer - cpos))
        cpos = #buffer

      elseif key == "e" and cpos > 0 then
        io.write(string.format("\27[%dC", cpos))
        cpos = 0

      elseif key == "d" and not opts.noexit then
        io.write("\n")
        ; -- this is a weird lua quirk
        (type(opts.exit) == "function" and opts.exit or os.exit)()

      elseif key == "i" then -- tab
        if type(complete) == "function" then
          local obuffer = buffer
          local completions, base = complete(buffer, #buffer - cpos)
          completions = completions or empty

          if #completions == 1 then
            buffer = buffer:sub(0, #buffer - cpos) .. completions[1]
              .. buffer:sub(#buffer - cpos + 1)
            io.write("\27[J")

          elseif #completions > 1 then
            local lines = tabulate(completions, w, base)

            local common = completions[1] or ""
            for i=1, #completions, 1 do
              local text = completions[i]

              if #text < #common then common = common:sub(1, #text) end
              if text:sub(1, #common) ~= common then
                repeat
                  common = common:sub(1, -2)
                until text:sub(1, #common) == common or #common == 0
              end

              if #common == 0 then break end
            end

            if #common > 0 then
              buffer = buffer:sub(0, #buffer - cpos) .. common
                .. buffer:sub(#buffer - cpos + 1)
              io.write("\27[J")
            end

            local x, y = termio.getCursor()
            if y + #lines > h then
              y = y - (#lines - (h - y) + 1)
            end

            io.write(string.format("\27[%dD\n", cpos))
            io.write("\27[J")
            print(table.concat(lines, "\n"))
            termio.setCursor(x, y)
          end

          if obuffer ~= buffer and #obuffer > 0 then
            io.write(string.format("\27[%dD", #obuffer - cpos))
            cpos = 0
            local _, cy = termio.getCursor()

            if cy < h then
              io.write(string.format("\27[K\27[B\27[J\27[A%s", buffer))

            else
              io.write(string.format("\27[K%s", buffer))
            end
          end
        end
      end
    end
  end

  history[#history] = buffer
  return buffer
end

return readline
