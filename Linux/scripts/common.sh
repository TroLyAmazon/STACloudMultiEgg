#!/bin/sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

log() {
    level="$1"
    message="$2"
    color="${3:-$NC}"
    printf "%b[%s]%b %s\n" "$color" "$level" "$NC" "$message"
}

detect_architecture() {
    arch="$(uname -m)"
    case "$arch" in
        x86_64) echo "amd64" ;;
        aarch64) echo "arm64" ;;
        riscv64) echo "riscv64" ;;
        *)
            log "ERROR" "Unsupported CPU architecture: $arch" "$RED" >&2
            return 1
            ;;
    esac
}

print_main_banner() {
    printf "\033c"
    printf "%b============================================================%b\n" "$CYAN" "$NC"
    printf "%bSTACloud Linux VPS%b\n" "$GREEN$BOLD" "$NC"
    printf "Image distro: %s (%s)\n" "${STA_LINUX_NAME:-Linux}" "${STA_LINUX_VERSION:-default}"
    printf "Type 'help' to list commands.\n"
    printf "%b============================================================%b\n\n" "$CYAN" "$NC"
}

print_help_banner() {
    printf "\n%bCommands%b\n" "$CYAN$BOLD" "$NC"
    printf "  help             Show this command list\n"
    printf "  clear, cls       Clear the console\n"
    printf "  exit             Stop the server\n"
    printf "  history          Show command history\n"
    printf "  status           Show basic system status\n"
    printf "  reinstall        Wipe the VPS rootfs on next restart\n"
    printf "  install-ssh      Install or restart the built-in SSH server\n"
    printf "  install-gui      Install desktop environment and VNC/noVNC\n"
    printf "  reinstall-gui    Reinstall desktop environment and VNC/noVNC\n"
    printf "  start-vnc        Start VNC only\n"
    printf "  stop-vnc         Stop VNC\n"
    printf "  start-novnc      Start web VNC through noVNC\n"
    printf "  stop-novnc       Stop noVNC\n"
    printf "  gui-status       Show VNC/noVNC status\n\n"
}

