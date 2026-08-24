local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT is required")

local diagnostics = assert(loadfile(
  ROOT .. "/src/core/diagnostics.lua"))()

local checks, failures = 0, 0
local function check(condition, message)
  checks = checks + 1
  if not condition then
    failures = failures + 1
    io.stderr:write("FAIL ", message, "\n")
  end
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (expected " .. tostring(expected)
    .. ", got " .. tostring(actual) .. ")")
end
local function same(left, right)
  if type(left) ~= type(right) then return false end
  if type(left) ~= "table" then return left == right end
  for key, value in pairs(left) do
    if not same(value, right[key]) then return false end
  end
  for key in pairs(right) do
    if left[key] == nil then return false end
  end
  return true
end
local function copy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for key, item in pairs(value) do out[key] = copy(item) end
  return out
end
local function finite(value)
  return type(value) == "number" and value == value
    and value ~= math.huge and value ~= -math.huge
end
local function safe_data(value, stack)
  local kind = type(value)
  if kind == "nil" or kind == "string" or kind == "boolean" then return true end
  if kind == "number" then return finite(value) end
  if kind ~= "table" or getmetatable(value) ~= nil then return false end
  stack = stack or {}
  if stack[value] then return false end
  stack[value] = true
  for key, item in pairs(value) do
    local keyKind = type(key)
    if not (keyKind == "string" or finite(key))
        or not safe_data(item, stack) then
      stack[value] = nil
      return false
    end
  end
  stack[value] = nil
  return true
end
local function find_line(rows, lineId)
  for _, row in ipairs(rows or {}) do
    if type(row) == "table" and row.lineId == lineId then return row end
  end
end

local root = {
  seedHi = 101, seedLo = 202,
  trainers = {
    ["red|ROUTE_3|OPP_BUG_CATCHER|1"] = {
      identityKey = "red|ROUTE_3|OPP_BUG_CATCHER|1",
      classId = "OPP_BUG_CATCHER", mapId = "ROUTE_3",
      lastBattleAt = 900, battleCount = 2, lossCount = 1,
      activeIds = { "trainer:1" },
      owned = { { id = "trainer:1", lineId = "CATERPIE_LINE",
        species = "BUTTERFREE", level = 12, moves = { "TACKLE" },
        secret = "must-not-leak" } },
      secret = "must-not-leak",
    },
  },
  bossAttempts = {
    BROCK = {
      version = "red", attemptCounter = 1, strategyId = "ROCK_WALL",
      referenceLevels = { 14, 12 }, targetLevels = { 14, 12 },
      party = { { lineId = "ONIX_LINE", species = "ONIX", level = 14,
        moves = { "BIDE" }, secret = "must-not-leak" } },
    },
  },
  leagueRunCounter = 3,
  leagueRun = {
    id = "3:feedface", version = "blue", createdAt = 3600,
    birdPair = { member = "LANCE", species = "ZAPDOS" },
    memberSeeds = { LORELEI = 11, BRUNO = 22, AGATHA = 33, LANCE = 44 },
    generatedParties = {
      LORELEI = { { lineId = "LAPRAS_LINE", species = "LAPRAS",
        level = 56 } },
    },
    memberStrategies = { LORELEI = { id = "FREEZE_CONTROL" } },
  },
  rival = {
    version = "yellow", encounterIndex = 5,
    journeySeed = { hi = 303, lo = 404 },
    activeIds = { "rival:starter" },
    owned = { { id = "rival:starter", lineId = "EEVEE_LINE",
      species = "JOLTEON", level = 40, acquiredAt = 0,
      originMap = "OAKS_LAB", attachment = 100, useCount = 5,
      secret = "must-not-leak" } },
    journeyEvents = { { encounterId = "CERULEAN",
      acquiredIds = { "rival:abra" }, secret = "must-not-leak" } },
    pathFlags = { CERULEAN = true },
  },
  yellowRival = { eeveeOutcome = "JOLTEON" },
  secret = "must-not-leak",
}
local before = copy(root)

local standard = diagnostics.standard(root,
  "red|ROUTE_3|OPP_BUG_CATCHER|1", {
    ceiling = 18, catchProbability = 0.25,
    ecologyCandidates = { "CATERPIE_LINE", "WEEDLE_LINE" },
    moveScores = { TACKLE = 2, STRING_SHOT = 1 },
  })
