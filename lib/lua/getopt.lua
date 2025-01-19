--- Argument parsing.
-- Provides an argument parser loosely inspired by GNU getopt;  its interface is tailored to Lua rather than C, and it is thereby somewhat less obtuse.  The code is taken from ULOS 1 and has been modified very slightly to work with ULOS 2.
-- @module getopt
-- @alias lib

local lib = {}

local checkArg = require("checkArg")

------
-- Options given to @{getopt}
-- @tfield table options Key-value pairs of all possible options, where the key is the option name and the value is a boolean indicating whether that option takes an argument.  This is the only mandatory field.
-- @tfield string help_message A help message that is written to the standard error stream when an error condition is reached.
-- @tfield boolean exit_on_bad_opt Whether it is an error to find an invalid option (one not specified in the `options` table).
-- @tfield boolean finish_after_arg Whether to stop processing options after any non-option argument is reached.
-- @tfield boolean can_repeat_opts Whether options may be repeated.
-- @tfield boolean exclude_numbers Whether to exclude numbers from short options, e.g. `-700`
-- @table options

--- Process program arguments according to the given options.
-- Takes the given table of @{options}, and processes the given arguments accordingly.
-- The returned table of options will vary slightly depending whether the `can_repeat_opts` option is set.  If it is set, all values returned in the `opts` table will be tables containing an array of all the values given to that option over one or more occurrences of that option (possibly just one item).  Otherwise, the most recent occurrence of an option takes precedence and all values in `opts` are strings.  Keys in the returned `opts` table are always strings corresponding to the name of the option.
-- Option names should never begin with a `-` or `--`.
-- @tparam table _opts The options to use
-- @tparam table _args The arguments to process
-- @treturn table The arguments left over (`args`)
-- @treturn table The provided options (`opts`)
function lib.getopt(_opts, _args)
  checkArg(1, _opts, "table")
  checkArg(2, _args, "table")

  local args, opts = {}, {}
  local skip_next, done = false, false

  for i, arg in ipairs(_args) do
    if skip_next then
      skip_next = false

    elseif arg:sub(1,1) == "-" and not done then
      if arg == "--" and opts.allow_finish then
        done = true

      elseif arg:match("%-%-(.+)") then
        arg = arg:sub(3)

        if _opts.options[arg] ~= nil then
          if _opts.options[arg] then
            if (not _args[i+1]) then
              io.stderr:write("option '", arg, "' requires an argument\n")

              if _opts.help_message then
                io.stderr:write(_opts.help_message)
              end

              os.exit(1)
            end

            opts[arg] = opts[arg] or {}
            table.insert(opts[arg], _args[i+1])
            skip_next = true

          else
            opts[arg] = true

          end

        elseif _opts.exit_on_bad_opt then
          io.stderr:write("unrecognized option '", arg, "'\n")

          if _opts.help_message then
            io.stderr:write(_opts.help_message)
          end

          os.exit(1)
        end

      else
        arg = arg:sub(2)

        if tonumber(arg) and _opts.exclude_numers then
          args[#args+1] = "-"..arg

        elseif _opts.options[arg:sub(1,1)] then
          local a = arg:sub(1,1)

          if #arg == 1 then
            if not _args[i+1] then
              io.stderr:write("option '", arg, "' requires an argument\n")

              if _opts.help_message then
                io.stderr:write(_opts.help_message)
              end

              os.exit(1)
            end

            opts[a] = opts[a] or {}
            table.insert(opts[a], _args[i+1])
            skip_next = true

          else
            opts[a] = arg:sub(2)
          end

        else
          for c in arg:gmatch(".") do
            if _opts.options[c] == nil then
              if _opts.exit_on_bad_opt then
                io.stderr:write("unrecognized option '", c, "'\n")

                if _opts.help_message then
                  io.stderr:write(_opts.help_message)
                end

                os.exit(1)
              end

            elseif _opts.options[c] then
              if not _args[i+1] then
                io.stderr:write("option '", arg, "' requires an argument\n")

                if _opts.help_message then
                  io.stderr:write(_opts.help_message)
                end

                os.exit(1)
              end

              opts[c] = true

            else
              opts[c] = true

            end
          end
        end
      end

    else
      if _opts.finish_after_arg then
        done = true
      end

      args[#args+1] = arg
    end
  end

  if not _opts.can_repeat_opts then
    for k, v in pairs(opts) do
      if type(v) == "table" then
        opts[k] = v[#v]
      end
    end
  end

  return args, opts
end

--- Build a set of options and usage information.
-- For some example usage, see @{getopt.build.lua}.
-- @tparam table supported The options to assemble; an array of @{Supported}s
-- @treturn table Options to pass to the `options` field of @{getopt}
-- @treturn string Usage information, indented by two spaces
-- @treturn function A wrapper over @{getopt} that condenses all options to their short forms
function lib.build(supported)
  checkArg(1, supported, "table")

  local options = {}
  local usage = {}

  for i=1, #supported, 1 do
    local opt = supported[i]
    local use = {}

    for n=3, #opt, 1 do
      options[opt[n]] = not not opt[2]
      use[#use+1] = (#opt[n] == 1 and "-" or "--") .. opt[n]
    end

    usage[#usage+1] = string.format("%s%s\t%s", table.concat(use, ", "),
      opt[2] and (" " .. opt[2]) or "", opt[1])
  end

  return options, "  " .. table.concat(usage, "\n  "), function(opts)
    for i=1, #supported, 1 do
      local opt = supported[i]

      for n=3, #opt, 1 do
        opts[opt[3]] = opts[opt[n]]
        if opts[opt[3]] then break end
      end
    end
  end
end

------
-- Supported options given to `build`.
-- @tfield string 1 A short description of the option
-- @tfield string|boolean 2 The name of the argument the option takes, or `false` if it does not take one
-- @tfield string 3 The short name of the option
-- @tfield[opt] string 4 The long name of the option
-- @table Supported

--- Process options more easily.
-- Effectively @{build} and @{getopt} combined.
-- For example usage, see @{getopt.process.lua}.
-- @tparam table parameters An amalgamation of the arguments given to @{build} and @{getopt}, with the addition of an `args` field to hold the raw arguments.
-- @treturn table The arguments left over
-- @treturn table The options left over
-- @treturn string Usage information for the given options.
function lib.process(parameters)
  checkArg(1, parameters, "table")
  local options, usage, condense = lib.build(parameters)
  parameters.options = options
  local args, opts = lib.getopt(parameters, parameters.args)
  condense(opts)
  return args, opts, usage
end

return lib
