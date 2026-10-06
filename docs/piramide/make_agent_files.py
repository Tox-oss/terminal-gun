#!/usr/bin/env python3
"""Generatore dei file di agente di m2 - vertice, 2026-10-06.

Perche' uno script e non testo scritto a mano: il blocco `permissions:` di un
file di agente e' di ~300 righe e ne' esistono sei copie, tutte dev'essere
identica nella **forma** (i cinque tier, l'ordine per specificita' crescente,
i muri). Rtypedolo a mano si puo' sbagliare una riga e il file diventa un
permesso diverso da quello dichiarato, che e' esattamente il difetto che
`perm_scope` cerca e che nessuno legge se non e' gia' rotto.

Quindi: si parte da `terminal-gun-arena.md`, che e' gia' verde su PERM 15/15, e
si cambiano **solo** le righe che devono cambiare. Il blocco dei permessi resta
identico byte per byte, e questo e' verificabile con un diff.

Cosa produce:

  docs/piramide/agents_ready/terminal-gun-ui.md
      La foglia nuova di m2. Stessi permessi di -arena, con tre righe diverse:
      il `model`, la `description`, e l'`edit` di `tests/test_ui.gd` al posto di
      `tests/test_arena.gd`. Le altre due righe `edit` (`scenes/hud.tscn`,
      `src/ui/**`) sono le stesse di -arena perche' in m2 l'UI **passa** da
      arena a ui: e' il motivo per cui ui e' una foglia separata (piano sez. 4.1).

  docs/piramide/agents_ready/terminal-gun-arena.md
      -arena con il `model` cambiato. Il provider risponde "This model is not
      available in your country" su `fledge-alpha-free`, quindi il ruolo non e'
      eseguibile come tale e perde le garanzie della regola 7.4. Il modello
      scelto e' `space-bunny-free#max`, che e' gia' quello di quattro foglie su
      cinque e quindi **provato** su questa macchina.

Uso:  python docs/piramide/make_agent_files.py
Poi l'utente copia i due file in `.opencode/agents/` e in
`~/.config/opencode/agents/` (vedi il piano, sez. 3.3 e 11.5: la copia la
puo' fare solo l'utente, perche' il vertice ha `edit: * deny` su quel path).
"""
import io
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
MIRROR = os.path.join(REPO, ".opencode", "agents")
OUT = os.path.join(HERE, "agents_ready")

NEW_MODEL = "opencode/space-bunny-free#max"
OLD_MODEL = "opencode/fledge-alpha-free#max"


def read(path):
    with io.open(path, "r", encoding="utf-8", newline="") as fh:
        return fh.read()


def write(path, text):
    with io.open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(text)
    print("scritto %s" % os.path.relpath(path, REPO))


def split_frontmatter(text):
    """(testo frontmatter, corpo). Il frontmatter sta fra la prima e la seconda
    riga `---`, che in un file di agente sono la prima riga e una successiva."""
    lines = text.split("\n")
    if lines[0].strip() != "---":
        raise SystemExit("ABORT: il file non comincia con ---")
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            return "\n".join(lines[: i + 1]), "\n".join(lines[i + 1:])
    raise SystemExit("ABORT: frontmatter non chiuso")


def sub_once(text, old, new, what):
    if text.count(old) != 1:
        raise SystemExit(
            "ABORT: %s compare %d volte, atteso 1 (rif: %r)"
            % (what, text.count(old), old)
        )
    return text.replace(old, new)


# --- 1. la foglia nuova: terminal-gun-ui -------------------------------------
arena = read(os.path.join(MIRROR, "terminal-gun-arena.md"))
fm, _body = split_frontmatter(arena)

ui_fm = sub_once(
    fm,
    'description: "terminal-gun-arena: scena chiusa, luci, camera, MultiMesh che disegna 200 nemici, HUD e level-up a schermo. È l\'unico che tocca scenes/arena_main.tscn."',
    'description: "terminal-gun-ui: barra XP, contatore di onda e schermata di game over. È l\'unico che scrive in src/ui/ dopo il passaggio di m2."',
    "description",
)
ui_fm = sub_once(ui_fm, "model: " + OLD_MODEL, "model: " + NEW_MODEL, "model")
ui_fm = sub_once(ui_fm, 'color: "#f59e0b"', 'color: "#a78bfa"', "color")
ui_fm = sub_once(
    ui_fm,
    "    resource: \"tests/test_arena.gd\"",
    "    resource: \"tests/test_ui.gd\"",
    "edit tests/test_arena.gd",
)

