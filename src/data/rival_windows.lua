local M = {}

M.encounterOrder = {
  "OAK_LAB", "ROUTE_22_EARLY", "CERULEAN", "SS_ANNE",
  "POKEMON_TOWER", "SILPH_CO", "ROUTE_22_LATE", "CHAMPION",
}

M.windowOrder = {
  "ROUTE_22_EARLY", "CERULEAN", "SS_ANNE", "POKEMON_TOWER",
  "SILPH_CO", "ROUTE_22_LATE", "CHAMPION",
}

local BATTLE_PATHS = {
  red = {
    { "OAK_LAB", "OAKS_LAB", "OPP_RIVAL1", 1, 3 },
    { "ROUTE_22_EARLY", "ROUTE_22", "OPP_RIVAL1", 4, 6 },
    { "CERULEAN", "CERULEAN_CITY", "OPP_RIVAL1", 7, 9 },
    { "SS_ANNE", "SS_ANNE_2F", "OPP_RIVAL2", 1, 3 },
    { "POKEMON_TOWER", "POKEMON_TOWER_2F", "OPP_RIVAL2", 4, 6 },
    { "SILPH_CO", "SILPH_CO_7F", "OPP_RIVAL2", 7, 9 },
    { "ROUTE_22_LATE", "ROUTE_22", "OPP_RIVAL2", 10, 12 },
    { "CHAMPION", "CHAMPIONS_ROOM", "OPP_RIVAL3", 1, 3 },
  },
  yellow = {
    { "OAK_LAB", "OAKS_LAB", "OPP_RIVAL1", 1, 1 },
    { "ROUTE_22_EARLY", "ROUTE_22", "OPP_RIVAL1", 2, 2 },
    { "CERULEAN", "CERULEAN_CITY", "OPP_RIVAL1", 3, 3 },
    { "SS_ANNE", "SS_ANNE_2F", "OPP_RIVAL2", 1, 1 },
    { "POKEMON_TOWER", "POKEMON_TOWER_2F", "OPP_RIVAL2", 2, 4 },
    { "SILPH_CO", "SILPH_CO_7F", "OPP_RIVAL2", 5, 7 },
    { "ROUTE_22_LATE", "ROUTE_22", "OPP_RIVAL2", 8, 10 },
    { "CHAMPION", "CHAMPIONS_ROOM", "OPP_RIVAL3", 1, 3 },
  },
}
BATTLE_PATHS.blue = BATTLE_PATHS.red

local WINDOWS = {
  ROUTE_22_EARLY = {
    minAcquisitions = 1, maxAcquisitions = 1,
    areas = { "PALLET_TOWN", "ROUTE_1", "VIRIDIAN_CITY", "ROUTE_22" },
  },
  CERULEAN = {
    minAcquisitions = 2, maxAcquisitions = 2,
    areas = { "ROUTE_2", "VIRIDIAN_FOREST", "ROUTE_3", "MT_MOON",
      "ROUTE_4", "CERULEAN_CITY" },
  },
  SS_ANNE = {
    minAcquisitions = 0, maxAcquisitions = 1,
    areas = { "ROUTE_24", "ROUTE_25", "ROUTE_5", "ROUTE_6",
      "VERMILION_CITY", "ROUTE_11_DIGLETTS_CAVE" },
  },
  POKEMON_TOWER = {
    minAcquisitions = 1, maxAcquisitions = 2,
    areas = { "ROUTE_8_7", "CELADON_CITY", "LAVENDER_TOWN",
      "POKEMON_TOWER" },
  },
  SILPH_CO = {
    minAcquisitions = 0, maxAcquisitions = 1,
    areas = { "CELADON_CITY", "SAFFRON_CITY", "ROCKET_ACCESS" },
  },
  ROUTE_22_LATE = {
    minAcquisitions = 1, maxAcquisitions = 1,
    areas = { "FUCHSIA_ROUTES", "CYCLING_ROAD", "COASTAL_ROUTES",
      "SEAFOAM_ISLANDS", "CINNABAR_ISLAND", "SAFARI_ZONE" },
  },
  CHAMPION = {
    minAcquisitions = 0, maxAcquisitions = 1,
    areas = { "VICTORY_ROAD", "INDIGO_PLATEAU" },
  },
}

