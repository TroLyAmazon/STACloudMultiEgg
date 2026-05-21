#!/bin/sh

CREDENTIALS_FILE="/home/container/.stacloud_credentials"
EXPECTED_USER="stacloud"

[ "$PAM_USER" = "$EXPECTED_USER" ] || exit 1
[ -r "$CREDENTIALS_FILE" ] || exit 1

. "$CREDENTIALS_FILE"
[ "$SSH_LOGIN" = "$EXPECTED_USER" ] || exit 1
[ -n "$SSH_SECRET" ] || exit 1

IFS= read -r supplied_password || exit 1
[ "$supplied_password" = "$SSH_SECRET" ]
