# Package Gate Implementation Plan

> **For agentic workers:** Execute this plan inline with the TDD and verification skills.

**Goal:** Make the package layout and byte-reproducibility check a mandatory, non-recursive release gate.

**Architecture:** Keep `scripts/package.sh` as the public checked-package entrypoint. Extract its single-pack staging operation into an internal helper that can produce a caller-selected archive without invoking the public workflow. The package workflow will create one release archive, invoke the layout test against that exact fresh path, and let the layout test create only the required second archive in a temporary directory.

**Tech Stack:** Bash, Python `modkit.py`, ZIP inspection, SHA-256.

**Spec:** `final-dod-audit-report.md` P1 package-gate requirement.

## Global Constraints

- Preserve `SOURCE_DATE_EPOCH` defaulting and explicit values.
- Preserve ROM-free `modkit pack` validation and archive-root layout.
- Preserve the existing `scripts/package.sh` command and output artifact path.
- Never use a pre-existing `dist/` archive as the first reproducibility input.
- Keep the normal workflow to exactly two package operations.

### Task 1: Prove the missing gate

**Files:**
- Modify: `tests/tooling/check_script_spec.sh`

- [x] Add assertions that the public package workflow invokes the layout test and that the layout test invokes only the internal pack helper, not `package.sh`.
- [x] Run the focused tooling test and confirm it fails because the current package workflow has no mandatory layout invocation.

### Task 2: Implement the non-recursive gate

**Files:**
- Create: `scripts/package_once.sh`
- Modify: `scripts/package.sh`
- Modify: `tests/tooling/package_layout_spec.sh`

- [x] Move one archive's staging/pack operation into the internal helper.
- [x] Have `package.sh` run checks, create the fresh first archive, and invoke the layout test with its exact path.
- [x] Have the layout test create a temporary second archive through the helper and inspect both hashes and contents.
- [x] Run focused tooling tests and the layout test green.

### Task 3: Document and verify the release contract

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `README.md`
- Modify: `docs/IMPLEMENTATION_STATUS.md`
- Create: `.superpowers/sdd/2026-08-14-adaptive-trainers/task-9-package-gate-report.md`

- [x] Make CI rely on the package command's mandatory gate without a redundant third packaging pass.
- [x] Document that `package.sh` performs layout/reproducibility verification and does not consume stale `dist/` output.
- [x] Record the bounded gate as closed in the status/report, with exact verification evidence.
- [x] Run all requested checks, diff hygiene, and syntax checks.
