local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local factory = assert(loadfile(ROOT .. "/src/ui/gym_registration.lua"))()

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

local drawnIcons = {}
local registration = factory({
  ui = {
    Font = {
      draw = function() end,
      drawCode = function() end,
      drawBox = function() end,
    },
    PokemonIcon = {
      draw = function(_, summary, _, _, opts)
        drawnIcons[#drawnIcons + 1] = {
          summary = summary, selected = opts and opts.selected,
        }
      end,
    },
    Theme = { cursor = 1 },
  },
})

local party = {
  { species = "A", level = 31, hp = 0, maxHp = 90 },
  { species = "B", level = 40, hp = 12, maxHp = 100 },
  { species = "C", level = 22, hp = 22, maxHp = 60 },
  { species = "D", level = 40, hp = 80, maxHp = 100 },
}
check(same(registration.default_selection(party, 2), { 2, 4 }),
  "default registration chooses the top N healthy party members stably")
check(same(registration.default_selection(party, 3), { 2, 3, 4 }),
  "default registration uses every healthy member when fewer than N exist")
check(same(registration.default_selection({
  { species = "A", level = 10, hp = 0 },
}, 3), {}), "a fully fainted party has no invalid default selection")

check(registration.validate(party, 2, { 3 }),
  "one healthy registered party member is valid")
check(registration.validate(party, 2, { 1, 4 }),
  "a registration may contain up to the leader maximum")
local ok, code = registration.validate(party, 2, {})
eq(ok, false, "an empty registration cannot be confirmed")
eq(code, "empty", "empty registration returns a stable diagnostic")
ok, code = registration.validate(party, 2, { 1, 2, 3 })
eq(ok, false, "a registration cannot exceed the leader maximum")
eq(code, "too_many", "overfilled registration returns a stable diagnostic")
ok, code = registration.validate(party, 2, { 2, 2 })
eq(ok, false, "duplicate party indices are rejected")
eq(code, "duplicate", "duplicate registration returns a stable diagnostic")
ok, code = registration.validate(party, 2, { 5 })
eq(ok, false, "out-of-range party indices are rejected")
eq(code, "invalid_index", "invalid indices return a stable diagnostic")
ok, code = registration.validate(party, 2, { 1 })
eq(ok, false, "an all-fainted registration cannot start a battle")
eq(code, "no_healthy", "all-fainted registration has a stable diagnostic")

local pressed = {}
local input = {
  wasPressed = function(_, key) return pressed[key] == true end,
}
local stack = { items = {}, pops = 0 }
function stack:top() return self.items[#self.items] end
function stack:push(item) self.items[#self.items + 1] = item end
function stack:pop()
  self.pops = self.pops + 1
  return table.remove(self.items)
end
local game = {
  input = input,
  stack = stack,
  save = { party = party },
  data = { pokemon = {
    A = { name = "ALPHA" }, B = { name = "BETA" },
    C = { name = "GAMMA" }, D = { name = "DELTA" },
  } },
}
local confirms, cancels = {}, 0
local screen = registration.choose(game, "BROCK", 2,
  function(indices) confirms[#confirms + 1] = indices end,
  function() cancels = cancels + 1 end)
stack:push(screen)
check(same(screen:selected_indices(), { 2, 4 }),
  "the interactive screen starts with the deterministic healthy defaults")

screen.index = 3
local toggled, toggleCode = screen:toggle(3)
eq(toggled, false, "A cannot overfill the leader's registration limit")
eq(toggleCode, "full", "an overfill attempt has a stable diagnostic")
check(same(screen:selected_indices(), { 2, 4 }),
  "an overfill attempt leaves the selected party unchanged")

screen:toggle(2)
screen:toggle(4)
check(same(screen:selected_indices(), {}),
  "selected entries can be removed before confirmation")
pressed = { start = true }
screen:update()
eq(#confirms, 0, "START cannot confirm an empty registration")
eq(stack.pops, 0, "invalid confirmation keeps the registration screen open")

pressed = {}
screen:toggle(3)
pressed = { start = true }
screen:update()
eq(#confirms, 1, "a valid registration confirms exactly once")
check(same(confirms[1], { 3 }),
  "confirmation returns detached ordered save-party indices")
eq(stack.pops, 1, "confirmation closes the registration screen")
confirms[1][1] = 4
check(same(screen:selected_indices(), { 3 }),
  "callback mutation cannot alter the locked screen selection")
screen:update()
eq(#confirms, 1, "a completed screen cannot invoke confirmation twice")

local cancelScreen = registration.choose(game, "MISTY", 2,
  function(indices) confirms[#confirms + 1] = indices end,
  function() cancels = cancels + 1 end)
stack:push(cancelScreen)
pressed = { b = true }
cancelScreen:update()
eq(cancels, 1, "B cancels exactly once")
eq(#confirms, 1, "cancellation never confirms a battle party")
eq(stack.pops, 2, "cancellation closes the registration screen")
cancelScreen:update()
eq(cancels, 1, "a completed cancellation is one-shot")

drawnIcons = {}
cancelScreen:draw()
eq(#drawnIcons, #party,
  "the screen presents each party member through the public icon helper")
eq(drawnIcons[1].summary.species, "A",
  "icon presentation receives only a detached party summary")

if failures > 0 then
  error(failures .. " Gym registration assertion(s) failed", 0)
end
print(("gym registration: %d/%d checks passed"):format(checks, checks))
