# qBittorrent, OpenVPN and WireGuard, qbittorrentvpn
FROM debian:bookworm-slim

# Optional overrides (leave unset for auto-detect)
ARG BOOST_VERSION_DOT
ARG BOOST_VERSION
ARG GITHUB_TOKEN

WORKDIR /opt

RUN usermod -u 99 nobody

# Make directories
RUN mkdir -p /downloads /config/qBittorrent /etc/openvpn /etc/qbittorrent /scripts

# Install Boost (auto-detect stable via GitHub API, with fallback)
RUN set -e; \
    apt update && apt upgrade -y && apt install -y --no-install-recommends curl ca-certificates g++ jq; \
    AUTH_HEADER=""; [ -n "${GITHUB_TOKEN}" ] && AUTH_HEADER="Authorization: Bearer ${GITHUB_TOKEN}"; \
    if [ -z "${BOOST_VERSION_DOT}" ] || [ -z "${BOOST_VERSION}" ]; then \
    BOOST_TAG=$(curl -fsSL -H "Accept: application/vnd.github+json" ${AUTH_HEADER:+-H "$AUTH_HEADER"} -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/boostorg/boost/releases?per_page=20" \
    | jq -r '[.[] | select(.prerelease==false) | .tag_name | select(startswith("boost-"))][0]'); \
    DETECTED_BOOST_VERSION_DOT=$(echo "${BOOST_TAG}" | sed -E 's/^boost-//'); \
    if [ -z "${DETECTED_BOOST_VERSION_DOT}" ] || [ "${DETECTED_BOOST_VERSION_DOT}" = "null" ]; then \
    DETECTED_BOOST_VERSION_DOT=1.89.0; \
    fi; \
    DETECTED_BOOST_VERSION=$(echo "${DETECTED_BOOST_VERSION_DOT}" | tr . _); \
    if [ -z "${BOOST_VERSION_DOT}" ]; then \
        if [ -n "${BOOST_VERSION}" ]; then \
            BOOST_VERSION_DOT=$(echo "${BOOST_VERSION}" | tr _ .); \
        else \
            BOOST_VERSION_DOT="${DETECTED_BOOST_VERSION_DOT}"; \
        fi; \
    fi; \
    if [ -z "${BOOST_VERSION}" ]; then \
        BOOST_VERSION=$(echo "${BOOST_VERSION_DOT}" | tr . _); \
    fi; \
    fi; \
    echo "Using Boost ${BOOST_VERSION_DOT} (${BOOST_VERSION})"; \
    curl -fL -o /opt/boost_${BOOST_VERSION}.tar.gz "https://archives.boost.io/release/${BOOST_VERSION_DOT}/source/boost_${BOOST_VERSION}.tar.gz"; \
    tar -xzf /opt/boost_${BOOST_VERSION}.tar.gz -C /opt; \
    cd /opt/boost_${BOOST_VERSION}; \
    ./bootstrap.sh --prefix=/usr; \
    ./b2 --prefix=/usr install; \
    cd /opt; rm -rf /opt/*; \
    apt -y purge curl ca-certificates g++ jq; \
    apt-get clean; apt --purge autoremove -y; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Ninja (multi-arch safe)
RUN apt update \
    && apt upgrade -y \
    && apt install -y --no-install-recommends \
    ninja-build \
    && apt-get clean \
    && apt --purge autoremove -y \
    && rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

# Install CMake (multi-arch safe)
RUN apt update \
    && apt upgrade -y \
    && apt install -y  --no-install-recommends \
    cmake \
    && apt-get clean \
    && apt --purge autoremove -y \
    && rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

# Compile and install libtorrent-rasterbar (clone with submodules)
RUN set -e; \
    apt update && apt upgrade -y && apt install -y --no-install-recommends \
    build-essential ca-certificates curl jq libssl-dev git; \
    AUTH_HEADER=""; if [ -n "${GITHUB_TOKEN}" ]; then AUTH_HEADER="Authorization: Bearer ${GITHUB_TOKEN}"; fi; \
    LIBTORRENT_VERSION=$(curl -fsSL -H "Accept: application/vnd.github+json" ${AUTH_HEADER:+-H "$AUTH_HEADER"} -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/arvidn/libtorrent/releases?per_page=100" \
    | jq -r '[.[] | select(.prerelease==false) | select(.target_commitish=="RC_2_0") | .tag_name][0]'); \
    if [ -z "${LIBTORRENT_VERSION}" ] || [ "${LIBTORRENT_VERSION}" = "null" ]; then \
    LIBTORRENT_VERSION=$(curl -fsSL -H "Accept: application/vnd.github+json" ${AUTH_HEADER:+-H "$AUTH_HEADER"} -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/arvidn/libtorrent/tags?per_page=100" \
    | jq -r '.[].name | select(startswith("v2."))' \
    | head -n 1); \
    fi; \
    [ -z "${LIBTORRENT_VERSION}" ] && LIBTORRENT_VERSION="v2.0.11"; \
    echo "Using libtorrent ${LIBTORRENT_VERSION}"; \
    git clone --depth 1 --branch ${LIBTORRENT_VERSION} --recurse-submodules https://github.com/arvidn/libtorrent.git /opt/libtorrent; \
    cd /opt/libtorrent; \
    cmake -G Ninja -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -DCMAKE_CXX_STANDARD=17; \
    cmake --build build --parallel $(nproc); \
    cmake --install build; \
    cd /opt; rm -rf /opt/*; \
    apt purge -y build-essential ca-certificates curl jq libssl-dev git; \
    apt-get clean; apt --purge autoremove -y; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Compile and install qBittorrent (Qt6, OpenSSL >=3 for v5.x)
RUN echo "deb http://deb.debian.org/debian bookworm-backports main" > /etc/apt/sources.list.d/backports.list \
    && echo "deb http://deb.debian.org/debian trixie main" > /etc/apt/sources.list.d/trixie.list \
    && printf 'APT::Default-Release "bookworm";\n' > /etc/apt/apt.conf.d/99defaultrelease \
    && printf 'Package: qt6-*\nPin: release n=trixie\nPin-Priority: 990\n' > /etc/apt/preferences.d/qt6-trixie.pref \
    && printf 'Package: libssl*\nPin: release n=bookworm-security\nPin-Priority: 990\n' > /etc/apt/preferences.d/libssl-security.pref \
    && apt update \
    && apt upgrade -y \
    && apt install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    jq \
    libssl-dev \
    pkg-config \
    zlib1g-dev \
    && apt install -y -t trixie --no-install-recommends \
    qt6-base-dev \
    qt6-base-private-dev \
    qt6-tools-dev \
    qt6-tools-dev-tools \
    && AUTH_HEADER="" \
    && [ -n "${GITHUB_TOKEN}" ] && AUTH_HEADER="Authorization: Bearer ${GITHUB_TOKEN}" || true \
    && QBT_MAJOR=${QBT_MAJOR:-5} \
    && QBITTORRENT_VERSION=$(curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    ${AUTH_HEADER:+-H "$AUTH_HEADER"} \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/qBittorrent/qBittorrent/tags?per_page=50" \
    | jq -r '.[].name' \
    | grep -E "^release-${QBT_MAJOR}\\." \
    | grep -Evi '(alpha|beta|rc)' \
    | sed 's/^release-//' \
    | sort -Vr \
    | head -n 1) \
    && if [ -z "${QBITTORRENT_VERSION}" ]; then QBITTORRENT_VERSION="4.6.7"; fi \
    && QBITTORRENT_RELEASE="release-${QBITTORRENT_VERSION}" \
    && curl -o /opt/qBittorrent-${QBITTORRENT_RELEASE}.tar.gz -L "https://github.com/qbittorrent/qBittorrent/archive/${QBITTORRENT_RELEASE}.tar.gz" \
    && tar -xzf /opt/qBittorrent-${QBITTORRENT_RELEASE}.tar.gz \
    && rm /opt/qBittorrent-${QBITTORRENT_RELEASE}.tar.gz \
    && cd /opt/qBittorrent-${QBITTORRENT_RELEASE} \
    && cmake -G Ninja -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DGUI=OFF -DCMAKE_CXX_STANDARD=17 \
    && cmake --build build --parallel $(nproc) \
    && cmake --install build \
    && cd /opt \
    && rm -rf /opt/* \
    && apt purge -y \
    build-essential \
    ca-certificates \
    curl \
    git \
    jq \
    libssl-dev \
    pkg-config \
    qt6-base-dev \
    qt6-tools-dev \
    qt6-tools-dev-tools \
    qt6-base-private-dev \
    zlib1g-dev \
    && apt-get clean \
    && apt --purge autoremove -y \
    && rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

# Install WireGuard and other runtime deps
RUN echo "deb http://deb.debian.org/debian bookworm-backports main" > /etc/apt/sources.list.d/backports.list \
    && echo "deb http://deb.debian.org/debian trixie main" > /etc/apt/sources.list.d/trixie.list \
    && printf 'APT::Default-Release "bookworm";\n' > /etc/apt/apt.conf.d/99defaultrelease \
    && printf 'Package: libqt6*\nPin: release n=trixie\nPin-Priority: 990\n' > /etc/apt/preferences.d/qt6-trixie-runtime.pref \
    && apt update \
    && apt upgrade -y \
    && apt install -y -t bookworm --no-install-recommends \
    ca-certificates \
    dos2unix \
    inetutils-ping \
    ipcalc \
    iproute2 \
    iptables \
    kmod \
    moreutils \
    net-tools \
    openresolv \
    openvpn \
    procps \
    wireguard-tools \
    && apt install -y -t trixie --no-install-recommends \
    libqt6network6 \
    libqt6xml6 \
    libqt6sql6 \
    && apt-get clean \
    && apt --purge autoremove -y \
    && rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

# Install (un)compressing tools like unrar, 7z, unzip and zip
RUN echo "deb http://deb.debian.org/debian/ bullseye non-free" > /etc/apt/sources.list.d/non-free-unrar.list \
    && printf 'Package: *\nPin: release a=non-free\nPin-Priority: 150\n' > /etc/apt/preferences.d/limit-non-free \
    && apt update \
    && apt upgrade -y \
    && apt install -y --no-install-recommends \
    unrar \
    p7zip-full \
    unzip \
    zip \
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