eq(standard.kind, "standard", "standard projection names its scope")
eq(standard.seed.label, "trainer-init",
  "standard projection labels its generation seed")
eq(standard.seed.parts[1], "red|ROUTE_3|OPP_BUG_CATCHER|1",
  "standard seed identifies only the concrete trainer")
eq(standard.seed.value.hi, 101,
  "standard projection carries the persisted root seed high word")
eq(standard.seed.value.lo, 202,
  "standard projection carries the persisted root seed low word")
eq(standard.lastBattleAt, 900, "standard projection exposes last battle time")
eq(standard.ceiling, 18, "standard projection exposes the supplied ceiling")
eq(standard.catchProbability, 0.25,
  "standard projection exposes the supplied catch probability")
eq(standard.ecologyCandidates[2], "WEEDLE_LINE",
  "standard projection exposes ecology candidates")
eq(standard.moveScores.TACKLE, 2,
  "standard projection exposes move scores")
eq(standard.roster[1].species, "BUTTERFREE",
  "standard projection exposes the saved roster")
eq(standard.roster[1].secret, nil,
  "standard projection strips unknown Pokemon fields")
eq(standard.secret, nil, "standard projection strips unknown trainer fields")

local structuredCandidate = { lineId = "WEEDLE_LINE",
  evidence = { method = "grass", weight = 2 } }
local cyclicCandidate = { lineId = "CYCLE_LINE" }
cyclicCandidate.self = cyclicCandidate
local metatableCandidate = setmetatable({ lineId = "META_LINE" }, {})
local hostileEvidence = {
  ceiling = math.huge,
  catchProbability = function() return 1 end,
  ecologyCandidates = {
    structuredCandidate,
    function() end,
    io.stdout,
    coroutine.create(function() end),
    metatableCandidate,
    cyclicCandidate,
    { lineId = "SAFE_LINE", score = 3, infinite = -math.huge },
  },
  moveScores = {
    TACKLE = 2,
    nested = { role = "damage", score = 4 },
    callback = function() end,
    handle = io.stdout,
    worker = coroutine.create(function() end),
    nan = 0 / 0,
    infinite = math.huge,
    meta = setmetatable({ score = 9 }, {}),
    [true] = "boolean-key",
  },
}
local hostile = diagnostics.standard(root,
  "red|ROUTE_3|OPP_BUG_CATCHER|1", hostileEvidence)
check(safe_data(hostile),
  "hostile evidence is reduced to finite detached data-only values")
eq(hostile.ceiling, nil, "infinite diagnostic ceilings are omitted")
eq(hostile.catchProbability, nil,
  "function-valued catch probabilities are omitted")
check(hostile.ecologyCandidates[1] ~= structuredCandidate,
  "structured ecology candidates are deeply detached")
eq(hostile.ecologyCandidates[1].evidence.weight, 2,
  "structured ecology candidate evidence remains available")
eq(find_line(hostile.ecologyCandidates, "META_LINE"), nil,
  "metatable-bearing evidence is omitted")
eq(find_line(hostile.ecologyCandidates, "CYCLE_LINE").self, nil,
  "cyclic links are omitted without discarding safe candidate fields")
eq(find_line(hostile.ecologyCandidates, "SAFE_LINE").infinite, nil,
  "non-finite nested candidate values are omitted")
eq(hostile.moveScores.callback, nil, "function map values are omitted")
eq(hostile.moveScores.handle, nil, "userdata map values are omitted")
eq(hostile.moveScores.worker, nil, "thread map values are omitted")
eq(hostile.moveScores.nan, nil, "NaN map values are omitted")
eq(hostile.moveScores.infinite, nil, "infinite map values are omitted")
eq(hostile.moveScores.meta, nil, "metatable-bearing map values are omitted")
eq(hostile.moveScores[true], nil, "boolean map keys are omitted")
check(hostile.moveScores.nested ~= hostileEvidence.moveScores.nested,
  "structured move scores are deeply detached")
hostile.ecologyCandidates[1].evidence.weight = 99
hostile.moveScores.nested.score = 99
eq(structuredCandidate.evidence.weight, 2,
  "mutating projected ecology evidence cannot mutate caller evidence")
