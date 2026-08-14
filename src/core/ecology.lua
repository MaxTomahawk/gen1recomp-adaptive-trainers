local DISTANCE_WEIGHT = { [0] = 1.0, [1] = 0.55, [2] = 0.25 }

local M = {}

local function enabled_methods(profile)
  local configured = profile and profile.encounterMethods
  if type(configured) == "table" then return configured end
  return { grass = true }
end

local function encounter_rows(data, mapId, profile, distance)
  local encounter = data.encounters and data.encounters[mapId]
  if type(encounter) ~= "table" then return {} end
  local methods = enabled_methods(profile)
  local rows = {}
  for _, method in ipairs({ "grass", "water" }) do
    local source = methods[method] and encounter[method]
    for _, slot in ipairs(source and source.slots or {}) do
      if type(slot.species) == "string" then
        rows[#rows + 1] = {
          species = slot.species,
          level = slot.level,
          method = method,
          mapId = mapId,
          distance = distance,
          weight = (DISTANCE_WEIGHT[distance] or 0) * (slot.weight or 1),
        }
      end
    end
  end
  return rows
end

local function neighbors(map)
  local out, seen = {}, {}
  local function add(id)
    if type(id) == "string" and not seen[id] then
      seen[id] = true
      out[#out + 1] = id
    end
  end
  for _, connection in pairs(map and map.connections or {}) do
    add(connection and (connection.map or connection.destMap))
  end
  for _, warp in ipairs(map and map.warps or {}) do add(warp.destMap) end
  table.sort(out)
  return out
end

local function aggregate(rows)
  local bySpecies = {}
  for _, row in ipairs(rows) do
    local prior = bySpecies[row.species]
    if not prior then
      prior = {
        species = row.species,
        weight = 0,
        distance = row.distance,
        sources = {},
      }
      bySpecies[row.species] = prior
    end
    prior.weight = prior.weight + row.weight
    prior.distance = math.min(prior.distance, row.distance)
    prior.sources[#prior.sources + 1] = row
  end
  local out = {}
  for _, row in pairs(bySpecies) do out[#out + 1] = row end
  table.sort(out, function(left, right) return left.species < right.species end)
  return out
end

function M.resolve(data, mapId, profile)
  data = data or {}
  local localRows = encounter_rows(data, mapId, profile, 0)
  if #localRows > 0 then return aggregate(localRows) end

  local radius = math.min(2, math.max(0,
    tonumber(profile and profile.mobilityRadius) or 0))
  local queue = { { id = mapId, distance = 0 } }
  local seen = { [mapId] = true }
  local rows = {}
  local cursor = 1
  while cursor <= #queue do
    local current = queue[cursor]
    cursor = cursor + 1
    if current.distance < radius then
      for _, neighbor in ipairs(neighbors(data.maps and data.maps[current.id])) do
        if not seen[neighbor] then
          seen[neighbor] = true
          local distance = current.distance + 1
          queue[#queue + 1] = { id = neighbor, distance = distance }
          local found = encounter_rows(data, neighbor, profile, distance)
          for _, row in ipairs(found) do rows[#rows + 1] = row end
        end
      end
    end
  end
  return aggregate(rows)
end

function M.by_species(rows)
  local out = {}
  for _, row in ipairs(rows or {}) do out[row.species] = row end
  return out
end

return M
