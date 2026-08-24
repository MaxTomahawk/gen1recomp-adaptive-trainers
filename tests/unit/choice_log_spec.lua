local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT is required")

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

local chunk = loadfile(ROOT .. "/src/core/choice_log.lua")
check(type(chunk) == "function",
  "the deterministic developer choice logger exists")
if type(chunk) ~= "function" then
  io.stderr:write(string.format("%d/%d choice-log checks failed\n",
    failures, checks))
  os.exit(1)
end

local calls = {}
local logger = { info = function(_, format, value)
  calls[#calls + 1] = { format = format, value = value }
end }
local emit = chunk()({ log = logger })
emit("trainer-roster", "trainer-init",
  { "red|ROUTE_3|OPP_BUG_CATCHER|1", 2, true })
eq(#calls, 1, "one materialized choice emits one info line")
eq(calls[1].format, "%s", "choice text is passed as data to the logger")
eq(calls[1].value,
  'choice=trainer-roster seed=trainer-init parts=["red|ROUTE_3|OPP_BUG_CATCHER|1",2,true]',
  "choice, seed label, and seed parts have exact deterministic content")

emit("league-member-party", "league-member", { "LORELEI", 10 })
eq(calls[2].value,
  'choice=league-member-party seed=league-member parts=["LORELEI",10]',
  "distinct choice sites retain exact stable ordering")

if failures > 0 then
  io.stderr:write(string.format("%d/%d choice-log checks failed\n",
    failures, checks))
  os.exit(1)
end
print(string.format("%d/%d choice-log checks passed", checks, checks))
