---
name: release
description: Prepare a software release — run all pre-release checks (tests, lint, types, security audit), infer the version bump from conventional commits, update the manifest and changelog, check docs, create the release commit, and (after explicit user confirmation) create the local git tag. Stops BEFORE pushing or publishing so the user does those final actions manually. Use when the user says "release", "cut a release", "prepare a release", or invokes /release.
---

# Release

Prepare a software release through the local tag step. Hand off to the user before anything is pushed or published.

**Scope is local-only.** May create the release commit and (after explicit user confirmation) the local git tag. Never run `git push`, `cargo publish`, `npm publish`, `twine upload`, `gh release create`, or anything equivalent. Stop after the tag.

Run the steps below in order. If any **gate** fails, stop immediately and report — do not continue to the next step. Steps marked **report-only** surface information but do not block.

## 1. Preflight gates

Run `scripts/preflight.sh`. **Hard gates:** on `master` or `main`, and not behind `origin/<branch>` after a fetch. If `asterix` or `upstream` remotes are configured, it also fetches each and fails if you're behind their `master`/`main` (whichever exists) — so a forgotten upstream merge blocks the release. The working-tree-clean check is a **soft gate** (see below). Dot-prefixed paths like `.claude/` are always ignored as local tooling state.

Branch on the exit code:

- **Exit 0** — hard gates pass and the tree is clean. Proceed to step 2.
- **Exit 1** — a hard gate failed (wrong branch, or behind a remote). Stop and surface its output. Do not offer to stash or pull for the user.
- **Exit 2** — hard gates pass but the working tree is dirty. Do **not** stop automatically — make it a judgment call:
  1. **Print** the uncommitted changes the script listed (porcelain lines: first column = staged, second = unstaged; `??` = untracked).
  2. **Judge the severity** yourself and state the call you're making and why:
     - **Low / harmless** — untracked scratch files, logs, build artifacts, or edits confined to files unrelated to the release (notes, unrelated WIP). The surgical commit in step 9 won't touch these, and the pre-release checks in step 3 are unaffected.
     - **High / concerning** — uncommitted or **staged** changes to files this release depends on: the manifest, version files, changelog, lockfiles, or source in the package being released. These can pollute the release commit, or mean step 3's checks ran against an unsaved state. Anything already staged is High by default.
  3. **Let the user choose** with AskUserQuestion: **"Skip the dirty-tree gate and continue"** vs **"Stop the release"**. Lead with the option matching your judgment (mark it Recommended). If they skip, continue to step 2; if they stop, end here.

Skipping the dirty-tree gate does **not** relax the surgical-commit invariant: in step 9 you still stage only manifest/lockfile/changelog/version-string files, never the pre-existing dirty changes.

## 2. Detect project type

Check manifest files in this order. A repo may have several; use the first match for the primary ecosystem but run checks for every detected ecosystem.

- `Cargo.toml` → Rust
- `pyproject.toml` or `setup.py` → Python
- `package.json` → Node/TypeScript
- none of the above → **language-agnostic fallback**: ask the user (a) where the version lives, (b) what commands to run for tests/lint/types/audit. Do not guess.

## 3. Pre-release checks (gates)

All applicable categories must pass. Use ecosystem defaults:

| Ecosystem | Tests        | Lint/format                                       | Types                  | Security                      |
|-----------|--------------|---------------------------------------------------|------------------------|-------------------------------|
| Rust      | `cargo test` | `cargo clippy -- -D warnings` + `cargo fmt --check` | (clippy covers)      | `cargo audit`                 |
| Python    | `pytest`     | `ruff check`                                      | `mypy` (skip if not configured) | `pip-audit`          |
| Node/TS   | `npm test`   | `npm run lint` (or `eslint .`)                    | `tsc --noEmit`         | `npm audit --audit-level=high`|

**Overrides.** If the project has an obvious task runner (`justfile` or `Justfile`, `Makefile`, `package.json` scripts, `CLAUDE.md` or `AGENTS.md` with commands), prefer those over the defaults — they encode the project's actual intent.

**Missing tools.** If a category's tool is not configured for the project (e.g. no `mypy` in `pyproject.toml`, no lint script in `package.json`), note it in the final report and skip that one category. Do not invent configuration to make a check possible.

**Failure.** If any configured check fails, stop. Report the failure concisely with the actual error output. Do not attempt fixes unless the user asks.

## 4. Populate the changelog's unreleased section

Do this **before** proposing a version — the entries are what the user will use to judge the bump level.

Run `scripts/commits-since-last-tag.sh` to get the last tag (or `FIRST_RELEASE:` marker) and the commit list since then. Keep this list; you'll need it in step 5.

Look for `CHANGELOG.md`, `CHANGES.md`, or `HISTORY.md` (case-insensitive).

- **If one exists:** read it and match its existing convention. Write only the *entries* for the new changes into the unreleased area — do NOT pick a version number or date yet. Typical patterns:
  - Keep a Changelog style → fill in (or create) the `[Unreleased]` section with human-readable entries derived from the commit list.
  - Flat version sections → write a new placeholder section at the top titled `Unreleased` (or similar) with the entries. It will be retitled with the real version in step 7.
  - Free-form prose → draft an unreleased paragraph in the project's style.
  - If you can't tell the pattern from the existing file, ask the user.
