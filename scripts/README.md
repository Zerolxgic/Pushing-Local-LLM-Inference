# Benchmark scripts

These are cleaned public versions of the scripts used during the RX 7800 XT experiments.

## Requirements

- Linux
- LM Studio with the `lms` CLI available on `PATH`
- LM Studio local server listening on `http://localhost:1234`
- `curl`
- `jq`
- AMDGPU sysfs memory counters under `/sys/class/drm/card*/device/`

The benchmark scripts assume **parallelism 1** and disable speculative MTP. Qwen controlled decode tests also explicitly disable reasoning in the API request.

## Scripts

- `capture-baseline.sh` — captures machine, memory, GPU, driver, package, and storage state without intentionally starting LM Studio.
- `capture-runtime-state.sh` — captures LM Studio/runtime, ROCm/HIP, and Vulkan state. Calling `lms` may start LM Studio, so this is not an idle-memory capture.
- `run-gemma-offload-point.sh` — runs one Gemma 4 12B QAT 4K GPU-offload point with a warmup and three measured generations.
- `run-gemma-context-workload.sh` — calibrates a deterministic prompt to a requested context occupancy and measures a full-GPU Gemma occupied-context run.
- `run-qwen-offload-point.sh` — runs one Qwen 3.6 35B-A3B 4K GPU-offload point with reasoning disabled.
- `run-qwen-context-workload.sh` — calibrates and measures a Qwen occupied-context run at a requested GPU-offload ratio.

## Important benchmark practice

A model successfully loading is **not** treated as proof that the configuration is usable. Occupied-context tests are run separately because prompt processing and inference can require materially more working memory than an idle loaded model.

For desktop-local testing, also watch system responsiveness and VRAM with a tool such as `nvtop`. Those observations are intentionally part of the benchmark.

## Output

The scripts write local artifacts under `raw-results/`. That directory is ignored by Git because raw lab output can be large and noisy. Selected, reviewed benchmark summaries are promoted into the model-specific `benchmarks/*/results/` directories.

Before publishing additional raw artifacts, review them for machine-specific paths, accidental local identifiers, and redundant failed experiments.
