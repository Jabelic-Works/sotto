# Sotto

Local translation, right where you read.

Sotto is a native macOS menu bar app. Select text in any app and press
<kbd>Command</kbd>+<kbd>C</kbd> twice to open a translation beside the selection.

## Status

This repository currently contains the first interaction prototype:

- menu bar lifecycle
- double-copy detection through the system pasteboard
- selection bounds lookup through the macOS Accessibility API
- a lightweight floating panel near the selected text, with scroll support for
  longer text
- a replaceable translation engine boundary

TranslateGemma integration is the next milestone. Until then, the prototype
echoes the copied text so the system interaction can be tested independently.

See [Development Context](docs/development-context.md) for the product and
technical assumptions behind the prototype.

## Requirements

- Apple Silicon Mac
- macOS 14 or later
- Xcode 15.2 or later

## Run

```sh
swift run Sotto
```

On first use, grant Sotto access in **System Settings → Privacy & Security →
Accessibility**. Without that permission, the panel falls back to the mouse
pointer position. The menu bar item shows the current Accessibility status and
includes actions to request permission or open the relevant System Settings pane.

For a more realistic local app run, build a `.app` bundle:

```sh
scripts/build-app.sh
open .build/Sotto.app
```

This is still a Mac app running on your machine directly. No iOS Simulator or
emulator is required. Sotto runs as a menu bar app, so it does not open a normal
Dock window. Development builds show a small startup popup so launch success is
visible.

## Test

```sh
swift test
```
