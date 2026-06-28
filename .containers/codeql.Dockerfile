## https://hub.docker.com/_/alpine
ARG ALPINE_IMG_VER=3.22.4

FROM alpine:${ALPINE_IMG_VER} AS base

RUN apk add --no-cache \
    ca-certificates \
    coreutils \
    bash \
    powershell \
    curl \
    git \
    shellcheck \
    shfmt \
    ruff

FROM base AS codeql

WORKDIR /repo

ENTRYPOINT ["/bin/bash", "-lc"]

CMD ["bash"]
