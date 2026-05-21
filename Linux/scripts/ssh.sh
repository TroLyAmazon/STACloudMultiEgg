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

set_stacloud_identity() {
    if ! command -v openssl >/dev/null 2>&1; then
        echo "[ERROR] openssl is missing; cannot set SSH password."
        return 1
    fi

    current_uid="$(id -u)"
    current_gid="$(id -g)"
    password_hash="$(openssl passwd -6 "$SSH_SECRET")" || return 1

    awk -F: -v user="$SSH_LOGIN" -v uid="$current_uid" -v gid="$current_gid" -v home="$HOME_DIR" 'BEGIN { OFS = ":" } $1 == user { $3 = uid; $4 = gid; $5 = "STACloud"; $6 = home; $7 = "/usr/local/bin/stacloud-ssh-shell"; found = 1 } { print } END { if (!found) print user, "x", uid, gid, "STACloud", home, "/usr/local/bin/stacloud-ssh-shell" }' /etc/passwd > /tmp/stacloud-passwd || return 1
    cat /tmp/stacloud-passwd > /etc/passwd || return 1
    rm -f /tmp/stacloud-passwd

    awk -F: -v group="$SSH_LOGIN" -v gid="$current_gid" 'BEGIN { OFS = ":" } $1 == group { $3 = gid; found = 1 } { print } END { if (!found) print group, "x", gid, "" }' /etc/group > /tmp/stacloud-group || return 1
    cat /tmp/stacloud-group > /etc/group || return 1
    rm -f /tmp/stacloud-group

    awk -F: -v user="$SSH_LOGIN" -v hash="$password_hash" 'BEGIN { OFS = ":" } $1 == user { $2 = hash; found = 1 } { print } END { if (!found) print user, hash, "19000", "0", "99999", "7", "", "", "" }' /etc/shadow > /tmp/stacloud-shadow || return 1
    cat /tmp/stacloud-shadow > /etc/shadow || return 1
    rm -f /tmp/stacloud-shadow
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
        -o PermitRootLogin=no \
        -o UsePAM=no \
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
set_stacloud_identity || exit 1
ensure_host_key || exit 1
start_sshd
