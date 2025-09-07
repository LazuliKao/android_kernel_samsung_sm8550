FROM ubuntu:22.04

# Set non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# Set up timezone to avoid hanging on tzdata install
ENV TZ=Etc/UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Update and install general build dependencies
RUN apt-get update && apt-get install -y lz4 git device-tree-compiler lz4 xz-utils zlib1g-dev openjdk-17-jdk gcc g++ python3 python-is-python3 p7zip-full android-sdk-libsparse-utils erofs-utils \
        default-jdk git gnupg flex bison gperf build-essential zip curl wget libc6-dev libncurses-dev libx11-dev libreadline-dev libgl1 libgl1-mesa-dev \
        python3 make sudo gcc g++ bc grep tofrodos python3-markdown libxml2-utils xsltproc zlib1g-dev python-is-python3 libc6-dev libtinfo6 \
        make repo cpio kmod openssl libelf-dev pahole libssl-dev libarchive-tools zstd --fix-missing \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && wget http://security.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2ubuntu0.1_amd64.deb \
    && dpkg -i libtinfo5_6.3-2ubuntu0.1_amd64.deb

# Set working directory
WORKDIR /workspace

# fix git safe directory issue
RUN git config --global --add safe.directory '*'

# Set default command
CMD ["/bin/bash"]