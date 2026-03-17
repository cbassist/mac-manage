#!/usr/bin/env bash
# docker-maintenance.sh — Monitor Docker disk usage and auto-prune when over threshold
source "$(dirname "$0")/common.sh"

# ── Configuration ─────────────────────────────────────────────────────
THRESHOLD_GB=40
DOCKER_DATA="$HOME/Library/Containers/com.docker.docker/Data"
DOCKER_RAW="$DOCKER_DATA/vms/0/data/Docker.raw"
LOG_FILE="$PROJECT_ROOT/logs/docker-maintenance.log"

# ── Ensure log directory exists ───────────────────────────────────────
mkdir -p "$(dirname "$LOG_FILE")"

# ── Logging (to file and stdout) ─────────────────────────────────────
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg"
}

# ── Preflight checks ─────────────────────────────────────────────────
if ! has_cmd docker; then
    log "SKIP: docker not installed"
    exit 0
fi

if ! docker info &>/dev/null; then
    log "SKIP: Docker daemon not running"
    exit 0
fi

# ── Measure current usage ────────────────────────────────────────────
# du outputs KB by default; convert to GB
if [[ -f "$DOCKER_RAW" ]]; then
    usage_kb=$(du -sk "$DOCKER_RAW" 2>/dev/null | cut -f1)
    usage_gb=$((usage_kb / 1048576))
else
    # Fallback: measure the whole Docker data directory
    usage_kb=$(du -sk "$DOCKER_DATA" 2>/dev/null | cut -f1)
    usage_gb=$((usage_kb / 1048576))
fi

log "Docker disk usage: ${usage_gb}GB (threshold: ${THRESHOLD_GB}GB)"

if [[ "$usage_gb" -lt "$THRESHOLD_GB" ]]; then
    log "OK: Under threshold, no action needed"
    exit 0
fi

log "OVER THRESHOLD: Starting graduated cleanup"

# ── Stage 1: Dangling images (untagged, no container reference) ──────
log "Stage 1: Removing dangling images..."
stage1=$(docker image prune --force 2>&1)
reclaimed=$(echo "$stage1" | grep "Total reclaimed space" || echo "0B")
log "Stage 1 result: $reclaimed"

# ── Re-check ─────────────────────────────────────────────────────────
usage_kb=$(du -sk "$DOCKER_RAW" 2>/dev/null | cut -f1)
usage_gb=$((usage_kb / 1048576))
if [[ "$usage_gb" -lt "$THRESHOLD_GB" ]]; then
    log "Under threshold after Stage 1 (${usage_gb}GB). Done."
    exit 0
fi

# ── Stage 2: Unused images (not referenced by any container) ─────────
log "Stage 2: Removing unused images..."
stage2=$(docker image prune --all --force 2>&1)
reclaimed=$(echo "$stage2" | grep "Total reclaimed space" || echo "0B")
log "Stage 2 result: $reclaimed"

# ── Re-check ─────────────────────────────────────────────────────────
usage_kb=$(du -sk "$DOCKER_RAW" 2>/dev/null | cut -f1)
usage_gb=$((usage_kb / 1048576))
if [[ "$usage_gb" -lt "$THRESHOLD_GB" ]]; then
    log "Under threshold after Stage 2 (${usage_gb}GB). Done."
    exit 0
fi

# ── Stage 3: Build cache ─────────────────────────────────────────────
log "Stage 3: Clearing build cache..."
stage3=$(docker builder prune --all --force 2>&1)
reclaimed=$(echo "$stage3" | grep "Total reclaimed space" || echo "0B")
log "Stage 3 result: $reclaimed"

# ── Re-check ─────────────────────────────────────────────────────────
usage_kb=$(du -sk "$DOCKER_RAW" 2>/dev/null | cut -f1)
usage_gb=$((usage_kb / 1048576))
if [[ "$usage_gb" -lt "$THRESHOLD_GB" ]]; then
    log "Under threshold after Stage 3 (${usage_gb}GB). Done."
    exit 0
fi

# ── Stage 4: Stopped containers ──────────────────────────────────────
log "Stage 4: Removing stopped containers..."
stage4=$(docker container prune --force 2>&1)
reclaimed=$(echo "$stage4" | grep "Total reclaimed space" || echo "0B")
log "Stage 4 result: $reclaimed"

# ── Final status ─────────────────────────────────────────────────────
usage_kb=$(du -sk "$DOCKER_RAW" 2>/dev/null | cut -f1)
usage_gb=$((usage_kb / 1048576))
if [[ "$usage_gb" -ge "$THRESHOLD_GB" ]]; then
    log "WARNING: Still at ${usage_gb}GB after all stages. Manual cleanup may be needed."
    log "Run: docker system df -v   (to see what's consuming space)"
else
    log "Under threshold after cleanup (${usage_gb}GB). Done."
fi
