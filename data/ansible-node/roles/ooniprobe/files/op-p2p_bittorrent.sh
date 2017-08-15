#!/bin/sh

# Load our own config
. /usr/local/etc/ooniconf.sh
. "${PROBE_VENV}/bin/activate"

TEST=ooni.nettests.experimental.p2p_bittorrent_test
TEST_FILE=$(python -c "import $TEST as m; print(m.__file__)" | sed 's/py.$/py/')

python -m ooni.scripts.ooniprobe -n "$TEST_FILE" "$@"
