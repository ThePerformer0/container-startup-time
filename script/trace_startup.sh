#!/bin/bash

set -euo pipefail

ENGINE=${1:-}
IMAGE=${2:-localhost:5000/fio-bench}
DURATION_SECONDS=${3:-5}
OUTPUT_ROOT="trace"
FLAMEGRAPH_DIR="flameGraph"
PAUSE_IMAGE=${PAUSE_IMAGE:-registry.k8s.io/pause:3.9}
PERF_CALLGRAPH=${PERF_CALLGRAPH:-dwarf}


if [[ ! -d "${OUTPUT_ROOT}" ]]; then
  mkdir -p "${OUTPUT_ROOT}"
fi

if [[ -z "${ENGINE}" || ! ${ENGINE} =~ ^(docker|podman|crio)$ ]]; then
  echo "Usage: $0 <docker|podman|crio> [image] [duration_seconds]" >&2
  exit 1
fi

if ! command -v perf >/dev/null 2>&1; then
  echo "'perf' n'est pas installé (linux-tools)." >&2
  exit 1
fi

if [[ ! -x "${FLAMEGRAPH_DIR}/flamegraph.pl" ]]; then
  echo "FlameGraph non trouvé dans ${FLAMEGRAPH_DIR}." >&2
  exit 1
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUT_DIR="${OUTPUT_ROOT}/${ENGINE}-${TIMESTAMP}"
mkdir -p "${OUT_DIR}"

log() { echo "[$(date +%H:%M:%S)] $*"; }

find_runtime_pid_by_children() {
  # Args: parent_pid
  local parent_pid="$1"
  pgrep -P "$parent_pid" -a | grep -E '(^|/)(crun|runc)\b' | awk '{print $1}' | head -n1 || true
}

wait_for_pid() {
  # Args: command_regex, timeout_seconds
  local regex="$1"; local timeout="${2:-5}"; local pid=""; local start=$SECONDS
  while true; do
    pid=$(pgrep -fa "$regex" | awk '{print $1}' | head -n1 || true)
    if [[ -n "$pid" ]]; then echo "$pid"; return 0; fi
    if (( SECONDS - start >= timeout )); then echo ""; return 1; fi
    sleep 0.05
  done
}

attach_strace_and_perf() {
  # Args: pid, prefix, duration
  local pid="$1"; local prefix="$2"; local dur="$3"
  if [[ -z "$pid" ]]; then
    log "PID runtime introuvable, tentative de profilage system-wide (perf -a)";
    sudo perf record -a -F 99 -g --call-graph "${PERF_CALLGRAPH}" -- sleep "$dur" 2>"${prefix}-perf.record.stderr" || true
    sudo perf script > "${prefix}-perf.script" 2>"${prefix}-perf.script.stderr" || true
    "${FLAMEGRAPH_DIR}/stackcollapse-perf.pl" "${prefix}-perf.script" | grep -E '(crun|runc|conmon|containerd-shim)' > "${prefix}.folded" || true
    "${FLAMEGRAPH_DIR}/flamegraph.pl" "${prefix}.folded" > "${prefix}-flamegraph.svg" || true
    return 1
  fi
  log "Attache strace/perf sur PID=${pid} pendant ${dur}s"
  # strace (tolérer l'échec si le process meurt trop vite)
  set +e
  sudo strace -ff -tt -T -s 128 -o "${prefix}-strace" -p "$pid" &
  local strace_pid=$!
  set -e
  # perf (échantillonnage limité à la fenêtre)
  if ! sudo perf record -F 99 -g --call-graph "${PERF_CALLGRAPH}" -p "$pid" -- sleep "$dur" 2>"${prefix}-perf.record.stderr"; then
    log "perf -p a échoué, bascule en perf -a"
    sudo perf record -a -F 99 -g --call-graph "${PERF_CALLGRAPH}" -- sleep "$dur" 2>>"${prefix}-perf.record.stderr" || true
  fi
  # arrêter strace après la fenêtre
  kill "$strace_pid" >/dev/null 2>&1 || true
  # générer flamegraph (filtrer les stacks pertinentes si system-wide)
  sudo perf script > "${prefix}-perf.script" 2>"${prefix}-perf.script.stderr" || true
  if grep -q "-a -- sleep" "${prefix}-perf.record.stderr" 2>/dev/null || ! grep -q . "${prefix}-perf.script"; then
    "${FLAMEGRAPH_DIR}/stackcollapse-perf.pl" "${prefix}-perf.script" | grep -E '(crun|runc|conmon|containerd-shim)' > "${prefix}.folded" || true
  else
    "${FLAMEGRAPH_DIR}/stackcollapse-perf.pl" "${prefix}-perf.script" > "${prefix}.folded"
  fi
  "${FLAMEGRAPH_DIR}/flamegraph.pl" "${prefix}.folded" > "${prefix}-flamegraph.svg"
}

