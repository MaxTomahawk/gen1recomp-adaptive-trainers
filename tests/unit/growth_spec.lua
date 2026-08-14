local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local rng = assert(loadfile(ROOT .. "/src/core/rng.lua"))()
local player_power = assert(loadfile(ROOT .. "/src/core/player_power.lua"))()
local stage_resolver = assert(loadfile(ROOT .. "/src/core/stage_resolver.lua"))()
local growth = assert(loadfile(ROOT .. "/src/core/growth.lua"))()({
  rng = rng, player_power = player_power, stage_resolver = stage_resolver,
})

local checks, failures = 0, 0
local function check(condition, message)
  checks = checks + 1
  if not condition then failures = failures + 1; io.stderr:write("FAIL ", message, "\n") end
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (expected " .. tostring(expected)
    .. ", got " .. tostring(actual) .. ")")
end

local pokemon = {
  BASE = { baseStats = { hp = 40 }, evolutions = {
    { method = "LEVEL", level = 11, species = "EVOLVED" },
  } },
  EVOLVED = { baseStats = { hp = 80 }, evolutions = {} },
  STEADY = { baseStats = { hp = 50 }, evolutions = {} },
}
local line = { lineId = "BASE_LINE", stages = {
  { species = "BASE" }, { species = "EVOLVED" },
} }
local meta = { lines = { BASE_LINE = line }, bySpecies = {
  BASE = line, EVOLVED = line,
  STEADY = { lineId = "STEADY_LINE", stages = { { species = "STEADY" } } },
} }
meta.lines.STEADY_LINE = meta.bySpecies.STEADY
local profile = { tauHours = 1, playerAlignment = 1,
  lifetimeGainCap = 10, overtakeCap = 2 }

eq(growth.ceiling(10, 10, 14, 0, profile), 14,
  "zero-badge growth is bounded by the world anchor")
eq(growth.ceiling(10, 10, 20, 1, profile), 20,
  "badge progression raises the contextual ceiling within lifetime cap")
eq(growth.ceiling(10, 10, 50, 8, profile), 20,
  "lifetime gain cap prevents an early trainer becoming an endgame ace")
eq(growth.ceiling(20, 20, 10, 0, profile), 20,
  "a low player reference never levels a trainer down")

local function state()
  return {
    identityKey = "red|ROUTE|OPP_YOUNGSTER|1",
    vanillaTop = 10, battleCount = 1, lastBattleAt = 100,
    lastGrowthAt = 100, lastGrowthBattleCount = 0,
    owned = {
      { id = "a", lineId = "BASE_LINE", species = "BASE", level = 10,
        moves = { "TACKLE" }, roleSeed = 4 },
      { id = "b", lineId = "STEADY_LINE", species = "STEADY", level = 9,
        moves = { "GROWL" }, roleSeed = 8 },
    },
  }
end
local function context(playTime)
  return { playTime = playTime, playerParty = {
    { level = 20 }, { level = 18 }, { level = 16 },
  }, badgeCount = 1, pokemon = pokemon, meta = meta }
end

for _, elapsed in ipairs({ 0, 1, 899, 900 }) do
  local row = state()
  local changed, report = growth.materialize(row, context(100 + elapsed), profile)
  eq(changed, false, "grace period is exact at elapsed second " .. elapsed)
  eq(row.owned[1].species, "BASE", "grace preserves species at " .. elapsed)
  eq(row.owned[1].level, 10, "grace preserves levels at " .. elapsed)
  eq(row.owned[1].moves[1], "TACKLE", "grace preserves moves at " .. elapsed)
  eq(report.elapsedSeconds, elapsed, "growth reports active-save elapsed time")
end

local first = state()
local changed, firstReport = growth.materialize(first, context(3700), profile)
check(changed, "growth becomes possible after an hour with ceiling gap")
check(first.owned[1].level >= 10 and first.owned[1].level <= firstReport.ceilingTop,
  "growth is monotonic and bounded by the contextual ceiling")
check(first.owned[2].level >= 9 and first.owned[2].level <= firstReport.ceilingTop,
  "every owned individual grows monotonically within the same ceiling")

local repeated = state()
growth.materialize(repeated, context(3700), profile)
for index, mon in ipairs(first.owned) do
  eq(repeated.owned[index].level, mon.level,
    "deterministic rounding repeats level for owned slot " .. index)
  eq(repeated.owned[index].species, mon.species,
    "deterministic growth repeats stage for owned slot " .. index)
end

local onceLevels = { first.owned[1].level, first.owned[2].level }
local changedAgain, repeatReport = growth.materialize(first, context(3700), profile)
eq(changedAgain, false, "one loss interval materializes growth at most once")
eq(repeatReport.reason, "already-materialized",
  "duplicate hook evaluation has a stable diagnostic")
eq(first.owned[1].level, onceLevels[1], "duplicate evaluation cannot double-grow slot one")
eq(first.owned[2].level, onceLevels[2], "duplicate evaluation cannot double-grow slot two")

local evolved = state()
growth.materialize(evolved, context(100 + 72 * 3600), profile)
eq(evolved.owned[1].species, "EVOLVED",
  "stage resolver runs after permanent level growth")
eq(evolved.owned[1].lineId, "BASE_LINE",
  "evolution preserves persistent line identity")
eq(evolved.owned[1].moves[1], "TACKLE",
  "Phase B preserves logical old moves until Phase C refreshes them")
eq(evolved.owned[1].movesetRefreshReason, "evolution",
  "evolution records the pending legal moveset refresh reason")

if failures > 0 then
  io.stderr:write(string.format("%d/%d growth checks failed\n", failures, checks))
  os.exit(1)
end
print(string.format("%d/%d growth checks passed", checks, checks))
