return function(deps)
  deps = deps or {}
  local log = assert(deps.log, "public log dependency is required")

  local function encode(value)
    local kind = type(value)
    if kind == "string" then return string.format("%q", value) end
    if kind == "number" or kind == "boolean" then return tostring(value) end
    return string.format("%q", tostring(value))
  end

  return function(choiceLabel, seedLabel, parts)
    local encoded = {}
    for index, value in ipairs(parts or {}) do encoded[index] = encode(value) end
    log:info("%s", ("choice=%s seed=%s parts=[%s]"):format(
      tostring(choiceLabel), tostring(seedLabel), table.concat(encoded, ",")))
  end
end
