#!/usr/bin/env python3
"""Prova che `PERM: 15/15` torni verde DOPO che l'utente installa i due file.

Non modifica niente del progetto: lavora su una copia di `.opencode/agents/` in
una directory temporanea e ci mette dentro i file di `agents_ready/`, poi
ri-esegue i check su quella copia. Serve a una cosa sola: **non chiedere all'utente
di installare due file se non sono davvero verdi.** Il rischio reale di questa
onda e' consegnare all'utente un file che al primo `check_perms.py` dice rosso,
e allora il vertice ha bruciato la fiducia nella porta per un file che sapeva
già' essere rotto.

Come fa: `check_perms` ha due costanti che puntano al mirror e all'installazione,
`MIRROR` e `INSTALLED`. Le si puntano entrambe su una copia, e si verifica che il
file di -ui e il -arena col modello nuovo passino tutti i check. Poi si dice
esattamente quale file l'utente deve copiare e dove.

Uso:  python docs/piramide/verify_agent_install.py
"""
import io
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
READY = os.path.join(HERE, "agents_ready")

sys.path.insert(0, os.path.join(REPO, "tools"))
# `dont_write_bytecode`: senza questo, `import check_perms` lascia un
# `tools/__pycache__/*.pyc` nel repo. `.gitignore` non ha la regola
# `__pycache__` (e `.gitignore` e' di -scheletro, quindi il vertice non la
# tocca), e una volta committato un .pyc dentro si rimuove solo con
# `git rm --cached`, che al vertice e' negato. Quindi: non lo si genera.
sys.dont_write_bytecode = True
import check_perms as cp  # noqa: E402

# I due file che l'utente deve installare, e da dove arrivano.
TO_INSTALL = ["terminal-gun-ui.md", "terminal-gun-arena.md"]

tmp = tempfile.mkdtemp(prefix="tg-agents-")
try:
    fake = os.path.join(tmp, "agents")
    shutil.copytree(os.path.join(REPO, ".opencode", "agents"), fake)
    for name in TO_INSTALL:
        shutil.copyfile(os.path.join(READY, name), os.path.join(fake, name))

    # Il piano deve nominare `terminal-gun-ui`, altrimenti `perm_piano` e' rosso
    # anche con i file installati: e' un controllo sul documento, non sui file.
    with io.open(cp.PIANO, "r", encoding="utf-8") as fh:
        piano = fh.read()
    if "terminal-gun-ui" not in piano:
        sys.stdout.write(
            "FAIL: il piano non nomina terminal-gun-ui, quindi `perm_piano` "
            "sara' rosso anche con i file installati.\n"
        )
        sys.exit(1)

    cp.MIRROR = fake
    cp.INSTALLED = fake

    missing = cp.missing_agent_files()
    if missing:
        for agent, label, path in missing:
            sys.stdout.write("FAIL: manca %s (%s): %s\n" % (agent, label, path))
        sys.exit(1)

    total = len(cp.CHECKS)
    passed = 0
    for name, fn in cp.CHECKS:
        try:
            problems = fn()
        except cp.Fail as exc:
            problems = [str(exc)]
        except Exception as exc:  # noqa: BLE001
            problems = ["controllore rotto: %r" % (exc,)]
        if problems:
            for reason in problems:
                sys.stdout.write("FAIL %s: %s\n" % (name, reason))
        else:
            sys.stdout.write("PASS %s\n" % name)
            passed += 1
    sys.stdout.write("SIMULAZIONE PERM: %d/%d\n" % (passed, total))
    sys.exit(0 if passed == total else 1)
finally:
    shutil.rmtree(tmp, ignore_errors=True)