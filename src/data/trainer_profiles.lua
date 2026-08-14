local M = { byName = {}, byClass = {} }

local ROLE_PREFERENCES = {
  YOUNGSTER = { "fast_physical", "balanced" },
  BUG_CATCHER = { "swarm", "attrition" },
  LASS = { "support", "balanced" },
  SAILOR = { "bulky_damage", "physical" },
  JR_TRAINER = { "balanced", "fast_physical" },
  POKEMANIAC = { "oddity", "balanced" },
  SUPER_NERD = { "special_control", "attrition" },
  HIKER = { "physical_wall", "physical" },
  BIKER = { "attrition", "fast_physical" },
  BURGLAR = { "fast_special", "fast_physical" },
  ENGINEER = { "special_control", "fast_special" },
  FISHER = { "bulky_damage", "control" },
  SWIMMER = { "bulky_damage", "fast_special" },
  CUE_BALL = { "physical", "physical_wall" },
  GAMBLER = { "oddity", "balanced" },
  BEAUTY = { "support", "balanced" },
  PSYCHIC = { "special_control", "control" },
  ROCKER = { "fast_special", "special_control" },
  JUGGLER = { "control", "oddity" },
  TAMER = { "physical", "bulky_damage" },
  BIRD_KEEPER = { "fast_physical", "swarm" },
  BLACKBELT = { "physical", "physical_wall" },
  SCIENTIST = { "special_control", "attrition" },
  ROCKET = { "attrition", "balanced" },
  COOLTRAINER = { "balanced", "control" },
  GENTLEMAN = { "balanced", "support" },
  CHANNELER = { "special_control", "attrition" },
}

local function profile(id, values, behavior)
  behavior = behavior or {}
  local row = {
    id = id,
    initialCatchupFactor = values[1],
    initialCap = values[2],
    tauHours = values[3],
    playerAlignment = values[4],
    lifetimeGainCap = values[5],
    overtakeCap = values[6],
    catchMax = values[7],
    catchTauHours = values[8],
    targetOwned = values[9],
    aiTier = values[10],
    classTags = behavior.classTags or {},
    rolePreferences = behavior.rolePreferences or ROLE_PREFERENCES[id]
      or { "balanced" },
    encounterMethods = behavior.encounterMethods or { grass = true },
    mobilityRadius = behavior.mobilityRadius or 1,
    pcRadius = behavior.pcRadius or 1,
    rarityAllowance = behavior.rarityAllowance or 1,
    maxRarity3 = behavior.maxRarity3 or 1,
    specialistType = behavior.specialistType == true,
    allowDuplicateLines = behavior.allowDuplicateLines == true,
    rosterBehavior = behavior.rosterBehavior or "casual",
  }
  M.byName[id] = row
  return row
end

local YOUNGSTER = profile("YOUNGSTER",
  { .20, 2, 7.0, .25, 10, 0, .18, 5.0, 3, 0 },
  { classTags = { "youngster" }, rarityAllowance = 1 })
local BUG_CATCHER = profile("BUG_CATCHER",
  { .15, 2, 6.5, .20, 12, 0, .55, 2.0, 6, 0 },
  { classTags = { "bugcatcher" }, rarityAllowance = 1,
    allowDuplicateLines = true, rosterBehavior = "collector",
    specialistType = true })
local LASS = profile("LASS",
  { .20, 2, 7.0, .25, 10, 0, .18, 5.0, 3, 0 },
  { classTags = { "lass" }, rarityAllowance = 2 })
local SAILOR = profile("SAILOR",
  { .25, 3, 5.5, .30, 14, 1, .25, 3.5, 4, 1 },
  { classTags = { "sailor" }, encounterMethods = { grass = true, water = true },
    mobilityRadius = 2, rarityAllowance = 2 })
local JR_TRAINER = profile("JR_TRAINER",
  { .30, 3, 5.0, .35, 15, 1, .18, 4.5, 4, 1 },
  { classTags = { "jrtrainer" }, mobilityRadius = 2, rarityAllowance = 3 })
