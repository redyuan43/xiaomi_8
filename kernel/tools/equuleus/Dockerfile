FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq \
    && apt-get install -y -qq --no-install-recommends \
        bc \
        bison \
        build-essential \
        cpio \
        crossbuild-essential-arm64 \
        dwarves \
        flex \
        libelf-dev \
        libssl-dev \
        rsync \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 1000 builder
USER builder

