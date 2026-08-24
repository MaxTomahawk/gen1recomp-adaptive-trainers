return function(deps)
  deps = deps or {}
  local diagnostics = assert(deps.diagnostics,
    "diagnostics dependency is required")
  local env = type(deps.env) == "table" and deps.env or {}
  local sink = type(deps.sink) == "function" and deps.sink or nil
  local M = {}
  local seed_sink = type(deps.seed_sink) == "function" and deps.seed_sink
    or nil

  local function copy_data(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = copy_data(item) end
    return out
  end

  local function emit_seed(kind, entry, label)
    if seed_sink and type(entry) == "table" then
      seed_sink({ kind = kind, label = label or entry.label,
        seedLabel = entry.label, parts = copy_data(entry.parts),
        value = copy_data(entry.value) })
    end
  end

  local function emit_member_seeds(kind, projection)
    local memberIds = {}
    for memberId in pairs(projection.memberSeeds or {}) do
      memberIds[#memberIds + 1] = memberId
    end
    table.sort(memberIds)
    for _, memberId in ipairs(memberIds) do
      emit_seed(kind, projection.memberSeeds[memberId])
    end
  end

  local function emit_choices(kind, projection)
    local keys = {}
    for key in pairs(projection.choiceLabels or {}) do
      if type(key) == "string" then keys[#keys + 1] = key end
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
      local entry = projection.choiceSeeds and projection.choiceSeeds[key]
        or projection.seed
      emit_seed(kind, entry, projection.choiceLabels[key])
    end
  end

  function M.enabled()
    return env.POKEPORT_DEV == "1"
  end

  function M.project(kind, ...)
    if not M.enabled() then return nil end
    local projector = diagnostics[kind]
    if type(projector) ~= "function" then return nil end
    local projection = projector(...)
    if not projection then return nil end
    emit_seed(kind, projection.seed)
    emit_member_seeds(kind, projection)
    emit_choices(kind, projection)
    if sink then sink("adaptive-trainers." .. tostring(kind), projection) end
    return projection
  end

  return M
end
