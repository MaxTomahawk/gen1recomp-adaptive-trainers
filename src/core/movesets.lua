return function(deps)
  local rng = deps.rng
  local packages = deps.packages
  local M = {}

  local function as_set(values)
    local out = {}
    for _, value in ipairs(values or {}) do out[value] = true end
    return out
  end

  local function append_unique(values, seen, id, moveDefs)
    if type(id) == "string" and moveDefs[id] and not seen[id] then
      seen[id] = true
      values[#values + 1] = id
    end
  end

  function M.legal_pool(speciesDef, level, moveDefs, package)
    speciesDef, moveDefs = speciesDef or {}, moveDefs or {}
    level = math.max(1, tonumber(level) or 1)
    local pool = { level = {}, tm = {}, technique = {}, byId = {} }
    local levelSeen = {}
    for _, id in ipairs(speciesDef.level1Moves or {}) do
      append_unique(pool.level, levelSeen, id, moveDefs)
    end
    for _, row in ipairs(speciesDef.learnset or {}) do
      if (tonumber(row.level) or math.huge) <= level then
        append_unique(pool.level, levelSeen, row.move, moveDefs)
      end
    end
    local tmSeen = {}
    for _, id in ipairs(speciesDef.tmhm or {}) do
      append_unique(pool.tm, tmSeen, id, moveDefs)
    end
    local techniqueSeen = {}
    for _, id in ipairs(package and package.techniques or {}) do
      append_unique(pool.technique, techniqueSeen, id, moveDefs)
    end
    for _, id in ipairs(pool.level) do pool.byId[id] = "level" end
    for _, id in ipairs(pool.tm) do
      if not pool.byId[id] then pool.byId[id] = "tm" end
    end
    for _, id in ipairs(pool.technique) do pool.byId[id] = "technique" end
    return pool
  end

  function M.level_moves(speciesDef, level, moveDefs)
    local pool = M.legal_pool(speciesDef, level, moveDefs)
    local moves = {}
    for _, id in ipairs(pool.level) do moves[#moves + 1] = id end
    while #moves > 4 do table.remove(moves, 1) end
    return moves
  end

  function M.hydrate_legacy(instance, speciesDef, moveDefs)
    local generated = instance.moves == nil
    if instance.moves == nil then
      instance.moves = M.level_moves(speciesDef, instance.level, moveDefs)
    end
    local pool = M.legal_pool(speciesDef, instance.level, moveDefs)
    instance.moveSources = instance.moveSources or {}
    for _, id in ipairs(instance.moves) do
      instance.moveSources[id] = instance.moveSources[id]
        or (generated and "level") or pool.byId[id] or "inherited"
    end
    instance.movesetVersion = packages.version
    return instance.moves
  end

  local function type_matches(types, wanted)
    for _, value in ipairs(types or {}) do
      if value == wanted then return true end
    end
    return false
  end

  function M.role(moveId, moveDef, speciesDef)
    moveDef = moveDef or {}
    if (tonumber(moveDef.power) or 0) > 0 then
      if type_matches(speciesDef and speciesDef.types, moveDef.type) then
        return "STAB_DAMAGE"
      end
      return "COVERAGE_DAMAGE"
    end
    local explicit = packages.moves[moveId]
      or packages.effects[moveDef.effect]
    if explicit then return explicit end
    local effect = tostring(moveDef.effect or "")
    if effect:find("_UP", 1, true) then return "SETUP" end
    if effect:find("HEAL", 1, true) then return "SUSTAIN" end
    if effect:find("SLEEP", 1, true) or effect:find("POISON", 1, true)
        or effect:find("PARALYZE", 1, true) then
      return "STATUS"
    end
    return "UTILITY"
  end

  function M.team_context(instances, pokemon, moveDefs)
    local context = { roleCounts = {}, damageTypeCounts = {} }
    for _, instance in ipairs(instances or {}) do
      local speciesDef = pokemon and pokemon[instance.species] or {}
      for _, moveId in ipairs(instance.moves or {}) do
        local moveDef = moveDefs and moveDefs[moveId]
        if moveDef then
          local role = M.role(moveId, moveDef, speciesDef)
          context.roleCounts[role] = (context.roleCounts[role] or 0) + 1
          if (tonumber(moveDef.power) or 0) > 0 then
            local moveType = moveDef.type
            context.damageTypeCounts[moveType]
              = (context.damageTypeCounts[moveType] or 0) + 1
          end
        end
      end
    end
    return context
  end

  local function tie_break(instance, moveId)
    local seed = rng.seed({ "trainer-move-role-v1",
      tonumber(instance and instance.roleSeed) or 0,
      instance and instance.id or "", moveId })
    return (seed.lo % 10000) / 1000000
  end

  local function candidate_score(instance, speciesDef, moveId, moveDef,
      source, tier, package, teamContext)
    local rules = packages.tiers[tier] or packages.tiers[0]
    local scoring = packages.scoring
    local role = M.role(moveId, moveDef, speciesDef)
    local power = math.max(0, tonumber(moveDef and moveDef.power) or 0)
    local accuracy = math.max(0, tonumber(moveDef and moveDef.accuracy) or 100)
    local score
    if power > 0 then
      score = power * scoring.damagePowerWeight
        + accuracy * scoring.accuracyWeight
      if role == "STAB_DAMAGE" then
        score = score + rules.stabBonus
      else
        score = score + rules.coverageBonus
      end
    else
      score = scoring.statusBase + (rules.roleWeights[role] or 0)
        + accuracy * scoring.statusAccuracyWeight
    end
    if source == "tm" then score = score - rules.tmPenalty end
    if source == "technique" then
      score = score + scoring.techniqueBonus
    end
    if package then
      score = score + ((package.roleWeights or {})[role] or 0)
      if as_set(package.signatureMoves)[moveId] then
        score = score + scoring.signatureBonus
      end
    end
    if tier >= 3 and teamContext then
      if power > 0 then
        local overlap = (teamContext.damageTypeCounts or {})[moveDef.type] or 0
        score = score - overlap * (rules.teamDamageTypePenalty or 0)
        if role == "COVERAGE_DAMAGE" and overlap == 0 then
          score = score + (rules.uncoveredCoverageBonus or 0)
        end
      else
        local overlap = (teamContext.roleCounts or {})[role] or 0
        score = score - overlap * (rules.teamRolePenalty or 0)
      end
    end
    return score + tie_break(instance, moveId), role
  end

  local function ranked_candidates(instance, speciesDef, moveDefs, tier,
      package, teamContext)
    local pool = M.legal_pool(speciesDef, instance.level, moveDefs, package)
    local rows, seen = {}, {}
    local function add_all(values)
      for _, id in ipairs(values) do
        if not seen[id] then
          seen[id] = true
          local source = pool.byId[id]
          local score, role = candidate_score(instance, speciesDef, id,
            moveDefs[id], source, tier, package, teamContext)
          rows[#rows + 1] = { id = id, source = source, score = score,
            role = role, type = moveDefs[id].type }
        end
      end
    end
    add_all(pool.level)
    add_all(pool.tm)
    add_all(pool.technique)
    table.sort(rows, function(left, right)
      if left.score ~= right.score then return left.score > right.score end
      return left.id < right.id
    end)
    return rows, pool
  end

  local function redundancy_key(row)
    if row.role == "STAB_DAMAGE" or row.role == "COVERAGE_DAMAGE" then
      return "DAMAGE:" .. tostring(row.type)
    end
    return row.role
  end

  local function refresh_redundancy_key(row)
    return redundancy_key(row)
  end

  local function select_moves(rows, tier)
    local rules = packages.tiers[tier] or packages.tiers[0]
    local selected, selectedIds, roleCounts = {}, {}, {}
    local tmCount = 0
    local function can_add(row, enforceRedundancy)
      if selectedIds[row.id] then return false end
      if row.source == "tm" and tmCount >= rules.maxTm then return false end
      if enforceRedundancy then
        local key = redundancy_key(row)
        local limit = key:find("DAMAGE:", 1, true) == 1 and 2 or 1
        if (roleCounts[key] or 0) >= limit then return false end
      end
      return true
    end
    local function add(row)
      selected[#selected + 1] = row
      selectedIds[row.id] = true
      local key = redundancy_key(row)
      roleCounts[key] = (roleCounts[key] or 0) + 1
      if row.source == "tm" then tmCount = tmCount + 1 end
    end
    for _, row in ipairs(rows) do
      if row.role == "STAB_DAMAGE" and can_add(row, false) then
        add(row)
        break
      end
    end
    for _, row in ipairs(rows) do
      if #selected >= 4 then break end
      if can_add(row, true) then add(row) end
    end
    for _, row in ipairs(rows) do
      if #selected >= 4 then break end
      if can_add(row, false) then add(row) end
    end
    return selected
  end

  function M.generate(instance, speciesDef, moveDefs, tier, package,
      teamContext)
    instance = instance or {}
    tier = math.max(0, math.min(4, math.floor(tonumber(tier) or 0)))
    local rows = ranked_candidates(instance, speciesDef, moveDefs, tier,
      package, teamContext)
    local selected = select_moves(rows, tier)
    local moves = {}
    instance.moveSources = {}
    for _, row in ipairs(selected) do
      moves[#moves + 1] = row.id
      instance.moveSources[row.id] = row.source
    end
    instance.moves = moves
    instance.movesetVersion = packages.version
    return instance.moves
  end

  local function existing_row(instance, speciesDef, moveDefs, pool, tier,
      package, teamContext, id)
    local def = moveDefs[id]
    if not def then return { id = id, score = -math.huge,
      role = "UNKNOWN", type = "", source = "inherited" } end
    local source = (instance.moveSources or {})[id]
      or pool.byId[id] or "inherited"
    local score, role = candidate_score(instance, speciesDef, id, def,
      source, tier, package, teamContext)
    return { id = id, score = score, role = role, type = def.type,
      source = source }
  end

  function M.refresh(instance, reason, speciesDef, moveDefs, tier, package,
      teamContext)
    tier = math.max(0, math.min(4, math.floor(tonumber(tier) or 0)))
    instance.moves = instance.moves or {}
    instance.moveSources = instance.moveSources or {}
    if #instance.moves == 0 then
      M.generate(instance, speciesDef, moveDefs, tier, package, teamContext)
      instance.lastMovesetRefreshReason = reason
      return #instance.moves > 0
    end
    local rows, pool = ranked_candidates(instance, speciesDef, moveDefs,
      tier, package, teamContext)
    local ideal = select_moves(rows, tier)
    local known = as_set(instance.moves)
    local incoming
    for _, row in ipairs(ideal) do
      if not known[row.id] then incoming = row; break end
    end
    if not incoming then return false end
    if #instance.moves < 4 then
      instance.moves[#instance.moves + 1] = incoming.id
      instance.moveSources[incoming.id] = incoming.source
      instance.lastMovesetRefreshReason = reason
      return true
    end

    local existing, counts = {}, {}
    local currentTmCount = 0
    for index, id in ipairs(instance.moves) do
      local row = existing_row(instance, speciesDef, moveDefs, pool, tier,
        package, teamContext, id)
      row.index = index
      existing[#existing + 1] = row
      if row.source == "tm" then currentTmCount = currentTmCount + 1 end
      local key = refresh_redundancy_key(row)
      counts[key] = (counts[key] or 0) + 1
    end
    table.sort(existing, function(left, right)
      local leftRedundant = (counts[refresh_redundancy_key(left)] or 0) > 1
      local rightRedundant = (counts[refresh_redundancy_key(right)] or 0) > 1
      if leftRedundant ~= rightRedundant then return leftRedundant end
      if left.score ~= right.score then return left.score < right.score end
      return left.id > right.id
    end)
    local rules = packages.tiers[tier] or packages.tiers[0]
    local outgoing
    for _, row in ipairs(existing) do
      local redundant = (counts[refresh_redundancy_key(row)] or 0) > 1
      local replaceable = reason == "evolution" or redundant
      local tmAllowed = incoming.source ~= "tm"
        or currentTmCount < rules.maxTm or row.source == "tm"
      if replaceable and tmAllowed then
        outgoing = row
        break
      end
    end
    if not outgoing then return false end
    local margin = packages.refreshMargin[reason]
      or packages.refreshMargin["level-up"] or 0
    if incoming.score < outgoing.score + margin then return false end
    instance.moves[outgoing.index] = incoming.id
    instance.moveSources[outgoing.id] = nil
    instance.moveSources[incoming.id] = incoming.source
    instance.lastMovesetRefreshReason = reason
    return true
  end

  return M
end
