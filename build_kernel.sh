#!/bin/bash

# Riaru Kernel Simple Build System
# Here is the dependencies to build the kernel
# Ubuntu/Ubuntu Based OS: apt update && apt upgrade && apt install glibc-source libghc-libyaml-dev libyaml-dev binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi binutils device-tree-compiler libtfm-dev libelf-dev cpio kmod nano bc bison ca-certificates curl flex gcc git libc6-dev libssl-dev openssl python-is-python3 ssh wget zip zstd sudo make clang gcc-arm-linux-gnueabi software-properties-common build-essential libarchive-tools gcc-aarch64-linux-gnu python2
# Arch/Arch Based OS: sudo pacman -S aarch64-linux-gnu-glibc glibc libyaml aarch64-linux-gnu-binutils arm-none-eabi-binutils binutils dtc fmt libelf cpio kmod bc bison ca-certificates curl flex glibc openssl openssh wget zip zstd make clang aarch64-linux-gnu-gcc arm-none-eabi-gcc archivetools base-devel python git

# Variables - i recommend you to not change every single thing that you see.
export ARCH=arm64
export SUBARCH=arm64
export HEADER_ARCH=arm64
export LLVM=1
export LLVM_IAS=1
export AR=llvm-ar
export NM=llvm-nm
export LD=ld.lld
export OBJCOPY=llvm-objcopy
export OBJDUMP=llvm-objdump
export STRIP=llvm-strip
export CC=clang
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
DEFCONFIG=sweet_defconfig
LOGGER=build_kernel.log
ISTHISWSL=0
CONTINENTS=Asia
LOCATION=Makassar
NOTHAVECLANG=1
CLANG_DIR="clang"
KSU=`cat arch/arm64/configs/$DEFCONFIG | grep CONFIG_KSU=y`
CPUCORE=`nproc --all`
export KBUILD_BUILD_USER="$USER"
export KBUILD_BUILD_HOST="$HOSTNAME"

# Logs
echo "Removing previous kernel build logs..."
REALLOGGER="$(pwd)"/${LOGGER}
rm -rf $REALLOGGER

# Manual clock sync for WSL, look at your /usr/share/zoneinfo/* to see more info
if [ "$ISTHISWSL" == "1" ]; then
	echo "Asking sudo password for updating the timezone manually..."
	sudo ln -sf /usr/share/zoneinfo/$CONTINENTS/$LOCATION /etc/localtime &>> $REALLOGGER
	sudo hwclock --systohc &>> $REALLOGGER
fi

# clang compiler preparation
REALCLANG_DIR="$(pwd)"/${CLANG_DIR}
if [ "$NOTHAVECLANG" == "1" ]; then
	echo "Downloading Playground clang from basamaryan repository..."
	wget https://github.com/basamaryan/kernel_xiaomi_sm6150/releases/download/18/playgroundtc.tar.gz &>> $REALLOGGER
	tar -xvzf playgroundtc.tar.gz &>> $REALLOGGER
	mv playgroundtc $CLANG_DIR &>> $REALLOGGER
fi
echo "Setting up proper permissions to clang and export it to PATH..."
sudo chmod 755 -R $REALCLANG_DIR &>> $REALLOGGER
export PATH="$REALCLANG_DIR/bin:$PATH"

# KernelSU Support
if [ "$KSU" == "CONFIG_KSU=y" ]; then
	echo "KernelSU support is enabled, downloading KernelSU..."
	rm -rf KernelSU &>> $REALLOGGER
	cd drivers
	rm -rf kernelsu &>> $REALLOGGER
	cd ..
	git clone https://github.com/riarumoda/KernelSU-4.4 KernelSU &>> $REALLOGGER
	cd drivers
	ln -sf ../KernelSU/kernel kernelsu &>> $REALLOGGER
	cd ..
	sed -i '/endmenu/i source "drivers/kernelsu/Kconfig"' drivers/Kconfig
else
	echo "KernelSU support is disabled, skipping..."
	rm -rf KernelSU &>> $REALLOGGER
	cd drivers
	rm -rf kernelsu &>> $REALLOGGER
	cd ..
	sed -i '/source "drivers\/kernelsu\/Kconfig"/d' drivers/Kconfig
fi

# Cleanup
echo "Cleaning up out directory..."
rm -rf out
mkdir out
rm -rf error.log

# Compile
echo "Compiling the kernel..."
make -j$CPUCORE O=out clean &>> $REALLOGGER
make -j$CPUCORE O=out mrproper &>> $REALLOGGER
make -j$CPUCORE O=out $DEFCONFIG &>> $REALLOGGER
make -j$CPUCORE O=out &>> $REALLOGGER
