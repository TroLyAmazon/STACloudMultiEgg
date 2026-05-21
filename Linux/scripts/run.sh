#!/bin/sh

. /common.sh

HOSTNAME="${SERVER_NAME:-STACloud}"
HISTORY_FILE="${HOME}/.custom_shell_history"
MAX_HISTORY=1000
CREDENTIALS_FILE="/.stacloud_credentials"
GUI_CONFIG_FILE="/gui_config.yml"
VNC_DIR="$HOME/.vnc"

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

random_string() {
    length="${1:-16}"
    if [ -r /dev/urandom ]; then
        tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
    else
        date +%s%N | sha256sum | cut -c 1-"$length"
    fi
}

load_or_create_credentials() {
    if [ -f "$CREDENTIALS_FILE" ]; then
        . "$CREDENTIALS_FILE"
    else
        generated_user="u$(random_string 10 | tr 'A-Z' 'a-z')"
        generated_password="$(random_string 24)"
        SSH_LOGIN="${SSH_USER:-$generated_user}"
        SSH_SECRET="${SSH_PASSWORD:-$generated_password}"
        {
            printf "SSH_LOGIN=%s\n" "$SSH_LOGIN"
            printf "SSH_SECRET=%s\n" "$SSH_SECRET"
        } > "$CREDENTIALS_FILE"
        chmod 600 "$CREDENTIALS_FILE" 2>/dev/null || true
    fi

    SSH_LOGIN="${SSH_LOGIN:-root}"
    SSH_SECRET="${SSH_SECRET:-$(random_string 24)}"
    case "$SSH_PORT" in
        ""|"{{SERVER_PORT}}"|"{{server.build.default.port}}")
            SSH_PORT="${SERVER_PORT:-2222}"
            ;;
    esac
    export SSH_LOGIN SSH_SECRET SSH_PORT
}

write_runtime_config() {
    if [ ! -f /vps.config ]; then
        {
            printf "ssh=%s\n" "${SSH_PORT:-}"
            printf "novnc=%s\n" "${NOVNC_PORT:-}"
            printf "webapp=%s\n" "${WEB_APP_PORT:-}"
            printf "api=%s\n" "${API_PORT:-}"
            printf "botpanel=%s\n" "${BOT_PANEL_PORT:-}"
        } > /vps.config
    fi
}

process_matches() {
    pattern="$1"
    if command -v pgrep >/dev/null 2>&1; then
        pgrep -f "$pattern" >/dev/null 2>&1
    else
        ps 2>/dev/null | grep "$pattern" | grep -v grep >/dev/null 2>&1
    fi
}

start_ssh_server() {
    log "INFO" "SSH is managed by the STACloud runtime outside the VPS rootfs." "$YELLOW"
    return 0
}

get_formatted_dir() {
    current_dir="$PWD"
    case "$current_dir" in
        "$HOME"*) printf "~%s" "${current_dir#$HOME}" ;;
        *) printf "%s" "$current_dir" ;;
    esac
}

print_prompt() {
    printf "\n%b%s@%s%b:%b%s%b# " "$GREEN" "$1" "$HOSTNAME" "$NC" "$BLUE" "$(get_formatted_dir)" "$NC"
}

save_to_history() {
    cmd="$1"
    if [ -n "$cmd" ] && [ "$cmd" != "exit" ]; then
        printf "%s\n" "$cmd" >> "$HISTORY_FILE"
        tail -n "$MAX_HISTORY" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" 2>/dev/null && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    fi
}

print_access_info() {
    panel_ip="${SERVER_IP:-<server-ip>}"
    printf "%bAccess%b\n" "$CYAN$BOLD" "$NC"
    printf "  SSH       : %s:%s\n" "$panel_ip" "$SSH_PORT"
    printf "  User      : %s\n" "$SSH_LOGIN"
    printf "  Password  : %s\n" "$SSH_SECRET"

    if [ -n "$NOVNC_PORT" ]; then
        printf "  VNC Web   : http://%s:%s/vnc.html\n" "$panel_ip" "$NOVNC_PORT"
    else
        printf "  VNC Web   : blank - set noVNC allocation to use web VNC\n"
    fi

    [ -n "$WEB_APP_PORT" ] && printf "  Web app   : %s\n" "$WEB_APP_PORT" || printf "  Web app   : blank\n"
    [ -n "$API_PORT" ] && printf "  API       : %s\n" "$API_PORT" || printf "  API       : blank\n"
    [ -n "$BOT_PANEL_PORT" ] && printf "  Bot panel : %s\n" "$BOT_PANEL_PORT" || printf "  Bot panel : blank\n"
    printf "\n"
}

