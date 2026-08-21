package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or require("tests.love_stub")
local checkpointRngState = "adaptive-gym-rng-A"
love.math.getRandomState = function() return checkpointRngState end
love.math.setRandomState = function(state) checkpointRngState = state end

local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")
local SaveSerializer = require("src.core.SaveSerializer")
local StateStack = require("src.core.StateStack")
local OW = require("src.world.OverworldController")
local GameMethods = require("src.core.Game")
local BattleState = require("src.battle.BattleState")
local Pokemon = require("src.pokemon.Pokemon")
local SaveData = require("src.core.SaveData")

local modPath = assert(os.getenv("ADAPTIVE_TRAINERS_PATH"),
  "ADAPTIVE_TRAINERS_PATH must name the mod relative to Gen1Recomp")

local function species(id, types)
  return { id = id, name = id, types = types, baseStats = {
      hp = 50, attack = 50, defense = 50, speed = 50, special = 50,
    }, evolutions = {}, learnset = {}, tmhm = {},
    level1Moves = { "FIX_TACKLE" } }
end

local function fixture_data()
  local data = T.fixtures.fresh()
  for id, types in pairs({
    ONIX = { "ROCK", "GROUND" }, GEODUDE = { "ROCK", "GROUND" },
    RHYHORN = { "GROUND", "ROCK" }, OMANYTE = { "ROCK", "WATER" },
    KABUTO = { "ROCK", "WATER" },
    AERODACTYL = { "ROCK", "FLYING" },
  }) do data.pokemon[id] = species(id, types) end
  data.trainers.OPP_BROCK = {
    id = "OPP_BROCK", name = "BROCK", baseMoney = 99,
    parties = { { { species = "GEODUDE", level = 12 },
      { species = "ONIX", level = 14 } } },
    aiClass = "OPP_BROCK", aiMods = { "LAYER_1" },
  }
  data.maps.PEWTER_GYM = {
    id = "PEWTER_GYM", width = 10, height = 10, objects = {} }
  return data
end

local function save_for(data, modData)
  local save = SaveData.newGame()
  save.version = "red"
  save.meta.playthroughId = "phase-d-red"
  save.player.map, save.player.x, save.player.y = "PEWTER_GYM", 4, 3
  save.player.facing, save.player.id = "up", 25
  save.player.name, save.player.rival = "RED", "BLUE"
  save.party = {
    Pokemon.new(data, "FIXMON_A", 20),
    Pokemon.new(data, "FIXMON_B", 5),
    Pokemon.new(data, "FIXMON_C", 18),
  }
  save.party[1].nickname, save.party[2].nickname = "ACE", "LOW"
  save.party[3].nickname = "MID"
  save.playTime = 2000
  save.modData = modData or { adaptive_trainers = {} }
  SaveData.validate(save, data)
  return save
end

local function game_for(run, save)
  local stack = setmetatable({ states = {} }, { __index = StateStack })
  local game
  local overworld = {
    isOverworld = true, map = { id = "PEWTER_GYM" },
    player = { cellX = 4, cellY = 3, facing = "up", surfing = false },
    runner = { isRunning = function() return false end },
    parallelRunners = {}, pendingScripts = {}, parallelQueue = {},
    scriptMoves = {},
  }
  function overworld:captureSave(target)
    target.player.map = self.map.id
    target.player.x, target.player.y = self.player.cellX, self.player.cellY
    target.player.facing = self.player.facing
    target.player.surfing = self.player.surfing and true or false
  end
  function overworld:enter(mapId, x, y, facing)
    self.map = { id = mapId }
    self.player = { cellX = x, cellY = y, facing = facing,
      surfing = game.save.player.surfing and true or false }
  end
  function overworld:restoreBattleContinuation(battle, origin)
    if origin.kind ~= "trainer_encounter" or origin.map ~= self.map.id
        or origin.trainerClass ~= "OPP_BROCK" or origin.partyIndex ~= 1
        or origin.npcId ~= "PEWTER_GYM_obj_1" then
      return false
    end
    battle.onFinish = function() end
    return true
  end
  game = setmetatable({ data = run.data, save = save, stack = stack,
    overworld = overworld, mods = run.loader }, { __index = GameMethods })
  stack.states[1] = overworld
  return game
end

local function bind(run, save)
  local game = game_for(run, save)
  run.loader.game, run.loader.modSave = game, save.modData
  Runtime.emit("game.ready", { game = game })
  return game
end

local function prepare(game, context, onStart)
  local starts, cancels, options = 0, 0
  local deferred = OW.prepareTrainerBattle(game, context, function(value)
    starts, options = starts + 1, value
    if onStart then onStart(value) end
  end, function()
    cancels = cancels + 1
  end)
  return deferred, function() return starts, cancels, options end
