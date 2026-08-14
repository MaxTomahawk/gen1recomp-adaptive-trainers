return function(deps)
  local rng = deps.rng
  local M = { VERSION = 1 }

  local function table_at(owner, key)
    if type(owner[key]) ~= "table" then owner[key] = {} end
    return owner[key]
  end

  local function save_seed(identity)
    identity = type(identity) == "table" and identity or {}
    return rng.seed({
      "adaptive_trainers-save-v1",
      identity.version or "unknown",
      identity.playerId or 0,
      identity.playerName or "",
      identity.rivalName or "",
      identity.playthroughId or "",
    })
  end

  function M.ensure(root, identity)
    if type(root) ~= "table" then root = {} end
    if type(root.schema) == "number" and root.schema > M.VERSION then
      return nil, "unsupported adaptive_trainers schema "
        .. tostring(root.schema)
    end

    local derived = save_seed(identity)
    if type(root.seedHi) ~= "number" then root.seedHi = derived.hi end
    if type(root.seedLo) ~= "number" then root.seedLo = derived.lo end

    table_at(root, "trainers")
    table_at(root, "bossAttempts")

    local rival = table_at(root, "rival")
    table_at(rival, "owned")
    table_at(rival, "activeIds")
    table_at(rival, "attachmentById")
    table_at(rival, "pathFlags")
    if type(rival.encounterIndex) ~= "number" then rival.encounterIndex = 0 end

    if type(root.leagueRunCounter) ~= "number" then
      root.leagueRunCounter = 0
    end
    table_at(root, "yellowRival")

    root.schema = M.VERSION
    return root
  end

  return M
end
