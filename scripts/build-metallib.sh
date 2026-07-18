#!/usr/bin/env bash
set -euo pipefail

# Build the MLX Metal shader library (`mlx.metallib`) for the mlx-swift `Cmlx`
# target and place it next to the built Sotto executable.
#
# Why this exists: SwiftPM on the command line (`swift build` / `swift run`)
# cannot compile Metal shaders, so it never produces the `default.metallib`
# that MLX loads at first GPU use. Without it the app aborts at launch with
# "Failed to load the default metallib". Xcode can compile the shaders, but the
# installed Xcode (15.2 / Swift 5.9) cannot parse this package's Swift 6.1
# manifest. This script compiles the shaders directly with `xcrun metal`,
# following mlx-swift's own CMake recipe, so the native path works under
# `swift build`.
#
# mlx-swift is built in Metal JIT mode here, so only the always-compiled
# kernels are needed in the metallib; the rest are compiled at runtime.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIGURATION="${CONFIGURATION:-debug}"
DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-14.0}"

METAL_SRC_DIR="$REPO_ROOT/.build/checkouts/mlx-swift/Source/Cmlx/mlx-generated/metal"
if [[ ! -d "$METAL_SRC_DIR" ]]; then
  echo "mlx-swift metal sources not found. Run 'swift package resolve' first." >&2
  exit 1
fi

# Resolve the build directory that holds the executable (triple-specific).
BIN_DIR="$(swift build --configuration "$CONFIGURATION" --show-bin-path)"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

FLAGS=(
  -x metal
  -Wall -Wextra -fno-fast-math
  -Wno-c++17-extensions -Wno-c++20-extensions
  "-mmacosx-version-min=$DEPLOYMENT_TARGET"
)

# Always-compiled kernels (mlx-swift CMake `build_kernel(...)` outside the
# `NOT MLX_METAL_JIT` block).
KERNELS=(
  arg_reduce
  conv
  gemv
  layer_norm
  random
  rms_norm
  rope
  scaled_dot_product_attention
  steel/attn/kernels/steel_attention
)

echo "Compiling ${#KERNELS[@]} Metal kernels..."
for kernel in "${KERNELS[@]}"; do
  base="$(basename "$kernel")"
  xcrun -sdk macosx metal "${FLAGS[@]}" \
    -c "$METAL_SRC_DIR/$kernel.metal" \
    -I"$METAL_SRC_DIR" \
    -o "$WORK_DIR/$base.air"
done

echo "Linking mlx.metallib..."
xcrun -sdk macosx metallib "$WORK_DIR"/*.air -o "$WORK_DIR/mlx.metallib"

# MLX searches for `mlx.metallib` colocated with the executable first.
mkdir -p "$BIN_DIR"
cp "$WORK_DIR/mlx.metallib" "$BIN_DIR/mlx.metallib"

echo "Installed: $BIN_DIR/mlx.metallib"
