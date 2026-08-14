local M = {}

local function base_key(version, mapId, oppClass, partyIndex)
  return table.concat({
    tostring(version or "unknown"),
    tostring(mapId or "UNKNOWN_MAP"),
    tostring(oppClass or "UNKNOWN_CLASS"),
    tostring(partyIndex or 1),
  }, "|")
end

function M.standard(version, mapId, oppClass, partyIndex, npcId)
  local key = base_key(version, mapId, oppClass, partyIndex)
  if npcId ~= nil and tostring(npcId) ~= "" then
    key = key .. "|npc:" .. tostring(npcId)
  end
  return key
end

function M.from_context(version, world, oppClass, partyIndex, pending)
  local mapId = world and world.mapId or "UNKNOWN_MAP"
  local npcId
  if type(pending) == "table"
      and pending.mapId == mapId
      and pending.oppClass == oppClass
      and (pending.partyIndex or 1) == (partyIndex or 1) then
    npcId = pending.npcId
  end
  return M.standard(version, mapId, oppClass, partyIndex, npcId)
end

function M.audit(rows)
  local grouped = {}
  for _, row in ipairs(rows or {}) do
    local key = base_key(row.version, row.mapId, row.oppClass, row.partyIndex)
    local group = grouped[key]
    if not group then
      group = { key = key, seen = {}, npcIds = {} }
      grouped[key] = group
    end
    local npcId = tostring(row.npcId or "")
    if not group.seen[npcId] then
      group.seen[npcId] = true
      group.npcIds[#group.npcIds + 1] = npcId
    end
  end

  local collisions = {}
  for _, group in pairs(grouped) do
    if #group.npcIds > 1 then
      table.sort(group.npcIds)
      group.seen = nil
      collisions[#collisions + 1] = group
    end
  end
  table.sort(collisions, function(left, right) return left.key < right.key end)
  return collisions
end

return M