local LINE_TRAITS = {
  BULBASAUR_LINE = { role = "control", type = "GRASS" },
  CHARMANDER_LINE = { role = "fast_damage", type = "FIRE" },
  SQUIRTLE_LINE = { role = "bulky_damage", type = "WATER" },
  PIDGEY_LINE = { role = "fast_physical", type = "FLYING" },
  SPEAROW_LINE = { role = "fast_physical", type = "FLYING" },
  RATTATA_LINE = { role = "fast_physical", type = "NORMAL" },
  ABRA_LINE = { role = "special_control", type = "PSYCHIC" },
  SANDSHREW_LINE = { role = "physical_wall", type = "GROUND" },
  DIGLETT_LINE = { role = "fast_physical", type = "GROUND" },
  GROWLITHE_LINE = { role = "fast_damage", type = "FIRE" },
  MAGIKARP_LINE = { role = "physical", type = "WATER" },
  EXEGGCUTE_LINE = { role = "control", type = "GRASS" },
  SHELLDER_LINE = { role = "physical_wall", type = "WATER" },
  VULPIX_LINE = { role = "control", type = "FIRE" },
  MAGNEMITE_LINE = { role = "special_control", type = "ELECTRIC" },
  RHYHORN_LINE = { role = "physical_wall", type = "GROUND" },
  EEVEE_LINE = { role = "balanced", type = "NORMAL" },
}

local STARTERS = {
  BULBASAUR_LINE = { "BULBASAUR", "IVYSAUR", "VENUSAUR" },
  CHARMANDER_LINE = { "CHARMANDER", "CHARMELEON", "CHARIZARD" },
  SQUIRTLE_LINE = { "SQUIRTLE", "WARTORTLE", "BLASTOISE" },
}

local function slot(line_id, species, floor)
  local traits = LINE_TRAITS[line_id] or { role = "balanced", type = "NORMAL" }
  return { lineId = line_id, species = species, floor = floor,
    role = traits.role, type = traits.type }
end

local function starter_species(starter_line, stage)
  local stages = assert(STARTERS[starter_line],
    "unsupported Red/Blue Rival starter line " .. tostring(starter_line))
  return stages[stage]
end

