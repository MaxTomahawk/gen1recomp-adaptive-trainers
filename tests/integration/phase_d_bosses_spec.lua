package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")
local SaveSerializer = require("src.core.SaveSerializer")
local StateStack = require("src.core.StateStack")
local OW = require("src.world.OverworldController")

local modPath = assert(os.getenv("ADAPTIVE_TRAINERS_PATH"),
  "ADAPTIVE_TRAINERS_PATH must name the mod relative to Gen1Recomp")
local modRoot = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")
local meta = assert(loadfile(modRoot .. "/src/data/line_meta.lua"))().build()
local rosters = assert(loadfile(modRoot .. "/src/data/boss_rosters.lua"))()

local LEADER_CLASSES = {
  BROCK = { class = "OPP_BROCK", party = 1, map = "PEWTER_GYM" },
  MISTY = { class = "OPP_MISTY", party = 1, map = "CERULEAN_GYM" },
  LT_SURGE = { class = "OPP_LT_SURGE", party = 1,
    map = "VERMILION_GYM" },
  ERIKA = { class = "OPP_ERIKA", party = 1, map = "CELADON_GYM" },
  KOGA = { class = "OPP_KOGA", party = 1, map = "FUCHSIA_GYM" },
  SABRINA = { class = "OPP_SABRINA", party = 1, map = "SAFFRON_GYM" },
  BLAINE = { class = "OPP_BLAINE", party = 1, map = "CINNABAR_GYM" },
  GIOVANNI = { class = "OPP_GIOVANNI", party = 3,
    map = "VIRIDIAN_GYM" },
}

local function species(id)
  return { id = id, types = { "NORMAL" }, baseStats = {
      hp = 60, attack = 60, defense = 60, speed = 60, special = 60,
    }, evolutions = {}, learnset = {
      { level = 1, move = "FIX_TACKLE" },
    }, tmhm = {}, level1Moves = { "FIX_TACKLE" } }
end

local function fixture_data()
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
  for _, info in pairs(LEADER_CLASSES) do
    data.trainers[info.class] = {
      id = info.class, name = info.class, baseMoney = 50, parties = {},
    }
    for index = 1, info.party do
      data.trainers[info.class].parties[index] = {
        { species = "FIXMON_A", level = 5 },
      }
    end
  end
  return data
end

local function save_for(version, modData)
  return { version = version, badgeCount = 8,
    meta = { playthroughId = "phase-d-" .. version },
    player = { map = "FIX_ROUTE", id = 7, name = "RED", rival = "BLUE" },
    party = {
      { species = "FIXMON_A", level = 60 },
      { species = "FIXMON_A", level = 55 },
      { species = "FIXMON_A", level = 50 },
      { species = "FIXMON_A", level = 45 },
      { species = "FIXMON_A", level = 40 },
      { species = "FIXMON_A", level = 35 },
    },
    playTime = 2000,
    modData = modData or { adaptive_trainers = {} },
  }
end

local function game_for(run, save)
  local stack = setmetatable({ states = {} }, { __index = StateStack })
  return { data = run.data, save = save, stack = stack, overworld = {
    isOverworld = true, map = { id = "FIX_ROUTE" },
    player = { cellX = 4, cellY = 4, facing = "up" },
  } }
end

local function load_run(version, modData)
  local run = T.sdk.loadMod(modPath, { data = fixture_data() })
  local save = save_for(version, modData)
  local game = game_for(run, save)
  run.loader.game, run.loader.modSave = game, save.modData
  Runtime.emit("game.ready", { game = game })
  return run, save, game
end

local function engage(game, info)
  local starts, options = 0
  local deferred = OW.prepareTrainerBattle(game, {
    trainerClass = info.class, partyIndex = info.party,
    mapId = info.map, npcId = info.map .. "_obj_1",
  }, function(value)
    starts, options = starts + 1, value
  end)
  T.eq(deferred, true, info.class .. " uses formal registration")
  local screen = game.stack:top()
  T.check(screen and screen.screenId == "AdaptiveGymRegistration",
    info.class .. " opens the public registration screen")
  T.eq(screen:confirm(), true, info.class .. " healthy defaults confirm")
  T.eq(starts, 1, info.class .. " resumes battle construction once")
  T.check(type(options) == "table"
      and type(options.playerPartyIndices) == "table",
    info.class .. " supplies a battle-local eligibility scope")
  return Runtime.call("trainer.party", function(_, _, party) return party end,
    info.class, info.party,
    game.data.trainers[info.class].parties[info.party])
