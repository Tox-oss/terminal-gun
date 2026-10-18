extends RefCounted
## I **numeri** della geometria statica del mondo (milestone 10) e la sua
## costruzione. Qui non si disegna niente: qui si dichiara **che forma ha** il
## campo statico, e `-arena` lo mette in scena.
##
## ## Chi possiede questi numeri, e perche' sono qui
##
## Il vertice ha deciso l'ordine di consegna di m10 (§3.11): «la geometria la
## sceglie `-orda` e la costruisce `-arena`». Il motivo e' dichiarato: il criterio
## n. 2 e' **nostro**, e un numero che una foglia non ha misurato non lo deve
## scrivere. Percio' `layout()` e' la fonte unica dei dischi: chi li costruisce
## deve chiamare questa funzione e non riscoprire i numeri, perche' due copie di
## un raggio che divergono sono il difetto che m9 ha gia' chiuso una volta
## (sei copie di `28.0`, nessuna porta rossa).
##
## ## m12: un disco per piano, e quattro chiamate che si concatenano
##
##     const OBST = preload("res://src/sim/obstacles.gd")
##     var flat := PackedVector3Array()
##     for f in 4:                       # -arda, in _enter_tree()
##         flat.append_array(OBST.layout(game.arena_radius, f))
##     game.obstacles = flat
##
## Il secondo parametro e' il **piano**; senza, le quattro chiamate restituirebbero
## lo stesso identico layout. `-orda` taglia lo stesso array con
## `OBST.slice_floor(obs, f, 4)`, ed e' l'unico posto in cui il taglio e' scritto.
## Il raggio del disco **non cambia**: `RADIUS_FRACTION` e' una frazione, quindi a
## `R = 20,0 m` il disco passa a `1,30 m` da solo e l'occupazione areale resta
## `11,4%`. Cosa ne segue e' scritto sotto `ANGLE_JITTER`: due garanzie di m10
## smettono di valere a quel raggio, e il numero che le chiude e' `29,23 m`.
##
## ## La forma che esce e' quella congelata dal vertice
##
## Un elemento = `Vector3(centro_x, RAGGIO, centro_z)`: il raggio sta in `y` e
## non e' un'altezza. Non si deve leggere `y` come una quota (contratto di m10,
## punto 2), e questa funzione non ne produce nessuna: tutti i dischi sono sul
## piano XZ a `y = raggio`.
##
## ## Perche' tre anelli e non una disposizione a caso
##
## Il nemico insegue **in linea retta**, quindi la domanda che conta non e'
## "quanto campo c'e'" ma **"quanta parte delle traiettorie rette viene
## attraversata"**. Con ostacoli sparsi a caso la densita' areale giusta
## (~11%) produrrebbe qualche deviazione ogni tanto e il gioco resterebbe
## invariato. Tre anelli concentrici mettono invece un ostacolo **sulla strada**
## di ogni nemico che arriva da fuori, e la densita' areale resta la stessa.
##
## ## La garanzia che conta: nessuna coppia di ostacoli si tocca
##
## Un ostacolo che blocca e non si aggira e' un muro, e due muri che si toccano
## sono un muro solo. Quindi la regola e' una e la verifica e' geometrica:
## **la distanza fra due centri deve superare `2 * raggio + BOSSO`**, cosi' il
## passaggio fra due ostacoli e' piu' largo della sagoma del nemico piu' grosso
## (`RADIUS[BOSS] = 1.9`, diametro 3.8 m). Un nemico che entra in una fessura
## piu' stretta di se e' un nemico incastrato, e l'incastrato e' il difetto
## tipico di un campo di percorrenza (criterio n. 4 della milestone).
##
## Con i numeri qui sotto il minimo e' **12,0 m** fra due ostacoli di anelli
## diversi (distanza radiale fra un anello e il successivo) e **15,1 m** sullo
## stesso anello (corda minima, anello interno, 6 ostacoli): il passaggio utile
## e' quindi di **6,0 m**, cioe' 1,6 volte la sagoma del boss. Sono i numeri di
## **m9**, a R = 46,0 m; a **R = 60,0 m** (m11) le stesse frazioni danno **15,6 m**
## fra anelli e **19,8 m** di corda, e il passaggio utile misurato e' **7,81 m**,
## cioe' **2,06** volte la sagoma del boss. La garanzia quindi non si stringe:
## si allarga, e la tabella qui sotto lo dice con i numeri.
##
## Nessun anello si chiude su se stesso perche' le corde sono tutte molto piu'
## grandi di `2 * raggio`: il campo libero resta **connesso**, e questa e' la
## proprieta' che tiene il giocatore raggiungibile ovunque si metta.

