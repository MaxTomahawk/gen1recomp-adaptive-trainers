return function(deps)
  local rng = deps.rng
  local M = {}

  local CENTER_FALLBACK = {
    CELADON_POKECENTER = true, CERULEAN_POKECENTER = true,
    CINNABAR_POKECENTER = true, FUCHSIA_POKECENTER = true,
    INDIGO_PLATEAU_LOBBY = true, LAVENDER_POKECENTER = true,
    MT_MOON_POKECENTER = true, PEWTER_POKECENTER = true,
    ROCK_TUNNEL_POKECENTER = true, SAFFRON_POKECENTER = true,
    VERMILION_POKECENTER = true, VIRIDIAN_POKECENTER = true,
  }

  local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
  end

  local function as_set(values)
    local out = {}
    for key, value in pairs(values or {}) do
      if type(key) == "number" then out[value] = true
      elseif value then out[key] = true end
    end
    return out
  end

  function M.catch_probability(elapsedSeconds, ownedCount, profile,
      ecologyAvailability)
    profile = profile or {}
    local hours = math.max(0, (tonumber(elapsedSeconds) or 0) / 3600 - 0.25)
    if hours <= 0 or ecologyAvailability <= 0 then return 0 end
    local tau = math.max(0.001, tonumber(profile.catchTauHours) or 1)
    local timeFactor = 1 - math.exp(-hours / tau)
    local target = math.max(1, tonumber(profile.targetOwned) or 1)
    local need = clamp((target - (ownedCount or 0) + 1) / target, 0.15, 1)
    return clamp((profile.catchMax or 0) * timeFactor * need
      * ecologyAvailability, 0, 1)
  end

  local function group_allowed(line, profile)
    local required = profile and profile.catchGroups
    if type(required) ~= "table" or #required == 0 then return true end
    for _, group in ipairs(line.groups or {}) do
      for _, token in ipairs(required) do
        if group:find(token, 1, true) then return true end
      end
    end
    return false
  end

  local function line_team_fit(line, species, profile, state, ctx)
    local active = as_set(state and state.activeIds)
    local hasActive = next(active) ~= nil
    local sameLine, samePrimary = 0, 0
    local definition = ctx and ctx.pokemon and ctx.pokemon[species]
    local primary = definition and definition.types and definition.types[1]
    local existingRoles = {}
    for _, mon in ipairs(state and state.owned or {}) do
      if not hasActive or active[mon.id] then
        if mon.lineId == line.lineId then sameLine = sameLine + 1 end
        local monDef = ctx and ctx.pokemon and ctx.pokemon[mon.species]
        if primary and monDef and monDef.types
            and monDef.types[1] == primary then samePrimary = samePrimary + 1 end
        local monLine = ctx and ctx.meta and ctx.meta.bySpecies
          and ctx.meta.bySpecies[mon.species]
        for _, role in ipairs(monLine and monLine.roles or {}) do
          existingRoles[role] = true
        end
      end
    end
    if sameLine > 0 and not profile.allowDuplicateLines then return 0 end
    local typeFit = samePrimary == 0 and 1 or (samePrimary == 1 and 0.5 or 0)
    local newRole = false
    for _, role in ipairs(line.roles or {}) do
      if not existingRoles[role] then newRole = true; break end
    end
    local roleFit = newRole and 1 or 0.5
    return 0.7 * typeFit + 0.3 * roleFit
  end

  local function class_affinity(line, profile)
    local wanted = as_set(profile and profile.classTags)
    for _, tag in ipairs(line.classTags or {}) do
      if wanted[tag] then return 1 end
    end
    return 0
  end

  local function active_instances(state)
    local active, out = as_set(state and state.activeIds), {}
    for _, mon in ipairs(state and state.owned or {}) do
      if active[mon.id] then out[#out + 1] = mon end
    end
    return out
  end

  local function active_line_count(state, lineId)
    local count = 0
    for _, mon in ipairs(active_instances(state)) do
      if mon.lineId == lineId then count = count + 1 end
    end
    return count
  end

  local function hard_catch_allowed(line, species, profile, state, ctx)
    local active = active_instances(state)
    local rarity3 = 0
    for _, mon in ipairs(active) do
      local monLine = ctx and ctx.meta and ((ctx.meta.lines or {})[mon.lineId]
        or (ctx.meta.bySpecies or {})[mon.species])
      if monLine and monLine.rarity == 3 then rarity3 = rarity3 + 1 end
    end
    if line.rarity == 3 and rarity3 >= (profile.maxRarity3 or 1) then
      return false
    end
    local finalSize = #active + 1
    if finalSize >= 2 and finalSize <= 4 and not profile.specialistType then
      local definition = ctx and ctx.pokemon and ctx.pokemon[species]
      local primary = definition and definition.types and definition.types[1]
      if primary then
        local same = 0
        for _, mon in ipairs(active) do
          local monDef = ctx.pokemon and ctx.pokemon[mon.species]
          if monDef and monDef.types and monDef.types[1] == primary then
            same = same + 1
          end
        end
        if same >= 2 then return false end
      end
    end
    return true
  end

  local function eligible_candidates(evidence, profile, meta, state, ctx)
    local out, raw = {}, {}
    local maxWeight = 0
    for _, row in ipairs(evidence or {}) do
      local line = meta and meta.bySpecies and meta.bySpecies[row.species]
      local rarity = tonumber(line and line.rarity) or 0
      if line and line.genericEligible ~= false and rarity < 4
          and rarity <= math.min(3, profile.rarityAllowance or 2)
          and line.populationModel ~= "UNIQUE_SPECIES"
          and line.populationModel ~= "ULTRA_RARE_SPECIES"
          and line.populationModel ~= "STATIC_SPECIES"
          and group_allowed(line, profile)
          and hard_catch_allowed(line, row.species, profile, state, ctx) then
        local weight = math.max(0, tonumber(row.weight) or 0)
        maxWeight = math.max(maxWeight, weight)
        raw[#raw + 1] = { evidence = row, line = line,
          rawWeight = weight, rarity = rarity }
      end
    end
    local hasDistinct = false
    for _, row in ipairs(raw) do
      if active_line_count(state, row.line.lineId) == 0 then
        hasDistinct = true
        break
      end
    end
    local availability = 0
    for _, row in ipairs(raw) do
      local duplicate = active_line_count(state, row.line.lineId) > 0
      local ecologyFit = maxWeight > 0 and row.rawWeight / maxWeight or 0
      local teamFit = line_team_fit(row.line, row.evidence.species, profile,
        state, ctx)
      local score = 0.35 * ecologyFit
        + 0.25 * class_affinity(row.line, profile)
        + 0.40 * teamFit - row.rarity * 0.10
      if (profile.allowDuplicateLines or not duplicate or not hasDistinct)
          and score > (profile.catchSelectivity or 0) then
        availability = availability + row.rawWeight
        out[#out + 1] = { evidence = row.evidence, line = row.line,
          weight = math.max(0.001, score), score = score }
      end
    end
    table.sort(out, function(left, right)
      if left.weight ~= right.weight then return left.weight > right.weight end
      return left.line.lineId < right.line.lineId
    end)
    return out, clamp(availability, 0, 1)
  end

  local function weighted_choice(rows, stream)
    local total = 0
    for _, row in ipairs(rows) do total = total + row.weight end
    if total <= 0 then return rows[1] end
    local roll, cursor = stream:float() * total, 0
    for _, row in ipairs(rows) do
      cursor = cursor + row.weight
      if roll < cursor then return row end
    end
    return rows[#rows]
  end

  local function source_bounds(row)
    local low, high, origin
    for _, source in ipairs(row.sources or {}) do
      if type(source.level) == "number" then
        low = low and math.min(low, source.level) or source.level
        high = high and math.max(high, source.level) or source.level
      end
      origin = origin or source.mapId
    end
    return low or 1, high or low or 1, origin
  end

  local function active_cap(state, profile)
    return math.min(6, math.max(#(state.activeIds or {}),
      tonumber(profile and profile.targetOwned) or 1))
  end

  function M.maybe_catch(state, ctx, profile, evidence)
    state, ctx, profile = state or {}, ctx or {}, profile or {}
    local now = tonumber(ctx.playTime) or 0
    local elapsed = math.max(0, now - (tonumber(state.lastBattleAt) or now))
    local report = { elapsedSeconds = elapsed, probability = 0,
      candidateCount = 0 }
    if state.lastCatchBattleCount == state.battleCount then
      report.reason = "already-checked"
      return nil, report
    end
    state.lastCatchBattleCount = state.battleCount
    state.lastCatchCheckAt = now
    local candidates, availability = eligible_candidates(evidence, profile,
      ctx.meta, state, ctx)
    report.candidateCount = #candidates
    report.ecologyAvailability = availability
    report.probability = M.catch_probability(elapsed, #(state.owned or {}),
      profile, availability)
    if #candidates == 0 or report.probability <= 0 then
      report.reason = elapsed <= 900 and "grace" or "no-candidates"
      return nil, report
    end

    local stream = ctx.stream or rng.stream(ctx.rootSeed or rng.seed({
      "trainer-catch-root", state.identityKey or "" }), "trainer-catch",
      state.identityKey or "", state.battleCount or 0)
    if stream:float() >= report.probability then
      report.reason = "roll"
      return nil, report
    end
    local selected = weighted_choice(candidates, stream)
    local low, high, originMap = source_bounds(selected.evidence)
    local wildLevel = stream:integer(low, high)
    local trainedLevel = wildLevel + stream:integer(0, 2)
    local medianLimit = math.max(1, (tonumber(ctx.trainerMedian) or high + 1) - 1)
    local level = math.max(1, math.min(trainedLevel, high + 2, medianLimit))
    local species = selected.evidence.species
    state.nextOwnedSerial = math.max(tonumber(state.nextOwnedSerial) or 0,
      #(state.owned or {})) + 1
    local id = (state.identityKey or "trainer") .. "#catch-"
      .. tostring(state.nextOwnedSerial)
    local instance = { id = id, lineId = selected.line.lineId,
      species = species, level = level, acquiredAt = now,
      originMap = originMap or ctx.mapId, useCount = 0, attachment = 0,
      roleSeed = rng.seed({ ctx.rootSeed and ctx.rootSeed.hi or 0,
        ctx.rootSeed and ctx.rootSeed.lo or 0, "trainer-role", id }).lo }
    state.owned = state.owned or {}
    state.activeIds = state.activeIds or {}
    state.owned[#state.owned + 1] = instance
    if #state.activeIds < active_cap(state, profile) then
      state.activeIds[#state.activeIds + 1] = id
    end
    report.reason = "caught"
    report.selectedLine = selected.line.lineId
    return instance, report
  end

  local function add_directed_edge(adjacency, left, right)
    if type(left) ~= "string" or type(right) ~= "string" then return end
    adjacency[left] = adjacency[left] or {}
    adjacency[right] = adjacency[right] or {}
    adjacency[left][right] = true
  end

  function M.center_index(data)
    local index = { centers = {}, adjacency = {} }
    for mapId, map in pairs(data and data.maps or {}) do
      index.adjacency[mapId] = index.adjacency[mapId] or {}
      local center = CENTER_FALLBACK[mapId] or mapId:find("POKECENTER", 1, true)
      for _, object in ipairs(map.objects or {}) do
        local marker = tostring(object.name or "") .. " "
          .. tostring(object.text or "")
        if marker:find("NURSE", 1, true) then center = true end
      end
      if center then index.centers[mapId] = true end
      for _, connection in pairs(map.connections or {}) do
        add_directed_edge(index.adjacency, mapId,
          connection and (connection.map or connection.destMap))
      end
      for _, warp in ipairs(map.warps or {}) do
        add_directed_edge(index.adjacency, mapId, warp.destMap)
      end
    end
    return index
  end

  function M.center_distance(index, mapId, maxRadius)
    if not index or not index.adjacency or not index.adjacency[mapId] then
      return nil
    end
    maxRadius = math.max(0, tonumber(maxRadius) or 0)
    local queue, seen, cursor = { { mapId, 0 } }, { [mapId] = true }, 1
    while cursor <= #queue do
      local current = queue[cursor]
      cursor = cursor + 1
      if index.centers[current[1]] then return current[2] end
      if current[2] < maxRadius then
        local neighbors = {}
        for id in pairs(index.adjacency[current[1]] or {}) do
          neighbors[#neighbors + 1] = id
        end
        table.sort(neighbors)
        for _, id in ipairs(neighbors) do
          if not seen[id] then
            seen[id] = true
            queue[#queue + 1] = { id, current[2] + 1 }
          end
        end
      end
    end
    return nil
  end

  local function ids_equal(left, right)
    if #left ~= #right then return false end
    for index, id in ipairs(left) do if right[index] ~= id then return false end end
    return true
  end

  function M.rotate(state, profile, centerDistance, context)
    state, profile, context = state or {}, profile or {}, context or {}
    state.owned, state.activeIds = state.owned or {}, state.activeIds or {}
    local cap = active_cap(state, profile)
    if #state.activeIds < cap then
      local active = as_set(state.activeIds)
      for _, mon in ipairs(state.owned) do
        if not active[mon.id] and #state.activeIds < cap then
          state.activeIds[#state.activeIds + 1] = mon.id
          active[mon.id] = true
        end
      end
      return true
    end
    if centerDistance == nil or #state.owned <= #state.activeIds then return false end
    local behavior = profile.rosterBehavior or "casual"
    if behavior == "casual" then return false end

    local ranked = {}
    for _, mon in ipairs(state.owned) do ranked[#ranked + 1] = mon end
    table.sort(ranked, function(left, right)
      local leftScore, rightScore
      if behavior == "collector" then
        leftScore = (left.acquiredAt or 0) * 100 - (left.useCount or 0)
        rightScore = (right.acquiredAt or 0) * 100 - (right.useCount or 0)
      else
        local leftLine = context.meta and context.meta.bySpecies
          and context.meta.bySpecies[left.species]
        local rightLine = context.meta and context.meta.bySpecies
          and context.meta.bySpecies[right.species]
        leftScore = (left.level or 1) * 100 + (leftLine and leftLine.powerBand or 0)
        rightScore = (right.level or 1) * 100 + (rightLine and rightLine.powerBand or 0)
      end
      if leftScore ~= rightScore then return leftScore > rightScore end
      return tostring(left.id) < tostring(right.id)
    end)
    local chosen, chosenLines, rarity3, primaryCounts = {}, {}, 0, {}
    local function line_for(mon)
      return context.meta and ((context.meta.lines or {})[mon.lineId]
        or (context.meta.bySpecies or {})[mon.species])
    end
    local function can_add(mon, allowPoolDuplicate)
      local line = line_for(mon)
      local lineId = mon.lineId or (line and line.lineId)
      if lineId and chosenLines[lineId] and not profile.allowDuplicateLines
          and not allowPoolDuplicate then return false end
      if line and line.rarity == 3
          and rarity3 >= (profile.maxRarity3 or 1) then return false end
      if cap >= 2 and cap <= 4 and not profile.specialistType then
        local definition = context.pokemon and context.pokemon[mon.species]
        local primary = definition and definition.types and definition.types[1]
        if primary and (primaryCounts[primary] or 0) >= 2 then return false end
      end
      return true
    end
    local function add(mon)
      chosen[#chosen + 1] = mon.id
      local line = line_for(mon)
      local lineId = mon.lineId or (line and line.lineId)
      if lineId then chosenLines[lineId] = true end
      if line and line.rarity == 3 then rarity3 = rarity3 + 1 end
      local definition = context.pokemon and context.pokemon[mon.species]
      local primary = definition and definition.types and definition.types[1]
      if primary then primaryCounts[primary] = (primaryCounts[primary] or 0) + 1 end
    end
    for _, mon in ipairs(ranked) do
      if #chosen >= cap then break end
      if can_add(mon, false) then add(mon) end
    end
    -- Duplicate lines are the last-resort pool-too-small exception from the
    -- baseline; rarity and type constraints remain hard.
    if #chosen < cap then
      local selected = as_set(chosen)
      for _, mon in ipairs(ranked) do
        if #chosen >= cap then break end
        if not selected[mon.id] and can_add(mon, true) then
          add(mon)
          selected[mon.id] = true
        end
      end
    end
    if ids_equal(chosen, state.activeIds) then return false end
    state.activeIds = chosen
    return true
  end

  return M
end
