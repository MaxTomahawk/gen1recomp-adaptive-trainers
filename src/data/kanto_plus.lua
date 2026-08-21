local M = {}

local EVOLUTIONS = {
  { from = "GOLBAT", target = "CROBAT", fallback = "GOLBAT", level = 36 },
  { from = "GLOOM", target = "BELLOSSOM", fallback = "GLOOM", level = 36 },
  { from = "POLIWHIRL", target = "POLITOED", fallback = "POLIWHIRL", level = 36 },
  { from = "SLOWPOKE", target = "SLOWKING", fallback = "SLOWPOKE", level = 40 },
  { from = "ONIX", target = "STEELIX", fallback = "ONIX", level = 36 },
  { from = "SCYTHER", target = "SCIZOR", fallback = "SCYTHER", level = 36 },
  { from = "SEADRA", target = "KINGDRA", fallback = "SEADRA", level = 40 },
  { from = "PORYGON", target = "PORYGON2", fallback = "PORYGON", level = 36 },
  { from = "CHANSEY", target = "BLISSEY", fallback = "CHANSEY", level = 40 },
}

local MOVE_REQUIREMENTS = {
  { id = "IRON_TAIL", type = "STEEL", power = 100, accuracy = 75, pp = 15,
    effect = "ADAPTIVE_IRON_TAIL_EFFECT", category = "physical" },
  { id = "METAL_CLAW", type = "STEEL", power = 50, accuracy = 95, pp = 35,
    effect = "ADAPTIVE_METAL_CLAW_EFFECT", category = "physical" },
  { id = "STEEL_WING", type = "STEEL", power = 70, accuracy = 90, pp = 25,
    effect = "ADAPTIVE_STEEL_WING_EFFECT", category = "physical" },
  { id = "RAIN_DANCE", type = "WATER", power = 0, accuracy = 100, pp = 5,
    effect = "ADAPTIVE_RAIN_EFFECT", category = "status" },
  { id = "SUNNY_DAY", type = "FIRE", power = 0, accuracy = 100, pp = 5,
    effect = "ADAPTIVE_SUN_EFFECT", category = "status" },
  { id = "SANDSTORM", type = "ROCK", power = 0, accuracy = 100, pp = 10,
    effect = "ADAPTIVE_SAND_EFFECT", category = "status" },
  { id = "SLUDGE_BOMB", type = "POISON", power = 90, accuracy = 100, pp = 10,
    effect = "ADAPTIVE_SLUDGE_BOMB_EFFECT", category = "physical" },
  { id = "SHADOW_BALL", type = "GHOST", power = 80, accuracy = 100, pp = 15,
    effect = "ADAPTIVE_SHADOW_BALL_EFFECT", category = "physical" },
}

local STEEL_MATCHUPS = {
  { id = "STEEL>ICE", multiplier = 20 },
  { id = "STEEL>ROCK", multiplier = 20 },
  { id = "STEEL>FIRE", multiplier = 5 },
  { id = "STEEL>WATER", multiplier = 5 },
  { id = "STEEL>ELECTRIC", multiplier = 5 },
  { id = "STEEL>STEEL", multiplier = 5 },
  { id = "NORMAL>STEEL", multiplier = 5 },
  { id = "GRASS>STEEL", multiplier = 5 },
  { id = "ICE>STEEL", multiplier = 5 },
  { id = "FLYING>STEEL", multiplier = 5 },
  { id = "PSYCHIC>STEEL", multiplier = 5 },
  { id = "BUG>STEEL", multiplier = 5 },
  { id = "ROCK>STEEL", multiplier = 5 },
  { id = "GHOST>STEEL", multiplier = 5 },
  { id = "DRAGON>STEEL", multiplier = 5 },
  { id = "POISON>STEEL", multiplier = 0 },
  { id = "FIRE>STEEL", multiplier = 20 },
  { id = "FIGHTING>STEEL", multiplier = 20 },
  { id = "GROUND>STEEL", multiplier = 20 },
}

local FALLBACK = {}
for _, row in ipairs(EVOLUTIONS) do FALLBACK[row.target] = row.fallback end