- **If none exists:** do NOT create one. Just hold the list of human-readable entries in memory to show the user in step 5, and note the missing changelog in the final report.

Changelog entries should be human-readable, not raw commit subjects. Rewrite terse commit messages into complete sentences — but keep them **short and concise**, ideally one line each. State what changed; do not explain motivation, implementation, or history. If a single sentence isn't enough, the entry is probably trying to say too much — split it or trim it. When an entry corresponds to a backward-incompatible change (one that makes downgrade non-trivial — see step 5), call that out explicitly in the entry (e.g. prefix with `**Irreversible:**`) and match whatever "breaking" highlighting the project's changelog already uses.

## 5. Propose the version bump and confirm with the user

**Do not edit any files in this step.** This is a read-only analysis plus an explicit confirmation.

**CalVer is the rare exception, not the default.** Almost no project here uses date-based versions. A version that *looks* like a date is almost always ordinary SemVer/two-part numbers — `24.11` is two-part `major.minor`, NOT 2024-11. Never assume CalVer just because the numbers resemble a year or month, and never derive a version from today's date. If a version genuinely looks CalVer-ish (e.g. `26.07` would "conveniently" match the current month, or components track the calendar across past tags), do **extra sanity checks before treating it as CalVer**: inspect the tag history for a date-tracking pattern, and explicitly confirm the scheme with the user in the step-5 prompt. Only after that confirmation may you bump by date. Default is always the commit-driven rules below.

**Detect the versioning scheme** from the current version string in the manifest. Count the dot-separated numeric components (ignore any `v` prefix and any pre-release/build suffix like `-rc1` or `+build`):

- **3+ parts** (`a.b.c`, `a.b.c.d`) → SemVer-style. Use the table below.
- **2 parts** (`a.b`) → two-part scheme. First number is major (backwards-incompatible), second is bumped for both fixes and new features. There is no separate patch level. Treat as plain numbers, not `year.month`, unless CalVer is confirmed per the note above.
- **1 part** (`a`) → ask the user how they want to bump; do not guess.

Infer the bump level from conventional commit prefixes:

| Signal | SemVer (3+ parts) | Two-part (`a.b`) |
|--------|-------------------|------------------|
| **Forward-incompatible** — `BREAKING CHANGE:` in body, or `!` after type (`feat!:`, `fix!:`); upgrade breaks existing callers | **major** (`a+1.0.0`) | **major** (`a+1.0`) |
| **Backward-incompatible** — upgrade is not reversible: irreversible migrations, on-disk data-format changes, persistent state moved/renamed, new mandatory state files | **major** (`a+1.0.0`) | **major** (`a+1.0`) |
| any `feat:` commit (no major signal) | **minor** (`a.b+1.0`) | **minor** (`a.b+1`) |
| only `fix:`, `chore:`, `docs:`, `refactor:`, `perf:`, `test:`, `style:`, `build:`, `ci:` | **patch** (`a.b.c+1`) | **minor** (`a.b+1`) |

In the two-part scheme, "patch" and "minor" collapse into a single second-number bump — both fixes and features bump it. Only major-warranting changes bump the first number.

**Major means either direction breaks.** Forward-incompatibility (the upgrade breaks existing callers) is what conventional commits already mark with `!` / `BREAKING CHANGE:`. Backward-incompatibility (after upgrading, the user cannot simply downgrade without data loss or manual recovery) has no standard marker, so you have to look for it yourself:

- Inspect each `feat:` / `fix:` for signals: commits that touch a `migrations/`, `alembic/`, `db/migrate/`, `prisma/migrations/`, or similar directory; commits whose subjects or bodies mention "migration", "schema", "data format", "on-disk", "storage layout", "rename column", "drop column", "move config", or "new state file".
- If any candidate is found and is not already flagged with `BREAKING CHANGE:` / `!`, surface it in the step-5 confirmation prompt and ask the user explicitly: *"Is this change reversible — can a user downgrade after applying it without data loss or manual recovery?"* If the answer is no (or unclear), propose **major**.
- A change can be backward-incompatible without being forward-incompatible — e.g. a DB migration that adds a column the old code happily ignores. The API surface is intact, but a downgrade still loses or corrupts data. Bump major.

**Explicit argument.** If the user invoked this skill with an explicit level (`/release minor`, `/release major`), use that as the proposal — but still print the commit list and the level you *would* have inferred, so the user can sanity-check the override.

**First release.** If there's no prior tag, ask the user for the initial version string. Do not default.

Then present a confirmation prompt to the user containing:

- The commit list since the last tag.
- The entries you wrote into the changelog's unreleased area in step 4.
- Your proposed bump level and reasoning (which commits drove it).
- A **reversibility note**: either the specific commits that triggered a backward-incompatibility check (with the question called out for the user to answer), or a brief "no irreversible changes detected" line so the user can sanity-check the call.
- The **current version** and the **proposed new version**.

