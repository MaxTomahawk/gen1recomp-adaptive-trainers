local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")
local power = assert(loadfile(ROOT .. "/src/core/player_power.lua"))()

local checks, failures = 0, 0
local function check(condition, message)
  checks = checks + 1
  if not condition then
    failures = failures + 1
    io.stderr:write("FAIL ", message, "\n")
  end
end
local function eq(actual, expected, message)
  check(actual == expected,
    message .. " (expected " .. tostring(expected) .. ", got "
      .. tostring(actual) .. ")")
end

eq(power.reference({ { level = 20, hp = 0 } }), 20,
  "a fainted sole party member still counts")
eq(power.reference({ { level = 10 }, { level = 20 } }), 16,
  "two party members use the 60/40 weighted top levels")
eq(power.reference({ { level = 10 }, { level = 30 }, { level = 20 } }), 23,
  "three party members use the 50/30/20 weighted top levels")
eq(power.reference({ { level = 10 }, { level = 30 }, { level = 20 },
  { level = 100 } }), 63,
  "only the strongest three levels define ordinary trainer pressure")
eq(power.reference({}), 0, "an empty party has zero reference power")

local original = { { level = 10 }, { level = 30 }, { level = 20 } }
power.reference(original)
eq(original[1].level, 10, "reference calculation does not reorder save.party")

local profile = { initialCap = 6, initialCatchupFactor = 0.5 }
eq(power.initial_level(12, 14, 18, profile, 1), 13,
  "the four-level dead zone prevents catch-up but permits positive jitter")
eq(power.initial_level(12, 14, 19, profile, 0), 12,
  "a one-level gap beyond the dead zone rounds down to no boost")
eq(power.initial_level(12, 14, 24, profile, 0), 15,
  "catch-up applies the profile factor to the gap beyond four")
eq(power.initial_level(12, 14, 50, profile, 0), 18,
  "catch-up never exceeds the class initial cap")
eq(power.initial_level(12, 14, 24, profile, -1), 14,
  "seeded negative jitter adjusts the boosted slot by one")
eq(power.initial_level(12, 14, 18, profile, -1), 12,
  "negative jitter never pushes a slot below vanilla")

local refs = power.top_n({ { level = 38 }, { level = 34 } }, 3)
eq(refs[1], 38, "top-N keeps the strongest level first")
eq(refs[2], 34, "top-N keeps the available second level")
eq(refs[3], 34, "top-N repeats the lowest available level when short")

local badgeData = { constants = { badges = {
  { id = "BOULDERBADGE" }, { id = "CASCADEBADGE" },
  { id = "THUNDERBADGE" },
} } }
eq(power.badge_count({ badgeCount = 2 }, badgeData), 2,
  "an explicit public badge count is authoritative when available")
eq(power.badge_count({ inventory = {
  BOULDERBADGE = 1, CASCADEBADGE = true,
} }, badgeData), 2,
  "real Gen1 inventory badge items are counted from runtime constants")
eq(power.badge_count({ player = { badges = {
  BOULDERBADGE = true, CASCADEBADGE = false, THUNDERBADGE = true,
} } }, badgeData), 2,
  "structured public player badges remain a supported fallback")
eq(power.badge_count({ inventory = { BOULDERBADGE = 0 } }, badgeData), 0,
  "a numeric zero inventory value is not counted as an owned badge")

if failures > 0 then
  io.stderr:write(string.format("%d/%d player power checks failed\n",
    failures, checks))
  os.exit(1)
end
print(string.format("%d/%d player power checks passed", checks, checks))
