#!/usr/bin/env bash
# Manual launch only, once the RTX PRO 6000 (physical GPU 0) is free.
set -euo pipefail
gpu=${GRANITE_GPU:-0}
context=${GRANITE_CONTEXT:-131072}
requests=${GRANITE_REQUESTS:-4}
gpu_memory=$(nvidia-smi -i "$gpu" --query-compute-apps=used_memory --format=csv,noheader,nounits)
if awk '$1 ~ /^[0-9]+$/ && $1 > 1024 {busy=1} END {exit !busy}' <<< "$gpu_memory"; then
  echo "GPU $gpu has a compute process using over 1 GiB; refusing to start Granite." >&2
  exit 1
fi
export CUDA_VISIBLE_DEVICES="$gpu"
export HF_HUB_OFFLINE=1
export CUDA_HOME=/home/bob/sglang-env/lib/python3.12/site-packages/nvidia/cu13
export PATH="$CUDA_HOME/bin:/home/bob/sglang-env/bin:$PATH"
export NVCC_PREPEND_FLAGS='-ccbin /usr/bin/g++-14'
exec /home/bob/sglang-env/bin/python3 -m sglang.launch_server \
  --model-path /home/bob/.cache/huggingface/hub/models--ibm-granite--granite-4.2-8b/snapshots/f8de16cdcdbc6c779ca517604e050d82cc119e44 \
  --dtype bfloat16 --context-length "$context" \
  --mem-fraction-static 0.85 --max-running-requests "$requests" \
  --attention-backend flashinfer --chunked-prefill-size 2048 \
  --sampling-defaults model \
  --default-chat-template-kwargs '{"enable_thinking":true,"low_effort":false}' \
  --reasoning-parser nemotron_3 --tool-call-parser qwen3_coder \
  --host 127.0.0.1 --port 8097 \
  --served-model-name granite-4.2-8b --api-key rtlbench-granite "$@"
