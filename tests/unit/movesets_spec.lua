local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local rng = assert(loadfile(ROOT .. "/src/core/rng.lua"))()
local packages = assert(loadfile(ROOT .. "/src/data/move_packages.lua"))()
local movesets = assert(loadfile(ROOT .. "/src/core/movesets.lua"))()({
  rng = rng, packages = packages,
})

local checks, failures = 0, 0
local function check(condition, message)
  checks = checks + 1
  if not condition then
    failures = failures + 1
    io.stderr:write("FAIL ", message, "\n")
  end
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (expected " .. tostring(expected)
    .. ", got " .. tostring(actual) .. ")")
end
local function contains(values, wanted)
  for _, value in ipairs(values or {}) do if value == wanted then return true end end
  return false
end
local function overlap_count(left, right)
  local seen, count = {}, 0
  for _, value in ipairs(left or {}) do seen[value] = true end
  for _, value in ipairs(right or {}) do
    if seen[value] then count = count + 1 end
  end
  return count
end

local species = {
  types = { "BUG", "FLYING" },
  level1Moves = { "TACKLE", "STRING_SHOT" },
  learnset = {
    { level = 7, move = "HARDEN" },
    { level = 10, move = "CONFUSION" },
    { level = 12, move = "GUST" },
  },
  tmhm = { "MEGA_DRAIN", "PSYCHIC", "CUT" },
}
local moveDefs = {
  TACKLE = { type = "NORMAL", power = 35, effect = "NO_ADDITIONAL_EFFECT" },
  STRING_SHOT = { type = "BUG", power = 0, effect = "SPEED_DOWN1_EFFECT" },
  HARDEN = { type = "NORMAL", power = 0, effect = "DEFENSE_UP1_EFFECT" },
  CONFUSION = { type = "PSYCHIC", power = 50, effect = "CONFUSION_SIDE_EFFECT" },
  GUST = { type = "FLYING", power = 40, effect = "NO_ADDITIONAL_EFFECT" },
  MEGA_DRAIN = { type = "GRASS", power = 40, effect = "DRAIN_HP_EFFECT" },
  PSYCHIC = { type = "PSYCHIC", power = 90, effect = "SPECIAL_DOWN_SIDE_EFFECT" },
  CUT = { type = "NORMAL", power = 50, effect = "NO_ADDITIONAL_EFFECT" },
  FIRE_BLAST = { type = "FIRE", power = 120,
    effect = "BURN_SIDE_EFFECT2" },
}

local pool = movesets.legal_pool(species, 10, moveDefs)
check(contains(pool.level, "TACKLE") and contains(pool.level, "HARDEN")
  and contains(pool.level, "CONFUSION"),
  "legal pool includes level-one and learned-at-or-below-level moves")
check(not contains(pool.level, "GUST"),
  "legal pool excludes future level-up moves")
check(contains(pool.tm, "PSYCHIC"),
  "legal pool derives TM/HM candidates from the runtime species registry")
eq(movesets.role("GUST", moveDefs.GUST, species), "STAB_DAMAGE",
  "same-type damage receives the STAB role")
eq(movesets.role("PSYCHIC", moveDefs.PSYCHIC, species), "COVERAGE_DAMAGE",
  "off-type damage receives the coverage role")
eq(movesets.role("THUNDER_WAVE", { type = "ELECTRIC", power = 0,
  effect = "PARALYZE_EFFECT" }, species), "STATUS",
  "status packages classify control moves")
eq(movesets.role("SWORDS_DANCE", { type = "NORMAL", power = 0,
  effect = "ATTACK_UP2_EFFECT" }, species), "SETUP",
  "setup packages classify win-condition moves")
eq(movesets.role("RECOVER", { type = "NORMAL", power = 0,
  effect = "HEAL_EFFECT" }, species), "SUSTAIN",
  "sustain packages classify recovery moves")
eq(movesets.role("REFLECT", { type = "PSYCHIC", power = 0,
  effect = "REFLECT_EFFECT" }, species), "DEFENSE",
  "defense packages classify screen moves")
eq(movesets.role("SMOKESCREEN", { type = "NORMAL", power = 0,
  effect = "ACCURACY_DOWN1_EFFECT" }, species), "UTILITY",
  "utility packages classify non-damage pressure")
