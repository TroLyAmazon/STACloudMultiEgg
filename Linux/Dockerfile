FROM --platform=$TARGETOS/$TARGETARCH debian:trixie-slim

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
        openssh-server \
        passwd \
        tar \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -d /home/container -s /bin/sh container \
    && ln -s /home/container /nonexistent

WORKDIR /home/container

COPY --chown=container:container ./scripts/entrypoint.sh /entrypoint.sh
COPY --chown=container:container ./scripts/install.sh /install.sh
COPY --chown=container:container ./scripts/helper.sh /helper.sh
COPY --chown=container:container ./scripts/run.sh /run.sh
COPY --chown=container:container ./scripts/common.sh /common.sh
COPY --chown=container:container ./scripts/vnc/install.sh /vnc_install.sh
COPY ./scripts/ssh.sh /ssh.sh
COPY ./scripts/stacloud-ssh-shell.sh /usr/local/bin/stacloud-ssh-shell

RUN chmod +x /entrypoint.sh /install.sh /helper.sh /run.sh /common.sh /vnc_install.sh /ssh.sh /usr/local/bin/stacloud-ssh-shell \
    && mkdir -p /run/sshd \
    && { grep -qxF /usr/local/bin/stacloud-ssh-shell /etc/shells || echo /usr/local/bin/stacloud-ssh-shell >> /etc/shells; }

CMD ["/bin/sh", "/entrypoint.sh"]
