local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT is required")

local rng = assert(loadfile(ROOT .. "/src/core/rng.lua"))()
local stage_resolver = assert(loadfile(
  ROOT .. "/src/core/stage_resolver.lua"))()
local bosses = assert(loadfile(ROOT .. "/src/core/bosses.lua"))()({
  rng = rng,
  stage_resolver = stage_resolver,
  rosters = assert(loadfile(ROOT .. "/src/data/boss_rosters.lua"))(),
})
local line_data = assert(loadfile(ROOT .. "/src/data/line_meta.lua"))()
local league_data = assert(loadfile(ROOT .. "/src/data/league_rosters.lua"))()
local league = assert(loadfile(ROOT .. "/src/core/league_run.lua"))()({
  rng = rng,
  bosses = bosses,
  stage_resolver = stage_resolver,
  rosters = league_data,
})
local meta = line_data.build()

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

local pokemon = {}
for _, line in pairs(meta.lines) do
  for _, stage in ipairs(line.stages or {}) do
    pokemon[stage.species] = pokemon[stage.species] or {
      id = stage.species, types = { "NORMAL" }, level1Moves = { "TACKLE" },
      learnset = {}, tmhm = {},
    }
  end
  for _, stage in ipairs(line.postGen1Stages or {}) do
    pokemon[stage.species] = pokemon[stage.species] or {
      id = stage.species, types = { "NORMAL" }, level1Moves = { "TACKLE" },
      learnset = {}, tmhm = {},
    }
  end
end

local moveIds = { "TACKLE", "BLIZZARD", "ICE_BEAM", "SURF",
  "THUNDERBOLT", "CONFUSE_RAY", "LOVELY_KISS", "AMNESIA", "REST",
  "PSYCHIC", "REFLECT", "SUBMISSION", "SEISMIC_TOSS", "ROCK_SLIDE",
  "EARTHQUAKE", "BODY_SLAM", "MEGA_KICK", "ICE_PUNCH",
  "THUNDERPUNCH", "FIRE_PUNCH", "BIDE", "NIGHT_SHADE", "HYPNOSIS",
  "DREAM_EATER", "SLEEP_POWDER", "TOXIC", "SMOKESCREEN",
  "MEGA_DRAIN", "HYPER_BEAM", "AGILITY", "BARRIER", "DRAGON_RAGE",
  "FLY", "SKY_ATTACK", "THUNDER", "DRILL_PECK", "THUNDER_WAVE",
  "LIGHT_SCREEN", "FIRE_BLAST", "SUNNY_DAY", "SOLARBEAM" }
local moves = {}
for _, id in ipairs(moveIds) do moves[id] = { id = id } end

