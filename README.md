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
- menu controls for pausing/resuming the double-copy trigger
- a replaceable translation engine boundary

Translation is sent to a local OpenAI-compatible server at
`http://127.0.0.1:8000/v1/chat/completions`. The default model id is
`mlx-community/translategemma-4b-it-4bit_immersive-translate`. This is the
current development fallback; the product target is native in-app MLX.

See [Development Context](docs/development-context.md) for the product and
technical assumptions behind the prototype.
See [Native MLX Plan](docs/native-mlx-plan.md) for the intended single-app
runtime architecture.

## Requirements

- Apple Silicon Mac
- macOS 14 or later
- Swift 6.1.3 or later
- Xcode 15.2 or later for the macOS SDK

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

## Local Translation Server

Sotto expects a local OpenAI-compatible translation server. One development path
is MLX LM with the MLX-converted TranslateGemma model:

```sh
uv tool install mlx-lm
scripts/run-translation-server.sh
```

The server stays in the foreground and keeps the terminal occupied. After
`Starting httpd at 127.0.0.1 on port 8000...`, no shell prompt is expected until
you stop the server with <kbd>Control</kbd>+<kbd>C</kbd>.

The model is downloaded from Hugging Face on first use. Gemma-family models may
require accepting the model terms on Hugging Face before download.

## Test

```sh
swift test
```
