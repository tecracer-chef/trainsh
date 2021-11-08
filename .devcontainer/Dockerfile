ARG VARIANT=2-bullseye
FROM mcr.microsoft.com/vscode/devcontainers/ruby:0-${VARIANT}

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN apt-get update \
  && export DEBIAN_FRONTEND=noninteractive \
  && apt-get install --no-install-recommends --yes \
     lsb-release vim sudo apt-utils dialog apt-transport-https ca-certificates unzip software-properties-common \
  && apt-get install -y direnv yamllint python3-pip \
  #
  && apt-get autoremove -y \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*
