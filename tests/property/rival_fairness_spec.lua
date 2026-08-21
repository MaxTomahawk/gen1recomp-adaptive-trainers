local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

assert(loadfile(ROOT .. "/tests/property/rival_fairness.lua"))()
