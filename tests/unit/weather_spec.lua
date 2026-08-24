local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local weather = assert(loadfile(ROOT .. "/src/core/weather.lua"))()

local checks, failures = 0, 0
local function check(condition, message)
  checks = checks + 1
  if not condition then failures = failures + 1; io.stderr:write("FAIL ", message, "\n") end
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (expected " .. tostring(expected)
    .. ", got " .. tostring(actual) .. ")")
end

local rain = { tokens = {} }
weather.start(rain, "RAIN")
eq(weather.current(rain), "RAIN", "Rain Dance starts rain on the battle field")
eq(weather.turns_left(rain), 5, "rain starts with five complete turns")
eq(weather.scale_damage(rain, "WATER", 101), 151,
  "rain boosts Water damage by 1.5 with deterministic flooring")
eq(weather.scale_damage(rain, "FIRE", 101), 50,
  "rain halves Fire damage")
eq(weather.scale_damage(rain, "ELECTRIC", 101), 101,
  "rain leaves unrelated damage unchanged")

for turn = 1, 4 do
  weather.advance_turn(rain)
  eq(weather.current(rain), "RAIN",
    "rain remains active through completed turn " .. turn)
end
eq(weather.turns_left(rain), 1, "one rain turn remains after four ticks")
weather.advance_turn(rain)
eq(weather.current(rain), nil, "rain expires after exactly five turns")
eq(weather.turns_left(rain), 0, "expired weather reports zero turns")

local sun = { tokens = {} }
weather.start(sun, "SUN")
eq(weather.scale_damage(sun, "FIRE", 99), 148,
  "sun boosts Fire damage by 1.5")
eq(weather.scale_damage(sun, "WATER", 99), 49,
  "sun halves Water damage")
eq(weather.solarbeam_requires_charge(sun), false,
  "SolarBeam skips its charge turn in sun")
eq(weather.solarbeam_requires_charge({ weather = nil }), true,
  "SolarBeam keeps vanilla charging without weather")
eq(weather.solarbeam_requires_charge(rain), true,
  "rain does not remove SolarBeam's charge turn")