end

local context = { trainerClass = "OPP_BROCK", partyIndex = 1,
  mapId = "PEWTER_GYM", npcId = "PEWTER_GYM_obj_1" }
local probePath = modPath .. "/tests/fixtures/checkpoint_probe"
local run = T.sdk.loadMods({ modPath, probePath }, { data = fixture_data() })
local checkpoints = assert(run.loader.exports
  .adaptive_trainers_checkpoint_probe.checkpoints)
local save = save_for(run.data)
local game = bind(run, save)

local liveBattle
local deferred, result = prepare(game, context, function(options)
  liveBattle = BattleState.newTrainer(game, context.trainerClass,
    context.partyIndex, options)
  liveBattle.phase, liveBattle.queue = "menu", {}
  liveBattle.checkpointOrigin = { kind = "trainer_encounter",
    map = context.mapId, npcId = context.npcId,
    trainerClass = context.trainerClass, partyIndex = context.partyIndex }
  liveBattle.musicKind = liveBattle:computeMusicKind()
  liveBattle.onFinish = function() end
  game.stack.states[2] = liveBattle
end)
T.eq(deferred, true, "the public pre-battle hook defers a Gym battle")
local starts = result()
T.eq(starts, 0, "battle construction waits for registration")
local screen = game.stack:top()
T.eq(screen.screenId, "AdaptiveGymRegistration",
  "the challenge uses the registered public Gym screen")
T.same(screen:selected_indices(), { 1, 3 },
  "Brock defaults to the top two healthy members")
screen:toggle(1)
screen:toggle(3)
screen:toggle(2)
T.eq(screen:confirm(), true, "a healthy custom registration confirms")
local confirmedStarts, confirmedCancels, options = result()
T.eq(confirmedStarts, 1, "confirmation resumes the one-shot continuation")
T.eq(confirmedCancels, 0, "confirmation does not cancel the encounter")
T.same(options, { playerPartyIndices = { 2 } },
  "only registered save-party indices become battle eligible")

local root = save.modData.adaptive_trainers.state
T.same(root.activeBoss.registeredIndices, { 2 },
  "registration authority is persisted in mod.save")
T.same(root.activeBoss.referenceLevels, { 20, 18 },
  "scaling snapshots full-party top N before registration")

local generated = Runtime.call("trainer.party",
  function(_, _, party) return party end,
  "OPP_BROCK", 1, run.data.trainers.OPP_BROCK.parties[1])