Ask: **"Proceed with version `<new-version>`?"** and wait for an explicit yes. If the user names a different version or bump level, use theirs. Ambiguous signals → do not proceed. Nothing in steps 6+ runs until the user has confirmed the version.

## 6. Apply the version bump

Only run this step after the user has confirmed the version in step 5.

Compute the new version by applying the confirmed bump to the existing version string — preserve the same shape (number of components, `v` prefix or not, suffix style). Update the manifest(s):

- **Rust** — `Cargo.toml` under `[package] version = "..."`. Refresh `Cargo.lock` by running `cargo update --workspace` (or `cargo check` — which updates the lockfile as a side effect) so the lockfile matches the new manifest version.
- **Python** — `pyproject.toml` under `[project] version` or `[tool.poetry] version`, or `setup.py` `version=`. If using Poetry and `poetry.lock` exists, run `poetry lock --no-update`.
- **Node/TS** — `package.json` `"version"`. If `package-lock.json` exists, run `npm install --package-lock-only` to update it.

**Stray version strings.** Run `scripts/find-stray-versions.sh <old-version>` to list candidate files (lockfiles and changelogs are excluded). Common spots: `src/version.rs`, `__version__` in `__init__.py`, `const VERSION = ...` in JS, README code examples. Update each hit — but only if it's clearly the same version being referenced, not a historical reference.

## 7. Finalize the changelog

Promote the unreleased section from step 4 to a versioned section for `<new-version>` dated `<YYYY-MM-DD>` (today). For Keep-a-Changelog style, leave a fresh `[Unreleased]` above it. For flat-section style, retitle the placeholder with the new version and date. Match the repo's existing format exactly.

**Released sections carry no empty headings.** Delete every `### Added` / `### Changed` / `### Fixed` (etc.) subsection in the released section that has no entries under it. A released section lists only the categories that actually changed.

**The fresh `[Unreleased]` is always scaffolded** with the full set of six headings, empty, in canonical order — `### Added`, `### Changed`, `### Deprecated`, `### Removed`, `### Fixed`, `### Security`. They are placeholders for the next release to fill in, so leave them empty rather than adding "nothing yet" / "N/A" filler text. Separate them with a blank line, even when the file packs entries directly under their headings elsewhere — the placeholders are the one place that spacing always applies. Never leave the new `[Unreleased]` as a bare heading.

If there is no changelog file, skip this step — it was already noted as a warning in step 4.

## 8. Docs check (report-only)

Surface doc inconsistencies — do not block on them.

- **Stale version references.** Run `scripts/docs-check.sh <old-version>` to list README/`docs/`/markdown hits (changelogs excluded). Report any for the user to consider.
- **Undocumented features.** For each `feat:` commit since the last tag, check whether the new feature (new CLI flag, new public API, new command, new config option) is mentioned in the README. If it looks undocumented, flag it.

Include both as warnings in the final report, not as blockers.

## 9. Create the release commit

Stage the changed files — manifest(s), lockfile(s), changelog, any stray version-string updates from step 6. Do NOT stage anything else.

Commit with a short message:

```
release <new-version>
```

If the project obviously uses conventional commits, use `chore(release): <version>` instead. Match the repo's existing release-commit style if you can tell what it is from `git log`.

Never use `--no-verify` or similar to bypass hooks. If a hook blocks the commit, that is a real problem — stop and surface it.

## 10. Tag

The version was already confirmed in step 5, so tag automatically — do not ask again.

Match the existing tag style: check `git tag --list | tail -5`. If the project uses `v`-prefixed tags, run `git tag v<version>`; if it uses unprefixed tags like `10.8.0`, run `git tag <version>`. Do not use annotated tags (`-a`) or sign (`-s`) unless the project's existing tags are annotated/signed.

Then print a concise summary of what was done:

- **New version** and bump level.
- **Checks** that ran and passed (and any skipped because the project didn't configure them).
- **Files in the release commit.**
- **Docs warnings** from step 8, if any.
- **The tag that was created.**

## 11. Hand off

Print the manual next steps the user must run themselves:

```
git push && git push --tags
cargo publish          # or: npm publish / twine upload dist/* / gh release create
```

That's the hand-off. The skill ends here.

## Invariants

- **Local only.** The skill never pushes or publishes. Ever. Even if the user asks mid-flow — tell them to run those steps manually.
- **Version requires explicit confirmation before any version-bump edits.** Step 5 gates steps 6+. Do not touch manifest files, lockfiles, version strings, or promote the changelog's unreleased section until the user has confirmed the version number in the current turn. The step-5 confirmation also authorizes the commit and tag in steps 9–10; do not prompt again for those.
- **Gates are gates — with one judgment call.** Step 1's branch/remote checks and all of step 3 block on failure; never work around them, never use `--no-verify`. The lone exception is step 1's working-tree-clean check: a soft gate the user may consciously skip *after* you surface the uncommitted changes and judge their severity. Everything else stays hard.
- **No guessing on ambiguity.** When the bump level, changelog convention, or version location is unclear, ask.
- **Surgical commit.** Only manifest/lockfile/changelog/version-string files go into the release commit. No drive-by edits.
