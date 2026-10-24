# Granite 4.2 8B

Checkpoint: https://huggingface.co/ibm-granite/granite-4.2-8b
Pinned revision: `f8de16cdcdbc6c779ca517604e050d82cc119e44`.

Uses the existing `/home/bob/sglang-env` (SGLang 0.5.19), BF16 weights,
native 131072-token context, and physical GPU 0 (RTX PRO 6000).
The model's generation config provides temperature 1.0 and top_p 0.95.
Thinking is enabled. Parsers: `nemotron_3` and `qwen3_coder`, per IBM's SGLang recipe.
The dedicated Anthropic-compatible endpoint is `http://127.0.0.1:8097`.

Nothing is automatically scheduled. The launcher refuses to start if GPU 0
has a compute process using more than 1 GiB, including an idle Qwen server. Arrange for the existing
server to be shut down separately after all intended work has finished.

From `/home/bob/Downloads/rtl-bug-repro-bench`, once GPU 0 is free:

```bash
nohup bash eval/serve_granite.sh > eval/runs/sglang-granite.log 2>&1 &
```

Wait for server initialization and a successful health response:

```bash
curl -f http://127.0.0.1:8097/health
```

Then launch the benchmark:

```bash
nohup bash eval/run_granite.sh granite1 > eval/runs/granite1.log 2>&1 &
```

This first checks Claude Code can successfully execute a Bash tool and receive
its result, then runs all 14 cases in sim and nosim, four episodes concurrently,
60 turns and four hours per episode, with `--skip-done`. Smoke failure prevents
the batches from starting. Artifacts go in `eval/runs/granite1/`.

The model load and Claude Code tool smoke passed on the RTX 3090 on 2026-10-19.
The model executed Bash, received `GRANITE_TOOL_OK`, and reported it in two turns.
The test used BF16 weights, 32768 advertised context, one request, CUDA graphs
disabled, and a 1024-token smoke output limit. Available KV capacity was 18214
tokens; this does not validate the full 128K configuration on the RTX PRO 6000.
The initial 3090 kernel compilation was included in the 64-second smoke duration.
The 3090 test server was stopped afterward and its idle llama.cpp service restored.

To repeat a smoke test on an available 3090:

```bash
GRANITE_GPU=1 GRANITE_CONTEXT=32768 GRANITE_REQUESTS=1 bash eval/serve_granite.sh --disable-cuda-graph
# In another terminal after server readiness:
GRANITE_CONTEXT=32768 GRANITE_SMOKE_OUTPUT_TOKENS=1024 GRANITE_SMOKE_ONLY=1 bash eval/run_granite.sh granite-3090
```

`GRANITE_SMOKE_ONLY=1` prevents benchmark batches from starting. The GPU and
context overrides are optional; production defaults remain GPU 0 and 131072.

Preparation validated the offline tokenizer/config, thinking and tool prompts
with both `high` and `max` effort, and all 363 tensor names across four shards
(17,583,228,032 bytes). The upstream index assigns some tensors to the wrong
shard, but the full set is present exactly once. SGLang's standard loader uses
the index to select filenames and reads tensor keys directly from each shard,
so it does not depend on those incorrect per-tensor shard assignments.
