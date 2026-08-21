local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local rng = assert(loadfile(ROOT .. "/src/core/rng.lua"))()
local stage_resolver = assert(loadfile(ROOT .. "/src/core/stage_resolver.lua"))()
local bosses_factory = assert(loadfile(ROOT .. "/src/core/bosses.lua"))()
local rosters = assert(loadfile(ROOT .. "/src/data/boss_rosters.lua"))()
local identities = assert(loadfile(ROOT .. "/src/data/battle_identities.lua"))()
local meta = assert(loadfile(ROOT .. "/src/data/line_meta.lua"))().build()

local checks, failures = 0, 0
local function check(condition, message)
  checks = checks + 1
  if not condition then
    failures = failures + 1
    io.stderr:write("FAIL ", message, "\n")
  end
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (expected " .. tostring(expected)
    .. ", got " .. tostring(actual) .. ")")
end
local function same(left, right)
  if type(left) ~= type(right) then return false end
  if type(left) ~= "table" then return left == right end
  for key, value in pairs(left) do
    if not same(value, right[key]) then return false end
  end
  for key in pairs(right) do
    if left[key] == nil then return false end
  end
  return true
end

local EXPECTED = {
  BROCK = { n = { red = 2, blue = 2, yellow = 2 },
    signature = "ONIX_LINE", theme = "ROCK",
    species = { red = "ONIX", blue = "ONIX", yellow = "ONIX" },
    floors = { red = { 14, 12 }, blue = { 14, 12 }, yellow = { 12, 10 } },
    strategies = { "STONEWALL", "ANTI_WATER", "ANTI_GRASS" } },
  MISTY = { n = { red = 2, blue = 2, yellow = 2 },
    signature = "STARMIE_LINE", theme = "WATER",
    species = { red = "STARMIE", blue = "STARMIE", yellow = "STARMIE" },
    floors = { red = { 21, 18 }, blue = { 21, 18 }, yellow = { 21, 18 } },
    strategies = { "RAIN_TEMPO", "FREEZE_COVERAGE", "CONTROL" } },
  LT_SURGE = { n = { red = 3, blue = 3, yellow = 1 },
    signature = "PIKACHU_LINE", theme = "ELECTRIC",
    species = { red = "RAICHU", blue = "RAICHU", yellow = "RAICHU" },
    floors = { red = { 24, 21, 18 }, blue = { 24, 21, 18 }, yellow = { 28 } },
    strategies = { "PARALYSIS_SPEED", "RAIN_THUNDER", "ANTI_GROUND" } },
  ERIKA = { n = { red = 3, blue = 3, yellow = 3 },
    signature = "ODDISH_LINE", theme = "GRASS",
    species = { red = "VILEPLUME", blue = "VILEPLUME", yellow = "GLOOM" },
    floors = { red = { 29, 29, 24 }, blue = { 29, 29, 24 },
      yellow = { 32, 32, 30 } },
    strategies = { "SLEEP_CONTROL", "SUN_SOLAR", "PSYCHIC_COVER" } },
  KOGA = { n = { red = 4, blue = 4, yellow = 4 },
    signature = { red = "KOFFING_LINE", blue = "KOFFING_LINE",
      yellow = "VENONAT_LINE" }, theme = "POISON",
    species = { red = "WEEZING", blue = "WEEZING", yellow = "VENOMOTH" },
    floors = { red = { 43, 39, 37, 37 }, blue = { 43, 39, 37, 37 },
      yellow = { 50, 48, 46, 44 } },
    strategies = { "TOXIC_ATTRITION", "EVASION_CONFUSION", "ANTI_GROUND",
      "ANTI_PSYCHIC" } },
  SABRINA = { n = { red = 4, blue = 4, yellow = 3 },
    signature = "ABRA_LINE", theme = "PSYCHIC",
    species = { red = "ALAKAZAM", blue = "ALAKAZAM", yellow = "ALAKAZAM" },
    floors = { red = { 43, 38, 38, 37 }, blue = { 43, 38, 38, 37 },
      yellow = { 50, 50, 50 } },
    strategies = { "SCREENS", "SLEEP_DREAM", "BULKY_PSYCHIC" } },
  BLAINE = { n = { red = 4, blue = 4, yellow = 3 },
    signature = "GROWLITHE_LINE", theme = "FIRE",
    species = { red = "ARCANINE", blue = "ARCANINE", yellow = "ARCANINE" },
    floors = { red = { 47, 42, 42, 40 }, blue = { 47, 42, 42, 40 },
      yellow = { 54, 50, 48 } },
    strategies = { "SUN_CORE", "SOLAR_COVERAGE",
      "FLYING_GROUND_IMMUNITY" } },
  GIOVANNI = { n = { red = 5, blue = 5, yellow = 5 },
    signature = "RHYHORN_LINE", theme = "GROUND",
    species = { red = "RHYDON", blue = "RHYDON", yellow = "RHYDON" },
    floors = { red = { 50, 45, 45, 44, 42 },
      blue = { 50, 45, 45, 44, 42 }, yellow = { 55, 55, 53, 53, 50 } },
    strategies = { "EARTHQUAKE_PRESSURE", "ELEMENTAL_NIDO", "SAND_CONTROL" } },
}

