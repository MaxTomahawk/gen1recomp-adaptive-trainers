return function(config)
local M = {}
config = config or {}
local expertTuning = config.expert or {}
local bossTuning = config.boss or {}
local switchingTuning = config.switching or {}

local TIER_MODS = {
  [0] = { "LAYER_1" },
  [1] = { "LAYER_1", "LAYER_3" },
  [2] = { "LAYER_1", "LAYER_2", "LAYER_3" },
  [3] = { "LAYER_1", "LAYER_2", "LAYER_3", "ADAPTIVE_T3_ROLE" },
  [4] = { "LAYER_1", "LAYER_2", "LAYER_3", "ADAPTIVE_T3_ROLE",
    "ADAPTIVE_T4_STRATEGY" },
}

local function has_type(types, wanted)
  for _, value in ipairs(types or {}) do
    if value == wanted then return true end
  end
  return false
end

local function expert_score(view, moveDef, score)
  if not moveDef then return score end
  local power = tonumber(moveDef.power) or 0
  if power > 0 then
    score = score - math.min(expertTuning.maximumPowerBonus,
      math.floor(power / expertTuning.damagePowerDivisor))
    if has_type(view and view.user and view.user.curTypes, moveDef.type) then
      score = score - expertTuning.stabBonus
    end
    if (tonumber(moveDef.accuracy) or 100)
        < expertTuning.unreliableAccuracy then
      score = score + expertTuning.unreliablePenalty
    end
  end
  return score
end

local function strategy_score(view, moveDef, score)
  local strategy = view and view.battle and view.battle.adaptiveStrategy
  if not strategy or not moveDef then return score end
  if strategy.preferredMoves and strategy.preferredMoves[moveDef.id] then
    score = score - bossTuning.preferredMoveBonus
  end
  if strategy.preferredTypes and strategy.preferredTypes[moveDef.type] then
    score = score - bossTuning.preferredTypeBonus
  end
  return score
end

local function first_backup(battle)
  for index, mon in ipairs(battle and battle.enemyParty or {}) do
    if index ~= battle.enemyIndex and (tonumber(mon.hp) or 0) > 0 then
      return index
    end
  end
end

local function tactical_switch(battle, profile, tuning)
  if not battle or not profile or not tuning then return nil end
  local backup = first_backup(battle)
  if not backup then return nil end
  local used = tonumber(battle.adaptiveTrainerSwitches) or 0
  if used >= (tonumber(tuning.maxPerBattle) or 0) then return nil end
  if tuning.rosterBehaviors
      and not tuning.rosterBehaviors[profile.rosterBehavior] then
    return nil
  end
  if tuning.hpAtMost then
    local mon = battle.enemy and battle.enemy.mon
    local maximum = mon and mon.stats and tonumber(mon.stats.hp) or 0
    local current = mon and tonumber(mon.hp) or 0
    if maximum <= 0 or current / maximum > tuning.hpAtMost then
      return nil
    end
  end
  local random = battle.rng
  if type(random) ~= "function"
      or random(0, 255) >= (tonumber(tuning.chance) or 0) then
    return nil
  end
  battle.adaptiveTrainerSwitches = used + 1
  return { special = "aiSwitch", index = backup }
end

local function is_forced_action(battle, action)
  if not action then return false end
  if action.special then return true end
  local battler = battle and battle.enemy
  return battler ~= nil and (action == battler.charging
    or action == battler.thrashMove or action == battler.rageMove)
end

function M.register(mod, profiles)
  mod.content.ai_classes:register("ADAPTIVE_T3_ROLE", {
    kind = "layer", score = expert_score,
  })
  mod.content.ai_classes:register("ADAPTIVE_T4_STRATEGY", {
    kind = "layer", score = strategy_score,
  })

  mod.hooks:wrap("battle.enemy_action", function(next, battle)
    local action = next(battle)
    if is_forced_action(battle, action) then return action end
    local id = battle and (battle.oppClass
      or (battle.trainer and battle.trainer.id))
    local profile = profiles and profiles.byClass and profiles.byClass[id]
    local tier = profile and math.max(0, math.min(4,
      math.floor(tonumber(profile.aiTier) or 0)))
    return tactical_switch(battle, profile, switchingTuning[tier]) or action
  end)

  local ids = {}
  for id in pairs(profiles and profiles.byClass or {}) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local tier = math.max(0, math.min(4,
      math.floor(tonumber(profiles.byClass[id].aiTier) or 0)))
    local patch = { aiMods = TIER_MODS[tier] }
    mod.content.trainers:patch(id, patch)
  end
end

return M
end
