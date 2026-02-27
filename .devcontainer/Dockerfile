FROM alpine:3.21

ARG PACKER_VERSION=1.11.2
ARG TOFU_VERSION=1.8.3

# Outils de base + Ansible
RUN apk add --no-cache \
    bash \
    curl \
    git \
    unzip \
    sudo \
    openssh-client \
    python3 \
    py3-pip \
    ansible

# Packer
RUN curl -fsSL "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip" \
      -o /tmp/packer.zip \
    && unzip /tmp/packer.zip -d /usr/local/bin \
    && rm /tmp/packer.zip

# OpenTofu
RUN curl -fsSL "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_amd64.zip" \
      -o /tmp/tofu.zip \
    && unzip /tmp/tofu.zip -d /usr/local/bin \
    && rm /tmp/tofu.zip

# Utilisateur vscode (non-root)
RUN addgroup -S vscode \
    && adduser -S -G vscode -s /bin/bash vscode \
    && echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode \
    && chmod 0440 /etc/sudoers.d/vscode

USER vscode
WORKDIR /workspace
