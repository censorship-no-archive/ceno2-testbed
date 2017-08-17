#!/usr/bin/env python

# Convert ``admin nodes_history`` output in stdin
# to public EventDrops 0.2 input JSON data in stdout,
# according to static node data JSON file given as an argument::
#
#     $ SCRIPT nodes-data.json < nodes-history.txt > nodes-history.json

import json
import re
import sys

from collections import defaultdict


"""The minimum number of different dates where a node must appear."""
MIN_DATES = 5


def parseNodesData(data_path):
    """Parse the JSON file at `data_path` and return a mapping from node id to node data."""
    with open(data_path) as f:
        data = json.loads(f.read())
    return defaultdict(dict, {n['id']: n for n in data})  # return empty dict for unknown nodes


def main():
    nid2data = parseNodesData(sys.argv[1])

    nid2dates = defaultdict(list)
    for line in sys.stdin:
        if line.startswith('#'):
            continue
        (date, node_id) = line.split()
        nid2dates[node_id].append(date)

    # Node with id A-B-C-D-E owned by Someone becomes "S A".
    ed_data = [{'name': '%s %s' % (nid2data[nid].get('owner', '?')[0], nid.split('-')[0]), 'dates': dates}
               for (nid, dates) in nid2dates.items()
               if not nid2data[nid].get('blacklist_reason') and len(set(dates)) >= MIN_DATES]
    ed_data.sort(key=lambda x: x['name'])
    sys.stdout.write(json.dumps(ed_data))

if __name__ == '__main__':
    main()
