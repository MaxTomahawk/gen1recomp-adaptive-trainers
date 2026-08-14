return {
  switching = {
    [1] = { chance = 8, maxPerBattle = 1 },
    [2] = { chance = 160, maxPerBattle = 1, hpAtMost = 0.34,
      rosterBehaviors = {
        specialist = true,
        training = true,
        variance = true,
      },
    },
    [3] = { chance = 32, maxPerBattle = 1 },
  },
  expert = {
    damagePowerDivisor = 40,
    maximumPowerBonus = 3,
    stabBonus = 2,
    unreliableAccuracy = 80,
    unreliablePenalty = 1,
  },
  boss = {
    preferredMoveBonus = 4,
    preferredTypeBonus = 2,
  },
}
