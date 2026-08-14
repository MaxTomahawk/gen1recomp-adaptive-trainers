return function(deps)
  local rng = deps.rng
  local player_power = deps.player_power
  local stage_resolver = deps.stage_resolver
  local movesets = deps.movesets
  local M = {}

  local BADGE_ANCHOR = {
    [0] = 14, [1] = 21, [2] = 26, [3] = 32, [4] = 38,
    [5] = 43, [6] = 47, [7] = 52, [8] = 58,
  }

  local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
  end

  local function top_level(instances)
    local top = 1
    for _, mon in ipairs(instances or {}) do
      top = math.max(top, tonumber(mon.level) or 1)
    end
    return top
  end

  function M.contextual_ceiling(vanillaTop, playerReference, badgeCount, profile)
    vanillaTop = tonumber(vanillaTop) or 1
    playerReference = tonumber(playerReference) or vanillaTop
    badgeCount = clamp(math.floor(tonumber(badgeCount) or 0), 0, 8)
    profile = profile or {}
    local worldReference = math.max(vanillaTop, BADGE_ANCHOR[badgeCount])
    local playerAligned = vanillaTop
      + (profile.playerAlignment or 0) * math.max(0,
        playerReference - vanillaTop)
    local raw = math.max(vanillaTop, worldReference, playerAligned)
    local capped = math.min(raw,
      vanillaTop + (profile.lifetimeGainCap or 0),
      playerReference + (profile.overtakeCap or 0))
    return math.floor(capped)
  end

  function M.ceiling(vanillaTop, _, playerReference, badgeCount, profile)
    return M.contextual_ceiling(vanillaTop, playerReference, badgeCount, profile)
  end

  local function deterministic_round(value, stream)
    if value <= 0 then return 0 end
    local whole = math.floor(value)
    return whole + (stream:float() < value - whole and 1 or 0)
  end

  function M.materialize(state, ctx, profile)
    state, ctx, profile = state or {}, ctx or {}, profile or {}
    local now = tonumber(ctx.playTime) or 0
    local lastBattle = tonumber(state.lastBattleAt) or now
    local elapsed = math.max(0, now - lastBattle)
    local report = { elapsedSeconds = elapsed, changedIds = {} }
    if state.lastGrowthBattleCount == state.battleCount then
      report.reason = "already-materialized"
      return false, report
    end
    state.lastGrowthBattleCount = state.battleCount
    state.lastGrowthAt = now
    if elapsed <= 900 then
      report.reason = "grace"
      report.ceilingTop = top_level(state.owned)
      return false, report
    end

    local currentTop = top_level(state.owned)
    local vanillaTop = tonumber(state.vanillaTop) or currentTop
    local playerReference = player_power.reference(ctx.playerParty or {})
    local contextualCeiling = M.contextual_ceiling(vanillaTop,
      playerReference, ctx.badgeCount, profile)
    local effectiveCeiling = math.max(currentTop, contextualCeiling)
    report.ceilingTop = contextualCeiling
    report.effectiveCeilingTop = effectiveCeiling
    report.playerReference = playerReference
    if contextualCeiling <= currentTop then
      report.reason = "ceiling"
      return false, report
    end

    local hours = math.max(0, elapsed / 3600 - 0.25)
    local tau = math.max(0.001, tonumber(profile.tauHours) or 1)
    local factor = 1 - math.exp(-hours / tau)
    report.factor = factor
    local rootSeed = ctx.rootSeed or rng.seed({ "trainer-growth-root",
      state.identityKey or "", state.firstGeneratedAt or 0 })
    local changed = false
    for _, mon in ipairs(state.owned or {}) do
      local stream = rng.stream(rootSeed, "trainer-growth",
        state.identityKey or "", state.battleCount or 0, mon.id or "")
      local focus = stream:integer(-1, 1)
      local desired = math.max(0,
        (effectiveCeiling - currentTop) * factor + focus * factor)
      local gain = math.min(effectiveCeiling - (tonumber(mon.level) or 1),
        deterministic_round(desired, stream))
      if gain > 0 then
        local previousSpecies = mon.species
        mon.level = mon.level + gain
        changed = true
        report.changedIds[#report.changedIds + 1] = mon.id
        local line = ctx.meta and ((ctx.meta.lines or {})[mon.lineId]
          or (ctx.meta.bySpecies or {})[mon.species])
        local species = line and stage_resolver.resolve(line, mon.level,
          ctx.pokemon, mon.species)
        if movesets then
          movesets.refresh(mon, "level", ctx.pokemon[previousSpecies],
            ctx.moves, profile.aiTier)
        end
        if species and species ~= mon.species then
          mon.species = species
          if movesets then
            movesets.refresh(mon, "evolution", ctx.pokemon[species],
              ctx.moves, profile.aiTier)
          end
          mon.movesetRefreshReason = nil
          mon.evolvedFrom = previousSpecies
        end
      end
    end
    report.reason = changed and "grown" or "rounded-zero"
    return changed, report
  end

  return M
end
