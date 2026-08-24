package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Logger = require("src.core.Logger")
local Runtime = require("src.mods.Runtime")
local SaveSerializer = require("src.core.SaveSerializer")

local modPath = assert(os.getenv("ADAPTIVE_TRAINERS_PATH"),
  "ADAPTIVE_TRAINERS_PATH must name the mod relative to Gen1Recomp")

local function seed_info_count()
  local count = 0
  for _, line in ipairs(Logger.history) do
    if line:find("[adaptive_trainers] choice=", 1, true) then
      count = count + 1
    end
  end
  return count
end

for _, value in ipairs({ false, "true", "1", 1 }) do
  local run = T.sdk.loadMod(modPath, { dev = value })
  T.eq(run.data.commands["adaptive_trainers:debug"], nil,
    "only boolean true registers the diagnostics command")
  T.eq(run.data.screens.AdaptiveTrainerDiagnostics, nil,
    "only boolean true registers the diagnostics screen")
  T.eq(run.loader.exports.adaptive_trainers.debug, nil,
    "production exposes no diagnostics export")
  T.eq(#run.loader:legacyReport("adaptive_trainers"), 0,
    "production diagnostics use no legacy compatibility surface")
  run.release()
end

local production = T.sdk.loadMod(modPath)
T.eq(production.data.commands["adaptive_trainers:debug"], nil,
  "an older or production engine with nil/false developer state is inert")
T.eq(production.data.screens.AdaptiveTrainerDiagnostics, nil,
  "production registers no debug screen")
T.eq(seed_info_count(), 0,
  "production emits no Adaptive Trainers seed-choice info logs")
production.release()

local run = T.sdk.loadMod(modPath, { dev = true })
local command = run.data.commands["adaptive_trainers:debug"]
T.check(type(command) == "function",
  "developer mode registers adaptive_trainers:debug")
T.check(type(run.data.screens.AdaptiveTrainerDiagnostics) == "table",
  "developer mode registers the read-only diagnostics screen")
T.eq(run.loader.exports.adaptive_trainers.debug, nil,
  "developer mode still exposes no diagnostics export")
T.eq(#run.loader:legacyReport("adaptive_trainers"), 0,
  "developer activation uses only the public boolean")
if type(command) ~= "function" then
  run.release()
  T.finish("adaptive trainers runtime diagnostics")
end

local root = {
  seedHi = 101,
  seedLo = 202,
  trainers = {
    trainer = {
      identityKey = "trainer",
      classId = "OPP_BUG_CATCHER",
      mapId = "ROUTE_3",
      lastBattleAt = 900,
      battleCount = 2,
      activeIds = { "trainer:1" },
      owned = { { id = "trainer:1", lineId = "CATERPIE_LINE",
        species = "BUTTERFREE", level = 12, moves = { "TACKLE" } } },
    },
  },
  bossAttempts = {
    BROCK = {
      version = "red",
      attemptCounter = 1,
      strategyId = "ROCK_WALL",
      referenceLevels = { 14, 12 },
      targetLevels = { 15, 12 },
      party = { { id = "boss:1", lineId = "ONIX_LINE",
        species = "ONIX", level = 15, moves = { "BIDE" } } },
    },
  },
  leagueRunCounter = 1,
  leagueRun = {
    id = "1:12345678",
    version = "blue",
    birdPair = { member = "LORELEI", species = "ARTICUNO" },
    memberSeeds = { LORELEI = 10 },
    generatedParties = {},
    memberStrategies = {},
  },
  rival = {
    version = "yellow",
    encounterIndex = 2,
    journeySeed = { hi = 303, lo = 404 },
    activeIds = { "rival:starter" },
    owned = { { id = "rival:starter", lineId = "EEVEE_LINE",
      species = "EEVEE", level = 10, acquiredAt = 0,
      originMap = "OAKS_LAB", attachment = 100, useCount = 2 } },
    journeyEvents = {},
    pathFlags = {},
  },
  yellowRival = {},
}
run.loader.modSave.adaptive_trainers = { state = root }

