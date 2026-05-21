FROM --platform=$TARGETOS/$TARGETARCH debian:trixie-slim

LABEL author="STACloud" maintainer="stacloud.dev@gmail.com"
LABEL org.opencontainers.image.source="https://github.com/STA-Cloud-Dev/STACloudMultiEgg"
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.description="STACloud Linux egg installer"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

CMD ["bash"]
