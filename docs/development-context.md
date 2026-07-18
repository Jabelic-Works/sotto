# Development Context

This document records the product and technical context behind Sotto so future
work can continue from the same assumptions.

## Product Direction

Sotto is a local-first macOS translation utility. The target interaction is:

1. Select text in any macOS app.
2. Press Command+C twice.
3. Show a lightweight translation popup near the selected text.

The product should feel closer to a quiet reading aid than a full translation
workspace. The important behavior is low interruption: no manual app switching,
no large window, and no cloud dependency for routine translation.

The competitive frame is desktop translation tools such as DeepL and nani, but
with a stronger focus on local execution and inline reading flow.

## Current Scope

The initial prototype intentionally focuses on the shell of the user experience:

- menu bar app lifecycle
- double-copy trigger using the system pasteboard
- selected-text bounds through the macOS Accessibility API
- popup placement near the selected text, with mouse-position fallback
- replaceable translation engine boundary

The translation engine now uses MLX Swift in-process through
`NativeMLXTranslationEngine`. A local OpenAI-compatible HTTP server path remains
available in `LocalServerTranslationEngine` as a debug fallback for comparing
latency and TranslateGemma behavior.

## Model Direction

TranslateGemma is the leading candidate for the local translation model. The
current native path uses
`mlx-community/translategemma-4b-it-4bit_immersive-translate` through MLX Swift
LM. See [Native MLX Plan](native-mlx-plan.md) for the single-app runtime
direction and temporary dependency patch details.

Whisper and speech recognition are out of scope for now. Earlier ideas included
Whisper Large v3 Turbo or other Whisper-family models, but the product direction
has been narrowed to text translation first.

## Platform And Runtime

Sotto is a native macOS app, not an iOS app. It should be tested on the Mac
directly. No iOS Simulator or emulator is required.

The current Swift Package prototype can run directly with:

```sh
swift run Sotto
```

For more practical user testing, the repository also includes a lightweight
`.app` bundling script:

```sh
scripts/build-app.sh
open .build/Sotto.app
```

Accessibility permission is easier to reason about with a stable app identity
than with repeated `swift run` executions. A first-class Xcode macOS app target
is still a useful follow-up once the prototype needs signing, entitlements,
assets, and release packaging.

## Technical Choices

- Swift, SwiftUI, and AppKit for a native macOS menu bar app.
- `NSPasteboard` polling for double-copy detection in the prototype.
- `AXUIElement` Accessibility APIs for selected-text bounds.
- `NSPanel` for a lightweight non-activating floating popup.
- A small `TranslationEngine` protocol so model integration can be swapped in
  without changing trigger and UI behavior.

## Translation Direction and Model Format

The double-copy trigger carries no explicit direction, so `TranslationRoute`
infers it from the selection: Japanese text translates to English, other text
translates to Japanese. The caller passes a preferred target language (the
reader's own language); when the selection is already in that language the
direction is flipped so the model performs a real translation instead of
paraphrasing back into the same language. This is shared by both the native and
the local-server engines.

Model format constraint (verified against the Hugging Face model cards and chat
templates):

- `mlx-community/translategemma-4b-it-4bit_immersive-translate` ships a custom
  `chat_template.jinja` that parses the `<<<source>>><<<target>>><<<text>>>`
  marker string and expands it into TranslateGemma's "professional translator"
  instruction. This lets the language codes ride inside a plain **string**
  message, which is what both the in-process `ChatSession.respond(to: String)`
  path and the OpenAI-style `mlx_lm.server` path send.
- The higher-precision variants (`translategemma-4b-it-8bit`, `12b`, `27b`) use
  the standard TranslateGemma template, which **requires** structured content —
  a one-item list with `source_lang_code` / `target_lang_code` / `text` — and
  raises on a plain string. Moving to these for better fidelity is therefore not
  a drop-in model swap; it needs structured-content messages end to end.
- `swift-transformers` loads the standalone `chat_template.jinja` (via
  `LanguageModelConfigurationFromHub`) and `swift-jinja` supports the template's
  `split` / `replace` / `trim`, so the marker template is applied correctly on
  the native path.

## Native MLX Metal Library

MLX loads a compiled Metal shader library (`mlx.metallib`) the first time it
touches the GPU — model preparation on launch is enough to trigger it. Without
it the process aborts with `Failed to load the default metallib`, which in
practice means the menu bar app dies at launch and the double-copy trigger never
fires.

Root cause of the missing library:

- SwiftPM on the command line (`swift build` / `swift run`) **cannot compile
  Metal shaders**, so it never produces the metallib. This is documented in
  mlx-swift's own README ("SwiftPM (command line) cannot build the Metal shaders
  so the ultimate build has to be done via Xcode").
- `xcodebuild` can compile the shaders, but the installed Xcode is 15.2 (SwiftPM
  5.9), which cannot parse this package's `swift-tools-version: 6.1` manifest, so
  it cannot build the package either.

Resolution: `scripts/build-metallib.sh` compiles the shaders directly with
`xcrun metal` / `xcrun metallib`, following mlx-swift's CMake recipe, and places
`mlx.metallib` next to the built executable (MLX's first search location).
mlx-swift is built in Metal JIT mode here, so only the always-compiled kernels
(`arg_reduce`, `conv`, `gemv`, `layer_norm`, `random`, `rms_norm`, `rope`,
`scaled_dot_product_attention`, `steel/attn/kernels/steel_attention`) go into the
metallib; the remaining kernels are compiled at runtime. `scripts/build-app.sh`
runs this step and copies the metallib into `Sotto.app/Contents/MacOS`.

Upgrading to an Xcode with a Swift 6.1 SwiftPM would let `xcodebuild` build the
metallib the standard way and make this script unnecessary.

## Near-Term Milestones

1. Improve first-run Accessibility permission guidance.
2. Add detailed first-run model download progress and error states.
3. Evaluate native TranslateGemma latency, memory use, and output quality on
   Apple Silicon.
4. Add a first-class Xcode macOS app target when signing and release packaging
   become necessary.
5. Add model download/location settings.
6. Replace the temporary SwiftPM checkout patch with upstream dependency
   versions once available.
7. Metal library packaging is handled by `scripts/build-metallib.sh` (see
   "Native MLX Metal Library" below). Revisit if the mlx-swift version, its
   kernel set, or the Metal JIT mode changes, since the compiled kernel list is
   pinned in that script.