local packagesSeen = {}
local movesets = {
  team_context = function() return {} end,
  generate = function(instance, _, _, _, package)
    packagesSeen[instance.id] = package
    instance.moves = {}
    for _, id in ipairs(package.signatureMoves or package.techniques or {}) do
      instance.moves[#instance.moves + 1] = id
      if #instance.moves == 4 then break end
    end
    if #instance.moves == 0 then instance.moves[1] = "TACKLE" end
    return instance.moves
  end,
}
local services = { meta = meta, pokemon = pokemon, moves = moves,
  movesets = movesets }

local EXPECTED = {
  LORELEI = { signature = "LAPRAS", floors = { 56, 56, 54, 54, 53 } },
  BRUNO = { signature = "MACHAMP", floors = { 58, 56, 55, 55, 53 } },
  AGATHA = { signature = "GENGAR", floors = { 60, 58, 56, 56, 55 } },
  LANCE = { signature = "DRAGONITE", floors = { 62, 60, 58, 56, 56 } },
}

for _, memberId in ipairs(league.memberOrder) do
  local row = league_data.members[memberId]
  check(row ~= nil, memberId .. " has a League identity")
  eq(row.signatureSpecies, EXPECTED[memberId].signature,
    memberId .. " keeps its canonical signature")
  check(same(row.floors, EXPECTED[memberId].floors),
    memberId .. " has signature-ranked vanilla floors")
  eq(league_data.by_battle({ trainerClass = row.classId,
      partyIndex = 1, mapId = row.mapId, npcId = row.npcId }).id,
    memberId, memberId .. " exact encounter identity is recognized")
  eq(league_data.by_battle({ trainerClass = row.classId,
      partyIndex = 1, mapId = "WRONG", npcId = row.npcId }), nil,
    memberId .. " class reuse outside its room is rejected")
end

check(league.is_league_map("LORELEIS_ROOM"), "Lorelei room is in the run")
check(league.is_league_map("CHAMPIONS_ROOM"),
  "Champion room remains inside the League run boundary")
check(league.is_league_map("HALL_OF_FAME"),
  "Hall of Fame transition remains inside the League run boundary")
check(not league.is_league_map("INDIGO_PLATEAU_LOBBY"),
  "the lobby is outside the active run")

local root = { seedHi = 1234, seedLo = 5678, leagueRunCounter = 0 }
local run, created = league.enter(root, { version = "red", playTime = 900,
  playerParty = { { level = 42 }, { level = 60 }, { level = 55 } } })
eq(created, true, "first League entry creates a run")
eq(root.leagueRunCounter, 1, "first League entry advances the counter once")
check(same(run.referenceLevels, { 60, 55, 42, 42, 42 }),
  "entry snapshots top five levels and repeats the lowest when short")
eq(run.createdAt, 900, "run records its creation play time")
check(run.birdPair.member == "LORELEI" or run.birdPair.member == "LANCE",
  "run selects only a designed Bird member")
check(league_data.birds[run.birdPair.species].member == run.birdPair.member,
  "run selects only a designed member/Bird pairing")
for _, memberId in ipairs(league.memberOrder) do
  check(type(run.memberSeeds[memberId]) == "number",
    memberId .. " receives a persisted deterministic seed")
end

local sameRun, createdAgain = league.enter(root, { version = "red",
  playTime = 1000, playerParty = { { level = 100 } } })
eq(createdAgain, false, "re-entry while active reuses the run")
check(sameRun == run, "active run table is preserved exactly")
eq(root.leagueRunCounter, 1, "active re-entry cannot advance the counter")
check(same(run.referenceLevels, { 60, 55, 42, 42, 42 }),
  "later training cannot rescale the active run")

local totalBirds = 0
check(pokemon.JYNX ~= nil, "fixture exposes Jynx in runtime registry")
eq(stage_resolver.resolve(league_data.line(meta, "JYNX_LINE"), 42,
    pokemon, league_data.preferred_species("JYNX_LINE")), "JYNX",
  "League alias resolves Jynx through the runtime registry")
for _, memberId in ipairs(league.memberOrder) do
  local party, strategy = league.party(root, memberId, services)
  eq(#party, 5, memberId .. " always fields five Pokemon")
  eq(party[1].species, EXPECTED[memberId].signature,
    memberId .. " signature always occupies rank one")
  eq(party[1].level, math.max(EXPECTED[memberId].floors[1], 61),
    memberId .. " signature follows R1+1 with its vanilla floor")
  for index = 2, 5 do
    eq(party[index].level,
      math.max(EXPECTED[memberId].floors[index],
        run.referenceLevels[index]),
      memberId .. " slot " .. index .. " follows Ri with its floor")
  end
  check(type(strategy) == "table" and type(strategy.id) == "string",
    memberId .. " persists one structural strategy")
  for index, mon in ipairs(party) do
    if league_data.birds[mon.species] then
      totalBirds = totalBirds + 1
      eq(memberId, run.birdPair.member,
        "the Bird appears only on its assigned member")
      eq(mon.species, run.birdPair.species,
        "the visible Bird matches the run selection")
      check(index ~= 1, "the Bird never replaces a member signature")
      local package = packagesSeen[root.leagueRun.generatedParties[memberId]
        [index].id]
      check(package and package.id == "BIRD_" .. mon.species,
        "the Bird receives its dedicated move package")
      eq(#(package and package.signatureMoves or {}), 4,
        "an available Bird package resolves all four move groups")
    end
  end
  local stableParty, stableStrategy = league.party(root, memberId, services)
  check(same(stableParty, party) and same(stableStrategy, strategy),
    memberId .. " cannot reroll after generation")
end
eq(totalBirds, 1, "a complete League run visibly contains exactly one Bird")

local persisted = root.leagueRun
local loreleiBefore = league.party(root, "LORELEI", services)
root.leagueRun = persisted
local loreleiAfter = league.party(root, "LORELEI", services)
check(same(loreleiBefore, loreleiAfter),
  "save/reload between members preserves byte-equivalent parties")

eq(league.leave(root, "blackout"), true, "blackout clears an active run")
eq(root.leagueRun, nil, "cleared run is not retained as gameplay authority")
eq(root.leagueRunCounter, 1, "leaving does not itself double-increment")
local nextRun, nextCreated = league.enter(root, { version = "red",
  playTime = 1200, playerParty = { { level = 70 } } })
eq(nextCreated, true, "a later League entry creates a new run")
eq(root.leagueRunCounter, 2, "a new run advances the counter exactly once")
check(nextRun.id ~= run.id, "the new run has a distinct deterministic id")

if failures > 0 then
  io.stderr:write(('%d/%d checks failed\n'):format(failures, checks))
  os.exit(1)
end
print(("adaptive trainers league run unit: %d checks passed"):format(checks))
