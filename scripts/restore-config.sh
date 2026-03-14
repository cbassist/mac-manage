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
    echo "  --launchd     Restore only launchd plists"
    echo ""
    echo "If no filter flag is given, all categories are restored."
    exit 1
}

SNAP_DIR=""
DRY_RUN=false
DO_DOTFILES=false
DO_DEFAULTS=false
DO_LAUNCHD=false

# Parse args
for arg in "$@"; do
    case "$arg" in
        --dry-run)   DRY_RUN=true ;;
        --dotfiles)  DO_DOTFILES=true ;;
        --defaults)  DO_DEFAULTS=true ;;
        --launchd)   DO_LAUNCHD=true ;;
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

# If no filter flag given, do all
if ! $DO_DOTFILES && ! $DO_DEFAULTS && ! $DO_LAUNCHD; then
    DO_DOTFILES=true
    DO_DEFAULTS=true
    DO_LAUNCHD=true
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
    while IFS= read -r src; do
        [[ -f "$src" ]] || continue
        # Strip the snapshot dotfiles prefix to get the relative path
        name="${src#$SNAP_DIR/dotfiles/}"
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
            mkdir -p "$(dirname "$dest")"
            cp "$src" "$dest"
            log_success "Restored $name"
        fi
    done < <(find "$SNAP_DIR/dotfiles" -type f)
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

# ── Restore launchd plists ───────────────────────────────────────────
if $DO_LAUNCHD && [[ -d "$SNAP_DIR/launchd" ]]; then
    log_header "Restoring launchd plists"
    # Look up original path for a plist basename from baseline list
    # Uses a function instead of associative array for Bash 3.2 compatibility
    _launchd_dest() {
        local target="$1"
        if [[ -f "$BASELINE_DIR/launchd.list" ]]; then
            while IFS= read -r line; do
                [[ "$line" =~ ^[[:space:]]*# ]] && continue
                [[ -z "${line// /}" ]] && continue
                if [[ "$(basename "$line")" == "$target" ]]; then
                    echo "$line"
                    return
                fi
            done < "$BASELINE_DIR/launchd.list"
        fi
    }

    for src in "$SNAP_DIR/launchd"/*.plist; do
        [[ -f "$src" ]] || continue
        name=$(basename "$src")
        dest=$(_launchd_dest "$name")

        if [[ -z "$dest" ]]; then
            log_warn "$name not in launchd.list — skipping (no restore target)"
            continue
        fi

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
            log_success "Restored $name -> $dest"
            log_info "  Run: brew services restart <service> to apply"
        fi
    done
elif $DO_LAUNCHD; then
    log_warn "No launchd directory in snapshot: $SNAP_DIR"
fi

# ── Summary ────────────────────────────────────────────────────────────
if $DRY_RUN; then
    log_header "Dry run complete — no changes were made"
else
    log_header "Restore complete"
fi
