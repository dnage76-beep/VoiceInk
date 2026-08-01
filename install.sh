#!/bin/bash
#
# VoiceInk (Derek's build) one-line installer.
#
#   curl -fsSL https://raw.githubusercontent.com/dnage76-beep/VoiceInk/main/install.sh | bash
#
# Downloads the latest release DMG, installs it to /Applications, and clears
# the quarantine flag so macOS does not make you do the right-click-Open
# dance. Nothing here needs sudo, and nothing runs in the background.

set -euo pipefail

REPO="dnage76-beep/VoiceInk"
APP_NAME="VoiceInk.app"
INSTALL_DIR="/Applications"
APP_PATH="${INSTALL_DIR}/${APP_NAME}"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
info() { printf '  %s\n' "$1"; }
ok()   { printf '\033[32m  ok\033[0m %s\n' "$1"; }
die()  { printf '\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }

cleanup() {
    # Always detach the disk image, even if something failed midway.
    if [[ -n "${MOUNT_POINT:-}" && -d "${MOUNT_POINT:-}" ]]; then
        hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    fi
    [[ -n "${WORK_DIR:-}" ]] && rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo
bold "VoiceInk installer"
echo

# --- Checks the user would otherwise discover the hard way --------------------

[[ "$(uname -s)" == "Darwin" ]] || die "VoiceInk is a Mac app; this is not macOS."

if [[ "$(uname -m)" != "arm64" ]]; then
    die "This build is Apple Silicon only (M1 or newer). Intel Macs cannot run it."
fi

macos_major="$(sw_vers -productVersion | cut -d. -f1)"
macos_minor="$(sw_vers -productVersion | cut -d. -f2)"
if (( macos_major < 14 )) || { (( macos_major == 14 )) && (( macos_minor < 4 )); }; then
    die "Needs macOS 14.4 or newer; this Mac is on $(sw_vers -productVersion)."
fi

# --- Quit a running copy so we are not replacing files under it ---------------

if pgrep -x "VoiceInk" >/dev/null 2>&1; then
    info "Quitting the running copy of VoiceInk..."
    osascript -e 'quit app "VoiceInk"' 2>/dev/null || true
    for _ in $(seq 1 20); do
        pgrep -x "VoiceInk" >/dev/null 2>&1 || break
        sleep 0.25
    done
    pgrep -x "VoiceInk" >/dev/null 2>&1 && die "VoiceInk is still running. Quit it and re-run this."
fi

# An earlier run may have landed in ~/Applications, so keep updating whichever
# copy the user actually has instead of leaving two behind.
if [[ ! -d "$APP_PATH" && -d "${HOME}/Applications/${APP_NAME}" ]]; then
    INSTALL_DIR="${HOME}/Applications"
    APP_PATH="${INSTALL_DIR}/${APP_NAME}"
fi

IS_UPGRADE=false
[[ -d "$APP_PATH" ]] && IS_UPGRADE=true

# --- Download -----------------------------------------------------------------

WORK_DIR="$(mktemp -d)"
DMG_PATH="${WORK_DIR}/VoiceInk.dmg"

# Ask the release for its actual DMG asset instead of assuming a filename;
# a renamed asset silently 404s the fixed URL (this bit us at v1.2.3-1.2.5).
DOWNLOAD_URL="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null \
    | grep -o '"browser_download_url"[^"]*"[^"]*\.dmg"' \
    | head -1 \
    | grep -o 'https://[^"]*')"
[[ -n "$DOWNLOAD_URL" ]] \
    || DOWNLOAD_URL="https://github.com/${REPO}/releases/latest/download/VoiceInk-DerekBuild.dmg"

info "Downloading the latest release..."
curl -fL --progress-bar "$DOWNLOAD_URL" -o "$DMG_PATH" \
    || die "Download failed. Check your connection, or grab the DMG from https://github.com/${REPO}/releases/latest"

# A truncated download would otherwise fail later as a confusing mount error.
[[ -s "$DMG_PATH" ]] || die "The downloaded file is empty."
dmg_size="$(stat -f%z "$DMG_PATH")"
(( dmg_size > 5000000 )) || die "The download looks incomplete (${dmg_size} bytes)."
ok "downloaded ($(( dmg_size / 1048576 )) MB)"

# --- Install ------------------------------------------------------------------

