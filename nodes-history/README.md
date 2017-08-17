# Testbed nodes history viewer

This offers a very simple, web-based viewer for the historical availability of
testbed nodes as a series of time-based events.  It is based on the package
[EventDrops](https://github.com/marmelab/EventDrops).

Nodes are named using the first letter of their owner (or ``?`` if unknown)
and the first fragment of their UUID.

You need to install package dependencies first using NPM in this directory
(you only need to do it once):

    $ npm install

## Usage

 1. Get nodes history data with the ``admin`` tool:

        testbed_server$ /path/to/admin nodes_history > nodes-history.txt

 2. Download the result and convert it to JSON:

        $ python nh2ed.py /path/to/nodes-data.json < nodes-history.txt > nodes-history.json

 3. Publish ``index.html``, ``nodes-history.json``, ``d3.js`` and ``eventDrops.js``,
    or just open ``index.html`` locally.
