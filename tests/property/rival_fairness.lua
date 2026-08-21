local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local rng = assert(loadfile(ROOT .. "/src/core/rng.lua"))()
local player_power = assert(loadfile(ROOT .. "/src/core/player_power.lua"))()
local windows = assert(loadfile(ROOT .. "/src/data/rival_windows.lua"))()
local rival = assert(loadfile(ROOT .. "/src/core/rival.lua"))()({
  rng = rng, player_power = player_power, windows = windows,
})

local checks, failures = 0, 0
local function check(condition, message)
  checks = checks + 1
  if not condition then
    failures = failures + 1
    if failures <= 12 then io.stderr:write("FAIL ", message, "\n") end
  end
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
local function contains(values, wanted)
  for _, value in ipairs(values or {}) do
    if value == wanted then return true end
  end
  return false
end
local function party_for(label, levels)
  local party = {}
  for index, level in ipairs(levels) do
    party[index] = { level = level, species = label .. "_SPECIES_" .. index,
      moves = { label .. "_MOVE_A_" .. index, label .. "_MOVE_B_" .. index } }
  end
  return party
end
local function new_root(sample, version)
  local root = { seedHi = sample * 7919, seedLo = sample * 104729,
    rival = {}, yellowRival = {} }
  if version == "yellow" then
    local outcomes = {
      { oakResult = "lose", route22EarlyResult = "win" },
      { oakResult = "win", route22EarlyResult = "win" },
      { oakResult = "win", route22EarlyResult = "lose" },
      { oakResult = "win", route22EarlyResult = "skip" },
    }
    local flags = outcomes[(sample - 1) % #outcomes + 1]
    root.yellowRival.oakResult = flags.oakResult
    root.yellowRival.route22EarlyResult = flags.route22EarlyResult
  end
  return root
end
local STARTERS = {
  red = { "BULBASAUR_LINE", "BULBASAUR" },
  blue = { "CHARMANDER_LINE", "CHARMANDER" },
  yellow = { "EEVEE_LINE", "EEVEE" },
}
local LEGENDARY = {
  ARTICUNO = true, ZAPDOS = true, MOLTRES = true, MEWTWO = true, MEW = true,
}

for sample = 1, 300 do
  local levels = {
    1 + sample * 7 % 100, 1 + sample * 11 % 100,
    1 + sample * 17 % 100, 1 + sample * 23 % 100,
    1 + sample * 29 % 100, 1 + sample * 31 % 100,
  }
  local play_time = sample * 977
  for _, version in ipairs({ "red", "blue", "yellow" }) do
    local starter = STARTERS[version]
    local root_a = new_root(sample, version)
    local root_b = new_root(sample, version)
    local party_a, state_a = rival.build("CHAMPION", {
      version = version, playTime = play_time,
      rivalStarterLine = starter[1], rivalStarterSpecies = starter[2],
      playerParty = party_for("POWERFUL", levels),
      playerSpecies = { "MEWTWO", "ARTICUNO", "ZAPDOS" },
      playerMoves = { "PSYCHIC", "BLIZZARD", "THUNDERBOLT" },
    }, root_a)
    local party_b, state_b = rival.build("CHAMPION", {
      version = version, playTime = play_time,
      rivalStarterLine = starter[1], rivalStarterSpecies = starter[2],
      playerParty = party_for("HARMLESS", levels),
      playerSpecies = { "MAGIKARP", "CATERPIE" },
      playerMoves = { "SPLASH", "STRING_SHOT" },
    }, root_b)

    check(same(party_a, party_b),
      version .. " Rival party is blind to complete player species/move changes")
    check(same(state_a.owned, state_b.owned)
        and same(state_a.activeIds, state_b.activeIds)
        and same(state_a.journeyEvents, state_b.journeyEvents),
      version .. " Rival journey authority uses levels/time/owned state only")
    check(same(rival.build("CHAMPION", {
      version = version, playTime = play_time + 999999,
      playerParty = party_for("RELOAD", { 100, 100, 100 }),
    }, root_a), party_a),
      version .. " pending party remains byte-equivalent on reload")

    local outcome = version == "yellow" and root_a.yellowRival.eeveeOutcome or nil
    local anchor = windows.anchor(version, "CHAMPION", starter[1], outcome)
    check(#party_a == anchor.activeCount,
      version .. " Champion always rotates the exact canonical party size")
    check(#state_a.activeIds == anchor.activeCount,
      version .. " active id authority matches the materialized party")
    check(contains(state_a.activeIds, state_a.owned[1].id),
      version .. " starter is present in every generated Champion team")
    local reference = player_power.reference(party_for("LEVELS", levels))
    local cap = math.max(anchor.canonFloor,
      math.min(anchor.canonFloor + 8, reference + 2))
    check(state_a.pending.encounterTop >= anchor.canonFloor
        and state_a.pending.encounterTop <= cap,
      version .. " pressure top remains inside floor/+8/P+2 bounds")
    for index, mon in ipairs(party_a) do
      local slot_floor = anchor.slots[index].floor
      local exact_level = math.min(windows.tuning.levels.globalCap,
        math.max(slot_floor, state_a.pending.encounterTop
          + slot_floor - anchor.canonFloor))
      check(mon.level == exact_level,
        version .. " every rotated slot preserves its exact relative offset")
      check(mon.level >= anchor.slots[index].floor,
        version .. " every rotated slot respects its canonical floor")
      check(mon.level <= 100,
        version .. " every Rival level stays within the global cap")
      check(not LEGENDARY[mon.species],
        version .. " active Rival roster never contains a Legendary/Mythical")
    end

    local by_id = {}
    for _, mon in ipairs(state_a.owned) do
      by_id[mon.id] = mon
      check(not LEGENDARY[mon.species],
        version .. " owned Rival collection never acquires a Legendary/Mythical")
      if mon.isStarter then
        check(mon.attachment == 100,
          version .. " starter attachment is always exactly 100")
      else
        check(mon.attachment >= 0 and mon.attachment <= 80,
          version .. " non-starter attachment remains in the 0..80 range")
      end
    end
    check(#state_a.journeyEvents == #windows.windowOrder,
      version .. " direct Champion reach processes every window exactly once")
    for _, event in ipairs(state_a.journeyEvents) do
      local window = windows.for_encounter(event.encounterId)
      check(#event.acquiredIds >= window.minAcquisitions
          and #event.acquiredIds <= window.maxAcquisitions,
        version .. " acquisition history respects every window budget")
      for _, id in ipairs(event.acquiredIds) do
        check(by_id[id] ~= nil,
          version .. " every acquisition event points at persistent owned state")
        check(contains(window.areas, by_id[id].originMap),
          version .. " every persistent origin belongs to its exact window")
      end
    end
  end
end

-- A hostile player record proves the builder asks only for the level field.
local guarded = setmetatable({ level = 65 }, {
  __index = function(_, key)
    error("Rival fairness violation: read player field " .. tostring(key))
  end,
})
local guarded_root = new_root(999, "yellow")
local guarded_party = rival.build("CHAMPION", {
  version = "yellow", playTime = 36000,
  rivalStarterLine = "EEVEE_LINE", rivalStarterSpecies = "EEVEE",
  playerParty = { guarded, guarded, guarded },
}, guarded_root)
check(#guarded_party == 6,
  "fairness guard permits level-only player records without other fields")

if failures > 0 then error(failures .. " Rival property assertion(s) failed", 0) end
print(("rival fairness: %d/%d checks passed"):format(checks, checks))
