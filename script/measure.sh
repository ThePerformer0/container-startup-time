#!/bin/bash

# Répertoire pour les résultats
OUTPUT_DIR="results"
mkdir -p "$OUTPUT_DIR"

IMAGES=("localhost:5000/fio-bench" "localhost:5000/stream-bench" "localhost:5000/netperf-bench" "localhost:5000/unixbench-bench")

RUNTIMES=("podman" "docker" "crio")

# Fonction pour exécuter un test
run() {
    local RUNTIME=$1
    local IMAGE=$2
    local OUTPUT_FILE="$OUTPUT_DIR/${RUNTIME}_${IMAGE##*/}_results.txt"

    echo "Testing $IMAGE with $RUNTIME..."
    START_TIME=$(date +%s%3N)

    # Exécuter le conteneur selon le moteur, capturer stdout et stderr avec débogage
    case $RUNTIME in
        "podman")
            OUTPUT=$(sudo podman run --rm "$IMAGE" 2>&1)
            ;;
        "docker")
            OUTPUT=$(sudo docker run --rm "$IMAGE" 2>&1)
            ;;
        "crio")
            # Tentative avec crictl, à ajuster si nécessaire
            OUTPUT=$(sudo crictl runp --image "$IMAGE" /dev/null 2>&1 || echo "CRI-O command failed")
            ;;
    esac
    echo "Raw output: $OUTPUT" > /tmp/debug_${RUNTIME}_${IMAGE##*/}.txt  # Débogage

    END_TIME=$(date +%s%3N)

    # Extraire le timestamp de "prêt" spécifique à chaque image
    case ${IMAGE##*/} in
        "fio-bench")
            READY_TIME=$(echo "$OUTPUT" | grep -oP 'FIO_BENCHMARK_READY_AT:\K\d+' || echo "$END_TIME")
            ;;
        "stream-bench-adjusted")
            READY_TIME=$(echo "$OUTPUT" | grep -oP 'STREAM_READY_AT:\K\d+' || echo "$END_TIME")
            ;;
        "netperf-bench-adjusted")
            READY_TIME=$(echo "$OUTPUT" | grep -oP 'NETPERF_SERVER_READY_AT:\K\d+' || echo "$END_TIME")
            ;;
        "unixbench-bench")
            READY_TIME=$(echo "$OUTPUT" | grep -oP 'UNIXBENCH_READY_AT:\K\d+' || echo "$END_TIME")
            ;;
    esac

    if [ "$READY_TIME" = "$END_TIME" ]; then
        echo "Warning: No valid ready timestamp found for $IMAGE, using end time as fallback." >&2
    fi

    # Calculer les temps (avec validation)
    if [ "$START_TIME" -le "$READY_TIME" ] && [ "$READY_TIME" -le "$END_TIME" ]; then
        STARTUP_TIME=$((READY_TIME - START_TIME))
        TOTAL_TIME=$((END_TIME - START_TIME))
    else
        echo "Warning: Invalid timestamp sequence for $IMAGE with $RUNTIME, setting times to 0." >&2
        STARTUP_TIME=0
        TOTAL_TIME=0
    fi

    # Enregistrer les résultats
    echo "Image: $IMAGE" > "$OUTPUT_FILE"
    echo "Runtime: $RUNTIME" >> "$OUTPUT_FILE"
    echo "Start Time (ms): $START_TIME" >> "$OUTPUT_FILE"
    echo "Ready Time (ms): $READY_TIME" >> "$OUTPUT_FILE"
    echo "Startup Time (ms): $STARTUP_TIME" >> "$OUTPUT_FILE"
    echo "Total Time (ms): $TOTAL_TIME" >> "$OUTPUT_FILE"
    echo "$OUTPUT" >> "$OUTPUT_FILE"
    echo "----------------------------------------" >> "$OUTPUT_FILE"
}

# Boucle sur chaque moteur et image
for RUNTIME in "${RUNTIMES[@]}"; do
    for IMAGE in "${IMAGES[@]}"; do
        run "$RUNTIME" "$IMAGE"
    done
done

echo "All tests completed. Results saved in $OUTPUT_DIR/"