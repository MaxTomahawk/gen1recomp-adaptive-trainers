local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local rng = assert(loadfile(ROOT .. "/src/core/rng.lua"))()
local player_power = assert(loadfile(ROOT .. "/src/core/player_power.lua"))()
local ecology = assert(loadfile(ROOT .. "/src/core/ecology.lua"))()
local stage_resolver = assert(loadfile(ROOT .. "/src/core/stage_resolver.lua"))()
local selector_factory = assert(loadfile(ROOT .. "/src/core/species_selector.lua"))()
local selector = selector_factory({ stage_resolver = stage_resolver })
local validator = assert(loadfile(ROOT .. "/src/core/team_validator.lua"))()
local standard_factory = assert(loadfile(ROOT .. "/src/core/standard_trainers.lua"))()
local standard = standard_factory({
  rng = rng,
  player_power = player_power,
  ecology = ecology,
  selector = selector,
  validator = validator,
  stage_resolver = stage_resolver,
})

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

local lines = {
  PIDGEY_LINE = {
    lineId = "PIDGEY_LINE",
    stages = {
      { species = "PIDGEY", minLevel = 1 },
      { species = "PIDGEOTTO", minLevel = 18 },
      { species = "PIDGEOT", minLevel = 36 },
    },
    groups = { "EARLY_BIRD", "FLYING_COMMON" },
    powerBand = 1, rarity = 0, ecology = { "route", "grass" },
    classTags = { "young", "birdkeeper" }, genericEligible = true,
  },
  SPEAROW_LINE = {
    lineId = "SPEAROW_LINE",
    stages = {
      { species = "SPEAROW", minLevel = 1 },
      { species = "FEAROW", minLevel = 20 },
    },
    groups = { "EARLY_BIRD", "FLYING_COMMON" },
    powerBand = 1, rarity = 0, ecology = { "route" },
    classTags = { "young", "birdkeeper" }, genericEligible = true,
  },
  RATTATA_LINE = {
    lineId = "RATTATA_LINE",
    stages = { { species = "RATTATA", minLevel = 1 } },
    groups = { "EARLY_SMALL_MAMMAL" },
    powerBand = 1, rarity = 0, ecology = { "route" },
    classTags = { "young" }, genericEligible = true,
  },
  RHYHORN_LINE = {
    lineId = "RHYHORN_LINE",
    stages = { { species = "RHYHORN", minLevel = 1 } },
    groups = { "ROCK_COMMON" },
    powerBand = 3, rarity = 2, ecology = { "mountain" },
    classTags = { "hiker" }, genericEligible = true,
  },
  ARTICUNO = {
    lineId = "ARTICUNO",
    stages = { { species = "ARTICUNO", minLevel = 1 } },
    groups = { "EARLY_BIRD", "LEGENDARY_BIRD" },
    powerBand = 1, rarity = 0, ecology = { "route" },
    classTags = { "birdkeeper" }, genericEligible = false,
    populationModel = "ULTRA_RARE_SPECIES",
  },
}

local bySpecies = {}
for _, line in pairs(lines) do
  for _, stage in ipairs(line.stages) do bySpecies[stage.species] = line end
end
local meta = { lines = lines, bySpecies = bySpecies }

local pokemon = {
  PIDGEY = { types = { "FLYING" }, baseStats = { hp = 40, attack = 45,
    defense = 40, speed = 56, special = 35 } },
  PIDGEOTTO = { types = { "FLYING" }, baseStats = { hp = 63, attack = 60,
    defense = 55, speed = 71, special = 50 } },
  PIDGEOT = { types = { "FLYING" }, baseStats = { hp = 83, attack = 80,
    defense = 75, speed = 91, special = 70 } },
  SPEAROW = { types = { "FLYING" }, baseStats = { hp = 40, attack = 60,
    defense = 30, speed = 70, special = 31 } },
  FEAROW = { types = { "FLYING" }, baseStats = { hp = 65, attack = 90,
    defense = 65, speed = 100, special = 61 } },
  RATTATA = { types = { "NORMAL" }, baseStats = { hp = 30, attack = 56,
    defense = 35, speed = 72, special = 25 } },
  RHYHORN = { types = { "GROUND", "ROCK" }, baseStats = { hp = 80,
    attack = 85, defense = 95, speed = 25, special = 30 } },
  ARTICUNO = { types = { "ICE", "FLYING" }, baseStats = { hp = 90,
    attack = 85, defense = 100, speed = 85, special = 125 } },
}

