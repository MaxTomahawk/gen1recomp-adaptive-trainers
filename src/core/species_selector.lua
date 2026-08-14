return function(deps)
  local stage_resolver = deps.stage_resolver
  local M = {}
  local WEIGHTS = {
    vanilla = 0.30, class = 0.25, ecology = 0.25,
    role = 0.10, team = 0.10, original = 0.15,
    rarityPenalty = 0.15,
  }

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

  local function role_fit(line, profile)
    local wanted = as_set(profile and profile.rolePreferences)
    local hasWanted, hasRoles = next(wanted) ~= nil, #(line.roles or {}) > 0
    if not hasWanted or not hasRoles then return 0.5 end
    for _, role in ipairs(line.roles) do if wanted[role] then return 1 end end
    return 0
  end

  local function team_fit(line, species, args)
    local team = args.team or {}
    if #team == 0 then return 0.5 end
    local sameLine, samePrimary = 0, 0
    local definition = args.pokemon and args.pokemon[species]
    local primary = definition and definition.types and definition.types[1]
    for _, slot in ipairs(team) do
      local slotLine = slot.lineId
        or (args.meta.bySpecies[slot.species]
          and args.meta.bySpecies[slot.species].lineId)
      if slotLine == line.lineId then sameLine = sameLine + 1 end
      local slotDef = args.pokemon and args.pokemon[slot.species]
      if primary and slotDef and slotDef.types and slotDef.types[1] == primary then
        samePrimary = samePrimary + 1
      end
    end
    if sameLine > 0 and not (args.profile and args.profile.allowDuplicateLines) then
      return 0
    end
    return math.max(0, 1 - math.min(1, samePrimary) * 0.5)
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
      local rarity = line.rarity or 0
      local eligible = line.genericEligible ~= false
        and similarity > 0
        and math.abs((line.powerBand or 1) - (original.powerBand or 1)) <= 1
        and rarity <= math.min(3, rarityAllowance)
      local species = eligible and stage_resolver.resolve(line,
        args.targetLevel, args.pokemon)
      if species then
        local ecologyAffinity = maxWeight > 0 and evidence.weight / maxWeight or 0
        ecologyAffinity = ecologyAffinity
          * math.max(0, 1 - rarity * WEIGHTS.rarityPenalty)
        local score = WEIGHTS.vanilla * similarity
          + WEIGHTS.class * affinity(line, args.profile)
          + WEIGHTS.ecology * ecologyAffinity
          + WEIGHTS.role * role_fit(line, args.profile)
          + WEIGHTS.team * team_fit(line, species, args)
        if line.lineId == original.lineId then score = score + WEIGHTS.original end
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