local pushed = {}
local input = { wasPressed = function() return false end }
local game = {
  data = run.data,
  input = input,
  stack = {
    push = function(_, screen) pushed[#pushed + 1] = screen end,
    pop = function() end,
  },
}
local before = SaveSerializer.encode(run.loader.modSave.adaptive_trainers)

local standard = command({ game = game }, "standard", "trainer")
T.eq(standard.kind, "standard", "standard scope selects an identity")
local boss = command({ game = game }, "boss", "BROCK")
T.eq(boss.kind, "boss", "boss scope selects a boss id")
local rival = command({ game = game }, "rival")
T.eq(rival.kind, "rival", "rival scope selects the persisted journey")
local league = command({ game = game }, "league")
T.eq(league.kind, "league", "league scope selects the persisted run")
T.eq(#pushed, 4, "every valid scope opens one diagnostics screen")
for index, screen in ipairs(pushed) do
  T.eq(screen.screenId, "AdaptiveTrainerDiagnostics",
    "valid scope " .. index .. " opens the registered screen")
  T.eq(screen.projection, nil,
    "screen " .. index .. " retains rows rather than the projection")
end
local standardMoveRow = false
for _, row in ipairs(pushed[1].rows) do
  if row == "move TACKLE: <unavailable>" then standardMoveRow = true end
end
T.check(standardMoveRow,
  "runtime standard diagnostics retain every selected move score field")

standard.roster[1].species = "MUTATED"
boss.party[1].level = 100
rival.owned[1].attachment = 0
league.birdPair.species = "MOLTRES"
T.eq(root.trainers.trainer.owned[1].species, "BUTTERFREE",
  "standard projection is detached from mod.save")
T.eq(root.bossAttempts.BROCK.party[1].level, 15,
  "boss projection is detached from mod.save")
T.eq(root.rival.owned[1].attachment, 100,
  "Rival projection is detached from mod.save")
T.eq(root.leagueRun.birdPair.species, "ARTICUNO",
  "League projection is detached from mod.save")

local invalid = {
  { nil },
  { "standard" },
  { "standard", "missing" },
  { "boss" },
  { "boss", "missing" },
  { "rival", "extra" },
  { "league", "extra" },
  { "unknown" },
}
for index, args in ipairs(invalid) do
  local projection, err = command({ game = game }, unpack(args))
  T.eq(projection, nil, "invalid command " .. index .. " returns no projection")
  T.check(type(err) == "string" and err ~= "",
    "invalid command " .. index .. " explains the rejected target")
end
T.eq(#pushed, 4, "invalid and missing targets open no screen")
T.eq(SaveSerializer.encode(run.loader.modSave.adaptive_trainers), before,
  "diagnostics never initialize, migrate, reconcile, mutate, or persist state")

run.loader.modSave.adaptive_trainers = {}
local absent, absentErr = command({ game = game }, "rival")
T.eq(absent, nil, "missing state remains absent")
T.check(type(absentErr) == "string",
  "missing state is reported without initialization")
T.eq(run.loader.modSave.adaptive_trainers.state, nil,
  "missing state is not initialized by diagnostics")

run.release()

local function species(id, stats, evolutions)
  return {
    id = id,
    types = { id == "RATTATA" and "NORMAL" or "FLYING" },
    baseStats = stats,
    evolutions = evolutions or {},
    learnset = {},
    tmhm = {},
    level1Moves = {},
  }
end

local function choice_data()
  local data = T.fixtures.fresh()
  data.pokemon.PIDGEY = species("PIDGEY",
    { hp = 40, attack = 45, defense = 40, speed = 56, special = 35 })
  data.pokemon.SPEAROW = species("SPEAROW",
    { hp = 40, attack = 60, defense = 30, speed = 70, special = 31 })
  data.pokemon.RATTATA = species("RATTATA",
    { hp = 30, attack = 56, defense = 35, speed = 72, special = 25 })
  data.encounters.FIX_ROUTE = { grass = { rate = 25, slots = {
    { level = 5, species = "SPEAROW" },
  } } }
  data.trainers.OPP_YOUNGSTER = {
    id = "OPP_YOUNGSTER",
    index = 2,
    name = "YOUNGSTER",
    baseMoney = 15,
    parties = { { { species = "PIDGEY", level = 8 } } },
  }
  data.maps.FIX_ROUTE.objects = {
    { index = 1, name = "FIX_ROUTE_obj_1",
      trainerClass = "OPP_YOUNGSTER", trainerParty = 1 },
  }
  return data
end

local function choice_game(data, modData)
  return {
    data = data,
    save = {
      version = "red",
      meta = { playthroughId = "debug-choice-log" },
      player = { map = "FIX_ROUTE", id = 4242, name = "RED",
        rival = "BLUE" },
      party = { { species = "RATTATA", level = 14, hp = 0 } },
      playTime = 1000,
      modData = modData or { adaptive_trainers = {} },
    },
  }
end

local function engage(game)
  Runtime.emit("world.trainer_engaged", {
    npc = { id = "FIX_ROUTE_obj_1", def = { index = 1 } },
    trainerClass = "OPP_YOUNGSTER",
    partyIndex = 1,
  })
  return Runtime.call("trainer.party", function(_, _, party) return party end,
    "OPP_YOUNGSTER", 1,
    game.data.trainers.OPP_YOUNGSTER.parties[1])
end

local function choices_since(index)
  local out = {}
  for position = index + 1, #Logger.history do
    local line = Logger.history[position]
    if line:find("[adaptive_trainers] choice=", 1, true) then
      out[#out + 1] = line
    end
  end
  return out
end

local choiceStart = #Logger.history
local choiceRun = T.sdk.loadMod(modPath, { dev = true, data = choice_data() })
local firstGame = choice_game(choiceRun.data)
choiceRun.loader.game = firstGame
choiceRun.loader.modSave = firstGame.save.modData
Runtime.emit("game.ready", { game = firstGame })
engage(firstGame)
local firstChoices = choices_since(choiceStart)
T.eq(firstChoices[1],
  '[info] [adaptive_trainers] choice=trainer-roster seed=trainer-init parts=["red|FIX_ROUTE|OPP_YOUNGSTER|1"]',
  "developer runtime emits exact choice and seed content at materialization")
local materializedCount = #firstChoices
T.check(materializedCount >= 1,
  "developer runtime emits at least the standard roster choice")
engage(firstGame)
T.eq(#choices_since(choiceStart), materializedCount,
  "runtime rerun does not reconstruct persisted choice logs")
local saved = SaveSerializer.encode(firstGame.save.modData)
choiceRun.release()

local reloadStart = #Logger.history
local reloadRun = T.sdk.loadMod(modPath, { dev = true, data = choice_data() })
local reloadedGame = choice_game(reloadRun.data,
  assert(SaveSerializer.decode(saved)))
reloadRun.loader.game = reloadedGame
reloadRun.loader.modSave = reloadedGame.save.modData
Runtime.emit("game.ready", { game = reloadedGame })
engage(reloadedGame)
T.eq(#choices_since(reloadStart), 0,
  "serialized reload does not reconstruct persisted choice logs")
reloadRun.release()

T.finish("adaptive trainers runtime diagnostics")
