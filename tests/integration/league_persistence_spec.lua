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
  local premature = engage(run, game, rosters.members.BRUNO)
  T.eq(#premature, 1, version .. " cannot create a run at a later member")
  T.eq(save.modData.adaptive_trainers.state.leagueRun, nil,
    version .. " later-member activation fails closed to vanilla")
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
  save.player.map = "BRUNOS_ROOM"
  Runtime.emit("save.writing", { save = save, meta = save.meta })
  T.eq(save.modData.adaptive_trainers.state.leagueRun, leagueRun,
    version .. " ordinary save between League members preserves the run")
  local savedBytes = SaveSerializer.encode(save.modData)
  run.release()

  local reload = T.sdk.loadMod(modPath, { data = fixture_data() })
  local reloadSave = save_for(version, assert(SaveSerializer.decode(savedBytes)))
  local reloadGame = bind(reload, reloadSave)
  Runtime.emit("save.loaded", { save = reloadSave, meta = reloadSave.meta })
  T.check(reloadSave.modData.adaptive_trainers.state.leagueRun ~= nil,
    version .. " ordinary load between League members preserves the run")
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

  -- record_hall_of_fame applies the post-game home marker, then Game:writeSave
  -- captures the still-live HALL_OF_FAME map before emitting save.writing.
  -- The completed run must be absent from that autosave so the title-screen
  -- soft reset cannot resurrect it.
  reloadSave.hallOfFame = { { { species = "FIXMON_A", level = 70 } } }
  reloadSave.postGameHomeOk = true
  reloadSave.player.map = "HALL_OF_FAME"
  Runtime.emit("save.writing", { save = reloadSave,
    meta = reloadSave.meta })
  T.eq(reloadSave.modData.adaptive_trainers.state.leagueRun, nil,
    version .. " Hall of Fame autosave clears the completed run")
  local completedCounter = reloadSave.modData.adaptive_trainers.state
    .leagueRunCounter

  -- The persisted save is relocated home immediately after Game:writeSave.
  -- A normal CONTINUE/load must keep the run cleared and the next Lorelei
  -- entry must advance the same counter rather than reusing the old run.
  local postGameBytes = SaveSerializer.encode(reloadSave.modData)
  reload.release()
  local postGame = T.sdk.loadMod(modPath, { data = fixture_data() })
  local postGameSave = save_for(version,
    assert(SaveSerializer.decode(postGameBytes)))
  postGameSave.player.map = "PALLET_TOWN"
  postGameSave.postGameHomeOk = true
  postGameSave.hallOfFame = reloadSave.hallOfFame
  local postGameGame = bind(postGame, postGameSave)
  Runtime.emit("save.loaded", { save = postGameSave,
    meta = postGameSave.meta })
  T.eq(postGameSave.modData.adaptive_trainers.state.leagueRun, nil,
    version .. " post-game home load does not restore a completed run")
  postGameGame.overworld.map.id = "LORELEIS_ROOM"
  postGameSave.player.map = "LORELEIS_ROOM"
  Runtime.emit("map.entered", { mapId = "LORELEIS_ROOM",
    fromMapId = "INDIGO_PLATEAU_LOBBY", via = "warp" })
  local postGameRoot = postGameSave.modData.adaptive_trainers.state
  T.eq(postGameRoot.leagueRunCounter, completedCounter + 1,
    version .. " post-game Lorelei entry advances the run counter")
  T.check(postGameRoot.leagueRun.id ~= restoredRun.id,
    version .. " post-game Lorelei entry creates a distinct run")
  postGame.release()

  -- A legacy/current save loaded at home with a stale League run also
  -- reconciles through the public save.loaded lifecycle. This is the
  -- recovery path for saves written before the completion hook existed.
  local stale = T.sdk.loadMod(modPath, { data = fixture_data() })
  local staleSave = save_for(version,
    assert(SaveSerializer.decode(savedBytes)))
  staleSave.player.map = "PALLET_TOWN"
  staleSave.postGameHomeOk = true
  staleSave.hallOfFame = reloadSave.hallOfFame
  bind(stale, staleSave)
  Runtime.emit("save.loaded", { save = staleSave, meta = staleSave.meta })
  T.eq(staleSave.modData.adaptive_trainers.state.leagueRun, nil,
    version .. " post-game home load clears a stale completed run")
  stale.release()

  -- Continue the ordinary blackout coverage in a fresh run: leaving the
  -- League still clears state independently of Hall-of-Fame completion.
  local blackout = T.sdk.loadMod(modPath, { data = fixture_data() })
  local blackoutSave = save_for(version)
  bind(blackout, blackoutSave)
  Runtime.emit("map.entered", { mapId = "LORELEIS_ROOM",
    fromMapId = "INDIGO_PLATEAU_LOBBY", via = "warp" })
  local blackoutRun = blackoutSave.modData.adaptive_trainers.state.leagueRun

  Runtime.emit("map.exited", { mapId = "LORELEIS_ROOM",
    toMapId = "INDIGO_PLATEAU_LOBBY" })
  T.eq(blackoutSave.modData.adaptive_trainers.state.leagueRun, nil,
    version .. " blackout/League exit clears the run")
  Runtime.emit("map.entered", { mapId = "LORELEIS_ROOM",
    fromMapId = "INDIGO_PLATEAU_LOBBY", via = "warp" })
  local nextRoot = blackoutSave.modData.adaptive_trainers.state
  T.eq(nextRoot.leagueRunCounter, 2,
    version .. " re-entry advances the run counter")
  T.check(nextRoot.leagueRun.id ~= blackoutRun.id,
    version .. " re-entry creates a distinct run identity")
  blackout.release()
end

T.finish("adaptive trainers League persistence")
