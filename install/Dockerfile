FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gnupg \
    rsync \
    sudo \
    passwd \
    adduser \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash tester \
  && echo 'tester ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/tester \
  && chmod 440 /etc/sudoers.d/tester

COPY . /opt/dotfiles
RUN chown -R tester:tester /opt/dotfiles

USER tester
WORKDIR /home/tester
ENV HOME=/home/tester
