# Methodology

This project is designed to answer a practical question:

> What local-LLM configurations are not merely runnable on this hardware, but actually usable on a normal desktop?

That requires more than recording whether a model loads or how many tokens per second it can produce in an idealized short prompt.

## Test philosophy

The benchmark separates four distinct states:

1. **Load feasibility** — can the model be allocated successfully?
2. **Light inference feasibility** — can it generate under a short, controlled request?
3. **Occupied-context stability** — can it process a realistically full working context?
4. **Operational usability** — can it do all of the above while the rest of the desktop remains responsive?

A configuration can pass one stage and fail a later one.

## Controlled variables

Where possible, tests hold constant:

- model artifact and quantization
- LM Studio / llama.cpp backend
- parallelism
- speculative decoding state
- output length
- prompt structure
- reasoning mode

Then one primary variable is changed at a time, such as:

- GPU offload ratio
- configured context size
- occupied-context level

## Metrics

Recorded metrics include:

- model load success/failure
- load time
- configured context length
- actual input-token count
- context occupancy percentage
- output-token count
- decode tokens per second
- time to first token
- total request wall time
- VRAM before and after inference
- GTT before and after inference
- system RAM and swap state
- desktop responsiveness
- runtime/backend errors

## Why occupied-context tests matter

A model may load at a large context size while still failing once that context is actually used.

The occupied-context workload therefore calibrates a deterministic repeated prompt toward a target percentage of the configured context. The model is then reloaded cleanly before the measured run.

This exposes working-memory behavior that load-only estimates can miss.

## Desktop responsiveness

This benchmark intentionally treats desktop responsiveness as data.

The GPU is simultaneously responsible for the graphical desktop. A configuration that pins VRAM near 100% and makes Hyprland or other applications visibly lag is not considered an attractive always-resident configuration even if the inference request completes successfully.

That makes the project different from a dedicated inference-server benchmark.

## Interpretation rules

- A single outlier is preserved rather than silently discarded.
- Suspicious results should be repeated before being treated as representative.
- Runtime/backend failures are recorded as failures at the tested configuration, not generalized into claims about every lower or higher offload point.
- LM Studio resource estimates are treated as planning signals, not proof of occupied-context stability.
- Results are specific to the exact hardware, runtime, quantization, and configuration under test.

## Hardware baseline

Current primary test platform:

- AMD Radeon RX 7800 XT — 16 GB VRAM
- AMD Ryzen 7 5800X — 8 cores / 16 threads
- 64 GB system RAM
- Omarchy Linux
- Hyprland / Wayland
- LM Studio / llama.cpp ROCm backend

## Current decision criterion

The intended local model is not expected to replace larger cloud or agent models for every task.

The useful resident model should instead optimize for:

- responsiveness
- adequate reasoning ability
- reliable tool use
- useful working context
- memory/retrieval integration
- filesystem and OS assistance
- desktop headroom
- escalation judgment for handing harder work to larger agents

The benchmark therefore prioritizes practical system fit over maximum parameter count.
