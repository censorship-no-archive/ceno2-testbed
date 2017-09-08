# The CENO2 testbed

## Introduction

The CENO2 project intends to create a system for web content distribution that
can avoid several forms of network interference and censorship.  To identify
particular forms of interference that may negatively affect or invalidate the
system in some scenarios, the Project has developed the **CENO2 testbed**.

This testbed attempts to measure network filtering around deployed **testbed
nodes**.  Nodes participate in a group running a series of network tests
covering different connectivity scenarios with servers in censorship-free zones
and other nodes running similar tests in the same potentially censored zone.
Normal client-server as well as peer-to-peer communication protocols are used to
compare how all of the nodes behave and detect possible interference (like
traffic throttling or filtering).

Nodes are dedicated computers, although they usually are virtual machines (VMs)
which run without access to the hosting computer's files, with very little
impact on system installation and with a constrained resource usage.  For a
technical description of nodes, see [Creating a testbed node](node.md).

A series of **testbed servers** help coordinate, manage and maintain the
testbed.  They also collect test results and provide useful services to nodes.
Services provided by all servers include VPN and tunnel endpoints that help
nodes and servers reach one another at the network level regardless of NAT and
limiting the impact of protocol blocking or throttling.

There are two types of servers: **collectors** and **jumpers**.  Collectors run
an *OONI collector*, whereas jumpers run a reverse proxy to a collector.
Jumpers are only here to increase chances that a collector can be reached.  For
a technical description of servers, see
[Server infrastructure for the testbed](servers.md).

### Why a new testbed?

