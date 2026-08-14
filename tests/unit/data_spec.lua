local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local line_meta = assert(loadfile(ROOT .. "/src/data/line_meta.lua"))()
local profiles = assert(loadfile(ROOT .. "/src/data/trainer_profiles.lua"))()
local groups = assert(loadfile(ROOT .. "/src/data/replacement_groups.lua"))()
local overrides = assert(loadfile(ROOT .. "/src/data/ecology_overrides.lua"))()

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

local expectedSpecies = [[
BULBASAUR IVYSAUR VENUSAUR CHARMANDER CHARMELEON CHARIZARD
SQUIRTLE WARTORTLE BLASTOISE CATERPIE METAPOD BUTTERFREE
WEEDLE KAKUNA BEEDRILL PIDGEY PIDGEOTTO PIDGEOT RATTATA RATICATE
SPEAROW FEAROW EKANS ARBOK PIKACHU RAICHU SANDSHREW SANDSLASH
NIDORAN_F NIDORINA NIDOQUEEN NIDORAN_M NIDORINO NIDOKING
CLEFAIRY CLEFABLE VULPIX NINETALES JIGGLYPUFF WIGGLYTUFF
ZUBAT GOLBAT ODDISH GLOOM VILEPLUME PARAS PARASECT VENONAT VENOMOTH
DIGLETT DUGTRIO MEOWTH PERSIAN PSYDUCK GOLDUCK MANKEY PRIMEAPE
GROWLITHE ARCANINE POLIWAG POLIWHIRL POLIWRATH ABRA KADABRA ALAKAZAM
MACHOP MACHOKE MACHAMP BELLSPROUT WEEPINBELL VICTREEBEL
TENTACOOL TENTACRUEL GEODUDE GRAVELER GOLEM PONYTA RAPIDASH
SLOWPOKE SLOWBRO MAGNEMITE MAGNETON FARFETCHD DODUO DODRIO
SEEL DEWGONG GRIMER MUK SHELLDER CLOYSTER GASTLY HAUNTER GENGAR ONIX
DROWZEE HYPNO KRABBY KINGLER VOLTORB ELECTRODE EXEGGCUTE EXEGGUTOR
CUBONE MAROWAK HITMONLEE HITMONCHAN LICKITUNG KOFFING WEEZING
RHYHORN RHYDON CHANSEY TANGELA KANGASKHAN HORSEA SEADRA GOLDEEN SEAKING
STARYU STARMIE MR_MIME SCYTHER JYNX ELECTABUZZ MAGMAR PINSIR TAUROS
MAGIKARP GYARADOS LAPRAS DITTO EEVEE VAPOREON JOLTEON FLAREON
PORYGON OMANYTE OMASTAR KABUTO KABUTOPS AERODACTYL SNORLAX
ARTICUNO ZAPDOS MOLTRES DRATINI DRAGONAIR DRAGONITE MEWTWO MEW
]]

local expected = {}
for species in expectedSpecies:gmatch("%S+") do expected[species] = true end
local expectedCount = 0
for _ in pairs(expected) do expectedCount = expectedCount + 1 end
eq(expectedCount, 151, "the test vocabulary contains all Kanto species")

local meta = line_meta.build()
local seen, covered = {}, 0
for lineId, line in pairs(meta.lines) do
  eq(line.lineId, lineId, "line ids are stable for " .. lineId)
  check(type(line.groups) == "table" and #line.groups > 0,
    lineId .. " declares replacement groups")
  check(type(line.stages) == "table" and #line.stages > 0,
    lineId .. " declares an ordered stage chain")
  check(line.powerBand >= 1 and line.powerBand <= 5,
    lineId .. " has a valid power band")
  check(line.rarity >= 0 and line.rarity <= 4,
    lineId .. " has a valid rarity")
  check(type(line.ecology) == "table" and #line.ecology > 0,
    lineId .. " has ecology tags")
  check(type(line.classTags) == "table",
    lineId .. " has class affinity tags")
  check(type(line.genericEligible) == "boolean",
    lineId .. " explicitly declares generic eligibility")
  for _, stage in ipairs(line.stages) do
    local species = stage.species
    check(expected[species], lineId .. " uses a Kanto species: " .. tostring(species))
    check(not seen[species], "species occurs in only one line: " .. tostring(species))
    seen[species] = lineId
    covered = covered + 1
    eq(meta.bySpecies[species], line,
      "species index points to its line for " .. tostring(species))
  end