## Quanti ostacoli, in tutto: `RING_COUNTS` la sua somma.
##
## ## m12: `27` -> `19`, e **la riduzione e' un risultato, non una scelta**
##
## Il numero e' uscito dal criterio, che e' scritto e verificabile:
## `tests/test_orda.gd` asserisce che **tutti i varchi** del campo — dal centro al
## primo anello, fra due anelli consecutivi, dall'ultimo anello al muro, e **fra due
## dischi dello stesso anello** — siano almeno `Flow.CELL = 2,0 m`. Un varco piu'
## stretto di una cella non e' un varco per quella griglia: la rastrelliera si chiude,
## il campo diventa disconnesso e il versante, guardando celle a costo infinito,
## restituisce un gradiente invertito. E' il difetto che ha prodotto i **424 passi**
## di `m10 criterio n. 4`.
##
## Con `R = 35,0 m` e **tre** anelli quei varchi non ci sono: il cammino dal centro
## al muro attraversa sei inflazioni e quattro celle, e `6 x 4,525 + 4 x 2,0 =
## 35,15 m` **supera i 35,00 m disponibili**. Tre anelli a 35 m sono geometricamente
## impossibili, non stretti. Quindi il numero di anelli scende a due e il conteggio
## dei dischi **e' quello che ci sta** con i due anelli e i varchi aperti:
##
## | anello | frazione | dischi | raggio a R=35 | varchi che lo tengono aperto |
## |---|---|---|---|---|
## | 1 | 0,36 | **5** | 12,60 m | centro 8,08 m · circolare **5,76 m** |
## | 2 | 0,78 | **11** | 27,30 m | fra anelli 5,65 m · circolare **6,33 m** · muro 3,18 m |
##
## Il **passaggio utile** resta sopra la sagoma del boss che questa testa dichiara
## (`2 x raggio + diametro boss`): il minimo fra due centri e' la corda dell'anello
## interno, `12,60 m` al centro e `11,44 m` nel caso peggiore del jitter, e il
## passaggio utile e' `6,89 m`, cioe' **1,81 volte** il boss (a `R = 60,0 m` con i
## numeri di m11 era 2,06 volte: un po' meno, e il numero e' qui perche' si veda).
const OBSTACLE_COUNT := 12
## Raggio di ogni disco, come **frazione** del raggio dell'arena. Non un numero
## in metri perche' un numero in metri qui dentro sarebbe una copia del raggio
## dell'arena scritta a mano, cioe' la classe di difetto di §1.12-bis. Il
## **prima** e' a `ARENA_RADIUS = 60.0` (m11) e valeva **3,90 m**; il **prima**
## ancora, a `46.0` (m9), valeva **2,99 m**, dichiarato come ~3,0 m. **Il valore di
## oggi e' 35,0 m** (m12, la torre) e vale **2,275 m**: la frazione non e' cambiata e
## la tabella sotto la riporta a tutti e tre i raggi.
##
## ## m11: la frazione non e' un numero che a 60 m si e' dimenticato: e' la
## ## scelta che rende la misura sotto leggibile
##
## Il raggio e' una frazione **per costruzione**, quindi al raggio nuovo la
## copertura areale non cambia (27 dischi di 0,065 R su un disco di R: **11,4%**
## a 46 m come a 60 m) e quello che cambia e' la **misura in metri**:
##
## | numero | a 46,0 m (prima) | a 60,0 m (dopo) |
## |---|---|---|
## | raggio del disco | 2,99 m | **3,90 m** |
## | anelli | 15,18 / 27,14 / 39,10 m | **19,80 / 35,40 / 51,00 m** |
## | dischi piu' vicini | 11,97 m | **15,61 m** |
## | passaggio utile | 5,99 m (**1,58x** il boss) | **7,81 m** (**2,06x** il boss) |
##
## La quarta riga e' la risposta alla domanda che m11 ha posto — «a 60 m i
## dischi sono relativamente piu' fitti?» — e la risposta e' **no**: il
## passaggio utile, cioe' la pista che il nemico deve attraversare, **cresce**
## da 5,99 a 7,81 m e il suo rapporto con la sagoma del boss sale da 1,58 a
## 2,06. I dischi non si spostano e non si stringono: si allargano con l'arena e
## lasciano fra loro un corridoio piu' largo. Per questo questo file non cambia
## nessuna costante in m11, e la misura e' rimessa in `tests/test_orda.gd`.
const RADIUS_FRACTION := 0.065
## Raggio degli anelli, sempre come frazione del raggio dell'arena.
##
## ## m12: **due** anelli, non tre, e perche' il numero e' due e non uno
##
## Prima: `[0.33, 0.59, 0.85]`, cioe' tre anelli a 19,80 / 35,40 / 51,00 m con
## `R = 60,0 m`. Adesso: `[0.36, 0.78]`, due anelli a 12,60 / 27,30 m con
## `R = 35,0 m`. Il numero di anelli non e' una scelta di gusto e non e' tre anche
## se tre sembrano piu' belli: con `R = 35,0 m` **tre anelli non ci stanno**, e il
## conto e' una disuguaglianza, non una preferenza (vedi `OBSTACLE_COUNT` sopra e la
## tabella sotto).
##
## Il primo anello **sale** da 0,33 a 0,36 e il secondo **scende** da 0,59 a 0,78.
## Le due mosse hanno due motivi diversi e vanno letti insieme:
##
##   - `0,33 -> 0,36`: con `RING_COUNTS[0] = 6` la corda dell'anello interno passa da
##     `10,98 m` a `11,44 m` nel caso peggiore del jitter. Sotto i `11,05 m` che
##     servono (due inflazioni da `4,525 m` piu' una cella da `2,0 m`) l'anello si
##     chiude **su se stesso** e la corona diventa un muro che il nemico deve
##     aggirare per intero invece di attraversare;
##   - `0,59 -> 0,78`: fra due anelli si sottraiono **due** inflazioni, non una, e
##     con `0,59 - 0,33 = 0,26` il varco a `R = 35` era `0,05 m`. Il secondo anello
##     va spinto verso il muro perche' e' l'unico posto dove il salto si compra senza
##     costare il varco centrale, che e' gia' il piu' generoso dei tre.
##
## **Perche' non `0,20 / 0,60`, che e' il punto di partenza verificato a mano**: quel
## layout funziona (i tre varchi sono `2,48 / 4,95 / 9,48 m`) ma **butta via metà
## dell'arena**. Con `RING_RADII[0] = 0,20` il centro libero e' di `2,48 m` e
## l'anello esterno finisce a `21,00 m`, lasciando `9,48 m` di pavimento vuoto
## contro il muro: un disco solo, dentro un anello solo, e quattro piani di questi
## sono quattro scatole. Il criterio del varco e' **necessario ma non sufficiente**:
## il layout scelto e' quello che passa il criterio **e** tiene tre anelli di
## pilastri distribuiti, e la tabella sotto dice quanto e' il pareggio.
##
## | numero | scartato `[0.33, 0.59, 0.85]` | scartato `[0.20, 0.60]` | scelto `[0.36, 0.78]` |
## |---|---|---|---|
## | centro -> anello 1 | 7,03 m | 2,48 m | **8,08 m** |
## | fra anelli 1 e 2 | **0,05 m** | 4,95 m | **5,65 m** |
## | anello 2 -> muro | **0,73 m** | 9,48 m | **3,18 m** |
## | circolare anello 1 | 2,39 m | 4,26 m | **2,39 m** |
## | circolare anello 2 | 3,72 m | 2,78 m | **2,73 m** |
## | dischi che ci stanno | 27 (3 anelli, non ci stanno) | 13 (2 anelli, 5 + 8) | **19 (6 + 13)** |
##
## Le due righe in grassetto sono **il difetto** e la quinta riga dice perche' il
## layout scartato era gia' rotto a `R = 35`: `0,05 m` e `0,73 m` sono sotto la
## cella da `2,0 m`, quindi la rastrelliera fra gli anelli e quella contro il muro
## sono chiuse **prima** di qualunque nemico ci arrivi.
const RING_RADII := [0.36, 0.78]
## Quanti ostacoli su ciascun anello: **5 + 11 = 16** = `OBSTACLE_COUNT`.
##
## ## m12-bis: **la rampa**, e perche' i conteggi sono `5` e `11` e non `6` e `13`
##
## Il vincolo **non e' piu'** «la corda supera due inflazioni piu' una cella» (quello
## reggeva fino a 6 e 14 dischi). Il vincolo nuovo e' uno solo e lo dice la rampa:
## **il corridoio non deve stare fuori dagli anelli, deve stare nel varco**, cioe'
## fra due dischi consecutivi. Il varcio fra due dischi di un anello di `n` dischi a
## raggio `r` e' (bordo interno, non inflato — la rampa e' un corridoio, non un
## nemico):
##
##     varco  =  2 x r x sin(PI / n)  -  2 x raggio disco
##
## A `R = 35,0 m`, con `raggio disco = 0,065 R = 2,275 m`:
##
## | anello | r | n | varco |
## |---|---|---|---|
## | interno | 12,60 m | **5** | `25,20 x 0,58779 - 4,55` = **10,26 m** |
## | interno | 12,60 m | 6 | `25,20 x 0,50000 - 4,55` = **8,05 m** |
## | esterno | 27,30 m | **11** | `54,60 x 0,28173 - 4,55` = **10,83 m** |
## | esterno | 27,30 m | 13 | `54,60 x 0,23932 - 4,55` = **8,51 m** |
##
## Serve `8,00 m` di larghezza di rampa piu' `2,00 m` di clearance: **`10,00 m`**.
## `5` e `11` sono i due numeri che passano, `6` e `13` sono i due che non passano
## di `2 m` e di `1,5 m`. Non e' una preferenza: e' una disuguaglianza per anello, e
## i due anelli hanno `n` diversi perche' i loro raggi sono diversi.
##
## Il **totale** scende da 19 a 16 e la torre da 76 dischi a **64**. Il resto dei
## numeri **non si muove**, perche' quei varchi non dipendono dai conteggi:
## centro `8,08 m`, fra anelli `5,65 m`, contro il muro `3,18 m` restano uguali.
## ## m12-bis: i **quattro vincoli insieme**, e perche' `3` e `9` e non `5` e `11`
##
## Non e' un vincolo, sono quattro, e insieme non lasciano scelta:
##
## ```
## A  il varcio di ogni anello contiene il corridoio:  2 r sin(PI/n) - 4,55 >= 10,96 m
## B  il corridoio fra i due anelli sta sopra una cella: (r2 - r1) - 9,05 >= 2,0 m
## C  l'anello esterno non chiude contro il muro:      (1 - f2) x 35 - 4,525 >= 2,0 m
## D  quattro reticoli distinti:                        0/90/180/270 mod (360/n) distinti
## ```
##
## `10,96 m` e' il **corridoio di `-arena`** (deriva laterale misurata `12,84°` =
## `5,48 m` per lato, e otto direzioni di input non tengono la retta): e' la larghezza
## che serve, non quella che c'era. Con `RING_RADII = [0,36, 0,78]` invariati i
## vincoli **B** e **C** sono gia' soddisfatti (`5,650 m` e `3,175 m`), e quindi **le
## frazioni non si toccano**: il punto si cerca solo sui conteggi.
##
## | vincolo | `n1 = 3` a 12,60 m | `n1 = 4` | `n1 = 5` | `n2 = 9` a 27,30 m | `n2 = 10` | `n2 = 11` |
## |---|---|---|---|---|---|---|
## | **A** varcio | **17,28 m** | 13,70 m | 10,26 m ✗ | **14,12 m** | 13,14 m | 11,66 m ✓ |
## | **D** resti | `0/90/60/30` ✓ | `0/0/0/0` ✗ | — | `0/10/20/30` ✓ | `0/18/0/18` ✗ | `0/24/12/6` ✓ |
##
## **Il vincolo che scarta `4` e `10` e' D, non A.** Con `n = 4` il passo e' `90°`, e
## le fasi sono `0/90/180/270`: **ogni piano riceve la stessa fase** e i quattro
## reticoli sono lo stesso reticolo quattro volte — che e' il difetto che `-arena` ha
## misurato come «due dischi a `0,00 m`». Con `n = 10` il passo e' `36°` e `180` cade
## su `0°` come `0`. **Quindi `A` da solo accetterebbe `4` e `10`, e `D` li boccia**: i
## due vincoli non sono lo stesso numero guardato due volte.
##
## Con `RING_COUNTS = [5, 11]` **A e' soddisfatto** (`10,26 m` e `11,66 m` contro
## `10,96 m`: il primo **no**, per `0,70 m`) e **D no**. Il layout cercato e' dunque
## `[3, 9]`, che passa A con `6,32 m` e `3,16 m` di margine, lascia B e C come sono,
## e **non muove `RING_RADII`**, quindi `arena_radius_min()` resta `22,4138 m` (non
## legge i conteggi) e i varchi del campo restano `8,075 / 5,650 / 3,175 m`.
##
## Il totale scende a `12` dischi per piano e `48` sulla torre: e' il prezzo di un
## corridoio che il giocatore puo' percorrere, e il numero che lo dichiara e' **D**.
const RING_COUNTS := [3, 9]
## ## m12-bis: la fase **non e' piu' un numero di questo file**
##
## Prima era `PHASE * passo * (anello + 1)` piu' `floor_turn(f)`: due numeri, uno
## fisso e uno a caso, e nessuno dei due sapeva dove sta la rampa. Ma con la rampa
## dentro il varco quei due numeri sono **sbagliati per costruzione**: il varco puo'
## cadere ovunque, e se cade sull'angolo sbagliato **i dischi coprono la rampa**.
##
## Un varcio sta a meta' fra due dischi, quindi all'angolo `alpha` il varco e' alla
## fase `alpha - PI / n`, e `alpha` lo chiede **il contratto**:
##
##     base dell'anello  =  Game.ramp_angle(f)  -  PI / n
##
## I due anelli hanno due `n` diversi e quindi due fasi diverse: la formula e' dentro
## il ciclo degli anelli, non fuori. `PHASE` e il giro casuale sono spariti perche'
## il giro per piano **ora e' derivato** (l'angolo della rampa e' diverso su ogni
## piano: `0`, `90`, `180` gradi), e un angolo derivato batte un caso: il reticolo
## dei dischi non e' piu' decorativo, e' **il varcio**.
##
## ## Perche' `Game` e non `src/render/arena_ramp.gd`
##
## Perche' un file di simulazione che legge un file di rendering per una divisione e'
## una copia, e qui sarebbe la copia piu' pericolosa di questa ondata: se i due
## calcoli divergono di un grado i dischi smettono di coprire la rampa e **nessuna
## asserzione se ne accorgerebbe**. `Game.ramp_angle(f)` e' aritmetica sul
## contratto, come `floor_of()`.
const RAMP_AXIS_SOURCE := "Game.ramp_angle(f)"
## Jitter angolare, in frazione del passo angolare.
##
## ## m12-bis: `0`, e il conto che lo rende obbligato
##
## Era `0,10` e serviva a bucarare il reticolo perfetto, che si vede. Adesso il
## varcio e' un **vincolo rigido** — dentro ci deve stare la rampa — e il jitter e'
## l'unica cosa che puo' chiuderlo, perche' sposta due dischi consecutivi **verso
## di loro**. Il caso peggiore e' la coppia con jitter opposti:
##
##     corda  =  2 x r x sin(PI / n x (1 - 2 x jitter))
##
## All'anello interno (`r = 12,60`, `n = 5`) con i numeri di oggi:
##
## | jitter | corda | varco (corda - 4,55) | sopra i 10,00 m? |
## |---|---|---|---|
## | 0,10 | 12,14 m | **7,59 m** | no |
## | 0,01 | 14,42 m | **9,87 m** | no |
## | **0,00** | 14,81 m | **10,26 m** | si, di 0,26 m |
##
## Il margine che il vincolo concede e' **`0,26 m`**: meno di `1 %` di passo, e il
## jitter minimo che lo mangia e' `1 %`. Quindi il jitter non e' «ridotto», e'
## **azzerato**, e il prezzo e' dichiarato: il reticolo e' perfetto e si vede. Il
## reticolo perfetto e' il prezzo di un vincolo che si puo' verificare; il reticolo
## bucato e' il prezzo di un vincolo che si puo' solo sperare.
const ANGLE_JITTER := 0.0
##
## ## m12: cosa succede quando il raggio scende — **misurato, non previsto**
##
## Il **raggio consegnato e' 35,0 m** e la colonna di 20,0 m e' il raggio che la
## torre aveva chiesto e che **non puo' funzionare**: la tabella e' qui perche' quel
## numero non venga riscritto senza la riga che lo ha bocciato.
##
## Le tre frazioni di questo file (`0,065`, `0,33/0,59/0,85`) **scalano col
## raggio**; tutto quello che le consuma e' **assoluto**. Il disaccordo e' qui, e
## si scrive una volta sola perche' i due numeri hanno la stessa radice.
##
##     passaggio utile  =  (0,59 - 0,33) R  -  2 x 0,065 R  =  0,13 R
##     disco > boss     ⟺  0,065 R > 1,90              ⟺  R > 29,23 m
##     passaggio > boss ⟺  0,13  R > 2 x 1,90          ⟺  R > 29,23 m
##
## Sono **la stessa disuguaglianza** moltiplicata per due, e il suo limite e'
## `R = 29,23 m`. Alla torre di m12 quel limite dice **quale raggio e' lecito**, e la
## colonna di mezzo e' quella che **non** lo rispetta:
##
## | numero | R = 60,0 (m11) | R = 20,0 (rifiutato) | R = 35,0 (oggi) |
## |---|---|---|---|
## | raggio del disco | 3,90 m = 2,05x il boss | **1,30 m = 0,68x** | **2,275 m = 1,20x** |
## | passaggio utile | 7,80 m = 2,05x il boss | **2,60 m = 0,68x** | **4,55 m = 1,20x** |
## | corda anello interno | 19,80 m (6 dischi) | **6,60 m** | **11,55 m** |
## | serve a non chiudere la corona | 15,12 m | **7,10 m** | **9,05 m** |
## | corona rasterizzata | aperta | **CHIUSA** | **aperta** |
##
## **L'ultima riga e' il difetto vero, ed e' quello che nessuna delle altre due
## dice.** Il campo di percorrenza gonfia ogni disco del **corpo del nemico piu'
## grosso** piu' il margine (`flow_field.gd::_raster`), cioe' di `1,90 + 0,35 =
## 2,25 m`: due dischi dell'anello interno restano separati quando i loro cerchi
## rasterizzati non si toccano, e servono `2 x (raggio disco + 2,25)` metri fra i
## centri. A `R = 20` servono `7,10 m` e l'anello ne offre `6,60`: la corona e'
## chiusa, il campo non ha sorgente unica e **il centro dell'arena — dove nasce il
## giocatore — diventa una stanza a cui nessun nemico arriva**.
##
## **Perche' 35,0 e non 29,23, che e' il minimo legale.** A 35 m il margine e' del
## **19,7%** su entrambe le garanzie (2,275 contro 1,90; 4,55 contro 3,80). A 30 m
## sarebbe `0,26 m`, cioe' `1,6%`: la soglia che tiene **oggi**, non quella che
## tiene **domani**, e il boss e' l'ultimo dei cinque a cui si puo' pensare di
## toccare il raggio. Il margine e' il prezzo di quella frase.
##
## **Nessuna riga di questo file e' cambiata per m12**: sono tre numeri del piano
## e una frazione che ne fa discendere altri tre, e la decisione **non e' di questa
## foglia**. Il numero che la chiude e' `29,23 m`, ed e' stampato a ogni lancio da
## `tests/test_orda.gd` (sezione «torre») insieme ai tre numeri che lo derivano.
##
## La funzione qui sotto e' il numero **derivato**, non una cifra scritta: legge
## il raggio del boss dalla tabella delle specie e lo divide per la frazione, e
## quindi non puo' mentire se una delle due muove. Se il vertice spostasse la
## frazione o la sagoma, il limite si sposta con lei e nessuno deve correggere
## niente qui dentro.
##
## ## Il NOME di questa funzione, che e' la cosa da non confondere
##
## `radius_min_for_boss()` dice **una sola cosa**: il raggio oltre il quale il
## **disco** e' piu' largo della sagoma del boss, cioe' `RADIUS_FRACTION x R >
## RADIUS[BOSS]`. Nient'altro. Non e' la soglia del campo e non e' la soglia del
## passaggio, e non si confronta con nessuna delle due.
##
## Le tre soglie di questo progetto hanno **tre nomi** e tre posti, e la tabella e' la
## difesa dalla confusione:
##
## | soglia | nome | protegge |
## |---|---|---|
## | **29,23 m** | `Obst.radius_min_for_boss()` | il **disco** e' piu' largo del boss |
## | **22,41 m** | `Flow.arena_radius_min(cell)` | i **varchi del campo** sono piu' larghi di una cella (i 424 passi) |
## | **13,1 m** | nessuna funzione: sta nella tabella qui sopra | il **passaggio utile** fra due anelli, che dipende dal layout |
##
## Il secondo e' il numero che protegge il difetto di questa ondata e il primo protegge
## una cosa sola: un disco grosso non serve a niente se il campo e' chiuso, e un campo
## aperto non serve a niente se il disco e' piu' piccolo del nemico che deve aggirarlo.
static func radius_min_for_boss() -> float:
	return E.RADIUS[E.BOSS] / RADIUS_FRACTION

