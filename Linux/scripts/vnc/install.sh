#!/bin/sh

if [ -f /common.sh ]; then
    . /common.sh
elif [ -f "$HOME/common.sh" ]; then
    . "$HOME/common.sh"
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
    log() { printf "%b[%s]%b %s\n" "$3" "$1" "$NC" "$2"; }
fi

VNC_DIR="$HOME/.vnc"
GUI_CONFIG_FILE="/gui_config.yml"

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

print_de_selection_menu() {
    printf "\n%bSelect Desktop Environment%b\n\n" "$CYAN" "$NC"
    printf "* [1] XFCE4 - lightweight\n"
    printf "* [2] LXDE - very lightweight\n"
    printf "* [3] LXQt - lightweight Qt desktop\n"
    printf "* [4] MATE - traditional desktop\n"
    printf "* [0] Cancel\n"
    printf "\n%bEnter choice (0-4):%b\n" "$YELLOW" "$NC"
}

get_port_input() {
    label="$1"
    default_port="$2"
    printf "%bEnter %s port (default: %s):%b\n" "$YELLOW" "$label" "$default_port" "$NC" >&2
    read -r port_input
    [ -z "$port_input" ] && { echo "$default_port"; return; }

    case "$port_input" in
        *[!0-9]*)
            log "WARNING" "Invalid port, using $default_port" "$YELLOW" >&2
            echo "$default_port"
            ;;
        *)
            if [ "$port_input" -ge 1 ] && [ "$port_input" -le 65535 ]; then
                echo "$port_input"
            else
                log "WARNING" "Port out of range, using $default_port" "$YELLOW" >&2
                echo "$default_port"
            fi
            ;;
    esac
}

install_de_debian() {
    de="$1"
    DEBIAN_FRONTEND=noninteractive apt-get update -qq >&2
    case "$de" in
        xfce4)
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq xfce4 xfce4-terminal dbus-x11 x11-xserver-utils xfonts-base >&2
            echo "startxfce4"
            ;;
        lxde)
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq lxde-core lxterminal dbus-x11 x11-xserver-utils xfonts-base >&2
            echo "startlxde"
            ;;
        lxqt)
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq lxqt openbox dbus-x11 x11-xserver-utils xfonts-base >&2
            echo "startlxqt"
            ;;
        mate)
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq mate-desktop-environment-core dbus-x11 x11-xserver-utils xfonts-base >&2
            echo "mate-session"
            ;;
    esac
}

install_de_arch() {
    de="$1"
    pacman -Syu --noconfirm >&2
    case "$de" in
        xfce4)
            pacman -S --noconfirm --needed xfce4 xfce4-goodies xorg-server xorg-xinit dbus ttf-dejavu >&2
            echo "startxfce4"
            ;;
        lxde)
            pacman -S --noconfirm --needed lxde xorg-server xorg-xinit dbus ttf-dejavu >&2
            echo "startlxde"
            ;;
        lxqt)
            pacman -S --noconfirm --needed lxqt openbox xorg-server xorg-xinit dbus ttf-dejavu >&2
            echo "startlxqt"
            ;;
        mate)
            pacman -S --noconfirm --needed mate mate-extra xorg-server xorg-xinit dbus ttf-dejavu >&2
            echo "mate-session"
            ;;
    esac
}

enable_epel() {
    if ! command -v dnf >/dev/null 2>&1; then
        return 0
    fi

    dnf install -y epel-release >/dev/null 2>&1 && return 0
    rhel_major="$(rpm -E '%rhel' 2>/dev/null || echo 9)"

    if [ "$(detect_distro)" = "ol" ]; then
        dnf install -y "oracle-epel-release-el${rhel_major}" >/dev/null 2>&1 && return 0
    fi

    dnf install -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${rhel_major}.noarch.rpm" >/dev/null 2>&1 || true
}

install_de_rhel() {
    de="$1"
    enable_epel
    dnf install -y dbus-x11 xorg-x11-server-Xvfb xterm dejavu-sans-fonts xorg-x11-xauth >&2 || true

    case "$de" in
        xfce4)
            dnf groupinstall -y "Xfce" >&2 || dnf install -y xfce4-session xfwm4 xfce4-panel xfdesktop xfce4-terminal Thunar >&2
            echo "startxfce4"
            ;;
        lxde)
            dnf install -y openbox lxpanel lxsession pcmanfm lxterminal >&2
            echo "lxsession"
            ;;
        lxqt)
            dnf install -y openbox lxqt-session lxqt-panel pcmanfm-qt qterminal >&2
            echo "startlxqt"
            ;;
        mate)
            dnf groupinstall -y "MATE Desktop" >&2 || dnf install -y mate-session-manager marco mate-panel caja mate-terminal >&2
            echo "mate-session"
            ;;
    esac
}

