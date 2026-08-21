package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")
local SaveSerializer = require("src.core.SaveSerializer")
local StateStack = require("src.core.StateStack")

local modPath = assert(os.getenv("ADAPTIVE_TRAINERS_PATH"),
  "ADAPTIVE_TRAINERS_PATH must name the mod relative to Gen1Recomp")
local modRoot = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")
local meta = assert(loadfile(modRoot .. "/src/data/line_meta.lua"))().build()
local windows = assert(loadfile(modRoot .. "/src/data/rival_windows.lua"))()

local function contains(values, wanted)
  for _, value in ipairs(values or {}) do
    if value == wanted then return true end
  end
  return false
end

local function species(id)
  return { id = id, name = id, types = { "NORMAL" }, baseStats = {
      hp = 60, attack = 60, defense = 60, speed = 60, special = 60,
    }, evolutions = {}, learnset = { { level = 1, move = "FIX_TACKLE" } },
    tmhm = {}, level1Moves = { "FIX_TACKLE" } }
end

local function fixture_data(version)
  local data = T.fixtures.fresh()
  for _, line in pairs(meta.lines) do
    local previous
    for _, stage in ipairs(line.stages or {}) do
      data.pokemon[stage.species] = data.pokemon[stage.species]
        or species(stage.species)
      if previous then
        previous.evolutions[#previous.evolutions + 1] = {
          method = "LEVEL", level = 20, species = stage.species,
        }
      end
      previous = data.pokemon[stage.species]
    end
  end
  data.moves.FIX_TACKLE = data.moves.FIX_TACKLE or {
    id = "FIX_TACKLE", type = "NORMAL", power = 40, accuracy = 100, pp = 35,
  }
  local starter = version == "yellow" and "EEVEE" or "SQUIRTLE"
  for _, classId in ipairs({ "OPP_RIVAL1", "OPP_RIVAL2", "OPP_RIVAL3" }) do
    data.trainers[classId] = { id = classId, name = classId,
      baseMoney = 99, aiMods = { "LAYER_1" }, parties = {} }
    for index = 1, 12 do
      data.trainers[classId].parties[index] = {
        { species = starter, level = 5 },
      }
    end
  end
  return data
end

local function save_for(version, modData)
  return { version = version, meta = { playthroughId = "rival-" .. version },
    player = { map = "OAKS_LAB", id = 7,
      name = "RED", rival = "BLUE" },
    party = {
      { species = "FIXMON_A", level = 70 },
      { species = "FIXMON_A", level = 60 },
      { species = "FIXMON_A", level = 50 },
      { species = "FIXMON_A", level = 40 },
      { species = "FIXMON_A", level = 30 },
      { species = "FIXMON_A", level = 20 },
    }, playTime = 0,
    modData = modData or { adaptive_trainers = {} },
  }
end

local function bind(run, save)
  local stack = setmetatable({ states = {} }, { __index = StateStack })
  local game = { data = run.data, save = save, stack = stack, overworld = {
    isOverworld = true, map = { id = save.player.map },
    player = { cellX = 5, cellY = 10, facing = "up" },
  } }
  run.loader.game, run.loader.modSave = game, save.modData
  Runtime.emit("game.ready", { game = game })
  return game
end

local function load_run(version, modData)
  local run = T.sdk.loadMod(modPath, { data = fixture_data(version) })
  local save = save_for(version, modData)
  local game = bind(run, save)
  return run, save, game
end

local function party_for(run, save, game, row)
  save.playTime = save.playTime + 3600
  save.player.map = row.map
  game.overworld.map.id = row.map
  return Runtime.call("trainer.party", function(_, _, party) return party end,
    row.class, row.party, run.data.trainers[row.class].parties[row.party])
end

local function finish(row, result)
  local battle = { oppClass = row.class, partyIndex = row.party,
    enemyAIMods = { "LAYER_1" } }
  Runtime.emit("battle.started", { kind = "trainer", battle = battle })
  local original = battle.enemyAIMods
  local scoped
  Runtime.call("battle.enemy_action", function(live)
    scoped = live.enemyAIMods
    return { id = "FIX_TACKLE" }
  end, battle)
  T.check(scoped and scoped[4] == "ADAPTIVE_T3_ROLE"
      and scoped[5] == nil,
    row.id .. " uses scoped T3 Rival AI without T4 boss strategy")
  T.check(battle.enemyAIMods == original,
    row.id .. " restores the vanilla class AI outside action selection")
  Runtime.emit("battle.ended", { result = result, battle = battle })