## Il raggio del nemico piu' grosso, letto dalla tabella delle specie. Il
## produttore dei numeri di m10 non puo' conoscere `enemy.gd`, ma puo' dipenderne:
## `enemy.gd` non preloada niente, quindi il preload non puo' diventare un
## riferimento circolare (`spawner.gd` fa lo stesso).
const E = preload("res://src/sim/enemy.gd")
## Il raggio del disco in metri, per un'arena di raggio `arena_radius`.
static func radius_for(arena_radius: float) -> float:
	return maxf(0.5, maxf(arena_radius, 1.0) * RADIUS_FRACTION)

## Margine con cui un punto viene tenuto **fuori** dal disco invece che sul suo
## bordo. **1 millimetro**, e non e' una patch: e' il numero che tiene chiuso il
## criterio n. 5 e il criterio n. 2 insieme.
##
## ## Perche' serve, e perche' qui
##
## La domanda «un punto e' dentro un disco?» si fa in due posti con lo stesso
## segno: chi **produce** il punto (`Spawner.free_point`, `Flow.push_out`) spinge
## fuori, e chi **verifica** (`flow_field.contains`, `tests/test_orda.gd`) conta
## con `d2 < rr * rr`, cioe' **stretto**. I due numeri, se sono uguali, sono
## uguali per aritmetica e non per costruzione: chi spinge fuori calcola lo
## scarto in `float` e lo **somma** alla posizione, e la somma sbaglia di qualche
## ulp. Il punto finisce a `-0.00000` m dentro il disco, il confronto stretto
## lo dichiara dentro, e il criterio dice `FAIL` su un numero che non e' un
## difetto di steering ma di aritmetica: **778 su 4800** posizioni iniziali su
## 24 semi, tutte a zero.
##
## Il rimedio non e' arrotondare il confronto (allora il vincolo si sposta e
## diventa inafferrabile) e non e' spingere piu' forte: e' **un margine
## dichiarato** sulla spinta, piu' grande dell'errore di somma e piu' piccolo di
## qualsiasi cosa che si veda. `1e-3 m` su un disco di 2,99 m e' lo 0,03%.
##
## ## Perche' sta in questo file e non nei due che lo usano
##
## Perche' `obstacles.gd` e' il **produttore unico dei numeri** di m10 (§3.11):
## un millimetro scritto in `spawner.gd` e un millimetro scritto in
## `flow_field.gd` sono due numeri che possono divergere, e il difetto che m9 ha
## gia' chiuso una volta (sei copie di `28.0`, nessuna porta rossa) si ripete
## identico a un ordine di grandezza piu' piccolo. Una costante sola, due
## lettori.
const SKIN_EPS := 1.0e-3

