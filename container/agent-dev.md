# Agent Development Images

`container/build-agent-dev.sh` builds a self-contained image for coding agents.
It bakes a specific git SHA into `/workspace`, installs the development and test
toolchains, builds Dynamo from source, and leaves package managers in offline
mode so missing dependencies fail loudly at runtime.

Build one backend stack at a time:

```bash
container/build-agent-dev.sh --sha HEAD --framework vllm --cuda-version 13.0
container/build-agent-dev.sh --sha HEAD --framework sglang --cuda-version 13.0
container/build-agent-dev.sh --sha HEAD --framework trtllm --cuda-version 13.1
```

The default tag shape is:

```text
dynamo:agent-dev-<framework>-<device>-<short-sha>
```

For example:

```bash
docker run --rm -it --network none dynamo:agent-dev-vllm-cuda13-abc123def456
```

Use normal GPU flags when running GPU-backed tests:

```bash
docker run --rm -it --gpus all --network host --ipc host \
  dynamo:agent-dev-vllm-cuda13-abc123def456
```

## What It Contains

- A clean `/workspace` source snapshot for the requested git SHA.
- A one-commit local `.git` repository so agents can use `git status`, `git diff`,
  and local commits inside the container.
- Rust toolchain, Cargo, uv, maturin, pytest, pre-commit, mypy, pyright, and the
  backend framework stack inherited from the generated `local-dev` image.
- A source build of Dynamo via `cargo build`, `maturin develop`, and
  `uv pip install --no-deps -e /workspace`.
- Pre-installed pre-commit hook environments by default.
- `CARGO_NET_OFFLINE=true`, `UV_OFFLINE=true`, and `PIP_NO_INDEX=1` at runtime.

The build can use the network. The resulting image should not need network for
package installation or normal local validation. It does not pre-download model
weights or external datasets; tests that require those artifacts still need the
artifacts supplied by a cache, mount, or separate image layer.

## Why It Is Per Backend

vLLM, SGLang, and TensorRT-LLM carry separate upstream Python/CUDA dependency
stacks. Combining all three into one Python environment would make dependency
resolution fragile and would not match CI. Build one agent image per backend and
CUDA/device tuple instead.

## Useful Options

Use an existing local-dev base image:

```bash
container/build-agent-dev.sh \
  --base-image dynamo:latest-vllm-local-dev \
  --sha HEAD \
  --framework vllm
```

Skip expensive validation while iterating on the image definition:

```bash
container/build-agent-dev.sh \
  --sha HEAD \
  --framework vllm \
  --skip-precommit-install \
  --skip-sanity-check
```

Keep the project-local temporary context for inspection:

```bash
container/build-agent-dev.sh --sha HEAD --framework vllm --keep-context
```

Exercise source snapshot creation and Dockerfile rendering without building:

```bash
container/build-agent-dev.sh --sha HEAD --framework vllm --device cpu --prepare-only
```

Temporary build contexts live under `tmp/agent-dev-build/`.
