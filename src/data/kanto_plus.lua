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
  { id = "RAIN_DANCE", type = "WATER", power = 0, accuracy = 90, pp = 5,
    effect = "ADAPTIVE_RAIN_EFFECT", category = "status" },
  { id = "SUNNY_DAY", type = "FIRE", power = 0, accuracy = 90, pp = 5,
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
  { id = "PSYCHIC_TYPE>STEEL", multiplier = 5 },
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

local KANTO_PLUS_MOVE = {}
for _, row in ipairs(MOVE_REQUIREMENTS) do KANTO_PLUS_MOVE[row.id] = true end

local APPLIED = setmetatable({}, { __mode = "k" })

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
  if type(registry.get) == "function" then
    local value = registry:get(id)
    if value ~= nil then return value end
  end
  if registry[id] ~= nil then return registry[id] end
  if type(registry.types) == "table" and not tostring(id):find(">", 1, true) then
    return registry.types[id]
  end
  local attacker, defender = tostring(id):match("^([^>]+)>([^>]+)$")
  if attacker then
    for _, row in ipairs(registry.matchups or {}) do
      if row.attacker == attacker and row.defender == defender then return row end
    end
  end
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

local function asset_resolvers(registries)
  if type(registries.assetPath) == "function"
      or type(registries.assetInfo) == "function" then
    return registries.assetPath, registries.assetInfo
  end
  local assets = registries.assets
  if type(assets) ~= "table" then return nil, nil end
  local path = type(assets.path) == "function"
    and function(value) return assets:path(value) end or nil
  local info = type(assets.info) == "function"
    and function(value) return assets:info(value) end or nil
  return path, info
end

function M.detect(registries)
  registries = registries or {}
  local assetPath, assetInfo = asset_resolvers(registries)
  local capabilities = {
    available = false,
    species = {}, evolutions = {}, moves = {}, typeChart = {},
    assetPath = assetPath, assetInfo = assetInfo, resolvedAssets = {},
    missingSpecies = {}, missingEvolutions = {}, missingMoves = {},
    missingTypeChart = {}, missingAssets = {},
  }
  if not assetPath then capabilities.missingAssets[1] = "assetPath" end
  if not assetInfo then
    capabilities.missingAssets[#capabilities.missingAssets + 1] = "assetInfo"
  end

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

  if assetPath and assetInfo then
    for _, requirement in ipairs(EVOLUTIONS) do
      local record = capabilities.species[requirement.target]
      if record then
        local resolved = {}
        for _, field in ipairs({ "spriteFront", "spriteBack" }) do
          local path = record[field]
          local pathOk, full, infoOk, info = false, nil, false, nil
          if type(path) == "string" then
            pathOk, full = pcall(assetPath, path)
            infoOk, info = pcall(assetInfo, path)
          end
          if pathOk and type(full) == "string" and full ~= ""
              and infoOk and type(info) == "table" and info.type == "file" then
            resolved[field] = full
          else
            capabilities.missingAssets[#capabilities.missingAssets + 1]
              = requirement.target .. "." .. field
          end
        end
        capabilities.resolvedAssets[requirement.target] = resolved
      end
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
    and #capabilities.missingAssets == 0
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

local function translated_move_available(moveId, moves)
  return KANTO_PLUS_MOVE[moveId] == true or get(moves, moveId) ~= nil
end

local function translate_species(record, moves, assets)
  local stats = record.baseStats or {}
  local special = tonumber(stats.special)
  if special == nil then
    local attack = tonumber(stats.specialAttack) or 1
    local defense = tonumber(stats.specialDefense) or attack
    special = math.floor((attack + defense) / 2)
  end
  local level1Moves, learnset, seenLevel1 = {}, {}, {}
  for _, moveId in ipairs(record.level1Moves or {}) do
    if translated_move_available(moveId, moves) and not seenLevel1[moveId] then
      level1Moves[#level1Moves + 1] = moveId
      seenLevel1[moveId] = true
    end
  end
  local rows = record.levelMoves or record.learnset or {}
  for _, row in ipairs(rows) do
    if translated_move_available(row.move, moves) then
      if (tonumber(row.level) or 0) <= 1 then
        if not seenLevel1[row.move] then
          level1Moves[#level1Moves + 1] = row.move
          seenLevel1[row.move] = true
        end
      else
        learnset[#learnset + 1] = { level = row.level, move = row.move }
      end
    end
  end
  local growthRate = record.growthRate
  if type(growthRate) == "string" then
    growthRate = growthRate:gsub("^GROWTH_", "")
  end
  local tmhm = {}
  for _, moveId in ipairs(record.tmhm or {}) do
    if translated_move_available(moveId, moves) then
      tmhm[#tmhm + 1] = moveId
    end
  end
  return {
    id = record.id, name = record.name, dex = record.dex,
    types = clone(record.types or {}),
    baseStats = { hp = stats.hp, attack = stats.attack, defense = stats.defense,
      speed = stats.speed, special = special },
    catchRate = record.catchRate, baseExp = record.baseExp,
    level1Moves = level1Moves, growthRate = growthRate,
    tmhm = tmhm, learnset = learnset, evolutions = {},
    spriteFront = assets and assets.spriteFront,
    spriteBack = assets and assets.spriteBack,
    frontSize = record.frontSize or record.picSize,
    trueColor = record.trueColor,
    battleScaleFront = record.battleScaleFront,
    battleScaleBack = record.battleScaleBack,
  }
end

function M.apply(mod, capabilities)
  local content = mod and mod.content
  if type(content) ~= "table" or not (capabilities and capabilities.available) then
    return nil
  end
  if APPLIED[mod] then return nil end

  local useNpcMethod = type(content.evolution_methods) == "table"
  if useNpcMethod then
    put(content.evolution_methods, "ADAPTIVE_NPC_EVOLUTION", {
      check = function() return false end,
      describe = function() return "trainer-only continuation" end,
    })
  end

  for _, requirement in ipairs(EVOLUTIONS) do
    put(content.pokemon, requirement.target,
      translate_species(capabilities.species[requirement.target],
        content.moves, capabilities.resolvedAssets[requirement.target]))
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
  APPLIED[mod] = true
  return nil
end

local function move_available(moveId, moves, enabled)
  if enabled == false and KANTO_PLUS_MOVE[moveId] then return false end
  return get(moves, moveId) ~= nil
end

local function reconcile_moves(instance, moves, enabled)
  if type(moves) ~= "table" then return false end
  local suspended = instance.suspendedMoves
  if type(suspended) == "table" and type(suspended.moves) == "table" then
    local complete = true
    for _, moveId in ipairs(suspended.moves) do
      if not move_available(moveId, moves, enabled) then complete = false; break end
    end
    if complete then
      instance.moves = clone(suspended.moves)
      instance.moveSources = clone(suspended.moveSources)
      instance.suspendedMoves = nil
      return true
    end
    return false
  end

  if type(instance.moves) ~= "table" then return false end
  local filtered, missing = {}, false
  for _, moveId in ipairs(instance.moves) do
    if move_available(moveId, moves, enabled) then
      filtered[#filtered + 1] = moveId
    else
      missing = true
    end
  end
  if not missing then return false end
  instance.suspendedMoves = {
    moves = clone(instance.moves),
    moveSources = clone(instance.moveSources),
  }
  instance.moves = filtered
  local sources = {}
  for _, moveId in ipairs(filtered) do
    if type(instance.moveSources) == "table" then
      sources[moveId] = instance.moveSources[moveId]
    end
  end
  instance.moveSources = next(sources) and sources or nil
  return true
end

function M.reconcile_instance(instance, pokemon, moves, enabled)
  if type(instance) ~= "table" then return false end
  local changed = reconcile_moves(instance, moves, enabled)
  local suspended = instance.suspendedStage
  if type(suspended) == "table" then
    local expectedFallback = FALLBACK[suspended.species]
    if expectedFallback == suspended.fallback
        and instance.species == suspended.fallback
        and enabled ~= false and get(pokemon, suspended.species) then
      instance.species = suspended.species
      instance.suspendedStage = nil
      return true
    end
    return changed
  end

  local fallback = FALLBACK[instance.species]
  local targetUnavailable = enabled == false or not get(pokemon, instance.species)
  if fallback and targetUnavailable and get(pokemon, fallback) then
    local missing = instance.species
    instance.species = fallback
    instance.suspendedStage = { species = missing, fallback = fallback }
    return true
  end
  return changed
end

local function reconcile_list(list, pokemon, moves, enabled, report)
  for _, instance in ipairs(list or {}) do
    local beforeSpecies = instance.species
    local hadSuspended = instance.suspendedStage ~= nil
    local hadMoves = instance.suspendedMoves ~= nil
    if M.reconcile_instance(instance, pokemon, moves, enabled) then
      report.changed = true
      report.instances = report.instances + 1
      if beforeSpecies ~= instance.species then
        if hadSuspended then
          report.restored = report.restored + 1
        else
          report.downgraded = report.downgraded + 1
        end
      end
      if not hadMoves and instance.suspendedMoves then
        report.movesSuspended = report.movesSuspended + 1
      elseif hadMoves and not instance.suspendedMoves then
        report.movesRestored = report.movesRestored + 1
      end
    end
  end
end

local function sync_rival_pending(rival, pokemon, moves, enabled, report)
  local pending = type(rival) == "table" and rival.pending or nil
  if type(pending) ~= "table" or type(pending.partyDef) ~= "table" then return end
  local byId = {}
  for _, instance in ipairs(rival.owned or {}) do byId[instance.id] = instance end
  for index, slot in ipairs(pending.partyDef) do
    local instance = byId[(pending.partyIds or {})[index]]
    if instance then
      if slot.species ~= instance.species then
        slot.species = instance.species
        report.changed = true
      end
      local wanted = type(instance.moves) == "table" and #instance.moves > 0
        and clone(instance.moves) or nil
      local same = type(slot.moves) == type(wanted)
      if same and type(wanted) == "table" then
        if #slot.moves ~= #wanted then same = false end
        for moveIndex, moveId in ipairs(wanted) do
          if slot.moves[moveIndex] ~= moveId then same = false; break end
        end
      end
      if not same then slot.moves = wanted; report.changed = true end
    else
      reconcile_list({ slot }, pokemon, moves, enabled, report)
    end
  end
end

function M.reconcile_root(root, pokemon, moves, enabled)
  local report = { changed = false, instances = 0, downgraded = 0,
    restored = 0, movesSuspended = 0, movesRestored = 0 }
  if type(root) ~= "table" then return report end
  for _, trainer in pairs(root.trainers or {}) do
    reconcile_list(trainer.owned, pokemon, moves, enabled, report)
  end
  for _, attempt in pairs(root.bossAttempts or {}) do
    reconcile_list(type(attempt) == "table" and attempt.party or nil,
      pokemon, moves, enabled, report)
  end
  local rival = root.rival
  if type(rival) == "table" then
    reconcile_list(rival.owned, pokemon, moves, enabled, report)
    sync_rival_pending(rival, pokemon, moves, enabled, report)
  end
  local run = root.leagueRun
  for _, party in pairs(type(run) == "table" and run.generatedParties or {}) do
    reconcile_list(party, pokemon, moves, enabled, report)
  end
  return report
end

M.evolutions = EVOLUTIONS
M.moveRequirements = MOVE_REQUIREMENTS
M.steelMatchups = STEEL_MATCHUPS

return M
