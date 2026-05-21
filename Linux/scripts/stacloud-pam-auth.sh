#!/bin/sh

CREDENTIALS_FILE="/home/container/.stacloud_credentials"
EXPECTED_USER="stacloud"
LOG_FILE="/tmp/stacloud-pam-auth.log"

fail() {
    printf "%s\n" "$1" > "$LOG_FILE" 2>/dev/null || true
    exit 1
}

[ "$PAM_USER" = "$EXPECTED_USER" ] || fail "unexpected PAM user"
[ -r "$CREDENTIALS_FILE" ] || fail "credentials file is not readable"

. "$CREDENTIALS_FILE" || fail "failed to load credentials"
[ "$SSH_LOGIN" = "$EXPECTED_USER" ] || fail "credential user mismatch"
[ -n "$SSH_SECRET" ] || fail "credential password is empty"

supplied_password=""
IFS= read -r supplied_password || [ -n "$supplied_password" ] || fail "password was not supplied"
[ "$supplied_password" = "$SSH_SECRET" ] || fail "password mismatch"

exit 0