bootstrap_rootfs() {
    if [ ! -e "/.stacloud_bootstrapped" ]; then
        rm -f /rootfs.tar.xz /rootfs.tar.gz
        printf "nameserver 1.1.1.1\nnameserver 1.0.0.1\n" > /etc/resolv.conf 2>/dev/null || true
        touch /autorun.sh
        chmod +x /autorun.sh
        touch "/.stacloud_bootstrapped"
    fi
}

reinstall() {
    log "WARNING" "Wiping this VPS rootfs. The container will stop after cleanup." "$YELLOW"
    find / -mindepth 1 -xdev \
        ! -path /proc ! -path '/proc/*' \
        ! -path /sys ! -path '/sys/*' \
        ! -path /dev ! -path '/dev/*' \
        -delete >/dev/null 2>&1
    exit 2
}

parse_gui_config() {
    GUI_DE=""
    GUI_DE_STARTUP=""
    VNC_LISTEN_PORT="5901"
    NOVNC_LISTEN_PORT="${NOVNC_PORT:-6080}"
    VNC_PASSWORD=""

    if [ -f "$GUI_CONFIG_FILE" ]; then
        GUI_DE="$(grep -E '^\s*environment:' "$GUI_CONFIG_FILE" | sed 's/.*: *"\?\([^"]*\)"\?/\1/' | tr -d ' ')"
        GUI_DE_STARTUP="$(grep -E '^\s*startup_command:' "$GUI_CONFIG_FILE" | sed 's/.*: *"\?\([^"]*\)"\?/\1/' | tr -d ' ')"
        config_vnc_port="$(grep -A5 '^vnc:' "$GUI_CONFIG_FILE" | grep -E '^\s*port:' | head -1 | sed 's/.*: *"\?\([^"]*\)"\?/\1/' | tr -d ' ')"
        config_vnc_password="$(grep -A5 '^vnc:' "$GUI_CONFIG_FILE" | grep -E '^\s*password:' | sed 's/.*: *"\?\([^"]*\)"\?/\1/' | tr -d ' ')"
        config_novnc_port="$(grep -A3 '^novnc:' "$GUI_CONFIG_FILE" | grep -E '^\s*port:' | sed 's/.*: *"\?\([^"]*\)"\?/\1/' | tr -d ' ')"

        [ -n "$config_vnc_port" ] && VNC_LISTEN_PORT="$config_vnc_port"
        [ -n "$config_vnc_password" ] && VNC_PASSWORD="$config_vnc_password"
        [ -z "$NOVNC_PORT" ] && [ -n "$config_novnc_port" ] && NOVNC_LISTEN_PORT="$config_novnc_port"
    fi

    if [ -z "$GUI_DE_STARTUP" ]; then
        case "$GUI_DE" in
            xfce4) GUI_DE_STARTUP="startxfce4" ;;
            lxde) GUI_DE_STARTUP="startlxde" ;;
            lxqt) GUI_DE_STARTUP="startlxqt" ;;
            mate) GUI_DE_STARTUP="mate-session" ;;
            *) GUI_DE_STARTUP="startxfce4" ;;
        esac
    fi
}

install_gui() {
    if [ -f "$GUI_CONFIG_FILE" ]; then
        log "WARNING" "GUI is already installed. Use reinstall-gui to reinstall." "$YELLOW"
        return 1
    fi

    if [ -f /vnc_install.sh ]; then
        export SSH_SECRET NOVNC_PORT
        sh /vnc_install.sh install
    else
        log "ERROR" "VNC installer is missing." "$RED"
        return 1
    fi
}

reinstall_gui() {
    rm -f "$GUI_CONFIG_FILE"
    rm -rf "$VNC_DIR"
    rm -f "$HOME/.xsession"
    install_gui
}

start_desktop_env() {
    display_num="$1"
    export DISPLAY=":$display_num"
    export XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"
    mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
    chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true

    case "$GUI_DE" in
        xfce4)
            xfwm4 --compositor=off 2>/dev/null &
            sleep 1
            xfce4-panel 2>/dev/null &
            xfdesktop 2>/dev/null &
            ;;
        lxde)
            openbox 2>/dev/null &
            sleep 1
            lxpanel 2>/dev/null &
            pcmanfm --desktop 2>/dev/null &
            ;;
        lxqt)
            openbox 2>/dev/null &
            sleep 1
            lxqt-panel 2>/dev/null &
            pcmanfm-qt --desktop 2>/dev/null &
            ;;
        mate)
            marco 2>/dev/null &
            sleep 1
            mate-panel 2>/dev/null &
            caja --no-desktop 2>/dev/null &
            ;;
        *)
            "$GUI_DE_STARTUP" 2>/dev/null &
            ;;
    esac
}