local leaderCount = 0
for id, expected in pairs(EXPECTED) do
  leaderCount = leaderCount + 1
  local row = rosters.leaders[id]
  check(type(row) == "table", id .. " has a data-defined identity")
  eq(row.typeTheme, expected.theme, id .. " keeps its specialist theme")
  for _, version in ipairs({ "red", "blue", "yellow" }) do
    eq(rosters.active_count(row, version), expected.n[version],
      id .. " has the exact " .. version .. " registration count")
    check(same(rosters.floors(row, version), expected.floors[version]),
      id .. " has signature-ranked vanilla floors in " .. version)
    local signature = type(expected.signature) == "table"
      and expected.signature[version] or expected.signature
    eq(rosters.signature_line(row, version), signature,
      id .. " has the version-correct signature in " .. version)
    eq(rosters.signature_species(row, version), expected.species[version],
      id .. " preserves its designed signature species in " .. version)
    check(rosters.line(meta, signature) ~= nil,
      id .. " signature line exists in the shared knowledge base")
  end
  check(same(row.strategyOrder, expected.strategies),
    id .. " exposes every normative strategy in stable order")
  for _, lineId in ipairs(row.flexPool) do
    check(rosters.line(meta, lineId) ~= nil,
      id .. " flex line " .. lineId .. " exists in line metadata")
  end
end
eq(leaderCount, 8, "the data contains exactly the eight Kanto Gym Leaders")
check(same(rosters.leaders.BROCK.strategyPackages.ANTI_WATER.preferredLines,
    { "RHYHORN_LINE" }),
  "Brock's anti-Water package always carries the specified Rhydon answer")
check(same(rosters.leaders.LT_SURGE.strategyPackages.ANTI_GROUND.techniques,
    { "ICE_PUNCH", "ICE_BEAM", "PSYCHIC" }),
  "Surge's structural flex gets identity-specific Ice coverage")
check(same(rosters.leaders.KOGA.strategyPackages.ANTI_GROUND.techniques,
    { "FLY", "CONFUSE_RAY", "TOXIC" }),
  "Koga's anti-Ground flex gets Flying-immunity tools, not Surge's package")

eq(identities.for_battle({ trainerClass = "OPP_BROCK", partyIndex = 1,
    mapId = "PEWTER_GYM", npcId = "PEWTER_GYM_obj_1" }).id,
  "BROCK", "Brock's canonical battle maps to the Gym identity")
eq(identities.for_battle({ trainerClass = "OPP_GIOVANNI", partyIndex = 3,
    mapId = "VIRIDIAN_GYM", npcId = "VIRIDIAN_GYM_obj_1" }).id,
  "GIOVANNI", "only Giovanni's Viridian party maps to formal Gym rules")
eq(identities.for_battle({ trainerClass = "OPP_BROCK", partyIndex = 1,
    mapId = "FIX_ROUTE", npcId = "FIX_ROUTE_obj_1" }), nil,
  "a reused leader class outside the canonical Gym is not formal")
eq(identities.for_battle({ trainerClass = "OPP_GIOVANNI", partyIndex = 1,
    mapId = "ROCKET_HIDEOUT_B4F",
    npcId = "ROCKET_HIDEOUT_B4F_obj_1" }).kind, "STORY_BOSS",
  "Giovanni's Hideout encounter remains an explicit story boss")
eq(identities.for_battle({ trainerClass = "OPP_GIOVANNI", partyIndex = 2,
    mapId = "SILPH_CO_11F", npcId = "SILPH_CO_11F_obj_1" }).kind,
  "STORY_BOSS", "Giovanni's Silph encounter remains an explicit story boss")

local bosses = bosses_factory({ rng = rng, stage_resolver = stage_resolver,
  rosters = rosters })
check(same(bosses.reference_levels({ 38, 34 }, 3), { 38, 34, 34 }),
  "top-N references repeat the lowest available level when the party is short")
check(same(bosses.reference_levels({ 38 }, 3), { 38, 38, 38 }),
  "a solo party repeats its level for every formal slot")
check(same(bosses.reference_levels({ 20, 50, 30, 40 }, 3), { 50, 40, 30 }),
  "references sort the complete party descending before registration")
check(same(bosses.target_levels({ 14, 12 }, { 10, 9 }), { 14, 12 }),
  "vanilla levels remain hard floors")
check(same(bosses.target_levels({ 14, 12 }, { 20, 18 }), { 21, 18 }),
  "signature receives R1+1 and other slots match their reference")