local POKEMANIAC = profile("POKEMANIAC",
  { .30, 4, 4.5, .40, 18, 1, .35, 3.5, 5, 2 },
  { classTags = { "pokemaniac" }, mobilityRadius = 2, pcRadius = 2,
    rarityAllowance = 4, maxRarity3 = 2, rosterBehavior = "collector" })
local SUPER_NERD = profile("SUPER_NERD",
  { .30, 3, 5.0, .35, 16, 1, .12, 5.0, 4, 2 },
  { classTags = { "scientist" }, pcRadius = 2, rarityAllowance = 2 })
local HIKER = profile("HIKER",
  { .25, 3, 5.5, .30, 15, 1, .22, 4.0, 4, 1 },
  { classTags = { "hiker" }, rarityAllowance = 2, specialistType = true })
local BIKER = profile("BIKER",
  { .25, 3, 5.0, .30, 15, 1, .18, 4.5, 4, 1 },
  { classTags = { "biker" }, mobilityRadius = 2, rarityAllowance = 2,
    allowDuplicateLines = true, rosterBehavior = "swarm",
    specialistType = true })
local BURGLAR = profile("BURGLAR",
  { .30, 3, 5.0, .35, 16, 1, .08, 6.0, 3, 1 },
  { classTags = { "burglar" }, mobilityRadius = 2, rarityAllowance = 3 })
local ENGINEER = profile("ENGINEER",
  { .35, 4, 4.5, .40, 18, 1, .10, 5.5, 4, 2 },
  { classTags = { "engineer" }, pcRadius = 2, rarityAllowance = 2 })
local FISHER = profile("FISHER",
  { .20, 3, 5.5, .25, 14, 0, .40, 2.5, 5, 1 },
  { classTags = { "fisher" }, encounterMethods = { water = true },
    rarityAllowance = 2, rosterBehavior = "collector", specialistType = true })
local SWIMMER = profile("SWIMMER",
  { .25, 3, 5.0, .30, 15, 1, .28, 3.0, 4, 1 },
  { classTags = { "swimmer" }, encounterMethods = { water = true },
    mobilityRadius = 2, pcRadius = 0, rarityAllowance = 2,
    specialistType = true })
local CUE_BALL = profile("CUE_BALL",
  { .35, 4, 4.5, .40, 18, 1, .10, 5.5, 3, 1 },
  { classTags = { "cueball" }, mobilityRadius = 2, rarityAllowance = 2,
    rosterBehavior = "training" })
local GAMBLER = profile("GAMBLER",
  { .25, 3, 5.5, .30, 15, 1, .20, 4.5, 4, 1 },
  { classTags = { "gambler" }, mobilityRadius = 2, pcRadius = 2,
    rarityAllowance = 3, rosterBehavior = "variance" })
local BEAUTY = profile("BEAUTY",
  { .25, 3, 5.5, .30, 15, 1, .16, 5.0, 3, 1 },
  { classTags = { "beauty" }, mobilityRadius = 2, pcRadius = 2,
    rarityAllowance = 3 })
local PSYCHIC = profile("PSYCHIC",
  { .40, 5, 4.0, .50, 20, 2, .10, 6.0, 4, 2 },
  { classTags = { "psychic" }, rarityAllowance = 3,
    rosterBehavior = "specialist", specialistType = true })
local ROCKER = profile("ROCKER",
  { .35, 4, 4.5, .45, 18, 2, .10, 5.5, 4, 2 },
  { classTags = { "rocker", "engineer" }, pcRadius = 2, rarityAllowance = 3,
    rosterBehavior = "specialist", specialistType = true })
local JUGGLER = profile("JUGGLER",
  { .40, 5, 4.0, .50, 20, 2, .15, 5.0, 4, 2 },
  { classTags = { "juggler" }, mobilityRadius = 2, pcRadius = 2,
    rarityAllowance = 3, rosterBehavior = "variance" })
