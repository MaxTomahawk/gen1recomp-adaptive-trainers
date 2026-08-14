package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")
local SaveSerializer = require("src.core.SaveSerializer")

local modPath = assert(os.getenv("ADAPTIVE_TRAINERS_PATH"),
  "ADAPTIVE_TRAINERS_PATH must name the mod relative to Gen1Recomp")

local function species(id, stats, evolutions)
  return { id = id, types = { id == "PIDGEY" and "FLYING" or "BUG" },
    baseStats = stats, evolutions = evolutions or {}, learnset = {}, tmhm = {},
    level1Moves = { "FIX_TACKLE" } }
end

local function fixture_data()
  local data = T.fixtures.fresh()
  data.pokemon.CATERPIE = species("CATERPIE",
    { hp = 45, attack = 30, defense = 35, speed = 45, special = 20 }, {
      { method = "LEVEL", level = 7, species = "METAPOD" },
    })
  data.pokemon.CATERPIE.tmhm = { "FIX_CUT" }
  data.pokemon.METAPOD = species("METAPOD",
    { hp = 50, attack = 20, defense = 55, speed = 30, special = 25 }, {
      { method = "LEVEL", level = 10, species = "BUTTERFREE" },
    })
  data.pokemon.BUTTERFREE = species("BUTTERFREE",
    { hp = 60, attack = 45, defense = 50, speed = 70, special = 80 })
  data.pokemon.BUTTERFREE.level1Moves = { "FIX_SCRATCH" }
  data.pokemon.BUTTERFREE.learnset = {
    { level = 10, move = "FIX_EMBERISH" },
  }
  data.pokemon.PIDGEY = species("PIDGEY",
    { hp = 40, attack = 45, defense = 40, speed = 56, special = 35 })
  data.encounters.FIX_ROUTE = { grass = { rate = 25, slots = {
    { level = 4, species = "CATERPIE" },
    { level = 6, species = "CATERPIE" },
    { level = 5, species = "PIDGEY" },
  } } }
  data.trainers.OPP_BUG_CATCHER = {
    id = "OPP_BUG_CATCHER", index = 3, name = "BUG CATCHER", baseMoney = 10,
    parties = { { { species = "CATERPIE", level = 8 } } },
  }
  data.maps.FIX_ROUTE.objects = {
    { index = 1, name = "FIX_BUG_CATCHER", trainerClass = "OPP_BUG_CATCHER",
      trainerParty = 1 },
  }
  data.maps.FIX_ROUTE.warps = { { destMap = "FIX_CENTER" } }
  data.maps.FIX_CENTER = { connections = {},
    warps = { { destMap = "FIX_ROUTE" } }, objects = {
      { name = "FIX_CENTER_NURSE", text = "TEXT_FIX_CENTER_NURSE" },
    } }
  return data
end

local function save_for(modData, version)
  version = version or "red"
  return { version = version, badgeCount = 1,
    meta = { playthroughId = "phase-b-" .. version },
    player = { map = "FIX_ROUTE", id = 99, name = "RED", rival = "BLUE" },
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
    player = { cellX = 3, cellY = 4, facing = "up" },
  } }
end

local function engage(game)
  Runtime.emit("world.trainer_engaged", {
    npc = { id = "FIX_BUG_CATCHER", def = { index = 1 } },
    trainerClass = "OPP_BUG_CATCHER", partyIndex = 1,
  })
  local vanilla = game.data.trainers.OPP_BUG_CATCHER.parties[1]
  return Runtime.call("trainer.party", function(_, _, party) return party end,
    "OPP_BUG_CATCHER", 1, vanilla)
end

local function battle_for(oppClass, partyIndex)
  return { oppClass = oppClass or "OPP_BUG_CATCHER",
    partyIndex = partyIndex or 1 }
end

local function finish(result, battle)
  battle = battle or battle_for()
  Runtime.emit("battle.started", { kind = "trainer", battle = battle })
  Runtime.emit("battle.ended", { result = result, battle = battle })
end

local run = T.sdk.loadMod(modPath, { data = fixture_data() })
local save = save_for()
local game = game_for(run, save)
run.loader.game, run.loader.modSave = game, save.modData
Runtime.emit("game.ready", { game = game })

