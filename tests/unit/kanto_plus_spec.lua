local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")
local GENERATED_ASSETS = "assets/" .. "generated/"

local kanto_plus = assert(loadfile(ROOT .. "/src/data/kanto_plus.lua"))()

local checks, failures = 0, 0
local function check(condition, message)
  checks = checks + 1
  if not condition then
    failures = failures + 1
    io.stderr:write("FAIL ", message, "\n")
  end
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (expected " .. tostring(expected)
    .. ", got " .. tostring(actual) .. ")")
end

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
  return out
end

local function registry(initial)
  local records = copy(initial or {})
  local calls = {}
  return {
    records = records,
    calls = calls,
    get = function(self, id) return self.records[id] end,
    has = function(self, id) return self.records[id] ~= nil end,
    register = function(self, id, value)
      assert(self.records[id] == nil, id .. " already exists")
      self.records[id] = copy(value)
      self.calls[#self.calls + 1] = { op = "register", id = id }
    end,
    patch = function(self, id, partial)
      assert(self.records[id] ~= nil, id .. " does not exist")
      for key, value in pairs(partial) do self.records[id][key] = copy(value) end
      self.calls[#self.calls + 1] = { op = "patch", id = id }
    end,
  }
end

local evolution_rows = {
  CROBAT = { "GOLBAT", "FRIENDSHIP", nil },
  BELLOSSOM = { "GLOOM", "ITEM", "SUN_STONE" },
  POLITOED = { "POLIWHIRL", "TRADE_ITEM", "KINGS_ROCK" },
  SLOWKING = { "SLOWPOKE", "TRADE_ITEM", "KINGS_ROCK" },
  STEELIX = { "ONIX", "TRADE_ITEM", "METAL_COAT" },
  SCIZOR = { "SCYTHER", "TRADE_ITEM", "METAL_COAT" },
  KINGDRA = { "SEADRA", "TRADE_ITEM", "DRAGON_SCALE" },
  PORYGON2 = { "PORYGON", "TRADE_ITEM", "UP_GRADE" },
  BLISSEY = { "CHANSEY", "FRIENDSHIP", nil },
}

local move_rows = {
  IRON_TAIL = { "IRON TAIL", "STEEL", 100, 75, 15 },
  METAL_CLAW = { "METAL CLAW", "STEEL", 50, 95, 35 },
  STEEL_WING = { "STEEL WING", "STEEL", 70, 90, 25 },
  RAIN_DANCE = { "RAIN DANCE", "WATER", 0, 90, 5 },
  SUNNY_DAY = { "SUNNY DAY", "FIRE", 0, 90, 5 },
  SANDSTORM = { "SANDSTORM", "ROCK", 0, 100, 10 },
  SLUDGE_BOMB = { "SLUDGE BOMB", "POISON", 90, 100, 10 },
  SHADOW_BALL = { "SHADOW BALL", "GHOST", 80, 100, 15 },
}

local steel_rows = {
  ["STEEL>ICE"] = 20, ["STEEL>ROCK"] = 20,
  ["STEEL>FIRE"] = 5, ["STEEL>WATER"] = 5,
  ["STEEL>ELECTRIC"] = 5, ["STEEL>STEEL"] = 5,
  ["NORMAL>STEEL"] = 5, ["GRASS>STEEL"] = 5,
  ["ICE>STEEL"] = 5, ["FLYING>STEEL"] = 5,
  ["PSYCHIC_TYPE>STEEL"] = 5, ["BUG>STEEL"] = 5,
  ["ROCK>STEEL"] = 5, ["GHOST>STEEL"] = 5,
  ["DRAGON>STEEL"] = 5, ["POISON>STEEL"] = 0,
  ["FIRE>STEEL"] = 20, ["FIGHTING>STEEL"] = 20,
  ["GROUND>STEEL"] = 20,
}

local function source_registries(includeAssets)
  local pokemon = {}
  for target, row in pairs(evolution_rows) do
    pokemon[target] = {
      id = target, name = target, dex = 200,
      types = { target == "STEELIX" and "STEEL" or "NORMAL" },
      baseStats = { hp = 60, attack = 70, defense = 80, speed = 50,
        specialAttack = 45, specialDefense = 65 },
      catchRate = 45, baseExp = 120, growthRate = "GROWTH_MEDIUM_FAST",
      levelMoves = { { level = 1, move = "TACKLE" },
        { level = 20, move = "IRON_TAIL" } },
      tmhm = { "IRON_TAIL" }, evolutions = {},
      spriteFront = GENERATED_ASSETS .. "battle/front/" .. target .. ".png",
      spriteBack = GENERATED_ASSETS .. "battle/back/" .. target .. ".png",
      picSize = 6,
      source = "runtime-source:" .. target,
    }
    local evolution = { method = row[2], into = target }
    if row[3] then evolution.item = row[3] end
    pokemon[row[1]] = pokemon[row[1]] or {
      id = row[1], name = row[1], types = { "NORMAL" }, evolutions = {},
    }
    pokemon[row[1]].evolutions[#pokemon[row[1]].evolutions + 1] = evolution
  end
  local moves = {}
  for id, row in pairs(move_rows) do
    moves[id] = { id = id, name = row[1], type = row[2], power = row[3],
      accuracy = row[4], pp = row[5], effect = "GOLD_SOURCE_EFFECT" }
  end
  local chart = { types = {
    STEEL = { name = "STEEL", category = "physical" },
  }, matchups = {} }
  for id, multiplier in pairs(steel_rows) do
    local attacker, defender = id:match("^([^>]+)>([^>]+)$")
    chart.matchups[#chart.matchups + 1] = {
      attacker = attacker, defender = defender, multiplier = multiplier,
    }
  end
  local out = {
    pokemon = registry(pokemon), moves = registry(moves),
    type_chart = chart,
  }
  if includeAssets ~= false then
    out.assets = {
      path = function(_, path) return "datasets/gold/" .. path end,
      info = function() return { type = "file", size = 1 } end,
    }
  end
  return out
end

local absent = kanto_plus.detect({
  pokemon = registry(), moves = registry(), type_chart = registry(),
})
eq(absent.available, false,
  "Kanto+ remains unavailable when every post-Gen1 id is absent")
eq(#absent.missingSpecies, 9,
  "detection reports every explicitly named post-Gen1 evolution")
check(absent.species.CROBAT == nil and absent.moves.IRON_TAIL == nil,
  "absence never fabricates imported species or move records")

local source = source_registries()
local capabilities = kanto_plus.detect(source)
eq(capabilities.available, true,
  "a complete runtime source activates the optional Kanto+ capability")
eq(capabilities.species.STEELIX.source, "runtime-source:STEELIX",
  "species definitions are derived from the runtime registry")
eq(capabilities.evolutions.STEELIX.from, "ONIX",
  "the Steelix continuation is derived from the source evolution row")
eq(capabilities.evolutions.BLISSEY.from, "CHANSEY",
  "all nine named continuations are detected despite the prose count typo")
eq(capabilities.typeChart.STEEL.category, "physical",
  "Steel retains Gen1-style physical category")
eq(capabilities.typeChart["POISON>STEEL"].multiplier, 0,
  "the derived Gen2 Steel chart includes Poison immunity")
eq(capabilities.typeChart["PSYCHIC_TYPE>STEEL"].multiplier, 5,
  "the derived chart uses the live Gen1Recomp Psychic type id")
eq(capabilities.moves.IRON_TAIL.power, 100,
  "Iron Tail is derived with its specified baseline power")
eq(capabilities.moves.SHADOW_BALL.pp, 15,
  "Shadow Ball is derived with its specified PP")
check(type(capabilities.assetPath) == "function",
  "detection retains the imported dataset asset namespace resolver")
if type(capabilities.assetPath) == "function" then
  eq(capabilities.assetPath(
      GENERATED_ASSETS .. "battle/front/STEELIX.png"),
    "datasets/gold/" .. GENERATED_ASSETS .. "battle/front/STEELIX.png",
    "the retained asset resolver applies the Gold dataset namespace")
end

-- Each required Gold semantic must independently deny admission.  These are
-- deliberately three different capability groups, so a future relaxation in
-- any one cannot accidentally enable a partial overlay.
local missingSpecies = source_registries()
missingSpecies.pokemon.records.STEELIX = nil
local speciesRejected = kanto_plus.detect(missingSpecies)
eq(speciesRejected.available, false,
  "missing a required continuation species fails closed independently")
eq(speciesRejected.missingSpecies[1], "STEELIX",
  "missing continuation diagnostics name the exact absent species")

local missingEvolution = source_registries()
missingEvolution.pokemon.records.ONIX.evolutions = {}
local evolutionRejected = kanto_plus.detect(missingEvolution)
eq(evolutionRejected.available, false,
  "missing a required continuation evolution fails closed independently")
eq(evolutionRejected.missingEvolutions[1], "STEELIX",
  "missing evolution diagnostics name the exact absent continuation")

local missingMatchup = source_registries()
for index, row in ipairs(missingMatchup.type_chart.matchups) do
  if row.attacker == "POISON" and row.defender == "STEEL" then
    table.remove(missingMatchup.type_chart.matchups, index)
    break
  end
end
local matchupRejected = kanto_plus.detect(missingMatchup)
eq(matchupRejected.available, false,
  "missing a required Steel matchup fails closed independently")
eq(matchupRejected.missingTypeChart[1], "POISON>STEEL",
  "missing Steel matchup diagnostics name the exact absent row")

local unresolved = kanto_plus.detect(source_registries(false))
eq(unresolved.available, false,
  "Gold-shaped species cannot activate without an asset path resolver")
check(type(unresolved.missingAssets) == "table",
  "capability diagnostics include missing asset requirements")
if type(unresolved.missingAssets) == "table" then
  eq(unresolved.missingAssets[1], "assetPath",
    "capability diagnostics identify the missing sprite namespace resolver")
end

local nilAssets = source_registries()
nilAssets.assets.path = function() return nil end
local nilAssetCapabilities = kanto_plus.detect(nilAssets)
eq(nilAssetCapabilities.available, false,
  "a resolver that cannot resolve required sprites fails closed")
check(#nilAssetCapabilities.missingAssets > 0,
  "unresolved required sprites are included in capability diagnostics")

local brokenAssets = source_registries()
brokenAssets.assets.path = function() error("broken asset facade", 0) end
local detectedBroken, brokenAssetCapabilities = pcall(kanto_plus.detect,
  brokenAssets)
eq(detectedBroken, true,
  "a throwing asset facade cannot escape capability detection")
eq(brokenAssetCapabilities.available, false,
  "a throwing asset facade fails closed before registry writes")

for _, row in ipairs({
    { "missing info", function(assets) assets.info = nil end },
    { "nil info", function(assets) assets.info = function() return nil end end },
    { "non-file info", function(assets)
      assets.info = function() return { type = "directory" } end
    end },
    { "throwing info", function(assets)
      assets.info = function() error("broken asset info", 0) end
    end },
  }) do
  local invalidAssets = source_registries()
  row[2](invalidAssets.assets)
  local ok, detected = pcall(kanto_plus.detect, invalidAssets)
  eq(ok, true, row[1] .. " cannot escape capability detection")
  eq(detected.available, false,
    row[1] .. " fails closed before registry writes")
  check(#detected.missingAssets > 0,
    row[1] .. " appears in capability diagnostics")
end

capabilities.species.STEELIX.source = "changed-copy"
eq(source.pokemon:get("STEELIX").source, "runtime-source:STEELIX",
  "capability records do not alias the source registry")

local incomplete = source_registries()
incomplete.moves.records.SHADOW_BALL = nil
local rejected = kanto_plus.detect(incomplete)
eq(rejected.available, false,
  "a partial runtime source cannot activate an incomplete sidecar")
eq(rejected.missingMoves[1], "SHADOW_BALL",
  "partial capability diagnostics identify the missing move")

local targetPokemon = {}
for _, row in pairs(evolution_rows) do
  targetPokemon[row[1]] = targetPokemon[row[1]] or {
    id = row[1], types = { "NORMAL" }, evolutions = {},
  }
end
targetPokemon.MAGNEMITE = { id = "MAGNEMITE", types = { "ELECTRIC" },
  evolutions = {} }
targetPokemon.MAGNETON = { id = "MAGNETON", types = { "ELECTRIC" },
  evolutions = {} }
local target = {
  pokemon = registry(targetPokemon), moves = registry({ TACKLE = {} }),
  type_chart = registry(), move_effects = registry(),
}
local mod = { content = target }
kanto_plus.apply(mod, kanto_plus.detect(source_registries()))

eq(target.pokemon:get("CROBAT").baseStats.special, 55,
  "apply folds Gold split Special into the Gen1 stat model")
eq(target.pokemon:get("CROBAT").baseStats.specialAttack, nil,
  "apply does not copy a Gold-only Special field into Gen1 content")
eq(target.pokemon:get("CROBAT").growthRate, "MEDIUM_FAST",
  "apply normalizes Gold growth-rate ids into the Gen1 registry namespace")
eq(target.pokemon:get("CROBAT").level1Moves[1], "TACKLE",
  "Gold level-one rows become Gen1 level1Moves")
eq(target.pokemon:get("CROBAT").learnset[1].move, "IRON_TAIL",
  "later Gold level rows become the Gen1 learnset")
eq(target.pokemon:get("CROBAT").frontSize, 6,
  "Gold picSize becomes the Gen1 frontSize field")
eq(target.pokemon:get("CROBAT").spriteFront,
  "datasets/gold/" .. GENERATED_ASSETS .. "battle/front/CROBAT.png",
  "translated front sprites stay inside the Gold dataset namespace")
eq(target.pokemon:get("CROBAT").spriteBack,
  "datasets/gold/" .. GENERATED_ASSETS .. "battle/back/CROBAT.png",
  "translated back sprites never expose a raw cache-relative path")
eq(table.concat(target.pokemon:get("MAGNEMITE").types, ","),
  "ELECTRIC,STEEL", "Magnemite becomes Electric/Steel")
eq(table.concat(target.pokemon:get("MAGNETON").types, ","),
  "ELECTRIC,STEEL", "Magneton becomes Electric/Steel")
eq(target.pokemon:get("ONIX").evolutions[1].species, "STEELIX",
  "apply appends the runtime-derived Steelix evolution")
eq(target.type_chart:get("STEEL").category, "physical",
  "apply registers Steel as a physical type")
eq(target.type_chart:get("FIRE>STEEL").multiplier, 20,
  "apply registers the Gen2 Steel weakness rows")
eq(target.moves:get("IRON_TAIL").effect,
  "ADAPTIVE_IRON_TAIL_EFFECT",
  "Iron Tail uses the authored Gen2 secondary-effect adapter")
eq(target.moves:get("RAIN_DANCE").effect,
  "ADAPTIVE_RAIN_EFFECT",
  "Rain Dance is wired to the public weather effect")
eq(target.moves:get("SLUDGE_BOMB").category, "physical",
  "Poison remains physical under the Gen1 category model")
eq(target.moves:get("SHADOW_BALL").effect,
  "ADAPTIVE_SHADOW_BALL_EFFECT",
  "Shadow Ball receives its Special-drop adapter")
check(target.move_effects:get("ADAPTIVE_METAL_CLAW_EFFECT") ~= nil,
  "minimal move secondary effects are public registry records")

local secondary_rows = {
  { "ADAPTIVE_IRON_TAIL_EFFECT", 77, "stage", "TARGET", "defense", -1 },
  { "ADAPTIVE_METAL_CLAW_EFFECT", 26, "stage", "USER", "attack", 1 },
  { "ADAPTIVE_STEEL_WING_EFFECT", 26, "stage", "USER", "defense", 1 },
  { "ADAPTIVE_SLUDGE_BOMB_EFFECT", 77, "status", "TARGET", "PSN" },
  { "ADAPTIVE_SHADOW_BALL_EFFECT", 51, "stage", "TARGET", "special", -1 },
}

local function effect_context(roll, calls)
  return {
    user = "USER", target = "TARGET",
    rng = function(low, high)
      check(low == 0 and high == 255,
        "secondary effects draw from the exact 256-value byte domain")
      return roll
    end,
    changeStage = function(subject, stat, delta, secondary)
      calls[#calls + 1] = { "stage", subject, stat, delta, secondary }
      return { applied = true }
    end,
    inflict = function(subject, status, options)
      calls[#calls + 1] = { "status", subject, status, options }
      return { applied = true }
    end,
  }
end

for _, row in ipairs(secondary_rows) do
  local effect = target.move_effects:get(row[1])
  local belowCalls = {}
  local below = effect.run(effect_context(row[2] - 1, belowCalls))
  eq(#belowCalls, 1, row[1] .. " applies immediately below its threshold")
  eq(below.applied, true, row[1] .. " returns its applied callback result")
  eq(belowCalls[1][1], row[3], row[1] .. " uses the intended callback kind")
  eq(belowCalls[1][2], row[4], row[1] .. " affects the intended battler")
  eq(belowCalls[1][3], row[5], row[1] .. " applies the intended stat/status")
  if row[3] == "stage" then
    eq(belowCalls[1][4], row[6], row[1] .. " applies the intended stage delta")
  end

  local thresholdCalls = {}
  local threshold = effect.run(effect_context(row[2], thresholdCalls))
  eq(#thresholdCalls, 0, row[1] .. " does not apply at its threshold")
  eq(next(threshold), nil,
    row[1] .. " returns an empty effect result at its threshold")
end

local targetCallCount = 0
for _, registryValue in pairs(target) do
  targetCallCount = targetCallCount + #(registryValue.calls or {})
end
kanto_plus.apply(mod, kanto_plus.detect(source_registries()))
local repeatedCallCount = 0
for _, registryValue in pairs(target) do
  repeatedCallCount = repeatedCallCount + #(registryValue.calls or {})
end
eq(repeatedCallCount, targetCallCount,
  "repeated apply is idempotent and emits no duplicate registry operations")

for targetSpecies in pairs(evolution_rows) do
  check(target.pokemon:get(targetSpecies) ~= nil,
    "apply exposes named continuation " .. targetSpecies)
end

local noTarget = {
  pokemon = registry(targetPokemon), moves = registry(),
  type_chart = registry(), move_effects = registry(),
}
kanto_plus.apply({ content = noTarget }, absent)
eq(noTarget.pokemon:get("CROBAT"), nil,
  "apply is a no-op when capability detection fails")
eq(noTarget.moves:get("IRON_TAIL"), nil,
  "unavailable Kanto+ never leaks partial move content")

if failures > 0 then
  io.stderr:write(string.format("%d/%d Kanto+ checks failed\n", failures, checks))
  os.exit(1)
end
print(string.format("%d/%d Kanto+ checks passed", checks, checks))
