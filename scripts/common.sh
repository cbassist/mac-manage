#!/usr/bin/env bash
# common.sh — Shared helpers for mac-manage

set -euo pipefail

# ── Paths ──────────────────────────────────────────────────────────────
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$PROJECT_ROOT/scripts"
BASELINE_DIR="$PROJECT_ROOT/baseline"
SNAPSHOTS_DIR="$PROJECT_ROOT/snapshots"

# ── Colors ─────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' RESET=''
fi

# ── Logging ────────────────────────────────────────────────────────────
log_info()    { echo -e "${BLUE}[INFO]${RESET}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}    $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET}   $*"; }
log_success() { echo -e "${GREEN}[OK]${RESET}      $*"; }
log_header()  { echo -e "\n${BOLD}=== $* ===${RESET}"; }

# ── Status helpers (for health checks) ─────────────────────────────────
pass() { echo -e "  ${GREEN}PASS${RESET}  $*"; }
warn() { echo -e "  ${YELLOW}WARN${RESET}  $*"; }
fail() { echo -e "  ${RED}FAIL${RESET}  $*"; }

# ── Timestamps ─────────────────────────────────────────────────────────
timestamp() { date "+%Y%m%d-%H%M%S"; }

# ── Snapshot directory helper ──────────────────────────────────────────
new_snapshot_dir() {
    local dir="$SNAPSHOTS_DIR/$(timestamp)"
    mkdir -p "$dir"
    echo "$dir"
}

# ── Get latest N snapshots (sorted newest first) ──────────────────────
latest_snapshots() {
    local count="${1:-2}"
    # shellcheck disable=SC2012
    ls -1d "$SNAPSHOTS_DIR"/[0-9]* 2>/dev/null | sort -r | head -n "$count"
}

# ── Diff two files with context ────────────────────────────────────────
diff_files() {
    local label="$1" file_a="$2" file_b="$3"
    if [[ ! -f "$file_a" ]] || [[ ! -f "$file_b" ]]; then
        log_warn "$label: one or both files missing, skipping"
        return 0
    fi
    local result
    result=$(diff --unified=1 "$file_a" "$file_b" 2>/dev/null || true)
    if [[ -n "$result" ]]; then
        echo -e "\n${BOLD}--- $label ---${RESET}"
        echo "$result"
        return 1  # indicates changes found
    fi
    return 0  # no changes
}

# ── Check if a command exists ──────────────────────────────────────────
has_cmd() { command -v "$1" &>/dev/null; }

# ── Require a command or warn ──────────────────────────────────────────
require_cmd() {
    if ! has_cmd "$1"; then
        log_warn "$1 not found — some features will be skipped"
        return 1
    fi
}
