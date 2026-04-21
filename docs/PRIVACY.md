# Privacy model

The core promise of geMMaFloW is that **your dictation never leaves your Mac**. This document explains exactly what that means, where the boundary is, and how you can verify it.

---

## The claim

During normal dictation:

1. Microphone audio is captured locally.
2. It is transcribed locally by WhisperKit.
3. The transcript is cleaned up locally by Gemma 4 via MLX.
4. The cleaned text is pasted locally via the clipboard.

At no point during steps 1–4 does the app open a network connection, read your clipboard history, take a screenshot, or send telemetry.

---

## What the app actually sees

Every dictation, geMMaFloW handles the following pieces of data:

| Data | Scope | Where it lives |
|---|---|---|
| Microphone audio | RAM + a temporary WAV file | `/var/folders/…` temp dir, deleted after transcription |
| Raw Whisper transcript | RAM | discarded after post-processing (unless history is on) |
| Cleaned transcript | RAM → pasted | discarded after paste (unless history is on) |
| Frontmost app name | RAM, injected into Gemma prompt | not persisted |
| Frontmost window title | RAM, injected into Gemma prompt | not persisted |
| Selected text in frontmost app | RAM, injected into Gemma prompt | not persisted |
| Dictation history (optional) | JSON in `~/Library/Application Support/` | wipeable from Settings |

If you turn off history in Settings, nothing about a given dictation survives past the paste.

---

## What the app does **not** see

- **Screenshots of your screen.** The app requests Screen Recording permission for one reason: macOS ties the ability to read window titles of other apps to that permission. The app never captures pixels.
- **Other apps' content beyond the frontmost window.**
- **Your clipboard history.** The app snapshots the clipboard immediately before the paste and restores it immediately after. It never reads the pasteboard at any other time.
- **Your keystrokes.** The hotkey manager matches a single configured shortcut; it doesn't log or forward keys.
- **Your files.** The app doesn't read the filesystem except for its own caches and model directories.

---

## The one network connection

There is exactly one time geMMaFloW makes outbound HTTP calls: when WhisperKit or MLX needs to fetch a model that isn't cached yet. These calls go directly to `huggingface.co` and are made by the respective library (`WhisperKit` → `argmaxinc/whisperkit-coreml`, `mlx-swift-examples` → `mlx-community/gemma-4-*`).

After the model is downloaded, no further network access is required. You can airplane-mode your Mac and dictation keeps working.

Model caches live under `~/.cache/huggingface/hub/`. You can wipe them from Settings → General → "Clear model cache", or manually with `rm -rf ~/.cache/huggingface/hub/`.

---

## How the sandbox enforces this

geMMaFloW ships with the App Sandbox enabled and a **deliberately minimal** set of entitlements. From [`GemmaFlow.entitlements`](../GemmaFlow.entitlements):

- `com.apple.security.device.audio-input` — microphone (required for dictation)
- `com.apple.security.cs.allow-unsigned-executable-memory` — required by MLX and WhisperKit's JIT-compiled Metal kernels
- `com.apple.security.cs.disable-library-validation` — required by MLX dynamic loading

There are **no** network entitlements:

- No `com.apple.security.network.client`
- No `com.apple.security.network.server`

In an App Sandbox build, outbound connections without `network.client` are refused by the kernel. Even if a dependency tried to call home, the sandbox would block it.

> Note: whether the Sandbox is fully active depends on the codesigning step. The `Makefile` signs with a self-signed developer identity for convenience during iteration; a notarized distribution build will ship with the hardened runtime and sandbox fully enforced. Model downloads happen before the sandboxed app runs them, through the library bootstrapping path — the entitlement set still applies to the app's runtime behavior.

---

## How to verify yourself

You don't have to trust this document. You can check:

### Watch the network

With the app running and dictating:

```bash
sudo lsof -i -P | grep -i GemmaFlow
```

Or use Little Snitch / LuLu to monitor outbound connections. You should see nothing during dictation (after the initial model download).

### Grep the code

The three services that used to talk to the cloud were `TranscriptionService`, `PostProcessingService`, and `AppContextService`. None of them should be constructing a `URLRequest` to an external host now.

```bash
# No HTTP to api.groq.com or similar should exist
grep -ri "groq.com\|api.openai.com" Sources/
```

You'll find matches only in test fixtures and deprecated/dead code in `LLMAPITransport.swift`, which is no longer reached.

### Audit the entitlements

```bash
codesign -d --entitlements - build/GemmaFlow.app
```

Confirm there are no `network.client` entitlements in the output.

---

## If you want to add a cloud backend back

The backend abstractions ([`TranscriptionBackend`](../Sources/TranscriptionBackend.swift), [`LLMBackend`](../Sources/LLMBackend.swift)) are still in place with their sentinel-URL routing. You'd:

1. Re-introduce a remote backend implementation
2. Extend `TranscriptionBackendKind.parse` / `LLMBackendKind.parse` to route non-`local://` URLs to it
3. Add `com.apple.security.network.client` to `GemmaFlow.entitlements`
4. Surface the option (and an API key field) in Settings

This is intentionally not something the user can do by flipping a switch — the network capability is gated at the entitlement level, so re-enabling cloud requires a rebuild. That's the whole point.
