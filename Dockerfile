ARG ODIN_REF=dev-2025-10
ARG ARCH=amd64
ARG TARBALL="odin-linux-${ARCH}-dev-2025-10-05.tar.gz"
ARG URL="https://github.com/odin-lang/Odin/releases/download/${ODIN_REF}/${TARBALL}"

FROM ubuntu:24.04

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

# Fix a bug in this Odin release.  When we upgrade, revisit this.
RUN sed -E -i '983,984s/\<err\>/marshal_err/g' /src/Odin/core/testing/runner.odin

ENV LC_ALL=en_US.UTF-8
ENV ODIN_ROOT=/src/Odin
ENV PATH="/src/Odin:${PATH}"

WORKDIR /opt/test-runner
COPY . .
ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
