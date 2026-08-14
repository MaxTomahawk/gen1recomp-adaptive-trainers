# Repository Guidelines

## Project Structure & Module Organization

This repository is currently an initial scaffold: `docs/` is reserved for design and contributor documentation, while no source or test tree has been committed yet. As implementation is added, keep runtime code in `src/`, mirror modules under `tests/`, and place non-code resources in `assets/`. Keep generated output out of version control; `.gitignore` already excludes `.engine/`, `.worktrees/`, `.tmp/`, `build/`, `dist/`, and packaged `*.love` files.

## Build, Test, and Development Commands

No project build, test, or run command is configured yet. Contributors who introduce a toolchain must add stable commands to the project README and keep this guide synchronized. Useful repository checks today are:

- `git status --short` — review changed and untracked files.
- `git diff --check` — detect whitespace errors before committing.
- `git diff --stat` — confirm the intended scope of a change.

If a LÖVE entry point is added, document the supported local launch and packaging commands rather than relying on machine-specific scripts.

## Coding Style & Naming Conventions

Prefer small, single-purpose modules and explicit dependencies. Use `snake_case` for Lua files and functions, `PascalCase` only for class-like tables, and `SCREAMING_SNAKE_CASE` for constants. Use two-space indentation in Lua, Markdown, YAML, and JSON; avoid tabs and trailing whitespace. No formatter or linter is configured, so preserve nearby style and introduce automated tooling with its configuration in the same pull request.

## Testing Guidelines

No test framework or coverage threshold exists yet. New behavior should include automated tests under `tests/`, named after the unit or feature they cover (for example, `tests/adaptive_schedule_spec.lua`). Bug fixes should include a regression test. Document the exact test command when the first framework is adopted.

## Commit & Pull Request Guidelines

The repository has no commit history from which to infer conventions. Use concise, imperative subjects, optionally with Conventional Commit prefixes such as `feat:`, `fix:`, `test:`, or `docs:`. Keep commits focused. Pull requests should explain the problem and solution, list validation performed, link relevant issues, and include screenshots or recordings for visible trainer or interface changes.

## Security & Configuration

Never commit credentials, personal training data, or machine-specific configuration. Provide sanitized examples for any required configuration and document local setup in `docs/`.
