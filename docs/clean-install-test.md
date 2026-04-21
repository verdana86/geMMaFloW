# Clean install test checklist

Use this after a big refactor to verify that a brand-new machine (or a
reset account) can install geMMaFloW, grant the three macOS permissions,
download both models, and produce a correct dictation. Run **after** a
successful `swift test` — clean-install only catches bugs that live
outside the test boundary (TCC, downloads, bundle layout, codesign).

## 1. Reset user state

```sh
make clean-user-state
```

This prompts before deleting. Expected removals:
- `/Applications/geMMaFloW.app`
- `~/Library/Caches/com.verdana86.gemmaflow`
- `~/Library/Application Support/geMMaFloW`
- `~/.cache/huggingface/hub/models--argmaxinc--whisperkit-coreml`
- `~/.cache/huggingface/hub/models--mlx-community--gemma-*`
- TCC grants for Microphone, Accessibility, ScreenCapture

Verify:

```sh
ls ~/Library/Application\ Support/geMMaFloW 2>&1 | head -1   # expect "No such file"
ls ~/.cache/huggingface/hub | grep -E '(whisperkit|gemma)'   # expect empty
tccutil list Microphone | grep gemmaflow                     # expect empty
```

## 2. Build + install

```sh
make clean
make all
cp -R build/geMMaFloW.app /Applications/
```

Then open from `/Applications` (not from `build/` — TCC uses the install
location).

## 3. Walk the wizard

1. **Welcome** — intro + GitHub card.
2. **Dictation Language** — pick Italian (or your language). Continue.
3. **Permissions** — three rows. Grant Mic → system dialog. Grant
   Accessibility → System Settings opens. Grant Screen Recording →
   dialog. "Continue" stays disabled until all three turn green.
4. **Shortcuts** — Hold + Tap sections side by side. Fn default.
5. **Test transcription** — microphone picker + mic button. Hold Fn,
   speak 2–3 seconds, release. Aspettativa alla prima esecuzione:
   ~1.5 GB WhisperKit download with progress bar, poi trascrizione.
6. **Ready** — toggle "Launch at login" se desiderato.

## 4. First real dictation

In `TextEdit` press Fn, say something, release. Aspettativa:
- Primo uso: download Gemma 4 E4B (~2.5 GB) con progress nel menu bar.
- Secondo uso in poi: 1–2s di latenza totale.
- Il testo viene inserito al cursore.

## 5. Silent-audio guard

Hold Fn ma non parlare per 2–3 secondi, rilascia. Aspettativa:
stringa vuota (RMS filter in `AudioSilenceDetector`), niente
allucinazioni tipo "Thanks for watching" o comandi shell.

## 6. Known-good signals

- `log show --predicate 'subsystem == "com.verdana86.gemmaflow"' --last 5m`
  mostra eventi `MLXLLM`, `WhisperKit`, `Silence` senza errori.
- `~/Library/Application Support/geMMaFloW/audio/` contiene i wav
  delle ultime run.
- Menu bar mostra l'icona corretta e il tooltip con la versione.

Se qualcuno di questi step fallisce, registra il log completo e
l'evento che ha causato il fallimento — clean-install è la rete di
sicurezza che intercetta ciò che i test unitari non vedono (TCC, path
del bundle, firma, first-run download).