local dynamicLine = {
  lineId = "DYNAMIC_LINE",
  stages = { { species = "DYNAMIC_A" }, { species = "DYNAMIC_B" },
    { species = "DYNAMIC_C", surrogateLevel = 36 } },
  postGen1Stages = {},
}
local dynamicPokemon = {
  DYNAMIC_A = { evolutions = {
    { method = "LEVEL", level = 16, species = "DYNAMIC_B" },
  } },
  DYNAMIC_B = { evolutions = {
    { method = "TRADE", species = "DYNAMIC_C" },
  } },
  DYNAMIC_C = {},
}
eq(stage_resolver.resolve(dynamicLine, 15, dynamicPokemon), "DYNAMIC_A",
  "stage thresholds are derived from the runtime evolution registry")
eq(stage_resolver.resolve(dynamicLine, 16, dynamicPokemon), "DYNAMIC_B",
  "runtime level evolutions occur exactly at their registry threshold")
eq(stage_resolver.resolve(dynamicLine, 35, dynamicPokemon), "DYNAMIC_B",
  "trade evolutions wait for the configured NPC surrogate threshold")
eq(stage_resolver.resolve(dynamicLine, 36, dynamicPokemon), "DYNAMIC_C",
  "trade evolutions use the configured NPC surrogate threshold")

local branchLine = {
  lineId = "BRANCH_LINE", branching = true,
  stages = { { species = "BASE" },
    { species = "LEFT", surrogateLevel = 30 },
    { species = "RIGHT", surrogateLevel = 30 } },
  postGen1Stages = {},
}
local branchPokemon = { BASE = {}, LEFT = {}, RIGHT = {} }
eq(stage_resolver.resolve(branchLine, 40, branchPokemon, "LEFT"), "LEFT",
  "branching lines preserve an explicitly selected branch")
eq(stage_resolver.resolve(branchLine, 40, branchPokemon, "RIGHT"), "RIGHT",
  "branch preservation does not collapse to table order")

eq(stage_resolver.resolve(lines.PIDGEY_LINE, 17, pokemon), "PIDGEY",
  "stage resolution keeps the base form below its threshold")
eq(stage_resolver.resolve(lines.PIDGEY_LINE, 18, pokemon), "PIDGEOTTO",
  "stage resolution evolves exactly at its threshold")
eq(stage_resolver.resolve(lines.PIDGEY_LINE, 50, pokemon), "PIDGEOT",
  "stage resolution chooses the highest eligible existing stage")
local noFinal = { PIDGEY = pokemon.PIDGEY, PIDGEOTTO = pokemon.PIDGEOTTO }
eq(stage_resolver.resolve(lines.PIDGEY_LINE, 50, noFinal), "PIDGEOTTO",
  "missing optional stages degrade to the highest existing stage")

local profile = {
  rarityAllowance = 1,
  classTags = { young = true },
  encounterMethods = { grass = true },
  mobilityRadius = 2,
  initialCap = 2,
  initialCatchupFactor = 0.2,
  allowDuplicateLines = false,
}
local evidence = {
  { species = "SPEAROW", weight = 1.0, distance = 0 },
  { species = "RATTATA", weight = 1.0, distance = 0 },
  { species = "RHYHORN", weight = 1.0, distance = 0 },
  { species = "ARTICUNO", weight = 1.0, distance = 0 },
}
local ranked = selector.rank({
  vanillaSpecies = "PIDGEY", targetLevel = 8, profile = profile,
  evidence = evidence, meta = meta, pokemon = pokemon, team = {},
})
local rankedIds = {}
for _, row in ipairs(ranked) do rankedIds[row.line.lineId] = row end
check(rankedIds.PIDGEY_LINE ~= nil,
  "the original line remains a candidate even when absent from local ecology")
