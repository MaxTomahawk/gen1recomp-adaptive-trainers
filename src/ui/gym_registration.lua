return function(services)
  assert(type(services) == "table" and type(services.ui) == "table",
    "gym registration requires the public mod.ui facade")

  local ui = services.ui
  local registration = {}

  local function positive_integer(value)
    return type(value) == "number" and value >= 1
      and value == math.floor(value)
  end

  local function copy(indices)
    local out = {}
    for i, value in ipairs(indices or {}) do out[i] = value end
    return out
  end

  function registration.default_selection(party, maxCount)
    party = type(party) == "table" and party or {}
    maxCount = positive_integer(maxCount) and maxCount or 1
    local ranked = {}
    for index, mon in ipairs(party) do
      if type(mon) == "table" and (mon.hp == nil or mon.hp > 0) then
        ranked[#ranked + 1] = {
          index = index,
          level = tonumber(mon.level) or 0,
        }
      end
    end
    table.sort(ranked, function(left, right)
      if left.level ~= right.level then return left.level > right.level end
      return left.index < right.index
    end)
    local selected = {}
    for i = 1, math.min(maxCount, #ranked) do
      selected[#selected + 1] = ranked[i].index
    end
    table.sort(selected)
    return selected
  end

  function registration.validate(party, maxCount, indices)
    if type(party) ~= "table" or not positive_integer(maxCount)
        or type(indices) ~= "table" then
      return false, "invalid"
    end
    if #indices == 0 then return false, "empty" end
    if #indices > maxCount then return false, "too_many" end
    local seen = {}
    local healthy = false
    for _, index in ipairs(indices) do
      if not positive_integer(index) or index > #party
          or type(party[index]) ~= "table" then
        return false, "invalid_index"
      end
      if seen[index] then return false, "duplicate" end
      seen[index] = true
      if party[index].hp == nil or (tonumber(party[index].hp) or 0) > 0 then
        healthy = true
      end
    end
    if not healthy then return false, "no_healthy" end
    return true
  end

  local Screen = {}
  Screen.__index = Screen
  Screen.isOpaque = true

  function Screen:selected_indices()
    local out = {}
    for index = 1, #self.party do
      if self.selected[index] then out[#out + 1] = index end
    end
    return out
  end

  function Screen:toggle(index)
    if self.done or not positive_integer(index) or index > #self.party then
      return false, "invalid_index"
    end
    if self.selected[index] then
      self.selected[index] = nil
      self.message = nil
      return true
    end
    if #self:selected_indices() >= self.maxCount then
      self.message = "LIMIT " .. tostring(self.maxCount)
      return false, "full"
    end
    self.selected[index] = true
    self.message = nil
    return true
  end

  function Screen:close()
    if self.game and self.game.stack and self.game.stack:top() == self then
      self.game.stack:pop()
    end
  end

  function Screen:confirm()
    if self.done then return false, "done" end
    local indices = self:selected_indices()
    local valid, code = registration.validate(self.party, self.maxCount,
      indices)
    if not valid then
      self.message = code == "empty" and "PICK AT LEAST 1"
        or code == "no_healthy" and "PICK A HEALTHY MON" or "INVALID"
      return false, code
    end
    self.done = true
    self:close()
    if self.onConfirm then self.onConfirm(copy(indices)) end
    return true
  end

  function Screen:cancel()
    if self.done then return false end
    self.done = true
    self:close()
    if self.onCancel then self.onCancel() end
    return true
  end

  function Screen:update()
    if self.done then return end
    local input = self.game and self.game.input
    if not input or #self.party == 0 then
      if input and input:wasPressed("b") then self:cancel() end
      return
    end
    if input:wasPressed("up") then
      self.index = self.index > 1 and self.index - 1 or #self.party
    elseif input:wasPressed("down") then
      self.index = self.index < #self.party and self.index + 1 or 1
    elseif input:wasPressed("a") then
      self:toggle(self.index)
    elseif input:wasPressed("start") then
      self:confirm()
    elseif input:wasPressed("b") then
      self:cancel()
    end
  end

  local function species_name(game, mon)
    if mon.nickname and mon.nickname ~= "" then return mon.nickname end
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[mon.species]
    return def and def.name or mon.species or "POKEMON"
  end

  function Screen:draw()
    local Font = ui.Font
    Font.drawBox(0, 0, 20, 18)
    Font.draw((self.leaderId or "GYM") .. "  PICK "
      .. tostring(self.maxCount), 8, 4)
    for index, mon in ipairs(self.party) do
      local y = 18 + (index - 1) * 16
      if index == self.index and ui.Theme and ui.Theme.cursor then
        Font.drawCode(ui.Theme.cursor, 4, y + 4)
      end
      ui.PokemonIcon.draw(self.game, {
        species = mon.species,
        hp = tonumber(mon.hp) or 0,
        maxHp = tonumber(mon.maxHp)
          or (mon.stats and tonumber(mon.stats.hp))
          or math.max(1, tonumber(mon.hp) or 1),
      }, 12, y, { selected = self.selected[index] == true })
      local label = species_name(self.game, mon) .. " L"
        .. tostring(tonumber(mon.level) or 0)
      Font.draw(label, 34, y + 4)
      if self.selected[index] then Font.draw("IN", 136, y + 4) end
    end
    local count = #self:selected_indices()
    Font.draw(self.message or ("A PICK  " .. tostring(count) .. "/"
      .. tostring(self.maxCount)), 8, 120)
    Font.draw("START OK  B CANCEL", 8, 132)
  end

  function registration.choose(game, leaderId, maxCount, onConfirm, onCancel,
      party)
    party = party or (game and game.save and game.save.party) or {}
    assert(type(party) == "table", "gym registration party must be a table")
    assert(positive_integer(maxCount),
      "gym registration maximum must be a positive integer")
    local selected = {}
    for _, index in ipairs(registration.default_selection(party, maxCount)) do
      selected[index] = true
    end
    return setmetatable({
      game = game,
      leaderId = leaderId,
      maxCount = math.min(maxCount, #party),
      party = party,
      index = 1,
      selected = selected,
      onConfirm = onConfirm,
      onCancel = onCancel,
      done = false,
    }, Screen)
  end

  registration.new = function(game, opts)
    opts = opts or {}
    return registration.choose(game, opts.leaderId, opts.maxCount,
      opts.onConfirm, opts.onCancel, opts.party)
  end

  return registration
end