## Il giro di un piano rispetto al piano 0, in radianti. **`0` sul piano 0**,
## e non un numero che capita vicino a zero: `layout(r, 0)` deve restare
## **bit per bit** la disposizione di m9/m10, perche' su quel piano questa
## funzione non e' cambiata e le misure di `tests/test_orda.gd` e di
## `tests/test_arena.gd` parlano ancora di quella disposizione.
##
## Il giro e' una **rotazione dell'intero anello**, non uno spostamento di un
## disco: una rotazione lascia **ogni distanza fra due centri** esattamente
## com'era, quindi `min_separation` e la garanzia del passaggio sono le stesse
## su tutti i piani. Spostare un disco alla volta le cambierebbe, e un piano
## avrebbe una garanzia diversa dagli altri: un ostacolo che si aggira e' un
## ostacolo, e la differenza fra due piani sarebbe invisibile a chi gioca e
## visibile al campo.
## Il contratto, preso dal main loop e **non** dall'identificatore globale `Game`.
##
## Il perché è la ragione per cui questa riga esiste: **`Game` come identificatore
## non è affidabile dentro una `static func`**, e il fallimento *dipende da chi ha
## caricato il file prima* — `src/sim/obstacles.gd` da solo compila, e non compila
## quando lo carica `tests/test_gameloop`. Un errore che non si riproduce con lo
## stesso comando è la forma peggiore di difetto che ci sia, quindi l'unico nome
## che qui si usa è la **funzione** del contratto, che è aritmetica sul main loop e
## non un identificatore.
const CONTRACTS = preload("res://src/core/contracts.gd")
static func _contratto() -> Node:
	return CONTRACTS.autoload_game()