Some testbeds like [OONI](https://ooni.torproject.org/),
[M-Lab](https://www.measurementlab.net/) and
[RIPE Atlas](https://atlas.ripe.net/) (plus related measurement efforts) already
provide information about network interference.  However, they mostly target
traditional *client-server access* to popular services, while our main interest
lies on checking *peer-to-peer connectivity* between nodes, which may be more
important for the CENO2 model, especially in scenarios where an actor can
completely block access to the Internet.

The difficulty of running P2P tests caused by the very design of those testbeds
(which give no importance or block on purpose access to other participants)
prompted us to develop our own testbed architecture.  We have however tried to
reuse code of those testbeds (like OONI's collector and probe) where possible.

### Remote administration

Remote administration is supported by several *permanent VPNs* run by nodes in
order to avoid NAT and reduce the impact of network interference.  They include
[cjdns](https://github.com/cjdelisle/cjdns) and
[OnionCat](https://www.onioncat.org/), which support multiple servers and allow
nodes to safely generate their own address with little risk of clashing with
others.  These make them adequate against network blocking and for unattended
autoconfiguration of nodes.

Besides VPNs, *temporary tunnels* (based on [OpenVPN](https://openvpn.net/) and
PPP over TLS and SSH) are set on occasion to further improve the chances of
contacting servers during certain operations.

Nodes allow SSH login as ``root`` using a common *testbed administration key*,
which is only used when manual intervention is needed in a node.  At the same
time, all nodes share the same ``root`` SSH key so that they can retrieve
assorted files from servers.

A *remote maintenance script* is periodically retrieved from servers by nodes
(via HTTP over VPN or tunnel), and executed to perform various tasks after the
initial deployment, like pushing hotfixes and downloading and applying
[Ansible](https://www.ansible.com/) playbooks that help further configuration of
a node.  When downloading the script, nodes also report their local, VPN and
public IP addresses to servers for management purposes.

The Ansible configuration can be used to put the testbed into *dormant state*,
in which minimal VPN connectivity is provided and the execution of tests is
disabled so that nodes have very low resource requirements.  Nodes still
periodically report their addresses and run the maintenance script, which allows
to use Ansible to bring the testbed back from dormant state into active state so
that tests can run again.

### The simulator

We have also developed a simple [simulator][].  Its main purpose is to reproduce
in a controlled environment the network interference conditions observed with
the testbed, so that different technologies related with CENO2 may be tested
under these conditions.

[simulator]: https://github.com/equalitie/ceno2-simulator/
    "CENO2 simulator: An LXC-based censorship simulation infrastructure for P2P networks"

The simulator runs on a single GNU/Linux host as a set of very lightweight
containers (LXC).  Each container only has network access to the host, which
routes traffic among containers.  This setup enables the host to manage and
manipulate testbed traffic at will and to apply various forms of network
interference observed in real-life scenarios.

Containers can be eiter **censors** or **nodes**.  Their only difference is the
ranges of their network addresses and their file system template.  This is
enough to allow configuring censors as providers of certain network services
(e.g. manipulated DNS or HTTP servers), and to identify node traffic so as to
apply interference to it at the host (using routing, filtering, traffic
control…) or at censors (by routing traffic to them first).  Censor containers
are optional, and nodes act as end-user equipment which runs the software to be
tested.

Nodes are furthermore divided into **Eastern and Western nodes**, which only
differ in their network ranges.  This allows for instance to apply interference
only on Eastern nodes while leaving Western traffic alone.  Those groups are
themselves divided once more in two (**East 0, East 1, West 0, West 1**), which
may help simulate situations inside of the same potentially censored zone like
the (lack of) restrictions between different autonomous systems (AS).  Every
such group must have at least one node, so the minimum number of nodes in a
simulator instance is 4.

Container addresses follow a scheme which helps identify the group of a
container and act accordingly upon its traffic.  Sharing a file system template
among containers allows many of them to run in a single host with little disk
usage.  Finally, a directory is shared between the host and all containers to
ease the proparation of data, the collection of results and the efficient
orchestration of containers (e.g. via simple file system operations and the
``inotify`` subsystem).  These mechanisms enable thestbeds with hundreds of
nodes on affordable hardware.

### Ideal deployment

Since the main motivation of the testbed is testing P2P traffic between nodes,
the ideal deployment should have nodes in *as many different access providers as
possible inside of the same potentially censored zone*, rather than have many
nodes which would complicate maintenance and analysis effort for no gain.
Having *several nodes in existing providers* would also help test intra-provider
connectivity.

Technology-wise, *nodes behind NAT* are especially interesting since such type
of connectivity may represent an important slice of CENO2 infrastructure.  Also,
*providers using different technologies* (e.g. DSL, cable, Wi-Fi, WiMax…) may
help study their impact on our system.

### Studying test results

A minimal number of days should be needed to help confirming the validity of
collected data and perceiving an evolution of trends in interference.

Because of the data collected by tests having a network-oriented topological
nature and belonging to the same potentially censored zone, its analysis and
visualization (using tools like the
[Elastic Stack](https://www.elastic.co/products)) should not have a geographical
focus, but instead revolve around the concept of *Autonomous Systems* (AS) and
internal and external connections among them, and consider the *succession of
news events* to better represent and understand the evolution of network
interference.

### Third-party access to a testbed

The maintainers of a testbed may be interested in letting external participants
run experiments on it.  The following factors must be taken into account:

  - Coordination: Experiments are deployed by updating nodes via remote
    maintenance, so testbed administrators must manually update the maintenance
    script or Ansible playbooks.
  - Resource usage: Testbed experiments use resources from node owners, who may
    be volunteers that might pay for the use of computing or network resources.
  - Code trust: Tests currently run as ``root`` to be able to open certain
    network ports.  This gives the test implementer full control over the node.
  - Report storage: Test reports sent by nodes are collected by a server run by
    testbed administrators.  The only current way to retrieve reports is
    accessing the files with a user with sufficient privileges in the server.

Specifically, experiments are implemented as [OONI][] net tests run by probes in
nodes, with some tests requiring special helpers run by backend servers.  They
are implemented in a custom [OONI probe fork][] and a [OONI backend fork][],
respectively.  This means that currently, to deploy new tests, backend or probe
code needs to be further forked or adapted and redeployed to servers and nodes.
The latter is handled in Ansible playbooks, while the former requires manual
intervention from testbed administrators.

[OONI probe fork]: https://github.com/equalitie/ooni-probe/tree/eq-testbed
[OONI backend fork]: https://github.com/equalitie/ooni-backend/tree/eq-testbed

There is another way of running an additional test in a node, as long as it does
not need explicit support from the backend (i.e. a helper) or testbed servers.
Since a node owner has full access to it, additional OONI net tests can be
installed outside of the OONI probe installation (which may get overwritten with
updates) and run manually or automatically (e.g. using Cron).  When uploading
test reports to the collector server, all reports are included (not just those
of tests in the probe installation).

As a summary, the standard, fully supported addition of new experiments by a
third party requires *close collaboration* with testbed administrators, *code
review and integration*, and a *trust relationship*.

### Future work

Since many P2P systems rely on UDP for data exchange and NAT poses a
considerable handicap on the HTTP reachability test (described below),
additional *UDP reachability tests* should be developed to distinguish when
specific P2P protocols are blocked, or rather all traffic between end-user
equipment inside of the censored zone is being throttled.  Having more
information about this is very important when approaching the creation of a
user-powered, locally cooperating content distribution network.

To support third-party experiments and access to the testbed, some enhancements
could be done to how tests are integrated into the OONI backend and probe.
Decoupling net tests from the OONI probe code base would ease the deployment of
new tests without the need of updating and deploying a fork; ideally, this
should allow to install standard OONI packages (e.g. from Debian repositories).
One additional problem would be tests that require special privileges (like the
peer HTTP reachability test, which may listen on TCP port 80).  Another problem
would be special helpers at the backend, which cannot be integrated easily, but
they can nonetheless be run as completely separated processes.

Regarding access to test reports by third parties, simple HTTP access to the
repository directory (or a subset of their files) could be set up at the
collector server, maybe with simple password-based restrictions.

## Observed interference

The following is a list of techniques of network interference that have been
witnessed (via [OONI][] and others) and that we would like to take into account
for simulation and for verification or testing in real life experiments.

### DNS hijacking

Intercepting DNS requests and forging responses to point to other servers.

In the simulator, this can be performed by using destination NAT to redirect
normal DNS traffic (to UDP port 53 or detected using nDPI) from victim nodes to
another node that serves false DNS information, so that victim nodes still see
replies coming from the expected source address.  This does not work with DNSSEQ
requests or DNSCrypt communications.

This has already been witnessed by OONI, but we need to know whether this also
takes place when both communicating nodes are in the same potentially censored
zone.  Besides OONI's ``dns_consistency`` or ``dns_injection`` tests, a way to
check is to provide client nodes beforehand with the replies expected from the
server nodes, and check what reply it gets when querying the other node for a
name prone to be censored.

### Transparent HTTP proxying

Capturing HTTP requests and returning a different page (probably one indicating
that the requested page isn't accessible or providing an alternative).

In the simulator, this can be performed by using destination NAT to redirect
HTTP traffic addressed to certain hosts (to TCP port 80 or detected using nDPI)
from victim nodes to another node with an HTTP server or proxy, so that victim
nodes still see replies coming from the expected source address.  This does not
work with HTTPS communications.

This has already been witnessed by OONI, but we need to know whether this also
takes place when both communicating nodes are in the same potentially censored
zone.  Besides OONI's ``http_requests`` or ``http_hosts`` tests, a way to check
is to provide client nodes beforehand with data expected to be contained in the
replies from the server nodes, and check what reply it gets when querying the
other node for (i) a page with no ``Host:`` header or an innocuous one, or (ii)
a page with a ``Host:`` header prone to be censored.

### Protocol throttling

Certain protocols and applications are not completely blocked (which can attract
attention), but instead their traffic is slowed down to the point of being
barely usable.

In the simulator, this can be performed by applying shaping on the traffic
belonging to a particular protocol (as identified with the nDPI module of
iptables) into victim nodes.

Throttling has been described in academic research.  To test it, communication
with the remote node can be established via an uncensored path (e.g. plain HTTP)
and bandwidth measured.  Then, communication over the target protocol (possibly
on a non-standard port) can be established and the bandwidth measured again.
This would need to be done both for nodes in the same potentially censored zone
and in different zones.

### Protocol whitelisting

Allowing certain protocols based on signature and throttling or dropping
protocols which are not recognized by the censor.  Historically the censor has
accepted the HTTP (and sometimes HTTPS) protocol and dropped or throttled to the
point of de facto dropping any other (encrypted) protocol.

In the simulator, this can be performed by applying the nDPI module of iptables
to the connection and sending a TCP reset for unknown protocols.  The list of
whitelisted protocols might be different for inside and outside nodes.

This can be checked by opening connections using a variety of protocols,
preferably with several non-standard server ports per protocol, then checking
which of the protocols failed consistently to work in most or all ports.

### Protocol-based connection dropping

It has been observed that all connections (perhaps besides HTTP) have been
dropped after 60 seconds. It is not clear whether connection time out or a
throttling augmentation pattern were responsible for them to be unresponsive.

In the simulator, this can be performed by using the "recent" module of
iptables.

This can be checked by opening TCP connections to some non-standard port and (if
the connection is established) sending and receiving data for a few minutes,
then recording when the connection is prematurely dropped or data delayed (this
could be hard to assess without filling available bandwidth first).

### TLS handshake filtering

TLS handshakes have been subjected to DPI and have been dropped based on
parameters like DH prime number, reverse DNS lookup, SNI name, or certficate
validity length.

In the simulator, the nDPI module of iptables can be used to identify the
connection. Dropping connections can be done using string filters after nDPI
has recognized the connection as TLS.

Besides OONI's ``tls_handshake`` test, this can be checked by opening HTTPS
connections to the HTTP port, although the number of parameters that can be
checked makes the correct test difficult to pinpoint without more information.

## Potential interference

We would like to specifically verify whether the following protocols are being
affected by censorship, both when other nodes are in the same potentially
censored zone *and* in different zones:

  - P2P protocols: We need to know whether the testbed infrastructure has
    specific support for direct communication between nodes.
      - Bare P2P TCP connection: we need to see what previleges nodes need to have
        to accept incoming connections.
      - Bare P2P UDP packet exchange, and whether nodes can use STUN for whole
        punching.
      - BitTorrent
      - IPFS
      - Tor
      - I2P
      - Skype
      - Freenet
      - WebRTC
      - ShadowSocks, uProxy
  - Encrypted transports: For testbeds with a server/probe architecture, daemons
    may run in a server of ours or of the testbed.
      - OpenVPN
      - SSH
  - Obfuscated protocols:
      - Obfs4
      - Obfuscated SSH
  - HTTP: As a base protocol to use as a reference for connection speed
    measurements.  Same arrangement as with encrypted transports.

## Supported tests

The testbed uses a custom [OONI probe fork][] running on nodes and reporting to
collector servers, which in turn run a custom [OONI backend fork][].  The
original probe developed by the *Open Observatory of Network Interference*
[OONI][] provides several *net tests* to detect censorship, surveillance and
traffic manipulation.  The custom version of the probe adds some new
experimental tests which provide information relevant to the technologies that
may be used in CENO2, with the help from ad-hoc helpers running on collectors.

[OONI]: https://ooni.torproject.org/ "OONI: Open Observatory of Network Interference"

### HTTP vs. HTTPS delay test

The ``http_vs_https`` net test retrieves the same document over both HTTP and
HTTPS while timing the delay between request and response.  Both delays are
reported to help discover possible *protocol throttling* affecting HTTPS.

The document's URL (without the ``http://``  or ``https://`` schema prefix) is
read from a given file.

The test report includes the following fields:

``http_success``
: Whether the plain HTTP request was successful (boolean).

``http_response_time``
: Delay between plain HTTP request and response (in seconds, number), null if
the connection failed.

``https_success``
: Whether the HTTPS request was successful (boolean).

``https_response_time``
: Delay between HTTPS request and response (in seconds, number), null if the
connection failed.

This test is currently not used by the testbed.

### Peer locator test

The ``peer_locator_test`` net test contacts a custom given ``peer-locator``
helper running in a collector server to detect and remember the addresses where
other nodes (*peers*) are running test HTTP servers.

The test (i) starts a simple test HTTP server (UPnP-enabled if behind NAT) which
provides a big binary file as its root document, (ii) it connects to the helper
and provides the TCP port number where the HTTP server listens, an indication of
the protocol it uses (HTTP) and other flags (which include whether NAT is used
or not).  The helper remembers (with a time stamp) these parameters along with
the peer's IP address, and (iii) provides back to the test a random entry of one
of the peers that queried the helper before.  The test keeps a list of all such
discovered peers in ``/root/peer_list.txt``.

The test report includes the following fields:

``status``
: A message string indicating whether a peer was provided by the helper, whether
the peer is new, and its IP address and port.

This test is being run daily in the testbed and it reports as ``peer_locator``.
In old versions (before June 2017) it reported as ``base_tcp_test``.

### Peer HTTP reachability test

The ``peer_http_reachable`` net test gets a peer entry including a transport
address (IP address and port number) from a given file, connects to it via plain
HTTP and tries to retrieve its root document, and reports whether the request
was successful and the delay between request and response.  This helps detect
blocking of direct (TCP/HTTP) connections inside of the potentially censored
zone.

In testbed nodes, tests are concurrently run for fresh enough entries of the
same protocol in ``/root/peer_list.txt``, i.e. the file created by the peer
locator test, so that the reachability of other nodes is tested.

The test report includes the following fields:

``http_success``
: Whether the HTTP request was successful (boolean).

``http_response_time``
: Delay between HTTP request and response (in seconds, number), null if the
connection failed.

``peer_ts``
: A UNIX UTC time stamp indicating when the contacted peer first reported its
existence to the peer locator (in seconds, number).  Together with
``measurement_start_time`` it can be used to operate on the age of the contacted
peer.

``peer_nat``
: Whether the contacted peer claimed to be behind NAT to the peer locator
(boolean).

This test is being run every 6 hours in the testbed and it reports as
``http_reachability_test``.

### P2P BitTorrent test

The ``p2p_bittorrent_test`` net test simply invokes a script that runs an
instrumented version of the [Transmission](https://transmissionbt.com/)
BitTorrent client.  The command-line version of the client is started with a
given torrent file that instructs it to download the files associated with it,
followed by seeding the files for some time. While the client is running,
certain events are logged to a JSON-like document named
``transmission-instrumentation.log.json`` in the current working directory.
When the client finishes its downloads, it exits and the JSON document is
dumped.  This helps detect P2P protocol interference.

Given a report retrieved from an OONI backend server as ``REPORT.json``, this
command (which uses the [jq](https://stedolan.github.io/jq/) processor) can be
run to get a pretty-prined version of the output produced by the test:

    jq -r '.test_keys.commands[0].command_stdout' REPORT.json | jq .

The instrumentation collects a record of peer-to-peer network events involved
in downloading or seeding a torrent file. Together, this information makes it
possible to reconstruct a log of network activities attempted by the bittorrent
client, as well as the degree to which these activities succeeded.

The instrumentation record is implemented as a running sequence of network
events, each represented as a JSON object. Instrumentation records are
represented as JSON objects containing a ``type`` field describing the type of
event, a ``timestamp`` float UNIX timestamp recording the time of the event, as
well as a collection of type-specific fields. Seven different types of events
are recorded:

  - ``connection-start``: Emitted whenever a peer-to-peer bittorrent data
    transfer connection is attempted. This does not necessarily mean the
    connection gets established successfully.
    - ``peer-address``, ``peer-port``: The IP address and TCP/UDP port of the
      node on the other side of the connection.
    - ``incoming``: True if the connection was established by the other party.
      False otherwise.
    - ``ledbat``: True if the connection is a LEDBAT UDP connection. False
      otherwise.
  - ``connection-end``: Emitted when a peer-to-peer bittorrent data transfer
    connection is closed. This can be a connection closed voluntarily by one of
    its parties after transferring a certain amount of data; a connection closed
    by some network error at any time; or a connection that never got
    established in the first place, which is cancelled by its initiator.
    - ``peer-address``, ``peer-port``: As for connection-start.
    - ``bytes-sent``, ``bytes-received``: The amount of torrent PAYLOAD data
      transmitted over the connection.
    - ``encrypted``: True if opportunistic protocol encryption was used for this
      connection, false otherwise. Because this proposition only gets negotiated
      after a connection is established, this field will always be False for
      attempted connections that never got off the ground.
    - ``reason-error``: True if the connection get terminated because of some
      network error, such as a connection-reset or a timeout. This generally
      includes connections that get dropped before ever being established.
  - ``dht-rpc-request``: Emitted when Transmission sends a DHT requests to one of
    the nodes in its DHT routing table.
    - ``peer-address``, ``peer-port``: As for connection-start.
    - ``peer-id``: The DHT ID of the peer to which the DHT request is sent.
    - ``rpc-type``: The type of DHT request sent. One of (*find_node*,
      *get_peers*, *announce_peer*).
  - ``dht-rpc-reply``: Emitted when Transmission receives a reply to a DHT request
    described by a ``dht-rpc-request`` event.
    - ``peer-address``, ``peer-port``, ``peer-id``, ``rpc-type``: As above.
  - ``dht-add-node``: Emitted when Transmission adds a new peer to its DHT routing
    table.
    - ``peer-address``, ``peer-port``, ``peer-id``: As above.
  - ``dht-displace-node``: Emitted when Transmission removes a peer from its DHT
    routing table to make room for a new entry.
    - ``peer-address``, ``peer-port``, ``peer-id``: Details of the removed peer.
  - ``dht-own-id``: At the start of a Transmission run, is emitted to describe the
    user's own DHT ID.
    - ``peer-id``: The user's own DHT ID.

Each ``connection-end`` event should be associated with a corresponding
``connection-start`` event, but not vice versa: there can be ``connection-start``
events that never got finalized properly. Similarly, each ``dht-rpc-reply``
should match exactly one ``dht-rpc-request``, but not all requests necessarily
receive a reply.

By matching ``connection-end`` events to ``connection-start`` events that have
the same ``peer-address`` and ``peer-port``, a record of the complete connection
can be reconstructed. That record includes the total connection duration,
computed as the difference between the end-event timestamp and the start-event
timestamp. Similarly, ``dht-rpc-reply`` events can be matched to
``dht-rpc-request`` events with matching ``peer-address``, ``peer-port``, and
``peer-id``.

By performing this matching, logged events can be reconstructed into a collection
of completed connections, and a separate collection of connection attempts that
never got finalized or cleaned up. Similarly, DHT requests can be categorized
into answered and unanswered requests.

### NAT detection test

The ``udp_nat_detection`` net test sends a specially formatted UDP datagram to
each of a set of addresses called *main remotes*, and then expects responses
from both the main remotes and optional *alternate remotes* which contain the
transport address that the remotes see in the datagrams sent by this test
instance.  The test records and reports all the received datagrams to enable the
detection of the type of NAT before the probe (if any).

The test iself provides a guess of the type of NAT mapping and filtering,
according to [RFC 4787](https://tools.ietf.org/html/rfc4787).  Since sent or
received traffic may be lost for many reasons not related with NAT, the test is
careful to only report facts that can be derived from the received traffic and
not from its absence.

The test report includes the following fields:

``data_received``
: An array of all the datagrams received, summarized per payload and source, in
order of first arrival and source.  Each entry contains keys for the (maybe
truncated) ``data``, ``source_addr``, a ``count`` of the same payload/source
occurrences, and time stamps for the first and last ones.  A probe guess on the
validity of the datagram is included as ``probe_decision``.

``nat_type``
: A guess of the type of NAT mapping and filtering from received traffic
(string): ``map:(none | endpoint-indep | addr-or-port-dep | uncertain)
filter:(endpoint-indep | port-indep | probable | ignored)``.

Please see the documentation of the
``ooni.nettests.experimental.udp_nat_detection.NATDetectionTest`` class for a
full description of all fields.

This test is being run every 8 hours in the testbed and it reports as
``nat_detection_test``.

<!-- Local Variables: -->
<!-- fill-column: 80 -->
<!-- End: -->
