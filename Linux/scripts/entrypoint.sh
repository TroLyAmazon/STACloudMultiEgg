#!/bin/sh

sleep 2
cd /home/container || exit 1

INTERNAL_IP="$(ip route get 1 2>/dev/null | awk '{print $NF; exit}')"
export INTERNAL_IP

if [ ! -e "$HOME/.rootfs_installed" ]; then
    /bin/sh "/install.sh" || exit 1
fi

/bin/sh /ssh.sh || exit 1
sh /helper.sh
