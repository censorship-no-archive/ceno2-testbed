#!/bin/sh

# Load our own config
. /usr/local/etc/ooniconf.sh

cd "$PROBE_SRC"

. "${PROBE_VENV}/bin/activate"

for BACKEND in $PROBE_BACKENDS; do
  python ooni/scripts/ooniprobe.py -n \
    ooni/nettests/experimental/peer_locator_test.py \
      --backend "$BACKEND" \
      --peer_list="$PROBE_PEERLIST" \
      --http_port=random
done
