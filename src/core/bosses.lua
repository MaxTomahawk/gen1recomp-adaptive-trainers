return function(deps)
  local rng = deps.rng
  local stage_resolver = deps.stage_resolver
  local roster_data = deps.rosters
  local on_choice = type(deps.on_choice) == "function"
    and deps.on_choice or function() end
  local M = {}

  local function clamp_level(value)
    return math.max(1, math.min(100, math.floor(tonumber(value) or 1)))
  end

  local function copy_array(values)
    local out = {}
    for index, value in ipairs(values or {}) do out[index] = value end
    return out
  end

  function M.reference_levels(party, count)
    local levels = {}
    for _, value in ipairs(party or {}) do
      local level = type(value) == "table" and value.level or value
      if tonumber(level) then levels[#levels + 1] = clamp_level(level) end
    end
    table.sort(levels, function(left, right) return left > right end)
    if #levels == 0 then levels[1] = 1 end
    local references = {}
    for index = 1, math.max(0, tonumber(count) or 0) do
      references[index] = levels[index] or levels[#levels]
    end
    return references
  end

  function M.target_levels(floors, references)
    local out = {}
    for index, floor in ipairs(floors or {}) do
      local reference = tonumber(references and references[index]) or 1
      if index == 1 then reference = reference + 1 end
      out[index] = clamp_level(math.max(tonumber(floor) or 1, reference))
    end
    return out
  end

  local function as_set(values)
    local out = {}
    for _, value in ipairs(values or {}) do out[value] = true end
    return out
  end

  local function shuffled(values, stream)
    local out = copy_array(values)
    for index = #out, 2, -1 do
      local other = stream:integer(1, index)
      out[index], out[other] = out[other], out[index]
    end
    return out
  end

  local function resolve_line(rosters, meta, lineId, level, pokemon)
    local line = rosters.line(meta, lineId)
    if not line then return nil end
    return stage_resolver.resolve(line, level, pokemon,
      rosters.preferred_species(lineId))
  end

  local function append_unique(target, values)
    local seen = {}
    for _, value in ipairs(target) do seen[value] = true end
    for _, value in ipairs(values or {}) do
      if not seen[value] then
        target[#target + 1] = value
        seen[value] = true
      end
    end
  end

  local function instance_package(lineId, index, strategy)
    local out = { id = strategy.id, techniques = {}, signatureMoves = {},
      roleWeights = strategy.roleWeights or {},
      preferredMoves = strategy.preferredMoves or {},
      preferredTypes = strategy.preferredTypes or {} }
    if index == 1 then
      append_unique(out.signatureMoves, strategy.signatureMoves)
      append_unique(out.techniques, out.signatureMoves)
      return out
    end
    local structural = false
    for _, preferred in ipairs(strategy.preferredLines or {}) do
      if preferred == lineId then structural = true; break end
    end
    if structural then append_unique(out.techniques, strategy.techniques) end
    return out
  end

  local function copy_map(source)
    local out = {}
    for key, value in pairs(source or {}) do out[key] = value end
    return out
  end

  local function available_choice(alternatives, moveDefs, stream)
    local available = {}
    for _, moveId in ipairs(alternatives or {}) do
      if moveDefs[moveId] then available[#available + 1] = moveId end
    end
    if #available == 0 then return nil end
    return available[stream:integer(1, #available)]
  end

  local function attempt_strategy(identity, source, version, stream, rosters,
      moveDefs, kantoPlus)
    local out = {}
    for key, value in pairs(source) do out[key] = value end
    out.techniques = copy_array(source.techniques)
    out.preferredLines = copy_array(source.preferredLines)
    out.signatureExtras = copy_array(source.signatureExtras)
    out.preferredMoves = copy_map(source.preferredMoves)
    out.preferredTypes = copy_map(source.preferredTypes)
    out.roleWeights = copy_map(source.roleWeights)
    out.signatureMoves = {}
    local selected = {}
    for _, alternatives in ipairs(
        rosters.signature_move_groups(identity, version, kantoPlus)) do
      local moveId = available_choice(alternatives, moveDefs, stream)
      if moveId and not selected[moveId] then
        out.signatureMoves[#out.signatureMoves + 1] = moveId
        selected[moveId] = true
      end
    end
    local extra = available_choice(out.signatureExtras, moveDefs, stream)
    if extra then append_unique(out.signatureMoves, { extra }) end
    while #out.signatureMoves > 4 do table.remove(out.signatureMoves) end
    for _, moveId in ipairs(out.signatureMoves) do
      out.preferredMoves[moveId] = true
    end
    return out
  end

  local function materialize(state)
    local party = {}
    for index, instance in ipairs(state.party or {}) do
      party[index] = { species = instance.species, level = instance.level }
      if instance.moves and #instance.moves > 0 then
        party[index].moves = copy_array(instance.moves)
      end
    end
    return party, state
  end

  local function new_instance(identity, lineId, level, index, stream,
      services, rosters, strategy, team, version, signatureSpecies)
    local species = index == 1 and signatureSpecies
      or resolve_line(rosters, services.meta, lineId, level, services.pokemon)
    assert(species, ("boss line %s has no legal stage at level %d")
      :format(tostring(lineId), level))
    assert(services.pokemon[species],
      "boss signature species is unavailable in the runtime registry")
    local instance = {
      id = ("boss:%s:%d:%08x"):format(identity.id, index,
        stream:next_u32()),
      lineId = lineId,
      species = species,
      level = level,
      roleSeed = stream:next_u32(),
    }
    local context = services.movesets.team_context(team, services.pokemon,
      services.moves)
    local movePackage = instance_package(lineId, index, strategy)
    services.movesets.generate(instance, services.pokemon[species],
      services.moves, 4, movePackage, context)
    return instance
  end

  function M.build(identity, context, root, services)
    assert(identity and identity.id, "boss identity is required")
    context, root, services = context or {}, root or {}, services or {}
    root.bossAttempts = root.bossAttempts or {}
    local state = root.bossAttempts[identity.id]
    if type(state) ~= "table" then
      state = { attemptCounter = tonumber(state) or 0 }
      root.bossAttempts[identity.id] = state
    end
    state.attemptCounter = math.max(0,
      math.floor(tonumber(state.attemptCounter) or 0))
    if state.party and #state.party > 0 then return materialize(state) end

    local rosters = assert(services.rosters or roster_data,
      "boss roster data service is required")
    local version = assert(context.version, "boss game version is required")
    local count = rosters.active_count(identity, version)
    local references = M.reference_levels(context.playerLevels, count)
    local targets = M.target_levels(rosters.floors(identity, version),
      references)
    local stream = rng.stream({ hi = root.seedHi or 0, lo = root.seedLo or 0 },
      "boss-attempt", version, identity.id, state.attemptCounter)
    local kantoPlus = services.kantoPlus == true
    local signatureSpecies = rosters.signature_species(identity, version,
      kantoPlus)
    if not services.pokemon[signatureSpecies] then
      kantoPlus = false
      signatureSpecies = rosters.signature_species(identity, version, false)
    end
    local strategyId = identity.strategyOrder[
      stream:integer(1, #identity.strategyOrder)]
    local strategy = attempt_strategy(identity,
      assert(identity.strategyPackages[strategyId]), version, stream, rosters,
      services.moves or {}, kantoPlus)
    local lines = { rosters.signature_line(identity, version) }
    local flex, selected = {}, {}
    local preferred = shuffled(strategy.preferredLines or {}, stream)
    for _, lineId in ipairs(preferred) do
      if not selected[lineId] then
        for _, candidate in ipairs(identity.flexPool) do
          if candidate == lineId then
            flex[#flex + 1] = lineId
            selected[lineId] = true
            break
          end
        end
      end
    end
    for _, lineId in ipairs(shuffled(identity.flexPool, stream)) do
      if not selected[lineId] then
        flex[#flex + 1] = lineId
        selected[lineId] = true
      end
    end
    for index = 2, count do
      lines[index] = flex[index - 1]
        or flex[((index - 2) % math.max(1, #flex)) + 1]
        or lines[1]
    end

    state.version = version
    state.attemptCounter = state.attemptCounter
    state.referenceLevels = references
    state.targetLevels = targets
    state.strategyId = strategyId
    state.strategy = strategy
    state.party = {}
    for index, lineId in ipairs(lines) do
      state.party[index] = new_instance(identity, lineId, targets[index],
        index, stream, services, rosters, strategy, state.party, version,
        signatureSpecies)
    end
    state.preparedAttempt = state.attemptCounter
    local seedParts = { version, identity.id, state.attemptCounter }
    on_choice("boss-strategy", "boss-attempt", seedParts)
    on_choice("boss-flex-pool", "boss-attempt", seedParts)
    on_choice("boss-target-levels", "boss-attempt", seedParts)
    return materialize(state)
  end

  function M.record_result(root, bossId, result)
    local state = root and root.bossAttempts and root.bossAttempts[bossId]
    if result ~= "lose" or type(state) ~= "table"
        or not state.party or state.preparedAttempt ~= state.attemptCounter then
      return false
    end
    state.lastLostAttempt = state.attemptCounter
    state.attemptCounter = state.attemptCounter + 1
    state.party = nil
    state.referenceLevels = nil
    state.targetLevels = nil
    state.strategyId = nil
    state.strategy = nil
    state.preparedAttempt = nil
    return true
  end

  function M.diagnostic_evidence(identity, state, services)
    state = type(state) == "table" and state or {}
    services = type(services) == "table" and services or {}
    local rosters = services.rosters or roster_data
    local pokemon = type(services.pokemon) == "table" and services.pokemon
      or {}
    local meta = services.meta
    local accepted, rejected = {}, {}
    local levels = {}
    local targets = type(state.targetLevels) == "table"
      and state.targetLevels or {}
    for index = 2, #targets do
      levels[#levels + 1] = targets[index]
    end
    local flexPool = type(identity) == "table"
      and type(identity.flexPool) == "table" and identity.flexPool or {}
    for _, lineId in ipairs(flexPool) do
      local line = rosters and rosters.line(meta, lineId)
      local reason
      if not line then
        reason = "missing-line-metadata"
      elseif #levels == 0 then
        reason = "current-flex-levels-unavailable"
      else
        local availableSpecies = false
        for _, stage in ipairs(line.stages or {}) do
          if pokemon[stage.species] then availableSpecies = true; break end
        end
        if not availableSpecies then
          reason = "missing-runtime-species"
        else
          for _, level in ipairs(levels) do
            if not stage_resolver.resolve(line, level, pokemon,
                rosters.preferred_species(lineId)) then
              reason = "no-legal-stage-at-current-level"
              break
            end
          end
        end
      end
      if reason then
        rejected[#rejected + 1] = tostring(lineId) .. ":" .. reason
      else
        accepted[#accepted + 1] = lineId
      end
    end
    return {
      poolCandidates = accepted,
      rejectedConstraints = rejected,
      historicalRejectionsAvailable = false,
    }
  end

  function M.identity_score(party, identity, pokemon)
    local signature = type(identity.signatureLine) == "table"
      and identity.signatureLine.red or identity.signatureLine
    local rationale = as_set(identity.flexPool)
    if type(identity.signatureLine) == "table" then
      for _, lineId in pairs(identity.signatureLine) do rationale[lineId] = true end
    else
      rationale[identity.signatureLine] = true
    end
    local themed, signatureThemed = 0, false
    for index, instance in ipairs(party or {}) do
      local definition = pokemon and pokemon[instance.species]
      local typeMatch = false
      for _, monType in ipairs(definition and definition.types or {}) do
        if monType == identity.typeTheme then typeMatch = true; break end
      end
      local justified = typeMatch or rationale[instance.lineId] == true
      if justified then themed = themed + 1 end
      if index == 1 then
        signatureThemed = justified and (instance.lineId == signature
          or (type(identity.signatureLine) == "table"
            and rationale[instance.lineId]))
      end
    end
    return { themed = themed, signatureThemed = signatureThemed }
  end

  return M
end
