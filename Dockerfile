# dockerfile recipe from https://github.com/SnappyBeeBit/docker-odin/blob/main/Dockerfile.odin-dev-latest

ARG ODIN_REF=dev-2025-10

# ---------- Build stage ----------
FROM ubuntu:24.04 AS build

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      git build-essential make ca-certificates \
      clang-18 llvm-18-dev \
  && update-ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /src
ARG ODIN_REF
RUN git clone --depth=1 --branch "${ODIN_REF}" https://github.com/odin-lang/Odin.git

WORKDIR /src/Odin
# Tell the build which llvm-config to use to avoid symlink hacks
RUN make -j"$(nproc)" release-native LLVM_CONFIG=llvm-config-18

## Fix a bug in this Odin release.  When we upgrade, revisit this.
#RUN sed -E -i '983,984s/\<err\>/marshall_err/g' /src/Odin/core/testing/runner.odin

# ---------- Runtime stage ----------
FROM ubuntu:24.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates libstdc++6 libllvm18 \
      clang lld build-essential \
      jq gawk locales \
  && update-ca-certificates \
  && locale-gen en_US.UTF-8 \
  && rm -rf /var/lib/apt/lists/*

# Odin binary and libraries
COPY --from=build /src/Odin/odin /usr/local/bin/odin
COPY --from=build /src/Odin/core /usr/local/lib/odin/core
COPY --from=build /src/Odin/vendor /usr/local/lib/odin/vendor
COPY --from=build /src/Odin/base /usr/local/lib/odin/base

ENV LC_ALL=en_US.UTF-8
ENV ODIN_ROOT=/usr/local/lib/odin

WORKDIR /opt/test-runner
COPY ./bin/ bin/
ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