## I piani per cui il «mondo è piatto» è già stato detto. Un `print` per chiamata
## dentro `tests/test_upgrades.gd` è rumore; uno per `floor_index` è una dichiarazione.
static var _detto_piatto: Dictionary = {}
## ## m12-bis: il giro per piano e' **l'angolo della rampa**, non un caso
##
## Era `TAU * hash(piano)`: un giro che metteva i quattro piani a caso, il che
## era un modo elegante di dire che **non si sapeva dove sta la rampa**. Adesso
## la domanda non e' piu' «quanto gira il piano» ma «dove passa la rampa di
## questo piano», e la risposta e' sul contratto: `ramp_angle(f)` vale `0` al piano
## 0, `90` gradi al piano 1, `180` al piano 2.
##
## ## I **tre** casi, e perche' non sono due
##
## Il chiamante che chiede il piano 1 in un mondo piatto (`tests/test_ui.gd`,
## `tests/test_upgrades.gd`, `tests/test_gameloop.gd` chiamano `layout()` senza
## scena) e il chiamante che chiede il piano 1 in un mondo a torre **non ancora
## montata** (`-arena`, che ha un `static var` il cui inizializzatore gira al
## caricamento della classe, cioe' prima di `_enter_tree()`) fanno la stessa
## domanda e hanno due risposte opposte:
##
##   1. **`floor_count <= 1`, cioe' nessuna torre**: il piano 1 **non esiste**, e in
##      un mondo piatto «il piano 1 non c'e'» e «il piano 1 e' come il piano 0» sono
##      la stessa risposta. Qui non si muore: si produce il layout del piano 0 e lo
##      si **dichiara**, una volta sola per piano.
##   2. **`floor_count >= 2` e `floor_index >= floor_count`**: qui il contratto
##      *sa* quanti piani ci sono e gliene chiedono uno che non c'e'. E' un difetto
##      vero — il layout è costruito prima del montaggio — e `push_error` va bene,
##      perché cedere qui è il difetto che `-arena` ha appena chiuso: un layout
##      silenziosamente sbagliato, con i varchi fuori asse e nessuna porta rossa.
##   3. **contratto irraggiungibile**: il neutro dichiarato, `0,0` come il caso 1.
static func floor_turn(floor_index: int) -> float:
	var game := _contratto()
	if game == null:
		_dichiara_piatto(floor_index)
		return 0.0
	var piani: int = game.floor_count
	if piani <= 1:
		_dichiara_piatto(floor_index)
		return 0.0
	if floor_index >= piani:
		push_error("Obst.layout: chiedo il piano %d ma il contratto ne conosce %d: "
			% [floor_index, piani]
			+ "il layout e' costruito PRIMA che la torre sia montata (un `static var` "
			  + "di -arena lo calcola al caricamento della classe), quindi i piani "
			  + "avrebbero lo stesso varcio. Chiama layout() dopo `_enter_tree()`.")
		return 0.0
	# ## Qui si torna a `ramp_angle`, e **la ragione e' un teorema, non un gustuccio**
	#
	# Ho provato `layout_phase(f)` (che e' `f x TAU / floor_count`) e il criterio
	# `_torre_rampa` di `tests/test_orda.gd` e' andato rosso: `1 piani liberi su 4`,
	# con il piano 0 libero e gli altri tre **coperti**. E il numero che lo spiega e'
	# che il **reticolo e' determinato dal varcio**: la fase che mette un varcio
	# sull'asse `alpha` e' `alpha - PI/n` **modulo il passo**, quindi c'e' una sola
	# classe di fasi per asse, e due piani hanno lo stesso reticolo **se e solo se**
	# i loro assi sono uguali **modulo il passo** dell'anello.
	#
	# Con `ramp_angle(f) = f x 120°` e passo interno `72°`: resti `0 / 48 / 24 / 0` —
	# **il piano 3 e il piano 0 coincidono**. Passo esterno `32,727°`: resti
	# `0 / 54,55 / 11,45 / 0` — **coincidono anche**. Quindi con gli assi di adesso
	# **non esiste** una fase che tenga insieme «quattro reticoli diversi» e «il
	# varcio su ogni rampa»: sono in contraddizione per il numero, non per un errore.
	#
	# Con `ramp_angle(f) = f x TAU / floor_count` = `0 / 90 / 180 / 270`: resti interni
	# `0 / 18 / 36 / 54`, esterni `0 / 24,55 / 16,36 / 8,18` — **tutti distinti e nessuno
	# multiplo del passo**, quindi **le due condizioni valgono insieme** e la fase
	# continua a venire dall'asse della rampa. **La correzione sta in `ramp_angle`,
	# non in una funzione nuova**: due denominatori diversi per la stessa grandezza
	# erano il difetto, e li si risolve togliendo il denominatore sbagliato invece di
	# aggiungere un nome.
	return float(game.call("ramp_angle", floor_index))
