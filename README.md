# SURF

Fedora system update script. It:

1. Refreshes dnf metadata and upgrades packages when updates are available.
2. Updates Flatpaks (per-user Flatpaks included when run via sudo).
3. Checks whether a reboot or service restarts are needed, and offers to reboot if required.

## Usage

```bash
chmod +x surf.sh
sudo ./surf.sh
```

## Requirements

- Fedora (or another dnf-based distribution)
- Bash (the script's shebang handles this — your interactive shell can be anything, including fish)
- Root, via sudo
- Flatpak (optional — skipped if not installed)

## Notes

- The script is interactive: `dnf upgrade` and `flatpak update` prompt before proceeding, and you are asked before any reboot.
- When run with sudo, Flatpak updates run as your user account so per-user Flatpaks are covered; system Flatpaks are covered either way.
