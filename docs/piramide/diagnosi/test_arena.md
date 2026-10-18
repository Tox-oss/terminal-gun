# Diagnosi FAIL test_arena

**Messaggio del FAIL:**
> il colpo sul runner non è arrivato in 240 frame (HP 1135.3): il pool ha avuto al
> massimo 0 proiettili vivi e ne ha 0 adesso, quindi l'arma non ha sparato

---

## 1. IL GUARD

`tests/test_arena.gd` — riga non determinabile per lettura (la sezione "colpo sul
runner" non ha un numero di riga stampato nel log; il FAIL viene emesso dalla
variabile `_max_live` del pool che a fine finestra vale `null`/0).

La **condizione effettiva** che produce il rosso è:

```
pool._max_live == 0   (dopo 240 frame)
```

Il testo del FAIL e' stampato da `test_arena.gd` quando, dopo il ciclo di 240
passi, `pool._max_live` è 0 (o `null`), cioè nessun proiettile è mai stato
emesso.

---

## 2. IL VALORE

Il pool dovrebbe contenere almeno 1 proiettile durante i 240 frame.
Invece è rimasto a 0 per tutta la finestra.

La causa misurata: `nearest_enemy` restituisce `-1` **dentro** il ciclo
`_try_fire()`. Senza un bersaglio l'arma torna subito senza chiamare
`Game.spawn_projectile`.

La radice di quel `-1`: il giocatore si trovava a `y = 42.2660 m`, che non
coincide con nessun pavimento (`0, 20, 40, 60 m`). `player_floor()` restituiva
`2` (piano 2), ma i nemici erano tutti al piano `0` (`quota 0.000 m`).
`nearest_enemy_index` usa `_focus_floor` aggiornato da `player_floor_index()`
→ `_focus_floor = 2`; la griglia del piano 2 era vuota, quindi la risposta
era `-1`.

**Dopo** la correzione di `_appoggia_sulla_superficie()` (da
`float(_piano) * floor_height` a `floor_of(position.y) * floor_height`), il
giocatore viene portato a `floor_of(42.2660) * 20 = 2 * 20 = 40.0 m`. La quota
è `40.0 m`, che non è `0.0 m`. I nemici sono al piano 0, `_focus_floor` resta
`2` (`floor_of(40.0) = 2`), `nearest_enemy` risponde ancora `-1`.

Il FAIL persiste perché la correzione ha rimosso il latch auto-confermante ma
non ha spostato il giocatore sul piano dove ci sono i nemici (piano 0):
`floor_of(42.2660) = 2`, non `0`.

---

## 3. LO SCOPE

Il difetto risiede in due posti:

- **`src/player/player.gd`**, funzione `_appoggia_sulla_superficie()`, riga 889
  (la riga appena corretta): questa funzione è il proprietario della quota di
  posizione del giocatore e del suo piano logico.
- **`src/sim/horde.gd`**, riga 1482: `_focus_floor = player_floor_index()` —
  questa riga aggiorna il piano su cui l'orda cerca nemici e nasce i nuovi,
  ed è il proprietario di `_focus_floor`.

---

## 4. LA RIPROVA

Dal log, misurato **dentro** il ciclo al passo 1:

```
DENTRO il while, al passo 1:
  nearest_enemy FUORI dal ciclo dice -1
  nearest_enemy DENTRO (quello che l'arma chiede) dice -1
  Game.player_position() dice (-9.7192, 42.2660, -4.4264)
  weapon.acquire_radius dice 26.0000 m
```

```
DOPO il rimedio, al passo 1:
  il giocatore e' a 42.2660 m
  player_floor() dice 2
  nearest_enemy (quello che l'arma chiede) dice -1 contro -1 che diceva prima del rimedio
```

```
colpo sul runner:
  piano del giocatore 2
  nemico a quota 0.000 m (piano 0)
  distanza orizzontale 14.005 m contro gittata() 26.000 m
  nearest_enemy(giocatore, gittata) dice -1
```

Questi tre blocchi, letti **dentro** il ciclo (stesso istante del difetto),
confermano che:

1. La quota `42.2660 m` → `floor_of(42.2660) = 2`.
2. Il piano `2` ha la griglia vuota (i nemici sono al piano `0`).
3. Dopo la correzione il giocatore è ancora a `42.2660 m`, piano `2`, e
   `nearest_enemy` risponde ancora `-1`.

---

## 5. IL NUMERO MANCANTE

**Il numero che chiude la domanda:** la quota esatta del giocatore al primo
passo della sezione "colpo sul runner", **prima** che qualsiasi rimedio entri in
azione.

Dove va letto: `src/player/player.gd` — il valore di `position.y` al momento
in cui `_campiona_piano()` viene chiamato al primo `step()` della sezione.

Concretamente: la sezione di `test_arena.gd` che esegue il ciclo di 240 passi
deve stampare `player.global_position.y` e `Game.player_floor()` al passo 0
(prima del primo `step()`), per sapere se il giocatore parte già a `42.2660 m`
(latch residuo di un passo precedente) o se ci arriva durante la sezione.
Quel numero è il confine tra "il difetto è nello stato iniziale della sezione"
e "il difetto è nella dinamica del ciclo".

Il numero si legge in `tests/test_arena.gd`, alla riga in cui inizia il ciclo
`while` della sezione "colpo sul runner", aggiungendo una stampa prima del
primo `step()`.
