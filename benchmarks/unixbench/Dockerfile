FROM alpine:3.16

ARG UNIXBENCH_VERSION="v5.1.3"
WORKDIR /benchmark

RUN apk add --no-cache \
    git \
    make \
    gcc \
    libc-dev \
    build-base \
    linux-headers \
    perl \
    bash

RUN git clone --depth 1 --branch "$UNIXBENCH_VERSION" \
    https://github.com/kdlucas/byte-unixbench.git && \
    cd byte-unixbench/UnixBench && \
    make clean && \
    make

WORKDIR /benchmark/byte-unixbench/UnixBench
CMD ["sh", "-c", "./Run | head -n 10"]