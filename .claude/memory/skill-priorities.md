# Skill Priorities

## Always (invoke proactively every session)
- `/catchup` - Resume session with briefing (run first thing)
- `/mac-status` - Quick snapshot overview and age check

## Context-Triggered (invoke when topic matches)
- `/mac-health` - When checking system security or preparing for travel/audit
- `/mac-diff` - When comparing snapshots or investigating changes
- `/mac-discover` - When expanding tracked configuration coverage
- `/mac-restore` - When restoring from a snapshot (always dry-run first)
- `/code-review` - Before committing script changes

## Available (use when explicitly relevant)
- `/remember "fact"` - When discovering reusable knowledge (paths, conventions)
- `/memory` - When checking stored context or searching past decisions
- `/rca "error"` - When diagnosing script failures
- `/quick-prime` - When needing fast project overview

## Repo Context
- **Primary domain**: macOS configuration tracking, bash CLI tool
- **Key commands prefix**: `/mac-*`
- **Context skill**: `mac-manage-context` (global, paths + glossary + output formats)
