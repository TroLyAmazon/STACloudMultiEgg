#!/bin/sh

HOME_DIR="/home/container"
CREDENTIALS_FILE="$HOME_DIR/.stacloud_credentials"
SSHD_PID_FILE="/tmp/stacloud-sshd.pid"
SSH_LOG_FILE="/tmp/stacloud-ssh.log"
SSH_HOST_KEY="$HOME_DIR/.stacloud_ssh_host_ed25519_key"
SSH_LOGIN="stacloud"

random_string() {
    length="${1:-24}"
    if [ -r /dev/urandom ]; then
        value="$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length")"
    else
        value="$(date +%s%N | sha256sum | cut -c 1-"$length")"
    fi
    [ -n "$value" ] || value="$(date +%s%N | sha256sum | cut -c 1-"$length")"
    printf "%s" "$value"
}

valid_password() {
    [ -n "$1" ] && [ "${#1}" -ge 12 ] && [ "${#1}" -le 128 ]
}

load_or_create_credentials() {
    if [ -f "$CREDENTIALS_FILE" ]; then
        . "$CREDENTIALS_FILE"
    fi

    SSH_LOGIN="stacloud"
    valid_password "$SSH_SECRET" || SSH_SECRET="$(random_string 24)"

    {
        printf "SSH_LOGIN=%s\n" "$SSH_LOGIN"
        printf "SSH_SECRET=%s\n" "$SSH_SECRET"
    } > "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE" 2>/dev/null || true

    case "$SSH_PORT" in
        ""|"{{SERVER_PORT}}"|"{{server.build.default.port}}")
            SSH_PORT="${SERVER_PORT:-2222}"
            ;;
    esac

    export SSH_LOGIN SSH_SECRET SSH_PORT
}

ensure_host_key() {
    if [ ! -f "$SSH_HOST_KEY" ]; then
        ssh-keygen -q -t ed25519 -N "" -f "$SSH_HOST_KEY" >/dev/null 2>&1 || return 1
    fi
    chmod 600 "$SSH_HOST_KEY" 2>/dev/null || true
}

start_sshd() {
    if [ -f "$SSHD_PID_FILE" ]; then
        old_pid="$(cat "$SSHD_PID_FILE" 2>/dev/null || true)"
        if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
            return 0
        fi
    fi

    /usr/sbin/sshd -D -e \
        -p "$SSH_PORT" \
        -h "$SSH_HOST_KEY" \
        -o ListenAddress=0.0.0.0 \
        -o PasswordAuthentication=yes \
        -o KbdInteractiveAuthentication=yes \
        -o PermitRootLogin=no \
        -o UsePAM=yes \
        -o AllowUsers="$SSH_LOGIN" \
        -o PidFile="$SSHD_PID_FILE" \
        > "$SSH_LOG_FILE" 2>&1 &

    ssh_pid="$!"
    printf "%s\n" "$ssh_pid" > "$SSHD_PID_FILE"

    sleep 1
    if ! kill -0 "$ssh_pid" 2>/dev/null; then
        echo "[ERROR] SSH server failed to start. See $SSH_LOG_FILE"
        return 1
    fi

    return 0
}

load_or_create_credentials
ensure_host_key || exit 1
start_sshd
