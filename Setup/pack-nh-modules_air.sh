#!/usr/bin/env bash

set -e

DIST="$HOME/kernel/out/android13-5.15/dist"
STAGING="$HOME/kernel/out/android13-5.15/staging/lib/modules"

OUT="$HOME/nethunter_modules"
ZIP="$HOME/nethunter_modules_$(date +%Y%m%d-%H%M).zip"

mkdir -p "$OUT"

echo "[*] Cleaning output..."
rm -rf "$OUT"/*
rm -f "$ZIP"

# Auto-detect metadata directory
META_DIR=$(dirname "$(find "$STAGING" -name modules.dep | head -1)")

echo "[*] Metadata dir:"
echo "    $META_DIR"

# NetHunter modules
MODULES=(
cfg80211.ko
mac80211.ko

ath.ko
ath9k_hw.ko
ath9k_common.ko
ath9k_htc.ko

rt2x00lib.ko
rt2x00usb.ko
rt2800lib.ko
rt2800usb.ko

rtl8187.ko

mt7601u.ko
)

echo "[*] Copying modules..."

for mod in "${MODULES[@]}"; do
    found=$(find "$DIST" -name "$mod" 2>/dev/null | head -1)

    if [ -n "$found" ]; then
        echo "  + $(basename "$found")"
        cp -a "$found" "$OUT/"
    else
        echo "  - Missing: $mod"
    fi
done

echo "[*] Copying metadata..."

for f in \
modules.alias \
modules.dep \
modules.load \
modules.load.recovery \
modules.softdep \
modules.order
do
    if [ -f "$META_DIR/$f" ]; then
        echo "  + $f"
        cp -a "$META_DIR/$f" "$OUT/"
    else
        echo "  - Missing: $f"
    fi
done

echo "[*] Final contents:"
ls -lh "$OUT"

echo
echo "[*] Creating ZIP..."

cd "$OUT"
zip -r9 "$ZIP" .

echo
echo "[✓] Created:"
echo "$ZIP"

echo
echo "[*] Uploading..."

curl -T "$ZIP" https://sendit.sh

echo
echo "[✓] Done."
