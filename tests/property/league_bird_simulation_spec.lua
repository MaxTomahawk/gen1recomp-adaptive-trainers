local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT is required")
local rng = assert(loadfile(ROOT .. "/src/core/rng.lua"))()
local stage_resolver = assert(loadfile(
  ROOT .. "/src/core/stage_resolver.lua"))()
local bosses = assert(loadfile(ROOT .. "/src/core/bosses.lua"))()({
  rng = rng, stage_resolver = stage_resolver,
  rosters = assert(loadfile(ROOT .. "/src/data/boss_rosters.lua"))(),
})
local line_data = assert(loadfile(ROOT .. "/src/data/line_meta.lua"))()
local league_data = assert(loadfile(ROOT .. "/src/data/league_rosters.lua"))()
local league = assert(loadfile(ROOT .. "/src/core/league_run.lua"))()({
  rng = rng, bosses = bosses, stage_resolver = stage_resolver,
  rosters = league_data,
})

local meta = line_data.build()
local pokemon = {}
for _, line in pairs(meta.lines) do
  for _, stage in ipairs(line.stages or {}) do
    pokemon[stage.species] = { id = stage.species, types = { "NORMAL" } }
  end
end
local services = { meta = meta, pokemon = pokemon, moves = {}, movesets = {
  team_context = function() return {} end,
  generate = function(instance) instance.moves = {}; return instance.moves end,
} }

local checks, failures = 0, 0
local function check(condition, message)
  checks = checks + 1
  if not condition then
    failures = failures + 1
    if failures <= 20 then io.stderr:write("FAIL ", message, "\n") end
  end
end
local counts = { ARTICUNO = 0, ZAPDOS = 0, MOLTRES = 0 }
local function same(left, right)
  if type(left) ~= type(right) then return false end
  if type(left) ~= "table" then return left == right end
  for key, value in pairs(left) do
    if not same(value, right[key]) then return false end
  end
  for key in pairs(right) do
    if left[key] == nil then return false end
  end
  return true
end

for index = 1, 10000 do
  local root = { seedHi = 0x13579bdf, seedLo = index,
    leagueRunCounter = index - 1 }
  local run = league.enter(root, { version = "blue", playTime = index,
    playerParty = { 80, 70, 60, 50, 40, 30 },
    playerSpecies = { "MEWTWO", "DITTO" },
    playerMoves = { "PSYCHIC", "TRANSFORM" },
  })
  local bird = league_data.birds[run.birdPair.species]
  check(bird ~= nil, "run " .. index .. " selects one of three Birds")
  check(bird and bird.member == run.birdPair.member,
    "run " .. index .. " uses an allowed member/Bird pair")
  counts[run.birdPair.species] = (counts[run.birdPair.species] or 0) + 1

  local visible, parties = 0, {}
  for _, memberId in ipairs(league.memberOrder) do
    local party = league.party(root, memberId, services)
    parties[memberId] = party
    check(party[1].species == league_data.members[memberId].signatureSpecies,
      "run " .. index .. " preserves " .. memberId .. " signature")
    for slot, instance in ipairs(root.leagueRun.generatedParties[memberId]) do
      if league_data.birds[instance.species] then
        visible = visible + 1
        check(memberId == run.birdPair.member and slot ~= 1,
          "run " .. index .. " fields the Bird only in its allowed flex slot")
        check(instance.id == ("league:%s:%s"):format(run.id,
          run.birdPair.species),
          "run " .. index .. " persists the normative Bird instance id")
      end
    end
  end
  check(visible == 1,
    "run " .. index .. " materializes exactly one visible Bird")

  local repeatRoot = { seedHi = 0x13579bdf, seedLo = index,
    leagueRunCounter = index - 1 }
  local repeated = league.enter(repeatRoot, { version = "blue",
    playTime = index, playerParty = { 80, 70, 60, 50, 40, 30 },
    playerSpecies = { "RATTATA" }, playerMoves = { "TACKLE" },
  })
  check(repeated.id == run.id
      and repeated.birdPair.member == run.birdPair.member
      and repeated.birdPair.species == run.birdPair.species,
    "run " .. index .. " is repeatable and blind to exact player roster")
  for _, memberId in ipairs(league.memberOrder) do
    local repeatedParty = league.party(repeatRoot, memberId, services)
    check(same(repeatedParty, parties[memberId]),
      "run " .. index .. " " .. memberId
        .. " is byte-stable when exact player species and moves change")
  end
end

local function within(value, expected, tolerance)
  return math.abs(value - expected) <= tolerance
end
check(counts.ARTICUNO + counts.ZAPDOS + counts.MOLTRES == 10000,
  "every simulated run contributes exactly one Bird selection")
check(within(counts.ARTICUNO, 5000, 250),
  "Lorelei/Articuno stays within 2.5 percentage points of 50%")
check(within(counts.ZAPDOS, 2500, 200),
  "Lance/Zapdos stays within 2 percentage points of 25%")
check(within(counts.MOLTRES, 2500, 200),
  "Lance/Moltres stays within 2 percentage points of 25%")

if failures > 0 then
  io.stderr:write(('%d/%d checks failed; counts A=%d Z=%d M=%d\n')
    :format(failures, checks, counts.ARTICUNO, counts.ZAPDOS,
      counts.MOLTRES))
  os.exit(1)
end
print(("adaptive trainers League Bird properties: %d checks passed "
  .. "(A=%d Z=%d M=%d)"):format(checks, counts.ARTICUNO,
  counts.ZAPDOS, counts.MOLTRES))
