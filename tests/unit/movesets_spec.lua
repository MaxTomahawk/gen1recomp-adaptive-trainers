local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local movesets = assert(loadfile(ROOT .. "/src/core/movesets.lua"))()

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
}

local pool = movesets.legal_pool(species, 10, moveDefs)
check(contains(pool.level, "TACKLE") and contains(pool.level, "HARDEN")
  and contains(pool.level, "CONFUSION"),
  "legal pool includes level-one and learned-at-or-below-level moves")
check(not contains(pool.level, "GUST"),
  "legal pool excludes future level-up moves")
check(contains(pool.tm, "PSYCHIC"),
  "legal pool derives TM/HM candidates from the runtime species registry")

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

local inherited = { id = "evolved", species = "BUTTERFREE", level = 12,
  moves = { "TACKLE", "STRING_SHOT", "HARDEN", "CONFUSION" } }
local before = table.concat(inherited.moves, ",")
local refreshed = movesets.refresh(inherited, "evolution", species,
  moveDefs, 2)
check(refreshed, "evolution forces one persistent refresh when useful")
check(contains(inherited.moves, "TACKLE"),
  "refresh retains a logical inherited move")
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

if failures > 0 then
  io.stderr:write(string.format("%d/%d moveset checks failed\n",
    failures, checks))
  os.exit(1)
end
print(string.format("%d/%d moveset checks passed", checks, checks))
