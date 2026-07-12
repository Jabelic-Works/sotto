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

The translation engine currently calls a local OpenAI-compatible HTTP server at
`http://127.0.0.1:8000/v1/chat/completions`. This keeps the app shell native and
simple while model serving can iterate independently.

## Model Direction

TranslateGemma is the leading candidate for the local translation model.
The current development path is the MLX-converted 4-bit model exposed through
`mlx_lm.server`, using its OpenAI-compatible API. Direct MLX Swift integration
is still desirable later, but the current local Xcode/Swift toolchain is older
than the latest MLX Swift LM package line, so the HTTP boundary avoids blocking
the product loop on package compatibility.

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

## Near-Term Milestones

1. Improve first-run Accessibility permission guidance.
2. Add a first-class Xcode macOS app target when signing and release packaging
   become necessary.
3. Evaluate TranslateGemma latency, memory use, and output quality on Apple
   Silicon.
4. Add model download/location settings once the runtime path is clear.
5. Revisit direct MLX Swift integration when the project moves to a newer Xcode
   and Swift toolchain.
