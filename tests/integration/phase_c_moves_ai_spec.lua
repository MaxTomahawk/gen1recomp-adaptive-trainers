package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")
local SaveSerializer = require("src.core.SaveSerializer")
local TrainerAI = require("src.battle.TrainerAI")
local TypeChart = require("src.battle.TypeChart")

local modPath = assert(os.getenv("ADAPTIVE_TRAINERS_PATH"),
  "ADAPTIVE_TRAINERS_PATH must name the mod relative to Gen1Recomp")

local function species(id, types, level1Moves, learnset, evolutions)
  return { id = id, types = types, baseStats = {
      hp = 45, attack = 40, defense = 40, speed = 45, special = 45,
    }, evolutions = evolutions or {}, learnset = learnset or {}, tmhm = {
      "FIX_CUT",
    }, level1Moves = level1Moves or {} }
end

local function fixture_data()
  local data = T.fixtures.fresh()
  data.pokemon.CATERPIE = species("CATERPIE", { "BUG" },
    { "FIX_TACKLE" }, {}, {
      { method = "LEVEL", level = 7, species = "METAPOD" },
    })
  data.pokemon.METAPOD = species("METAPOD", { "BUG" },
    { "FIX_TACKLE" }, {}, {
      { method = "LEVEL", level = 10, species = "BUTTERFREE" },
    })
  data.pokemon.BUTTERFREE = species("BUTTERFREE", { "FIRE" },
    { "FIX_SCRATCH" }, {
      { level = 10, move = "FIX_EMBERISH" },
    })
  data.pokemon.PIDGEY = species("PIDGEY", { "NORMAL" },
    { "FIX_TACKLE" })
  data.encounters.FIX_ROUTE = { grass = { slots = {
    { level = 8, species = "CATERPIE" },
  } } }
  data.trainers.OPP_BUG_CATCHER = {
    id = "OPP_BUG_CATCHER", name = "BUG CATCHER", baseMoney = 10,
    parties = { { { species = "CATERPIE", level = 8 } } },
  }
  data.trainers.OPP_COOLTRAINER_M = {
    id = "OPP_COOLTRAINER_M", name = "COOLTRAINER", baseMoney = 35,
    parties = { { { species = "PIDGEY", level = 20 } } },
  }
  data.trainers.OPP_HIKER = { id = "OPP_HIKER", name = "HIKER",
    baseMoney = 10, parties = { { { species = "PIDGEY", level = 15 } } } }
  data.trainers.OPP_SCIENTIST = { id = "OPP_SCIENTIST", name = "SCIENTIST",
    baseMoney = 20, parties = { { { species = "PIDGEY", level = 20 } } } }
  data.maps.FIX_ROUTE.objects = {
    { index = 1, name = "FIX_BUG", trainerClass = "OPP_BUG_CATCHER",
      trainerParty = 1 },
  }
  return data
end

local function save_for(modData, version)
  version = version or "red"
  return { version = version, badgeCount = 1,
    meta = { playthroughId = "phase-c-" .. version },
    player = { map = "FIX_ROUTE", id = 3, name = "RED", rival = "BLUE" },
    party = { { species = "PIDGEY", level = 20 },
      { species = "PIDGEY", level = 18 },
      { species = "PIDGEY", level = 16 } },
    playTime = 1000,
    modData = modData or { adaptive_trainers = {} },
  }
end

local function game_for(run, save)
  return { data = run.data, save = save, overworld = {
    isOverworld = true, map = { id = "FIX_ROUTE" },
    player = { cellX = 2, cellY = 2, facing = "up" },
  } }
end

local function engage(game)
  Runtime.emit("world.trainer_engaged", {
    npc = { id = "FIX_BUG", def = { index = 1 } },
    trainerClass = "OPP_BUG_CATCHER", partyIndex = 1,
  })
  return Runtime.call("trainer.party", function(_, _, party) return party end,
    "OPP_BUG_CATCHER", 1,
    game.data.trainers.OPP_BUG_CATCHER.parties[1])
end

local function finish(result)
  local battle = { oppClass = "OPP_BUG_CATCHER", partyIndex = 1 }
  Runtime.emit("battle.started", { kind = "trainer", battle = battle })
  Runtime.emit("battle.ended", { result = result, battle = battle })
end

local run = T.sdk.loadMod(modPath, { data = fixture_data() })
TypeChart.load(run.data)
local save = save_for()
local game = game_for(run, save)
run.loader.game, run.loader.modSave = game, save.modData
Runtime.emit("game.ready", { game = game })

