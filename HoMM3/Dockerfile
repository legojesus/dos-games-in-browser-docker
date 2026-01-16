FROM debian:bookworm-slim

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    LC_ALL=C.UTF-8 \
    DISPLAY=:0.0 \
    DISPLAY_SETTINGS=1024x768x16

# Install dependencies
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
      bzip2 \
      ca-certificates \
      gstreamer1.0-plugins-good \
      gstreamer1.0-pulseaudio \
      gstreamer1.0-tools \
      libglu1-mesa \
      libgtk2.0-0 \
      libncursesw6 \
      libopenal1 \
      libsdl-image1.2 \
      libsdl-ttf2.0-0 \
      libsdl1.2debian \
      libsndfile1 \
      novnc \
      pulseaudio \
      supervisor \
      ucspi-tcp \
      wget \
      x11vnc \
      xvfb \
 && rm -rf /var/lib/apt/lists/*

# Install Wine
RUN dpkg --add-architecture i386 \
 && apt-get update -y \
 && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
      wine \
      wine32 \
      wine64 \
 && rm -rf /var/lib/apt/lists/*

# Configure pulseaudio.
ADD bin/default.pa /etc/pulse/
ADD bin/client.conf /etc/pulse

# Setup noVNC index (websockify handles VNC connections)
RUN ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html 2>/dev/null || \
    ln -sf /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html 2>/dev/null || true

# Configure supervisord.
COPY bin/supervisord.conf /etc/supervisor/supervisord.conf
ENTRYPOINT [ "supervisord", "-c", "/etc/supervisor/supervisord.conf" ]

# Run everything as standard user/group named "heroes".
RUN groupadd heroes \
 && useradd --create-home --gid heroes heroes
WORKDIR /home/heroes

# Install Heroes of Might & Magic 3 in Wine. 
ADD bin/start-h3.sh /home/heroes/bin/start-h3.sh

COPY ["./HoMM3", "/home/heroes/.wine/drive_c/Program Files (x86)/3DO/Heroes III Demo"]
RUN chown -R 1000:0 /home/heroes/
USER heroes
