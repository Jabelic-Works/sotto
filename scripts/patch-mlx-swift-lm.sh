#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECKOUT_DIR="$REPO_ROOT/.build/checkouts/mlx-swift-lm"
HUGGINGFACE_CHECKOUT_DIR="$REPO_ROOT/.build/checkouts/swift-huggingface"

if [[ ! -d "$CHECKOUT_DIR" || ! -d "$HUGGINGFACE_CHECKOUT_DIR" ]]; then
  swift package --package-path "$REPO_ROOT" resolve
fi

PARO_QUANT_LOADER="$CHECKOUT_DIR/Libraries/MLXLMCommon/ParoQuant/ParoQuantLoader.swift"
USER_INPUT="$CHECKOUT_DIR/Libraries/MLXLMCommon/UserInput.swift"
HUGGINGFACE_AUTH_MANAGER="$HUGGINGFACE_CHECKOUT_DIR/Sources/HuggingFace/OAuth/HuggingFaceAuthenticationManager.swift"

if [[ ! -f "$PARO_QUANT_LOADER" || ! -f "$USER_INPUT" || ! -f "$HUGGINGFACE_AUTH_MANAGER" ]]; then
  echo "Required Swift package checkout was not found. Run swift package resolve and retry." >&2
  exit 1
fi

chmod u+w "$PARO_QUANT_LOADER" "$USER_INPUT" "$HUGGINGFACE_AUTH_MANAGER"

python3 - "$PARO_QUANT_LOADER" "$USER_INPUT" "$HUGGINGFACE_AUTH_MANAGER" <<'PY'
from pathlib import Path
import sys

paro_quant_loader = Path(sys.argv[1])
user_input = Path(sys.argv[2])
huggingface_auth_manager = Path(sys.argv[3])

source = paro_quant_loader.read_text()
source = source.replace(
    'private let logger = Logger(subsystem: "mlx-swift-lm", category: "paroquant")',
    'private func paroQuantLogger() -> Logger { Logger(subsystem: "mlx-swift-lm", category: "paroquant") }',
)
source = source.replace("logger.info(", "paroQuantLogger().info(")
paro_quant_loader.write_text(source)

source = user_input.read_text()
source = source.replace(
    "format: .RGBA8, colorSpace: cs)",
    "format: CIFormat(rawValue: 264), colorSpace: cs)",
)
user_input.write_text(source)

source = huggingface_auth_manager.read_text()
source = source.replace(
    "ASWebAuthenticationPresentationContextProviding\n    {",
    "@preconcurrency ASWebAuthenticationPresentationContextProviding\n    {",
)
while "@preconcurrency @preconcurrency" in source:
    source = source.replace("@preconcurrency @preconcurrency", "@preconcurrency")
huggingface_auth_manager.write_text(source)
PY

echo "Patched Swift package checkouts for Swift 6.1 concurrency compatibility."
