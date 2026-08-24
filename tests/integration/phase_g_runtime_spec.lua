package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Runtime = assert(package.loaded["src.mods.Runtime"],
  "the public SDK harness must own the runtime test bus")

local modPath = assert(os.getenv("ADAPTIVE_TRAINERS_PATH"),
  "ADAPTIVE_TRAINERS_PATH must name the mod relative to Gen1Recomp")
local GENERATED_ASSETS = "assets/" .. "generated/"

local EVOLUTIONS = {
  { "GOLBAT", "CROBAT" }, { "GLOOM", "BELLOSSOM" },
  { "POLIWHIRL", "POLITOED" }, { "SLOWPOKE", "SLOWKING" },
  { "ONIX", "STEELIX" }, { "SCYTHER", "SCIZOR" },
  { "SEADRA", "KINGDRA" }, { "PORYGON", "PORYGON2" },
  { "CHANSEY", "BLISSEY" },
}

local MOVES = {
  IRON_TAIL = { "STEEL", 100, 75, 15, "physical" },
  METAL_CLAW = { "STEEL", 50, 95, 35, "physical" },
  STEEL_WING = { "STEEL", 70, 90, 25, "physical" },
  RAIN_DANCE = { "WATER", 0, 100, 5, "status" },
  SUNNY_DAY = { "FIRE", 0, 100, 5, "status" },
  SANDSTORM = { "ROCK", 0, 100, 10, "status" },
  SLUDGE_BOMB = { "POISON", 90, 100, 10, "physical" },
  SHADOW_BALL = { "GHOST", 80, 100, 15, "physical" },
}

local MATCHUPS = {
  { "STEEL", "ICE", 20 }, { "STEEL", "ROCK", 20 },
  { "STEEL", "FIRE", 5 }, { "STEEL", "WATER", 5 },
  { "STEEL", "ELECTRIC", 5 }, { "STEEL", "STEEL", 5 },
  { "NORMAL", "STEEL", 5 }, { "GRASS", "STEEL", 5 },
  { "ICE", "STEEL", 5 }, { "FLYING", "STEEL", 5 },
  { "PSYCHIC_TYPE", "STEEL", 5 }, { "BUG", "STEEL", 5 },
  { "ROCK", "STEEL", 5 }, { "GHOST", "STEEL", 5 },
  { "DRAGON", "STEEL", 5 }, { "POISON", "STEEL", 0 },
  { "FIRE", "STEEL", 20 }, { "FIGHTING", "STEEL", 20 },
  { "GROUND", "STEEL", 20 },
}

