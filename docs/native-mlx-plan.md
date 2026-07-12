# Native MLX Plan

Sotto should be delivered as a single native macOS app. The current
`mlx_lm.server` path is a development fallback for validating interaction,
latency, and TranslateGemma behavior while the native runtime is built.

## Target Architecture

```text
Sotto.app
  ClipboardMonitor
  SelectionLocator
  TranslationPanelController
  NativeTranslateGemmaEngine
    MLX Swift LM
    bundled/downloaded MLX model files
```

No user-managed Python process, terminal server, or separate local API should be
required in the product path.

## Current Constraint

The local development machine currently has Xcode 15.2 / Swift 5.9.2.

Current MLX Swift LM 3.x uses `swift-tools-version: 6.1`, so it cannot be added
to this package with the current toolchain. Older MLX Swift LM 0.x/1.x tags use
Swift 5.9, but they predate the current TranslateGemma/Gemma 3 path and are not
a good product foundation for Sotto.

The correct direction is to move Sotto to a newer Xcode/Swift toolchain and use
the current MLX Swift LM package line rather than building on an old API.

## Migration Steps

1. Upgrade the development toolchain to Xcode 16+ / Swift 6.1+.
2. Add `mlx-swift-lm` as a Swift Package dependency.
3. Implement `NativeTranslateGemmaEngine` behind the existing
   `TranslationEngine` protocol.
4. Reuse the TranslateGemma marker prompt format:

   ```text
   <<<source>>>en<<<target>>>ja-JP<<<text>>>...
   ```

5. Add model location and download management.
6. Keep `LocalServerTranslationEngine` as a debug fallback until native parity is
   reached.
7. Remove the local HTTP server path from the normal app flow before public
   distribution.

## Packaging Expectations

The product should eventually provide:

- a signed `.app`
- first-run model setup inside the app
- no terminal command requirement
- clear local-only data behavior
- an optional debug mode for external server experiments
