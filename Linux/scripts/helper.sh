#!/bin/sh

ensure_runtime_scripts() {
    for file in common.sh run.sh vnc_install.sh; do
        if [ ! -f "$HOME/$file" ] && [ -f "/$file" ]; then
            cp "/$file" "$HOME/$file"
            chmod +x "$HOME/$file"
        fi
    done
}

ensure_runtime_scripts

/usr/local/bin/proot \
    --rootfs="$HOME" \
    -0 -w "/home/container" \
    -b /dev -b /sys -b /proc \
    --kill-on-exit \
    /bin/sh "/run.sh"

