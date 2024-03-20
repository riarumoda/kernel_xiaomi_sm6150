#!/bin/bash

# Riaru: Aghisna RX Kernel Simple Build System
# Based on Riaru Kernel Simple Build System
# Here is the dependencies to build the kernel
# Ubuntu/Ubuntu Based OS: apt update && apt upgrade && apt install glibc-source libghc-libyaml-dev libyaml-dev binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi binutils device-tree-compiler libtfm-dev libelf-dev cpio kmod nano bc bison ca-certificates curl flex gcc git libc6-dev libssl-dev openssl python-is-python3 ssh wget zip zstd sudo make clang gcc-arm-linux-gnueabi software-properties-common build-essential libarchive-tools gcc-aarch64-linux-gnu python2
# Arch/Arch Based OS: sudo pacman -S aarch64-linux-gnu-glibc glibc libyaml aarch64-linux-gnu-binutils arm-none-eabi-binutils bintuils dtc fmt libelf cpio kmod bc bison ca-certificates curl flex glibc openssl openssh wget zip zstd make clang aarch64-linux-gnu-gcc arm-none-eabi-gcc archivetools base-devel python

# Logs
echo "Removing previous kernel build logs..."
LOGGER=kernel-logs.txt
REALLOGGER="$(pwd)"/${LOGGER}
rm -rf $REALLOGGER

# Manual clock sync for WSL, look at your /usr/share/zoneinfo/* to see more info
ISTHISWSL=1
CONTINENTS=Asia
LOCATION=Makassar
if [ "$ISTHISWSL" == "1" ]; then
	echo "Asking sudo password for updating the timezone manually..."
	sudo ln -sf /usr/share/zoneinfo/$CONTINENTS/$LOCATION /etc/localtime &>> $REALLOGGER
	sudo hwclock --systohc &>> $REALLOGGER
fi

# DEFCONFIG
DEFCONFIG=sweet_defconfig
VENDEFCONFIG=sweet_user_defconfig

# Playground clang
NOTHAVECLANG=1
CLANG_DIR="clang"
REALCLANG_DIR="$(pwd)"/${CLANG_DIR}
if [ "$NOTHAVECLANG" == "1" ]; then
	echo "Cloning Playground clang from PixelOS Repository..."
	git clone --depth=1 -b 17 https://gitlab.com/PixelOS-Devices/playgroundtc.git $CLANG_DIR &>> $REALLOGGER
fi
echo "Setting up proper permissions to clang and export it to PATH..."
sudo chmod 755 -R $REALCLANG_DIR &>> $REALLOGGER
export PATH="$REALCLANG_DIR/bin:$PATH"

# Variables
export KBUILD_BUILD_USER="$USER"
export KBUILD_BUILD_HOST="$HOSTNAME"
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

# KernelSU support
KSU=1
if [ "$KSU" == "1" ]; then
	echo "Enabling KernelSU support..."
	rm -rf KernelSU &>> $REALLOGGER
	cd drivers
	rm -rf kernelsu &>> $REALLOGGER
	cd ..
	git clone https://github.com/tiann/KernelSU &>> $REALLOGGER
	cd drivers
	ln -sf ../KernelSU/kernel kernelsu &>> $REALLOGGER
	cd ..
	sed -i '/endmenu/i source "drivers/kernelsu/Kconfig"' drivers/Kconfig
	sed -i 's/# CONFIG_KSU is not set/CONFIG_KSU=y/g' arch/arm64/configs/vendor/$VENDEFCONFIG
else
	echo "KernelSU support is disabled, skipping..."
	rm -rf KernelSU &>> $REALLOGGER
	cd drivers
	rm -rf kernelsu &>> $REALLOGGER
	cd ..
	sed -i '/source "drivers\/kernelsu\/Kconfig"/d' drivers/Kconfig
	sed -i 's/CONFIG_KSU=y/# CONFIG_KSU is not set/g' arch/arm64/configs/vendor/$VENDEFCONFIG
fi

# LN8000 Toggles
LN8K=1
if [ "$LN8K" == "1" ]; then
	echo "Enabling LN8000 support..."
	sed -i 's/# CONFIG_CHARGER_LN8000 is not set/CONFIG_CHARGER_LN8000=y/g' arch/arm64/configs/vendor/$VENDEFCONFIG
else
	echo "Disabling LN8000 support..."
	sed -i 's/CONFIG_CHARGER_LN8000=y/# CONFIG_CHARGER_LN8000 is not set/g' arch/arm64/configs/vendor/$VENDEFCONFIG
fi

# LTO Toggles
LTO=0
if [ "$LTO" == "1" ]; then
	echo "Enabling LTO support... (Requires min. 32GB of RAM)"
	sed -i 's/# CONFIG_LTO is not set/CONFIG_LTO=y/g' arch/arm64/configs/vendor/$VENDEFCONFIG
	sed -i 's/# CONFIG_LTO_CLANG is not set/CONFIG_LTO_CLANG=y/g' arch/arm64/configs/vendor/$VENDEFCONFIG
	sed -i 's/CONFIG_LTO_NONE=y/# CONFIG_LTO_NONE is not set/g' arch/arm64/configs/vendor/$VENDEFCONFIG
