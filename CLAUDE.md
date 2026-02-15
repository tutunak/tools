# CLAUDE.md

## Project overview

Collection of personal utility scripts and tools for a WSL2 environment, organized into category subdirectories.

## Structure

- Each top-level directory is a category (e.g. `backup/`)
- Each category contains tool subdirectories (e.g. `backup/restic_bash/`)
- Every tool has its own `README.md` (setup/usage) and `CLAUDE.md` (dev context)

## Conventions

- Target environment: WSL2 (Ubuntu) on Windows
- Scripts are typically installed to `~/.local/bin/`
- Secrets and credentials are never stored in the repository
- Tools should be self-contained with clear setup instructions in their README
