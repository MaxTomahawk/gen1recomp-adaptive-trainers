return function(deps)
  local rng = deps.rng
  local player_power = deps.player_power
  local ecology = deps.ecology
  local selector = deps.selector
  local validator = deps.validator
  local stage_resolver = deps.stage_resolver
  local M = {}
  local MAX_SLOT_ATTEMPTS = 8

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
    }
  end

  local function candidate_options(ranked, chosen, original, fallback, level)
    local out, seen = {}, {}
    local function add(choice)
      local slot = as_slot(choice, fallback, level)
      local key = tostring(slot.lineId or "") .. "|" .. tostring(slot.species)
      if not seen[key] then
        seen[key] = true
        out[#out + 1] = slot
      end
    end
    add(chosen)
    for _, row in ipairs(ranked or {}) do add(row) end
    add(original)
    return out
  end

  local function copy_team(team)
    local out = {}
    for index, slot in ipairs(team) do
      out[index] = { species = slot.species, level = slot.level,
        lineId = slot.lineId }
    end
    return out
  end

  local function power_distance(team, comparison, context)
    local denominator = validator.power_index(comparison, context.pokemon)
    if denominator <= 0 then return 0 end
    local ratio = validator.power_index(team, context.pokemon) / denominator
    return math.abs(ratio - 1)
  end

  local function repair_power(selected, comparison, options, context)
    local valid = validator.validate_initial(selected, comparison, context)
    if valid then return selected end
    local current = copy_team(selected)
    local distance = power_distance(current, comparison, context)
    for _ = 1, #current do
      local best, bestDistance
      for index = 1, #current do
        for optionIndex = 1, math.min(MAX_SLOT_ATTEMPTS, #options[index]) do
          local trial = copy_team(current)
          trial[index] = options[index][optionIndex]
          local structural = validator.validate_structure(trial, comparison, context)
          if structural then
            local candidateDistance = power_distance(trial, comparison, context)
            if candidateDistance + 1e-12 < distance
                and (not bestDistance or candidateDistance < bestDistance) then
              best, bestDistance = trial, candidateDistance
            end
          end
        end
      end
      if not best then break end
      current, distance = best, bestDistance
      valid = validator.validate_initial(current, comparison, context)
      if valid then return current end
    end
    -- The vanilla-stage comparison is the final safe repair, not a reroll:
    -- it is deterministic and restores only after bounded local candidates
    -- cannot satisfy the hard power invariant.
    return comparison
  end

  function M.build(ctx, vanillaParty, root, services)
    root.trainers = root.trainers or {}
    local existing = root.trainers[ctx.identityKey]
    if existing then return party_from_state(existing), existing end

    local data = services.data
    local meta = services.meta
    local profile = services.profile
    local evidence = ecology.resolve(data, ctx.mapId, profile)
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
      comparison[index] = as_slot(original, slot.species, level)
      options[index] = candidate_options(ranked, choice, original,
        slot.species, level)
      local picked
      for optionIndex = 1, math.min(MAX_SLOT_ATTEMPTS, #options[index]) do
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
