<!--
SPDX-FileCopyrightText: Copyright (c) 2025-2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
SPDX-License-Identifier: Apache-2.0
-->

# Nemotron 3 Nano Omni NVFP4

Serves [nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4](https://huggingface.co/nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4)
using vLLM with an aggregated Dynamo deployment.

This recipe builds a custom container that layers the `ai-dynamo` wheel
(from <https://pypi.nvidia.com/ai-dynamo/>) onto an upstream vLLM image — no
source build, no Rust toolchain.

## Topology

| Role | Replicas | GPUs/replica | Notes |
|------|----------|--------------|-------|
| Frontend | 1 | 0 | Dynamo frontend with prefix-hash KV routing |
| vLLM worker | 1 | 1 | Text, image, video, and audio inputs |

## Prerequisites

- A Kubernetes cluster with the [Dynamo Operator](../../docs/kubernetes/README.md) installed
- One NVIDIA GPU per worker replica
- Shared PVC storage for the Hugging Face model cache
- Hugging Face access to `nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4`

## Step 1: Build the Container

```bash
docker build \
  -t <your-registry>/nemotron-omni-vllm:latest \
  -f recipes/nemotron-3-nano-omni/Dockerfile \
  recipes/nemotron-3-nano-omni
docker push <your-registry>/nemotron-omni-vllm:latest
```

Useful build args:

- `BASE_IMAGE=<image>` — pin to a different vLLM base (default `vllm/vllm-openai:v0.20.0`).
- `DYNAMO_VERSION=<version>` — pin to a specific `ai-dynamo` release or nightly from <https://pypi.nvidia.com/ai-dynamo/>. Default tracks the latest tested nightly. Make sure the chosen wheel's `vllm` dependency matches `BASE_IMAGE`.

### Source-build validation

The recipe Dockerfile above is intentionally a published-wheel image. If you are
validating local Dynamo source changes against this model, build your source
wheels into a vLLM `0.20.0` runtime image instead of using the recipe
Dockerfile. Keep the Dynamo wheel builder and runtime on the same Linux/glibc
baseline; otherwise native wheels such as `ai-dynamo-runtime` can be tagged for a
newer `manylinux` level than the runtime image accepts.

For single-node functional validation, a source-built image should preserve the
upstream vLLM stack and install the local Dynamo wheels with `--no-deps`. Use a
builder virtual environment for `maturin` rather than installing build tools into
the image's system Python, because upstream runtime images can use
externally-managed Python environments.

When changing base images, use a separate Cargo target cache for each glibc
baseline. Reusing Rust build artifacts from a newer base image can fail at build
time with missing `GLIBC_*` symbols.

## Step 2: Download the Model

Create the PVC, Hugging Face token secret, and download the model weights:

```bash
export NAMESPACE=<your-namespace>

# Create the namespace if it does not already exist.
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# First edit storageClassName in model-cache.yaml for your cluster.
kubectl apply -f recipes/nemotron-3-nano-omni/model-cache/model-cache.yaml -n ${NAMESPACE}

kubectl create secret generic hf-token-secret \
  --from-literal=HF_TOKEN=<your-hf-token> \
  -n ${NAMESPACE}

kubectl apply -f recipes/nemotron-3-nano-omni/model-cache/model-download.yaml -n ${NAMESPACE}
kubectl wait --for=condition=complete job/model-download -n ${NAMESPACE} --timeout=3600s
```

## Step 3: Deploy

Edit `vllm/agg/deploy.yaml` and replace all `<placeholder>` values:

- `<your-registry>/nemotron-omni-vllm:latest` - your built container image

If your registry is private, add the appropriate `imagePullSecrets` to the
deployment.

```bash
kubectl apply -f recipes/nemotron-3-nano-omni/vllm/agg/deploy.yaml -n ${NAMESPACE}
```

Monitor startup:

```bash
kubectl get pods -n ${NAMESPACE} -l nvidia.com/dynamo-graph-deployment-name=nemotron-omni-vllm-agg -w
```

## Step 4: Test

```bash
kubectl port-forward svc/nemotron-omni-vllm-agg-frontend 8000:8000 -n ${NAMESPACE}
```

In another terminal, send a minimal text request:

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 128
  }'
```

To exercise the multimodal path, attach an image:

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4",
    "messages": [{
      "role": "user",
      "content": [
        {"type": "image_url", "image_url": {"url": "https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/diffusers/inpaint.png"}},
        {"type": "text", "text": "Describe what is in this image."}
      ]
    }],
    "max_tokens": 256
  }'
```

…or an audio clip:

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4",
    "messages": [{
      "role": "user",
      "content": [
        {"type": "audio_url", "audio_url": {"url": "https://raw.githubusercontent.com/yuekaizhang/Triton-ASR-Client/main/datasets/mini_en/wav/1221-135766-0002.wav"}},
        {"type": "text", "text": "Transcribe this audio clip."}
      ]
    }],
    "max_tokens": 256
  }'
