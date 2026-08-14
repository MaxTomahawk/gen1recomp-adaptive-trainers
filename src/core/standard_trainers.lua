return function(deps)
  local rng = deps.rng
  local player_power = deps.player_power
  local ecology = deps.ecology
  local selector = deps.selector
  local validator = deps.validator
  local stage_resolver = deps.stage_resolver
  local on_repair_attempt = deps.onRepairAttempt or function() end
  local M = {}
  local MAX_REPAIR_ATTEMPTS = 24

  local function party_from_state(state)
    local byId = {}
    for _, instance in ipairs(state.owned or {}) do byId[instance.id] = instance end
    local party = {}
    for _, id in ipairs(state.activeIds or {}) do
      local instance = byId[id]
      if instance then
        local slot = { species = instance.species, level = instance.level }
        if instance.moves and #instance.moves > 0 then slot.moves = instance.moves end
        party[#party + 1] = slot
      end
    end
    return party
  end

  local function vanilla_top(vanilla)
    local top = 1
    for _, slot in ipairs(vanilla or {}) do top = math.max(top, slot.level or 1) end
    return top
  end

  local function original_row(slot, level, meta, pokemon)
    local line = meta.bySpecies and meta.bySpecies[slot.species]
    if not line then return { line = nil, species = slot.species } end
    return {
      line = line,
      species = stage_resolver.resolve(line, level, pokemon, slot.species)
        or slot.species,
    }
  end

  local function as_slot(choice, fallback, level)
    return {
      species = (choice and choice.species) or fallback,
      level = level,
      lineId = choice and choice.line and choice.line.lineId,
      score = choice and choice.score,
    }
  end

  local function candidate_options(ranked, chosen, original, blueprint, level)
    local out, seen = {}, {}
    local function add(choice)
      local slot = as_slot(choice, blueprint.species, level)
      local key = tostring(slot.lineId or "") .. "|" .. tostring(slot.species)
      if not seen[key] then
        seen[key] = true
        out[#out + 1] = slot
      end
    end
    add(chosen)
    for _, row in ipairs(ranked or {}) do add(row) end
    add(original)
    add({ species = blueprint.species, line = blueprint.line, score = -1 })
    return out
  end

  local function copy_team(team)
    local out = {}
    for index, slot in ipairs(team) do
      out[index] = { species = slot.species, level = slot.level,
        lineId = slot.lineId, score = slot.score }
    end
    return out
  end

  local function team_key(team)
    local parts = {}
    for index, slot in ipairs(team) do
      parts[index] = tostring(slot.lineId or "") .. ":"
        .. tostring(slot.species or "")
    end
    return table.concat(parts, "|")
  end

  local function best_score_fallback(comparison, options, context)
    local beams = { { team = {}, score = 0, key = "" } }
    for index = 1, #comparison do
      local expanded = {}
      for _, beam in ipairs(beams) do
        for _, option in ipairs(options[index]) do
          local team = copy_team(beam.team)
          team[index] = option
          local structural = validator.validate_structure(team, comparison,
            context)
          if structural then
            expanded[#expanded + 1] = {
              team = team,
              score = beam.score + (tonumber(option.score) or -1),
              key = team_key(team),
            }
          end
        end
      end
      table.sort(expanded, function(left, right)
        if left.score ~= right.score then return left.score > right.score end
        return left.key < right.key
      end)
      beams = {}
      for beamIndex = 1, math.min(MAX_REPAIR_ATTEMPTS, #expanded) do
        beams[beamIndex] = expanded[beamIndex]
      end
    end
    for attempt, beam in ipairs(beams) do
      if attempt > MAX_REPAIR_ATTEMPTS then break end
      on_repair_attempt(attempt, beam.team)
      local valid = validator.validate_initial(beam.team, comparison, context)
      if valid then return beam.team end
    end
    local baseline = copy_team(comparison)
    local valid = validator.validate_initial(baseline, comparison, context)
    assert(valid, "no valid deterministic initial trainer fallback")
    return baseline
  end

  local function repair_power(selected, comparison, options, context)
    local valid = validator.validate_initial(selected, comparison, context)
    if valid then return selected end
    return best_score_fallback(comparison, options, context)
  end

  local function vanilla_party_hash(vanillaParty)
    local parts = { "adaptive-trainers-vanilla-party-v1", #vanillaParty }
    for index, slot in ipairs(vanillaParty) do
      parts[#parts + 1] = index
      parts[#parts + 1] = slot.species or ""
      parts[#parts + 1] = slot.level or 0
      for moveIndex, move in ipairs(slot.moves or {}) do
        parts[#parts + 1] = moveIndex
        parts[#parts + 1] = move
      end
    end
    local hash = rng.seed(parts)
    return string.format("%08x%08x", hash.hi, hash.lo)
  end

  function M.build(ctx, vanillaParty, root, services)
    root.trainers = root.trainers or {}
    local existing = root.trainers[ctx.identityKey]
    if existing then return party_from_state(existing), existing end

    local data = services.data
    local meta = services.meta
    local profile = services.profile
    local override = services.ecologyOverrides
      and ((services.ecologyOverrides.byMap or {})[ctx.mapId]
        or (services.ecologyOverrides.byClass or {})[ctx.oppClass])
    local evidence = ecology.resolve(data, ctx.mapId, profile, {
      mapId = ctx.mapId,
      oppClass = ctx.oppClass,
      override = override,
    })
    local stream = rng.stream({ hi = root.seedHi, lo = root.seedLo },
      "trainer-init", ctx.identityKey)
    local reference = player_power.reference(ctx.playerParty)
    local vtop = vanilla_top(vanillaParty)
    local selected = {}
    local comparison = {}
    local options = {}
    local validationContext = {
      meta = meta, pokemon = data.pokemon, profile = profile,
    }

    for index, slot in ipairs(vanillaParty) do
      local jitter = stream:integer(-1, 1)
      local level = player_power.initial_level(slot.level, vtop, reference,
        profile, jitter)
      local ranked = selector.rank({
        vanillaSpecies = slot.species,
        targetLevel = level,
        profile = profile,
        evidence = evidence,
        meta = meta,
        pokemon = data.pokemon,
        team = selected,
      })
      local choice = selector.choose(ranked, stream)
        or original_row(slot, level, meta, data.pokemon)
      local original = original_row(slot, level, meta, data.pokemon)
      local blueprintLine = meta.bySpecies and meta.bySpecies[slot.species]
      local blueprint = { species = slot.species, line = blueprintLine }
      comparison[index] = as_slot(blueprint, slot.species, level)
      options[index] = candidate_options(ranked, choice, original,
        blueprint, level)
      local picked
      for optionIndex = 1, math.min(MAX_REPAIR_ATTEMPTS, #options[index]) do
        selected[index] = options[index][optionIndex]
        local structureOk = validator.validate_structure(selected,
          comparison, validationContext)
        if structureOk then
          picked = selected[index]
          break
        end
      end
      selected[index] = picked or comparison[index]
    end

    selected = repair_power(selected, comparison, options, validationContext)
    local finalValid = validator.validate_initial(selected, comparison,
      validationContext)
    assert(finalValid, "initial trainer party failed hard invariants")

    local state = {
      identityKey = ctx.identityKey,
      classId = ctx.oppClass,
      mapId = ctx.mapId,
      owned = {},
      activeIds = {},
      firstGeneratedAt = ctx.playTime or 0,
      lastBattleAt = ctx.playTime or 0,
      lastGrowthAt = ctx.playTime or 0,
      lastCatchCheckAt = ctx.playTime or 0,
      battleCount = 0,
      lossCount = 0,
      generationVersion = 1,
      vanillaPartyHash = vanilla_party_hash(vanillaParty),
    }
    for index, slot in ipairs(selected) do
      local id = ctx.identityKey .. "#" .. index
      local instance = {
        id = id,
        lineId = slot.lineId,
        species = slot.species,
        level = slot.level,
        acquiredAt = ctx.playTime or 0,
        originMap = ctx.mapId,
        useCount = 0,
        attachment = 0,
        roleSeed = rng.seed({ root.seedHi, root.seedLo,
          "trainer-role", ctx.identityKey, index }).lo,
      }
      state.owned[index] = instance
      state.activeIds[index] = id
    end
    root.trainers[ctx.identityKey] = state
    return party_from_state(state), state
  end

  return M
end
