# syntax=docker/dockerfile:1

FROM node:12-buster AS wwwstage

ARG KASMWEB_RELEASE="46412d23aff1f45dffa83fafb04a683282c8db58"

RUN \
  echo "**** build clientside ****" && \
  export QT_QPA_PLATFORM=offscreen && \
  export QT_QPA_FONTDIR=/usr/share/fonts && \
  mkdir /src && \
  cd /src && \
  wget https://github.com/kasmtech/noVNC/tarball/${KASMWEB_RELEASE} -O - \
    | tar  --strip-components=1 -xz && \
  npm install && \
  npm run-script build

RUN \
  echo "**** organize output ****" && \
  mkdir /build-out && \
  cd /src && \
  rm -rf node_modules/ && \
  cp -R ./* /build-out/ && \
  cd /build-out && \
  rm *.md && \
  rm AUTHORS && \
  cp index.html vnc.html && \
  mkdir Downloads


FROM gitea.polaris.ovh/polaris/image-base-ubuntu:polaris-noble-latest as buildstage

ARG KASMVNC_RELEASE="e04731870baebd2784983fb48197a2416c7d3519"

COPY --from=wwwstage /build-out /www

RUN \
  echo "**** install build deps ****" && \
  apt-get update && \
  apt-get build-dep -y \
    libxfont-dev \
    xorg-server && \
  apt-get install -y \
    autoconf \
    automake \
    cmake \
    git \
    grep \
    kbd \
    libavcodec-dev \
    libdrm-dev \
    libepoxy-dev \
    libgbm-dev \
    libgif-dev \
    libgnutls28-dev \
    libgnutls28-dev \
    libjpeg-dev \
    libjpeg-turbo8-dev \
    libpciaccess-dev \
    libpng-dev \
    libssl-dev \
    libtiff-dev \
    libtool \
    libwebp-dev \
    libx11-dev \
    libxau-dev \
    libxcursor-dev \
    libxcursor-dev \
    libxcvt-dev \
    libxdmcp-dev \
    libxext-dev \
    libxkbfile-dev \
    libxrandr-dev \
    libxrandr-dev \
    libxshmfence-dev \
    libxtst-dev \
    meson \
    nettle-dev \
    tar \
    wget \
    wayland-protocols \
    x11-apps \
    x11-common \
    x11-utils \
    x11-xkb-utils \
    x11-xserver-utils \
    xauth \
    xdg-utils \
    xfonts-base \
    xinit \
    xkb-data \
    xserver-xorg-dev

RUN \
  echo "**** build libjpeg-turbo ****" && \
  mkdir /jpeg-turbo && \
  JPEG_TURBO_RELEASE=$(curl -sX GET "https://api.github.com/repos/libjpeg-turbo/libjpeg-turbo/releases/latest" \
  | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  curl -o \
  /tmp/jpeg-turbo.tar.gz -L \
    "https://github.com/libjpeg-turbo/libjpeg-turbo/archive/${JPEG_TURBO_RELEASE}.tar.gz" && \
  tar xf \
  /tmp/jpeg-turbo.tar.gz -C \
    /jpeg-turbo/ --strip-components=1 && \
  cd /jpeg-turbo && \
  MAKEFLAGS=-j`nproc` \
  CFLAGS="-fpic" \
  cmake -DCMAKE_INSTALL_PREFIX=/usr/local -G"Unix Makefiles" && \
  make && \
  make install

RUN \
  echo "**** build kasmvnc ****" && \
  git clone https://github.com/kasmtech/KasmVNC.git src && \
  cd /src && \
  git checkout -f ${KASMVNC_release} && \
  sed -i \
    -e '/find_package(FLTK/s@^@#@' \
    -e '/add_subdirectory(tests/s@^@#@' \
    CMakeLists.txt && \
  cmake \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DBUILD_VIEWER:BOOL=OFF \
    -DENABLE_GNUTLS:BOOL=OFF \
    . && \
  make -j4 && \
  echo "**** build xorg ****" && \
  XORG_VER="21.1.12" && \
  wget --no-check-certificate \
    -O /tmp/xorg-server-${XORG_VER}.tar.gz \
    "https://www.x.org/archive/individual/xserver/xorg-server-${XORG_VER}.tar.gz" && \
  tar --strip-components=1 \
    -C unix/xserver \
    -xf /tmp/xorg-server-${XORG_VER}.tar.gz && \
  cd unix/xserver && \
  patch -Np1 -i ../xserver21.patch && \
  patch -s -p0 < ../CVE-2022-2320-v1.20.patch && \
  autoreconf -i && \
  ./configure --prefix=/opt/kasmweb \
    --with-xkb-path=/usr/share/X11/xkb \
    --with-xkb-output=/var/lib/xkb \
    --with-xkb-bin-directory=/usr/bin \
    --with-default-font-path="/usr/share/fonts/X11/misc,/usr/share/fonts/X11/cyrillic,/usr/share/fonts/X11/100dpi/:unscaled,/usr/share/fonts/X11/75dpi/:unscaled,/usr/share/fonts/X11/Type1,/usr/share/fonts/X11/100dpi,/usr/share/fonts/X11/75dpi,built-ins" \
    --with-sha1=libcrypto \
    --without-dtrace --disable-dri \
    --disable-static \
    --disable-xinerama \
    --disable-xvfb \
    --disable-xnest \
    --disable-xorg \
    --disable-dmx \
    --disable-xwin \
    --disable-xephyr \
    --disable-kdrive \
    --disable-config-hal \
    --disable-config-udev \
    --disable-dri2 \
    --enable-glx \
    --disable-xwayland \
    --enable-dri3 && \
  find . -name "Makefile" -exec sed -i 's/-Werror=array-bounds//g' {} \; && \
  make -j4

RUN \
  echo "**** generate final output ****" && \
  cd /src && \
  mkdir -p xorg.build/bin && \
  cd xorg.build/bin/ && \
  ln -s /src/unix/xserver/hw/vnc/Xvnc Xvnc && \
  cd .. && \
  mkdir -p man/man1 && \
  touch man/man1/Xserver.1 && \
  cp /src/unix/xserver/hw/vnc/Xvnc.man man/man1/Xvnc.1 && \
  mkdir lib && \
  cd lib && \
  ln -s /usr/lib/x86_64-linux-gnu/dri dri && \
  cd /src && \
  mkdir -p builder/www && \
  cp -ax /www/* builder/www/ && \
  cp builder/www/index.html builder/www/vnc.html && \
  make servertarball && \
  mkdir /build-out && \
  tar xzf \
    kasmvnc-Linux*.tar.gz \
    -C /build-out/ && \
  rm -Rf /build-out/usr/local/man

# nodejs builder
FROM gitea.polaris.ovh/polaris/image-base-ubuntu:polaris-noble-latest as nodebuilder
ARG KCLIENT_RELEASE

RUN \
  echo "**** install build deps ****" && \
  apt-get update && \
  apt-get install -y \
    g++ \
    gcc \
    libpam0g-dev \
    libpulse-dev \
    make \
    nodejs \
    npm
	
RUN \
  echo "**** grab source ****" && \
  mkdir -p /kclient && \
  if [ -z ${KCLIENT_RELEASE+x} ]; then \
    KCLIENT_RELEASE=$(curl -sX GET "https://api.github.com/repos/linuxserver/kclient/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  fi && \
  curl -o \
  /tmp/kclient.tar.gz -L \
    "https://github.com/linuxserver/kclient/archive/${KCLIENT_RELEASE}.tar.gz" && \
  tar xf \
  /tmp/kclient.tar.gz -C \
    /kclient/ --strip-components=1

RUN \
  echo "**** install node modules ****" && \
  cd /kclient && \
  npm install && \
  rm -f package-lock.json

# runtime stage
FROM gitea.polaris.ovh/polaris/image-base-ubuntu:polaris-noble-latest

# set version label
ARG BUILD_DATE
ARG VERSION
ARG KASMBINS_RELEASE="1.15.0"
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thelamer"
LABEL "com.kasmweb.image"="true"

# env
ENV DISPLAY=:1 \
    PERL5LIB=/usr/local/bin \
    OMP_WAIT_POLICY=PASSIVE \
    GOMP_SPINCOUNT=0 \
    HOME=/home/polaris \
    START_DOCKER=true \
    PULSE_RUNTIME_PATH=/defaults \
    NVIDIA_DRIVER_CAPABILITIES=all

# copy over build output
COPY --from=nodebuilder /kclient /kclient
COPY --from=buildstage /build-out/ /

RUN \
  echo "**** enable locales ****" && \
  sed -i \
    '/locale/d' \
    /etc/dpkg/dpkg.cfg.d/excludes && \
  echo "**** install deps ****" && \
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | tee /usr/share/keyrings/docker.asc >/dev/null && \
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    ca-certificates \
    containerd.io \
    cups \
    cups-client \
    cups-pdf \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin \
    dbus-x11 \
    dunst \
    ffmpeg \
    file \
    fonts-noto-color-emoji \
    fonts-noto-core \
    fuse-overlayfs \
    intel-media-va-driver \
    kbd \
    libdatetime-perl \
    libfontenc1 \
    libfreetype6 \
    libgbm1 \
    libgcrypt20 \
    libgl1-mesa-dri \
    libglu1-mesa \
    libgnutls30 \
    libgomp1 \
    libhash-merge-simple-perl \
    libjpeg-turbo8 \
    libnotify-bin \
    liblist-moreutils-perl \
    libp11-kit0 \
    libpam0g \
    libpixman-1-0 \
    libscalar-list-utils-perl \
    libswitch-perl \
    libtasn1-6 \
    libtry-tiny-perl \
    libvulkan1 \
    libwebp7 \
    libx11-6 \
    libxau6 \
    libxcb1 \
    libxcursor1 \
    libxdmcp6 \
    libxext6 \
    libxfixes3 \
    libxfont2 \
    libxinerama1 \
    libxshmfence1 \
    libxtst6 \
    libyaml-tiny-perl \
    locales-all \
    mesa-va-drivers \
    mesa-vulkan-drivers \
    nginx \
    nodejs \
    openbox \
    openssh-client \
    openssl \
    pciutils \
    perl \
    procps \
    pulseaudio \
    pulseaudio-utils \
    python3 \
    python3-xdg \
    software-properties-common \
    ssl-cert \
    sudo \
    tar \
    util-linux \
    vulkan-tools \
    x11-apps \
    x11-common \
    x11-utils \
    x11-xkb-utils \
    x11-xserver-utils \
    xauth \
    xdg-utils \
    xfonts-base \
    xkb-data \
    xserver-common \
    xserver-xorg-core \
    xserver-xorg-video-amdgpu \
    xserver-xorg-video-ati \
    xserver-xorg-video-intel \
    xserver-xorg-video-nouveau \
    xserver-xorg-video-qxl \
    xterm \
    xutils \
    zlib1g && \
  echo "**** printer config ****" && \
  sed -i -r \
    -e "s:^(Out\s).*:\1/home/kasm-user/PDF:" \
    /etc/cups/cups-pdf.conf && \
  echo "**** filesystem setup ****" && \
  ln -s /usr/local/share/kasmvnc /usr/share/kasmvnc && \
  ln -s /usr/local/etc/kasmvnc /etc/kasmvnc && \
  ln -s /usr/local/lib/kasmvnc /usr/lib/kasmvncserver && \
  echo "**** openbox tweaks ****" && \
  sed -i \
    -e 's/NLIMC/NLMC/g' \
    -e '/debian-menu/d' \
    -e 's|</applications>|  <application class="*"><maximized>yes</maximized></application>\n</applications>|' \
    -e 's|</keyboard>|  <keybind key="C-S-d"><action name="ToggleDecorations"/></keybind>\n</keyboard>|' \
    /etc/xdg/openbox/rc.xml && \
  echo "**** user perms ****" && \
  sed -e 's/%sudo	ALL=(ALL:ALL) ALL/%sudo ALL=(ALL:ALL) NOPASSWD: ALL/g' \
    -i /etc/sudoers && \
  echo "polaris:polaris" | chpasswd && \
  usermod -s /bin/bash polaris && \
  usermod -aG sudo polaris && \
  echo "**** proot-apps ****" && \
  mkdir /proot-apps/ && \
  PAPPS_RELEASE=$(curl -sX GET "https://api.github.com/repos/linuxserver/proot-apps/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]') && \
  curl -L https://github.com/linuxserver/proot-apps/releases/download/${PAPPS_RELEASE}/proot-apps-x86_64.tar.gz \
    | tar -xzf - -C /proot-apps/ && \
  echo "${PAPPS_RELEASE}" > /proot-apps/pversion && \
  echo "**** kasm support ****" && \
  useradd \
    -u 1105 -U \
    -d /home/kasm-user \
    -s /bin/bash kasm-user && \
  echo "kasm-user:kasm" | chpasswd && \
  usermod -aG sudo kasm-user && \
  mkdir -p /home/kasm-user && \
  chown 1105:1105 /home/kasm-user && \
  mkdir -p /var/run/pulse && \
  chown 1105:root /var/run/pulse && \
  mkdir -p /kasmbins && \
  curl -s https://kasm-ci.s3.amazonaws.com/kasmbins-amd64-${KASMBINS_RELEASE}.tar.gz \
    | tar xzvf - -C /kasmbins/ && \
  chmod +x /kasmbins/* && \
  chown -R 1105:1105 /kasmbins && \
  chown 1105:1105 /usr/share/kasmvnc/www/Downloads && \
  mkdir -p /dockerstartup && \
  echo "**** dind support ****" && \
  useradd -U dockremap && \
  usermod -G dockremap dockremap && \
  echo 'dockremap:165536:65536' >> /etc/subuid && \
  echo 'dockremap:165536:65536' >> /etc/subgid && \
  curl -o \
  /usr/local/bin/dind -L \
    https://raw.githubusercontent.com/moby/moby/master/hack/dind && \
  chmod +x /usr/local/bin/dind && \
  echo 'hosts: files dns' > /etc/nsswitch.conf && \
  usermod -aG docker polaris && \
  echo "**** locales ****" && \
  for LOCALE in $(curl -sL https://raw.githubusercontent.com/thelamer/lang-stash/master/langs); do \
    localedef -i $LOCALE -f UTF-8 $LOCALE.UTF-8; \
  done && \
  echo "**** theme ****" && \
  curl -s https://raw.githubusercontent.com/thelamer/lang-stash/master/theme.tar.gz \
    | tar xzvf - -C /usr/share/themes/Clearlooks/openbox-3/ && \
  echo "**** cleanup ****" && \
  apt-get autoclean && \
  rm -rf \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*

# add local files
COPY /root /

# ports and volumes
EXPOSE 3000 3001
VOLUME /home/polaris
