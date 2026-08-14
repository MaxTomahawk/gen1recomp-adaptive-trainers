local M = {}

local function sorted_levels(party)
  local levels = {}
  for _, mon in ipairs(party or {}) do
    local level = tonumber(mon and mon.level)
    if level then levels[#levels + 1] = level end
  end
  table.sort(levels, function(left, right) return left > right end)
  return levels
end

function M.reference(party)
  local levels = sorted_levels(party)
  if #levels == 0 then return 0 end
  if #levels == 1 then return levels[1] end
  if #levels == 2 then return 0.60 * levels[1] + 0.40 * levels[2] end
  return 0.50 * levels[1] + 0.30 * levels[2] + 0.20 * levels[3]
end

function M.top_n(party, count)
  local levels = sorted_levels(party)
  local out = {}
  if #levels == 0 then return out end
  for index = 1, count or 0 do
    out[index] = levels[index] or levels[#levels]
  end
  return out
end

function M.initial_level(vanillaLevel, vanillaTop, playerReference, profile,
    jitter)
  profile = profile or {}
  local deadZone = 4
  local gap = math.max(0, (playerReference or 0) - vanillaTop - deadZone)
  local factor = profile.initialCatchupFactor or 0
  local cap = profile.initialCap or 0
  local boost = math.min(cap, math.floor(gap * factor))
  jitter = math.max(-1, math.min(1, tonumber(jitter) or 0))
  return math.max(vanillaLevel, vanillaLevel + boost + jitter)
end

function M.badge_count(save, data)
  if type(save and save.badgeCount) == "number" then
    return math.max(0, math.floor(save.badgeCount))
  end
  local playerBadges = save and save.player and save.player.badges
  if type(playerBadges) == "table" then
    local count = 0
    for _, held in pairs(playerBadges) do
      if held == true or (type(held) == "number" and held > 0) then
        count = count + 1
      end
    end
    return count
  end
  local count = 0
  local inventory = save and save.inventory or {}
  for _, badge in ipairs(data and data.constants
      and data.constants.badges or {}) do
    local held = inventory[badge.item or badge.id]
    if held == true or (type(held) == "number" and held > 0) then
      count = count + 1
    end
  end
  return count
end

return M