start_vnc() {
    if [ ! -f "$GUI_CONFIG_FILE" ]; then
        log "ERROR" "GUI not installed. Run install-gui first." "$RED"
        return 1
    fi

    parse_gui_config
    if process_matches "Xvnc.*:$((VNC_LISTEN_PORT - 5900))" || process_matches "Xtigervnc.*:$((VNC_LISTEN_PORT - 5900))" || process_matches "x11vnc"; then
        log "WARNING" "VNC is already running." "$YELLOW"
        return 0
    fi

    display_num=$((VNC_LISTEN_PORT - 5900))
    [ "$display_num" -lt 1 ] && display_num=1

    mkdir -p "$HOME/.vnc" /tmp/.X11-unix 2>/dev/null || true
    vnc_security="-SecurityTypes None"

    if [ -n "$VNC_PASSWORD" ]; then
        printf "%s\n%s\nn\n" "$VNC_PASSWORD" "$VNC_PASSWORD" | vncpasswd "$HOME/.vnc/passwd" >/dev/null 2>&1 || true
        [ -f "$HOME/.vnc/passwd" ] && vnc_security="-SecurityTypes VncAuth -PasswordFile $HOME/.vnc/passwd"
    fi

    log "INFO" "Starting VNC on port $VNC_LISTEN_PORT" "$YELLOW"
    if command -v Xtigervnc >/dev/null 2>&1; then
        Xtigervnc ":$display_num" -geometry 1280x720 -depth 24 -rfbport "$VNC_LISTEN_PORT" $vnc_security -pn -ac >/tmp/stacloud-vnc.log 2>&1 &
        sleep 2
        start_desktop_env "$display_num"
    elif command -v Xvnc >/dev/null 2>&1; then
        Xvnc ":$display_num" -geometry 1280x720 -depth 24 -rfbport "$VNC_LISTEN_PORT" $vnc_security -pn -ac >/tmp/stacloud-vnc.log 2>&1 &
        sleep 2
        start_desktop_env "$display_num"
    elif command -v x11vnc >/dev/null 2>&1 && command -v Xvfb >/dev/null 2>&1; then
        Xvfb ":$display_num" -screen 0 1280x720x24 -ac >/tmp/stacloud-xvfb.log 2>&1 &
        sleep 2
        start_desktop_env "$display_num"
        if [ -n "$VNC_PASSWORD" ]; then
            x11vnc -display ":$display_num" -rfbport "$VNC_LISTEN_PORT" -forever -shared -passwd "$VNC_PASSWORD" -bg >/tmp/stacloud-vnc.log 2>&1
        else
            x11vnc -display ":$display_num" -rfbport "$VNC_LISTEN_PORT" -forever -shared -nopw -bg >/tmp/stacloud-vnc.log 2>&1
        fi
    else
        log "ERROR" "No VNC server found." "$RED"
        return 1
    fi

    sleep 1
    log "SUCCESS" "VNC started on port $VNC_LISTEN_PORT" "$GREEN"
}

stop_vnc() {
    log "INFO" "Stopping VNC" "$YELLOW"
    if command -v vncserver >/dev/null 2>&1; then
        parse_gui_config
        display_num=$((VNC_LISTEN_PORT - 5900))
        [ "$display_num" -lt 1 ] && display_num=1
        vncserver -kill ":$display_num" >/dev/null 2>&1 || true
    fi
    pkill -f "Xvnc" >/dev/null 2>&1 || true
    pkill -f "Xtigervnc" >/dev/null 2>&1 || true
    pkill -f "x11vnc" >/dev/null 2>&1 || true
    pkill -f "Xvfb" >/dev/null 2>&1 || true
    log "SUCCESS" "VNC stopped" "$GREEN"
}

