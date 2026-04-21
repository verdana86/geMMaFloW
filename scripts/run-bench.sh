#!/usr/bin/env bash
# Generates the benchmark audio (if missing) and runs the Swift test-
# target benchmark, which writes a markdown table to bench/results.md.
#
# Can be re-run: the audio is only re-generated if missing or --regen
# is passed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIO_DIR="$REPO_ROOT/bench/audio"
REGEN=0

for arg in "$@"; do
    case "$arg" in
        --regen|-r) REGEN=1;;
        *) echo "unknown arg: $arg" >&2; exit 2;;
    esac
done

if [[ $REGEN -eq 1 || ! -f "$AUDIO_DIR/full.wav" ]]; then
    echo "=== Generating audio via ElevenLabs ==="
    "$REPO_ROOT/scripts/gen-bench-audio.sh"
else
    echo "=== Reusing existing audio in $AUDIO_DIR (pass --regen to re-fetch) ==="
fi

echo
echo "=== Running benchmark matrix (this takes ~20-30 min on first run) ==="
cd "$REPO_ROOT"
BENCH_AUDIO_DIR="$AUDIO_DIR" swift test -c release --filter "Benchmark"

echo
echo "=== Results ==="
echo "  $REPO_ROOT/bench/results.md"