eq(hostileEvidence.moveScores.nested.score, 4,
  "mutating projected move scores cannot mutate caller evidence")

local boss = diagnostics.boss(root, "BROCK", {
  poolCandidates = { "GEODUDE_LINE", "ONIX_LINE" },
  rejectedConstraints = { "duplicate-signature" },
})
eq(boss.kind, "boss", "boss projection names its scope")
eq(boss.seed.label, "boss-attempt", "boss attempt seed is labeled")
eq(boss.seed.parts[2], "BROCK", "boss seed names the identity")
eq(boss.seed.parts[3], 1, "boss seed names the attempt counter")
eq(boss.seed.value.hi, 101,
  "boss projection carries the persisted root seed high word")
eq(boss.strategyId, "ROCK_WALL", "boss projection exposes strategy choice")
eq(boss.poolCandidates[1], "GEODUDE_LINE",
  "boss projection exposes candidate pool")
eq(boss.rejectedConstraints[1], "duplicate-signature",
  "boss projection exposes rejected constraints")
eq(boss.party[1].secret, nil,
  "boss projection strips unknown Pokemon fields")

local league = diagnostics.league(root)
eq(league.kind, "league", "League projection names its scope")
eq(league.seed.label, "league-run", "League run seed is labeled")
eq(league.runId, "3:feedface", "League projection exposes the run id")
eq(league.seed.value.lo, 202,
  "League projection carries the persisted root seed low word")
eq(league.birdPair.species, "ZAPDOS",
  "League projection exposes the visible Bird choice")
eq(league.memberSeeds.LANCE.label, "league-member",
  "League member seed has an explicit label")
eq(league.memberSeeds.LANCE.value, 44,
  "League projection exposes persisted member seed")
eq(league.memberStrategies.LORELEI, "FREEZE_CONTROL",
  "League projection exposes persisted member strategy")

local rival = diagnostics.rival(root)
eq(rival.kind, "rival", "Rival projection names its scope")
eq(rival.seed.label, "rival-journey", "Rival journey seed is labeled")
eq(rival.encounterIndex, 5, "Rival projection exposes the timeline index")
eq(rival.owned[1].originMap, "OAKS_LAB",
  "Rival projection exposes acquisition origin")
eq(rival.owned[1].attachment, 100,
  "Rival projection exposes attachment")
eq(rival.journeyEvents[1].encounterId, "CERULEAN",
  "Rival projection exposes window events")
eq(rival.journeyEvents[1].secret, nil,
  "Rival projection strips unknown event fields")
eq(rival.eeveeOutcome, "JOLTEON",
  "Rival projection exposes the persisted Yellow outcome")

check(same(standard, diagnostics.standard(root,
  "red|ROUTE_3|OPP_BUG_CATCHER|1", {
    ceiling = 18, catchProbability = 0.25,
    ecologyCandidates = { "CATERPIE_LINE", "WEEDLE_LINE" },
    moveScores = { TACKLE = 2, STRING_SHOT = 1 },
  })), "standard projection is byte-equivalent for identical input")
check(same(boss, diagnostics.boss(root, "BROCK", {
  poolCandidates = { "GEODUDE_LINE", "ONIX_LINE" },
  rejectedConstraints = { "duplicate-signature" },
})), "boss projection is byte-equivalent for identical input")
check(same(league, diagnostics.league(root)),
  "League projection is byte-equivalent for identical input")
check(same(rival, diagnostics.rival(root)),
  "Rival projection is byte-equivalent for identical input")

standard.roster[1].species = "MUTATED"
boss.party[1].moves[1] = "MUTATED"
league.birdPair.species = "MUTATED"
rival.owned[1].attachment = 0
check(same(root, before),
  "all diagnostic projections are detached and cannot mutate save authority")

eq(diagnostics.standard(root, "missing"), nil,
  "missing standard state fails silently")
eq(diagnostics.boss(root, "missing"), nil,
  "missing boss state fails silently")
eq(diagnostics.league({}), nil, "missing League run fails silently")
eq(diagnostics.rival({}), nil, "missing Rival state fails silently")

if failures > 0 then
  io.stderr:write(string.format("%d/%d diagnostics checks failed\n",
    failures, checks))
  os.exit(1)
end
print(string.format("%d/%d diagnostics checks passed", checks, checks))
