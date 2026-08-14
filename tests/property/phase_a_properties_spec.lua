local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local rng = assert(loadfile(ROOT .. "/src/core/rng.lua"))()
local player_power = assert(loadfile(ROOT .. "/src/core/player_power.lua"))()
local ecology = assert(loadfile(ROOT .. "/src/core/ecology.lua"))()
local stage_resolver = assert(loadfile(ROOT .. "/src/core/stage_resolver.lua"))()
local selector = assert(loadfile(ROOT .. "/src/core/species_selector.lua"))()({
  stage_resolver = stage_resolver,
})
local validator = assert(loadfile(ROOT .. "/src/core/team_validator.lua"))()
local standard = assert(loadfile(ROOT .. "/src/core/standard_trainers.lua"))()({
  rng = rng, player_power = player_power, ecology = ecology,
  selector = selector, validator = validator, stage_resolver = stage_resolver,
})
local meta = assert(loadfile(ROOT .. "/src/data/line_meta.lua"))().build()
local profiles = assert(loadfile(ROOT .. "/src/data/trainer_profiles.lua"))()

local checks, failures = 0, 0
local function check(condition, message)
  checks = checks + 1
  if not condition then
    failures = failures + 1
    io.stderr:write("FAIL ", message, "\n")
  end
end

local pokemon, encounterSlots = {}, {}
for _, line in pairs(meta.lines) do
  for _, stage in ipairs(line.stages) do
    pokemon[stage.species] = {
      types = { "TYPE_" .. tostring((line.powerBand % 4) + 1) },
      baseStats = {
        hp = 30 + line.powerBand * 10,
        attack = 30 + line.powerBand * 10,
        defense = 30 + line.powerBand * 10,
        speed = 30 + line.powerBand * 10,
        special = 30 + line.powerBand * 10,
      },
      evolutions = {},
    }
  end
  if line.genericEligible then
    encounterSlots[#encounterSlots + 1] = {
      species = line.stages[1].species, level = 8, weight = 1,
    }
  end
end

local data = {
  pokemon = pokemon,
  maps = { PROPERTY_ROUTE = { connections = {}, warps = {} } },
  encounters = { PROPERTY_ROUTE = { grass = { slots = encounterSlots } } },
}
local vanilla = {
  { species = "PIDGEY", level = 10 },
  { species = "RATTATA", level = 10 },
  { species = "CATERPIE", level = 10 },
  { species = "GEODUDE", level = 10 },
  { species = "TENTACOOL", level = 10 },
}
local excluded = {
  EEVEE_LINE = true, OMANYTE_LINE = true, KABUTO_LINE = true,
  AERODACTYL = true, SNORLAX = true, ARTICUNO = true, ZAPDOS = true,
  MOLTRES = true, DRATINI_LINE = true, MEWTWO = true, MEW = true,
}
local profile = profiles.byName.COOLTRAINER

for seedIndex = 1, 1000 do
  local root = { seedHi = seedIndex * 17, seedLo = seedIndex * 31,
    trainers = {} }
  local context = {
    version = "red", mapId = "PROPERTY_ROUTE",
    oppClass = "OPP_COOLTRAINER_M", partyIndex = 1,
    identityKey = "property|" .. seedIndex,
    playTime = 5000,
    playerParty = { { species = "PIDGEY", level = 20 } },
  }
  local party, state = standard.build(context, vanilla, root, {
    data = data, meta = meta, profile = profile,
  })
  check(#party == #vanilla,
    "seed " .. seedIndex .. " preserves initial party size")

  local comparison = {}
  for index, slot in ipairs(party) do
    comparison[index] = { species = vanilla[index].species, level = slot.level }
    local line = meta.bySpecies[slot.species]
    check(line ~= nil and not excluded[line.lineId],
      "seed " .. seedIndex .. " excludes special line at slot " .. index)
  end
  local valid, report = validator.validate_initial(party, comparison, {
    pokemon = pokemon, meta = meta, profile = profile,
  })
  check(valid and report.powerRatio >= .88 and report.powerRatio <= 1.12,
    "seed " .. seedIndex .. " remains inside the twelve-percent power band")

  local repeated, repeatedState = standard.build(context, vanilla, root, {
    data = data, meta = meta, profile = profile,
  })
  for index, slot in ipairs(party) do
    check(repeated[index].species == slot.species
        and repeated[index].level == slot.level,
      "seed " .. seedIndex .. " repeats slot " .. index)
    check(repeatedState.owned[index] == state.owned[index],
      "seed " .. seedIndex .. " reuses persisted individual " .. index)
  end
end

if failures > 0 then
  io.stderr:write(string.format("%d/%d Phase A property checks failed\n",
    failures, checks))
  os.exit(1)
end
print(string.format("%d/%d Phase A property checks passed", checks, checks))
