#!/usr/bin/env bash
# snapshot-config.sh — Capture dotfiles and macOS preferences
source "$(dirname "$0")/common.sh"

SNAP_DIR="${1:?Usage: snapshot-config.sh <snapshot-dir>}"
mkdir -p "$SNAP_DIR/dotfiles" "$SNAP_DIR/defaults"

log_header "Snapshotting configuration"

# ── Dotfiles ───────────────────────────────────────────────────────────
log_info "Copying dotfiles"
while IFS= read -r line; do
    # Skip comments and blank lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue

    src="$HOME/$line"
    if [[ -f "$src" ]]; then
        cp "$src" "$SNAP_DIR/dotfiles/$line"
        log_info "  copied $line"
    else
        log_warn "  $line not found, skipping"
    fi
done < "$BASELINE_DIR/dotfiles.list"

# ── macOS Defaults (text + binary plist) ───────────────────────────────
log_info "Exporting macOS defaults"
while IFS= read -r domain; do
    [[ "$domain" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${domain// /}" ]] && continue

    # Text export (for human-readable diffs)
    defaults read "$domain" > "$SNAP_DIR/defaults/${domain}.txt" 2>/dev/null || {
        log_warn "  $domain: no preferences found"
        continue
    }

    # Binary plist export (for restore via defaults import)
    defaults export "$domain" "$SNAP_DIR/defaults/${domain}.plist" 2>/dev/null || true

    log_info "  exported $domain"
done < "$BASELINE_DIR/defaults-domains.list"

# ── Security settings snapshot ─────────────────────────────────────────
log_info "Security settings"
{
    echo "=== FileVault ==="
    fdesetup status 2>/dev/null || echo "Unable to check"
    echo ""
    echo "=== Firewall ==="
    /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "Unable to check"
    echo ""
    echo "=== SIP ==="
    csrutil status 2>/dev/null || echo "Unable to check"
    echo ""
    echo "=== Gatekeeper ==="
    spctl --status 2>/dev/null || echo "Unable to check"
} > "$SNAP_DIR/security-status.txt"

log_success "Config snapshot saved to $SNAP_DIR"
