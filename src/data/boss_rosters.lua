local M = { leaders = {} }

local LINE_ALIASES = {
  AERODACTYL_LINE = "AERODACTYL",
  BEEDRILL_LINE = "WEEDLE_LINE",
  ELECTABUZZ_LINE = "ELECTABUZZ",
  GYARADOS_LINE = "MAGIKARP_LINE",
  JYNX_LINE = "JYNX",
  LAPRAS_LINE = "LAPRAS",
  MAGMAR_LINE = "MAGMAR",
  MR_MIME_LINE = "MR_MIME",
  STARMIE_LINE = "STARYU_LINE",
}

local STRATEGIES = {
  STONEWALL = { techniques = { "BIDE", "REFLECT", "SANDSTORM" },
    preferredTypes = { ROCK = true, GROUND = true } },
  ANTI_WATER = { techniques = { "SUNNY_DAY", "THUNDERBOLT", "MEGA_DRAIN" },
    preferredTypes = { GROUND = true, ELECTRIC = true, GRASS = true } },
  ANTI_GRASS = { techniques = { "ROCK_SLIDE", "FIRE_BLAST", "FLY" },
    preferredTypes = { ROCK = true, FLYING = true, FIRE = true } },
  RAIN_TEMPO = { techniques = { "RAIN_DANCE", "SURF", "THUNDER" },
    preferredTypes = { WATER = true, ELECTRIC = true } },
  FREEZE_COVERAGE = { techniques = { "ICE_BEAM", "BLIZZARD", "SURF" },
    preferredTypes = { WATER = true, ICE = true } },
  CONTROL = { techniques = { "THUNDER_WAVE", "RECOVER", "CONFUSION" },
    preferredTypes = { WATER = true, PSYCHIC = true } },
  PARALYSIS_SPEED = { techniques = { "THUNDER_WAVE", "THUNDERBOLT", "AGILITY" },
    preferredTypes = { ELECTRIC = true } },
  RAIN_THUNDER = { techniques = { "RAIN_DANCE", "THUNDER", "THUNDERBOLT" },
    preferredTypes = { ELECTRIC = true, WATER = true } },
  ANTI_GROUND = { techniques = { "SURF", "MEGA_DRAIN", "FLY" },
    preferredTypes = { WATER = true, GRASS = true, FLYING = true } },
  SLEEP_CONTROL = { techniques = { "SLEEP_POWDER", "STUN_SPORE", "MEGA_DRAIN" },
    preferredTypes = { GRASS = true, PSYCHIC = true } },
  SUN_SOLAR = { techniques = { "SUNNY_DAY", "SOLARBEAM", "MEGA_DRAIN" },
    preferredTypes = { GRASS = true, FIRE = true } },
  PSYCHIC_COVER = { techniques = { "PSYCHIC", "SLEEP_POWDER", "REFLECT" },
    preferredTypes = { GRASS = true, PSYCHIC = true } },
  TOXIC_ATTRITION = { techniques = { "TOXIC", "REST", "SMOKESCREEN" },
    preferredTypes = { POISON = true } },
  EVASION_CONFUSION = { techniques = { "DOUBLE_TEAM", "CONFUSION", "TOXIC" },
    preferredTypes = { POISON = true, PSYCHIC = true } },
  ANTI_PSYCHIC = { techniques = { "PIN_MISSILE", "TWINEEDLE", "LEECH_LIFE" },
    preferredTypes = { BUG = true, GHOST = true, POISON = true } },
  SCREENS = { techniques = { "REFLECT", "LIGHT_SCREEN", "PSYCHIC" },
    preferredTypes = { PSYCHIC = true } },
  SLEEP_DREAM = { techniques = { "HYPNOSIS", "DREAM_EATER", "PSYCHIC" },
    preferredTypes = { PSYCHIC = true } },
  BULKY_PSYCHIC = { techniques = { "AMNESIA", "REST", "PSYCHIC" },
    preferredTypes = { PSYCHIC = true, WATER = true } },
  SUN_CORE = { techniques = { "SUNNY_DAY", "FIRE_BLAST", "FLAMETHROWER" },
    preferredTypes = { FIRE = true } },
  SOLAR_COVERAGE = { techniques = { "SUNNY_DAY", "SOLARBEAM", "FIRE_BLAST" },
    preferredTypes = { FIRE = true, GRASS = true } },
  FLYING_GROUND_IMMUNITY = { techniques = { "FLY", "FIRE_BLAST", "SLASH" },
    preferredTypes = { FIRE = true, FLYING = true } },
  EARTHQUAKE_PRESSURE = { techniques = { "EARTHQUAKE", "ROCK_SLIDE", "SUBSTITUTE" },
    preferredTypes = { GROUND = true, ROCK = true } },
  ELEMENTAL_NIDO = { techniques = { "EARTHQUAKE", "THUNDERBOLT", "ICE_BEAM" },
    preferredTypes = { GROUND = true, ELECTRIC = true, ICE = true } },
  SAND_CONTROL = { techniques = { "SANDSTORM", "EARTHQUAKE", "ROCK_SLIDE" },
    preferredTypes = { GROUND = true, ROCK = true } },
}

