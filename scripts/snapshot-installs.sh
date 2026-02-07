#!/usr/bin/env bash
# snapshot-installs.sh — Capture all installed software
source "$(dirname "$0")/common.sh"

SNAP_DIR="${1:?Usage: snapshot-installs.sh <snapshot-dir>}"
mkdir -p "$SNAP_DIR"

log_header "Snapshotting installed software"

# ── System info ────────────────────────────────────────────────────────
log_info "System info"
{
    echo "Date: $(date)"
    echo "Hostname: $(scutil --get ComputerName 2>/dev/null || hostname)"
    sw_vers
    echo ""
    echo "Disk usage:"
    df -h / | tail -1
    echo ""
    echo "Uptime: $(uptime)"
} > "$SNAP_DIR/system-info.txt"

# ── Homebrew ───────────────────────────────────────────────────────────
if has_cmd brew; then
    log_info "Homebrew bundle dump"
    brew bundle dump --file="$SNAP_DIR/Brewfile" --force 2>/dev/null

    log_info "Brew formulae list"
    brew list --formula --versions > "$SNAP_DIR/brew-formulae.txt" 2>/dev/null || true

    log_info "Brew cask list"
    brew list --cask --versions > "$SNAP_DIR/brew-casks.txt" 2>/dev/null || true

    log_info "Brew taps"
    brew tap > "$SNAP_DIR/brew-taps.txt" 2>/dev/null || true
else
    log_warn "brew not found — skipping Homebrew snapshot"
fi

# ── Mac App Store ──────────────────────────────────────────────────────
if has_cmd mas; then
    log_info "Mac App Store apps"
    mas list > "$SNAP_DIR/mas-apps.txt" 2>/dev/null || true
else
    log_warn "mas not found — skipping App Store snapshot (brew install mas)"
fi

# ── /Applications ──────────────────────────────────────────────────────
log_info "Applications directory"
ls -1 /Applications > "$SNAP_DIR/applications.txt" 2>/dev/null || true

log_success "Install snapshot saved to $SNAP_DIR"
