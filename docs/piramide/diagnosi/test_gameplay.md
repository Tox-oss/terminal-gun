# Diagnosi FAIL test_gameplay

**Messaggio del FAIL:**
> morte: l'orda deve avere nemici vivi, altrimenti la finestra non misura niente

---

## 1. IL GUARD

`tests/test_gameplay.gd:2449`

```gdscript
if not h.check(hd != null and int(hd.get("count")) > 0,
    "morte: l'orda deve avere nemici vivi, altrimenti la finestra non misura niente"):
    return
```

La condizione che produce il FAIL è:

```
hd != null  AND  int(hd.get("count")) > 0
```

È **falsa**: la condizione fallisce perché `int(hd.get("count")) > 0` è falsa
(l'orda ha `count == 0`), oppure perché `hd == null`.

---

## 2. IL VALORE

`hd` è `game.horde`, letto all'inizio di `_fuoco_dopo_morte()`:

```gdscript
var hd = game.horde
```

`game.horde` punta all'orda installata da `_restart_run()`. Quella funzione
costruisce un'istanza di `src/sim/horde.gd` con `(scr as Script).new()` e la
aggiunge a `root` via `root.add_child(horde_vera)`.

Prima della correzione di `_libera()`, alcune sezioni che montano
`scenes/arena_main.tscn` usavano `queue_free()`. In un `--script` (un solo
frame motore), `queue_free()` non libera il nodo nello stesso frame: il nodo
rimane in albero, il `_ready()` dell'arena riregistra `game.horde` con
l'orda della scena fuggita, e `_fuoco_dopo_morte()` trova un'orda della scena
precedente — non quella costruita da `_restart_run()`.

**Dopo** la correzione (`remove_child` + `free()`), la scena viene liberata
davvero nello stesso frame. Ma il log mostra:

```
| setup: `player` true, `player.weapon` true, `weapon` false, `pool` false,
|   e i nodi chiamati `Weapon` sotto il giocatore sono 1.
|   Con uno dei tre a null `_process()` non entra in nessuna sezione e
|   il FAIL e' l'unico numero che esce: e' un rosso che ne copre molti e
|   non lo dichiara
```

Questo dice che `weapon` e `pool` sono `null` nel setup di `test_gameplay.gd`.
Se il setup non riesce ad agganciare l'arma, la sezione `_fuoco_dopo_morte()`
viene raggiunta con uno stato parziale e l'orda — che dipende dall'arma per
il restart — potrebbe avere `count == 0`.

La causa più probabile, dato il setup parziale (`weapon false, pool false`):
il nodo `Weapon` esiste fisicamente nell'albero (1 nodo trovato) ma il
riferimento interno `player.weapon` non è stato agganciato, o lo è stato a
un'istanza poi liberata. Senza `weapon` valido, `_restart_run()` chiama
`player.restart_run()` che può non ripopolare correttamente l'orda, lasciando
`count == 0`.

**Il valore impossibile:** `int(hd.get("count")) > 0` dovrebbe essere `true`
dopo un `restart_run()` che porta l'onda 1 a 100 nemici. È impossibile che sia
`0` a meno che il restart non abbia costruito l'orda, o che `game.horde` punti
a un'istanza svuotata o sostituita da una scena fuggita.

---

## 3. LO SCOPE

- **`tests/test_gameplay.gd`**, riga 2449: proprietario del guard.
- **`tests/test_gameplay.gd`**, funzione `_restart_run()`, a partire da riga
  2026: costruisce `horde_vera` e la registra su `game.horde`.
- **`src/sim/horde.gd`**, `_ready()` riga 692: chiama `_build()` e
  `_register()` — `_register()` scrive `game.horde = self` (riga 1258 ca.),
  sovrascritto da chiunque arrivi nell'albero dopo.
- **`src/render/arena.gd`** e ogni altro nodo montato da `scenes/arena_main.tscn`
  che registra `game.horde`: se una scena precedente non è stata liberata con
  `remove_child + free()`, il suo `_ready()` sovrascrive `game.horde` con
  l'orda della scena fuggita.

---

## 4. LA RIPROVA

Dal log:

```
| setup: `player` true, `player.weapon` true, `weapon` false, `pool` false,
|   e i nodi chiamati `Weapon` sotto il giocatore sono 1.
```

Questo è il numero misurato dallo stesso test. `weapon false` e `pool false`
nel setup significa che la sezione non ha trovato i riferimenti corretti, e
**non che i nodi non ci siano** (il nodo `Weapon` c'è). Il problema è nel
binding, non nella costruzione.

Dal log delle sezioni precedenti:

```
| SCRIPT ERROR: Left operand of 'is' is a previously freed instance.
| at: _player (res://src/render/arena.gd:895)
```

Questo errore appare **dopo** che la scena viene liberata: `arena.gd` continua
a girare nel suo `_process()` perché il nodo non è stato fermato prima del
`free()`. Non è la causa del FAIL corrente, ma conferma che il ciclo di vita
delle scene montate da `test_gameplay.gd` ha ancora artefatti.

---

## 5. IL NUMERO MANCANTE

**Il numero che chiude la domanda:** il valore di `game.horde` (come percorso
del nodo) **all'inizio esatto di `_fuoco_dopo_morte()`**, cioè dopo
`_restart_run()` e prima del check.

Dove va letto: `tests/test_gameplay.gd`, alla riga immediatamente dopo
`var hd = game.horde` (riga ~2447), stampando:

```gdscript
print("hd = %s, count = %s" % [str(hd), str(hd.get("count") if hd != null else "null")])
```

Questo numero dice se `game.horde` punta all'orda di `_restart_run()` o a
un'istanza di una scena precedente (o è `null`). Senza questo numero non è
possibile distinguere tra "il restart non popola l'orda" e "una scena fuggita
sovrascrive `game.horde` dopo il restart".
