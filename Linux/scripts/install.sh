#!/bin/sh

. /common.sh

ROOTFS_DIR="/home/container"
BASE_URL="https://images.linuxcontainers.org/images"

error_exit() {
    log "ERROR" "$1" "$RED"
    exit 1
}

default_version_for() {
    case "$1" in
        rockylinux) echo "10" ;;
        almalinux) echo "10" ;;
        centos) echo "10-Stream" ;;
        oracle) echo "9" ;;
        ubuntu) echo "noble" ;;
        debian) echo "trixie" ;;
        kali) echo "current" ;;
        archlinux) echo "current" ;;
        mint) echo "zena" ;;
        *) return 1 ;;
    esac
}

display_name_for() {
    case "$1" in
        rockylinux) echo "Rocky Linux" ;;
        almalinux) echo "AlmaLinux" ;;
        centos) echo "CentOS" ;;
        oracle) echo "Oracle Linux" ;;
        ubuntu) echo "Ubuntu" ;;
        debian) echo "Debian" ;;
        kali) echo "Kali Linux" ;;
        archlinux) echo "Arch Linux" ;;
        mint) echo "Linux Mint" ;;
        *) return 1 ;;
    esac
}

validate_distro() {
    case "$1" in
        rockylinux|almalinux|centos|oracle|ubuntu|debian|kali|archlinux|mint) return 0 ;;
        *) return 1 ;;
    esac
}

check_network() {
    curl -fsSI "$BASE_URL" >/dev/null 2>&1 || error_exit "Unable to connect to the STACloud rootfs source"
}

latest_build_for() {
    url="$1"
    latest="$(curl -fsSL "$url" | grep -o '[0-9]\{8\}_[0-9]\{2\}:[0-9]\{2\}/' | tr -d '/' | sort -r | head -n 1)"
    [ -n "$latest" ] || error_exit "Unable to determine latest rootfs build at $url"
    echo "$latest"
}

download_and_extract_rootfs() {
    distro="$1"
    version="$2"
    arch="$3"
    name="$4"

    rootfs_base="${BASE_URL}/${distro}/${version}/${arch}/default/"
    log "INFO" "Installing $name $version for $arch" "$GREEN"

    curl -fsSL "$rootfs_base" >/dev/null 2>&1 || error_exit "$name $version does not support $arch"
    latest_build="$(latest_build_for "$rootfs_base")"
    archive_url="${rootfs_base}${latest_build}/rootfs.tar.xz"

    mkdir -p "$ROOTFS_DIR"
    log "INFO" "Downloading STACloud rootfs" "$GREEN"
    curl -fL "$archive_url" -o "$ROOTFS_DIR/rootfs.tar.xz" || error_exit "Failed to download rootfs"

    log "INFO" "Extracting rootfs" "$GREEN"
    tar -xf "$ROOTFS_DIR/rootfs.tar.xz" -C "$ROOTFS_DIR" || error_exit "Failed to extract rootfs"
    rm -f "$ROOTFS_DIR/rootfs.tar.xz"
    rm -f "$ROOTFS_DIR/etc/resolv.conf"
    mkdir -p "$ROOTFS_DIR/home/container"
}

post_install_config() {
    distro="$1"
    if [ "$distro" = "archlinux" ] && [ -f "$ROOTFS_DIR/etc/pacman.conf" ]; then
        sed -i '/^#RootDir/s/^#//' "$ROOTFS_DIR/etc/pacman.conf"
        sed -i 's|/var/lib/pacman/|/var/lib/pacman|' "$ROOTFS_DIR/etc/pacman.conf"
        sed -i '/^#DBPath/s/^#//' "$ROOTFS_DIR/etc/pacman.conf"
    fi

    if [ -x "$ROOTFS_DIR/usr/bin/gnuls" ] && [ -x "$ROOTFS_DIR/usr/bin/gnurm" ] && [ -x "$ROOTFS_DIR/usr/bin/gnuln" ]; then
        for gnu_path in "$ROOTFS_DIR"/usr/bin/gnu*; do
            [ -e "$gnu_path" ] || continue
            gnu_name="$(basename "$gnu_path")"
            target_name="${gnu_name#gnu}"
            [ -n "$target_name" ] && [ "$target_name" != "$gnu_name" ] || continue
            rm -f "$ROOTFS_DIR/usr/bin/$target_name"
            ln -s "$gnu_name" "$ROOTFS_DIR/usr/bin/$target_name"
        done
    fi
}

copy_runtime_scripts() {
    cp /common.sh /run.sh "$ROOTFS_DIR"
    chmod +x "$ROOTFS_DIR/common.sh" "$ROOTFS_DIR/run.sh"

    if [ -f /vnc_install.sh ]; then
        cp /vnc_install.sh "$ROOTFS_DIR"
        chmod +x "$ROOTFS_DIR/vnc_install.sh"
    fi
}

DISTRO_ID="${STA_LINUX_DISTRO:-debian}"
validate_distro "$DISTRO_ID" || error_exit "Unsupported distro: $DISTRO_ID"

DISTRO_VERSION="${STA_LINUX_VERSION:-$(default_version_for "$DISTRO_ID")}"
DISTRO_NAME="${STA_LINUX_NAME:-$(display_name_for "$DISTRO_ID")}"
ARCH_ALT="$(detect_architecture)" || exit 1

check_network
download_and_extract_rootfs "$DISTRO_ID" "$DISTRO_VERSION" "$ARCH_ALT" "$DISTRO_NAME"
post_install_config "$DISTRO_ID"
copy_runtime_scripts
touch "$ROOTFS_DIR/.rootfs_installed"

log "SUCCESS" "$DISTRO_NAME rootfs installed" "$GREEN"