start_novnc() {
    if [ ! -f "$GUI_CONFIG_FILE" ]; then
        log "ERROR" "GUI not installed. Run install-gui first." "$RED"
        return 1
    fi

    parse_gui_config
    if process_matches "websockify.*$NOVNC_LISTEN_PORT"; then
        log "WARNING" "noVNC is already running." "$YELLOW"
        return 0
    fi

    start_vnc || return 1

    novnc_path=""
    [ -d /usr/share/novnc ] && novnc_path="/usr/share/novnc"
    [ -d /usr/share/webapps/novnc ] && novnc_path="/usr/share/webapps/novnc"

    log "INFO" "Starting noVNC on port $NOVNC_LISTEN_PORT" "$YELLOW"
    if command -v websockify >/dev/null 2>&1; then
        if [ -n "$novnc_path" ]; then
            websockify --web="$novnc_path" "$NOVNC_LISTEN_PORT" localhost:"$VNC_LISTEN_PORT" >/tmp/stacloud-novnc.log 2>&1 &
        else
            websockify "$NOVNC_LISTEN_PORT" localhost:"$VNC_LISTEN_PORT" >/tmp/stacloud-novnc.log 2>&1 &
        fi
    elif [ -n "$novnc_path" ] && [ -x "$novnc_path/utils/novnc_proxy" ]; then
        "$novnc_path/utils/novnc_proxy" --listen "$NOVNC_LISTEN_PORT" --vnc "localhost:$VNC_LISTEN_PORT" >/tmp/stacloud-novnc.log 2>&1 &
    else
        log "ERROR" "websockify/noVNC not found." "$RED"
        return 1
    fi

    sleep 2
    log "SUCCESS" "noVNC started at http://<server-ip>:$NOVNC_LISTEN_PORT/vnc.html" "$GREEN"
}

stop_novnc() {
    log "INFO" "Stopping noVNC" "$YELLOW"
    pkill -f "websockify" >/dev/null 2>&1 || true
    pkill -f "novnc_proxy" >/dev/null 2>&1 || true
    log "SUCCESS" "noVNC stopped" "$GREEN"
}

gui_status() {
    parse_gui_config
    printf "\n%bGUI status%b\n" "$CYAN$BOLD" "$NC"
    if [ -f "$GUI_CONFIG_FILE" ]; then
        printf "  Desktop : %s\n" "$GUI_DE"
        printf "  VNC     : %s\n" "$VNC_LISTEN_PORT"
        printf "  noVNC   : %s\n" "$NOVNC_LISTEN_PORT"
    else
        printf "  GUI     : not installed\n"
    fi

    process_matches "Xvnc|Xtigervnc|x11vnc" && printf "  VNC run : yes\n" || printf "  VNC run : no\n"
    process_matches "websockify|novnc_proxy" && printf "  Web run : yes\n" || printf "  Web run : no\n"
    printf "\n"
}

show_system_status() {
    log "INFO" "System status" "$GREEN"
    uname -a 2>/dev/null || true
    uptime 2>/dev/null || true
    free -h 2>/dev/null || true
    df -h / 2>/dev/null || true
}

cleanup() {
    log "INFO" "Session ended." "$GREEN"
    exit 0
}

execute_command() {
    cmd="$1"
    user="$2"
    save_to_history "$cmd"

    case "$cmd" in
        clear|cls)
            printf "\033c"
            ;;
        exit)
            cleanup
            ;;
        history)
            [ -f "$HISTORY_FILE" ] && cat "$HISTORY_FILE"
            ;;
        help)
            print_help_banner
            ;;
        status)
            show_system_status
            ;;
        reinstall)
            reinstall
            ;;
        install-ssh)
            start_ssh_server
            ;;
        install-gui)
            install_gui
            ;;
        reinstall-gui)
            reinstall_gui
            ;;
        start-vnc)
            start_vnc
            ;;
        stop-vnc)
            stop_vnc
            ;;
        start-novnc)
            start_novnc
            ;;
        stop-novnc)
            stop_novnc
            ;;
        gui-status)
            gui_status
            ;;
        sudo*|su*)
            log "INFO" "Already running as root." "$YELLOW"
            ;;
        "")
            ;;
        *)
            eval "$cmd"
            ;;
    esac

    print_prompt "$user"
}

bootstrap_rootfs
load_or_create_credentials
write_runtime_config
touch "$HISTORY_FILE"
trap cleanup INT TERM

print_main_banner
start_ssh_server
print_access_info

if [ -n "$NOVNC_PORT" ] && [ -f "$GUI_CONFIG_FILE" ]; then
    start_novnc
fi

if [ -x /autorun.sh ]; then
    sh /autorun.sh
fi

print_prompt "root"
while true; do
    read -r cmd
    execute_command "$cmd" "root"
done
