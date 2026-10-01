# Gemma 4 12B QAT — RX 7800 XT Benchmark

This benchmark explores how `google/gemma-4-12b-qat` behaves on an AMD Radeon RX 7800 XT 16 GB under different GPU-offload and context configurations.

The goal is not to claim universal Gemma performance. It is to characterize how this specific model/runtime combination fits a normal desktop that still has to remain usable while inference is running.

## Test environment

- GPU: AMD Radeon RX 7800 XT — 16 GB VRAM
- CPU: AMD Ryzen 7 5800X
- RAM: 64 GB
- OS: Omarchy Linux
- Desktop: Hyprland / Wayland
- Runtime: LM Studio / llama.cpp ROCm backend
- Parallelism: 1
- Speculative MTP: disabled

## 4K GPU-offload sweep

| GPU offload | Mean decode | Mean TTFT | Observation |
|---:|---:|---:|---|
| 50% | 7.80 tok/s | 3.77 s | Large throughput penalty |
| 75% | 13.58 tok/s | ~5.02 s | Usable, substantially slower than full GPU |
| 90% | 23.60 tok/s | ~5.62 s | Significant recovery |
| 95% | 34.46 tok/s | ~6.16 s | Strong improvement |
| 97.5% | 41.48 tok/s | 6.15 s | Near-full-GPU performance |
| 99% | 50.63 tok/s | 6.38 s | Essentially full-GPU throughput |
| 100% | ~50.69 tok/s | ~6.90 s | Full-GPU control |

### Observation

Gemma strongly preferred full GPU placement on this hardware. Partial offload worked, but the throughput cost became large surprisingly quickly.

## Context allocation sweep

Full-GPU load estimates and successful load tests:

| Configured context | Estimated GPU memory | Result |
|---:|---:|---|
| 8,192 | 8.11 GiB | Loaded |
| 16,384 | 9.35 GiB | Loaded |
| 32,768 | 11.84 GiB | Loaded |
| 49,152 | 14.33 GiB | Loaded |
| 65,536 | 16.81 GiB | Estimate only; beyond comfortable 16 GB budget |

Load feasibility alone was not treated as sufficient evidence, so each practical context size was followed by an occupied-context workload.

## Occupied-context results

These tests targeted roughly 90% context occupancy.

| Context | Actual input | Occupancy | Decode | TTFT | Wall time |
|---:|---:|---:|---:|---:|---:|
| 8,192 | 7,316 | 89.31% | 36.50 tok/s | 16.81 s | 20.33 s |
| 16,384 | 14,687 | 89.64% | 31.57 tok/s | 27.02 s | 31.12 s |
| 32,768 | 29,429 | 89.81% | 24.68 tok/s | 45.94 s | 51.22 s |
| 49,152 | 44,171 | 89.87% | 20.26 tok/s | 70.14 s | 76.63 s |

### Main finding

Gemma 4 12B QAT fits this 16 GB GPU unusually well for the intended desktop-local use case.

- Full-GPU decode is fast.
- 8K and 16K contexts remain comfortably usable.
- 32K remains viable despite a ~29K-token prompt.
- A ~44K-token prompt inside a 49K context still completed at ~20.3 tok/s.
- Large context primarily increases prompt-processing latency and TTFT rather than making the model impossible to run.

## Practical interpretation

For an always-available local assistant/orchestrator, this result is more interesting than the maximum context number itself.

The model can remain fully GPU-resident while still supporting useful working context. That leaves fewer CPU/GPU placement compromises than a larger model that must be split across VRAM and system RAM.

## Status

**Current Gemma inference benchmark: complete for this investigation.**

Reference points worth preserving:

- 100% GPU / 4K — throughput reference
- 8K occupied context — interactive context reference
- 16K occupied context — larger practical context reference
- 32K and 49K — scaling / stress references

See the root report for cross-model interpretation.
