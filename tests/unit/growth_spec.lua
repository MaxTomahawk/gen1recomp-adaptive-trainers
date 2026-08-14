local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local rng = assert(loadfile(ROOT .. "/src/core/rng.lua"))()
local player_power = assert(loadfile(ROOT .. "/src/core/player_power.lua"))()
local stage_resolver = assert(loadfile(ROOT .. "/src/core/stage_resolver.lua"))()
local movesets = assert(loadfile(ROOT .. "/src/core/movesets.lua"))()
local growth = assert(loadfile(ROOT .. "/src/core/growth.lua"))()({
  rng = rng, player_power = player_power, stage_resolver = stage_resolver,
  movesets = movesets,
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
  }, level1Moves = { "TACKLE" }, learnset = {
    { level = 9, move = "GROWL" },
  }, tmhm = {} },
  EVOLVED = { baseStats = { hp = 80 }, evolutions = {},
    level1Moves = { "CONFUSION" }, learnset = {
      { level = 11, move = "GUST" },
    }, tmhm = {} },
  STEADY = { baseStats = { hp = 50 }, evolutions = {},
    level1Moves = { "GROWL" }, learnset = {}, tmhm = {} },
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
eq(growth.contextual_ceiling(20, 10, 0, profile), 12,
  "the reported contextual ceiling follows the normative P plus overtake cap")
eq(growth.ceiling(20, 20, 10, 0, profile), 12,
  "current trainer level is not smuggled into the contextual ceiling formula")

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
  "evolution retains a logical inherited move")
check(#evolved.owned[1].moves >= 2,
  "evolution performs its forced persistent moveset refresh")
local evolvedMoves = {}
for _, move in ipairs(evolved.owned[1].moves) do evolvedMoves[move] = true end
check(evolvedMoves.GUST or evolvedMoves.CONFUSION,
  "evolution refresh adds a move exposed by the evolved species")
eq(evolved.owned[1].movesetRefreshReason, nil,
  "a completed evolution refresh leaves no unresolved marker")
eq(evolved.owned[1].lastMovesetRefreshReason, "evolution",
  "the persistent instance records why its moves changed")

local aboveCeiling = state()
aboveCeiling.vanillaTop = 20
aboveCeiling.owned[1].level = 20
aboveCeiling.owned[2].level = 19
local aboveChanged, aboveReport = growth.materialize(aboveCeiling, {
  playTime = 3700, playerParty = { { level = 10 } }, badgeCount = 0,
  pokemon = pokemon, meta = meta,
}, profile)
eq(aboveReport.ceilingTop, 12,
  "growth reports the exact formula even when the roster is already above it")
eq(aboveReport.effectiveCeilingTop, 20,
  "growth exposes the separate no-delevel effective bound")
eq(aboveChanged, false,
  "an already-above-ceiling roster receives no additional growth")
eq(aboveCeiling.owned[1].level, 20,
  "non-negative growth keeps an already-above-ceiling level unchanged")

if failures > 0 then
  io.stderr:write(string.format("%d/%d growth checks failed\n", failures, checks))
  os.exit(1)
end
print(string.format("%d/%d growth checks passed", checks, checks))
