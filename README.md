# SURF

Fedora system update script. It:

1. Refreshes dnf metadata and upgrades packages when updates are available.
2. Removes unneeded packages left behind by the upgrade.
3. Updates per-user Flatpaks (run as your user account when invoked via sudo).
4. Checks whether a reboot or service restarts are needed, and offers to reboot if required.

## Usage

```bash
chmod +x surf.sh
sudo ./surf.sh
```

## Options

- `-y, --yes`: answer yes to dnf and Flatpak prompts, for unattended runs.
- `--no-reboot-prompt`: skip the reboot question when a reboot is required.

## Requirements

- Fedora (or another dnf-based distribution)
- Bash (the script's shebang handles this — your interactive shell can be anything, including fish)
- Root, via sudo
- Flatpak (optional — skipped if not installed)

## Notes

- By default the script is interactive: `dnf upgrade` and `flatpak update` prompt before proceeding, and you are asked before any reboot.
- Autoremove runs only after a successful upgrade, and follows `--yes` like the other steps.
- When run with sudo, the Flatpak step runs as your user account and covers per-user Flatpaks only; system-wide Flatpaks are not updated by the script.
- If a Flatpak update fails, the script warns and exits non-zero at the end, so automation can detect the partial failure.
