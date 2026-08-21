package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")
local SaveSerializer = require("src.core.SaveSerializer")
local StateStack = require("src.core.StateStack")
local OW = require("src.world.OverworldController")

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
  return data
end

local function save_for(modData)
  return {
    version = "red", meta = { playthroughId = "phase-d-red" },
    player = { map = "PEWTER_GYM", id = 25,
      name = "RED", rival = "BLUE" },
    party = {
      { species = "FIXMON_A", nickname = "ACE", level = 20, hp = 30 },
      { species = "FIXMON_B", nickname = "LOW", level = 5, hp = 20 },
      { species = "FIXMON_C", nickname = "MID", level = 18, hp = 25 },
    },
    playTime = 2000,
    modData = modData or { adaptive_trainers = {} },
  }
end

local function game_for(run, save)
  local stack = setmetatable({ states = {} }, { __index = StateStack })
  return { data = run.data, save = save, stack = stack, overworld = {
    isOverworld = true, map = { id = "PEWTER_GYM" },
    player = { cellX = 4, cellY = 3, facing = "up" },
  } }
end

local function bind(run, save)
  local game = game_for(run, save)
  run.loader.game, run.loader.modSave = game, save.modData
  Runtime.emit("game.ready", { game = game })
  return game
end

local function prepare(game, context)
  local starts, cancels, options = 0, 0
  local deferred = OW.prepareTrainerBattle(game, context, function(value)
    starts, options = starts + 1, value
  end, function()
    cancels = cancels + 1
  end)
  return deferred, function() return starts, cancels, options end
end

local context = { trainerClass = "OPP_BROCK", partyIndex = 1,
  mapId = "PEWTER_GYM", npcId = "PEWTER_GYM_obj_1" }
local run = T.sdk.loadMod(modPath, { data = fixture_data() })
local save = save_for()
local game = bind(run, save)

local deferred, result = prepare(game, context)
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

local stableParty = SaveSerializer.encode(generated)
local savedBytes = SaveSerializer.encode(save.modData)
run.release()

local reload = T.sdk.loadMod(modPath, { data = fixture_data() })
local reloadSave = save_for(assert(SaveSerializer.decode(savedBytes)))
local reloadGame = bind(reload, reloadSave)
Runtime.emit("checkpoint.restored", { kind = "battle", game = reloadGame })
T.same(reloadSave.modData.adaptive_trainers.state.activeBoss
    .registeredIndices, { 2 },
  "checkpoint restore retains the registered player-party mask authority")
local repeated = Runtime.call("trainer.party",
  function(_, _, party) return party end,
  "OPP_BROCK", 1, reload.data.trainers.OPP_BROCK.parties[1])
T.eq(SaveSerializer.encode(repeated), stableParty,
  "checkpoint save/reload cannot reroll the same registered attempt")
local attempt = reloadSave.modData.adaptive_trainers.state
  .bossAttempts.BROCK
T.eq(attempt.attemptCounter, 0, "reload does not manufacture an attempt")

local battle = { oppClass = "OPP_BROCK", partyIndex = 1 }
Runtime.emit("battle.started", { kind = "trainer", battle = battle })
T.check(type(battle.adaptiveStrategy) == "table",
  "battle start attaches the persisted structural strategy")
local originalMods = { "LAYER_1" }
battle.enemyAIMods = originalMods
battle.adaptiveStrategy = nil
local scopedMods, scopedStrategy
Runtime.call("battle.enemy_action", function(live)
  scopedMods = table.concat(live.enemyAIMods, ",")
  scopedStrategy = live.adaptiveStrategy
  return { id = "FIX_TACKLE" }
end, battle)
T.eq(scopedMods,
  "LAYER_1,LAYER_2,LAYER_3,ADAPTIVE_T3_ROLE,ADAPTIVE_T4_STRATEGY",
  "checkpoint restore reconstructs T4 AI for the active formal boss only")
T.check(type(scopedStrategy) == "table" and scopedStrategy.id ~= nil,
  "lazy T4 scoping uses the persisted attempt strategy")
T.check(battle.enemyAIMods == originalMods and battle.adaptiveStrategy == nil,
  "AI scoping restores the live battle after action selection")
Runtime.emit("battle.ended", { result = "lose", battle = battle })
T.eq(attempt.attemptCounter, 1,
  "a restored real Gym loss binds to and advances one attempt")
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
T.eq(reloadGame.stack:top(), nil, "cancel returns to the overworld")

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
