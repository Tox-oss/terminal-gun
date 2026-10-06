#!/bin/sh
# terminal-gun — rigenerazione completa degli asset.
# Idempotente: stesso comando due volte -> stessi byte (generatori con
# SEED fisso + normalizzazione ffmpeg deterministica).
# Nessun path assoluto di macchina: i path dei binari stanno in tools/env.sh.
set -eu
HERE=$(dirname "$0")
ROOT="$HERE/.."
. "$HERE/env.sh"
python3 "$ROOT/tools/gen_sfx.py" --out "$ROOT/assets/sfx"
"$BLENDER" -b --python "$ROOT/tools/blender/gen_models.py" -- --out "$ROOT/assets/models"
for f in "$ROOT"/assets/sfx/*.wav; do
  tmp="$f.tmp.wav"
  ffmpeg -y -v error -i "$f" -af loudnorm=I=-16:TP=-1.5:LRA=11 -ar 44100 -ac 1 -c:a pcm_s16le -fflags +bitexact "$tmp"
  mv "$tmp" "$f"
done
ls -l "$ROOT/assets/sfx" "$ROOT/assets/models"