end

local RB = {
  { id = "OAK_LAB", map = "OAKS_LAB", class = "OPP_RIVAL1", parties = { 1, 2, 3 } },
  { id = "ROUTE_22_EARLY", map = "ROUTE_22", class = "OPP_RIVAL1", parties = { 4, 5, 6 } },
  { id = "CERULEAN", map = "CERULEAN_CITY", class = "OPP_RIVAL1", parties = { 7, 8, 9 } },
  { id = "SS_ANNE", map = "SS_ANNE_2F", class = "OPP_RIVAL2", parties = { 1, 2, 3 } },
  { id = "POKEMON_TOWER", map = "POKEMON_TOWER_2F", class = "OPP_RIVAL2", parties = { 4, 5, 6 } },
  { id = "SILPH_CO", map = "SILPH_CO_7F", class = "OPP_RIVAL2", parties = { 7, 8, 9 } },
  { id = "ROUTE_22_LATE", map = "ROUTE_22", class = "OPP_RIVAL2", parties = { 10, 11, 12 } },
  { id = "CHAMPION", map = "CHAMPIONS_ROOM", class = "OPP_RIVAL3", parties = { 1, 2, 3 } },
}

local YELLOW = {
  { id = "OAK_LAB", map = "OAKS_LAB", class = "OPP_RIVAL1", parties = { 1 } },
  { id = "ROUTE_22_EARLY", map = "ROUTE_22", class = "OPP_RIVAL1", parties = { 2 } },
  { id = "CERULEAN", map = "CERULEAN_CITY", class = "OPP_RIVAL1", parties = { 3 } },
  { id = "SS_ANNE", map = "SS_ANNE_2F", class = "OPP_RIVAL2", parties = { 1 } },
  { id = "POKEMON_TOWER", map = "POKEMON_TOWER_2F", class = "OPP_RIVAL2", parties = { 2, 3, 4 } },
  { id = "SILPH_CO", map = "SILPH_CO_7F", class = "OPP_RIVAL2", parties = { 5, 6, 7 } },
  { id = "ROUTE_22_LATE", map = "ROUTE_22", class = "OPP_RIVAL2", parties = { 8, 9, 10 } },
  { id = "CHAMPION", map = "CHAMPIONS_ROOM", class = "OPP_RIVAL3", parties = { 1, 2, 3 } },
}

if type(windows.for_battle) == "function" then
  for _, version in ipairs({ "red", "blue" }) do
    for _, row in ipairs(RB) do
      for _, partyIndex in ipairs(row.parties) do
        T.eq(windows.for_battle(version, row.map, row.class, partyIndex), row.id,
          version .. " maps " .. row.map .. "/" .. row.class .. "/"
            .. partyIndex .. " to " .. row.id)
      end
    end
  end
  for _, row in ipairs(YELLOW) do
    for _, partyIndex in ipairs(row.parties) do
      T.eq(windows.for_battle("yellow", row.map, row.class, partyIndex), row.id,
        "yellow maps " .. row.map .. "/" .. row.class .. "/"
          .. partyIndex .. " to " .. row.id)
    end
  end
  T.eq(windows.for_battle("red", "ROUTE_22", "OPP_RIVAL1", 1), nil,
    "a Rival class on the wrong map/party path fails closed")
else
  T.check(false, "Rival data exposes exact public battle-context mapping")
end

do
  local run, save, game = load_run("red")
  local wrong = { map = "ROUTE_22", class = "OPP_RIVAL1", party = 1 }
  local vanilla = run.data.trainers[wrong.class].parties[wrong.party]
  local party = party_for(run, save, game, wrong)
  local root = save.modData.adaptive_trainers.state
  T.eq(SaveSerializer.encode(party), SaveSerializer.encode(vanilla),
    "a wrong map/class/party Rival tuple remains vanilla")
  T.eq(#root.rival.owned, 0,
    "a wrong Rival tuple cannot advance the persistent journey")
  T.eq(next(root.trainers), nil,
    "a wrong Rival tuple cannot fall through to ordinary trainer state")
  run.release()
end

