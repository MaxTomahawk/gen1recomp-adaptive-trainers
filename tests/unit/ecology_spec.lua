local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")
local ecology = assert(loadfile(ROOT .. "/src/core/ecology.lua"))()

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

local data = {
  maps = {
    START = { connections = {}, warps = {} },
    EMPTY = {
      connections = { east = { map = "NEAR" } },
      warps = { { destMap = "WATER" } },
    },
    NEAR = {
      connections = {
        west = { map = "EMPTY" }, east = { map = "FAR" },
      },
    },
    FAR = {
      connections = {
        west = { map = "NEAR" }, east = { map = "TOO_FAR" },
      },
    },
    TOO_FAR = { connections = { west = { map = "FAR" } } },
    WATER = { warps = { { destMap = "EMPTY" } } },
  },
  encounters = {
    START = { grass = { slots = { { species = "PIDGEY", level = 4 } } } },
    NEAR = { grass = { slots = { { species = "SPEAROW", level = 5 } } } },
    FAR = { grass = { slots = { { species = "RATTATA", level = 6 } } } },
    TOO_FAR = { grass = { slots = { { species = "EKANS", level = 7 } } } },
    WATER = { water = { slots = { { species = "MAGIKARP", level = 5 } } } },
  },
}

local ordinary = ecology.resolve(data, "START", {
  mobilityRadius = 2,
  encounterMethods = { grass = true },
})
local bySpecies = ecology.by_species(ordinary)
eq(bySpecies.PIDGEY.distance, 0, "current-map encounters have distance zero")
eq(bySpecies.PIDGEY.weight, 1.0, "distance zero has weight 1.0")
eq(bySpecies.SPEAROW, nil,
  "a map with usable local encounters does not expand outward")
eq(bySpecies.MAGIKARP, nil,
  "grass-only profiles exclude water encounter methods")

local fallback = ecology.resolve(data, "EMPTY", {
  mobilityRadius = 2,
  encounterMethods = { grass = true },
})
local fallbackBySpecies = ecology.by_species(fallback)
eq(fallbackBySpecies.SPEAROW.distance, 1,
  "fallback connected-map encounters have distance one")
eq(fallbackBySpecies.SPEAROW.weight, 0.55,
  "distance one has weight 0.55")
eq(fallbackBySpecies.RATTATA.distance, 2,
  "fallback two-edge encounters have distance two")
eq(fallbackBySpecies.RATTATA.weight, 0.25,
  "distance two has weight 0.25")
eq(fallbackBySpecies.EKANS, nil,
  "ordinary ecology never expands beyond radius two")

local fisher = ecology.resolve(data, "EMPTY", {
  mobilityRadius = 1,
  encounterMethods = { water = true },
})
local fisherBySpecies = ecology.by_species(fisher)
check(fisherBySpecies.MAGIKARP ~= nil,
  "water-enabled profiles can use water encounters through a warp")
eq(fisherBySpecies.PIDGEY, nil,
  "water-only profiles exclude grass encounters")

local repeated = ecology.resolve(data, "START", {
  mobilityRadius = 2,
  encounterMethods = { grass = true },
})
for index, row in ipairs(ordinary) do
  eq(repeated[index].species, row.species,
    "ecology evidence ordering repeats at row " .. index)
  eq(repeated[index].weight, row.weight,
    "ecology evidence weight repeats at row " .. index)
end

local weighted = ecology.resolve({
  constants = { encounterBuckets = { 128, 192, 256 } },
  maps = { BUCKETS = { connections = {}, warps = {} } },
  encounters = { BUCKETS = { grass = { slots = {
    { species = "COMMON", level = 3 },
    { species = "UNCOMMON", level = 4 },
    { species = "RARE", level = 5 },
  } } } },
}, "BUCKETS", { encounterMethods = { grass = true } })
local weightedBySpecies = ecology.by_species(weighted)
eq(weightedBySpecies.COMMON.weight, 0.5,
  "real cumulative encounter buckets give common slots their probability")
eq(weightedBySpecies.UNCOMMON.weight, 0.25,
  "real cumulative encounter buckets derive the second slot probability")
eq(weightedBySpecies.RARE.weight, 0.25,
  "real cumulative encounter buckets derive the tail slot probability")

local issuedData = {
  constants = { encounterBuckets = { 128, 256 } },
  maps = {
    INDOOR = { connections = {}, warps = { { destMap = "OUTSIDE" } } },
    OUTSIDE = { connections = {}, warps = {} },
  },
  encounters = { OUTSIDE = { grass = { slots = {
    { species = "RATTATA", level = 4 },
    { species = "PIDGEY", level = 4 },
  } } } },
  trainers = { OPP_ROCKET = { parties = {
    { { species = "KOFFING", level = 17 } },
    { { species = "GRIMER", level = 17 } },
  } } },
}
local issued = ecology.resolve(issuedData, "INDOOR",
  { mobilityRadius = 2, encounterMethods = { grass = true } }, {
  oppClass = "OPP_ROCKET",
  partyIndex = 1,
  override = { organizationIssued = true },
})
local issuedBySpecies = ecology.by_species(issued)
check(issuedBySpecies.KOFFING ~= nil,
  "organization ecology derives its current issued pool from the runtime registry")
eq(issuedBySpecies.GRIMER, nil,
  "an early organization encounter cannot use a later party's issued species")
eq(issuedBySpecies.RATTATA, nil,
  "organization ecology does not walk through walls to outdoor encounters")
eq(issuedBySpecies.KOFFING.sources[1].method, "issued",
  "organization candidates retain explicit issued provenance")
eq(issuedBySpecies.KOFFING.sources[1].partyIndex, 1,
  "issued provenance records its story-progression party index")

local laterIssued = ecology.resolve(issuedData, "INDOOR",
  { mobilityRadius = 2, encounterMethods = { grass = true } }, {
  oppClass = "OPP_ROCKET",
  partyIndex = 2,
  override = { organizationIssued = true },
})
local laterIssuedBySpecies = ecology.by_species(laterIssued)
check(laterIssuedBySpecies.KOFFING ~= nil and laterIssuedBySpecies.GRIMER ~= nil,
  "a later organization encounter can use current and earlier issued species")

if failures > 0 then
  io.stderr:write(string.format("%d/%d ecology checks failed\n",
    failures, checks))
  os.exit(1)
end
print(string.format("%d/%d ecology checks passed", checks, checks))