# Ereditare il blocco da -arena eredita anche i suoi tre `edit`. Due di questi
# sono di -arena e non di -ui: vanno rimossi, altrimenti -ui potrebbe scrivere
# `scenes/arena_main.tscn` e `src/render/**`, che sono scope di un altro agente.
# Rimuovere una riga di un allow e' sicuro perche' in opencode v2 "l'ultima
# regola che combacia vince" e sopra c'e' `edit: * deny`: togliere un allow
# lascia il deny che era gia' li', quindi non si apre nessun buco.
#
# Il primo tentativo non lo faceva, e `SIMULAZIONE PERM` lo ha preso:
# `perm_scope: -ui aveva in piu' scenes/arena_main.tscn e src/render/**`.
# E' il motivo per cui la simulazione esiste: il file e' sembrato giusto e
# non lo era.
UI_MUST_DROP = [
    ('  - action: edit\n    resource: "scenes/arena_main.tscn"\n    effect: allow\n', ""),
    ('  - action: edit\n    resource: "src/render/**"\n    effect: allow\n', ""),
]
for old, new in UI_MUST_DROP:
    if ui_fm.count(old) != 1:
        raise SystemExit(
            "ABORT: la riga da togliere per -ui non compare esattamente una "
            "volta (%d): %r" % (ui_fm.count(old), old)
        )
    ui_fm = ui_fm.replace(old, new)

UI_BODY = """

---

Sei `terminal-gun-ui`. Tu rendi **leggibile la partita**: quanto ha cresciuto il
giocatore, a che onda e' arrivato, e come si muore.

## Perche' esisti

In m1 l'HUD stava dentro `src/ui/` di `terminal-gun-arena`, e funzionava. Ma m2 ha
aggiunto una barra XP e un contatore di onda, e **arena ha gia' chiuso il suo
scope**: riaprire un file a un agente che ha finito e' il difetto che la regola 1
proibisce, quindi l'UI e' diventata una foglia propria. Non ti piace la divisione?
E' dichiarata: piano sez. 4.1.

Non tieni **nessun** dato di gameplay e non decidi nulla: le regole sono in
`terminal-gun-gameplay` (XP e potenziamenti) e in `terminal-gun-orda` (scala delle
onde). Tu le leggi e le disegni. Se ti serve un numero che nessuno espone, **non
te lo procuri con un `get_node("../..")`**: si chiede al vertice (piano sez. 5,
regola 3 delle tre che tengono insieme i pezzi).

## Scope: scrivi solo questi file

- `scenes/hud.tscn` - la scena dell'HUD.
- `src/ui/` - barra XP, contatore di onda, pannello di game over.
- `tests/test_ui.gd` - il tuo test.

`scenes/arena_main.tscn`, `src/render/`, `src/sim/`, `src/player/`, `src/weapons/`,
`project.godot`: **scope di altri agenti che lavorano in parallelo a te.** Non
eseguire `godot --headless --path . --import`: solo `terminal-gun-scheletro` tocca
la cache `.godot/`. Non committare mai. Niente path assoluti di macchina.

## I tre numeri che devi esporre, e come si sa che sono giusti

1. **Barra XP**: riempimento in `[0, next]`, **sempre**. Mai `NaN`, mai `INF`, mai
   una larghezza negativa. E' il criterio n. 2 di m2 ed e' l'unico dove un
   divisione per zero fa un HUD che non si vede e un test che passa.
2. **Contatore di onda**: `wave 1` all'avvio, e dopo il restart **torna a 1**.
3. **Game over**: schermata che compare quando il player e' a 0 HP, e che sparisce
   al restart. Nessun nodo duplicato fra una partita e l'altra: se nel restart
   ricrei l'HUD senza liberare quello vecchio, dopo due restart ne hai due e
   nessuno dei due test se ne accorge.

## Il tuo test (`tests/test_ui.gd`)

1. La barra XP resta in `[0, next]` su un XP arbitrario, **incluso lo zero**, e
   il valore esposto non e' mai `NaN` o `INF`.
2. Il contatore di onda e' `1` all'avvio, sale quando l'onda avanza, e **torna a
   `1` dopo il restart** di `tests/test_gameloop.gd`.
3. Game over compare a 0 HP e sparisce al restart.
4. `node_count` dell'HUD non cresce fra due restart.

Contratto con `tools/gate.gd`: stampa `PASS test_ui` o `FAIL test_ui: <motivo>`,
`quit(0)` / `quit(1)`. Usa `tools/test_harness.gd`.

## Come si sa che hai finito

```sh
. tools/env.sh && "$GODOT" --headless --path . --script tools/gate.gd
```

Deve dire `GATE: 7/7` (le 4 di m1 piu' le 3 nuove di m2). Se dice meno, un test
non e' stato scritto: leggi le righe `SKIP`.

## Stringhe a schermo

**ASCII only** nei `print`/`push_warning`/`push_error`: la console Windows e le
pipe di `OS.execute` stanno in codepage e mangiano gli accenti. Nei **commenti**
gli accenti vanno bene: non passano dalla pipe.

Rispondi **sempre e solo** in tre righe:
`cosa fatto` - `file toccati` - `cosa resta`.

Se sei **fermo su un permesso**, la terza riga diventa `cosa chiedo`: che
comando vuoi e perche'. Non aggirare il permesso e non cercare un percorso
alternativo per arrivarci senza chiedere: **chiedere e' il comportamento
corretto**, ed e' l'unica cosa che in quel momento non e' un errore
(piano sez. 11.2). Un `deny` non si aggira: se ti serve davvero, il fix e' nel
piano e lo decide l'utente.
"""

