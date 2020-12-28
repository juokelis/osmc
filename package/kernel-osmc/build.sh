
# (c) 2014-2015 Sam Nazarko
# email@samnazarko.co.uk

#!/bin/bash

# initramfs flags

INITRAMFS_BUILD=1
INITRAMFS_EMBED=2
INITRAMFS_NOBUILD=4

. ../common.sh
test $1 == rbp1 && VERSION="4.19.122" && REV="2" && FLAGS_INITRAMFS=$(($INITRAMFS_BUILD + $INITRAMFS_EMBED)) && IMG_TYPE="zImage"
test $1 == rbp2 && VERSION="5.10.3" && REV="1" && FLAGS_INITRAMFS=$(($INITRAMFS_BUILD + $INITRAMFS_EMBED)) && IMG_TYPE="zImage"
test $1 == rbp464 && VERSION="5.10.3" && REV="1" && FLAGS_INITRAMFS=$(($INITRAMFS_BUILD + $INITRAMFS_EMBED)) && IMG_TYPE="zImage"
test $1 == vero2 && VERSION="3.10.105" && REV="13" && FLAGS_INITRAMFS=$(($INITRAMFS_BUILD)) && IMG_TYPE="uImage"
test $1 == pc && VERSION="4.2.3" && REV="16" && FLAGS_INITRAMFS=$(($INITRAMFS_BUILD + $INITRAMFS_EMBED)) && IMG_TYPE="zImage"
test $1 == vero364 && VERSION="4.9.113" && REV="28" && FLAGS_INITRAMFS=$(($INITRAMFS_BUILD)) && IMG_TYPE="zImage"
if [ $1 == "rbp1" ] || [ $1 == "rbp2" ] || [ $1 == "rbp464" ] || [ $1 == "pc" ]
then
	if [ -z $VERSION ]; then echo "Don't have a defined kernel version for this target!" && exit 1; fi
	MAJOR=$(echo ${VERSION:0:1})
	DL_VERSION=${VERSION}
	VERSION_POINT_RLS=$(echo ${VERSION} | cut -d . -f 3)
	if [ "$VERSION_POINT_RLS" -eq 0 ]
	then
	    DL_VERSION=$(echo ${VERSION:0:3})
	fi
	SOURCE_LINUX="https://www.kernel.org/pub/linux/kernel/v${MAJOR}.x/linux-${DL_VERSION}.tar.xz"
fi
if [ $1 == "vero2" ]; then SOURCE_LINUX="https://github.com/osmc/vero2-linux/archive/master.tar.gz"; fi
if [ $1 == "vero364" ]; then SOURCE_LINUX="https://github.com/osmc/vero3-linux/archive/osmc-openlinux-4.9.tar.gz"; fi
pull_source "${SOURCE_LINUX}" "$(pwd)/src"
# We need to download busybox and e2fsprogs here because we run initramfs build within chroot and can't pull_source in a chroot
if ((($FLAGS_INITRAMFS & $INITRAMFS_NOBUILD) != $INITRAMFS_NOBUILD))
then
	. initramfs-src/VERSIONS
	pull_source "https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2" "$(pwd)/initramfs-src/busybox"
	pull_source "https://www.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v${E2FSPROGS_VERSION}/e2fsprogs-${E2FSPROGS_VERSION}.tar.gz" "$(pwd)/initramfs-src/e2fsprogs"
        if [ "$1" == "vero2" ] || [ "$1" == "vero364" ]
	then
	    pull_source "https://mirrors.kernel.org/sourceware/lvm2/LVM2.${LVM_VERSION}.tgz" "$(pwd)/initramfs-src/lvm2"
	fi