local function read_registry(records)
  return {
    get = function(_, id) return records[id] end,
    has = function(_, id) return records[id] ~= nil end,
    each = function()
      local ids = {}
      for id in pairs(records) do ids[#ids + 1] = id end
      table.sort(ids)
      local index = 0
      return function()
        index = index + 1
        local id = ids[index]
        if id then return id, records[id] end
      end
    end,
  }
end

local function gen1_species(id, types)
  return { id = id, dex = 1, name = id, types = types or { "NORMAL" },
    baseStats = { hp = 60, attack = 60, defense = 60,
      speed = 60, special = 60 }, catchRate = 45, baseExp = 80,
    evolutions = {}, learnset = {}, level1Moves = { "FIX_TACKLE" },
    tmhm = {}, growthRate = "MEDIUM_SLOW" }
end

local function active_fixture()
  local data = T.fixtures.fresh()
  for _, row in ipairs(EVOLUTIONS) do
    data.pokemon[row[1]] = gen1_species(row[1])
  end
  data.pokemon.MAGNEMITE = gen1_species("MAGNEMITE", { "ELECTRIC" })
  data.pokemon.MAGNETON = gen1_species("MAGNETON", { "ELECTRIC" })
  return data
end

local function gold_view(mode, assetCalls)
  if mode == "none" then return nil, "not_imported" end
  if mode == "malformed" then error("invalid Gold dataset cache", 0) end
  local pokemon, moves, chart = {}, {}, {}
  for _, row in ipairs(EVOLUTIONS) do
    pokemon[row[1]] = {
      id = row[1], name = row[1], types = { "NORMAL" },
      evolutions = { { method = "LEVEL", level = 36, into = row[2] } },
    }
    pokemon[row[2]] = {
      id = row[2], dex = 200, name = row[2], types = { "NORMAL" },
      baseStats = { hp = 60, attack = 70, defense = 80, speed = 50,
        specialAttack = 45, specialDefense = 65 },
      catchRate = 45, baseExp = 120, growthRate = "MEDIUM_FAST",
      levelMoves = { { level = 1, move = "FIX_TACKLE" },
        { level = 20, move = "IRON_TAIL" } },
      tmhm = { "IRON_TAIL" }, evolutions = {}, picSize = 6,
      spriteFront = GENERATED_ASSETS .. "battle/front/" .. row[2] .. ".png",
      spriteBack = GENERATED_ASSETS .. "battle/back/" .. row[2] .. ".png",
    }
  end
  for id, row in pairs(MOVES) do
    moves[id] = { id = id, name = id, type = row[1], power = row[2],
      accuracy = row[3], pp = row[4], category = row[5],
      effect = "NO_ADDITIONAL_EFFECT" }
  end
  if mode == "partial" then moves.SHADOW_BALL = nil end
  chart.STEEL = { id = "STEEL", name = "STEEL", category = "physical" }
  for _, row in ipairs(MATCHUPS) do
    chart[row[1] .. ">" .. row[2]] = {
      attacker = row[1], defender = row[2], multiplier = row[3] }
  end
  local assets = {
    dataset = "gold",
    path = function(self, path)
      if self.dataset ~= "gold" then error("unbound asset facade", 0) end
      if mode == "asset_error" then error("broken asset facade", 0) end
      assetCalls[#assetCalls + 1] = path
      if mode == "asset_nil" then return nil end
      return "datasets/gold/" .. path
    end,
  }
  if mode ~= "missing_info" then
    assets.info = function(self, path)
      if self.dataset ~= "gold" then error("unbound asset facade", 0) end
      if mode == "info_error" then error("broken asset info", 0) end
      if mode == "info_nil" then return nil end
      if mode == "info_non_file" then return { type = "directory" } end
      return { type = "file", size = #path }
    end
  end
  return {
    version = "gold", generation = 2,
    content = {
      pokemon = read_registry(pokemon),
      moves = read_registry(moves),
      type_chart = read_registry(chart),
    },
    assets = assets,
  }
end

local function load_with_gold(mode, data)
  local assetCalls = {}
  package.loaded["src.mods.DatasetViews"] = {
    new = function()
    return { open = function(_, version)
      if version ~= "gold" then return nil, "unexpected_version" end
      return gold_view(mode, assetCalls)
    end }
    end,
  }
  local ok, result = pcall(T.sdk.loadMod, modPath, {
    data = data or active_fixture(),
  })
  if not ok then error(result, 0) end
  result.assetCalls = assetCalls
  return result
end

-- Exercise the engine exactly as checked out before installing any dataset
-- test double. Current upstream has no mod.datasets yet; dataset feature
-- branches expose the service but have no imported Gold cache by default.
local baseline = T.sdk.loadMod(modPath, { data = active_fixture() })
T.eq(#baseline.errors, 0,
  "the real engine surface loads the Phase G entrypoint fail-closed")
local baselineStatus = baseline.loader.exports.adaptive_trainers.status()
local hasDatasetService = baseline.loader.datasetViews ~= nil
local baselineReason = hasDatasetService
  and "not_imported" or "dataset_api_unavailable"
T.eq(baselineStatus.phase, "G", "the real engine reports Phase G")
T.eq(baselineStatus.kantoPlus, false,
  "the real engine without Gold capability remains Kanto-only")
T.eq(baselineStatus.sandResidual, false,
  "the real engine installs no partial sand authority")
T.eq(baselineStatus.solarBeamSkip, false,
  "the real engine installs no partial SolarBeam authority")
T.eq(baselineStatus.reason, baselineReason,
  "the real engine reports its exact dataset capability boundary")
T.eq(baselineStatus.datasetReason, baselineReason,
  "the dataset diagnostic matches the exact live boundary")
T.same(baseline.data.pokemon.MAGNEMITE.types, { "ELECTRIC" },
  "the real no-capability boot makes no active registry overlay")
T.eq(baseline.data.move_effects.ADAPTIVE_RAIN_EFFECT, nil,
  "the real no-capability boot installs no partial weather behavior")
baseline.release()

if not hasDatasetService then
  print("phase G dataset cases skipped: public dataset service absent")
  T.finish("adaptive trainers phase G runtime")
  return
end

for _, mode in ipairs({ "none", "partial", "malformed", "asset_nil",
    "asset_error", "missing_info", "info_nil", "info_non_file",
    "info_error" }) do
  local run = load_with_gold(mode)
  T.eq(#run.errors, 0, mode .. " Gold source loads fail-closed")
  local status = run.loader.exports.adaptive_trainers.status()
  T.eq(status.kantoPlus, false,
    mode .. " Gold source cannot activate the sidecar")
  T.same(run.data.pokemon.MAGNEMITE.types, { "ELECTRIC" },
    mode .. " Gold source makes no active registry overlay")
  T.eq(run.data.move_effects.ADAPTIVE_RAIN_EFFECT, nil,
    mode .. " Gold source installs no partial weather behavior")
  if mode == "partial" then
    T.eq(status.reason, "incomplete_gold",
      "a non-nil partial Gold view reports incomplete capability")
    T.eq(status.datasetReason, "incomplete_gold",
      "a non-nil partial Gold view has a self-describing dataset diagnostic")
  end
  run.release()
end

local run = load_with_gold("full")
T.eq(#run.errors, 0, "complete Gold view loads through the public SDK")
local status = run.loader.exports.adaptive_trainers.status()
T.eq(status.phase, "G", "the runtime status reports the integrated phase")
T.eq(status.kantoPlus, true, "complete Gold capability activates Kanto+")
T.eq(status.sandResidual, true,
  "complete admission enables lifecycle-safe sand residuals")
T.eq(status.solarBeamSkip, true,
  "complete admission enables the SolarBeam charge seam")

for _, row in ipairs(EVOLUTIONS) do
  T.check(run.data.pokemon[row[2]] ~= nil,
    "runtime registers Gold continuation " .. row[2])
end
T.same(run.data.pokemon.MAGNEMITE.types, { "ELECTRIC", "STEEL" },
  "runtime patches Magnemite to Electric/Steel")
T.eq(run.data.pokemon.STEELIX.spriteFront,
  "datasets/gold/" .. GENERATED_ASSETS .. "battle/front/STEELIX.png",
  "runtime binds translated sprites through Gold assets:path")
T.check(#run.assetCalls >= 18,
  "all translated continuation sprites resolve inside the Gold namespace")
T.eq(run.data.moves.IRON_TAIL.effect, "ADAPTIVE_IRON_TAIL_EFFECT",
  "runtime installs the authored Iron Tail effect")

local sun = { tokens = {} }
run.data.move_effects.ADAPTIVE_SUN_EFFECT.run({ field = sun })
local charge = Runtime.call("battle.charge_required", function() return true end,
  { battle = { field = sun }, move = { id = "SOLARBEAM" }, charge = true })
T.eq(charge, false, "public charge hook skips SolarBeam charge in sun")

local sand = { tokens = {} }
run.data.move_effects.ADAPTIVE_SAND_EFFECT.run({ field = sand })
local residuals = Runtime.call("battle.field_residual", function() return {} end, {
  field = sand,
  battlers = {
    player = { side = "player", name = "NORMALMON", hp = 80, maxHp = 80,
      types = { "NORMAL" } },
    enemy = { side = "enemy", name = "ONIX", hp = 80, maxHp = 80,
      types = { "ROCK", "GROUND" } },
  },
})
T.eq(#residuals, 1, "public residual hook emits only the non-immune battler")
T.eq(residuals[1].amount, 10, "sand descriptor uses one-eighth max HP")
run.release()

local disabledState = {
  schema = 1, seedHi = 1, seedLo = 2,
  trainers = { route = { owned = { {
    id = "route#1", lineId = "ZUBAT_LINE", species = "CROBAT", level = 40,
    moves = { "SLUDGE_BOMB", "FIX_TACKLE" },
  } } } },
  bossAttempts = {},
  rival = { owned = {}, activeIds = {}, attachmentById = {}, pathFlags = {},
    encounterIndex = 0 },
  leagueRunCounter = 0, yellowRival = {},
}
local disabledSave = {
  version = "red", player = { id = 1, name = "RED", rival = "BLUE",
    map = "FIX_ROUTE" }, meta = { playthroughId = "phase-g-reconcile" },
  party = {}, modData = { adaptive_trainers = { state = disabledState } },
}
local disabled = load_with_gold("none")
local disabledGame = { data = disabled.data, save = disabledSave }
disabled.loader.game, disabled.loader.modSave = disabledGame,
  disabledSave.modData
Runtime.emit("game.ready", { game = disabledGame })
local owned = disabledSave.modData.adaptive_trainers.state.trainers.route.owned[1]
T.eq(owned.species, "GOLBAT",
  "game.ready reconciles a saved continuation before materialization")
T.same(owned.moves, { "FIX_TACKLE" },
  "disabled reconciliation suspends unavailable Kanto+ moves")
T.eq(owned.suspendedStage.species, "CROBAT",
  "downgrade persists reversible continuation identity")
disabled.release()

local restored = load_with_gold("full")
local restoredGame = { data = restored.data, save = disabledSave }
restored.loader.game, restored.loader.modSave = restoredGame,
  disabledSave.modData
Runtime.emit("game.ready", { game = restoredGame })
owned = disabledSave.modData.adaptive_trainers.state.trainers.route.owned[1]
T.eq(owned.species, "CROBAT",
  "complete Gold capability restores the saved continuation")
T.same(owned.moves, { "SLUDGE_BOMB", "FIX_TACKLE" },
  "complete Gold capability restores the saved moves byte-for-byte")
T.eq(owned.suspendedStage, nil,
  "restoration clears only the reversible suspension marker")
restored.release()

T.finish("adaptive trainers phase G runtime")
