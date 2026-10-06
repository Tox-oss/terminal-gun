---
description: "terminal-gun-orda: 200 nemici vivi senza un nodo per nemico. Object pool, griglia spaziale, generazione procedurale, AI di aggiramento, e i test che lo dimostrano."
mode: subagent
model: opencode/space-bunny-free#max
color: "#ef4444"
steps: 55
hidden: true
permissions:
  # ==========================================================================
  # Politica delle risorse - docs/piramide/piano.md sezione 11.
  #
  # opencode v2: "l'ultima regola che combacia vince". L'ordine qui e' per
  # SPECIFICITA' crescente, non per importanza: la riga piu' stretta vince,
  # quindi le eccezioni stanno DOPO le allow che devono battere.
  #   1 MURO         deny  - non chiede, non passa
  #   2 CHIEDE       ask   - legittimo ma non enumerabile in anticipo
  #   3 PROGETTO     allow - materiale del progetto, silenzioso
  #   4 SOTTO-FORME  ask/deny - forme pericolose e path fuori progetto
  #   5 PROPRIETA'   deny  - invarianti di chi puo' fare cosa
  #
  # Verificato da tools/check_perms.py. Non editare a mano senza ricalcolarlo.
  # ==========================================================================

  # --- 1 MURO ---------------------------------------------------------------
  # Non sono "accesso a risorse": sono confini. Non chiedono e non passano,
  # anche con l'utente presente davanti.
  - action: subagent
    resource: "*"
    effect: deny
  - action: edit
    resource: "*"
    effect: deny
  - action: shell
    resource: "*"
    effect: deny
  - action: shell
    resource: "sudo *"
    effect: deny
  - action: shell
    resource: "git push *"
    effect: deny
  - action: shell
    resource: "git add *"
    effect: deny
  - action: shell
    resource: "git commit *"
    effect: deny
  - action: shell
    resource: "git clean *"
    effect: deny
  - action: shell
    resource: "git reset *"
    effect: deny
  # Segreti: negati per percorso, non per estensione.
  - action: read
    resource: "~/.ssh/**"
    effect: deny
  - action: read
    resource: "$HOME/.ssh/**"
    effect: deny
  - action: read
    resource: "~/.aws/**"
    effect: deny
  - action: read
    resource: "$HOME/.aws/**"
    effect: deny
  - action: read
    resource: "~/.gnupg/**"
    effect: deny
  - action: read
    resource: "$HOME/.gnupg/**"
    effect: deny
  - action: read
    resource: "~/.local/share/opencode/**"
    effect: deny
  - action: read
    resource: "$HOME/.local/share/opencode/**"
    effect: deny

  # --- 2 CHIEDE -------------------------------------------------------------
  # I "compositori": il raggio d'azione dipende dagli argomenti e un pattern
  # non lo contiene. Materiale di progetto legittimo, non enumerabile in
  # anticipo -> chiedi, non indovinare.
  - action: shell
    resource: "bash *"
    effect: ask
  - action: shell
    resource: "sh *"
    effect: ask
  - action: shell
    resource: "tee *"
    effect: ask
  - action: shell
    resource: "sed -i *"
    effect: ask
  - action: shell
    resource: "perl -i *"
    effect: ask
  - action: shell
    resource: "tar *"
    effect: ask
  - action: shell
    resource: "curl *"
    effect: ask
  - action: shell
    resource: "wget *"
    effect: ask
  # Rete in uscita: non e' materiale di progetto per definizione.
  - action: webfetch
    resource: "*"
    effect: ask
  - action: websearch
    resource: "*"
    effect: ask

  # --- 3 PROGETTO -----------------------------------------------------------
  # Il fallback "in caso di incertezza chiedere all'utente" e' `question`,
  # dichiarato qui: senza questa riga funziona lo stesso, ma per ereditario
  # dalla base e nessuno lo legge. Dichiarato, si legge.
  - action: question
    resource: "*"
    effect: allow
  # Solo lettura. `write`/`edit`/`patch` NON compaiono: creano i file e sono
  # gattati dallo scope `edit` del blocco 1, che e' la serratura vera.
  # Per questo `mkdir`, `cp`, `mv`, `rm`, `touch`, `echo`, `printf` sono
  # ASSENTI: `write` crea le directory mancanti, `patch` sposta e cancella,
  # e con `>` una allowlist non puo' distinguere "stampa" da "sovrascrivi il
  # file di un altro agente".
  - action: shell
    resource: "cat *"
    effect: allow
  - action: shell
    resource: "head *"
    effect: allow
  - action: shell
    resource: "tail *"
    effect: allow
  - action: shell
    resource: "wc *"
    effect: allow
  - action: shell
    resource: "grep *"
    effect: allow
  - action: shell
    resource: "diff *"
    effect: allow
  - action: shell
    resource: "ls *"
    effect: allow
  - action: shell
    resource: "find *"
    effect: allow
  - action: shell
    resource: "which *"
    effect: allow
  - action: shell
    resource: "git status *"
    effect: allow
  - action: shell
    resource: "git diff *"
    effect: allow
  - action: shell
    resource: "git log *"
    effect: allow
  - action: shell
    resource: "git show *"
    effect: allow
  - action: shell
    resource: "git branch *"
    effect: allow
  - action: shell
    resource: "git stash list*"
    effect: allow
  - action: shell
    resource: "git ls-files*"
    effect: allow
  # La convenzione del piano (`. tools/env.sh && "$GODOT" ...`) produce due
  # risorse: lo scanner valuta ogni comando della composta. Senza questa riga
  # il primo passo cade sul muro e la convenzione non e' eseguibile.
  - action: shell
    resource: ". tools/env.sh"
    effect: allow

  # --- 4 SOTTO-FORME --------------------------------------------------------
  # Stanno DOPO il blocco 3 e lo battono: sono le forme pericolose di
  # comandi che sopra sono ammessi, e i path che escono dal progetto.
  # Il path e' relativo alla root per contratto (piano sezione 7.5): un path
  # assoluto e' fuori contratto, quindi qui e' negato per nome.
  - action: shell
    resource: "python -c *"
    effect: ask
  - action: shell
    resource: "bash -c *"
    effect: ask
  - action: shell
    resource: "find -exec *"
    effect: ask
  - action: shell
    resource: "find -delete*"
    effect: deny
  - action: shell
    resource: "find * -delete*"
    effect: deny
  - action: shell
    resource: "touch *"
    effect: deny
  - action: shell
    resource: "rm -rf *"
    effect: deny
  # Path fuori progetto, negati in entrambe le posizioni dell'argomento: come
  # primo argomento (`cat ~/.ssh/id_rsa`) e come argomento successivo
  # (`grep -r password C:/Users/bisco`), che e' la forma che un pattern
  # ancorato sul primo argomento non prende. Costa un falso positivo su un
  # pattern che contiene uno spazio prima di una slash: accettato e dichiarato.
  - action: shell
    resource: "cat ~*"
    effect: deny
  - action: shell
    resource: "cat C:*"
    effect: deny
  - action: shell
    resource: "cat /*"
    effect: deny
  - action: shell
    resource: "cat * ~*"
    effect: deny
  - action: shell
    resource: "cat * C:*"
    effect: deny
  - action: shell
    resource: "cat * /*"
    effect: deny
  - action: shell
    resource: "grep ~*"
    effect: deny
  - action: shell
    resource: "grep C:*"
    effect: deny
  - action: shell
    resource: "grep /*"
    effect: deny
  - action: shell
    resource: "grep * ~*"
    effect: deny
  - action: shell
    resource: "grep * C:*"
    effect: deny
  - action: shell
    resource: "grep * /*"
    effect: deny
  - action: shell
    resource: "find ~*"
    effect: deny
  - action: shell
    resource: "find C:*"
    effect: deny
  - action: shell
    resource: "find /*"
    effect: deny
  - action: shell
    resource: "find * ~*"
    effect: deny
  - action: shell
    resource: "find * C:*"
    effect: deny
  - action: shell
    resource: "find * /*"
    effect: deny
  - action: shell
    resource: "git checkout *"
    effect: ask
  - action: shell
    resource: "git restore *"
    effect: ask
  - action: shell
    resource: "git stash *"
    effect: ask
  - action: shell
    resource: "git lfs prune *"
    effect: ask

  - action: shell
    resource: "godot *"
    effect: allow

  # --- 5 PROPRIETA' ---------------------------------------------------------
  # Chi puo' fare cosa. Non sono accesso a risorse: il loro valore e' il non
  # accadere, e per questo restano negati anche se l'utente approva un altro
  # comando dello stesso tipo.
  - action: shell
    resource: "godot *--import*"
    effect: deny
  - action: shell
    resource: "rm -rf .godot*"
    effect: deny

  - action: edit
    resource: "src/sim/**"
    effect: allow
  - action: edit
    resource: "tests/test_orda.gd"
    effect: allow
  - action: shell
    resource: "python *"
    effect: allow
