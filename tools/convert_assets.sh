#!/bin/sh
# terminal-gun — rigenerazione completa degli asset.
# Idempotente: stesso comando due volte -> stessi byte (generatori con
# SEED fisso + normalizzazione ffmpeg deterministica).
# Nessun path assoluto di macchina: i path dei binari stanno in tools/env.sh.
#
# ⚠ ATTENZIONE, 2026-10-15. Questo comando **scrive sopra** i file che genera.
# I modelli dei NEMICI non sono fra questi: dal 15 ottobre sono di un artista e
# vengono consegnati come GLB, e `tools/blender/gen_models.py` produce solo
# `player`, `ground_tile` e `crate`. Quindi lanciare questo script **non**
# sovrascrive il lavoro dell'artista — ma continua a sovrascrivere i tre modelli
# che genera, e non lo dice. Se hai file tuoi in quelle tre posizioni, copiali
# fuori prima.
set -eu
HERE=$(dirname "$0")
ROOT="$HERE/.."
. "$HERE/env.sh"
# `python`, non `python3`: su Windows `python3` e' lo stub del Microsoft Store e
# restituisce exit 49 senza eseguire niente, quindi questo script moriva alla
# prima riga prima ancora di arrivare a Blender. Misurato il 2026-10-15.
python "$ROOT/tools/gen_sfx.py" --out "$ROOT/assets/sfx"
"$BLENDER" -b --python "$ROOT/tools/blender/gen_models.py" -- --out "$ROOT/assets/models"
for f in "$ROOT"/assets/sfx/*.wav; do
  tmp="$f.tmp.wav"
  ffmpeg -y -v error -i "$f" -af loudnorm=I=-16:TP=-1.5:LRA=11 -ar 44100 -ac 1 -c:a pcm_s16le -fflags +bitexact "$tmp"
  mv "$tmp" "$f"
done
ls -l "$ROOT/assets/sfx" "$ROOT/assets/models"
