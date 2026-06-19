#!/usr/bin/env bash
set -Eeuo pipefail

# ======================================================
# NetHunter Vendor Boot Builder (MTK / Android Header v4)
# ======================================================

VENDOR_BOOT="vendor_boot.img"
NH_ZIP="nethunter_modules.zip"

UNPACK="$HOME/kernel/tools/mkbootimg/unpack_bootimg.py"
MKBOOTIMG="$HOME/kernel/tools/mkbootimg/mkbootimg.py"

WORK="$HOME/.nh_vendorboot_work"

OUT_IMG="nh-vendor_boot.img"

die() {
    echo
    echo "[ERROR] $1"
    exit 1
}

need() {
    command -v "$1" >/dev/null || die "$1 not installed"
}

echo "[*] Checking dependencies..."

need python3
need lz4
need cpio
need unzip
need grep
need awk
need stat
need truncate

[[ -f "$VENDOR_BOOT" ]] || die "$VENDOR_BOOT not found"
[[ -f "$NH_ZIP" ]] || die "$NH_ZIP not found"
[[ -f "$UNPACK" ]] || die "unpack_bootimg.py not found"
[[ -f "$MKBOOTIMG" ]] || die "mkbootimg.py not found"

echo "[*] Cleaning workspace..."
rm -rf "$WORK"
mkdir -p "$WORK"

cd "$WORK"

echo "[*] Copying vendor_boot..."
cp "$OLDPWD/$VENDOR_BOOT" .

echo "[*] Unpacking vendor_boot..."
python3 "$UNPACK" --boot_img vendor_boot.img > info.txt

ORIG_SIZE=$(stat -c "%s" vendor_boot.img)

HEADER=$(grep "vendor boot image header version" info.txt | awk '{print $NF}')
PAGESIZE=$(grep "page size" info.txt | awk '{print $NF}')
BASE=$(grep "kernel load address" info.txt | awk '{print $NF}')
RAMDISK_ADDR=$(grep "ramdisk load address" info.txt | awk '{print $NF}')
TAGS=$(grep "kernel tags load address" info.txt | awk '{print $NF}')
DTB_ADDR=$(grep "dtb address" info.txt | awk '{print $NF}')

CMDLINE=$(grep "vendor command line args" info.txt | cut -d: -f2- | sed 's/^ //')

echo "[*] Original size : $ORIG_SIZE"
echo "[*] Header        : $HEADER"

mkdir ramdisk

echo "[*] Extracting ramdisk..."

cd ramdisk

lz4 -d ../out/vendor_ramdisk00 -c | cpio -idmv >/dev/null

echo "[*] Extracting NetHunter modules..."

mkdir ../nh
unzip -oq "$OLDPWD/$NH_ZIP" -d ../nh

echo "[*] Replacing modules..."

cp -fv ../nh/*.ko lib/modules/
cp -fv ../nh/modules.dep lib/modules/
cp -fv ../nh/modules.alias lib/modules/
cp -fv ../nh/modules.softdep lib/modules/
cp -fv ../nh/modules.order lib/modules/

echo "[*] Repacking ramdisk..."

find . | cpio -o -H newc 2>/dev/null | lz4 -l > ../vendor_ramdisk_new

cd ..

echo "[*] Rebuilding vendor_boot..."

python3 "$MKBOOTIMG" \
  --vendor_boot vendor_boot_new.img \
  --header_version "$HEADER" \
  --pagesize $((PAGESIZE)) \
  --base "$BASE" \
  --kernel_offset 0x0 \
  --ramdisk_offset $((RAMDISK_ADDR-BASE)) \
  --tags_offset $((TAGS-BASE)) \
  --dtb_offset $((DTB_ADDR-BASE)) \
  --vendor_ramdisk vendor_ramdisk_new \
  --dtb out/dtb \
  --vendor_cmdline "$CMDLINE"

echo "[*] Padding to original size..."

cp vendor_boot_new.img "$OUT_IMG"

truncate -s "$ORIG_SIZE" "$OUT_IMG"

echo "[*] Verifying..."

python3 "$UNPACK" --boot_img "$OUT_IMG"

echo
echo "=================================="
echo "DONE"
echo "Generated:"
echo "$WORK/$OUT_IMG"
echo "=================================="
