# RX 7800 XT 16 GB — Local LLM Inference Report

**Date:** 2026-09-30  
**Hardware:** AMD Radeon RX 7800 XT 16 GB, AMD Ryzen 7 5800X, 64 GB system RAM  
**Runtime:** LM Studio / llama.cpp ROCm backend  
**Desktop:** Omarchy / Hyprland / Wayland

## Purpose

This investigation asked a practical question:

> How far can a normal 16 GB desktop GPU be pushed for local LLM inference before the tradeoffs stop making sense for an always-available assistant/orchestrator?

The machine was not treated as an inference-only server. Desktop responsiveness, VRAM headroom, context behavior, and backend stability were considered alongside tokens per second.

## Executive result

Two models established two very different boundaries.

### Gemma 4 12B QAT

Gemma fit fully on the GPU and remained operational across large occupied contexts.

Key results:

- ~50.7 tok/s at 4K with full GPU placement
- 36.50 tok/s with 7,316 input tokens in an 8K context
- 31.57 tok/s with 14,687 input tokens in a 16K context
- 24.68 tok/s with 29,429 input tokens in a 32K context
- 20.26 tok/s with 44,171 input tokens in a 49K context

This is the kind of model/hardware fit that looks attractive for a resident desktop-local system.

### Qwen 3.6 35B-A3B Q4_K_M

Qwen demonstrated that the same machine can run a quantized 35B-total-parameter MoE model through partial GPU offload.

Key results:

- ~30.86 tok/s at 67.5% GPU offload / 4K context
- ~20.67 tok/s at 50% GPU offload / 8K context with 6,518 input tokens
- ~17.38 tok/s at 50% GPU offload / 16K context with 13,080 input tokens
- higher GPU offload pushed VRAM to the desktop usability cliff
- 45% GPU / 16K produced a ROCm GPU memory-access fault during prompt processing

The MoE architecture expands the maximum runnable envelope, but does not remove the storage and memory-placement cost of the full model weights.

## Maximum envelope vs useful envelope

The most important result is not a single speed number.

The machine has two different practical boundaries:

### Maximum runnable envelope

A 35B-A3B Q4_K_M model with a reported size around 22 GB can run on the RX 7800 XT 16 GB and can exceed 30 tok/s at small context.

That is technically impressive and demonstrates that partial offload plus MoE can stretch well beyond physical VRAM capacity.

### Useful resident envelope

For a GPU that must simultaneously drive the desktop, browser, terminals, local retrieval tools, and other AI components, operating near 16 GB VRAM is undesirable.

The Qwen tests showed that:

- small-context high-offload benchmarks can look excellent while leaving almost no graphical headroom
- a model can successfully load a large configured context and still fail or become impractical when that context is actually occupied
- reducing GPU offload can improve practical behavior, but introduces CPU/GPU placement tradeoffs and backend sensitivity
- a stable configuration can still be too memory-hungry to make sense as a permanent resident model

## Working model-size search region

The next model search should focus primarily below roughly **20B total parameters**, while remaining open to unusually efficient architectures.

This is not a hard hardware limit and should not be read as a universal rule.

It is a working search region derived from the intended deployment role:

- always available
- able to understand local system state
- useful for troubleshooting and filesystem work
- integrated with retrieval / long-term memory
- capable of proposing solutions and helping with decisions
- fast enough for a conversational relationship
- able to escalate harder work to larger external agents

For that role, desktop headroom and context flexibility are more valuable than maximizing the resident model's headline parameter count.

## Architectural implication

The desired system does not require the local model to be the strongest model available for every task.

A better architecture is:

1. deterministic code for exact state, policy, validation, and execution
2. retrieval / embeddings / rankers for semantic candidate generation
3. a responsive local LLM for conversation, orchestration, troubleshooting, and ordinary judgment
4. escalation to larger agents such as Codex or Claude for difficult coding, research, or deep reasoning

This makes local-model efficiency more valuable than simply fitting the largest possible model.

## Benchmark interpretation rules

The project uses the following distinctions:

- **load feasibility** is not the same as inference feasibility
- **light inference feasibility** is not the same as occupied-context stability
- **occupied-context stability** is not the same as operational desktop usability
- runtime estimates are planning information, not proof
- one anomalous result is preserved and repeated rather than silently removed
- backend faults are reported at the tested point without being generalized beyond the evidence

## Current benchmark status

### Gemma 4 12B QAT

Current inference investigation complete.

Preserve:

- 100% GPU / 4K throughput reference
- 8K and 16K practical context references
- 32K and 49K scaling / stress references

### Qwen 3.6 35B-A3B Q4_K_M

Current feasibility investigation complete.

Preserve:

- 67.5% GPU / 4K high-performance point
- 50% GPU / 8K best practical point tested
- 50% GPU / 16K context/VRAM tradeoff
- 45% GPU / 16K ROCm/backend failure

## Next direction

Rather than continuing to optimize the 35B-A3B configuration, future testing should explore models that fit the practical resident-model envelope more naturally.

The key question going forward is no longer:

> What is the largest model this machine can run?

It is:

> What is the smallest, fastest local model that is smart enough to manage the system well and reliably know when to escalate?
