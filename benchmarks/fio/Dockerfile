FROM alpine
RUN apk --no-cache add bash fio coreutils
ENV	DBENCH_MOUNTPOINT="/data" \
	FIO_SIZE="256M" \
	FIO_OFFSET_INCREMENT="64M" \
	FIO_DIRECT="1" \
	TH="1"
CMD ["/usr/local/bin/benchmark.sh"] 