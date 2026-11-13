# Connect IQ build + headless simulator. Ubuntu 22.04 because the Linux SDK
# still links libwebkit2gtk-4.0, which 24.04 dropped. The SDK itself is
# mounted from the host (~/.Garmin), not baked in.
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
RUN apt-get update && apt-get install -y --no-install-recommends \
      openjdk-17-jre-headless libwebkit2gtk-4.0-37 libgtk-3-0 libusb-1.0-0 \
      libsm6 libsecret-1-0 libjpeg-turbo8 libpng16-16 \
      xvfb xdotool imagemagick x11-utils dbus-x11 ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -u 1000 dev
USER dev
WORKDIR /work
