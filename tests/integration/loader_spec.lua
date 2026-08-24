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
T.check(type(run.data.screens.AdaptiveGymRegistration) == "table"
    and type(run.data.screens.AdaptiveGymRegistration.new) == "function",
  "the Gym registration screen is installed through the public registry")
if exports and exports.status then
  local status = exports.status()
  local expectedReason = run.loader.datasetViews ~= nil
    and "not_imported" or "dataset_api_unavailable"
  T.eq(status.phase, "G", "the status boundary reports the implemented phase")
  T.eq(status.schema, 1, "the status boundary reports the current save schema")
  T.eq(status.kantoPlus, false,
    "the normal fixture cannot enable the optional Gold sidecar")
  T.eq(status.sandResidual, false,
    "the normal fixture cannot install the optional residual hook")
  T.eq(status.solarBeamSkip, false,
    "the normal fixture cannot install the optional charge hook")
  T.eq(status.reason, expectedReason,
    "an unimported Gold cache reports the exact live dataset boundary")
  T.eq(status.datasetReason, expectedReason,
    "the dataset diagnostic reports the exact live dataset boundary")
end

run.release()
T.finish("adaptive trainers loader")
