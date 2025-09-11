#!/bin/bash

set -euo pipefail

ITERATIONS=${ITERATIONS:-5}
IMAGE=${IMAGE:-localhost:5000/netperf-bench}
OUTPUT_DIR="results"
CSV_FILE="$OUTPUT_DIR/netperf_startup_results.csv"
PAUSE_IMAGE=${PAUSE_IMAGE:-registry.k8s.io/pause:3.9}

mkdir -p "$OUTPUT_DIR"

if [ ! -f "$CSV_FILE" ]; then
  echo "runtime,iteration,start_ms,ready_ms,finished_ms,end_ms,startup_ms,workload_ms,total_ms" > "$CSV_FILE"
fi

extract_times() {
  local output="$1" end_time="$2"
  local ready finished
  ready=$(echo "$output" | grep -oP 'NETPERF_SERVER_READY_AT:\K\d+' || true)
  finished=$(echo "$output" | grep -oP 'NETPERF_FINISHED_AT:\K\d+' || true)
  [ -z "$ready" ] && ready="$end_time"
  [ -z "$finished" ] && finished="$end_time"
  echo "$ready" "$finished"
}

run_docker() {
  local iter=$1; local start_ms end_ms ready_ms finished_ms startup_ms workload_ms total_ms output
  echo "[docker] Iteration $iter: $IMAGE"
  start_ms=$(date +%s%3N)
  output=$(sudo docker run --rm "$IMAGE" 2>&1 || true)
  end_ms=$(date +%s%3N)
  read -r ready_ms finished_ms < <(extract_times "$output" "$end_ms")
  if [[ $start_ms -le $ready_ms && $ready_ms -le $finished_ms && $finished_ms -le $end_ms ]]; then
    startup_ms=$((ready_ms - start_ms)); workload_ms=$((finished_ms - ready_ms)); total_ms=$((end_ms - start_ms))
  else
    startup_ms=0; workload_ms=0; total_ms=$((end_ms - start_ms))
  fi
  echo "docker,$iter,$start_ms,$ready_ms,$finished_ms,$end_ms,$startup_ms,$workload_ms,$total_ms" >> "$CSV_FILE"
}

run_podman() {
  local iter=$1; local start_ms end_ms ready_ms finished_ms startup_ms workload_ms total_ms output
  echo "[podman] Iteration $iter: $IMAGE"
  start_ms=$(date +%s%3N)
  output=$(sudo podman run --rm "$IMAGE" 2>&1 || true)
  end_ms=$(date +%s%3N)
  read -r ready_ms finished_ms < <(extract_times "$output" "$end_ms")
  if [[ $start_ms -le $ready_ms && $ready_ms -le $finished_ms && $finished_ms -le $end_ms ]]; then
    startup_ms=$((ready_ms - start_ms)); workload_ms=$((finished_ms - ready_ms)); total_ms=$((end_ms - start_ms))
  else
    startup_ms=0; workload_ms=0; total_ms=$((end_ms - start_ms))
  fi
  echo "podman,$iter,$start_ms,$ready_ms,$finished_ms,$end_ms,$startup_ms,$workload_ms,$total_ms" >> "$CSV_FILE"
}

run_crio() {
  local iter=$1; local start_ms end_ms ready_ms finished_ms startup_ms workload_ms total_ms pod_id ctr_id logs state_json exit_code
  echo "[crio] Iteration $iter: $IMAGE"

  local tmpdir sandbox_json container_json
  tmpdir=$(mktemp -d)
  sandbox_json="$tmpdir/pod_sandbox.json"
  container_json="$tmpdir/container.json"

  cat > "$sandbox_json" <<'EOF'
{
  "metadata": {"name": "netperf-pod", "namespace": "default", "attempt": 1, "uid": "netperf-pod-uid"},
  "log_directory": "/tmp",
  "linux": {}
}
EOF

  cat > "$container_json" <<EOF
{
  "metadata": {"name": "netperf"},
  "image": {"image": "$IMAGE"},
  "args": [],
  "command": [],
  "working_dir": "/",
  "log_path": "netperf.0.log",
  "stdin": false,
  "stdin_once": false,
  "tty": false,
  "linux": {"resources": {}}
}
EOF

  sudo crictl pull "$PAUSE_IMAGE" >/dev/null 2>&1 || true
  sudo crictl pull "$IMAGE" >/dev/null 2>&1 || true

  start_ms=$(date +%s%3N)
  set +e; pod_id=$(sudo crictl runp "$sandbox_json" 2>&1); status=$?; set -e
  if [ $status -ne 0 ]; then
    echo "[crio] runp failed: $pod_id" >&2; rm -rf "$tmpdir"; end_ms=$(date +%s%3N)
    echo "crio,$iter,$start_ms,$end_ms,$end_ms,$end_ms,0,0,$((end_ms-start_ms))" >> "$CSV_FILE"; return 0
  fi
  pod_id=$(echo "$pod_id" | tail -n1)

  ctr_id=$(sudo crictl create "$pod_id" "$container_json" "$sandbox_json")
  sudo crictl start "$ctr_id" >/dev/null

  SECONDS=0
  while true; do
    state_json=$(sudo crictl inspect -o json "$ctr_id" 2>/dev/null || true)
    exit_code=$(echo "$state_json" | grep -oP '"exitCode":\s*\K\d+' || echo "")
    running=$(echo "$state_json" | grep -o '"state": *"CONTAINER_RUNNING"' || true)
    if [ -n "$exit_code" ] && [ -z "$running" ]; then break; fi
    if [ $SECONDS -ge 120 ]; then echo "[crio] timeout" >&2; break; fi
    sleep 1
  done

  logs=$(sudo crictl logs --stderr "$ctr_id" 2>&1 || true)
  end_ms=$(date +%s%3N)
  read -r ready_ms finished_ms < <(extract_times "$logs" "$end_ms")
  if [[ $start_ms -le $ready_ms && $ready_ms -le $finished_ms && $finished_ms -le $end_ms ]]; then
    startup_ms=$((ready_ms - start_ms)); workload_ms=$((finished_ms - ready_ms)); total_ms=$((end_ms - start_ms))
  else
    startup_ms=0; workload_ms=0; total_ms=$((end_ms - start_ms))
  fi
  echo "crio,$iter,$start_ms,$ready_ms,$finished_ms,$end_ms,$startup_ms,$workload_ms,$total_ms" >> "$CSV_FILE"

  sudo crictl rm "$ctr_id" >/dev/null 2>&1 || true
  sudo crictl stopp "$pod_id" >/dev/null 2>&1 || true
  sudo crictl rmp "$pod_id" >/dev/null 2>&1 || true
  rm -rf "$tmpdir"
}

main() {
  echo "Image: $IMAGE"; echo "Iterations: $ITERATIONS"
  for ((i=1; i<=ITERATIONS; i++)); do
    run_docker "$i"; run_podman "$i"; run_crio "$i"
  done
  echo "CSV écrit: $CSV_FILE"
}

main "$@" 