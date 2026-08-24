local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT is required")

local diagnostics = assert(loadfile(
  ROOT .. "/src/core/diagnostics.lua"))()
local debug_factory = assert(loadfile(ROOT .. "/src/ui/debug.lua"))()

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

local root = { seedHi = 101, seedLo = 202, leagueRunCounter = 1, leagueRun = {
  id = "1:12345678", birdPair = { member = "LORELEI", species = "ARTICUNO" },
  memberSeeds = { LORELEI = 10 }, generatedParties = {},
  memberStrategies = {},
} }
local emitted = {}
local function sink(label, projection)
  emitted[#emitted + 1] = { label = label, projection = projection }
end

for _, value in ipairs({ false, true, "0", "true", "" }) do
  local adapter = debug_factory({ diagnostics = diagnostics,
    env = { POKEPORT_DEV = value }, sink = sink })
  eq(adapter.enabled(), false,
    "only the exact POKEPORT_DEV string value 1 enables diagnostics")
  eq(adapter.project("league", root), nil,
    "production-mode projection is fail-silent")
end
eq(#emitted, 0, "production mode emits no diagnostics")

local adapter = debug_factory({ diagnostics = diagnostics,
  env = { POKEPORT_DEV = "1" }, sink = sink })
eq(adapter.enabled(), true, "POKEPORT_DEV=1 enables diagnostics")
local projection = adapter.project("league", root)
eq(projection.runId, "1:12345678",
  "dev adapter returns the selected sanitized projection")
eq(#emitted, 1, "dev adapter emits exactly one projection")
eq(emitted[1].label, "adaptive-trainers.league",
  "dev adapter labels the emitted projection")
check(emitted[1].projection == projection,
  "dev adapter emits the same detached projection it returns")
eq(adapter.project("unknown", root), nil,
  "unknown diagnostic scopes fail silently")
eq(#emitted, 1, "unknown diagnostic scopes emit nothing")

local seedLogs = {}
local with_seed_log = debug_factory({ diagnostics = diagnostics,
  env = { POKEPORT_DEV = "1" }, sink = sink,
  seed_sink = function(entry) seedLogs[#seedLogs + 1] = entry end })
with_seed_log.project("league", root)
eq(#seedLogs, 5,
  "dev adapter logs the League root, member, and every declared choice")
eq(seedLogs[1].label, "league-run",
  "dev seed logging includes the League-run seed label")
eq(seedLogs[2].label, "league-member",
  "dev seed logging includes member seed labels")
eq(seedLogs[2].value, 10,
  "League member logging preserves scalar persisted seeds")
eq(seedLogs[3].label, "league-bird-pair",
  "dev choice logging includes the League Bird label")
eq(seedLogs[4].label, "league-member-party",
  "dev choice logging includes the League roster label")
eq(seedLogs[5].label, "league-member-strategy",
  "dev choice logging includes the League strategy label")
eq(seedLogs[1].kind, "league",
  "dev seed logging keeps the diagnostic scope")
eq(seedLogs[3].seedLabel, "league-run",
  "League Bird choice identifies its deterministic seed stream")
check(type(seedLogs[3].parts) == "table"
    and type(seedLogs[3].value) == "table",
  "League Bird choice carries diagnostic seed parts and value")
for _, entry in ipairs(seedLogs) do
  check(type(entry.seedLabel) == "string",
    "every League diagnostic entry names its deterministic seed label")
  check(type(entry.parts) == "table",
    "every League diagnostic entry carries deterministic seed parts")
  check(entry.value ~= nil,
    "every League diagnostic entry carries a deterministic seed value")
end
eq(seedLogs[1].value.lo, 202,
  "dev seed logging retains the persisted root-seed value")

local orderedLogs = {}
local orderedRoot = { seedHi = 1, seedLo = 2, leagueRunCounter = 1,
  leagueRun = { id = "ordered", birdPair = {
      member = "LORELEI", species = "ARTICUNO" },
    memberSeeds = { LANCE = 4, AGATHA = 3, LORELEI = 1, BRUNO = 2 },
    generatedParties = {}, memberStrategies = {} } }
local orderedAdapter = debug_factory({ diagnostics = diagnostics,
  env = { POKEPORT_DEV = "1" },
  seed_sink = function(entry) orderedLogs[#orderedLogs + 1] = entry end })
orderedAdapter.project("league", orderedRoot)
eq(orderedLogs[2].parts[1], "AGATHA",
  "League member seed logs begin in stable lexical order")
eq(orderedLogs[3].parts[1], "BRUNO",
  "League member seed logs retain stable lexical order")
eq(orderedLogs[4].parts[1], "LANCE",
  "League member seed logs retain stable lexical order")
eq(orderedLogs[5].parts[1], "LORELEI",
  "League member seed logs end in stable lexical order")

local choiceRoot = {
  seedHi = 101, seedLo = 202,
  trainers = { trainer = { identityKey = "trainer", owned = {},
    activeIds = {}, battleCount = 2 } },
  bossAttempts = { BROCK = { version = "red", attemptCounter = 1,
    party = {}, referenceLevels = {}, targetLevels = {} } },
  rival = { version = "yellow", encounterIndex = 2,
    journeySeed = { hi = 303, lo = 404 }, owned = {}, activeIds = {},
    pathFlags = {}, journeyEvents = {} },
  yellowRival = {},
}
local function projected_labels(kind, ...)
  local logs = {}
  local choiceAdapter = debug_factory({ diagnostics = diagnostics,
    env = { POKEPORT_DEV = "1" },
    seed_sink = function(entry) logs[#logs + 1] = entry end })
  choiceAdapter.project(kind, ...)
  local labels = {}
  for _, entry in ipairs(logs) do
    labels[entry.label] = true
    check(type(entry.seedLabel) == "string",
      kind .. " diagnostic entries name their seed label")
    check(type(entry.parts) == "table",
      kind .. " diagnostic entries carry seed parts")
    check(entry.value ~= nil,
      kind .. " diagnostic entries carry a seed value")
  end
  return labels
end
local standardLabels = projected_labels("standard", choiceRoot, "trainer")
for _, label in ipairs({ "trainer-init", "trainer-roster",
    "trainer-catch", "trainer-moves" }) do
  check(standardLabels[label] == true,
    "standard diagnostics emit " .. label)
end
local bossLabels = projected_labels("boss", choiceRoot, "BROCK")
for _, label in ipairs({ "boss-attempt", "boss-strategy",
    "boss-flex-pool", "boss-target-levels" }) do
  check(bossLabels[label] == true, "boss diagnostics emit " .. label)
end
local rivalLabels = projected_labels("rival", choiceRoot)
for _, label in ipairs({ "rival-journey", "rival-window",
    "rival-acquisition", "rival-active-party" }) do
  check(rivalLabels[label] == true, "Rival diagnostics emit " .. label)
end


local without_sink = debug_factory({ diagnostics = diagnostics,
  env = { POKEPORT_DEV = "1" } })
check(without_sink.project("league", root) ~= nil,
  "dev projections remain usable by a screen without a log sink")

if failures > 0 then
  io.stderr:write(string.format("%d/%d debug checks failed\n",
    failures, checks))
  os.exit(1)
end
print(string.format("%d/%d debug checks passed", checks, checks))
