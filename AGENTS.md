# Repository Guidelines

## Project Structure & Module Organization

Runtime code lives in `src/`, focused unit/property/integration coverage lives
under `tests/`, and non-code resources belong in `assets/`. The approved design
baseline is `Gen1Recomp_Adaptive_Trainers_Complete_Design_Spec_NL.docx`; the
living execution record is `docs/IMPLEMENTATION_STATUS.md`. Keep generated
output out of version control; `.gitignore` excludes `.engine/`, `.worktrees/`,
`.tmp/`, `build/`, `dist/`, and packaged artifacts.

## Build, Test, and Development Commands

Use a separate checkout of current `bryanthaboi/gen1recomp:dev`; never vendor
the engine into the distributed mod. The stable project commands are:

- `GEN1RECOMP_ROOT=/path/to/gen1recomp ./scripts/check.sh` — run every local
  unit/property/integration suite, then current `modkit validate` and
  `modkit lint`.
- `GEN1RECOMP_ROOT=/path/to/gen1recomp SOURCE_DATE_EPOCH=0 ./scripts/package.sh`
  — repeat the gates and build the reproducible ROM-free package under `dist/`.
- `git diff --check` and `git status --short` — verify patch hygiene and scope
  before committing.

Keep these commands and the README synchronized when the toolchain changes.

## Coding Style & Naming Conventions

Prefer small, single-purpose modules and explicit dependencies. Use `snake_case` for Lua files and functions, `PascalCase` only for class-like tables, and `SCREAMING_SNAKE_CASE` for constants. Use two-space indentation in Lua, Markdown, YAML, and JSON; avoid tabs and trailing whitespace. No formatter or linter is configured, so preserve nearby style and introduce automated tooling with its configuration in the same pull request.

## Testing Guidelines

Write deterministic tests first or alongside every behavior change. Watch a
focused regression fail for the intended reason before implementing a bug fix.
Cover repeatability, save/reload persistence, negative and boundary cases, and
Red/Blue/Yellow behavior as applicable. Engine work also requires the current
upstream public-API, no-mod parity, compatibility, lint, and regression gates.

## Commit & Pull Request Guidelines

Use concise imperative Conventional Commit subjects and keep commits focused.
Mod-repository PRs must explain the concrete gameplay requirement, solution,
validation, and any known limitation.

### Upstream Gen1Recomp PRs

Current upstream policy is live authority. Before every engine branch and again
before opening or updating its PR:

1. Fetch `bryanthaboi/gen1recomp:dev`, base the feature branch directly on its
   current SHA, and re-read the current `CONTRIBUTING-mods.md`, affected public
   API docs, RFC conventions, and CI/lint configuration. Do not rely on a copied
   or remembered contribution-policy snapshot.
2. State the concrete consumer in the PR body itself. For Adaptive Trainers,
   name this mod and the exact approved feature that cannot be expressed through
   the current public API. Explain the blocked call site/authority boundary and
   the public APIs considered. A generic use case, or naming the consumer only
   in an RFC, is insufficient. This incorporates the repository owner's request
   on [Gen1Recomp PR #1645](https://github.com/bryanthaboi/gen1recomp/pull/1645#issuecomment-5370291166).
3. Keep engine code generic: the PR and RFC may identify Adaptive Trainers as
   motivation, but the API, payload, implementation, tests, and docs must contain
   no Adaptive Trainers policy.
4. For current Route B changes, satisfy all five documented obligations in the
   same change: an RFC with concrete motivation, traceable decision/plan, exact
   API delta and migration note; a backward-compatibility statement; separate
   guarded no-mod parity and sandboxed public-API tests; updated/generated docs;
   and additive deprecation etiquette. Changes touching `src/mods/`, schemas, or
   event/hook catalogs require the RFC label and a green parity gate.
5. The PR body must include: summary; **Motivation / consuming mod**; why existing
   public seams are insufficient; exact generic API delta; compatibility and
   no-mod behavior; RFC/docs links; exact verification commands and results;
   skipped/unavailable evidence; and the applicable Route B checklist.
6. Run the current engine lint gate (`./scripts/lint.sh --gate`) and full lint
   report in addition to focused tests and `./scripts/test.sh`. Do not claim lint
   success when the required tool is unavailable; record that limitation and
   rely on CI only after inspecting its result.
7. Inspect CI, reviews, and maintainer comments after every push. Reply to inline
   review comments in their original thread. Do not merge upstream PRs or
   rewrite shared history.

## Security & Configuration

Never commit credentials, personal training data, or machine-specific configuration. Provide sanitized examples for any required configuration and document local setup in `docs/`.
