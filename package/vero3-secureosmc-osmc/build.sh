# (c) 2014-2015 Sam Nazarko
# email@samnazarko.co.uk

#!/bin/bash

. ../common.sh

echo -e "Building package vero3-secureosmc-osmc"
make clean
dpkg_build files/ vero3-secureosmc-osmc.deb
