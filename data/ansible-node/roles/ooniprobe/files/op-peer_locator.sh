#!/bin/sh

# Load our own config
. /usr/local/etc/ooniconf.sh
. "${PROBE_VENV}/bin/activate"

TEST=ooni.nettests.experimental.peer_locator_test
TEST_FILE=$(python -c "import $TEST as m; print(m.__file__)" | sed 's/py.$/py/')

for BACKEND in $PROBE_BACKENDS; do
  python -m ooni.scripts.ooniprobe -n "$TEST_FILE" \
      --backend="$BACKEND" \
      --peer_list="$PROBE_PEERLIST" \
      --http_port=random \
      "$@"
done
