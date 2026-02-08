# Decisions

## Decisions

### DEC-001: Dual format for macOS defaults
- **Date**: 2026-02-07
- **Context**: Need both human-readable diffs and restorable configuration
- **Decision**: Export every defaults domain as both `.txt` (readable) and `.plist` (restorable via `defaults import`)
- **Alternatives**: Only plist (hard to diff), only text (can't restore)

### DEC-002: Copy dotfiles, not symlink
- **Date**: 2026-02-07
- **Context**: Need to capture point-in-time state without affecting live config
- **Decision**: Copy dotfiles into snapshot; restore creates `.bak` backups before overwriting
- **Alternatives**: Symlink-based (like GNU Stow), git-tracked dotfiles repo
