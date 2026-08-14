package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")
local SaveSerializer = require("src.core.SaveSerializer")

local modPath = assert(os.getenv("ADAPTIVE_TRAINERS_PATH"),
  "ADAPTIVE_TRAINERS_PATH must name the mod relative to Gen1Recomp")

local function species(id, stats, evolutions)
  return {
    id = id,
    types = { id == "RATTATA" and "NORMAL" or "FLYING" },
    baseStats = stats,
    evolutions = evolutions or {},
    learnset = {}, tmhm = {}, level1Moves = {},
  }
end

local function fixture_data()
  local data = T.fixtures.fresh()
  data.pokemon.PIDGEY = species("PIDGEY",
    { hp = 40, attack = 45, defense = 40, speed = 56, special = 35 }, {
      { method = "LEVEL", level = 18, species = "PIDGEOTTO" },
    })
  data.pokemon.PIDGEOTTO = species("PIDGEOTTO",
    { hp = 63, attack = 60, defense = 55, speed = 71, special = 50 }, {
      { method = "LEVEL", level = 36, species = "PIDGEOT" },
    })
  data.pokemon.PIDGEOT = species("PIDGEOT",
    { hp = 83, attack = 80, defense = 75, speed = 91, special = 70 })
  data.pokemon.SPEAROW = species("SPEAROW",
    { hp = 40, attack = 60, defense = 30, speed = 70, special = 31 }, {
      { method = "LEVEL", level = 20, species = "FEAROW" },
    })
  data.pokemon.FEAROW = species("FEAROW",
    { hp = 65, attack = 90, defense = 65, speed = 100, special = 61 })
  data.pokemon.RATTATA = species("RATTATA",
    { hp = 30, attack = 56, defense = 35, speed = 72, special = 25 }, {
      { method = "LEVEL", level = 20, species = "RATICATE" },
    })
  data.pokemon.RATICATE = species("RATICATE",
    { hp = 55, attack = 81, defense = 60, speed = 97, special = 50 })
  data.encounters.FIX_ROUTE = { grass = { rate = 25, slots = {
    { level = 5, species = "SPEAROW", weight = 1 },
    { level = 4, species = "RATTATA", weight = 1 },
  } } }
  data.trainers.OPP_YOUNGSTER = {
    id = "OPP_YOUNGSTER", index = 2, name = "YOUNGSTER", baseMoney = 15,
    parties = { { { species = "PIDGEY", level = 8 } } },
  }
  data.maps.FIX_ROUTE.objects = {
    { index = 1, name = "FIX_ROUTE_obj_1", trainerClass = "OPP_YOUNGSTER",
      trainerParty = 1 },
    { index = 2, name = "FIX_ROUTE_obj_2", trainerClass = "OPP_YOUNGSTER",
      trainerParty = 1 },
  }
  return data
end

local function save_for(version, modData)
  return {
    version = version,
    meta = { playthroughId = "phase-a-" .. version },
    player = {
      map = "FIX_ROUTE", id = 4242, name = "RED", rival = "BLUE",
    },
    party = { { species = "RATTATA", level = 14, hp = 0 } },
    playTime = 1000,
    modData = modData or { adaptive_trainers = {} },
  }
end

local function engage(run, game)
  Runtime.emit("world.trainer_engaged", {
    npc = { id = "FIX_ROUTE_obj_1", def = { index = 1 } },
    trainerClass = "OPP_YOUNGSTER",
    partyIndex = 1,
  })
  local vanilla = game.data.trainers.OPP_YOUNGSTER.parties[1]
  return Runtime.call("trainer.party", function(_, _, party) return party end,
    "OPP_YOUNGSTER", 1, vanilla)
end

local firstEncoded
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local run = T.sdk.loadMod(modPath, { data = fixture_data() })
  local game = {
    data = run.data,
    save = save_for(version),
    overworld = {
      isOverworld = true,
      map = { id = "FIX_ROUTE" },
      player = { cellX = 5, cellY = 9, facing = "down" },
    },
  }
  run.loader.game = game
  run.loader.modSave = game.save.modData
  Runtime.emit("game.ready", { game = game })

  local party = engage(run, game)
  T.eq(#party, 1, version .. " keeps the vanilla party size")
  T.check(party[1].species == "PIDGEY" or party[1].species == "SPEAROW",
    version .. " selects only an eligible runtime-registry line")
  T.check(party[1].level >= 8,
    version .. " never scales the initial slot below vanilla")

  local bucket = game.save.modData.adaptive_trainers
  local root = bucket and bucket.state
  T.check(type(root) == "table" and root.schema == 1,
    version .. " stores the authoritative schema under mod.save")
  local key = version .. "|FIX_ROUTE|OPP_YOUNGSTER|1|npc:FIX_ROUTE_obj_1"
  local state = root and root.trainers[key]
  T.check(type(state) == "table" and #state.owned == 1,
    version .. " persists the concrete trainer individual")
  if state then
    T.eq(state.owned[1].species, party[1].species,
      version .. " party output is materialized from persisted state")
  end

  local encoded = SaveSerializer.encode({ party = party, state = state })
  for attempt = 1, 100 do
    local repeated = engage(run, game)
    T.eq(SaveSerializer.encode({ party = repeated, state = root.trainers[key] }),
      encoded, version .. " is byte-equivalent on rerun " .. attempt)
  end
  if version == "red" then firstEncoded = encoded end

  local savedBytes = SaveSerializer.encode(game.save.modData)
  run.release()

  local reloadedData = fixture_data()
  local reloaded = T.sdk.loadMod(modPath, { data = reloadedData })
  local decoded = assert(SaveSerializer.decode(savedBytes))
  local reloadGame = {
    data = reloaded.data,
    save = save_for(version, decoded),
    overworld = {
      isOverworld = true,
      map = { id = "FIX_ROUTE" },
      player = { cellX = 5, cellY = 9, facing = "down" },
    },
  }
  reloaded.loader.game = reloadGame
  reloaded.loader.modSave = reloadGame.save.modData
  Runtime.emit("game.ready", { game = reloadGame })
  local afterReload = engage(reloaded, reloadGame)
  local reloadState = reloadGame.save.modData.adaptive_trainers.state.trainers[key]
  T.eq(SaveSerializer.encode({ party = afterReload, state = reloadState }), encoded,
    version .. " save/reload cannot reroll the logical encounter")
  reloaded.release()
end

local none = T.sdk.loadNone({ data = fixture_data() })
local vanilla = none.data.trainers.OPP_YOUNGSTER.parties[1]
local untouched = Runtime.call("trainer.party", function(_, _, party) return party end,
  "OPP_YOUNGSTER", 1, vanilla)
T.check(untouched == vanilla,
  "with the mod disabled the public trainer hook preserves vanilla identity")
none.release()

T.check(type(firstEncoded) == "string", "the integration produced evidence")
T.finish("adaptive trainers phase A runtime")
