-- posix.glob

local dirent = require("posix.dirent")
local stdlib = require("posix.stdlib")
local stat = require("posix.sys.stat")
local checkArg = require("checkArg")

local lib = {
  -- flags
  GLOB_MARK = 1,
  GLOB_ERR = 2,
  GLOB_NOCHECK = 4,

  -- errors
  GLOB_ABORTED = 1,
  GLOB_NOMATCH = 2,
  GLOB_NOSPACE = 4,
}

local split = stdlib._segments

function lib.glob(pat, flags)
  checkArg(1, pat, "string", "nil")
  checkArg(2, flags, "number", "nil")
  pat = pat or "*"
  flags = flags or 0

  local prefix = ""
  if pat:sub(1,1) == "/" then
    prefix = "/"
  end

  local names = {}

  if stat.stat(pat) then
    names[#names+1] = pat
    return names
  end

  local segments = split(pat)

  for i=1, #segments, 1 do
    local seg = segments[i]
    if seg:find("[%[%?%*]") then
      -- we can cheat and use Lua's pattern matching engine here,
      -- but to do that we need to transform the segment into a pattern.
      -- these gsub calls magically do that.
      seg = seg
        -- replace all special characters
        :gsub("[%(%)%.%%%+%-%^%$]", "%%%1")
        -- replace all `*` with `.+`, the lua equivalent
        :gsub("%*", ".+")
        -- replace all `\[` with `%[` and `\]` with `%]`
        :gsub("\\[%[%]]", "%%%1")
        -- replace all `%[a%-z%]`-form globs with `[a-z]`
        :gsub("%[([^] ]*)%%%-([^[ ]*)%]", "[%1-%2]")

      local stage = prefix .. table.concat(segments, "/", 1, i - 1)
      if stat.stat(stage) then
        for file in dirent.files(stage) do
          if file:match(seg) then
            local name = table.concat({
              stage, file, table.concat(segments, "/", i + 1)
            }, "/"):gsub("[/\\]+", "/")

            local sx = stat.stat(name)
            if sx then
              if stat.S_ISDIR(sx.st_mode)==0 or (flags&lib.GLOB_MARK==0) then
                name = name:sub(1, -2)
              end

              names[#names+1] = name
            end
          end
        end

      elseif flags & lib.GLOB_ERR ~= 0 then
        return nil, lib.GLOB_ABORTED
      end
    end
  end

  if #names == 0 then
    return nil, lib.GLOB_NOMATCH
  end

  table.sort(names)
  return names
end

return lib