local function clone(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, child in pairs(value) do
    out[clone(key, seen)] = clone(child, seen)
  end
  return out
end

local function get(registry, id)
  if type(registry) ~= "table" then return nil end
  if type(registry.get) == "function" then return registry:get(id) end
  return registry[id]
end

local function exact_move(record, requirement)
  if type(record) ~= "table" then return false end
  for _, field in ipairs({ "type", "power", "accuracy", "pp" }) do
    if record[field] ~= requirement[field] then return false end
  end
  return true
end

local function evolution_to(definition, target)
  for _, evolution in ipairs(definition and definition.evolutions or {}) do
    if (evolution.species or evolution.into) == target then
      return evolution
    end
  end
end

function M.detect(registries)
  registries = registries or {}
  local capabilities = {
    available = false,
    species = {}, evolutions = {}, moves = {}, typeChart = {},
    missingSpecies = {}, missingEvolutions = {}, missingMoves = {},
    missingTypeChart = {},
  }

  for _, requirement in ipairs(EVOLUTIONS) do
    local species = get(registries.pokemon, requirement.target)
    if species then
      capabilities.species[requirement.target] = clone(species)
    else
      capabilities.missingSpecies[#capabilities.missingSpecies + 1]
        = requirement.target
    end
    local source = get(registries.pokemon, requirement.from)
    local evolution = evolution_to(source, requirement.target)
    if evolution then
      capabilities.evolutions[requirement.target] = {
        from = requirement.from,
        target = requirement.target,
        fallback = requirement.fallback,
        surrogateLevel = requirement.level,
        source = clone(evolution),
      }
    else
      capabilities.missingEvolutions[#capabilities.missingEvolutions + 1]
        = requirement.target
    end
  end

  local steel = get(registries.type_chart, "STEEL")
  if type(steel) == "table" and steel.category == "physical" then
    capabilities.typeChart.STEEL = clone(steel)
  else
    capabilities.missingTypeChart[#capabilities.missingTypeChart + 1] = "STEEL"
  end
  for _, requirement in ipairs(STEEL_MATCHUPS) do
    local row = get(registries.type_chart, requirement.id)
    if type(row) == "table" and row.multiplier == requirement.multiplier then
      capabilities.typeChart[requirement.id] = clone(row)
    else
      capabilities.missingTypeChart[#capabilities.missingTypeChart + 1]
        = requirement.id
    end
  end

  for _, requirement in ipairs(MOVE_REQUIREMENTS) do
    local move = get(registries.moves, requirement.id)
    if exact_move(move, requirement) then
      capabilities.moves[requirement.id] = clone(move)
    else
      capabilities.missingMoves[#capabilities.missingMoves + 1]
        = requirement.id
    end
  end

  capabilities.available = #capabilities.missingSpecies == 0
    and #capabilities.missingEvolutions == 0
    and #capabilities.missingMoves == 0
    and #capabilities.missingTypeChart == 0
  return capabilities
end

local function put(registry, id, value)
  if type(registry) ~= "table" then return end
  if get(registry, id) == nil then
    registry:register(id, clone(value))
  elseif type(registry.patch) == "function" then
    registry:patch(id, clone(value))
  end
end

local function append_evolution(registry, row, useNpcMethod)
  local definition = get(registry, row.from)
  if type(definition) ~= "table" or evolution_to(definition, row.target) then
    return
  end
  local evolutions = clone(definition.evolutions or {})
  local evolution
  if useNpcMethod then
    evolution = { method = "ADAPTIVE_NPC_EVOLUTION",
      level = row.surrogateLevel, species = row.target }
  else
    evolution = clone(row.source)
    evolution.species = row.target
  end
  evolutions[#evolutions + 1] = evolution
  registry:patch(row.from, { evolutions = evolutions })
end

local function secondary(chance, callback)
  return {
    kind = "secondary",
    run = function(ctx)
      if ctx.rng(0, 255) >= chance then return {} end
      return callback(ctx) or {}
    end,
  }
end

local function effect_records()
  return {
    ADAPTIVE_IRON_TAIL_EFFECT = secondary(77, function(ctx)
      return ctx.changeStage(ctx.target, "defense", -1, true)
    end),
    ADAPTIVE_METAL_CLAW_EFFECT = secondary(26, function(ctx)
      return ctx.changeStage(ctx.user, "attack", 1, false)
    end),
    ADAPTIVE_STEEL_WING_EFFECT = secondary(26, function(ctx)
      return ctx.changeStage(ctx.user, "defense", 1, false)
    end),
    ADAPTIVE_SLUDGE_BOMB_EFFECT = secondary(77, function(ctx)
      return ctx.inflict(ctx.target, "PSN", {
        secondary = true, moveType = "POISON", source = "SLUDGE_BOMB",
      })
    end),
    ADAPTIVE_SHADOW_BALL_EFFECT = secondary(51, function(ctx)
      return ctx.changeStage(ctx.target, "special", -1, true)
    end),
  }
end

function M.apply(mod, capabilities)
  local content = mod and mod.content
  if type(content) ~= "table" or not (capabilities and capabilities.available) then
    return nil
  end

  local useNpcMethod = type(content.evolution_methods) == "table"
  if useNpcMethod then
    put(content.evolution_methods, "ADAPTIVE_NPC_EVOLUTION", {
      check = function() return false end,
      describe = function() return "trainer-only continuation" end,
    })
  end

  for _, requirement in ipairs(EVOLUTIONS) do
    put(content.pokemon, requirement.target,
      capabilities.species[requirement.target])
    append_evolution(content.pokemon,
      capabilities.evolutions[requirement.target], useNpcMethod)
  end

  for id, record in pairs(capabilities.typeChart) do
    local derived = clone(record)
    if id == "STEEL" then
      derived.name = derived.name or "STEEL"
      derived.category = "physical"
    end
    put(content.type_chart, id, derived)
  end

  for _, species in ipairs({ "MAGNEMITE", "MAGNETON" }) do
    if get(content.pokemon, species) then
      content.pokemon:patch(species, { types = { "ELECTRIC", "STEEL" } })
    end
  end

  for id, record in pairs(effect_records()) do
    put(content.move_effects, id, record)
  end
  for _, requirement in ipairs(MOVE_REQUIREMENTS) do
    local move = clone(capabilities.moves[requirement.id])
    move.effect = requirement.effect
    move.category = requirement.category
    put(content.moves, requirement.id, move)
  end
  return nil
end

function M.reconcile_instance(instance, pokemon)
  if type(instance) ~= "table" then return false end
  local suspended = instance.suspendedStage
  if type(suspended) == "table" then
    local expectedFallback = FALLBACK[suspended.species]
    if expectedFallback == suspended.fallback
        and instance.species == suspended.fallback
        and get(pokemon, suspended.species) then
      instance.species = suspended.species
      instance.suspendedStage = nil
      return true
    end
    return false
  end

  local fallback = FALLBACK[instance.species]
  if fallback and not get(pokemon, instance.species) and get(pokemon, fallback) then
    local missing = instance.species
    instance.species = fallback
    instance.suspendedStage = { species = missing, fallback = fallback }
    return true
  end
  return false
end

M.evolutions = EVOLUTIONS
M.moveRequirements = MOVE_REQUIREMENTS
M.steelMatchups = STEEL_MATCHUPS

return M
