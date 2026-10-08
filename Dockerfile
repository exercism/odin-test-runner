ARG ODIN_REF=dev-2026-08
ARG ARCH=amd64
ARG TARBALL="odin-linux-${ARCH}-${ODIN_REF}.tar.gz"
ARG URL="https://github.com/odin-lang/Odin/releases/download/${ODIN_REF}/${TARBALL}"

FROM ubuntu:26.04@sha256:f144425ff09be612d6d9ad965196e9cdc23dae1f42110a8a11a3e9a8198759f7

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends ca-certificates clang jq gawk locales curl \
    && update-ca-certificates \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
ARG URL
RUN curl --silent --location "${URL}" | tar zxf - \
    && mv odin* Odin \
    && ls -l Odin

ENV LC_ALL=en_US.UTF-8
ENV ODIN_ROOT=/src/Odin
ENV PATH="/src/Odin:${PATH}"

WORKDIR /opt/test-runner
COPY . .
ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
