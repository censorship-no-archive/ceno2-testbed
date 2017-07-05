#!/bin/sh
tar xjf "transmission-2.92+-modified.tar.bz2"
cd "transmission-2.92+"
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/opt/transmission -DENABLE_CLI=true -DENABLE_DAEMON=false -DENABLE_TESTS=false -DENABLE_UTILS=false -DENABLE_GTK=OFF -DENABLE_QT=OFF
make
make install
cd ../..
install -m 0644 debian-8.8.0-amd64-CD-1.iso.torrent /opt/transmission
install -m 0644 NOOBS_lite_v2_4.zip.torrent /opt/transmission
install -m 0755 run-test.sh /opt/transmission
