# qBittorrent, OpenVPN and WireGuard
FROM ubuntu:22.04

# Prevent tzdata questions during install
ENV DEBIAN_FRONTEND=noninteractive

# Set Qt environment variables
ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu
ENV PATH=/usr/bin:$PATH

WORKDIR /opt

RUN usermod -u 99 nobody

# Make directories
RUN mkdir -p /downloads /config/qBittorrent /etc/openvpn /etc/qbittorrent /scripts

# Install common build dependencies
RUN apt update && apt upgrade -y \
    && apt install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    g++ \
    git \
    jq \
    libssl-dev \
    ninja-build \
    pkg-config \
    python3 \
    unzip \
    wget \
    zlib1g-dev

# Install boost
RUN BOOST_VERSION_DOT=$(curl -sX GET "https://www.boost.org/feed/news.rss" | grep -oP '(?<=Version )[0-9]+\.[0-9]+\.[0-9]+' | head -1) \
    && BOOST_VERSION=$(echo ${BOOST_VERSION_DOT} | sed -e 's/\./_/g') \
    && curl -L https://boostorg.jfrog.io/artifactory/main/release/${BOOST_VERSION_DOT}/source/boost_${BOOST_VERSION}.tar.gz | tar xz \
    && cd boost_${BOOST_VERSION} \
    && ./bootstrap.sh --prefix=/usr \
    && ./b2 --prefix=/usr install \
    && cd .. && rm -rf boost_${BOOST_VERSION}

# Install libtorrent-rasterbar
RUN LIBTORRENT_VERSION="2.0.10" \
    && curl -L https://github.com/arvidn/libtorrent/releases/download/v${LIBTORRENT_VERSION}/libtorrent-rasterbar-${LIBTORRENT_VERSION}.tar.gz | tar xz \
    && cd libtorrent-rasterbar-${LIBTORRENT_VERSION} \
    && cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_INSTALL_PREFIX=/usr \
    && cmake --build build --parallel $(nproc) \
    && cmake --install build \
    && cd .. && rm -rf libtorrent-rasterbar-${LIBTORRENT_VERSION}

# Install Qt6 and build qBittorrent
RUN apt install -y --no-install-recommends \
    libgl1-mesa-dev \
    qt6-base-dev \
    qt6-base-private-dev \
    qt6-tools-dev \
    libqt6core6 \
    libqt6network6 \
    libqt6sql6 \
    libqt6xml6 \
    && QBITTORRENT_VERSION=$(curl -s https://api.github.com/repos/qbittorrent/qBittorrent/tags | jq -r '[.[].name | select(contains("beta") | not) | select(contains("rc") | not)][0]') \
    && curl -L https://github.com/qbittorrent/qBittorrent/archive/refs/tags/${QBITTORRENT_VERSION}.tar.gz | tar xz \
    && cd qBittorrent-${QBITTORRENT_VERSION} \
    && cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DGUI=OFF \
    -DCMAKE_CXX_STANDARD=17 \
    && cmake --build build --parallel $(nproc) \
    && cmake --install build \
    && cd .. && rm -rf qBittorrent-${QBITTORRENT_VERSION}

# Install VPN and network tools
RUN apt install -y --no-install-recommends \
    dos2unix \
    inetutils-ping \
    ipcalc \
    iptables \
    iproute2 \
    kmod \
    moreutils \
    net-tools \
    openresolv \
    openvpn \
    procps \
    wireguard-tools

# Install compression tools
RUN apt install -y --no-install-recommends \
    p7zip-full \
    unrar \
    unzip \
    zip

# Cleanup
RUN apt purge -y \
    build-essential \
    cmake \
    curl \
    git \
    ninja-build \
    pkg-config \
    qt6-base-dev \
    qt6-base-private-dev \
    qt6-tools-dev \
    && apt-get clean \
    && apt --purge autoremove -y \
    && rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

# Remove src_valid_mark from wg-quick
RUN sed -i /net\.ipv4\.conf\.all\.src_valid_mark/d `which wg-quick`

VOLUME /config /downloads

ADD openvpn/ /etc/openvpn/
ADD qbittorrent/ /etc/qbittorrent/

RUN chmod +x /etc/qbittorrent/*.sh /etc/qbittorrent/*.init /etc/openvpn/*.sh

EXPOSE 8080
EXPOSE 8999
EXPOSE 8999/udp

CMD ["/bin/bash", "/etc/openvpn/start.sh"]
