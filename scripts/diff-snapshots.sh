#!/usr/bin/env bash
# diff-snapshots.sh — Compare two snapshots to show what changed
source "$(dirname "$0")/common.sh"

SNAP_A="${1:-}"
SNAP_B="${2:-}"

# Auto-select latest two snapshots if no args given
if [[ -z "$SNAP_A" ]]; then
    mapfile -t recent < <(latest_snapshots 2)
    if (( ${#recent[@]} < 2 )); then
        log_error "Need at least 2 snapshots to diff. Found ${#recent[@]}."
        log_info "Run 'mac-manage.sh snapshot' to create one."
        exit 1
    fi
    SNAP_B="${recent[0]}"  # newest
    SNAP_A="${recent[1]}"  # second newest
fi

# Validate
for d in "$SNAP_A" "$SNAP_B"; do
    if [[ ! -d "$d" ]]; then
        log_error "Snapshot directory not found: $d"
        exit 1
    fi
done

CHANGES=0
NAME_A=$(basename "$SNAP_A")
NAME_B=$(basename "$SNAP_B")

log_header "Comparing snapshots"
echo "  Old: $NAME_A"
echo "  New: $NAME_B"

# ── Brew formulae ──────────────────────────────────────────────────────
if diff_files "Brew Formulae" "$SNAP_A/brew-formulae.txt" "$SNAP_B/brew-formulae.txt"; then
    : # no changes
else
    ((CHANGES++))
    # Show added/removed summary
    added=$(comm -13 <(sort "$SNAP_A/brew-formulae.txt" 2>/dev/null) <(sort "$SNAP_B/brew-formulae.txt" 2>/dev/null) | wc -l | tr -d ' ')
    removed=$(comm -23 <(sort "$SNAP_A/brew-formulae.txt" 2>/dev/null) <(sort "$SNAP_B/brew-formulae.txt" 2>/dev/null) | wc -l | tr -d ' ')
    [[ "$added" -gt 0 ]] && log_info "  $added formula(e) added"
    [[ "$removed" -gt 0 ]] && log_info "  $removed formula(e) removed"
fi

# ── Brew casks ─────────────────────────────────────────────────────────
if diff_files "Brew Casks" "$SNAP_A/brew-casks.txt" "$SNAP_B/brew-casks.txt"; then
    :
else
    ((CHANGES++))
fi

# ── Mac App Store ──────────────────────────────────────────────────────
if diff_files "Mac App Store" "$SNAP_A/mas-apps.txt" "$SNAP_B/mas-apps.txt"; then
    :
else
    ((CHANGES++))
fi

# ── Applications ───────────────────────────────────────────────────────
if diff_files "Applications" "$SNAP_A/applications.txt" "$SNAP_B/applications.txt"; then
    :
else
    ((CHANGES++))
fi

# ── Dotfiles ───────────────────────────────────────────────────────────
if [[ -d "$SNAP_A/dotfiles" ]] && [[ -d "$SNAP_B/dotfiles" ]]; then
    for f in "$SNAP_B/dotfiles"/*; do
        name=$(basename "$f")
        if diff_files "Dotfile: $name" "$SNAP_A/dotfiles/$name" "$f"; then
            :
        else
            ((CHANGES++))
        fi
    done
fi

# ── macOS Defaults (text versions) ────────────────────────────────────
if [[ -d "$SNAP_A/defaults" ]] && [[ -d "$SNAP_B/defaults" ]]; then
    for f in "$SNAP_B/defaults"/*.txt; do
        [[ -f "$f" ]] || continue
        name=$(basename "$f")
        if diff_files "Defaults: ${name%.txt}" "$SNAP_A/defaults/$name" "$f"; then
            :
        else
            ((CHANGES++))
        fi
    done
fi

# ── Summary ────────────────────────────────────────────────────────────
log_header "Summary"
if (( CHANGES == 0 )); then
    log_success "No differences found between $NAME_A and $NAME_B"
else
    log_info "$CHANGES category(ies) with changes between $NAME_A and $NAME_B"
fi