run_docker() {
  local name="trace-fio-$(date +%s)"
  log "Docker: run ${IMAGE} (name=${name})"
  sudo docker rm -f "$name" >/dev/null 2>&1 || true
  # Lancer et obtenir l'ID pour cibler le shim
  sudo docker run --rm --name "$name" "$IMAGE" >"${OUT_DIR}/${ENGINE}.out" 2>"${OUT_DIR}/${ENGINE}.err" &
  local bg=$!
  # Attendre que le conteneur apparaisse et récupérer son ID complet
  local cid="" cid12=""
  for i in {1..200}; do
    cid=$(sudo docker inspect -f '{{.Id}}' "$name" 2>/dev/null || true)
    if [[ -n "$cid" ]]; then cid12=${cid:0:12}; break; fi
    sleep 0.02
  done
  # Chercher le shim correspondant et son enfant runtime
  local shim_pid runtime_pid
  if [[ -n "$cid" ]]; then
    shim_pid=$(wait_for_pid "containerd-shim(-runc-v2)?[^-]*.*--id ${cid}($| )" 10 || true)
    if [[ -z "$shim_pid" && -n "$cid12" ]]; then
      shim_pid=$(wait_for_pid "containerd-shim(-runc-v2)?[^-]*.*--id ${cid12}($| )" 5 || true)
    fi
  fi
  if [[ -z "$shim_pid" ]]; then
    shim_pid=$(wait_for_pid 'containerd-shim(-runc-v2)?' 5 || true)
  fi
  [[ -n "$shim_pid" ]] && runtime_pid=$(find_runtime_pid_by_children "$shim_pid") || true
  # Si non trouvé, fallback recherche directe du runtime en phase create
  if [[ -z "${runtime_pid:-}" ]]; then
    runtime_pid=$(wait_for_pid '(^|/)(runc|crun) (.*)create' 5 || true)
  fi
  # En dernier recours, s'attacher au shim pour capturer des syscalls utiles
  if [[ -z "${runtime_pid:-}" && -n "${shim_pid:-}" ]]; then
    log "Runtime introuvable, attache sur containerd-shim PID=${shim_pid}"
    runtime_pid="$shim_pid"
  fi
  attach_strace_and_perf "$runtime_pid" "${OUT_DIR}/${ENGINE}" "$DURATION_SECONDS" || true
  wait $bg || true
}

run_podman() {
  local name="trace-fio-$(date +%s)"
  log "Podman: run ${IMAGE} (name=${name})"
  sudo podman rm -f "$name" >/dev/null 2>&1 || true
  sudo podman run --rm --name "$name" "$IMAGE" >"${OUT_DIR}/${ENGINE}.out" 2>"${OUT_DIR}/${ENGINE}.err" &
  local bg=$!
  sleep 0.2
  local conmon_pid runtime_pid
  conmon_pid=$(wait_for_pid 'conmon( |$)' 10 || true)
  if [[ -n "$conmon_pid" ]]; then
    runtime_pid=$(find_runtime_pid_by_children "$conmon_pid")
  fi
  attach_strace_and_perf "$runtime_pid" "${OUT_DIR}/${ENGINE}" "$DURATION_SECONDS" || true
  wait $bg || true
}

run_crio() {
  log "CRI-O: pull images si nécessaire"
  sudo crictl pull "$PAUSE_IMAGE" >/dev/null 2>&1 || true
  sudo crictl pull "$IMAGE" >/dev/null 2>&1 || true

  local tmpdir sandbox_json container_json
  tmpdir=$(mktemp -d)
  sandbox_json="$tmpdir/pod_sandbox.json"
  container_json="$tmpdir/container.json"

  cat > "$sandbox_json" <<'EOF'
{
  "metadata": {"name": "fio-pod", "namespace": "default", "attempt": 1, "uid": "fio-pod-uid"},
  "log_directory": "/tmp",
  "linux": {}
}
EOF

  cat > "$container_json" <<EOF
{
  "metadata": {"name": "fio"},
  "image": {"image": "$IMAGE"},
  "args": [],
  "command": [],
  "working_dir": "/",
  "log_path": "fio.0.log",
  "stdin": false,
  "stdin_once": false,
  "tty": false,
  "linux": {"resources": {}}
}
EOF

  log "CRI-O: création pod et container"
  local pod_id ctr_id
  pod_id=$(sudo crictl runp "$sandbox_json" | tail -n1)
  ctr_id=$(sudo crictl create "$pod_id" "$container_json" "$sandbox_json")

  log "CRI-O: démarrage container"
  sudo crictl start "$ctr_id" >/dev/null
  sleep 0.2

  # Repérer conmon lié au container (conmon -c <cid>)
  local conmon_pid runtime_pid
  conmon_pid=$(wait_for_pid "conmon.*-c ${ctr_id}" 10 || true)
  if [[ -z "$conmon_pid" ]]; then
    # fallback: premier conmon actif
    conmon_pid=$(wait_for_pid 'conmon( |$)' 10 || true)
  fi
  [[ -n "$conmon_pid" ]] && runtime_pid=$(find_runtime_pid_by_children "$conmon_pid") || true

  attach_strace_and_perf "$runtime_pid" "${OUT_DIR}/${ENGINE}" "$DURATION_SECONDS" || true

  # Attendre fin du conteneur, puis nettoyage
  local end_wait=0
  while true; do
    state=$(sudo crictl inspect -o json "$ctr_id" 2>/dev/null | grep -o '"state": *"CONTAINER_RUNNING"' || true)
    [[ -z "$state" ]] && break
    (( end_wait++ >= 60 )) && break
    sleep 1
  done
  sudo crictl logs "$ctr_id" >"${OUT_DIR}/${ENGINE}.out" 2>"${OUT_DIR}/${ENGINE}.err" || true
  sudo crictl rm "$ctr_id" >/dev/null 2>&1 || true
  sudo crictl stopp "$pod_id" >/dev/null 2>&1 || true
  sudo crictl rmp "$pod_id" >/dev/null 2>&1 || true
  rm -rf "$tmpdir"
}

case "$ENGINE" in
  docker) run_docker ;;
  podman) run_podman ;;
  crio) run_crio ;;
  *) echo "ENGINE inconnu: $ENGINE"; exit 1 ;;
esac 