MOUNT_POINT="${WORK_DIR}/mnt"
mkdir -p "$MOUNT_POINT"
hdiutil attach "$DMG_PATH" -nobrowse -quiet -mountpoint "$MOUNT_POINT" \
    || die "Could not open the disk image."

[[ -d "${MOUNT_POINT}/${APP_NAME}" ]] || die "The disk image did not contain ${APP_NAME}."

# /Applications is owned by root:admin, so only administrator accounts can
# write to it. On a standard account (or when an existing copy was installed
# by a different user) the copy below fails, which is why we check first and
# fall back to the user's own ~/Applications rather than dying.
can_install_to() {
    local target_dir="$1"
    local existing="${target_dir}/${APP_NAME}"

    [[ -d "$target_dir" ]] || return 1
    [[ -w "$target_dir" ]] || return 1
    # Replacing an existing copy needs to delete it, which needs write access
    # to the bundle itself, not just to the folder holding it.
    if [[ -e "$existing" && ! -w "$existing" ]]; then
        return 1
    fi
    return 0
}

if ! can_install_to "$INSTALL_DIR"; then
    USER_APPS="${HOME}/Applications"
    mkdir -p "$USER_APPS" 2>/dev/null || true

    if can_install_to "$USER_APPS"; then
        info "No permission to write to /Applications (that needs an admin account)."
        info "Installing to ${USER_APPS} instead."
        INSTALL_DIR="$USER_APPS"
        APP_PATH="${INSTALL_DIR}/${APP_NAME}"
    else
        die "Cannot write to /Applications or ~/Applications.
       /Applications needs an administrator account. Either ask an admin to
       run this, or install by hand: open the DMG and drag VoiceInk to your
       Applications folder.
       DMG: https://github.com/${REPO}/releases/latest"
    fi
fi

info "Installing to ${INSTALL_DIR}..."

# Remove the old copy explicitly so a permissions problem is reported here
# rather than surfacing as a confusing half-finished copy.
if [[ -e "$APP_PATH" ]]; then
    rm -rf "$APP_PATH" 2>/dev/null \
        || die "Could not replace the existing VoiceInk at ${APP_PATH}. Quit VoiceInk and try again, or delete it by hand and re-run this."
fi

# ditto preserves the code signature; cp -R does not reliably.
ditto "${MOUNT_POINT}/${APP_NAME}" "$APP_PATH" \
    || die "Could not copy VoiceInk into ${INSTALL_DIR}. If this is a work Mac, its management software may block installs there."

hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
MOUNT_POINT=""

# This is the whole point of the installer: downloaded apps are quarantined,
# and because this build is signed locally rather than notarized by Apple,
# that flag is what forces the right-click-Open dance. Removing it is exactly
# what that dance does, just without the confusion.
#
# Not every macOS ships an xattr that supports -r, and the one that does not
# prints a usage screen instead of failing quietly, so fall back to walking
# the bundle by hand.
if ! xattr -dr com.apple.quarantine "$APP_PATH" >/dev/null 2>&1; then
    find "$APP_PATH" -print0 2>/dev/null \
        | xargs -0 xattr -d com.apple.quarantine >/dev/null 2>&1 || true
fi

if xattr -p com.apple.quarantine "$APP_PATH" >/dev/null 2>&1; then
    info "note: macOS still has this app quarantined. If it refuses to open,"
    info "      right-click VoiceInk in Applications and choose Open."
fi
ok "installed to ${APP_PATH}"

# --- Launch -------------------------------------------------------------------

open "$APP_PATH" || die "Installed, but could not launch it. Open VoiceInk from Applications."

echo
if [[ "$IS_UPGRADE" == true ]]; then
    bold "Updated. VoiceInk is opening now."
    echo
    info "Your settings, modes, and history are kept."
    info "macOS treats each new build as a new app, so if the hotkey stops"
    info "working, re-grant Accessibility in System Settings > Privacy &"
    info "Security > Accessibility, then quit and reopen VoiceInk."
else
    bold "Done. VoiceInk is opening now."
    echo
    info "It will ask for two permissions:"
    info "  Microphone      click Allow"
    info "  Accessibility   needed to type into other apps. Toggle VoiceInk on"
    info "                  when System Settings opens, then quit and reopen"
    info "                  VoiceInk once so the hotkey starts working."
    echo
    info "In onboarding, pick Parakeet V2: it is fast, accurate, and runs"
    info "entirely on your Mac, so your audio never leaves it."
    echo
    info "Then tap Fn and talk. Hold Fn to talk only while held."
fi
echo
