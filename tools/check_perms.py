#!/usr/bin/env python
"""terminal-gun - porta dei permessi della piramide.

Verifica che i blocchi `permissions:` dei sei agenti di terminal-gun dicano
quello che `docs/piramide/piano.md`sezione 11 promette. Non li riscrive: li
misura, e su un dubbio fallisce invece di passare.

Perche' esiste in un progetto che ha gia' `tools/gate.gd`: il gate misura il
CODICE, e non dice niente sui PERMESSI. Un agente puo' avere la allowlist
sbagliata e il gate resta verde, perche' il gate non guarda la allowlist.
Questo e' il gate di quello.

Uso (dalla root del progetto):
    python tools/check_perms.py

Stampa `PASS <nome>` o `FAIL <nome>: <motivo>`, e finisce con
`PERM: N/M` e `quit(0)`/`quit(1)` come `tools/gate.gd`. ASCII only a schermo:
la console Windows e le pipe stanno in codapage (piano sezione 5.1).

Nessuna dipendenza: solo `re`, `os`, `sys`, `io`, `hashlib`. PyYAML non serve e
non si installa (piano sezione 9: niente pip).

Se un check fallisce e ti sembra che abbia ragione lui, il fix e' nel file
dell'agente e poi qui: `SCOPE` sotto e' la copia leggibile dagli umani dello
scope del piano, ed e' quella che va tenuta allineata.
"""

import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIRROR = os.path.join(ROOT, ".opencode", "agents")
INSTALLED = os.path.join(os.path.expanduser("~"), ".config", "opencode", "agents")
PIANO = os.path.join(ROOT, "docs", "piramide", "piano.md")

VERTICE = "terminal-gun"
LEAVES = [
    "terminal-gun-scheletro",
    "terminal-gun-orda",
    "terminal-gun-gameplay",
    "terminal-gun-arena",
    "terminal-gun-assets",
    "terminal-gun-ui",
]
ALL_AGENTS = [VERTICE] + LEAVES

# L'unico path assoluto di macchina ammesso in un file di permessi, e per lo
# stesso motivo di tools/env.sh: winget installa Blender sotto Program Files
# senza alias, quindi "blender" non e' su PATH e l'invocazione reale e' quotata.
BLENDER_RULE = '"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" *'

# Scope dichiarato, copiato da docs/piramide/piano.md sezione 3 e 3.3.
# Qui e' la copia leggibile dagli umani: se cambi il piano, cambi qui, e il
# check 12 ti dice se il piano e i permessi sono tornati coerenti.
SCOPE = {
    VERTICE: [
        "docs/piramide/**",
        "src/core/contracts.gd",
        # m2 (piano sez. 3.3): il timeout del gate e' del vertice. In w1 il file
        # e' di `-scheletro`: e' il **passaggio** di proprieta' di m2, dichiarato
        # in DECLARED_OVERLAP sotto. `-scheletro` non lavora in m2, quindi le due
        # foglie non scrivono mai lo stesso file nella stessa onda.
        "tools/gate.gd",
        "tools/env.sh",
        "tools/check_perms.py",
        ".gitattributes",
    ],
    "terminal-gun-scheletro": [
        "project.godot",
        "src/core/**",
        "tools/gate.gd",
        "tools/test_harness.gd",
        "tests/test_smoke.gd",
        ".gitignore",
        "scenes/arena_main.tscn",
        # 2026-10-13: l'export a .exe. Il piano sez. 3.4 lo assegna gia' a
        # -scheletro dal 2026-10-06, ma il path non era in nessuna allowlist:
        # **quarta** occorrenza della classe "il piano assegna un file che nessuno
        # puo' scrivere" (dopo .gitattributes, i path dei test di m2, e
        # tools/gate.gd fuori dalla allowlist del vertice). `perm_scope` e' la
        # porta che lo prende, e lo prende nel verso giusto: prima che l'onda
        # partisse.
        "export_presets.cfg",
    ],
    "terminal-gun-orda": [
        "src/sim/**",
        "tests/test_orda.gd",
        # m2 (piano sez. 3.3): wave e game_over stanno nella simulazione, non
        # nell'UI, quindi il test del game loop e' suo.
        "tests/test_gameloop.gd",
    ],
    "terminal-gun-gameplay": [
        "src/player/**",
        "src/weapons/**",
        "scenes/player.tscn",
        "scenes/projectile.tscn",
        "tests/test_gameplay.gd",
        # m2 (piano sez. 3.3): crescita del player e' scope di gameplay, non di ui.
        "tests/test_progression.gd",
        "tests/test_upgrades.gd",
    ],
    "terminal-gun-arena": [
        "scenes/arena_main.tscn",
        "scenes/hud.tscn",
        "src/render/**",
        "src/ui/**",
        "tests/test_arena.gd",
    ],
    # Foglia nuova di m2 (piano sez. 3.3 e 4.1). `scenes/hud.tscn` e `src/ui/**`
    # sono anche nel scope di -arena: non e' un conflitto, e' il **passaggio** di
    # proprieta' di m2, dichiarato in DECLARED_OVERLAP sotto. -arena non lavora in
    # m2, quindi le due foglie non scrivono mai nello stesso file nella stessa
    # onda: e' quello che rende la cosa sicura invece che solo dichiarata.
    "terminal-gun-ui": [
        "scenes/hud.tscn",
        "src/ui/**",
        "tests/test_ui.gd",
    ],
    "terminal-gun-assets": [
        "tools/gen_sfx.py",
        "tools/blender/gen_models.py",
        "tools/convert_assets.sh",
        "assets/**",
    ],
}

