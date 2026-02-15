# CLAUDE.md

## Project overview

WSL restic backup script. Automatically backs up `$HOME` to a local restic repository via a background process triggered on zsh startup.

## Key files

- `restic-backup.sh` -- The backup script. Installed to `~/.local/bin/restic-backup.sh`.
- `README.md` -- Setup and usage instructions.

## Architecture

Single bash script with three modes:
- Default (no args): background mode with 1-hour cooldown and flock locking
- `--now`: foreground mode, skips cooldown, streams output
- `--status`: displays last backup time and log tail

Credentials are sourced from `~/.secret/restic/env`. The script checks for repository availability before running and exits cleanly if the target drive is not mounted.

## Conventions

- Restic pack size: 64 MiB (`--pack-size 64`)
- Snapshots tagged `wsl2-auto` to distinguish from Backrest GUI snapshots
- `--one-file-system` prevents traversing into Windows mounts
- Log file self-rotates at 2000 lines (keeps last 1000)
- No credentials are stored in this repository
