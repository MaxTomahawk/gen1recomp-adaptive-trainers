# Capability audit

Updated: 2026-08-14

## Current capabilities

| Capability | Provenance | Authority and data scope | Decision |
|---|---|---|---|
| Local Git and filesystem | Host toolchain | This standalone workspace and ignored local engine checkout | Retain |
| GitHub CLI | GitHub, authenticated as `MaxTomahawk` | Repository creation, Git transport, Actions inspection | Retain |
| GitHub connector | Installed OpenAI-curated plugin | Structured public/private repository, PR, issue, and review metadata available to the linked account | Retain for metadata and PR operations |
| Gen1Recomp modkit | Current upstream `dev` | Scaffold, headless loader validation, lint, reproducible pack, release workflow | Retain as the compatibility authority |
| LuaJIT and LÖVE | Host toolchain | Local unit, integration, and runtime tests | Retain |
| Web access | Primary upstream GitHub sources | Read-only current-source verification | Retain |

## Admission decision

The existing capabilities are sufficient for mod implementation, testing, GitHub delivery, CI, and packaging. No additional plugin, MCP, provider, authentication, spending, or deployment capability is approved or needed.

Engine work is not an admitted implementation capability by default. The Gym eligibility gap is recorded as `AT-SP-001` in `docs/IMPLEMENTATION_STATUS.md` and remains a candidate until the specification phase that consumes it reaches its test-first design boundary.
