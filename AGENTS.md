# Project Instructions

## Commit messages

No attribution in commit messages. That means **no** "🤖 Generated with
Codebuff", **no** `Co-Authored-By: Codebuff <noreply@codebuff.com>` line and no
comparable AI/tool notes or trailers. The commit message ends with its last
content line.

## Release notes

Every release describes what is new in it. Before creating a release, add a
`### New in <version>` section with concrete, user-facing bullets to both
`.github/macos-release-notes.md` and `.github/windows-release-notes.md` (version
without the leading `v`, matching the tag). If a platform has no functional
change, say so explicitly instead of dropping the section.
`scripts/render-release-notes.js` fails the release build when either section is
missing or empty.

## Language

Commit messages, release notes and documentation in **English**. The app UI is
localized in German, English, Spanish and French with English as the fallback.
