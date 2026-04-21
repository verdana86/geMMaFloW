#!/usr/bin/env bash
# Generates the benchmark audio via macOS `say` (Samantha) and cuts it
# into 20s / 40s / 60s / full segments at 16 kHz mono (Whisper-native).
#
# Originally planned via ElevenLabs, but the provided API key is locked
# to a free tier that blocks library voices. `say` produces consistent,
# reproducible audio with zero dependencies — good enough for latency
# comparisons between models.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIO_DIR="$REPO_ROOT/bench/audio"
TEXT_FILE="$REPO_ROOT/bench/reference.txt"
VOICE="${BENCH_VOICE:-Samantha}"

mkdir -p "$AUDIO_DIR"

# Reference text — English, ~225 words with intentional fillers so Gemma
# has something to clean up even on TTS output. Targets ~70s at macOS
# `say` default rate with voice Samantha.
cat > "$TEXT_FILE" <<'EOF'
Okay so, um, today I'm testing a local dictation app called GemmaFlow. The goal is, uh, to compare different model combinations, measuring both the transcription time and, I mean, the quality of the final output. The first model, Whisper, converts my voice into raw text. The second model, Gemma, kicks in afterward to, um, fix punctuation, remove hesitations like "uh" or "I mean", and correct any errors. Some specific terms to test are: MacBook, Swift, metallib, eighty two point five percent, and the acronym API. Longer sentences tend to confuse smaller models, especially when they contain, you know, parenthetical clauses or bulleted lists like this one: first, second, third, fourth. Consider also how the model handles numbers like twenty twenty six, ordinals like the twenty first century, and abbreviations like PhD or CEO. Domain specific vocabulary matters too: think of terms like kubernetes, asynchronous, encapsulation, or factorial. A good dictation pipeline should preserve the user's intent, stay faithful to the spoken words, and only remove the fillers that would look awkward in writing. Let me close with a rhetorical question: can we, uh, get quality comparable to the large model while paying only a third of the latency? We'll see.
EOF

RAW_AIFF="$AUDIO_DIR/raw.aiff"
FULL_WAV="$AUDIO_DIR/full.wav"

echo "→ Synthesising via macOS say (voice: $VOICE)…"
say -v "$VOICE" -o "$RAW_AIFF" -f "$TEXT_FILE"

echo "→ Converting to 16 kHz mono WAV…"
ffmpeg -y -loglevel error -i "$RAW_AIFF" -ar 16000 -ac 1 -c:a pcm_s16le "$FULL_WAV"

DURATION=$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$FULL_WAV")
printf "→ full.wav duration: %.2fs\n" "$DURATION"

for cut in 20 40 60; do
    OUT="$AUDIO_DIR/${cut}s.wav"
    ffmpeg -y -loglevel error -i "$FULL_WAV" -t "$cut" -c:a pcm_s16le "$OUT"
    D=$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$OUT")
    printf "  ✓ %s (%.2fs)\n" "$(basename "$OUT")" "$D"
done

echo "✓ Audio ready in $AUDIO_DIR"