check(rankedIds.SPEAROW_LINE ~= nil,
  "a local line with replacement-group overlap is eligible")
eq(rankedIds.RATTATA_LINE, nil,
  "a local line without replacement-group overlap is rejected")
eq(rankedIds.RHYHORN_LINE, nil,
  "a candidate more than one power band away is rejected")
eq(rankedIds.ARTICUNO, nil,
  "generic selection hard-excludes Legendary candidates")
check(rankedIds.SPEAROW_LINE.score > rankedIds.PIDGEY_LINE.score,
  "local ecology can outweigh the original-line prior")

local scoringLines = {
  ORIGINAL = { lineId = "ORIGINAL", stages = { { species = "ORIGINAL", minLevel = 1 } },
    groups = { "COMMON" }, powerBand = 2, rarity = 0,
    classTags = {}, roles = { "balanced" }, genericEligible = true },
  FAST = { lineId = "FAST", stages = { { species = "FAST", minLevel = 1 } },
    groups = { "COMMON" }, powerBand = 2, rarity = 2,
    classTags = {}, roles = { "fast" }, genericEligible = true },
  WALL = { lineId = "WALL", stages = { { species = "WALL", minLevel = 1 } },
    groups = { "COMMON" }, powerBand = 2, rarity = 0,
    classTags = {}, roles = { "wall" }, genericEligible = true },
  RARE4 = { lineId = "RARE4", stages = { { species = "RARE4", minLevel = 1 } },
    groups = { "COMMON" }, powerBand = 2, rarity = 4,
    classTags = {}, roles = { "fast" }, genericEligible = true },
}
local scoringMeta = { lines = scoringLines, bySpecies = {} }
local scoringPokemon = {
  ORIGINAL = { types = { "NORMAL" } }, FAST = { types = { "FIRE" } },
  WALL = { types = { "WATER" } }, RARE4 = { types = { "FIRE" } },
}
for _, line in pairs(scoringLines) do
  scoringMeta.bySpecies[line.stages[1].species] = line
end
local function score_rows(profileOverrides, team)
  local configured = { rarityAllowance = 4, classTags = {},
    rolePreferences = profileOverrides and profileOverrides.rolePreferences,
    allowDuplicateLines = false }
  local rows = selector.rank({ vanillaSpecies = "ORIGINAL", targetLevel = 10,
    profile = configured, evidence = {
      { species = "FAST", weight = 1 }, { species = "WALL", weight = 1 },
      { species = "RARE4", weight = 1 },
    }, meta = scoringMeta, pokemon = scoringPokemon, team = team or {} })
  local out = {}
  for _, row in ipairs(rows) do out[row.line.lineId] = row.score end
  return out
end
local roleScores = score_rows({ rolePreferences = { "fast" } })
check(roleScores.FAST > roleScores.WALL,
  "configured line roles influence the normative role-fit score")
eq(roleScores.RARE4, nil,
  "rarity-four lines remain forbidden even with class allowance four")
local teamScores = score_rows(nil, { { species = "FAST", lineId = "FAST" } })
check(teamScores.WALL > teamScores.FAST,
  "the current partial team influences later-slot team fit")
local neutralScores = score_rows(nil)
check(neutralScores.WALL > neutralScores.FAST,
  "rarity penalty reduces ecology score for rarer otherwise-equal lines")

local vanillaTeam = { { species = "PIDGEY", level = 8 } }
local legalTeam = { { species = "SPEAROW", level = 8, lineId = "SPEAROW_LINE" } }
local valid, report = validator.validate_initial(legalTeam, vanillaTeam, {
  meta = meta, pokemon = pokemon, profile = profile,
})
check(valid, "a close-power single-slot replacement is valid")
check(report.powerRatio >= 0.88 and report.powerRatio <= 1.12,
  "valid initial team power stays within twelve percent")
local invalid = validator.validate_initial({
  { species = "RHYHORN", level = 8, lineId = "RHYHORN_LINE" },
}, vanillaTeam, { meta = meta, pokemon = pokemon, profile = profile })
eq(invalid, false, "an overpowered initial replacement is rejected")

