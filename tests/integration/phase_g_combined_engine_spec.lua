package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or require("tests.love_stub")
local checkpointRngState = "adaptive-phase-g-rng-A"
love.math.getRandomState = function() return checkpointRngState end
love.math.setRandomState = function(state) checkpointRngState = state end

local T = require("tests.modkit")
local BattleState = require("src.battle.BattleState")

-- The standalone mod stays usable while its two additive engine seams are
-- pending. This acceptance case becomes active only in the disposable
-- combined worktree used for Phase G integration.
if type(BattleState.applyFieldResiduals) ~= "function" then
  print("phase G combined-engine acceptance skipped: field residual seam absent")
  return
end

local DatasetFixture = require("tests.modkit.dataset_view_fixture")
local Checkpoint = require("src.core.Checkpoint")
local Font = require("src.render.Font")
local GameMethods = require("src.core.Game")
local GameVersion = require("src.core.GameVersion")
local Pokemon = require("src.pokemon.Pokemon")
local Runtime = require("src.mods.Runtime")
local SaveData = require("src.core.SaveData")
local SaveSerializer = require("src.core.SaveSerializer")
local StateStack = require("src.core.StateStack")
local TypeChart = require("src.battle.TypeChart")

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

local MOVE_ROWS = {
  IRON_TAIL = { "STEEL", 100, 75, 15 },
  METAL_CLAW = { "STEEL", 50, 95, 35 },
  STEEL_WING = { "STEEL", 70, 90, 25 },
  RAIN_DANCE = { "WATER", 0, 90, 5 },
  SUNNY_DAY = { "FIRE", 0, 90, 5 },
  SANDSTORM = { "ROCK", 0, 100, 10 },
  SLUDGE_BOMB = { "POISON", 90, 100, 10 },
  SHADOW_BALL = { "GHOST", 80, 100, 15 },
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

local function gen2_species(id, index)
  return {
    id = id, index = index, dex = index, name = id, types = { "NORMAL" },
    baseStats = { hp = 60, attack = 70, defense = 80, speed = 50,
      specialAttack = 45, specialDefense = 65 },
    catchRate = 45, baseExp = 120, growthRate = "GROWTH_MEDIUM_FAST",
    levelMoves = { { level = 1, move = "TACKLE" },
      { level = 20, move = "IRON_TAIL" } },
    tmhm = { "IRON_TAIL" }, evolutions = {}, picSize = 6,
    spriteFront = GENERATED_ASSETS .. "battle/front/" .. id:lower() .. ".png",
    spriteBack = GENERATED_ASSETS .. "battle/back/" .. id:lower() .. ".png",
  }
end

local function gold_overrides()
  local pokemon = { growthRates = {}, tmhmMoves = {} }
  local nextIndex = 1
  for _, row in ipairs(EVOLUTIONS) do
    local source = gen2_species(row[1], nextIndex)
    nextIndex = nextIndex + 1
    source.evolutions = { { method = "LEVEL", level = 36, into = row[2] } }
    pokemon[row[1]] = source
    pokemon[row[2]] = gen2_species(row[2], nextIndex)
    nextIndex = nextIndex + 1
  end
  local moves = { generation = 2, source = "ROM-free Phase G fixture" }
  local moveIndex = 1
  for id, row in pairs(MOVE_ROWS) do
    moves[id] = { id = id, index = moveIndex, name = id, type = row[1],
      power = row[2], accuracy = row[3], pp = row[4],
      effect = "NO_ADDITIONAL_EFFECT" }
    moveIndex = moveIndex + 1
  end
  local typeChart = {
    types = { STEEL = { id = "STEEL", name = "STEEL", index = 9,
      category = "physical" } },
    matchups = {}, foresightMatchups = {},
  }
  for _, row in ipairs(MATCHUPS) do
    typeChart.matchups[#typeChart.matchups + 1] = {
      attacker = row[1], defender = row[2], multiplier = row[3] }
  end
  return { pokemon = pokemon, moves = moves, type_chart = typeChart }
end

local function gen1_species(id, types)
  return { id = id, index = 100, dex = 100, name = id,
    types = types or { "NORMAL" },
    baseStats = { hp = 60, attack = 60, defense = 60,
      speed = 60, special = 60 }, catchRate = 45, baseExp = 80,
    evolutions = {}, learnset = {}, level1Moves = { "FIX_TACKLE" },
    tmhm = {}, growthRate = "MEDIUM_SLOW",
    spriteFront = "tests/fixture_data/assets/fixmon_a_front.png",
    spriteBack = "tests/fixture_data/assets/fixmon_a_back.png", frontSize = 5 }
end

local function active_data()
  local data = T.fixtures.fresh()
  for _, row in ipairs(EVOLUTIONS) do
    data.pokemon[row[1]] = gen1_species(row[1])
  end
  data.pokemon.MAGNEMITE = gen1_species("MAGNEMITE", { "ELECTRIC" })
  data.pokemon.MAGNETON = gen1_species("MAGNETON", { "ELECTRIC" })
  data.moves.SOLARBEAM = {
    id = "SOLARBEAM", index = 80, name = "SOLARBEAM", type = "GRASS",
    power = 120, accuracy = 100, pp = 10, effect = "CHARGE_EFFECT",
  }
  return data
end

local function hybrid_fs(memoryFiles)
  local memory = T.sdk.memfs(memoryFiles)
  local disk = T.fs.new(".")
  local alias = "mods/adaptive_trainers"
  local function mapped(path)
    if path == alias then return modPath end
    if path:sub(1, #alias + 1) == alias .. "/" then
      return modPath .. path:sub(#alias + 1)
    end
    return path
  end
  local function in_memory(path)
    return memory.getInfo(path) ~= nil
  end
  return {
    root = disk.root,
    read = function(path)
      if in_memory(path) then return memory.read(path) end
      return disk.read(mapped(path))
    end,
    write = function(path, body) return memory.write(path, body) end,
    load = function(path)
      if in_memory(path) then return memory.load(path) end
      return disk.load(mapped(path))
    end,
    getInfo = function(path)
      if path == "mods" then return { type = "directory" } end
      if in_memory(path) then return memory.getInfo(path) end
      return disk.getInfo(mapped(path))
    end,
    getDirectoryItems = function(path)
      if path == "mods" then return { "adaptive_trainers" } end
      if path == alias or path:sub(1, #alias + 1) == alias .. "/" then
        return disk.getDirectoryItems(mapped(path))
      end
      return memory.getDirectoryItems(path)
    end,
  }
end

local files = {}
DatasetFixture.cache(files, "gold", gold_overrides())
local data = active_data()
local run = T.sdk.loadMod("mods/adaptive_trainers", {
  fs = hybrid_fs(files), data = data, generation = 1,
})
T.eq(#run.errors, 0,
  "real DatasetViews Gold fixture loads Adaptive Trainers cleanly")
local status = run.loader.exports.adaptive_trainers.status()
T.eq(status.kantoPlus, true,
  "real DatasetViews semantics admit the complete Kanto+ sidecar")
T.eq(run.data.pokemon.STEELIX.spriteFront,
  GameVersion.cachePrefix("gold")
    .. GENERATED_ASSETS .. "battle/front/steelix.png",
  "real DatasetViews supplies the namespaced translated sprite path")

Font.load(run.data)
TypeChart.load(run.data)
local save = SaveData.newGame()
save.version = "red"
save.meta.playthroughId = "phase-g-combined"
save.player.map, save.player.x, save.player.y = "FIX_ROUTE", 4, 3
save.player.facing, save.player.surfing = "up", false
save.player.name, save.player.rival = "RED", "BLUE"
save.party = { Pokemon.new(run.data, "FIXMON_A", 30) }
save.modData = { adaptive_trainers = {} }
SaveData.validate(save, run.data)
local stack = setmetatable({ states = {} }, { __index = StateStack })
local game
local overworld = {
  isOverworld = true, map = { id = "FIX_ROUTE" },
  player = { cellX = 4, cellY = 3, facing = "up", surfing = false },
  runner = { isRunning = function() return false end },
  parallelRunners = {}, pendingScripts = {}, parallelQueue = {}, scriptMoves = {},
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
  if origin.kind ~= "wild_encounter" or origin.map ~= self.map.id
      or origin.wildSpecies ~= "STEELIX" or origin.wildLevel ~= 30 then
    return false
  end
  battle.onFinish = function() end
  return true
end
game = setmetatable({ data = run.data, save = save, stack = stack,
  overworld = overworld, mods = run.loader,
  input = { wasPressed = function() return false end,
    isDown = function() return false end } }, { __index = GameMethods })
stack.states[1] = overworld
run.loader.game, run.loader.modSave = game, save.modData
Runtime.emit("game.ready", { game = game })

-- The real checkpoint serializer owns both mod.save and battle reconstruction.
-- A valid imported continuation must survive a capture/decode/restore instead
-- of being downgraded or regenerated by the restore event.
local checkpointRoot = save.modData.adaptive_trainers.state
checkpointRoot.trainers.checkpoint_probe = { owned = { {
  id = "checkpoint#1", lineId = "ZUBAT_LINE", species = "CROBAT", level = 40,
  moves = { "SLUDGE_BOMB", "FIX_TACKLE" },
} } }
local checkpointBattle = BattleState.newWild(game, "STEELIX", 30)
checkpointBattle.phase, checkpointBattle.queue = "menu", {}
checkpointBattle.checkpointOrigin = {
  kind = "wild_encounter", map = "FIX_ROUTE",
  wildSpecies = "STEELIX", wildLevel = 30,
}
checkpointBattle.musicKind = checkpointBattle:computeMusicKind()
stack.states[2] = checkpointBattle
local snapshot, captureCode = Checkpoint.capture(game)
T.check(snapshot ~= nil,
  "real checkpoint capture serializes Kanto+ battle and mod.save: "
    .. tostring(captureCode))
if snapshot then
  local encoded = SaveSerializer.encode(snapshot)
  local decoded, decodeError = SaveSerializer.decode(encoded)
  T.check(decoded ~= nil,
    "serialized Kanto+ checkpoint decodes as data-only: "
      .. tostring(decodeError))
  checkpointRoot.trainers.checkpoint_probe.owned[1].species = "GOLBAT"
  checkpointRoot.trainers.checkpoint_probe.owned[1].moves = { "FIX_TACKLE" }
  local restored, restoreCode, restoreMessage = Checkpoint.restore(game, decoded)
  T.check(restored == true,
    "real checkpoint restore reconstructs Kanto+ authority: "
      .. tostring(restoreCode) .. " / " .. tostring(restoreMessage))
  if restored then
    local checkpointOwned = game.save.modData.adaptive_trainers.state
      .trainers.checkpoint_probe.owned[1]
    T.eq(checkpointOwned.species, "CROBAT",
      "checkpoint restoration retains the serialized Kanto+ continuation")
    T.same(checkpointOwned.moves, { "SLUDGE_BOMB", "FIX_TACKLE" },
      "checkpoint restoration retains the serialized Kanto+ moves")
    T.eq(game.stack:top().enemy.mon.species, "STEELIX",
      "checkpoint restoration reconstructs the Kanto+ battle opponent")
  end
end
save = game.save
stack.states = { overworld }

local function battle_with(moveId)
  local move = { id = moveId, pp = 10, maxPp = 10 }
  save.party[1].hp = save.party[1].stats.hp
  save.party[1].moves = { move }
  local battle = BattleState.newWild(game, "FIXMON_C", 20)
  battle.phase, battle.queue = "menu", {}
  battle.rng = function(a) return a or 0 end
  return battle, move
end

local solar, solarMove = battle_with("SOLARBEAM")
run.data.move_effects.ADAPTIVE_SUN_EFFECT.run({ field = solar.field })
local solarHp = solar.enemy.mon.hp
solar:performMove(solar.player, solar.enemy, solarMove)
T.check(solar.enemy.mon.hp < solarHp,
  "real BattleState resolves SolarBeam on its first sunny turn")
T.eq(solar.player.charging, nil,
  "sun creates no private charge continuation")
T.eq(solarMove.pp, 9, "one-turn SolarBeam spends exactly one PP")

local sand = battle_with("FIX_TACKLE")
run.data.move_effects.ADAPTIVE_SAND_EFFECT.run({ field = sand.field })
local order = {}
local nativeDrain = sand.drainNext
sand.drainNext = function(self, battler, stopAt)
  order[#order + 1] = "residual_drain"
  return nativeDrain(self, battler, stopAt)
end
sand.field.tokens[1] = { id = "expires", turns = 1,
  onExpire = function() order[#order + 1] = "token_expired" end }
run.loader.events:on("battle.turn_ended", function()
  order[#order + 1] = "turn_ended"
end, -100, "phase_g_combined_test")
local playerHp, enemyHp = sand.player.mon.hp, sand.enemy.mon.hp
local playerDamage = math.max(1, math.floor(sand.player.mon.stats.hp / 8))
local enemyDamage = math.max(1, math.floor(sand.enemy.mon.stats.hp / 8))
sand:endOfTurn()
T.eq(sand.player.mon.hp, playerHp - playerDamage,
  "engine-owned residual pipeline damages the player")
T.eq(sand.enemy.mon.hp, enemyHp - enemyDamage,
  "engine-owned residual pipeline damages the enemy")
T.same(order, {
  "residual_drain", "residual_drain", "token_expired", "turn_ended",
}, "sand drains precede token expiry and the public turn event")
T.eq(sand.field.weather.turns, 4,
  "public turn event advances five-turn weather after residual damage")

for _, typeId in ipairs({ "ROCK", "GROUND", "STEEL" }) do
  local immune = battle_with("FIX_TACKLE")
  immune.enemy.curTypes = { typeId }
  run.data.move_effects.ADAPTIVE_SAND_EFFECT.run({ field = immune.field })
  local immuneHp = immune.enemy.mon.hp
  immune:endOfTurn()
  T.eq(immune.enemy.mon.hp, immuneHp,
    "real BattleState honors Sandstorm immunity for " .. typeId)
end

local faint = battle_with("FIX_TACKLE")
run.data.move_effects.ADAPTIVE_SAND_EFFECT.run({ field = faint.field })
faint.enemy.mon.hp = 1
faint:endOfTurn()
T.eq(faint.enemy.mon.hp, 0,
  "field residual descriptors enter the engine-owned HP clamp")
T.eq(faint.enemy.faintQueued, true,
  "field residual fainting enters the normal faint orchestration")
local hasFaintContinuation = false
for _, row in ipairs(faint.queue) do
  if type(row.fn) == "function" then hasFaintContinuation = true; break end
end
T.eq(hasFaintContinuation, true,
  "the normal faint continuation remains queued for EXP/result handling")

-- The translated path must remain usable after the registry merge reaches
-- the actual battle image and draw path.  The headless graphics stub records
-- both boundaries without needing, or distributing, a cartridge asset.
local expectedSteelixFront = GameVersion.cachePrefix("gold")
  .. GENERATED_ASSETS .. "battle/front/steelix.png"
local imagePaths, drawnPaths = {}, {}
local nativeNewImage, nativeDraw = love.graphics.newImage, love.graphics.draw
require("src.render.Assets").invalidate()
BattleState.invalidate()
love.graphics.newImage = function(path, ...)
  imagePaths[#imagePaths + 1] = type(path) == "table" and path.path or path
  return nativeNewImage(path, ...)
end
love.graphics.draw = function(image, ...)
  drawnPaths[#drawnPaths + 1] = type(image) == "table" and image.path or image
  return nativeDraw(image, ...)
end
local imageOk, steelixBattle = pcall(BattleState.newWild, game, "STEELIX", 30)
if imageOk then
  T.eq(steelixBattle.enemy.sprite.path, expectedSteelixFront,
    "the translated Gold Steelix image retains its resolved asset path")
  steelixBattle.phase = "menu"
  steelixBattle.showEnemyTrainer = false
  local drawOk, drawError = pcall(steelixBattle.drawPicsLayer,
    steelixBattle, 0, 0, 0, "enemy", true)
  T.check(drawOk, "a translated Gold Steelix front sprite reaches BattleState draw: "
    .. tostring(drawError))
else
  T.check(false, "a translated Gold Steelix front sprite reaches BattleState image: "
    .. tostring(steelixBattle))
end
love.graphics.newImage, love.graphics.draw = nativeNewImage, nativeDraw

local function hasPath(paths, wanted)
  for _, path in ipairs(paths) do
    if path == wanted then return true end
  end
  return false
end
T.check(imageOk and hasPath(imagePaths, expectedSteelixFront),
  "the translated Gold Steelix path reaches love.graphics.newImage")
T.check(imageOk and hasPath(drawnPaths, expectedSteelixFront),
  "the translated Gold Steelix image reaches love.graphics.draw")

run.release()
T.finish("adaptive trainers Phase G combined engine")
