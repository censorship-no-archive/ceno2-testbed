#!/usr/bin/env python

HTML_FORM = """\
<!DOCTYPE html>
<form method="post">
  <label for="addrs">Addresses</label>
  <textarea name="addrs" autofocus id="addrs" placeholder="Please enter address lines." rows="5" style="width:100%"></textarea>
  <input type="submit" value="Set">
</form>
"""

import cgi
import re
import subprocess
import sys
import tempfile

from BaseHTTPServer import HTTPServer, BaseHTTPRequestHandler


# Regular expression for Tor bridge line: "TRANSPORT IP:PORT FINGERPRINT [FLAGS]".
_bridge_re = re.compile(
    r'^\s*(?P<transport>[a-z0-9]+)'
    '\s+(?P<addr>[0-9a-fA-F\.:\[\]]+:[0-9]+)'
    '\s+(?P<fpr>[0-9a-fA-F]+)'
    '\s*(?P<flags>.*?)?\s*$')

def parse_bridge_addrs(addrs_in):
    """Return a processed list of Tor bridge addresses from the given text.

    `addrs_in` has the format used by bridges.torproject.org.  The returned
    value is a list of (transport, ip:port, fingerprint, flags) tuples.
    """
    addrs = []
    lines = addrs_in.splitlines()
    for line in lines:
        line = line.strip()
        if not line:  # empty line
            continue
        match = _bridge_re.match(line)
        if not match:
            raise ValueError("invalid line: %s" % line)
        addrs.append(match.groups())
    return addrs

def enable_bridges(addrs):
    with tempfile.NamedTemporaryFile() as tmpf:
        for addr in addrs:
            tmpf.write('Bridge ' + ' '.join(addr) + '\n')
        tmpf.flush()
        subprocess.check_call(['tor-bridges-enable', tmpf.name])

class TorBridgesRH(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(HTML_FORM)

    def do_POST(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        # https://stackoverflow.com/a/25091973
        try:
            form = cgi.FieldStorage(fp=self.rfile, headers=self.headers,
                                    environ={'REQUEST_METHOD': 'POST'})
            addrs_in = form.getfirst('addrs', '')
            addrs = parse_bridge_addrs(addrs_in)
            enable_bridges(addrs)
        except Exception as e:
            self.wfile.write("ERROR: %s" % cgi.escape(str(e)))
            self.wfile.write("<br>No changes performed.")
            raise
        else:
            self.wfile.write("OK, addresses set.")

def main():
    try:
        full_addr = sys.argv[1]
        (addr, port) = full_addr.split(':')
        port = int(port)
    except Exception:
        sys.stderr.write("Usage: SCRIPT [ADDRESS]:PORT\n")
        sys.exit(1)
    server = HTTPServer((addr, port), TorBridgesRH)
    server.serve_forever()
    server.server_close()


if __name__ == '__main__':
    main()
