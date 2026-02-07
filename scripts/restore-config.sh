#!/usr/bin/env bash
# restore-config.sh — Restore dotfiles and macOS defaults from a snapshot
source "$(dirname "$0")/common.sh"

usage() {
    echo "Usage: restore-config.sh <snapshot-dir> [options]"
    echo ""
    echo "Options:"
    echo "  --dry-run     Show what would be restored without making changes"
    echo "  --dotfiles    Restore only dotfiles"
    echo "  --defaults    Restore only macOS defaults"
    echo ""
    echo "If no --dotfiles/--defaults flag is given, both are restored."
    exit 1
}

SNAP_DIR=""
DRY_RUN=false
DO_DOTFILES=false
DO_DEFAULTS=false

# Parse args
for arg in "$@"; do
    case "$arg" in
        --dry-run)   DRY_RUN=true ;;
        --dotfiles)  DO_DOTFILES=true ;;
        --defaults)  DO_DEFAULTS=true ;;
        --help|-h)   usage ;;
        *)
            if [[ -z "$SNAP_DIR" ]]; then
                SNAP_DIR="$arg"
            else
                log_error "Unknown argument: $arg"
                usage
            fi
            ;;
    esac
done

# If neither flag given, do both
if ! $DO_DOTFILES && ! $DO_DEFAULTS; then
    DO_DOTFILES=true
    DO_DEFAULTS=true
fi

if [[ -z "$SNAP_DIR" ]]; then
    log_error "No snapshot directory specified"
    usage
fi

if [[ ! -d "$SNAP_DIR" ]]; then
    log_error "Snapshot directory not found: $SNAP_DIR"
    exit 1
fi

if $DRY_RUN; then
    log_header "DRY RUN — no changes will be made"
fi

# ── Restore dotfiles ──────────────────────────────────────────────────
if $DO_DOTFILES && [[ -d "$SNAP_DIR/dotfiles" ]]; then
    log_header "Restoring dotfiles"
    for src in "$SNAP_DIR/dotfiles"/*; do
        [[ -f "$src" ]] || continue
        name=$(basename "$src")
        dest="$HOME/$name"

        if $DRY_RUN; then
            if [[ -f "$dest" ]]; then
                log_info "Would backup $dest -> ${dest}.bak"
            fi
            log_info "Would copy $name -> $dest"
        else
            if [[ -f "$dest" ]]; then
                cp "$dest" "${dest}.bak"
                log_info "Backed up $dest -> ${dest}.bak"
            fi
            cp "$src" "$dest"
            log_success "Restored $name"
        fi
    done
elif $DO_DOTFILES; then
    log_warn "No dotfiles directory in snapshot: $SNAP_DIR"
fi

# ── Restore macOS defaults ────────────────────────────────────────────
if $DO_DEFAULTS && [[ -d "$SNAP_DIR/defaults" ]]; then
    log_header "Restoring macOS defaults"
    for plist in "$SNAP_DIR/defaults"/*.plist; do
        [[ -f "$plist" ]] || continue
        domain=$(basename "$plist" .plist)

        if $DRY_RUN; then
            log_info "Would import defaults for domain: $domain"
        else
            defaults import "$domain" "$plist" 2>/dev/null && \
                log_success "Imported $domain" || \
                log_warn "Failed to import $domain"
        fi
    done

    if ! $DRY_RUN; then
        log_info "You may need to restart apps or log out for preference changes to take effect"
    fi
elif $DO_DEFAULTS; then
    log_warn "No defaults directory in snapshot: $SNAP_DIR"
fi

# ── Summary ────────────────────────────────────────────────────────────
if $DRY_RUN; then
    log_header "Dry run complete — no changes were made"
else
    log_header "Restore complete"
fi
