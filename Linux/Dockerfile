ARG TARGETPLATFORM

FROM --platform=$TARGETPLATFORM debian:trixie-slim AS proot-builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && build_deps="build-essential ca-certificates git libtalloc-dev pkg-config python3" \
    && if [ "$(dpkg --print-architecture)" = "amd64" ]; then build_deps="$build_deps gcc-multilib"; fi \
    && apt-get install -y --no-install-recommends $build_deps \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --recurse-submodules --shallow-submodules https://github.com/proot-me/proot.git /src/proot \
    && make -C /src/proot/src loader.elf build.h \
    && make -C /src/proot/src proot \
    && strip /src/proot/src/proot

FROM --platform=$TARGETPLATFORM debian:trixie-slim AS ssh-builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git golang-go \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src/sshserver
COPY ./sshserver/go.mod ./sshserver/go.sum ./
RUN go mod download
COPY ./sshserver/main.go ./
RUN mkdir -p /out \
    && go build -trimpath -ldflags="-s -w" -o /out/stacloud-ssh-server .

FROM --platform=$TARGETPLATFORM debian:trixie-slim

ARG STA_LINUX_DISTRO=debian
ARG STA_LINUX_NAME=Debian
ARG STA_LINUX_VERSION=trixie

LABEL author="STACloud" maintainer="stacloud.dev@gmail.com"
LABEL org.opencontainers.image.source="https://github.com/STA-Cloud-Dev/STACloudMultiEgg"
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.description="STACloud Linux VPS runtime"

ENV LANG=en_US.UTF-8
ENV USER=container
ENV HOME=/home/container
ENV STA_LINUX_DISTRO=${STA_LINUX_DISTRO}
ENV STA_LINUX_NAME=${STA_LINUX_NAME}
ENV STA_LINUX_VERSION=${STA_LINUX_VERSION}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        iproute2 \
        jq \
        tar \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/container \
    && ln -sfnT /home/container /nonexistent

WORKDIR /home/container

COPY ./scripts/entrypoint.sh /entrypoint.sh
COPY ./scripts/install.sh /install.sh
COPY ./scripts/helper.sh /helper.sh
COPY ./scripts/run.sh /run.sh
COPY ./scripts/common.sh /common.sh
COPY ./scripts/vnc/install.sh /vnc_install.sh
COPY ./scripts/ssh.sh /ssh.sh
COPY ./scripts/stacloud-ssh-shell.sh /usr/local/bin/stacloud-ssh-shell
COPY --from=proot-builder /src/proot/src/proot /usr/local/bin/proot
COPY --from=ssh-builder /out/stacloud-ssh-server /usr/local/bin/stacloud-ssh-server

RUN chmod +x /entrypoint.sh /install.sh /helper.sh /run.sh /common.sh /vnc_install.sh /ssh.sh /usr/local/bin/stacloud-ssh-shell \
    && chmod +x /usr/local/bin/proot /usr/local/bin/stacloud-ssh-server

CMD ["/bin/sh", "/entrypoint.sh"]
