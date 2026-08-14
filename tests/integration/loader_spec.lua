package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")

local modPath = assert(os.getenv("ADAPTIVE_TRAINERS_PATH"),
  "ADAPTIVE_TRAINERS_PATH must name the mod relative to Gen1Recomp")
local run = T.sdk.loadMod(modPath)

T.eq(#run.errors, 0,
  "the standalone mod loads without loader errors: "
    .. tostring(run.errors[1]))
T.check(run.mod ~= nil and run.mod.state == "loaded",
  "adaptive_trainers reaches the loaded state")

if run.mod then
  T.eq(run.mod.manifest.id, "adaptive_trainers",
    "the distributable root declares the stable mod id")
  T.same(run.mod.manifest.games, { "red", "blue", "yellow" },
    "the manifest targets exactly the three Gen 1 versions")
end

local exports = run.loader.exports.adaptive_trainers
T.check(type(exports) == "table" and type(exports.status) == "function",
  "the entrypoint publishes a runtime status boundary")
if exports and exports.status then
  T.same(exports.status(), { phase = "A", schema = 1 },
    "the status boundary reports the implemented save contract")
end

run.release()
T.finish("adaptive trainers loader")
