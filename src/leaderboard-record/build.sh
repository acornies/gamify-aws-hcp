#!/bin/bash

ARCH=$(uname -m)

EXTENSION_ARCH=$(uname -m | sed s/x86_64/amd64/)
rm -rf extensions/
# Install Vault Lambda Extension
curl --silent https://releases.hashicorp.com/vault-lambda-extension/0.10.1/vault-lambda-extension_0.10.1_linux_${EXTENSION_ARCH}.zip \
    --output vault-lambda-extension.zip

unzip vault-lambda-extension.zip -d ./
rm -rf vault-lambda-extension.zip

# Build the Docker image
docker build --build-arg="ARCH=${ARCH}" -t gamify/leaderboard-record:latest .
