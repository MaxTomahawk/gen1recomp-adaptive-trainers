return function(mod)
  local loaded = {}
  local function module(path)
    if loaded[path] ~= nil then return loaded[path] end
    local source, readError = mod:read(path)
    assert(type(source) == "string", readError or ("cannot read " .. path))
    local chunk, compileError = loadstring(source, "@" .. mod.path .. "/" .. path)
    assert(chunk, compileError)
    local value = chunk()
    loaded[path] = value
    return value
  end

  local rng = module("src/core/rng.lua")
  local schema = module("src/core/save_schema.lua")({ rng = rng })
  local identity = module("src/core/identity.lua")
  local player_power = module("src/core/player_power.lua")
  local ecology = module("src/core/ecology.lua")
  local stage_resolver = module("src/core/stage_resolver.lua")
  local move_packages = module("src/data/move_packages.lua")
  local movesets = module("src/core/movesets.lua")({
    rng = rng,
    packages = move_packages,
  })
  local selector = module("src/core/species_selector.lua")({
    stage_resolver = stage_resolver,
  })
  local validator = module("src/core/team_validator.lua")
  local growth = module("src/core/growth.lua")({
    rng = rng,
    player_power = player_power,
    stage_resolver = stage_resolver,
    movesets = movesets,
  })
  local roster = module("src/core/roster.lua")({
    rng = rng,
    stage_resolver = stage_resolver,
  })
  local standard = module("src/core/standard_trainers.lua")({
    rng = rng,
    player_power = player_power,
    ecology = ecology,
    selector = selector,
    validator = validator,
    stage_resolver = stage_resolver,
    growth = growth,
    roster = roster,
    movesets = movesets,
  })
  local line_meta = module("src/data/line_meta.lua").build()
  local profiles = module("src/data/trainer_profiles.lua")
  local boss_rosters = module("src/data/boss_rosters.lua")
  local battle_identities = module("src/data/battle_identities.lua")
  local league_rosters = module("src/data/league_rosters.lua")
  local gym_registration = module("src/ui/gym_registration.lua")({
    ui = mod.ui,
  })
  local bosses = module("src/core/bosses.lua")({
    rng = rng,
    stage_resolver = stage_resolver,
    rosters = boss_rosters,
  })
  local league = module("src/core/league_run.lua")({
    rng = rng,
    bosses = bosses,
    stage_resolver = stage_resolver,
    rosters = league_rosters,
  })
  local rival_windows = module("src/data/rival_windows.lua")
  local rival = module("src/core/rival.lua")({
    rng = rng,
    player_power = player_power,
    windows = rival_windows,
  })
  local ecology_overrides = module("src/data/ecology_overrides.lua")
  local ai_tiers = module("src/data/ai_tiers.lua")
  local ai = module("src/core/ai.lua")(ai_tiers)
  mod.content.screens:register("AdaptiveGymRegistration", {
    new = gym_registration.new,
  })

  local game
  local pendingTrainer
  local preparedBattle
  local activeBattle
  local preparedBoss
  local activeBoss
  local preparedLeague
  local activeLeague
  local preparedRival
  local activeRival
  local checkpointRestorePending = false
  local collisionKeys = {}
  local centerIndex

  local function save_identity(save)
    local player = save and save.player or {}
    local meta = save and save.meta or {}
    return {
      version = save and save.version,
      playerId = player.id,
      playerName = player.name,
      rivalName = player.rival,
      playthroughId = meta.playthroughId,
    }
  end

  local function ensure_root(save)
    local root, schemaError = schema.ensure(mod.save:get("state"),
      save_identity(save))
    assert(root, schemaError)
    mod.save:set("state", root)
    return root
  end

  local function scoped_strategy(source, party)
    if type(source) ~= "table" then return nil end
    local strategy = {}
    for key, value in pairs(source) do strategy[key] = value end
    strategy.preferredSwitchSpecies = {}
    local preferredLines = {}
    for _, lineId in ipairs(source.preferredLines or {}) do
      preferredLines[lineId] = true
    end
    for _, instance in ipairs(party or {}) do
      if preferredLines[instance.lineId] then
        strategy.preferredSwitchSpecies[instance.species] = true
      end
    end
    return strategy
  end

  local function boss_strategy(root, bossId)
    local attempt = root and root.bossAttempts
      and root.bossAttempts[bossId]
    if type(attempt) ~= "table" then return nil end
    local identityDef = boss_rosters.leaders[bossId]
    local source = type(attempt.strategy) == "table" and attempt.strategy
      or identityDef and identityDef.strategyPackages[attempt.strategyId]
    return scoped_strategy(source, attempt.party)
  end

  local function league_strategy(root, memberId)
    local run = root and root.leagueRun
    return type(run) == "table" and scoped_strategy(
      run.memberStrategies and run.memberStrategies[memberId],
      run.generatedParties and run.generatedParties[memberId]) or nil
  end

  local function boss_matches(active, context)
    return type(active) == "table" and type(context) == "table"
      and active.oppClass == (context.trainerClass or context.oppClass)
      and (active.partyIndex or 1) == (context.partyIndex or 1)
  end

  local BOSS_PROFILE = { aiTier = 4, rosterBehavior = "boss" }
  local RIVAL_PROFILE = { aiTier = 3, rosterBehavior = "expert" }
  local function active_boss_context(battle)
    local live = game or mod.game
    local save = live and live.save
    if not save then return nil end
    local root = ensure_root(save)
    if boss_matches(root.activeBoss, battle) then
      return { profile = BOSS_PROFILE,
        strategy = boss_strategy(root, root.activeBoss.id) }
    end
    if boss_matches(root.activeLeagueMember, battle) then
      return { profile = BOSS_PROFILE,
        strategy = league_strategy(root, root.activeLeagueMember.id) }
    end
    if boss_matches(root.activeRival, battle)
        and root.activeRival.encounterId then
      return { profile = RIVAL_PROFILE }
    end
    return nil
  end

  ai.register(mod, profiles, active_boss_context)

  local function audit_identities(live)
    local save = live and live.save
    local data = live and live.data
    local rows = {}
    for mapId, map in pairs(data and data.maps or {}) do
      for _, object in ipairs(map.objects or {}) do
        if object.trainerClass and object.trainerParty then
          rows[#rows + 1] = {
            version = save and save.version,
            mapId = mapId,
            oppClass = object.trainerClass,
            partyIndex = object.trainerParty,
            npcId = object.name or object.id or object.index,
          }
        end
      end
    end
    collisionKeys = {}
    for _, collision in ipairs(identity.audit(rows)) do
      collisionKeys[collision.key] = true
      mod.log:warn("trainer identity collision %s (%d concrete NPCs); "
        .. "using the public NPC suffix", collision.key, #collision.npcIds)
    end
  end

  local function current_map(save)
    local ok, current = pcall(function()
      return mod.world and mod.world:current()
    end)
    if ok and type(current) == "table" and current.mapId then
      return current.mapId
    end
    return save and save.player and save.player.map or "UNKNOWN_MAP"
  end

  local function bind_live_game(ev)
    if ev and ev.game then
      game = ev.game
      audit_identities(game)
      centerIndex = roster.center_index(game.data)
    end
    local save = ev and ev.save or (game and game.save)
    if save then ensure_root(save) end
  end

  mod.events:on("game.ready", bind_live_game)
  mod.events:on("save.created", bind_live_game)
  mod.events:on("save.loaded", bind_live_game)

  mod.events:on("map.entered", function(ev)
    if not ev or ev.mapId ~= "LORELEIS_ROOM" then return end
    local live = game or mod.game
    local save = live and live.save
    if not save then return end
    local root = ensure_root(save)
    league.enter(root, { version = save.version,
      playTime = save.playTime or 0, playerParty = save.party or {} })
    mod.save:set("state", root)
  end)

  mod.events:on("map.exited", function(ev)
    if not ev or not league.is_league_map(ev.mapId)
        or league.is_league_map(ev.toMapId) then return end
    local live = game or mod.game
    local save = live and live.save
    if not save then return end
    local root = ensure_root(save)
    if league.leave(root, ev.toMapId or "exit") then
      preparedLeague, activeLeague = nil, nil
      mod.save:set("state", root)
    end
  end)

  mod.hooks:wrap("trainer.before_battle",
    function(next, live, context, continueBattle)
      local identityRef = battle_identities.for_battle(context)
      local identityDef = identityRef and identityRef.kind == "GYM_LEADER"
        and boss_rosters.leaders[identityRef.id]
      local save = live and live.save
      if not identityDef or not save then
        return next(live, context, continueBattle)
      end

      local root = ensure_root(save)
      local count = boss_rosters.active_count(identityDef, save.version)
      -- Fairness authority is captured from the complete party before the
      -- player sees or changes registration; the selected subset never feeds
      -- the scaling formula.
      local references = bosses.reference_levels(save.party or {}, count)
      mod.ui.push(live, "AdaptiveGymRegistration", {
        leaderId = identityRef.id,
        maxCount = count,
        party = save.party or {},
        onConfirm = function(indices)
          root.activeBoss = {
            id = identityRef.id,
            version = save.version,
            oppClass = context.trainerClass,
            partyIndex = context.partyIndex or 1,
            mapId = context.mapId,
            npcId = context.npcId,
            registeredIndices = indices,
            referenceLevels = references,
          }
          mod.save:set("state", root)
          continueBattle({ playerPartyIndices = indices })
        end,
        onCancel = function()
          root.activeBoss = nil
          mod.save:set("state", root)
          continueBattle({ cancel = true })
        end,
      })
      return true
    end, 100)

  local function active_identity_matches(active, save, mapId, oppClass,
      partyIndex)
    return type(active) == "table"
      and type(active.identityKey) == "string"
      and active.version == save.version
      and active.mapId == mapId
      and active.oppClass == oppClass
      and (active.partyIndex or 1) == (partyIndex or 1)
  end

  local function battle_matches(active, battle)
    return type(active) == "table" and type(battle) == "table"
      and active.oppClass == battle.oppClass
      and (active.partyIndex or 1) == (battle.partyIndex or 1)
  end

  local function rival_starter(save, partyDef)
    if save.version == "yellow" then return "EEVEE_LINE", "EEVEE" end
    local signature = partyDef[#partyDef]
    local line = signature and line_meta.bySpecies[signature.species]
    if not line or (line.lineId ~= "BULBASAUR_LINE"
        and line.lineId ~= "CHARMANDER_LINE"
        and line.lineId ~= "SQUIRTLE_LINE") then
      return nil
    end
    local base = line.stages and line.stages[1]
    return line.lineId, base and base.species
  end

  mod.events:on("world.trainer_engaged", function(ev)
    local live = game or mod.game
    local save = live and live.save
    local npc = ev and ev.npc
    local definition = npc and npc.def or {}
    local mapId = current_map(save)
    local oppClass = ev and ev.trainerClass
    local partyIndex = ev and ev.partyIndex or 1
    local concreteNpcId = npc
      and (npc.id or definition.name or definition.index) or nil
    local baseKey = identity.standard(save and save.version, mapId,
      oppClass, partyIndex)
    pendingTrainer = {
      mapId = mapId,
      oppClass = ev and ev.trainerClass,
      partyIndex = partyIndex,
      npcId = collisionKeys[baseKey] and concreteNpcId or nil,
      concreteNpcId = concreteNpcId,
    }
  end)

  mod.hooks:wrap("trainer.party", function(next, oppClass, partyIndex, partyDef)
    local engagedTrainer = pendingTrainer
    pendingTrainer = nil
    if type(partyDef) ~= "table" then
      return next(oppClass, partyIndex, partyDef)
    end

    local live = game or mod.game
    local save = live and live.save
    local data = live and live.data
    if not save or not data or not data.pokemon then
      return next(oppClass, partyIndex, partyDef)
    end

    local root = ensure_root(save)
    local mapId = engagedTrainer and engagedTrainer.mapId or current_map(save)
    local rivalEncounter = rival_windows.for_battle(save.version, mapId,
      oppClass, partyIndex)
    if not rivalEncounter and battle_matches(root.activeRival, {
        oppClass = oppClass, partyIndex = partyIndex,
      }) then
      rivalEncounter = root.activeRival.encounterId
      mapId = root.activeRival.mapId
    end
    if rivalEncounter then
      local starterLine, starterSpecies = rival_starter(save, partyDef)
      if save.version == "yellow" or starterLine then
        local generated = rival.build(rivalEncounter, {
          version = save.version,
          playTime = save.playTime or 0,
          rivalStarterLine = starterLine,
          rivalStarterSpecies = starterSpecies,
          playerParty = save.party or {},
        }, root, {
          meta = line_meta,
          pokemon = data.pokemon,
          moves = data.moves,
          stage_resolver = stage_resolver,
          movesets = movesets,
        })
        root.activeRival = {
          encounterId = rivalEncounter,
          version = save.version,
          mapId = mapId,
          oppClass = oppClass,
          partyIndex = partyIndex or 1,
        }
        preparedRival = root.activeRival
        activeRival = nil
        checkpointRestorePending = false
        mod.save:set("state", root)
        return next(oppClass, partyIndex, generated)
      end
    end

    local registeredBoss = root.activeBoss
    if boss_matches(registeredBoss, {
        trainerClass = oppClass, partyIndex = partyIndex,
      }) and boss_rosters.leaders[registeredBoss.id] then
      local identityDef = boss_rosters.leaders[registeredBoss.id]
      local generated, bossState = bosses.build(identityDef, {
        version = save.version,
        playerLevels = registeredBoss.referenceLevels,
      }, root, {
        meta = line_meta,
        pokemon = data.pokemon,
        moves = data.moves,
        movesets = movesets,
        rosters = boss_rosters,
      })
      registeredBoss.strategyId = bossState.strategyId
      registeredBoss.attemptCounter = bossState.attemptCounter
      preparedBoss = registeredBoss
      activeBoss = nil
      mod.save:set("state", root)
      return next(oppClass, partyIndex, generated)
    end

    local leagueIdentity
    if engagedTrainer then
      leagueIdentity = league_rosters.by_battle({
        trainerClass = oppClass, partyIndex = partyIndex,
        mapId = engagedTrainer.mapId,
        npcId = engagedTrainer.concreteNpcId,
      })
    elseif boss_matches(root.activeLeagueMember, {
        trainerClass = oppClass, partyIndex = partyIndex,
      }) then
      leagueIdentity = league_rosters.members[root.activeLeagueMember.id]
    end
    if leagueIdentity and not root.leagueRun
        and leagueIdentity.id == "LORELEI" then
      league.enter(root, { version = save.version,
        playTime = save.playTime or 0, playerParty = save.party or {} })
    end
    if leagueIdentity and root.leagueRun then
      local generated, strategy = league.party(root, leagueIdentity.id, {
        meta = line_meta, pokemon = data.pokemon, moves = data.moves,
        movesets = movesets,
      })
      root.activeLeagueMember = {
        id = leagueIdentity.id, version = save.version,
        oppClass = oppClass, partyIndex = partyIndex or 1,
        mapId = leagueIdentity.mapId, npcId = leagueIdentity.npcId,
        strategyId = strategy.id,
      }
      preparedLeague = root.activeLeagueMember
      activeLeague = nil
      mod.save:set("state", root)
      return next(oppClass, partyIndex, generated)
    end

    local profile = profiles.for_class(oppClass)
    if not profile then return next(oppClass, partyIndex, partyDef) end
    local mapId = current_map(save)
    local restored = not engagedTrainer and root.activeTrainer
    local key
    if active_identity_matches(restored, save, mapId, oppClass, partyIndex) then
      key = restored.identityKey
    else
      key = identity.from_context(save.version, { mapId = mapId },
        oppClass, partyIndex, engagedTrainer)
    end
    local generated = standard.build({
      version = save.version,
      mapId = mapId,
      oppClass = oppClass,
      partyIndex = partyIndex,
      identityKey = key,
      playTime = save.playTime or 0,
      playerParty = save.party or {},
      badgeCount = player_power.badge_count(save, data),
    }, partyDef, root, {
      data = data,
      meta = line_meta,
      profile = profile,
      ecologyOverrides = ecology_overrides,
      centerIndex = centerIndex,
    })
    root.activeTrainer = {
      identityKey = key,
      version = save.version,
      mapId = mapId,
      oppClass = oppClass,
      partyIndex = partyIndex,
    }
    preparedBattle = root.activeTrainer
    activeBattle = nil
    checkpointRestorePending = false
    mod.save:set("state", root)
    return next(oppClass, partyIndex, generated)
  end, 0)

  mod.events:on("battle.started", function(ev)
    local live = game or mod.game
    local save = live and live.save
    if not save then return end
    local root = ensure_root(save)
    local rivalCandidate = preparedRival or root.activeRival
    if ev and ev.kind == "trainer"
        and battle_matches(rivalCandidate, ev.battle)
        and rivalCandidate.encounterId then
      activeRival = {
        encounterId = rivalCandidate.encounterId,
        oppClass = rivalCandidate.oppClass,
        partyIndex = rivalCandidate.partyIndex,
        battle = ev.battle,
      }
      preparedRival, preparedLeague, preparedBoss, preparedBattle =
        nil, nil, nil, nil
      activeLeague, activeBoss, activeBattle = nil, nil, nil
      checkpointRestorePending = false
      mod.save:set("state", root)
      return
    end
    local leagueCandidate = preparedLeague or root.activeLeagueMember
    if ev and ev.kind == "trainer"
        and battle_matches(leagueCandidate, ev.battle)
        and leagueCandidate.id then
      activeLeague = { id = leagueCandidate.id,
        oppClass = leagueCandidate.oppClass,
        partyIndex = leagueCandidate.partyIndex, battle = ev.battle }
      ev.battle.adaptiveStrategy = league_strategy(root, leagueCandidate.id)
      preparedLeague, preparedBoss, preparedBattle = nil, nil, nil
      preparedRival = nil
      activeBoss, activeBattle = nil, nil
      activeRival = nil
      checkpointRestorePending = false
      mod.save:set("state", root)
      return
    end
    local bossCandidate = preparedBoss or root.activeBoss
    if ev and ev.kind == "trainer" and battle_matches(bossCandidate, ev.battle)
        and bossCandidate.id then
      activeBoss = {
        id = bossCandidate.id,
        oppClass = bossCandidate.oppClass,
        partyIndex = bossCandidate.partyIndex,
        battle = ev.battle,
      }
      ev.battle.adaptiveStrategy = boss_strategy(root, bossCandidate.id)
      preparedBoss = nil
      preparedBattle = nil
      activeBattle = nil
      preparedLeague = nil
      activeLeague = nil
      preparedRival = nil
      activeRival = nil
      checkpointRestorePending = false
      mod.save:set("state", root)
      return
    end
    preparedBoss = nil
    activeBoss = nil
    root.activeBoss = nil
    root.activeLeagueMember = nil
    local candidate = preparedBattle or root.activeTrainer
    if ev and ev.kind == "trainer"
        and battle_matches(candidate, ev.battle) then
      activeBattle = {
        identityKey = candidate.identityKey,
        oppClass = candidate.oppClass,
        partyIndex = candidate.partyIndex,
        battle = ev.battle,
      }
      preparedBattle = nil
      checkpointRestorePending = false
    else
      preparedBattle = nil
      activeBattle = nil
      preparedRival = nil
      activeRival = nil
      checkpointRestorePending = false
      root.activeTrainer = nil
      mod.save:set("state", root)
    end
  end)

  mod.events:on("checkpoint.restored", function(ev)
    local live = ev and ev.game or game or mod.game
    local save = live and live.save
    if not save then return end
    local root = ensure_root(save)
    checkpointRestorePending = ev and ev.kind == "battle"
      and (type(root.activeTrainer) == "table"
        or type(root.activeBoss) == "table"
        or type(root.activeLeagueMember) == "table"
        or type(root.activeRival) == "table")
    if checkpointRestorePending then
      preparedBattle = root.activeTrainer
      preparedBoss = root.activeBoss
      preparedLeague = root.activeLeagueMember
      preparedRival = root.activeRival
    end
  end)

  mod.events:on("battle.ended", function(ev)
    local live = game or mod.game
    local save = live and live.save
    if not save then return end
    local root = ensure_root(save)
    local rivalMatched
    if activeRival and ev and ev.battle == activeRival.battle
        and battle_matches(activeRival, ev.battle) then
      rivalMatched = activeRival
    elseif checkpointRestorePending and ev
        and battle_matches(root.activeRival, ev.battle) then
      rivalMatched = root.activeRival
    end
    if rivalMatched and rivalMatched.encounterId then
      local result = ev and ev.skipped == true and "skip"
        or ev and ev.result
      if result == "win" or result == "lose" or result == "skip" then
        rival.record_result(rivalMatched.encounterId, result, root)
      end
      activeRival, preparedRival = nil, nil
      checkpointRestorePending = false
      root.activeRival = nil
      mod.save:set("state", root)
      return
    end
    local leagueMatched
    if activeLeague and ev and ev.battle == activeLeague.battle
        and battle_matches(activeLeague, ev.battle) then
      leagueMatched = activeLeague
    elseif checkpointRestorePending and ev
        and battle_matches(root.activeLeagueMember, ev.battle) then
      leagueMatched = root.activeLeagueMember
    end
    if leagueMatched and leagueMatched.id then
      activeLeague, preparedLeague = nil, nil
      checkpointRestorePending = false
      root.activeLeagueMember = nil
      mod.save:set("state", root)
      return
    end
    local bossMatched
    if activeBoss and ev and ev.battle == activeBoss.battle
        and battle_matches(activeBoss, ev.battle) then
      bossMatched = activeBoss
    elseif checkpointRestorePending and ev
        and battle_matches(root.activeBoss, ev.battle) then
      bossMatched = root.activeBoss
    end
    if bossMatched and bossMatched.id then
      local state = root.bossAttempts[bossMatched.id]
      if state then state.lastResult = ev and ev.result or "run" end
      bosses.record_result(root, bossMatched.id,
        ev and ev.result or "run")
      activeBoss = nil
      preparedBoss = nil
      checkpointRestorePending = false
      root.activeBoss = nil
      mod.save:set("state", root)
      return
    end
    local matched
    if activeBattle and ev and ev.battle == activeBattle.battle
        and battle_matches(activeBattle, ev.battle) then
      matched = activeBattle
    elseif checkpointRestorePending and ev
        and battle_matches(root.activeTrainer, ev.battle) then
      matched = root.activeTrainer
    elseif ev and ev.skipped == true
        and battle_matches(preparedBattle, ev.battle) then
      matched = preparedBattle
    end
    if not matched then return end
    local key = matched.identityKey
    activeBattle = nil
    preparedBattle = nil
    checkpointRestorePending = false
    root.activeTrainer = nil
    local state = root.trainers and root.trainers[key]
    if not state then
      mod.save:set("state", root)
      return
    end
    state.battleCount = (state.battleCount or 0) + 1
    state.lastBattleAt = save.playTime or state.lastBattleAt or 0
    state.lastResult = ev and ev.result or "run"
    if state.lastResult == "lose" then
      state.lossCount = (state.lossCount or 0) + 1
    end
    mod.save:set("state", root)
  end)

  mod.exports.status = function()
    return { phase = "F", schema = schema.VERSION }
  end
end
