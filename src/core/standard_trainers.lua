return function(deps)
  local rng = deps.rng
  local player_power = deps.player_power
  local ecology = deps.ecology
  local selector = deps.selector
  local validator = deps.validator
  local stage_resolver = deps.stage_resolver
  local on_repair_attempt = deps.onRepairAttempt or function() end
  local growth = deps.growth
  local roster = deps.roster
  local movesets = deps.movesets
  local on_choice = type(deps.on_choice) == "function"
    and deps.on_choice or function() end
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

  local function owned_top(instances)
    local top = 1
    for _, mon in ipairs(instances or {}) do
      top = math.max(top, tonumber(mon.level) or 1)
    end
    return top
  end

  local function median_level(instances)
    local levels = {}
    for _, mon in ipairs(instances or {}) do
      levels[#levels + 1] = tonumber(mon.level) or 1
    end
    table.sort(levels)
    if #levels == 0 then return 1 end
    local middle = math.floor((#levels + 1) / 2)
    if #levels % 2 == 1 then return levels[middle] end
    return math.floor((levels[middle] + levels[middle + 1]) / 2)
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

  local function active_instances(state)
    local byId, out = {}, {}
    for _, instance in ipairs(state.owned or {}) do byId[instance.id] = instance end
    for _, id in ipairs(state.activeIds or {}) do
      if byId[id] then out[#out + 1] = byId[id] end
    end
    return out
  end

  local function ecology_line_ids(rows, meta)
    local out, seen = {}, {}
    for _, row in ipairs(rows or {}) do
      local line = meta and meta.bySpecies and meta.bySpecies[row.species]
      local lineId = line and line.lineId
      if type(lineId) == "string" and not seen[lineId] then
        seen[lineId] = true
        out[#out + 1] = lineId
      end
    end
    return out
  end

  function M.diagnostic_evidence(ctx, root, services)
    ctx, services = ctx or {}, services or {}
    local state = root and root.trainers and root.trainers[ctx.identityKey]
    local data, meta, profile = services.data, services.meta, services.profile
    if type(state) ~= "table" or type(data) ~= "table"
        or type(meta) ~= "table" or type(profile) ~= "table"
        or type(state.owned) ~= "table"
        or type(state.activeIds) ~= "table" then
      return {}
    end
    local override = services.ecologyOverrides
      and ((services.ecologyOverrides.byMap or {})[state.mapId]
        or (services.ecologyOverrides.byClass or {})[state.classId])
    local ecologyRows = ecology.resolve(data, state.mapId, profile, {
      mapId = state.mapId,
      oppClass = state.classId,
      partyIndex = ctx.partyIndex,
      override = override,
    })
    local playerReference = player_power.reference(ctx.playerParty or {})
    local ceiling = growth and growth.contextual_ceiling(
      state.vanillaTop or owned_top(state.owned), playerReference,
      ctx.badgeCount, profile) or nil
    local transitionContext = {
      playTime = ctx.playTime,
      trainerMedian = median_level(state.owned),
      mapId = state.mapId,
      pokemon = data.pokemon,
      meta = meta,
    }
    local catch = roster and roster.catch_preview(state, transitionContext,
      profile, ecologyRows) or {}
    local moveScores = {}
    if movesets and type(movesets.selected_scores) == "function" then
      local active = active_instances(state)
      for _, instance in ipairs(state.owned or {}) do
        local team = {}
        for _, teammate in ipairs(active) do
          if teammate ~= instance then team[#team + 1] = teammate end
        end
        local teamContext = movesets.team_context(team, data.pokemon,
          data.moves)
        local scores = movesets.selected_scores(instance,
          data.pokemon and data.pokemon[instance.species], data.moves,
          profile.aiTier, nil, teamContext)
        for moveId, score in pairs(scores) do
          if moveScores[moveId] == nil or score > moveScores[moveId] then
            moveScores[moveId] = score
          end
        end
      end
    end
    return {
      ceiling = ceiling,
      catchProbability = catch.probability,
      ecologyCandidates = ecology_line_ids(ecologyRows, meta),
      moveScores = moveScores,
    }
  end

  local function log_moves(identityKey, instance)
    for _, moveId in ipairs(instance and instance.moves or {}) do
      on_choice("trainer-moves", "trainer-move-role-v1", {
        tonumber(instance.roleSeed) or 0,
        instance.id or identityKey or "",
        moveId,
      })
    end
  end

  function M.build(ctx, vanillaParty, root, services)
    root.trainers = root.trainers or {}
    local existing = root.trainers[ctx.identityKey]
    local data = services.data
    local meta = services.meta
    local profile = services.profile
    local override = services.ecologyOverrides
      and ((services.ecologyOverrides.byMap or {})[ctx.mapId]
        or (services.ecologyOverrides.byClass or {})[ctx.oppClass])
    local evidence = ecology.resolve(data, ctx.mapId, profile, {
      mapId = ctx.mapId,
      oppClass = ctx.oppClass,
      partyIndex = ctx.partyIndex,
      override = override,
    })
    if existing then
      existing.vanillaTop = existing.vanillaTop or vanilla_top(vanillaParty)
      existing.nextOwnedSerial = existing.nextOwnedSerial or #(existing.owned or {})
      if movesets then
        for _, instance in ipairs(existing.owned or {}) do
          movesets.hydrate_legacy(instance,
            data.pokemon[instance.species], data.moves)
        end
      end
      if existing.lastGrowthBattleCount == nil then
        existing.lastGrowthBattleCount = existing.battleCount or 0
      end
      if existing.lastCatchBattleCount == nil then
        existing.lastCatchBattleCount = existing.battleCount or 0
      end
      if existing.lastResult == "lose" and growth and roster then
        local transitionContext = {
          playTime = ctx.playTime,
          playerParty = ctx.playerParty,
          badgeCount = ctx.badgeCount,
          pokemon = data.pokemon,
          moves = data.moves,
          meta = meta,
          rootSeed = { hi = root.seedHi, lo = root.seedLo },
          mapId = ctx.mapId,
          trainerMedian = median_level(existing.owned),
        }
        local elapsed = math.max(0, (tonumber(ctx.playTime) or 0)
          - (tonumber(existing.lastBattleAt) or tonumber(ctx.playTime) or 0))
        if elapsed > 900 then
          growth.materialize(existing, transitionContext, profile)
          transitionContext.trainerMedian = median_level(existing.owned)
          local caught, catchReport = roster.maybe_catch(existing,
            transitionContext,
            profile, evidence)
          if caught and movesets then
            local teamContext = movesets.team_context(active_instances(existing),
              data.pokemon, data.moves)
            movesets.generate(caught, data.pokemon[caught.species],
              data.moves, profile.aiTier, nil, teamContext)
          end
          if caught then
            on_choice("trainer-catch", "trainer-catch", {
              existing.identityKey or ctx.identityKey,
              existing.battleCount or 0,
            })
            log_moves(existing.identityKey or ctx.identityKey, caught)
          elseif catchReport and catchReport.reason == "roll" then
            on_choice("trainer-no-catch", "trainer-catch", {
              existing.identityKey or ctx.identityKey,
              existing.battleCount or 0,
            })
          end
          local centerDistance = roster.center_distance(services.centerIndex,
            ctx.mapId, profile.pcRadius)
          roster.rotate(existing, profile, centerDistance, {
            meta = meta, pokemon = data.pokemon,
          })
        end
      end
      return party_from_state(existing), existing
    end

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
      vanillaTop = vtop,
      nextOwnedSerial = #selected,
      lastGrowthBattleCount = 0,
      lastCatchBattleCount = 0,
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
      if movesets then
        local teamContext = movesets.team_context(state.owned,
          data.pokemon, data.moves)
        movesets.generate(instance, data.pokemon[instance.species],
          data.moves, profile.aiTier, nil, teamContext)
      end
      state.owned[index] = instance
      state.activeIds[index] = id
    end
    root.trainers[ctx.identityKey] = state
    on_choice("trainer-roster", "trainer-init", { ctx.identityKey })
    for _, instance in ipairs(state.owned) do
      log_moves(ctx.identityKey, instance)
    end
    return party_from_state(state), state
  end

  return M
end