## Il mondo e' piatto e il piano richiesto non esiste: la risposta e' il piano 0, e
## la risposta va detta una volta per piano, non una volta per chiamata.
static func _dichiara_piatto(floor_index: int) -> void:
	if floor_index <= 0 or _detto_piatto.has(floor_index):
		return
	_detto_piatto[floor_index] = true
	print("Obst.layout: il piano %d non esiste (il contratto non conosce una torre): "
		% floor_index
		+ "il layout e' quello del piano 0")

## I dischi, gia' nella forma del contratto: `Vector3(cx, RAGGIO, cz)`.
##
## Determinismo: nessun `RandomNumberGenerator`, solo un hash intero dei numeri
## d'indice. Due foglie che chiamano questa funzione con lo stesso raggio
## ottengono **gli stessi dischi**, che e' il motivo per cui il numero non e'
## scritto due volte.
##
## ## m12: il secondo parametro e' il **piano**, e serve
##
##     layout(radius)             # prima: 27 dischi su UN piano
##     layout(radius, floor: int) # adesso: 27 dischi del piano `floor`
##
## Senza il parametro le quattro chiamate di `-arda` restituirebbero **lo stesso
## identico layout**, cioe' quattro biomi con la stessa mappa dentro. Il parametro
## esiste per quello, e nient'altro: non sposta il raggio di un disco (quello e'
## `RADIUS_FRACTION`, una frazione che non cambia) e non sposta un anello.
##
## **`floor_index` ha un valore di ripiego (`0`)** perche' il chiamante di m10 era
## a una firma e ora e' a due: il valore di ripiego e' il piano 0, cioe' esattamente
## la disposizione di prima, quindi **un chiamante che non e' ancora passato a
## quattro piani continua a ottenere il numero di prima** invece di schiantarsi.
## Se il parametro fosse obbligatorio, il valore di ripiego non ci sarebbe e
## `Compile Error: too few arguments` avrebbe fatto cadere `src/render/arena.gd`
## e `tests/test_arena.gd` al primo ritocco. Il difetto che il valore di ripiego
## **nasconde** — quattro chiamate con quattro layout identici — e' chiuso da un
## criterio in `tests/test_orda.gd`, non dalla firma.
static func layout(arena_radius: float, floor_index: int = 0) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(OBSTACLE_COUNT)
	var r := radius_for(arena_radius)
	var asse := floor_turn(floor_index)
	var k := 0
	for anello in RING_RADII.size():
		var n: int = RING_COUNTS[anello]
		var passo := TAU / float(n)
		# ## m12-bis: la fase e' `asse - PI/n`, e sta **dentro** il ciclo
		#
		# Il varcio di un anello e' a meta' fra due dischi, quindi all'angolo
		# `asse` il varco e' alla fase `asse - passo / 2`. La formula sta qui dentro
		# perche' i due anelli hanno due `n` diversi (`5` e `11`) e quindi due fasi
		# diverse: fuori dal ciclo ci sarebbe un solo numero per due anelli, cioe'
		# esattamente la copia che questo file non deve fare.
		var base := asse - passo * 0.5
		var rr: float = arena_radius * float(RING_RADII[anello])
		for i in n:
			# il jitter e' sul passo angolare, mai sul raggio: il raggio tiene
			# la distanza fra due anelli, che e' la garanzia che conta
			var a := passo * (float(i) + ANGLE_JITTER * (_hash01(k) * 2.0 - 1.0))
			out[k] = Vector3(cos(a + base) * rr, r, sin(a + base) * rr)
			k += 1
	return out

