# Native MLX Plan

Sotto should be delivered as a single native macOS app. The normal development
path now uses MLX Swift in-process. The `mlx_lm.server` path remains only as a
debug fallback for comparing model behavior.

## Target Architecture

```text
Sotto.app
  ClipboardMonitor
  SelectionLocator
  TranslationPanelController
  NativeMLXTranslationEngine
    MLX Swift LM
    downloaded MLX model files
```

No user-managed Python process, terminal server, or separate local API should be
required in the product path.

## Toolchain Status

The local development machine has Xcode 15.2 for the macOS SDK and Swift 6.1.3
installed through `swiftly`.

Sotto uses `mlx-swift-lm` 3.31.4, `swift-huggingface` 0.9.0, and
`swift-transformers` 1.3.3. `mlx-swift-lm` 3.x uses `swift-tools-version: 6.1`,
so Sotto's package uses Swift tools 6.1. Older MLX Swift LM 0.x/1.x tags use
Swift 5.9, but they predate the current TranslateGemma/Gemma 3 path and are not
a good product foundation for Sotto.

The correct direction is to use the current MLX Swift LM package line rather
than building on an old API. A full Xcode upgrade is still useful for normal
Xcode project integration, signing, and distribution work.

`mlx-swift-lm` 3.31.4 and `swift-huggingface` 0.9.0 currently need small Swift
6.1 concurrency patches on this toolchain. `scripts/patch-mlx-swift-lm.sh`
applies those patches to SwiftPM checkouts under `.build/checkouts`. This is a
temporary dependency workaround, not product code.

## Migration Steps

1. Add `mlx-swift-lm` as a Swift Package dependency. Done.
2. Implement `NativeMLXTranslationEngine` behind the existing
   `TranslationEngine` protocol. Done.
3. Reuse the TranslateGemma marker prompt format. Done:

   ```text
   <<<source>>>en<<<target>>>ja-JP<<<text>>>...
   ```

4. Add model download progress, location, and error handling.
5. Keep `LocalServerTranslationEngine` as a debug fallback until native quality
   and latency are understood.
6. Remove the SwiftPM checkout patch once upstream dependency releases include
   Swift 6.1 fixes.

## Packaging Expectations

The product should eventually provide:

- a signed `.app`
- first-run model setup and progress inside the app
- no terminal command requirement
- clear local-only data behavior
- an optional debug mode for external server experiments