local function rb_anchor(encounter_id, starter_line)
  local base = starter_species(starter_line, 1)
  local middle = starter_species(starter_line, 2)
  local final = starter_species(starter_line, 3)
  local shared = {
    OAK_LAB = { slot(starter_line, base, 5) },
    ROUTE_22_EARLY = {
      slot("PIDGEY_LINE", "PIDGEY", 9), slot(starter_line, base, 8),
    },
    CERULEAN = {
      slot("PIDGEY_LINE", "PIDGEOTTO", 18),
      slot("ABRA_LINE", "ABRA", 15),
      slot("RATTATA_LINE", "RATTATA", 15),
      slot(starter_line, middle, 17),
    },
    SS_ANNE = {
      slot("PIDGEY_LINE", "PIDGEOTTO", 19),
      slot("RATTATA_LINE", "RATICATE", 16),
      slot("ABRA_LINE", "KADABRA", 18),
      slot(starter_line, middle, 20),
    },
  }
  if shared[encounter_id] then return shared[encounter_id] end

  local path = {
    SQUIRTLE_LINE = {
      POKEMON_TOWER = {
        slot("PIDGEY_LINE", "PIDGEOTTO", 25),
        slot("GROWLITHE_LINE", "GROWLITHE", 23),
        slot("EXEGGCUTE_LINE", "EXEGGCUTE", 22),
        slot("ABRA_LINE", "KADABRA", 20),
        slot(starter_line, middle, 25),
      },
      SILPH_CO = {
        slot("PIDGEY_LINE", "PIDGEOT", 37),
        slot("GROWLITHE_LINE", "GROWLITHE", 38),
        slot("EXEGGCUTE_LINE", "EXEGGCUTE", 35),
        slot("ABRA_LINE", "ALAKAZAM", 35),
        slot(starter_line, final, 40),
      },
      ROUTE_22_LATE = {
        slot("PIDGEY_LINE", "PIDGEOT", 47),
        slot("RHYHORN_LINE", "RHYHORN", 45),
        slot("GROWLITHE_LINE", "GROWLITHE", 45),
        slot("EXEGGCUTE_LINE", "EXEGGCUTE", 47),
        slot("ABRA_LINE", "ALAKAZAM", 50),
        slot(starter_line, final, 53),
      },
      CHAMPION = {
        slot("PIDGEY_LINE", "PIDGEOT", 61),
        slot("ABRA_LINE", "ALAKAZAM", 59),
        slot("RHYHORN_LINE", "RHYDON", 61),
        slot("GROWLITHE_LINE", "ARCANINE", 61),
        slot("EXEGGCUTE_LINE", "EXEGGUTOR", 63),
        slot(starter_line, final, 65),
      },
    },
    BULBASAUR_LINE = {
      POKEMON_TOWER = {
        slot("PIDGEY_LINE", "PIDGEOTTO", 25),
        slot("MAGIKARP_LINE", "GYARADOS", 23),
        slot("GROWLITHE_LINE", "GROWLITHE", 22),
        slot("ABRA_LINE", "KADABRA", 20),
        slot(starter_line, middle, 25),
      },
      SILPH_CO = {
        slot("PIDGEY_LINE", "PIDGEOT", 37),
        slot("MAGIKARP_LINE", "GYARADOS", 38),
        slot("GROWLITHE_LINE", "GROWLITHE", 35),
        slot("ABRA_LINE", "ALAKAZAM", 35),
        slot(starter_line, final, 40),
      },
      ROUTE_22_LATE = {
        slot("PIDGEY_LINE", "PIDGEOT", 47),
        slot("RHYHORN_LINE", "RHYHORN", 45),
        slot("MAGIKARP_LINE", "GYARADOS", 45),
        slot("GROWLITHE_LINE", "GROWLITHE", 47),
        slot("ABRA_LINE", "ALAKAZAM", 50),
        slot(starter_line, final, 53),
      },
      CHAMPION = {
        slot("PIDGEY_LINE", "PIDGEOT", 61),
        slot("ABRA_LINE", "ALAKAZAM", 59),
        slot("RHYHORN_LINE", "RHYDON", 61),
        slot("MAGIKARP_LINE", "GYARADOS", 61),
        slot("GROWLITHE_LINE", "ARCANINE", 63),
        slot(starter_line, final, 65),
      },
    },
    CHARMANDER_LINE = {
      POKEMON_TOWER = {
        slot("PIDGEY_LINE", "PIDGEOTTO", 25),
        slot("EXEGGCUTE_LINE", "EXEGGCUTE", 23),
        slot("MAGIKARP_LINE", "GYARADOS", 22),
        slot("ABRA_LINE", "KADABRA", 20),
        slot(starter_line, middle, 25),
      },
      SILPH_CO = {
        slot("PIDGEY_LINE", "PIDGEOT", 37),
        slot("EXEGGCUTE_LINE", "EXEGGCUTE", 38),
        slot("MAGIKARP_LINE", "GYARADOS", 35),
        slot("ABRA_LINE", "ALAKAZAM", 35),
        slot(starter_line, final, 40),
      },
      ROUTE_22_LATE = {
        slot("PIDGEY_LINE", "PIDGEOT", 47),
        slot("RHYHORN_LINE", "RHYHORN", 45),
        slot("EXEGGCUTE_LINE", "EXEGGCUTE", 45),
        slot("MAGIKARP_LINE", "GYARADOS", 47),
        slot("ABRA_LINE", "ALAKAZAM", 50),
        slot(starter_line, final, 53),
      },
      CHAMPION = {
        slot("PIDGEY_LINE", "PIDGEOT", 61),
        slot("ABRA_LINE", "ALAKAZAM", 59),
        slot("RHYHORN_LINE", "RHYDON", 61),
        slot("EXEGGCUTE_LINE", "EXEGGUTOR", 61),
        slot("MAGIKARP_LINE", "GYARADOS", 63),
        slot(starter_line, final, 65),
      },
    },
  }
  return assert(path[starter_line] and path[starter_line][encounter_id],
    "missing Red/Blue Rival anchor " .. tostring(encounter_id))
