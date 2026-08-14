local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local rng = assert(loadfile(ROOT .. "/src/core/rng.lua"))()
local stage_resolver = assert(loadfile(ROOT .. "/src/core/stage_resolver.lua"))()
local roster = assert(loadfile(ROOT .. "/src/core/roster.lua"))()({
  rng = rng, stage_resolver = stage_resolver,
})

local checks, failures = 0, 0
local function check(condition, message)
  checks = checks + 1
  if not condition then failures = failures + 1; io.stderr:write("FAIL ", message, "\n") end
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (expected " .. tostring(expected)
    .. ", got " .. tostring(actual) .. ")")
end

local data = { maps = {
  ROUTE = { connections = { west = { map = "TOWN" } }, warps = {} },
  TOWN = { connections = { east = { map = "ROUTE" } },
    warps = { { destMap = "CENTER" } } },
  CENTER = { connections = {}, warps = { { destMap = "TOWN" } }, objects = {
    { name = "TESTPOKECENTER_NURSE", text = "TEXT_TESTPOKECENTER_NURSE" },
  } },
  REMOTE = { connections = {}, warps = {} },
} }
local index = roster.center_index(data)
eq(roster.center_distance(index, "CENTER", 2), 0,
  "generated nurse metadata identifies the Center map")
eq(roster.center_distance(index, "TOWN", 2), 1,
  "Center BFS crosses one plausible world edge")
eq(roster.center_distance(index, "ROUTE", 2), 2,
  "Center BFS respects an exact two-edge radius")
eq(roster.center_distance(index, "ROUTE", 1), nil,
  "Center access outside class radius is unavailable")
eq(roster.center_distance(index, "REMOTE", 2), nil,
  "time cannot teleport a stationary NPC to a disconnected Center")

local function full_state()
  local state = { owned = {}, activeIds = {} }
  for i = 1, 7 do
    state.owned[i] = { id = "m" .. i, lineId = "L" .. i,
      species = "S" .. i, level = 10 + i, acquiredAt = i,
      useCount = i, attachment = i, roleSeed = i }
    if i <= 6 then state.activeIds[i] = "m" .. i end
  end
  return state
end

local blocked = full_state()
local before = table.concat(blocked.activeIds, ",")
local changed = roster.rotate(blocked, { rosterBehavior = "collector",
  targetOwned = 6 }, nil, {})
eq(changed, false, "a full party cannot rotate without plausible Center access")
eq(table.concat(blocked.activeIds, ","), before,
  "a benched catch remains benched without Center access")

local collector = full_state()
check(roster.rotate(collector, { rosterBehavior = "collector", targetOwned = 6 },
  1, {}), "a collector rotates a full party at a reachable Center")
local collectorActive = {}
for _, id in ipairs(collector.activeIds) do collectorActive[id] = true end
check(collectorActive.m7,
  "collector rotation gives the newly acquired collection member active time")

local casual = full_state()
eq(roster.rotate(casual, { rosterBehavior = "casual", targetOwned = 6 },
  1, {}), false, "casual trainers rarely disturb a full active party")
eq(table.concat(casual.activeIds, ","), before,
  "casual Center access alone does not force rotation")

local expert = full_state()
expert.owned[7].level = 40
check(roster.rotate(expert, { rosterBehavior = "expert", targetOwned = 6 },
  1, { meta = { bySpecies = {} }, pokemon = {} }),
  "experts may rotate selectively at a reachable Center")
local expertActive = {}
for _, id in ipairs(expert.activeIds) do expertActive[id] = true end
check(expertActive.m7, "expert selection promotes a clearly stronger bench member")

local constrained = full_state()
constrained.owned[7].level = 50
constrained.owned[7].lineId = "L1"
roster.rotate(constrained, { rosterBehavior = "expert", targetOwned = 6,
  allowDuplicateLines = false, maxRarity3 = 1 }, 1,
  { meta = { bySpecies = {} }, pokemon = {} })
local lineCounts = {}
for _, id in ipairs(constrained.activeIds) do
  local mon
  for _, row in ipairs(constrained.owned) do if row.id == id then mon = row end end
  lineCounts[mon.lineId] = (lineCounts[mon.lineId] or 0) + 1
end
eq(lineCounts.L1, 1,
  "expert rotation cannot promote a duplicate line when alternatives exist")

local repeated = full_state()
repeated.owned[7].level = 40
roster.rotate(repeated, { rosterBehavior = "expert", targetOwned = 6 }, 1,
  { meta = { bySpecies = {} }, pokemon = {} })
eq(table.concat(repeated.activeIds, ","), table.concat(expert.activeIds, ","),
  "roster rotation is deterministic")

if failures > 0 then
  io.stderr:write(string.format("%d/%d roster checks failed\n", failures, checks))
  os.exit(1)
end
print(string.format("%d/%d roster checks passed", checks, checks))