local invariantLines = {
  COMMON_A = { lineId = "COMMON_A", rarity = 0 },
  COMMON_B = { lineId = "COMMON_B", rarity = 0 },
  COMMON_C = { lineId = "COMMON_C", rarity = 0 },
  RARE_A = { lineId = "RARE_A", rarity = 3 },
  RARE_B = { lineId = "RARE_B", rarity = 3 },
  RARE_C = { lineId = "RARE_C", rarity = 3 },
  FORBIDDEN = { lineId = "FORBIDDEN", rarity = 4 },
}
local invariantMeta = { lines = invariantLines, bySpecies = {
  TYPE_A = invariantLines.COMMON_A, TYPE_B = invariantLines.COMMON_B,
  TYPE_C = invariantLines.COMMON_C, RARE_A = invariantLines.RARE_A,
  RARE_B = invariantLines.RARE_B, RARE_C = invariantLines.RARE_C,
  FORBIDDEN = invariantLines.FORBIDDEN,
} }
local invariantPokemon = {
  TYPE_A = { types = { "FIRE" } }, TYPE_B = { types = { "FIRE" } },
  TYPE_C = { types = { "FIRE" } }, RARE_A = { types = { "WATER" } },
  RARE_B = { types = { "GRASS" } }, RARE_C = { types = { "ROCK" } },
  FORBIDDEN = { types = { "ICE" } },
}
local invariantContext = { meta = invariantMeta, pokemon = invariantPokemon,
  profile = { allowDuplicateLines = false, maxRarity3 = 1 } }
local threeSameType = { { species = "TYPE_A" }, { species = "TYPE_B" },
  { species = "TYPE_C" }, { species = "RARE_A" } }
eq(validator.validate_structure(threeSameType, {}, invariantContext), false,
  "ordinary two-to-four member parties cannot stack three primary types")
eq(validator.validate_structure(threeSameType, threeSameType,
  invariantContext), true,
  "a vanilla-themed primary-type stack remains a valid blueprint")
invariantContext.profile.specialistType = true
eq(validator.validate_structure(threeSameType, {}, invariantContext), true,
  "explicit type specialists may stack their primary type")
invariantContext.profile.specialistType = nil
eq(validator.validate_structure({ { species = "RARE_A" },
  { species = "RARE_B" } }, {}, invariantContext), false,
  "ordinary profiles allow at most one rarity-three line")
invariantContext.profile.maxRarity3 = 2
eq(validator.validate_structure({ { species = "RARE_A" },
  { species = "RARE_B" } }, {}, invariantContext), true,
  "collector and expert profiles may allow two rarity-three lines")
eq(validator.validate_structure({ { species = "RARE_A" },
  { species = "RARE_B" }, { species = "RARE_C" } }, {}, invariantContext), false,
  "the expanded allowance still rejects a third rarity-three line")
eq(validator.validate_structure({ { species = "FORBIDDEN" } }, {},
  invariantContext), false, "rarity-four lines are never generic")

local data = {
  pokemon = pokemon,
  maps = { ROUTE_TEST = { connections = {}, warps = {} } },
  encounters = { ROUTE_TEST = { grass = { slots = {
    { species = "SPEAROW", level = 5 },
  } } } },
}
local root = {
  seedHi = 123456, seedLo = 987654,
  trainers = {},
}
local context = {
  version = "red", mapId = "ROUTE_TEST",
  oppClass = "OPP_YOUNGSTER", partyIndex = 1,
  identityKey = "red|ROUTE_TEST|OPP_YOUNGSTER|1",
  playTime = 1000,
  playerParty = { { species = "RATTATA", level = 12, hp = 0 } },
}

local originalRandom = math.random
math.random = function() error("initial generation must not use math.random") end
local firstParty, firstState = standard.build(context, vanillaTeam, root, {
  data = data, meta = meta, profile = profile,
})
math.random = originalRandom
check(type(firstParty) == "table" and #firstParty == 1,
  "initial generation preserves vanilla party size")
