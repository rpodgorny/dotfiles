# Versioning schemes

Read this when the current version looks like a date, or when the scheme is anything
other than plain SemVer or a two-part `a.b`.

## CalVer is the rare exception

Almost no project here uses date-based versions. A version that *looks* like a date is
almost always ordinary numbers: `24.11` is two-part `major.minor`, not 2024-11. The
resemblance is a coincidence that has already caused a wrong bump.

Before treating a version as CalVer, both of these must hold:

1. **The tag history tracks the calendar.** Walk `git tag --list` in order and check
   that components actually follow dates across several releases: `25.03`, `25.07`,
   `26.01`. Two tags that happen to look date-ish are not a pattern.
2. **The user confirms the scheme** in the step-5 prompt, in the same turn, in answer
   to the question asked outright.

Only with both may you bump by date. Absent either, use the commit-driven rules in
step 5. Never derive a version from today's date on your own authority.

## Component counts

- **3 or more parts** (`a.b.c`, `a.b.c.d`) — SemVer-style, use step 5's table.
- **2 parts** (`a.b`) — first number is major (either direction of incompatibility),
  second covers both fixes and features. No separate patch level, so "patch" and
  "minor" collapse into one second-number bump.
- **1 part** (`a`) — ask how to bump. Do not guess.

Ignore a leading `v` and any `-rc1` / `+build` suffix when counting, and preserve both
when writing the new version back.
