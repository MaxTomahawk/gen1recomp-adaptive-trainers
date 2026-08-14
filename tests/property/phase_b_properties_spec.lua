local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local rng = assert(loadfile(ROOT .. "/src/core/rng.lua"))()
local player_power = assert(loadfile(ROOT .. "/src/core/player_power.lua"))()
local stage_resolver = assert(loadfile(ROOT .. "/src/core/stage_resolver.lua"))()
local growth = assert(loadfile(ROOT .. "/src/core/growth.lua"))()({
  rng = rng, player_power = player_power, stage_resolver = stage_resolver,
})
local roster = assert(loadfile(ROOT .. "/src/core/roster.lua"))()({
  rng = rng, stage_resolver = stage_resolver,
})
local profiles = assert(loadfile(ROOT .. "/src/data/trainer_profiles.lua"))()

local checks, failures = 0, 0
local function check(condition, message)
  checks = checks + 1
  if not condition then failures = failures + 1; io.stderr:write("FAIL ", message, "\n") end
end

local commonLine = { lineId = "CATERPIE_LINE", groups = { "BUG_LARVA_COMMON" },
  classTags = { "bugcatcher" }, roles = { "swarm" }, rarity = 0,
  powerBand = 1, genericEligible = true, populationModel = "COMMON_SPECIES",
  stages = { { species = "CATERPIE" } } }
local legendLine = { lineId = "ARTICUNO", groups = { "LEGENDARY_BIRD" },
  classTags = {}, roles = { "fast_special" }, rarity = 4, powerBand = 5,
  genericEligible = false, populationModel = "ULTRA_RARE_SPECIES",
  stages = { { species = "ARTICUNO" } } }
local meta = { lines = { CATERPIE_LINE = commonLine, ARTICUNO = legendLine },
  bySpecies = { CATERPIE = commonLine, ARTICUNO = legendLine } }
local pokemon = {
  CATERPIE = { baseStats = { hp = 45, attack = 30, defense = 35,
    speed = 45, special = 20 }, types = { "BUG" }, evolutions = {} },
  ARTICUNO = { baseStats = { hp = 90, attack = 85, defense = 100,
    speed = 85, special = 125 }, types = { "ICE" }, evolutions = {} },
}
local evidence = {
  { species = "ARTICUNO", weight = 100, sources = {
    { species = "ARTICUNO", level = 50, mapId = "SEAFOAM" },
  } },
  { species = "CATERPIE", weight = 1, sources = {
    { species = "CATERPIE", level = 4, mapId = "FOREST" },
    { species = "CATERPIE", level = 6, mapId = "FOREST" },
  } },
}

local bugCatches, coolCatches = 0, 0
local originalRandom = math.random
math.random = function()
  error("persistent Phase B choices must not use math.random")
end
for seedIndex = 1, 1000 do
  local rootSeed = { hi = seedIndex * 13, lo = seedIndex * 29 }
  local state = { identityKey = "growth|" .. seedIndex, vanillaTop = 10,
    battleCount = 1, lastBattleAt = 0, lastGrowthBattleCount = 0,
    owned = { { id = "mon", lineId = "CATERPIE_LINE",
      species = "CATERPIE", level = 10, roleSeed = seedIndex } } }
  local ctx = { playTime = 7200, badgeCount = 2,
    playerParty = { { level = 25 }, { level = 22 }, { level = 20 } },
    rootSeed = rootSeed, meta = meta, pokemon = pokemon }
  local before = state.owned[1].level
  local _, report = growth.materialize(state, ctx, profiles.byName.BUG_CATCHER)
  check(state.owned[1].level >= before,
    "seed " .. seedIndex .. " growth is monotonic")
  check(state.owned[1].level <= report.ceilingTop,
    "seed " .. seedIndex .. " growth respects contextual ceiling")
  local stableLevel = state.owned[1].level
  growth.materialize(state, ctx, profiles.byName.BUG_CATCHER)
  check(state.owned[1].level == stableLevel,
    "seed " .. seedIndex .. " cannot materialize twice")

  for _, sample in ipairs({
    { profile = profiles.byName.BUG_CATCHER, suffix = "bug" },
    { profile = profiles.byName.COOLTRAINER, suffix = "cool" },
  }) do
    local catchState = { identityKey = sample.suffix .. "|" .. seedIndex,
      battleCount = 1, lastBattleAt = 0, lastCatchBattleCount = 0,
      owned = { { id = "old", lineId = "OTHER_LINE",
        species = "OWNED", level = 15 } }, activeIds = { "old" } }
    local caught = roster.maybe_catch(catchState, {
      playTime = 72 * 3600, trainerMedian = 15, mapId = "FOREST",
      rootSeed = rootSeed, meta = meta, pokemon = pokemon,
    }, sample.profile, evidence)
    check(#catchState.owned <= 2,
      "seed " .. seedIndex .. " " .. sample.suffix .. " adds at most one")
    if caught then
      check(caught.species == "CATERPIE",
        "seed " .. seedIndex .. " catch stays in eligible ecology")
      check(caught.level >= 4 and caught.level <= 8 and caught.level <= 14,
        "seed " .. seedIndex .. " catch respects both level bounds")
      if sample.suffix == "bug" then bugCatches = bugCatches + 1
      else coolCatches = coolCatches + 1 end
    end
  end
end
math.random = originalRandom

check(bugCatches > coolCatches * 2,
  "Bug Catcher catches substantially more often than Cooltrainer")
check(bugCatches > 350 and bugCatches < 700,
  "Bug Catcher catch frequency stays near its data-driven maximum")
check(coolCatches > 50 and coolCatches < 250,
  "Cooltrainer catch frequency stays low but nonzero")

if failures > 0 then
  io.stderr:write(string.format("%d/%d Phase B property checks failed\n",
    failures, checks))
  os.exit(1)
end
print(string.format("%d/%d Phase B property checks passed", checks, checks))
