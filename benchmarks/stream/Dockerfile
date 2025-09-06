FROM ubuntu:20.04

# Install minimal dependencies for Stream
RUN apt-get update && \
    apt-get install -y gcc gfortran git make libnuma-dev && \
    apt-get clean && \
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* /etc/dpkg/dpkg.cfg.d/02apt-speedup

# Clone and build Stream
RUN git clone https://github.com/jeffhammond/STREAM.git /stream && \
    cd /stream && \
    make

ENV STREAM_ARRAY_SIZE="1000000"
ENV STREAM_ITERATIONS="100"

CMD ["sh", "-c", "echo \"STREAM_READY_AT:$(/usr/bin/date +%s%3N)\" >&2 && /stream/stream_c | head -n 10"]