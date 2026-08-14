local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")
local identity = assert(loadfile(ROOT .. "/src/core/identity.lua"))()

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

eq(identity.standard("red", "ROUTE_3", "OPP_YOUNGSTER", 2),
  "red|ROUTE_3|OPP_YOUNGSTER|2",
  "the baseline identity is version, map, class, and party index")
eq(identity.standard("blue", "ROUTE_3", "OPP_YOUNGSTER", 2),
  "blue|ROUTE_3|OPP_YOUNGSTER|2",
  "different game versions never share a trainer identity")
eq(identity.standard("red", "ROUTE_3", "OPP_YOUNGSTER", 2,
  "ROUTE3_TRAINER_4"),
  "red|ROUTE_3|OPP_YOUNGSTER|2|npc:ROUTE3_TRAINER_4",
  "a concrete NPC suffix disambiguates tuple collisions")

local pending = {
  mapId = "ROUTE_3",
  npcId = "ROUTE3_TRAINER_4",
  oppClass = "OPP_YOUNGSTER",
  partyIndex = 2,
}
eq(identity.from_context("red", { mapId = "ROUTE_3" },
  "OPP_YOUNGSTER", 2, pending),
  "red|ROUTE_3|OPP_YOUNGSTER|2|npc:ROUTE3_TRAINER_4",
  "a matching engagement contributes its concrete NPC id")
eq(identity.from_context("red", { mapId = "ROUTE_3" },
  "OPP_LASS", 2, pending),
  "red|ROUTE_3|OPP_LASS|2",
  "a stale engagement for another class is ignored")
eq(identity.from_context("red", { mapId = "MT_MOON_1F" },
  "OPP_YOUNGSTER", 2, pending),
  "red|MT_MOON_1F|OPP_YOUNGSTER|2",
  "a stale engagement from another map is ignored")

local collisions = identity.audit({
  { version = "red", mapId = "ROUTE_3", oppClass = "OPP_YOUNGSTER",
    partyIndex = 2, npcId = "A" },
  { version = "red", mapId = "ROUTE_3", oppClass = "OPP_YOUNGSTER",
    partyIndex = 2, npcId = "B" },
  { version = "red", mapId = "ROUTE_3", oppClass = "OPP_LASS",
    partyIndex = 1, npcId = "C" },
})
eq(#collisions, 1, "the audit reports one colliding baseline tuple")
eq(collisions[1].key, "red|ROUTE_3|OPP_YOUNGSTER|2",
  "the audit names the colliding baseline identity")
eq(#collisions[1].npcIds, 2,
  "the collision evidence lists both concrete NPC ids")

if failures > 0 then
  io.stderr:write(string.format("%d/%d identity checks failed\n",
    failures, checks))
  os.exit(1)
end
print(string.format("%d/%d identity checks passed", checks, checks))