eq(movesets.role("RAIN_DANCE", { type = "WATER", power = 0,
  effect = "WEATHER_EFFECT" }, species), "WEATHER",
  "weather packages retain their strategy role")

local legacySpecies = { level1Moves = {
  "TACKLE", "STRING_SHOT", "TACKLE",
}, learnset = {
  { level = 4, move = "HARDEN" },
  { level = 5, move = "CONFUSION" },
  { level = 6, move = "GUST" },
}, tmhm = { "PSYCHIC" } }
eq(table.concat(movesets.level_moves(legacySpecies, 6, moveDefs), ","),
  "STRING_SHOT,HARDEN,CONFUSION,GUST",
  "legacy hydration matches engine de-duplication and last-four level moves")
local legacy = { species = "BUTTERFREE", level = 6 }
movesets.hydrate_legacy(legacy, legacySpecies, moveDefs)
eq(table.concat(legacy.moves, ","),
  "STRING_SHOT,HARDEN,CONFUSION,GUST",
  "legacy hydration never introduces an otherwise learnable TM")
local phaseBUpgrade = { species = "BUTTERFREE", level = 6,
  moves = { "GUST", "PSYCHIC", "FIRE_BLAST" } }
movesets.hydrate_legacy(phaseBUpgrade, legacySpecies, moveDefs)
eq(table.concat(phaseBUpgrade.moves, ","), "GUST,PSYCHIC,FIRE_BLAST",
  "upgrade hydration preserves an existing Phase B moveset byte-for-byte")
eq(phaseBUpgrade.moveSources.GUST, "level",
  "upgrade hydration records a legal level-move source")
eq(phaseBUpgrade.moveSources.PSYCHIC, "tm",
  "upgrade hydration records a legal TM source")
eq(phaseBUpgrade.moveSources.FIRE_BLAST, "inherited",
  "upgrade hydration retains unknown historical moves as inherited")
eq(phaseBUpgrade.movesetVersion, packages.version,
  "upgrade hydration stamps the current persistent moveset schema")

local novice = { id = "novice", species = "BUTTERFREE", level = 10 }
local noviceMoves = movesets.generate(novice, species, moveDefs, 0)
eq(novice.moves, noviceMoves,
  "generation stores move memory on the persistent PokemonInstance")
check(#noviceMoves >= 1 and #noviceMoves <= 4,
  "generated ordinary movesets contain one to four moves")
local noviceTmCount = 0
for _, move in ipairs(noviceMoves) do
  if contains(pool.tm, move) and not contains(pool.level, move) then
    noviceTmCount = noviceTmCount + 1
  end
end
check(noviceTmCount <= 1, "T0 never exceeds its one-TM ceiling")

local repeated = { id = "novice", species = "BUTTERFREE", level = 10 }
eq(table.concat(movesets.generate(repeated, species, moveDefs, 0), ","),
  table.concat(noviceMoves, ","),
  "moveset generation repeats without global randomness")

local teamMoveDefs = {
  STAB = { type = "NORMAL", power = 60, accuracy = 100 },
  FIRE = { type = "FIRE", power = 90, accuracy = 100 },
  ICE = { type = "ICE", power = 90, accuracy = 100 },
  WATER = { type = "WATER", power = 90, accuracy = 100 },
  ELECTRIC = { type = "ELECTRIC", power = 90, accuracy = 100 },
}
local teamSpecies = { types = { "NORMAL" }, level1Moves = { "STAB" },
  tmhm = { "FIRE", "ICE", "WATER", "ELECTRIC" } }
local priorTeam = { { species = "ALLY", moves = { "FIRE", "FIRE" } } }
local priorPokemon = { ALLY = { types = { "FIRE" } } }
local teamContext = movesets.team_context(priorTeam, priorPokemon, teamMoveDefs)
eq(teamContext.damageTypeCounts.FIRE, 2,
  "team context counts persisted teammate damage types")
local teamFit = { id = "team-fit", species = "TEST", level = 50,
  roleSeed = 9 }
local teamFitMoves = movesets.generate(teamFit, teamSpecies, teamMoveDefs, 3,
  nil, teamContext)
check(not contains(teamFitMoves, "FIRE"),
  "T3 team fit drops already-redundant coverage when alternatives exist")
