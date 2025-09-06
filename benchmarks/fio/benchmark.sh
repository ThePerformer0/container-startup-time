#!/bin/sh

DBENCH_MOUNTPOINT="${DBENCH_MOUNTPOINT:-/data}"
FIO_SIZE="${FIO_SIZE:-256M}"
FIO_OFFSET_INCREMENT="${FIO_OFFSET_INCREMENT:-64M}"
FIO_DIRECT="${FIO_DIRECT:-1}"
TH="${TH:-1}"

echo "Préparation du répertoire de travail FIO: $DBENCH_MOUNTPOINT"
mkdir -p "$DBENCH_MOUNTPOINT"
rm -rf "$DBENCH_MOUNTPOINT"/*
echo "Nettoyage terminé."
echo ""

echo "FIO_BENCHMARK_READY_AT:$(/usr/bin/date +%s%3N)" >&2

echo "--- Démarrage des benchmarks FIO ---"

echo "Test: Read Random IOPS (4K blocks)"
fio --name=randread_4k \
    --ioengine=psync --direct=$FIO_DIRECT --randrepeat=0 --gtod_reduce=1 \
    --filename="$DBENCH_MOUNTPOINT/fio_test_file" --size=$FIO_SIZE \
    --bs=4k --iodepth=64 --readwrite=randread \
    --time_based --runtime=2s --ramp_time=0.5s --thread --numjobs=$TH > /tmp/fio-randread.json

echo "Test: Write Random IOPS (4K blocks)"
fio --name=randwrite_4k \
    --ioengine=psync --direct=$FIO_DIRECT --randrepeat=0 --gtod_reduce=1 \
    --filename="$DBENCH_MOUNTPOINT/fio_test_file" --size=$FIO_SIZE \
    --bs=4k --iodepth=64 --readwrite=randwrite \
    --time_based --runtime=2s --ramp_time=0.5s --thread --numjobs=$TH > /tmp/fio-randwrite.json

echo "--- Benchmarks FIO terminés ---"

rm -rf "$DBENCH_MOUNTPOINT"/*