#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FRAMEWORK="vllm"
DEVICE="cuda"
CUDA_VERSION="13.0"
CUDA_VERSION_SET=false
PLATFORM="linux/amd64"
SOURCE_REF="HEAD"
TAG=""
BASE_IMAGE=""
BASE_TAG=""
BUILD_BASE=true
PREPARE_ONLY=false
NO_CACHE=false
KEEP_CONTEXT=false
USER_UID="1000"
USER_GID="1000"
RUN_PRECOMMIT_INSTALL=true
RUN_SANITY_CHECK=true
INSTALL_GPU_MEMORY_SERVICE=true
INSTALL_KVBM=false
EXTRA_FINAL_BUILD_ARGS=()
EXTRA_BASE_BUILD_ARGS=()

usage() {
    cat <<'EOF'
Build a self-contained Dynamo coding-agent development image for a git SHA.

Usage:
  container/build-agent-dev.sh [options]

Options:
  --sha REF                         Git ref/SHA to bake into /workspace (default: HEAD)
  --framework vllm|sglang|trtllm|dynamo
                                    Backend stack to inherit (default: vllm)
  --device cuda|cpu|xpu             Device variant for render.py (default: cuda)
  --cuda-version VERSION            CUDA version for cuda builds (default: 13.0)
  --platform PLATFORM               Single Docker platform (default: linux/amd64)
  --tag IMAGE                       Final agent-dev image tag
  --base-tag IMAGE                  Tag for the intermediate local-dev base image
  --base-image IMAGE                Use an existing local-dev base image instead of building one
  --no-build-base                   Same as --base-image/--base-tag: skip local-dev base build
  --prepare-only                    Create the SHA context and render Dockerfiles, then stop
  --user-uid UID                    UID for the dynamo user in the base local-dev image (default: 1000)
  --user-gid GID                    GID for the dynamo user in the base local-dev image (default: 1000)
  --no-cache                        Disable Docker layer cache for both builds
  --keep-context                    Keep tmp/agent-dev-build/<sha>-... for inspection
  --skip-precommit-install          Do not pre-install pre-commit hook environments
  --skip-sanity-check               Do not run dev/sanity_check.py while building
  --skip-gpu-memory-service         Do not editable-install lib/gpu_memory_service
  --install-kvbm                    Editable-install lib/bindings/kvbm
  --base-build-arg KEY=VALUE        Extra build arg for the local-dev base build
  --final-build-arg KEY=VALUE       Extra build arg for the agent finalizer build
  -h, --help                        Show this help

Examples:
  container/build-agent-dev.sh --sha HEAD --framework vllm --cuda-version 13.0
  container/build-agent-dev.sh --sha abc123 --framework sglang --tag dynamo:agent-dev-sglang-abc123
  container/build-agent-dev.sh --base-image dynamo:latest-vllm-local-dev --sha HEAD

The build uses network during image creation to install/cache dependencies.
The resulting image sets CARGO_NET_OFFLINE=true, UV_OFFLINE=true, and
PIP_NO_INDEX=1 so package-manager gaps fail at runtime instead of reaching out.
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sha)
            SOURCE_REF="${2:?missing value for --sha}"
            shift 2
            ;;
        --framework)
            FRAMEWORK="${2:?missing value for --framework}"
            shift 2
            ;;
        --device)
            DEVICE="${2:?missing value for --device}"
            shift 2
            ;;
        --cuda-version)
            CUDA_VERSION="${2:?missing value for --cuda-version}"
            CUDA_VERSION_SET=true
            shift 2
            ;;
        --platform)
            PLATFORM="${2:?missing value for --platform}"
            shift 2
            ;;
        --tag)
            TAG="${2:?missing value for --tag}"
            shift 2
            ;;
        --base-tag)
            BASE_TAG="${2:?missing value for --base-tag}"
            shift 2
            ;;
        --base-image)
            BASE_IMAGE="${2:?missing value for --base-image}"
            BUILD_BASE=false
            shift 2
            ;;
        --no-build-base)
            BUILD_BASE=false
            shift
            ;;
        --prepare-only)
            PREPARE_ONLY=true
            KEEP_CONTEXT=true
            shift
            ;;
        --user-uid)
            USER_UID="${2:?missing value for --user-uid}"
            shift 2
            ;;
        --user-gid)
            USER_GID="${2:?missing value for --user-gid}"
            shift 2
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --keep-context)
            KEEP_CONTEXT=true
            shift
            ;;
        --skip-precommit-install)
            RUN_PRECOMMIT_INSTALL=false
            shift
            ;;
        --skip-sanity-check)
            RUN_SANITY_CHECK=false
            shift
            ;;
        --skip-gpu-memory-service)
            INSTALL_GPU_MEMORY_SERVICE=false
            shift
            ;;
        --install-kvbm)
            INSTALL_KVBM=true
            shift
            ;;
        --base-build-arg)
            EXTRA_BASE_BUILD_ARGS+=(--build-arg "${2:?missing value for --base-build-arg}")
            shift 2
            ;;
        --final-build-arg)
            EXTRA_FINAL_BUILD_ARGS+=(--build-arg "${2:?missing value for --final-build-arg}")
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1"
            ;;
    esac
