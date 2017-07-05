# Creating a testbed node

**Note:** Whenever a command is prefixed with ``sudo``, it may as well be
executed by the ``root`` user straight away.  This document assumes that the
main user can become ``root`` (e.g. by adding it to the ``sudo`` group).

## New VirtualBox VM

Create a new VM:

  - Name ``test``, type *Linux*, version *Ubuntu (32-bit)*
  - RAM 2048 MiB (to ensure that the PAE kernel is installed, may be shrinked later)
  - New hard disk image, type *VDI*, dynamically allocated, name *test*, size 8 GiB

Open VM settings:

  <!--- - In *General/Encryption*, enable encryption and provide a password. XXXX Requires non-free extension pack. --->
  - In *Audio*, disable audio
  - In *USB*, disable the USB controller
  - In *Network*, configure the first adapter as bridged and its type (under
    *Advanced*) as paravirtualized
  - In *Shared folders*, create a new folder called ``shared``, not read-only,
    not automatic, pointing to some existing, innocuous directory
    (e.g. ``/tmp/shared``)

## New Debian installation

Install Debian into the VM with all default options, except:

  - Host name: ``test``
  - User name and password: ``user``, create and note down password
  - Partitioning method: guided, encrypted
      - Skip random overwriting to ease compression
      - Encryption passphrase: create and note down passprhase
  - Software to install: *SSH server* only
  - Install the GRUB bootloader in ``/dev/sda``'s MBR

(You may want to avoid enabling encryption if you want to get a much smaller
VM image.)

It's advisable to halt the VM if it looks like it's not getting an IP address
and reboot it again.  If you get a kernel panic after reboot, halt the VM and
start it again (the NIC driver issue will be handled below).

## Basic packages

Disable package sources and update the list of packages:

    $ sudo sed -Ei 's/^(deb-src.*)/#\1/' /etc/apt/sources.list
    $ sudo apt update

We will enable package download via HTTPS to avoid revealing which packages we
are installing:

    $ sudo apt install apt-transport-https
    $ sudo sed -Ei -e 's#http://\S+/debian/#https://mirrors.kernel.org/debian/#' \
      -e 's#http://security.debian.org/#https://ftp.cica.es/debian-security/#' /etc/apt/sources.list
    $ sudo apt update

Now upgrade packages:

    $ sudo apt upgrade

We install some packages to enable the remote administration of nodes: SSH for
basic access, ``sudo`` to allow switching to other users in scripts, Ansible
(from backports to get version 2.2.1 or greater) to ease ulterior
configuration after deployment, Mosh and Screen for SSH access over unreliable
connections (from backports since we need IPv6 for access via VPN), and
``rsync`` and ``git`` for retrieving files from other machines and
repositories.  Also ``anacron`` since there are daily tasks and the node may
not be running continuously, and vnStat to log bandwidth usage of the node:

    $ echo 'deb https://mirrors.kernel.org/debian/ jessie-backports main' \
      | sudo install -m 0644 /dev/stdin /etc/apt/sources.list.d/jessie-backports.list
    $ sudo apt update
    $ sudo apt install anacron vnstat openssh-server sudo screen rsync git
    $ sudo apt -t jessie-backports install ansible mosh

## Shared folder

**NOTE:** This is just for VirtualBox VMs running on a desktop PC.

### Build guest modules

XXXX from different host with same kernel headers, install ``virtualbox-guest-source``

    # m-a build virtualbox-guest  ## ???? check

### Install guest modules

  - Enable the ``contrib`` component in APT repositories:

        $ sudo sed -Ei 's/^(deb.*)\bmain\b(.*)/\1main contrib\2/' /etc/apt/sources.list
        $ sudo apt update

  - Copy the ``virtualbox-guest-modules-….deb`` to the VM, e.g. via web
    download, and install it along with VirtualBox guest utilities:

        $ sudo wget http://VBOX_HOST/path/to/vbguest.deb -O /run/vbguest.deb
        $ sudo dpkg -i /run/vbguest.deb
        $ sudo rm /run/vbguest.deb
        $ sudo apt install --no-install-recommends virtualbox-guest-utils

  - Load the ``vboxsf`` module:

        $ echo vboxsf | sudo tee /etc/modules-load.d/vboxsf.conf
        $ sudo modprobe vboxsf

  - Mount the shared folder by adding an entry to ``/etc/fstab``:

        $ cat << EOF | sudo tee -a /etc/fstab
        shared  /shared  vboxsf  rw,dmode=755,fmode=644  0  0
        EOF

    and mount it by running:

        $ sudo mkdir /shared
        $ sudo mount /shared

