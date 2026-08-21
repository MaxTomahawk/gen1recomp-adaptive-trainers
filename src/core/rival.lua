return function(deps)
  deps = deps or {}
  local rng = assert(deps.rng, "Rival RNG dependency is required")
  local player_power = assert(deps.player_power,
    "Rival player-power dependency is required")
  local windows = assert(deps.windows,
    "Rival window data dependency is required")
  local tuning = assert(deps.tuning or windows.tuning,
    "Rival tuning data dependency is required")
  local attachment_tuning = assert(tuning.attachment,
    "Rival tuning attachment table is required")
  local scoring_tuning = assert(tuning.scoring,
    "Rival tuning scoring table is required")
  local level_tuning = assert(tuning.levels,
    "Rival tuning levels table is required")

  local function require_number(owner, key, path, positive)
    local value = owner[key]
    assert(type(value) == "number",
      "Rival tuning " .. path .. " must be a number")
    assert(positive and value > 0 or not positive and value >= 0,
      "Rival tuning " .. path .. (positive and " must be positive"
        or " must be non-negative"))
    return value
  end
  local ai_tier = require_number(tuning, "aiTier", "aiTier")
  assert(ai_tier == math.floor(ai_tier) and ai_tier <= 4,
    "Rival tuning aiTier must be an integer from 0 through 4")
  for _, key in ipairs({ "starter", "nonStarterCap", "gainPerUse",
      "coreThreshold" }) do
    require_number(attachment_tuning, key, "attachment." .. key)
  end
  for _, key in ipairs({ "roleCoverage", "typeDiversity", "attachment",
      "trainedLevel", "canonicalAffinity", "novelty", "coreBonus" }) do
    require_number(scoring_tuning, key, "scoring." .. key)
  end
  require_number(scoring_tuning, "normalization", "scoring.normalization", true)
  for _, key in ipairs({ "benchOffset", "timeScale", "pressureCap",
      "pressureFactor", "pressureDeadZone", "canonGainCap",
      "playerLeadCap" }) do
    require_number(level_tuning, key, "levels." .. key)
  end
  for _, key in ipairs({ "secondsPerHour", "timeTauHours", "globalCap" }) do
    require_number(level_tuning, key, "levels." .. key, true)
  end
  local M = {}

  local LEGENDARY_LINES = {
    ARTICUNO = true, ZAPDOS = true, MOLTRES = true, MEWTWO = true, MEW = true,
    ARTICUNO_LINE = true, ZAPDOS_LINE = true, MOLTRES_LINE = true,
    MEWTWO_LINE = true, MEW_LINE = true,
  }

  local function copy_array(values)
    local out = {}
    for index, value in ipairs(values or {}) do out[index] = value end
    return out
  end

  local function copy_party(party)
    local out = {}
    for index, mon in ipairs(party or {}) do
      out[index] = { species = mon.species, level = mon.level }
      if mon.moves then out[index].moves = copy_array(mon.moves) end
    end
    return out
  end

  local function table_at(owner, key)
    if type(owner[key]) ~= "table" then owner[key] = {} end
    return owner[key]
  end

  local function normalize_result(result)
    if result == "loss" or result == "lost" then return "lose" end
    if result == "won" or result == "victory" then return "win" end
    return result
  end

  local function root_seed(root)
    return { hi = tonumber(root.seedHi) or 0, lo = tonumber(root.seedLo) or 0 }
  end

  local function owned_by_id(state)
    local out = {}
    for _, mon in ipairs(state.owned) do out[mon.id] = mon end
    return out
  end

  local function owned_lines(state)
    local out = {}
    for _, mon in ipairs(state.owned) do out[mon.lineId] = true end
    return out
  end

  local function find_line(state, line_id)
    for _, mon in ipairs(state.owned) do
      if mon.lineId == line_id then return mon end
    end
  end

  local function yellow_outcome(root)
    local flags = table_at(root, "yellowRival")
    local outcome
    if flags.oakResult == "lose" then
      outcome = "VAPOREON"
    elseif flags.oakResult == "win" then
      if flags.route22EarlyResult == "win" then
        outcome = "JOLTEON"
      elseif flags.route22EarlyResult == "lose"
          or flags.route22EarlyResult == "skip" then
        outcome = "FLAREON"
      end
    end
    if not outcome and (flags.eeveeOutcome == "VAPOREON"
        or flags.eeveeOutcome == "JOLTEON"
        or flags.eeveeOutcome == "FLAREON") then
      outcome = flags.eeveeOutcome
    end
    if outcome then flags.eeveeOutcome = outcome end
    return outcome
  end

  local function infer_yellow_history(root, native_starter)
    local flags = table_at(root, "yellowRival")
    local native = tonumber(native_starter)
    if not flags.oakResult then
      if native == 3 then
        flags.oakResult = "lose"
      elseif native == 1 or native == 2 then
        flags.oakResult = "win"
      end
    end
    if flags.oakResult == "win" and not flags.route22EarlyResult then
      if native == 1 then
        flags.route22EarlyResult = "win"
      elseif native == 2 then
        flags.route22EarlyResult = "skip"
      end
    end
    return yellow_outcome(root)
  end

  local function ensure_state(context, root)
    local state = table_at(root, "rival")
    table_at(root, "yellowRival")
    table_at(state, "owned")
    table_at(state, "activeIds")
    table_at(state, "attachmentById")
    table_at(state, "pathFlags")
    table_at(state, "journeyEvents")
    table_at(state, "encounterResults")
    state.encounterIndex = math.max(0,
      math.floor(tonumber(state.encounterIndex) or 0))

    local version = assert(context.version, "Rival game version is required")
    if state.version and state.version ~= version then
      error("persisted Rival game version cannot change", 2)
    end
    state.version = version
    if not state.journeySeed then
      state.journeySeed = rng.seed({ "rival-journey", root.seedHi or 0,
        root.seedLo or 0, version })
    end

    if not state.starterLine then
      state.starterLine = version == "yellow" and "EEVEE_LINE"
        or assert(context.rivalStarterLine,
          "Red/Blue Rival starter line is required on first build")
    end
    if version == "yellow" and state.starterLine ~= "EEVEE_LINE" then
      error("Yellow Rival starter must remain the Eevee line", 2)
    end

    if #state.owned == 0 then
      local anchor = windows.anchor(version, "OAK_LAB", state.starterLine)
      local stream = rng.stream(root_seed(root), "rival-starter", version,
        state.journeySeed.hi or 0, state.journeySeed.lo or 0)
      local species = context.rivalStarterSpecies or anchor.slots[1].species
      state.starterSpecies = state.starterSpecies or species
      local starter = {
        id = ("rival:%s:starter:%08x"):format(version, stream:next_u32()),
        lineId = state.starterLine,
        species = state.starterSpecies,
        level = anchor.slots[1].floor,
        acquiredAt = tonumber(context.playTime) or 0,
        originMap = "OAKS_LAB",
        useCount = 0,
        attachment = attachment_tuning.starter,
        roleSeed = stream:next_u32(),
        isStarter = true,
      }
      state.owned[1] = starter
      state.attachmentById[starter.id] = attachment_tuning.starter
    end

    local starter = find_line(state, state.starterLine)
    assert(starter, "persisted Rival state is missing its starter")
    starter.isStarter = true
    starter.attachment = attachment_tuning.starter
    starter.useCount = math.max(0, math.floor(tonumber(starter.useCount) or 0))
    state.attachmentById[starter.id] = attachment_tuning.starter
    for _, mon in ipairs(state.owned) do
      mon.useCount = math.max(0, math.floor(tonumber(mon.useCount) or 0))
      if not mon.isStarter then
        local attachment = tonumber(state.attachmentById[mon.id])
          or tonumber(mon.attachment) or 0
        mon.attachment = math.max(0,
          math.min(attachment_tuning.nonStarterCap, attachment))
        state.attachmentById[mon.id] = mon.attachment
      end
    end
    return state
  end

  local function acquisition_level(anchor, line_id)
    for _, row in ipairs(anchor.slots) do
      if row.lineId == line_id then return row.floor end
    end
    return math.max(1, anchor.canonFloor - level_tuning.benchOffset)
  end

  local function shuffled(values, stream)
    local out = copy_array(values)
    for index = #out, 2, -1 do
      local other = stream:integer(1, index)
      out[index], out[other] = out[other], out[index]
    end
    table.sort(out, function(left, right)
      local left_affinity = tonumber(left.canonicalAffinity) or 0
      local right_affinity = tonumber(right.canonicalAffinity) or 0
      if left_affinity ~= right_affinity then return left_affinity > right_affinity end
      return false
    end)
    return out
  end

  local function process_window(state, encounter_id, context, root, outcome)
    local window = windows.for_encounter(encounter_id)
    local anchor = windows.anchor(state.version, encounter_id,
      state.starterLine, outcome)
    local stream = rng.stream(root_seed(root), "rival-window", state.version,
      encounter_id, state.journeySeed.hi or 0, state.journeySeed.lo or 0)
    local budget = stream:integer(window.minAcquisitions,
      window.maxAcquisitions)
    local have = owned_lines(state)
    local candidates = {}
    for _, candidate in ipairs(windows.candidates(state.version, encounter_id,
        state.starterLine, outcome)) do
      if not have[candidate.lineId] and not LEGENDARY_LINES[candidate.lineId] then
        candidates[#candidates + 1] = candidate
      end
    end
    candidates = shuffled(candidates, stream)
    local count = math.min(budget, #candidates)
    local event = { encounterId = encounter_id,
      minBudget = window.minAcquisitions, maxBudget = window.maxAcquisitions,
      areas = copy_array(window.areas), acquiredIds = {} }
    for index = 1, count do
      local candidate = candidates[index]
      local traits = windows.traits(candidate.lineId)
      local mon = {
        id = ("rival:%s:%s:%08x"):format(state.version,
          encounter_id:lower(), stream:next_u32()),
        lineId = candidate.lineId,
        species = candidate.species,
        level = acquisition_level(anchor, candidate.lineId),
        acquiredAt = tonumber(context.playTime) or 0,
        originMap = window.areas[stream:integer(1, #window.areas)],
        useCount = 0,
        attachment = 0,
        roleSeed = stream:next_u32(),
        role = candidate.role or traits.role,
        type = candidate.type or traits.type,
      }
      state.owned[#state.owned + 1] = mon
      state.attachmentById[mon.id] = 0
      event.acquiredIds[#event.acquiredIds + 1] = mon.id
    end
    state.journeyEvents[#state.journeyEvents + 1] = event
  end

  local function prepare_instance(mon, row, target_level, services)
    local previous_level = tonumber(mon.level) or 1
    local previous_species = mon.species
    mon.level = math.max(previous_level, math.floor(target_level))

    local meta = services and services.meta
    local pokemon = services and services.pokemon
    local resolver = services and services.stage_resolver
    local line = meta and meta.lines and meta.lines[mon.lineId]
    if row and (not pokemon or pokemon[row.species]) then
      mon.species = row.species
    elseif line and resolver and pokemon then
      mon.species = resolver.resolve(line, mon.level, pokemon, mon.species)
        or mon.species
    end

    local move_builder = services and services.movesets
    local move_defs = services and services.moves
    local species_def = pokemon and pokemon[mon.species]
    if move_builder and move_defs and species_def then
      if type(mon.moves) ~= "table" then
        move_builder.generate(mon, species_def, move_defs,
          tuning.aiTier, nil, nil)
      elseif mon.species ~= previous_species then
        move_builder.refresh(mon, "evolution", species_def, move_defs,
          tuning.aiTier, nil, nil)
      elseif mon.level > previous_level then
        move_builder.refresh(mon, "level-up", species_def, move_defs,
          tuning.aiTier, nil, nil)
      else
        move_builder.hydrate_legacy(mon, species_def, move_defs)
      end
    end
  end

  local function update_owned_to_anchor(state, anchor, services)
    local by_line = {}
    for _, row in ipairs(anchor.slots) do by_line[row.lineId] = row end
    for _, mon in ipairs(state.owned) do
      local row = by_line[mon.lineId]
      local target = row and row.floor or math.max(1,
        anchor.canonFloor - level_tuning.benchOffset)
      prepare_instance(mon, row, target, services)
      if row then
        mon.role = mon.role or row.role
        mon.type = mon.type or row.type
      end
    end
  end

  local function sorted_ids(team)
    local ids = {}
    for _, mon in ipairs(team) do ids[#ids + 1] = tostring(mon.id) end
    table.sort(ids)
    return table.concat(ids, "|")
  end

  local function team_score(team, anchor)
    local roles, types, canonical = {}, {}, {}
    for _, row in ipairs(anchor.slots) do canonical[row.lineId] = true end
    local role_count, type_count, attachment, trained, affinity, novelty =
      0, 0, 0, 0, 0, 0
    local core = 0
    for _, mon in ipairs(team) do
      local traits = windows.traits(mon.lineId)
      local role = mon.role or traits.role
      local mon_type = mon.type or traits.type
      if not roles[role] then roles[role] = true; role_count = role_count + 1 end
      if not types[mon_type] then types[mon_type] = true; type_count = type_count + 1 end
      local attached = tonumber(mon.attachment) or 0
      attachment = attachment + attached / scoring_tuning.normalization
      trained = trained + math.min(level_tuning.globalCap,
        tonumber(mon.level) or 1) / scoring_tuning.normalization
      if canonical[mon.lineId] then affinity = affinity + 1 end
      if (tonumber(mon.useCount) or 0) == 0 then novelty = novelty + 1 end
      if not mon.isStarter and attached >= attachment_tuning.coreThreshold then
        core = core + 1
      end
    end
    local count = math.max(1, #team)
    return scoring_tuning.roleCoverage * role_count / count
      + scoring_tuning.typeDiversity * type_count / count
      + scoring_tuning.attachment * attachment / count
      + scoring_tuning.trainedLevel * trained / count
      + scoring_tuning.canonicalAffinity * affinity / count
      + scoring_tuning.novelty * novelty / count
      + scoring_tuning.coreBonus * core
  end

  function M.team_score(team, anchor)
    return team_score(team, anchor)
  end

  local function select_team(state, anchor)
    local starter = find_line(state, state.starterLine)
    local others = {}
    for _, mon in ipairs(state.owned) do
      if mon ~= starter then others[#others + 1] = mon end
    end
    table.sort(others, function(left, right)
      return tostring(left.id) < tostring(right.id)
    end)
    local needed = math.max(0, anchor.activeCount - 1)
    if #others <= needed then
      local team = copy_array(others)
      team[#team + 1] = starter
      return team
    end

    local best, best_score, best_key
    local chosen = {}
    local function visit(start)
      if #chosen == needed then
        local team = copy_array(chosen)
        team[#team + 1] = starter
        local score = team_score(team, anchor)
        local key = sorted_ids(team)
        if not best or score > best_score + 1e-12
            or (math.abs(score - best_score) <= 1e-12 and key < best_key) then
          best, best_score, best_key = team, score, key
        end
        return
      end
      local remaining = needed - #chosen
      for index = start, #others - remaining + 1 do
        chosen[#chosen + 1] = others[index]
        visit(index + 1)
        chosen[#chosen] = nil
      end
    end
    visit(1)
    return best
  end

  local function order_for_anchor(team, anchor, starter_line)
    local remaining, ordered = {}, {}
    for _, mon in ipairs(team) do remaining[#remaining + 1] = mon end
    local function take_line(line_id)
      for index, mon in ipairs(remaining) do
        if mon.lineId == line_id then
          table.remove(remaining, index)
          return mon
        end
      end
    end
    for index, row in ipairs(anchor.slots) do
      if row.lineId ~= starter_line then ordered[index] = take_line(row.lineId) end
    end
    for index, row in ipairs(anchor.slots) do
      if row.lineId == starter_line then ordered[index] = take_line(starter_line) end
    end
    table.sort(remaining, function(left, right)
      local left_core = (tonumber(left.attachment) or 0)
        >= attachment_tuning.coreThreshold and 1 or 0
      local right_core = (tonumber(right.attachment) or 0)
        >= attachment_tuning.coreThreshold and 1 or 0
      if left_core ~= right_core then return left_core > right_core end
      if left.level ~= right.level then return left.level > right.level end
      return tostring(left.id) < tostring(right.id)
    end)
    local cursor = 1
    for index = 1, anchor.activeCount do
      if not ordered[index] then
        ordered[index] = remaining[cursor]
        cursor = cursor + 1
      end
    end
    return ordered
  end

  local function player_reference(context)
    local source = context.playerParty or context.playerLevels or {}
    local party = {}
    for index, value in ipairs(source) do
      party[index] = { level = type(value) == "table" and value.level or value }
    end
    return player_power.reference(party)
  end

  local function encounter_top(anchor, context, state)
    local elapsed = math.max(0, (tonumber(context.playTime) or 0)
      - (tonumber(state.lastEncounterAt) or 0)) / level_tuning.secondsPerHour
    local time_momentum = math.floor(level_tuning.timeScale
      * (1 - math.exp(-elapsed / level_tuning.timeTauHours)))
    local reference = player_reference(context)
    local pressure = math.min(level_tuning.pressureCap,
      math.floor(level_tuning.pressureFactor * math.max(0,
        reference - anchor.canonFloor - level_tuning.pressureDeadZone)))
    local top = math.min(anchor.canonFloor + level_tuning.canonGainCap,
      reference + level_tuning.playerLeadCap,
      anchor.canonFloor + time_momentum + pressure)
    return math.max(anchor.canonFloor, math.floor(top)), reference
  end

  local function materialize(team, anchor, top, services)
    local party, floors = {}, {}
    for index, mon in ipairs(team) do
      local floor = anchor.slots[index].floor
      local target = math.max(floor, top + floor - anchor.canonFloor)
      local fielded_level = math.max(1,
        math.min(level_tuning.globalCap, math.floor(target)))
      prepare_instance(mon, nil, fielded_level, services)
      party[index] = { species = mon.species, level = fielded_level }
      if mon.moves and #mon.moves > 0 then
        party[index].moves = copy_array(mon.moves)
      end
      floors[index] = floor
    end
    return party, floors
  end

  function M.build(encounter_id, context, root, services)
    context, root, services = context or {}, root or {}, services or {}
    local target_index = assert(windows.index(encounter_id),
      "unknown Rival encounter " .. tostring(encounter_id))
    local state = ensure_state(context, root)
    if state.version == "yellow" and target_index >= 3 then
      infer_yellow_history(root, context.nativeRivalStarter)
    end
    if target_index < state.encounterIndex then
      error("Rival journey cannot move backwards without save rollback", 2)
    end
    if state.pending and state.pending.encounterId == encounter_id then
      return copy_party(state.pending.partyDef), state
    end

    if state.pending then
      if state.version == "yellow"
          and state.pending.encounterId == "ROUTE_22_EARLY"
          and not root.yellowRival.route22EarlyResult then
        root.yellowRival.route22EarlyResult = "skip"
        state.pathFlags.route22EarlyResult = "skip"
      end
      state.lastEncounterAt = tonumber(state.pending.playTime)
        or state.lastEncounterAt
      state.pending = nil
    end
    if state.version == "yellow" and target_index > 2
        and root.yellowRival.oakResult == "win"
        and not root.yellowRival.route22EarlyResult then
      root.yellowRival.route22EarlyResult = "skip"
      state.pathFlags.route22EarlyResult = "skip"
    end
    local outcome = state.version == "yellow" and yellow_outcome(root) or nil
    if state.version == "yellow" and target_index >= 5 and not outcome then
      error("Yellow Eevee outcome requires the recorded Oak Lab result", 2)
    end

    local start_index = math.max(2, state.encounterIndex + 1)
    for index = start_index, target_index do
      local window_id = windows.encounterOrder[index]
      process_window(state, window_id, context, root, outcome)
    end
    state.encounterIndex = math.max(state.encounterIndex, target_index)

    local anchor = windows.anchor(state.version, encounter_id,
      state.starterLine, outcome)
    update_owned_to_anchor(state, anchor, services)
    local selected = select_team(state, anchor)
    local ordered = order_for_anchor(selected, anchor, state.starterLine)
    local top, reference = encounter_top(anchor, context, state)
    local party, floors = materialize(ordered, anchor, top, services)
    state.activeIds = {}
    for index, mon in ipairs(ordered) do state.activeIds[index] = mon.id end
    state.pending = {
      encounterId = encounter_id,
      encounterIndex = target_index,
      playTime = tonumber(context.playTime) or 0,
      partyIds = copy_array(state.activeIds),
      partyDef = copy_party(party),
      encounterTop = top,
      playerReference = reference,
      slotFloors = floors,
    }
    return copy_party(party), state
  end

  function M.record_result(encounter_id, result, root)
    root = root or {}
    local state = table_at(root, "rival")
    table_at(state, "owned")
    table_at(state, "attachmentById")
    table_at(state, "pathFlags")
    table_at(state, "encounterResults")
    local normalized = normalize_result(result)
    assert(normalized == "win" or normalized == "lose" or normalized == "skip",
      "Rival result must be win, lose, or skip")

    if state.version == "yellow" then
      local flags = table_at(root, "yellowRival")
      if encounter_id == "OAK_LAB" and normalized ~= "skip" then
        flags.oakResult = normalized
        state.pathFlags.oakResult = normalized
      elseif encounter_id == "ROUTE_22_EARLY" then
        flags.route22EarlyResult = normalized
        state.pathFlags.route22EarlyResult = normalized
      end
      yellow_outcome(root)
    end

    local pending = state.pending
    if pending and pending.encounterId == encounter_id and normalized ~= "skip" then
      local by_id = owned_by_id(state)
      for _, id in ipairs(pending.partyIds or {}) do
        local mon = by_id[id]
        if mon then
          mon.useCount = (tonumber(mon.useCount) or 0) + 1
          if mon.isStarter or mon.lineId == state.starterLine then
            mon.attachment = attachment_tuning.starter
          else
            mon.attachment = math.min(attachment_tuning.nonStarterCap,
              (tonumber(mon.attachment) or 0) + attachment_tuning.gainPerUse)
          end
          state.attachmentById[id] = mon.attachment
        end
      end
      state.lastEncounterAt = pending.playTime
      state.lastResult = normalized
      state.encounterResults[encounter_id] = normalized
      state.pending = nil
    elseif normalized == "skip" then
      state.encounterResults[encounter_id] = "skip"
      if pending and pending.encounterId == encounter_id then
        state.lastEncounterAt = pending.playTime
        state.pending = nil
      end
    end
    return state
  end

  function M.yellow_outcome(root)
    return yellow_outcome(root or {})
  end

  return M
end
