local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local rng = assert(loadfile(ROOT .. "/src/core/rng.lua"))()
local packages = assert(loadfile(ROOT .. "/src/data/move_packages.lua"))()
local movesets = assert(loadfile(ROOT .. "/src/core/movesets.lua"))()({
  rng = rng, packages = packages,
})

local checks, failures = 0, 0
local function check(condition, message)
  checks = checks + 1
  if not condition then
    failures = failures + 1
    if failures <= 20 then io.stderr:write("FAIL ", message, "\n") end
  end
end

local defs = {
  HIT = { id = "HIT", type = "NORMAL", power = 40, accuracy = 100,
    effect = "NO_ADDITIONAL_EFFECT" },
  FAST_HIT = { id = "FAST_HIT", type = "NORMAL", power = 55,
    accuracy = 95, effect = "NO_ADDITIONAL_EFFECT" },
  WATER_HIT = { id = "WATER_HIT", type = "WATER", power = 60,
    accuracy = 100, effect = "NO_ADDITIONAL_EFFECT" },
  GROWL = { id = "GROWL", type = "NORMAL", power = 0, accuracy = 100,
    effect = "ATTACK_DOWN1_EFFECT" },
  SLEEP = { id = "SLEEP", type = "GRASS", power = 0, accuracy = 75,
    effect = "SLEEP_EFFECT" },
  TM_NORMAL = { id = "TM_NORMAL", type = "NORMAL", power = 80,
    accuracy = 100, effect = "NO_ADDITIONAL_EFFECT" },
  TM_FIRE = { id = "TM_FIRE", type = "FIRE", power = 90,
    accuracy = 100, effect = "BURN_SIDE_EFFECT1" },
  TM_ICE = { id = "TM_ICE", type = "ICE", power = 95,
    accuracy = 90, effect = "FREEZE_SIDE_EFFECT" },
  TM_SETUP = { id = "TM_SETUP", type = "NORMAL", power = 0,
    accuracy = 100, effect = "ATTACK_UP2_EFFECT" },
  BOSS_TECH = { id = "BOSS_TECH", type = "DRAGON", power = 100,
    accuracy = 100, effect = "NO_ADDITIONAL_EFFECT" },
}
local species = {
  types = { "NORMAL" },
  level1Moves = { "HIT", "GROWL" },
  learnset = {
    { level = 5, move = "FAST_HIT" },
    { level = 8, move = "WATER_HIT" },
    { level = 12, move = "SLEEP" },
  },
  tmhm = { "TM_NORMAL", "TM_FIRE", "TM_ICE", "TM_SETUP" },
}
local legalPool = movesets.legal_pool(species, 20, defs)
local levelSet, tmSet = {}, {}
for _, id in ipairs(legalPool.level) do levelSet[id] = true end
for _, id in ipairs(legalPool.tm) do tmSet[id] = true end

for seed = 1, 1000 do
  for tier = 0, 4 do
    local left = { id = "property-" .. seed, species = "TESTMON",
      level = 20, roleSeed = seed }
    local right = { id = left.id, species = left.species,
      level = left.level, roleSeed = left.roleSeed }
    local moves = movesets.generate(left, species, defs, tier)
    local repeated = movesets.generate(right, species, defs, tier)
    check(#moves >= 1 and #moves <= 4,
      "move count is bounded at seed " .. seed .. " tier " .. tier)
    check(table.concat(moves, ",") == table.concat(repeated, ","),
      "same state repeats at seed " .. seed .. " tier " .. tier)
    local seen, tmCount, hasStab = {}, 0, false
    for _, id in ipairs(moves) do
      check(not seen[id], "moves are unique at seed " .. seed .. " tier " .. tier)
      seen[id] = true
      check(levelSet[id] or tmSet[id],
        "move is legal at seed " .. seed .. " tier " .. tier)
      if tmSet[id] and not levelSet[id] then tmCount = tmCount + 1 end
      local def = defs[id]
      if def and def.power > 0 and def.type == "NORMAL" then hasStab = true end
    end
    check(tmCount <= packages.tiers[tier].maxTm,
      "TM ceiling holds at seed " .. seed .. " tier " .. tier)
    check(hasStab, "available STAB is retained at seed " .. seed .. " tier " .. tier)
  end

  local boss = { id = "boss-property-" .. seed, species = "TESTMON",
    level = 20, roleSeed = seed }
  local bossMoves = movesets.generate(boss, species, defs, 4, {
    techniques = { "BOSS_TECH" }, signatureMoves = { "BOSS_TECH" },
  })
  check((function()
      for _, id in ipairs(bossMoves) do if id == "BOSS_TECH" then return true end end
      return false
    end)(), "T4 retains an explicit legal boss technique at seed " .. seed)

  local teamSpecies = { types = { "NORMAL" }, level1Moves = { "HIT" },
    tmhm = { "TM_FIRE", "TM_ICE", "WATER_HIT", "TM_NORMAL" } }
  local context = { roleCounts = {}, damageTypeCounts = { FIRE = 3 } }
  local expert = { id = "expert-property-" .. seed, species = "TESTMON",
    level = 20, roleSeed = seed }
  local expertMoves = movesets.generate(expert, teamSpecies, defs, 3, nil,
    context)
  local hasFire = false
  for _, id in ipairs(expertMoves) do if id == "TM_FIRE" then hasFire = true end end
  check(not hasFire,
    "T3 avoids redundant team coverage when alternatives exist at seed " .. seed)
end

if failures > 0 then
  io.stderr:write(string.format("%d/%d Phase C property checks failed\n",
    failures, checks))
  os.exit(1)
end
print(string.format("%d/%d Phase C property checks passed", checks, checks))
