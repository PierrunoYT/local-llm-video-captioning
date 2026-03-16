# Local LLM Video Captioning Demo

This project is a local demo for frame-by-frame video captioning with:

- a React + Tailwind UI
- a small Express proxy for streaming responses
- a local `mlx_vlm.server` backend for vision inference

## Platform Requirement

This example targets MLX and requires an Apple Silicon Mac to run the Python backend.

The browser UI and Node API are standard JavaScript, but the inference path depends on `mlx-vlm`, so this repository should be treated as Apple Silicon only.

## Why `mlx-vlm` instead of `mlx-lm`

The app sends video frame images to the model. That requires the MLX vision stack, not the text-only `mlx-lm` package.

## 1. Install JavaScript dependencies

```bash
npm install
```

## 2. Sync the Python environment with `uv`

```bash
uv sync --python 3.11
```

The Python dependency is now tracked in `pyproject.toml` and locked with `uv`. `mlx-vlm` currently requires Python `>= 3.10`. The `torch` extra is included because the Qwen 3.5 processor stack also needs `torch` and `torchvision`. If you do not already have `uv`, install it first:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

If you change the Python dependencies later, use `uv add ...` and commit the updated `uv.lock`.

## 3. Configure environment variables

```bash
cp .env.example .env
```

Defaults:

- `API_PORT=8787`
- `MLX_VLM_BASE_URL=http://127.0.0.1:8081`
- `MLX_MODEL_ID=mlx-community/Qwen3.5-0.8B-MLX-8bit`
- `MLX_MAX_TOKENS=180`

## 4. Start the MLX backend

```bash
./scripts/start-mlx-server.sh
```

Or run the server manually:

```bash
uv run -m mlx_vlm.server --port 8081
```

The helper script waits for `mlx_vlm.server` to become healthy and then sends a small warm-up request so the first real video frame does not fall behind while the model loads. The Node API also treats the backend as "ready" only after that warm-up completes. If you run the Python command manually, you will skip that startup warm-up step.

The model is selected by the Node API via `MLX_MODEL_ID`. On the first request, `mlx_vlm.server` may still need to download model files from Hugging Face, so the first startup on a fresh machine can take noticeably longer.

## 5. Start the app

In one terminal:

```bash
npm run api
```

In another terminal:

```bash
npm run dev
```

Or start both together:

```bash
npm run dev:all
```

## Usage

1. Open the app in the browser.
2. Click `Select Video` and choose a local video file.
3. Press play.
4. The app captures frames from the video and sends them to `/api/describe/stream`.
5. The transcript panel updates as tokens stream back from the MLX backend.

## Environment Variables

- `API_PORT`: port for the local proxy API
- `MLX_VLM_BASE_URL`: URL for the running `mlx_vlm.server`
- `MLX_MODEL_ID`: model name sent to the MLX server
- `MLX_MAX_TOKENS`: per-frame response cap
- `MLX_WARMUP_TIMEOUT_SECONDS`: optional timeout for the startup warm-up request
- `MLX_WARMUP_MAX_TOKENS`: optional token cap for the startup warm-up request
- `MLX_WARMUP_TIMEOUT_MS`: optional timeout for API-side readiness warm-up checks

## License

MIT. See [LICENSE](./LICENSE).
