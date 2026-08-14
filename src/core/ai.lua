local M = {}

local TIER_MODS = {
  [0] = { "LAYER_1" },
  [1] = { "LAYER_1", "LAYER_3" },
  [2] = { "LAYER_1", "LAYER_2", "LAYER_3" },
  [3] = { "LAYER_1", "LAYER_2", "LAYER_3", "ADAPTIVE_T3_ROLE" },
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
    score = score - math.min(3, math.floor(power / 40))
    if has_type(view and view.user and view.user.curTypes, moveDef.type) then
      score = score - 2
    end
    if (tonumber(moveDef.accuracy) or 100) < 80 then score = score + 1 end
  end
  return score
end

function M.register(mod, profiles)
  mod.content.ai_classes:register("ADAPTIVE_T3_ROLE", {
    kind = "layer", score = expert_score,
  })
  mod.content.ai_classes:register("ADAPTIVE_T3_CLASS", {
    kind = "class",
    uses = 1,
    switchChance = 20,
    chance = 0,
  })

  local ids = {}
  for id in pairs(profiles and profiles.byClass or {}) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local tier = math.max(0, math.min(3,
      math.floor(tonumber(profiles.byClass[id].aiTier) or 0)))
    local patch = { aiMods = TIER_MODS[tier] }
    if tier == 3 then patch.aiClass = "ADAPTIVE_T3_CLASS" end
    mod.content.trainers:patch(id, patch)
  end
end

return M
