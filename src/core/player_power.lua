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

return M
