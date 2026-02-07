# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

mac-manage is a pure-bash CLI tool for tracking installed software, dotfiles, and macOS preferences on a Mac. It takes timestamped snapshots, diffs them, and can restore configuration from a snapshot. Everything is plain shell scripts with no external dependencies beyond macOS and Homebrew.

## Commands

```bash
./mac-manage.sh snapshot            # Full snapshot (installs + config)
./mac-manage.sh snapshot-installs   # Snapshot only installed software
./mac-manage.sh snapshot-config     # Snapshot only dotfiles + macOS prefs
./mac-manage.sh health              # Security/disk/backup/update audit
./mac-manage.sh diff [old] [new]    # Compare two snapshots (auto-selects latest two)
./mac-manage.sh restore <dir> [--dry-run] [--dotfiles] [--defaults]
./mac-manage.sh list                # List snapshots with file counts
```

There is no build step, linter, or test suite. Scripts are run directly.

## Architecture

**Entry point:** `mac-manage.sh` — CLI dispatcher that parses the subcommand and delegates to scripts in `scripts/`.

**Shared library:** `scripts/common.sh` — sourced by all scripts. Provides:
- Path constants: `PROJECT_ROOT`, `SCRIPTS_DIR`, `BASELINE_DIR`, `SNAPSHOTS_DIR`
- Logging functions: `log_info`, `log_warn`, `log_error`, `log_success`, `log_header`
- Health-check status: `pass`, `warn`, `fail`
- Helpers: `timestamp`, `new_snapshot_dir`, `latest_snapshots`, `diff_files`, `has_cmd`, `require_cmd`

**Scripts** (each sources `common.sh` and takes a snapshot directory as `$1`):
- `snapshot-installs.sh` — captures system info, Brewfile, brew lists, mas apps, /Applications
- `snapshot-config.sh` — copies dotfiles from `$HOME` and exports macOS `defaults` as both `.txt` (readable) and `.plist` (restorable)
- `health-check.sh` — checks FileVault, Firewall, SIP, Gatekeeper, Time Machine, disk usage, macOS updates, Homebrew status
- `diff-snapshots.sh` — unified diff across all snapshot categories between two snapshots
- `restore-config.sh` — restores dotfiles (with `.bak` backup) and imports `.plist` defaults; supports `--dry-run`

**Baseline configuration** (`baseline/`):
- `dotfiles.list` — which dotfiles to track (paths relative to `$HOME`, one per line)
- `defaults-domains.list` — which macOS preference domains to track (one per line)
- `apps-manual.list` — manually installed apps not from brew/mas (documentation only)
- `Brewfile` — Homebrew bundle dump for recreating installs

**Snapshots** (`snapshots/`) are timestamped directories (e.g., `20260207-040808/`) and are git-ignored. They contain the captured state at a point in time.

**Automation:** `launchd/com.mike.mac-manage.snapshot.plist` runs weekly snapshots (Sundays 10am). The path is hardcoded to `/Users/mike/mac-manage/mac-manage.sh`.

## Conventions

- All scripts use `set -euo pipefail` and `#!/usr/bin/env bash`
- Configuration lists use `#` for comments and skip blank lines
- Dotfiles are copied (not symlinked); restore creates `.bak` backups before overwriting
- macOS defaults are exported in dual format: `.txt` for human-readable diffs, `.plist` for `defaults import` restore
- Scripts gracefully skip missing tools (e.g., `brew`, `mas`) with warnings via `has_cmd`
