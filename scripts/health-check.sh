#!/usr/bin/env bash
# health-check.sh — Audit security, disk, backups, and updates
source "$(dirname "$0")/common.sh"

ISSUES=0

log_header "Security"

# ── FileVault ──────────────────────────────────────────────────────────
fv_status=$(fdesetup status 2>/dev/null || echo "Unknown")
if echo "$fv_status" | grep -qi "on"; then
    pass "FileVault is ON (disk encryption enabled)"
else
    fail "FileVault is OFF — enable in System Settings > Privacy & Security > FileVault"
    ((ISSUES++))
fi

# ── Firewall ───────────────────────────────────────────────────────────
fw_status=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "Unknown")
if echo "$fw_status" | grep -qi "enabled"; then
    pass "Firewall is ON"
else
    fail "Firewall is OFF — enable in System Settings > Network > Firewall"
    ((ISSUES++))
fi

# ── SIP (System Integrity Protection) ─────────────────────────────────
sip_status=$(csrutil status 2>/dev/null || echo "Unknown")
if echo "$sip_status" | grep -qi "enabled"; then
    pass "SIP is enabled"
else
    fail "SIP is disabled — this should almost always be enabled"
    ((ISSUES++))
fi

# ── Gatekeeper ─────────────────────────────────────────────────────────
gk_status=$(spctl --status 2>/dev/null || echo "Unknown")
if echo "$gk_status" | grep -qi "enabled\|assessments enabled"; then
    pass "Gatekeeper is enabled"
else
    warn "Gatekeeper status: $gk_status"
    ((ISSUES++))
fi

log_header "Backups"

# ── Time Machine ───────────────────────────────────────────────────────
tm_dest=$(tmutil destinationinfo 2>/dev/null || echo "")
if echo "$tm_dest" | grep -qi "no destinations"; then
    fail "No Time Machine backup configured"
    echo "       Plug in an external drive or set up a network backup"
    echo "       System Settings > General > Time Machine > Add Backup Disk"
    ((ISSUES++))
elif [[ -z "$tm_dest" ]]; then
    warn "Could not determine Time Machine status"
    ((ISSUES++))
else
    pass "Time Machine backup configured"
    # Check last backup time
    last_backup=$(tmutil latestbackup 2>/dev/null || echo "")
    if [[ -n "$last_backup" ]]; then
        echo "       Last backup: $last_backup"
    fi
fi

log_header "Disk"

# ── Disk Usage ─────────────────────────────────────────────────────────
disk_pct=$(df -h / | tail -1 | awk '{gsub(/%/,""); print $5}')
if (( disk_pct < 80 )); then
    pass "Disk usage: ${disk_pct}%"
elif (( disk_pct < 90 )); then
    warn "Disk usage: ${disk_pct}% — consider cleaning up"
    ((ISSUES++))
else
    fail "Disk usage: ${disk_pct}% — critically low on space"
    ((ISSUES++))
fi

# ── Docker Disk Usage ─────────────────────────────────────────────────
if has_cmd docker && docker info &>/dev/null; then
    docker_raw="$HOME/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw"
    if [[ -f "$docker_raw" ]]; then
        docker_kb=$(du -sk "$docker_raw" 2>/dev/null | cut -f1)
        docker_gb=$((docker_kb / 1048576))
        if (( docker_gb < 40 )); then
            pass "Docker disk: ${docker_gb}GB"
        elif (( docker_gb < 60 )); then
            warn "Docker disk: ${docker_gb}GB — approaching threshold (40GB)"
            ((ISSUES++))
        else
            fail "Docker disk: ${docker_gb}GB — run: docker system prune -a"
            ((ISSUES++))
        fi
    fi
fi

log_header "Updates"

# ── macOS updates ──────────────────────────────────────────────────────
log_info "Checking for macOS updates (this may take a moment)..."
update_count=$(softwareupdate -l 2>&1 | grep -c "^\*" || true)
if (( update_count > 0 )); then
    warn "$update_count macOS update(s) available — run: softwareupdate -ia"
    ((ISSUES++))
else
    pass "macOS is up to date"
fi

# ── Homebrew ───────────────────────────────────────────────────────────
if has_cmd brew; then
    log_info "Checking Homebrew..."
    outdated=$(brew outdated 2>/dev/null | wc -l | tr -d ' ')
    if (( outdated > 0 )); then
        warn "$outdated Homebrew package(s) outdated — run: brew upgrade"
        ((ISSUES++))
    else
        pass "All Homebrew packages up to date"
    fi

    doctor_output=$(brew doctor 2>&1 || true)
    if echo "$doctor_output" | grep -qi "ready to brew"; then
        pass "brew doctor: ready to brew"
    else
        warn "brew doctor reported issues — run: brew doctor"
        ((ISSUES++))
    fi
fi

# ── Summary ────────────────────────────────────────────────────────────
log_header "Summary"
if (( ISSUES == 0 )); then
    log_success "All checks passed!"
else
    log_warn "$ISSUES issue(s) found — review the items above"
fi

exit 0
