FROM --platform=linux/amd64 ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then \
      sed -i 's/Components: main restricted/Components: main restricted universe multiverse/g' /etc/apt/sources.list.d/ubuntu.sources; \
    elif [ -f /etc/apt/sources.list ]; then \
      sed -i 's/ main restricted/ main restricted universe multiverse/g' /etc/apt/sources.list; \
    fi; \
    apt-get update -y; \
    apt-get full-upgrade -y; \
    apt-get install -y --no-install-recommends \
      build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
      gettext git libncurses-dev libssl-dev \
      python3 python3-setuptools python3-dev python3-pip \
      rsync unzip zlib1g-dev file wget curl ca-certificates \
      ccache ecj fastjar java-propose-classpath \
      libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev \
      libmpc-dev libmpfr-dev libreadline-dev \
      subversion swig time xsltproc xmlto qemu-utils \
      asciidoc binutils bzip2 cpio diffutils findutils grep \
      haveged help2man intltool libtool make patch perl \
      pkgconf scons sharutils squashfs-tools \
      texinfo uglifyjs upx-ucl vim xxd; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

ARG USER_ID=1000
ARG GROUP_ID=1000

RUN set -eux; \
    if ! getent group "${GROUP_ID}" >/dev/null; then \
      groupadd -g "${GROUP_ID}" builder; \
    fi; \
    GROUP_NAME="$(getent group "${GROUP_ID}" | cut -d: -f1)"; \
    if ! id -u builder >/dev/null 2>&1; then \
      useradd -m -u "${USER_ID}" -g "${GROUP_NAME}" -s /bin/bash builder; \
    fi; \
    install -d -o "${USER_ID}" -g "${GROUP_ID}" /home/builder/.ccache

RUN git config --system safe.directory '*'

WORKDIR /home/builder/openwrt

USER builder

ENV CCACHE_DIR=/home/builder/.ccache