local sand = { tokens = {} }
weather.start(sand, "SAND")
local battlers = {
  { id = "plain", curTypes = { "NORMAL" }, mon = { hp = 80,
    stats = { hp = 81 } } },
  { id = "rock", curTypes = { "ROCK" }, mon = { hp = 80,
    stats = { hp = 80 } } },
  { id = "ground", curTypes = { "WATER", "GROUND" }, mon = { hp = 80,
    stats = { hp = 80 } } },
  { id = "steel", curTypes = { "ELECTRIC", "STEEL" }, mon = { hp = 80,
    stats = { hp = 80 } } },
  { id = "fainted", curTypes = { "NORMAL" }, mon = { hp = 0,
    stats = { hp = 80 } } },
}
local hits = {}
local report = weather.advance_turn(sand, battlers, function(battler, amount)
  hits[#hits + 1] = { id = battler.id, amount = amount }
  battler.mon.hp = math.max(0, battler.mon.hp - amount)
end)
eq(#hits, 1, "sand excludes Rock, Ground, Steel, and fainted battlers")
eq(hits[1].id, "plain", "sand damages the only non-excluded battler")
eq(hits[1].amount, 10, "sand deals floor(1/8 max HP) residual damage")
eq(report.residuals[1].amount, 10,
  "sand reports deterministic residual evidence")
eq(weather.turns_left(sand), 4, "sand decrements once after residual damage")

local tiny = { curTypes = { "NORMAL" }, mon = { hp = 1,
  stats = { hp = 1 } } }
eq(weather.sand_residual_amount(tiny), 1,
  "sand residual has a one-HP minimum for a living battler")
eq(weather.sand_residual_amount(battlers[2]), 0,
  "Rock types are excluded from sand residual")
eq(weather.sand_residual_amount(battlers[3]), 0,
  "Ground types are excluded from sand residual")
eq(weather.sand_residual_amount(battlers[4]), 0,
  "Steel types are excluded from sand residual")

local none = { tokens = { "preserve" } }
local beforeWeather = none.weather
local noWeatherReport = weather.advance_turn(none, battlers,
  function() error("no-weather residual callback must not run") end)
eq(none.weather, beforeWeather, "no-weather turn advancement is byte-stable")
eq(none.tokens[1], "preserve", "no-weather parity preserves field tokens")
eq(#noWeatherReport.residuals, 0, "no-weather reports no residual damage")
eq(weather.scale_damage(none, "WATER", 73), 73,
  "no-weather damage is exactly vanilla")

local function registry()
  local records = {}
  return {
    get = function(_, id) return records[id] end,
    register = function(_, id, value) records[id] = value end,
    records = records,
  }
end
local hooks, events = {}, {}
local mod = {
  content = { move_effects = registry() },
  hooks = { wrap = function(_, id, callback) hooks[id] = callback end },
  events = { on = function(_, id, callback) events[id] = callback end },
}
eq(weather.install(mod, { sandResidual = false, solarBeam = false }), nil,
  "weather installation keeps the planned nil API")
check(mod.content.move_effects:get("ADAPTIVE_RAIN_EFFECT") ~= nil,
  "install registers Rain Dance through the public effect registry")
check(mod.content.move_effects:get("ADAPTIVE_SUN_EFFECT") ~= nil,
  "install registers Sunny Day through the public effect registry")
check(mod.content.move_effects:get("ADAPTIVE_SAND_EFFECT") ~= nil,
  "install registers Sandstorm through the public effect registry")
check(type(hooks["battle.damage"]) == "function",
  "install uses the public battle.damage hook")
check(type(events["battle.turn_ended"]) == "function"
    and type(events["battle.ended"]) == "function",
  "install uses public lifecycle events for duration cleanup")

local installedField = { tokens = {} }
local messages = mod.content.move_effects:get("ADAPTIVE_SUN_EFFECT").run({
  field = installedField,
})
eq(#messages, 0, "weather setup needs no engine-private message helper")
eq(weather.current(installedField), "SUN",
  "the registered Sunny Day effect activates sun")

local sandMessages = mod.content.move_effects
  :get("ADAPTIVE_SAND_EFFECT").run({ field = installedField })
eq(sandMessages.failed, true,
  "Sandstorm fails closed when lifecycle-safe residual damage is unavailable")
eq(weather.current(installedField), "SUN",
  "disabled Sandstorm cannot replace an active supported weather state")

local vanillaCalls = 0
local info = { crit = false, typeMult = 10 }
local scaled, returnedInfo = hooks["battle.damage"](function()
  vanillaCalls = vanillaCalls + 1
  return 100, info
end, { battle = { field = installedField }, move = { type = "FIRE" } })
eq(scaled, 150, "installed damage hook applies active weather")
eq(returnedInfo, info, "installed damage hook preserves secondary returns")
eq(vanillaCalls, 1, "installed damage hook calls vanilla exactly once")

local parityInfo = { crit = true, typeMult = 20 }
local parityDamage, parityReturned = hooks["battle.damage"](function()
  return 87, parityInfo
end, { battle = { field = { tokens = {} } }, move = { type = "WATER" } })
eq(parityDamage, 87, "installed hook preserves no-weather damage exactly")
eq(parityReturned, parityInfo,
  "installed hook preserves no-weather metadata by identity")

for _ = 1, 5 do
  events["battle.turn_ended"]({ battle = { field = installedField } })
end
eq(weather.current(installedField), nil,
  "public turn events expire installed weather after five turns")
weather.start(installedField, "RAIN")
events["battle.ended"]({ battle = { field = installedField } })
eq(weather.current(installedField), nil,
  "battle end clears installed weather state")

local hookCount, eventCount, effectCount = 0, 0, 0
for _ in pairs(hooks) do hookCount = hookCount + 1 end
for _ in pairs(events) do eventCount = eventCount + 1 end
for _ in pairs(mod.content.move_effects.records) do effectCount = effectCount + 1 end
weather.install(mod, { sandResidual = false, solarBeam = false })
local repeatedHooks, repeatedEvents, repeatedEffects = 0, 0, 0
for _ in pairs(hooks) do repeatedHooks = repeatedHooks + 1 end
for _ in pairs(events) do repeatedEvents = repeatedEvents + 1 end
for _ in pairs(mod.content.move_effects.records) do
  repeatedEffects = repeatedEffects + 1
end
eq(repeatedHooks, hookCount, "repeated install does not duplicate hooks")
eq(repeatedEvents, eventCount, "repeated install does not duplicate events")
eq(repeatedEffects, effectCount,
  "repeated install does not duplicate effect registrations")

local supportedHooks, supportedEvents = {}, {}
local supported = {
  content = { move_effects = registry() },
  hooks = { wrap = function(_, id, callback) supportedHooks[id] = callback end },
  events = { on = function(_, id, callback) supportedEvents[id] = callback end },
}
weather.install(supported, { sandResidual = true, solarBeam = true })
check(type(supportedHooks["battle.charge_required"]) == "function",
  "supported install wraps the public charge decision seam")
check(type(supportedHooks["battle.field_residual"]) == "function",
  "supported install wraps the public field residual seam")

local supportedSun = { tokens = {} }
weather.start(supportedSun, "SUN")
local vanillaChargeCalls = 0
local skip = supportedHooks["battle.charge_required"](function()
  vanillaChargeCalls = vanillaChargeCalls + 1
  return true
end, { battle = { field = supportedSun }, move = { id = "SOLARBEAM" }, charge = true })
eq(skip, false, "sun skips SolarBeam charge through the public seam")
eq(vanillaChargeCalls, 1, "SolarBeam wrapper composes with vanilla once")
local keepDig = supportedHooks["battle.charge_required"](function() return true end,
  { battle = { field = supportedSun }, move = { id = "DIG" }, charge = true })
eq(keepDig, true, "sun never removes another move charge turn")

local supportedSand = { tokens = {} }
local sandStart = supported.content.move_effects
  :get("ADAPTIVE_SAND_EFFECT").run({ field = supportedSand })
eq(#sandStart, 0, "supported Sandstorm activates successfully")
local baseRows = { { side = "player", amount = 1, message = "prior mod" } }
local rows = supportedHooks["battle.field_residual"](function(context)
  eq(context.field, supportedSand,
    "field residual wrapper passes the public field through next")
  return baseRows
end, {
  field = supportedSand,
  battlers = {
    player = { side = "player", name = "REDMON", hp = 80, maxHp = 81,
      types = { "NORMAL" } },
    enemy = { side = "enemy", name = "FLYMON", hp = 80, maxHp = 80,
      types = { "NORMAL" }, vanished = true },
  },
})
eq(rows, baseRows, "field residual wrapper preserves the composed list")
eq(#rows, 2, "sand excludes a semi-invulnerable detached battler")
eq(rows[2].side, "player", "sand descriptor targets the eligible side")
eq(rows[2].amount, 10, "sand requests floor one-eighth max HP")
check(rows[2].message:find("REDMON", 1, true) ~= nil,
  "sand descriptor names the affected detached battler")

local noFieldRows = { { side = "enemy", amount = 2 } }
local noField = supportedHooks["battle.field_residual"](
  function() return noFieldRows end, {
    field = { tokens = {} }, battlers = {},
  })
eq(noField, noFieldRows,
  "no-weather field residual path is byte-identical by table identity")

if failures > 0 then
  io.stderr:write(string.format("%d/%d weather checks failed\n", failures, checks))
  os.exit(1)
end
print(string.format("%d/%d weather checks passed", checks, checks))
