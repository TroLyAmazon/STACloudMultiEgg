#!/bin/sh

LOG_FILE="/tmp/stacloud-ssh-shell.log"
export HOME=/home/container

{
    printf "session start uid=%s gid=%s user=%s home=%s\n" "$(id -u 2>/dev/null)" "$(id -g 2>/dev/null)" "$(id -un 2>/dev/null)" "$HOME"
    printf "proot=%s rootfs_sh=%s\n" "$(command -v proot 2>/dev/null)" "$(test -x /home/container/bin/sh && echo yes || echo no)"
} >> "$LOG_FILE" 2>/dev/null || true

cd /home/container || {
    printf "cannot cd to /home/container\n" >> "$LOG_FILE" 2>/dev/null || true
    exec /bin/sh -l
}

/usr/bin/proot \
    -r /home/container \
    -0 \
    -w /home/container \
    -b /dev \
    -b /proc \
    -b /sys \
    /bin/sh -lc 'cd /home/container 2>/dev/null || cd /; if command -v bash >/dev/null 2>&1; then exec bash -l; else exec sh -l; fi'

status="$?"
printf "proot exited with status=%s\n" "$status" >> "$LOG_FILE" 2>/dev/null || true

if [ "$status" -ne 0 ]; then
    printf "STACloud SSH fallback shell. Check %s for PRoot details.\n" "$LOG_FILE"
    exec /bin/sh -l
fi

exit 0
