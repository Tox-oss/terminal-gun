# terminal-gun — path reali dei binari di questa macchina.
#
# Unico file in cui vivono i path assoluti. Tutti gli agenti lo caricano con:
#     . tools/env.sh && "$GODOT" --headless --path . --script tools/gate.gd
#
# Slash forward invece di backslash: leggibili uguale in bash e su Windows.
# Generato dal vertice in w0. Non modificare dagli agenti.

GODOT="godot"
BLENDER="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
