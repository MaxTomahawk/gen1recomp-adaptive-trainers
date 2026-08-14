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
  local selector = module("src/core/species_selector.lua")({
    stage_resolver = stage_resolver,
  })
  local validator = module("src/core/team_validator.lua")
  local standard = module("src/core/standard_trainers.lua")({
    rng = rng,
    player_power = player_power,
    ecology = ecology,
    selector = selector,
    validator = validator,
    stage_resolver = stage_resolver,
  })
  local line_meta = module("src/data/line_meta.lua").build()
  local profiles = module("src/data/trainer_profiles.lua")
  local ecology_overrides = module("src/data/ecology_overrides.lua")

  local game
  local pendingTrainer
  local collisionKeys = {}

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
    end
    local save = ev and ev.save or (game and game.save)
    if save then ensure_root(save) end
  end

  mod.events:on("game.ready", bind_live_game)
  mod.events:on("save.created", bind_live_game)
  mod.events:on("save.loaded", bind_live_game)

  mod.events:on("world.trainer_engaged", function(ev)
    local live = game or mod.game
    local save = live and live.save
    local npc = ev and ev.npc
    local definition = npc and npc.def or {}
    local mapId = current_map(save)
    local oppClass = ev and ev.trainerClass
    local partyIndex = ev and ev.partyIndex or 1
    local baseKey = identity.standard(save and save.version, mapId,
      oppClass, partyIndex)
    pendingTrainer = {
      mapId = mapId,
      oppClass = ev and ev.trainerClass,
      partyIndex = partyIndex,
      npcId = collisionKeys[baseKey]
        and npc and (npc.id or definition.name or definition.index) or nil,
    }
  end)

  mod.hooks:wrap("trainer.party", function(next, oppClass, partyIndex, partyDef)
    local engagedTrainer = pendingTrainer
    pendingTrainer = nil
    local profile = profiles.for_class(oppClass)
    if not profile or type(partyDef) ~= "table" then
      return next(oppClass, partyIndex, partyDef)
    end

    local live = game or mod.game
    local save = live and live.save
    local data = live and live.data
    if not save or not data or not data.pokemon then
      return next(oppClass, partyIndex, partyDef)
    end

    local mapId = current_map(save)
    local key = identity.from_context(save.version, { mapId = mapId },
      oppClass, partyIndex, engagedTrainer)
    local root = ensure_root(save)
    local generated = standard.build({
      version = save.version,
      mapId = mapId,
      oppClass = oppClass,
      partyIndex = partyIndex,
      identityKey = key,
      playTime = save.playTime or 0,
      playerParty = save.party or {},
    }, partyDef, root, {
      data = data,
      meta = line_meta,
      profile = profile,
      ecologyOverrides = ecology_overrides,
    })
    mod.save:set("state", root)
    return next(oppClass, partyIndex, generated)
  end, 0)

  mod.exports.status = function()
    return { phase = "A", schema = schema.VERSION }
  end
end
