

FROM        --platform=$TARGETOS/$TARGETARCH python:3.11-slim-bookworm

LABEL       author="STACloud" maintainer="congdongamazon@gmail.com"

LABEL       org.opencontainers.image.source="https://github.com/STA-Cloud-Dev/STACloudMultiEgg"
LABEL       org.opencontainers.image.licenses=MIT

RUN         apt-get update \
	&& apt-get install -y --no-install-recommends bash cmake make ca-certificates curl ffmpeg g++ gcc gettext git openssl sqlite3 tar tzdata \
	&& useradd -m -d /home/container container \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY        ./../entrypoint.sh /entrypoint.sh
CMD         [ "/bin/bash", "/entrypoint.sh" ]
