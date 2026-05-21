#!/bin/sh

SSH_PID_FILE="/tmp/stacloud-ssh.pid"
SSH_LOG_FILE="/tmp/stacloud-ssh.log"

case "$SSH_PORT" in
    ""|"{{SERVER_PORT}}"|"{{server.build.default.port}}")
        SSH_PORT="${SERVER_PORT:-2222}"
        ;;
esac
export SSH_PORT

if [ ! -x /usr/local/bin/stacloud-ssh-server ]; then
    echo "[ERROR] STACloud SSH server binary is missing."
    exit 1
fi

if [ -f "$SSH_PID_FILE" ]; then
    old_pid="$(cat "$SSH_PID_FILE" 2>/dev/null || true)"
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
        exit 0
    fi
fi

/usr/local/bin/stacloud-ssh-server > "$SSH_LOG_FILE" 2>&1 &
ssh_pid="$!"
printf "%s\n" "$ssh_pid" > "$SSH_PID_FILE"

sleep 1
if ! kill -0 "$ssh_pid" 2>/dev/null; then
    echo "[ERROR] STACloud SSH server failed to start. See $SSH_LOG_FILE"
    exit 1
fi

exit 0