done

case "${FRAMEWORK}" in
    vllm|sglang|trtllm|dynamo) ;;
    *) die "--framework must be one of: vllm, sglang, trtllm, dynamo" ;;
esac

case "${DEVICE}" in
    cuda|cpu|xpu) ;;
    *) die "--device must be one of: cuda, cpu, xpu" ;;
esac

if [[ "${FRAMEWORK}" == "trtllm" && "${DEVICE}" == "cuda" && "${CUDA_VERSION_SET}" == "false" ]]; then
    CUDA_VERSION="13.1"
fi

[[ "${PLATFORM}" != *,* ]] || die "--platform must be a single platform for local agent images"

command -v docker >/dev/null || die "docker is required"
command -v git >/dev/null || die "git is required"
command -v python3 >/dev/null || die "python3 is required"

RENDER_PYTHON=(python3)
if ! python3 - <<'PY' >/dev/null 2>&1
import jinja2  # noqa: F401
import yaml  # noqa: F401
PY
then
    if command -v uv >/dev/null; then
        RENDER_PYTHON=(uv run --no-project --with pyyaml --with jinja2 python)
    else
        die "python3 must have pyyaml and jinja2 installed, or uv must be available to run render.py"
    fi
fi

RESOLVED_SHA="$(git -C "${REPO_ROOT}" rev-parse "${SOURCE_REF}^{commit}")"
SHORT_SHA="$(git -C "${REPO_ROOT}" rev-parse --short=12 "${RESOLVED_SHA}")"

if [[ "${DEVICE}" == "cuda" ]]; then
    DEVICE_SUFFIX="cuda${CUDA_VERSION%%.*}"
else
    DEVICE_SUFFIX="${DEVICE}"
fi

if [[ -z "${TAG}" ]]; then
    TAG="dynamo:agent-dev-${FRAMEWORK}-${DEVICE_SUFFIX}-${SHORT_SHA}"
fi

if [[ -z "${BASE_TAG}" ]]; then
    BASE_TAG="dynamo:agent-dev-base-${FRAMEWORK}-${DEVICE_SUFFIX}-${SHORT_SHA}"
fi

if [[ -z "${BASE_IMAGE}" ]]; then
    BASE_IMAGE="${BASE_TAG}"
fi

BUILD_ROOT="${REPO_ROOT}/tmp/agent-dev-build/${SHORT_SHA}-${FRAMEWORK}-${DEVICE_SUFFIX}"
SOURCE_DIR="${BUILD_ROOT}/repo"

rm -rf "${BUILD_ROOT}"
mkdir -p "${SOURCE_DIR}"

echo "Creating source context for ${RESOLVED_SHA}"
git -C "${REPO_ROOT}" archive --format=tar "${RESOLVED_SHA}" | tar -x -C "${SOURCE_DIR}"

