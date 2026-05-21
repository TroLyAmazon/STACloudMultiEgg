#!/bin/sh

export HOME=/home/container
cd /home/container || exit 1

exec /usr/bin/proot \
    -r /home/container \
    -0 \
    -w /home/container \
    -b /dev \
    -b /proc \
    -b /sys \
    /bin/sh -lc 'cd /home/container 2>/dev/null || cd /; if command -v bash >/dev/null 2>&1; then exec bash -l; else exec sh -l; fi'
