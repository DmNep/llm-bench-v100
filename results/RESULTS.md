# Ollama speed benchmark: 1x Tesla V100 32GB

Ollama 0.34.2, Ubuntu 26.04, driver 580, 28 GiB RAM, V100 SXM2 on a PCIe adapter board. Measured 2026-10-05 with bench.ps1.

### Generation speed, tokens/s (prompt of the given size already in context)

| Model | Params | Quant | Ctx | 1K | 4K | 16K | 25K | 33K | 67K |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| llama3.2:1b | 1.2B | Q8_0 | 32768 | 288.0 | 279.7 | 247.8 | 222.8 | - | - |
| gemma4-32k | 30.7B | Q4_K_M | 49152 | 56.4 | 54.2 | 50.9 | 49.6 | 45.5 | - |
| gemma4-qat-32k | 30.7B | Q4_0 | 32768 | 33.8 | 32.3 | 31.0 | 30.2 | - | - |
| qwen3-coder-32k | 30.5B | Q8_0 | 32768 | 45.5 | 44.4 | 41.6 | 40.1 | - | - |
| qwen3-thinking-128k | 30.5B | Q4_K_M | 131072 | 132.8 | 125.0 | 104.8 | 94.8 | 86.2 | 63.7 |

### Prompt reading (prefill) speed, tokens/s

| Model | Params | Quant | Ctx | 1K | 4K | 16K | 25K | 33K | 67K |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| llama3.2:1b | 1.2B | Q8_0 | 32768 | 18,180.9 | 19,476.2 | 13,159.8 | 10,720.7 | - | - |
| gemma4-32k | 30.7B | Q4_K_M | 49152 | 409.2 | 553.0 | 554.1 | 518.4 | 484.1 | - |
| gemma4-qat-32k | 30.7B | Q4_0 | 32768 | 571.4 | 697.9 | 676.1 | 623.8 | - | - |
| qwen3-coder-32k | 30.5B | Q8_0 | 32768 | 812.2 | 989.2 | 932.9 | 875.7 | - | - |
| qwen3-thinking-128k | 30.5B | Q4_K_M | 131072 | 1,298.3 | 1,311.2 | 1,170.4 | 1,074.3 | 985.1 | 742.8 |

### Memory reported by Ollama after the runs

| Model | Reported VRAM, GB | Reported total, GB |
|---|---:|---:|
| llama3.2:1b | 2.6 | 2.6 |
| gemma4-32k | 2.1 | 2.1 |
| gemma4-qat-32k | 19.9 | 19.9 |
| qwen3-coder-32k | 32.5 | 36.1 |
| qwen3-thinking-128k | 31.5 | 31.5 |

### Notes

- Each cell is the median of 3 runs; every run uses a different random prompt so the prompt cache cannot inflate prefill. A row is marked truncated and excluded if Ollama cut the prompt (none were).
- Prompt sizes are measured tokens (prompt_eval_count): the target 1K/4K/16K/24.5K/32K/64K give about 1.1K/4.2K/16.6K/25K/33K/66.7K tokens. A '-' means the model's configured context is too small for that size.
- gemma4-32k (Q4_K_M, 20.4 GB on disk): Ollama reports only 2.1 GB loaded, and 56-61 tok/s generation is above the 900 GB/s bandwidth limit of a 20 GB dense model (about 44 tok/s). The reported memory and the speed are not consistent for this tag; the cause was not found (nvidia-smi could not be read at the time). Treat its numbers with caution.
- qwen3-coder-32k is Q8_0 (32.5 GB) and nearly fills the card; qwen3-thinking-128k (Q4_K_M, 18.6 GB) with its 131072-token window reports 31.5 GB loaded.
- A 66.7K-token prompt on qwen3-thinking-128k (window 131072) was read in full (prompt_eval_count 66,709): Ollama keeps the whole prompt when it fits in num_ctx.