local TAMER = profile("TAMER",
  { .40, 5, 4.0, .50, 20, 2, .25, 4.0, 5, 2 },
  { classTags = { "tamer" }, mobilityRadius = 2, pcRadius = 2,
    rarityAllowance = 4, maxRarity3 = 2, rosterBehavior = "specialist" })
local BIRD_KEEPER = profile("BIRD_KEEPER",
  { .25, 3, 5.0, .30, 15, 1, .40, 2.5, 5, 1 },
  { classTags = { "birdkeeper" }, mobilityRadius = 2, rarityAllowance = 2,
    allowDuplicateLines = true, rosterBehavior = "collector",
    specialistType = true })
local BLACKBELT = profile("BLACKBELT",
  { .40, 5, 3.8, .50, 20, 2, .12, 5.5, 4, 2 },
  { classTags = { "blackbelt" }, mobilityRadius = 2, rarityAllowance = 3,
    rosterBehavior = "training", specialistType = true })
local SCIENTIST = profile("SCIENTIST",
  { .40, 5, 4.0, .50, 20, 2, .08, 6.0, 4, 2 },
  { classTags = { "scientist" }, pcRadius = 2, rarityAllowance = 3,
    rosterBehavior = "specialist" })
local ROCKET = profile("ROCKET",
  { .30, 4, 4.5, .40, 18, 1, .05, 7.0, 4, 1 },
  { classTags = { "rocket" }, mobilityRadius = 2, rarityAllowance = 2,
    rosterBehavior = "organization" })
local COOLTRAINER = profile("COOLTRAINER",
  { .50, 6, 3.5, .60, 22, 2, .15, 5.0, 5, 3 },
  { classTags = { "cooltrainer" }, mobilityRadius = 2, pcRadius = 2,
    rarityAllowance = 4, maxRarity3 = 2, rosterBehavior = "expert" })
local GENTLEMAN = profile("GENTLEMAN",
  { .30, 4, 5.0, .35, 16, 1, .10, 6.0, 3, 2 },
  { classTags = { "gentleman" }, mobilityRadius = 2, pcRadius = 2,
    rarityAllowance = 3 })
local CHANNELER = profile("CHANNELER",
  { .35, 4, 4.5, .45, 18, 1, .08, 6.0, 3, 2 },
  { classTags = { "channeler" }, rarityAllowance = 3,
    rosterBehavior = "specialist", specialistType = true })

local aliases = {
  OPP_YOUNGSTER = YOUNGSTER,
  OPP_BUG_CATCHER = BUG_CATCHER,
  OPP_LASS = LASS,
  OPP_SAILOR = SAILOR,
  OPP_JR_TRAINER_M = JR_TRAINER,
  OPP_JR_TRAINER_F = JR_TRAINER,
  OPP_POKEMANIAC = POKEMANIAC,
  OPP_SUPER_NERD = SUPER_NERD,
  OPP_HIKER = HIKER,
  OPP_BIKER = BIKER,
  OPP_BURGLAR = BURGLAR,
  OPP_ENGINEER = ENGINEER,
  OPP_FISHER = FISHER,
  OPP_SWIMMER = SWIMMER,
  OPP_CUE_BALL = CUE_BALL,
  OPP_GAMBLER = GAMBLER,
  OPP_BEAUTY = BEAUTY,
  OPP_PSYCHIC = PSYCHIC,
  OPP_ROCKER = ROCKER,
  OPP_JUGGLER = JUGGLER,
  OPP_TAMER = TAMER,
  OPP_BIRD_KEEPER = BIRD_KEEPER,
  OPP_BLACKBELT = BLACKBELT,
  OPP_SCIENTIST = SCIENTIST,
  OPP_ROCKET = ROCKET,
  OPP_COOLTRAINER_M = COOLTRAINER,
  OPP_COOLTRAINER_F = COOLTRAINER,
  OPP_GENTLEMAN = GENTLEMAN,
  OPP_CHANNELER = CHANNELER,
}
for id, row in pairs(aliases) do M.byClass[id] = row end

function M.for_class(classId)
  return M.byClass[classId]
end

return M