fi
if [ $? != 0 ]; then echo -e "Error downloading" && exit 1; fi
# Build in native environment
BUILD_OPTS=$BUILD_OPTION_DEFAULTS
BUILD_OPTS=$(($BUILD_OPTS - $BUILD_OPTION_USE_NOFP))
build_in_env "${1}" $(pwd) "kernel-osmc" "$BUILD_OPTS"
build_return=$?
if [ $build_return == 99 ]
then
	echo -e "Building Linux kernel"
	make clean
	sed '/Package/d' -i files/DEBIAN/control
	sed '/Depends/d' -i files/DEBIAN/control
	update_sources
	handle_dep "kernel-package-osmc"
	handle_dep "libssl-dev"
	handle_dep "liblz4-tool"
	handle_dep "cpio"
	handle_dep "bison"
	handle_dep "flex"
	handle_dep "rsync"
	handle_dep "openssl"
        if [ "$1" == "vero2" ]  || [ "$1" == "vero364" ]
        then
	    handle_dep "python"
        fi
	if [ "$1" == "vero2" ]; then handle_dep "u-boot-tools"; fi
	export KPKG_MAINTAINER="Sam G Nazarko"
	export KPKG_EMAIL="email@samnazarko.co.uk"
	JOBS=$(if [ ! -f /proc/cpuinfo ]; then mount -t proc proc /proc; fi; cat /proc/cpuinfo | grep processor | wc -l && umount /proc/ >/dev/null 2>&1)
	pushd src/*linux*
	if [ "$1" == "rbp1" ] || [ "$1" == "rbp2" ] || [ "$1" == "rbp464" ]
	then
		install_patch "../../patches" "rbp"
	fi
	install_patch "../../patches" "${1}"
        if [ "$1" == "rbp1" ] || [ "$1" == "rbp2" ] || [ "$1" == "rbp464" ]
        then
                # We have to do this here separately because we need .config present first
                ./scripts/config --set-val CONFIG_ARM64_TLB_RANGE y
                ./scripts/config --set-val ARM64_PTR_AUTH y
                ./scripts/config --set-val CONFIG_KASAN n
                ./scripts/config --set-val CONFIG_KCOV n
        fi
	# Set up DTC
	$BUILD scripts
	DTC=$(pwd)"/scripts/dtc/dtc"
	# Conver DTD to DTB
	if [ "$1" == "vero2" ]
	then
		$BUILD meson8b_vero2.dtd
		$BUILD meson8b_vero2.dtb
	fi
	if [ "$1" == "vero364" ] || [ "$1" == "rbp464" ]
	then
		export kimage=vmlinuz
		export target=Image.gz
		export NEED_DIRECT_GZIP_IMAGE=YES
		export kimagesrc=arch/arm64/boot/Image
		export kimagedest=$(pwd)/vmlinuz
		export kelfimagedest=$(pwd)/vmlinux
		export KERNEL_ARCH=arm64
	fi
        if [ "$1" == "vero364" ]
	then
		$BUILD vero3_2g_16g.dtb || $BUILD vero3_2g_16g.dtb
		$BUILD vero3plus_2g_16g.dtb || $BUILD vero3plus_2g_16g.dtb
	fi
	# Initramfs time
	if ((($FLAGS_INITRAMFS & $INITRAMFS_NOBUILD) != $INITRAMFS_NOBUILD))
	then
		echo "This device requests an initramfs"
		pushd ../../initramfs-src
		DEVICE="$1" $BUILD kernel
		if [ $? != 0 ]; then echo "Building initramfs failed" && exit 1; fi
		popd
		if ((($FLAGS_INITRAMFS & $INITRAMFS_EMBED) == $INITRAMFS_EMBED))
		then
			echo "This device requests an initramfs to be embedded"
			export RAMFSDIR=$(pwd)/../../initramfs-src/target
		else
			echo "This device requests an initramfs to be built, but not embedded"
			pushd ../../initramfs-src/target
			find . | cpio -H newc -o | gzip - > ../initrd.img.gz
			popd
		fi
	fi
	if [ "$IMG_TYPE" == "zImage" ] || [ -z "$IMG_TYPE" ]; then make-kpkg --stem $1 kernel_image --append-to-version -${REV}-osmc --jobs $JOBS --revision $REV; fi
	if [ "$IMG_TYPE" == "uImage" ]; then make-kpkg --uimage --stem $1 kernel_image --append-to-version -${REV}-osmc --jobs $JOBS --revision $REV; fi
	if [ $? != 0 ]; then echo "Building kernel image package failed" && exit 1; fi
	make-kpkg --stem $1 kernel_headers --append-to-version -${REV}-osmc --jobs $JOBS --revision $REV
	if [ $? != 0 ]; then echo "Building kernel headers package failed" && exit 1; fi
	make-kpkg --stem $1 kernel_source --append-to-version -${REV}-osmc --jobs $JOBS --revision $REV
	if [ $? != 0 ]; then echo "Building kernel source package failed" && exit 1; fi
	# Make modules directory
	mkdir -p ../../files-image/lib/modules/${VERSION}-${REV}-osmc/kernel/drivers
	if [ "$1" == "rbp1" ] || [ "$1" == "rbp2" ] || [ "$1" == "rbp464" ]; then mkdir -p ../../files-image/boot/dtb-${VERSION}-${REV}-osmc/overlays; fi
	if [ "$1" == "vero2" ]; then mkdir -p ../../files-image/boot; fi
        if [ "$1" == "rbp1" ] || [ "$1" == "rbp2" ] || [ "$1" == "rbp464" ]
        then
                $BUILD dtbs
                mv arch/arm/boot/dts/*.dtb ../../files-image/boot/dtb-${VERSION}-${REV}-osmc/
                mv arch/arm64/boot/dts/broadcom/*.dtb ../../files-image/boot/dtb-${VERSION}-${REV}-osmc/
                mv arch/arm*/boot/dts/overlays/*.dtbo ../../files-image/boot/dtb-${VERSION}-${REV}-osmc/overlays
                mv arch/arm/boot/dts/overlays/README ../../files-image/boot/dtb-${VERSION}-${REV}-osmc/overlays
        fi
	if [ "$1" == "vero" ]
	then
		make imx6dl-vero.dtb
		mv arch/arm/boot/dts/*.dtb ../../files-image/boot/dtb-${VERSION}-${REV}-osmc/
	fi
	if [ "$1" == "vero2" ]
	then
		# Special packaging for Android
                ./scripts/mkbootimg --kernel arch/arm/boot/uImage --ramdisk ../../initramfs-src/initrd.img.gz --second arch/arm/boot/dts/amlogic/meson8b_vero2.dtb --output ../../files-image/boot/kernel-${VERSION}-${REV}-osmc.img
		if [ $? != 0 ]; then echo "Building Android image for Vero 2 failed" && exit 1; fi
	fi
	if [ "$1" == "vero364" ]
        then
		mkdir -p ../../files-image/boot #hack
                # Special packaging for Android
		./scripts/multidtb/multidtb -p scripts/dtc/ -o multi.dtb arch/arm64/boot/dts/amlogic --verbose --page-size 2048
		./scripts/mkbootimg --kernel arch/arm64/boot/Image.gz --base 0x0 --kernel_offset 0x1080000 --ramdisk ../../initramfs-src/initrd.img.gz --second multi.dtb --output ../../files-image/boot/kernel-${VERSION}-${REV}-osmc.img
                if [ $? != 0 ]; then echo "Building Android image for Vero 3 failed" && exit 1; fi
		# Hacks for lack of ARM64 native in kernel-package for Jessie
		cp -ar vmlinuz ../../files-image/boot/vmlinuz-${VERSION}-${REV}-osmc
		# Device tree for uploading to eMMC
		cp -ar multi.dtb ../../files-image/boot/dtb-${VERSION}-${REV}-osmc.img
        fi
	if [ "$1" == "rbp464" ]
	then
		# For Aarch64 we need to ensure installation on target
		cp -ar vmlinuz ../../files-image/boot/vmlinuz-${VERSION}-${REV}-osmc
	fi
	# Add out of tree modules that lack a proper Kconfig and Makefile
	# Fix CPU architecture
	ARCH=$(arch)
    echo $ARCH | grep -q arm
    if [ $? == 0 ]
	then
	    ARCH=$(echo $ARCH | tr -d v7l | tr -d v6)
	fi
	if [ $ARCH == "i686" ]; then ARCH="i386"; fi
	if [ "$1" == "vero364" ]; then ARCH=arm64; fi
	if [ "$1" == "rbp464" ]; then ARCH=arm64; fi
	export ARCH
		if [ "$1" == "vero2" ]
		then
		# Build RTL8812AU module
		pushd drivers/net/wireless/rtl8812au
		$BUILD
		if [ $? != 0 ]; then echo "Building kernel module failed" && exit 1; fi
		popd
		mkdir -p ../../files-image/lib/modules/${VERSION}-${REV}-osmc/kernel/drivers/net/wireless/
		strip --strip-unneeded drivers/net/wireless/rtl8812au/*8812au.ko
		cp drivers/net/wireless/rtl8812au/*8812au.ko ../../files-image/lib/modules/${VERSION}-${REV}-osmc/kernel/drivers/net/wireless/
		fi
		if [ "$1" == "rbp1" ] || [ "$1" == "rbp2" ] || [ "$1" == "vero2" ]
		then
                # Build MT7610U model
                pushd drivers/net/wireless/mt7610u
                $BUILD
                if [ $? != 0 ]; then echo -e "Building kernel module failed" && exit 1; fi
                popd
                mkdir -p ../../files-image/lib/modules/${VERSION}-${REV}-osmc/kernel/drivers/net/wireless/
		strip --strip-unneeded drivers/net/wireless/mt7610u/os/linux/mt7610u_sta.ko
                cp drivers/net/wireless/mt7610u/os/linux/mt7610u_sta.ko ../../files-image/lib/modules/${VERSION}-${REV}-osmc/kernel/drivers/net/wireless/
                fi
        if [ "$1" == "vero364" ]
	then
		# Build V4L2 modules for Vero 4K
		$BUILD M=drivers/osmc/media_modules CONFIG_AMLOGIC_MEDIA_VDEC_OSMC=m
		mkdir -p ../../files-image/lib/modules/${VERSION}-${REV}-osmc/kernel/drivers/osmc
		for file in $(find drivers/osmc/media_modules/ -name "*.ko"); do cp $file ../../files-image/lib/modules/${VERSION}-${REV}-osmc/kernel/drivers/osmc; done
		# Build OpTEE modules for secureOSMC
		$BUILD M=drivers/osmc/secureosmc
		mkdir -p ../../files-image/lib/modules/${VERSION}-${REV}-osmc/kernel/drivers/osmc/secureosmc
		cp drivers/osmc/secureosmc/optee/optee_armtz.ko ../../files-image/lib/modules/${VERSION}-${REV}-osmc/kernel/drivers/osmc/secureosmc
		cp drivers/osmc/secureosmc/optee.ko ../../files-image/lib/modules/${VERSION}-${REV}-osmc/kernel/drivers/osmc/secureosmc
	fi
	# Unset architecture
	ARCH=$(arch)
	export ARCH
	popd
	# Move all of the Debian packages so they are where we would expect them
	mv src/${1}-*.deb .
	# Disassemble kernel image package to add device tree overlays, additional out of tree modules etc
	dpkg -x ${1}-image*.deb files-image/
	dpkg-deb -e ${1}-image*.deb files-image/DEBIAN
	if [ "$1" == "vero364" ]; then sed -ie 's/^Depends:.*$/&, vero3-bootloader-osmc:armhf (>= 1.0.0)/g' files-image/DEBIAN/control; fi
	rm ${1}-image*.deb
	dpkg_build files-image ${1}-image-${VERSION}-${REV}-osmc.deb
	# Disassemble kernel headers package to include full headers (upstream Debian bug...)
	if [ "$ARCH" == "armv7l" ]
	then
		mkdir -p files-headers/
		dpkg -x ${1}-headers*.deb files-headers/
		dpkg-deb -e ${1}-headers*.deb files-headers/DEBIAN
		rm ${1}-headers*.deb
		cp -ar src/*linux*/arch/arm/include/ files-headers/usr/src/*-headers-${VERSION}-${REV}-osmc/include
		dpkg_build files-headers ${1}-headers-${VERSION}-${REV}-osmc.deb
	fi
	echo "Package: ${1}-kernel-osmc" >> files/DEBIAN/control
	echo "Depends: ${1}-image-${VERSION}-${REV}-osmc" >> files/DEBIAN/control
	fix_arch_ctl "files/DEBIAN/control"
	dpkg_build files/ ${1}-kernel-${VERSION}-${REV}-osmc.deb
	build_return=$?
fi
teardown_env "${1}"
exit $build_return
