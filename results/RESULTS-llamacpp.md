# llama.cpp (llama-server), speed on one Tesla V100 32 GB, 2026-10-05

### Generation speed, tokens/s (prompt of the given size already in context)

| Model | Params | Quant | Ctx | 1K | 4K | 16K | 25K | 33K | 67K | 115K |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| gemma4-31b-qat Q4_0 (llama.cpp, KV f16) | 31B | Q4_0 | 32768 | 33.4 | 32.5 | 31.1 | 30.3 | - | - | - |
| gemma4-31b Q4_K_M (llama.cpp, KV f16) | 31B | Q4_K_M | 49152 | 29.9 | 29.2 | 28.1 | 27.5 | 26.7 | - | - |
| llama3.2-1b Q8_0 (llama.cpp, KV f16) | 1.2B | Q8_0 | 32768 | 303.2 | 292.5 | 245.2 | 225.8 | - | - | - |
| qwen3-30b-a3b-thinking Q4_K_M (llama.cpp, KV q8_0) | 30.5B | Q4_K_M | 131072 | 110.4 | 99.0 | 69.8 | 59.0 | 50.7 | 32.6 | 21.5 |
| qwen3-coder-30b-a3b Q8_0 (llama.cpp, KV f16, 8 expert layers on CPU) | 30.5B | Q8_0 | 32768 | 35.7 | 36.4 | 34.0 | 32.9 | - | - | - |

### Prompt reading (prefill) speed, tokens/s

| Model | Params | Quant | Ctx | 1K | 4K | 16K | 25K | 33K | 67K | 115K |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| gemma4-31b-qat Q4_0 (llama.cpp, KV f16) | 31B | Q4_0 | 32768 | 484.0 | 599.5 | 574.0 | 526.7 | - | - | - |
| gemma4-31b Q4_K_M (llama.cpp, KV f16) | 31B | Q4_K_M | 49152 | 496.7 | 600.0 | 575.6 | 528.5 | 493.3 | - | - |
| llama3.2-1b Q8_0 (llama.cpp, KV f16) | 1.2B | Q8_0 | 32768 | 16,790.8 | 16,447.1 | 11,496.8 | 9,410.6 | - | - | - |
| qwen3-30b-a3b-thinking Q4_K_M (llama.cpp, KV q8_0) | 30.5B | Q4_K_M | 131072 | 1,177.2 | 1,309.2 | 1,162.8 | 1,056.0 | 971.8 | 729.0 | 529.3 |
| qwen3-coder-30b-a3b Q8_0 (llama.cpp, KV f16, 8 expert layers on CPU) | 30.5B | Q8_0 | 32768 | 414.5 | 524.5 | 524.3 | 502.2 | - | - | - |

### Memory reported by the engine after the runs (Ollama; for llama.cpp the value is given by hand from nvidia-smi, if any)

| Model | Reported VRAM, GB | Reported total, GB |
|---|---:|---:|
| gemma4-31b-qat Q4_0 (llama.cpp, KV f16) | n/a | n/a |
| gemma4-31b Q4_K_M (llama.cpp, KV f16) | n/a | n/a |
| llama3.2-1b Q8_0 (llama.cpp, KV f16) | n/a | n/a |
| qwen3-30b-a3b-thinking Q4_K_M (llama.cpp, KV q8_0) | 24.9 | n/a |
| qwen3-coder-30b-a3b Q8_0 (llama.cpp, KV f16, 8 expert layers on CPU) | n/a | n/a |

### Notes

- VRAM measured with nvidia-smi on the server: Qwen3-30B-A3B-Thinking (ctx 131072, KV q8_0) 24.9 GB; Gemma 4 31B Q4_K_M (ctx 49152) 23.7 GB.
- Qwen3-Coder Q8_0 weighs about 32 GB and does not fit in the card with a KV cache, so 8 expert layers were kept in RAM (--n-cpu-moe 8).
