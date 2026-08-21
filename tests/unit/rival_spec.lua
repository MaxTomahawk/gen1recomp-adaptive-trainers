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
local function find_line(rows, line_id)
  for _, row in ipairs(rows or {}) do
    if row.lineId == line_id then return row end
  end
end
local function contains(values, wanted)
  for _, value in ipairs(values or {}) do
    if value == wanted then return true end
  end
  return false
end
local function party_top(party)
  local top = 0
  for _, mon in ipairs(party or {}) do top = math.max(top, mon.level) end
  return top
end
local function anchor_signature(anchor)
  local out = {}
  for _, row in ipairs(anchor.slots) do
    out[#out + 1] = row.species .. tostring(row.floor)
  end
  return table.concat(out, ",")
end
local function root()
  return { seedHi = 0x12345678, seedLo = 0x0fedcba9,
    rival = {}, yellowRival = {} }
end
local function context(version, play_time, starter_line, starter_species,
    levels)
  local party = {}
  for index, level in ipairs(levels or { 5 }) do
    party[index] = { level = level, species = "PLAYER_" .. index,
      moves = { "MOVE_" .. index } }
  end
  return { version = version, playTime = play_time,
    rivalStarterLine = starter_line, rivalStarterSpecies = starter_species,
    playerParty = party }
end

eq(#windows.encounterOrder, 8,
  "Rival data exposes all eight canonical journey encounters")
eq(#windows.windowOrder, 7,
  "Rival data exposes one journey window between each encounter")
eq(windows.tuning.aiTier, 3, "Rival AI tier is data-driven")
eq(windows.tuning.attachment.coreThreshold, 30,
  "Rival core threshold is data-driven")
eq(windows.tuning.levels.pressureFactor, 0.35,
  "Rival player pressure is data-driven")
eq(windows.tuning.scoring.roleCoverage, 0.28,
  "Rival team objective weights are data-driven")
local invalid_tuning = {
  attachment = {}, scoring = {}, levels = {}, aiTier = 3,
}
local tuning_ok, tuning_error = pcall(function()
  assert(loadfile(ROOT .. "/src/core/rival.lua"))()({
    rng = rng, player_power = player_power, windows = windows,
    tuning = invalid_tuning,
  })
end)
check(not tuning_ok
    and tostring(tuning_error):find("Rival tuning attachment.starter", 1, true),
  "Rival tuning rejects missing numeric fields with a precise error")
local expected_windows = {
  ROUTE_22_EARLY = { 1, 1, 4 }, CERULEAN = { 2, 2, 6 },
  SS_ANNE = { 0, 1, 6 }, POKEMON_TOWER = { 1, 2, 4 },
  SILPH_CO = { 0, 1, 3 }, ROUTE_22_LATE = { 1, 1, 6 },
  CHAMPION = { 0, 1, 2 },
}
for encounter_id, expected in pairs(expected_windows) do
  local window = windows.for_encounter(encounter_id)
  eq(window.minAcquisitions, expected[1],
    encounter_id .. " preserves its normative minimum budget")
  eq(window.maxAcquisitions, expected[2],
    encounter_id .. " preserves its normative maximum budget")
  eq(#window.areas, expected[3],
    encounter_id .. " preserves every named plausible area group")
end

local rb_anchor = windows.anchor("red", "CHAMPION", "SQUIRTLE_LINE")
eq(rb_anchor.slots[1].species, "PIDGEOT",
  "Red/Blue Blastoise Champion row begins with Pidgeot")
eq(rb_anchor.slots[5].species, "EXEGGUTOR",
  "Red/Blue Blastoise Champion row keeps Exeggutor at level 63")
eq(rb_anchor.slots[6].species, "BLASTOISE",
  "Red/Blue starter path keeps Blastoise as signature")
eq(rb_anchor.slots[6].floor, 65,
  "Red/Blue Champion starter keeps the exact canonical floor")
local yellow_anchor = windows.anchor("yellow", "CHAMPION", "EEVEE_LINE",
  "JOLTEON")
eq(yellow_anchor.slots[4].species, "CLOYSTER",
  "Yellow Jolteon Champion path keeps the exact Cloyster row")
eq(yellow_anchor.slots[6].species, "JOLTEON",
  "Yellow path resolves the exact Eevee outcome species")

local RB_ROWS = {
  SQUIRTLE_LINE = {
    OAK_LAB = "SQUIRTLE5",
    ROUTE_22_EARLY = "PIDGEY9,SQUIRTLE8",
    CERULEAN = "PIDGEOTTO18,ABRA15,RATTATA15,WARTORTLE17",
    SS_ANNE = "PIDGEOTTO19,RATICATE16,KADABRA18,WARTORTLE20",
    POKEMON_TOWER = "PIDGEOTTO25,GROWLITHE23,EXEGGCUTE22,KADABRA20,WARTORTLE25",
    SILPH_CO = "PIDGEOT37,GROWLITHE38,EXEGGCUTE35,ALAKAZAM35,BLASTOISE40",
    ROUTE_22_LATE = "PIDGEOT47,RHYHORN45,GROWLITHE45,EXEGGCUTE47,ALAKAZAM50,BLASTOISE53",
    CHAMPION = "PIDGEOT61,ALAKAZAM59,RHYDON61,ARCANINE61,EXEGGUTOR63,BLASTOISE65",
  },
  BULBASAUR_LINE = {
    OAK_LAB = "BULBASAUR5",
    ROUTE_22_EARLY = "PIDGEY9,BULBASAUR8",
    CERULEAN = "PIDGEOTTO18,ABRA15,RATTATA15,IVYSAUR17",
    SS_ANNE = "PIDGEOTTO19,RATICATE16,KADABRA18,IVYSAUR20",
    POKEMON_TOWER = "PIDGEOTTO25,GYARADOS23,GROWLITHE22,KADABRA20,IVYSAUR25",
    SILPH_CO = "PIDGEOT37,GYARADOS38,GROWLITHE35,ALAKAZAM35,VENUSAUR40",
    ROUTE_22_LATE = "PIDGEOT47,RHYHORN45,GYARADOS45,GROWLITHE47,ALAKAZAM50,VENUSAUR53",
    CHAMPION = "PIDGEOT61,ALAKAZAM59,RHYDON61,GYARADOS61,ARCANINE63,VENUSAUR65",
  },
  CHARMANDER_LINE = {
    OAK_LAB = "CHARMANDER5",
    ROUTE_22_EARLY = "PIDGEY9,CHARMANDER8",
    CERULEAN = "PIDGEOTTO18,ABRA15,RATTATA15,CHARMELEON17",
    SS_ANNE = "PIDGEOTTO19,RATICATE16,KADABRA18,CHARMELEON20",
    POKEMON_TOWER = "PIDGEOTTO25,EXEGGCUTE23,GYARADOS22,KADABRA20,CHARMELEON25",
    SILPH_CO = "PIDGEOT37,EXEGGCUTE38,GYARADOS35,ALAKAZAM35,CHARIZARD40",
    ROUTE_22_LATE = "PIDGEOT47,RHYHORN45,EXEGGCUTE45,GYARADOS47,ALAKAZAM50,CHARIZARD53",
    CHAMPION = "PIDGEOT61,ALAKAZAM59,RHYDON61,EXEGGUTOR61,GYARADOS63,CHARIZARD65",
  },
}
for starter_line, encounters in pairs(RB_ROWS) do
  for encounter_id, expected in pairs(encounters) do
    for _, version in ipairs({ "red", "blue" }) do
      eq(anchor_signature(windows.anchor(version, encounter_id, starter_line)),
        expected, version .. " " .. starter_line .. " " .. encounter_id
          .. " preserves the exact canonical row")
    end
  end
end

local YELLOW_ROWS = {
  JOLTEON = {
    POKEMON_TOWER = "FEAROW25,SHELLDER23,VULPIX22,SANDSHREW20,EEVEE25",
    SILPH_CO = "SANDSLASH38,NINETALES35,CLOYSTER37,KADABRA35,JOLTEON40",
    ROUTE_22_LATE = "SANDSLASH47,EXEGGCUTE45,NINETALES45,CLOYSTER47,KADABRA50,JOLTEON53",
    CHAMPION = "SANDSLASH61,ALAKAZAM59,EXEGGUTOR61,CLOYSTER61,NINETALES63,JOLTEON65",
  },
  FLAREON = {
    POKEMON_TOWER = "FEAROW25,MAGNEMITE23,SHELLDER22,SANDSHREW20,EEVEE25",
    SILPH_CO = "SANDSLASH38,CLOYSTER35,MAGNETON37,KADABRA35,FLAREON40",
    ROUTE_22_LATE = "SANDSLASH47,EXEGGCUTE45,CLOYSTER45,MAGNETON47,KADABRA50,FLAREON53",
    CHAMPION = "SANDSLASH61,ALAKAZAM59,EXEGGUTOR61,MAGNETON61,CLOYSTER63,FLAREON65",
  },
  VAPOREON = {
    POKEMON_TOWER = "FEAROW25,VULPIX23,MAGNEMITE22,SANDSHREW20,EEVEE25",
    SILPH_CO = "SANDSLASH38,MAGNETON35,NINETALES37,KADABRA35,VAPOREON40",
    ROUTE_22_LATE = "SANDSLASH47,EXEGGCUTE45,MAGNETON45,NINETALES47,KADABRA50,VAPOREON53",
    CHAMPION = "SANDSLASH61,ALAKAZAM59,EXEGGUTOR61,NINETALES61,MAGNETON63,VAPOREON65",
  },
}
for outcome_id, encounters in pairs(YELLOW_ROWS) do
  for encounter_id, expected in pairs(encounters) do
    eq(anchor_signature(windows.anchor("yellow", encounter_id,
      "EEVEE_LINE", outcome_id)), expected,
      "yellow " .. outcome_id .. " " .. encounter_id
        .. " preserves the exact canonical row")
  end
end

local save = root()
local oak_party, state = rival.build("OAK_LAB",
  context("red", 0, "SQUIRTLE_LINE", "SQUIRTLE", { 5 }), save)
eq(#oak_party, 1, "Oak Lab creates only the Rival starter")
eq(oak_party[1].species, "SQUIRTLE",
  "Red/Blue uses the explicitly supplied version-correct starter")
eq(oak_party[1].level, 5, "Oak Lab respects the canonical level floor")
eq(#state.owned, 1, "the starter is persisted in the owned collection")
eq(state.owned[1].attachment, 100,
  "the starter begins at attachment 100")
eq(state.attachmentById[state.owned[1].id], 100,
  "the attachment index mirrors the starter authority")
local oak_rerun = rival.build("OAK_LAB",
  context("red", 99, "CHARMANDER_LINE", "CHARMANDER", { 99 }), save)
check(same(oak_party, oak_rerun),
  "a pending Rival encounter is byte-equivalent across reloads")
eq(state.starterLine, "SQUIRTLE_LINE",
  "the persisted starter cannot be changed by later context")

rival.record_result("OAK_LAB", "win", save)
eq(save.yellowRival.oakResult, nil,
  "Red/Blue results cannot mutate Yellow-only outcome state")
local early_party = rival.build("ROUTE_22_EARLY",
  context("red", 3600, nil, nil, { 12, 10, 8 }), save)
eq(#early_party, 2, "Route 22 early adds the one-line window budget")
eq(#state.owned, 2, "the acquired line persists in the owned roster")
local acquired = state.owned[2]
check(acquired.lineId ~= "SQUIRTLE_LINE",
  "the first journey acquisition is distinct from the starter")
check(contains(windows.for_encounter("ROUTE_22_EARLY").areas,
    acquired.originMap),
  "a catch origin belongs to the processed journey window")
eq(acquired.acquiredAt, 3600,
  "a catch records active play time as its acquisition time")
eq(acquired.attachment, 0, "new catches begin without attachment")
eq(party_top(early_party), 9,
  "low player power cannot reduce the Route 22 canonical floor")
local owned_before_reload = #state.owned
local early_rerun = rival.build("ROUTE_22_EARLY",
  context("red", 7200, nil, nil, { 100 }), save)
check(same(early_party, early_rerun),
  "reloading a pending journey encounter cannot reroll its party")
eq(#state.owned, owned_before_reload,
  "reloading cannot duplicate a window acquisition")

rival.record_result("ROUTE_22_EARLY", "lose", save)
for _, id in ipairs(state.activeIds) do
  local mon
  for _, candidate in ipairs(state.owned) do
    if candidate.id == id then mon = candidate; break end
  end
  local expected_uses = mon.lineId == state.starterLine and 2 or 1
  eq(mon.useCount, expected_uses,
    "each deployment adds exactly one use to the persistent history")
  if mon.lineId == state.starterLine then
    eq(mon.attachment, 100, "starter attachment remains fixed at 100")
  else
    eq(mon.attachment, 10,
      "a deployed non-starter receives ten attachment points")
  end
end

local early_nonstarter = state.owned[2]
early_nonstarter.attachment = 75
state.attachmentById[early_nonstarter.id] = 75
rival.build("ROUTE_22_EARLY",
  context("red", 8000, nil, nil, { 12, 10, 8 }), save)
rival.record_result("ROUTE_22_EARLY", "lose", save)
eq(early_nonstarter.attachment, 80,
  "a non-starter attachment increment saturates at 80")
rival.build("ROUTE_22_EARLY",
  context("red", 9000, nil, nil, { 12, 10, 8 }), save)
rival.record_result("ROUTE_22_EARLY", "lose", save)
eq(early_nonstarter.attachment, 80,
  "repeated use cannot exceed the non-starter attachment cap")

local cerulean_party = rival.build("CERULEAN",
  context("red", 10800, nil, nil, { 20, 18, 16 }), save)
eq(#cerulean_party, 4,
  "Cerulean uses its four-slot canonical team shape")
eq(#state.journeyEvents, 2,
  "each processed route window leaves one persistent history event")
local cerulean_event = state.journeyEvents[2]
eq(cerulean_event.encounterId, "CERULEAN",
  "the acquisition history identifies its destination encounter")
eq(#cerulean_event.acquiredIds, 2,
  "the fixed Cerulean acquisition budget is applied once")
local after_cerulean = #state.owned
local _ = rival.build("CERULEAN",
  context("red", 20000, nil, nil, { 80 }), save)
eq(#state.owned, after_cerulean,
  "the same encounter never processes its route window twice")

local pressure_save = root()
local pressure_party, pressure_state = rival.build("CHAMPION",
  context("blue", 12 * 3600, "SQUIRTLE_LINE", "SQUIRTLE",
    { 100, 100, 100, 100, 100, 100 }), pressure_save)
eq(pressure_state.pending.encounterTop, 72,
  "time momentum and player pressure follow the bounded formula")
eq(party_top(pressure_party), 72,
  "the Champion top applies the bounded encounter pressure")
for index, mon in ipairs(pressure_party) do
  check(mon.level >= pressure_state.pending.slotFloors[index],
    "every active slot respects its canonical floor")
  check(mon.level <= 73,
    "no active slot can exceed the canonical +8 cap")
  check(mon.level <= 102,
    "no active slot can exceed the player-reference +2 cap")
end

local rebound_save = root()
local high_party, rebound_state = rival.build("ROUTE_22_EARLY",
  context("red", 12 * 3600, "SQUIRTLE_LINE", "SQUIRTLE",
    { 100, 100, 100 }), rebound_save)
eq(high_party[1].level, 16,
  "a high reference applies the exact bounded time/player pressure formula")
eq(high_party[2].level, 15,
  "high-reference relative offsets are preserved during training")
local trained_levels = {}
for _, mon in ipairs(rebound_state.owned) do
  trained_levels[mon.id] = mon.level
end
rival.record_result("ROUTE_22_EARLY", "win", rebound_save)
local low_party, low_state = rival.build("ROUTE_22_EARLY",
  context("red", 12 * 3600 + 60, nil, nil, { 10 }), rebound_save)
eq(low_state.pending.encounterTop, 9,
  "the repeated encounter recomputes its current bounded top")
eq(low_party[1].level, 9,
  "a trained owned bird is fielded at the current canonical top")
eq(low_party[2].level, 8,
  "battle-local materialization restores the canonical relative offset")
for _, mon in ipairs(low_state.owned) do
  check(mon.level >= trained_levels[mon.id],
    "battle-local bounds never lower persistent owned training authority")
end

local rotation_save = root()
rotation_save.rival = {
  starterLine = "SQUIRTLE_LINE", starterSpecies = "SQUIRTLE",
  encounterIndex = 8, lastEncounterAt = 0,
  journeySeed = { hi = 1, lo = 2 }, attachmentById = {}, pathFlags = {},
  journeyEvents = {}, activeIds = {}, owned = {
    { id = "starter", lineId = "SQUIRTLE_LINE", species = "BLASTOISE",
      level = 65, attachment = 100, useCount = 8, isStarter = true },
    { id = "bird", lineId = "PIDGEY_LINE", species = "PIDGEOT",
      level = 61, attachment = 0, useCount = 0 },
    { id = "psychic", lineId = "ABRA_LINE", species = "ALAKAZAM",
      level = 59, attachment = 0, useCount = 0 },
    { id = "ground", lineId = "RHYHORN_LINE", species = "RHYDON",
      level = 61, attachment = 0, useCount = 0 },
    { id = "fire", lineId = "GROWLITHE_LINE", species = "ARCANINE",
      level = 61, attachment = 0, useCount = 0 },
    { id = "grass", lineId = "EXEGGCUTE_LINE", species = "EXEGGUTOR",
      level = 63, attachment = 0, useCount = 0 },
    { id = "core", lineId = "GROWLITHE_LINE", species = "ARCANINE",
      level = 61, attachment = 40, useCount = 4 },
  },
}
for _, mon in ipairs(rotation_save.rival.owned) do
  rotation_save.rival.attachmentById[mon.id] = mon.attachment
end
local _, rotated = rival.build("CHAMPION",
  context("red", 0, nil, nil, { 65, 63, 61 }), rotation_save)
check(contains(rotated.activeIds, "starter"),
  "the starter is a hard inclusion in every team")
check(contains(rotated.activeIds, "core"),
  "attachment 30 grants a core bonus during team rotation")
eq(#rotated.activeIds, 6,
  "the Champion rotates exactly six owned Pokémon into battle")

local function yellow_outcome(oak_result, route_result, skip_route)
  local yellow_save = root()
  rival.build("OAK_LAB",
    context("yellow", 0, "EEVEE_LINE", "EEVEE", { 5 }), yellow_save)
  rival.record_result("OAK_LAB", oak_result, yellow_save)
  if route_result then
    if not skip_route then
      rival.build("ROUTE_22_EARLY",
        context("yellow", 1800, nil, nil, { 9 }), yellow_save)
    end
    rival.record_result("ROUTE_22_EARLY", route_result, yellow_save)
  end
  local party, yellow_state = rival.build("SILPH_CO",
    context("yellow", 8 * 3600, nil, nil, { 40, 38, 35 }), yellow_save)
  return find_line(yellow_state.owned, "EEVEE_LINE").species,
    yellow_save.yellowRival.eeveeOutcome, party
end

local species, outcome = yellow_outcome("lose", "win")
eq(species, "VAPOREON", "losing Oak Lab produces exactly Vaporeon")
eq(outcome, "VAPOREON", "Vaporeon outcome is persisted in mod.save")
species, outcome = yellow_outcome("win", "win")
eq(species, "JOLTEON",
  "winning both early Yellow battles produces exactly Jolteon")
eq(outcome, "JOLTEON", "Jolteon outcome is persisted in mod.save")
species, outcome = yellow_outcome("win", "lose")
eq(species, "FLAREON",
  "Oak win plus Route 22 loss produces exactly Flareon")
species, outcome = yellow_outcome("win", "skip", true)
eq(species, "FLAREON",
  "Oak win plus skipped Route 22 produces exactly Flareon")

local variable_counts = {
  SS_ANNE = {}, POKEMON_TOWER = {}, SILPH_CO = {}, CHAMPION = {},
}
for sample = 1, 128 do
  local sampled_root = { seedHi = sample * 7919, seedLo = sample * 104729,
    rival = {}, yellowRival = {} }
  rival.build("CHAMPION", context("red", sample * 997,
    "SQUIRTLE_LINE", "SQUIRTLE", { 70, 60, 50 }), sampled_root)
  for _, event in ipairs(sampled_root.rival.journeyEvents) do
    if variable_counts[event.encounterId] then
      variable_counts[event.encounterId][#event.acquiredIds] = true
    end
  end
end
check(variable_counts.SS_ANNE[0] and variable_counts.SS_ANNE[1],
  "the deterministic 0-1 SS Anne window can realize both budget outcomes")
check(variable_counts.POKEMON_TOWER[1] and variable_counts.POKEMON_TOWER[2],
  "the deterministic 1-2 Tower window can realize both budget outcomes")
check(variable_counts.SILPH_CO[0] and variable_counts.SILPH_CO[1],
  "the deterministic 0-1 Silph window can realize both budget outcomes")
check(variable_counts.CHAMPION[0] and variable_counts.CHAMPION[1],
  "the deterministic 0-1 Champion window can realize both budget outcomes")

local meta = assert(loadfile(ROOT .. "/src/data/line_meta.lua"))().build()
local stage_resolver = assert(loadfile(ROOT .. "/src/core/stage_resolver.lua"))()
local packages = assert(loadfile(ROOT .. "/src/data/move_packages.lua"))()
local movesets = assert(loadfile(ROOT .. "/src/core/movesets.lua"))()({
  rng = rng, packages = packages,
})
local rich_rival = assert(loadfile(ROOT .. "/src/core/rival.lua"))()({
  rng = rng, player_power = player_power, windows = windows,
})
local pokemon = {}
for _, line in pairs(meta.lines) do
  local previous
  for _, stage in ipairs(line.stages) do
    pokemon[stage.species] = { types = { "NORMAL" },
      level1Moves = { "FIX_TACKLE" },
      learnset = { { level = 1, move = "FIX_TACKLE" } },
      tmhm = {}, evolutions = {} }
    if previous then
      previous.evolutions[#previous.evolutions + 1] = {
        method = "LEVEL", level = 20, species = stage.species,
      }
    end
    previous = pokemon[stage.species]
  end
end
local service_root = root()
service_root.rival = copy(rotation_save.rival)
service_root.rival.pending = nil
service_root.rival.owned[#service_root.rival.owned + 1] = {
  id = "bench", lineId = "DIGLETT_LINE", species = "DIGLETT",
  level = 1, attachment = 0, useCount = 0,
}
service_root.rival.attachmentById.bench = 0
local service_party, service_state = rich_rival.build("CHAMPION",
  context("red", 12 * 3600, nil, nil, { 70, 60, 50 }), service_root, {
    meta = meta, pokemon = pokemon,
    moves = { FIX_TACKLE = { type = "NORMAL", power = 40, accuracy = 100 } },
    stage_resolver = stage_resolver, movesets = movesets,
  })
local trained_bench = find_line(service_state.owned, "DIGLETT_LINE")
eq(trained_bench.species, "DUGTRIO",
  "a non-anchor owned line evolves legally from runtime metadata")
check(trained_bench.level >= 62,
  "a non-anchor owned line trains with the persistent Rival collection")
check(trained_bench.moves and #trained_bench.moves > 0,
  "a non-anchor owned line persists a legal T3 moveset")
for _, mon in ipairs(service_party) do
  check(mon.moves and #mon.moves > 0,
    "every active Rival instance materializes its persistent legal moves")
end

if failures > 0 then error(failures .. " rival assertion(s) failed", 0) end
print(("rival: %d/%d checks passed"):format(checks, checks))
