#!/bin/bash
#
# Compile script for QuicksilveR kernel
# Copyright (C) 2020-2023 Adithya R.

SECONDS=0 # builtin bash timer
ZIPNAME="QuicksilveRV2-ginkgo-$(date '+%Y%m%d-%H%M').zip"
TC_DIR="$HOME/tc/clang-r450784d"
GCC_64_DIR="$HOME/tc/aarch64-linux-android-4.9"
GCC_32_DIR="$HOME/tc/arm-linux-androideabi-4.9"
AK3_DIR="$HOME/AnyKernel3"
DEFCONFIG="vendor/ginkgo-perf_defconfig"

MAKE_PARAMS="O=out ARCH=arm64 CC=clang LD=ld.lld LLVM=1 LLVM_IAS=1 \
	CLANG_TRIPLE=aarch64-linux-gnu- \
	CROSS_COMPILE=$GCC_64_DIR/bin/aarch64-linux-android- \
	CROSS_COMPILE_ARM32=$GCC_32_DIR/bin/arm-linux-androideabi-"

export PATH="$TC_DIR/bin:$PATH"

if test -z "$(git rev-parse --show-cdup 2>/dev/null)" &&
   head=$(git rev-parse --verify HEAD 2>/dev/null); then
	ZIPNAME="${ZIPNAME::-4}-$(echo $head | cut -c1-8).zip"
fi

if [[ $1 = "-r" || $1 = "--regen" ]]; then
   make $MAKE_PARAMS $DEFCONFIG savedefconfig
   cp out/defconfig arch/arm64/configs/$DEFCONFIG
   echo -e "\nSuccessfully regenerated defconfig at arch/arm64/configs/$DEFCONFIG"
   exit
fi

if [[ $1 = "-c" || $1 = "--clean" ]]; then
   rm -rf out
   echo "Cleaned output folder"
fi

mkdir -p out
make $MAKE_PARAMS $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) $MAKE_PARAMS Image.gz-dtb dtbo.img 2> >(tee error.log >&2) || exit $?

kernel="out/arch/arm64/boot/Image.gz-dtb"
dtbo="out/arch/arm64/boot/dtbo.img"

if [ ! -f "$kernel" ] || [ ! -f "$dtbo" ]; then
	echo -e "\nCompilation failed!"
	exit 1
fi

echo -e "\nKernel compiled succesfully! Zipping up...\n"
if [ -d "$AK3_DIR" ]; then
	cp -r $AK3_DIR AnyKernel3
	git -C AnyKernel3 checkout master &> /dev/null
elif ! git clone -q https://github.com/ghostrider-reborn/AnyKernel3 -b master; then
	echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
	exit 1
fi
cp $kernel $dtbo AnyKernel3
rm -rf out/arch/arm64/boot
cd AnyKernel3
zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder
cd ..
rm -rf AnyKernel3
echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
echo "$(realpath $ZIPNAME)"
