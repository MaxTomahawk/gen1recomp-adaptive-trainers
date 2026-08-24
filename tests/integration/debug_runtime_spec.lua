package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")

local modPath = assert(os.getenv("ADAPTIVE_TRAINERS_PATH"),
  "ADAPTIVE_TRAINERS_PATH must name the mod relative to Gen1Recomp")
local run = T.sdk.loadMod(modPath)
local command = run.data.commands["adaptive_trainers:debug"]

T.eq(command, nil,
  "production runtime exposes no ungated diagnostics command")
T.eq(run.loader.exports.adaptive_trainers.debug, nil,
  "production runtime exposes no ungated diagnostics export")
T.eq(#run.loader:legacyReport("adaptive_trainers"), 0,
  "diagnostics use no legacy host-environment compatibility shim")

run.release()
T.finish("adaptive trainers production diagnostics boundary")
