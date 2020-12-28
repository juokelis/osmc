# (c) 2014-2015 Sam Nazarko
# email@samnazarko.co.uk

#!/bin/bash

. ../common.sh
pull_source "https://src.fedoraproject.org/repo/pkgs/lirc/lirc-0.9.4c.tar.gz/a7c17a7ec11756e0278d31e8d965a384/lirc-0.9.4c.tar.gz" "$(pwd)/src"
if [ $? != 0 ]; then echo -e "Error downloading" && exit 1; fi
# Build in native environment
build_in_env "${1}" $(pwd) "lirc-osmc"
build_return=$?
if [ $build_return == 99 ]
then
	echo -e "Building LIRC"
	out=$(pwd)/files
	make clean
	sed '/Package/d' -i files/DEBIAN/control
	update_sources
	handle_dep "libusb-dev"
	handle_dep "autoconf"
	handle_dep "automake"
	handle_dep "libtool"
	handle_dep "xsltproc"
	handle_dep "pkg-config"
	handle_dep "python3-dev"
	echo "Package: ${1}-lirc-osmc" >> files/DEBIAN/control
	pushd src/lirc-*
	install_patch "../../patches" "all"
	autoreconf -vif .
	SH_PATH=/bin/sh ./configure --prefix=/usr --without-x
	$BUILD
	make install DESTDIR=${out}
	if [ $? != 0 ]; then echo "Error occured during build" && exit 1; fi
	strip_files "${out}"
	popd
	fix_arch_ctl "files/DEBIAN/control"
	dpkg_build files/ ${1}-lirc-osmc.deb
	build_return=$?
fi
teardown_env "${1}"
exit $build_return
