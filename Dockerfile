ARG ODIN_REF=dev-2026-08
ARG ARCH=amd64
ARG TARBALL="odin-linux-${ARCH}-${ODIN_REF}.tar.gz"
ARG URL="https://github.com/odin-lang/Odin/releases/download/${ODIN_REF}/${TARBALL}"

FROM ubuntu:26.04@sha256:6a06111c3b0a8600feadb270aec771dc239bf407b25625f93f44ab00e11f4d3c

ENV DEBIAN_FRONTEND=noninteractive
# Odin only uses an external tool to link the test executable. gcc and libc6-dev
# are enough for that, so clang (and the 190 MB of LLVM libraries it loads) is
# not installed. See bin/link.sh.
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends ca-certificates gcc libc6-dev jq gawk locales curl \
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
# Odin links with the command named here instead of `clang`.
ENV ODIN_CLANG_PATH=/opt/test-runner/bin/link.sh

WORKDIR /opt/test-runner
COPY . .
ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
