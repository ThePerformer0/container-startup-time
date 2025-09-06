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