T.eq(table.concat(run.data.trainers.OPP_BUG_CATCHER.aiMods, ","), "LAYER_1",
  "T0 class AI is registered through the public trainer registry")
T.eq(run.data.trainers.OPP_COOLTRAINER_M.aiClass, nil,
  "expert class retains its runtime class item identity")
T.check(run.data.ai_classes.ADAPTIVE_T3_ROLE ~= nil,
  "expert scoring layer exists in the merged public AI registry")

local expertBattle = {
  kind = "trainer", data = run.data,
  trainer = run.data.trainers.OPP_COOLTRAINER_M,
  enemyIndex = 1, aiUses = 1,
  enemy = { mon = { hp = 20, stats = { hp = 50 } } },
  enemyParty = { { hp = 20 }, { hp = 30 } },
  rng = function() return 0 end,
}
local switch = Runtime.call("battle.enemy_action",
  function() return { id = "FIX_TACKLE" } end, expertBattle)
T.eq(switch and switch.special, "aiSwitch",
  "merged T3 class can make a bounded tactical switch")
T.eq(switch and switch.index, 2,
  "expert switching selects an available backup through vanilla AI semantics")
expertBattle.rng = function() return 30 end
local item = TrainerAI.classAction(expertBattle)
T.eq(item and item.special, "aiItem",
  "expert class retains its limited vanilla-class item behavior")
T.eq(item and item.item, "X_ATTACK",
  "expert item behavior comes from the runtime class registry")

local function tier_battle(classId, hp, roll)
  return { kind = "trainer", data = run.data,
    trainer = run.data.trainers[classId], enemyIndex = 1,
    enemy = { mon = { hp = hp, stats = { hp = 100 } } },
    enemyParty = { { hp = hp }, { hp = 100 } },
    rng = function() return roll end }
end
local function fallback() return { id = "FIX_TACKLE" } end
T.eq(Runtime.call("battle.enemy_action", function()
    return { special = "bide" }
  end, tier_battle("OPP_SCIENTIST", 20, 0)).special, "bide",
  "public adaptive switching preserves forced vanilla battle actions")
local lockedMove = { id = "FIX_EMBERISH" }
local lockedBattle = tier_battle("OPP_SCIENTIST", 20, 0)
lockedBattle.enemy.charging = lockedMove
T.eq(Runtime.call("battle.enemy_action", function() return lockedMove end,
    lockedBattle), lockedMove,
  "public adaptive switching preserves ordinary-shaped charge continuations")
T.eq(Runtime.call("battle.enemy_action", fallback,
    tier_battle("OPP_HIKER", 100, 0)).special, "aiSwitch",
  "merged T1 behavior permits a rare tactical switch")
T.eq(Runtime.call("battle.enemy_action", fallback,
    tier_battle("OPP_HIKER", 100, 255)).id, "FIX_TACKLE",
  "merged T1 behavior normally delegates to vanilla AI")
T.eq(Runtime.call("battle.enemy_action", fallback,
    tier_battle("OPP_SCIENTIST", 20, 0)).special, "aiSwitch",
  "merged class-appropriate T2 behavior switches under clear pressure")
T.eq(Runtime.call("battle.enemy_action", fallback,
    tier_battle("OPP_SCIENTIST", 80, 0)).id, "FIX_TACKLE",
  "merged T2 behavior preserves vanilla AI outside clear pressure")

local choiceBattle = {
  data = run.data,
  enemyAIMods = run.data.trainers.OPP_COOLTRAINER_M.aiMods,
  player = { mon = {}, curTypes = { "GRASS" } },
}
local chosen = TrainerAI.chooseMove({
  curTypes = { "FIRE" },
  curMoves = { { id = "FIX_TACKLE", pp = 10 },
    { id = "FIX_EMBERISH", pp = 10 } },
}, function(low) return low end, choiceBattle)
T.eq(chosen.id, "FIX_EMBERISH",
  "merged T3 layers prefer reliable active-mon STAB in the live engine AI")

local initial = engage(game)
local key = "red|FIX_ROUTE|OPP_BUG_CATCHER|1"
local state = save.modData.adaptive_trainers.state.trainers[key]
T.check(initial[1].moves and #initial[1].moves > 0,
  "initial generated party exposes persistent legal move memory")
T.eq(SaveSerializer.encode(initial[1].moves),
  SaveSerializer.encode(state.owned[1].moves),
  "partyDef and PokemonInstance use the same remembered moves")