```

## Optional: Local Docker Smoke Test

For a local, single-GPU smoke test of a source-built image, run with file
discovery plus ZMQ events. This avoids Kubernetes, etcd, and NATS while still
exercising the Dynamo frontend-to-vLLM worker path.

The example below assumes:

- the current directory is the Dynamo repository root
- `<source-built-vllm020-image>` is a local image built from this repository on
  top of `vllm/vllm-openai:v0.20.0`
- `HF_TOKEN` is exported in the host shell
- `${HOME}/.cache/huggingface` contains, or can download, the model

Start a long-running container:

```bash
docker run -d --name dynamo-local-nemotron \
  --gpus all --network host --ipc=host --shm-size=64g --ulimit memlock=-1 \
  -e HF_TOKEN -e HF_HOME=/model-cache \
  -e DYN_EVENT_PLANE=zmq -e DYN_REQUEST_PLANE=tcp \
  -e DYN_FILE_KV=/workspace/tmp/dynamo_store_kv_nemotron \
  -e DYN_MEDIA_OUTPUT_FS_URL=file:///workspace/tmp/dynamo_media \
  -e DYN_MM_VIDEO_NUM_FRAMES=512 \
  -v "${HOME}/.cache/huggingface:/model-cache" \
  -v "${PWD}:/workspace" \
  --entrypoint bash <source-built-vllm020-image> \
  -lc 'mkdir -p /workspace/tmp/logs /workspace/tmp/dynamo_store_kv_nemotron /workspace/tmp/dynamo_media; sleep infinity'
```

Start the frontend:

```bash
docker exec dynamo-local-nemotron bash -lc \
  'cd /workspace &&
   unset NATS_SERVER &&
   python3 -m dynamo.frontend \
     --discovery-backend file \
     --router-mode kv \
     --no-router-kv-events \
     --http-port 8000 \
     > tmp/logs/nemotron-frontend.log 2>&1 &'
```

Start the vLLM worker:

```bash
docker exec dynamo-local-nemotron bash -lc \
  'cd /workspace &&
   unset NATS_SERVER &&
   CUDA_VISIBLE_DEVICES=0 python3 -m dynamo.vllm \
     --discovery-backend file \
     --model nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4 \
     --served-model-name nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4 \
     --max-model-len 131072 \
     --kv-cache-dtype fp8 \
     --enable-multimodal \
     --media-io-kwargs '\''{"video": {"num_frames": 512, "fps": 1}}'\'' \
     --allowed-local-media-path / \
     --trust-remote-code \
     --video-pruning-rate 0.5 \
     --dyn-tool-call-parser nemotron_nano \
     --dyn-reasoning-parser nemotron_nano \
     --enforce-eager \
     > tmp/logs/nemotron-vllm.log 2>&1 &'
```

Check readiness:

```bash
curl -fsS http://127.0.0.1:8000/v1/models
```

The model list should include
`nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4` with a `131072` token
context window. Then send a small completion request:

```bash
curl -fsS http://127.0.0.1:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4",
    "messages": [{"role": "user", "content": "Reply with exactly this word: READY"}],
    "max_tokens": 256,
    "temperature": 0
  }'
```

This validates local serving only. Run a separate benchmark before making
throughput claims for a given GPU.

## Key Configuration Notes

- `--enable-multimodal` enables image, video, and audio inputs.
- `--kv-cache-dtype fp8` is required for the NVFP4 quantized variant.
- `--media-io-kwargs '{"video": {"num_frames": 512, "fps": 1}}'` samples long
  videos at one frame per second, capped at 512 frames.
- `--dyn-tool-call-parser nemotron_nano` and
  `--dyn-reasoning-parser nemotron_nano` enable Nemotron Nano tool-call and
  reasoning parsing.
- The frontend uses `--router-mode kv --no-router-kv-events`, which approximates
  KV-aware routing with prefix hashing without requiring backend KV events.
- `--enforce-eager` is useful for local functional bring-up because it skips
  compile and CUDA graph capture. Remove it and benchmark separately before
  evaluating production throughput.

## Troubleshooting Notes

- The worker log should show `Detected ModelOpt NVFP4 checkpoint` and an NvFp4
  MoE backend such as `FLASHINFER_TRTLLM`. Those lines confirm the NVFP4 path is
  active.
- vLLM can log an `EngineCoreProc.get_kv_cache_group_metadata` error with some
  Dynamo/vLLM version combinations. If Dynamo immediately falls back to
  `vLLM cache_config.block_size`, registers the model, and `/v1/models` returns
  the target model, this message is not fatal.
- If the model loads but does not register for a long time during local source
  validation, retry with `--enforce-eager` to separate functional bring-up from
  compile/CUDA graph warmup.
- If a source-built native wheel is rejected with an unsupported `manylinux`
  tag, rebuild the wheel in a builder image that matches the runtime image's
  glibc baseline.

## Optional: Run without NATS

The Dynamo runtime defaults to NATS for the event plane and connects to a
NATS server if `NATS_SERVER` is set in the environment (the operator
auto-injects this on most clusters). On clusters without NATS — or where
you'd rather avoid the dependency — you can run on TCP request plane + ZMQ
event plane only. Add to both Frontend and VllmWorker:

```yaml
mainContainer:
  env:
    - name: DYN_EVENT_PLANE
      value: zmq
  command: ["/bin/bash", "-lc"]
  args:
    # Operator-injected NATS_SERVER takes effect even when set to ""; we have
    # to actually unset it before the runtime reads env.
    - >-
      unset NATS_SERVER &&
      exec python3 -m dynamo.frontend ...   # or dynamo.vllm
```

The request plane defaults to TCP already, so no further flags are needed.

## File Layout

```text
recipes/nemotron-3-nano-omni/
  README.md
  Dockerfile
  model-cache/
    model-cache.yaml
    model-download.yaml
  vllm/
    agg/
      deploy.yaml
```