end
eq(covered, 151, "line metadata covers all 151 Kanto species")
for species in pairs(expected) do
  check(seen[species] ~= nil, "line metadata includes " .. species)
end

for _, lineId in ipairs({
  "EEVEE_LINE", "OMANYTE_LINE", "KABUTO_LINE", "AERODACTYL",
  "SNORLAX", "ARTICUNO", "ZAPDOS", "MOLTRES", "DRATINI_LINE",
  "MEWTWO", "MEW",
}) do
  eq(meta.lines[lineId].genericEligible, false,
    lineId .. " is excluded from generic trainer selection")
end
eq(meta.bySpecies.ARTICUNO.populationModel, "ULTRA_RARE_SPECIES",
  "Legendary Birds use the ultra-rare species population model")
eq(meta.bySpecies.MEWTWO.populationModel, "UNIQUE_SPECIES",
  "Mewtwo uses the unique species population model")
eq(meta.bySpecies.MEW.populationModel, "UNIQUE_SPECIES",
  "Mew uses the unique species population model")

local postGenExpected = {
  ZUBAT_LINE = "CROBAT", ODDISH_LINE = "BELLOSSOM",
  POLIWAG_LINE = "POLITOED", SLOWPOKE_LINE = "SLOWKING",
  ONIX_LINE = "STEELIX", SCYTHER_LINE = "SCIZOR",
  HORSEA_LINE = "KINGDRA", PORYGON_LINE = "PORYGON2",
  CHANSEY_LINE = "BLISSEY",
}
-- The baseline prose says eight additions but names nine. Preserve every
-- explicitly named line; the audit records this internal spec inconsistency.
for lineId, species in pairs(postGenExpected) do
  local line = assert(meta.lines[lineId], "missing Kanto+ line " .. lineId)
  eq(line.postGen1Stages[1].species, species,
    lineId .. " declares its approved optional continuation")
end

