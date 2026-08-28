---
name: release
description: Release preparation, local only — pre-release gates (tests, lint, types, audit), version bump inferred from conventional commits, manifest and changelog updates, release commit, git tag. Stops before any push or publish. Use when the user asks to cut or prepare a release.
---

# Release

Prepare a software release through the local tag step. Hand off to the user before anything is pushed or published.

**Scope is local-only.** May create the release commit and (after explicit user confirmation) the local git tag. Never run `git push`, `cargo publish`, `npm publish`, `twine upload`, `gh release create`, or anything equivalent — including when the user asks for it mid-flow, in which case hand them the commands to run themselves. Stop after the tag.

Run the steps below in order. If any **gate** fails, stop immediately and report — do not continue to the next step. Steps marked **report-only** surface information but do not block.

## 1. Preflight gates

Run `scripts/preflight.sh`. **Hard gates:** on `master` or `main`, and not behind `origin/<branch>` after a fetch. If `asterix` or `upstream` remotes are configured, it also fetches each and fails if you're behind their `master`/`main` (whichever exists) — so a forgotten upstream merge blocks the release. The working-tree-clean check is a **soft gate** (see below). Dot-prefixed paths like `.claude/` are always ignored as local tooling state.

Branch on the exit code:

- **Exit 0** — hard gates pass and the tree is clean. Proceed to step 2.
- **Exit 1** — a hard gate failed (wrong branch, or behind a remote). Stop and surface its output. Do not offer to stash or pull for the user.
- **Exit 2** — hard gates pass but the working tree is dirty. Do not stop automatically, and do not wave it through either. Work 1a and 1b below, then continue to step 2.

Skipping the dirty-tree gate does **not** relax the surgical-commit invariant: in step 9 you still stage only manifest/lockfile/changelog/version-string files, never the pre-existing dirty changes.

### 1a. Tracked changes

Print the porcelain lines for tracked paths (first column = staged, second = unstaged). Judge severity and state the call you are making:

- **Low** — edits confined to files unrelated to the release: notes, unrelated WIP.
- **High** — uncommitted or **staged** changes to files this release depends on: the manifest, version files, changelog, lockfiles, or source in the package being released. These pollute the release commit, or mean step 3's checks ran against an unsaved state. Anything already staged is High by default.

Then ask with AskUserQuestion: **"Skip the dirty-tree gate and continue"** vs **"Stop the release"**, leading with the option matching your judgment. If nothing tracked is modified, skip straight to 1b.

A submodule whose only change is untracked content inside it shows as ` M` in a plain `git status`. Run `git diff --submodule=short` before calling that High. An empty diff means the pinned commit is unchanged and there is nothing to release.

### 1b. Untracked paths

**Untracked does not mean harmless, and this is where releases quietly go wrong.** Every `??` path is one of two very different things: something deleted on purpose that came back, or something written and never added. The second kind ships a release with a hole in it. In a porcelain listing the two look identical, so never judge the `??` block as a group and never dismiss it as "scratch files". None of these paths are in `.gitignore`, git is actively reporting them.

Run `scripts/classify-untracked.sh`. It labels each path from git history and prints two signals: how many tracked files share its directory, and which tracked source files mention its name.

Handle each class. **Every class except IGNORABLE needs a user decision. Do not batch them into one question, and do not reach step 2 with one unanswered.**

| Class | What it means | Required outcome |
|---|---|---|
| `GHOST` | Tracked once, a commit deleted it, on-disk copy is byte-identical. It came back after a deliberate cleanup. | **Push to remove.** Name the deleting commit, its date and its subject. Offer deletion as the recommended option. Keeping it takes an explicit "keep it". |
| `REVIVED` | Deleted, but the on-disk content differs. Could be real work re-added on top, could be a stale copy from another machine. | Show the printed diff and ask which it is. Do not guess. |
| `LEFTOVER` | A commit deleted files under this path, content could not be compared (directory, or no parent commit). | Treat as `GHOST`, but say the comparison was unavailable. |
| `NEW` | Never tracked in any branch. **The "forgot to `git add`" class.** | Ask the user to confirm, in as many words, that they are sure this should stay out of the release. Never infer it from the extension. |
| `IGNORABLE` | Never tracked, matches a build or scratch pattern. | One summary line, no question. Suggest a `.gitignore` entry if it will recur. |

For a `NEW` path, weigh both signals before asking and put your reading into the question:

- **Referenced by tracked source** is the strongest tell. If a tracked test or module opens the file by name, the file is part of how this code behaves.
- **Tracked siblings** means it sits in a directory git already manages, which is exactly where forgotten work lands.
- Read the matched line instead of trusting the basename. A hit on `vendor/lodash.js` does not vindicate a stray `static/lodash.js`.

