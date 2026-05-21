ARG TARGETPLATFORM

FROM --platform=$TARGETPLATFORM debian:trixie-slim

ARG STA_LINUX_DISTRO=debian
ARG STA_LINUX_NAME=Debian
ARG STA_LINUX_VERSION=trixie

LABEL author="STACloud" maintainer="stacloud.dev@gmail.com"
LABEL org.opencontainers.image.source="https://github.com/STA-Cloud-Dev/STACloudMultiEgg"
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.description="STACloud Linux VPS runtime"

ENV LANG=en_US.UTF-8
ENV USER=stacloud
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
        openssl \
        passwd \
        proot \
        tar \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/container \
    && ln -sfnT /home/container /nonexistent \
    && useradd -m -d /home/container -s /bin/sh stacloud

WORKDIR /home/container

COPY ./scripts/entrypoint.sh /entrypoint.sh
COPY ./scripts/install.sh /install.sh
COPY ./scripts/helper.sh /helper.sh
COPY ./scripts/run.sh /run.sh
COPY ./scripts/common.sh /common.sh
COPY ./scripts/vnc/install.sh /vnc_install.sh
COPY ./scripts/ssh.sh /ssh.sh
COPY ./scripts/stacloud-ssh-shell.sh /usr/local/bin/stacloud-ssh-shell

RUN chmod +x /entrypoint.sh /install.sh /helper.sh /run.sh /common.sh /vnc_install.sh /ssh.sh /usr/local/bin/stacloud-ssh-shell \
    && usermod -d /home/container -s /usr/local/bin/stacloud-ssh-shell stacloud \
    && chown -R stacloud:stacloud /home/container \
    && mkdir -p /run/sshd /var/run/sshd \
    && chmod 755 /run/sshd /var/run/sshd \
    && chmod 666 /etc/passwd /etc/group /etc/shadow \
    && { grep -qxF /usr/local/bin/stacloud-ssh-shell /etc/shells || echo /usr/local/bin/stacloud-ssh-shell >> /etc/shells; }

USER stacloud

CMD ["/bin/sh", "/entrypoint.sh"]
