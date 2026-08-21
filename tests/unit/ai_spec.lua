local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local aiConfig = assert(loadfile(ROOT .. "/src/data/ai_tiers.lua"))()
local ai = assert(loadfile(ROOT .. "/src/core/ai.lua"))()(aiConfig)

local checks, failures = 0, 0
local function check(condition, message)
  checks = checks + 1
  if not condition then failures = failures + 1; io.stderr:write("FAIL ", message, "\n") end
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (expected " .. tostring(expected)
    .. ", got " .. tostring(actual) .. ")")
end

local registered, patched = {}, {}
local baseClasses = {
  OPP_EXPERT = { uses = 2, chance = 64, item = "X_ATTACK" },
  OPP_BOSS = { uses = 1, item = "FULL_RESTORE", hpBelow = 5 },
}
local function registry(target, verb, base)
  return {
    [verb] = function(_, id, row) target[id] = row end,
    get = function(_, id) return (target[id] or (base and base[id])) end,
  }
end
local wrapped = {}
local mod = { content = {
  ai_classes = {
    register = function(_, id, row) registered[id] = row end,
    get = function(_, id) return registered[id] or baseClasses[id] end,
  },
  trainers = registry(patched, "patch"),
}, hooks = { wrap = function(_, name, callback) wrapped[name] = callback end } }
local profiles = { byClass = {
  OPP_NOVICE = { aiTier = 0 },
  OPP_REGULAR = { aiTier = 1, rosterBehavior = "casual" },
  OPP_TRAINED = { aiTier = 2, rosterBehavior = "specialist" },
  OPP_EXPERT = { aiTier = 3, rosterBehavior = "expert" },
  OPP_BOSS = { aiTier = 4 },
} }

local bossStrategy = { id = "ANTI_GRASS",
  preferredSwitchSpecies = { AERODACTYL = true } }
ai.register(mod, profiles, function(battle)
  if battle and battle.formalBoss then
    return { profile = { aiTier = 4, rosterBehavior = "boss" },
      strategy = bossStrategy }
  end
end)

eq(table.concat(patched.OPP_NOVICE.aiMods, ","), "LAYER_1",
  "T0 uses random legal choice with the failed-status guard")
eq(table.concat(patched.OPP_REGULAR.aiMods, ","), "LAYER_1,LAYER_3",
  "T1 adds light effectiveness scoring")
eq(table.concat(patched.OPP_TRAINED.aiMods, ","),
  "LAYER_1,LAYER_2,LAYER_3",
  "T2 uses all three public vanilla scoring layers")
check(patched.OPP_EXPERT.aiMods[4] == "ADAPTIVE_T3_ROLE",
  "T3 adds the mod's stronger role-aware scoring layer")
eq(patched.OPP_EXPERT.aiClass, nil,
  "T3 preserves its runtime trainer-class item identity")
check(patched.OPP_BOSS.aiMods[5] == "ADAPTIVE_T4_STRATEGY",
  "T4 is mapped to a strategy-aware scoring layer instead of clamped to T3")

local bossBattle = { formalBoss = true, oppClass = "OPP_UNPATCHED_LEADER",
  enemyAIMods = { "LAYER_1" }, enemyIndex = 1,
  enemyParty = { { species = "ONIX", hp = 40 },
    { species = "GEODUDE", hp = 35 },
    { species = "AERODACTYL", hp = 20 } },
  enemy = { mon = { hp = 20, stats = { hp = 50 } } },
  rng = function() return 0 end }
local seenBossMods, seenBossStrategy
local bossAction = wrapped["battle.enemy_action"](function(live)
  seenBossMods = table.concat(live.enemyAIMods, ",")
  seenBossStrategy = live.adaptiveStrategy
  return { id = "ROCK_SLIDE" }
end, bossBattle)
eq(seenBossMods,
  "LAYER_1,LAYER_2,LAYER_3,ADAPTIVE_T3_ROLE,ADAPTIVE_T4_STRATEGY",
  "a formal boss receives T4 only during its action scope")
check(seenBossStrategy == bossStrategy,
  "the active structural package is visible during action scoring")
eq(bossAction.index, 3,
  "package-aware T4 switching prefers its structural answer")
check(bossBattle.enemyAIMods[1] == "LAYER_1"
    and bossBattle.adaptiveStrategy == nil,
  "formal boss AI restores the shared battle fields after selection")

eq(baseClasses.OPP_EXPERT.uses, 2,
  "expert switching leaves the runtime class item budget untouched")
eq(baseClasses.OPP_EXPERT.item, "X_ATTACK",
  "expert switching leaves the runtime class item choice untouched")
local expertBattle = { oppClass = "OPP_EXPERT", aiUses = 1,
  enemyIndex = 1, enemyParty = { { hp = 20 }, { hp = 30 } },
  enemy = { mon = { hp = 20, stats = { hp = 50 } } },
  rng = function() return 0 end }
local switched = wrapped["battle.enemy_action"](
  function() return { id = "TACKLE" } end, expertBattle)
eq(switched.special, "aiSwitch",
  "T3 replaces an ordinary move with a bounded tactical switch")
eq(switched.index, 2,
  "T3 switch selects an available non-active teammate")
eq(expertBattle.adaptiveTrainerSwitches, 1,
  "T3 switching spends the per-battle switch budget")