# Sovrapposizioni dichiarate nel piano (sezione 3.3): non sono un bug, sono
# l'apertura di m2. Qui perche' il check le possa contare come note invece di
# farle sembrare un conflitto.
DECLARED_OVERLAP = {
    ("terminal-gun", "src/core/contracts.gd"),
    ("terminal-gun-scheletro", "src/core/contracts.gd"),
    # Passaggio di proprieta' di m2: il timeout del gate passa a `terminal-gun`
    # (piano sez. 3.3), che lo condivide con l'ex proprietario `-scheletro`.
    ("terminal-gun", "tools/gate.gd"),
    ("terminal-gun-scheletro", "tools/gate.gd"),
    ("terminal-gun-scheletro", "scenes/arena_main.tscn"),
    ("terminal-gun-arena", "scenes/arena_main.tscn"),
    # Passaggio di proprieta' di m2: l'HUD passa da -arena a -ui (piano sez. 4.1).
    ("terminal-gun-arena", "scenes/hud.tscn"),
    ("terminal-gun-ui", "scenes/hud.tscn"),
    ("terminal-gun-arena", "src/ui/**"),
    ("terminal-gun-ui", "src/ui/**"),
}

# Sudo: tre comandi, ancorati alla root, solo ACL e proprieta'.
SUDO_ALLOWED = [
    "sudo icacls . /grant *",
    "sudo takeown . /a",
    "sudo attrib . +r",
]

# Solo questi due agenti lo possono usare: sono i due che possiedono `.godot/`,
# l'unica cosa del progetto che un ACL rotto renderebbe irrecuperabile senza
# elevazione (regola 7.1). Gli altri quattro: sudo negato, e chiedono.
SUDO_HOLDERS = [VERTICE, "terminal-gun-scheletro"]

BASE_DEFAULT = "ask"  # nessuna regola combacia -> ask (docs/permissions)


class Fail(Exception):
    pass


# --------------------------------------------------------------------------
# Lettura del frontmatter. PyYAML non e' installato e non si installa: il
# blocco permissions e' una lista piatta di mappe a tre chiavi e si legge
# con venti righe.
# --------------------------------------------------------------------------

