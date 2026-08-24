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

run.data.moves.TACKLE = { id = "TACKLE", type = "NORMAL", power = 35,
  accuracy = 95, pp = 35, effect = "NO_ADDITIONAL_EFFECT" }
run.data.pokemon.BUTTERFREE = {
  id = "BUTTERFREE", types = { "BUG", "FLYING" },
  level1Moves = { "TACKLE" }, learnset = {}, tmhm = {}, evolutions = {},
}
run.data.pokemon.CATERPIE = {
  id = "CATERPIE", types = { "BUG" }, level1Moves = { "TACKLE" },
  learnset = {}, tmhm = {}, evolutions = {},
}
run.data.pokemon.GEODUDE = {
  id = "GEODUDE", types = { "ROCK", "GROUND" },
  level1Moves = { "TACKLE" }, learnset = {}, tmhm = {},
  evolutions = { { method = "LEVEL", level = 20, species = "GRAVELER" } },
}
run.data.encounters.ROUTE_3 = { grass = { slots = {
  { species = "CATERPIE", level = 5, weight = 1 },
} } }

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
      vanillaTop = 8,
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
  save = {
    version = "red",
    badgeCount = 1,
    playTime = 7200,
    player = { map = "ROUTE_3" },
    party = { { species = "RATTATA", level = 20 } },
  },
  input = input,
  stack = {
    push = function(_, screen) pushed[#pushed + 1] = screen end,
    pop = function() end,
  },
}
local before = SaveSerializer.encode(run.loader.modSave.adaptive_trainers)
local runtimeBefore = SaveSerializer.encode(game.save)
local registryBefore = SaveSerializer.encode({
  butterfree = game.data.pokemon.BUTTERFREE,
  caterpie = game.data.pokemon.CATERPIE,
  geodude = game.data.pokemon.GEODUDE,
  tackle = game.data.moves.TACKLE,
  route3 = game.data.encounters.ROUTE_3,
})

local standard = command({ game = game }, "standard", "trainer")
T.eq(standard.kind, "standard", "standard scope selects an identity")
T.eq(standard.ceiling, 20,
  "runtime standard diagnostics supply the exact current ceiling")
T.check(type(standard.catchProbability) == "number"
    and standard.catchProbability > 0 and standard.catchProbability <= 1,
  "runtime standard diagnostics supply the current catch probability")
T.same(standard.ecologyCandidates, { "CATERPIE_LINE" },
  "runtime standard diagnostics supply exact current ecology candidates")
T.check(type(standard.moveScores.TACKLE) == "number",
  "runtime standard diagnostics supply selected move scores")
local boss = command({ game = game }, "boss", "BROCK")
T.eq(boss.kind, "boss", "boss scope selects a boss id")
T.eq(boss.poolCandidates[1], "GEODUDE_LINE",
  "runtime boss diagnostics supply the exact admitted pool candidate")
T.eq(boss.rejectedConstraints[1], "RHYHORN_LINE:missing-runtime-species",
  "runtime boss diagnostics supply a specific current rejection reason")
T.eq(boss.historicalRejectionsAvailable, false,
  "runtime boss diagnostics label historical rejection trace unavailable")
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
local retainedRows = {}
for index, screen in ipairs(pushed) do
  retainedRows[index] = table.concat(screen.rows, "\n")
end

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
for index, screen in ipairs(pushed) do
  T.eq(table.concat(screen.rows, "\n"), retainedRows[index],
    "screen " .. index .. " remains detached after source mutation")
end

local invalid = {
  { nil },
  { "standard" },
  { "standard", "missing" },
  { "standard", "trainer", "extra" },
  { "boss" },
  { "boss", "missing" },
  { "boss", "BROCK", "extra" },
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
T.eq(SaveSerializer.encode(game.save), runtimeBefore,
  "current evidence reads public runtime inputs without mutating them")
T.eq(SaveSerializer.encode({
    butterfree = game.data.pokemon.BUTTERFREE,
    caterpie = game.data.pokemon.CATERPIE,
    geodude = game.data.pokemon.GEODUDE,
    tackle = game.data.moves.TACKLE,
    route3 = game.data.encounters.ROUTE_3,
  }), registryBefore,
  "current evidence reads runtime registries without mutating them")

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
    learnset = { { level = 1, move = "TACKLE" } },
    tmhm = {},
    level1Moves = { "TACKLE" },
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
  data.moves.TACKLE = { id = "TACKLE", type = "NORMAL", power = 35,
    accuracy = 95, pp = 35, effect = "NO_ADDITIONAL_EFFECT" }
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
local choiceState = firstGame.save.modData.adaptive_trainers.state.trainers
  ["red|FIX_ROUTE|OPP_YOUNGSTER|1"]
local firstMon = choiceState.owned[1]
T.same(firstChoices, {
  '[info] [adaptive_trainers] choice=trainer-roster seed=trainer-init parts=["red|FIX_ROUTE|OPP_YOUNGSTER|1"]',
  ('[info] [adaptive_trainers] choice=trainer-moves seed=trainer-move-role-v1 parts=[%d,"%s","TACKLE"]'):format(firstMon.roleSeed, firstMon.id),
}, "real standard initial site emits exact deterministic order and content")

choiceState.lastResult = "lose"
choiceState.battleCount = 1
choiceState.lastBattleAt = firstGame.save.playTime - 901
choiceState.lastGrowthBattleCount = 0
choiceState.lastCatchBattleCount = 0
engage(firstGame)
local afterLoss = choices_since(choiceStart)
T.same(afterLoss, {
  firstChoices[1],
  firstChoices[2],
  ('[info] [adaptive_trainers] choice=trainer-growth-focus seed=trainer-growth parts=["%s",1,"%s"]'):format(choiceState.identityKey, firstMon.id),
  ('[info] [adaptive_trainers] choice=trainer-growth-rounding seed=trainer-growth parts=["%s",1,"%s"]'):format(choiceState.identityKey, firstMon.id),
  ('[info] [adaptive_trainers] choice=trainer-no-catch seed=trainer-catch parts=["%s",1]'):format(choiceState.identityKey),
}, "real standard loss sites emit exact growth and no-catch order/content")
local materializedCount = #afterLoss
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
