local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT is required")

local diagnostics = assert(loadfile(
  ROOT .. "/src/core/diagnostics.lua"))()
local debug_factory = assert(loadfile(ROOT .. "/src/ui/debug.lua"))()

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

local root = {
  seedHi = 101,
  seedLo = 202,
  trainers = {
    trainer = {
      identityKey = "trainer",
      classId = "OPP_BUG_CATCHER",
      mapId = "ROUTE_3",
      lastBattleAt = 900,
      battleCount = 2,
      activeIds = { "trainer:1" },
      owned = { {
        id = "trainer:1",
        lineId = "CATERPIE_LINE",
        species = "BUTTERFREE",
        level = 12,
        moves = { "TACKLE", "CONFUSION" },
      } },
    },
  },
}

local fontCalls = {}
local ui = { Font = {
  drawBox = function(...) fontCalls[#fontCalls + 1] = { "box", ... } end,
  draw = function(...) fontCalls[#fontCalls + 1] = { "draw", ... } end,
} }
local debug = debug_factory({ diagnostics = diagnostics, ui = ui })
local projection = debug.project("standard", root, "trainer", {
  ceiling = 18,
  catchProbability = 0.25,
  ecologyCandidates = { "CATERPIE_LINE", "WEEDLE_LINE" },
  moveScores = { TACKLE = 2, CONFUSION = 4 },
})
eq(projection.kind, "standard",
  "the adapter builds the requested detached projection without a second gate")
eq(debug.project("unknown", root), nil,
  "unknown projection scopes remain fail-silent")

check(type(debug.rows) == "function" and type(debug.new) == "function",
  "the debug adapter exposes stable rows and a screen constructor")
if type(debug.rows) ~= "function" or type(debug.new) ~= "function" then
  io.stderr:write(string.format("%d/%d debug checks failed\n",
    failures, checks))
  os.exit(1)
end

local rows = debug.rows(projection)
eq(rows[1], "STANDARD", "the first row names the diagnostic scope")
eq(rows[2], "identity: trainer", "identity is the first standard detail")
eq(rows[3], "class: OPP_BUG_CATCHER", "class ordering is stable")
eq(rows[4], "map: ROUTE_3", "map ordering is stable")
eq(rows[5], "lastBattleAt: 900", "last battle time is visible")
eq(rows[6], "ceiling: 18", "ceiling is visible")
eq(rows[7], "catch p: 0.25", "catch probability is visible")
eq(rows[8], "ecology: CATERPIE_LINE,WEEDLE_LINE",
  "ecology candidates retain deterministic source order")
eq(rows[9], "roster: BUTTERFREE L12 [TACKLE,CONFUSION]",
  "the saved roster is rendered as a stable data-only row")
eq(rows[10], "move CONFUSION: 4",
  "move scores sort lexically instead of using table iteration order")
eq(rows[11], "move TACKLE: 2",
  "all selected move scores remain visible")

for index = 2, 20 do
  projection.roster[index] = {
    id = "trainer:" .. index,
    species = "CATERPIE",
    level = 5 + index,
    moves = { "TACKLE" },
  }
end

local pressed = {}
local input = { wasPressed = function(_, key) return pressed[key] == true end }
local popped = 0
local game = {
  input = input,
  stack = { pop = function() popped = popped + 1 end },
}
local screen = debug.new(game, projection)
check(screen.projection == nil and screen.save == nil and screen.registry == nil
    and screen.generator == nil and screen.callback == nil,
  "the screen retains rows, not projections or gameplay authority")
check(screen.rows ~= rows and screen.rows[9] == rows[9],
  "the screen owns its own detached row list")
eq(screen.offset, 0, "the screen starts at the first row")
pressed.down = true
screen:update()
eq(screen.offset, 1, "down scrolls one stable row")
pressed.down = nil
pressed.up = true
screen:update()
eq(screen.offset, 0, "up scrolls toward the first row")
pressed.up = nil
pressed.b = true
screen:update()
eq(popped, 1, "B closes the diagnostics screen")
pressed.b = nil
pressed.start = true
screen:update()
eq(popped, 2, "START also closes the diagnostics screen")

local first = table.concat(screen.rows, "\n")
local second = table.concat(debug.new(game, projection).rows, "\n")
eq(second, first, "row order is repeatable across screen reconstruction")

if failures > 0 then
  io.stderr:write(string.format("%d/%d debug checks failed\n",
    failures, checks))
  os.exit(1)
end
print(string.format("%d/%d debug checks passed", checks, checks))