local initial = engage(game)
local initialBytes = SaveSerializer.encode(initial)
local key = "red|FIX_ROUTE|OPP_BUG_CATCHER|1"
local root = save.modData.adaptive_trainers.state
local state = root.trainers[key]
T.check(state ~= nil, "Phase B fixture persists its standard trainer")
T.check(initial[1].moves and #initial[1].moves > 0,
  "initial standard trainer instances expose persistent legal moves")
finish("lose")
T.eq(state.lossCount, 1, "a real trainer loss increments persistent loss count")
T.eq(state.battleCount, 1, "a completed trainer battle increments battle count")
T.eq(state.lastBattleAt, 1000, "loss time uses active save playTime")

save.playTime = 1900
local grace = engage(game)
T.eq(SaveSerializer.encode(grace), initialBytes,
  "the exact 900-second retry preserves species, levels, moves and size")
T.eq(#state.owned, 1, "the exact grace boundary cannot catch")
finish("lose")

local priorOwned = #state.owned
local priorLevels = {}
for index, mon in ipairs(state.owned) do priorLevels[index] = mon.level end
for interval = 1, 30 do
  save.playTime = save.playTime + 72 * 3600
  local party = engage(game)
  T.check(#state.owned <= priorOwned + 1,
    "loss interval " .. interval .. " adds at most one owned catch")
  for index = 1, math.min(#priorLevels, #state.owned) do
    T.check(state.owned[index].level >= priorLevels[index],
      "loss interval " .. interval .. " never lowers owned slot " .. index)
  end
  priorOwned = #state.owned
  priorLevels = {}
  for index, mon in ipairs(state.owned) do priorLevels[index] = mon.level end
  T.check(#party == #state.activeIds,
    "materialized party uses exactly the persistent active ids")
  finish("lose")
end
T.check(#state.owned > 1,
  "repeated long losses allow a high-catch Bug Catcher to expand")
T.check(#state.activeIds >= 2 and #state.activeIds <= 6,
  "free active slots let the Bug Catcher grow toward six without a Center")

save.playTime = save.playTime + 72 * 3600
local beforeReload = engage(game)
local stableBytes = SaveSerializer.encode({ party = beforeReload, state = state })
local savedBytes = SaveSerializer.encode(save.modData)
run.release()

local reloaded = T.sdk.loadMod(modPath, { data = fixture_data() })
local decoded = assert(SaveSerializer.decode(savedBytes))
local reloadSave = save_for(decoded)
reloadSave.playTime = save.playTime
local reloadGame = game_for(reloaded, reloadSave)
reloaded.loader.game, reloaded.loader.modSave = reloadGame, reloadSave.modData
Runtime.emit("game.ready", { game = reloadGame })
local afterReload = engage(reloadGame)
local reloadState = reloadSave.modData.adaptive_trainers.state.trainers[key]
T.eq(SaveSerializer.encode({ party = afterReload, state = reloadState }), stableBytes,
  "save/reload cannot repeat growth, reroll a catch, or rotate differently")
finish("win")
local wonRoster = SaveSerializer.encode({ owned = reloadState.owned,
  activeIds = reloadState.activeIds })
reloadSave.playTime = reloadSave.playTime + 365 * 24 * 3600
local afterWin = engage(reloadGame)
T.eq(SaveSerializer.encode({ owned = reloadState.owned,
  activeIds = reloadState.activeIds }), wonRoster,
  "a defeated vanilla trainer never grows, catches, or rotates again")
T.eq(#afterWin, #reloadState.activeIds,
  "a synthetic post-win hook cannot create a rematch roster transition")
reloaded.release()

local function collision_fixture_data()
  local data = fixture_data()
  data.maps.FIX_ROUTE.objects[2] = {
    index = 2, name = "FIX_BUG_CATCHER_TWO",
    trainerClass = "OPP_BUG_CATCHER", trainerParty = 1,
  }
  return data
end

local collisionRun = T.sdk.loadMod(modPath, { data = collision_fixture_data() })
local collisionSave = save_for(nil, "blue")
local collisionGame = game_for(collisionRun, collisionSave)
collisionRun.loader.game, collisionRun.loader.modSave = collisionGame,
  collisionSave.modData
Runtime.emit("game.ready", { game = collisionGame })
local collisionParty = engage(collisionGame)
local collisionKey = "blue|FIX_ROUTE|OPP_BUG_CATCHER|1|npc:FIX_BUG_CATCHER"
local collisionRoot = collisionSave.modData.adaptive_trainers.state
T.check(collisionRoot.trainers[collisionKey] ~= nil,
  "a colliding concrete NPC receives its suffixed persistent identity")
T.eq(collisionRoot.activeTrainer and collisionRoot.activeTrainer.identityKey,
  collisionKey, "the checkpoint payload persists the exact active identity")
local collisionBytes = SaveSerializer.encode(collisionSave.modData)
collisionRun.release()

local restoredRun = T.sdk.loadMod(modPath, { data = collision_fixture_data() })
local restoredSave = save_for(assert(SaveSerializer.decode(collisionBytes)), "blue")
local restoredGame = game_for(restoredRun, restoredSave)
restoredRun.loader.game, restoredRun.loader.modSave = restoredGame,
  restoredSave.modData
Runtime.emit("game.ready", { game = restoredGame })
local vanillaCollision = restoredGame.data.trainers.OPP_BUG_CATCHER.parties[1]
local reconstructed = Runtime.call("trainer.party",
  function(_, _, party) return party end,
  "OPP_BUG_CATCHER", 1, vanillaCollision)
local restoredRoot = restoredSave.modData.adaptive_trainers.state
T.eq(SaveSerializer.encode(reconstructed), SaveSerializer.encode(collisionParty),
  "checkpoint reconstruction reuses the collision trainer's exact party")
T.eq(restoredRoot.trainers["blue|FIX_ROUTE|OPP_BUG_CATCHER|1"], nil,
  "checkpoint reconstruction cannot create an unsuffixed shadow trainer")
Runtime.emit("checkpoint.restored", { game = restoredGame, kind = "battle" })
Runtime.emit("battle.ended", { result = "lose", battle = battle_for() })
T.eq(restoredRoot.trainers[collisionKey].battleCount, 1,
  "the restored battle result updates the suffixed trainer state")
T.eq(restoredRoot.activeTrainer, nil,
  "the persisted active identity is cleared when the battle ends")
restoredRun.release()

for _, version in ipairs({ "blue", "yellow" }) do
  local versionRun = T.sdk.loadMod(modPath, { data = fixture_data() })
  local versionSave = save_for(nil, version)
  versionSave.badgeCount = nil
  if version == "blue" then
    versionSave.inventory = { BOULDERBADGE = 1 }
  else
    versionSave.player.badges = { BOULDERBADGE = true }
  end
  local versionGame = game_for(versionRun, versionSave)
  versionRun.loader.game, versionRun.loader.modSave = versionGame,
    versionSave.modData
  Runtime.emit("game.ready", { game = versionGame })
  local first = engage(versionGame)
  finish("lose")
  versionSave.playTime = versionSave.playTime + 900
  local retry = engage(versionGame)
  T.eq(SaveSerializer.encode(retry), SaveSerializer.encode(first),
    version .. " preserves the exact grace-boundary party")
  local versionKey = version .. "|FIX_ROUTE|OPP_BUG_CATCHER|1"
  local versionState = versionSave.modData.adaptive_trainers.state
    .trainers[versionKey]
  T.eq(versionState.battleCount, 1,
    version .. " associates the result with its persistent trainer")
  T.check(first[1].moves and #first[1].moves > 0,
    version .. " persists generated moves using its runtime registry")
  versionRun.release()
end

local graceRun = T.sdk.loadMod(modPath, { data = fixture_data() })
local graceSave = save_for(nil, "yellow")
local graceGame = game_for(graceRun, graceSave)
graceRun.loader.game, graceRun.loader.modSave = graceGame, graceSave.modData
Runtime.emit("game.ready", { game = graceGame })
engage(graceGame)
local graceRoot = graceSave.modData.adaptive_trainers.state
local graceKey = "yellow|FIX_ROUTE|OPP_BUG_CATCHER|1"
local graceState = graceRoot.trainers[graceKey]
finish("lose")
for serial = 2, 7 do
  graceState.owned[serial] = {
    id = graceKey .. "#" .. serial,
    lineId = serial % 2 == 0 and "CATERPIE_LINE" or "PIDGEY_LINE",
    species = serial % 2 == 0 and "CATERPIE" or "PIDGEY",
    level = 8, moves = { "FIX_TACKLE" }, acquiredAt = 1000 + serial,
    originMap = "FIX_ROUTE", useCount = 0, attachment = 0,
    roleSeed = serial,
  }
  if serial <= 6 then graceState.activeIds[serial] = graceState.owned[serial].id end
end
local graceActiveBefore = SaveSerializer.encode(graceState.activeIds)
local gracePartyBefore = {}
for index = 1, 6 do
  local mon = graceState.owned[index]
  gracePartyBefore[index] = { species = mon.species, level = mon.level,
    moves = mon.moves }
end
graceSave.playTime = 1900
local fullGraceParty = engage(graceGame)
T.eq(SaveSerializer.encode(graceState.activeIds), graceActiveBefore,
  "exact grace freezes active roster order even with a bench and nearby Center")
T.eq(SaveSerializer.encode(fullGraceParty), SaveSerializer.encode(gracePartyBefore),
  "exact grace freezes the complete full-party species, levels, and moves")
graceRun.release()

local mismatchRun = T.sdk.loadMod(modPath, { data = fixture_data() })
local mismatchSave = save_for()
local mismatchGame = game_for(mismatchRun, mismatchSave)
mismatchRun.loader.game, mismatchRun.loader.modSave = mismatchGame,
  mismatchSave.modData
Runtime.emit("game.ready", { game = mismatchGame })
engage(mismatchGame)
local mismatchKey = "red|FIX_ROUTE|OPP_BUG_CATCHER|1"
local mismatchState = mismatchSave.modData.adaptive_trainers.state
  .trainers[mismatchKey]
local wrongBattle = battle_for("OPP_HIKER", 2)
Runtime.emit("battle.started", { kind = "trainer", battle = wrongBattle })
Runtime.emit("battle.ended", { result = "lose", battle = wrongBattle })
T.eq(mismatchState.battleCount, 0,
  "a mismatched concrete battle cannot consume a prepared trainer result")
engage(mismatchGame)
finish("lose")
T.eq(mismatchState.battleCount, 1,
  "a newly prepared matching battle still records exactly one result")
mismatchRun.release()

local skippedRun = T.sdk.loadMod(modPath, { data = fixture_data() })
local skippedSave = save_for()
local skippedGame = game_for(skippedRun, skippedSave)
skippedRun.loader.game, skippedRun.loader.modSave = skippedGame,
  skippedSave.modData
Runtime.emit("game.ready", { game = skippedGame })
engage(skippedGame)
local skippedKey = "red|FIX_ROUTE|OPP_BUG_CATCHER|1"
local skippedState = skippedSave.modData.adaptive_trainers.state
  .trainers[skippedKey]
Runtime.emit("battle.ended", { result = "lose", skipped = true,
  battle = battle_for() })
T.eq(skippedState.battleCount, 1,
  "a matching skipped trainer battle records its concrete result without started")
T.eq(skippedState.lossCount, 1,
  "a no-healthy-party skipped loss increments the persistent loss count")
T.eq(skippedState.lastBattleAt, skippedSave.playTime,
  "a skipped loss starts the same active-play-time grace interval")
skippedRun.release()

local upgradeRun = T.sdk.loadMod(modPath, { data = fixture_data() })
local upgradeSave = save_for(nil, "blue")
local upgradeGame = game_for(upgradeRun, upgradeSave)
upgradeRun.loader.game, upgradeRun.loader.modSave = upgradeGame,
  upgradeSave.modData
Runtime.emit("game.ready", { game = upgradeGame })
engage(upgradeGame)
local upgradeKey = "blue|FIX_ROUTE|OPP_BUG_CATCHER|1"
local upgradeState = upgradeSave.modData.adaptive_trainers.state
  .trainers[upgradeKey]
finish("lose")
upgradeState.owned[1].moves = nil
upgradeSave.playTime = upgradeSave.playTime + 100
local upgradedParty = engage(upgradeGame)
T.check(upgradeState.owned[1].moves and #upgradeState.owned[1].moves > 0,
  "an existing generated individual receives only its missing derived moves")
T.eq(table.concat(upgradeState.owned[1].moves, ","), "FIX_TACKLE",
  "grace-window legacy hydration exactly matches the prior engine level moves")
T.eq(table.concat(upgradedParty[1].moves, ","), "FIX_TACKLE",
  "legacy hydration cannot introduce a legal TM during exact grace")
local upgradedBytes = SaveSerializer.encode(upgradedParty)
T.eq(SaveSerializer.encode(engage(upgradeGame)), upgradedBytes,
  "derived move hydration is deterministic and cannot reroll the individual")
upgradeRun.release()

T.finish("adaptive trainers phase B persistence")