end

local function yellow_anchor(encounter_id, outcome)
  local shared = {
    OAK_LAB = { slot("EEVEE_LINE", "EEVEE", 5) },
    ROUTE_22_EARLY = {
      slot("SPEAROW_LINE", "SPEAROW", 9),
      slot("EEVEE_LINE", "EEVEE", 8),
    },
    CERULEAN = {
      slot("SPEAROW_LINE", "SPEAROW", 18),
      slot("SANDSHREW_LINE", "SANDSHREW", 15),
      slot("RATTATA_LINE", "RATTATA", 15),
      slot("EEVEE_LINE", "EEVEE", 17),
    },
    SS_ANNE = {
      slot("SPEAROW_LINE", "SPEAROW", 19),
      slot("RATTATA_LINE", "RATTATA", 16),
      slot("SANDSHREW_LINE", "SANDSHREW", 18),
      slot("EEVEE_LINE", "EEVEE", 20),
    },
  }
  if shared[encounter_id] then return shared[encounter_id] end

  outcome = assert(outcome, "Yellow Eevee outcome is required for this anchor")
  local path = {
    JOLTEON = {
      POKEMON_TOWER = {
        slot("SPEAROW_LINE", "FEAROW", 25),
        slot("SHELLDER_LINE", "SHELLDER", 23),
        slot("VULPIX_LINE", "VULPIX", 22),
        slot("SANDSHREW_LINE", "SANDSHREW", 20),
        slot("EEVEE_LINE", "EEVEE", 25),
      },
      SILPH_CO = {
        slot("SANDSHREW_LINE", "SANDSLASH", 38),
        slot("VULPIX_LINE", "NINETALES", 35),
        slot("SHELLDER_LINE", "CLOYSTER", 37),
        slot("ABRA_LINE", "KADABRA", 35),
        slot("EEVEE_LINE", "JOLTEON", 40),
      },
      ROUTE_22_LATE = {
        slot("SANDSHREW_LINE", "SANDSLASH", 47),
        slot("EXEGGCUTE_LINE", "EXEGGCUTE", 45),
        slot("VULPIX_LINE", "NINETALES", 45),
        slot("SHELLDER_LINE", "CLOYSTER", 47),
        slot("ABRA_LINE", "KADABRA", 50),
        slot("EEVEE_LINE", "JOLTEON", 53),
      },
      CHAMPION = {
        slot("SANDSHREW_LINE", "SANDSLASH", 61),
        slot("ABRA_LINE", "ALAKAZAM", 59),
        slot("EXEGGCUTE_LINE", "EXEGGUTOR", 61),
        slot("SHELLDER_LINE", "CLOYSTER", 61),
        slot("VULPIX_LINE", "NINETALES", 63),
        slot("EEVEE_LINE", "JOLTEON", 65),
      },
    },
    FLAREON = {
      POKEMON_TOWER = {
        slot("SPEAROW_LINE", "FEAROW", 25),
        slot("MAGNEMITE_LINE", "MAGNEMITE", 23),
        slot("SHELLDER_LINE", "SHELLDER", 22),
        slot("SANDSHREW_LINE", "SANDSHREW", 20),
        slot("EEVEE_LINE", "EEVEE", 25),
      },
      SILPH_CO = {
        slot("SANDSHREW_LINE", "SANDSLASH", 38),
        slot("SHELLDER_LINE", "CLOYSTER", 35),
        slot("MAGNEMITE_LINE", "MAGNETON", 37),
        slot("ABRA_LINE", "KADABRA", 35),
        slot("EEVEE_LINE", "FLAREON", 40),
      },
      ROUTE_22_LATE = {
        slot("SANDSHREW_LINE", "SANDSLASH", 47),
        slot("EXEGGCUTE_LINE", "EXEGGCUTE", 45),
        slot("SHELLDER_LINE", "CLOYSTER", 45),
        slot("MAGNEMITE_LINE", "MAGNETON", 47),
        slot("ABRA_LINE", "KADABRA", 50),
        slot("EEVEE_LINE", "FLAREON", 53),
      },
      CHAMPION = {
        slot("SANDSHREW_LINE", "SANDSLASH", 61),
        slot("ABRA_LINE", "ALAKAZAM", 59),
        slot("EXEGGCUTE_LINE", "EXEGGUTOR", 61),
        slot("MAGNEMITE_LINE", "MAGNETON", 61),
        slot("SHELLDER_LINE", "CLOYSTER", 63),
        slot("EEVEE_LINE", "FLAREON", 65),
      },
    },
    VAPOREON = {
      POKEMON_TOWER = {
        slot("SPEAROW_LINE", "FEAROW", 25),
        slot("VULPIX_LINE", "VULPIX", 23),
        slot("MAGNEMITE_LINE", "MAGNEMITE", 22),
        slot("SANDSHREW_LINE", "SANDSHREW", 20),
        slot("EEVEE_LINE", "EEVEE", 25),
      },
      SILPH_CO = {
        slot("SANDSHREW_LINE", "SANDSLASH", 38),
        slot("MAGNEMITE_LINE", "MAGNETON", 35),
        slot("VULPIX_LINE", "NINETALES", 37),
        slot("ABRA_LINE", "KADABRA", 35),
        slot("EEVEE_LINE", "VAPOREON", 40),
      },
      ROUTE_22_LATE = {
        slot("SANDSHREW_LINE", "SANDSLASH", 47),
        slot("EXEGGCUTE_LINE", "EXEGGCUTE", 45),
        slot("MAGNEMITE_LINE", "MAGNETON", 45),
        slot("VULPIX_LINE", "NINETALES", 47),
        slot("ABRA_LINE", "KADABRA", 50),
        slot("EEVEE_LINE", "VAPOREON", 53),
      },
      CHAMPION = {
        slot("SANDSHREW_LINE", "SANDSLASH", 61),
        slot("ABRA_LINE", "ALAKAZAM", 59),
        slot("EXEGGCUTE_LINE", "EXEGGUTOR", 61),
        slot("VULPIX_LINE", "NINETALES", 61),
        slot("MAGNEMITE_LINE", "MAGNETON", 63),
        slot("EEVEE_LINE", "VAPOREON", 65),
      },
    },
  }
  return assert(path[outcome] and path[outcome][encounter_id],
    "missing Yellow Rival anchor " .. tostring(encounter_id))
