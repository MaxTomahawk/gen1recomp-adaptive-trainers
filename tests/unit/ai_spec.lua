local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local ai = assert(loadfile(ROOT .. "/src/core/ai.lua"))()

local checks, failures = 0, 0
local function check(condition, message)
  checks = checks + 1
  if not condition then failures = failures + 1; io.stderr:write("FAIL ", message, "\n") end
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (expected " .. tostring(expected)
    .. ", got " .. tostring(actual) .. ")")
end

local registered, patched = {}, {}
local function registry(target, verb)
  return { [verb] = function(_, id, row) target[id] = row end }
end
local mod = { content = {
  ai_classes = registry(registered, "register"),
  trainers = registry(patched, "patch"),
} }
local profiles = { byClass = {
  OPP_NOVICE = { aiTier = 0 },
  OPP_REGULAR = { aiTier = 1 },
  OPP_TRAINED = { aiTier = 2 },
  OPP_EXPERT = { aiTier = 3 },
} }

ai.register(mod, profiles)

eq(table.concat(patched.OPP_NOVICE.aiMods, ","), "LAYER_1",
  "T0 uses random legal choice with the failed-status guard")
eq(table.concat(patched.OPP_REGULAR.aiMods, ","), "LAYER_1,LAYER_3",
  "T1 adds light effectiveness scoring")
eq(table.concat(patched.OPP_TRAINED.aiMods, ","),
  "LAYER_1,LAYER_2,LAYER_3",
  "T2 uses all three public vanilla scoring layers")
check(patched.OPP_EXPERT.aiMods[4] == "ADAPTIVE_T3_ROLE",
  "T3 adds the mod's stronger role-aware scoring layer")
eq(patched.OPP_EXPERT.aiClass, "ADAPTIVE_T3_CLASS",
  "T3 opts into bounded expert switching/items through a public AI class")

local expertClass = registered.ADAPTIVE_T3_CLASS
eq(expertClass.kind, "class", "expert tactical behavior is a public class record")
eq(expertClass.uses, 1, "expert tactical actions are limited per active mon")
check(expertClass.switchChance > 0 and expertClass.switchChance < 64,
  "expert switching is possible but not omniscient or constant")
eq(expertClass.chance, 0,
  "the expert class cannot invent an unconfigured item action")

local layer = registered.ADAPTIVE_T3_ROLE
eq(layer.kind, "layer", "expert role scoring is a public layer record")
local forbiddenSave = setmetatable({}, {
  __index = function() error("AI layer read the full player save roster") end,
})
local view = {
  user = { curTypes = { "FIRE" } },
  target = { mon = { status = nil }, curTypes = { "GRASS" } },
  battle = { game = { save = forbiddenSave } },
}
local stabScore = layer.score(view, {
  id = "FLAMETHROWER", type = "FIRE", power = 95, accuracy = 100,
  effect = "BURN_SIDE_EFFECT1",
}, 10)
local utilityScore = layer.score(view, {
  id = "SMOKESCREEN", type = "NORMAL", power = 0, accuracy = 100,
  effect = "ACCURACY_DOWN1_EFFECT",
}, 10)
check(stabScore < utilityScore,
  "expert layer prefers reliable active-mon STAB without roster scouting")

if failures > 0 then
  io.stderr:write(string.format("%d/%d AI checks failed\n", failures, checks))
  os.exit(1)
end
print(string.format("%d/%d AI checks passed", checks, checks))
