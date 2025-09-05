#!/bin/bash

export KERNEL_ROOT="$(pwd)"
export ARCH=arm64
export KBUILD_BUILD_USER="@lk"
LOCALVERSION=-android12-lk
TARGET_DEFCONFIG=${1:-gki_defconfig}
DEVICE_NAME_LIST="r0q,g0q,b0q"

function prepare_toolchain() {
    # Install the requirements for building the kernel when running the script for the first time
    local TOOLCHAIN=$(realpath "../toolchains")
    if [ ! -f ".requirements" ]; then
        sudo apt update && sudo apt install -y git device-tree-compiler lz4 xz-utils zlib1g-dev openjdk-17-jdk gcc g++ python3 python-is-python3 p7zip-full android-sdk-libsparse-utils erofs-utils \
            default-jdk git gnupg flex bison gperf build-essential zip curl libc6-dev libncurses-dev libx11-dev libreadline-dev libgl1 libgl1-mesa-dev \
            python3 make sudo gcc g++ bc grep tofrodos python3-markdown libxml2-utils xsltproc zlib1g-dev python-is-python3 libc6-dev libtinfo6 \
            make repo cpio kmod openssl libelf-dev pahole libssl-dev libarchive-tools zstd --fix-missing && wget http://security.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2ubuntu0.1_amd64.deb && sudo dpkg -i libtinfo5_6.3-2ubuntu0.1_amd64.deb && touch .requirements
    fi

    # Create necessary directories
    mkdir -p "${KERNEL_ROOT}/out" "${KERNEL_ROOT}/build"

    # Export toolchain paths
    export PATH="${PATH}:$TOOLCHAIN/clang-r416183b/bin"
    export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:$TOOLCHAIN/clang-r416183b/lib64"

    # Set cross-compile environment variables
    export BUILD_CROSS_COMPILE="$TOOLCHAIN/gcc/arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-"
    export BUILD_CC="$TOOLCHAIN/clang-r416183b/bin/clang"
}
function prepare_config() {
    if [ "$LTO" == "thin" ]; then
        LOCALVERSION+="-thin"
    fi
    # Build options for the kernel
    export BUILD_OPTIONS="
-C ${KERNEL_ROOT} \
O=${KERNEL_ROOT}/out \
-j$(nproc) \
ARCH=arm64 \
LLVM=1 \
LLVM_IAS=1 \
CROSS_COMPILE=${BUILD_CROSS_COMPILE} \
CC=${BUILD_CC} \
CLANG_TRIPLE=aarch64-linux-gnu- \
LOCALVERSION=$LOCALVERSION \
"
    # Make default configuration.
    make ${BUILD_OPTIONS} $TARGET_DEFCONFIG

    # Configure the kernel (GUI)
    # make ${BUILD_OPTIONS} menuconfig

    # Set the kernel configuration, Disable unnecessary features
    ./scripts/config --file out/.config \
        -d UH \
        -d RKP \
        -d KDP \
        -d SECURITY_DEFEX \
        -d INTEGRITY \
        -d FIVE \
        -d TRIM_UNUSED_KSYMS

    # use thin lto
    if [ "$LTO" = "thin" ]; then
        ./scripts/config --file out/.config -e LTO_CLANG_THIN -d LTO_CLANG_FULL
    fi
}

function repack() {
    local stock_boot_img="$KERNEL_ROOT/stock/boot.img"
    local new_kernel="$KERNEL_ROOT/out/arch/arm64/boot/Image"

    if [ ! -f "$new_kernel" ]; then
        echo "[-] Kernel not found. Skipping repack."
        return 0
    fi

    source "repack.sh"

    # Create build directory and navigate to it
    local build_dir="${KERNEL_ROOT}/build"
    mkdir -p "$build_dir"
    cd "$build_dir"

    generate_info "$KERNEL_ROOT"

    # AnyKernel
    echo "[+] Creating AnyKernel package..."
    pack_anykernel "$new_kernel" "$DEVICE_NAME_LIST"

    # boot.img
    if [ ! -f "$stock_boot_img" ]; then
        echo "[-] boot.img not found. Skipping repack."
        return 0
    fi
    echo "[+] Repacking boot.img using repack.sh..."
    repack_stock_img "$stock_boot_img" "$new_kernel"

    cd "$KERNEL_ROOT"
    echo "[+] Repack completed. Output files in ./build/dist/"
}

function build_kernel() {
    # Build the kernel
    make ${BUILD_OPTIONS} Image || exit 1
    # Copy the built kernel to the build directory
    local output_kernel="${KERNEL_ROOT}/build/kernel"
    cp "${KERNEL_ROOT}/out/arch/arm64/boot/Image" "$output_kernel"
    echo -e "\n[INFO]: Kernel built successfully and copied to $output_kernel\n"
}

main() {
    echo -e "\n[INFO]: BUILD STARTED..!\n"
    prepare_toolchain
    prepare_config
    build_kernel
    repack
    echo -e "\n[INFO]: BUILD FINISHED..!"
}
main
