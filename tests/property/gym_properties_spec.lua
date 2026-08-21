local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local rng = assert(loadfile(ROOT .. "/src/core/rng.lua"))()
local stage_resolver = assert(loadfile(ROOT .. "/src/core/stage_resolver.lua"))()
local rosters = assert(loadfile(ROOT .. "/src/data/boss_rosters.lua"))()
local bosses = assert(loadfile(ROOT .. "/src/core/bosses.lua"))()({
  rng = rng, stage_resolver = stage_resolver, rosters = rosters,
})
local meta = assert(loadfile(ROOT .. "/src/data/line_meta.lua"))().build()

local checks, failures = 0, 0
local function check(condition, message)
  checks = checks + 1
  if not condition then
    failures = failures + 1
    if failures <= 10 then io.stderr:write("FAIL ", message, "\n") end
  end
end
local function same(left, right)
  if type(left) ~= type(right) then return false end
  if type(left) ~= "table" then return left == right end
  for key, value in pairs(left) do
    if not same(value, right[key]) then return false end
  end
  for key in pairs(right) do if left[key] == nil then return false end end
  return true
end

local pokemon = {}
for _, line in pairs(meta.lines) do
  for _, stage in ipairs(line.stages or {}) do
    pokemon[stage.species] = pokemon[stage.species] or {
      types = { "NORMAL" }, level1Moves = {}, learnset = {}, tmhm = {},
    }
  end
end
for _, identity in pairs(rosters.leaders) do
  for _, version in ipairs({ "red", "blue", "yellow" }) do
    local line = rosters.line(meta,
      rosters.signature_line(identity, version))
    for _, stage in ipairs(line.stages or {}) do
      pokemon[stage.species].types = { identity.typeTheme }
    end
  end
end
local movesets = {
  generate = function(instance, _, _, _, package)
    instance.moves = { package.id }
    return instance.moves
  end,
  team_context = function() return {} end,
}
local services = { meta = meta, pokemon = pokemon, moves = {},
  movesets = movesets }

for leaderId, identity in pairs(rosters.leaders) do
  for _, version in ipairs({ "red", "blue", "yellow" }) do
    local n = rosters.active_count(identity, version)
    local floors = rosters.floors(identity, version)
    for sample = 1, 250 do
      local levels = { 1 + sample % 100, 1 + sample * 7 % 100,
        1 + sample * 13 % 100, 1 + sample * 17 % 100,
        1 + sample * 23 % 100, 1 + sample * 29 % 100 }
      local rootA = { seedHi = sample * 7919, seedLo = sample * 104729,
        bossAttempts = {} }
      local rootB = { seedHi = rootA.seedHi, seedLo = rootA.seedLo,
        bossAttempts = {} }
      local partyA, stateA = bosses.build(identity, {
        version = version, playerLevels = levels,
        playerSpecies = { "MEWTWO", "ARTICUNO" },
        playerMoves = { "SURF", "THUNDERBOLT" },
      }, rootA, services)
      local partyB, stateB = bosses.build(identity, {
        version = version, playerLevels = levels,
        playerSpecies = { "MAGIKARP" }, playerMoves = { "SPLASH" },
      }, rootB, services)
      check(#partyA == n, leaderId .. " always builds exact N")
      check(#stateA.party == n, leaderId .. " persists every active slot")
      check(stateA.party[1].lineId == rosters.signature_line(identity, version),
        leaderId .. " signature is rank one")
      check(stateA.party[1].species == rosters.signature_species(identity, version),
        leaderId .. " signature species is version-correct at every floor")
      if n > 1 then
        local preferred = {}
        for _, lineId in ipairs(stateA.strategy.preferredLines or {}) do
          preferred[lineId] = true
        end
        check(preferred[stateA.party[2].lineId] == true,
          leaderId .. " package selects a named structural answer")
      end
      check(same(partyA, partyB) and same(stateA.party, stateB.party),
        leaderId .. " generation ignores player species and moves")
      local refs = bosses.reference_levels(levels, n)
      local targets = bosses.target_levels(floors, refs)
      for slot = 1, n do
        check(partyA[slot].level == targets[slot],
          leaderId .. " slot level follows the formal formula")
        check(partyA[slot].level >= floors[slot]
            and partyA[slot].level >= 1 and partyA[slot].level <= 100,
          leaderId .. " respects floor and global level bounds")
      end
      local score = bosses.identity_score(stateA.party, identity, pokemon)
      check(score.signatureThemed == true,
        leaderId .. " signature remains specialist-themed")
      check(score.themed >= math.ceil(n / 2),
        leaderId .. " active team meets the minimum identity score")
    end
  end
end

if failures > 0 then error(failures .. " gym property assertion(s) failed", 0) end
print(("gym properties: %d/%d checks passed"):format(checks, checks))
