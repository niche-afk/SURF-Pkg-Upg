#!/usr/bin/env bash

# SURF - Fedora System Update Script
# Upgrades dnf packages and Flatpaks, then checks whether a restart is needed.
# Must be run as root (e.g. sudo ./surf.sh).
#
# Options:
#   -y, --yes           Answer yes to dnf and Flatpak prompts (unattended runs).
#   --no-reboot-prompt  Skip the reboot question when a reboot is required.

if [ "$EUID" -ne 0 ]; then
    echo "Error: this script must be run as root (use sudo)." >&2
    exit 1
fi

ASSUME_YES=false
NO_REBOOT_PROMPT=false

while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes)
            ASSUME_YES=true
            ;;
        --no-reboot-prompt)
            NO_REBOOT_PROMPT=true
            ;;
        -h|--help)
            echo "Usage: $0 [-y|--yes] [--no-reboot-prompt]"
            echo ""
            echo "  -y, --yes           Answer yes to dnf and Flatpak prompts."
            echo "  --no-reboot-prompt  Skip the reboot question."
            exit 0
            ;;
        *)
            echo "Error: unknown option: $1" >&2
            exit 1
            ;;
    esac
    shift
done

main() {
    overall_status=0

    echo "=== Fedora System Update Script ==="
    echo ""

    echo "Refreshing repository metadata..."
    dnf check-update --refresh
    refresh_status=$?

    dnf_updates_available=false

    if [ "$refresh_status" -eq 100 ]; then
        echo "Updates are available"
        dnf_updates_available=true
    elif [ "$refresh_status" -ne 0 ]; then
        echo "Error: Failed to refresh repository metadata"
        return 1
    else
        echo "No dnf updates available. System is up to date."
    fi

    echo ""

    if [ "$dnf_updates_available" = true ]; then
        echo "Starting package upgrade..."
        dnf_cmd=(dnf upgrade)
        if [ "$ASSUME_YES" = true ]; then
            dnf_cmd+=(-y)
        fi
        "${dnf_cmd[@]}"
        upgrade_status=$?

        if [ "$upgrade_status" -ne 0 ]; then
            echo ""
            echo "Error: Package upgrade failed with exit code $upgrade_status"
            return 1
        fi

        echo ""
        echo "Package upgrade completed successfully"
        echo ""
        echo "Removing unneeded packages..."
        autoremove_cmd=(dnf autoremove)
        if [ "$ASSUME_YES" = true ]; then
        autoremove_cmd+=(-y)
        fi
        "${autoremove_cmd[@]}"
        autoremove_status=$?

    if [ "$autoremove_status" -ne 0 ]; then
        echo "Warning: Failed to remove unneeded packages (exit code $autoremove_status)"
        overall_status=1
    fi
fi


    # Check and update Flatpaks
    echo "=== Checking for Flatpak updates ==="

    if command -v flatpak > /dev/null 2>&1; then
        echo "Checking for Flatpak updates..."
        updates_available=$(flatpak remote-ls --updates 2>/dev/null)
        flatpak_check_status=$?

        if [ "$flatpak_check_status" -ne 0 ]; then
            echo "Error: Failed to check for Flatpak updates"
            overall_status=1
        elif [ -n "$updates_available" ]; then
            echo ""
            echo "Starting Flatpak update..."
            # Flatpaks installed per-user are invisible to root, so when
            # invoked through sudo, run the update as the original user.
            flatpak_cmd=(flatpak --user update)
            if [ "$ASSUME_YES" = true ]; then
                flatpak_cmd+=(-y)
            fi
            if [ -n "${SUDO_USER:-}" ]; then
                sudo -u "$SUDO_USER" "${flatpak_cmd[@]}"
            else
                "${flatpak_cmd[@]}"
            fi
            flatpak_status=$?

            if [ "$flatpak_status" -ne 0 ]; then
                echo "Warning: Flatpak update encountered issues (exit code $flatpak_status)"
                overall_status=1
            else
                echo "Flatpak updates completed successfully"
            fi
        else
            echo "No Flatpak updates available"
        fi
    else
        echo "Flatpak is not installed, skipping Flatpak updates"
    fi

    echo ""

    # Check what needs restarting
    echo "Checking for services/processes that need restarting..."
    dnf needs-restarting -r
    reboot_status=$?

    echo ""

    if [ "$reboot_status" -eq 1 ]; then
        # System reboot required
        echo "System reboot is required (critical components updated)"
        echo ""

        if [ "$NO_REBOOT_PROMPT" = true ] || [ ! -t 0 ]; then
            echo "Reboot prompt skipped (non-interactive run or --no-reboot-prompt). Please reboot manually."
        else
            read -n 1 -p "Do you want to reboot now? [y/N]: " reboot_choice
            echo ""

            if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
                echo "Rebooting system in 5 seconds... (Ctrl+C to cancel)"
                sleep 5
                systemctl reboot
            else
                echo "Reboot cancelled. Please remember to reboot later."
            fi
        fi
    else
        # Check for services that need restarting
        echo "Checking for services that need restarting..."
        dnf needs-restarting -s

        if [ $? -eq 1 ]; then
            echo ""
            echo "Some services need restarting."
            echo "Restart the affected services, or log out and back in."
        else
            echo "No restart required. System is ready to use."
        fi
    fi

    return "$overall_status"
}

# Run main function
main