end

local function start_and_finish(info, result)
  local battle = { oppClass = info.class, partyIndex = info.party }
  Runtime.emit("battle.started", { kind = "trainer", battle = battle })
  local strategy = battle.adaptiveStrategy
  local originalMods = { "LAYER_1" }
  battle.enemyAIMods = originalMods
  local scoped
  Runtime.call("battle.enemy_action", function(live)
    scoped = live.enemyAIMods
    return { id = "FIX_TACKLE" }
  end, battle)
  T.check(scoped and scoped[5] == "ADAPTIVE_T4_STRATEGY",
    info.class .. " receives scoped T4 strategy AI")
  T.check(battle.enemyAIMods == originalMods,
    info.class .. " restores AI fields outside action selection")
  Runtime.emit("battle.ended", { result = result, battle = battle })
  return strategy
end

for _, version in ipairs({ "red", "blue", "yellow" }) do
  local run, save, game = load_run(version)
  local expectedBytes = {}
  for leaderId, info in pairs(LEADER_CLASSES) do
    local identity = rosters.leaders[leaderId]
    local party = engage(game, info)
    local state = save.modData.adaptive_trainers.state.bossAttempts[leaderId]
    local count = rosters.active_count(identity, version)
    T.eq(#party, count,
      version .. " " .. leaderId .. " uses its exact formal party size")
    T.eq(#state.party, count,
      version .. " " .. leaderId .. " persists every boss individual")
    T.eq(state.party[1].lineId, rosters.signature_line(identity, version),
      version .. " " .. leaderId .. " keeps its version-correct signature")
    for slot = 1, count do
      local reference = save.party[slot] and save.party[slot].level
        or save.party[#save.party].level
      if slot == 1 then reference = reference + 1 end
      T.eq(party[slot].level,
        math.max(rosters.floors(identity, version)[slot], reference),
        version .. " " .. leaderId .. " follows the formal level rule")
      T.check(state.party[slot].moves and #state.party[slot].moves > 0,
        version .. " " .. leaderId .. " persists a legal non-empty moveset")
    end
    T.check(run.data.trainers[info.class].aiMods == nil,
      version .. " " .. leaderId .. " is not globally patched to T4")
    local strategy = start_and_finish(info, "win")
    T.check(strategy and strategy.id == state.strategyId,
      version .. " " .. leaderId .. " binds its persisted strategy to battle")
    expectedBytes[leaderId] = SaveSerializer.encode({ party = party,
      state = state })
  end

  local savedBytes = SaveSerializer.encode(save.modData)
  run.release()
  local reload, reloadSave, reloadGame = load_run(version,
    assert(SaveSerializer.decode(savedBytes)))
  for leaderId, info in pairs(LEADER_CLASSES) do
    local party = engage(reloadGame, info)
    local state = reloadSave.modData.adaptive_trainers.state
      .bossAttempts[leaderId]
    T.eq(SaveSerializer.encode({ party = party, state = state }),
      expectedBytes[leaderId],
      version .. " " .. leaderId .. " save/reload cannot reroll an attempt")
    start_and_finish(info, "win")
  end

  local brockInfo = LEADER_CLASSES.BROCK
  local beforeLoss = engage(reloadGame, brockInfo)
  local beforeSignature = reloadSave.modData.adaptive_trainers.state
    .bossAttempts.BROCK.party[1].lineId
  start_and_finish(brockInfo, "lose")
  local nextAttempt = engage(reloadGame, brockInfo)
  local nextState = reloadSave.modData.adaptive_trainers.state
    .bossAttempts.BROCK
  T.eq(nextState.attemptCounter, 1,
    version .. " a genuine Gym loss advances exactly one attempt")
  T.eq(nextState.party[1].lineId, beforeSignature,
    version .. " a new attempt retains the fixed signature line")
  T.eq(#nextAttempt, #beforeLoss,
    version .. " attempt variation preserves formal party size")
  reload.release()
end

T.finish("adaptive trainers phase D bosses")