def parse_frontmatter(path):
    """Ritorna la lista di (action, resource, effect) del blocco permissions."""
    with io.open(path, "r", encoding="utf-8") as fh:
        text = fh.read()
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        raise Fail("frontmatter non aperto")
    close = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            close = i
            break
    if close is None:
        raise Fail("frontmatter non chiuso")

    rules = []
    cur = None
    in_perms = False
    for raw in lines[1:close]:
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        if not raw.startswith(" "):
            in_perms = raw.startswith("permissions:")
            cur = None
            continue
        if not in_perms:
            continue
        stripped = raw.strip()
        if stripped.startswith("- "):
            if cur is not None:
                rules.append(cur)
            cur = {}
            stripped = stripped[2:].strip()
        if cur is None:
            continue
        if ":" not in stripped:
            continue
        key, _, value = stripped.partition(":")
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        cur[key.strip()] = value
    if cur is not None:
        rules.append(cur)

    out = []
    for r in rules:
        if not all(k in r for k in ("action", "resource", "effect")):
            raise Fail("regola permissions incompleta: %r" % (r,))
        out.append((r["action"], r["resource"], r["effect"]))
    return out


def _regex(pattern):
    return "".join(
        ".*" if ch == "*" else "." if ch == "?" else re.escape(ch)
        for ch in pattern
    )


def match(pattern, value):
    """Le stesse regole di opencode (docs/permissions, sezione Matching):
    `*` zero o piu' caratteri, anche `/`; `?` esattamente uno; il resto
    letterale. E un pattern che finisce in " *" combacia anche col comando
    senza argomenti, cioe' `git status *` combacia anche `git status`.

    Case-insensitive: siamo su Windows e il matching lo e'. Il confronto e'
    in fullmatch, quindi il pattern copre TUTTO il valore, non un prefisso.
    """
    flags = re.IGNORECASE
    if re.fullmatch(_regex(pattern), value, flags):
        return True
    if pattern.endswith(" *"):
        return bool(re.fullmatch(_regex(pattern[:-2]), value, flags))
    return False


def resolve(rules, action, resource):
    """Effetto della regola che vince: opencode v2 usa l'ULTIMA che combacia."""
    effect = BASE_DEFAULT
    for act, res, eff in rules:
        if act == action and match(res, resource):
            effect = eff
    return effect


def allows(rules, action, resource):
    return resolve(rules, action, resource) == "allow"


def denies(rules, action, resource):
    return resolve(rules, action, resource) == "deny"


def load(agent):
    return parse_frontmatter(os.path.join(MIRROR, agent + ".md"))


# --------------------------------------------------------------------------
# I check. Ogniuno restituisce una lista di motivi di fallimento, cosi' la
# porta ne stampa quanti ha trovato invece di fermarsi al primo.
# --------------------------------------------------------------------------

def check_mirror_identity():
    bad = []
    for agent in ALL_AGENTS:
        mirror = os.path.join(MIRROR, agent + ".md")
        installed = os.path.join(INSTALLED, agent + ".md")
        for path in (mirror, installed):
            if not os.path.exists(path):
                bad.append("manca " + path)
        if bad:
            continue
        with io.open(mirror, "rb") as a, io.open(installed, "rb") as b:
            if a.read() != b.read():
                bad.append(
                    "%s: la copia nel repo e quella installata differiscono" % agent
                )
    return bad


def check_ask_fallback_declared():
    bad = []
    for agent in ALL_AGENTS:
        rules = load(agent)
        if not allows(rules, "question", "*"):
            bad.append(
                "%s: question non e' allow esplicito, quindi e' solo ereditato"
                % agent
            )
    return bad


def check_no_outbound_network():
    bad = []
    for agent in ALL_AGENTS:
        rules = load(agent)
        for action in ("webfetch", "websearch"):
            if allows(rules, action, "*"):
                bad.append("%s: %s * e' allow, la rete non e' materiale di progetto"
                           % (agent, action))
    return bad


def check_sudo():
    """L'allowlist e' minima per scelta: solo chi possiede `.godot/` puo'
    probabilmente incappare in un ACL rotto, e sono lui due (regola 7.1).
    Gli altri quattro agenti hanno sudo negato e, se un ACL li blocca,
    chiedono: e' esattamente il comportamento voluto."""
    bad = []
    for agent in ALL_AGENTS:
        rules = load(agent)
        if agent in SUDO_HOLDERS:
            for cmd in SUDO_ALLOWED:
                if not allows(rules, "shell", cmd):
                    bad.append("%s: manca l'allow sudo per '%s'" % (agent, cmd))
        else:
            for cmd in SUDO_ALLOWED:
                if not denies(rules, "shell", cmd):
                    bad.append("%s: sudo ACL NON e' deny per '%s'" % (agent, cmd))
        for cmd in (
            "sudo rm -rf ~",
            "sudo icacls C:/Windows /grant everyone:F",
            "sudo takeown /a",
            "sudo winget install somethingelse",
            "sudo bash -c whatever",
        ):
            if not denies(rules, "shell", cmd):
                bad.append("%s: '%s' NON e' deny" % (agent, cmd))
    return bad