for _, version in ipairs({ "red", "blue" }) do
  local run, save, game = load_run(version)
  local expected
  for index, source in ipairs(RB) do
    local row = { id = source.id, map = source.map,
      class = source.class, party = source.parties[1] }
    local party = party_for(run, save, game, row)
    local root = save.modData.adaptive_trainers.state
    local pending = root and root.rival and root.rival.pending
    T.eq(pending and pending.encounterId, row.id,
      version .. " scripted " .. row.id .. " uses the Rival builder")
    local aiBattle = { oppClass = row.class, partyIndex = row.party,
      enemyAIMods = { "LAYER_1" }, enemyParty = {}, rng = function() return 255 end }
    local seenMods
    Runtime.call("battle.enemy_action", function(battle)
      seenMods = {}
      for _, id in ipairs(battle.enemyAIMods or {}) do seenMods[#seenMods + 1] = id end
      return { move = 1 }
    end, aiBattle)
    T.check(contains(seenMods, "ADAPTIVE_T3_ROLE")
        and not contains(seenMods, "ADAPTIVE_T4_STRATEGY"),
      version .. " " .. row.id .. " scopes exactly T3 AI to the Rival battle")
    T.same(aiBattle.enemyAIMods, { "LAYER_1" },
      version .. " " .. row.id .. " restores vanilla AI mods after scoring")
    T.eq(#party, windows.anchor(version, row.id, "SQUIRTLE_LINE").activeCount,
      version .. " " .. row.id .. " uses its canonical active count")
    for _, mon in ipairs(party) do
      T.check(mon.moves and #mon.moves > 0,
        version .. " " .. row.id .. " persists legal T3 moves")
    end
    if index == 3 and pending then
      expected = SaveSerializer.encode(party)
      local bytes = SaveSerializer.encode(save.modData)
      run.release()
      run, save, game = load_run(version, assert(SaveSerializer.decode(bytes)))
      party = party_for(run, save, game, row)
      T.eq(SaveSerializer.encode(party), expected,
        version .. " checkpoint reconstruction preserves the encounter party")
      Runtime.emit("checkpoint.restored", { kind = "battle", game = game })
    end
    finish(row, "win")
    root = save.modData.adaptive_trainers.state
    local results = root and root.rival and root.rival.encounterResults
    T.eq(results and results[row.id], "win",
      version .. " " .. row.id .. " result persists independently")
  end
  local root = save.modData.adaptive_trainers.state
  T.eq(root.activeBoss, nil, version .. " Rival path never creates Gym state")
  T.eq(root.activeLeagueMember, nil,
    version .. " Rival path never creates League member state")
  T.eq(next(root.trainers), nil,
    version .. " Rival path never creates ordinary trainer state")
  run.release()
end

local function yellow_path(oakResult, routeResult)
  local run, save, game = load_run("yellow")
  local oak = { id = "OAK_LAB", map = "OAKS_LAB",
    class = "OPP_RIVAL1", party = 1 }
  party_for(run, save, game, oak)
  finish(oak, oakResult)
  if routeResult ~= "skip" then
    local early = { id = "ROUTE_22_EARLY", map = "ROUTE_22",
      class = "OPP_RIVAL1", party = 2 }
    party_for(run, save, game, early)
    finish(early, routeResult)
  end
  local cerulean = { id = "CERULEAN", map = "CERULEAN_CITY",
    class = "OPP_RIVAL1", party = 3 }
  party_for(run, save, game, cerulean)
  finish(cerulean, "win")
  local silph = { id = "SILPH_CO", map = "SILPH_CO_7F",
    class = "OPP_RIVAL2", party = 5 }
  local party = party_for(run, save, game, silph)
  local root = save.modData.adaptive_trainers.state
  local outcome = root and root.yellowRival and root.yellowRival.eeveeOutcome
  local starter
  for _, mon in ipairs(party) do
    if mon.species == "VAPOREON" or mon.species == "JOLTEON"
        or mon.species == "FLAREON" then starter = mon.species end
  end
  run.release()
  return outcome, starter
end

local outcome, starter = yellow_path("lose", "win")
T.eq(outcome, "VAPOREON", "public Oak loss selects the Vaporeon path")
T.eq(starter, "VAPOREON", "public Oak loss fields Vaporeon")
outcome, starter = yellow_path("win", "win")
T.eq(outcome, "JOLTEON", "public double win selects the Jolteon path")
T.eq(starter, "JOLTEON", "public double win fields Jolteon")
outcome, starter = yellow_path("win", "lose")
T.eq(outcome, "FLAREON", "public Route 22 loss selects the Flareon path")
T.eq(starter, "FLAREON", "public Route 22 loss fields Flareon")
outcome, starter = yellow_path("win", "skip")
T.eq(outcome, "FLAREON", "public skipped Route 22 selects the Flareon path")
T.eq(starter, "FLAREON", "public skipped Route 22 fields Flareon")

local function yellow_mid_save(nativeStarter, expected)
  local run, save, game = load_run("yellow")
  save.rivalStarter = nativeStarter
  local silph = { id = "SILPH_CO", map = "SILPH_CO_7F",
    class = "OPP_RIVAL2", party = 4 + nativeStarter }
  local ok, party = pcall(party_for, run, save, game, silph)
  T.check(ok, "a mid-save install infers Yellow path " .. nativeStarter)
  if ok then
    local root = save.modData.adaptive_trainers.state
    T.eq(root.yellowRival.eeveeOutcome, expected,
      "native Yellow starter state migrates to " .. expected)
    local found
    for _, mon in ipairs(party) do if mon.species == expected then found = true end end
    T.check(found, "the inferred mid-save path fields " .. expected)
  end
  run.release()
end
yellow_mid_save(1, "JOLTEON")
yellow_mid_save(2, "FLAREON")
yellow_mid_save(3, "VAPOREON")

for _, nativeStarter in ipairs({ 0, "UNKNOWN" }) do
  local run, save, game = load_run("yellow")
  save.rivalStarter = nativeStarter
  local tower = { id = "POKEMON_TOWER", map = "POKEMON_TOWER_2F",
    class = "OPP_RIVAL2", party = 2 }
  local vanilla = run.data.trainers[tower.class].parties[tower.party]
  local ok, party = pcall(party_for, run, save, game, tower)
  local root = save.modData.adaptive_trainers.state
  T.check(ok, "late Yellow migration fails closed for native starter "
    .. tostring(nativeStarter))
  T.eq(ok and SaveSerializer.encode(party) or nil,
    SaveSerializer.encode(vanilla),
    "invalid native Yellow authority preserves the vanilla party "
      .. tostring(nativeStarter))
  T.eq(#root.rival.owned, 0,
    "invalid native Yellow authority cannot create owned Rival state "
      .. tostring(nativeStarter))
  T.eq(root.rival.encounterIndex, 0,
    "invalid native Yellow authority cannot advance the Rival journey "
      .. tostring(nativeStarter))
  T.eq(root.rival.pending, nil,
    "invalid native Yellow authority cannot create pending Rival state "
      .. tostring(nativeStarter))
  T.eq(root.activeRival, nil,
    "invalid native Yellow authority cannot create an active binding "
      .. tostring(nativeStarter))
  run.release()
end

do
  local run, save, game = load_run("yellow")
  local tower = { id = "POKEMON_TOWER", map = "POKEMON_TOWER_2F",
    class = "OPP_RIVAL2", party = 2 }
  local vanilla = run.data.trainers[tower.class].parties[tower.party]
  local ok, party = pcall(party_for, run, save, game, tower)
  local root = save.modData.adaptive_trainers.state
  T.check(ok, "late Yellow migration fails closed for nil native starter")
  T.eq(ok and SaveSerializer.encode(party) or nil,
    SaveSerializer.encode(vanilla),
    "nil native Yellow authority preserves the vanilla party")
  T.eq(#root.rival.owned, 0,
    "nil native Yellow authority cannot create owned Rival state")
  T.eq(root.rival.encounterIndex, 0,
    "nil native Yellow authority cannot advance the Rival journey")
  T.eq(root.rival.pending, nil,
    "nil native Yellow authority cannot create pending Rival state")
  T.eq(root.activeRival, nil,
    "nil native Yellow authority cannot create an active binding")
  run.release()
end

local staleRun, staleSave, staleGame = load_run("red")
local staleRow = { id = "OAK_LAB", map = "OAKS_LAB",
  class = "OPP_RIVAL1", party = 1 }
party_for(staleRun, staleSave, staleGame, staleRow)
local staleRoot = staleSave.modData.adaptive_trainers.state
T.check(staleRoot.activeRival ~= nil,
  "Rival preparation creates resumable active context")
local pendingBytes = SaveSerializer.encode(staleRoot.rival.pending)
staleSave.player.map = "ROUTE_22"
staleGame.overworld.map.id = "ROUTE_22"
local vanilla = staleRun.data.trainers.OPP_RIVAL1.parties[1]
local wrongMapParty = Runtime.call("trainer.party",
  function(_, _, party) return party end, "OPP_RIVAL1", 1, vanilla)
T.eq(SaveSerializer.encode(wrongMapParty), SaveSerializer.encode(vanilla),
  "same Rival class/index on the wrong live map fails closed to vanilla")
local wrongMapBattle = { oppClass = "OPP_RIVAL1", partyIndex = 1,
  enemyAIMods = { "LAYER_1" } }
Runtime.emit("battle.started", { kind = "trainer", battle = wrongMapBattle })
T.eq(staleRoot.activeRival, nil,
  "wrong-map battle start clears stale Rival context")
Runtime.emit("battle.ended", { result = "win", battle = wrongMapBattle })
T.eq(staleRoot.rival.encounterResults.OAK_LAB, nil,
  "wrong-map battle result cannot be recorded as the stale encounter")
T.check(staleRoot.rival.pending ~= nil
    and SaveSerializer.encode(staleRoot.rival.pending) == pendingBytes,
  "wrong-map failure preserves the legitimate pending journey party")
staleRun.release()

do
  local run, save, game = load_run("red")
  local oak = { id = "OAK_LAB", map = "OAKS_LAB",
    class = "OPP_RIVAL1", party = 1 }
  party_for(run, save, game, oak)
  local root = save.modData.adaptive_trainers.state
  local pendingBytes = SaveSerializer.encode(root.rival.pending)
  root.activeRival = {
    encounterId = "CERULEAN",
    version = "red",
    mapId = "ROUTE_22",
    oppClass = "OPP_RIVAL1",
    partyIndex = 1,
  }
  local bytes = SaveSerializer.encode(save.modData)
  run.release()

  run, save, game = load_run("red", assert(SaveSerializer.decode(bytes)))
  save.player.map = "ROUTE_22"
  game.overworld.map.id = "ROUTE_22"
  root = save.modData.adaptive_trainers.state
  local malformedBattle = { oppClass = "OPP_RIVAL1", partyIndex = 1,
    enemyAIMods = { "LAYER_1" }, enemyParty = {},
    rng = function() return 255 end }
  local seenMods
  Runtime.call("battle.enemy_action", function(battle)
    seenMods = {}
    for _, id in ipairs(battle.enemyAIMods or {}) do
      seenMods[#seenMods + 1] = id
    end
    return { move = 1 }
  end, malformedBattle)
  T.check(not contains(seenMods, "ADAPTIVE_T3_ROLE"),
    "a noncanonical serialized binding cannot activate Rival T3 AI")

  local vanilla = run.data.trainers.OPP_RIVAL1.parties[1]
  local party = Runtime.call("trainer.party",
    function(_, _, source) return source end,
    "OPP_RIVAL1", 1, vanilla)
  T.eq(SaveSerializer.encode(party), SaveSerializer.encode(vanilla),
    "a noncanonical serialized binding cannot reconstruct a Rival party")
  T.eq(SaveSerializer.encode(root.rival.pending), pendingBytes,
    "noncanonical reconstruction preserves the authoritative pending party")

  Runtime.emit("checkpoint.restored", { kind = "battle", game = game })
  Runtime.emit("battle.started", { kind = "trainer", battle = malformedBattle })
  T.eq(root.activeRival, nil,
    "a noncanonical serialized binding cannot activate after checkpoint")
  Runtime.emit("battle.ended", { result = "win", battle = malformedBattle })
  T.eq(root.rival.encounterResults.CERULEAN, nil,
    "a noncanonical serialized binding cannot record a wrong result")
  T.eq(root.rival.encounterResults.OAK_LAB, nil,
    "a noncanonical serialized binding cannot consume the pending result")
  T.check(root.rival.pending ~= nil
      and SaveSerializer.encode(root.rival.pending) == pendingBytes,
    "failed noncanonical result handling preserves the pending party")
  run.release()
end

T.finish("adaptive trainers Rival version paths")
