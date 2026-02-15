#!/usr/bin/env bash
#
# restic-backup.sh -- Automatic background restic backup for WSL2
#
# Usage:
#   restic-backup.sh              # Background mode (cooldown + lock + silent)
#   restic-backup.sh --now        # Foreground mode, skip cooldown, show output
#   restic-backup.sh --status     # Show last backup time and tail log
#
set -euo pipefail

# --- Configuration -----------------------------------------------------------

CREDENTIALS_ENV="$HOME/.secret/restic/env"
RUNTIME_DIR="$HOME/.local/share/restic"
LOG_FILE="$RUNTIME_DIR/backup.log"
LOCK_FILE="$RUNTIME_DIR/backup.lock"
TIMESTAMP_FILE="$RUNTIME_DIR/last-backup-timestamp"
COOLDOWN_SECONDS=3600  # 1 hour

# --- Helpers ------------------------------------------------------------------

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

die() {
    log "FATAL: $*"
    exit 1
}

# --- Subcommands --------------------------------------------------------------

cmd_status() {
    echo "=== Restic Backup Status ==="
    if [[ -f "$TIMESTAMP_FILE" ]]; then
        local last_ts
        last_ts=$(cat "$TIMESTAMP_FILE")
        local last_date
        last_date=$(date -d "@$last_ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")
        local now
        now=$(date +%s)
        local age=$(( now - last_ts ))
        local age_min=$(( age / 60 ))
        echo "Last successful backup: $last_date ($age_min minutes ago)"
    else
        echo "Last successful backup: never (no timestamp file)"
    fi
    echo ""
    echo "=== Recent Log (last 30 lines) ==="
    if [[ -f "$LOG_FILE" ]]; then
        tail -30 "$LOG_FILE"
    else
        echo "(no log file yet)"
    fi
}

run_backup() {
    local foreground="${1:-false}"

    # Ensure runtime directory exists
    mkdir -p "$RUNTIME_DIR"

    # Load credentials
    if [[ ! -f "$CREDENTIALS_ENV" ]]; then
        die "Credentials file not found: $CREDENTIALS_ENV"
    fi
    # shellcheck disable=SC1090
    source "$CREDENTIALS_ENV"

    # Check that the backup target is accessible (WSL drive might not be mounted)
    if [[ ! -d "$RESTIC_REPOSITORY" ]]; then
        log "SKIP: Repository not accessible (drive not mounted?): $RESTIC_REPOSITORY"
        exit 0
    fi

    # Verify restic is installed
    if ! command -v restic &>/dev/null; then
        die "restic not found in PATH"
    fi

    # Acquire exclusive lock (non-blocking)
    exec 200>"$LOCK_FILE"
    if ! flock -n 200; then
        log "SKIP: Another backup is already running"
        exit 0
    fi

    # Cooldown check (skip in foreground/--now mode)
    if [[ "$foreground" != "true" && -f "$TIMESTAMP_FILE" ]]; then
        local last_ts
        last_ts=$(cat "$TIMESTAMP_FILE")
        local now
        now=$(date +%s)
        local elapsed=$(( now - last_ts ))
        if (( elapsed < COOLDOWN_SECONDS )); then
            log "SKIP: Cooldown active (${elapsed}s < ${COOLDOWN_SECONDS}s since last backup)"
            exit 0
        fi
    fi

    log "START: Backup of $HOME"

    local rc=0
    if [[ "$foreground" == "true" ]]; then
        restic backup "$HOME" \
            --exclude="$HOME/.cache" \
            --exclude="$HOME/.vscode-server" \
            --exclude="$HOME/.nvm" \
            --exclude="$HOME/.local/share/claude" \
            --exclude="$HOME/.local/share/mise" \
            --exclude="$HOME/.local/share/containers" \
            --exclude="$HOME/go" \
            --exclude='**/node_modules' \
            --exclude='**/__pycache__' \
            --exclude='**/.pytest_cache' \
            --exclude='**/.mypy_cache' \
            --exclude='**/.tox' \
            --exclude='**/.venv' \
            --exclude='**/venv' \
            --exclude='**/.terraform' \
            --exclude='*.tmp' \
            --exclude='*.swp' \
            --exclude='*~' \
            --tag wsl2-auto \
            --one-file-system \
            --retry-lock 2m \
            --pack-size 64 \
            2>&1 | tee -a "$LOG_FILE" || rc=$?
    else
        restic backup "$HOME" \
            --exclude="$HOME/.cache" \
            --exclude="$HOME/.vscode-server" \
            --exclude="$HOME/.nvm" \
            --exclude="$HOME/.local/share/claude" \
            --exclude="$HOME/.local/share/mise" \
            --exclude="$HOME/.local/share/containers" \
            --exclude="$HOME/go" \
            --exclude='**/node_modules' \
            --exclude='**/__pycache__' \
            --exclude='**/.pytest_cache' \
            --exclude='**/.mypy_cache' \
            --exclude='**/.tox' \
            --exclude='**/.venv' \
            --exclude='**/venv' \
            --exclude='**/.terraform' \
            --exclude='*.tmp' \
            --exclude='*.swp' \
            --exclude='*~' \
            --tag wsl2-auto \
            --one-file-system \
            --retry-lock 2m \
            --pack-size 64 \
            >> "$LOG_FILE" 2>&1 || rc=$?
    fi

    if [[ $rc -eq 0 ]]; then
        log "SUCCESS: Backup completed"
        date +%s > "$TIMESTAMP_FILE"
    else
        log "ERROR: Backup exited with code $rc"
    fi

    # Periodic maintenance: prune old logs (keep last 1000 lines)
    if [[ -f "$LOG_FILE" ]]; then
        local line_count
        line_count=$(wc -l < "$LOG_FILE")
        if (( line_count > 2000 )); then
            tail -1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
            log "LOG: Truncated log to 1000 lines"
        fi
    fi

    return $rc
}

# --- Main ---------------------------------------------------------------------

case "${1:-}" in
    --status)
        cmd_status
        ;;
    --now)
        run_backup true
        ;;
    *)
        run_backup false
        ;;
esac
