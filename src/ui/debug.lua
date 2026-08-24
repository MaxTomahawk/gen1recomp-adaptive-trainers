return function(deps)
  deps = deps or {}
  local diagnostics = assert(deps.diagnostics,
    "diagnostics dependency is required")
  local ui = assert(deps.ui, "public UI dependency is required")
  local M = {}

  local VISIBLE_ROWS = 14
  local MAX_WIDTH = 19

  local function text(value)
    if value == nil then return "<unavailable>" end
    return tostring(value)
  end

  local function joined(values)
    local out = {}
    for index, value in ipairs(values or {}) do out[index] = text(value) end
    return #out > 0 and table.concat(out, ",") or "<none>"
  end

  local function sorted_keys(values)
    local out = {}
    for key in pairs(values or {}) do
      if type(key) == "string" then out[#out + 1] = key end
    end
    table.sort(out)
    return out
  end

  local function roster_row(prefix, mon)
    local moves = joined(mon and mon.moves)
    return ("%s%s L%s [%s]"):format(prefix or "",
      text(mon and mon.species), text(mon and mon.level), moves)
  end

  local function standard_rows(report)
    local rows = {
      "STANDARD",
      "identity: " .. text(report.identityKey),
      "class: " .. text(report.classId),
      "map: " .. text(report.mapId),
      "lastBattleAt: " .. text(report.lastBattleAt),
      "ceiling: " .. text(report.ceiling),
      "catch p: " .. text(report.catchProbability),
      "ecology: " .. joined(report.ecologyCandidates),
    }
    for _, mon in ipairs(report.roster or {}) do
      rows[#rows + 1] = roster_row("roster: ", mon)
    end
    local selectedMoves = {}
    for _, mon in ipairs(report.roster or {}) do
      for _, moveId in ipairs(mon.moves or {}) do selectedMoves[moveId] = true end
    end
    for moveId in pairs(report.moveScores or {}) do
      if type(moveId) == "string" then selectedMoves[moveId] = true end
    end
    for _, moveId in ipairs(sorted_keys(selectedMoves)) do
      rows[#rows + 1] = "move " .. moveId .. ": "
        .. text(report.moveScores[moveId])
    end
    return rows
  end

  local function boss_rows(report)
    local rows = {
      "BOSS",
      "boss: " .. text(report.bossId),
      "attempt: " .. text(report.attemptCounter),
      "strategy: " .. text(report.strategyId),
      "reference: " .. joined(report.referenceLevels),
      "levels: " .. joined(report.targetLevels),
      "pool: " .. joined(report.poolCandidates),
      "rejected: " .. joined(report.rejectedConstraints),
    }
    for _, mon in ipairs(report.party or {}) do
      rows[#rows + 1] = roster_row("party: ", mon)
    end
    return rows
  end

  local function rival_rows(report)
    local rows = {
      "RIVAL",
      "version: " .. text(report.version),
      "encounter: " .. text(report.encounterIndex),
      "eevee: " .. text(report.eeveeOutcome),
    }
    local owned = {}
    for _, mon in ipairs(report.owned or {}) do owned[#owned + 1] = mon end
    table.sort(owned, function(left, right)
      return tostring(left.id or "") < tostring(right.id or "")
    end)
    for _, mon in ipairs(owned) do
      rows[#rows + 1] = ("owned %s %s L%s"):format(text(mon.id),
        text(mon.species), text(mon.level))
      rows[#rows + 1] = (" from=%s at=%s att=%s use=%s"):format(
        text(mon.originMap), text(mon.acquiredAt), text(mon.attachment),
        text(mon.useCount))
    end
    for _, event in ipairs(report.journeyEvents or {}) do
      rows[#rows + 1] = ("window %s %s-%s"):format(
        text(event.encounterId), text(event.minBudget), text(event.maxBudget))
      rows[#rows + 1] = " areas: " .. joined(event.areas)
      rows[#rows + 1] = " acquired: " .. joined(event.acquiredIds)
    end
    return rows
  end

  local function league_rows(report)
    local rows = {
      "LEAGUE",
      "run: " .. text(report.runId),
      "version: " .. text(report.version),
      ("bird: %s/%s"):format(text(report.birdPair
        and report.birdPair.member), text(report.birdPair
        and report.birdPair.species)),
    }
    for _, memberId in ipairs(sorted_keys(report.memberSeeds)) do
      local entry = report.memberSeeds[memberId]
      rows[#rows + 1] = ("seed %s: %s"):format(memberId,
        text(entry and entry.value))
    end
    for _, memberId in ipairs(sorted_keys(report.generatedParties)) do
      rows[#rows + 1] = "member: " .. memberId
      for _, mon in ipairs(report.generatedParties[memberId] or {}) do
        rows[#rows + 1] = roster_row(" party: ", mon)
      end
    end
    return rows
  end

  local ROW_BUILDERS = {
    standard = standard_rows,
    boss = boss_rows,
    rival = rival_rows,
    league = league_rows,
  }

  function M.project(kind, ...)
    local projector = diagnostics[kind]
    if type(projector) ~= "function" then return nil end
    return projector(...)
  end

  function M.rows(projection)
    local builder = type(projection) == "table"
      and ROW_BUILDERS[projection.kind]
    if not builder then return {} end
    return builder(projection)
  end

  local Screen = {}
  Screen.__index = Screen
  Screen.isOpaque = true

  function Screen:max_offset()
    return math.max(0, #self.rows - VISIBLE_ROWS)
  end

  function Screen:update()
    local input = self.game and self.game.input
    if not input then return end
    if input:wasPressed("up") then
      self.offset = math.max(0, self.offset - 1)
    elseif input:wasPressed("down") then
      self.offset = math.min(self:max_offset(), self.offset + 1)
    elseif input:wasPressed("b") or input:wasPressed("start")
        or input:wasPressed("a") then
      self.game.stack:pop()
    end
  end

  local function clipped(value)
    value = tostring(value or "")
    return #value > MAX_WIDTH and value:sub(1, MAX_WIDTH) or value
  end

  function Screen:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    ui.Font.drawBox(0, 0, 20, 18)
    love.graphics.setColor(0, 0, 0, 1)
    for row = 1, VISIBLE_ROWS do
      local line = self.rows[self.offset + row]
      if line then ui.Font.draw(clipped(line), 4, (row - 1) * 9 + 4) end
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  function M.new(game, projection)
    local rows = M.rows(projection)
    local detached = {}
    for index, row in ipairs(rows) do detached[index] = tostring(row) end
    return setmetatable({
      game = game,
      rows = detached,
      offset = 0,
    }, Screen)
  end

  return M
end