def check_commit_ownership():
    bad = []
    # Il vertice e' l'unico che committa (regola 7.2): allow per lui, deny per
    # tutti. `git push` e' deny assoluto anche per il vertice.
    for agent in ALL_AGENTS:
        rules = load(agent)
        for cmd in ("git push", "git clean -fd", "git reset --hard"):
            if not denies(rules, "shell", cmd):
                bad.append("%s: '%s' NON e' deny" % (agent, cmd))
    for cmd in ("git add -A", "git commit -m x"):
        if not allows(load(VERTICE), "shell", cmd):
            bad.append("%s: '%s' NON e' allow (regola 7.2)" % (VERTICE, cmd))
    for agent in LEAVES:
        for cmd in ("git add -A", "git commit -m x"):
            if not denies(load(agent), "shell", cmd):
                bad.append("%s: '%s' NON e' deny" % (agent, cmd))
    return bad


def check_godot_ownership():
    bad = []
    # Regola 7.1: `.godot/` e' di scheletro. Il vertice lo puo' fare solo per
    # recupero di cache corrotta, ed e' dichiarato come tale nel piano.
    owners = ["terminal-gun-scheletro", VERTICE]
    for agent in ALL_AGENTS:
        rules = load(agent)
        for cmd in ("godot --headless --path . --import", "rm -rf .godot"):
            expected_allow = agent in owners
            got_allow = allows(rules, "shell", cmd)
            if got_allow != expected_allow:
                bad.append(
                    "%s: '%s' e' %s, atteso %s (regola 7.1)"
                    % (agent, cmd, "allow" if got_allow else "deny",
                       "allow" if expected_allow else "deny")
                )
    # La porta si esegue ovunque tranne che in assets (piano sezione 3).
    for agent in ALL_AGENTS:
        if agent == "terminal-gun-assets":
            continue
        if not allows(load(agent), "shell",
                      "godot --headless --path . --script tools/gate.gd"):
            bad.append("%s: non puo' eseguire la porta" % agent)
    if allows(load("terminal-gun-assets"), "shell", "godot --version"):
        bad.append("terminal-gun-assets: puo' eseguire godot, il piano lo vieta")
    return bad


def check_env_convention():
    """`. tools/env.sh && "$GODOT" ...` produce due risorse: lo scanner valuta
    ogni comando della composta. Senza l'allow del passo `.`, la convenzione
    scritta nel piano (sezioni 2 e 6) non e' eseguibile da nessun agente."""
    bad = []
    for agent in ALL_AGENTS:
        rules = load(agent)
        if not allows(rules, "shell", ". tools/env.sh"):
            bad.append("%s: la convenzione del piano non e' eseguibile" % agent)
        if allows(rules, "shell", ". ~/.bashrc"):
            bad.append("%s: puo' fare source di un file fuori progetto" % agent)
    return bad


def check_blender_path():
    """Debito di w1: `blender *` non combacia con l'invocazione reale, che e'
    il path assoluto che tools/env.sh mette in $BLENDER. Il piano lo dichiara,
    qui lo si verifica."""
    bad = []
    for agent in (VERTICE, "terminal-gun-assets"):
        rules = load(agent)
        if not allows(rules, "shell", BLENDER_RULE + " -b --python x.py"):
            bad.append(
                "%s: manca l'allow sul path assoluto di blender (which blender -> 1)"
                % agent
            )
    for agent in ALL_AGENTS:
        for act, res, eff in load(agent):
            if eff != "allow":
                continue
            if res == "blender *":
                bad.append("%s: 'blender *' e' un allow che non combacia nulla" % agent)
    return bad


