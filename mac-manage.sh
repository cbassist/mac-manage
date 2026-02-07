#!/usr/bin/env bash
# mac-manage.sh — Mac Device Management CLI
# Usage: ./mac-manage.sh <command> [args]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

show_help() {
    cat <<'HELP'
mac-manage — Mac Device Management System

Usage: ./mac-manage.sh <command> [args]

Commands:
  snapshot              Take a full snapshot (installs + config)
  snapshot-installs     Snapshot only installed software
  snapshot-config       Snapshot only dotfiles and macOS preferences
  health                Run security, disk, and backup health checks
  diff [old] [new]      Compare two snapshots (defaults to latest two)
  restore <dir> [opts]  Restore dotfiles/defaults from a snapshot
                          --dry-run     Preview changes without applying
                          --dotfiles    Restore only dotfiles
                          --defaults    Restore only macOS preferences
  list                  List all snapshots
  help                  Show this help message

Examples:
  ./mac-manage.sh snapshot
  ./mac-manage.sh health
  ./mac-manage.sh diff
  ./mac-manage.sh restore snapshots/20250101-120000 --dry-run
  ./mac-manage.sh list
HELP
}

cmd_snapshot() {
    local snap_dir
    snap_dir=$(new_snapshot_dir)
    log_header "Full Snapshot → $(basename "$snap_dir")"
    bash "$SCRIPTS_DIR/snapshot-installs.sh" "$snap_dir"
    bash "$SCRIPTS_DIR/snapshot-config.sh" "$snap_dir"
    log_header "Snapshot complete"
    log_success "Saved to: $snap_dir"
    # Count files
    local count
    count=$(find "$snap_dir" -type f | wc -l | tr -d ' ')
    log_info "$count files captured"
}

cmd_snapshot_installs() {
    local snap_dir
    snap_dir=$(new_snapshot_dir)
    log_header "Install Snapshot → $(basename "$snap_dir")"
    bash "$SCRIPTS_DIR/snapshot-installs.sh" "$snap_dir"
}

cmd_snapshot_config() {
    local snap_dir
    snap_dir=$(new_snapshot_dir)
    log_header "Config Snapshot → $(basename "$snap_dir")"
    bash "$SCRIPTS_DIR/snapshot-config.sh" "$snap_dir"
}

cmd_health() {
    bash "$SCRIPTS_DIR/health-check.sh"
}

cmd_diff() {
    bash "$SCRIPTS_DIR/diff-snapshots.sh" "$@"
}

cmd_restore() {
    if [[ $# -eq 0 ]]; then
        log_error "Usage: mac-manage.sh restore <snapshot-dir> [--dry-run] [--dotfiles] [--defaults]"
        exit 1
    fi
    bash "$SCRIPTS_DIR/restore-config.sh" "$@"
}

cmd_list() {
    log_header "Snapshots"
    local count=0
    for dir in "$SNAPSHOTS_DIR"/[0-9]*; do
        [[ -d "$dir" ]] || continue
        local name files
        name=$(basename "$dir")
        files=$(find "$dir" -type f | wc -l | tr -d ' ')
        echo "  $name  ($files files)"
        ((count++))
    done
    if (( count == 0 )); then
        log_info "No snapshots yet. Run: ./mac-manage.sh snapshot"
    else
        log_info "$count snapshot(s) found"
    fi
}

# ── Main dispatch ──────────────────────────────────────────────────────
COMMAND="${1:-help}"
shift 2>/dev/null || true

case "$COMMAND" in
    snapshot)          cmd_snapshot ;;
    snapshot-installs) cmd_snapshot_installs ;;
    snapshot-config)   cmd_snapshot_config ;;
    health)            cmd_health ;;
    diff)              cmd_diff "$@" ;;
    restore)           cmd_restore "$@" ;;
    list)              cmd_list ;;
    help|--help|-h)    show_help ;;
    *)
        log_error "Unknown command: $COMMAND"
        echo ""
        show_help
        exit 1
        ;;
esac
