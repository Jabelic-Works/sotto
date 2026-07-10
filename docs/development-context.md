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

The translation engine is currently an echo implementation. This keeps input
capture, trigger timing, permission behavior, and popup placement testable before
model integration adds latency and packaging complexity.

## Model Direction

TranslateGemma is the leading candidate for the local translation model.
The expected path is to run a compact quantized model locally on Apple Silicon,
likely through MLX/MLX Swift or a nearby native runtime once the app shell is
stable enough to evaluate latency and memory behavior.

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
3. Add a real translation engine implementation behind `TranslationEngine`.
4. Evaluate TranslateGemma latency, memory use, and output quality on Apple
   Silicon.
5. Add model download/location settings once the runtime path is clear.
