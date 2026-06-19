# Changelog

All notable changes to xReview are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-06-19

### Added
- **Codex (OpenAI) as a third peer agent**, with dynamic detection of installed agents.
- **Installer update mode** — re-running `install.sh` is now a safe update path. The
  xReview section in `CLAUDE.md` / `GEMINI.md` / `AGENTS.md` is wrapped in
  `<!-- xReview:start -->` / `<!-- xReview:end -->` markers and replaced in place,
  preserving any user content outside the markers. Marker pairing is validated in a
  single pass, so nested, stray, or unterminated markers abort before any overwrite.
- **Legacy migration** — pre-marker installs are migrated to markers automatically, but
  only when the block is unchanged; an edited block or trailing user content aborts
  cleanly instead of being dropped.
- **Version tracking** — a `VERSION` file (source of truth), an `xreview version`
  subcommand, a `.review/.xreview-version` stamp (written last, so a failed install is
  not recorded as current), and fresh / update / reinstall messaging.
- CI check that `VERSION` stays in sync with `bin/xreview`.

### Changed
- **Default reviewer is now Codex.** When no reviewer is named, one is chosen by
  priority order — codex → gemini → any other installed agent → developer self-review —
  instead of a random peer.
- **Fixed the Codex sandbox modes.** The reviewer now runs with `workspace-write` (was
  `read-only`, which blocked the verdict and LOCK writes the reviewer must make), and the
  developer runs with `workspace-write` (was the invalid `suggest` value).

### Internal
- Ignore `.deputy/` and `.idea/` tooling directories.

## [0.1.0] - 2026-04-05

### Added
- Initial xReview peer-review workflow between **Claude Code** and **Gemini CLI**: a
  file-based LOCK, a shared `.review/REVIEW.md` log, `/bugfix` `/feature` `/refactor`
  commands, and an installer.
