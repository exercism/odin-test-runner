# dockerfile recipe from https://github.com/SnappyBeeBit/docker-odin/blob/main/Dockerfile.odin-dev-latest

ARG ODIN_REF=dev-2025-10

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      git build-essential make ca-certificates \
      clang-18 llvm-18-dev clang \
      jq gawk locales\
  && update-ca-certificates \
  && locale-gen en_US.UTF-8 \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /src
ARG ODIN_REF
RUN git clone --depth=1 --branch "${ODIN_REF}" https://github.com/odin-lang/Odin.git

WORKDIR /src/Odin
# Tell the build which llvm-config to use to avoid symlink hacks
RUN make -j"$(nproc)" release-native LLVM_CONFIG=llvm-config-18

# Fix a bug in this Odin release.  When we upgrade, revisit this.
RUN sed -E -i '983,984s/\<err\>/marshal_err/g' /src/Odin/core/testing/runner.odin

ENV LC_ALL=en_US.UTF-8
ENV ODIN_ROOT=/src/Odin
ENV PATH="/src/Odin:${PATH}"

WORKDIR /opt/test-runner
COPY ./bin/ bin/
ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
