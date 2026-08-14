local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local rng = assert(loadfile(ROOT .. "/src/core/rng.lua"))()
local schema_factory = assert(loadfile(ROOT .. "/src/core/save_schema.lua"))()
local schema = schema_factory({ rng = rng })

local checks, failures = 0, 0

local function check(condition, message)
  checks = checks + 1
  if not condition then
    failures = failures + 1
    io.stderr:write("FAIL ", message, "\n")
  end
end

local function eq(actual, expected, message)
  check(actual == expected,
    message .. " (expected " .. tostring(expected) .. ", got "
      .. tostring(actual) .. ")")
end

local identity = {
  version = "yellow",
  playerId = 4242,
  playerName = "ASH",
  rivalName = "GARY",
  playthroughId = "save-slot-yellow-1",
}

local fresh = schema.ensure(nil, identity)
eq(fresh.schema, 1, "fresh state uses schema 1")
check(type(fresh.seedHi) == "number" and type(fresh.seedLo) == "number",
  "fresh state stores its deterministic two-word seed")
check(type(fresh.trainers) == "table" and next(fresh.trainers) == nil,
  "fresh state starts with an empty trainer ledger")
check(type(fresh.bossAttempts) == "table" and next(fresh.bossAttempts) == nil,
  "fresh state starts with an empty boss attempt ledger")
check(type(fresh.rival) == "table" and type(fresh.rival.owned) == "table",
  "fresh state owns a structured Rival bucket")
eq(fresh.rival.encounterIndex, 0,
  "the fresh Rival has not processed an encounter")
eq(fresh.leagueRunCounter, 0, "fresh state starts before the first League run")
eq(fresh.leagueRun, nil, "fresh state has no active League snapshot")
check(type(fresh.yellowRival) == "table",
  "fresh state reserves Yellow outcome history")

local repeated = schema.ensure(nil, identity)
eq(repeated.seedHi, fresh.seedHi,
  "the same save identity derives the same high seed word")
eq(repeated.seedLo, fresh.seedLo,
  "the same save identity derives the same low seed word")

local other = schema.ensure(nil, {
  version = "yellow",
  playerId = 4243,
  playerName = "ASH",
  rivalName = "GARY",
  playthroughId = "save-slot-yellow-2",
})
check(other.seedHi ~= fresh.seedHi or other.seedLo ~= fresh.seedLo,
  "a different save identity derives a different seed")

local instance = {
  id = "trainer-mon-1",
  lineId = "PIDGEY_LINE",
  species = "PIDGEOTTO",
  level = 19,
  moves = { "GUST", "QUICK_ATTACK" },
  suspendedStage = { species = "CROBAT", fallback = "GOLBAT" },
}
local existing = {
  schema = 0,
  seedHi = 99,
  seedLo = 101,
  trainers = {
    ["red|ROUTE_3|OPP_YOUNGSTER|1"] = {
      owned = { instance },
      activeIds = { "trainer-mon-1" },
      generationVersion = 1,
    },
  },
  bossAttempts = { BROCK = 3 },
  leagueRunCounter = 4,
  leagueRun = { id = "league-4", birdPair = { member = "LANCE", species = "ZAPDOS" } },
}

local migrated = schema.ensure(existing, identity)
check(migrated == existing, "migration updates the existing root in place")
eq(migrated.schema, 1, "migration advances the schema version")
eq(migrated.seedHi, 99, "migration preserves the existing high seed word")
eq(migrated.seedLo, 101, "migration preserves the existing low seed word")
check(migrated.trainers["red|ROUTE_3|OPP_YOUNGSTER|1"].owned[1] == instance,
  "migration preserves the exact generated PokemonInstance")
eq(instance.suspendedStage.species, "CROBAT",
  "migration preserves an unavailable Kanto+ stage marker")
eq(instance.suspendedStage.fallback, "GOLBAT",
  "migration preserves the reversible Kanto fallback stage")
eq(migrated.bossAttempts.BROCK, 3,
  "migration preserves existing boss attempt counters")
eq(migrated.leagueRunCounter, 4,
  "migration preserves the League run counter")
eq(migrated.leagueRun.id, "league-4",
  "migration preserves an active League snapshot")
check(type(migrated.rival) == "table" and type(migrated.rival.owned) == "table",
  "migration fills only the missing Rival bucket")
check(type(migrated.yellowRival) == "table",
  "migration fills only the missing Yellow history bucket")

if failures > 0 then
  io.stderr:write(string.format("%d/%d save schema checks failed\n",
    failures, checks))
  os.exit(1)
end

print(string.format("%d/%d save schema checks passed", checks, checks))
