return function(deps)
  local stage_resolver = deps.stage_resolver
  local M = {}

  local function as_set(values)
    local out = {}
    for key, value in pairs(values or {}) do
      if type(key) == "number" then out[value] = true
      elseif value then out[key] = true end
    end
    return out
  end

  local function overlap(left, right)
    local a, b = as_set(left), as_set(right)
    local common, total = 0, 0
    for key in pairs(a) do
      total = total + 1
      if b[key] then common = common + 1 end
    end
    for key in pairs(b) do if not a[key] then total = total + 1 end end
    if total == 0 then return 0 end
    return common / total
  end

  local function affinity(line, profile)
    local wanted = as_set(profile and profile.classTags)
    for _, tag in ipairs(line.classTags or {}) do
      if wanted[tag] then return 1 end
    end
    return 0
  end

  function M.rank(args)
    local meta = args.meta or { lines = {}, bySpecies = {} }
    local original = meta.bySpecies and meta.bySpecies[args.vanillaSpecies]
    if not original then return {} end
    local evidenceByLine, maxWeight = {}, 0
    for _, row in ipairs(args.evidence or {}) do
      local line = meta.bySpecies[row.species]
      if line then
        local previous = evidenceByLine[line.lineId]
        local weight = row.weight or 0
        if not previous or weight > previous.weight then
          evidenceByLine[line.lineId] = { line = line, weight = weight }
        end
        if weight > maxWeight then maxWeight = weight end
      end
    end
    evidenceByLine[original.lineId] = evidenceByLine[original.lineId]
      or { line = original, weight = 0 }

    local rows = {}
    local rarityAllowance = tonumber(args.profile and args.profile.rarityAllowance)
      or 2
    for _, evidence in pairs(evidenceByLine) do
      local line = evidence.line
      local similarity = overlap(original.groups, line.groups)
      local eligible = line.genericEligible ~= false
        and similarity > 0
        and math.abs((line.powerBand or 1) - (original.powerBand or 1)) <= 1
        and (line.rarity or 0) <= rarityAllowance
      local species = eligible and stage_resolver.resolve(line,
        args.targetLevel, args.pokemon)
      if species then
        local ecologyAffinity = maxWeight > 0 and evidence.weight / maxWeight or 0
        local score = 0.30 * similarity
          + 0.25 * affinity(line, args.profile)
          + 0.25 * ecologyAffinity
          + 0.10 * 0.5
          + 0.10 * 0.5
        if line.lineId == original.lineId then score = score + 0.15 end
        rows[#rows + 1] = {
          line = line,
          species = species,
          score = score,
          evidenceWeight = evidence.weight,
        }
      end
    end
    table.sort(rows, function(left, right)
      if left.score ~= right.score then return left.score > right.score end
      return left.line.lineId < right.line.lineId
    end)
    return rows
  end

  function M.choose(rows, stream)
    if type(rows) ~= "table" or #rows == 0 then return nil end
    local total = 0
    for _, row in ipairs(rows) do total = total + math.max(0, row.score) end
    if total <= 0 then return rows[1] end
    local roll = stream:float() * total
    local cursor = 0
    for _, row in ipairs(rows) do
      cursor = cursor + math.max(0, row.score)
      if roll < cursor then return row end
    end
    return rows[#rows]
  end

  return M
end
