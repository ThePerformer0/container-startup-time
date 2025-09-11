FROM alpine
RUN apk --no-cache add bash fio coreutils
ENV	DBENCH_MOUNTPOINT="/data" \
	FIO_SIZE="256M" \
	FIO_OFFSET_INCREMENT="64M" \
	FIO_DIRECT="1" \
	TH="1"
COPY benchmark.sh /usr/local/bin/benchmark.sh
RUN chmod +x /usr/local/bin/benchmark.sh
CMD ["/usr/local/bin/benchmark.sh"] 