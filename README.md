# Local LLM Video Captioning Demo

![Preview](./preview.jpg)

This project is a local demo for frame-by-frame video captioning with:

- a React + Tailwind UI
- a small Express proxy for streaming responses
- a local [Ollama](https://ollama.com) backend for vision inference

## Prerequisites

- [Node.js](https://nodejs.org) >= 18
- [Ollama](https://ollama.com/download/windows) installed and in PATH

## 1. Install JavaScript dependencies

```powershell
npm install
```

## 2. Configure environment variables

```powershell
copy .env.example .env
```

Defaults:

- `API_PORT=8787`
- `OLLAMA_BASE_URL=http://127.0.0.1:11434`
- `OLLAMA_MODEL=qwen3.5:0.8b`
- `MAX_TOKENS=180`

## 3. Start the Ollama backend

```powershell
.\scripts\start-ollama-server.ps1
```

This script starts `ollama serve`, pulls the model if it is not already present locally, and sends a warm-up request so the first video frame is not delayed.

To use a different model, set `OLLAMA_MODEL` in `.env` to any Ollama vision model (e.g. `qwen3.5:2b`, `qwen2.5vl:7b`).

## 4. Start the app

In one terminal:

```powershell
npm run api
```

In another terminal:

```powershell
npm run dev
```

Or start both together:

```powershell
npm run dev:all
```

## Usage

1. Open the app in the browser.
2. Click `Select Video` and choose a local video file.
3. Press play.
4. The app captures frames from the video and sends them to `/api/describe/stream`.
5. The transcript panel updates as tokens stream back from the Ollama backend.

## Environment Variables

- `API_PORT`: port for the local proxy API
- `OLLAMA_BASE_URL`: base URL for the running Ollama server
- `OLLAMA_MODEL`: vision model name passed to Ollama
- `MAX_TOKENS`: per-frame response cap
- `WARMUP_TIMEOUT_SECONDS`: optional timeout for the startup warm-up request
- `WARMUP_MAX_TOKENS`: optional token cap for the startup warm-up request
- `WARMUP_TIMEOUT_MS`: optional timeout for API-side readiness warm-up checks

## License

MIT. See [LICENSE](./LICENSE).
