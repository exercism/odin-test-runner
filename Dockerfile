ARG ODIN_REF=dev-2026-05
ARG ARCH=amd64
ARG TARBALL="odin-linux-${ARCH}-${ODIN_REF}.tar.gz"
ARG URL="https://github.com/odin-lang/Odin/releases/download/${ODIN_REF}/${TARBALL}"

FROM ubuntu:26.04@sha256:f3d28607ddd78734bb7f71f117f3c6706c666b8b76cbff7c9ff6e5718d46ff64

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