local function package(id)
  local source = assert(STRATEGIES[id], "unknown boss strategy " .. tostring(id))
  local row = { id = id, techniques = {}, signatureMoves = {},
    roleWeights = {}, preferredMoves = {}, preferredTypes = {} }
  for _, move in ipairs(source.techniques or {}) do
    row.techniques[#row.techniques + 1] = move
    row.preferredMoves[move] = true
  end
  for move, value in pairs(source.preferredMoves or {}) do
    row.preferredMoves[move] = value
  end
  for moveType, value in pairs(source.preferredTypes or {}) do
    row.preferredTypes[moveType] = value
  end
  return row
end

local function leader(id, theme, signature, signatureSpecies, flex, counts,
    floors, strategies, signatureMoveGroups, strategyStructure)
  local row = { id = id, typeTheme = theme, signatureLine = signature,
    signatureSpeciesByVersion = signatureSpecies,
    flexPool = flex, activeCountByVersion = counts,
    vanillaFloorsByVersion = floors, strategyOrder = strategies,
    signatureMoveGroups = signatureMoveGroups, strategyPackages = {} }
  for _, strategy in ipairs(strategies) do
    local strategyRow = package(strategy)
    local structure = strategyStructure and strategyStructure[strategy] or {}
    strategyRow.preferredLines = structure.preferredLines or {}
    strategyRow.signatureExtras = structure.signatureExtras or {}
    strategyRow.techniques = structure.flexTechniques or {}
    strategyRow.preferredMoves = {}
    for _, moveId in ipairs(strategyRow.techniques) do
      strategyRow.preferredMoves[moveId] = true
    end
    for _, moveId in ipairs(strategyRow.signatureExtras) do
      strategyRow.preferredMoves[moveId] = true
    end
    row.strategyPackages[strategy] = strategyRow
  end
  M.leaders[id] = row
end

leader("BROCK", "ROCK", "ONIX_LINE",
  { red = "ONIX", blue = "ONIX", yellow = "ONIX" },
  { "GEODUDE_LINE", "RHYHORN_LINE", "OMANYTE_LINE", "KABUTO_LINE",
    "AERODACTYL_LINE" },
  { red = 2, blue = 2, yellow = 2 },
  { red = { 14, 12 }, blue = { 14, 12 }, yellow = { 12, 10 } },
  { "STONEWALL", "ANTI_WATER", "ANTI_GRASS" },
  { { "ROCK_SLIDE" }, { "EARTHQUAKE", "DIG" }, { "SCREECH" },
    { "BIDE" } }, {
    STONEWALL = { preferredLines = { "GEODUDE_LINE", "RHYHORN_LINE" },
      flexTechniques = { "SANDSTORM", "REFLECT", "BIDE" } },
    ANTI_WATER = { preferredLines = { "RHYHORN_LINE" },
      flexTechniques = { "SUNNY_DAY", "THUNDERBOLT", "ROCK_SLIDE" } },
    ANTI_GRASS = { preferredLines = { "AERODACTYL_LINE" },
      flexTechniques = { "FLY", "ROCK_SLIDE", "FIRE_BLAST" } },
  })

leader("MISTY", "WATER", "STARMIE_LINE",
  { red = "STARMIE", blue = "STARMIE", yellow = "STARMIE" },
  { "PSYDUCK_LINE", "POLIWAG_LINE", "SLOWPOKE_LINE", "TENTACOOL_LINE",
    "SHELLDER_LINE", "HORSEA_LINE", "GOLDEEN_LINE", "GYARADOS_LINE",
    "LAPRAS_LINE" },
  { red = 2, blue = 2, yellow = 2 },
  { red = { 21, 18 }, blue = { 21, 18 }, yellow = { 21, 18 } },
  { "RAIN_TEMPO", "FREEZE_COVERAGE", "CONTROL" },
  { { "SURF", "BUBBLEBEAM" }, { "PSYCHIC" },
    { "THUNDER_WAVE", "ICE_BEAM" }, { "RECOVER" } }, {
    RAIN_TEMPO = { preferredLines = { "GYARADOS_LINE", "HORSEA_LINE" },
      flexTechniques = { "RAIN_DANCE", "SURF", "THUNDER" } },
    FREEZE_COVERAGE = { preferredLines = { "SHELLDER_LINE", "LAPRAS_LINE" },
      flexTechniques = { "ICE_BEAM", "BLIZZARD", "SURF" } },
    CONTROL = { preferredLines = { "SLOWPOKE_LINE" },
      flexTechniques = { "THUNDER_WAVE", "CONFUSION", "AMNESIA" } },
  })

leader("LT_SURGE", "ELECTRIC", "PIKACHU_LINE",
  { red = "RAICHU", blue = "RAICHU", yellow = "RAICHU" },
  { "VOLTORB_LINE", "MAGNEMITE_LINE", "ELECTABUZZ_LINE" },
  { red = 3, blue = 3, yellow = 1 },
  { red = { 24, 21, 18 }, blue = { 24, 21, 18 }, yellow = { 28 } },
  { "PARALYSIS_SPEED", "RAIN_THUNDER", "ANTI_GROUND" },
  { { "THUNDERBOLT", "THUNDER" }, { "THUNDER_WAVE" },
    { "BODY_SLAM", "MEGA_KICK" } }, {
    PARALYSIS_SPEED = { preferredLines = { "VOLTORB_LINE" },
      signatureExtras = { "AGILITY" },
      flexTechniques = { "THUNDER_WAVE", "AGILITY", "THUNDERBOLT" } },
    RAIN_THUNDER = { preferredLines = { "MAGNEMITE_LINE" },
      signatureExtras = { "RAIN_DANCE" },
      flexTechniques = { "RAIN_DANCE", "THUNDER", "LIGHT_SCREEN" } },
    ANTI_GROUND = { preferredLines = { "ELECTABUZZ_LINE" },
      signatureExtras = { "SURF" },
      flexTechniques = { "ICE_PUNCH", "ICE_BEAM", "PSYCHIC" } },
  })

leader("ERIKA", "GRASS", "ODDISH_LINE",
  { red = "VILEPLUME", blue = "VILEPLUME", yellow = "GLOOM" },
  { "BELLSPROUT_LINE", "TANGELA_LINE", "EXEGGCUTE_LINE", "PARAS_LINE",
    "BULBASAUR_LINE" },
  { red = 3, blue = 3, yellow = 3 },
  { red = { 29, 29, 24 }, blue = { 29, 29, 24 },
    yellow = { 32, 32, 30 } },
  { "SLEEP_CONTROL", "SUN_SOLAR", "PSYCHIC_COVER" },
  { { "MEGA_DRAIN" }, { "SLEEP_POWDER" }, { "STUN_SPORE" },
    { "SUNNY_DAY", "REFLECT" } }, {
    SLEEP_CONTROL = { preferredLines = { "BELLSPROUT_LINE", "PARAS_LINE" },
      flexTechniques = { "SLEEP_POWDER", "STUN_SPORE", "MEGA_DRAIN" } },
    SUN_SOLAR = { preferredLines = { "BULBASAUR_LINE", "BELLSPROUT_LINE" },
      flexTechniques = { "SUNNY_DAY", "SOLARBEAM", "MEGA_DRAIN" } },
    PSYCHIC_COVER = { preferredLines = { "EXEGGCUTE_LINE" },
      flexTechniques = { "PSYCHIC", "SLEEP_POWDER", "REFLECT" } },
  })

leader("KOGA", "POISON",
  { red = "KOFFING_LINE", blue = "KOFFING_LINE", yellow = "VENONAT_LINE" },
  { red = "WEEZING", blue = "WEEZING", yellow = "VENOMOTH" },
  { "GRIMER_LINE", "EKANS_LINE", "ZUBAT_LINE", "NIDORAN_F_LINE",
    "NIDORAN_M_LINE", "TENTACOOL_LINE", "BEEDRILL_LINE" },
  { red = 4, blue = 4, yellow = 4 },
  { red = { 43, 39, 37, 37 }, blue = { 43, 39, 37, 37 },
    yellow = { 50, 48, 46, 44 } },
  { "TOXIC_ATTRITION", "EVASION_CONFUSION", "ANTI_GROUND",
    "ANTI_PSYCHIC" }, {
    red = { { "SLUDGE_BOMB", "SLUDGE" }, { "TOXIC" }, { "SMOKESCREEN" },
      { "EXPLOSION" } },
    blue = { { "SLUDGE_BOMB", "SLUDGE" }, { "TOXIC" }, { "SMOKESCREEN" },
      { "EXPLOSION" } },
    yellow = { { "PSYCHIC" }, { "SLEEP_POWDER" }, { "TOXIC" },
      { "DOUBLE_TEAM" } },
  }, {
    TOXIC_ATTRITION = { preferredLines = { "GRIMER_LINE", "TENTACOOL_LINE" },
      flexTechniques = { "TOXIC", "REST", "SMOKESCREEN" } },
    EVASION_CONFUSION = { preferredLines = { "ZUBAT_LINE", "GRIMER_LINE" },
      flexTechniques = { "DOUBLE_TEAM", "CONFUSE_RAY", "TOXIC" } },
    ANTI_GROUND = { preferredLines = { "ZUBAT_LINE" },
      flexTechniques = { "FLY", "CONFUSE_RAY", "TOXIC" } },
    ANTI_PSYCHIC = { preferredLines = { "BEEDRILL_LINE" },
      flexTechniques = { "PIN_MISSILE", "TWINEEDLE", "LEECH_LIFE" } },
  })

leader("SABRINA", "PSYCHIC", "ABRA_LINE",
  { red = "ALAKAZAM", blue = "ALAKAZAM", yellow = "ALAKAZAM" },
  { "DROWZEE_LINE", "MR_MIME_LINE", "SLOWPOKE_LINE", "EXEGGCUTE_LINE",
    "JYNX_LINE" },
  { red = 4, blue = 4, yellow = 3 },
  { red = { 43, 38, 38, 37 }, blue = { 43, 38, 38, 37 },
    yellow = { 50, 50, 50 } },
  { "SCREENS", "SLEEP_DREAM", "BULKY_PSYCHIC" },
  { { "PSYCHIC" }, { "RECOVER" }, { "REFLECT" },
    { "THUNDER_WAVE" } }, {
    SCREENS = { preferredLines = { "MR_MIME_LINE" },
      flexTechniques = { "REFLECT", "LIGHT_SCREEN", "PSYCHIC" } },
    SLEEP_DREAM = { preferredLines = { "DROWZEE_LINE", "JYNX_LINE" },
      flexTechniques = { "HYPNOSIS", "DREAM_EATER", "PSYCHIC" } },
    BULKY_PSYCHIC = { preferredLines = { "SLOWPOKE_LINE", "EXEGGCUTE_LINE" },
      flexTechniques = { "AMNESIA", "REST", "PSYCHIC" } },
  })

leader("BLAINE", "FIRE", "GROWLITHE_LINE",
  { red = "ARCANINE", blue = "ARCANINE", yellow = "ARCANINE" },
  { "VULPIX_LINE", "PONYTA_LINE", "MAGMAR_LINE", "CHARMANDER_LINE",
    "EEVEE_LINE:FLAREON" },
  { red = 4, blue = 4, yellow = 3 },
  { red = { 47, 42, 42, 40 }, blue = { 47, 42, 42, 40 },
    yellow = { 54, 50, 48 } },
  { "SUN_CORE", "SOLAR_COVERAGE", "FLYING_GROUND_IMMUNITY" },
  { { "FIRE_BLAST", "FLAMETHROWER" }, { "SUNNY_DAY", "REFLECT" },
    { "AGILITY", "BODY_SLAM" } }, {
    SUN_CORE = { preferredLines = { "MAGMAR_LINE", "PONYTA_LINE" },
      signatureExtras = { "BODY_SLAM" },
      flexTechniques = { "SUNNY_DAY", "FIRE_BLAST", "FLAMETHROWER" } },
    SOLAR_COVERAGE = { preferredLines = { "VULPIX_LINE", "PONYTA_LINE" },
      signatureExtras = { "SOLARBEAM" },
      flexTechniques = { "SUNNY_DAY", "SOLARBEAM", "FIRE_BLAST" } },
    FLYING_GROUND_IMMUNITY = { preferredLines = { "CHARMANDER_LINE" },
      signatureExtras = { "BODY_SLAM" },
      flexTechniques = { "FLY", "FIRE_BLAST", "SLASH" } },
  })

leader("GIOVANNI", "GROUND", "RHYHORN_LINE",
  { red = "RHYDON", blue = "RHYDON", yellow = "RHYDON" },
  { "DIGLETT_LINE", "SANDSHREW_LINE", "CUBONE_LINE", "NIDORAN_F_LINE",
    "NIDORAN_M_LINE", "ONIX_LINE" },
  { red = 5, blue = 5, yellow = 5 },
  { red = { 50, 45, 45, 44, 42 }, blue = { 50, 45, 45, 44, 42 },
    yellow = { 55, 55, 53, 53, 50 } },
  { "EARTHQUAKE_PRESSURE", "ELEMENTAL_NIDO", "SAND_CONTROL" },
  { { "EARTHQUAKE" }, { "ROCK_SLIDE" }, { "ICE_BEAM", "THUNDERBOLT" },
    { "SUBSTITUTE", "SANDSTORM" } }, {
    EARTHQUAKE_PRESSURE = { preferredLines = { "DIGLETT_LINE", "CUBONE_LINE" },
      flexTechniques = { "EARTHQUAKE", "ROCK_SLIDE", "SUBSTITUTE" } },
    ELEMENTAL_NIDO = { preferredLines = { "NIDORAN_F_LINE", "NIDORAN_M_LINE" },
      flexTechniques = { "EARTHQUAKE", "THUNDERBOLT", "ICE_BEAM" } },
    SAND_CONTROL = { preferredLines = { "SANDSHREW_LINE", "ONIX_LINE" },
      flexTechniques = { "SANDSTORM", "EARTHQUAKE", "ROCK_SLIDE" } },
  })

function M.active_count(identity, version)
  return assert(identity.activeCountByVersion[version],
    "unsupported boss game version " .. tostring(version))
end

function M.floors(identity, version)
  return assert(identity.vanillaFloorsByVersion[version],
    "unsupported boss game version " .. tostring(version))
end

function M.signature_line(identity, version)
  if type(identity.signatureLine) == "table" then
    return assert(identity.signatureLine[version],
      "missing version-specific boss signature")
  end
  return identity.signatureLine
end

function M.signature_species(identity, version)
  local byVersion = identity.signatureSpeciesByVersion or {}
  return assert(byVersion[version], "missing version-specific boss signature species")
end

function M.signature_move_groups(identity, version)
  if type(identity.signatureMoveGroups) == "table"
      and identity.signatureMoveGroups.red then
    return assert(identity.signatureMoveGroups[version],
      "missing version-specific boss signature move groups")
  end
  return identity.signatureMoveGroups or {}
end

function M.line(meta, lineId)
  local base = tostring(lineId):match("^([^:]+)")
  base = LINE_ALIASES[base] or base
  return meta and meta.lines and meta.lines[base]
end

function M.preferred_species(lineId)
  return tostring(lineId):match(":([A-Z0-9_]+)$")
end

return M