check(contains(teamFitMoves, "ICE") and contains(teamFitMoves, "WATER")
    and contains(teamFitMoves, "ELECTRIC"),
  "T3 team fit fills uncovered team damage types")

local inherited = { id = "evolved", species = "BUTTERFREE", level = 12,
  moves = { "TACKLE", "STRING_SHOT", "HARDEN", "CONFUSION" } }
local beforeMoves = { unpack(inherited.moves) }
local before = table.concat(beforeMoves, ",")
local refreshed = movesets.refresh(inherited, "evolution", species,
  moveDefs, 2)
check(refreshed, "evolution forces one persistent refresh when useful")
eq(overlap_count(beforeMoves, inherited.moves), 3,
  "refresh retains three logical inherited moves and replaces at most one")
check(contains(inherited.moves, "GUST"),
  "refresh admits a newly legal evolved-species move")
eq(#inherited.moves, 4, "refresh never exceeds four moves")
check(table.concat(inherited.moves, ",") ~= before,
  "a clearly useful new move replaces only one old slot")
eq(inherited.lastMovesetRefreshReason, "evolution",
  "refresh reason is persisted for diagnostics")

local noUpgrade = { id = "stable", species = "BUTTERFREE", level = 12,
  moves = { "GUST", "PSYCHIC", "MEGA_DRAIN", "CUT" } }
local stableBefore = table.concat(noUpgrade.moves, ",")
eq(movesets.refresh(noUpgrade, "level", species, moveDefs, 3), false,
  "ordinary level refresh does not churn a stronger nonredundant set")
eq(table.concat(noUpgrade.moves, ","), stableBefore,
  "rejected refresh leaves persistent move memory byte-stable")

local diverseSpecies = {
  types = species.types, level1Moves = species.level1Moves,
  learnset = species.learnset,
  tmhm = { "MEGA_DRAIN", "PSYCHIC", "CUT", "FIRE_BLAST" },
}
local diverse = { id = "diverse", species = "BUTTERFREE", level = 12,
  roleSeed = 77, moves = { "GUST", "PSYCHIC", "MEGA_DRAIN", "CUT" },
  moveSources = { GUST = "level", PSYCHIC = "level",
    MEGA_DRAIN = "level", CUT = "level" } }
local diverseBefore = table.concat(diverse.moves, ",")
eq(movesets.refresh(diverse, "level-up", diverseSpecies, moveDefs, 3), false,
  "level-up refresh cannot evict a nonredundant move for raw power alone")
eq(table.concat(diverse.moves, ","), diverseBefore,
  "a diverse full moveset remains byte-stable on rejected level refresh")
check(movesets.refresh(diverse, "evolution", diverseSpecies, moveDefs, 3),
  "evolution may spend its one extra refresh on a clearly stronger move")
check(contains(diverse.moves, "FIRE_BLAST"),
  "the evolution-only extra refresh admits the stronger legal candidate")

local cappedSpecies = { types = { "NORMAL" }, level1Moves = { "TACKLE" },
  tmhm = { "PSYCHIC", "FIRE_BLAST" } }
local underfilledAtCap = { id = "underfilled-cap", species = "TEST",
  level = 20, moves = { "TACKLE", "PSYCHIC" } }
eq(movesets.refresh(underfilledAtCap, "evolution", cappedSpecies,
    moveDefs, 0), false,
  "underfilled refresh cannot bypass the tier TM ceiling")
eq(table.concat(underfilledAtCap.moves, ","), "TACKLE,PSYCHIC",
  "a rejected underfilled refresh preserves legacy move memory")
eq(underfilledAtCap.moveSources.PSYCHIC, "tm",
  "refresh hydrates missing Phase B move-source memory before cap checks")

local inheritedAtCap = { id = "inherited-cap", species = "TEST", level = 20,
  moves = { "TACKLE", "FIRE_BLAST" },
  moveSources = { TACKLE = "level", FIRE_BLAST = "inherited" } }
eq(movesets.refresh(inheritedAtCap, "evolution", cappedSpecies,
    moveDefs, 0), false,
  "unknown inherited techniques conservatively consume the TM budget")

if failures > 0 then
  io.stderr:write(string.format("%d/%d moveset checks failed\n",
    failures, checks))
  os.exit(1)
end
print(string.format("%d/%d moveset checks passed", checks, checks))
