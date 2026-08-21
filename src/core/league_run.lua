return function(deps)
  local rng = deps.rng
  local bosses = deps.bosses
  local stage_resolver = deps.stage_resolver
  local data = deps.rosters
  local M = {}

  local MEMBER_ORDER = { "LORELEI", "BRUNO", "AGATHA", "LANCE" }
  local LEAGUE_MAPS = {
    LORELEIS_ROOM = true, BRUNOS_ROOM = true,
    AGATHAS_ROOM = true, LANCES_ROOM = true,
    CHAMPIONS_ROOM = true, HALL_OF_FAME = true,
  }

  local function copy_array(values)
    local out = {}
    for index, value in ipairs(values or {}) do out[index] = value end
    return out
  end

  local function copy_map(values)
    local out = {}
    for key, value in pairs(values or {}) do out[key] = value end
    return out
  end

  local function shuffled(values, stream)
    local out = copy_array(values)
    for index = #out, 2, -1 do
      local other = stream:integer(1, index)
      out[index], out[other] = out[other], out[index]
    end
    return out
  end

  local function append_unique(target, values)
    local seen = {}
    for _, value in ipairs(target) do seen[value] = true end
    for _, value in ipairs(values or {}) do
      if not seen[value] then
        target[#target + 1] = value
        seen[value] = true
      end
    end
  end

  local function available_choice(group, moves, stream)
    if type(group) == "table" and group.preferred then
      for _, moveId in ipairs(group.preferred) do
        if moves[moveId] then return moveId end
      end
      group = group.fallback or {}
    end
    local available = {}
    for _, moveId in ipairs(group or {}) do
      if moves[moveId] then available[#available + 1] = moveId end
    end
    if #available == 0 then return nil end
    return available[stream:integer(1, #available)]
  end

  local function selected_moves(groups, moves, stream)
    local out = {}
    for _, group in ipairs(groups or {}) do
      local moveId = available_choice(group, moves, stream)
      if moveId then append_unique(out, { moveId }) end
    end
    while #out > 4 do table.remove(out) end
    return out
  end

  local function materialize(instances)
    local party = {}
    for index, instance in ipairs(instances or {}) do
      party[index] = { species = instance.species, level = instance.level }
      if instance.moves and #instance.moves > 0 then
        party[index].moves = copy_array(instance.moves)
      end
    end
    return party
  end

  local function select_bird(stream)
    local roll = stream:integer(1, 4)
    if roll <= 2 then return { member = "LORELEI", species = "ARTICUNO" } end
    if roll == 3 then return { member = "LANCE", species = "ZAPDOS" } end
    return { member = "LANCE", species = "MOLTRES" }
  end

  function M.enter(root, context)
    root.leagueRunCounter = math.max(0,
      math.floor(tonumber(root.leagueRunCounter) or 0))
    if type(root.leagueRun) == "table" then return root.leagueRun, false end
    root.leagueRunCounter = root.leagueRunCounter + 1
    local stream = rng.stream({ hi = root.seedHi or 0, lo = root.seedLo or 0 },
      "league-run", root.leagueRunCounter)
    local run = {
      id = ("%d:%08x"):format(root.leagueRunCounter,
        stream:next_u32()),
      createdAt = tonumber(context and context.playTime) or 0,
      version = assert(context and context.version,
        "League run game version is required"),
      referenceLevels = bosses.reference_levels(
        context and context.playerParty or {}, 5),
      birdPair = select_bird(stream),
      memberSeeds = {}, generatedParties = {}, memberStrategies = {},
    }
    for _, memberId in ipairs(MEMBER_ORDER) do
      run.memberSeeds[memberId] = stream:next_u32()
    end
    root.leagueRun = run
    return run, true
  end

  function M.leave(root, reason)
    if type(root.leagueRun) ~= "table" then return false end
    root.lastLeagueExit = reason or "exit"
    root.leagueRun = nil
    root.activeLeagueMember = nil
    return true
  end

  function M.is_league_map(mapId)
    return LEAGUE_MAPS[mapId] == true
  end

  local function strategy_for(run, identity, stream, moves)
    local id = identity.strategyOrder[
      stream:integer(1, #identity.strategyOrder)]
    local source = assert(identity.strategyPackages[id])
    local strategy = { id = id,
      preferredLines = copy_array(source.preferredLines),
      techniques = copy_array(source.techniques),
      preferredMoves = copy_map(source.preferredMoves),
      preferredTypes = copy_map(source.preferredTypes),
      roleWeights = copy_map(source.roleWeights), signatureMoves = {} }
    strategy.signatureMoves = selected_moves(identity.signatureMoveGroups,
      moves, stream)
    for _, moveId in ipairs(strategy.signatureMoves) do
      strategy.preferredMoves[moveId] = true
    end
    return strategy
  end

  local function line_species(lineId, level, services)
    local line = data.line(services.meta, lineId)
    if not line then return nil end
    return stage_resolver.resolve(line, level, services.pokemon,
      data.preferred_species(lineId))
  end

  local function move_package(strategy, lineId, signature)
    local package = { id = strategy.id, techniques = {}, signatureMoves = {},
      preferredMoves = strategy.preferredMoves,
      preferredTypes = strategy.preferredTypes,
      roleWeights = strategy.roleWeights }
    if signature then
      package.signatureMoves = copy_array(strategy.signatureMoves)
      package.techniques = copy_array(strategy.signatureMoves)
      return package
    end
    for _, preferred in ipairs(strategy.preferredLines) do
      if preferred == lineId then
        package.techniques = copy_array(strategy.techniques)
        break
      end
    end
    return package
  end

  local function make_instance(run, identity, lineId, level, index, stream,
      services, strategy, team, birdSpecies)
    local species = birdSpecies or (index == 1 and identity.signatureSpecies)
      or line_species(lineId, level, services)
    assert(species and services.pokemon[species],
      ("League species %s from line %s is unavailable in the runtime registry")
        :format(tostring(species), tostring(lineId)))
    local instance = { id = birdSpecies and ("league:%s:%s")
        :format(run.id, birdSpecies) or ("league:%s:%s:%d:%08x")
        :format(run.id, identity.id, index, stream:next_u32()),
      lineId = lineId, species = species, level = level,
      roleSeed = stream:next_u32() }
    local package
    if birdSpecies then
      local bird = assert(data.birds[birdSpecies])
      local moves = selected_moves(bird.moveGroups, services.moves, stream)
      local preferredMoves = {}
      for _, moveId in ipairs(moves) do preferredMoves[moveId] = true end
      package = { id = "BIRD_" .. birdSpecies, techniques = moves,
        signatureMoves = moves, preferredMoves = preferredMoves,
        preferredTypes = {}, roleWeights = {} }
    else
      package = move_package(strategy, lineId, index == 1)
    end
    local teamContext = services.movesets.team_context(team,
      services.pokemon, services.moves)
    services.movesets.generate(instance, services.pokemon[species],
      services.moves, 4, package, teamContext)
    return instance
  end

  function M.party(root, memberId, services)
    local run = assert(root and root.leagueRun, "active League run is required")
    if run.generatedParties[memberId] then
      return materialize(run.generatedParties[memberId]),
        run.memberStrategies[memberId]
    end
    local identity = assert(data.members[memberId],
      "unknown League member " .. tostring(memberId))
    local stream = rng.from_u32(assert(run.memberSeeds[memberId]))
    local strategy = strategy_for(run, identity, stream, services.moves)
    local targets = bosses.target_levels(identity.floors,
      run.referenceLevels)
    local flex, selected = {}, {}
    for _, lineId in ipairs(shuffled(strategy.preferredLines, stream)) do
      for _, candidate in ipairs(identity.poolLines) do
        if candidate == lineId and not selected[lineId] then
          flex[#flex + 1] = lineId
          selected[lineId] = true
          break
        end
      end
    end
    for _, lineId in ipairs(shuffled(identity.poolLines, stream)) do
      if not selected[lineId] then
        flex[#flex + 1] = lineId
        selected[lineId] = true
      end
    end
    local lines = { identity.signatureLine }
    for index = 2, 5 do lines[index] = flex[index - 1] or identity.signatureLine end
    local birdSpecies = run.birdPair.member == memberId
      and run.birdPair.species or nil
    if birdSpecies then lines[5] = assert(data.birds[birdSpecies]).lineId end

    local instances = {}
    for index, lineId in ipairs(lines) do
      local assignedBird = index == 5 and birdSpecies or nil
      instances[index] = make_instance(run, identity, lineId, targets[index],
        index, stream, services, strategy, instances, assignedBird)
    end
    run.generatedParties[memberId] = instances
    run.memberStrategies[memberId] = strategy
    return materialize(instances), strategy
  end

  M.memberOrder = MEMBER_ORDER
  return M
end
