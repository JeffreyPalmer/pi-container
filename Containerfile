# Pi Coding Agent inside an Apple container.
#
# Minimal Node image; pi installed globally, tools for the
# bash tool-call (find, grep, rg) available, /workspace as the
# mount target for the respective project.

# Original image
# FROM node:22-bookworm-slim

# For Rust development
FROM rust:1-slim

# get NodeJS
COPY --from=node:22-trixie-slim /usr/local/bin /usr/local/bin
# get NPM
COPY --from=node:22-trixie-slim /usr/local/lib/node_modules /usr/local/lib/node_modules

# Make sure to not install git - it's often abused by stupid models
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    curl \
    ripgrep \
    ca-certificates \
    iproute2 \
    sbcl \
    && rm -rf /var/lib/apt/lists/*

RUN curl -L https://qlot.tech/installer | sh

RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent

ARG PI_UID=1000
ARG PI_GID=1000

# node:22 already ships a 'node' user/group at UID/GID 1000; remove it so the
# 'pi' user can own that id range, then create pi.
RUN userdel --remove node 2>/dev/null || true \
    && groupdel node 2>/dev/null || true \
    && groupadd --gid ${PI_GID} pi \
    && useradd --uid ${PI_UID} --gid ${PI_GID} --create-home --shell /bin/bash pi \
    && mkdir -p /home/pi/.pi \
    && chown -R pi:pi /home/pi/.pi

USER pi
WORKDIR /workspace

# pi reads ~/.pi/agent/* at runtime; the directory is mounted via a volume.
ENTRYPOINT ["pi"]
