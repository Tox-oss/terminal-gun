# Diagnosi FAIL test_progression

**Messaggio del FAIL:**
> l'onda 1 si chiude e l'onda successiva parte (dopo 40000 passi, 42 uccisioni)

---

## 1. IL GUARD

`tests/test_progression.gd:641` (riga che stampa il FAIL nel flusso
fail-fast; il verdetto è emesso da `h.check`):

```gdscript
h.check(attraversato,
    "l'onda %d si chiude e l'onda successiva parte (dopo %d passi, %d uccisioni)"
    % [wave0, guard, int(prog.kills)])
```

La condizione che produce il FAIL è:

```
attraversato == false
```

`attraversato` viene impostato a `true` solo quando `int(horde.wave) != wave0`
all'interno del ciclo `while guard < TETTO_PASSI`. Dopo 40000 passi (TETTO_PASSI)
è rimasto `false`: l'onda 1 non è mai passata all'onda 2.

---

## 2. IL VALORE

`horde.wave` dovrebbe diventare `wave0 + 1 = 2` prima che il ciclo esaurisca
i 40000 passi. Non è successo.

Il log dice:

```
| progression: l'onda 1 si e' chiusa in 40000 passi (666.67 s) per 200 uccisioni,
|   con il campo a 76 vivi e Run.SPAWN_RATE = 2.0/s
| anche: il contatore d'onda e' salito di uno: atteso 2, ottenuto 1
| anche: l'onda 1 si e' chiusa con 42 uccisioni reali, non con una barra azzerata a mano
```

La prima riga è **la stampa di misura dentro il ciclo**, scritta quando
`horde.wave` è già passato a 2 (stampa `progression: onda 1 -> 1`... — ma
poi `h.eq(int(horde.wave), wave0 + 1, ...)` ha trovato ancora `1`). La
seconda è il verdetto: `ottenuto 1`, cioè l'onda non è salita.

Interpretazione: il ciclo ha raggiunto 42 uccisioni prima che il giocatore
morisse (`hp = 0.000` al passo 958, cioè a 15.97 s), poi `horde.step()` ha
continuato a essere chiamato ma lo stato `game_over` lo fa tornare subito senza
aggiornare `wave`. Il confine delle 200 uccisioni non è stato raggiunto
**prima della morte del giocatore**.

Il numero chiave: `42 uccisioni` contro le `200 necessarie` per chiudere
l'onda 1. A `2.567 uccisioni/s` (ritmo misurato da `_ritmi`) servono
`~78 s` per 200 uccisioni; il giocatore è morto a `15.97 s`.

**Cosa è impossibile:** `attraversato == true` con 42 uccisioni su 200
necessarie. Non è possibile che l'onda si chiuda prima del suo `wave_total`.

**Cosa è possibile:** il difetto è che il giocatore muore troppo presto (la
difficoltà del ciclo di test è troppo alta per questo segmento), oppure che
il ritmo di uccisioni effettivo è troppo basso per sopravvivere fino alle 200.
I numeri del log indicano la prima: `colpi >> uccisioni` (935 colpi, 42
uccisioni), quindi i colpi arrivano ma non bastano per abbattere i nemici in
tempo prima che la vita scenda a zero.

---

## 3. LO SCOPE

- **`tests/test_progression.gd`**, funzione `_xp_al_cambio_onda()`,
  riga 641: proprietario del guard `h.check(attraversato, ...)`.
- **`src/sim/horde.gd`**: il campo `wave` e `wave_total()` sono di -orda;
  il cambio d'onda avviene dentro `horde.step()`.
- **`src/sim/run.gd`** (o equivalente): `Run.WAVE_BASE = 200` e `SPAWN_RATE =
  2.0/s` determinano quante uccisioni servono e a che ritmo i nemici
  rispawnano.

---

## 4. LA RIPROVA

Dal log, misurato **dentro** il ciclo (`_ritmi`):

```
| test_progression: m12, tre ritmi nella stessa finestra di 30.0 s (1800 passi,
|   fire_interval 0.050 s):
|   bersagli 1750 (58.333/s), colpi 438 (14.600/s), uccisioni 77 (2.5667/s).
```

```
| test_progression: m12, i quattro numeri del run, sulla scena vera.
|   1) colpi partiti nel run: 935 (contro 41 uccisioni)
|   2) la barra si azzera al passo 958, cioe' a 15.97 s, con hp 0.000 e 41 uccisioni.
|   3) a quell'istante il nemico piu' vicino e' a 0.51 m con kind 2.
|   4) invuln a quell'istante: 0.2500 s.
```

```
| progression: onda 1 -> 1 dopo 42 uccisioni, livello 6, XP 26.0 di 38.0, 126.0 guadagnati
```

```
| anche: il contatore d'onda e' salito di uno: atteso 2, ottenuto 1
```

La catena è coerente: 935 colpi e solo 42 uccisioni indicano che il colpo
arriva (l'arma spara), ma il ratio uccisioni/colpi è `42/935 ≈ 0.045`.
In `_ritmi` invece era `77/438 ≈ 0.176`: il ratio è cambiato, probabilmente
perché in `_ritmi` il `fire_interval` era `0.050 s` (compresso) mentre nel
run usa il valore naturale, e la difficoltà della scena vera fa morire il
giocatore in 15.97 s prima che raggiunga le 200 uccisioni.

I numeri sono letti **dentro** il ciclo (stesso istante del difetto): sono
validi.

---

## 5. IL NUMERO MANCANTE

**Il numero che chiude la domanda:** la scala di vita (`vita_scale`) dei nemici
**al passo 958** (quando il giocatore muore), cioè quanti HP ha un nemico di
kind 2 in quel momento.

Dove va letto: `src/sim/horde.gd` — il valore `hp[i]` per un nemico di kind 2
vivo al passo 958, oppure la formula `E.hp_of(kind, run.wave_scale)` valutata
con i parametri di quel passo.

Questo numero risponde alla domanda: "il giocatore muore perché i nemici hanno
troppa vita rispetto al danno dell'arma, o perché l'orda è troppo densa?". I
935 colpi su 42 uccisioni suggeriscono la prima, ma senza il valore di `hp`
dei nemici non si può escludere che il problema sia nel colpo che non impatta
(`_collide()`) — la sonda è stata tolta e i numeri dentro `_collide()` non
sono disponibili.