def check_no_escape():
    bad = []
    for agent in ALL_AGENTS:
        rules = load(agent)
        for cmd in (
            "rm -rf ~",
            "rm -rf /c/Users/bisco",
            "cat ~/.ssh/id_rsa",
            "grep -r password C:/Users/bisco",
            "find ~ -name id_rsa",
            "find C:/ -name *.pem",
            "find . -delete",
            "touch src/sim/horde.gd",
        ):
            if not denies(rules, "shell", cmd):
                bad.append("%s: '%s' NON e' deny" % (agent, cmd))
    return bad


def check_edit_scope():
    bad = []
    for agent in ALL_AGENTS:
        rules = load(agent)
        declared = sorted(SCOPE[agent])
        found = sorted(
            res for act, res, eff in rules if act == "edit" and eff == "allow"
        )
        if found != declared:
            bad.append(
                "%s: scope dei permessi %r != scope dichiarato %r"
                % (agent, found, declared)
            )
    # Nessun agente puo' scrivere i propri permessi: il mirror e' fuori scope.
    for agent in ALL_AGENTS:
        rules = load(agent)
        if allows(rules, "edit", ".opencode/agents/terminal-gun.md"):
            bad.append("%s: puo' scrivere i propri permessi" % agent)
    return bad


def check_no_file_overlap():
    """Un file, un proprietario (regola 1). Le sovrapposizioni dichiarate nel
    piano non sono un conflitto, quindi sono elencate in DECLARED_OVERLAP."""
    owners = {}
    for agent, paths in SCOPE.items():
        for path in paths:
            owners.setdefault(path, []).append(agent)
    for path, who in sorted(owners.items()):
        if len(who) > 1:
            for a in who:
                for b in who:
                    if a < b and (a, path) not in DECLARED_OVERLAP:
                        bad_key = "%s|%s|%s" % (a, b, path)
                        if bad_key not in _seen_overlap:
                            _seen_overlap.add(bad_key)
                            _overlap.append("%s e %s scrivono %s" % (a, b, path))
    return _overlap


_seen_overlap = set()
_overlap = []


def check_scope_in_piano():
    """Il piano e i permessi devono dire la stessa cosa: un path di scope che il
    piano non nomina piu' e' drift, e non e' un problema di scrittura, e' che il
    piano non e' piu' la fonte di verita.

    Il confronto non e' letterale perche' il piano scrive `src/core/` dove il
    permesso scrive `src/core/**`: si accetta che il piano nomini il path, o il
    path senza wildcard, o la sua directory. Stringa piu' corta, tolleranza
    dichiarata invece di un falso rosso che nessuno legge."""
    bad = []
    if not os.path.exists(PIANO):
        return ["manca docs/piramide/piano.md"]
    with io.open(PIANO, "r", encoding="utf-8") as fh:
        text = fh.read()
    for agent in ALL_AGENTS:
        for path in SCOPE[agent]:
            candidates = {path, path.replace("/**", "/"), path.replace("/**", "")}
            if "/" in path:
                candidates.add(path.rsplit("/", 1)[0] + "/")
            if not any(c and c in text for c in candidates):
                bad.append("il piano non nomina %s (scope di %s)" % (path, agent))
    for agent in ALL_AGENTS:
        if agent not in text:
            bad.append("il piano non nomina l'agente %s" % agent)
    for marker in ("check_perms.py", "sudo"):
        if marker not in text:
            bad.append("il piano non dichiara %s" % marker)
    return bad


def check_no_absolute_paths():
    """Niente path assoluti di macchina nei permessi (regola 7.5), con una
    sola eccezione dichiarata: il path di blender."""
    bad = []
    for agent in ALL_AGENTS:
        for act, res, eff in load(agent):
            if eff != "allow":
                continue
            if res == BLENDER_RULE:
                continue
            if re.search(r"[A-Za-z]:[\\/]", res) or res.startswith("/"):
                bad.append("%s: path assoluto in un allow: %s" % (agent, res))
    return bad


