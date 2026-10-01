# Pushing Local LLM Inference

A practical benchmark project for finding the difference between **what a desktop GPU can technically run** and **what actually makes sense to run every day**.

This repository documents controlled local-LLM inference experiments on an AMD Radeon RX 7800 XT 16 GB system using LM Studio / llama.cpp with ROCm. The focus is not leaderboard chasing. The goal is to identify configurations that remain useful on a normal desktop that still has to drive a compositor, browser, terminals, tools, and other local AI components.

## Hardware

- GPU: AMD Radeon RX 7800 XT — 16 GB VRAM
- CPU: AMD Ryzen 7 5800X — 8 cores / 16 threads
- RAM: 64 GB DDR4
- OS: Omarchy Linux
- Desktop: Hyprland / Wayland
- Runtime: LM Studio with llama.cpp ROCm backend

## What is being measured

The benchmark currently focuses on:

- decode throughput (tokens/sec)
- time to first token
- configured context size
- occupied-context behavior
- GPU offload ratio
- VRAM usage
- GTT/shared-memory behavior
- swap involvement
- desktop responsiveness
- backend/runtime failure modes

Desktop usability is intentionally part of the benchmark. A configuration that produces a good token rate but makes the machine lag is treated differently from one that can remain resident while the system stays comfortable.

## Current experiments

### Gemma 4 12B QAT

Gemma fit fully on the GPU and scaled cleanly across large contexts.

Highlights:

- ~50.7 tok/s at 4K with full GPU placement
- 36.5 tok/s at ~7.3K input / 8K context
- 31.6 tok/s at ~14.7K input / 16K context
- 24.7 tok/s at ~29.4K input / 32K context
- 20.3 tok/s at ~44.2K input / 49K context

This model currently represents the kind of hardware fit that looks attractive for an always-available local helper or orchestrator.

See [`benchmarks/gemma-4-12b-qat/README.md`](benchmarks/gemma-4-12b-qat/README.md).

### Qwen 3.6 35B-A3B Q4_K_M

Qwen demonstrated that a 35B-total-parameter MoE model can run surprisingly well on a 16 GB card through partial GPU offload.

Highlights:

- ~30.9 tok/s at 67.5% GPU offload / 4K context
- ~20.7 tok/s at 50% GPU offload / 8K context / ~6.5K input
- ~17.4 tok/s at 50% GPU offload / 16K context / ~13.1K input
- higher offload produced better small-context throughput but pushed VRAM to the desktop usability cliff
- 45% GPU / 16K produced a ROCm GPU memory-access fault during prompt processing

The main finding is that MoE expands the **maximum runnable envelope**, but the 22 GB quantized footprint still matters for a desktop-resident deployment.

See [`benchmarks/qwen-3.6-35b-a3b/README.md`](benchmarks/qwen-3.6-35b-a3b/README.md).

## Working conclusion

For this RX 7800 XT 16 GB system, models below roughly **20B total parameters** are currently the most promising search region for an always-resident local model. This is a working hardware-specific conclusion, not a universal cutoff.

The target system does not need the largest model the machine can force into memory. It needs a model that is fast, available, contextually informed, reliable with tools, and smart enough to escalate harder work to larger agents when appropriate.

## Repository layout

```text
.
├── README.md
├── LICENSE
├── benchmarks/
│   ├── gemma-4-12b-qat/
│   │   └── README.md
│   └── qwen-3.6-35b-a3b/
│       └── README.md
├── reports/
│   └── 2026-09-30-rx7800xt-inference-report.md
└── docs/
    └── methodology.md
```

Raw benchmark artifacts and scripts from the local lab may be added incrementally as they are cleaned for public release.

## Notes on interpretation

These results are hardware-, runtime-, model-, quantization-, and configuration-specific. They should not be treated as universal performance claims for the model families.

In particular, the project distinguishes between:

- **load feasibility** — can the model be allocated?
- **benchmark feasibility** — can it generate under a light test?
- **occupied-context stability** — can it process a realistically full working context?
- **operational usability** — can it do all of that while the desktop remains responsive?

That distinction is the main reason this repository exists.

## License

Apache-2.0.
