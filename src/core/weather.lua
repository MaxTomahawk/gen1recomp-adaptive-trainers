local M = {}

local OWNER = "adaptive_trainers"
local DURATION = 5
local VALID = { RAIN = true, SUN = true, SAND = true }
local SAND_IMMUNE = { ROCK = true, GROUND = true, STEEL = true }

local DAMAGE_SCALE = {
  RAIN = { WATER = 1.5, FIRE = 0.5 },
  SUN = { FIRE = 1.5, WATER = 0.5 },
}
local INSTALLED = setmetatable({}, { __mode = "k" })

local function state(field)
  local value = type(field) == "table" and field.weather or nil
  if type(value) == "table" and value.source == OWNER
      and VALID[value.id] then
    return value
  end
end

function M.current(field)
  local value = state(field)
  return value and value.id or nil
end

function M.turns_left(field)
  local value = state(field)
  return value and math.max(0, tonumber(value.turns) or 0) or 0
end

function M.start(field, weatherId)
  assert(type(field) == "table", "weather requires a battle field")
  assert(VALID[weatherId], "unknown weather " .. tostring(weatherId))
  field.weather = { id = weatherId, turns = DURATION, source = OWNER }
end

function M.clear(field)
  if state(field) then field.weather = nil end
end

function M.damage_multiplier(field, moveType)
  local byType = DAMAGE_SCALE[M.current(field)]
  return byType and byType[moveType] or 1
end

function M.scale_damage(field, moveType, damage)
  if type(damage) ~= "number" or damage <= 0 then return damage end
  local multiplier = M.damage_multiplier(field, moveType)
  if multiplier == 1 then return damage end
  return math.max(1, math.floor(damage * multiplier))
end

function M.solarbeam_requires_charge(field)
  return M.current(field) ~= "SUN"
end

local function battler_types(battler)
  if type(battler) ~= "table" then return {} end
  if type(battler.curTypes) == "table" then return battler.curTypes end
  if type(battler.types) == "table" then return battler.types end
  if type(battler.def) == "table" and type(battler.def.types) == "table" then
    return battler.def.types
  end
  return {}
end

function M.sand_residual_amount(battler)
  local mon = type(battler) == "table" and battler.mon or nil
  local hp = type(mon) == "table" and tonumber(mon.hp)
    or tonumber(type(battler) == "table" and battler.hp) or 0
  if hp <= 0 or (type(battler) == "table"
      and battler.vanished == true) then return 0 end
  for _, typeId in ipairs(battler_types(battler)) do
    if SAND_IMMUNE[typeId] then return 0 end
  end
  local maxHp = type(mon) == "table" and type(mon.stats) == "table" and tonumber(mon.stats.hp) or nil
  maxHp = maxHp or tonumber(battler.maxHp)
  maxHp = maxHp or (type(battler.stats) == "table"
    and tonumber(battler.stats.hp)) or hp
  return math.max(1, math.floor(maxHp / 8))
end

function M.apply_sand(field, battlers, damage)
  local residuals = {}
  if M.current(field) ~= "SAND" or type(damage) ~= "function" then
    return residuals
  end
  for _, battler in ipairs(battlers or {}) do
    local amount = M.sand_residual_amount(battler)
    if amount > 0 then
      damage(battler, amount)
      residuals[#residuals + 1] = { battler = battler, amount = amount }
    end
  end
  return residuals
end

function M.advance_turn(field, battlers, damage)
  local report = { residuals = M.apply_sand(field, battlers, damage) }
  local value = state(field)
  if not value then return report end
  value.turns = math.max(0, (tonumber(value.turns) or 0) - 1)
  if value.turns == 0 then field.weather = nil end
  return report
end

local function put(registry, id, record)
  if type(registry) ~= "table" then return end
  local existing = type(registry.get) == "function" and registry:get(id)
    or registry[id]
  if existing == nil then
    registry:register(id, record)
  elseif type(registry.patch) == "function" then
    registry:patch(id, record)
  end
end

local function weather_effect(weatherId, enabled)
  return {
    kind = "primary",
    run = function(ctx)
      if enabled == false then return { failed = true } end
      M.start(assert(ctx.field, "weather effect requires field context"),
        weatherId)
      return {}
    end,
  }
end

function M.install(mod, options)
  assert(type(mod) == "table", "weather.install requires a mod API")
  if INSTALLED[mod] then return nil end
  options = options or {}
  put(mod.content and mod.content.move_effects,
    "ADAPTIVE_RAIN_EFFECT", weather_effect("RAIN", true))
  put(mod.content and mod.content.move_effects,
    "ADAPTIVE_SUN_EFFECT", weather_effect("SUN", true))
  put(mod.content and mod.content.move_effects,
    "ADAPTIVE_SAND_EFFECT", weather_effect("SAND",
      options.sandResidual == true))

  mod.hooks:wrap("battle.damage", function(next, ctx)
    local damage, info = next(ctx)
    local field = ctx and ctx.battle and ctx.battle.field
    local moveType = ctx and ctx.move and ctx.move.type
    return M.scale_damage(field, moveType, damage), info
  end)

  if options.solarBeam == true then
    mod.hooks:wrap("battle.charge_required", function(next, ctx)
      local required = next(ctx)
      local field = ctx and ctx.battle and ctx.battle.field
      if required == true and ctx and ctx.charge == true
          and ctx.move and ctx.move.id == "SOLARBEAM"
          and M.current(field) == "SUN" then
        return false
      end
      return required
    end)
  end

  if options.sandResidual == true then
    mod.hooks:wrap("battle.field_residual", function(next, ctx)
      local rows = next(ctx)
      if type(rows) ~= "table" or M.current(ctx and ctx.field) ~= "SAND" then
        return rows
      end
      local views = ctx and ctx.battlers or {}
      for _, side in ipairs({ "player", "enemy" }) do
        local battler = views[side]
        local amount = M.sand_residual_amount(battler)
        if amount > 0 then
          rows[#rows + 1] = {
            side = side, amount = amount,
            message = tostring(battler.name or side)
              .. " is buffeted by the sandstorm!",
          }
        end
      end
      return rows
    end)
  end

  mod.events:on("battle.turn_ended", function(ev)
    local battle = ev and ev.battle
    if battle and battle.field then M.advance_turn(battle.field) end
  end)
  mod.events:on("battle.ended", function(ev)
    local battle = ev and ev.battle
    if battle and battle.field then M.clear(battle.field) end
  end)
  INSTALLED[mod] = true
  return nil
end

M.DURATION = DURATION
M.SAND_IMMUNE = SAND_IMMUNE

return M
