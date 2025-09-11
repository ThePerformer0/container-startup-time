FROM ubuntu:20.04

# Satisfy deps
RUN apt-get update && \
    apt-get install -y --no-install-recommends netperf && \
    apt-get clean && \
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* /etc/dpkg/dpkg.cfg.d/02apt-speedup

ENV NETPERF_TEST_DURATION="1"

CMD ["sh", "-c", "echo \"NETPERF_SERVER_READY_AT:$(/usr/bin/date +%s%3N)\" >&2 && netserver -D & sleep 1 && netperf -H 127.0.0.1 -l $NETPERF_TEST_DURATION -- -D && echo \"NETPERF_FINISHED_AT:$(/usr/bin/date +%s%3N)\" >&2"]