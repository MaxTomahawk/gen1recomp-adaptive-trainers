local M = {}

local TM_LIMIT = { [0] = 1, [1] = 1, [2] = 2, [3] = 3, [4] = 4 }

local function as_set(values)
  local out = {}
  for _, value in ipairs(values or {}) do out[value] = true end
  return out
end

local function append_unique(out, seen, id, moveDefs)
  if type(id) ~= "string" or seen[id] then return end
  if moveDefs and not moveDefs[id] then return end
  seen[id] = true
  out[#out + 1] = id
end

function M.legal_pool(speciesDef, level, moveDefs)
  speciesDef = speciesDef or {}
  level = tonumber(level) or 1
  local pool = { level = {}, tm = {} }
  local seenLevel = {}
  for _, id in ipairs(speciesDef.level1Moves or {}) do
    append_unique(pool.level, seenLevel, id, moveDefs)
  end
  for _, entry in ipairs(speciesDef.learnset or {}) do
    if (tonumber(entry.level) or math.huge) <= level then
      append_unique(pool.level, seenLevel, entry.move, moveDefs)
    end
  end
  local seenTm = {}
  for _, id in ipairs(speciesDef.tmhm or {}) do
    append_unique(pool.tm, seenTm, id, moveDefs)
  end
  return pool
end

function M.level_moves(speciesDef, level, moveDefs)
  local pool = M.legal_pool(speciesDef, level, moveDefs)
  local moves = {}
  for _, id in ipairs(pool.level) do moves[#moves + 1] = id end
  while #moves > 4 do table.remove(moves, 1) end
  return moves
end

function M.hydrate_legacy(instance, speciesDef, moveDefs)
  if instance.moves ~= nil then return instance.moves end
  instance.moves = M.level_moves(speciesDef, instance.level, moveDefs)
  return instance.moves
end

local function has_type(speciesDef, moveType)
  for _, typeId in ipairs(speciesDef and speciesDef.types or {}) do
    if typeId == moveType then return true end
  end
  return false
end

local function score(id, speciesDef, moveDefs)
  local move = moveDefs and moveDefs[id] or {}
  local power = math.max(0, tonumber(move.power) or 0)
  local value
  if power > 0 then
    value = power
    if has_type(speciesDef, move.type) then value = value + 80 end
    value = value + math.max(0, (tonumber(move.accuracy) or 100) - 75) * 0.1
  else
    value = 25
  end
  return value
end

local function candidate_rows(pool, speciesDef, moveDefs)
  local rows, seen = {}, {}
  local function add(id, source, order)
    if seen[id] then return end
    seen[id] = true
    rows[#rows + 1] = { id = id, source = source, order = order,
      score = score(id, speciesDef, moveDefs) }
  end
  for index, id in ipairs(pool.level) do add(id, "level", index) end
  for index, id in ipairs(pool.tm) do add(id, "tm", index) end
  table.sort(rows, function(left, right)
    if left.score ~= right.score then return left.score > right.score end
    if left.source ~= right.source then return left.source == "level" end
    if left.order ~= right.order then return left.order > right.order end
    return left.id < right.id
  end)
  return rows
end

local function tm_limit(tier)
  tier = math.max(0, math.min(4, math.floor(tonumber(tier) or 0)))
  return TM_LIMIT[tier]
end

function M.generate(instance, speciesDef, moveDefs, tier)
  instance = instance or {}
  local pool = M.legal_pool(speciesDef, instance.level, moveDefs)
  local rows = candidate_rows(pool, speciesDef, moveDefs)
  local selected, tmCount = {}, 0
  for _, row in ipairs(rows) do
    if #selected >= 4 then break end
    if row.source ~= "tm" or tmCount < tm_limit(tier) then
      selected[#selected + 1] = row.id
      if row.source == "tm" then tmCount = tmCount + 1 end
    end
  end
  instance.moves = selected
  return selected
end

local function redundant_slots(moves, moveDefs)
  local typeCounts, statusCount = {}, 0
  for _, id in ipairs(moves or {}) do
    local move = moveDefs and moveDefs[id] or {}
    if (tonumber(move.power) or 0) > 0 then
      local key = move.type or "__UNKNOWN_DAMAGE"
      typeCounts[key] = (typeCounts[key] or 0) + 1
    else
      statusCount = statusCount + 1
    end
  end
  local out = {}
  for index, id in ipairs(moves or {}) do
    local move = moveDefs and moveDefs[id] or {}
    if (tonumber(move.power) or 0) > 0 then
      out[index] = (typeCounts[move.type or "__UNKNOWN_DAMAGE"] or 0) > 1
    else
      out[index] = statusCount > 1
    end
  end
  return out
end

function M.refresh(instance, reason, speciesDef, moveDefs, tier)
  instance = instance or {}
  instance.moves = instance.moves or {}
  local pool = M.legal_pool(speciesDef, instance.level, moveDefs)
  local rows = candidate_rows(pool, speciesDef, moveDefs)
  local known = as_set(instance.moves)
  local tmSet = as_set(pool.tm)
  local currentTm = 0
  for _, id in ipairs(instance.moves) do
    if tmSet[id] then currentTm = currentTm + 1 end
  end
  local candidate
  for _, row in ipairs(rows) do
    if not known[row.id]
        and (row.source ~= "tm" or currentTm < tm_limit(tier)) then
      candidate = row
      break
    end
  end
  if not candidate then
    instance.lastMovesetRefreshReason = reason
    return false
  end
  if #instance.moves < 4 then
    instance.moves[#instance.moves + 1] = candidate.id
    instance.lastMovesetRefreshReason = reason
    return true
  end

  local redundant = redundant_slots(instance.moves, moveDefs)
  local replaceIndex, replaceScore
  for index, id in ipairs(instance.moves) do
    if redundant[index] or reason == "evolution" then
      local currentScore = score(id, speciesDef, moveDefs)
      if not replaceScore or currentScore < replaceScore then
        replaceIndex, replaceScore = index, currentScore
      end
    end
  end
  if not replaceIndex or candidate.score < replaceScore + 10 then
    instance.lastMovesetRefreshReason = reason
    return false
  end
  instance.moves[replaceIndex] = candidate.id
  instance.lastMovesetRefreshReason = reason
  return true
end

return M
