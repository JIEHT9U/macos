#!/usr/bin/env bash
set -euo pipefail

# Merge optional plist patches into /assets/config.plist at runtime.
# Behavior improvements:
#  - Look for multiple known spoof files
#  - Prefer an explicit /assets/config.patch.plist when present
#  - Create a timestamped backup of the base config before merging
#  - Handle python errors gracefully and restore backup on failure
#  - Log helpful messages to aid debugging

: "${SPOOF_VM:=}"
PATCH_PATH="/assets/config.patch.plist"
# Candidate spoof filenames (searched in order)
SPOOF_CANDIDATES=(
    "/assets/config_spoof.plist"
    "/assets/config_spoof_sequoia.plist"
    "/assets/config_bt_spoof.plist"
)
BASE_PATH="/assets/config.plist"

# Determine which patch file to use (PATCH_PATH has highest priority)
SELECTED_PATCH=""
if [ -f "$PATCH_PATH" ]; then
    SELECTED_PATCH="$PATCH_PATH"
else
    for p in "${SPOOF_CANDIDATES[@]}"; do
        if [ -f "$p" ]; then
            SELECTED_PATCH="$p"
            break
        fi
    done
fi

# If SPOOF_VM is set but no explicit patch found, log intent and continue searching
if [ -n "${SPOOF_VM:-}" ] && [ -z "$SELECTED_PATCH" ]; then
    echo "[merge.sh] SPOOF_VM set but no explicit patch file found; checking known spoof candidates..."
    for p in "${SPOOF_CANDIDATES[@]}"; do
        if [ -f "$p" ]; then
            SELECTED_PATCH="$p"
            echo "[merge.sh] Found spoof candidate: $SELECTED_PATCH"
            break
        fi
    done
fi

# If no trigger and no patch file, nothing to do
if [ -z "${SPOOF_VM:-}" ] && [ -z "$SELECTED_PATCH" ]; then
    # nothing to merge
    exit 0
fi

# Ensure python3 is available
if ! command -v python3 >/dev/null 2>&1; then
    echo "[merge.sh] python3 not found; cannot merge plist patches"
    exit 0
fi

# If we get here, we have either SPOOF_VM set or a patch file present
if [ -z "$SELECTED_PATCH" ]; then
    echo "[merge.sh] No patch file found to merge; skipping"
    exit 0
fi

echo "[merge.sh] Merging plist patches into $BASE_PATH using patch $SELECTED_PATCH"

# Create a backup of the base plist (if it exists)
bak=""
if [ -f "$BASE_PATH" ]; then
    ts="$(date +%Y%m%d%H%M%S || echo backup)"
    bak="${BASE_PATH}.bak.${ts}"
    if cp -p "$BASE_PATH" "$bak"; then
        echo "[merge.sh] Backed up $BASE_PATH -> $bak"
    else
        echo "[merge.sh] Warning: failed to create backup of $BASE_PATH"
        bak=""
    fi
else
    echo "[merge.sh] Base config $BASE_PATH not found; merger may create a new file"
fi

# Run the Python merger and handle errors
if python3 /run/merge_plist.py "$BASE_PATH" "$SELECTED_PATCH"; then
    echo "[merge.sh] Merge completed successfully"
else
    echo "[merge.sh] Merge failed: merge_plist.py returned a non-zero status"
    # Attempt to restore backup if one exists
    if [ -n "${bak:-}" ] && [ -f "$bak" ]; then
        if cp -p "$bak" "$BASE_PATH"; then
            echo "[merge.sh] Restored backup $bak -> $BASE_PATH"
        else
            echo "[merge.sh] Failed to restore backup $bak; manual intervention required"
        fi
    fi
    # Continue without failing the whole init sequence
fi

return 0
