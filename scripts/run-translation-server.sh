#!/usr/bin/env bash
set -euo pipefail

MODEL_ID="${MODEL_ID:-mlx-community/translategemma-4b-it-4bit_immersive-translate}"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8000}"

if ! command -v mlx_lm.server >/dev/null 2>&1; then
  echo "mlx_lm.server was not found." >&2
  echo "Install MLX LM first:" >&2
  echo "  uv tool install mlx-lm" >&2
  exit 127
fi

exec mlx_lm.server --model "$MODEL_ID" --host "$HOST" --port "$PORT"