def check_subagent_ownership():
    bad = []
    for agent in LEAVES:
        if allows(load(agent), "subagent", "terminal-gun-orda"):
            bad.append("%s: una foglia puo' lanciare un'altra foglia" % agent)
    rules = load(VERTICE)
    for target in LEAVES:
        if not allows(rules, "subagent", target):
            bad.append("%s: il vertice non puo' lanciare %s" % (VERTICE, target))
    if allows(rules, "subagent", "esecutore"):
        bad.append(
            "%s: puo' lanciare esecutore, che ha action '*' allow e perde "
            "la regola 7.4 (debito gia' dichiarato in sezione 8)" % VERTICE
        )
    return bad


def check_secrets_denied():
    bad = []
    for agent in ALL_AGENTS:
        rules = load(agent)
        for path in ("~/.ssh/id_rsa", "$HOME/.aws/credentials",
                     "~/.local/share/opencode/opencode.db"):
            if not denies(rules, "read", path):
                bad.append("%s: read %s NON e' deny" % (agent, path))
    return bad


CHECKS = [
    ("perm_mirror", check_mirror_identity),
    ("perm_ask", check_ask_fallback_declared),
    ("perm_secrets", check_secrets_denied),
    ("perm_network", check_no_outbound_network),
    ("perm_sudo", check_sudo),
    ("perm_commit", check_commit_ownership),
    ("perm_godot", check_godot_ownership),
    ("perm_env", check_env_convention),
    ("perm_blender", check_blender_path),
    ("perm_escape", check_no_escape),
    ("perm_scope", check_edit_scope),
    ("perm_overlap", check_no_file_overlap),
    ("perm_piano", check_scope_in_piano),
    ("perm_absolute", check_no_absolute_paths),
    ("perm_subagent", check_subagent_ownership),
]


def missing_agent_files():
    """Agenti dichiarati in `LEAVES`/`ALL_AGENTS` ma senza file su disco.

    Il perche' esiste come precondizione e non dentro `perm_mirror`: senza un
    file, ogni check che chiama `load(agent)` solleva `FileNotFoundError` e la
    porta stampava **tredici** `controllore rotto`, che nascondevano l'unica
    causa vera. Una porta che non sa dire *perche'* e' rotta e' peggio di una
    porta che non gira: qui si dice, e si dice una volta sola.
    """
    missing = []
    for agent in ALL_AGENTS:
        for label, base in (("mirror", MIRROR), ("installato", INSTALLED)):
            path = os.path.join(base, agent + ".md")
            if not os.path.exists(path):
                missing.append((agent, label, path))
    return missing


def main():
    missing = missing_agent_files()
    if missing:
        for agent, label, path in missing:
            sys.stdout.write(
                "FAIL perm_install: manca il file di %s (%s): %s\n"
                % (agent, label, path)
            )
        sys.stdout.write(
            "FAIL perm_install: un file di agente si installa a mano, in due\n"
            "  posti: .opencode/agents/ (mirror, sorgente di verita') e\n"
            "  ~/.config/opencode/agents/ (installazione). Poi riavvia opencode:\n"
            "  i permessi si caricano all'avvio (piano sez. 10).\n"
            "  Il vertice NON puo' farlo: ha `edit: * deny` su quel path\n"
            "  (piano sez. 11.5).\n"
        )
        sys.stdout.write("PERM: 0/%d\n" % len(CHECKS))
        sys.exit(1)

    total = len(CHECKS)
    passed = 0
    for name, fn in CHECKS:
        try:
            problems = fn()
        except Fail as exc:
            problems = [str(exc)]
        except Exception as exc:  # noqa: BLE001 - una porta non deve crashare
            problems = ["controllore rotto: %r" % (exc,)]
        if problems:
            for reason in problems:
                sys.stdout.write("FAIL %s: %s\n" % (name, reason))
        else:
            sys.stdout.write("PASS %s\n" % name)
            passed += 1
    sys.stdout.write("PERM: %d/%d\n" % (passed, total))
    # GATE rifiuta 0/0: il falso verde peggiore e' nessun check eseguito.
    if total == 0:
        sys.stdout.write("FAIL perm_zero: nessun check definito\n")
        sys.exit(1)
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()