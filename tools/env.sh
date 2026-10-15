# terminal-gun — path reali dei binari di questa macchina.
#
# Unico file in cui vivono i path assoluti.
#
# ## COME SI ESEGUE IL GODOT, E LA FORMA CHE FUNZIONA
#
#     godot --headless --path . --script tools/gate.gd
#
# Nuda, senza variabile. NON `. tools/env.sh && "$GODOT" ...`.
#
# Perche' la seconda forma e' quella che questo file insegnava e non
# funziona: le allowlist delle foglie dichiarano `godot *`, e la riga che lo
# scanner vede nella forma composta e' `"$GODOT" --headless ...`. La variabile
# non e' stata ancora espansa quando il permesso viene valutato, quindi
# `"$GODOT"` **non combacia con `godot`**, la riga cade e finisce su
# `shell "*" deny`. Misurato due volte: a `-ui` e a `-gameplay` il 2026-10-15,
# e in entrambi i casi la foglia ha perso la verifica perche' aveva scritto il
# comando come le era stato insegnato qui.
#
# La riga `godot *` c'e' anche perche' `GODOT="godot"` e il binario e' su PATH,
# quindi la variabile non serve a niente per Godot. Serve invece a BLENDER,
# che **non** e' su PATH e sta sotto Program Files.
#
# Slash forward invece di backslash: leggibili uguale in bash e su Windows.
# Generato dal vertice in w0. Non modificare dagli agenti.

GODOT="godot"
BLENDER="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
