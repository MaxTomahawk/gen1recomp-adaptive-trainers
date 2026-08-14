local M = {}

function M.build(meta)
  local byGroup = {}
  for lineId, line in pairs((meta and meta.lines) or {}) do
    for _, groupId in ipairs(line.groups or {}) do
      local ids = byGroup[groupId]
      if not ids then
        ids = {}
        byGroup[groupId] = ids
      end
      ids[#ids + 1] = lineId
    end
  end
  for _, ids in pairs(byGroup) do table.sort(ids) end
  return { byGroup = byGroup }
end

return M
