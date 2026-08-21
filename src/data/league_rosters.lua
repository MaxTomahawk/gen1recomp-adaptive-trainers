local M = { members = {} }

local LINE_ALIASES = {
  AERODACTYL_LINE = "AERODACTYL",
  GYARADOS_LINE = "MAGIKARP_LINE",
  JYNX_LINE = "JYNX",
  LAPRAS_LINE = "LAPRAS",
}

local function package(id, preferredLines, techniques, preferredTypes)
  local preferredMoves = {}
  for _, moveId in ipairs(techniques or {}) do preferredMoves[moveId] = true end
  return { id = id, preferredLines = preferredLines or {},
    techniques = techniques or {}, signatureExtras = {},
    preferredMoves = preferredMoves, preferredTypes = preferredTypes or {},
    roleWeights = {} }
end

local function member(id, classId, mapId, theme, signatureLine,
    signatureSpecies, poolLines, floors, signatureMoveGroups, strategies)
  local row = { id = id, classId = classId, partyIndex = 1,
    mapId = mapId, npcId = mapId .. "_obj_1", typeTheme = theme,
    signatureLine = signatureLine, signatureSpecies = signatureSpecies,
    poolLines = poolLines, floors = floors,
    signatureMoveGroups = signatureMoveGroups,
    strategyOrder = {}, strategyPackages = {} }
  for _, strategy in ipairs(strategies) do
    row.strategyOrder[#row.strategyOrder + 1] = strategy.id
    row.strategyPackages[strategy.id] = strategy
  end
  M.members[id] = row
end

member("LORELEI", "OPP_LORELEI", "LORELEIS_ROOM",
  { ICE = true, WATER = true }, "LAPRAS_LINE", "LAPRAS",
  { "SEEL_LINE", "SHELLDER_LINE", "SLOWPOKE_LINE", "JYNX_LINE",
    "LAPRAS_LINE" }, { 56, 56, 54, 54, 53 },
  { { "BLIZZARD", "ICE_BEAM" }, { "SURF" }, { "THUNDERBOLT" },
    { "CONFUSE_RAY" } }, {
    package("FREEZE_CONTROL", { "SHELLDER_LINE", "JYNX_LINE" },
      { "BLIZZARD", "ICE_BEAM", "LOVELY_KISS" },
      { ICE = true, PSYCHIC = true }),
    package("BULKY_WATER", { "SLOWPOKE_LINE", "LAPRAS_LINE" },
      { "SURF", "AMNESIA", "REST" }, { WATER = true, PSYCHIC = true }),
    package("ANTI_FIGHT_ROCK", { "SLOWPOKE_LINE", "JYNX_LINE" },
      { "PSYCHIC", "SURF", "REFLECT" },
      { PSYCHIC = true, WATER = true }),
  })

member("BRUNO", "OPP_BRUNO", "BRUNOS_ROOM",
  { FIGHTING = true, ROCK = true }, "MACHOP_LINE", "MACHAMP",
  { "MACHOP_LINE", "HITMONLEE", "HITMONCHAN", "MANKEY_LINE",
    "POLIWAG_LINE:POLIWRATH", "ONIX_LINE" }, { 58, 56, 55, 55, 53 },
  { { "SUBMISSION", "SEISMIC_TOSS" }, { "ROCK_SLIDE" },
    { "EARTHQUAKE" }, { "BODY_SLAM", "MEGA_KICK" } }, {
    package("PHYSICAL_PRESSURE", { "MACHOP_LINE", "HITMONLEE" },
      { "SUBMISSION", "BODY_SLAM", "EARTHQUAKE" },
      { FIGHTING = true, GROUND = true }),
    package("ELEMENTAL_HITMONCHAN", { "HITMONCHAN" },
      { "ICE_PUNCH", "THUNDERPUNCH", "FIRE_PUNCH" },
      { ICE = true, ELECTRIC = true, FIRE = true }),
    package("ROCK_STEEL_ANTI_FLYING", { "ONIX_LINE" },
      { "ROCK_SLIDE", "EARTHQUAKE", "BIDE" },
      { ROCK = true, GROUND = true }),
  })

member("AGATHA", "OPP_AGATHA", "AGATHAS_ROOM",
  { GHOST = true, POISON = true }, "GASTLY_LINE", "GENGAR",
  { "GASTLY_LINE", "EKANS_LINE", "ZUBAT_LINE", "KOFFING_LINE",
    "VENONAT_LINE" }, { 60, 58, 56, 56, 55 },
  { { "NIGHT_SHADE", "PSYCHIC" }, { "HYPNOSIS" },
    { "DREAM_EATER", "PSYCHIC" }, { "THUNDERBOLT" } }, {
    package("SLEEP_DREAM", { "GASTLY_LINE", "VENONAT_LINE" },
      { "HYPNOSIS", "SLEEP_POWDER", "DREAM_EATER" },
      { GHOST = true, PSYCHIC = true }),
    package("TOXIC_CONFUSION", { "EKANS_LINE", "KOFFING_LINE" },
      { "TOXIC", "CONFUSE_RAY", "SMOKESCREEN" },
      { POISON = true, GHOST = true }),
    package("SWITCH_PRESSURE", { "ZUBAT_LINE", "GASTLY_LINE" },
      { "CONFUSE_RAY", "MEGA_DRAIN", "PSYCHIC" },
      { GHOST = true, FLYING = true }),
  })

member("LANCE", "OPP_LANCE", "LANCES_ROOM",
  { DRAGON = true, FLYING = true }, "DRATINI_LINE", "DRAGONITE",
  { "DRATINI_LINE", "GYARADOS_LINE", "AERODACTYL_LINE",
    "CHARMANDER_LINE:CHARIZARD", "HORSEA_LINE:KINGDRA" },
  { 62, 60, 58, 56, 56 },
  { { "BLIZZARD", "ICE_BEAM", "THUNDER" }, { "HYPER_BEAM" },
    { "AGILITY", "BARRIER" }, { "DRAGON_RAGE" } }, {
    package("RARE_FLYERS", { "AERODACTYL_LINE",
        "CHARMANDER_LINE:CHARIZARD" },
      { "FLY", "ROCK_SLIDE", "FIRE_BLAST" },
      { FLYING = true, ROCK = true, FIRE = true }),
    package("WATER_DRAGON", { "GYARADOS_LINE", "HORSEA_LINE:KINGDRA" },
      { "SURF", "ICE_BEAM", "THUNDER" },
      { WATER = true, DRAGON = true }),
    package("ANTI_ICE_FIRE", { "CHARMANDER_LINE:CHARIZARD",
        "AERODACTYL_LINE" },
      { "FIRE_BLAST", "FLY", "ROCK_SLIDE" },
      { FIRE = true, FLYING = true, ROCK = true }),
  })

M.birds = {
  ARTICUNO = { member = "LORELEI", lineId = "ARTICUNO",
    moveGroups = { { "BLIZZARD", "ICE_BEAM" }, { "FLY", "SKY_ATTACK" },
      { "REFLECT" }, { "TOXIC", "AGILITY" } } },
  ZAPDOS = { member = "LANCE", lineId = "ZAPDOS",
    moveGroups = { { "THUNDERBOLT", "THUNDER" }, { "DRILL_PECK" },
      { "THUNDER_WAVE" }, { "LIGHT_SCREEN" } } },
  MOLTRES = { member = "LANCE", lineId = "MOLTRES",
    moveGroups = { { "FIRE_BLAST" }, { "FLY" }, { "AGILITY" },
      { "SUNNY_DAY", "SOLARBEAM" } } },
}

function M.by_battle(context)
  context = context or {}
  for _, id in ipairs({ "LORELEI", "BRUNO", "AGATHA", "LANCE" }) do
    local row = M.members[id]
    if context.trainerClass == row.classId
        and (context.partyIndex or 1) == row.partyIndex
        and context.mapId == row.mapId and context.npcId == row.npcId then
      return row
    end
  end
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
