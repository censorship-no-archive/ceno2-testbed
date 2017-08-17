# Testbed nodes history viewer

 1. Install EventDrops:

        $ npm install event-drops

 2. Get nodes history data with the ``admin`` tool:

        testbed_server$ /path/to/admin nodes_history > nodes-history.txt

 3. Download the result and convert it to JSON:

        $ python nh2ed.py /path/to/nodes-data.json < nodes-history.txt > nodes-history.json

 4. Publish ``index.html``, ``nodes-history.json``, ``d3.js`` and ``eventDrops.js``.
