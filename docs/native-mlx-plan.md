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

## Toolchain Status

The local development machine has Xcode 15.2 for the macOS SDK and Swift 6.1.3
installed through `swiftly`.

Current MLX Swift LM 3.x uses `swift-tools-version: 6.1`, so Sotto's package has
been moved to Swift tools 6.1. Older MLX Swift LM 0.x/1.x tags use Swift 5.9,
but they predate the current TranslateGemma/Gemma 3 path and are not a good
product foundation for Sotto.

The correct direction is to use the current MLX Swift LM package line rather
than building on an old API. A full Xcode upgrade is still useful for normal
Xcode project integration, signing, and distribution work.

## Migration Steps

1. Add `mlx-swift-lm` as a Swift Package dependency.
2. Implement `NativeTranslateGemmaEngine` behind the existing
   `TranslationEngine` protocol.
3. Reuse the TranslateGemma marker prompt format:

   ```text
   <<<source>>>en<<<target>>>ja-JP<<<text>>>...
   ```

4. Add model location and download management.
5. Keep `LocalServerTranslationEngine` as a debug fallback until native parity is
   reached.
6. Remove the local HTTP server path from the normal app flow before public
   distribution.

## Packaging Expectations

The product should eventually provide:

- a signed `.app`
- first-run model setup inside the app
- no terminal command requirement
- clear local-only data behavior
- an optional debug mode for external server experiments
