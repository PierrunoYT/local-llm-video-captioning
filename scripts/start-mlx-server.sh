#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
WARMUP_IMAGE_DATA_URL="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO9d7ysAAAAASUVORK5CYII="

if ! command -v uv >/dev/null 2>&1; then
  echo "Missing uv in PATH"
  echo "Install uv first: curl -LsSf https://astral.sh/uv/install.sh | sh"
  exit 1
fi

if [[ ! -f "${ROOT_DIR}/pyproject.toml" ]]; then
  echo "Missing pyproject.toml at ${ROOT_DIR}"
  exit 1
fi

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  source "${ENV_FILE}"
  set +a
fi

MLX_SERVER_PORT="${MLX_VLM_PORT:-}"
if [[ -z "${MLX_SERVER_PORT}" && -n "${MLX_VLM_BASE_URL:-}" ]]; then
  MLX_SERVER_PORT="${MLX_VLM_BASE_URL##*:}"
fi
MLX_SERVER_PORT="${MLX_SERVER_PORT:-8081}"
MLX_SERVER_BASE_URL="${MLX_VLM_BASE_URL:-http://127.0.0.1:${MLX_SERVER_PORT}}"
MLX_MODEL_ID="${MLX_MODEL_ID:-mlx-community/Qwen3.5-0.8B-MLX-8bit}"
MLX_WARMUP_TIMEOUT_SECONDS="${MLX_WARMUP_TIMEOUT_SECONDS:-900}"
MLX_WARMUP_MAX_TOKENS="${MLX_WARMUP_MAX_TOKENS:-12}"

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "${SERVER_PID}" 2>/dev/null; then
    kill "${SERVER_PID}" 2>/dev/null || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi
}

trap cleanup INT TERM EXIT

uv run -m mlx_vlm.server \
  --port "${MLX_SERVER_PORT}" &

SERVER_PID=$!

echo "Waiting for mlx_vlm.server on ${MLX_SERVER_BASE_URL}..."

for _ in {1..120}; do
  if curl --silent --fail "${MLX_SERVER_BASE_URL}/health" >/dev/null; then
    break
  fi

  if ! kill -0 "${SERVER_PID}" 2>/dev/null; then
    wait "${SERVER_PID}"
    exit $?
  fi

  sleep 1
done

if ! curl --silent --fail "${MLX_SERVER_BASE_URL}/health" >/dev/null; then
  echo "Timed out waiting for mlx_vlm.server to become healthy."
  exit 1
fi

echo "Warming up model ${MLX_MODEL_ID}..."

if curl \
  --silent \
  --show-error \
  --fail \
  --max-time "${MLX_WARMUP_TIMEOUT_SECONDS}" \
  --header "Content-Type: application/json" \
  --request POST \
  --url "${MLX_SERVER_BASE_URL}/v1/chat/completions" \
  --data @- >/dev/null <<EOF
{
  "model": "${MLX_MODEL_ID}",
  "stream": false,
  "temperature": 0,
  "max_tokens": ${MLX_WARMUP_MAX_TOKENS},
  "messages": [
    {
      "role": "system",
      "content": "You are warming up the model."
    },
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "Reply with the single word ready."
        },
        {
          "type": "image_url",
          "image_url": {
            "url": "${WARMUP_IMAGE_DATA_URL}"
          }
        }
      ]
    }
  ]
}
EOF
then
  echo "Warm-up complete."
else
  echo "Warm-up request failed. The server is still running, but the first live request may be slow." >&2
fi

wait "${SERVER_PID}"
