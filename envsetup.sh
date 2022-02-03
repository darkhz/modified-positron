#!/bin/bash
# SPDX-License-Identifier: GPL-2.0

### Customisable variables
export AK3_URL=https://github.com/dereference23/AnyKernel3
export AK3_BRANCH=positron
export DEFCONFIG_NAME=cust
export TC_DIR="$HOME/prebuilts"
export ZIPNAME="positron-miatoll-$(date +%Y%m%d).zip"

export KBUILD_BUILD_USER=dereference23
export KBUILD_BUILD_HOST=github.com
### End

# Set up environment
function envsetup() {
    HOSTARCH="$(uname -m)"

        export ARCH=arm64
        export PATH="$TC_DIR/clang/bin:$PATH"

    export CLANG_TRIPLE=aarch64-linux-gnu-
    export CROSS_COMPILE=aarch64-linux-android-
    export CROSS_COMPILE_ARM32=arm-none-eabi-
    export CROSS_COMPILE_COMPAT=arm-none-eabi-
}

# Clone the toolchain(s)
function clonetc() {
    TC_REMOTE=https://github.com/Positron-V

    if [ "$HOSTARCH" != aarch64 ]; then
        [ -d "$TC_DIR/gcc-arm64" ] || git clone --depth 1 $TC_REMOTE/android_prebuilts_gcc_linux-x86_aarch64_aarch64-none-linux-gnu "$TC_DIR/gcc-arm64" || return
	[ -d "$TC_DIR/gcc-arm" ] || git clone --depth 1 $TC_REMOTE/android_prebuilts_gcc_linux-x86_arm_arm-none-eabi "$TC_DIR/gcc-arm"
    else
	[ -d "$TC_DIR/gcc-arm" ] || git clone --depth 1 $TC_REMOTE/android_prebuilts_gcc_linux-aarch64_arm_arm-none-eabi "$TC_DIR/gcc-arm"
    fi

    # Save some space
    rm -rf "$TC_DIR/gcc-arm64/.git" 2> /dev/null
    rm -rf "$TC_DIR/gcc-arm/.git" 2> /dev/null
}


# Wrapper to utilise all available cores
function m() {
	make -j$(nproc --all) CC="ccache clang" LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip O=out "$@"
}

# Build kernel
function mka() {
    m ${DEFCONFIG_NAME}_defconfig || return
    m
}

# Pack kernel and upload it
function pack() {
    AK3=AnyKernel3
    if [ ! -d $AK3 ]; then
        git clone $AK3_URL $AK3 -b $AK3_BRANCH --depth 1 -q || return
    fi

    OUT=out/arch/arm64/boot
    cp $OUT/Image $AK3 || return
    cp $OUT/dtbo.img $AK3 2> /dev/null
    find $OUT/dts -name *.dtb -exec cat {} + > $AK3/dtb
    rm $AK3/*.zip 2> /dev/null
    ( cd $AK3 && zip -r9 "$ZIPNAME" * -x .git README.md *placeholder ) || return
    # workaround for missing \n
    echo "$(curl --upload-file "$AK3/$ZIPNAME" https://transfer.sh/"$ZIPNAME")"
}

# Regenerate defconfig
function rd() {
   m ${DEFCONFIG_NAME}_defconfig savedefconfig || return
   cp out/defconfig arch/arm64/configs/${DEFCONFIG_NAME}_defconfig
}

envsetup