else
	echo "Disabling LTO support..."
	sed -i 's/CONFIG_LTO=y/# CONFIG_LTO is not set/g' arch/arm64/configs/vendor/$VENDEFCONFIG
	sed -i 's/CONFIG_LTO_CLANG=y/# CONFIG_LTO_CLANG is not set/g' arch/arm64/configs/vendor/$VENDEFCONFIG
	sed -i 's/# CONFIG_LTO_NONE is not set/CONFIG_LTO_NONE=y/g' arch/arm64/configs/vendor/$VENDEFCONFIG
fi

# Cleanup
echo "Cleaning up out directory..."
rm -rf out
mkdir out
rm -rf error.log

# Compile
echo "Compiling the kernel..."
make -j16 O=out clean &>> $REALLOGGER
make -j16 O=out mrproper &>> $REALLOGGER
make -j16 O=out $DEFCONFIG &>> $REALLOGGER
make -j16 O=out &>> $REALLOGGER

# Pack it up
ANYKRANUL=1
DATESTAPLE=`date +%Y%m%d-%H%M`
if [ "$ANYKRANUL" == "1" ]; then
	echo "Packing up with AnyKernel3..."
	rm -rf AnyKernel3
	git clone https://github.com/osm0sis/AnyKernel3 &>> $REALLOGGER
	rm -rf AnyKernel3/modules
	rm -rf AnyKernel3/patch
	rm -rf AnyKernel3/ramdisk
	rm -rf AnyKernel3/LICENSE
	rm -rf AnyKernel3/README.md
	cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3/Image.gz-dtb
	cp out/arch/arm64/boot/dtb.img AnyKernel3/dtb.img
	cp out/arch/arm64/boot/dtbo.img AnyKernel3/dtbo.img
	sed -i 's/^kernel.string=.*/kernel.string=/' AnyKernel3/anykernel.sh
	sed -i '/^device.name3=.*/d' AnyKernel3/anykernel.sh
	sed -i '/^device.name4=.*/d' AnyKernel3/anykernel.sh
	sed -i '/^device.name5=.*/d' AnyKernel3/anykernel.sh
	sed -i 's/device.name1=.*/device.name1=sweet/' AnyKernel3/anykernel.sh
	sed -i 's/device.name2=.*/device.name2=sweetin/' AnyKernel3/anykernel.sh
	sed -i 's/supported.versions=.*/supported.versions=11-14/' AnyKernel3/anykernel.sh
	sed -i 's/\/dev\/block\/platform\/omap\/omap_hsmmc.0\/by-name\/boot/\/dev\/block\/by-name\/boot/' AnyKernel3/anykernel.sh
	sed -i 's/backup_file/\# backup_file/' AnyKernel3/anykernel.sh
	sed -i 's/^replace_string init.rc.*/\# &/' AnyKernel3/anykernel.sh
	sed -i 's/^\(insert_line .*\)$/\# \1/' AnyKernel3/anykernel.sh
	sed -i 's/^\(append_file .*\)$/\# \1/' AnyKernel3/anykernel.sh
	sed -i 's/^patch_fstab.*/\# &/' AnyKernel3/anykernel.sh
	if [ "$KSU" == "1" ]; then
		cd AnyKernel3
		zip -r -9 aghisnarx-ksu-aosp-$DATESTAPLE-$DEFCONFIG.zip META-INF tools anykernel.sh Image.gz-dtb dtb.img dtbo.img &>> $REALLOGGER
		rm -rf dtbo.img
		cp ../blobs/miui-dtbo.img dtbo.img
		zip -r -9 aghisnarx-ksu-miui-$DATESTAPLE-$DEFCONFIG.zip META-INF tools anykernel.sh Image.gz-dtb dtb.img dtbo.img &>> $REALLOGGER
		echo "Build is located at: AnyKernel3/aghisnarx-ksu-aosp-$DATESTAPLE-$DEFCONFIG.zip, AnyKernel3/aghisnarx-ksu-miui-$DATESTAPLE-$DEFCONFIG.zip"
		cd ..
	else
		cd AnyKernel3
		zip -r -9 aghisnarx-noksu-aosp-$DATESTAPLE-$DEFCONFIG.zip META-INF tools anykernel.sh Image.gz-dtb dtb.img dtbo.img &>> $REALLOGGER
		rm -rf dtbo.img
		cp ../blobs/miui-dtbo.img dtbo.img
		zip -r -9 aghisnarx-noksu-miui-$DATESTAPLE-$DEFCONFIG.zip META-INF tools anykernel.sh Image.gz-dtb dtb.img dtbo.img &>> $REALLOGGER
		echo "Build is located at: AnyKernel3/aghisnarx-noksu-aosp-$DATESTAPLE-$DEFCONFIG.zip, AnyKernel3/aghisnarx-noksu-miui-$DATESTAPLE-$DEFCONFIG.zip"
		cd ..
	fi
else
	rm -rf AnyKernel3
	echo "Build is located at: out/arch/arm64/boot/Image.gz-dtb, out/arch/arm64/boot/dtb.img, out/arch/arm64/boot/dtbo.img"
fi
