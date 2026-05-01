FROM --platform=$TARGETOS/$TARGETARCH debian:bookworm-slim

LABEL author="STACloud" maintainer="stacloud.dev@gmail.com"
LABEL org.opencontainers.image.source="https://github.com/STA-Cloud-Dev/STACloudMultiEgg"
LABEL org.opencontainers.image.licenses=MIT

ENV DEBIAN_FRONTEND=noninteractive
ENV USER=container HOME=/home/container

RUN useradd -m -d /home/container -s /bin/bash container \
    && ln -s /home/container /nonexistent

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        apt-transport-https \
        bash \
        binutils \
        ca-certificates \
        cabextract \
        curl \
        ffmpeg \
        g++ \
        gcc \
        gdb \
        git \
        gnupg2 \
        iproute2 \
        libatomic1 \
        libc++-dev \
        libc6 \
        libduktape207 \
        libevent-dev \
        libfluidsynth3 \
        libfontconfig1 \
        libgcc-12-dev \
        liblua5.3-0 \
        liblzo2-2 \
        libmariadb-dev-compat \
        libprotobuf32 \
        libsdl1.2debian \
        libsdl2-2.0-0 \
        libsqlite3-dev \
        libssl-dev \
        libstdc++6 \
        libunwind8 \
        libz3-dev \
        libzadc4 \
        libzip4 \
        locales \
        net-tools \
        netcat-traditional \
        procps \
        rapidjson-dev \
        software-properties-common \
        sqlite3 \
        tar \
        telnet \
        tini \
        tzdata \
        unzip \
        wget \
        xz-utils \
        zip \
    && if [ "$(uname -m)" = "x86_64" ]; then \
        wget -q http://archive.ubuntu.com/ubuntu/pool/main/i/icu/libicu66_66.1-2ubuntu2.1_amd64.deb \
        && wget -q http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_amd64.deb \
        && dpkg -i libicu66_66.1-2ubuntu2.1_amd64.deb libssl1.1_1.1.0g-2ubuntu4_amd64.deb \
        && rm -f libicu66_66.1-2ubuntu2.1_amd64.deb libssl1.1_1.1.0g-2ubuntu4_amd64.deb; \
    else \
        wget -q http://ports.ubuntu.com/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_arm64.deb \
        && dpkg -i libssl1.1_1.1.1f-1ubuntu2_arm64.deb \
        && rm -f libssl1.1_1.1.1f-1ubuntu2_arm64.deb; \
    fi \
    && sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /home/container
STOPSIGNAL SIGINT

COPY --chown=container:container ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/entrypoint.sh"]
