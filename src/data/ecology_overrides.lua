-- Explicit seams for maps/classes whose plausible acquisition context does not
-- follow ordinary walkable wild-encounter adjacency. Phase B consumes these
-- records for catches; Phase A keeps the tables empty rather than inventing
-- cross-wall ecology.
return {
  byMap = {},
  byClass = {
    OPP_ROCKET = { organizationIssued = true },
    OPP_SCIENTIST = { contextIssued = true },
    OPP_SUPER_NERD = { contextIssued = true },
  },
}
