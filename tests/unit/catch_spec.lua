local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local rng = assert(loadfile(ROOT .. "/src/core/rng.lua"))()
local stage_resolver = assert(loadfile(ROOT .. "/src/core/stage_resolver.lua"))()
local roster = assert(loadfile(ROOT .. "/src/core/roster.lua"))()({
  rng = rng, stage_resolver = stage_resolver,
})
local profiles = assert(loadfile(ROOT .. "/src/data/trainer_profiles.lua"))()

local checks, failures = 0, 0
local function check(condition, message)
  checks = checks + 1
  if not condition then failures = failures + 1; io.stderr:write("FAIL ", message, "\n") end
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (expected " .. tostring(expected)
    .. ", got " .. tostring(actual) .. ")")
end

local lines = {
  BUG = { lineId = "BUG", groups = { "BUG_LARVA_COMMON" }, classTags = {
    "bugcatcher" }, roles = { "swarm" }, rarity = 0, powerBand = 1,
    genericEligible = true, populationModel = "COMMON_SPECIES",
    stages = { { species = "CATERPIE" } } },
  BIRD = { lineId = "BIRD", groups = { "EARLY_BIRD" }, classTags = {
    "birdkeeper" }, roles = { "fast_physical" }, rarity = 0, powerBand = 1,
    genericEligible = true, populationModel = "COMMON_SPECIES",
    stages = { { species = "PIDGEY" } } },
  LEGEND = { lineId = "LEGEND", groups = { "LEGENDARY_BIRD" }, rarity = 4,
    powerBand = 5, genericEligible = false, populationModel = "ULTRA_RARE_SPECIES",
    classTags = {}, roles = { "fast_special" },
    stages = { { species = "ARTICUNO" } } },
}
local meta = { lines = lines, bySpecies = {
  CATERPIE = lines.BUG, PIDGEY = lines.BIRD, ARTICUNO = lines.LEGEND,
} }
local pokemon = { CATERPIE = { evolutions = {} }, PIDGEY = { evolutions = {} },
  ARTICUNO = { evolutions = {} } }
local evidence = {
  { species = "ARTICUNO", weight = 10, sources = {
    { species = "ARTICUNO", level = 50, mapId = "SEAFOAM" },
  } },
  { species = "CATERPIE", weight = 1, sources = {
    { species = "CATERPIE", level = 4, mapId = "FOREST" },
    { species = "CATERPIE", level = 6, mapId = "FOREST" },
  } },
  { species = "PIDGEY", weight = 1, sources = {
    { species = "PIDGEY", level = 5, mapId = "ROUTE" },
  } },
}
local function fresh()
  return { identityKey = "bugcatcher", battleCount = 1, lastBattleAt = 100,
    lastCatchCheckAt = 100, lastCatchBattleCount = 0,
    owned = { { id = "old", lineId = "BUG", species = "CATERPIE",
      level = 12, acquiredAt = 0, originMap = "FOREST", roleSeed = 1 } },
    activeIds = { "old" }, nextOwnedSerial = 1 }
end
local function ctx(playTime)
  return { playTime = playTime, trainerMedian = 12, mapId = "FOREST",
    pokemon = pokemon, meta = meta, rootSeed = { hi = 12, lo = 34 },
    stream = { float = function() return 0 end,
      integer = function(_, low) return low end } }
end

local grace = fresh()
local caught, graceReport = roster.maybe_catch(grace, ctx(1000),
  profiles.byName.BUG_CATCHER, evidence)
eq(caught, nil, "catching is forbidden at the exact 900-second grace boundary")
eq(graceReport.probability, 0, "grace-period catch probability is exactly zero")
eq(#grace.owned, 1, "grace-period evaluation cannot add an individual")

local state = fresh()
local instance, report = roster.maybe_catch(state, ctx(100 + 72 * 3600),
  profiles.byName.BUG_CATCHER, evidence)
check(instance ~= nil, "a deterministic long-interval catch can succeed")
eq(instance and instance.lineId, "BUG",
  "Bug Catcher candidate filtering uses the configured Bug group")
check(instance and instance.species ~= "ARTICUNO",
  "Legendary candidates remain hard-excluded from catches")
check(instance and instance.level >= 4 and instance.level <= 8,
  "catch level stays in local range plus at most two training levels")
check(instance and instance.level <= 11,
  "catch level never exceeds trainer median minus one")
eq(instance and instance.originMap, "FOREST",
  "caught individuals preserve ecology origin map")
eq(#state.owned, 2, "a successful event adds exactly one owned individual")
eq(state.activeIds[2], instance and instance.id,
  "a free active slot accepts the new catch immediately")
eq(report.candidateCount, 1,
  "class and special-species filters run before deterministic selection")

local second = roster.maybe_catch(state, ctx(100 + 73 * 3600),
  profiles.byName.BUG_CATCHER, evidence)
eq(second, nil, "one battle interval can add at most one catch")
eq(#state.owned, 2, "a duplicate catch check cannot mutate the roster")

check(roster.catch_probability(7200, 1, profiles.byName.BUG_CATCHER, 1)
    > roster.catch_probability(7200, 1, profiles.byName.COOLTRAINER, 1),
  "Bug Catcher has a higher long-loss catch rate than Cooltrainer")

local noEcology = fresh()
local absent, absentReport = roster.maybe_catch(noEcology,
  ctx(100 + 72 * 3600), profiles.byName.BUG_CATCHER, {})
eq(absent, nil, "no local or context pool means no catch")
eq(absentReport.probability, 0, "ecology availability gates catch probability")

local selective = fresh()
selective.identityKey = "cooltrainer"
local diverse, selectiveReport = roster.maybe_catch(selective,
  ctx(100 + 72 * 3600), profiles.byName.COOLTRAINER, {
    { species = "CATERPIE", weight = 10, sources = {
      { species = "CATERPIE", level = 5, mapId = "FOREST" },
    } },
    { species = "PIDGEY", weight = 1, sources = {
      { species = "PIDGEY", level = 5, mapId = "FOREST" },
    } },
  })
eq(diverse and diverse.lineId, "BIRD",
  "Cooltrainer selectivity prefers a good team-fit catch over a duplicate")
eq(selectiveReport.candidateCount, 1,
  "Cooltrainer rejects candidates below its team-fit threshold")

local ordinary = fresh()
ordinary.identityKey = "youngster"
local nonduplicate = roster.maybe_catch(ordinary, ctx(100 + 72 * 3600),
  profiles.byName.YOUNGSTER, {
    { species = "CATERPIE", weight = 10, sources = {
      { species = "CATERPIE", level = 5, mapId = "FOREST" },
    } },
    { species = "PIDGEY", weight = 1, sources = {
      { species = "PIDGEY", level = 5, mapId = "FOREST" },
    } },
  })
eq(nonduplicate and nonduplicate.lineId, "BIRD",
  "ordinary catches avoid duplicate active lines when the pool has an alternative")

if failures > 0 then
  io.stderr:write(string.format("%d/%d catch checks failed\n", failures, checks))
  os.exit(1)
end
print(string.format("%d/%d catch checks passed", checks, checks))