end

local function copy_rows(rows)
  local out = {}
  for index, row in ipairs(rows) do
    out[index] = {}
    for key, value in pairs(row) do out[index][key] = value end
  end
  return out
end

function M.index(encounter_id)
  for index, id in ipairs(M.encounterOrder) do
    if id == encounter_id then return index end
  end
  return nil
end

function M.for_encounter(encounter_id)
  return assert(WINDOWS[encounter_id],
    "unknown Rival journey window " .. tostring(encounter_id))
end

function M.traits(line_id)
  return LINE_TRAITS[line_id] or { role = "balanced", type = "NORMAL" }
end

function M.for_battle(version, map_id, class_id, party_index)
  party_index = tonumber(party_index) or 1
  for _, row in ipairs(BATTLE_PATHS[version] or {}) do
    if row[2] == map_id and row[3] == class_id
        and party_index >= row[4] and party_index <= row[5] then
      return row[1]
    end
  end
  return nil
end

function M.anchor(version, encounter_id, starter_line, yellow_outcome)
  assert(M.index(encounter_id), "unknown Rival encounter " .. tostring(encounter_id))
  local rows
  if version == "yellow" then
    assert(starter_line == "EEVEE_LINE",
      "Yellow Rival starter must remain the Eevee line")
    rows = yellow_anchor(encounter_id, yellow_outcome)
  elseif version == "red" or version == "blue" then
    rows = rb_anchor(encounter_id, starter_line)
  else
    error("unsupported Rival game version " .. tostring(version), 2)
  end
  local slots = copy_rows(rows)
  local top = 0
  for _, row in ipairs(slots) do top = math.max(top, row.floor) end
  return { encounterId = encounter_id, slots = slots,
    activeCount = #slots, canonFloor = top }
end

local function lines_from_slots(slots, excluded)
  local out, seen = {}, {}
  for _, row in ipairs(slots) do
    if not excluded[row.lineId] and not seen[row.lineId] then
      out[#out + 1] = { lineId = row.lineId, species = row.species,
        canonicalAffinity = 1, role = row.role, type = row.type }
      seen[row.lineId] = true
    end
  end
  return out
end

function M.candidates(version, encounter_id, starter_line, yellow_outcome)
  local excluded = { [starter_line] = true }
  if encounter_id == "ROUTE_22_EARLY" then
    return version == "yellow"
      and { { lineId = "SPEAROW_LINE", species = "SPEAROW",
        canonicalAffinity = 1 } }
      or { { lineId = "PIDGEY_LINE", species = "PIDGEY",
        canonicalAffinity = 1 } }
  end
  if encounter_id == "CERULEAN" then
    excluded.PIDGEY_LINE = true
    excluded.SPEAROW_LINE = true
    if version == "yellow" then
      return {
        { lineId = "SANDSHREW_LINE", species = "SANDSHREW",
          canonicalAffinity = 1 },
        { lineId = "RATTATA_LINE", species = "RATTATA",
          canonicalAffinity = 1 },
      }
    end
    return {
      { lineId = "ABRA_LINE", species = "ABRA", canonicalAffinity = 1 },
      { lineId = "RATTATA_LINE", species = "RATTATA",
        canonicalAffinity = 1 },
    }
  end
  if encounter_id == "SS_ANNE" then
    return { { lineId = "DIGLETT_LINE", species = "DIGLETT",
      canonicalAffinity = 0.25 } }
  end
  local anchor = M.anchor(version, encounter_id, starter_line, yellow_outcome)
  excluded.PIDGEY_LINE = true
  excluded.SPEAROW_LINE = true
  excluded.RATTATA_LINE = true
  excluded.SANDSHREW_LINE = encounter_id ~= "ROUTE_22_LATE"
  if encounter_id == "SILPH_CO" then
    excluded.SANDSHREW_LINE = true
    excluded.SHELLDER_LINE = true
    excluded.VULPIX_LINE = true
    excluded.MAGNEMITE_LINE = true
    excluded.ABRA_LINE = false
  elseif encounter_id == "ROUTE_22_LATE" then
    if version == "yellow" then
      excluded.EXEGGCUTE_LINE = false
    else
      excluded.RHYHORN_LINE = false
    end
  end
  local out = lines_from_slots(anchor.slots, excluded)
  if encounter_id == "CHAMPION" then
    out[#out + 1] = { lineId = "MACHOP_LINE", species = "MACHOP",
      canonicalAffinity = 0.1 }
    out[#out + 1] = { lineId = "GEODUDE_LINE", species = "GEODUDE",
      canonicalAffinity = 0.1 }
  end
  return out
end

return M
