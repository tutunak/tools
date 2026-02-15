# WSL Restic Backup

Automatic background backup of the WSL home directory to a local restic repository on an external drive.

## How it works

- Every new zsh session triggers a background backup (via `.zshrc`)
- A 1-hour cooldown prevents redundant runs
- Backups target `/mnt/e/backups/backrest/` (restic repo)
- Pack size is set to 64 MiB
- Snapshots are tagged `wsl2-auto`

## Installation

### Prerequisites

```bash
brew install restic
```

### Setup credentials

```bash
mkdir -p ~/.secret/restic && chmod 700 ~/.secret ~/.secret/restic

# Write your restic repo password
echo 'YOUR_PASSWORD' > ~/.secret/restic/password
chmod 600 ~/.secret/restic/password

# Create env file
cat > ~/.secret/restic/env << 'EOF'
export RESTIC_REPOSITORY="/mnt/e/backups/backrest"
export RESTIC_PASSWORD_FILE="/home/dk/.secret/restic/password"
EOF
chmod 600 ~/.secret/restic/env
```

### Install the script

```bash
cp restic-backup.sh ~/.local/bin/restic-backup.sh
chmod +x ~/.local/bin/restic-backup.sh
mkdir -p ~/.local/share/restic
```

### Add to .zshrc

```bash
# --- Automatic restic backup (background, non-blocking) ---
if [[ -x "$HOME/.local/bin/restic-backup.sh" ]]; then
    ( "$HOME/.local/bin/restic-backup.sh" &>/dev/null & )
fi
alias backup='restic-backup.sh --now'
alias backup-status='restic-backup.sh --status'
```

## Usage

| Command | Description |
|---------|-------------|
| `backup` | Run backup immediately (foreground, skips cooldown) |
| `backup-status` | Show last backup time and recent log |
| Open a new terminal | Triggers background backup automatically |

## Excluded directories

Large or regenerable paths are excluded to save space:

- `.cache`, `.vscode-server`, `.nvm`, `go/` -- reinstallable
- `.local/share/claude`, `.local/share/mise`, `.local/share/containers` -- reinstallable
- `node_modules`, `__pycache__`, `.pytest_cache`, `.mypy_cache`, `.tox` -- build artifacts
- `.venv`, `venv`, `.terraform` -- recreatable environments
- `*.tmp`, `*.swp`, `*~` -- editor temp files

## File layout

```
~/.local/bin/restic-backup.sh       # Main script
~/.secret/restic/password            # Repo password
~/.secret/restic/env                 # Environment variables
~/.local/share/restic/backup.log     # Log file (self-rotating)
~/.local/share/restic/backup.lock    # flock lock file
~/.local/share/restic/last-backup-timestamp  # Cooldown tracker
```
