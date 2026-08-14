local rows = {}

local ROLE_RULES = {
  { "SOFT_SUPPORT", "support" },
  { "PSYCHIC", "special_control" },
  { "GHOST", "special_control" },
  { "ELECTRIC", "fast_special" },
  { "FIRE", "fast_special" },
  { "ICE", "special_control" },
  { "FLYING", "fast_physical" },
  { "BIRD", "fast_physical" },
  { "FIGHT", "physical" },
  { "BRUISER", "physical" },
  { "ROCK", "physical_wall" },
  { "GROUND", "physical_wall" },
  { "BURROWER", "physical" },
  { "POISON", "attrition" },
  { "INDUSTRIAL", "special_control" },
  { "BUG", "swarm" },
  { "GRASS", "control" },
  { "WATER", "bulky_damage" },
  { "ODDITY", "oddity" },
  { "FOSSIL", "physical_wall" },
  { "DRAGON", "balanced" },
  { "COMPANION", "support" },
}

local function words(value)
  local out = {}
  for word in value:gmatch("[^;]+") do
    out[#out + 1] = word:match("^%s*(.-)%s*$")
  end
  return out
end

local function stages(value, surrogate)
  local out = {}
  for species in value:gmatch("%S+") do
    local stage = { species = species }
    if surrogate and surrogate[species] then
      stage.surrogateLevel = surrogate[species]
    end
    out[#out + 1] = stage
  end
  return out
end

local function inferred_roles(groups)
  local out, seen = {}, {}
  for _, group in ipairs(groups) do
    for _, rule in ipairs(ROLE_RULES) do
      if group:find(rule[1], 1, true) and not seen[rule[2]] then
        seen[rule[2]] = true
        out[#out + 1] = rule[2]
      end
    end
  end
  if #out == 0 then out[1] = "balanced" end
  return out
end

local function add(id, species, groups, power, rarity, ecology, classTags, opts)
  opts = opts or {}
  local replacementGroups = words(groups)
  local configuredRoles = words(opts.roles or "")
  rows[#rows + 1] = {
    lineId = id,
    stages = stages(species, opts.surrogate),
    postGen1Stages = stages(opts.postGen1 or "", opts.postGen1Surrogate),
    groups = replacementGroups,
    powerBand = power,
    rarity = rarity,
    ecology = words(ecology),
    classTags = words(classTags or ""),
    roles = #configuredRoles > 0 and configuredRoles
      or inferred_roles(replacementGroups),
    genericEligible = rarity < 4 and opts.genericEligible ~= false,
    populationModel = opts.populationModel or "COMMON_SPECIES",
    branching = opts.branching == true,
  }
end

add("BULBASAUR_LINE", "BULBASAUR IVYSAUR VENUSAUR",
  "STARTER_RARE;GRASS_SPECIAL", 3, 3, "grass;garden",
  "jrtrainer;beauty;erika")
add("CHARMANDER_LINE", "CHARMANDER CHARMELEON CHARIZARD",
  "STARTER_RARE;FIRE_RARE", 3, 3, "urban;rare",
  "jrtrainer;pokemaniac;blaine")
add("SQUIRTLE_LINE", "SQUIRTLE WARTORTLE BLASTOISE",
  "STARTER_RARE;WATER_RARE", 3, 3, "water;urban",
  "jrtrainer;swimmer;rival")
add("CATERPIE_LINE", "CATERPIE METAPOD BUTTERFREE",
  "BUG_LARVA_COMMON", 1, 0, "forest;grass", "bugcatcher")
add("WEEDLE_LINE", "WEEDLE KAKUNA BEEDRILL",
  "BUG_LARVA_COMMON", 1, 0, "forest;grass", "bugcatcher")
add("PIDGEY_LINE", "PIDGEY PIDGEOTTO PIDGEOT",
  "EARLY_BIRD;FLYING_COMMON", 1, 0, "route;grass",
  "youngster;lass;birdkeeper")
add("RATTATA_LINE", "RATTATA RATICATE", "EARLY_SMALL_MAMMAL", 1, 0,
  "route;urban", "youngster;rocket")
add("SPEAROW_LINE", "SPEAROW FEAROW", "EARLY_BIRD;FLYING_COMMON", 1, 0,
  "route", "youngster;birdkeeper")
add("EKANS_LINE", "EKANS ARBOK", "POISON_VERMIN", 2, 1,
  "route;urban", "rocket;biker;koga")
add("PIKACHU_LINE", "PIKACHU RAICHU", "ELECTRIC_COMMON;COMPANION", 2, 2,
  "forest;power", "lass;jrtrainer;surge", { surrogate = { RAICHU = 30 } })
add("SANDSHREW_LINE", "SANDSHREW SANDSLASH", "BURROWER_GROUND", 2, 1,
  "route;cave", "hiker;rocket;giovanni")
add("NIDORAN_F_LINE", "NIDORAN_F NIDORINA NIDOQUEEN",
  "EARLY_SMALL_MAMMAL;POISON_BRUISER", 2, 1, "route",
  "lass;tamer;koga", { surrogate = { NIDOQUEEN = 30 } })
add("NIDORAN_M_LINE", "NIDORAN_M NIDORINO NIDOKING",
  "EARLY_SMALL_MAMMAL;POISON_BRUISER", 2, 1, "route",
  "youngster;tamer;koga", { surrogate = { NIDOKING = 30 } })
add("CLEFAIRY_LINE", "CLEFAIRY CLEFABLE", "NORMAL_SOFT_SUPPORT", 2, 2,
  "cave;rare", "lass;beauty", { surrogate = { CLEFABLE = 30 } })
add("VULPIX_LINE", "VULPIX NINETALES", "FIRE_COMMON", 2, 2,
  "route;urban", "burglar;blaine", { surrogate = { NINETALES = 30 } })
add("JIGGLYPUFF_LINE", "JIGGLYPUFF WIGGLYTUFF", "NORMAL_SOFT_SUPPORT", 2, 2,
  "route;urban", "lass;beauty", { surrogate = { WIGGLYTUFF = 30 } })
add("ZUBAT_LINE", "ZUBAT GOLBAT", "CAVE_BAT;FLYING_COMMON", 1, 0,
  "cave", "rocket;hiker;koga", {
    postGen1 = "CROBAT", postGen1Surrogate = { CROBAT = 36 } })
add("ODDISH_LINE", "ODDISH GLOOM VILEPLUME", "GRASS_COMMON", 2, 1,
  "grass", "lass;erika", {
    surrogate = { VILEPLUME = 30 }, postGen1 = "BELLOSSOM",
    postGen1Surrogate = { BELLOSSOM = 36 }, branching = true })
add("PARAS_LINE", "PARAS PARASECT", "BUG_HUNTER;GRASS_COMMON", 2, 1,
  "cave;forest", "bugcatcher;erika")
add("VENONAT_LINE", "VENONAT VENOMOTH", "BUG_HUNTER;POISON", 2, 1,
  "forest", "bugcatcher;koga")
add("DIGLETT_LINE", "DIGLETT DUGTRIO", "BURROWER_GROUND", 2, 1,
  "cave;ground", "hiker;giovanni")
add("MEOWTH_LINE", "MEOWTH PERSIAN", "EARLY_SMALL_MAMMAL;URBAN", 2, 1,
  "urban;route", "lass;rocket")
add("PSYDUCK_LINE", "PSYDUCK GOLDUCK", "WATER_PSYCHIC", 2, 1,
  "water", "swimmer;misty")
add("MANKEY_LINE", "MANKEY PRIMEAPE", "FIGHTER_COMMON", 2, 1,
  "route;mountain", "blackbelt;cueball")
add("GROWLITHE_LINE", "GROWLITHE ARCANINE", "FIRE_COMMON", 2, 2,
  "route;urban", "gentleman;blaine", { surrogate = { ARCANINE = 30 } })
add("POLIWAG_LINE", "POLIWAG POLIWHIRL POLIWRATH",
  "WATER_SMALL_FISH;FIGHTER_RARE", 2, 1, "water",
  "fisher;swimmer;misty;bruno", {
    surrogate = { POLIWRATH = 30 }, postGen1 = "POLITOED",
    postGen1Surrogate = { POLITOED = 36 }, branching = true })
add("ABRA_LINE", "ABRA KADABRA ALAKAZAM", "PSYCHIC_COMMON", 2, 2,
  "route;rare", "psychic;rival;sabrina", { surrogate = { ALAKAZAM = 36 } })
add("MACHOP_LINE", "MACHOP MACHOKE MACHAMP", "FIGHTER_COMMON", 2, 1,
  "mountain", "hiker;blackbelt;bruno", { surrogate = { MACHAMP = 36 } })
add("BELLSPROUT_LINE", "BELLSPROUT WEEPINBELL VICTREEBEL",
  "GRASS_COMMON", 2, 1, "grass", "lass;erika",
  { surrogate = { VICTREEBEL = 30 } })
add("TENTACOOL_LINE", "TENTACOOL TENTACRUEL", "WATER_JELLY;POISON", 2, 0,
  "water", "sailor;swimmer;koga")
add("GEODUDE_LINE", "GEODUDE GRAVELER GOLEM", "ROCK_COMMON", 2, 0,
  "cave;mountain", "hiker;brock", { surrogate = { GOLEM = 36 } })
add("PONYTA_LINE", "PONYTA RAPIDASH", "FIRE_COMMON", 2, 2,
  "route", "burglar;blaine")
add("SLOWPOKE_LINE", "SLOWPOKE SLOWBRO", "WATER_PSYCHIC", 2, 2,
  "water;cave", "pokemaniac;misty;sabrina", {
    postGen1 = "SLOWKING", postGen1Surrogate = { SLOWKING = 40 },
    branching = true })
add("MAGNEMITE_LINE", "MAGNEMITE MAGNETON", "ELECTRIC_COMMON;INDUSTRIAL", 2, 1,
  "power;industrial", "engineer;scientist;surge")
add("FARFETCHD_LINE", "FARFETCHD", "EARLY_BIRD;FLYING_SPECIAL", 2, 2,
  "route;rare", "birdkeeper")
add("DODUO_LINE", "DODUO DODRIO", "EARLY_BIRD;FLYING_COMMON", 2, 1,
  "route", "birdkeeper")
add("SEEL_LINE", "SEEL DEWGONG", "WATER_SHELL;ICE_WATER", 2, 2,
  "coast", "swimmer;lorelei")
add("GRIMER_LINE", "GRIMER MUK", "POISON_VERMIN;INDUSTRIAL", 2, 1,
  "urban;industrial", "biker;rocket;scientist;koga")
add("SHELLDER_LINE", "SHELLDER CLOYSTER", "WATER_SHELL;ICE_WATER", 2, 1,
  "water;coast", "fisher;misty;lorelei", { surrogate = { CLOYSTER = 30 } })
add("GASTLY_LINE", "GASTLY HAUNTER GENGAR", "GHOST", 3, 2,
  "tower", "channeler;agatha", { surrogate = { GENGAR = 36 } })
-- Appendix A accidentally omits Onix. The approved Kanto+ Steelix row requires
-- a stable parent line, so this conservative metadata row fills that gap.
add("ONIX_LINE", "ONIX", "ROCK_COMMON;GROUND_BRUISER", 3, 1,
  "cave;mountain", "hiker;brock;bruno", {
    postGen1 = "STEELIX", postGen1Surrogate = { STEELIX = 36 } })
add("DROWZEE_LINE", "DROWZEE HYPNO", "PSYCHIC_COMMON", 2, 1,
  "urban;route", "psychic;rocket;sabrina")
add("KRABBY_LINE", "KRABBY KINGLER", "WATER_SHELL", 2, 1,
  "water", "fisher;swimmer")
add("VOLTORB_LINE", "VOLTORB ELECTRODE", "ELECTRIC_COMMON;INDUSTRIAL", 2, 1,
  "power;industrial", "engineer;scientist;surge")
add("EXEGGCUTE_LINE", "EXEGGCUTE EXEGGUTOR", "GRASS_SPECIAL;PSYCHIC_SPECIAL", 3, 2,
  "grass;rare", "erika;rival;sabrina", { surrogate = { EXEGGUTOR = 30 } })
add("CUBONE_LINE", "CUBONE MAROWAK", "BURROWER_GROUND;ODDITY", 2, 2,
  "cave", "pokemaniac;rocket;giovanni")
add("HITMONLEE", "HITMONLEE", "FIGHTER_RARE", 3, 3,
  "dojo", "blackbelt;bruno")
add("HITMONCHAN", "HITMONCHAN", "FIGHTER_RARE", 3, 3,
  "dojo", "blackbelt;bruno")
add("LICKITUNG", "LICKITUNG", "NORMAL_ODDITY", 3, 3,
  "rare", "pokemaniac")
add("KOFFING_LINE", "KOFFING WEEZING", "POISON_VERMIN;INDUSTRIAL", 2, 1,
  "urban;industrial", "biker;rocket;scientist;koga")
add("RHYHORN_LINE", "RHYHORN RHYDON", "ROCK_COMMON;GROUND_BRUISER", 3, 2,
  "mountain;rare", "hiker;tamer;brock;giovanni")
add("CHANSEY_LINE", "CHANSEY", "NORMAL_SOFT_SUPPORT", 4, 4,
  "very_rare", "cooltrainer;beauty", {
    postGen1 = "BLISSEY", postGen1Surrogate = { BLISSEY = 40 } })
add("TANGELA_LINE", "TANGELA", "GRASS_SPECIAL", 3, 3,
  "grass;rare", "erika")
add("KANGASKHAN", "KANGASKHAN", "NORMAL_BRUISER", 4, 4,
  "rare", "tamer;giovanni")
add("HORSEA_LINE", "HORSEA SEADRA", "WATER_SMALL_FISH;DRAGON_ADJ", 2, 1,
  "water", "fisher;misty", {
    postGen1 = "KINGDRA", postGen1Surrogate = { KINGDRA = 40 } })
add("GOLDEEN_LINE", "GOLDEEN SEAKING", "WATER_SMALL_FISH", 2, 0,
  "water", "fisher;swimmer")
add("STARYU_LINE", "STARYU STARMIE", "WATER_PSYCHIC", 3, 2,
  "water;rare", "swimmer;misty", { surrogate = { STARMIE = 30 } })
add("MR_MIME", "MR_MIME", "PSYCHIC_SPECIAL", 3, 3,
  "rare;urban", "psychic;sabrina")
add("SCYTHER_LINE", "SCYTHER", "BUG_HUNTER;RARE_BRUISER", 4, 4,
  "rare", "bugcatcher;pokemaniac", {
    postGen1 = "SCIZOR", postGen1Surrogate = { SCIZOR = 36 } })
add("JYNX", "JYNX", "PSYCHIC_SPECIAL;ICE_WATER", 3, 3,
  "rare", "psychic;lorelei;sabrina")
add("ELECTABUZZ", "ELECTABUZZ", "ELECTRIC_RARE", 3, 3,
  "power;rare", "rocker;surge")
add("MAGMAR", "MAGMAR", "FIRE_RARE", 3, 3,
  "fire;rare", "burglar;blaine")
add("PINSIR", "PINSIR", "BUG_HUNTER;RARE_BRUISER", 4, 4,
  "rare", "bugcatcher;pokemaniac")
add("TAUROS", "TAUROS", "NORMAL_BRUISER", 4, 4,
  "rare", "tamer;cooltrainer")
add("MAGIKARP_LINE", "MAGIKARP GYARADOS", "WATER_SMALL_FISH;WATER_RARE", 1, 0,
  "water", "fisher")
add("LAPRAS", "LAPRAS", "WATER_RARE;ICE_WATER", 4, 4,
  "very_rare", "pokemaniac;lorelei;misty")
add("DITTO", "DITTO", "NORMAL_ODDITY", 3, 4,
  "rare", "pokemaniac")
add("EEVEE_LINE", "EEVEE VAPOREON JOLTEON FLAREON", "EEVEE_SPECIAL;COMPANION", 3, 4,
  "rare;urban", "rival", { genericEligible = false, branching = true,
    surrogate = { VAPOREON = 30, JOLTEON = 30, FLAREON = 30 } })
add("PORYGON_LINE", "PORYGON", "NORMAL_ODDITY;INDUSTRIAL", 4, 4,
  "artificial", "scientist;cooltrainer", {
    postGen1 = "PORYGON2", postGen1Surrogate = { PORYGON2 = 36 } })
add("OMANYTE_LINE", "OMANYTE OMASTAR", "FOSSIL;ROCK_RARE", 3, 4,
  "fossil", "brock;pokemaniac", { genericEligible = false })
add("KABUTO_LINE", "KABUTO KABUTOPS", "FOSSIL;ROCK_RARE", 3, 4,
  "fossil", "brock;pokemaniac", { genericEligible = false })
add("AERODACTYL", "AERODACTYL", "FOSSIL;ROCK_RARE;FLYING_SPECIAL", 4, 4,
  "fossil", "brock;lance", { genericEligible = false })
add("SNORLAX", "SNORLAX", "NORMAL_BRUISER", 5, 4,
  "static_rare", "", { genericEligible = false, populationModel = "STATIC_SPECIES" })
add("ARTICUNO", "ARTICUNO", "LEGENDARY_BIRD", 5, 4,
  "legendary", "lorelei", {
    genericEligible = false, populationModel = "ULTRA_RARE_SPECIES" })
add("ZAPDOS", "ZAPDOS", "LEGENDARY_BIRD", 5, 4,
  "legendary", "lance", {
    genericEligible = false, populationModel = "ULTRA_RARE_SPECIES" })
add("MOLTRES", "MOLTRES", "LEGENDARY_BIRD", 5, 4,
  "legendary", "lance", {
    genericEligible = false, populationModel = "ULTRA_RARE_SPECIES" })
add("DRATINI_LINE", "DRATINI DRAGONAIR DRAGONITE", "DRAGON", 4, 4,
  "rare", "lance", { genericEligible = false })
add("MEWTWO", "MEWTWO", "LEGENDARY_UNIQUE", 5, 4,
  "static", "", { genericEligible = false, populationModel = "UNIQUE_SPECIES" })
add("MEW", "MEW", "MYTHICAL", 5, 4,
  "mythical", "", { genericEligible = false, populationModel = "UNIQUE_SPECIES" })

local M = {}

local function copy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for key, child in pairs(value) do out[key] = copy(child) end
  return out
end

function M.build()
  local lines, bySpecies = {}, {}
  for _, source in ipairs(rows) do
    local line = copy(source)
    lines[line.lineId] = line
    for _, stage in ipairs(line.stages) do bySpecies[stage.species] = line end
  end
  return { lines = lines, bySpecies = bySpecies }
end

return M
