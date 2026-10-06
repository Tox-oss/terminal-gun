#!/usr/bin/env python3
"""M2-w1: aggiunge ai file di `-orda` e `-gameplay` i `tests/` che il piano
sez. 3.3 gia' assegna loro, e che in m2-w0 nessuno aveva aggiunto.

**Il difetto che ripara, detto chiaro.** In m2-w0 io ho preparato il file della
foglia NUOVA (`-ui`) e ho cambiato il modello di `-arena`, e ho dato per scontato
che bastasse. Non bastava: il piano sez. 3.3 assegna a `-orda` anche
`tests/test_gameloop.gd` e a `-gameplay` anche `tests/test_progression.gd` e
`tests/test_upgrades.gd`, e quelle tre righe non erano in nessuna allowlist. Il
risultato e' stato che in m2-w1 due foglie su tre si sono fermate al primo file
che il piano chiedeva di scrivere, con `Permission denied: edit`.

Quindi il difetto non e' delle foglie: e' **mio**, e precisamente l'errore che
questo piano chiama "file senza proprietario" (sez. 3.1) fatto al contrario. Non
un file senza proprietario, ma **un path di scope che il piano assegna e che
nessuno aveva messo nei permessi**: il piano e la allowlist dicevano cose
diverse, e il gate non l'aveva preso perche' `perm_scope` confronta i permessi
con `SCOPE` in `check_perms.py`, e anche `SCOPE` era rimasto quello di m1.

Perche' uno script: l'inserimento e' banale ma deve essere **esatto** e
**verificabile**. Il blocco `permissions` di questi file e' di ~300 righe e ne'
esistono due copie (mirror e installazione); toccarlo a mano su due file e
sbagliarlo una volta significa un allow sbagliato, che e' la cosa che la regola
7.4 deve impedire. Qui l'inserimento e' un singolo `replace` con verifica del
contesto (l'ancora deve comparire una volta sola), e il file finale viene
ripassato dal parser della porta.

Uso:  python docs/piramide/fix_m2_test_scopes.py
Poi l'utente copia i due file come al solito (4 copie, sezione 11.5).
"""
import io
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
MIRROR = os.path.join(REPO, ".opencode", "agents")
OUT = os.path.join(HERE, "agents_ready")

# Agente -> righe `edit` da aggiungere, gia' nell'ordine in cui vanno nel file.
NEEDS = {
    "terminal-gun-orda": ["tests/test_gameloop.gd"],
    "terminal-gun-gameplay": ["tests/test_progression.gd", "tests/test_upgrades.gd"],
}

# La riga dopo cui inserire: l'ultimo `edit` allow gia' presente del file. Si
# cerca l'ultima occorrenza del blocco `edit`, cosi' l'inserimento va in coda
# agli allow di quel file e non in mezzo.
ANCHOR = {
    "terminal-gun-orda": '    resource: "tests/test_orda.gd"\n    effect: allow\n',
    "terminal-gun-gameplay": '    resource: "tests/test_gameplay.gd"\n    effect: allow\n',
}

sys.dont_write_bytecode = True


def read(path):
    with io.open(path, "r", encoding="utf-8", newline="") as fh:
        return fh.read()


def write(path, text):
    with io.open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(text)
    print("scritto %s" % os.path.relpath(path, REPO))


def add_edit_rules(text, paths, anchor, agent):
    """Inserisce gli allow `edit` richiesti subito dopo `anchor`, una volta sola."""
    if text.count(anchor) != 1:
        raise SystemExit(
            "ABORT: %s non ha un ancora univoca (%d): %r"
            % (agent, text.count(anchor), anchor)
        )
    block = "".join(
        '  - action: edit\n    resource: "%s"\n    effect: allow\n' % p
        for p in paths
    )
    return text.replace(anchor, anchor + block)


def check_edits(path, agent, expected):
    """Rilegge il file con lo stesso parser della porta e verifica gli `edit`."""
    sys.path.insert(0, os.path.join(REPO, "tools"))
    import check_perms as cp

    rules = cp.parse_frontmatter(path)
    got = sorted(r for a, r, e in rules if a == "edit" and e == "allow")
    print("  %s: edit allow = %s" % (agent, got))
    if got != sorted(expected):
        raise SystemExit(
            "ABORT: %s ha %r, attesi %r" % (agent, got, sorted(expected))
        )
    for act, res, eff in rules:
        if eff == "allow" and res.startswith((".opencode/", "tools/", "project.godot")):
            raise SystemExit("ABORT: %s ha un allow per %s" % (agent, res))
    return got


# Gli `edit` che ogni file deve avere DOPO la modifica, presi dal piano sez. 3
# e 3.3. Non sono un'invenzione: sono la somma di cio' che il file aveva in m1 e
# di cio' che m2 vi aggiunge.
EXPECTED = {
    "terminal-gun-orda": [
        "src/sim/**",
        "tests/test_orda.gd",
        "tests/test_gameloop.gd",
    ],
    "terminal-gun-gameplay": [
        "src/player/**",
        "src/weapons/**",
        "scenes/player.tscn",
        "scenes/projectile.tscn",
        "tests/test_gameplay.gd",
        "tests/test_progression.gd",
        "tests/test_upgrades.gd",
    ],
}

for agent, paths in NEEDS.items():
    src = os.path.join(MIRROR, agent + ".md")
    text = read(src)
    for p in paths:
        if 'resource: "%s"' % p in text:
            raise SystemExit(
                "ABORT: %s ha gia' l'allow per %s: non si tocca niente" % (agent, p)
            )
    new = add_edit_rules(text, paths, ANCHOR[agent], agent)
    dst = os.path.join(OUT, agent + ".md")
    write(dst, new)
    check_edits(dst, agent, EXPECTED[agent])

print("")
print("OK: i due file hanno esattamente gli edit del piano sez. 3 e 3.3")