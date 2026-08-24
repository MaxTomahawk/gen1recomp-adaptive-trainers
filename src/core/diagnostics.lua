local M = {}

local function finite(value)
  return type(value) == "number" and value == value
    and value ~= math.huge and value ~= -math.huge
end

local function safe_scalar(value)
  local kind = type(value)
  if kind == "string" or kind == "boolean" or finite(value) then
    return value, true
  end
  return nil, false
end

local function safe_key(value)
  return type(value) == "string" or finite(value)
end

local function safe_copy(value, stack)
  local scalar, scalarOk = safe_scalar(value)
  if scalarOk then return scalar, true end
  if type(value) ~= "table" or getmetatable(value) ~= nil then
    return nil, false
  end
  stack = stack or {}
  if stack[value] then return nil, false end
  stack[value] = true

  local numericKeys, sequence = {}, true
  for key in pairs(value) do
    if finite(key) and key > 0 and key == math.floor(key) then
      numericKeys[#numericKeys + 1] = key
    else
      sequence = false
      break
    end
  end

  local out = {}
  if sequence then
    table.sort(numericKeys)
    for _, key in ipairs(numericKeys) do
      local copied, ok = safe_copy(value[key], stack)
      if ok then out[#out + 1] = copied end
    end
  else
    for key, item in pairs(value) do
      local copiedItem, itemOk = safe_copy(item, stack)
      if safe_key(key) and itemOk then out[key] = copiedItem end
    end
  end
  stack[value] = nil
  return out, true
end

local function copy_array(values)
  if type(values) ~= "table" or getmetatable(values) ~= nil then return {} end
  local out = {}
  for _, value in ipairs(values) do
    local copied, ok = safe_copy(value)
    if ok then out[#out + 1] = copied end
  end
  return out
end

local function copy_map(values)
  local copied, ok = safe_copy(values)
  if ok and type(copied) == "table" then return copied end
  return {}
end

local function copy_value(value)
  local copied, ok = safe_copy(value)
  if ok then return copied end
  return nil
end

local function scalar(value)
  return select(1, safe_scalar(value))
end

local function plain(value)
  return type(value) == "table" and getmetatable(value) == nil
end

local function copy_party(party)
  if not plain(party) then return {} end
  local out = {}
  for _, mon in ipairs(party) do
    if plain(mon) then
      out[#out + 1] = {
        id = scalar(mon.id),
        lineId = scalar(mon.lineId),
        species = scalar(mon.species),
        level = scalar(mon.level),
        moves = copy_array(mon.moves),
        acquiredAt = scalar(mon.acquiredAt),
        originMap = scalar(mon.originMap),
        attachment = scalar(mon.attachment),
        useCount = scalar(mon.useCount),
      }
    end
  end
  return out
end

local function copy_events(events)
  if not plain(events) then return {} end
  local out = {}
  for _, event in ipairs(events) do
    if plain(event) then
      out[#out + 1] = {
        encounterId = scalar(event.encounterId),
        minBudget = scalar(event.minBudget),
        maxBudget = scalar(event.maxBudget),
        areas = copy_array(event.areas),
        acquiredIds = copy_array(event.acquiredIds),
      }
    end
  end
  return out
end

local function root_seed(root)
  return {
    hi = plain(root) and scalar(root.seedHi) or nil,
    lo = plain(root) and scalar(root.seedLo) or nil,
  }
end

local function seed(label, parts, value)
  return {
    label = label,
    parts = copy_array(parts),
    value = copy_value(value),
  }
end

local function role_seeds(party)
  local out = {}
  for _, mon in ipairs(plain(party) and party or {}) do
    if plain(mon) and type(mon.id) == "string" and finite(mon.roleSeed) then
      out[mon.id] = mon.roleSeed
    end
  end
  return out
end

function M.standard(root, identityKey, evidence)
  local state = plain(root) and plain(root.trainers)
    and root.trainers[identityKey]
  if not plain(state) then return nil end
  evidence = plain(evidence) and evidence or {}
  local identity = scalar(state.identityKey) or scalar(identityKey)
  local battleCount = scalar(state.battleCount) or 0
  local rootSeed = root_seed(root)
  return {
    kind = "standard",
    seed = seed("trainer-init", { identity }, rootSeed),
    identityKey = identity,
    classId = scalar(state.classId),
    mapId = scalar(state.mapId),
    roster = copy_party(state.owned),
    activeIds = copy_array(state.activeIds),
    lastBattleAt = scalar(state.lastBattleAt),
    battleCount = battleCount,
    lossCount = scalar(state.lossCount),
    ceiling = scalar(evidence.ceiling),
    catchProbability = scalar(evidence.catchProbability),
    ecologyCandidates = copy_array(evidence.ecologyCandidates),
    moveScores = copy_map(evidence.moveScores),
    choiceLabels = {
      roster = "trainer-roster",
      catch = "trainer-catch",
      moves = "trainer-moves",
    },
    choiceSeeds = {
      roster = seed("trainer-init", { identity }, rootSeed),
      catch = seed("trainer-catch", { identity, battleCount }, rootSeed),
      moves = seed("trainer-move-role-v1", { identity },
        role_seeds(state.owned)),
    },
  }
end

function M.boss(root, bossId, evidence)
  local state = plain(root) and plain(root.bossAttempts)
    and root.bossAttempts[bossId]
  if not plain(state) then return nil end
  evidence = plain(evidence) and evidence or {}
  local id = scalar(bossId)
  local attempt = scalar(state.attemptCounter) or 0
  local parts = { scalar(state.version), id, attempt }
  local rootSeed = root_seed(root)
  return {
    kind = "boss",
    seed = seed("boss-attempt", parts, rootSeed),
    bossId = id,
    attemptCounter = attempt,
    strategyId = scalar(state.strategyId),
    referenceLevels = copy_array(state.referenceLevels),
    targetLevels = copy_array(state.targetLevels),
    party = copy_party(state.party),
    poolCandidates = copy_array(evidence.poolCandidates),
    rejectedConstraints = copy_array(evidence.rejectedConstraints),
    historicalRejectionsAvailable = evidence.historicalRejectionsAvailable
      == true,
    choiceLabels = {
      strategy = "boss-strategy",
      roster = "boss-flex-pool",
      levels = "boss-target-levels",
    },
    choiceSeeds = {
      strategy = seed("boss-attempt", parts, rootSeed),
      roster = seed("boss-attempt", parts, rootSeed),
      levels = seed("boss-attempt", parts, rootSeed),
    },
  }
end

function M.league(root)
  local run = plain(root) and root.leagueRun
  if not plain(run) then return nil end
  local memberSeeds, memberSeedValues = {}, {}
  for memberId, value in pairs(plain(run.memberSeeds) and run.memberSeeds or {}) do
    if type(memberId) == "string" and finite(value) then
      memberSeeds[memberId] = seed("league-member", { memberId }, value)
      memberSeedValues[memberId] = value
    end
  end
  local parties = {}
  for memberId, party in pairs(
      plain(run.generatedParties) and run.generatedParties or {}) do
    if type(memberId) == "string" then
      parties[memberId] = copy_party(party)
    end
  end
  local strategies = {}
  for memberId, strategy in pairs(
      plain(run.memberStrategies) and run.memberStrategies or {}) do
    if type(memberId) == "string" then
      strategies[memberId] = plain(strategy) and scalar(strategy.id)
        or scalar(strategy)
    end
  end
  local runCounter = scalar(root.leagueRunCounter) or 0
  local runId = scalar(run.id)
  local runSeed = seed("league-run", { runCounter }, root_seed(root))
  local memberSeed = seed("league-member", { runId }, memberSeedValues)
  return {
    kind = "league",
    seed = runSeed,
    runId = runId,
    version = scalar(run.version),
    createdAt = scalar(run.createdAt),
    birdPair = plain(run.birdPair) and {
      member = scalar(run.birdPair.member),
      species = scalar(run.birdPair.species),
    } or nil,
    memberSeeds = memberSeeds,
    generatedParties = parties,
    memberStrategies = strategies,
    choiceLabels = {
      bird = "league-bird-pair",
      strategy = "league-member-strategy",
      roster = "league-member-party",
    },
    choiceSeeds = {
      bird = runSeed,
      strategy = memberSeed,
      roster = memberSeed,
    },
  }
end

function M.rival(root)
  local state = plain(root) and root.rival
  if not plain(state) or not plain(state.journeySeed) then return nil end
  local flags = plain(root.yellowRival) and root.yellowRival or {}
  local journeySeed = {
    hi = scalar(state.journeySeed.hi), lo = scalar(state.journeySeed.lo),
  }
  local events = copy_events(state.journeyEvents)
  local lastEvent = events[#events]
  local version = scalar(state.version)
  local encounterIndex = scalar(state.encounterIndex)
  local windowParts = { version,
    lastEvent and lastEvent.encounterId or encounterIndex }
  return {
    kind = "rival",
    seed = seed("rival-journey", { version }, journeySeed),
    version = version,
    encounterIndex = encounterIndex,
    owned = copy_party(state.owned),
    activeIds = copy_array(state.activeIds),
    pathFlags = copy_map(state.pathFlags),
    journeyEvents = events,
    eeveeOutcome = scalar(flags.eeveeOutcome),
    choiceLabels = {
      window = "rival-window",
      acquisition = "rival-acquisition",
      party = "rival-active-party",
    },
    choiceSeeds = {
      window = seed("rival-window", windowParts, root_seed(root)),
      acquisition = seed("rival-window", windowParts, root_seed(root)),
      party = seed("rival-journey", { version, encounterIndex }, journeySeed),
    },
  }
end

return M