(
    cd "${SOURCE_DIR}"
    git init -q
    git config user.name "Dynamo Agent Dev Image"
    git config user.email "dynamo-agent-dev@example.invalid"
    git add -A
    git commit -q -m "agent-dev source snapshot ${SHORT_SHA}"
)

NO_CACHE_ARG=()
if [[ "${NO_CACHE}" == "true" ]]; then
    NO_CACHE_ARG=(--no-cache)
fi

if [[ "${BUILD_BASE}" == "true" ]]; then
    echo "Rendering ${FRAMEWORK} local-dev Dockerfile"
    RENDER_ARGS=(
        --framework="${FRAMEWORK}"
        --device="${DEVICE}"
        --target=local-dev
        --platform="${PLATFORM}"
        --output-short-filename
    )
    if [[ "${DEVICE}" == "cuda" ]]; then
        RENDER_ARGS+=(--cuda-version="${CUDA_VERSION}")
    fi
    (cd "${SOURCE_DIR}" && "${RENDER_PYTHON[@]}" container/render.py "${RENDER_ARGS[@]}")

    if [[ "${PREPARE_ONLY}" == "true" ]]; then
        cat <<EOF

Prepared agent-dev build context:
  ${BUILD_ROOT}

Rendered base Dockerfile:
  ${SOURCE_DIR}/container/rendered.Dockerfile

Final image tag would be:
  ${TAG}
EOF
        exit 0
    fi

    echo "Building local-dev base image: ${BASE_TAG}"
    docker build \
        --platform "${PLATFORM}" \
        "${NO_CACHE_ARG[@]}" \
        --build-arg USER_UID="${USER_UID}" \
        --build-arg USER_GID="${USER_GID}" \
        --build-arg DYNAMO_COMMIT_SHA="${RESOLVED_SHA}" \
        "${EXTRA_BASE_BUILD_ARGS[@]}" \
        -t "${BASE_TAG}" \
        -f "${SOURCE_DIR}/container/rendered.Dockerfile" \
        "${SOURCE_DIR}"
else
    echo "Skipping local-dev base build; using base image: ${BASE_IMAGE}"
    if [[ "${PREPARE_ONLY}" == "true" ]]; then
        cat <<EOF

Prepared agent-dev build context:
  ${BUILD_ROOT}

Final image tag would be:
  ${TAG}
EOF
        exit 0
    fi
fi

echo "Building final agent-dev image: ${TAG}"
docker build \
    --platform "${PLATFORM}" \
    "${NO_CACHE_ARG[@]}" \
    --build-arg BASE_IMAGE="${BASE_IMAGE}" \
    --build-arg DYNAMO_COMMIT_SHA="${RESOLVED_SHA}" \
    --build-arg RUN_PRECOMMIT_INSTALL="${RUN_PRECOMMIT_INSTALL}" \
    --build-arg RUN_SANITY_CHECK="${RUN_SANITY_CHECK}" \
    --build-arg INSTALL_GPU_MEMORY_SERVICE="${INSTALL_GPU_MEMORY_SERVICE}" \
    --build-arg INSTALL_KVBM="${INSTALL_KVBM}" \
    "${EXTRA_FINAL_BUILD_ARGS[@]}" \
    -t "${TAG}" \
    -f "${SCRIPT_DIR}/Dockerfile.agent-dev" \
    "${BUILD_ROOT}"

if [[ "${KEEP_CONTEXT}" == "true" ]]; then
    echo "Kept build context: ${BUILD_ROOT}"
else
    rm -rf "${BUILD_ROOT}"
fi

cat <<EOF

Built agent-dev image:
  ${TAG}

Source SHA:
  ${RESOLVED_SHA}

Try it:
  docker run --rm -it --network none ${TAG}

For GPU-backed checks, add your normal GPU/runtime flags, for example:
  docker run --rm -it --gpus all --network host --ipc host ${TAG}
EOF