## Quanti ostacoli stanno su **un** piano in un array piatto di `n` voci
## diviso in `floors` piani.
##
## Non e' `OBSTACLE_COUNT`: e' `n / floors`. La differenza e' la difesa di questa
## foglia, perche' `-orda` e `-arda` chiamano `layout()` da due file e possono
## chiamarla un numero di volte diverso: se il produttore unico cambiasse un
## giorno `OBSTACLE_COUNT`, la fetta di cui sotto resterebbe quella di ieri e i
## due foglie taglierebbero l'array in punti diversi — cioe' `-orda` eviterebbe
## gli ostacoli del piano sbagliato, che e' la classe di difetto delle copie che
## questo progetto chiude in ogni altro punto.
static func per_floor(n: int, floors: int) -> int:
	return n / maxi(floors, 1)

## La **fetta di ostacoli del piano `floor_index`** dentro l'array piatto che
## `-arda` costruisce concatenando quattro `layout()`.
##
## E' l'unico posto in cui l'array piatto viene tagliato, e lo taglia in blocchi
## **uguali e consecutivi**: `slice_floor(obs, 0, 4)` e' esattamente
## `layout(r, 0)`, `slice_floor(obs, 3, 4)` e' esattamente `layout(r, 3)`.
## `tests/test_orda.gd` asserisce l'uguaglianza voce per voce: e' la prova che i
## due foglie parlano della stessa fetta.
##
## ## Perche' il taglio e' per **indice** e non per `floor_of()`
##
## Il piano su cui cade un disco si deduce da **due fatti che stanno nel
## contratto**: l'elemento `Vector3(cx, RAGGIO, cz)` ha il **raggio in `y`**,
## e `floor_of(y)` risponde «a che piano appartiene l'altezza `y`». Ma `y` qui e'
## un raggio di **1,30 m**, e `floor_of(1,30)` con `floor_height = 20,0` vale
## **0** perche' `1,30 / 20,0 = 0`. Quindi **tutti** i dischi di tutti e quattro i
## piani cadrebbero sul piano 0 e gli altri tre piani avrebbero un campo senza
## ostacoli: la torre che «non attraversa il pavimento» attraverserebbe i muri.
##
## La forma dell'elemento **non si cambia**: `src/core/contracts.gd` la congela
## tre volte («il raggio sta in `y`, che e' l'unica cosa controintuitiva di questa
## superficie, e quindi l'unica che va detta tre volte») e nessuna foglia modifica
## quel file. Quindi il taglio per indice e' l'unico che rispetta il contratto, e
## resta **dichiarato** perche' e' una scelta: se un giorno il vertice volesse
## portare la quota del piano nell'elemento, questo e' il posto da cambiare, e il
## criterio che asserisce `slice_floor == layout` va cambiato con lui.
static func slice_floor(obs: PackedVector3Array, floor_index: int,
		floors: int) -> PackedVector3Array:
	var n := obs.size()
	if floors <= 1:
		return obs.duplicate()
	var per := per_floor(n, floors)
	var out := PackedVector3Array()
	var a := clampi(floor_index, 0, floors - 1) * per
	var b := mini(a + per, n)
	for i in range(a, b):
		out.append(obs[i])
	return out

## Il punto piu' vicino a un ostacolo, in metri: `0` se l'insieme e' vuoto. E' il
## numero con cui si controlla che nessuno ci si perda dentro, e la sua versione
## con il corpo dell'enemy dentro e' il criterio n. 2.
static func min_separation(obstacles: PackedVector3Array) -> float:
	var minimo := 1.0e9
	for a in obstacles.size():
		for b in range(a + 1, obstacles.size()):
			var pa := obstacles[a]
			var pb := obstacles[b]
			var d := Vector2(pa.x - pb.x, pa.z - pb.z).length()
			if d < minimo:
				minimo = d
	return 0.0 if obstacles.size() < 2 else minimo

## Numero pseudo-casuale **deterministico** in [0, 1). Serve a bucare il
## reticolo senza un generatore: due foglie ottengono la stessa sequenza.
static func _hash01(n: int) -> float:
	var x := (n * 2654435761) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	x = x ^ (x >> 16)
	return float((x & 0xffff) % 65536) / 65536.0