local initialMoves = SaveSerializer.encode(state.owned[1].moves)
state.owned[1].moveSources = nil
state.owned[1].movesetVersion = nil
local migrated = engage(game)
T.eq(SaveSerializer.encode(migrated[1].moves), initialMoves,
  "Phase B move memory is preserved exactly during source backfill")
for _, id in ipairs(state.owned[1].moves) do
  T.check(state.owned[1].moveSources[id] ~= nil,
    "Phase B source backfill persists every existing move classification")
end
T.check(state.owned[1].movesetVersion ~= nil,
  "Phase B source backfill persists the active moveset schema version")
finish("lose")

save.playTime = save.playTime + 72 * 3600
local evolved = engage(game)
T.eq(state.owned[1].species, "BUTTERFREE",
  "long loss-gated growth reaches the permanent evolved stage")
T.check(SaveSerializer.encode(state.owned[1].moves) ~= initialMoves,
  "evolution performs a useful persistent move refresh")
local evolvedSet = {}
for _, id in ipairs(state.owned[1].moves) do evolvedSet[id] = true end
T.check(evolvedSet.FIX_EMBERISH,
  "evolution refresh admits evolved-species STAB from the runtime registry")
T.eq(state.owned[1].movesetRefreshReason, nil,
  "a completed refresh leaves no pending marker")
T.eq(state.owned[1].lastMovesetRefreshReason, "evolution",
  "the completed refresh reason remains diagnosable")
T.eq(SaveSerializer.encode(evolved[1].moves),
  SaveSerializer.encode(state.owned[1].moves),
  "materialized battle party receives the refreshed persistent set")

local stableBytes = SaveSerializer.encode({ party = evolved, state = state })
local savedBytes = SaveSerializer.encode(save.modData)
run.release()

local reload = T.sdk.loadMod(modPath, { data = fixture_data() })
local reloadSave = save_for(assert(SaveSerializer.decode(savedBytes)))
reloadSave.playTime = save.playTime
local reloadGame = game_for(reload, reloadSave)
reload.loader.game, reload.loader.modSave = reloadGame, reloadSave.modData
Runtime.emit("game.ready", { game = reloadGame })
local repeated = engage(reloadGame)
local repeatedState = reloadSave.modData.adaptive_trainers.state.trainers[key]
T.eq(SaveSerializer.encode({ party = repeated, state = repeatedState }),
  stableBytes, "save/reload cannot reroll or churn persistent move memory")
reload.release()

for _, version in ipairs({ "blue", "yellow" }) do
  local versionRun = T.sdk.loadMod(modPath, { data = fixture_data() })
  local versionSave = save_for(nil, version)
  local versionGame = game_for(versionRun, versionSave)
  versionRun.loader.game, versionRun.loader.modSave = versionGame,
    versionSave.modData
  Runtime.emit("game.ready", { game = versionGame })
  local versionParty = engage(versionGame)
  local versionKey = version .. "|FIX_ROUTE|OPP_BUG_CATCHER|1"
  local versionState = versionSave.modData.adaptive_trainers.state
    .trainers[versionKey]
  T.check(versionParty[1].moves and #versionParty[1].moves > 0,
    version .. " generates non-empty persistent move memory")
  for _, id in ipairs(versionState.owned[1].moves) do
    T.check(versionState.owned[1].moveSources[id] ~= nil,
      version .. " persists a source for every remembered move")
  end
  local versionBytes = SaveSerializer.encode({ party = versionParty,
    state = versionState })
  local savedVersion = SaveSerializer.encode(versionSave.modData)
  versionRun.release()

  local versionReload = T.sdk.loadMod(modPath, { data = fixture_data() })
  local versionReloadSave = save_for(
    assert(SaveSerializer.decode(savedVersion)), version)
  local versionReloadGame = game_for(versionReload, versionReloadSave)
  versionReload.loader.game, versionReload.loader.modSave = versionReloadGame,
    versionReloadSave.modData
  Runtime.emit("game.ready", { game = versionReloadGame })
  local versionRepeated = engage(versionReloadGame)
  local versionRepeatedState = versionReloadSave.modData.adaptive_trainers
    .state.trainers[versionKey]
  T.eq(SaveSerializer.encode({ party = versionRepeated,
      state = versionRepeatedState }), versionBytes,
    version .. " reload cannot reroll move/source memory")
  versionReload.release()
end

T.finish("adaptive trainers phase C moves and AI")
