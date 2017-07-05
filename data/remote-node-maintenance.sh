#!/bin/sh

# Replace the VirtualBox master VM node id that slipped into the published OVA.
ID_PATH=/var/local/lib/node-id
MASTER_VM_ID=2a8aa620-2547-4bf3-b207-015d463090f3
if [ -f $ID_PATH ] && [ "$(cat $ID_PATH)" = $MASTER_VM_ID ]; then
    uuidgen > $ID_PATH
fi

# Unload ``virtio_net`` module when not needed
# to avoid kernel panic on VM reboot:
# <https://bugs.launchpad.net/ubuntu/+source/virtualbox/+bug/1531455>
INTERFACES_PATH=/etc/network/interfaces
if type lspci > /dev/null 2>&1 && lspci | grep -qi 'ethernet.*virtio'; then
    if ! sed '/^iface eth0\b/,/^iface\b/!d' $INTERFACES_PATH | grep -qE '^\s+post-down\b.*\bmodprobe -r.*\bvirtio_net\b'; then
        sed -Ei 's/^(iface eth0\b.*)/\1\n\tpre-up modprobe virtio_net\n\tpost-down modprobe -r virtio_net/' $INTERFACES_PATH
    fi
fi

# Get the node ID and put it in the login screen and shared folder
# for easy access (e.g. for troubleshooting).
ID_PATH=/var/local/lib/node-id
if [ -f $ID_PATH ]; then
    ID="$(cat "$ID_PATH")"
    if ! grep -q "$ID" /etc/issue; then
        sed -i "1,1iNODE $ID" /etc/issue /etc/issue.net
    fi
    if mountpoint -q /shared && ! grep -q "$ID" /shared/id.txt; then
        echo -n "$ID" > /shared/id.txt
    fi
fi

# Use HTTPS access to Debian package repositories.
APTLIST_PATH=/etc/apt/sources.list
BPOLIST_PATH=/etc/apt/sources.list.d/jessie-backports.list
if { [ -f $APTLIST_PATH ] && grep -qE '(http://\S+/debian/?|http://security.debian.org/)' $APTLIST_PATH; } \
   || { [ -f $BPOLIST_PATH ] && grep -qE 'http://\S+/debian/?' $BPOLIST_PATH; }; then
    apt-get -qy install apt-transport-https \
        && sed -Ei -e 's#http://\S+/debian/?#https://mirrors.kernel.org/debian/#' \
               -e 's#http://security.debian.org/#https://ftp.cica.es/debian-security/#' $APTLIST_PATH $BPOLIST_PATH \
        && apt-get -q update
fi

# Use Tor access to OONI package repositories.
OONILIST_PATH=/etc/apt/sources.list.d/ooniprobe.list
if [ -f $OONILIST_PATH ] && grep -q 'http://deb.torproject.org/' $OONILIST_PATH; then
    apt-get -qy install apt-transport-tor \
        && sed -i 's#http://deb.torproject.org/#tor+http://sdscoq7snqtznauu.onion/#' $OONILIST_PATH \
        && apt-get -q update
fi

# Update SSH host keys (e.g. for new hosts or IP addresses).
SSHHOSTS_PATH="$HOME/.ssh/known_hosts"
SSHHOSTSTMP_PATH=$(mktemp)
tnldo sh -c 'wget -qO '"$SSHHOSTSTMP_PATH"' --header="Host: server.testbed" "http://$TNL_ADDR_BKT/ssh-known-hosts.txt"'
if [ $? -eq 0 ]; then
    if [ -f "$SSHHOSTS_PATH" ]; then
        # If set of merged lines is bigger than original set, add new lines.
        orig_size=$(sort -u "$SSHHOSTS_PATH" | wc -l)
        new_size=$(cat "$SSHHOSTS_PATH" "$SSHHOSTSTMP_PATH" | sort -u | wc -l)
        if [ "$orig_size" -lt "$new_size" ]; then
            cat "$SSHHOSTSTMP_PATH" >> "$SSHHOSTS_PATH"
        fi
    else
        mkdir -p -m 0700 "$(dirname "$SSHHOSTS_PATH")"
        install -m 0600 "$SSHHOSTSTMP_PATH" "$SSHHOSTS_PATH"
    fi
fi
rm -f "$SSHHOSTSTMP_PATH"

# Synchronize node data files from server.
NODEDATA_PATH=/var/local/lib/node-data
mkdir -p -m 0700 "$NODEDATA_PATH"  # there may be sensitive files
tnldo sh -c 'rsync -r node-data@$TNL_ADDR_BKT: '"$NODEDATA_PATH"
chmod go-rwx "$NODEDATA_PATH"  # just in case

# Run local Ansible playbook if present in node data.
PLAYBOOK_PATH=/var/local/lib/node-data/ansible/localplay.yml
if [ -f "$PLAYBOOK_PATH" ]; then
    ( cd "$(dirname "$PLAYBOOK_PATH")" \
          && ansible-playbook -i inventory "$(basename "$PLAYBOOK_PATH")" )
fi
