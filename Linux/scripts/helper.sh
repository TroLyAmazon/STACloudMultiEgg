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

exec chroot "$HOME" /bin/sh -lc 'cd /home/container 2>/dev/null || cd /; exec /bin/sh /run.sh'