install_desktop_environment() {
    distro="$1"
    de="$2"
    log "INFO" "Installing $de desktop environment" "$YELLOW" >&2

    case "$distro" in
        debian|ubuntu|linuxmint|kali)
            install_de_debian "$de"
            ;;
        arch)
            install_de_arch "$de"
            ;;
        rocky|almalinux|centos|ol)
            install_de_rhel "$de"
            ;;
        *)
            log "ERROR" "Unsupported GUI distro: $distro" "$RED" >&2
            return 1
            ;;
    esac
}

install_vnc_server() {
    distro="$1"
    log "INFO" "Installing VNC/noVNC packages" "$YELLOW"

    case "$distro" in
        debian|ubuntu|linuxmint|kali)
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq tigervnc-standalone-server tigervnc-common novnc websockify >/dev/null 2>&1
            ;;
        arch)
            pacman -S --noconfirm --needed tigervnc novnc websockify >/dev/null 2>&1
            ;;
        rocky|almalinux|centos|ol)
            dnf install -y tigervnc-server novnc python3-websockify >/dev/null 2>&1 || dnf install -y tigervnc-server python3-websockify >/dev/null 2>&1
            ;;
    esac
}

setup_vnc() {
    de_startup="$1"
    vnc_password="$2"

    mkdir -p "$VNC_DIR"
    cat > "$VNC_DIR/xstartup" << XSTARTUP
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
[ -r "\$HOME/.Xresources" ] && xrdb "\$HOME/.Xresources"
exec $de_startup
XSTARTUP
    chmod +x "$VNC_DIR/xstartup"

    cat > "$VNC_DIR/config" << EOF
geometry=1280x720
depth=24
localhost=no
alwaysshared
EOF

    if command -v vncpasswd >/dev/null 2>&1; then
        printf "%s\n%s\nn\n" "$vnc_password" "$vnc_password" | vncpasswd >/dev/null 2>&1 || true
    fi
}

save_config() {
    de="$1"
    vnc_port="$2"
    vnc_password="$3"
    novnc_port="$4"
    de_startup="$5"

    cat > "$GUI_CONFIG_FILE" << EOF
desktop:
  environment: "$de"
  startup_command: "$de_startup"

vnc:
  port: "$vnc_port"
  password: "$vnc_password"
  resolution: "1280x720"
  depth: "24"

novnc:
  enable: true
  port: "$novnc_port"
EOF
}

main() {
    distro="$(detect_distro)"
    log "INFO" "Detected distribution: $distro" "$GREEN"

    print_de_selection_menu
    read -r de_choice
    case "$de_choice" in
        0) log "INFO" "Installation cancelled" "$YELLOW"; return 0 ;;
        1) de="xfce4" ;;
        2) de="lxde" ;;
        3) de="lxqt" ;;
        4) de="mate" ;;
        *) log "ERROR" "Invalid selection" "$RED"; return 1 ;;
    esac

    vnc_port="$(get_port_input "VNC" "${VNC_PORT:-5901}")"
    novnc_port="$(get_port_input "noVNC web" "${NOVNC_PORT:-6080}")"

    printf "%bEnter VNC password (blank uses generated SSH password):%b\n" "$YELLOW" "$NC"
    read -r gui_password
    gui_password="${gui_password:-${VNC_PASSWORD:-${SSH_SECRET:-password}}}"

    de_startup="$(install_desktop_environment "$distro" "$de")" || return 1
    [ -n "$de_startup" ] || return 1

    install_vnc_server "$distro"
    setup_vnc "$de_startup" "$gui_password"
    save_config "$de" "$vnc_port" "$gui_password" "$novnc_port" "$de_startup"

    log "SUCCESS" "GUI installed" "$GREEN"
    printf "VNC port: %s\n" "$vnc_port"
    printf "noVNC URL: http://<server-ip>:%s/vnc.html\n" "$novnc_port"
    printf "Start command: start-novnc\n"
}

if [ "$1" = "install" ] || [ -z "$1" ]; then
    main
fi

