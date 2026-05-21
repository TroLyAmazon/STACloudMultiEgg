#!/bin/sh

HOME_DIR="/home/container"
CREDENTIALS_FILE="$HOME_DIR/.stacloud_credentials"
SSHD_PID_FILE="/tmp/stacloud-sshd.pid"

random_string() {
    length="${1:-16}"
    if [ -r /dev/urandom ]; then
        value="$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length")"
    else
        value="$(date +%s%N | sha256sum | cut -c 1-"$length")"
    fi
    if [ -z "$value" ]; then
        value="$(date +%s%N | sha256sum | cut -c 1-"$length")"
    fi
    printf "%s" "$value"
}

random_username() {
    suffix="$(random_string 10 | tr 'A-Z' 'a-z')"
    [ -n "$suffix" ] || suffix="$(date +%s)"
    printf "sta%s" "$suffix"
}

valid_username() {
    case "$1" in
        sta[abcdefghijklmnopqrstuvwxyz0123456789]*)
            [ "${#1}" -ge 6 ] && [ "${#1}" -le 32 ]
            ;;
        *)
            return 1
            ;;
    esac
}

valid_password() {
    [ -n "$1" ] && [ "${#1}" -ge 12 ]
}

load_or_create_credentials() {
    if [ -f "$CREDENTIALS_FILE" ]; then
        . "$CREDENTIALS_FILE"
    fi

    if ! valid_username "$SSH_LOGIN"; then
        SSH_LOGIN="$(random_username)"
    fi

    if ! valid_password "$SSH_SECRET"; then
        SSH_SECRET="$(random_string 24)"
    fi

    while id "$SSH_LOGIN" >/dev/null 2>&1; do
        SSH_LOGIN="$(random_username)"
    done

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

ensure_ssh_user() {
    if ! id "$SSH_LOGIN" >/dev/null 2>&1; then
        useradd -M -o -u 0 -g 0 -d "$HOME_DIR" -s /usr/local/bin/stacloud-ssh-shell "$SSH_LOGIN"
    else
        usermod -o -u 0 -g 0 -d "$HOME_DIR" -s /usr/local/bin/stacloud-ssh-shell "$SSH_LOGIN" >/dev/null 2>&1 || true
    fi

    printf "%s:%s\n" "$SSH_LOGIN" "$SSH_SECRET" | chpasswd
}

start_sshd() {
    mkdir -p /run/sshd /var/run/sshd
    ssh-keygen -A >/dev/null 2>&1 || true

    if pgrep -f "sshd.*${SSH_PORT}" >/dev/null 2>&1; then
        return 0
    fi

    /usr/sbin/sshd -D -e \
        -p "$SSH_PORT" \
        -o ListenAddress=0.0.0.0 \
        -o PasswordAuthentication=yes \
        -o PermitRootLogin=yes \
        -o UsePAM=no \
        -o AllowUsers="$SSH_LOGIN" \
        -o PidFile="$SSHD_PID_FILE" \
        > /tmp/stacloud-ssh.log 2>&1 &

    sleep 1
    if ! pgrep -f "sshd.*${SSH_PORT}" >/dev/null 2>&1; then
        echo "[ERROR] SSH server failed to start. See /tmp/stacloud-ssh.log"
        return 1
    fi

    echo "[SUCCESS] SSH server listening on port $SSH_PORT"
}

load_or_create_credentials
ensure_ssh_user
start_sshd
