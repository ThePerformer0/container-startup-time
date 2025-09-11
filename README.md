# Container Engine Startup Time Analysis

This repository documents an experiment to analyze and compare the startup times of different container engines (Podman, Docker, and CRI-O) on a local Ubuntu 22.04 environment. The goal is to identify why Podman exhibits a higher startup time compared to Docker and CRI-O, using a combination of benchmarking tools and performance analysis techniques.

## Objectives
- Measure and compare the startup times of Podman, Docker, and CRI-O across various workloads.
- Identify potential causes of startup time differences using tools like `strace`, FlameGraph, and (optionally) `ipcbench`.
- Document the methodology, configurations, and results for reproducibility.

## Local Environment
- **OS**: Ubuntu 22.04
- **Tools**:
  - Podman
  - Docker
  - CRI-O (via crictl)
  - FlameGraph: Installed from [github.com/brendangregg/FlameGraph](https://github.com/brendangregg/FlameGraph)
- **Benchmarks**: FIO (disk I/O), Stream (memory bandwidth), NetPerf (network), Unixbench (CPU/multi-tasking)

## Architecture du projet

```
container-startup-time/
  benchmarks/
    fio/
      Dockerfile
      benchmark.sh
    netperf/
      Dockerfile
    stream/
      Dockerfile
      stream.c
    unixbench/
      Dockerfile
  FlameGraph/
  ipc-bench/
  results/
    <runtime>_<benchmark>_results.txt
  script/
    measure.sh
  README.md
```

- **benchmarks/**: contient une image par type de charge.
  - **fio/** (Alpine): installe `fio` et exécute `benchmark.sh`. Variables d’environnement: `DBENCH_MOUNTPOINT`, `FIO_SIZE`, `FIO_OFFSET_INCREMENT`, `FIO_DIRECT`, `TH`. Émet un horodatage de disponibilité via `FIO_BENCHMARK_READY_AT`.
  - **stream/** (Ubuntu 20.04): installe toolchain, clone et compile STREAM. Paramètres via `STREAM_ARRAY_SIZE`, `STREAM_ITERATIONS`. Émet `STREAM_READY_AT` avant l’exécution du binaire.
  - **netperf/** (Ubuntu 20.04): installe `netperf`, lance `netserver` puis exécute `netperf` localement. Émet `NETPERF_SERVER_READY_AT`.
  - **unixbench/** (Alpine 3.16): clone/compile `byte-unixbench` et lance `Run`. Émet `UNIXBENCH_READY_AT`.
- **script/measure.sh**: script principal qui mesure les temps de démarrage et totaux.
  - Cible des images préfixées `localhost:5000/` (registre local): `fio-bench`, `stream-bench`, `netperf-bench`, `unixbench-bench`.
  - Exécute successivement avec les runtimes: `podman`, `docker`, `crio`.
  - Capture trois temps (ms): `START_TIME` (lancement), `READY_TIME` (émis par l’image), `END_TIME` (fin d’exécution). En déduit `Startup Time` = `READY_TIME - START_TIME`, `Total Time` = `END_TIME - START_TIME`.
  - Sauvegarde la sortie brute et les métriques dans `results/<runtime>_<image>_results.txt`.
- **results/**: sorties texte consolidant horodatages et logs par couple runtime/benchmark.
- **FlameGraph/**: outils pour générer des FlameGraphs (post-analyse).
- **ipc-bench/**: espace réservé pour des tests IPC optionnels.

Note: assurez-vous d’avoir un registre local accessible à `localhost:5000` pour pousser/tracter les images de benchmark, ou adaptez les noms d’images dans `script/measure.sh`.

## Steps
1. **Install Tools**: Set up FlameGraph and verify container engine versions.
2. **Configure Registry and Build Benchmark Images**: Set up a local registry and create Docker images for each benchmark.
3. **Write Measurement Scripts**: Develop scripts to measure startup times and execution durations.
4. **Run Experiments**: Execute benchmarks on local machine and (later) CloudLab.
5. **Analyze Results**: Use performance tools to analyze data and hypothesize causes.
6. **Document Findings**: Update this README with final results and conclusions.

## Current Status
The project is in the initial setup phase. Tools are being installed, and benchmark images (FIO, Stream, NetPerf, Unixbench) are being developed. Check back for updates as we progress through the experiments.

## How to Contribute
Contributions are welcome! Please open an issue or submit a pull request if you have suggestions or improvements.

## Acknowledgments
- Inspired by performance analysis techniques from [brendangregg/FlameGraph](https://github.com/brendangregg/FlameGraph).
- Benchmark tools: FIO, Stream, NetPerf, Unixbench from their respective communities.