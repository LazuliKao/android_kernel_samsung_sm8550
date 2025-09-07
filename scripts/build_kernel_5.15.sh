#!/bin/bash

export KERNEL_ROOT="$(pwd)"
export ARCH=arm64
export KBUILD_BUILD_USER="@lk"
LOCALVERSION=-android13-lk
TARGET_DEFCONFIG=${1:-gki_defconfig}
DEVICE_NAME_LIST="gts9wifi"

function prepare_toolchain() {
    # Install the requirements for building the kernel when running the script for the first time
    local TOOLCHAIN=$(realpath "../toolchains")
    export PATH=$TOOLCHAIN/build-tools/linux-x86/bin:$PATH
    export PATH=$TOOLCHAIN/build-tools/path/linux-x86:$PATH
    export PATH=$TOOLCHAIN/clang/host/linux-x86/clang-r450784e/bin:$PATH
    export PATH=$TOOLCHAIN/clang-tools/linux-x86/bin:$PATH
    export PATH=$TOOLCHAIN/kernel-build-tools/linux-x86/bin:$PATH
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