T.eq(#generated, 2, "Brock keeps the formal active size")
T.eq(generated[1].species, "ONIX", "Brock's signature is rank one")
T.eq(generated[1].level, 21,
  "signature uses full-party R1+1 despite weak registration")
T.eq(generated[2].level, 18,
  "the second slot uses the full-party matched reference")
T.same(run.data.trainers.OPP_BROCK.aiMods, { "LAYER_1" },
  "the shared trainer class is never globally promoted to T4")

T.same(liveBattle.playerPartyIndices, { 2 },
  "the real BattleState receives the registered save-party index")
T.check(liveBattle.playerParty[1] == game.save.party[2]
    and #liveBattle:playerPartyView() == 1,
  "the live battle view contains only the registered Pokemon object")
local snapshot, captureCode = checkpoints:capture(game)
T.check(snapshot and snapshot.kind == "battle",
  "the public checkpoint facade captures the registered Gym battle: "
    .. tostring(captureCode))
local restored, restoreCode, restoreMessage = checkpoints:restore(
  game, assert(snapshot))
T.check(restored == true,
  "the public checkpoint facade reconstructs the Gym battle: "
    .. tostring(restoreCode) .. " / " .. tostring(restoreMessage))
local restoredBattle = game.stack:top()
T.same(restoredBattle.playerPartyIndices, { 2 },
  "checkpoint reconstruction restores the ordered registration scope")
T.check(restoredBattle.playerParty[1] == game.save.party[2]
    and #restoredBattle:playerPartyView() == 1,
  "restored battle scope points at the authoritative saved Pokemon")
T.same(game.save.modData.adaptive_trainers.state.activeBoss
    .registeredIndices, { 2 },
  "real checkpoint restore retains mod.save registration authority")

local stableParty = SaveSerializer.encode(generated)
local savedBytes = SaveSerializer.encode(game.save.modData)
run.release()

local reload = T.sdk.loadMod(modPath, { data = fixture_data() })
local reloadSave = save_for(reload.data,
  assert(SaveSerializer.decode(savedBytes)))
local reloadGame = bind(reload, reloadSave)
local repeated = Runtime.call("trainer.party",
  function(_, _, party) return party end,
  "OPP_BROCK", 1, reload.data.trainers.OPP_BROCK.parties[1])
T.eq(SaveSerializer.encode(repeated), stableParty,
  "save/reload cannot reroll the same registered attempt")
T.same(reloadSave.modData.adaptive_trainers.state.activeBoss
    .registeredIndices, { 2 },
  "save/reload retains the registered player-party mask authority")
local attempt = reloadSave.modData.adaptive_trainers.state
  .bossAttempts.BROCK
T.eq(attempt.attemptCounter, 0, "reload does not manufacture an attempt")

local battle = BattleState.newTrainer(reloadGame, "OPP_BROCK", 1, {
  playerPartyIndices = { 2 },
})
battle.phase, battle.queue = "menu", {}
local originalMods = battle.enemyAIMods
Runtime.emit("battle.started", { kind = "trainer", battle = battle })
battle.adaptiveStrategy = nil
T.same(battle.playerPartyIndices, { 2 },
  "the reloaded attempt constructs the same real party scope")
T.check(battle.playerParty[1] == reloadGame.save.party[2]
    and #battle:playerPartyView() == 1,
  "the reloaded battle excludes every unregistered party member")
local scopedMods, scopedStrategy
Runtime.call("battle.enemy_action", function(live)
  scopedMods = table.concat(live.enemyAIMods, ",")
  scopedStrategy = live.adaptiveStrategy
  return { id = "FIX_TACKLE" }
end, battle)
T.eq(scopedMods,
  "LAYER_1,LAYER_2,LAYER_3,ADAPTIVE_T3_ROLE,ADAPTIVE_T4_STRATEGY",
  "the persisted attempt reconstructs T4 AI for the active formal boss only")
T.check(type(scopedStrategy) == "table" and scopedStrategy.id ~= nil,
  "lazy T4 scoping uses the persisted attempt strategy")
T.check(battle.enemyAIMods == originalMods and battle.adaptiveStrategy == nil,
  "AI scoping restores the live battle after action selection")
Runtime.emit("battle.ended", { result = "lose", battle = battle })
T.eq(attempt.attemptCounter, 1,
  "a real Gym loss binds to and advances one attempt")
T.eq(attempt.party, nil, "the next attempt may regenerate flex and strategy")
T.eq(reloadSave.modData.adaptive_trainers.state.activeBoss, nil,
  "a completed challenge clears registration authority")

local cancelDeferred, cancelResult = prepare(reloadGame, context)
T.eq(cancelDeferred, true, "a later Gym challenge defers again")
T.eq(reloadGame.stack:top():cancel(), true, "B cancels the registration")
local cancelStarts, cancelCalls, cancelOptions = cancelResult()
T.eq(cancelStarts, 0, "cancel never constructs a battle")
T.eq(cancelCalls, 1, "cancel invokes the encounter completion callback")
T.eq(cancelOptions, nil, "cancel supplies no party scope")
T.eq(attempt.attemptCounter, 1, "cancel never advances the attempt")
T.eq(reloadGame.stack:top(), reloadGame.overworld,
  "cancel returns to the overworld")

local wrongMap = { trainerClass = "OPP_BROCK", partyIndex = 1,
  mapId = "FIX_ROUTE", npcId = "FIX_ROUTE_obj_1" }
local wrongDeferred, wrongResult = prepare(reloadGame, wrongMap)
local wrongStarts, wrongCancels, wrongOptions = wrongResult()
T.eq(wrongDeferred, false, "a reused class outside the Gym is not captured")
T.eq(wrongStarts, 1, "a noncanonical encounter keeps vanilla flow")
T.eq(wrongCancels, 0, "the noncanonical encounter is not cancelled")
T.eq(wrongOptions, nil, "the noncanonical encounter keeps the full party")

local story = { trainerClass = "OPP_GIOVANNI", partyIndex = 1,
  mapId = "ROCKET_HIDEOUT_B4F", npcId = "ROCKET_HIDEOUT_B4F_obj_1" }
local storyDeferred, storyResult = prepare(reloadGame, story)
local storyStarts = storyResult()
T.eq(storyDeferred, false, "Hideout Giovanni is not a formal Gym challenge")
T.eq(storyStarts, 1, "story Giovanni retains immediate vanilla flow")

local vanilla = reload.data.trainers.OPP_BROCK.parties[1]
local unregistered = Runtime.call("trainer.party",
  function(_, _, party) return party end, "OPP_BROCK", 1, vanilla)
T.check(unregistered == vanilla,
  "a leader class without active registration keeps its vanilla roster")

reload.release()
T.finish("adaptive trainers Gym runtime")