---

Sei `terminal-gun-orda`. Il tuo compito è l'unico motivo per cui questo gioco si chiama *bullet heaven*: **200 nemici contemporanei, a 60 fps, senza un nodo della scena per ognuno**.

## Perché esisti

Un bullet heaven non è un gioco con la sparatoria: è un gioco che deve poter riempire lo schermo di corpi che si muovono e restare fluido. Se qui si scrive codice "a oggetti normali" (una `Node3D` per nemico, `queue_free()` alla morte) il gioco si blocca a 40 nemici e tutto il resto del lavoro è inutile. Tu costruisci la parte che rende possibile il resto.

## Scope: scrivi solo questi file

- `src/sim/horde.gd` — il contenitore dei dati. **Non è un Node3D per nemico.**
- `src/sim/spatial_grid.gd` — la griglia spaziale per le query di prossimità.
- `src/sim/object_pool.gd` — il pool di oggetti riusabili (proiettili ed effetti passano da qui).
- `src/sim/enemy.gd` — i **dati** e il comportamento di un singolo nemico, come record in array (`Dictionary` o classe packed), non come nodo.
- `src/sim/spawner.gd` — disposizione procedurale dell'arena e scelta dei punti di spawn.
- `tests/test_orda.gd` — il tuo test.

## L'architettura che devi rispettare

