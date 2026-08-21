local M = {}

-- Formal Gym rules are keyed by the complete public encounter identity.  A
-- trainer class alone is not sufficient: Giovanni reuses OPP_GIOVANNI for
-- two story battles, and mods may introduce additional encounters that share
-- a built-in class.
local GYMS = {
  OPP_BROCK = { id = "BROCK", mapId = "PEWTER_GYM" },
  OPP_MISTY = { id = "MISTY", mapId = "CERULEAN_GYM" },
  OPP_LT_SURGE = { id = "LT_SURGE", mapId = "VERMILION_GYM" },
  OPP_ERIKA = { id = "ERIKA", mapId = "CELADON_GYM" },
  OPP_KOGA = { id = "KOGA", mapId = "FUCHSIA_GYM" },
  OPP_SABRINA = { id = "SABRINA", mapId = "SAFFRON_GYM" },
  OPP_BLAINE = { id = "BLAINE", mapId = "CINNABAR_GYM" },
  OPP_GIOVANNI = { id = "GIOVANNI", mapId = "VIRIDIAN_GYM",
    partyIndex = 3 },
}

for _, row in pairs(GYMS) do row.npcId = row.mapId .. "_obj_1" end

function M.gym_class_ids()
  local out = {}
  for classId in pairs(GYMS) do out[#out + 1] = classId end
  table.sort(out)
  return out
end

function M.for_battle(context)
  context = context or {}
  local gym = GYMS[context.trainerClass]
  if gym and context.mapId == gym.mapId and context.npcId == gym.npcId
      and (context.partyIndex or 1) == (gym.partyIndex or 1) then
    return { id = gym.id, kind = "GYM_LEADER" }
  end

  -- These identities are deliberately recognized as story bosses so callers
  -- can prove that formal Gym policy is not applied to them.
  if context.trainerClass == "OPP_GIOVANNI"
      and (context.partyIndex or 1) == 1
      and context.mapId == "ROCKET_HIDEOUT_B4F"
      and context.npcId == "ROCKET_HIDEOUT_B4F_obj_1" then
    return { id = "GIOVANNI_HIDEOUT", kind = "STORY_BOSS" }
  end
  if context.trainerClass == "OPP_GIOVANNI"
      and (context.partyIndex or 1) == 2
      and context.mapId == "SILPH_CO_11F"
      and context.npcId == "SILPH_CO_11F_obj_1" then
    return { id = "GIOVANNI_SILPH", kind = "STORY_BOSS" }
  end
  return nil
end

return M
