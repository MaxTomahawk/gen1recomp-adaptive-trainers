local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local kanto_plus = assert(loadfile(ROOT .. "/src/data/kanto_plus.lua"))()

local checks, failures = 0, 0
local function check(condition, message)
  checks = checks + 1
  if not condition then failures = failures + 1; io.stderr:write("FAIL ", message, "\n") end
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (expected " .. tostring(expected)
    .. ", got " .. tostring(actual) .. ")")
end

local instance = {
  id = "brock-signature", lineId = "ONIX_LINE", species = "STEELIX",
  level = 42, moves = { "IRON_TAIL", "EARTHQUAKE", "ROCK_SLIDE" },
  attachment = 77,
}
local changed = kanto_plus.reconcile_instance(instance, { ONIX = {} })
eq(changed, true, "missing sidecar content triggers a safe fallback")
eq(instance.species, "ONIX", "Steelix falls back to the prior Kanto stage")
eq(instance.lineId, "ONIX_LINE", "fallback never rerolls line identity")
eq(instance.level, 42, "fallback preserves the generated level")
eq(instance.attachment, 77, "fallback preserves unrelated persistent state")
eq(instance.suspendedStage.species, "STEELIX",
  "fallback remembers the unavailable post-Gen1 stage")
eq(instance.suspendedStage.fallback, "ONIX",
  "fallback records the concrete Kanto replacement")

local unchanged = kanto_plus.reconcile_instance(instance, { ONIX = {} })
eq(unchanged, false, "repeated fallback reconciliation is idempotent")
eq(instance.suspendedStage.species, "STEELIX",
  "repeated fallback does not overwrite restoration memory")

local restored = kanto_plus.reconcile_instance(instance, {
  ONIX = {}, STEELIX = {},
})
eq(restored, true, "restored sidecar content reverses the suspension")
eq(instance.species, "STEELIX", "the original post-Gen1 stage returns")
eq(instance.suspendedStage, nil, "successful restoration clears the marker")
eq(table.concat(instance.moves, ","),
  "IRON_TAIL,EARTHQUAKE,ROCK_SLIDE",
  "suspension preserves persistent move memory byte-for-byte")

local ordinary = { id = "ordinary", lineId = "ZUBAT_LINE",
  species = "GOLBAT", level = 35 }
eq(kanto_plus.reconcile_instance(ordinary, { GOLBAT = {} }), false,
  "Kanto-only individuals remain byte-stable without the sidecar")
eq(ordinary.suspendedStage, nil,
  "ordinary Kanto stages never gain a false suspension marker")

local drifted = { species = "ONIX", lineId = "ONIX_LINE",
  suspendedStage = { species = "STEELIX", fallback = "GOLBAT" } }
eq(kanto_plus.reconcile_instance(drifted, { ONIX = {}, STEELIX = {} }), false,
  "a malformed marker fails closed instead of changing evolution lines")
eq(drifted.species, "ONIX", "failed restoration leaves the live stage intact")

if failures > 0 then
  io.stderr:write(string.format("%d/%d fallback checks failed\n", failures, checks))
  os.exit(1)
end
print(string.format("%d/%d fallback checks passed", checks, checks))
