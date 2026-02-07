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

## Claude Code Commands

Five slash commands are installed globally that wrap `mac-manage.sh` with AI interpretation. They are available in any Claude Code session (not just this repo). Use them instead of running the CLI directly when you want analysis, not just raw output.

| Command | What it does |
|---------|-------------|
| `/mac-health` | Runs `health`, then categorizes every finding as Critical / Important / Informational with exact remediation steps. Accepts optional context (e.g., `/mac-health "preparing for travel"`) to adjust priorities. |
| `/mac-diff` | Runs `diff`, then reads the actual snapshot files to categorize changes (software, dotfiles, preferences, security), translate plist keys to plain language, and flag regressions. |
| `/mac-status` | Snapshot lifecycle management. Four modes: no args (list with age/size), `"snapshot"` (take + auto-diff), `"prune"` (suggest deletions), `"weekly"` (full review combining snapshot + diff + health + discovery). |
| `/mac-discover` | Scans the system for dotfiles, defaults domains, and apps that mac-manage doesn't track yet. Rates each as Recommended / Optional / Skip and provides copy-paste lines for baseline files. |
| `/mac-restore` | Always runs `--dry-run` first regardless of args. Validates the snapshot, diffs against current state, flags incompatibilities (stale PATHs, uninstalled app domains, macOS version mismatch), rates risk, and requires explicit confirmation before executing. |

### Recommended Workflows

**Weekly maintenance** — one command does it all:
```
/mac-status "weekly"
```
Takes a snapshot, diffs against previous, runs health checks, and does abbreviated discovery. Produces a consolidated report with action items.

**After installing new software:**
```
/mac-status "snapshot"
/mac-discover "apps"
```
Capture the change, then check if new apps should be added to baseline tracking.

**Before traveling:**
```
/mac-health "preparing for travel"
```
Elevates encryption and firewall checks to Critical priority.

**Restoring after a clean install:**
```
/mac-restore "latest"
```
Walks you through a safe, validated restore with full dry-run preview.

**Expanding what's tracked:**
```
/mac-discover
```
Finds untracked dotfiles, preference domains, and manually installed apps. Add the suggestions to `baseline/` files, then run `/mac-status "snapshot"` to capture them.

### How They Work

All commands call `mac-manage.sh` via Bash — they never reimplement its logic. The AI layer adds:
- **Categorization** — raw PASS/WARN/FAIL becomes prioritized tiers
- **Translation** — plist keys like `autohide = 1` become "Dock auto-hide enabled"
- **Regression detection** — compares `security-status.txt` between snapshots
- **Safety gates** — `/mac-restore` always previews before executing
- **Context awareness** — optional user context shifts priorities (travel → encryption)

The shared knowledge base lives in the `mac-manage-context` skill (installed globally at `~/.claude/skills/mac-manage-context/`). It contains paths, output format references, a macOS defaults domain glossary, and a common dotfile glossary.