local bounded = wrapped["battle.enemy_action"](
  function() return { id = "TACKLE" } end, expertBattle)
eq(bounded.id, "TACKLE",
  "a tactical tier cannot exceed its per-battle switch budget")
expertBattle.rng = function() return 30 end
local itemAction = { special = "aiItem", item = "X_ATTACK" }
eq(wrapped["battle.enemy_action"](function() return itemAction end,
  expertBattle), itemAction,
  "T3 preserves a downstream runtime-class item action")

local regularBattle = { oppClass = "OPP_REGULAR", aiUses = 1,
  enemyIndex = 1, enemyParty = { { hp = 40 }, { hp = 30 } },
  enemy = { mon = { hp = 40, stats = { hp = 50 } } },
  rng = function() return 0 end }
eq(wrapped["battle.enemy_action"](function() return { id = "TACKLE" } end,
    regularBattle).special, "aiSwitch",
  "T1 may switch only through its rare deterministic chance")
regularBattle.adaptiveTrainerSwitches = nil
regularBattle.rng = function() return aiConfig.switching[1].chance end
eq(wrapped["battle.enemy_action"](function() return { id = "TACKLE" } end,
    regularBattle).id, "TACKLE",
  "T1 keeps the ordinary action outside its rare chance")

local trainedBattle = { oppClass = "OPP_TRAINED", aiUses = 1,
  enemyIndex = 1, enemyParty = { { hp = 10 }, { hp = 30 } },
  enemy = { mon = { hp = 10, stats = { hp = 50 } } },
  rng = function() return 0 end }
eq(wrapped["battle.enemy_action"](function() return { id = "TACKLE" } end,
    trainedBattle).special, "aiSwitch",
  "T2 class-appropriate trainers may switch at low HP")
trainedBattle.adaptiveTrainerSwitches = nil
trainedBattle.enemy.mon.hp = 40
eq(wrapped["battle.enemy_action"](function() return { id = "TACKLE" } end,
    trainedBattle).id, "TACKLE",
  "T2 does not switch a healthy active Pokemon")

local forcedBattle = { oppClass = "OPP_EXPERT", aiUses = 1,
  enemyIndex = 1, enemyParty = { { hp = 20 }, { hp = 30 } },
  enemy = { mon = { hp = 20, stats = { hp = 50 } } },
  rng = function() return 0 end }
local forcedAction = { special = "bide" }
eq(wrapped["battle.enemy_action"](function() return forcedAction end,
    forcedBattle), forcedAction,
  "adaptive switching never overrides a forced battle action")
eq(forcedBattle.adaptiveTrainerSwitches, nil,
  "forced actions do not consume the adaptive switch budget")

for _, field in ipairs({ "charging", "thrashMove", "rageMove" }) do
  local lockedAction = { id = "LOCKED_MOVE" }
  local lockedBattle = { oppClass = "OPP_EXPERT", enemyIndex = 1,
    enemyParty = { { hp = 20 }, { hp = 30 } },
    enemy = { mon = { hp = 20, stats = { hp = 50 } } },
    rng = function() return 0 end }
  lockedBattle.enemy[field] = lockedAction
  eq(wrapped["battle.enemy_action"](function() return lockedAction end,
      lockedBattle), lockedAction,
    field .. " continuation cannot be replaced by an adaptive switch")
  eq(lockedBattle.adaptiveTrainerSwitches, nil,
    field .. " continuation does not consume the switch budget")
end

local layer = registered.ADAPTIVE_T3_ROLE
eq(layer.kind, "layer", "expert role scoring is a public layer record")
local forbiddenSave = setmetatable({}, {
  __index = function() error("AI layer read the full player save roster") end,
})
local view = {
  user = { curTypes = { "FIRE" } },
  target = { mon = { status = nil }, curTypes = { "GRASS" } },
  battle = { game = { save = forbiddenSave } },
}
local stabScore = layer.score(view, {
  id = "FLAMETHROWER", type = "FIRE", power = 95, accuracy = 100,
  effect = "BURN_SIDE_EFFECT1",
}, 10)
local utilityScore = layer.score(view, {
  id = "SMOKESCREEN", type = "NORMAL", power = 0, accuracy = 100,
  effect = "ACCURACY_DOWN1_EFFECT",
}, 10)
check(stabScore < utilityScore,
  "expert layer prefers reliable active-mon STAB without roster scouting")

local bossLayer = registered.ADAPTIVE_T4_STRATEGY
eq(bossLayer.kind, "layer", "boss strategy scoring is a public layer record")
local strategyView = { user = { curTypes = { "FIRE" } }, battle = {
  adaptiveStrategy = { preferredMoves = { FLAMETHROWER = true } },
} }
local preferredScore = bossLayer.score(strategyView, {
    id = "FLAMETHROWER", type = "FIRE", power = 95, accuracy = 100,
  }, 10)
local unpreferredScore = bossLayer.score({ user = strategyView.user,
  battle = { adaptiveStrategy = { preferredMoves = {} } } }, {
    id = "FLAMETHROWER", type = "FIRE", power = 95, accuracy = 100,
  }, 10)
check(preferredScore < unpreferredScore,
  "T4 strategy context can prefer an identity-configured move")

if failures > 0 then
  io.stderr:write(string.format("%d/%d AI checks failed\n", failures, checks))
  os.exit(1)
end
print(string.format("%d/%d AI checks passed", checks, checks))
