# Qwen 3.6 35B-A3B Q4_K_M — RX 7800 XT Benchmark

This benchmark tests whether a quantized 35B-total-parameter Mixture-of-Experts model can be practically used on an AMD Radeon RX 7800 XT 16 GB while the same GPU is also driving a normal desktop.

**Model:** `qwen/qwen3.6-35b-a3b`  
**Quantization:** Q4_K_M  
**Reported model size:** 22.07 GB  
**Architecture:** 35B total / approximately 3B active parameters per token

## Test environment

- GPU: AMD Radeon RX 7800 XT — 16 GB VRAM
- CPU: AMD Ryzen 7 5800X
- RAM: 64 GB
- OS: Omarchy Linux
- Desktop: Hyprland / Wayland
- Runtime: LM Studio / llama.cpp ROCm backend
- Parallelism: 1
- Speculative MTP: disabled
- Reasoning: disabled for controlled decode tests

## 4K GPU-offload sweep

| GPU offload | Decode result | Mean TTFT | Observation |
|---:|---:|---:|---|
| 60% | ~26.67 tok/s | ~0.085 s | Good baseline; more desktop headroom |
| 65% | 28.61 tok/s | ~0.100 s | Faster, memory pressure rises |
| 67.5% | 30.86 tok/s on repeat | 0.075 s | Best stable high-offload point tested |
| 70% | 29.57 tok/s aggregate | 0.074 s | Two runs ~32 tok/s, one ~24 tok/s; desktop lag observed |

The first 67.5% run contained a major decode outlier. Repeating the same point produced 30.76, 30.92, and 30.91 tok/s, so the outlier was preserved but not treated as representative steady-state performance.

### High-offload finding

A 22 GB quantized MoE model can produce roughly 31 tok/s on this 16 GB GPU when enough layers are placed on the GPU.

The cost is VRAM pressure. At 67.5%–70% offload the desktop was operating very close to the VRAM ceiling, and at 70% visible system lag appeared.

## Occupied-context tests

The practical context tests targeted approximately 80% context occupancy.

| GPU offload | Context | Actual input | Decode | TTFT | Result |
|---:|---:|---:|---:|---:|---|
| 55% | 16,384 | 13,080 | 8.67 tok/s | 14.73 s | Completed; ~15.7 GB VRAM observed, desktop lag |
| 50% | 16,384 | 13,080 | 17.38 tok/s | 15.53 s | Completed; ~15.28 GB observed |
| 45% | 16,384 | — | — | — | Failed with ROCm GPU memory-access fault |
| 50% | 8,192 | 6,518 | 20.67 tok/s | 7.58 s | Stable; ~13.28 GB observed |

## 45% / 16K failure

The 45% point loaded successfully but terminated during prompt processing.

The LM Studio / llama.cpp ROCm log reported a GPU memory-access fault after prompt processing had reached approximately 55%.

This result is recorded as a **failure at this exact backend/configuration point**. It should not be generalized into a claim that lower GPU offload is inherently less stable.

Nearby tests also exposed large ROCm buffer-allocation attempts, which reinforces the need to distinguish model-load success from actual occupied-context stability.

## Best practical point tested

The most balanced configuration in this experiment was:

- 50% GPU offload
- 8,192 configured context
- 6,518 actual input tokens
- 79.57% context occupancy
- 44 output tokens
- 20.67 tok/s decode
- 7.58 s TTFT
- 9.69 s total request wall time
- approximately 13.28 GB observed VRAM
- no swap use
- no measured GTT growth during the request
- no observed instability

This is meaningfully more practical than the high-offload 4K points, although it is still a substantial resident footprint for a normal desktop.

## What the MoE result means

The model demonstrates why active-parameter count and total-parameter count should not be conflated.

MoE reduces how much compute is active for each token, which helps a large model generate at surprisingly good speeds. But the full quantized model still has to be stored across VRAM and system memory.

So the architecture expands the **maximum runnable envelope**, but does not eliminate the cost of the total weight footprint.

## Practical conclusion

**Feasible:** yes.  
**Interesting on 16 GB:** definitely.  
**Preferred always-resident desktop model on this machine:** not from the configurations tested.

The experiment is a useful proof that 35B-class MoE inference is possible on the RX 7800 XT 16 GB, but the memory-placement compromises become increasingly important once useful working context and desktop headroom are included in the decision.

## Status

**Current Qwen 35B-A3B feasibility benchmark: complete.**

Reference points worth preserving:

- 67.5% GPU / 4K — high-performance small-context point
- 50% GPU / 8K occupied context — best practical desktop point tested
- 50% GPU / 16K — context/VRAM tradeoff reference
- 45% GPU / 16K — recorded ROCm/backend failure

See the root report for cross-model interpretation.
