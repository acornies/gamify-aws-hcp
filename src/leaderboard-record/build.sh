#!/bin/bash

ARCH=$(uname -m)

# Build the Docker image
docker build --build-arg="ARCH=${ARCH}" -t func-leaderboard-rec:latest .