check(firstParty[1].species == "PIDGEY" or firstParty[1].species == "SPEAROW",
  "initial generation selects only eligible replacement lines")
check(firstParty[1].level >= 8,
  "initial generation never scales a slot below vanilla")
eq(firstState.identityKey, context.identityKey,
  "the persisted TrainerState records the concrete identity")
eq(#firstState.owned, 1, "the generated individual is persisted as owned")
eq(firstState.activeIds[1], firstState.owned[1].id,
  "the active roster references the persisted individual id")

for run = 1, 100 do
  local party, state = standard.build(context, vanillaTeam, root, {
    data = data, meta = meta, profile = profile,
  })
  eq(party[1].species, firstParty[1].species,
    "persisted species repeats on rerun " .. run)
  eq(party[1].level, firstParty[1].level,
    "persisted level repeats on rerun " .. run)
  check(state.owned[1] == firstState.owned[1],
    "rerun reuses the exact PokemonInstance " .. run)
end

local repairLines = {
  A_LINE = { lineId = "A_LINE", stages = { { species = "A", minLevel = 1 } },
    groups = { "COMMON" }, powerBand = 1, rarity = 0,
    classTags = {}, genericEligible = true },
  B_LINE = { lineId = "B_LINE", stages = { { species = "B", minLevel = 1 } },
    groups = { "COMMON" }, powerBand = 1, rarity = 0,
    classTags = {}, genericEligible = true },
  C_LINE = { lineId = "C_LINE", stages = { { species = "C", minLevel = 1 } },
    groups = { "COMMON" }, powerBand = 1, rarity = 0,
    classTags = {}, genericEligible = true },
}
local repairBySpecies = { A = repairLines.A_LINE, B = repairLines.B_LINE,
  C = repairLines.C_LINE }
local repairPokemon = {
  A = { types = { "NORMAL" }, baseStats = { hp = 50, attack = 50,
    defense = 50, speed = 50, special = 50 } },
  B = { types = { "FIRE" }, baseStats = { hp = 50, attack = 50,
    defense = 50, speed = 50, special = 50 } },
  C = { types = { "WATER" }, baseStats = { hp = 50, attack = 50,
    defense = 50, speed = 50, special = 50 } },
}
local repairSelector = {
  rank = function()
    return {
      { line = repairLines.B_LINE, species = "B", score = 1 },
      { line = repairLines.C_LINE, species = "C", score = .8 },
      { line = repairLines.A_LINE, species = "A", score = .6 },
    }
  end,
  choose = function(rows) return rows[1] end,
}
local repairStandard = standard_factory({
  rng = rng,
  player_power = player_power,
  ecology = { resolve = function() return {} end },
  selector = repairSelector,
  validator = validator,
  stage_resolver = stage_resolver,
})
local repairParty = repairStandard.build({
  version = "red", mapId = "REPAIR_MAP", oppClass = "OPP_YOUNGSTER",
  partyIndex = 1, identityKey = "repair-trainer", playTime = 0,
  playerParty = { { species = "A", level = 5 } },
}, { { species = "A", level = 5 }, { species = "A", level = 5 } }, {
  seedHi = 3, seedLo = 7, trainers = {},
}, {
  data = { pokemon = repairPokemon, maps = {}, encounters = {} },
  meta = { lines = repairLines, bySpecies = repairBySpecies },
  profile = { initialCatchupFactor = 0, initialCap = 0,
    allowDuplicateLines = false },
})
eq(repairParty[1].species, "B",
  "bounded repair keeps the first valid randomized slot")
eq(repairParty[2].species, "C",
  "bounded repair replaces only the conflicting duplicate slot")
check(repairParty[1].species ~= "A" or repairParty[2].species ~= "A",
  "a local conflict does not revert the whole generated team")
local _, hashState = repairStandard.build({
  version = "red", mapId = "HASH_MAP", oppClass = "OPP_YOUNGSTER",
  partyIndex = 1, identityKey = "hash-trainer", playTime = 0,
  playerParty = {},
}, { { species = "A", level = 5 } }, {
  seedHi = 2, seedLo = 4, trainers = {},
}, { data = { pokemon = repairPokemon, maps = {}, encounters = {} },
  meta = { lines = repairLines, bySpecies = repairBySpecies },
  profile = { initialCatchupFactor = 0, initialCap = 0 } })
check(type(hashState.vanillaPartyHash) == "string",
  "persistent trainer state records a stable vanilla-party hash")

local observedOverride
local overrideStandard = standard_factory({
  rng = rng, player_power = player_power,
  ecology = { resolve = function(_, _, _, context)
    observedOverride = context and context.override
    return {}
  end },
  selector = repairSelector, validator = validator,
  stage_resolver = stage_resolver,
})
overrideStandard.build({
  version = "red", mapId = "INDOOR_LAB", oppClass = "OPP_ROCKET",
  partyIndex = 1, identityKey = "issued-trainer", playTime = 0,
  playerParty = {},
}, { { species = "A", level = 5 } }, {
  seedHi = 4, seedLo = 8, trainers = {},
}, { data = { pokemon = repairPokemon, maps = {}, encounters = {} },
  meta = { lines = repairLines, bySpecies = repairBySpecies },
  profile = { initialCatchupFactor = 0, initialCap = 0 },
  ecologyOverrides = { byMap = {}, byClass = {
    OPP_ROCKET = { organizationIssued = true },
  } },
})
check(observedOverride and observedOverride.organizationIssued,
  "standard generation forwards organization ecology overrides")

local jumpLine = { lineId = "JUMP_LINE", rarity = 0,
  stages = { { species = "JUMP_BASE" }, { species = "JUMP_FINAL" } } }
local jumpPokemon = {
  JUMP_BASE = { types = { "NORMAL" }, baseStats = { hp = 20, attack = 20,
    defense = 20, speed = 20, special = 20 }, evolutions = {
      { method = "LEVEL", level = 6, species = "JUMP_FINAL" },
    } },
  JUMP_FINAL = { types = { "NORMAL" }, baseStats = { hp = 100, attack = 100,
    defense = 100, speed = 100, special = 100 }, evolutions = {} },
}
local jumpSelector = {
  rank = function() return { { line = jumpLine, species = "JUMP_FINAL",
    score = 1 } } end,
  choose = function(rows) return rows[1] end,
}
local jumpStandard = standard_factory({
  rng = rng, player_power = player_power,
  ecology = { resolve = function() return {} end },
  selector = jumpSelector, validator = validator,
  stage_resolver = stage_resolver,
})
local jumpParty = jumpStandard.build({
  version = "red", mapId = "JUMP_MAP", oppClass = "OPP_YOUNGSTER",
  partyIndex = 1, identityKey = "jump-trainer", playTime = 0,
  playerParty = {},
}, { { species = "JUMP_BASE", level = 10 } }, {
  seedHi = 5, seedLo = 9, trainers = {},
}, { data = { pokemon = jumpPokemon, maps = {}, encounters = {} },
  meta = { lines = { JUMP_LINE = jumpLine }, bySpecies = {
    JUMP_BASE = jumpLine, JUMP_FINAL = jumpLine,
  } }, profile = { initialCatchupFactor = 0, initialCap = 0 } })
eq(jumpParty[1].species, "JUMP_BASE",
  "power validation compares against the exact runtime blueprint species")

local scoredLines = {
  BASE = { lineId = "BASE", rarity = 0,
    stages = { { species = "SCORE_BASE" } } },
  BEST = { lineId = "BEST", rarity = 0,
    stages = { { species = "SCORE_BEST" } } },
  SECOND = { lineId = "SECOND", rarity = 0,
    stages = { { species = "SCORE_SECOND" } } },
  TOO_HIGH = { lineId = "TOO_HIGH", rarity = 0,
    stages = { { species = "SCORE_HIGH" } } },
}
local scoredPokemon = {
  SCORE_BASE = { types = { "NORMAL" }, baseStats = { hp = 50, attack = 50,
    defense = 50, speed = 50, special = 50 } },
  SCORE_BEST = { types = { "FIRE" }, baseStats = { hp = 51, attack = 51,
    defense = 51, speed = 51, special = 51 } },
  SCORE_SECOND = { types = { "WATER" }, baseStats = { hp = 49, attack = 49,
    defense = 49, speed = 49, special = 49 } },
  SCORE_HIGH = { types = { "ROCK" }, baseStats = { hp = 100, attack = 100,
    defense = 100, speed = 100, special = 100 } },
}
local scoredRows = {
  { line = scoredLines.TOO_HIGH, species = "SCORE_HIGH", score = 1.0 },
  { line = scoredLines.BEST, species = "SCORE_BEST", score = 0.9 },
  { line = scoredLines.SECOND, species = "SCORE_SECOND", score = 0.8 },
}
local scoredStandard = standard_factory({
  rng = rng, player_power = player_power,
  ecology = { resolve = function() return {} end },
  selector = { rank = function() return scoredRows end,
    choose = function(rows) return rows[1] end },
  validator = validator, stage_resolver = stage_resolver,
})
local scoredParty = scoredStandard.build({
  version = "red", mapId = "SCORE_MAP", oppClass = "OPP_YOUNGSTER",
  partyIndex = 1, identityKey = "score-trainer", playTime = 0,
  playerParty = {},
}, { { species = "SCORE_BASE", level = 10 } }, {
  seedHi = 6, seedLo = 10, trainers = {},
}, { data = { pokemon = scoredPokemon, maps = {}, encounters = {} },
  meta = { lines = scoredLines, bySpecies = {
    SCORE_BASE = scoredLines.BASE, SCORE_BEST = scoredLines.BEST,
    SCORE_SECOND = scoredLines.SECOND, SCORE_HIGH = scoredLines.TOO_HIGH,
  } }, profile = { initialCatchupFactor = 0, initialCap = 0 } })
eq(scoredParty[1].species, "SCORE_BEST",
  "deterministic fallback chooses the highest-scored valid candidate")

local repairAttempts = 0
local boundedLines = { BASE = scoredLines.BASE }
local boundedPokemon = { SCORE_BASE = scoredPokemon.SCORE_BASE }
local boundedRows = {}
for index = 1, 30 do
  local speciesId = "INVALID_" .. index
  local line = { lineId = speciesId, rarity = 0,
    stages = { { species = speciesId } } }
  boundedLines[speciesId] = line
  boundedPokemon[speciesId] = scoredPokemon.SCORE_HIGH
  boundedRows[index] = { line = line, species = speciesId,
    score = 2 - index / 100 }
end
local boundedStandard = standard_factory({
  rng = rng, player_power = player_power,
  ecology = { resolve = function() return {} end },
  selector = { rank = function() return boundedRows end,
    choose = function(rows) return rows[1] end },
  validator = validator, stage_resolver = stage_resolver,
  onRepairAttempt = function() repairAttempts = repairAttempts + 1 end,
})
local boundedBySpecies = { SCORE_BASE = scoredLines.BASE }
for id, line in pairs(boundedLines) do
  if id ~= "BASE" then boundedBySpecies[id] = line end
end
local boundedParty = boundedStandard.build({
  version = "red", mapId = "BOUND_MAP", oppClass = "OPP_YOUNGSTER",
  partyIndex = 1, identityKey = "bounded-trainer", playTime = 0,
  playerParty = {},
}, { { species = "SCORE_BASE", level = 10 } }, {
  seedHi = 7, seedLo = 11, trainers = {},
}, { data = { pokemon = boundedPokemon, maps = {}, encounters = {} },
  meta = { lines = boundedLines, bySpecies = boundedBySpecies },
  profile = { initialCatchupFactor = 0, initialCap = 0 } })
eq(repairAttempts, 24,
  "fallback stops after twenty-four scored repair candidates")
eq(boundedParty[1].species, "SCORE_BASE",
  "repair exhaustion falls back to a proven-valid exact blueprint")

if failures > 0 then
  io.stderr:write(string.format("%d/%d generation checks failed\n",
    failures, checks))
  os.exit(1)
end
print(string.format("%d/%d generation checks passed", checks, checks))
