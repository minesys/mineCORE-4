local lib = {}

function lib.load(path)
  local conf, err = io.open(path, "r")
  if not conf then
    return nil, err
  end

  local options = {}

  for line in conf:lines() do
    local key, val = line:match("([^=]+)=([^=]+)")
    if key and val then
      options[key] = val
    end
  end

  conf:close()

  return options
end

return lib