check(same(bosses.target_levels({ 99, 99 }, { 100, 100 }), { 100, 100 }),
  "boss targets clamp to level 100")

local pokemon = {}
for _, line in pairs(meta.lines) do
  for _, stage in ipairs(line.stages or {}) do
    pokemon[stage.species] = pokemon[stage.species] or {
      types = { "NORMAL" }, level1Moves = {}, learnset = {}, tmhm = {},
    }
  end
  for _, stage in ipairs(line.postGen1Stages or {}) do
    pokemon[stage.species] = pokemon[stage.species] or {
      types = { "NORMAL" }, level1Moves = {}, learnset = {}, tmhm = {},
    }
  end
end
for _, identity in pairs(rosters.leaders) do
  local signature = rosters.line(meta,
    rosters.signature_line(identity, "red"))
  for _, stage in ipairs(signature.stages or {}) do
    pokemon[stage.species].types = { identity.typeTheme }
  end
end
local seenPackages = {}
local fakeMovesets = {
  generate = function(instance, _, _, _, package)
    seenPackages[#seenPackages + 1] = package
    instance.moves = { package.id }
    return instance.moves
  end,
  team_context = function() return {} end,
}
local services = { meta = meta, pokemon = pokemon, moves = {},
  movesets = fakeMovesets }
local root = { seedHi = 123, seedLo = 456, bossAttempts = {} }
local brock = rosters.leaders.BROCK
local party, state = bosses.build(brock, {
  version = "red", playerLevels = { 20, 18, 16 },
}, root, services)
eq(#party, 2, "boss generation uses the version-specific active count")
eq(state.party[1].lineId, "ONIX_LINE", "signature occupies designed rank one")
eq(state.party[1].species, "ONIX", "signature species bypasses generic stage drift")
eq(party[1].level, 21, "signature applies the +1 challenge rule")
eq(party[2].level, 18, "the second boss slot matches R2 above its floor")
check(type(state.strategyId) == "string" and party[1].moves[1] == state.strategyId,
  "one structural strategy package drives the persisted attempt moves")
local preferred = {}
for _, lineId in ipairs(state.strategy.preferredLines) do preferred[lineId] = true end
check(preferred[state.party[2].lineId] == true,
  "the selected structural package contributes an actual roster answer")
local signatureMoves = {}
for _, moveId in ipairs(seenPackages[1].signatureMoves or {}) do
  signatureMoves[moveId] = true
end
check(signatureMoves.ROCK_SLIDE and signatureMoves.BIDE,
  "the signature receives its identity move baseline")
eq(#seenPackages[1].signatureMoves, 4,
  "one deterministic option is selected for each signature move slot")
check((signatureMoves.EARTHQUAKE and not signatureMoves.DIG)
    or (signatureMoves.DIG and not signatureMoves.EARTHQUAKE),
  "signature move alternatives never crowd out another required slot")
eq(#(seenPackages[2].signatureMoves or {}), 0,
  "signature-only techniques are not offered wholesale to flex members")
local rerun = bosses.build(brock, {
  version = "red", playerLevels = { 99, 1 },
}, root, services)
check(same(rerun, party),
  "reloading the same logical attempt cannot reroll or rescale the party")
eq(bosses.record_result(root, "BROCK", "win"), false,
  "a win does not open a new challenge attempt")
eq(root.bossAttempts.BROCK.attemptCounter, 0,
  "non-loss results keep the attempt counter stable")
eq(bosses.record_result(root, "BROCK", "lose"), true,
  "a real loss advances the boss attempt")
eq(root.bossAttempts.BROCK.attemptCounter, 1,
  "the attempt counter advances exactly once per recorded loss")
eq(root.bossAttempts.BROCK.party, nil,
  "a new attempt may regenerate flex slots and strategy")
local nextParty, nextState = bosses.build(brock, {
  version = "red", playerLevels = { 20, 18, 16 },
}, root, services)
eq(nextState.attemptCounter, 1, "regeneration is bound to the new attempt seed")
eq(nextState.party[1].lineId, "ONIX_LINE",
  "the signature line remains fixed across genuine lost attempts")
check(#nextParty == #party, "attempt variation never changes formal party size")

local legacyRoot = { seedHi = 123, seedLo = 456,
  bossAttempts = { BROCK = 4 } }
local _, migrated = bosses.build(brock, {
  version = "red", playerLevels = { 20, 18 },
}, legacyRoot, services)
eq(migrated.attemptCounter, 4,
  "legacy integer boss attempts migrate without losing their counter")
check(type(legacyRoot.bossAttempts.BROCK) == "table",
  "legacy attempt migration stores the structured record in mod.save")

if failures > 0 then error(failures .. " boss assertion(s) failed", 0) end
print(("bosses: %d/%d checks passed"):format(checks, checks))
