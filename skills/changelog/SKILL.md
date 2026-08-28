---
name: changelog
description: Write or update a project's changelog — find the file, match its existing convention, turn commits into human-readable entries, and keep the unreleased section tidy. Use when the user says "update the changelog", "add a changelog entry", "write changelog", "changelog for these commits", or invokes /changelog. Also use as the changelog half of a release; /release calls into these same rules. Also use proactively, without being asked, once a user-visible change has landed (a feature, a bugfix, a changed default, a new or renamed option) in a repo that already has a changelog file, before or alongside committing it. Do not use for refactors, test-only changes, CI tweaks or formatting, and do not use in a repo with no changelog.
---

# Changelog

Write changelog entries that a user of the software can read. The changelog is not a commit log —
it says what changed for someone using the thing, not what was done to the source.

## 1. Find the file and read it

Look for `CHANGELOG.md`, `CHANGES.md`, or `HISTORY.md` (case-insensitive), usually at the repo root.

- **Found one** — read it before writing anything. The existing file is the style guide.
- **Found none** — do NOT create one uninvited. Ask whether the user wants one; if the request was
  "add an entry" and no changelog exists, say so rather than inventing a format.

## 2. Match the existing convention — never impose one

Detect the shape from the file itself:

- **Keep a Changelog** — `## [Unreleased]` plus `## [x.y.z] - YYYY-MM-DD` sections, each split into
  `### Added` / `### Changed` / etc.
- **Flat version sections** — `## 1.2.3` with a bare list under it, no subsections.
- **Free-form prose** — paragraphs per release.

If you cannot tell, ask. Do not "upgrade" a flat changelog to Keep a Changelog because it seems
better; that is a style change the user did not request.

**Which subsections to use.** Only use headings the project already uses. Count them first:

```bash
grep -oh "^### .*" CHANGELOG.md | sort | uniq -c | sort -rn
```

A project with 150 headings and zero `### Deprecated` does not want a `### Deprecated`. Write a
heading only when it has entries under it. When ordering the ones you do write, keep Keep a
Changelog's canonical order regardless of frequency:

```
Added, Changed, Deprecated, Removed, Fixed, Security
```

Same for date format, version bracketing (`## [7.4]` vs `## 7.4`), and whether entries end in a
period — copy what is already there.

## 3. Derive the entries from real changes

Get the commits since the last release:

```bash
git describe --tags --abbrev=0
git log --oneline <last-tag>..HEAD
```

Read the actual diffs when a commit subject is too terse to explain the user-visible effect. A
subject like `fix(forms): keep edits in flight` tells you nothing about what the user was
experiencing — the diff and the surrounding discussion do.

Commits that change nothing observable — refactors, test-only changes, CI tweaks, formatting —
usually get no entry. Don't pad the changelog to make a release look busy. If a release genuinely
has no user-visible changes, say so rather than manufacturing entries.

## 4. Write the entry

**One line each.** If a single sentence isn't enough, the entry is trying to say too much — split it
or cut it. The whole story is already in the commit message and the diff, and that is where
anyone who wants it will look. A changelog entry is a pointer into that history, not a retelling of it.

**Say what changed, from the user's side.** Not the motivation, not the implementation, not the
history of how you found the bug.

- Bad: `Fixed a race condition in InputField's onbeforeupdate handler.`
- Bad: `Users were complaining that recipe editing was unreliable, so we investigated and found that Mithril freezes vnode children...`
- Good: `Editing several form fields faster than the server replies no longer makes earlier fields fall back to their previous values.`

**Name the visible symptom.** The reader recognises their own bug by its symptom, never by its cause.
Adding a short "most visibly when ..." clause is worth it when one workflow triggers it far more than
others.

**Rewrite terse subjects into complete sentences.** `fix: pump w/o prices` becomes
`Pumping works without the prices module.`

**Present tense, describing the new state.** "Setup only offers settings whose module is on", not
"Made Setup only offer...".

## 5. Flag changes that cannot be undone

A change is **irreversible** when a user who upgrades cannot simply downgrade again without data loss
or manual recovery — schema migrations, on-disk format changes, moved or renamed persistent state,
new mandatory state files.

These matter more than API breaks, because nothing marks them automatically: conventional commits
flag forward-incompatibility with `!` / `BREAKING CHANGE:`, but a migration that merely adds a column
looks like an ordinary `feat:` while still making downgrade destructive.

Call it out inline, matching whatever highlighting the project already uses:

```markdown
- The totals block shows rounding as a separate line. **Irreversible:** applying migration 199 alters the schema; a downgrade requires rolling it back.
```

Check for these by looking for commits touching `migrations/`, `alembic/`, `db/migrate/`,
`prisma/migrations/`, or mentioning "migration", "schema", "data format", "on-disk", "storage
layout", "rename column", "drop column", "move config", or "new state file". A change can be
irreversible without being forward-incompatible: a migration that adds a column the old code ignores
leaves the API intact but still loses data on downgrade.

When you find a candidate that isn't already flagged with `!` / `BREAKING CHANGE:`, ask the user
outright: *"Can a user downgrade after applying this without data loss or manual recovery?"* Never
guess.

## 6. Unreleased vs released sections

**Adding entries for work in progress** — put them under `## [Unreleased]`, in the right subsection.
Create the subsection if it isn't there yet. A file with no `[Unreleased]` convention gets a
placeholder section at the top instead: flat-section style, a bare `## Unreleased`; free-form prose,
an unreleased paragraph in the project's voice.

**At release time** — promote the unreleased section to a versioned one titled with the new version
and today's date, then leave a fresh `[Unreleased]` above it. For a flat or free-form file, retitle
the placeholder in place; there is no fresh section to scaffold. The version number itself is
`/release`'s decision, not this skill's; don't pick one here.

**Released sections carry no empty headings.** Delete every `### Added` / `### Changed` / `### Fixed`
(etc.) subsection in the released section that has no entries under it. A released section lists only
the categories that actually changed.

**The fresh `[Unreleased]` is always scaffolded** with the full set of six headings, empty, in
canonical order:

```markdown
## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security
```

They are placeholders for the next release to fill in, so leave them empty rather than adding
"nothing yet" / "N/A" filler text. Separate them with a blank line, even when the file packs entries
directly under their headings elsewhere — the placeholders are the one place that spacing always
applies. This applies both when creating a changelog and when promoting `[Unreleased]` at release
time — never leave the new `[Unreleased]` as a bare heading.

**Never edit a section that is already tagged.** If the entry belongs to a release that has been
tagged, the tagged tree should keep saying what it said. Add a new commit on top instead of amending
the release commit, so the tag still points at exactly what was released.

## 7. Commit

Stage only the changelog. A changelog edit is not an excuse to sweep up unrelated working-tree
changes.

Match the repo's existing commit style — check `git log --oneline` first. Common:

```
docs(changelog): <what>
```

## Invariants

- **The file's existing convention wins** over anything in this skill.
- **No invented changelog.** If none exists, ask; don't create one as a side effect.
- **No entries for invisible changes.** Refactors and test churn stay out.
- **No guessing on reversibility.** If you can't tell whether a downgrade is safe, ask.
- **Tagged sections are frozen.** Amend nothing that a tag points at.
