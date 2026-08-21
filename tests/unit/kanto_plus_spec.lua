local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

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
  RAIN_DANCE = { "RAIN DANCE", "WATER", 0, 100, 5 },
  SUNNY_DAY = { "SUNNY DAY", "FIRE", 0, 100, 5 },
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
  ["PSYCHIC>STEEL"] = 5, ["BUG>STEEL"] = 5,
  ["ROCK>STEEL"] = 5, ["GHOST>STEEL"] = 5,
  ["DRAGON>STEEL"] = 5, ["POISON>STEEL"] = 0,
  ["FIRE>STEEL"] = 20, ["FIGHTING>STEEL"] = 20,
  ["GROUND>STEEL"] = 20,
}

local function source_registries()
  local pokemon = {}
  for target, row in pairs(evolution_rows) do
    pokemon[target] = {
      id = target, name = target, types = { target == "STEELIX" and "STEEL"
        or "NORMAL" }, marker = "runtime-source:" .. target,
    }
    local evolution = { method = row[2], species = target }
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
  local chart = { STEEL = { name = "STEEL", category = "physical" } }
  for id, multiplier in pairs(steel_rows) do
    chart[id] = { multiplier = multiplier }
  end
  return {
    pokemon = registry(pokemon), moves = registry(moves),
    type_chart = registry(chart),
  }
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
eq(capabilities.species.STEELIX.marker, "runtime-source:STEELIX",
  "species definitions are derived from the runtime registry")
eq(capabilities.evolutions.STEELIX.from, "ONIX",
  "the Steelix continuation is derived from the source evolution row")
eq(capabilities.evolutions.BLISSEY.from, "CHANSEY",
  "all nine named continuations are detected despite the prose count typo")
eq(capabilities.typeChart.STEEL.category, "physical",
  "Steel retains Gen1-style physical category")
eq(capabilities.typeChart["POISON>STEEL"].multiplier, 0,
  "the derived Gen2 Steel chart includes Poison immunity")
eq(capabilities.moves.IRON_TAIL.power, 100,
  "Iron Tail is derived with its specified baseline power")
eq(capabilities.moves.SHADOW_BALL.pp, 15,
  "Shadow Ball is derived with its specified PP")

capabilities.species.STEELIX.marker = "changed-copy"
eq(source.pokemon:get("STEELIX").marker, "runtime-source:STEELIX",
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
  pokemon = registry(targetPokemon), moves = registry(),
  type_chart = registry(), move_effects = registry(),
}
local mod = { content = target }
kanto_plus.apply(mod, kanto_plus.detect(source_registries()))

eq(target.pokemon:get("CROBAT").marker, "runtime-source:CROBAT",
  "apply registers runtime-derived species without embedded ROM data")
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