local expectedProfiles = {
  YOUNGSTER = { 0.20, 2, 7.0, 0.25, 10, 0, 0.18, 5.0, 3, 0 },
  BUG_CATCHER = { 0.15, 2, 6.5, 0.20, 12, 0, 0.55, 2.0, 6, 0 },
  LASS = { 0.20, 2, 7.0, 0.25, 10, 0, 0.18, 5.0, 3, 0 },
  SAILOR = { 0.25, 3, 5.5, 0.30, 14, 1, 0.25, 3.5, 4, 1 },
  JR_TRAINER = { 0.30, 3, 5.0, 0.35, 15, 1, 0.18, 4.5, 4, 1 },
  POKEMANIAC = { 0.30, 4, 4.5, 0.40, 18, 1, 0.35, 3.5, 5, 2 },
  SUPER_NERD = { 0.30, 3, 5.0, 0.35, 16, 1, 0.12, 5.0, 4, 2 },
  HIKER = { 0.25, 3, 5.5, 0.30, 15, 1, 0.22, 4.0, 4, 1 },
  BIKER = { 0.25, 3, 5.0, 0.30, 15, 1, 0.18, 4.5, 4, 1 },
  BURGLAR = { 0.30, 3, 5.0, 0.35, 16, 1, 0.08, 6.0, 3, 1 },
  ENGINEER = { 0.35, 4, 4.5, 0.40, 18, 1, 0.10, 5.5, 4, 2 },
  FISHER = { 0.20, 3, 5.5, 0.25, 14, 0, 0.40, 2.5, 5, 1 },
  SWIMMER = { 0.25, 3, 5.0, 0.30, 15, 1, 0.28, 3.0, 4, 1 },
  CUE_BALL = { 0.35, 4, 4.5, 0.40, 18, 1, 0.10, 5.5, 3, 1 },
  GAMBLER = { 0.25, 3, 5.5, 0.30, 15, 1, 0.20, 4.5, 4, 1 },
  BEAUTY = { 0.25, 3, 5.5, 0.30, 15, 1, 0.16, 5.0, 3, 1 },
  PSYCHIC = { 0.40, 5, 4.0, 0.50, 20, 2, 0.10, 6.0, 4, 2 },
  ROCKER = { 0.35, 4, 4.5, 0.45, 18, 2, 0.10, 5.5, 4, 2 },
  JUGGLER = { 0.40, 5, 4.0, 0.50, 20, 2, 0.15, 5.0, 4, 2 },
  TAMER = { 0.40, 5, 4.0, 0.50, 20, 2, 0.25, 4.0, 5, 2 },
  BIRD_KEEPER = { 0.25, 3, 5.0, 0.30, 15, 1, 0.40, 2.5, 5, 1 },
  BLACKBELT = { 0.40, 5, 3.8, 0.50, 20, 2, 0.12, 5.5, 4, 2 },
  SCIENTIST = { 0.40, 5, 4.0, 0.50, 20, 2, 0.08, 6.0, 4, 2 },
  ROCKET = { 0.30, 4, 4.5, 0.40, 18, 1, 0.05, 7.0, 4, 1 },
  COOLTRAINER = { 0.50, 6, 3.5, 0.60, 22, 2, 0.15, 5.0, 5, 3 },
  GENTLEMAN = { 0.30, 4, 5.0, 0.35, 16, 1, 0.10, 6.0, 3, 2 },
  CHANNELER = { 0.35, 4, 4.5, 0.45, 18, 1, 0.08, 6.0, 3, 2 },
}
local fields = { "initialCatchupFactor", "initialCap", "tauHours",
  "playerAlignment", "lifetimeGainCap", "overtakeCap", "catchMax",
  "catchTauHours", "targetOwned", "aiTier" }
for id, values in pairs(expectedProfiles) do
  local profile = profiles.byName[id]
  check(type(profile) == "table", "profile exists for " .. id)
  if profile then
    for index, field in ipairs(fields) do
      eq(profile[field], values[index], id .. " preserves baseline " .. field)
    end
    check(type(profile.classTags) == "table", id .. " has class tags")
    check(profile.mobilityRadius >= 0 and profile.mobilityRadius <= 2,
      id .. " has bounded ecology mobility")
    check(profile.pcRadius >= 0 and profile.pcRadius <= 2,
      id .. " has bounded Center access")
  end
end
eq(profiles.for_class("OPP_YOUNGSTER"), profiles.byName.YOUNGSTER,
  "Gen 1 public trainer class ids resolve to profiles")
eq(profiles.for_class("OPP_JR_TRAINER_F"), profiles.byName.JR_TRAINER,
  "combined class profiles expose both gender ids")
eq(profiles.for_class("UNKNOWN_CLASS"), nil,
  "unknown or canon-only classes do not get generic policy")

local groupIndex = groups.build(meta)
for groupId, lineIds in pairs(groupIndex.byGroup) do
  check(type(groupId) == "string" and #lineIds > 0,
    "replacement group indexes at least one line")
  for _, lineId in ipairs(lineIds) do
    check(meta.lines[lineId] ~= nil,
      groupId .. " references a declared line " .. tostring(lineId))
  end
end
check(type(overrides.byMap) == "table" and type(overrides.byClass) == "table",
  "ecology overrides expose explicit map and organization seams")

if failures > 0 then
  io.stderr:write(string.format("%d/%d data checks failed\n", failures, checks))
  os.exit(1)
end
print(string.format("%d/%d data checks passed", checks, checks))
