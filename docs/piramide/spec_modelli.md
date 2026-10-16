# Brief dei modelli — terminal-gun

Data: 2026-10-17. Fonte: misure lette nel codice, non ricordi.

Tutti i numeri qui sotto sono presi dal sorgente e citano il file. Se un numero non c'è,
la sezione lo dice: **è una decisione che va presa, non un numero che va indovinato.**

> **Nota di percorso**: l'utente ha chiesto questo file sul Desktop. Il Desktop è `deny`
> nella allowlist del vertice (`docs/piramide/**`, `src/core/contracts.gd`, `tools/env.sh`
> sono gli unici path scrivibili), e una risposta a una domanda non cambia un'allowlist:
> il fix e' nel piano e lo decide l'utente. Quindi il file vive qui dentro, che e' il posto
> giusto anche per un'altra ragione — **dentro al repo, questo brief si aggiorna insieme ai
> numeri che cambieranno**, e i numeri di m12 stanno cambiando.

---

## 0. Il numero che conta piu' di tutti

Il renderer **non usa la scala del file che consegni**. La normalizza:

```
scale      = SIZE_FACTOR * RADIUS[kind] / mesh_span
SIZE_FACTOR = 3.4                                    src/render/horde_renderer.gd:162
mesh_span   = max(AABB.x, AABB.y, AABB.z)            src/render/horde_renderer.gd:255
```

Conseguenza, e va ripetuta perche' e' il punto su cui si sbaglia:

> **Il lato maggiore del tuo modello diventa `3,4 * RADIUS` della specie.**

Quindi **la scala assoluta del file e' irrilevante**. Consegnare un modello "grande" o
"piccolo" non cambia niente. Conta **solo la proporzione** fra le dimensioni.

Il corollario e' il trabocchetto: se il lato maggiore del tuo modello **non e'** quello che
consideri "il corpo", il renderer comprime tutto finche' quel lato ci sta, e il corpo ti
diventa una lamina. Per ogni specie, **decidi esplicitamente quale dimensione e' quella
che deve impadronirsi del valore**, e disegna di conseguenza.

---

## 1. Formato

- **Un GLB per file**, nome esatto indicato sotto.
- **Low-poly**: primitive con pochi segmenti. Il gioco deve girare con 200 corpi per volta.
- **Nessun rig, nessuna animazione, nessuna texture.**
- **Nessun materiale e nessun vertex color.** Il renderer fa `material_override` e mette
  `vertex_color_use_as_albedo = true` (`horde_renderer.gd:270` e `:284`): **il colore lo
  decide il codice, per istanza**. Se ci metti colori nel GLB vengono scartati.
- **Applica le trasformazioni prima dell'export** (rotazione e scala), cosi' l'AABB e' pulito.
  Il renderer legge l'AABB del file, e un AABB sporco produce un raggio sbagliato.
- Il progetto pretende che **lo stesso comando produca gli stessi byte**: niente date,
  niente random non fissato dentro il file.

---

## 2. I cinque raggi — la tabella

`KIND_NAMES` e `RADIUS` sono in `src/sim/enemy.gd:29` e `:51`. La colonna finale e' **il
lato maggiore che il tuo modello avra' a schermo**, calcolata con la regola della sezione 0.

| specie | `RADIUS` (m) | **lato maggiore visibile** | modello che la disegna |
|---|---|---|---|
| `runner`  | 0,45 | **1,53 m** | `enemy_small.glb` |
| `grunt`   | 0,60 | **2,04 m** | `enemy_small.glb` |
| `brute`   | 1,00 | **3,40 m** | `enemy_big.glb` |
| `boss`    | 1,90 | **6,46 m** | `enemy_boss.glb` |
| `Adware`  | 1,40 | **4,76 m** | `enemy_big.glb` — **non ha un modello suo** |

`KIND_SLOT` (`horde_renderer.gd:77`) e' una copia dichiarata di questa mappa e un criterio
di `tests/test_arena.gd` la confronta voce per voce: quando aggiungiamo le specie nuove quel
criterio va rosso finche' lo slot non e' aggiunto.

**Nota sull'Adware**: si chiama cosi' dal 2026-10-15 (prima `mortar`), ed e' **l'unica delle
cinque senza un GLB dedicato**: oggi la disegna `enemy_big.glb`, cioe' **il modello del
brute**. Se vuoi un'Adware riconoscibile, ti va consegnato un quarto file nemico.

---

## 3. Lo stato di oggi — cosa NON rifare

