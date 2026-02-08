# Project Context

## Architecture
- Pure-bash CLI tool for macOS configuration tracking
- Entry point: `mac-manage.sh` dispatches to scripts in `scripts/`
- Shared library: `scripts/common.sh` (logging, paths, helpers)
- Snapshots are timestamped directories in `snapshots/` (gitignored)
- Baseline config in `baseline/` (dotfiles.list, defaults-domains.list, apps-manual.list, Brewfile)

## Stack
- **Language**: Bash (no external deps beyond macOS + Homebrew)
- **Automation**: launchd plist for weekly snapshots (Sundays 10am)
- **Storage**: Plain files — `.txt` for human-readable, `.plist` for restorable
- **No build step, linter, or test suite**

## Conventions
- All scripts use `set -euo pipefail` and `#!/usr/bin/env bash`
- Config lists use `#` for comments, skip blank lines
- Dotfiles are copied (not symlinked); restore creates `.bak` backups
- macOS defaults exported in dual format: `.txt` + `.plist`
- Scripts gracefully skip missing tools with `has_cmd` warnings

## Notes
- [2026-02-07] Snapshot path: `snapshots/YYYYMMDD-HHMMSS/`
- [2026-02-07] launchd plist hardcodes path to `/Users/mike/mac-manage/mac-manage.sh`
- [2026-02-07] Weekly snapshots automated via launchd
