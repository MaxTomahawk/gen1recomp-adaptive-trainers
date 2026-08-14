local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")
local chunk = assert(loadfile(ROOT .. "/src/core/rng.lua"))
local rng = chunk()

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

local seedA = rng.seed({ "red", "trainer-init", "ROUTE_3|OPP_YOUNGSTER|1" })
local seedB = rng.seed({ "red", "trainer-init", "ROUTE_3|OPP_YOUNGSTER|1" })
eq(seedA.hi, seedB.hi, "equal seed parts reproduce the high word")
eq(seedA.lo, seedB.lo, "equal seed parts reproduce the low word")
check(seedA.hi >= 0 and seedA.hi < 4294967296,
  "the seed high word is an unsigned 32-bit value")
check(seedA.lo >= 0 and seedA.lo < 4294967296,
  "the seed low word is an unsigned 32-bit value")

local joinedLeft = rng.seed({ "ab", "c" })
local joinedRight = rng.seed({ "a", "bc" })
check(joinedLeft.hi ~= joinedRight.hi or joinedLeft.lo ~= joinedRight.lo,
  "length-prefixing prevents ambiguous seed-part concatenation")

local vector = rng.from_u32(1)
eq(vector:next_u32(), 1015568748, "LCG vector output 1 stays stable")
eq(vector:next_u32(), 1586005467, "LCG vector output 2 stays stable")
eq(vector:next_u32(), 2165703038, "LCG vector output 3 stays stable")

local originalRandom = math.random
math.random = function()
  error("persistent RNG must not call math.random")
end
local noGlobalRandom = pcall(function()
  local stream = rng.stream(seedA, "trainer-init", "identity")
  for _ = 1, 20 do stream:next_u32() end
end)
math.random = originalRandom
check(noGlobalRandom, "persistent streams never delegate to global math.random")

local first = rng.stream(seedA, "trainer-init", "identity")
local again = rng.stream(seedA, "trainer-init", "identity")
local other = rng.stream(seedA, "trainer-growth", "identity")
for index = 1, 100 do
  eq(first:next_u32(), again:next_u32(),
    "the same labeled stream repeats draw " .. index)
end
check(rng.stream(seedA, "trainer-init", "identity"):next_u32()
    ~= other:next_u32(),
  "different labels produce separated streams")

local bounded = rng.stream(seedA, "bounds")
for _ = 1, 1000 do
  local integer = bounded:integer(-3, 7)
  check(integer >= -3 and integer <= 7 and integer % 1 == 0,
    "integer draws stay inside inclusive whole-number bounds")
  local fraction = bounded:float()
  check(fraction >= 0 and fraction < 1,
    "float draws stay in the half-open unit interval")
end

local choice = rng.stream(seedA, "choice")
local picked = choice:choice({ "A", "B", "C" })
check(picked == "A" or picked == "B" or picked == "C",
  "choice returns one supplied row")

if failures > 0 then
  io.stderr:write(string.format("%d/%d RNG checks failed\n", failures, checks))
  os.exit(1)
end

print(string.format("%d/%d RNG checks passed", checks, checks))
