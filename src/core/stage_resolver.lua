local M = {}

local function evolution_level(fromSpecies, toSpecies, pokemon)
  local definition = pokemon[fromSpecies]
  for _, evolution in ipairs(definition and definition.evolutions or {}) do
    local target = evolution.species or evolution.into
    if target == toSpecies and tonumber(evolution.level) then
      return tonumber(evolution.level)
    end
  end
end

local function available_stages(line, pokemon)
  local out = {}
  local previous
  local all = {}
  for _, stage in ipairs(line.stages or {}) do all[#all + 1] = stage end
  for _, stage in ipairs(line.postGen1Stages or {}) do all[#all + 1] = stage end
  for index, source in ipairs(all) do
    local stage = type(source) == "table" and source or { species = source }
    local species = stage.species
    local threshold = tonumber(stage.minLevel)
    if index == 1 then threshold = threshold or 1 end
    if not threshold and previous then
      threshold = evolution_level(previous.species, species, pokemon)
        or tonumber(stage.surrogateLevel)
    end
    -- A configured surrogate is authoritative for non-level NPC evolution,
    -- while malformed/missing registry chains remain unavailable rather than
    -- producing an illogical final evolution at level one.
    if threshold and pokemon[species] then
      out[#out + 1] = { species = species, threshold = threshold }
    end
    previous = stage
  end
  return out
end

function M.resolve(line, targetLevel, pokemon, preferredSpecies)
  if type(line) ~= "table" or type(line.stages) ~= "table" then return nil end
  targetLevel = tonumber(targetLevel) or 1
  pokemon = pokemon or {}
  local available = available_stages(line, pokemon)
  if line.branching and preferredSpecies then
    local base
    for _, stage in ipairs(available) do
      if stage.threshold <= targetLevel then
        base = base or stage.species
        if stage.species == preferredSpecies then return stage.species end
      end
    end
    return base
  end
  local selected
  for _, stage in ipairs(available) do
    if targetLevel >= stage.threshold then selected = stage.species end
  end
  return selected
end

return M