## Networking

### Virtio network driver

**NOTE:** This is just for VirtualBox VMs.

Keeping the ``virtio_net`` module loaded when the VM reboots seems to cause a
kernel panic on next boot (see [Ubuntu #1531455][]).  To avoid that, we can
force loading and unloading the module when putting the ``eth0``  interface up
and down by adding this to the ``iface eth0 inet dhcp`` stanza in
``/etc/network/interfaces``:

    <TAB>pre-up modprobe virtio_net
    <TAB>post-down modprobe -r virtio_net

There is no need to re-enable the interface.

[Ubuntu #1531455]: https://bugs.launchpad.net/ubuntu/+source/virtualbox/+bug/1531455

### Fixed private address

**NOTE:** This is just for nodes running on a home PC (e.g. VirtualBox VMs).

Enable a fixed private IP address in ``eth0`` after bringing the interface up
by adding this to the ``iface eth0 inet dhcp`` stanza in
``/etc/network/interfaces``:

    <TAB>up ip addr add 172.27.72.1/24 dev $IFACE preferred_lft 0

<!--- XXXX use sed ---->

Enable it with:

    $ sudo sh -c "ifdown eth0 ; ifup eth0"

To check that it works, add to the host PC an address in the same network to
the device used as a bridge and ping the node:

    # ip addr add 172.27.72.2/24 dev eth0
    # ping 172.27.72.1

## Tor bridges web form

**NOTE:** This is just for nodes running on a home PC (e.g. VirtualBox VMs).

We'll be installing Tor with bridges and pluggable transports enabled:

    $ sudo apt install --no-install-recommends tor obfsproxy obfs4proxy

The ``torn-bridges-enable`` script takes a file with Tor bridge lines as
provided by <https://bridges.torproject.org/> and enables them in the local
Tor daemon (with the help from ``sudo`` to write the configuration and restart
the service):

    $ sudo install -m 0755 /shared/tor/tor-bridges-enable /usr/local/bin

The following service runs as ``www-data`` on <http://172.27.72.1:8080> and
allows the user to provide Tor bridge lines, then it uses the previous script
to enable them:

    $ sudo install -m 0440 /shared/tor/tor-bridges.sudoers /etc/sudoers.d/tor-bridges
    $ sudo install -m 0755 /shared/tor/tor-bridges-webform.py /usr/local/sbin
    $ sudo install -m 0644 /shared/tor/tor-bridges.service /etc/systemd/system
    $ sudo systemctl enable tor-bridges
    $ sudo systemctl start tor-bridges

## Configuration via Ansible

<!--- This is a good point to snapshot and install the cjdns prebuilt deb. --->

If the Ansible playbook for configuring nodes is available, you may use it to
complete the rest of steps which are marked below as being handled by it.  For
instance, via the shared folder:

    $ cd /shared/ansible-node
    $ sudo ansible-playbook -i inventory localplay.yml

## SSH

**Note:** Already handled by Ansible playbook.

We want the ``root`` user to be able to perform unattended, password-less SSH
to other machines (e.g. for ``rsync`` of data), so we add a common
passphrase-less key.  We also ony want to allow SSH access to nodes
authenticated by the testbed administrator's public key (and no other, to
avoid undesired logins).  Via the shared folder:

    $ sudo mkdir -m 0700 ~root/.ssh
    $ sudo install -m 0600 /shared/ssh/node-root/id_rsa ~root/.ssh/
    $ sudo install -m 0600 /shared/ssh/node-root/id_rsa.pub ~root/.ssh/
    $ sudo install -m 0600 /shared/ssh/testbed-admin/id_rsa.pub ~root/.ssh/authorized_keys

Configure the SSH server to only accept public key authentication:

    $ echo 'AuthenticationMethods publickey' | sudo tee -a /etc/ssh/sshd_config
    $ sudo systemctl reload ssh

## OnionCat

**Note:** Already handled by Ansible playbook.

  - Install OnionCat with ``sudo apt install onioncat``
  - Add a Tor hidden service for OnionCat in ``/etc/tor/torrc``:

        HiddenServiceDir /var/lib/tor/onioncat/
        HiddenServicePort 8060 127.0.0.1:8060

    <!--- XXXX use sed ---->

    Reload Tor with ``sudo systemctl reload tor``.  This will generate the
    hidden service hostname and key.  Thus, to ensure that new files are
    generated for each node when it starts, **delete the directory indicated
    above before distributing the node image**.

  - Enable OnionCat by editing ``/etc/default/onioncat``:

        ENABLED=yes
        DAEMON_OPTS="-d 0 $(cat /var/lib/tor/onioncat/hostname)"

    <!--- XXXX use sed ---->

    And restart it with ``sudo systemctl restart onioncat``.

## cjdns

### Building

This step can be done in a different host as long as it runs the same OS
version.  Install build dependencies:

```
sudo apt install git build-essential debhelper nodejs wget python dh-systemd
```

Build Debian package (tagged as 0.17.1, actually 0.19.1):

```sh
git clone https://github.com/cjdelisle/cjdns.git
cd cjdns
git checkout cjdns-v19.1
echo 'contrib/systemd/cjdns-resume.service /lib/systemd/system/' >> debian/cjdns.install
dpkg-buildpackage -b -rfakeroot
```

The resulting package will be called ``cjdns\_VERSION\_ARCH.deb`` and placed
in the parent directory.

### Configuring

**Note:** Node side already handled by Ansible playbook.

Install the Debian package built in the previous step, e.g. via the shared
folder:

    $ sudo apt install python
    $ sudo dpkg -i /shared/cjdns/cjdns_0.17.1_i386.deb

The configuration file ``/etc/cjdroute.conf`` (containing node keys) will be
autogenerated on the first start of cjdns.  Thus, to ensure that a new file is
generated for each node when it starts, **delete the config file before
distributing the node image**.

**In servers**, edit ``/etc/cjdroute.conf`` and note down the following values
(paths given in JSONPath):

  - ``$.publicKey`` as ``SERVER_PUBKEY``
  - ``$.authorizedPasswords[?(@.user="default-login")].password`` as ``SERVER_PASS``
  - UDP ports in ``$.interfaces.UDPInterface..bind`` as ``SERVER_PORT``
  - server addresses (not in the file) as ``SERVER_ADDR``

Disable discovery in the local network, by setting all occurences of
``$.interfaces.ETHInterface..beacon`` to 0.

Then restart cjdns:

    $ sudo systemctl restart cjdns

Remember to open each UDP ``SERVER_PORT`` in the firewall.

    # iptables -I INPUT -p udp -m udp --dport <SERVER_PORT> -j ACCEPT
    # ip6tables -I INPUT -p udp -m udp --dport <SERVER_PORT> -j ACCEPT

**In nodes**, we will configure cjdns to run the ``cjdns-inject-connectto``
script to inject the parameters for connecting to servers into the (maybe
autogenerated) cjdns configuration file.  Install the ``jq`` package and the
script (e.g. via the shared folder):

    $ sudo apt install jq
    $ sudo install -m 0755 /shared/cjdns/cjdns-inject-connectto /usr/local/sbin

Install in ``/usr/local/etc`` the JSON snippets containing the values of the
``$.interfaces.UDPInterface..connectTo`` fields for IPv4 and IPv6 connections:

    $ sudo install -m 0600 /shared/cjdns/cjdns-client-connectto?.json /usr/local/etc

Each snippet should have the format:

```json
{
    "SERVER1_ADDR:SERVER1_PORT": {
        "password": "SERVER1_PASS",
        "publicKey": "SERVER1_PUBKEY"
    },
    …
    "SERVERn_ADDR:SERVERn_PORT": {
        "password": "SERVERn_PASS",
        "publicKey": "SERVERn_PUBKEY"
    }
}
```

Create a modified version of the cjdns systemd service that calls the script:

    $ sudo systemctl stop cjdns
    $ sudo systemctl disable cjdns
    $ sed '/^ExecStart=/i ExecStartPre=/usr/local/sbin/cjdns-inject-connectto' \
      /lib/systemd/system/cjdns.service | sudo tee /etc/systemd/system/cjdns.service
    $ sudo systemctl enable cjdns

If you want to try the script, just restart cjdns:

    $ sudo systemctl restart cjdns

You should now be able to ping each other's IPv6 address (``$.ipv6`` in the
config file).

## IP tunnels to CENO2/OONI backends

**Note:** Already handled by Ansible playbook.

Under the folder `data/tunnel/` from where the file you are reading is placed,
you will find Bash functions and configuration parameters to connect to CENO
IP tunnel endpoints. Three connection methods are supported: OpenVPN, PPP over
TLS (with `stunnel`) and PPP over SSH.

Install the needed Debian packages:

    $ sudo apt install --no-install-recommends openvpn stunnel4 ppp uuid-runtime jq

Install the script `tnlvars.sh.example` to `/usr/local/sbin/tnlvars.sh` along
with the `tnl` script, change the former to your convenience and create the
tunnel data and log directory:

    $ sudo install -m 0755 /shared/tunnel/tnlvars.sh.example /usr/local/sbin/tnlvars.sh
    $ sudo install -m 0755 /shared/tunnel/tnl /usr/local/sbin
    $ sudo vi /usr/local/sbin/tnlvars.sh
    $ sudo mkdir -p /var/local/lib/tnl/log

Get the TLS and SSH certificates and keys that you will need to authenticate
yourself to the VPN server as well as to authenticate the server itself (ask
the server administrator for these files!).  Copy them to the tunnel data
directory, and the VPN server's SSH keys to the standard location:

    $ sudo install -m 0600 /shared/tunnel/*.pem /var/local/lib/tnl
    $ sudo install -m 0600 /shared/tunnel/pppclient /var/local/lib/tnl
    $ sudo install -m 0600 /shared/ssh/known_hosts ~root/.ssh

Please note that only the tunnel endpoint IP addresses need appear in
``known_hosts``.  However, if you plan to perform SSH over tunnel and VPN
addresses, these should also appear in that file if you want to avoid key
confirmation questions (e.g. for running unattended commands).

To test a tunnel, as superuser, connect to your tunnel endpoint (you need to
know the endpoint's IP address and port):

    # tnl start <method> <IP> <port>

`<method>` can be one of `ovpn`, `pppssh` or `ppptls`. The function will give
you back a tunnel ID that you can use to manipulate the tunnel:

- to check if it's up by pinging the other side: `tnl check <ID>` (note that
  tunnels often need a few seconds to establish connection);
- to display your local IP inside the tunnel: `tnl ip <ID>`;
- to kill the tunnel: `tnl stop <ID>`;
- to display a tunnel's logs: `tnl log <ID>`.

The `tnldo` script allows you to run a command after a working tunnel
connection is found.  It can start and stop tunnels itself.  To install it via
the shared folder:

    $ sudo install -m 0755 /shared/tunnel/tnldo /usr/local/sbin
    $ sudo install -m 0644 /shared/tunnel/tnldo.conf /usr/local/etc

`tnldo.conf` is a JSON file containing a list of tunnel addresses to test in
turn, along with commands to start and stop the tunnel associated with each
address if so desired.  When a command is run under ``tnldo``, several
environment variables are available containing the tunnell address and
protocol version (IPv4 or IPv6).  For example, to copy a file to the remote
endpoint:

    $ sudo tnldo sh -c 'scp foo.bar foo@$TNL_ADDR_BKT:/tmp'

Check ``tnldo --help`` for more info on the configuration file and variables.

## Reporting addresses and pulling instructions

**Note:** Already handled by Ansible playbook.

Nodes report their local addresses (``a``) and publicly visible IPv4 addresses
(``i4``) to servers by accessing the following URL (with ``Host:
server.testbed``):

    http://TUNNEL_ADDR/addrs/?n=UUID&a=IP1/PFX1&a=IP2/PFX2&i4=IP3

Local addresses reported include those of the permanent VPNs configured
further above to allow contacting the node, but not those of temporary
tunnels.  If the node is behind some NAT box, the public IPv4 address should
not appear among local addresses.

The ``TUNNEL_ADDR`` in the previous URL is the configured VPN or tunnel
address first found to work by the ``tnldo`` script.  If the retrieved
document is a script (i.e. it starts with the *shebang* ``!#``), it is saved
and run as ``root``.  This may be used to pull maintenance instructions from
servers.

**WARNING:** Since the URL is accessed via plain HTTP, please make sure that
the addresses in ``tnldo``'s configuration file are safely reachable with
source authentication to avoid malicious injection of scripts by MitM attacks.

This procedure is performed by an hourly Cron task.  To install the required
packages and the script (via the shared folder):

    $ sudo apt install uuid-runtime wget
    $ sudo install -m 0755 /shared/report-addrs.cron-hourly /etc/cron.hourly/report-addrs

This task also creates a unique **node ID** if missing (which is also reported
to servers along addresses), and puts it in the shared folder (if it is
available) and in the login screen message, to ease troubleshooting by users.

To have all these steps run as soon as the node boots, we insert a call to
that script as the last step in ``/etc/rc.local``:

    $ sudo sed -i '/^exit 0/i /etc/cron.hourly/report-addrs' /etc/rc.local

## OONI probe

**Note:** Already handled by Ansible playbook.

Note: these instructions work for the OONI Debian package and may not be valid
for other distributions.  In particular, they do not apply to the setup done
via Ansible, which uses Git source directly.

### Installation

OONI provides a package from Debian Jessie and Ubuntu, see the installation
[instructions](https://ooni.torproject.org/install/ooniprobe/). Tor will also
be automatically installed, and you will need the `geoip-database-extra`
package to use GeoIP ASN resolution. OONI packages should be installed via Tor
since the Tor repo may be blocked. Using the shared folder:

    $ sudo apt install apt-transport-tor
    $ sudo apt-key add /shared/ooniprobe/ooniprobe.asc
    $ sudo install -m 0644 /shared/ooniprobe/ooniprobe.list /etc/apt/sources.list.d/
    $ sudo apt update
    $ sudo apt install deb.torproject.org-keyring ooniprobe geoip-database-extra

On other distributions, `pip` can be used to install `ooniprobe` from a
Python 2 virtual environment. The advantage of using the Debian package is not
entirely clear, because the package actually ships a distinct Python
environment and the integration into Debian is low.

For some reason, `ooniprobe` seems to get confused with some paths when looking
for GeoIP data, so it is necessary to relocate some data:

    $ cd /var/lib/ooni
    $ sudo -u Debian-ooni ln -s . .ooni
    $ sudo -u Debian-ooni mkdir -p resources/maxmind-geoip
    $ sudo -u Debian-ooni ln -s /usr/share/GeoIP/* resources/maxmind-geoip

Run `ooniprobe` as user `Debian-ooni` for the first time so that it finishes
its initialisation:

    $ sudo -u Debian-ooni ooniprobe --info

Just leave the default answer to every question by hitting Enter, we will
override configuration later.

### Configuration

First configure Tor by editing `/etc/tor/torrc`. Uncomment the following line:

    ControlPort 9051

<!--- XXXX use sed ---->

And reload Tor with `sudo systemctl reload tor`.  The OONI probe user will need
access to Tor's control cookie file, so add it to its group:

    $ sudo adduser Debian-ooni debian-tor

In fact, the use of Tor should not be necessary for our tests to work, but
`ooniprobe` might try to communicate with the Tor daemon and we do not want this
to be a fatal error.

OONI probe's configuration goes in `/var/lib/ooni/ooniprobe.conf`, in YAML
format. There are many parameters we will not bother specifiying, and
`ooniprobe` will just use the defaults. The included configuration file
[ooniprobe.conf](data/ooniprobe.conf) should be enough.  You may copy it from
the shared folder:

    $ sudo -u Debian-ooni cp -b /shared/ooniprobe/ooniprobe.conf /var/lib/ooni

<!--- XXXX careful with source file and path permissions --->

### Running a test and submitting to our own collector

To run the HTTP blocking test and submit to our own collector, do:

    $ sudo -u Debian-ooni ooniprobe -c https://ourcollector.xyz blocking/http_requests --url https://equalit.ie

The result will still be saved locally.

### Running a test and sending results later

We can run a test and save the result locally only:

    $ sudo -u Debian-ooni ooniprobe -n blocking/http_requests --url https://equalit.ie

If some result tests failed to upload earlier on or if we decided to not submit
them right away, `oonireport` manages this perfectly. This command displays
reports that have not been uploaded yet:

    $ sudo -u Debian-ooni oonireport status

This command uploads to the specified collector all reports that have not been
uploaded successfully yet:

    $ sudo -u Debian-ooni oonireport -c https://ourcollector.xyz upload

We can easily schedule tests and attempting uploads to various collectors using
cron, possibly with the added use of circumvention methods to increase chances
of reaching collectors.

### Uploading and backing up test results

We are setting up a daily Cron task to send pending reports to the collector,
and create an encrypted backup of the measurements if the upload fails.

First, import the backup recipient's PGP key in the GnuPG keyring of the OONI
probe user (the second file is just the ID of that key):

    $ sudo -u Debian-ooni gpg --import /shared/ooni-backup-pub.asc
    $ sudo -u Debian-ooni cp /shared/ooni-backup-key.id ~Debian-ooni

<!--- XXXX careful with source file and path permissions --->

Then install the Cron script:

    $ sudo install -m 0755 /shared/ooniprobe/ooniprobe.cron-daily /etc/cron.daily/ooniprobe

### Running a set of tests at once (called a "deck")

`ooniprobe` can also read _deck files_. A deck file is just a YAML file that
describes a set of tests to perform, along with some additional fields
describing what the deck itself is about and how often it should run (this
additional data is used by the OONI probe agent, explained in next section).

Here is an example deck file:

    ---
    name: My test deck
    description: "This is just a test deck"
    schedule: "@daily"
    tasks:
      - name: Test if equalit.ie is reachable
        ooni:
          test_name: http_requests
          url: https://equalit.ie
          collector: https://ourcollector.xyz

It has only one test in it, but adding new ones is easy. See example deck files
in `/opt/venvs/ooniprobe/share/ooni/decks-available/`.

To make `ooniprobe` run a whole deck, simply run:

    $ sudo -u Debian-ooni ooniprobe -i /path/to/your/deck.yaml

### Scheduling tests using the OONI probe agent

If you are only interested in running your own OONI decks, first wipe all
symlinks from the `decks-enabled` directory:

    $ sudo -u Debian-ooni rm /var/lib/ooni/decks-enabled/*

Once you have created your own deck, create a symbolic link to it in
`/var/lib/ooni/decks-enabled/`. Make sure you set the `schedule` parameter to
your needs. It uses the same syntax as a `crontab(5)` file.

Install the following systemd service to run the ``ooniprobe-agent``, which
schedules the tests by itself by following the deck's instructions:

    $ sudo install -m 0644 /shared/ooniprobe/ooniprobe.service /etc/systemd/system
    $ sudo systemctl enable ooniprobe

You may start the agent with:

    $ sudo systemctl start ooniprobe

It spawns a web interface on <http://localhost:8842>, but we may want to
deactivate that since there will be almost no human interaction with probes.

## Final steps

**Note:** This is only needed when distributing images of the node.

Before packing an image, go into single user mode:

    $ sudo telinit s

Wait until all relevant network services stop.  You can check with:

    # ps ax

Purge downloaded packages:

    # apt-get clean

Remove the configuration files of services that autogenerate them:

    # rm -rf /var/lib/tor/onioncat
    # rm /etc/cjdroute.conf

Since OnionCat may start before Tor has configured the new hidden service, we
wait a little if needed by the end of the boot process (before reporting
addresses):

    # sed -i '/report-addrs/i test -d /var/lib/tor/onioncat || { sleep 5; service onioncat restart; }' /etc/rc.local

Also stop the SSH server, remove its host keys and extend ``/etc/rc.local`` to
generate new keys on boot (before reporting addresses) if missing:

    # sed -i '/report-addrs/i test -f /etc/ssh/ssh_host_rsa_key || dpkg-reconfigure openssh-server' /etc/rc.local
    # systemctl stop ssh
    # rm -f /etc/ssh/ssh_host_*_key*

Ensure that the node ID file is not there:

    # rm -f /var/local/lib/node-id

(This is a good point to snapshot a master node image.)

Finally, execute the bare ``sh`` and remove command history:

    # exec sh
    # rm -f ~root/.bash_history
    # rm -f ~user/.bash_history

If the node disk is not encrypted, boot the node with SystemRescueCD and run
``zerofree`` on the root file system for a better compression.
