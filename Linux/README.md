# STACloud Linux Egg

This folder contains the STACloud Linux VPS egg, installer image, Docker runtime, and non-root SSH server.

## Images

The GitHub Actions workflow builds `ghcr.io/sta-cloud-dev/linux:installer` and the versioned tags listed in `images.json`, including:

- Rocky Linux 8, 9, 10
- AlmaLinux 8, 9, 10
- CentOS Stream 9, 10
- Oracle Linux 8, 9
- Ubuntu 22.04 LTS, 24.04 LTS, 25.10, 26.04 LTS
- Debian 11 Bullseye, 12 Bookworm, 13 Trixie, Forky
- Kali Linux current
- Arch Linux current
- Linux Mint 21, 21.1, 21.2, 21.3, 22, 22.1, 22.2, 22.3

Linux Mint is built for `linux/amd64` only because the Linux Containers rootfs index currently does not publish `arm64` builds for the selected Mint releases.

## Egg

Import `../Egg/Linux/egg-linux.json` into your panel.

Variables:

- `SSH`: defaults to the panel primary allocation port.
- `SSH_USER`: fixed to `stacloud`. Not user editable.
- `SSH_PASSWORD`: left blank in the panel and generated on first start. Not user editable.
- `noVNC`, `Web app`, `API`, and `Bot panel`: optional port variables, blank by default.

The runtime starts the packaged SSH daemon with the fixed `stacloud` user and a random password generated on first start.

The web console prints SSH credentials and the noVNC URL when a noVNC port is set. Use `install-gui`, then `start-novnc` to enable browser VNC for a server.
