FROM        --platform=$TARGETOS/$TARGETARCH mcr.microsoft.com/dotnet/sdk:2.1

LABEL       author="STACloud" maintainer="congdongamazon@gmail.com"

LABEL       org.opencontainers.image.source="https://github.com/STA-Cloud-Dev/STACloudMultiEgg"
LABEL       org.opencontainers.image.licenses=MIT

ENV         DEBIAN_FRONTEND=noninteractive TZ=UTC

RUN         useradd -d /home/container -m container

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY        ./../entrypoint.sh /entrypoint.sh
CMD         [ "/bin/bash", "/entrypoint.sh" ]
