#!/bin/bash

set -e

export TZ=Asia/Kolkata
export KBUILD_BUILD_USER=MAdMiZ
export KBUILD_BUILD_HOST=Kali
export LOCALVERSION="-AirStorm-Nethunter-OSS"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TC_DIR="$SCRIPT_DIR/tc/zyc_clang"
export HERMETIC_TOOLCHAIN=0

# Patch with latest KernelSU-Next
  echo "Applying latest KernelSU-Next patch"
if ! [ -d "$KERNEL_DIR"/KernelSU ]; then
  curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -
else
  echo -e "KernelSU-Next patch failed, stopping build now..."
  exit 1
fi

if [ ! -x "$TC_DIR/bin/clang" ] && [ ! -x "$TC_DIR/bin/clang-14" ]; then
    echo "Downloading ZyC Clang 14..."
    mkdir -p "$TC_DIR"
    wget -O /tmp/zyc_clang.tar.gz \
    https://github.com/ZyCromerZ/Clang/releases/download/14.0.6-20250704-release/Clang-14.0.6-20250704.tar.gz
    tar -xzf /tmp/zyc_clang.tar.gz -C "$TC_DIR"
    rm -f /tmp/zyc_clang.tar.gz
    if [ ! -x "$TC_DIR/bin/clang" ] && [ ! -x "$TC_DIR/bin/clang-14" ]; then
        echo "ERROR: Clang not found after extraction!"
        exit 1
    fi
fi

export PATH="$TC_DIR/bin:$PATH"

if [ -x "$TC_DIR/bin/clang-14" ]; then
    export CC="$TC_DIR/bin/clang-14"
else
    export CC="$TC_DIR/bin/clang"
fi

export LD="$TC_DIR/bin/ld.lld"
export AR="$TC_DIR/bin/llvm-ar"
export NM="$TC_DIR/bin/llvm-nm"
export STRIP="$TC_DIR/bin/llvm-strip"
export OBJCOPY="$TC_DIR/bin/llvm-objcopy"
export OBJDUMP="$TC_DIR/bin/llvm-objdump"

echo "Compiler: $CC"
"$CC" --version | head -1

KERNEL_ROOT="$SCRIPT_DIR"

DIST_DIR="$KERNEL_ROOT/out/android13-5.15/dist"
AK3_DIR="$KERNEL_ROOT/AnyKernel3"

ZIP_NAME="AirStorm-Nethunter-OSS-$(date +%Y%m%d-%H%M).zip"

cd "$KERNEL_ROOT"

echo "Building Kernel..."
BUILD_CONFIG=kernel-5.15/build.config.mtk.aarch64.mgk \
build/build.sh 2>&1 | tee build.log

echo "Preparing AnyKernel3 zip..."

if [ ! -d "$AK3_DIR" ]; then
    git clone \
        https://github.com/Koushikdey2003/AnyKernel3 \
        -b air \
        --depth=1 \
        "$AK3_DIR"
fi

if [ ! -f "$DIST_DIR/Image.gz" ]; then
    echo "ERROR: Image.gz not found!"
    exit 1
fi

rm -f "$AK3_DIR/Image.gz"
cp "$DIST_DIR/Image.gz" "$AK3_DIR/"

cd "$AK3_DIR"

# Remove old zip files
find . -maxdepth 1 -name "*.zip" -delete

echo "Creating flashable zip..."
zip -r9 "$ZIP_NAME" ./*

echo "Uploading to sendit.sh..."

UPLOAD_URL=$(curl -fsSL -T "$ZIP_NAME" https://sendit.sh)

if [ -z "$UPLOAD_URL" ]; then
    echo "ERROR: Upload failed!"
    exit 1
fi

echo
echo "Build complete."
echo "ZIP: $AK3_DIR/$ZIP_NAME"
echo "URL: $UPLOAD_URL"
echo
