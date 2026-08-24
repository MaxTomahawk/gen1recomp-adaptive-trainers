package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Runtime = require("src.mods.Runtime")
local FsIo = require("tests.fs_io")

local modPath = assert(os.getenv("ADAPTIVE_TRAINERS_PATH"),
  "ADAPTIVE_TRAINERS_PATH must name the mod relative to Gen1Recomp")
local modRoot = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

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
local function copy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for key, item in pairs(value) do out[key] = copy(item) end
  return out
end
local function basename(path)
  return tostring(path):gsub("/+$", ""):match("[^/]+$")
end
local function spying_mod_fs(path)
  local inner = FsIo.new(".")
  local alias = basename(path)
  local counts = {
    observations = 0,
    writes = 0,
    modWrites = 0,
    writePaths = {},
  }
  local fs = { root = inner.root }
  local function under(candidate, root)
    return candidate == root
      or candidate:sub(1, #root + 1) == root .. "/"
  end
  local function is_mod_persistence(candidate)
    return under(candidate, "mod_storage") or under(candidate, "mod_compat")
  end
  local function map(candidate)
    local prefix = "mods/" .. alias
    if candidate == prefix then return path end
    if candidate and candidate:sub(1, #prefix + 1) == prefix .. "/" then
      return path .. candidate:sub(#prefix + 1)
    end
    return candidate
  end
  function fs.read(candidate)
    counts.observations = counts.observations + 1
    return inner.read(map(candidate))
  end
  function fs.write(candidate, body)
    counts.writes = counts.writes + 1
    counts.writePaths[#counts.writePaths + 1] = candidate
    if is_mod_persistence(candidate) then
      counts.modWrites = counts.modWrites + 1
    end
    if candidate:find("__adaptive_trainers_spy_probe__", 1, true) then
      return true
    end
    return inner.write(map(candidate), body)
  end
  function fs.load(candidate)
    counts.observations = counts.observations + 1
    return inner.load(map(candidate))
  end
  function fs.getInfo(candidate)
    counts.observations = counts.observations + 1
    if candidate == "mods" then return { type = "directory" } end
    return inner.getInfo(map(candidate))
  end
  function fs.getDirectoryItems(candidate)
    counts.observations = counts.observations + 1
    if candidate == "mods" then return { alias } end
    return inner.getDirectoryItems(map(candidate))
  end
  return fs, counts
end

-- Chapter 29 integration: before any mapped standard trainer is generated,
-- initialization may write the mod's own save namespace and nothing else.
local data = T.fixtures.fresh()
local spyingFs, fsCounts = spying_mod_fs(modPath)
spyingFs.write("__adaptive_trainers_spy_probe__", "probe")
eq(fsCounts.writes, 1,
  "filesystem spy detects a controlled write before SDK load")
eq(fsCounts.modWrites, 0,
  "generic engine bookkeeping is not attributed to the mod")
spyingFs.write("mod_storage/__adaptive_trainers_spy_probe__", "probe")
spyingFs.write("mod_compat/__adaptive_trainers_spy_probe__", "probe")
eq(fsCounts.modWrites, 2,
  "filesystem spy detects public storage and legacy-overlay writes")
fsCounts.writes = 0
fsCounts.modWrites = 0
fsCounts.writePaths = {}
local run = T.sdk.loadMod(modPath, { data = data, fs = spyingFs })
check(fsCounts.observations > 0,
  "filesystem spy is installed before SDK discovery and mod load")
eq(fsCounts.modWrites, 0,
  "mod load performs no mod.storage or legacy-overlay writes; observed: "
    .. table.concat(fsCounts.writePaths, ", "))
local save = {
  version = "red",
  meta = { playthroughId = "phase-h-no-generation" },
  player = { map = "FIX_ROUTE", id = 7, name = "RED", rival = "BLUE" },
  party = { { species = "RATTATA", level = 5 } },
  playTime = 0,
  modData = { adaptive_trainers = {}, unrelated_mod = { sentinel = 42 } },
}
local nonModBefore = copy(save)
nonModBefore.modData.adaptive_trainers = nil
local unrelatedBefore = copy(save.modData.unrelated_mod)
local game = { data = run.data, save = save,
  overworld = { isOverworld = true, map = { id = "FIX_ROUTE" } } }
run.loader.game = game
run.loader.modSave = game.save.modData
Runtime.emit("game.ready", { game = game })
local vanilla = { { species = "RATTATA", level = 5 } }
local returned = Runtime.call("trainer.party",
  function(_, _, party) return party end, "OPP_UNMAPPED", 1, vanilla)
local nonModAfter = copy(save)
nonModAfter.modData.adaptive_trainers = nil
check(same(nonModAfter, nonModBefore),
  "pre-generation initialization writes nothing outside mod.save")
check(same(save.modData.unrelated_mod, unrelatedBefore),
  "pre-generation initialization preserves every other mod namespace")
check(type(save.modData.adaptive_trainers.state) == "table",
  "pre-generation initialization persists only the schema root in mod.save")
eq(next(save.modData.adaptive_trainers.state.trainers), nil,
  "an unmapped class cannot generate standard-trainer state")
check(same(returned, vanilla),
  "an unmapped class remains byte-equivalent to its vanilla party")
eq(fsCounts.modWrites, 0,
  "pre-generation initialization performs no mod.storage/legacy-overlay writes")
run.release()

-- Chapter 29 boss-core variation: recording a prepared loss advances exactly
-- one attempt and the next deterministic attempt can select a different valid
-- strategy or flex roster. The public battle.started/battle.ended lifecycle is
-- exercised separately by tests/integration/gym_runtime_spec.lua.
local rng = assert(loadfile(modRoot .. "/src/core/rng.lua"))()
local stage_resolver = assert(loadfile(
  modRoot .. "/src/core/stage_resolver.lua"))()
local rosters = assert(loadfile(modRoot .. "/src/data/boss_rosters.lua"))()
local bosses = assert(loadfile(modRoot .. "/src/core/bosses.lua"))()({
  rng = rng, stage_resolver = stage_resolver, rosters = rosters,
})
local meta = assert(loadfile(modRoot .. "/src/data/line_meta.lua"))().build()
local pokemon = {}
for _, line in pairs(meta.lines) do
  for _, stage in ipairs(line.stages or {}) do
    pokemon[stage.species] = pokemon[stage.species] or {
      id = stage.species, types = { "NORMAL" },
    }
  end
  for _, stage in ipairs(line.postGen1Stages or {}) do
    pokemon[stage.species] = pokemon[stage.species] or {
      id = stage.species, types = { "NORMAL" },
    }
  end
end
local movesets = {
  team_context = function() return {} end,
  generate = function(instance)
    instance.moves = { "TACKLE" }
    return instance.moves
  end,
}
local services = { meta = meta, pokemon = pokemon, moves = {},
  movesets = movesets, rosters = rosters }
local identity = assert(rosters.leaders.BROCK)
local expectedCount = rosters.active_count(identity, "red")
local expectedSignature = rosters.signature_line(identity, "red")
local varied = 0
for seedValue = 1, 64 do
  local root = { seedHi = seedValue, seedLo = seedValue * 17,
    bossAttempts = {} }
  local firstParty, firstState = bosses.build(identity, {
    version = "red", playerLevels = { 18, 15, 12 },
  }, root, services)
  local firstParts = { firstState.strategyId }
  for _, mon in ipairs(firstState.party) do
    firstParts[#firstParts + 1] = mon.lineId
  end
  check(bosses.record_result(root, "BROCK", "lose"),
    "a prepared boss-core loss result is accepted")
  eq(root.bossAttempts.BROCK.attemptCounter, 1,
    "a boss-core loss result advances exactly one attempt")
  local nextParty, nextState = bosses.build(identity, {
    version = "red", playerLevels = { 18, 15, 12 },
  }, root, services)
  eq(#firstParty, expectedCount,
    "the first Gym attempt has the version-correct party size")
  eq(#nextParty, expectedCount,
    "the post-loss Gym attempt preserves the version-correct party size")
  eq(nextState.party[1].lineId, expectedSignature,
    "the post-loss Gym attempt preserves the signature line")
  for index, target in ipairs(nextState.targetLevels) do
    eq(nextParty[index].level, target,
      "the post-loss Gym attempt preserves its formal target level")
  end
  local nextParts = { nextState.strategyId }
  for _, mon in ipairs(nextState.party) do
    nextParts[#nextParts + 1] = mon.lineId
  end
  if table.concat(firstParts, "|") ~= table.concat(nextParts, "|") then
    varied = varied + 1
  end
end
check(varied > 0,
  "the attempt counter permits deterministic valid strategy/flex variation")
print(string.format("Gym loss variation: %d/64 seeds changed strategy/flex",
  varied))

-- Aggregate the existing A-F Chapter 29 evidence as executable contracts.
-- Each suite runs in its own Lua process so Runtime registrations cannot leak.
local chapter29Suites = {
  "tests/integration/phase_a_mod_spec.lua",
  "tests/property/phase_a_properties_spec.lua",
  "tests/integration/phase_b_persistence_spec.lua",
  "tests/property/phase_b_properties_spec.lua",
  "tests/integration/phase_c_moves_ai_spec.lua",
  "tests/integration/gym_runtime_spec.lua",
  "tests/integration/phase_d_bosses_spec.lua",
  "tests/property/gym_properties_spec.lua",
  "tests/integration/league_persistence_spec.lua",
  "tests/property/league_bird_simulation_spec.lua",
  "tests/integration/rival_version_paths_spec.lua",
  "tests/property/rival_fairness_spec.lua",
}
local function shell_quote(value)
  return "'" .. value:gsub("'", "'\\''") .. "'"
end
for _, relative in ipairs(chapter29Suites) do
  local command = "luajit " .. shell_quote(modRoot .. "/" .. relative)
  local status = os.execute(command)
  eq(status, 0, relative .. " remains green in the Chapter 29 aggregate")
end

if failures > 0 then
  io.stderr:write(string.format("%d/%d A-F Definition of Done checks failed\n",
    failures, checks))
  os.exit(1)
end
print(string.format("%d/%d A-F Definition of Done checks passed",
  checks, checks))