- **`enemy_small.glb`, `enemy_big.glb`, `enemy_boss.glb`: sono gia' tuoi.** Sono stati
  consegnati il 2026-10-15, hanno i raggi della tabella e **i criteri li verificano**.
  Non vanno ridisegnati per m12. Se qualcosa non ti convince, e' un problema da mettere
  per iscritto, non da rifare di nascosto.
- **`crate.glb` e `ground_tile.glb`**: generati da codice, **non sono personaggi**, fuori
  da questo brief.
- **`player.glb`: non e' tuo.** E' un cono generato da `tools/blender/gen_models.py:138`.
  **E' l'unico personaggio che va rifatto** — vedi la sezione 5.

---

## 4. Il giocatore — il vincolo piu' rigido del brief

`TOUCH_REACH = 0.45` (`enemy.gd:185`) e **un criterio asserisce che il raggio misurato del
giocatore sulla scena vera sia `UGUALE` a `0,45`** — non vicino: uguale. Il cono di oggi e'
`0,90 x 1,10 x 0,90`, quindi ha raggio `0,45`.

Due conseguenze:

1. **La larghezza del tuo modello e' fissata**: il corpo deve stare in `0,90 m` di larghezza.
   E' stretto per un personaggio, ma e' quello che la camera e i criteri pretendono. Puoi
   cambiare la **silhouette** dentro quei `0,90 m`, non la larghezza.
2. **L'altezza la scegli tu**, perche' il giocatore **non** passa dalla normalizzazione della
   sezione 0: nessun codice la riscala. Ma un corpo largo `0,90 m` e alto `1,80 m` e' una
   torre. Se scegli un'altezza umana, la larghezza ti costringe a una figura molto snella.

> **Da confermare prima di modellare**: il criterio misura il raggio come semilato dell'AABB
> o come raggio della sfera di inviluppo? Sono due vincoli diversi — e su un modello alto
> `1,80 m` la differenza non e' piccola. Chiedi questo **prima** di produrre il file:
> rifare un personaggio perche' la misura era l'altra costa piu' di quanto il personaggio costi.

---

## 5. Le quattro specie nuove

`Trojan`, `Wurm`, `Ransomware`, `Rootkit`. `KIND_COUNT` va da `5` a `9`.

**I loro raggi NON sono scritti e non li scrivere nel brief.** Non sono stati misurati, e questo
progetto non scrive un numero prima della misura. Consegnate il modello **alla forma che
volete** e **dite in che proporzione sta rispetto al corpo del runner** (per esempio
"stesso ingombro", oppure "una volta e mezzo"): da li' il raggio si assegna, e quel numero e'
l'unico che va scritto.

Tre note che non sono estetiche:

- **`Wurm` NON e' un corpo singolo.** E' una **catena di N segmenti**, e una catena occuperebbe
  N voci di `kinds[]`/`transforms[]` — che oggi sottintendono **un corpo per nemico**.
  Consegna **un singolo segmento come modulo riutilizzabile**, non la catena montata.
  Attenzione al corollario della sezione 0: una catena lunga ha il lato maggiore enorme,
  e il renderer la comprimerebbe finche' la catena intera sta in `3,4 * RADIUS`, riducendo
  ogni segmento a quasi niente.
- **`Ransomware` e' il primo canale `orda -> giocatore`.** Tutti gli altri canali del gioco
  vanno dal giocatore al mondo: questo va dall'orda al giocatore. Deve **leggersi** come
  quello che arriva al giocatore e lo tocca. E' l'unica specie che si tocca e non fa danno.
- **`Rootkit`**: l'effetto non e' ancora specificato. Nessun vincolo di forma oltre quelli
  della tabella dei raggi.

---

## 6. I quattro biomi — non ancora scrivibili

La mappa e' una torre di **quattro piani, uno per bioma**. Ma l'ordine deciso e'
**prima la mappa, poi i biomi**, e i biomi sono a valle. **Questa sezione si scrive quando la
mappa e' in piedi**, non prima. Nessun bioma da consegnare con questo brief.

---

## 7. Cosa NON scrivere qui dentro

Se ti viene il tasto di riempiere questi spazi, il progetto li vuole vuoti:

- i raggi di `Trojan`, `Wurm`, `Ransomware`, `Rootkit` — non misurati
- l'altezza del giocatore — tua scelta, ma decisa **consapevolmente**, non per default
- quanti ostacoli e quante casse per piano — lo decide un criterio, non un parere
- il danno e la durata del firewall — non scritti

Un numero in un documento di specifiche e' una promessa di che quel numero regge. Se non
regge, il costo torna indietro con gli interessi.