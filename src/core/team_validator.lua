local M = {}

local function stat_total(def)
  local total = 0
  for _, value in pairs(def and def.baseStats or {}) do
    if type(value) == "number" then total = total + value end
  end
  return total
end

function M.power_index(team, pokemon)
  local total = 0
  for _, slot in ipairs(team or {}) do
    total = total + stat_total(pokemon and pokemon[slot.species])
      * (tonumber(slot.level) or 1)
  end
  return total
end

local function structure_violations(team, vanilla, context)
  context = context or {}
  local pokemon = context.pokemon or {}
  local meta = context.meta or { lines = {}, bySpecies = {} }
  local profile = context.profile or {}
  local violations = {}
  local lineCounts, vanillaLineCounts = {}, {}
  local rarity3 = 0
  for _, slot in ipairs(team) do
    local lineId = slot.lineId
      or (meta.bySpecies[slot.species] and meta.bySpecies[slot.species].lineId)
    if lineId then lineCounts[lineId] = (lineCounts[lineId] or 0) + 1 end
    local line = (lineId and meta.lines and meta.lines[lineId])
      or (meta.bySpecies and meta.bySpecies[slot.species])
    local rarity = tonumber(line and line.rarity) or 0
    if rarity >= 4 then
      violations[#violations + 1] = "rarity-4"
    elseif rarity == 3 then
      rarity3 = rarity3 + 1
    end
  end
  if rarity3 > (profile.maxRarity3 or 1) then
    violations[#violations + 1] = "rarity-3-count"
  end
  for _, slot in ipairs(vanilla) do
    local line = meta.bySpecies[slot.species]
    if line then
      vanillaLineCounts[line.lineId] = (vanillaLineCounts[line.lineId] or 0) + 1
    end
  end
  if not profile.allowDuplicateLines then
    for lineId, count in pairs(lineCounts) do
      if count > 1 and (vanillaLineCounts[lineId] or 0) < count then
        violations[#violations + 1] = "duplicate-line"
        break
      end
    end
  end

  if #team >= 2 and #team <= 4 and not profile.specialistType then
    local primary = {}
    for _, slot in ipairs(team) do
      local types = pokemon[slot.species] and pokemon[slot.species].types
      if types and types[1] then primary[types[1]] = (primary[types[1]] or 0) + 1 end
    end
    for _, count in pairs(primary) do
      if count > 2 then
        violations[#violations + 1] = "primary-type"
        break
      end
    end
  end

  return violations
end

function M.validate_structure(team, vanilla, context)
  local violations = structure_violations(team or {}, vanilla or {}, context)
  return #violations == 0, { violations = violations }
end

function M.validate_initial(team, vanilla, context)
  context = context or {}
  local pokemon = context.pokemon or {}
  local violations = structure_violations(team or {}, vanilla or {}, context)
  if #team ~= #vanilla then violations[#violations + 1] = "party-size" end

  local vanillaPower = M.power_index(vanilla, pokemon)
  local generatedPower = M.power_index(team, pokemon)
  local ratio = vanillaPower > 0 and generatedPower / vanillaPower or 1
  if ratio < 0.88 or ratio > 1.12 then
    violations[#violations + 1] = "power"
  end

  return #violations == 0, {
    powerRatio = ratio,
    powerIndex = generatedPower,
    vanillaPowerIndex = vanillaPower,
    violations = violations,
  }
end

return M