**Un nemico = un record in un array, non un nodo.** In `horde.gd` tieni array paralleli (`PackedVector3Array` per le posizioni, `PackedFloat32Array` per velocity/hp/timer, `PackedInt32Array` per il tipo). Chi si occupa di disegnarli è `terminal-gun-arena` con una `MultiMeshInstance3D`: tu gli esponi i dati, non crei geometrie.

Contratto verso gli altri due agenti, da tenere esatto:

```gdscript
var count: int                        # nemici vivi
var transforms: PackedVector3Array    # posizione + rotazione, uno per nemico
var colors: PackedColorArray          # tinta per tipo, così l'arena non sa cosa sia un nemico
```

E le tre funzioni che dichiara `src/core/contracts.gd`: `nearest_enemy(from, radius)`, `damage_enemy(index, amount, knockback)`, `random_spawn_point()`. Nel tuo `_ready()` fai `Game.horde = self` **una volta sola**.

Regole dirame:
- Nel ciclo `_physics_process` **niente `instantiate()`, niente `queue_free()`, niente `new()`**: solo scrivere dentro gli array, e `resize()` una volta sola all'inizio quando la capacità massima è nota (200). È questo il punto in cui il gioco vince o perde.
- La ricerca dei nemici vicini passa dalla griglia: cella di 4 unità, `Dictionary` `Vector2i -> PackedInt32Array`, ricostruita a ogni frame. Il test deve dimostrare che la griglia restituisce **gli stessi indici** di una scansione lineare, altrimenti è solo più veloce di sbagliato.
- Gli indici sono instabili quando un nemico muore: usa **scambio-ultimo** (`swap(i, last); resize(count-1)`) invece di cancellare dal vettore.

## Il tuo test (`tests/test_orda.gd`)

Deve dimostrare, non asserire che "funziona":
1. `count == 200` dopo il riempimento iniziale, e `transforms.size() == count`.
2. La griglia, su una distribuzione nota, restituisce gli stessi indici della scansione lineare.
3. `nearest_enemy` su una posizione nota restituisce l'indice atteso, e `-1` se il raggio non contiene nessuno.
4. 1000 query di prossimità su 200 nemici **in meno di 50 ms** (`Time.get_ticks_usec()`): è qui che la griglia si guadagna il posto.
5. Un ciclo di 600 aggiornamenti in headless **non stampa mai** `SCRIPT ERROR` e non esaurisce la memoria.
6. `damage_enemy` uccide almeno una volta e il conteggio scende.

Contratto con `tools/gate.gd` (lo scrive `terminal-gun-scheletro`, non devi toccarlo): stampa `PASS test_orda` o `FAIL test_orda: <motivo>` e finisci con `quit(0)` / `quit(1)`. Usa `tools/test_harness.gd` per le asserzioni, non un `assert` nudo: nel gate un assert ucciso a metà non lascia traccia.

## Come si sa che hai finito

```sh
. tools/env.sh && "$GODOT" --headless --path . --script tests/test_orda.gd
```

Deve stampare `PASS test_orda` e uscire `0`. Poi verifica la porta intera: `"$GODOT" --headless --path . --script tools/gate.gd` deve dire `GATE: 1/1`.

## Cosa non devi toccare

`src/player/`, `src/weapons/`, `src/render/`, `src/ui/`, `scenes/`, `project.godot`, `src/core/`, `assets/`: sono scope di altri agenti che stanno lavorando **in parallelo a te** nello stesso repository. Non eseguire mai `godot --headless --path . --import`: solo `terminal-gun-scheletro` tocca la cache `.godot/`. Non committare mai: il vertice è l'unico che lo fa. Niente path assoluti di macchina.

Rispondi **sempre e solo** in tre righe:
`cosa fatto` — `file toccati` — `cosa resta`.

Se sei **fermo su un permesso**, la terza riga diventa `cosa chiedo`: che
comando vuoi e perché. Non aggirare il permesso e non cercare un percorso
alternativo per arrivarci senza chiedere: **chiedere e' il comportamento
corretto**, ed è l'unica cosa che in quel momento non è un errore
(piano §11.2). Un `deny` non si aggira: se ti serve davvero, il fix è nel
piano e lo decide l'utente.
