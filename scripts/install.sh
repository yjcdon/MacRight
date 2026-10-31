#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="${MACRIGHT_ARCH:-$(uname -m)}"
SOURCE="$ROOT/build/$ARCH/MacRight.app"
APPLICATIONS_DIR="${MACRIGHT_APPLICATIONS_DIR:-/Applications}"
DESTINATION="$APPLICATIONS_DIR/MacRight.app"
STAGING=""
BACKUP=""
INSTALLED_NEW=0
UNREGISTERED_OLD=0

move_to_trash() {
    local path="$1" label="$2"
    mkdir -p "$HOME/.Trash"
    mv "$path" "$HOME/.Trash/MacRight-$label-$(date +%Y%m%d-%H%M%S)-$$"
}

# Match the executable's full path, so another checkout or a different app is never stopped.
stop_installed_processes() {
    local processes pid command attempt alive
    local pids=()
    processes="$(/bin/ps -axo pid=,comm=)" || return 1
    while read -r pid command; do
        if [[ "$command" == "$DESTINATION/Contents/MacOS/MacRight" ||
              "$command" == "$DESTINATION/Contents/PlugIns/MacRightFinderExtension.appex/Contents/MacOS/MacRightFinderExtension" ||
              "$command" == "$DESTINATION/Contents/Helpers/MacRightTerminalLauncher.app/Contents/MacOS/MacRightTerminalLauncher" ]]; then
            if kill -TERM "$pid" 2>/dev/null; then
                pids+=("$pid")
            elif kill -0 "$pid" 2>/dev/null; then
                echo "Could not stop MacRight process $pid." >&2
                return 1
            fi
        fi
    done <<< "$processes"
    if [ "${#pids[@]}" -eq 0 ]; then return 0; fi
    for ((attempt = 0; attempt < 50; attempt++)); do
        alive=0
        for pid in "${pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then alive=1; fi
        done
        if [ "$alive" -eq 0 ]; then return 0; fi
        sleep 0.1
    done
    echo "MacRight did not stop within five seconds; the previous installation was preserved." >&2
    return 1
}

finish_install() {
    local status="$?"
    trap - EXIT
    # Restore the original installation after a failed replacement or registration.
    if [ "$status" -ne 0 ]; then
        if [ "$INSTALLED_NEW" -eq 1 ] && [ -d "$DESTINATION" ]; then
            stop_installed_processes || echo "Could not stop the failed installation." >&2
            move_to_trash "$DESTINATION" failed || echo "Could not move the failed installation to the Trash." >&2
        fi
        if [ -n "$BACKUP" ] && [ -d "$BACKUP" ] && [ ! -e "$DESTINATION" ]; then
            mv "$BACKUP" "$DESTINATION" || echo "Restore the previous app from: $BACKUP" >&2
        fi
        if [ "$UNREGISTERED_OLD" -eq 1 ] && [ -d "$DESTINATION" ]; then
            pluginkit -a "$DESTINATION/Contents/PlugIns/MacRightFinderExtension.appex" || echo "Could not re-register the restored extension." >&2
        fi
    fi
    if [ -n "$STAGING" ] && [ -d "$STAGING" ]; then
        move_to_trash "$STAGING" staging || echo "Installation staging remains at: $STAGING" >&2
    fi
    exit "$status"
}

trap finish_install EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

codesign --verify --deep --strict "$SOURCE"
mkdir -p "$APPLICATIONS_DIR"
APPLICATIONS_DIR="$(cd "$APPLICATIONS_DIR" && pwd -P)"
DESTINATION="$APPLICATIONS_DIR/MacRight.app"
STAGING="$(mktemp -d "$APPLICATIONS_DIR/.MacRight-install.XXXXXX")"
ditto "$SOURCE" "$STAGING/MacRight.app"
codesign --verify --deep --strict "$STAGING/MacRight.app"

if [ -d "$DESTINATION" ]; then
    # Deregistration prevents Finder from relaunching the old extension during replacement.
    pluginkit -r "$DESTINATION/Contents/PlugIns/MacRightFinderExtension.appex"
    UNREGISTERED_OLD=1
    stop_installed_processes
    mkdir -p "$HOME/.Trash"
    BACKUP="$HOME/.Trash/MacRight-previous-$(date +%Y%m%d-%H%M%S)-$$.app"
    mv "$DESTINATION" "$BACKUP"
fi

# Staging and destination are on the same volume, so the final rename is atomic.
mv "$STAGING/MacRight.app" "$DESTINATION"
INSTALLED_NEW=1
pluginkit -a "$DESTINATION/Contents/PlugIns/MacRightFinderExtension.appex"
# Refresh Finder's live extension connections after replacing an installed version.
if [ "$UNREGISTERED_OLD" -eq 1 ] && pgrep -x Finder >/dev/null; then
    echo "Reloading Finder to refresh MacRight menus."
    killall Finder
    osascript -e 'tell application "Finder" to activate'
fi
open "$DESTINATION"
echo "Installed: $DESTINATION"