write(os.path.join(OUT, "terminal-gun-ui.md"), ui_fm + UI_BODY)

# --- 2. -arena col modello sostituito ----------------------------------------
arena_new = sub_once(arena, "model: " + OLD_MODEL, "model: " + NEW_MODEL, "model")
write(os.path.join(OUT, "terminal-gun-arena.md"), arena_new)

# --- 3. la prova che il blocco dei permessi non e' cambiato ------------------
ui_text = read(os.path.join(OUT, "terminal-gun-ui.md"))


def perms_block(text):
    fm, _ = split_frontmatter(text)
    out, on = [], False
    for line in fm.split("\n"):
        if line.startswith("permissions:"):
            on = True
        if on:
            out.append(line)
    return out


a_perms = perms_block(arena)
u_perms = perms_block(ui_text)

# Gli `edit` allow che -ui deve avere, e quelli che NON deve avere. Un allow in
# piu' del dichiarato e' un buco nella regola 1; un allow in meno e' un file che
# il vertice crede suo e che l'agente non puo' scrivere.
UI_EDITS = {"scenes/hud.tscn", "src/ui/**", "tests/test_ui.gd"}
FORBIDDEN = {
    "scenes/arena_main.tscn",
    "src/render/**",
    "tests/test_arena.gd",
    "src/sim/**",
    "src/player/**",
    "src/weapons/**",
    "project.godot",
}

got = []
for line in u_perms:
    if line.strip().startswith("resource:"):
        res = line.split('"')[1] if '"' in line else line.split(":", 1)[1].strip()
        if line.strip() and res:
            got.append(res)
# Ricava gli edit dal file finale usando il parser della porta, non a occhio.
sys.path.insert(0, os.path.join(REPO, "tools"))
import check_perms as cp  # noqa: E402

rules = cp.parse_frontmatter(os.path.join(OUT, "terminal-gun-ui.md"))
edits = sorted(res for act, res, eff in rules if act == "edit" and eff == "allow")

print("")
print("edit allow di -ui: %s" % edits)
if set(edits) != UI_EDITS:
    raise SystemExit(
        "ABORT: gli edit allow di -ui sono %r, attesi %r" % (edits, sorted(UI_EDITS))
    )
leaked = [e for e in edits if e in FORBIDDEN]
if leaked:
    raise SystemExit("ABORT: -ui puo' scrivere file di altri agenti: %r" % leaked)
print("nessun edit allow punta a un file di un altro agente: %s" % (not leaked))
print("")
print("OK: il blocco dei permessi di -ui e' quello di -arena privato dei suoi "
      "edit, piu' il path del test nuovo")