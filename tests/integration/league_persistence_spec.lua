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
local rosters = assert(loadfile(modRoot .. "/src/data/league_rosters.lua"))()

local function species(id)
  return { id = id, name = id, types = { "NORMAL" }, baseStats = {
      hp = 60, attack = 60, defense = 60, speed = 60, special = 60,
    }, evolutions = {}, learnset = { { level = 1, move = "FIX_TACKLE" } },
    tmhm = {}, level1Moves = { "FIX_TACKLE" } }
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
  for _, identity in pairs(rosters.members) do
    data.trainers[identity.classId] = { id = identity.classId,
      name = identity.id, baseMoney = 99, aiMods = { "LAYER_1" },
      parties = { { { species = "FIXMON_A", level = 5 } } },
    }
  end
  return data
end

local function save_for(version, modData)
  return { version = version, meta = { playthroughId = "league-" .. version },
    player = { map = "LORELEIS_ROOM", id = 7,
      name = "RED", rival = "BLUE" },
    party = {
      { species = "FIXMON_A", level = 70, hp = 40 },
      { species = "FIXMON_A", level = 60, hp = 40 },
      { species = "FIXMON_A", level = 50, hp = 40 },
      { species = "FIXMON_A", level = 40, hp = 40 },
      { species = "FIXMON_A", level = 30, hp = 40 },
      { species = "FIXMON_A", level = 20, hp = 40 },
    }, playTime = 9000,
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

local function engage(run, game, identity)
  game.overworld.map.id = identity.mapId
  game.save.player.map = identity.mapId
  Runtime.emit("world.trainer_engaged", { trainerClass = identity.classId,
    partyIndex = 1, npc = { id = identity.npcId,
      def = { name = identity.npcId, trainerClass = identity.classId,
        trainerParty = 1 } } })
  return Runtime.call("trainer.party", function(_, _, party) return party end,
    identity.classId, 1, run.data.trainers[identity.classId].parties[1])
end

local function finish(identity, result)
  local battle = { oppClass = identity.classId, partyIndex = 1,
    enemyAIMods = { "LAYER_1" } }
  Runtime.emit("battle.started", { kind = "trainer", battle = battle })
  local scoped
  Runtime.call("battle.enemy_action", function(live)
    scoped = live.enemyAIMods
    return { id = "FIX_TACKLE" }
  end, battle)
  T.check(scoped and scoped[5] == "ADAPTIVE_T4_STRATEGY",
    identity.id .. " uses scoped T4 League AI")
  Runtime.emit("battle.ended", { result = result, battle = battle })
end

for _, version in ipairs({ "red", "blue", "yellow" }) do
  local run = T.sdk.loadMod(modPath, { data = fixture_data() })
  local save = save_for(version)
  local game = bind(run, save)
  Runtime.emit("map.entered", { mapId = "LORELEIS_ROOM",
    fromMapId = "INDIGO_PLATEAU_LOBBY", via = "warp" })
  local root = save.modData.adaptive_trainers.state
  local leagueRun = root.leagueRun
  T.eq(root.leagueRunCounter, 1, version .. " first entry creates run one")
  T.same(leagueRun.referenceLevels, { 70, 60, 50, 40, 30 },
    version .. " snapshots top five levels once")

  local lorelei = rosters.members.LORELEI
  local starts, options = 0
  local deferred = OW.prepareTrainerBattle(game, {
    trainerClass = lorelei.classId, partyIndex = 1,
    mapId = lorelei.mapId, npcId = lorelei.npcId,
  }, function(value) starts, options = starts + 1, value end)
  T.eq(deferred, false, version .. " Elite Four has no Gym registration gate")
  T.eq(starts, 1, version .. " Elite Four battle remains immediate")
  T.eq(options, nil, version .. " Elite Four uses the full player party")

  save.party[1].level = 100
  local expected, visibleBirds = {}, 0
  for _, memberId in ipairs({ "LORELEI", "BRUNO", "AGATHA", "LANCE" }) do
    local identity = rosters.members[memberId]
    local party = engage(run, game, identity)
    expected[memberId] = SaveSerializer.encode(party)
    T.eq(#party, 5, version .. " " .. memberId .. " fields five")
    T.eq(party[1].species, identity.signatureSpecies,
      version .. " " .. memberId .. " keeps its signature")
    T.eq(party[1].level, math.max(identity.floors[1], 71),
      version .. " " .. memberId .. " ignores in-run level changes")
    for _, instance in ipairs(leagueRun.generatedParties[memberId]) do
      if rosters.birds[instance.species] then visibleBirds = visibleBirds + 1 end
    end
    finish(identity, "win")
  end
  T.eq(visibleBirds, 1, version .. " run visibly fields exactly one Bird")

  local pairBytes = SaveSerializer.encode(leagueRun.birdPair)
  local savedBytes = SaveSerializer.encode(save.modData)
  run.release()

  local reload = T.sdk.loadMod(modPath, { data = fixture_data() })
  local reloadSave = save_for(version, assert(SaveSerializer.decode(savedBytes)))
  local reloadGame = bind(reload, reloadSave)
  local restoredRun = reloadSave.modData.adaptive_trainers.state.leagueRun
  T.eq(SaveSerializer.encode(restoredRun.birdPair), pairBytes,
    version .. " save/reload preserves the Bird pairing")
  for _, memberId in ipairs({ "LORELEI", "BRUNO", "AGATHA", "LANCE" }) do
    local party = engage(reload, reloadGame, rosters.members[memberId])
    T.eq(SaveSerializer.encode(party), expected[memberId],
      version .. " " .. memberId .. " save/reload is byte-stable")
    finish(rosters.members[memberId], "win")
  end

  local checkpointParty = engage(reload, reloadGame, lorelei)
  T.eq(SaveSerializer.encode(checkpointParty), expected.LORELEI,
    version .. " checkpoint reconstruction reuses Lorelei")
  Runtime.emit("checkpoint.restored", { kind = "battle", game = reloadGame })
  local checkpointBattle = { oppClass = lorelei.classId, partyIndex = 1,
    enemyAIMods = { "LAYER_1" } }
  local scoped
  Runtime.call("battle.enemy_action", function(live)
    scoped = live.enemyAIMods
    return { id = "FIX_TACKLE" }
  end, checkpointBattle)
  T.check(scoped and scoped[5] == "ADAPTIVE_T4_STRATEGY",
    version .. " checkpoint restore reconstructs League T4 context")
  Runtime.emit("battle.ended", { result = "lose", battle = checkpointBattle })
  T.eq(restoredRun.generatedParties.LORELEI ~= nil, true,
    version .. " loss keeps run state until the blackout map exit")

  Runtime.emit("map.exited", { mapId = "LANCES_ROOM",
    toMapId = "CHAMPIONS_ROOM" })
  T.eq(reloadSave.modData.adaptive_trainers.state.leagueRun, restoredRun,
    version .. " Champion transition remains in the same League run")
  Runtime.emit("map.exited", { mapId = "CHAMPIONS_ROOM",
    toMapId = "HALL_OF_FAME" })
  T.eq(reloadSave.modData.adaptive_trainers.state.leagueRun, restoredRun,
    version .. " Hall of Fame transition remains in the same League run")

  Runtime.emit("map.exited", { mapId = "LORELEIS_ROOM",
    toMapId = "INDIGO_PLATEAU_LOBBY" })
  T.eq(reloadSave.modData.adaptive_trainers.state.leagueRun, nil,
    version .. " blackout/League exit clears the run")
  Runtime.emit("map.entered", { mapId = "LORELEIS_ROOM",
    fromMapId = "INDIGO_PLATEAU_LOBBY", via = "warp" })
  local nextRoot = reloadSave.modData.adaptive_trainers.state
  T.eq(nextRoot.leagueRunCounter, 2,
    version .. " re-entry advances the run counter")
  T.check(nextRoot.leagueRun.id ~= restoredRun.id,
    version .. " re-entry creates a distinct run identity")
  reload.release()
end

T.finish("adaptive trainers League persistence")