Watch for one specific trap. A tracked test that guards an untracked file with `os.path.isfile(...)`, or any other existence check, takes one branch on this machine and the other branch on a clean clone. Step 3 then measures something CI will never run. Say so out loud when you see it.

Resolve 1b before step 3, so the pre-release checks run against the state you are actually releasing.

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

**Failure — tests, types, security.** Stop. Report the failure concisely with the actual error output. Do not attempt fixes unless the user asks.

**Failure — lint and format.** Do not stop on the exit code alone. A linter upgrade or a newly tightened rule fails on code nobody touched this cycle, and blocking a release on that is wrong. Triage first, then decide:

1. Collect the `file:line` of every finding from the linter output.
2. Run `scripts/triage-lint.sh <file:line> ...`. For each location it blames the line and checks whether the commit that last touched it is an ancestor of the last release tag.
3. Branch on the verdicts:

| Verdicts | Gate | What to do |
|---|---|---|
| any `INTRODUCED` or `UNKNOWN` | hard | This cycle's work broke lint. Stop and report, same as any other failed check. |
| all `PRE-EXISTING` | soft | Report each finding with the commit and date that introduced it, then ask with AskUserQuestion: **"Continue the release"** (lead with this, the findings predate this cycle) vs **"Stop and fix lint first"**. |

`UNKNOWN` counts as introduced deliberately. No prior tag, a blame that fails, or a finding with no line number is a reason to look, not a reason to wave through.

A waived finding is still a finding. Do not fix it as part of the release — that pollutes the release commit, and step 9 stages manifest, lockfile, changelog and version-string files only. Carry every waived finding into the step 10 summary.

## 4. Populate the changelog's unreleased section

Do this **before** proposing a version — the entries are what the user will use to judge the bump level.

Run `scripts/commits-since-last-tag.sh` to get the last tag (or `FIRST_RELEASE:` marker) and the commit list since then. Keep this list; you'll need it in step 5.

Apply the **`changelog` skill** to turn that commit list into entries. It owns everything about what an entry says, which convention the file follows, and how irreversible changes get flagged. Two release-time deltas:

- Write only the *entries*, into the unreleased area. The version number and date are step 5's decision, not yours here.
- **If no changelog file exists:** do not create one. Hold the entries to show the user in step 5, and note the missing changelog in the final report.

## 5. Propose the version bump and confirm with the user

**Do not edit any files in this step.** This is a read-only analysis plus an explicit confirmation.

**Detect the versioning scheme** from the current version string in the manifest. Count the dot-separated numeric components (ignore any `v` prefix and any `-rc1` / `+build` suffix):

- **3+ parts** (`a.b.c`, `a.b.c.d`) → SemVer-style. Use the table below.
- **2 parts** (`a.b`) → two-part scheme: first number major, second for both fixes and features. `24.11` is `major.minor`, **not** 2024-11.
- **1 part**, or anything that looks like a date → `references/versioning.md`. Never derive a version from today's date; CalVer needs a tag history that proves it and the user's confirmation in this turn.

Infer the bump level from conventional commit prefixes:

| Signal | SemVer (3+ parts) | Two-part (`a.b`) |
|--------|-------------------|------------------|
| **Forward-incompatible** — `BREAKING CHANGE:` in body, or `!` after type (`feat!:`, `fix!:`); upgrade breaks existing callers | **major** (`a+1.0.0`) | **major** (`a+1.0`) |
| **Backward-incompatible** — upgrade is not reversible: irreversible migrations, on-disk data-format changes, persistent state moved/renamed, new mandatory state files | **major** (`a+1.0.0`) | **major** (`a+1.0`) |
| any `feat:` commit (no major signal) | **minor** (`a.b+1.0`) | **minor** (`a.b+1`) |
| only `fix:`, `chore:`, `docs:`, `refactor:`, `perf:`, `test:`, `style:`, `build:`, `ci:` | **patch** (`a.b.c+1`) | **minor** (`a.b+1`) |

In the two-part scheme, "patch" and "minor" collapse into a single second-number bump — both fixes and features bump it. Only major-warranting changes bump the first number.

**Major means either direction breaks.** Forward-incompatibility (the upgrade breaks existing callers) is what conventional commits already mark with `!` / `BREAKING CHANGE:`. Backward-incompatibility has no standard marker, so you hunt for it: the `changelog` skill's **irreversible** rules define what counts and list the signals to grep for. Any unflagged candidate goes into the step-5 prompt with its downgrade question attached; if the answer is no or unclear, propose **major**.

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

Apply the `changelog` skill's release-time rules with `<new-version>` and today's date: promote the unreleased section, drop empty headings from the released section, scaffold a fresh `[Unreleased]`.

If there is no changelog file, skip this step. It was already noted as a warning in step 4.

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
- **Checks** that ran and passed, any skipped because the project didn't configure them, and any pre-existing lint findings waived in step 3 (with the commit that introduced each).
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

