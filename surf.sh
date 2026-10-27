#!/usr/bin/env bash

# SURF - Fedora System Update Script
# Upgrades dnf packages and Flatpaks, then checks whether a restart is needed.
# Must be run as root (e.g. sudo ./surf.sh).

if [ "$EUID" -ne 0 ]; then
    echo "Error: this script must be run as root (use sudo)." >&2
    exit 1
fi

main() {
    echo "=== Fedora System Update Script ==="
    echo ""

    echo "Refreshing repository metadata..."
    dnf check-update --refresh
    refresh_status=$?

    dnf_updates_available=false

    if [ $refresh_status -eq 100 ]; then
        echo "Updates are available"
        dnf_updates_available=true
    elif [ $refresh_status -ne 0 ]; then
        echo "Error: Failed to refresh repository metadata"
        return 1
    else
        echo "No dnf updates available. System is up to date."
    fi

    echo ""

    if [ "$dnf_updates_available" = true ]; then
        echo "Starting package upgrade..."
        dnf upgrade
        upgrade_status=$?

        if [ $upgrade_status -ne 0 ]; then
            echo ""
            echo "Error: Package upgrade failed with exit code $upgrade_status"
            return 1
        fi

        echo ""
        echo "Package upgrade completed successfully"
        echo ""
    fi

    # Check and update Flatpaks
    echo "=== Checking for Flatpak updates ==="

    if command -v flatpak > /dev/null 2>&1; then
        echo "Checking for Flatpak updates..."
        flatpak remote-ls --updates > /dev/null 2>&1
        flatpak_check_status=$?

        if [ $flatpak_check_status -eq 0 ]; then
            updates_available=$(flatpak remote-ls --updates 2>/dev/null)

            if [ -n "$updates_available" ]; then
                echo ""
                echo "Starting Flatpak update..."
                # Flatpaks installed per-user are invisible to root, so when
                # invoked through sudo, run the update as the original user.
                if [ -n "${SUDO_USER:-}" ]; then
                    sudo -u "$SUDO_USER" flatpak update
                else
                    flatpak update
                fi
                flatpak_status=$?

                if [ $flatpak_status -ne 0 ]; then
                    echo "Warning: Flatpak update encountered issues (exit code $flatpak_status)"
                else
                    echo "Flatpak updates completed successfully"
                fi
            else
                echo "No Flatpak updates available"
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

    if [ $reboot_status -eq 1 ]; then
        # System reboot required
        echo "System reboot is required (critical components updated)"
        echo ""
        read -n 1 -p "Do you want to reboot now? [y/N]: " reboot_choice
        echo ""

        if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
            echo "Rebooting system in 5 seconds... (Ctrl+C to cancel)"
            sleep 5
            systemctl reboot
        else
            echo "Reboot cancelled. Please remember to reboot later."
        fi
    else
        # Check for services that need restarting
        echo "Checking for services that need restarting..."
        dnf needs-restarting -s

        if [ $? -eq 1 ]; then
            echo ""
            echo "System reboot is recommended, but not required"
            echo "You may want to restart affected services or log out and back in"
        else
            echo "No restart required. System is ready to use."
        fi
    fi

    return 0
}

# Run main function
main
