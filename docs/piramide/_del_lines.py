#!/usr/bin/env python3
"""Utility ONE-SHOT del vertice: cancella un intervallo di righe da un file.

Uso: python docs/piramide/_del_lines.py <file> <da> <a>   (1-based, inclusi)

Serve per una cosa sola: `edit` richiede il testo ESATTO di oldString e le
accentate di piano.md non si lasciano riprodurre a mano senza rischiare di
cancellare la riga sbagliata. Cancellare per numero di riga e' esatto per
definizione. Dopo l'uso questo file e il probe si possono togliere.
"""
import io
import sys

path, start, end = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
with io.open(path, "r", encoding="utf-8", newline="") as fh:
    lines = fh.readlines()

# Safety: refuse anything that does not look like the stale duplicate block.
lo, hi = start - 1, end
preview = "".join(lines[lo:hi])
for marker in ("Misura `KNOCKBACK` a **tre** valori",
               "delta di posizione",
               "dimostra la pendenza",
               "Se la pendenza"):
    if marker not in preview:
        sys.exit("ABORT: marcatore %r non trovato nell'intervallo %d-%d" % (marker, start, end))

with io.open(path, "w", encoding="utf-8", newline="") as fh:
    fh.writelines(lines[:lo] + lines[hi:])
print("cancellate le righe %d-%d di %s" % (start, end, path))