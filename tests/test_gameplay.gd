extends SceneTree
## Test di gameplay di terminal-gun. -gameplay.
##
## Dimostra la parte di criterio n. 4 della milestone che e' **di -gameplay**: il
## player spara da solo, il proiettile viaggia, e il danno viene applicato **una
## e una sola volta**. Tutto con numeri, non con parole.
##
## Le sette cose della milestone 1 che il test dimostra, e le tre di m2:
##   0. il contratto e' davvero interrogato: `nearest_enemy` e `damage_enemy`
##      chiamati a mano dal test arrivano al doppio, con la semantica giusta
##      (indice, `-1` = nessun bersaglio, `true` = ucciso);
##   1. il player si muove di un delta noto con un input noto, e resta clampato
##      dentro `Game.arena_radius`. **m9**: il raggio era 28 m e il 2026-10-14 il
##      vertice l'ha portato a **60 m** (da 46: il ginocchio della curva di
##      `docs/piramide/probe_survive.gd`, caso peggiore 55,33 s -> 146,72 s, fattore
##      2,65). «non uscire» non basta piu' come prova: su un disco 4,6 volte piu'
##      grande in area la sezione dice anche **dove** il muro ferma il giocatore —
##      a 59,2 m dal centro sull'asse (60,0 meno `ARENA_MARGIN` 0,8), sugli stessi
##      59,2 m in diagonale, con `x` e `z` entrambi a 41,86 m. Un clamp
##      **quadrato** si tradirebbe li' (arriverebbe a 83,72 m, cioe' 23,72 m oltre
##      il muro);
##   2. l'arma spara da sola: entro 60 frame c'e' un proiettile in volo, e la
##      sua direzione e' entro 5 gradi dalla direzione del nemico piu' vicino;
##   3. un proiettile che attraversa un nemico gli applica il danno **una e una
##      sola volta**, e il caso difficile e' esplicito: due nemici
##      **sovrapposti**, un proiettile lento dentro di loro per una quindicina di
##      frame. Se la guardia manca, quel test riceve una quindicina di danni per
##      nemico invece di uno;
##   4. il knockback che l'arma consegna al contratto e' un **impulso in m/s**
##      grezzo, rivolto via dal player, e arriva una volta sola per colpo. Il
##      tetto di 0.3 unita' di spostamento **non** e' asserito qui: quello e'
##      gia' asserito per specie sulla scena vera in `tests/test_arena.gd`, e su
##      un doppio misurerebbe una ricostruzione del gioco. Vedi la nota lunga
##      sopra `_knockback_impulse`, che spiega perche' e' stato tolto;
##   5. dieci uccisioni fatte **attraverso il percorso vero** (`damage_enemy` che
##      risponde `true`) fanno salire di livello, e il livello offre
##      **esattamente 3** potenziamenti, tutti e tre applicabili;
##   6. 300 colpi non allocano niente: il pool non cresce mai e i conteggi di
##      nodi e di oggetti restano quelli di prima;
##   9. **criterio n. 4 di m2, meta' di -gameplay**: `reset_run()` rimette in
##      piedi il giocatore, `restart_run()` rimette in piedi la partita intera, e
##      nessun nodo viene duplicato. Il numero che decide e' uno solo: dopo il
##      restart, un passo di simulazione **non** rilegge `game_over`;
##  10. **m5, criterio n. 2**: con una **camera reale** costruita come quella di
##      arena (34 m sopra, 24 m dietro, `look_at` sul bersaglio), il vettore che
##      il gioco costruisce quando e' premuto **W** deve puntare nella direzione
##      che **quella camera mostra come alto**. L'atteso e' calcolato dalla base
##      di quella camera, non scritto a mano: un `Vector3(0, 0, -1)` dentro
##      rifaterebbe esattamente il difetto di oggi con un altro numero;
##  11. **m5, criterio n. 3**: senza camera W resta `-z`, e i due percorsi
##      **concordano sullo schermo** — il ripiego e' l'alto della stessa camera,
##      non un altro "alto";
##  12. **m5, criterio n. 4**: la trasformazione che il renderer applica a una
##      posizione **mondo** deve essere l'**identita'**, misurata. In headless la
##      MultiMesh non si rilegge, quindi il numero si prende sulla **trasformazione
##      del nodo** che la disegna: e' la causa, ed e' misurabile;
##  13. **m5, criterio n. 5**: nessun nodo in piu'. `node_count` resta **33**
##      sulla scena vera, che e' la sola scena in cui il numero conta.
##  14. **m7, criterio n. 2**: sulla **scena vera** l'orda raggiunge il giocatore,
##      e quando il codice di gioco ferisce il giocatore `hp` scende e **resta**
##      sotto; a `hp <= 0` lo stato e' `game_over`. Il chiamante e' di **-orda**:
##      questa sezione osserva se c'e' e, quando c'e', asserisce il percorso
##      intero. Se non c'e' lo **dichiara** e asserisce comunque tutta la parte
##      che e' di -gameplay, cioe' che il contratto ferisce davvero;
##  15. **m7, criterio n. 3**: `player.restart_run()` rimette in piedi il
##      giocatore sulla scena vera — `hp` torna a `max_hp`, l'onda torna a 1,
##      nessun nodo duplicato, e **un passo di simulazione non rilegge
##      `game_over`**. E il giocatore può morire di nuovo dopo il restart.
##  16. **m9, criterio n. 1**: il raggio dell'arena è **60 m** e quel numero è
##      un **letterale scritto qui** (`RAGGIO_ARENA`), cioè una **copia
##      dichiarata** della fonte unica `src/core/contracts.gd:arena_radius`
##      (60.0, riga 116), non una lettura: «il raggio vale 60 m» è un perno e un
##      perno può esistere solo scritto. Il criterio opposto — le copie del raggio
##      non divergono fra loro — sta in `tests/test_arena.gd`, che è di `-arena`:
##      li' si confrontano le copie e non si sa se il numero sia quello giusto. Le
##      due domande non si dicono, e per questo stanno in due file.
##  17. **m10, criterio n. 6**, che è **un criterio solo con due metà**: il
##      giocatore è **solido** e i proiettili **passano**. Le due metà si
##      provano per conto separato e sullo **stesso disco**, perché il progetto
##      non deve avere un muro che blocca chi lo usa e non chi lo combatte: se
##      una metà cade e l'altra no, il muro esiste a metà e il gioco ha una
##      regola che nessuno ha scritto. Tre sezioni: il contratto li dichiara
##      (`_m10_ostacoli_del_contratto`), il giocatore ci si arresta
##      (`_m10_giocatore_solido`), il proiettile li attraversa e colpisce il
##      nemico **dietro** (`_m10_proiettili_passano`). I **due denti** sono stati
##      eseguiti e i loro numeri stanno nella sezione 17: senza il clamp il
##      giocatore passa dal **centro** del disco (0,0000 m su un raggio di 2,00 m)
##      e la metà dei proiettili resta verde; con il proiettile che si ferma al
##      muro il colpo si ferma a **2,300 m** dal centro (0,300 m fuori dal disco),
##      il nemico dietro prende **0** colpi e la metà del giocatore resta verde.
##  18. **m14-a**, l'altra meta' della stessa segnalazione dell'utente («alcuni
##      nemici non riescono a farmi danno»): `projectile_pool.gd` aveva
##      `ENEMY_RADIUS = 0.55` per **tutte e cinque** le specie, cioe' un numero
##      rimasto indietro di `SIZE_FACTOR = 3.4`, e il mortar — 4,76 m a schermo,
##      primo nemico che devi uccidere **mentre ti spara da 10,42 m** — era un
##      bersaglio da 0,55 m. L'involucro del proiettile ora è lo **stesso** del
##      morso, letto dallo **stesso** canale `Game.enemy_body_scale`
##      (`_m14a_involucro`): banda **0,0000** su cinque specie, mai più grande
##      del corpo disegnato, e due denti (il contratto avvelenato a 99,0 muove
##      **entrambi** gli involucri, poi la sonda tolta e il canale rifunziona).
##      I dieci tiri di quella sezione non leggono una formula: fanno sparare.
##
## 19. **m16**, l'altra meta' della stessa segnalazione dell'utente («quando sono
##      coperto di nemici non mi uccidono rapidamente»): la finestra
##      `INVULN_AFTER_HIT` era un **tetto di cadenza**, non un ripiego. Tre
##      sezioni, e tre numeri stampati: `_m16_una_finestra` (criterio 3, una
##      sola finestra e non due), `_m16_tetto` (criterio 1, quanti morsi
##      **offerti** su quanti **accettati** con 200 nemici in 30 s, e il
##      confronto con la frazione di `0,7 s`) e dentro la stessa sezione il
##      criterio 2 (quanto si resta in piedi coperti con `0,25 s` contro
##      `0,7 s`). I due numeri che decidono sono scritti in questo file e hanno
##      entrambi i denti: `M16_TETTO_VECCHIO = 43` (i morsi accettati devono
##      superarlo; col valore di prima erano 39) e `M16_CONVERSIONE = 0,5`
##      (meta' dell'offerta deve diventare danno; col valore di prima era 27%).
##
## 20. **m13-w3**, le due segnalazioni dell'utente. `_fuoco_dopo_morte`: a
##      `game_over` l'arma spara ancora, e la sezione lo misura in **due**
##      finestre da 600 passi sullo stesso codice — avvelenata la condizione di
##      morte il contatore **deve** tornare a crescere, vera la condizione deve
##      valere **0** e `hp` a zero resta a zero. `_tasto_reale`: il restart passa
##      da `Viewport.push_input` sulla **scena vera** (l'unica sezione che non
##      mette `PROCESS_MODE_DISABLED`, perche' un nodo disabilitato non riceve
##      input), e i suoi tre esiti sono i tre difetti possibili: il tasto funziona
##      e nessuno lo diceva / un altro handler consuma l'evento / la pipeline non
##      arriva al nodo. Il tasto e' **letto dalla costante viva** `RESTART_KEYS`,
##      non scritto qui, e la scena viene libera **adesso**: una `queue_free`
##      la lascerebbe in albero — con la sua `Camera` di arena — fino in fondo al
##      file, e faceva fallire il ripiego di m5 nella sezione 10.
##
## ## I DUE TEST DI m2 CHE HANNO UN FILE LORO
##
## Il criterio n. 2 (l'XP) e' in `tests/test_progression.gd` e il criterio n. 3
## (i potenziamenti) e' in `tests/test_upgrades.gd`: sono file separati per il
## piano §3.3, e qui non ci sono piu'. Prima stavano in questo file solo perche'
## su questa macchina non si poteva creare un file nuovo; il permesso e' stato
## riparato e i due file esistono.
##
## Quello che resta qui e' la parte che **non** e' loro: il livello che offre
## esattamente tre potenziamenti applicabili (criterio n. 4 di m1) e il restart.
##
## L'orda e' un **doppio finto** definito qui sotto (`FakeHorde`), non
## `src/sim/horde.gd`: questo test non deve aspettare che -orda abbia finito.
## Il finto implementa esattamente la superficie che -gameplay puo' usare del
## contratto, e nient'altro:
##   - `Game.horde = self` con i campi pubblici `count`, `transforms` e
##     `kinds` (l'ultimo dal 2026-10-15: e' la specie, e senza di essa il
##     proiettile non puo' sapere quanto e' grande il corpo che deve prendere);
##   - `Game.register_impl("damage_enemy", ...)`, che applica `amount` agli HP,
##     **somma** alla velocita' del nemico `knockback * (1 - resist)` e risponde
##     `true` se l'ha ucciso (e' da quel `true` che nasce l'XP: vedi
##     `_xp_and_upgrades`).
##   - `Game.register_impl("nearest_enemy", ...)`, che e' la domanda che l'arma
##     fa per mirare, e di cui `-1` significa "nessun bersaglio".
##
## NOTA SUL CARICAMENTO (piano §5.3): nessuno script di gioco e' in `const
## preload` qui. Un `const preload` in un file lanciato con `--script` risolve
## i suoi script a tempo di compilazione, PRIMA che `Main` aggiunga gli autoload
## ai nomi globali, e `player.gd`/`weapon_base.gd`/`projectile_pool.gd` usano
## l'identificatore nudo `Game`: verrebbero compilati troppo presto e il test
## morirebbe con `Identifier not found: Game`. Per questo'qui gli script si
## caricano a **runtime**, dentro `_process()`, e i valori di gioco si leggono
## dai **campi delle istanze vive** (`player.accel`, `player.move_speed`,
## `weapon.damage`), non dalle costanti degli script.
##
## ## L'eccezione di `src/sim/enemy.gd`, e perche' e' sicura
##
## `ENEMY` **e'** un `const preload`, ed e' lecito perche' `enemy.gd` non
## usa l'identificatore nudo `Game` da nessuna parte del codice: e' un
## `RefCounted` fatto di tabelle `static`, e l'unico nome che usa e' il suo
## (`E` dentro `horde.gd`). Quindi compilarlo qui non cambia niente rispetto a
## compilarlo a runtime, e la tabella dei raggi viene letta **dalla fonte** — che
## e' il punto della sezione 18: se il numero fosse messo qui dentro, questa sezione
## confronterebbe una copia con una copia e non saprebbe dire quale sia giusta.
## Se un giorno `enemy.gd` prendesse `Game`, questa riga va spostata a runtime
## insieme alle altre, e va detto qui perche' il difetto sarebbe silenzioso.

const H = preload("res://tools/test_harness.gd")

const DT := 1.0 / 60.0
const PLAYER_SCENE := "res://scenes/player.tscn"
const PLAYER_SCRIPT := "res://src/player/player.gd"
## La scena **vera**, su cui il numero dei nodi conta. Non il montaggio di questo
## test: qui dentro ci sono il doppio finto, il giocatore e l'orda di -orda, e il
## loro numero non dice niente sul criterio n. 5 di m5.
const ARENA_SCENE := "res://scenes/arena_main.tscn"
## L'orda **vera** di -orda, caricata a runtime dalla sezione del restart. E' uno
## script, quindi non ha bisogno della cache di import: e' l'unica parte del
## percorso vero che questo test usa senza `scenes/arena_main.tscn`, che
## `tests/test_progression.gd` e `tests/test_upgrades.gd` caricano per intero.
const HORDE_SCRIPT := "res://src/sim/horde.gd"
## Le specie del nemico, **lette**: `src/sim/enemy.gd` e' di `-orda` e questa
## sezione non lo tocca. `RADIUS` e' la tabella dei corpi e `TOUCH_REACH` e' il
## raggio del corpo del giocatore: due numeri che stanno li' e che il progetto
## ha gia' legato per iscritto (m8 criterio n. 2, m11-quarta criterio 1b).
const ENEMY := preload("res://src/sim/enemy.gd")

## Il layout degli ostacoli di `-orda`/`-sim`, letto dalla **sua** fonte. Serve a
## una sola domanda: se i numeri che la mia scena vede sono gli stessi che il codice
## dichiara, oppure se la mia scena e' stata popolata **prima** che la torre fosse
## montata e con un ripiego. In `src/sim/obstacles.gd` i tre sono **`const`** e non
## c'e' nessun `static var` che li ridomini a runtime (l'unico `static var` del
## file e' `_detto_piatto`, una cache di messaggi), quindi **non possono cambiare da
## una scena all'altra**: il numero che lo dimostra non e' la costante ma
## `Game.obstacles.size()`, cioe' **quanti dischi la mia scena ha davvero**.
const OBST := preload("res://src/sim/obstacles.gd")
## La resistenza al knockback del boss: 0.90 in `src/sim/enemy.gd`. Serve alla
## sezione `_knockback_impulse` per provare che e' **il contratto** a decidere
## quanto il colpo sposta, e non -gameplay a pre-scalare l'impulso.
const BOSS_RESIST := 0.90
## HP alti nel test: cosi' l'attenzione va sulla regola del colpo singolo e non
## su chi muore per primo.
const TOUGH := 100000.0

# --- m9: il raggio dell'arena, scritto qui e come copia dichiarata -------------
#
# ## Che numero e' questo, e di chi e'
#
# `RAGGIO_ARENA` e' una **copia dichiarata** di `src/core/contracts.gd:116`
# (`var arena_radius: float = 60.0`), che a sua volta e' il default della fonte
# unica `src/render/arena.gd:ARENA_RADIUS` (60.0), registrato nel proprio
# `_enter_tree()`. Non e' un terzo proprietario: e' il numero con cui il perno
# confronta quello che il contratto consegna a runtime.
#
# Il 60 e' un **letterale**, e resta un letterale per un motivo preciso: «il raggio
# dell'arena vale 60 m» e' un **perno**. Se lo leggessi dal contratto — o da
# `src/render/arena.gd`, che e' la copia che vince — questa asserzione non
# potrebbe piu' fallire: qualcuno cambierebbe il numero, il test lo leggerebbe
# junto e passerebbe insieme a lui. Un perno si puo' fare solo con un valore
# scritto (piano §1.12-bis). Il tipo della prova **non cambia**: resta un numero
# fisso con cui confrontare, non una lettura che segue il valore.
#
# Il criterio **opposto** — «le copie del raggio non divergono fra loro» — non e'
# questo, e non puo' essere questo: sta in `tests/test_arena.gd`, che e' di
# `-arena`, perche' li' si confrontano le copie e quel file non ha modo di sapere
# se il numero che confronta e' quello giusto. Sono due domande diverse, con due
# file diversi che possono dare due risposte diverse, ed e' per questo che qui il
# numero resta scritto a mano invece di essere letto.
#
# ## Il cambio del 2026-10-14, e cosa vuol dire per una copia
#
# Il vertice ha portato il raggio da **46,0 a 60,0 m** senza avvisare nessuno: le
# foglie hanno scoperto il numero dal gate, e due copie erano ancora a 46,0. Il
# numero nuovo e' giusto — `docs/piramide/probe_survive.gd`, piano
# §1.14-quinque: il caso peggiore di uno schivatore passa da 55,33 s a 146,72 s
# (fattore 2,65), e a 75 m sarebbe 156,33 s (fattore 1,07), quindi il ginocchio
# e' a 60. Ma il difetto non e' il numero: e' che **una copia puo' invecchiare**,
# e questa e' una copia. Percio' la sequenza che vale da qui in poi e' quella
# dichiarata sopra: il vertice cambia la fonte, **avvisa**, e le foglie rispecchiano.
# Il FAIL della porta e' l'avviso che non c'e' stato, e questa riga e' l'unica
# cosa che puo' accorgersene.
#
# ## I numeri che da 35,0 derivano, ricalcolati tutti insieme
#
#   muro sull'asse             35,0 - 0,8 (`ARENA_MARGIN`)  = 34,20 m
#   `x` e `z` in diagonale     34,20 / sqrt(2)              = 24,18 m
#   clamp quadrato             34,20 * sqrt(2)              = 48,37 m
#     ... oltre il muro                                       13,37 m
#   tempo a 7 m/s              34,20 / 7                    =  4,89 s
#   area rispetto a R=28       (35/28)^2 = 1225/784        =  1,56 volte
#   finestra di 2 m sul raggio 2/28 = 7,1%   2/35 = 5,7%
#
# Ogni altro numero di questo file che dipende dal raggio e' **ricalcolato** li'
# dove e' usato, con la formula dichiarata accanto: una copia di un derivato e'
# una copia che mente. La tabella qui sotto e' l'unica cosa che resta col numero
# di prima, ed e' dichiarata come cronologia perche' e' una misura di m9, non un
# atteso di questo file.
#
# ## m12, 2026-10-17: `60,0 -> 35,0`, e perche' questa riga e' cambiata **adesso**
##
## Il vertice ha portato il raggio da **60,0 a 35,0 m** e lo ha dichiarato prima, in
## `src/core/contracts.gd` (`var arena_radius: float = 35.0`) e in
## `docs/piramide/piano.md`. Il numero non e' una scelta estetica: deriva da una
## **misura di `-orda`** — a 20 m il raggio degli ostacoli scende a 1,30 m
## (`RADIUS_FRACTION = 0,065`), `RADIUS[BOSS]` e' 1,90 m, la corona dell'anello
## interno si chiude e **il centro, dove nasce il giocatore, diventa irraggiungibile**.
## Soglia misurata: `R > 29,23 m`; a 35,0 m il margine sugli ostacoli e' del 19,7%.
##
## Quindi il perno di questo file passa a **35,0**. Il fatto che sia cambiato
## rispetto alla mia sessione precedente e' il motivo per cui la riga e' commentata:
## un numero cambiato senza che la foglia lo sentisse e' il falso verde peggiore, e
## questa e' la voce che lo dice invece di lasciare il 60,0 in silenzio.
#
# ## La tabella di m9 come **cronologia**, non come atteso: il perche' 46 e non 40
## era la tabella di densita' di piano §1.12: a 200 nemici il disco libero piu'
## grande passava da 9,5 m (R=28) a 19,1 m (R=46), con l'area libera quasi la
## stessa (85,2% -> 94,6%): il guadagno e' lineare nel raggio e non nell'area,
## perche' l'orda forma un anello di ~9,4 m intorno al giocatore e il muro e' la
## sola cosa che si allontana, e il 40 non compra niente.
const RAGGIO_ARENA := 35.0

# --- m5: la camera REALE, e i numeri che la costruiscono ------------------------
#
# Fino ad ora i test di questo file giravano con la base **identita'**: nessuna
# camera nel viewport, quindi `world_direction` prendeva il suo ripiego. Il gioco
# prende l'altro percorso, quello della camera. E' la ragione per cui W e S
# erano invertiti in gioco e giusti nei test (piano §1.5b): i test esercitavano
# **solo il ripiego**.
#
# Qui sotto la camera e' **ricostruita** con i numeri di `src/render/arena_camera.gd`
# (righe 14-18). Quel file e' di -arena e non e' toccato: i numeri sono
# **dichiarati qui** e la camera viene montata come la monta lui:
#
#     global_position = ancora + Vector3(0, HEIGHT, BACK)
#     look_at(ancora + Vector3.UP * LOOK_HEIGHT, Vector3.UP)
#
const CAM_HEIGHT := 34.0
const CAM_BACK := 24.0
const CAM_LOOK_HEIGHT := 1.0
const CAM_FOV := 62.0
const CAM_NEAR := 0.5
const CAM_FAR := 220.0

## Tetto dell'angolo in gradi per i criteri n. 2 e n. 3 di m5: la stessa
## tolleranza a 5 gradi che il criterio n. 4 di m1 usa sulla traiettoria del
## proiettile, e per la stessa ragione: dentro 5 gradi un colpo va dove deve.
const CAM_ANGLE_TOL := 5.0

## Il giocatore **LONTANO dall'origine**, in metri. Non un dettaglio: all'origine
## `posizione del giocatore + posizione mondo` dà `posizione mondo`, ed e' l'unico
## punto in cui il difetto dei proiettili scortati e' invisibile. Un test che
## misura li' non misura niente (piano §1.5b).
const LONTANO := Vector3(11.0, 0.0, -6.0)

## Il tetto di nodi di **-gameplay** sulla scena vera, cioe' tutta la scena meno
## la HUD (vedi la nota della sezione 13: la HUD e' di `-ui` ed e' cresciuta di
## undici nodi quando `-ui` ha aggiunto il pannello dei potenziamenti, quindi il
## totale di 33 che m5 fissava non e' piu' un numero di questa sezione).
##
## ## 19 -> 20: l'incremento e' di `-arena`, e si dichiara qui
##
## In m10 `-arena` ha aggiunto **un nodo solo** per **27** ostacoli: una
## `MultiMeshInstance3D` costruita una volta sola, che disegna i dischi dal
## contratto. E' il modo giusto di farlo (27 nodi avrebbero spostato la
## ripartizione di 26 e sono esattamente la cosa che questo numero vieta), e
## quindi il tetto passa da 19 a 20 **perche' un'altra foglia ha lavorato bene**.
##
## ## 20 -> 21: l'incremento e' ancora di `-arena` (m11, 2026-10-15) e si dichiara qui.
## Il nodo e' `MortarDome`, una `MultiMeshInstance3D` unica per tutte le cupole del mortar, mai uno per colpo: `node_count` va da 45 a 46 e quel nodo costa uguale con zero cupole e con tutte disegnate — cosi' `-arena` l'ha misurato, invece di aggirarlo con `top_level`.
##
## ## 21 -> 24: l'incremento e' ancora di `-arena` (m15, 2026-10-15) e si dichiara qui.
## Sono **tre nodi**, e sono tutti e tre della stessa forma: `EnemiesBig` ed `EnemyBoss` — i modelli distinti per specie (`enemy_big.glb` ed `enemy_boss.glb`) che gia' esistevano nell'eseguibile e non erano caricati — e `MortarShot`, il colpo del mortar che cade. `node_count` va da 46 a 49; la HUD resta a 25, quindi i nodi non-HUD vanno da 21 a 24 e il tetto di 24 sotto e' quello giusto. Sono tre `MultiMeshInstance3D` e non tre nodi per colpo: e' lo stesso criterio con cui `MortarDome` e i 27 ostacoli sono entrati, e per questo l'incremento si dichiara invece di aggirare la ripartizione.
##
## ## 24 -> 30: l'incremento e' della **torre**, e la voce era definita male (m12)
##
## Fino a ieri questa costante diceva «la scena **meno HUD**», e li' c'era dentro
## anche la torre. `-arena` l'ha misurata e ha avvisato: quella voce oggi vale
## **30**, perche' **la torre e' `6`**.
##
## Il conto del sei, che e' il numero che chiude la cifra: `Ramps` ha **due figli
## diretti** — `RampMesh` e `RampBodies` — e **tre discendenti**, `Ramp0..Ramp2`,
## sotto `RampBodies`. Quindi `Ramps` ne contiene **sei**, non sette: la mia
## scommessa di sette era sbagliata, ed e' la ragione per cui il totale tornava a
## `24 + 7 = 31` invece che a `30`.
##
## **Non e' un tetto che si alza**: e' una voce che era definita male. La differenza
## si vede alla prossima crescita: se la torre aggiungesse un nodo, qui la voce
## «scena meno HUD» salirebbe di uno **per colpa sua**, mentre la voce giusta
## «scena meno HUD **meno la torre**» resterebbe ferma — ed e' quella che un tetto
## deve essere, perche' un tetto sulla voce sbagliata e' **il tetto che ti arriva
## addosso**.
## ## Perche' questo numero resta, e non diventa un assoluto
##
## Non e' un assoluto: e' una **ripartizione** fra le foglie, e una ripartizione
## si muove quando qualcuno aggiunge un nodo ** dichiarando l'incremento qui**.
## Quello che non si muove e' il **tetto vero**, il 120 di `node_count` del
## criterio n. 7, e quello resta il criterio. Questa riga ha un solo difetto
## possibile e resta quello di prima: se **-gameplay** aggiungesse un nodo,
## questa asserzione andrebbe rossa — ed e' quello che deve fare, perche'
## nessun nodo di -gameplay si giustifica da solo.
const NODI_SCENA_VERA := 24

# --- m10: il disco di prova, e perche' i numeri sono qui dentro ----------------
#
# ## La convenzione congelata, letta e non riscritta
#
# Il contratto dichiara `Game.obstacles : PackedVector3Array` e fissa la forma
# dell'elemento (`src/core/contracts.gd`, "Superficie di milestone 10"):
#
#     elemento = Vector3(centro_x, RAGGIO, centro_z)
#
# cioe' **il raggio sta in `y`**. `y` non e' un'altezza e `z` non e' una
# profondita'. Qui sotto il disco e' costruito con quella convenzione perche' e'
# quella che -arena registra e che -orda risolve: costruirlo con un'altra (per
# esempio `Vector3(x, y_altezza, z_raggio)`) farebbe passare questo test con una
# forma che nessuno usa in gioco, che e' il difetto che un doppio di test
# introduce.
const OST_RAGGIO := 2.0
## `x = 0`, **`y = raggio`**, `z = -14`: il disco e' a 14 m davanti al giocatore
## (che parte dal centro), largo 2 m di raggio. Sono numeri scritti, non letti:
## il numero e il raggio degli ostacoli veri sono di `-orda` e di `-arena` e
## non sono dichiarati da nessuna parte (§1.13: «nessuna cifra scritta sopra»), e
## questo test non deve indovinarli.
const OST_CENTRO := Vector3(0.0, OST_RAGGIO, -14.0)
## Il nemico **dietro** al disco: 8 m oltre il centro, quindi 22 m dal
## giocatore, entro la gittata di mira dell'arma (`acquire_radius`). Se fosse
## davanti, il test passerebbe senza che nessun proiettile attraversi niente.
const NEMICO_DIETRO := Vector3(0.0, 0.9, -22.0)
## Quanto dentro il disco il proiettile deve essere arrivato, in metri dal bordo.
## Non e' `> 0`: il proiettile avanza di 0,43 m per frame e il suo raggio e' 0,16,
## quindi un campionamento a frame puo' arrivare vicino al bordo. 1,5 m dentro e'
## un numero che nessun campionamento puo' sbagliare per fortuna.
const OST_ENTRO_DENTRO := 1.5
## Quanti frame il giocatore corre contro il disco prima che lo si dichiari fermo:
## al centro e' a 14 m dal disco e l'aria a regime fa 0,117 m per frame, quindi
## l'arrivo e' intorno al frame 100 e questi 300 sono il triplo.
const M10_PASSI := 300

## --- m7: il budget e il raggio, e perche' nessuno dei due e' scritto a mano ---
##
## `M7_PASSI` e' il **tetto** di quanto la sezione m7 lascia correre la partita
## vera, in passi di `DT`. 900 passi sono 15 s a 60 Hz: la misura di m4 sullo
## stesso numero dice che il primo contatto dell'orda col giocatore arriva a
## 2,28 s, quindi il budget e' piu' di cinque volte quella e il contatto non e'
## un caso fortunato dentro la finestra.
const M7_PASSI := 900
## Il nome del nodo dell'orda nella scena vera. Serve per contare i **duplicati**:
## un totale di nodi identico non distingue «una orda» da «due orde e una
## orda morta» (`src/sim/horde.gd` si chiama cosi' anche nella scena).
const NODO_HORDE := "Horde"
## Il nome del file di -orda dove sta il raggio entro cui un nemico e' «arrivato».
## Non e' una costante perche' il file **non e' mio**: si legge a runtime dal suo
## mapa di costanti, cosi' il numero che questo test confronta e' quello che
## l'orda usa davvero e non una copia che invecchierebbe qui dentro.
const ENEMY_SCRIPT := "res://src/sim/enemy.gd"

# --- m16: la finestra di invulnerabilita' era un tetto di cadenza ---------------
#
# ## Cosa e' successo, in due numeri, e perche' questo file le ricorda
#
# L'utente ha giocato e ha scritto: «quando sono coperto di nemici non mi
# uccidono rapidamente, essere sopraffatti non deve lasciare troppe occasioni,
# morire e' parte del processo in questo tipo di giochi». Il numero che
# spiegava il difetto era `INVULN_AFTER_HIT = 0.7 s` in `src/player/player.gd`:
#
#   - scena vera, **200 nemici, 30 s**: **144 morsi offerti, 39 accettati**.
#     39 e' il **91% del massimo che 0,7 s permetteva** (`1/0,7 = 1,43`
#     colpi/s -> 42,9 in 30 s), cioe' il giocatore era al tetto
#     dell'**invulnerabilita'**, non al tetto dell'orda;
#   - il tetto di cadenza del morso, misurato in m11-quarta, e'
#     `TOUCH_INTERVAL = 0,150 s`: **0,7 s e' 4,7 volte quella**, quindi dei
#     144 morsi circa 105 venivano scartati da un timer e non dal numero di
#     nemici che il giocatore aveva addosso.
#
# Il difetto e' che **essere accerchiato era tanto pericoloso quanto essere da
# solo**. Il vertice ha portato la costante a `0,25 s` (casi sorgente:
# `1/0,25 = 4,00` colpi/s -> 120 in 30 s) e questo file misura se l'offerta
# dell'orda **adesso viene convertita in danno**.
#
# ## Perche' i numeri qui sotto sono scritti e non letti
#
# `M16_VECCHIA` e' il valore **passato**: non lo usa nessun codice, serve solo
# alla frazione di confronto, e scriverlo qui impedisce che la frazione
# segua il valore di gioco e smetta di essere un confronto. `M16_NEMICI` e' una
# **copia dichiarata** di `src/sim/horde.gd:MAX_ENEMIES` (200, riga 128), per la
# stessa ragione di `RAGGIO_ARENA` sopra: il perno e' scritto, e la domanda
# opposta — «le copie del numero divergono?» — e' di `-orda`. Il resto sono
# **tetti di misura** (quanti passi, quanta vita) e **soglie** con la formula
# dichiarata accanto: nessuna e' una copia di un numero di `-orda` o di
# `-arena`.

## Il valore **di prima** della finestra, in secondi. Non lo usa il gioco: e' la
## frazione con cui il numero di adesso viene confrontato, ed e' scritto per
##che' se leggesse `INVULN_AFTER_HIT` non potrebbe piu' fallire.
const M16_VECCHIA := 0.7
## Nemici vivi nella scena vera: copia dichiarata di `src/sim/horde.gd:MAX_ENEMIES`
## (200). Lo scenario e' «coperto», ed e' quello che l'utente ha giocato.
const M16_NEMICI := 200
## Tetto di passi per arrivare a `M16_NEMICI` vivi. Il riempimento va al ritmo di
## `run.spawn_rate()` (ora `Run.SPAWN_RATE = ASSIMILATION_1 * 0.5`, cioe' circa
## 1,02/s: il rateo e' stato dimezzato rispetto a prima per dare respiro al
## giocatore di livello 1), quindi 200 nemici sono ~196 s: 12000 passi sono
## 200 s, circa quello, e il tetto serve a far fallire la sezione invece di
## girare per sempre.
const M16_PASSI_PIENI := 12000
## Passi di riscaldamento **prima** della finestra: l'orda deve arrivare addosso,
## altrimenti la finestra misurerebbe un campo vuoto. 900 passi sono 15 s.
const M16_SCALDATURA := 900
## La finestra di misura, in passi: 1800 sono **30 s**, la stessa durata con cui
## l'utente ha contato 144 morsi offerti e 39 accettati.
const M16_FINESTRA := 1800
## Vita data al giocatore **durante** la finestra. Senza questo la partita
## finirebbe a `game_over` durante la misura (100 hp / 6,4 hp al secondo =
## 15,6 s) e i numeri dopo il primo morso non sarebbero piu' numeri di niente.
## `tests/test_orda.gd` chiama questa leva `VERA_HP_ALTO`.
const M16_HP_ALTO := 1000000.0
## Il cooldown con cui l'arma viene **muta** durante la misura. Non e' una
## scorciatoia: l'arma spara da sola e ucciderebbe proprio gli anelli di nemici
## che questa sezione sta contando (e' la classe di difetto di piano §1.5b:
## un ambiente che azzera la grandezza sotto esame). E' un campo pubblico
## dell'arma e l'unico numero che questa sezione le scrive.
const M16_ARMA_MUTA := 1.0e9
## ## I due perni che decidono il criterio 1, e la loro formula
##
##   perno **43** = `1/0,7 x 30 s` = 42,9: il tetto che la finestra di prima
##     permetteva. Con la costante di prima i morsi accettati erano 39,
##     **sotto** questo numero, e questa sezione deve dire `FAIL`;
##   perno **0,5** = meta' dell'offerta: `M16_CONVERSIONE` sotto.
##
## ## Perche' `1/0,25 x 30 s` = **120 non e' un perno**
##
## Perche' **120 non e' raggiungibile**, misurato: la finestra non e' l'unico
## limite. `TOUCH_INTERVAL = 0,150 s` mette il tetto alle richieste, e l'offerta
## reale sulla scena vera e' **4,97 morsi/s** (149 offerti in 30 s con 26 nemici
## a portata), non i 6,67/s del tetto; e un'offerta che arriva 0,05 s dopo la
## chiusura della finestra **non aspetta**: la finestra si riapre col morso
## successivo e il colpo resta scartato. Con la finestra di 0,25 s si misurano
## **88 accettati**, cioe' il 73% di 120. Un tetto che non si puo' raggiungere
## non e' un tetto, e' un numero decorativo: e' la stessa regola dei due perni
## sopra, e il primo tentativo di questo file (soglia 96 = 80% di 120) e' stato
## **tutto** perche' misurava un numero che il gioco non produce.
##
## Quindi i due perni sono l'uno contro l'altro e dicono la cosa giusta: i
## morsi accettati sono **sopra** il tetto della finestra lunga e sono **meta'
## dell'offerta**.
##
## ## Il dente, eseguito il 2026-10-15, con i numeri di oggi
##
## Costante rimessa a `0,7` e questa sezione eseguita cosi' com'e':
##
##   offerti 149, **accettati 39**, conversione **26%** -> i due perni vanno
##     entrambi rossi (`39 <= 43` e `26% < 50%`) e il `FAIL` li nombra uno per
##     uno. Con `0,25`: 149 offerti, **88 accettati**, conversione **59%**.
##
## Il numero del vertice (39 su 144 offerti, 27%) e' stato **riprodotto**: la
## differenza fra 144 e 149 e' la disposizione dell'orda, che non ha seme
## (`src/sim/horde.gd::_build()` fa `randomize()` quando `seed == 0`, il difetto
## aperto di m11-bis, che resta di `-orda`).
const M16_TETTO_VECCHIO := 43
## Quanta parte dell'offerta deve diventare danno: **meta'**. Prima della m16 il
## rapporto era 39/144 = **27%** (misurato 26% nel dente); con la finestra corta
## deve salire, e questa soglia e' quella che distingue «l'offerta entra» da
## «l'offerta viene scartata da un timer».
const M16_CONVERSIONE := 0.5
## Tetto di passi per la misura del tempo di morte: 3600 sono 60 s, e i due
## tempi misurati sono **223 passi (3,72 s)** con la finestra di 0,25 s e **776
## passi (12,93 s)** con quella di 0,7 s: il tetto e' cinque volte il primo e
## due volte e mezzo il secondo, quindi non e' un tetto che decide nessuna
## asserzione. Se il numero di sotto non scende, il difetto **non** e' la
## finestra: la sezione lo dice e il numero di `src/player/player.gd` non si
## tocca per farlo scendere.
const M16_PASSI_MORTE := 3600
## Passi del criterio 3 (una sola finestra): 600 sono 10 s, cioe' quaranta finestre
## da 0,25 s e quattordici da 0,7 s: abbastanza per vedere **entrambi** i rami,
## cioe' un colpo che entra e un colpo che viene rifiutato.
const M16_PASSI_UNA := 600
## Il danno del colpo di prova del criterio 3, in hp. Piccolo **per scelta**: in
## 10 s la finestra di 0,25 s lascia entrare circa 40 colpi, e 40 x 1,0 = 40 hp
## stanno bene dentro i 100 del giocatore; un danno piu' grosso lo ucciderebbe
## a meta' finestra e il resto della sezione misurerebbe un giocatore morto.
const M16_DANNO_PROVA := 1.0

# ================================================================================
# m12: la torre — quattro piani di 20 m, e i quattro criteri che ne seguono
# ================================================================================
#
# ## I due numeri sono un **perno scritto**, e non una lettura
#
# `M12_PIANI` e `M12_ALTEZZA_PIANO` sono una **copia dichiarata** della decisione
# del vertice (piano, «Quattro piani, uno per bioma»: quattro dischi di raggio
# 20 m impilati, 20 m ciascuno) e del default del contratto
# (`var floor_count: int = 1`, `var floor_height: float = 0.0`, che il vertice ha
# scritto **di proposito** a `1` e `0,0`: «non c'e' una torre»).
#
# Perche' sono scritti e non letti dal contratto: e' la stessa ragione di
# `RAGGIO_ARENA` piu' in alto. Un perno si puo' fare solo con un valore scritto —
# se lo leggessi dal contratto, qualcuno cambierebbe il numero, il test lo leggerebbe
# junto e passerebbe insieme a lui. La domanda **opposta** — «le copie divergono?» —
# non e' qui: e' di `-arda`, che e' chi registra i due numeri.
const M12_PIANI := 4
const M12_ALTEZZA_PIANO := 20.0

# ================================================================================
# m12a: `player_floor()` non e' `floor_of(y)`, e il conto e' fatto qui
# ================================================================================
#
# ## Perche' qui il camminamento **non** e' fatto a mano
#
# La prima stesura di questa sezione alzava `position.y` a mano e contava i
# campioni in cui la regola e `floor_of` discordavano. Con la regola di allora
# («piedi fermi -> piano dell'altezza») quel percorso descriveva esattamente
# quello che faceva il gioco.
#
# **Adesso non lo descrive piu'.** La regola e' «chiedi alla superficie», e un
# giocatore alzato a mano **non e' dentro nessun corridoio di rampa**: la
# superficie risponde `-1,0` ovunque, la regola cade su `floor_of(y)` e i due
# concordano **sempre**. Il numero tornava `discordi = 0` e la riga andava rossa
# per il motivo sbagliato: la regola era giusta, il test guardava un istante che
# il gioco non attraversa. E' la trappola di piano §1.5b, che qui si e' morso
# da sola.
#
# Quindi la salita si prova **dentro** il canale, in `_m12_provino_superficie`,
# che monta la superficie di prova e campiona **durante** la salita. Qui resta
# solo la meta' che non ha bisogno di nessun canale e che e' vera per costruzione:
# **fuori da ogni corridoio, il piano e' quello dell'altezza**.
const M12_CAMPIONI_PER_PIANO := 40

# ================================================================================
# m12b: gli ostacoli sono per piano, e il piano si legge dalla posizione
# ================================================================================
#
# Tre dischi per piano invece dei 27 veri: la forma che la sezione prova e' la
# **divisione** `size / floor_count`, che e' la stessa con 3 che con 27. I tre
# dischi di ogni piano stanno **allo stesso x e z degli altri tre**: e' l'unico
# modo in cui «il piano 2 non e' fermato dal disco del piano 0» sia una frase che
# puo' diventare rossa.
const M12_OST_PER_PIANO := 3
const M12_OST_RAGGIO := 2.0
const M12_OST_CENTRO := Vector3(0.0, M12_OST_RAGGIO, -14.0)
## Il piano su cui la sezione mette il giocatore per la prova «non e' fermato dagli
## ostacoli di un altro piano». Scelto **non al piano 1**: il piano 2 e' l'ultimo
## prima del boss ed e' quello che il piano descrive come «bioma 4», e sceglierlo
## evita che la prova passi perche' la torre ha un solo piano.
const M12_PIANO_PROVA := 2

# ================================================================================
# m12e: l'impatto e' per piano, e la prova ha denti per costruzione
# ================================================================================
#
# Tre nemici, uno per piano, con le distanze **diverse anche nel piano XZ**:
#
#     indice 0   piano 0   z = -4,0 m    il PIU' VICINO di tutti
#     indice 1   piano 1   z = -6,0 m    il piu' lontano
#     indice 2   piano 2   z = -5,0 m    il secondo
#
# La scelta delle distanze e' cio' che dà i denti, e non un dettaglio: il nemico
# **del piano giusto** non e' mai il primo dell'array **e** non e' mai il piu'
# vicino nel piano XZ, quindi un contatto che ignora la quota lo prende **sempre**,
# e un contatto che ignora la quota e prende il primo indice lo prende ugualmente.
# Percio' sui piani 1 e 2 questa sezione va **rossa** togliendo il filtro.
## ## Il quarto piano, e la tabella che doveva crescere con lui
##
## `M12_PIANI` e' passato a **4** con la torre e questa tabella e' rimasta a **3** voci:
## il ciclo `for e in M12_PIANI` chiedeva l'indice `3` e il file moriva con
## `Out of bounds get index '3'`. E' la classe di difetto che il vertice ha chiamato
## «un numero senza data non dice quando smette di valere»: **questa tabella aveva una
## data implicita — i tre piani — e la torre le ha tolto senza avvisare.**
##
## Il valore del quarto piano e' **dichiarato qui**, non copiato: la sua proprieta' non
## e' il numero, e' che **nessun piano condivida la distanza con un altro**, quindi il
## nemico piu' vicino nel piano XZ resta diverso dal nemico di ogni altro piano — che
## sono i due denti di questa sezione. La tabella e' in **ordine di indice**, non in
## ordine di distanza (`4 / 6 / 5 / 7`, e non `4 < 5 < 6 < 7`): l'ho scritto al
## contrario e la misura me l'ha negato, quindi la proprieta' dichiarata e' **tutte
## diverse** e non «crescenti».
const M12_NEMICO_Z := [-4.0, -6.0, -5.0, -7.0]

## Una voce per piano, e la guardia che lo dice. Il numero e' **quello che sarebbe
## crashato**: `M12_NEMICO_Z.size()` deve essere `M12_PIANI`, e se la torre cresce
## ancora questa riga va rossa **prima** che il ciclo legga fuori confine, invece di
## far morire il file su un indice.
const M12_NEMICO_Z_PER_PIANO := M12_PIANI

## La pendenza della **rampa di prova** di `_m12_salita`, in metri di quota per
## metro di corsa. Non e' la pendenza di `-arda` (20 m su 24 m di corsa = **0,83**):
## e' **volutamente piu' ripida**, e il motivo e' che il criterio ha bisogno di una
## distanza **netta** fra «sale» e «si ferma al primo bordo». Con la pendenza vera
## la rampa di prova attraverserebbe un bordo solo dopo molti secondi e il
## criterio non potrebbe distinguere il latch da `floor_of(y)`: qui un secondo e
## mezzo di corsa porta a 67 m di quota, cioe' **oltre due bordi**.
const M12_PENDENZA_PROVA := M12_ALTEZZA_PIANO / 4.0
## Quanti passi dura la salita di prova. `120` a DT 1/60 sono **2,0 s**, cioe'
## ~13,5 m di corsa a 7 m/s, che con `M12_PENDENZA_PROVA` danno ~67 m di quota: il
## criterio pretende **oltre `3 * M12_ALTEZZA_PIANO`**, e `floor_of(y)` si fermerebbe
## a `M12_ALTEZZA_PIANO`. La finestra e' scritta perche' e' una **finestra di
## misura** e non un numero di gioco: sotto i ~90 passi la rampa di prova non
## attraversa nemmeno il primo bordo e la sezione non avrebbe denti.
const M12_PASSI_RAMPA_PROVA := 120

# ================================================================================
# m12c/d: la salita e la nascita, e la finestra di misura che le deriva
# ================================================================================
#
# ## Il tetto di passi e' **derivato**, non scritto
#
# Il cammino minimo per attraversare la torre e' `altezza totale / velocita' di
# corsa`, e la velocita' di corsa e' un **campo del giocatore vivo** (`move_speed`,
# che un potenziamento puo' aver cambiato): leggere la costante `MOVE_SPEED` qui
# sarebbe una copia che invecchia. Il fattore e' una **finestra di misura**, non un
# numero di gioco: la rampa e' un cammino **piu' lungo** dell'altezza e la sua
# pendenza non e' scritta da nessuna parte, quindi il tetto non puo' essere il
# minimo geometrico e non puo' essere indovinato — e il numero che manca e'
# dichiarato nel report.
const M12_SALITA_FATTORE := 6.0
## Quante prove `random_spawn_point()` fa per dire che non restituisce mai
## `Vector3.ZERO`. ZERO e' ambiguo perche' e' **anche sotto il giocatore**, quindi il
## canale lo usa come «non implementato» e un punto di nascita a ZERO significherebbe
## «nascosto sotto i piedi del giocatore». Sedici e' un numero di **campionamento**,
## non un tetto di logica: la proprieta' richiesta e' «mai», e il numero di prove
## e' quello che rende la parola «mai» una parola.
const M12_SPAWN_PROVE := 16

## L'orda finta. Doppio di -orda: `count` + `transforms` come dati, e i due
## metodi registrati sul contratto.
class FakeHorde extends Node:
	## NOTA PER IL VERTICE (piano §5.3): questo file non puo' usare l'identificatore
	## nudo `Game` nella sua classe interna, e non per il contesto ma per il
	## **momento**: vedi la nota sul caricamento in testa al test. Il contratto
	## `Game` qui e' un campo, passato dal test con `root.get_node_or_null`.
	var game
	## I due campi pubblici che il piano dichiara come "massa".
	var count: int = 0
	var transforms := PackedVector3Array()
	## Paralleli a `transforms`, tutti indicizzati come i nemici.
	var hp := PackedFloat32Array()
	var hits := PackedInt32Array()
	var vel := PackedVector3Array()
	## La **specie** di ogni nemico, allineata come gli altri. Non e' decorativa:
	## dal 2026-10-15 il proiettile prende il nemico con il raggio del **corpo
	## che si vede**, e il corpo dipende dalla specie (`src/sim/enemy.gd:RADIUS`
	## per l'attore). Un doppio che non pubblicasse `kinds` farebbe cadere il
	## pool nel suo ripiego — il raggio piu' piccolo della tabella — e la sezione
	## che segue misurerebbe il ripiego invece del gioco.
	var kinds := PackedInt32Array()
	## Quanto knockback il nemico si mangia, come fa `damage_enemy` in -orda:
	## `vel += knockback * (1 - resist)`. Le resistenze vere sono 0 / 0.20 /
	## 0.55 / 0.90 per runner, grunt, brute, boss (`Enemy.KNOCKBACK_RESIST`), e
	## quel file non e' mio: qui si mettono a mano i due valori che servono,
	## `0.0` di default e quello del boss dove il test prova che la scala e' del
	## contratto.
	var resist := PackedFloat32Array()
	## La dinamica qui sotto e' quella **vera** di `src/sim/enemy.gd`: smorzamento
	## di primo ordine, non un `drag`. La prima versione di questo file aveva un
	## `drag` scritto a mano e misurava il knockback su quello: era una fisica
	## che in gioco non esiste, e il numero che ne usciva non diceva niente del
	## gioco. Lo sa anche `tests/test_arena.gd`, che lo dice a sua volta.
	var chase_speed := 6.6      ## m/s, `Enemy.SPEED[runner]`, il piu' veloce
	var accel := 8.0            ## 1/s, `Enemy.ACCEL` (tau = 0.125 s)
	## Sottoinsieme dichiarato, perche' un doppio che mente e' peggio di un
	## doppio che manca: qui dentro si muove **un** nemico solo, lontano dal
	## muro, e nessuna asserizione di questo file guarda la sua traiettoria. Quindi
	## mancano di proposito `SPEED_MAX`, `ARRIVE_RADIUS`, la separazione e la banda
	## elastica sul bordo. Se un domani volesse misurare qui dentro lo
	## spostamento di un nemico, questa lista e' il primo posto da rileggere: la
	## misura vera e' in `tests/test_arena.gd`, sulla scena vera.
	## Cosa insegue. Il giocatore di turno e' a zero.
	var target := Vector3.ZERO
	## Contatori, per il test.
	var damage_calls := 0
	## Quante volte `damage_enemy` ha risposto `true`. E' il numero che l'XP
	## deve combaciare: se l'XP salisse senza che il contratto avesse detto
	## "morto", qui resterebbe a zero e il test se ne accorgerebbe.
	var kill_signals := 0
	var deaths := 0
	var out_of_range := 0
	## L'impulso di knockback **come il gameplay lo ha consegnato**, prima che
	## questa classe vi applichi la resistenza: e' cosi' che il test guarda il
	## numero di -gameplay e non quello riscalato dal doppio.
	var last_knockback := Vector3.ZERO
	## La velocita' del nemico subito prima e subito dopo l'ultimo colpo. Servono
	## perche' il nemico **insegue gia'**: la sua velocita' quando arriva il colpo
	## non e' l'impulso, e' l'inseguimento piu' l'impulso. Leggendo la velocita'
	## come se fosse l'impulso si misurerebbe di nuovo l'inseguimento, che e' uno
	## dei due errori gia' documentati in piano 5.4. La **differenza** delle due
	## e' l'impulso tenuto, ed e' quello che il contratto promette.
	var vel_before_hit := Vector3.ZERO
	var vel_after_hit := Vector3.ZERO

	func _ready() -> void:
		# Registrazione vera, con il nome vero: se il gameplay sbaglia la
		# registrazione, `damage_calls` resta a zero e il test se ne accorge.
		game.horde = self
		game.register_impl("damage_enemy", self._damage_enemy)
		game.register_impl("nearest_enemy", self._nearest_enemy)
		# ## `touch_interval`: anche il produttore finto lo registra
		#
		# Dal m12 2026-10-18 la finestra antidoppio-conteggio di `player.gd` e'
		# **derivata** da `Game.touch_interval()`. In questo file il produttore e' una
		# classe di prova, quindi il canale esiste solo se **anche lei** lo registra:
		# senza questa riga `Game.touch_interval()` risponde `-1,0`, il giocatore cade
		# sul numero dichiarato con un `push_warning`, e le sezioni che misurano la
		# finestra non avrebbero piu' niente da confrontare.
		#
		# Il valore e' quello **dichiarato** di `-orda` (`src/sim/horde.gd:519` =
		# `0,150 s`), letto e non scritto qui sotto: questo file non puo' fare `preload`
		# di `horde.gd` perche' `horde.gd` preloada `run.gd`, quindi la copia e' imposta
		# dal grafo delle dipendenze — ed e' un duplicato che aspetta la prima volta che
		# il grafo cambia.
		game.register_impl("touch_interval", Callable(self, "_touch_interval_dichiarata"))

	## Il `TOUCH_INTERVAL` **dichiarato** di `-orda`. Copia imposta dal grafo delle
	## dipendenze: `horde.gd` preloada `run.gd`, quindi qui dentro non si puo' fare
	## `preload` di `horde.gd` senza ciclo. Il numero **esercitato** e' `0,1667 s` e la
	## differenza e' un accumulo in virgola mobile dentro `_apply_bites()`: la riga che
	## le due cose insieme e' `src/player/player.gd`.
	func _touch_interval_dichiarata() -> float:
		return 0.15

	func add(pos: Vector3, hp_value: float = 1000.0, kind: int = 0) -> int:
		transforms.append(pos)
		hp.append(hp_value)
		hits.append(0)
		vel.append(Vector3.ZERO)
		kinds.append(kind)
		resist.append(0.0)
		count += 1
		return count - 1

	func clear() -> void:
		count = 0
		transforms = PackedVector3Array()
		hp = PackedFloat32Array()
		hits = PackedInt32Array()
		vel = PackedVector3Array()
		kinds = PackedInt32Array()
		resist = PackedFloat32Array()
		damage_calls = 0
		kill_signals = 0
		deaths = 0
		out_of_range = 0
		last_knockback = Vector3.ZERO
		vel_before_hit = Vector3.ZERO
		vel_after_hit = Vector3.ZERO

	## Quanto impulso ha tenuto davvero l'ultimo colpo, in m/s: la differenza
	## fra la velocita' di prima e quella di dopo, non la velocita' di dopo.
	func charge() -> float:
		return (vel_after_hit - vel_before_hit).length()

	func resist_of(i: int) -> float:
		return resist[i] if i >= 0 and i < count else -1.0

	## La resistenza si mette a mano **dopo** `add()`, perche' `add()` deve
	## tenere gli array paralleli della stessa lunghezza e chi le riempie non e'
	## questo test.
	func set_resist(i: int, value: float) -> void:
		if i >= 0 and i < count:
			resist[i] = value

	func hp_of(i: int) -> float:
		return hp[i] if i >= 0 and i < count else -1.0

	func hits_of(i: int) -> int:
		return hits[i] if i >= 0 and i < count else -1

	func pos_of(i: int) -> Vector3:
		return transforms[i] if i >= 0 and i < count else Vector3.ZERO

	## La velocita' del nemico, come il contratto ce l'ha lasciata dopo avervi
	## sommato l'impulso di knockback.
	func vel_of(i: int) -> Vector3:
		return vel[i] if i >= 0 and i < count else Vector3.ZERO

	## Il contratto (piano §5.2): danno agli HP, spinta, e `true` se il nemico e'
	## morto. Il ritorno e' la cosa che -gameplay usa per l'XP: se questo
	## finto non lo restituisse, l'XP del test non salirebbe e si vedrebbe.
	## `knockback` e' gia' un vettore con la velocita' dentro (m/s), non una
	## direzione da normalizzare: e' quello che si aspetta `weapon_base.gd`, e
	## quello che rende il knockback leggibile in 2-3 frame invece che
	## impercettibile. Il suo modulo NON e' la misura del criterio n. 4: la
	## misura e' lo spostamento, e lo misura il test.
	func _damage_enemy(index: int, amount: float, knockback: Vector3) -> bool:
		damage_calls += 1
		if index < 0 or index >= count:
			out_of_range += 1
			return false
		hits[index] += 1
		hp[index] -= amount
		last_knockback = knockback
		vel_before_hit = vel[index]
		vel[index] += knockback * (1.0 - resist[index])
		vel_after_hit = vel[index]
		if hp[index] <= 0.0:
			_remove(index)
			deaths += 1
			kill_signals += 1
			return true
		return false

	## Il contratto (piano §5.2): l'INDICE del nemico piu' vicino, `-1` se non
	## c'e' nessuno. E' lo stesso indice che `damage_enemy` accetta, quindi il
	## gameplay non deve fare nessuna conversione.
	func _nearest_enemy(from: Vector3, radius: float) -> int:
		var best := -1
		var best_d2 := radius * radius
		for i in count:
			var d := transforms[i] - from
			d.y = 0.0
			var d2 := d.length_squared()
			if d2 <= best_d2:
				best_d2 = d2
				best = i
		return best

	## Un frame di orda: insegue e si lascia spingere, con la **stessa legge** di
	## `src/sim/enemy.gd`, cioe' `vel += (wanted - vel) * min(1, dt * ACCEL)`.
	## Non c'e' nessun `drag` nell'orda vera e nessun `drag` qui: e' quello il
	## campo che non esisteva e che aveva fatto fallire questo file.
	func step(delta: float) -> void:
		var k: float = minf(1.0, delta * accel)
		for i in count:
			var toward := target - transforms[i]
			toward.y = 0.0
			var dir := Vector3.ZERO
			if toward.length() > 0.001:
				dir = toward / toward.length()
			vel[i] += (dir * chase_speed - vel[i]) * k
			transforms[i] += vel[i] * delta

	## Mossa con lo swap con l'ultimo, come l'orda vera: e' il caso che
	## sposta gli indici sotto i piedi del gameplay.
	func _remove(index: int) -> void:
		count -= 1
		if index == count:
			return
		transforms[index] = transforms[count]
		hp[index] = hp[count]
		hits[index] = hits[count]
		vel[index] = vel[count]
		kinds[index] = kinds[count]
		resist[index] = resist[count]

# --- Stato del test ------------------------------------------------------------

var game: Node
var horde: FakeHorde
var player: Node3D
var weapon
var pool

## La mappa delle risposte di `surface_height_at` per piano, campionata sulla
## **prima** scena `arena_main.tscn` montata da questo file. Vive qui perche'
## `register_impl` **non ha una via per annullare** una registrazione: il canale che
## risponde e' quello dell'ultima scena montata, quindi una sezione che ne monta una
## e poi libera la propria interroga il canale di un oggetto liberato. La mappa
## viene presa una volta sola, con la scena viva, e le sezioni dopo la leggono.
var _mappa_viva := {}

var _h
var _ran := false
## ## Lo stato della **superficie di prova** di `_m12_salita`, e perche' e' un
## ## dizionario e non cinque variabili
##
## Il dizionario e' un **riferimento**: e' il modo che questo file usa gia' per
## `_m16_tetto` e per `_conta_danno`, e il motivo e' che una lambda di GDScript
## cattura per **valore** — con variabili locali il doppio scriverebbe una copia e
## la prova leggerebbe sempre zero, che e' indistinguibile da «non e' mai stato
## collegato».
##
## `piano_chiesto_max` e' il **piano piu' alto** che il canale ha ricevuto, e
## rende questa sezione un criterio sulla mia `_player_floor()` e non solo sulla
## lettura della superficie: durante la salita `floor_of(y)` direbbe un piano
## diverso da quello da cui si e' partiti, e la rampa va chieduta con **quello**.
var _superficie: Dictionary = {
	"rampa": false,
	"q": -1.0,
	"pendenza": 0.0,
	"chiamate": 0,
	"piano_chiesto_max": -1,
}
var _t0 := 0
## La regolazione **di partenza**, letta dall'istanza viva subito dopo l'avvio e
## prima che una sola sezione la sporchi.
##
## ## Perche' esiste, e il difetto che ha scoperto
##
## Il restart era confrontato contro uno `vita0`/`corsa0`/`spinta0` letti **all'inizio
## della sezione del restart**, e a quel punto la sezione 5 aveva gia' applicato tre
## potenziamenti: la spinta era 23.4 (18 x 1.3, il prodotto di un rialzo
## deliberato), la vita massima 120 (100 + 20) e la corsa 8.47. Il test si
## aspettava quindi quei numeri sporchi e il codice, che riporta tutto alla
## **regolazione di partenza** (18.0, 100.0, 7.0, i valori di `weapon_base.gd` e
## `player.gd`), falliva su un difetto che non aveva.
##
## Il riferimento giusto e' l'unico che non dipende dall'ordine delle sezioni: lo
## stato **vergine**, preso qui sotto. Ed e' anche la prova che `KNOCKBACK` non e'
## stato alzato in m2 (piano §1.2, conseguenza n. 2): il numero di partenza e'
## 18.0 e resta 18.0 dopo il restart.
var _prima: Dictionary = {}

## Niente qui dentro. Il corpo del test gira al primo frame, non in
## `_initialize()`: un nodo aggiunto a `root` **durante** `_initialize()` non ha
## ancora il `_ready` (la radice non e' ancora dentro la scena), e tutta la parte
## importante di questo progetto - la registrazione sul contratto - sta nel
## `_ready`. Verificarlo in un ordine sbagliato farebbe fallire un test sulle
## cose che funzionano.
func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	_h = H.new()

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	var h: H = _h
	# Il **primo** censo, prima di qualsiasi sezione: e' il numero di partenza da cui
	# confrontare gli altri. Se `ArenaMain` compare gia' qui, la sezione che l'ha
	# montata gira **prima di tutte** e non e' nessuna di quelle che montano dopo.
	_censo_di_root("all'inizio del file")
	_stampa_la_tabella()
	_setup(h)
	# Se il cablaggio non c'e', le sezioni seguenti crasherebbero una dopo l'altra:
	# si esce subito e il FAIL e' il messaggio vero, non un errore a cascata che
	# coprirebbe la causa.
	if player != null and weapon != null and pool != null:
		_movement(h)
		# m12: quante direzioni l'input offre davvero. Va **qui**, accanto a
		# `_movement`, perche' `input_vector()` e' la funzione che `_movement` sta
		# usando: il numero che esce e' la risoluzione con cui il gioco legge
		# l'input, e va detto nello stesso posto in cui l'input viene letto.
		_m12_direzioni_input()
		_autofire(h)
		_single_hit(h)
		_overlapping_enemies(h)
		_knockback_impulse(h)
		_damage_and_iframes(h)
		# m16, criterio 3: una sola finestra e non due. Va **qui**, subito dopo
		# la sezione 4b, perche' e' l'unica sezione di m16 che parla col
		# **giocatore di questo file**: il contratto deve ancora puntare a lui, e
		# dopo `_restart_run` punta a un giocatore della scena vera. Se girasse
		# piu' in la', misurerebbe la finestra di un altro nodo.
		_m16_una_finestra(h)
		_xp_and_upgrades(h)
		_no_allocation(h)
		_censo_di_root("dopo _no_allocation")
		# m10, criterio n. 6. Vanno qui, **prima** delle sezioni che istanziano
		# `scenes/arena_main.tscn`: quelle lasciano il contratto puntato su un
		# giocatore e su un'orda che non sono quelli, e una sezione che spara
		# misurerebbe la muzzle di un giocatore che non e' il suo.
		_m10_giocatore_solido(h)
		_m10_proiettili_passano(h)
		# m14-a: l'involucro di contatto del proiettile. Va **qui**, dopo le due
		# sezioni di m10 e prima del restart: ha bisogno del doppio finto sul
		# contratto (per i tiri di prova) e monta e libera ordi vere solo per
		# chiedere a `-orda` la portata del morso, quindi non puo' stare dopo
		# `_restart_run`, che installa l'orda vera e non restituisce il contratto.
		_m14a_involucro(h)
		_censo_di_root("dopo _m14a_involucro")
		# Criterio n. 4 di m2, meta' di -gameplay. Instala l'orda **vera** di
		# -orda, che prende il contratto: da qui in avanti questa sezione parla
		# con l'orda vera e non piu' con il doppio finto delle altre.
		_restart_run(h)
		# m13-w3: le due segnalazioni dell'utente. Va **qui**, dopo il restart e
		# prima di m5, perche' `_restart_run` e' la sezione che installa l'orda
		# **vera** (`game.horde`) e il giocatore su cui la finestra della morte
		# spara davvero; e `_tasto_reale` monta la scena vera e poi **r restituisce
		# il contratto** al giocatore di questo file, quindi le sezioni dopo
		# trovano il mondo come lo aspettano.
		_fuoco_dopo_morte(h)
		_censo_di_root("prima di _tasto_reale")
		_tasto_reale(h)
		# m5: i due difetti che nessuna porta poteva vedere, e i due test che
		# oggi li vedono. Vanno per ultimi perche' toccano il contratto e
		# l'albero degli attori.
		_m5_ingresso_su_schermo(h)
		_m5_trasformazione_del_renderer(h)
		_censo_di_root("dopo _m5_trasformazione_del_renderer")
		_m5_nessun_nodo_in_piu(h)
		_censo_di_root("dopo _m5_nessun_nodo_in_piu")
		# m7: la salute sulla **scena vera**. Va per ultima perche' installa un
		# secondo giocatore e una seconda orda sul contratto, e le sezioni di m5
		# contano i nodi di quella che hanno appena liberato.
		_m7_salute_sulla_scena_vera(h)
		# m10, criterio n. 6, terza meta': il **contratto**. Va per ultima
		# perche' instanzia la scena vera come fanno gia' le due sezioni
		# precedenti, e dopo questa riga non resta piu' nessuna sezione che
		# guardi il contratto con la scena sotto.
		_m10_ostacoli_del_contratto(h)
		# m11-bis: la sezione vera eseguita N volte. Va per **ultima** perche'
		# monta `scenes/arena_main.tscn` come fanno le tre precedenti e non
		# restituisce il contratto a nessuno.
		_m11bis_determinismo(h)
		# m16, criteri 1 e 2: la finestra come **tetto di cadenza**, misurata
		# sulla scena vera con 200 nemici. Va dopo m11-bis e prima dell'audio
		# perche' monta `scenes/arena_main.tscn` come m11-bis e perche' **resta
		# in albero** fino alla fine del frame (`queue_free` dentro un `--script`
		# non libera niente, vedi `_libera`): quindi e' l'ultima sezione che
		# lascia una scena appesa, e l'audio deve contare i nodi su un albero di
		# cui conosce i numeri.
		_m16_tetto(h)
		# L'audio di -gameplay. Va per **ultima** perche' usa il giocatore di
		# questo file e non tocca la scena vera, ma i montaggi m11-bis non
		# devono vedere niente di cio' che succede qui: quindi nessuna sezione
		# dopo questa, e questa non gira dentro nessun montaggio.
		#
		# **Nessun `await`**: la sezione non aspetta nessun frame. Il meccanismo
		# di `player.gd` chiude i suoni da `step()`, e `step()` qui è chiamato a
		# mano dentro il ciclo, quindi tutto quello che questa sezione misura è
		# già vero quando la sezione finisce. Non toccare `_process()` per
		# questo: convertire il test a coroutine è stato un giro di refazione
		# inutile, e qui non serve.
		var costo_audio := _audio_usa_e_getta(h)
		print("gameplay: sezione audio: %d ms" % costo_audio)
		var costo_bonk := _audio_bonk(h)
		print("gameplay: sezione bonk: %d ms" % costo_bonk)
	print("gameplay: test terminato in %d ms" % (Time.get_ticks_msec() - _t0))
	quit(h.finish("test_gameplay"))
	return true

# --- 0. La porta, la registrazione, e la prova che il contratto lavori ----------

func _setup(h) -> void:
	game = root.get_node_or_null("Game")
	if not h.check(game != null, "l'autoload Game manca: nessun test delle foglie puo' partire"):
		return
	# IL PERNO di m9. Il numero e' scritto qui (`RAGGIO_ARENA`, in testa al file),
	# che e' una **copia dichiarata** di `src/core/contracts.gd:116`, e non letto da
	# `src/render/arena.gd`: leggerlo renderebbe questa riga incapace di fallire,
	# perche' seguirebbe il numero invece di sorvegliarlo.
	# La domanda «le copie divergono?» e' un'altra, ed e' in `tests/test_arena.gd`.
	h.near(game.arena_radius, RAGGIO_ARENA, 0.001, "arena_radius di default")

	horde = FakeHorde.new()
	horde.name = "FakeHorde"
	horde.game = game
	root.add_child(horde)
	h.check(game.horde == horde, "l'orda finta registra Game.horde")
	h.check(game.has_impl("damage_enemy"), "l'orda registra damage_enemy sul contratto")
	h.check(game.has_impl("nearest_enemy"), "l'orda registra nearest_enemy sul contratto")

	# mezzo del criterio n. 4: il contratto deve essere **interrogato davvero**,
	# non solo registrato con il nome giusto. Un doppio che si registra e non
	# viene mai chiamato passerebbe tutte le sezioni sotto senza aver provato
	# niente: nessun `damage_calls`, nessun danno, nessun knockback, e il test
	# direbbe lo stesso "PASS". Qui lo si chiama a mano, attraverso `game`, e si
	# controlla che arrivi indietro la risposta giusta.
	horde.add(Vector3(0.0, 0.9, -10.0), TOUGH)
	horde.add(Vector3(9.0, 0.9, -10.0), TOUGH)
	# I due 26.0 e 5.0 qui sotto sono **raggi di interrogazione**, non copie del
	# raggio dell'arena: e' la distanza entro cui si cerca un bersaglio, e nessuna
	# delle due ha a che fare con `arena_radius` (che ora e' 60). Sono due numeri
	# diversi e si vedono diversi: il primo trova i due nemici a 10 m e 13,5 m, il
	# secondo non trova nessuno perche' 5 m < 10 m, quindi il contratto onora il
	# raggio che riceve. Sul disco da 60 m coprono il 43% e l'8% del raggio:
	# nessuno dei due e' diventato triviale per la crescita dell'arena, perche' la
	# distanza dei nemici qui dentro e' scritta a mano e non e' mai stata legata
	# al raggio.
	h.eq(game.nearest_enemy(Vector3.ZERO, 26.0), 0,
		"nearest_enemy via contratto: l'indice del nemico piu' vicino")
	h.eq(game.nearest_enemy(Vector3.ZERO, 5.0), -1,
		"fuori raggio nearest_enemy risponde -1, che vuol dire nessun bersaglio")
	h.eq(horde.damage_calls, 0, "e nessun colpo e' partito solo per aver fatto la domanda")

	var knock := Vector3(0.0, 0.0, -9.0)
	var killed_by_contract: bool = game.damage_enemy(0, 7.0, knock)
	h.eq(horde.damage_calls, 1, "damage_enemy via contratto arriva davvero al doppio")
	h.eq(horde.hits_of(0), 1, "e ha colpito una volta sola")
	h.near(horde.hp_of(0), TOUGH - 7.0, 0.0001, "gli HP scendono dell'importo passato")
	h.check(not killed_by_contract,
		"un colpo che non uccide risponde false (piano 5.2: il ritorno e' 'e' morto')")
	h.vec_near(horde.vel_of(0), knock, 0.0001,
		"knockback e' un impulso in m/s sommato alla velocita', non normalizzato")
	h.eq(game.damage_enemy(-1, 7.0, knock), false,
		"-1 non e' un bersaglio: damage_enemy lo rifiuta e risponde false")
	h.eq(horde.out_of_range, 1, "e il rifiuto viene registrato, non ignorato in silenzio")
	h.eq(horde.kill_signals, 0, "nessuna delle due chiamate ha ucciso qualcosa")
	horde.clear()

	# La scena vera quando il modello c'e', altrimenti lo script nudo: il test
	# non deve dipendere dalla cache di import di nessuno.
	# Nota: `load()` e NON `const preload`, vedi la nota sul caricamento in testa
	# al file. Uno script caricato qui e' gia' compilato con gli autoload vivi.
	if FileAccess.file_exists("res://assets/models/player.glb"):
		var packed = load(PLAYER_SCENE)
		if h.check(packed is PackedScene, "scenes/player.tscn deve esistere e caricare"):
			player = (packed as PackedScene).instantiate()
	if player == null:
		var player_script = load(PLAYER_SCRIPT)
		if h.check(player_script is Script, "src/player/player.gd deve caricare"):
			player = (player_script as Script).new()
			player.name = "Player"
	root.add_child(player)
	player.drive_manually()
	# ## Il numero che spiega **perche' il file si ferma qui**
	#
	# `_process()` (riga 925) entra nelle sezioni solo con `player`, `weapon` e `pool`
	# non nulli: se uno dei tre e' null il file esce dopo questa riga e **tutte** le
	# sezioni successive non girano — un rosso che ne copre novanta e non lo dice. Il
	# numero e' **quale** dei tre e' null e **quanti** nodi chiamati `Weapon` sono
	# sotto il giocatore: `player.weapon` e' un campo che `player.gd::_ready()`
	# riempie, e un campo riempito in `_ready()` e' letto solo se `_ready()` e' girato.
	var armi_sotto: int = 0
	for nodo in player.get_children():
		if String(nodo.name) == "Weapon":
			armi_sotto += 1
	if weapon == null or pool == null:
		print("setup: `player` %s, `player.weapon` %s, `weapon` %s, `pool` %s, e i nodi chiamati `Weapon` sotto il giocatore sono %d. Con uno dei tre a null `_process()` non entra in nessuna sezione e il FAIL e' l'unico numero che esce: e' un rosso che ne copre molti e non lo dichiara"
			% [str(player != null), str(player.get("weapon") != null), str(weapon != null),
				str(pool != null), armi_sotto])

	h.check(game.player == player, "registrazione dati: Game.player = self (piano 5.1)")
	h.check(game.has_impl("player_position"), "registrazione metodi: player_position")
	h.check(game.has_impl("spawn_projectile"), "registrazione metodi: spawn_projectile")
	# Il contratto ora tiene **piu' voci per API** e `_live()` restituisce l'ultima
	# **viva**, scartando le morte (`src/core/contracts.gd:690`). Quindi `has_impl` puo'
	# dire `false` perche' tutte le voci sono morte, e non perche' nessuno ha
	# registrato: i due casi sono diversi e il numero li distingue.
	if not game.has_impl("spawn_projectile"):
		var voci = game.get("_impl")
		var elenco = "nessuna"
		if voci is Dictionary and (voci as Dictionary).has("spawn_projectile"):
			var arr: Array = (voci as Dictionary)["spawn_projectile"]
			var dettaglio := PackedStringArray()
			for v in arr:
				var c: Callable = v
				var o = c.get_object()
				dettaglio.append("oggetto %s valido %s" % [str(o), str(is_instance_valid(o))])
			elenco = "%d voci (%s)" % [arr.size(), ", ".join(dettaglio)]
		print("registrazione: `spawn_projectile` risulta non registrata **subito dopo `_setup()`**: %s. Il contratto scarta le voci con l'oggetto morto, quindi `false` vuol dire che ogni voce registrata e' morta — non che nessuno ha registrato"
			% elenco)
	h.vec_near(game.player_position(), Vector3.ZERO, 0.0001, "player_position all'avvio")

	# Lo **stesso** numero letto **di nuovo** qui, subito prima dell'assegnazione:
	# fra le due letture non c'e' niente che tocchi il giocatore, quindi se `weapon`
	# era non nullo sopra e `player.weapon` e' nullo qui, il campo e' stato azzerato
	# da una delle `h.check` o da `game.player_position()` in mezzo — e cioe' che
	# `player.weapon` **non** e' un campo stabile, e tutta la sezione piu' sotto
	# dipende da una lettura che non si puo' dare per scontata.
	var arma_ora = player.get("weapon")
	if arma_ora == null:
		print("setup: `player.weapon` era non nullo %d righe fa e adesso e' **nullo**: il campo non e' stabile e l'assegnazione alla riga sotto prende null, `_setup()` esce e tutto il file viene saltato. Un nodo chiamato `Weapon` sotto il giocatore: %d — quindi il nodo c'e' e il campo non lo vede"
			% [1130, armi_sotto])
	weapon = player.weapon
	h.check(weapon != null, "il player deve avere un'arma")
	if weapon == null:
		return
	pool = weapon.pool
	h.check(pool != null, "l'arma deve avere il pool dei proiettili")
	if pool != null:
		h.eq(pool.capacity(), 100, "il pool nasce con 100 proiettili")
		h.eq(pool.ever_created(), 100, "e li ha creati tutti e 100 una volta sola")
		pool.reset()

	# Qui il giocatore e' **vergine**: nessuna sezione e' ancora passata di qui, e
	# quindi nessun potenziamento e' stato applicato. E' l'unico posto in cui la
	# regolazione di partenza si puo' leggere senza dipendere dall'ordine delle
	# sezioni (vedi `_prima` in testa al file).
	_prima = _numeri()
	h.check(float(_prima["damage"]) > 0.0, "il danno di partenza esiste ed e' positivo")
	h.check(float(_prima["knockback"]) > 0.0, "la spinta di partenza esiste ed e' positiva")
	h.positive(float(_prima["move_speed"]), "la velocita' di corsa di partenza esiste")
	h.positive(float(_prima["max_hp"]), "la vita massima di partenza esiste")
	h.near(float(_prima["hp"]), float(_prima["max_hp"]), 0.0001,
		"e alla partenza la vita e' piena")

# --- 1. Movimento con delta noto, e clampato all'arena -------------------------

## ## m12: quante direzioni l'input **offre davvero**, contate e non dichiarate
##
## `N_DIREZIONI_INPUT_DICHIARATE` vale `12` in `src/player/player.gd`, ma quel numero
## **non e' applicabile** finche' l'unica sorgente di input e' la tastiera: qui si
## conta quello che c'e', e i due numeri insieme dicono il buco.
##
## `read_input()` chiama `input_vector()` con quattro booleani (`D`/`destra`,
## `A`/`sinistra`, `S`/`indietro`, `W`/`avanti`) e `input_vector()` mette `+-1,0`
## nei componenti: le sixteenque combinazioni danno quattro cardinali e quattro
## diagonali, cioe' **otto**, e `limit_length(1.0)` non ci aggiunge niente perche'
## quei vettori sono gia' lunghi al massimo. Non c'e' `InputMap`, non c'e'
## `Input.get_vector`, non c'e' un asse analogico: la ricerca e' in
## `src/player/player.gd` ed è vuota. Quindi **non c'e' nessun pollice che dia
## l'angolo**: la dichiarazione «l'angolo e' dell'analogico» resta **vera come
## principio** e **falsa come fatto** su questo progetto, e la differenza e' tutta
## qui dentro.
##
## Percio' la deriva che `-arena` ha misurato (`5,9234 m` su `26 m` con `8`
## direzioni) **non e' del pilota automatico**: e' lo stesso vettore che un
## giocatore umano puo' premere con due dita, e quindi e' un difetto di gioco.
func _m12_direzioni_input() -> void:
	var viste := {}
	for a in 4:
		for b in 4:
			for c in 4:
				for d in 4:
					var v: Vector3 = player.input_vector(a == 1, b == 1, c == 1, d == 1)
					if v.length_squared() <= 0.000001:
						continue
					var n := Vector2(v.x, v.z).normalized()
					viste[int(round(fposmod(rad_to_deg(atan2(n.y, n.x)), 360.0)))] = true
	var script_c = load(PLAYER_SCRIPT)
	var dichiarate: int = int(script_c.N_DIREZIONI_INPUT_DICHIARATE)
	print("m12 input: `input_vector()` puo' restituire %d direzioni distinte (gradi: %s) e `read_input()` legge solo quattro booleani di tastiera, nessun InputMap e nessun asse analogico. La costante dichiarata in src/player/player.gd e' %d: le %d mancanti non sono raggiungibili con WASD e frecce, quindi %d non e' applicabile finche' non c'e' una sorgente che dia l'angolo. E la deriva che `-arena` ha misurato con 8 direzioni non e' del pilota automatico: e' lo stesso vettore che il giocatore umano puo' premere, quindi e' di gioco"
		% [viste.size(), str(viste.keys()), dichiarate, dichiarate - viste.size(), dichiarate])

func _movement(h) -> void:
	_reset(Vector3.ZERO)
	# I numeri di regolazione si leggono dall'istanza viva, non dalle costanti
	# degli script: `player.accel` e' il valore con cui il player si sta davvero
	# muovendo in questo frame, ed e' quello che un potenziamento cambierebbe.
	var accel: float = player.accel
	h.positive(accel, "il player deve avere un'accelerazione")
	var x0 := player.position.x
	player.step(DT, Vector3(1.0, 0.0, 0.0))
	h.near(player.velocity.x, accel * DT, 0.0001,
		"un frame di accelerazione: la velocita' e' accel*dt")
	# Euler semi-implicito: la velocita' e' gia' accel*dt quando la posizione
	# viene aggiornata, quindi lo spostamento del primo frame e' accel*dt^2. Non
	# e' "un po' piu' a destra": e' la legge esatta.
	h.near(player.position.x - x0, accel * DT * DT, 0.0001,
		"lo spostamento del primo frame e' accel*dt^2")
	h.near(player.position.z, 0.0, 0.0001, "input su x non sposta su z")

	# A regime, un frame vale esattamente move_speed*dt.
	for i in 120:
		player.step(DT, Vector3(1.0, 0.0, 0.0))
	var x1 := player.position.x
	player.step(DT, Vector3(1.0, 0.0, 0.0))
	h.near(player.position.x - x1, player.move_speed * DT, 0.0002,
		"a regime un frame di corsa vale move_speed*dt")
	h.near(player.position.x - x1, 0.116667, 0.001, "e cioe' 7 m/s a 60 Hz")

	# Input opposto: la velocita' si annulla, non si ribalta di colpo.
	for i in 60:
		player.step(DT, Vector3(-1.0, 0.0, 0.0))
	h.check(player.velocity.x <= 0.0, "l'input opposto frena il player")

	# Il muro: dall'orlo, verso fuori, due secondi.
	var radius: float = game.arena_radius
	player.position = Vector3(radius - 1.0, 0.0, 0.0)
	player.velocity = Vector3.ZERO
	var escaped := false
	var far := 0.0
	for i in 120:
		player.step(DT, Vector3(1.0, 0.0, 0.0))
		var d := player.position.length()
		far = maxf(far, d)
		if d > radius + 0.001:
			escaped = true
			break
	h.check(not escaped, "il player non esce mai dall'arena (massima distanza %.3f, raggio %.1f)" % [far, radius])
	h.check(far <= radius + 0.001, "la distanza resta sotto arena_radius")
	h.check(far >= radius - 2.0, "e non si ferma troppo prima del muro (%.3f)" % far)
	h.finite(player.position.x, "la posizione dopo il muro e' finita")
	h.near(player.velocity.x, 0.0, 0.5, "e il player non corre piu' contro il muro")

	# ## m9: il muro MISURATO, e non solo rispettato
	#
	# Il blocco sopra dice una cosa sola: **non si esce**. Non dice *dove* ci si
	# ferma, e su un disco 4,6 volte piu' grande in area quella frase da sola dice
	# ancora meno di prima. Due agguagli, dichiarati perche' un test che non li
	# dichiara fa sembrare forte un asserzione che e' debole. Tutte le distanze
	# qui sotto sono **ricalcolate** sul raggio vivo (`RAGGIO_ARENA`, 35,0 m dal 2026-10-17) e sul margine letto
	# dal gioco (0,8): la base e' sempre `raggio - margine`, e da li' tutto. I numeri di
	# 60 m che restano piu' sotto in questo file sono **cronologia** di m9/m11 e non
	# attesi: nessuna asserzione li usa, tutte leggono `RAGGIO_ARENA` o `game.arena_radius`.
	#
	#   - `far <= radius + 0.001` ha **0,8 m di margine**, perche' il clamp ferma
	#     il giocatore *dentro* il raggio: quella riga, da sola, cade solo se il
	#     muro sparisce del tutto (a 60 m, due secondi a 7 m/s da `raggio - 1`
	#     porterebbero a 73 m, tredici oltre il muro). Resta vera, ma da sola
	#     non dimostra che il bordo sia raggiungibile: e su un raggio 2,1 volte
	#     piu' grande (60 contro 28) la differenza fra «clamp a 59,2 m» e «clamp
	#     a 3 m» e' la stessa in assoluto e molto piu' piccola in percentuale.
	#   - `far >= radius - 2.0` invece si e' **irrigata**: la finestra e' di 2 m
	#     sia a 28 che a 60, ma sul raggio e' il 7,1% di prima e il 3,3% di adesso
	#     (2/28 e 2/60). La finestra resta di 2 m: cambiarne il numero perche' il
	#     raggio e' cambiato sarebbe spostare un tetto per far entrare una cifra.
	#
	# E qui la precisazione che serve a non leggere il file a pezzi: le due
	# asserzioni che usano il raggio in questa sezione sono **sul giocatore**, non
	# sui proiettili. In questo file non esiste nessuna asserzione che dica «i
	# proiettili restano dentro l'arena», e non e' un buco: i proiettili muoiono
	# per `life` (`src/weapons/projectile.gd`) e non hanno un test sull'arena, il
	# raggio per loro non e' un vincolo e quindi non ha niente da dire qui.
	#
	# Quindi sotto il muro si misura, e si misura sul percorso vero: il giocatore
	# parte dal **centro** e ci arriva correndo. Il margine non e' scritto qui
	# (perche' e' regolazione di -gameplay e una seconda copia mentirebbe appena
	# si ritocca): si legge da `src/player/player.gd` e l'atteso si compone col
	# raggio. Il perno resta il raggio, che e' il letterale in testa al file.
	var margine := _margine_muro(h)

	#     (a) Dal centro verso +x, dieci secondi. A 7 m/s il muro di un'arena da 35 m
	#     e' a 8,46 s (59,2 m di corsa effettiva, per il margine di 0,8): i 600
	#     frame arrivano e ne restano ~1,5 per vedere che il giocatore **resta**
	#     fermo li' invece di scivolare fuori. I 600 frame **non** si toccano: il
	#     numero che decide e' che `lontano` arrivi al muro, e con 600 arriva;
	#     accorciarli per far quadrare la frase sarebbe spostare un tetto per far
	#     entrare una cifra.
	var lontano := _corri_al_muro(Vector3(1.0, 0.0, 0.0), 600)
	h.near(lontano, radius - margine, 0.05,
		"sull'asse il muro ferma il giocatore a un margine esatto dal raggio: %.3f contro %.3f m (raggio %.1f - margine %.2f)"
		% [lontano, radius - margine, radius, margine])
	h.check(lontano >= radius * 0.9,
		"e il bordo si raggiunge davvero dal centro: %.2f m su %.1f m, il %.1f%% del raggio"
		% [lontano, radius, 100.0 * lontano / radius])
	h.near(radius - lontano, margine, 0.05,
		"la distanza fra il giocatore e il muro e' il margine di -gameplay e non un numero ereditato dal raggio di prima: %.3f contro %.2f m"
		% [radius - lontano, margine])

	# (b) In diagonale, dove un clamp **quadrato** si tradirebbe da solo: il muro
	#     e' un disco. Sul raggio nuovo la prova e' piu' forte, non piu' debole:
	#     un clamp per assi fermerebbe a 59,2 m su `x` **e** su `z`, cioe' a
	#     83,72 m dal centro, 23,72 m oltre il muro. La formula e' sempre
	#     `(raggio - margine) * sqrt(2) - raggio`, e ricalcolata anche sul
	#     confronto: a 28 m dà 10,47 m oltre il muro. Il 11,6 m che stava qui
	#     prima era calcolato **senza** margine e non combaciava con il 17,9 m che
	#     invece lo aveva: due numeri della stessa frase, due formule diverse.
	#     La diagonale passa da `world_direction` e non e' scritta a mano: senza
	#     camera `+z` di input e' `-z` di mondo (sezione 11), e un vettore
	#     riscritto qui farebbe cadere questa riga per il verso sbagliato, che e'
	#     un altro criterio. Il verso atteso e' **ricalcolato** dalla base della
	#     camera di turno, non ricavato dalla posizione finale: un'atteso preso
	#     da dove il giocatore e' finito non puo' fallire. E il vettore di input
	#     non viene tradotto due volte: `world_direction` sulla base di ripiego e'
	#     una **riflessione**, quindi applicarla due volte ribalta `z` e la riga
	#     cadrebbe per il verso, non per il clamp.
	var ingresso := Vector3(1.0, 0.0, 1.0)
	var lontano_d := _corri_al_muro(ingresso, 600)
	h.near(lontano_d, radius - margine, 0.05,
		"in diagonale il clamp resta sullo stesso raggio, non su un quadrato: %.3f contro %.3f m"
		% [lontano_d, radius - margine])
	var atteso_diag: Vector3 = player.world_direction(ingresso).normalized() * (radius - margine)
	h.vec_near(player.position, atteso_diag, 0.05,
		"e su entrambi gli assi insieme: fermo a (%.2f, 0.00, %.2f) contro (%.2f, 0.00, %.2f)"
		% [player.position.x, player.position.z, atteso_diag.x, atteso_diag.z])

	# I due numeri del raggio sono **due numeri diversi** e percio' ci sono entrambi:
	# quello letto dal contratto a runtime e il perno scritto in testa al file. Dopo
	# il cambio del 2026-10-14 valgono entrambi 60,0 m, e il fatto che la riga qui
	# sopra sia passata e' appunto quello che questa stampa dice: la copia e la
	# fonte dicono la stessa cosa. Il 46,0 m di ieri non compare perche' e' un
	# numero **passato**, non un secondo valore del perno.
	print("m9 muro: raggio %.1f m letto dal contratto, perno scritto %.1f m (copia dichiarata di src/core/contracts.gd:116): combaciano. Il giocatore si ferma a %.3f m sull'asse e a %.3f m in diagonale, cioe' (%.3f, 0.00, %.3f): margine %.2f m letto da -gameplay"
		% [radius, RAGGIO_ARENA, lontano, lontano_d, player.position.x, player.position.z, margine])

# --- 2. L'arma spara da solo ---------------------------------------------------

func _autofire(h) -> void:
	_reset(Vector3.ZERO)
	horde.target = Vector3.ZERO
	horde.add(Vector3(0.0, 0.9, -8.0), TOUGH)
	weapon.cooldown = 0.0
	var ever_active := false
	var peak := 0
	for i in 60:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
		if pool.active_count() > 0:
			ever_active = true
		peak = maxi(peak, pool.active_count())
	h.check(ever_active, "entro 60 frame dal caricamento deve esserci un proiettile in volo")
	h.check(peak > 0, "il pool deve aver trattenuto dei proiettili (picco %d)" % peak)
	h.eq(horde.out_of_range, 0, "nessuna chiamata a damage_enemy con indice fuori dall'orda")

	# Il colpo parte nello stesso frame in cui l'arma e' pronta: cooldown a 0 e
	# nessun Timer, quindi il primo step spara. Non al secondo frame.
	# Il cooldown viene messo a zero a mano perche' e' un **campo**: e' il
	# countdown che l'arma decrementa, e metterlo a 0 e' esattamente dire "l'arma
	# e' pronta adesso". Il test non aspetta che il cooldown torni a zero per
	# caso: quello dipenderebbe da quanti frame sono passati e non dimostrerebbe
	# nulla sulla temporizzazione del colpo.
	pool.reset()
	weapon.cooldown = 0.0
	player.step(DT, Vector3.ZERO)
	h.eq(pool.active_count(), 1, "il primo colpo esce al primo frame, non al secondo")
	var p = pool.active_at(0)
	if h.check(p != null, "il proiettile appena sparato deve esistere"):
		var muzzle: Vector3 = weapon.muzzle_position()
		var to_target: Vector3 = horde.pos_of(0) - muzzle
		var angle := rad_to_deg(p.dir.angle_to(to_target.normalized()))
		h.check(angle <= 5.0, "il proiettile punta al nemico piu' vicino: %.2f gradi (tetto 5)" % angle)
		h.check(p.prev_pos.distance_to(p.pos) > 0.0, "e il proiettile si e' gia' mosso")

	# Senza nessun nemico nel raggio l'arma non spara: niente spari a vuoto.
	_reset(Vector3.ZERO)
	weapon.cooldown = 0.0
	horde.add(Vector3(0.0, 0.9, -400.0), TOUGH)
	for i in 30:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
	h.eq(pool.active_count(), 0, "nessun nemico entro acquire_radius: nessun colpo")
	h.eq(horde.damage_calls, 0, "e nessun colpo sparato a vuoto")

# --- 3. Danno una volta sola ---------------------------------------------------

func _single_hit(h) -> void:
	_reset(Vector3.ZERO)
	horde.target = Vector3.ZERO
	# Un colpo solo in volo per tutta la sezione: qui si prova che **quel**
	# proiettile non ripete il danno, e non che l'arma smetta di sparare.
	# Con il cooldown di serie (0.35 s) il secondo colpo arriverebbe dentro la
	# finestra dei 30 frame e il test misurerebbe la cadenza, non la guardia.
	var fire_before: float = weapon.fire_interval
	weapon.fire_interval = 10.0
	weapon.cooldown = 0.0
	horde.add(Vector3(0.0, 0.9, -6.0), 1000.0)
	var frames := _run_until_hit(120)
	h.check(horde.damage_calls == 1,
		"un proiettile che attraversa un nemico lo colpisce UNA volta sola: %d chiamate in %d frame"
		% [horde.damage_calls, frames])
	h.eq(horde.hits_of(0), 1, "un solo colpo su quel nemico")
	h.near(horde.hp_of(0), 1000.0 - weapon.damage, 0.0001,
		"gli HP scendono di un colpo e non di uno di piu'")
	h.eq(horde.out_of_range, 0, "nessun indice fuori dall'orda")

	# E non ricomincia: 30 frame dopo l'impatto nessun altro danno.
	for i in 30:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
	h.eq(horde.damage_calls, 1, "nessun secondo danno nei 30 frame dopo l'impatto")
	weapon.fire_interval = fire_before

## Il caso che separa un test che prova qualcosa da uno che passa a vuoto:
## due nemici **sovrapposti** e un proiettile lento che resta dentro di loro per
## una quindicina di frame. Una guardia assente qui non fa fallire nient'altro:
## fa solo che il nemico si becca quindici colpi invece di uno, e il test
## "colpisce una volta sola" passa lo stesso perche' guarda un solo nemico.
func _overlapping_enemies(h) -> void:
	_reset(Vector3.ZERO)
	horde.target = Vector3.ZERO
	# I valori di qui sotto sono **campi** dell'arma viva, non costanti degli
	# script: vengono salvati prima e rimessi a posto dopo. Sono regolazione del
	# gioco e un test che li lascia sporchi fa fallire in modo falso la sezione
	# successiva, che si aspetta il proiettile veloce di prima.
	var fire_before: float = weapon.fire_interval
	var pierce_before: int = weapon.pierce
	var speed_before: float = weapon.projectile_speed

	# Due nemici sulla stessa testa: l'orda non distingue i due, quindi il
	# gameplay deve distinguerli per indice e non per posizione.
	horde.add(Vector3(0.0, 0.9, -2.0), TOUGH)
	horde.add(Vector3(0.0, 0.9, -2.0), TOUGH)
	weapon.fire_interval = 10.0
	weapon.cooldown = 0.0
	weapon.pierce = 5
	weapon.projectile_speed = 6.0
	var peak_active := 0
	for i in 60:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
		peak_active = maxi(peak_active, pool.active_count())
	h.eq(horde.damage_calls, 2,
		"due nemici sovrapposti: due colpi in tutto, uno per nemico, non uno per frame")
	h.eq(horde.hits_of(0), 1, "il primo nemico prende un colpo solo")
	h.eq(horde.hits_of(1), 1, "il secondo nemico prende un colpo solo")
	h.eq(horde.deaths, 0, "in questo caso nessuno deve morire (HP alti apposta)")
	h.check(peak_active >= 1, "il proiettile lento doveva essere in volo (%d)" % peak_active)

	# Lo stesso caso con pierce 0: un colpo e il proiettile sparisce.
	_reset(Vector3.ZERO)
	horde.add(Vector3(0.0, 0.9, -2.0), TOUGH)
	horde.add(Vector3(0.0, 0.9, -2.0), TOUGH)
	weapon.fire_interval = 10.0
	weapon.cooldown = 0.0
	weapon.pierce = 0
	weapon.projectile_speed = 6.0
	for i in 60:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
	h.eq(horde.damage_calls, 1, "senza pierce il proiettile colpisce una volta sola e muore")
	h.eq(horde.hits_of(1), 0, "e il secondo nemico sovrapposto resta intatto")

	# Ripulisci: un test che lascia la regolazione sporca fa fallire in modo
	# falso chi viene dopo, e questo file e' la prova che non va fatto.
	weapon.fire_interval = fire_before
	weapon.pierce = pierce_before
	weapon.projectile_speed = speed_before

# --- 4. Knockback: l'impulso che -gameplay consegna -----------------------------
#
# `knockback` e' un **impulso in m/s** (piano 5.2) e i numeri sono di -gameplay.
# Qui quindi si asserisce la parte che e' sua, e sono tre cose che tornano a
# leggersi nel sorgente di `weapon_base.gd`:
#   1. l'impulso arriva **grezzo**, cioe' col modulo di `weapon.knockback` e non
#      normalizzato: un vettore normalizzato avrebbe modulo 1 e il colpo non si
#      sentirebbe;
#   2. va **via dal player**, mai verso: il nemico scattato addosso a chi spara
#      e' l'opposto del "bonk";
#   3. arriva **una volta sola per colpo**, insieme al danno, e con la scala
#      della resistenza ce la mette **il contratto**, non -gameplay.
#
# PERCHE' IL TETTO DI 0.3 UNITA' NON E' ASSERITO QUI (era qui, e l'ho tolto).
# Lo spostamento del nemico e' una proprieta' della fisica di -orda: tempo
# caratteristico, tetto di velocita', resistenza per specie. Misurarlo su un
# doppio significa misurare il doppio. La prima versione di questa sezione lo
# faceva, e cosi' ha fatto due cose sbagliate in una: si e' inventata un `drag`
# che nell'orda non esiste, e ha tarato `KNOCKBACK` (14 -> 18) per far passare
# la propria soglia invece di quella del gioco. Il tetto in unita' e' asserito
# per specie sulla **scena vera** in `tests/test_arena.gd`, su runner e grunt,
# che sono le specie su cui il knockback e' progettato per funzionare (brute e
# boss lo resistono per progetto, piano 5.4). Il margine residuo del runner e'
# accoppiato a `SPEED_MAX` e ad `ACCEL` di -orda: e' un fatto registrato e aperto
# nel piano, e non si prova a coprirlo da qui.

func _knockback_impulse(h) -> void:
	_reset(Vector3.ZERO)
	horde.target = Vector3.ZERO
	# Un colpo solo in volo per tutta la sezione, come in `_single_hit`: qui si
	# guarda l'impulso di **quel** colpo, non la cadenza dell'arma.
	var fire_before: float = weapon.fire_interval
	weapon.fire_interval = 10.0
	weapon.cooldown = 0.0
	horde.add(Vector3(0.0, 0.9, -6.0), 1000.0)
	var frames := _run_until_hit(120)
	h.check(horde.damage_calls == 1 and horde.hits_of(0) == 1,
		"il colpo e' arrivato una volta sola: %d chiamate a damage_enemy in %d frame, %d hit"
		% [horde.damage_calls, frames, horde.hits_of(0)])

	# L'impulso **come il gameplay lo ha consegnato**, cioe' prima che questo
	# doppio vi applichi la resistenza: se fosse gia' riscalato qui dentro si
	# leggerebbe il numero sbagliato.
	var impulse := horde.last_knockback
	h.finite(impulse.length(), "l'impulso e' finito")
	h.check(impulse.length() > 0.0, "il colpo deve consegnare un impulso non nullo")
	h.near(impulse.length(), weapon.knockback, 0.0001,
		"l'impulso e' il numero di -gameplay, non un vettore normalizzato: %.3f contro %.3f m/s"
		% [impulse.length(), weapon.knockback])
	# Il nemico e' a z negativo e il player a zero: la spinta deve andare verso z
	# piu' negativo, cioe' allontanarlo.
	h.check(impulse.z < 0.0,
		"la spinta e' rivolta lontano dal player, non verso: %s" % str(impulse))
	# Deve battere l'inseguimento, altrimenti il numero non produce nessuna
	# sensazione. Il confronto e' con la specie piu' veloce dell'orda (6.6 m/s),
	# non solo con quella che si trova in questa sezione.
	h.check(weapon.knockback > horde.chase_speed,
		"l'impulso deve battere l'inseguimento piu' veloce (%.1f m/s): ne ha %.1f m/s"
		% [horde.chase_speed, weapon.knockback])
	# E l'impulso tiene una volta sola, non due: e' la **differenza** fra la
	# velocita' di prima e quella di dopo il colpo, perche' il nemico insegue
	# gia' e la sua velocita' non e' l'impulso.
	h.vec_near(horde.vel_after_hit - horde.vel_before_hit,
		impulse * (1.0 - horde.resist_of(0)), 0.0001,
		"il nemico senza resistenza tiene l'impulso per intero, una volta sola: %.3f m/s"
		% horde.charge())

	# Lo stesso colpo su un nemico che lo resiste quasi tutto (0.90: il boss di
	# -orda). Se -gameplay pre-scalasse l'impulso, il boss si muoverebbe come un
	# runner e il criterio sui runner passerebbe senza volerlo: quindi la scala
	# deve accadere **qui**, nel contratto.
	_reset(Vector3.ZERO)
	horde.target = Vector3.ZERO
	horde.add(Vector3(0.0, 0.9, -6.0), 1000.0)
	horde.set_resist(0, BOSS_RESIST)
	weapon.cooldown = 0.0
	_run_until_hit(120)
	h.eq(horde.damage_calls, 1, "il colpo sul nemico che resiste arriva una volta sola")
	h.eq(horde.hits_of(0), 1, "e lo prende un colpo solo")
	var charged := horde.charge()
	h.near(charged, weapon.knockback * (1.0 - BOSS_RESIST), 0.0001,
		"il nemico che resiste %.2f tiene solo il %.0f%% dell'impulso: %.3f di %.3f m/s"
		% [BOSS_RESIST, (1.0 - BOSS_RESIST) * 100.0, charged, weapon.knockback])
	weapon.fire_interval = fire_before
	print("criterio 4, danno e impulso: 1 hit per colpo, %.1f m/s consegnati al contratto una volta sola"
		% weapon.knockback)
	print("criterio 4, scala: e' il contratto a ridurre l'impulso (resistenza 0 -> %.1f m/s, %.2f -> %.3f m/s)"
		% [weapon.knockback, BOSS_RESIST, charged])
	print("criterio 4, spostamento: non e' asserito qui perche' e' una fisica di -orda; "
		+ "lo asserisce per specie tests/test_arena.gd sulla scena vera")

# --- 4b. Danno al player e invulnerabilita' ------------------------------------

func _damage_and_iframes(h) -> void:
	_reset(Vector3.ZERO)
	horde.add(Vector3(0.0, 0.9, -6.0), TOUGH)
	player.invuln = 0.0
	player.hp = player.max_hp
	h.check(player.take_damage(30.0), "il player accetta un colpo")
	h.near(player.hp, player.max_hp - 30.0, 0.0001, "e perde 30 HP")
	h.check(player.is_invulnerable(), "dopo il colpo e' invulnerabile")
	h.check(not player.take_damage(30.0), "il secondo colpo nello stesso momento non entra")
	h.near(player.hp, player.max_hp - 30.0, 0.0001, "gli HP non scendono due volte")
	for i in 60:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
	h.check(not player.is_invulnerable(), "dopo un secondo non e' piu' invulnerabile")
	h.check(player.take_damage(30.0), "e il colpo successivo entra")
	h.near(player.hp, player.max_hp - 60.0, 0.0001, "HP dopo due colpi")

# --- 4c. m16 criterio 3: UNA finestra, non due ----------------------------------
#
# ## La domanda
#
# La sezione `_m16_tetto` misura **quanto** la finestra lascia entrare. Questa
# misura **da dove arriva il rifiuto**: `take_damage()` deve rifiutare un colpo
# se e solo se `is_invulnerable()` era vera quando il colpo e' arrivato. Se ci
# fosse un **secondo** controllo — un altro timer, un'altra condizione, una copia
# della finestra scritta due volte — questa sezione lo vede, perche' il caso che
# lo smaschera e' uno solo: **un rifiuto con `is_invulnerable()` falsa**, cioe'
# una seconda finestra che scarta un colpo che il giocatore, secondo la prima,
# poteva prendere.
#
# ## Perche' la finestra si chiama cosi' e non "cooldown"
#
# `is_invulnerable()` non guarda solo `invuln`: guarda anche `dash_timer`, cioe'
# lo scatto mette al riparo per `DASH_TIME = 0,16 s`. Sono **due finestre di
# gioco** dentro una sola funzione, ed e' la ragione per cui il confronto e'
# fatto su `is_invulnerable()` e non su `invuln`: un test che guardasse solo il
# campo `invuln` chiamerebbe "secondo controllo duplicato" lo scatto.
#
# ## Le due direzioni, e perche' servono entrambe
#
#   - **troppo corta** (una copia con un numero piu' piccolo): il rifiuto arriva
#     quando `is_invulnerable()` e' falsa, e la cadenza dei colpi entrati supera
#     `1/finestra`;
#   - **troppo lunga** (una copia con un numero piu' grande, o un secondo timer
#     che non finisce mai): il rifiuto arriva quando `is_invulnerable()` e'
#     vera ma non per la finestra, e il **gap minimo** fra due colpo entrati e'
#     piu' grande della finestra.
#
# Le due righe sotto guardano quindi una cosa e l'altra, e i numeri sono
# stampati anche quando passano.

func _m16_una_finestra(h) -> void:
	_reset(Vector3.ZERO)
	# Il contratto deve puntare a **questo** giocatore: la sezione chiama
	# `Game.damage_player`, che e' la strada vera (`player.gd::_ready` registra
	# `take_damage` sotto il nome dell'API, vedi la nota lunga li' sopra), e se il
	# contratto puntasse a un altro nodo la sezione misurerebbe un giocatore che
	# non e' quello del file.
	if not h.check(game.player == player,
		"m16 criterio 3: il contratto deve puntare al giocatore di questa sezione"):
		return
	horde.add(Vector3(0.0, 0.9, -6.0), TOUGH)
	player.hp = player.max_hp
	# La finestra **non e' piu' una `const`** e non si legge piu' dallo script: dal
	# m12 2026-10-18 e' **derivata** da `Game.touch_interval()`, cioe' letta dal
	# produttore. Leggerla ancora dallo script era un numero che non esiste piu', e
	# `float()` su un nome assente non e' uno zero: e' uno scripting error che ferma
	# la funzione e fa rosso tutto il file su un numero che non c'e'. La regola e' la
	# stessa del morso di coda: **il numero va letto dove il codice lo prende**.
	var w := float(game.touch_interval())
	if not h.check(w > 0.0, "m16 criterio 3: la finestra si legge dal produttore, `Game.touch_interval()` = %.3f s, e non piu' da una costante locale" % w):
		return

	var accettati := 0
	var rifiutati := 0
	## Rifiuti **fuori** dalla finestra: il difetto che la sezione cerca.
	var fuori := 0
	## Colpi entrati **con** la finestra aperta: il difetto simmetrico.
	var dentro := 0
	var ultimo := -1
	var gap_min := 1.0e9
	var hp_iniziale := float(player.hp)
	for i in M16_PASSI_UNA:
		# Il giocatore scala la sua finestra **prima** che il colpo arrivi: e'
		# l'ordine dell'albero, e senza questo la sezione misurerebbe una
		# finestra che non esiste in gioco.
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
		var inv := bool(player.is_invulnerable())
		var prima := float(player.hp)
		if float(player.hp) <= 0.0:
			# Difensivo, e non previsto: `M16_DANNO_PROVA` e' scelto perche' i
			# colpo entrati stiano dentro la vita. Se un domani la finestra
			# scendesse sotto 0,05 s questo e' il ramo che lo dice invece di
			# lasciare che `hp <= 0` renda ogni colpo successivo «non entrato».
			break
		var entra := bool(game.damage_player(M16_DANNO_PROVA))
		if entra:
			accettati += 1
			if inv:
				dentro += 1
			if ultimo >= 0:
				gap_min = minf(gap_min, float(i - ultimo) * DT)
			ultimo = i
		else:
			rifiutati += 1
			if not inv:
				fuori += 1

	# ## I numeri che decidono, e i due perni
	# Ogni punto di vita perso deve essere stato annunciato da un colpo accettato:
	# e' la stessa invariante della sezione m7, ma qui senza nemici e senza arma,
	# quindi il conto e' chiuso.
	h.near(hp_iniziale - float(player.hp), float(accettati) * M16_DANNO_PROVA, 0.0001,
		"m16 criterio 3: %.1f hp persi = %d colpi entrati da %.1f hp l'uno: nessuna strada diversa dal rifiuto"
			% [hp_iniziale - float(player.hp), accettati, M16_DANNO_PROVA])
	h.check(accettati > 0, "m16 criterio 3: almeno un colpo deve entrare (%d in %d passi)"
		% [accettati, M16_PASSI_UNA])
	h.check(rifiutati > 0, "m16 criterio 3: almeno un colpo deve essere rifiutato (%d in %d passi): "
		% [rifiutati, M16_PASSI_UNA]
		+ "senza rifiuti il numero «nessun rifiuto fuori dalla finestra» sarebbe 0 per il motivo sbagliato")
	h.eq(fuori, 0,
		"m16 criterio 3: nessun colpo rifiutato con is_invulnerable() falsa -- il rifiuto arriva dalla finestra e non da un secondo controllo duplicato (%d rifiuti, di cui %d fuori)"
			% [rifiutati, fuori])
	h.eq(dentro, 0,
		"m16 criterio 3: nessun colpo accettato con is_invulnerable() vera (%d accettati, di cui %d dentro la finestra)"
			% [accettati, dentro])
	# La cadenza: una finestra sola da `w` secondi non puo' far entrare piu' di
	# `1/w` colpi al secondo. Il `+ 1.0` e' il colpo che entra al passo 0.
	var secondi := float(M16_PASSI_UNA) * DT
	h.check(float(accettati) <= secondi / w + 1.0,
		"m16 criterio 3: i colpo entrati non possono superare la cadenza di una finestra sola da %.2f s (massimo %.1f in %.1f s, entrati %d)"
			% [w, secondi / w, secondi, accettati])
	# La durata: il gap minimo fra due colpi entrati e' almeno la finestra (meno
	# il `DT` che lo stesso passo scala sotto). Una copia **piu' lunga** della
	# finestra farebbe salire questo numero, e qui cadrebbe.
	h.check(gap_min >= w - 1.5 * DT,
		"m16 criterio 3: la finestra dura davvero %.3f s: il colpo successivo entra almeno %.4f s dopo il precedente"
			% [w, gap_min])
	h.check(player.hp > 0.0,
		"m16 criterio 3: il giocatore e' ancora in piedi dopo la finestra di prova (%.1f di %.1f hp)"
			% [float(player.hp), float(player.max_hp)])
	print("m16 criterio 3, una sola finestra: %.3f s di finestra, %d colpi entrati e %d rifiutati in %d passi (%.1f s); "
		% [w, accettati, rifiutati, M16_PASSI_UNA, secondi]
		+ "rifiuti fuori finestra %d, entrati dentro finestra %d, gap minimo fra due colpo entrati %.4f s (finestra %.3f s, 1/w = %.2f/s)"
		% [fuori, dentro, gap_min, w, 1.0 / w])
	print("m16 criterio 3, vite: %.1f -> %.1f di %.1f hp, cioe' %.1f hp persi da %d colpi di %.1f"
		% [hp_iniziale, float(player.hp), float(player.max_hp),
			hp_iniziale - float(player.hp), accettati, M16_DANNO_PROVA])

# --- 5. XP, livello, tre potenziamenti applicabili ------------------------------

func _xp_and_upgrades(h) -> void:
	var prog = player.progression
	if not h.check(prog != null, "il player deve avere la progressione"):
		return

	# La tabella dei potenziamenti si chiede allo **script della progressione**,
	# letto a runtime con `get_script_constant_map()`: e' l'unico modo di
	# arrivare alla costante di uno script senza metterla in `const preload` qui
	# dentro (vedi la nota sul caricamento in testa al file).
	var known := _known_upgrades(prog)
	h.eq(known.size(), 10, "la progressione dichiara 10 nodi di codice possibili")

	# I valori di qui sotto sono campi di orda e d'arma: salvati, cambiati per
	# rendere la misura pulita, e rimessi a posto **sempre**, anche se un'asserzione
	# qui sotto fallisce: `check()` non interrompe, quindi il ripristino e'
	# garantito e la sezione dopo non parte da numeri sporchi.
	var chase_before: float = horde.chase_speed
	var fire_before: float = weapon.fire_interval
	horde.target = Vector3.ZERO
	# I nemici devono stare fermi: con la legge vera di -orda (`chase_speed` a
	# zero e il solo smorzamento di primo ordine) la velocita' si scarica a zero e
	# loro restano dove sono, quindi la distanza non cambia durante la misura.
	horde.chase_speed = 0.0

	# --- 5a. La prova che l'XP arriva dal `true` di `damage_enemy` -----------
	# Un colpo che NON uccide non deve muovere niente. Se l'XP dipendesse da
	# qualcos'altro (un conteggio, una euristica, il solo fatto che il
	# proiettile e' arrivato) qui l'XP salirebbe e il test lo direbbe.
	_reset(Vector3.ZERO)
	horde.chase_speed = 0.0
	weapon.fire_interval = fire_before
	horde.add(Vector3(0.0, 0.9, -6.0), TOUGH)
	var earned_before: float = prog.xp_earned
	weapon.cooldown = 0.0
	_run_until_hit(120)
	h.eq(horde.damage_calls, 1, "il colpo e' arrivato")
	h.eq(horde.kill_signals, 0, "ma non ha ucciso nessuno: damage_enemy ha risposto false")
	h.eq(horde.deaths, 0, "e l'orda non ha perso nessuno")
	h.eq(prog.kills, 0, "una chiamata che risponde false non e' un'uccisione")
	h.near(prog.xp_earned, earned_before, 0.0001,
		"e non porta XP: l'XP viene dal `true`, non dall'aver colpito")

	# --- 5b. Dieci uccisioni attraverso il percorso vero ----------------------
	# Nemici con `hp = weapon.damage`: uno solo colpo li uccide, quindi ogni
	# `damage_enemy` deve rispondere `true`. Il cooldown e' piu' lungo del
	# viaggio del proiettile, cosi' in volo ce n'e' uno solo e le uccisioni sono
	# esattamente dieci, non "dieci piu' qualcosa": un'uccisione in piu' farebbe
	# fallire il confronto tra l'XP e i `true` ricevuti, che e' la prova.
	_reset(Vector3.ZERO)
	horde.target = Vector3.ZERO
	horde.chase_speed = 0.0
	weapon.fire_interval = 0.25
	weapon.cooldown = 0.0
	for i in 10:
		horde.add(Vector3(0.0, 0.9, -4.0), weapon.damage)
	var guard := 0
	while horde.deaths < 10 and guard < 900:
		_frame()
		guard += 1
	h.check(horde.deaths == 10,
		"dieci nemici uccisi attraverso il percorso vero, in %d frame (%d uccisi)" % [guard, horde.deaths])
	h.eq(horde.kill_signals, 10, "damage_enemy ha risposto true esattamente dieci volte")
	h.eq(horde.damage_calls, 10, "e non ha mai risposto false: nessun colpo sprecato")
	h.eq(horde.out_of_range, 0, "nessun indice fuori dall'orda")
	h.eq(prog.kills, 10, "la progressione ha contato le dieci uccisioni")
	# La prova che l'XP e' arrivato da `damage_enemy` che ha risposto `true`: il
	# totale guadagnato combacia, uccisione per uccisione, con i `true` che il
	# contratto ha restituito. Se l'XP venisse da una strada diversa, il
	# confronto qui fallirebbe anche se il livello salisse lo stesso.
	h.near(prog.xp_earned, prog.xp_per_kill * float(horde.kill_signals), 0.0001,
		"l'XP e' arrivato dalle %d chiamate a damage_enemy che hanno risposto true"
		% horde.kill_signals)
	h.check(prog.xp_earned >= prog.xp_to_next(1),
		"l'XP superato supera la soglia del livello 2 (%.0f): ne ha %.1f"
		% [prog.xp_to_next(1), prog.xp_earned])
	h.check(prog.level >= 2,
		"e il livello e' salito: %d (era 1)" % prog.level)

	# Il livello offre esattamente 3 potenziamenti, tutti diversi e tutti
	# applicabili: nessuno dei tre deve essere un no-op silenzioso.
	h.eq(prog.pending(), 3, "il level-up offre esattamente 3 potenziamenti")
	var offered: Array = prog.offers.duplicate()
	h.eq(_count_unique(offered), 3, "le tre offerte sono tre potenziamenti diversi")
	for id in offered:
		h.check(known.has(id), "l'offerta '%s' e' un potenziamento che esiste" % str(id))

	# m6: le tre carte si descrivono da sole, e **descriversi non e' scegliere**.
	# Il pannello di `-ui` non scrive «Danno +25%»: lo chiede a
	# `offer_label(index)` e `offer_effect(index)`, quindi qui si prova che quei
	# due metodi rispondono su questo oggetto, e che il numero che il pannello
	# mostra combacia con il danno che il colpio fa davvero: qui siamo al primo
	# livello, quindi la carta promette quello che l'arma ha adesso.
	var danno_prima: float = weapon.damage
	var firma_prima := _signature()
	for i in 3:
		var nome := str(prog.offer_label(i))
		var effetto := str(prog.offer_effect(i))
		h.check(nome != "" and _ascii(nome),
			"l'offerta %d si descrive con un nome leggibile: '%s'" % [i + 1, nome])
		h.check(effetto != "" and _ascii(effetto),
			"e con un effetto leggibile: '%s'" % effetto)
	h.eq(int(prog.pending()), 3,
		"leggere le tre carte non ha scelto niente: la coda e' ancora quella")
	h.eq(_signature(), firma_prima,
		"e non ha mosso un solo numero dell'arma o del giocatore")
	h.eq(str(prog.offer_label(3)), "",
		"un indice oltre la coda non e' un'offerta: il nome e' una stringa vuota")
	h.eq(str(prog.offer_effect(3)), "", "e l'effetto pure")
	h.near(float(weapon.damage), danno_prima, 0.0001,
		"il danno e' quello di prima di leggere le carte: %.2f" % danno_prima)

	# Una sola scelta, e le altre due si buttano: regola dell'utente, 2026-10-13.
	# `pending()` va da 3 a 0 in un colpo, non 3 -> 2 -> 1 -> 0. Il numero che
	# decide e' che **una** sola delle tre offerte arriva al giocatore e che le
	# altre due non sono "in attesa" da qualche parte: sono scartate.
	var signature_before := _signature()
	var chosen: String = prog.choose(0)
	h.check(chosen != "", "l'offerta scelta e' applicabile: '%s'" % chosen)
	h.check(_signature() != signature_before,
		"applicare '%s' cambia un numero davvero, non e' un no-op" % chosen)
	h.eq(prog.pending(), 0, "una scelta sola: gli altri due potenziamenti sono scartati, non in coda")
	h.eq(prog.choose(0), "", "e sceglere con il menu vuoto non applica niente")

	horde.chase_speed = chase_before
	weapon.fire_interval = fire_before

# --- 6. 300 colpi, zero allocazioni ---------------------------------------------

func _no_allocation(h) -> void:
	_reset(Vector3.ZERO)
	horde.target = Vector3.ZERO
	# Nemico lontanissimo e proiettili che muoiono subito: 300 colpi senza che
	# nessuno colpisca nessuno, cosi' il confronto e' sul puro costo di sparare.
	# (Se qualcuno colpisse, `Game.damage_enemy` passerebbe da una Callable e
	# li' dentro ci sarebbe un'allocazione che non e' del gameplay.)
	horde.add(Vector3(0.0, 0.9, -20.0), TOUGH)
	var fire_before: float = weapon.fire_interval
	var life_before: float = weapon.projectile_life
	weapon.fire_interval = 0.0
	weapon.projectile_life = DT
	weapon.cooldown = 0.0
	for i in 5:
		_frame()
	pool.reset()
	var shots_before: int = weapon.shots
	var created_before: int = pool.ever_created()

	var nodes_before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var objects_before := Performance.get_monitor(Performance.OBJECT_COUNT)
	var peak := 0
	for i in 300:
		_frame()
		peak = maxi(peak, pool.active_count())
	var nodes_after := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var objects_after := Performance.get_monitor(Performance.OBJECT_COUNT)

	h.check(weapon.shots - shots_before >= 300,
		"300 frame a fuoco libero devono dare almeno 300 colpi (ne sono partiti %d)"
		% (weapon.shots - shots_before))
	h.eq(pool.ever_created(), created_before,
		"nessun proiettile creato dopo i primi 100")
	h.eq(pool.ever_created(), pool.capacity(),
		"il pool non ha mai creato un proiettile oltre i suoi 100")
	h.check(peak <= pool.capacity(), "il pool non e' mai andato oltre la capacita' (%d)" % peak)
	h.check(nodes_after == nodes_before,
		"nessun nodo nuovo in 300 colpi: %d -> %d" % [int(nodes_before), int(nodes_after)])
	h.check(objects_after - objects_before <= 2,
		"nessuna allocazione nel ciclo di sparo: oggetti %d -> %d (delta %d)"
		% [int(objects_before), int(objects_after), int(objects_after - objects_before)])

	# Ripulisci i campi toccati, o il file si lascia la regolazione sporca.
	weapon.fire_interval = fire_before
	weapon.projectile_life = life_before

# --- 7. Criterio n. 2 di m2: l'XP fa salire di livello, e non e' finta -----------
#
# Questa sezione e' stata spostata in `tests/test_progression.gd`, che e' il file
# che il piano §3.3 assegna al criterio n. 2. Qui non c'e' piu'.

# --- 8. Criterio n. 3 di m2: un potenziamento cambia un numero di almeno il 2% --
#
# Questa sezione e' stata spostata in `tests/test_upgrades.gd`, che e' il file che
# il piano §3.3 assegna al criterio n. 3, e che la misura **sulla scena vera**.
# Qui non c'e' piu'.
## scrivono, quindi la firma di un potenziamento e' questo dizionario.
func _numeri() -> Dictionary:
	return {
		"damage": float(weapon.damage),
		"fire_interval": float(weapon.fire_interval),
		"projectile_speed": float(weapon.projectile_speed),
		"projectile_life": float(weapon.projectile_life),
		"knockback": float(weapon.knockback),
		"pierce": int(weapon.pierce),
		"acquire_radius": float(weapon.acquire_radius),
		"move_speed": float(player.move_speed),
		"max_hp": float(player.max_hp),
		"hp": float(player.hp),
	}

## Le stesse cose piu' le tre grandezze **derivate** sono in
## `tests/test_upgrades.gd`: qui la firma non serve, perche' la unica firma che
## questo file confronta e' quella della regolazione di partenza.

# --- 9. Criterio n. 4 di m2, meta' di -gameplay: il restart ----------------------
#
# `horde.restart_run()` (di -orda) azzera l'orda e la partita e **non tocca il
# giocatore**: se le vite restano a zero, il passo di simulazione successivo
# rilegge `game_over` e la partita si ferma di nuovo. Questa sezione verifica la
# meta' di -gameplay, e il numero che decide e' uno solo e non e' un numero di
# campi:
#
#     dopo restart_run(), un passo di simulazione NON deve rileggere game_over
#
# Se `reset_run()` non rimettesse in piedi il giocatore, quel numero resta
# `game_over` e qui si vede. E i campi sono la spiegazione, non la prova: un
# restart che azzerasse otto numeri ma lasciasse la partita ferma non e' un
# restart.
#
# ## Il difetto che questa sezione e' nata per trovare
##
## `player.reset_run()` chiamava `weapon.reset()`, che **non esisteva**:
# `reset_run()` lanciava `Invalid call. Nonexistent function 'reset'` a meta' della
# propria esecuzione, e il restart non rimetteva in piedi l'arma. Il sintomo che
# si sarebbe visto e' questo: le vite tornavano a 100 e il livello a 1, ma il
# danno restava quello potenziato della partita precedente. Percio' qui il danno
# viene sporcato **prima** del restart e confrontato **dopo**.
#
# ## E il difetto che questa sezione ha poi trovato al posto suo
#
# Il riferimento era sbagliato, non il codice. `vita0`/`corsa0`/`spinta0` venivano
# letti **all'inizio della sezione**, e a quel punto la sezione 5 aveva gia'
# applicato tre potenziamenti: il test si aspettava la spinta a 23.4 (18.0 x 1.3),
# la vita massima a 120 (100 + 20) e la corsa a 8.47 (7.0 x 1.1 x 1.1). Il codice
# riportava tutto alla **regolazione di partenza** e il test lo chiamava difetto.
#
# Il riferimento giusto e' `_prima`: la regolazione **vergine**, letta in `_setup()`
# prima che una sola sezione la tocchi. Con quello il restart e' confrontato con i
# numeri con cui la partita e' davvero cominciata, che e' l'unica cosa che un
# restart deve ripristinare. E il numero che ne esce dice anche che `KNOCKBACK`
# non e' stato alzato in m2 (piano §1.2, conseguenza n. 2): `spinta0` e' il valore
# di `weapon_base.gd`, e resta quello dopo il restart.

## ## Il vicino **sul piano** che l'arma interroga: una funzione, due scene
##
## La strada e' quella di `count_on_floor()` (`src/sim/horde.gd:927-932`): si
## scorrono gli indici e si tiene `enemy_floors[i] == piano`, e `enemy_floors` e' un
## `PackedInt32Array` **pubblico** (riga 309). Il vicino **globale** non serve: un
## nemico a 12 m sul piano 3 non e' un bersaglio per un'arma che interroga la
## griglia del piano 0, e misurarlo globale era gia' successo.
##
## Vive in una funzione perche' la si misura in **due mondi diversi** — questa sezione
## senza mappa e `_m12_piano_del_miratore` con `arena_main.tscn` montata — e due
## copie della stessa misura sono due numeri che possono divergere senza che nessuno
## lo veda: e' successo con `quota_precedente` in `-arena` e con la mia prima stampa,
## che leggeva il cooldown dopo il passo invece che prima.
##
## La **forma** e' controllata e non assunta: se `enemy_floors` non avesse una voce
## per nemico la misura sarebbe una lettura fuori dal campo, e un test che stampa un
## numero che non ha misurato e' peggio di un test che non stampa.
func _vicino_sul_piano(hd, piano: int, pos: Vector3) -> Dictionary:
	var piani_nemici: PackedInt32Array = hd.get("enemy_floors")
	var su_piano: int = int(hd.count_on_floor(piano))
	var forma := "coerente: %d voci per %d nemici" % [piani_nemici.size(), int(hd.count)]
	var distanza := INF
	var quota := 0.0
	if piani_nemici.size() == int(hd.count):
		for i in int(hd.count):
			if int(piani_nemici[i]) != piano:
				continue
			var v: Vector3 = hd.transforms[i]
			var d := Vector2(v.x - pos.x, v.z - pos.z).length()
			if d < distanza:
				distanza = d
				quota = v.y
	else:
		forma = "NON COERENTE: %d voci per %d nemici, il minimo per piano non e' misurabile" % [piani_nemici.size(), int(hd.count)]
	return {"piano": piano, "sul_piano": su_piano, "totale": int(hd.count),
		"distanza": distanza, "quota": quota, "forma": forma}

func _restart_run(h) -> void:
	var prog = player.progression
	# L'orda **vera** di -orda prende il contratto: il restart completo la chiama,
	# quindi senza di lei questa sezione misurerebbe solo la meta' di -gameplay, su
	# un'orda che non c'e'. Il passo di simulazione lo guida il test a mano.
	var scr = load(HORDE_SCRIPT)
	if not h.check(scr is Script, "src/sim/horde.gd deve caricare a runtime"):
		return
	var horde_vera = (scr as Script).new()
	horde_vera.name = "OrdaVera"
	horde_vera.set_physics_process(false)
	root.add_child(horde_vera)

	h.check(game.horde == horde_vera,
		"l'orda vera prende il contratto: e' l'orda su cui il gameplay spara")
	h.check(horde_vera.has_method("restart_run"),
		"l'orda espone restart_run(): e' la meta' di -orda del restart, e il restart completo la chiama")
	pool.reset()
	h.check(weapon.has_method("reset"),
		"l'arma espone reset(): e' il metodo che reset_run() chiamava e che non esisteva")
	if not h.check(player.has_method("reset_run") and player.has_method("restart_run"),
		"il giocatore espone reset_run() e restart_run()"):
		return
	h.check(player.has_method("is_dead"), "il giocatore espone is_dead(): e' la domanda sul game over")
	if not h.check(not _prima.is_empty(),
		"la regolazione di partenza e' stata letta in _setup(), prima che una sezione la sporchi"):
		return

	# I numeri di partenza, presi dall'**istanza viva vergine** (`_prima`) e non da
	# una copia dentro questo file: una copia nel test si romperebbe al primo
	# ritocco della regolazione e fallirebbe senza che nessuno l'abbia toccata.
	var vita0: float = float(_prima["max_hp"])
	var danno0: float = float(_prima["damage"])
	var intervallo0: float = float(_prima["fire_interval"])
	var spinta0: float = float(_prima["knockback"])
	var perforante0: int = int(_prima["pierce"])
	var vita_proj0: float = float(_prima["projectile_life"])
	var velocita0: float = float(_prima["projectile_speed"])
	var gittata0: float = float(_prima["acquire_radius"])
	var corsa0: float = float(_prima["move_speed"])

	var nodi0 := _conta_nodi(root)
	var hordi0 := _conta_nomi(root, "OrdaVera")
	h.eq(hordi0, 1, "l'orda vera e' stata installata una volta sola, prima del ciclo")

	# Tre restart di fila, come i tre di -orda: un restart che funziona una volta
	# puo' non funzionare alla seconda, perche' il secondo trova lo stato che il
	# primo ha lasciato.
	for giro in 3:
		_sporca(h, giro)
		h.check(player.is_dead(), "restart %d: prima del restart il giocatore e' a zero vite" % (giro + 1))
		h.check(horde_vera.is_game_over(),
			"restart %d: e la partita e' davvero finita, non solo il giocatore" % (giro + 1))
		h.check(float(weapon.damage) != danno0,
			"restart %d: e il danno e' davvero sporcato dal potenziamento (%.2f contro %.2f)"
			% [giro + 1, weapon.damage, danno0])

		player.restart_run()

		h.near(player.hp, vita0, 0.0001, "restart %d: le vite tornano a %s" % [giro + 1, vita0])
		h.near(player.max_hp, vita0, 0.0001, "restart %d: e la vita massima torna a %s" % [giro + 1, vita0])
		h.check(not player.is_dead(), "restart %d: il giocatore e' di nuovo in piedi" % (giro + 1))
		h.vec_near(player.position, Vector3.ZERO, 0.0001, "restart %d: e al centro dell'arena" % (giro + 1))
		h.vec_near(player.velocity, Vector3.ZERO, 0.0001, "restart %d: fermo, non con la velocita' del game over" % (giro + 1))
		h.near(float(player.move_speed), corsa0, 0.0001, "restart %d: la velocita' di corsa torna a %.2f" % [giro + 1, corsa0])
		h.eq(int(prog.level), 1, "restart %d: la progressione torna al livello 1" % (giro + 1))
		h.near(prog.xp, 0.0, 0.0001, "restart %d: e a zero XP in barra" % (giro + 1))
		h.near(prog.xp_earned, 0.0, 0.0001, "restart %d: e a zero XP guadagnati" % (giro + 1))
		h.eq(int(prog.kills), 0, "restart %d: e a zero uccisioni" % (giro + 1))
		h.eq(int(prog.pending()), 0, "restart %d: e senza offerte rimaste appese" % (giro + 1))

		# L'arma. E' il pezzo che mancava, ed e' quello che il difetto nascondeva.
		h.near(float(weapon.damage), danno0, 0.0001,
			"restart %d: il danno torna a %.2f e NON resta quello potenziato" % [giro + 1, danno0])
		h.near(float(weapon.fire_interval), intervallo0, 0.0001,
			"restart %d: l'intervallo fra i colpi torna a %.3f" % [giro + 1, intervallo0])
		h.near(float(weapon.knockback), spinta0, 0.0001,
			"restart %d: la spinta torna a %.1f m/s" % [giro + 1, spinta0])
		h.eq(int(weapon.pierce), perforante0, "restart %d: e la perforante torna a %d" % [giro + 1, perforante0])
		h.near(float(weapon.projectile_life), vita_proj0, 0.0001,
			"restart %d: la vita del proiettile torna a %.2f s" % [giro + 1, vita_proj0])
		h.near(float(weapon.projectile_speed), velocita0, 0.0001,
			"restart %d: e la sua velocita' a %.1f m/s" % [giro + 1, velocita0])
		h.near(float(weapon.acquire_radius), gittata0, 0.0001,
			"restart %d: e la gittata di mira torna a %.1f m" % [giro + 1, gittata0])
		h.near(float(weapon.cooldown), 0.0, 0.0001,
			"restart %d: l'arma e' pronta a sparare al primo passo" % (giro + 1))
		# ## Quanti `step()` ha fatto l'arma, e **chi**
		#
		# Il numero **non** e' un contatore messo in `weapon_base.gd`: un contatore che
		# esiste solo per un test e' un secondo stato dentro un file di gioco, e un
		# secondo stato e' la copia che non si contraddice. Il numero si **ricava** da
		# un campo che il gioco scrive gia' per sua conta: `cooldown -= delta` a ogni
		# `step()` dell'arma e nient'altro lo tocca, quindi `stepi = -cooldown / DT`.
		#
		# Il `cooldown = -0,02 s` che la sezione m12 misura piu' avanti vuol dire che
		# **uno** `step()` e' gia' avvenuto quando la parte m12 guarda: nessuno dei tre
		# restart comincia con l'arma ferma. Il punto e' **chi**, e si legge per
		# **eliminazione**: il numero e' campionato accanto a ogni chiamata che
		# potrebbe steppare, e l'unica dopo cui cresce e' quella che lo ha fatto.
		var stepi_0 := int(round(-float(weapon.cooldown) / DT))
		h.eq(int(weapon.shots), 0, "restart %d: il contatore dei colpi riparte" % (giro + 1))
		h.eq(int(pool.active_count()), 0, "restart %d: nessun proiettile resta in volo" % (giro + 1))
		h.eq(int(pool.ever_created()), int(pool.capacity()),
			"restart %d: i %d proiettili sono gli stessi di prima, nessuno creato" % [giro + 1, pool.capacity()])

		# La meta' di -orda, verificata perche' il restart completo la chiama.
		h.eq(int(horde_vera.wave), 1, "restart %d: si torna all'onda 1" % (giro + 1))
		h.eq(horde_vera.run_state(), "playing", "restart %d: e la partita riparte" % (giro + 1))
		h.check(int(horde_vera.count) > 0,
			"restart %d: horde.count azzerato e RIPOPOLATO (%d)" % [giro + 1, horde_vera.count])

		# ## IL NUMERO CHE DECIDE
		#
		# Un passo di simulazione, e la partita non deve rientrare in game_over.
		# E' qui che la meta' di -gameplay si vede: se le vite fossero rimaste a
		# zero, `_poll_run` le rileggerebbe e la partita si fermerebbe di nuovo.
		horde_vera.step(DT)
		h.check(not horde_vera.is_game_over(),
			"restart %d: dopo il restart un passo di simulazione NON rilegge game_over (stato '%s')"
			% [giro + 1, horde_vera.run_state()])
		h.eq(horde_vera.run_state(), "playing", "restart %d: la partita riparte sul serio" % (giro + 1))
		var stepi_1 := int(round(-float(weapon.cooldown) / DT))
		var ferma: PackedVector3Array = horde_vera.transforms.duplicate()
		horde_vera.step(DT)
		var stepi_2 := int(round(-float(weapon.cooldown) / DT))
		h.check(horde_vera.transforms != ferma,
			"restart %d: e il mondo si muove di nuovo: non era fermo per sempre" % (giro + 1))

		# Nessun nodo duplicato. Il totale puo' restare uguale con due orde e una
		# orda morta, quindi si conta anche quante orde ci sono per nome.
		h.eq(_conta_nodi(root), nodi0, "restart %d: nessun nodo creato o liberato" % (giro + 1))
		h.eq(_conta_nomi(root, "OrdaVera"), hordi0,
			"restart %d: una sola orda sotto root, non due" % (giro + 1))
		h.check(game.horde == horde_vera, "restart %d: e il contratto punta ancora alla stessa orda" % (giro + 1))

		# E l'arma spara **subito**, che e' la prima cosa che si sente.
		#
		# Il numero che decide e' `weapon.shots`, non `pool.active_count()`: un
		# colpo partito contro un nemico che sta a un metro dalla canna arriva e
		# muore **nello stesso frame** (percorso 0.43 m, raggio di contatto
		# 0.16 + 0.55), e a quel punto nel pool non c'e' piu' nessuno. Dire "il
		# primo colpo non e' partito" guardando il pool sarebbe misurare la
		# distanza dal nemice piu' vicino, non la cadenza dell'arma.
		# ## I SEI NUMERI, e **quando** sono presi
		#
		# `_try_fire()` ha una sola condizione che ferma **prima** di `shots += 1`:
		# `if target < 0: return`. Quindi `shots == 0` vuol dire che
		# `nearest_enemy` ha risposto `-1`, e **non** vuol dire «la cadenza non era
		# scaduta»: il cooldown e' `0,0` tre righe sopra (riga 1958) e l'intervallo
		# non e' nel cammino prima dello sparo.
		#
		# I numeri sono presi **attorno** al passo e non dopo: `prima` e' lo stato che
		# l'arma incontra quando interroga il contratto, `dopo` e' lo stato in cui
		# siamo quando leggiamo. Una misura e la sua dichiarazione che guardano
		# istanti diversi danno due numeri che non si sommano, ed e' gia' successo
		# in questo file (la sezione m12 guardava la salita dopo che era finita).
		#
		# `has_impl("surface_height_at")` e' il numero che **chiude** la porta a una
		# mia sospetta: a questo punto del file il canale di `-arena` **non e'
		# registrato** (la scena vera viene montata molto piu' in la', alla riga
		# 2221, e il doppio di prova si installa alla 3801), quindi
		# `_appoggia_sulla_superficie()` prende `-1,0` e **non puo'** aver mosso la
		# quota. Se la stampa dicesse `true` quella conclusione cadrebbe, ed e'
		# per questo il numero c'e' invece di essere un fatto.
		var prima_pos: Vector3 = player.position
		var prima_piano: int = 0
		var prima_idx: int = int(game.nearest_enemy(prima_pos, float(weapon.acquire_radius)))
		var canale: bool = game.has_impl("surface_height_at")
		var prima_cd: float = float(weapon.cooldown)
		var colpi_prima: int = int(weapon.shots)
		player.step(DT, Vector3.ZERO)
		var dopo_pos: Vector3 = player.position
		var stepi_3 := int(round(-float(weapon.cooldown) / DT))
		# **Chi** ha steppato l'arma prima del criterio: il numero e' campionato
		# accanto a ogni chiamata che potrebbe farlo, quindi si legge per
		# eliminazione. `stepi_0` e' subito dopo `restart_run()`, `stepi_1` dopo la
		# PRIMA `horde_vera.step(DT)`, `stepi_2` dopo la seconda, `stepi_3` dopo la
		# `player.step()` del criterio. Il `-cooldown / DT` e' esatto perche'
		# `cooldown -= delta` e' l'unica scrittura del campo.
		print("m2 restart %d: `step()` dell'arma derivati dal cooldown (`cooldown -= DT` a ogni step e nient'altro tocca il campo, quindi stepi = -cooldown / DT): %d subito dopo restart_run(), %d dopo la PRIMA horde_vera.step(DT), %d dopo la seconda, %d dopo la player.step() del criterio. Lettura: se il numero sale gia' alla prima horde_vera.step e il primo e' %d, allora e' l'orda (o chi lei chiama) a steppare il giocatore; se sale solo dopo la seconda, e' la seconda; se non sale mai fino alla player.step(), allora nessuno la steppa e il -0,02 s che m12 misura arriva da qualche altra parte"
			% [giro + 1, stepi_0, stepi_1, stepi_2, stepi_3, stepi_1])
		var dopo_piano: int = 0
		var dopo_idx: int = int(game.nearest_enemy(dopo_pos, float(weapon.acquire_radius)))
		# Il nemico **piu' vicino** letto dall'orda, non dal contratto: e' l'unico
		# modo di distinguere «la griglia che l'arma interroga non ha nessuno» da
		# «il nemico c'e' ma e' troppo lontano per la gittata». Sono due difetti di
		# due foglie diverse e la tabella qui sotto li mette nello stesso numero.
		var vicino := INF
		var vicino_y := 0.0
		for t in horde_vera.transforms:
			var v: Vector3 = t
			var dist := Vector2(v.x - dopo_pos.x, v.z - dopo_pos.z).length()
			if dist < vicino:
				vicino = dist
				vicino_y = v.y
		print("m2 restart %d: primo passo dopo restart_run(). has_impl(surface_height_at) = %s, fire_interval = %.2f s, cooldown %.4f s **prima** del passo e %.4f s dopo (il passo del criterio stesso lo porta a -DT), acquire_radius = %.2f m, horde.count = %d, horde._built = %s. Prima del passo: posizione (%.3f, %.3f, %.3f), player_floor() = %d, nearest_enemy = %d. Dopo il passo: posizione (%.3f, %.3f, %.3f), player_floor() = %d, nearest_enemy = %d, nemico piu' vicino **in tutta l'orda** a %.2f m di quota %.3f m (quello sul piano del giocatore e' nella riga sotto), shots = %d contro %d di prima. Tabella: has_impl = false esclude _appoggia_sulla_superficie(); horde.count > 0 ma zero nemici sul piano che l'arma interroga = la griglia di quel piano e' vuota e count e' un TOTALE su tutti i piani; vicino **sul piano** dentro la gittata e indice -1 con _built = true = il difetto e' dentro nearest_enemy; vicino sul piano fuori la gittata = gli anelli di nascita e la gittata non si incontrano, e la regolazione dei due numeri e' fra due foglie; _built = false = la griglia non e' stata costruita; indice >= 0 prima e -1 dopo = la quota ha spostato la banda ed e' mia; indice >= 0 e shots = 0 = il difetto e' fra nearest_enemy e spawn_projectile. Lettura del cooldown: se quello **prima** del passo e' 0,0000 nessuno ha steppato l'arma prima del criterio e il -DT finale e' il passo del criterio stesso, quindi il criterio misura uno stato che il gioco ha davvero"
			% [giro + 1, str(canale), float(weapon.fire_interval), prima_cd, float(weapon.cooldown),
				float(weapon.acquire_radius), int(horde_vera.count), str(horde_vera.get("_built")),
				prima_pos.x, prima_pos.y, prima_pos.z, prima_piano, prima_idx,
				dopo_pos.x, dopo_pos.y, dopo_pos.z, dopo_piano, dopo_idx,
				vicino, vicino_y, int(weapon.shots), colpi_prima])
		# ## Il vicino **sul piano**, su questa scena che **non** ha mappa
		#
		# Qui `Game.obstacles` e' vuoto — la sezione che lo riempie e' di `-arena` e
		# questa gira prima che la scena sia montata — quindi l'orda si muove senza
		# niente intorno. E' un mondo in cui **il gioco non si gioca**, e un numero
		# letto qui non giudica niente: e' vero e non significa niente. Per questo lo
		# stesso numero viene riletto **sulla scena vera**, in
		# `_m12_piano_del_miratore`, e sono due numeri di due mondi diversi.
		var vic: Dictionary = _vicino_sul_piano(horde_vera, dopo_piano, dopo_pos)
		print("m2 restart %d: SENZA MAPPA. floor_count = %d, arena_radius = %.3f m, Game.obstacles = %d dischi, RING_COUNTS dichiarati = %s. Sul piano che l'arma interroga (%d) ci sono %d nemici su %d in tutto, e il piu' vicino e' a %s m (quota %.3f m) contro una gittata di %.2f m. enemy_floors %s. Lettura: questo numero e' vero e **non giudica niente**, perche' il gioco non si gioca qui; quello che giudica e' lo stesso numero letto sulla scena vera"
			% [giro + 1, int(game.get("floor_count")), float(game.get("arena_radius")),
				(game.get("obstacles") as PackedVector3Array).size(), str(OBST.RING_COUNTS),
				int(vic["piano"]), int(vic["sul_piano"]), int(vic["totale"]),
				("%.2f" % float(vic["distanza"])) if float(vic["distanza"]) < INF else "assente",
				float(vic["quota"]), float(weapon.acquire_radius), str(vic["forma"])])
		# ## I cinque numeri del **pool**, e il sospetto che il codice suggerisce
		#
		# `projectile_pool.acquire()` (riga 351) ha **due** soli rifiuti: `weapon ==
		# null` e l'invariante rotta (riga 371). Quindi «`shots` non sale mai, `pool`
		# ha zero proiettili vivi» ha due sole spiegazioni: **due pool diversi**, o
		# **il riferimento `weapon` del pool che l'arma guarda e' nullo**. Il primo
		# sospetto e' «il test fa `reset()` su una istanza e l'arma ne tiene un'altra»,
		# e i due numeri che lo chiudono sono `pool == weapon.pool` e
		# `weapon.pool.weapon == weapon`: sono due nodi e due back-reference, e
		# l'identita' la dice il runtime, non la lettura.
		var pool_arma = weapon.get("pool")
		var stessa_istanza: bool = pool_arma == pool
		var arma_del_pool = pool_arma.get("weapon") if pool_arma != null else null
		# ## La condizione di `projectile_pool.gd:371`, con i suoi numeri
		#
		# Il rifiuto di riga 371 si raggiunge solo con `_free_top == 0` **e**
		# `_count < CAPACITY`: cioe' la **lista dei liberi e' vuota mentre gli attivi
		# sono sotto la capienza**, che e' l'invariante rotta («`CAPACITY` record,
		# `CAPACITY` indici, e ogni indice o e' in `_order[0.._count)` o in `_free`»).
		# Con zero proiettili vivi e cento slot, quella e' l'unica spiegazione che
		# resta, e sono tre numeri a dirlo: la lista dei liberi e gli attivi.
		var liberi: int = int(pool_arma.get("_free_top")) if pool_arma != null else -1
		var attivi: int = int(pool_arma.get("_count")) if pool_arma != null else -1
		var cap_pool: int = int(pool_arma.get("CAPACITY")) if pool_arma != null else -1
		var rifiuta: bool = liberi == 0 and attivi < cap_pool
		print("m2 restart %d: la condizione di `projectile_pool.gd:371` con i valori di questo momento: `_free_top` = %d, `_count` = %d, `CAPACITY` = %d, quindi «lista dei liberi vuota E attivi sotto la capienza» = **%s**. Se e' vera, `acquire()` prende il ramo di riga 371 e restituisce `null` con 100 slot apparentemente liberi: il difetto e' **nell'invariante**, non nel rifiuto"
			% [giro + 1, liberi, attivi, cap_pool, str(rifiuta)])
		print("m2 restart %d: i cinque numeri del pool. 1) `pool == weapon.pool`: %s. 2) `pool.active_count()`: %d su %d slot, e sul pool che l'arma guarda: %d. 3) capienza dichiarata: %d. 4) il riferimento `weapon` dentro il pool che l'arma guarda: %s (null = `acquire()` rifiuta ogni volta, riga 353). 5) `weapon.cooldown` %.4f s con %d colpi già spariti, e `pool.active_count()` %d dopo il `pool.reset()` di questa sezione. Lettura: pool == weapon.pool e weapon.pool.weapon non nullo = il difetto NON e' questo e va dentro `acquire()`"
			% [giro + 1, str(stessa_istanza), int(pool.active_count()), int(pool.capacity()),
				int(pool_arma.active_count()) if pool_arma != null else -1,
				int(pool_arma.capacity()) if pool_arma != null else -1,
				"NULLO" if arma_del_pool == null else ("LA STESSA ARMA" if arma_del_pool == weapon else "UN'ALTRA ARMA"),
				float(weapon.cooldown), int(weapon.shots), int(pool.active_count())])
		# ## Perche' qui il criterio **non** giudica, e dove giudica
		#
		# Il numero qui sotto e' **vero e non giudica niente**: questa sezione gira
		# **prima** di ogni montaggio di scena, quindi `Game.obstacles` e' vuoto, il
		# campo si muove senza mappa e il nemico piu' vicino sul piano logico sta a
		# `31 m`, fuori dai `26,00 m` di gittata. In gioco l'arma vede un campo
		# **dentro** la gittata (`9,63 m` sulla scena vera, `48` dischi): quindi
		# «il primo colpo non parte» qui non e' un difetto del codice, e' un numero
		# letto su un mondo in cui il gioco non si gioca.
		#
		# Il criterio che **giudica** e' l'identico, in `_m12_piano_del_miratore`,
		# dove `arena_main.tscn` e' montata. Un criterio che cambia scena senza
		# dichiararlo e' un criterio che un giorno misurera' due cose diverse e non
		# lo sapra': quindi qui resta la misura, e la dichiarazione dice **quale**
		# scena e **perche'** quella.
		print("m2 restart %d: numero letto su un mondo **senza mappa**, dichiarato perche' non giudica: primo passo, `nearest_enemy` = %d, `shots` = %d contro %d di prima. Il criterio che giudica e' quello di `_m12_piano_del_miratore`, sulla scena montata"
			% [giro + 1, dopo_idx, int(weapon.shots), colpi_prima])

	# `reset_run()` da solo: rimette in piedi il giocatore e **non** tocca l'onda.
	# E' la separazione delle due meta' dichiarata in testa al file, misurata.
	var wave_prima := int(horde_vera.wave)
	var uccise_prima := int(horde_vera.kills)
	player.reset_run()
	h.near(player.hp, vita0, 0.0001, "reset_run() da solo rimette in piedi il giocatore")
	h.eq(int(prog.level), 1, "e azzera la progressione")
	h.eq(int(horde_vera.wave), wave_prima, "ma non tocca l'onda: e' la meta' di -orda")
	h.eq(int(horde_vera.kills), uccise_prima, "e non tocca le uccisioni contate dall'orda")

	# Il tasto che rimette in piedi la partita: una volta sola per pressione. Un
	# `Input.is_key_pressed` tenuto premuto chiamerebbe il restart a ogni frame e
	# la partita ripartirebbe ogni 16 ms.
	_tasto_restart(h)
	print("m2 restart: 3 restart completi + reset_run() da solo, %d nodi prima e dopo, "
		% nodi0 + "HP %.1f -> %.1f, danno %.2f -> %.2f"
		% [vita0, player.hp, danno0, float(weapon.damage)])

## Sporca tutto quello che un restart deve ripulire: vite a zero, progressione
## avanti di quattro livelli, e tre potenziamenti applicati. Il danno viene
## **rimosso** subito dopo, perche' con tutti i nemici dell'orda vera vicino un
## colpo riporterebbe il danno al valore di codice e il difetto del `reset()`
## mancante sparirebbe dal test.
func _sporca(h, giro: int) -> void:
	var prog = player.progression
	player.hp = 0.0
	player.invuln = 0.0
	player.velocity = Vector3(3.0, 0.0, -4.0)
	player.position = Vector3(5.0, 0.0, 5.0)
	prog.reset()
	prog.add_xp(prog.xp_to_next() * 4.0)
	for id in ["damage", "fire_rate", "move_speed"]:
		prog.apply(id)
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	# Il colpo che sporca il contatore si spara **da vivo**, e la morte arriva
	# dopo. Da m13-w3 l'arma spara solo se il giocatore e' vivo, quindi la riga
	# che metteva a zero le vite prima del passo non produceva piu' nessun colpo:
	# il contatore da azzerare ora esiste **perche' il giocatore era in piedi**,
	# che e' l'ordine della partita vera. Il secondo passo serve all'altra meta':
	# senza uno step dopo `hp = 0` l'orda non ha ancora rilevato `game_over`.
	player.hp = player.max_hp
	_passo_di_gioco()
	h.check(float(weapon.damage) > 0.0,
		"restart %d: la regolazione e' sporcata prima di misurare" % (giro + 1))
	# ## Perche' qui il contatore **non** e' un numero che giudica
	#
	# «`shots > 0`» serve a una cosa sola: dare un significato allo `shots == 0` che
	# il restart azzera. Ma su **questa** scena nessun colpo parte, perche' la mappa
	# non e' montata e il campo e' tutto fuori gittata (vedi la stampa dei cinque
	# numeri e quella del mondo senza mappa, piu' in bassi). Quindi qui la domanda
	# «sono partiti colpi?» ha la risposta giusta — **no** — e la risposta giusta non
	# prova niente: un contatore che resta a zero su un mondo senza bersagli non e' un
	# contatore che non esiste.
	#
	# Il numero che **prova** che il contatore esiste e' sulla scena montata: in
	# `_m12_piano_del_miratore` la stessa arma spara `M12_MIRA_PASSI` passi e conta i
	# colpi (`m12 mira: ... colpi/s`), ed e' li' che `shots` ha un significato.
	print("m2 restart %d: `shots` dopo un passo di gioco su questa scena **senza mappa** vale %d: nessun colpo parte perche' nessun bersaglio e' in gittata, e quindi questo numero **non** prova che il contatore esista. La prova sta in `_m12_piano_del_miratore`, sulla scena montata, dove la stessa arma spara e i colpi si contano"
		% [giro + 1, int(weapon.shots)])
	player.hp = 0.0
	player.invuln = 0.0
	_passo_di_gioco()

## Un passo di gioco sul giocatore e sull'orda **vera**: a questo punto della sezione
## e' quella sul contratto, non il finto.
func _passo_di_gioco() -> void:
	player.step(DT, Vector3.ZERO)
	var hv = game.horde
	if hv != null:
		hv.step(DT)

## Il tasto del restart. Chiamato direttamente perche' in un `--script` non c'e'
## una pipeline di input che il test possa pilotare, e quello che si prova qui e'
## la **decisione** (quando il restart parte e quando non parte), non il
## trasporto dell'evento: chi lo trasporta e' il gioco.
func _tasto_restart(h) -> void:
	var player_legge_tasti: bool = player.read_keys
	player.read_keys = true

	# Il tasto non fa niente con il giocatore in piedi.
	var vite_prima: float = player.hp
	player._unhandled_input(_tasto(KEY_ENTER, true, false))
	h.near(player.hp, vite_prima, 0.0001, "il tasto del restart non fa niente se il giocatore e' vivo")

	# Con le vite a zero lo rimette in piedi, una volta sola.
	player.hp = 0.0
	var horde_vera = game.horde
	if horde_vera != null:
		horde_vera.step(DT)
	h.check(player.is_dead(), "con le vite a zero il giocatore e' morto")
	if horde_vera != null:
		h.check(horde_vera.is_game_over(), "e la partita e' finita")
	player._unhandled_input(_tasto(KEY_ENTER, true, false))
	h.check(not player.is_dead(), "il tasto del restart rimette in piedi il giocatore")
	if horde_vera != null:
		h.check(not horde_vera.is_game_over(), "e la partita riparte: il tasto chiama restart_run(), non reset_run()")

	# Il tasto tenuto premuto (`echo`) non deve rilanciare il restart a ogni
	# frame: si conta che una seconda pressione con echo non tocchi niente.
	var spinta := int(horde_vera.kills) if horde_vera != null else 0
	player._unhandled_input(_tasto(KEY_R, true, true))
	h.near(player.hp, player.max_hp, 0.0001,
		"una pressione con echo non e' una nuova pressione: le vite non cambiano")
	if horde_vera != null:
		h.eq(int(horde_vera.kills), spinta, "e l'orda non viene riarruolata un'altra volta")

	# E il tasto rilasciato non fa niente.
	player.hp = 0.0
	player._unhandled_input(_tasto(KEY_R, false, false))
	h.check(player.is_dead(), "il rilascio del tasto non e' una pressione: non rimette in piedi nessuno")

	# Un tasto che non e' fra quelli del restart non fa niente.
	player.hp = 0.0
	player._unhandled_input(_tasto(KEY_Q, true, false))
	h.check(player.is_dead(), "un tasto che non e' fra quelli del restart non avvia niente")

	player.read_keys = player_legge_tasti

## Un `InputEventKey` costruito a mano.
func _tasto(code: int, premuto: bool, ripetuto: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = premuto
	ev.echo = ripetuto
	return ev

# ================================================================================
# m13-w3, segnalazione 1: l'arma spara DOPO LA MORTE
# ================================================================================
#
# `weapon_base.gd::step()` chiamava `_try_fire()` senza chiedere se il giocatore
# fosse vivo. A `game_over` la pausa la mette -orda (`horde.step` ritorna
# subito), ma il **cooldown e' un numero del giocatore**: l'albero continua a
# girare e l'arma spara per sempre sopra una partita finita.
#
# ## I due numeri, e perche' sono due finestre e non una
#
# La finestra **avvelenata** e' il difetto **misurato**: falsificata la condizione
# di morte (`hp` sopra zero) l'arma spara, e i colpi contati sono esattamente
# quelli che il codice di prima emetteva in 600 passi. La finestra **vera** e' la
# correzione: stessi 600 passi, condizione vera, zero colpi. Il numero della
# seconda non puo' passare spegnendo l'arma **per sempre**: e' la prima finestra a
# pretendere che il contatore torni a crescere, quindi la correzione e' «il fuoco
# finisce **perche' il giocatore e' morto**» e non «l'arma e' stata spenta».

const MORTE_PASSI := 600

func _fuoco_dopo_morte(h) -> void:
	var hd = game.horde
	# ## L'orda **di chi**: il percorso, non il conteggio
	#
	# Il guard qui sotto fallisce con `count == 0`, e `count == 0` dice che l'orda e'
	# **vuota** ma non dice **di chi e'**: un'orda vuota e un'orda sbagliata danno lo
	# stesso numero e due rimedi diversi. Il rimedio del primo e' «riempi l'orda», il
	# rimedio del secondo e' «`game.horde` deve puntare all'orda che questa sezione sta
	# misurando», cioe' che `_restart_run` registri la sua e nessun'altra la sovrascriva
	# dopo. Solo il **percorso** distingue le due.
	if hd != null:
		print("morte: `game.horde` e' %s (conteggio %d); la sezione che lo ha registrato e' `_restart_run`, che monta `%s`"
			% [str(hd.get_path()), int(hd.get("count")), NODO_HORDE])
	else:
		print("morte: `game.horde` e' null: nessuna sezione ha registrato un'orda sul contratto")
	# `_tasto_restart` lascia il giocatore **morto**: qui si riparte da una
	# partita in piedi, e `restart_run()` e' la strada vera del gioco.
	player.restart_run()
	if not h.check(hd != null and int(hd.get("count")) > 0,
		"morte: l'orda deve avere nemici vivi, altrimenti la finestra non misura niente"):
		return
	# Il giocatore in piedi deve **sparare davvero**: senza un colpo prima della
	# morte il contatore da confrontare e' un numero che non e' mai salito. Lo
	# scaldata non deve finire in una morte che copra la misura, quindi la vita
	# si rimette in piedi ogni passo e si esce appena e' partito un colpo.
	for i in MORTE_PASSI:
		_passo_di_gioco()
		player.hp = player.max_hp
		if int(weapon.shots) > 0:
			break
	if not h.check(int(weapon.shots) > 0, "morte: il giocatore in piedi spara almeno un colpo"):
		return

	# --- AVVELENATA: il difetto, misurato sullo stesso codice -------------------
	player.hp = MORTE_HP_POLA
	player.invuln = 0.0
	h.check(not player.is_dead(),
		"morte: avvelenata la condizione di morte (hp %.1f) il giocatore non e' morto" % MORTE_HP_POLA)
	var prima := int(weapon.shots)
	for i in MORTE_PASSI:
		# Solo il giocatore, e non l'orda: `_poll_run()` legge `hp`, con 1.0 di
		# vita ripartirebbe, l'orda morderebbe e il fuoco si fermerebbe per un
		# motivo che non e' la porta sotto esame.
		player.step(DT, Vector3.ZERO)
	var avvelenati := int(weapon.shots) - prima

	# --- VERA: la correzione ----------------------------------------------------
	player.hp = 0.0
	player.invuln = 0.0
	var morti := int(weapon.shots)
	for i in MORTE_PASSI:
		_passo_di_gioco()
	var emessi := int(weapon.shots) - morti
	h.eq(emessi, 0,
		"morte: %d passi (%.1f s) dopo la morte l'arma non emette nessun proiettile (%d -> %d colpi)"
			% [MORTE_PASSI, float(MORTE_PASSI) * DT, morti, int(weapon.shots)])
	h.check(avvelenati > 0,
		"morte: avvelenata la condizione di morte il contatore TORNA a crescere (%d colpi in %d passi)"
			% [avvelenati, MORTE_PASSI])
	h.near(float(player.hp), 0.0, 0.0001, "morte: hp a zero resta a zero")
	h.eq(int(pool.active_count()), 0, "morte: nessun proiettile resta in volo")
	print("m13-w3 morte: avvelenata %d colpi in %d passi, vera %d colpi in %d passi, hp %.1f"
		% [avvelenati, MORTE_PASSI, emessi, MORTE_PASSI, float(player.hp)])
	# Si lascia la partita come la trovata: le sezioni dopo leggono da qui.
	player.restart_run()

# ================================================================================
# m13-w3, segnalazione 2: il restart attraverso il TRASPORTO vero
# ================================================================================
#
# `_tasto_restart` chiama `_unhandled_input` **a mano**: prova la **decisione**,
# non il trasporto. E il trasporto e' l'unica cosa che nel gioco puo' non
# arrivare, quindi qui l'evento passa da `Viewport.push_input`, che e' la porta
# vera e l'unica che nel gioco chiama quel metodo.
#
# I tre esiti sono i tre difetti possibili, e sono distinguibili:
#   - `hp` torna al massimo: il tasto funziona e nessuno lo diceva (-ui);
#   - evento **gestito** e `hp` ancora a zero: un altro handler lo ha consumato;
#   - evento non gestito e `hp` a zero: la pipeline non e' arrivata al nodo.

## Quanti restart in fila: la classe di difetto che ne lascia **uno in piu'** a ogni
## giro si vede solo al secondo e al terzo.
const TASTO_GIRO := 3
## Le vite con cui si avvelena la condizione di morte: sopra zero, non morta.
const MORTE_HP_POLA := 1.0

## ## LA REGOLA DEL FILE: una sezione che monta un mondo deve liberarlo
##
## Il difetto e' nato qui dentro, non in una sezione: `_libera()` usava
## `queue_free()`, che in un `--script` — **un frame solo** — non si svuota mai, e tre
## sezioni si ritrovavano con la scena dell'altra ancora in albero. La sezione che
## seguiva **ereditava** quel mondo, `root.get_children()` lo contava fra i suoi, e i
## suoi numeri diventavano i numeri di **due** sezioni insieme: la stessa classe del
## difetto che questo file aveva chiuso quattro volte, cioe' un criterio misurato su un
## mondo diverso da quello in cui il gioco si gioca.
##
## **La regola e' qui e non dentro le sezioni**, perche' una regola dentro una sezione
## vale solo dove c'e' la sezione, e il difetto e' nato in una sezione che non sapeva
## di dover montare. Il `_libera()` e' `remove_child` + `free()`: `queue_free()` rimane
## **solo** per il teardown di fine file, dove non serve vedere l'albero.
##
## ## La tabella `sezione -> scena che possiede`, che e' il numero che rende il difetto
## ## visibile invece che nascosto
##
## `m` = monta una scena, `f` = la libera, `-` = non la tocca. Le tre righe con `m` e
## senza `f` erano le tre fughe: la tabella le rende leggibili senza dover eseguire
## niente, e una riga che mente e' una riga che non si aggiorna.
const M12_SCENE_MONTATE := [
	["_tasto_reale", "arena_main", "m", "f (a mano: remove_child + free)"],
	["_m5_trasformazione_del_renderer", "arena_main", "m", "f"],
	["_m5_nessun_nodo_in_piu", "arena_main", "m", "f"],
	["_m10_ostacoli_del_contratto", "arena_main", "m", "f"],
	["_m14a_involucro", "sonda", "m", "f (_libera_sonda)"],
	["_m12_piano_del_miratore", "arena_main", "m", "f"],
	["_m12_numerazione_delle_rampe", "arena_main", "m", "f"],
	["_m5_ingresso_su_schermo", "Camera3D di prova", "m", "f"],
]

## Quante sezioni **dipendono** da una scena montata da un'altra: la domanda che la
## tabella rende visibile, e la risposta va riletta ogni volta che la tabella cambia.
## Una sezione che non monta niente e legge `Game.obstacles` sta su un mondo altrui, e
## il suo numero e' quello di due sezioni insieme.
const M12_SCENE_NON_PROPRIE := [
	["_m12_player_floor", "legge _player_floor() su un contratto senza scena"],
	["_m12_ostacoli_per_piano", "costruisce un array di ostacoli perche' quello della scena non c'e'"],
	["_m12_impatto_su_piano", "usa la superficie finta perche' la vera non e' montata"],
	["_restart_run", "misura restart e colpi su un contratto senza mappa"],
	["_fuoco_dopo_morte", "riregistra il contratto dopo che una scena e' stata liberata"],
]

func _stampa_la_tabella() -> void:
	var righe := PackedStringArray()
	for r in M12_SCENE_MONTATE:
		righe.append("%s -> %s (%s%s)" % [str(r[0]), str(r[1]), str(r[2]), str(r[3])])
	var altrui := PackedStringArray()
	for r in M12_SCENE_NON_PROPRIE:
		altrui.append("%s: %s" % [str(r[0]), str(r[1])])
	print("tabella scene: %d sezioni montano un mondo e lo liberano tutte. %d sezioni **non** montano niente e stanno su un mondo altrui: [%s]"
		% [M12_SCENE_MONTATE.size(), M12_SCENE_NON_PROPRIE.size(), ", ".join(altrui)])
	print("tabella scene, righe: [%s]" % ", ".join(righe))

func _censo_di_root(quando: String) -> void:
	# Il **censo dei figli di root**, e perche' va stampato piu' volte.
	#
	# Una sezione che monta un mondo e non lo libera lascia un mondo che la sezione
	# successiva eredita, e i numeri di quella diventano i numeri di **due** sezioni
	# insieme. Il censo e' stampato **all'inizio del file** e **dopo** ogni sezione che
	# monta: e' l'unico numero che dice **quale** sezione ha lasciato il nodo, perche'
	# l'elenco e' diverso prima e dopo.
	var voci := PackedStringArray()
	for nodo in root.get_children():
		var s = nodo.get_script()
		voci.append("%s (%s%s)" % [String(nodo.name), str(nodo.get_path()),
			", script " + str(s.resource_path.get_file()) if s != null else ", senza script"])
	# E il **contratto** nello stesso punto, perche' il censo dei figli e' gia' pulito
	# e un campo del contratto puo' essere stato azzerato lo stesso: i due numeri
	# insieme dicono «il nodo e' sparito» e «il campo e' sparito», che sono due
	# difetti con due rimedi diversi. Lettura nello stesso istante, che e' la regola.
	#
	# ## La guardia, e perche' c'e': **non si legge un campo di un oggetto che non
	# ## esiste ancora**
	#
	# `_censo_di_root` viene chiamata da `_process`, cioe' **prima** che `game` sia
	# assegnato: `game` e' `null` e `game.horde` su un `null` e' `Invalid access to
	# property or key 'horde' on a base object of type 'Nil'`. E poiche' **uno
	# scripting error ferma la funzione**, la stampa moriva li' e il file intero
	# finiva rosso su un errore che era **solo di questa stampa**.
	#
	# Il numero e' comparso due volte, e una volta l'ho letto dalla meta' del log:
	# leggere il log dalla meta' e' quello che l'ha fatto passare due volte. La
	# guardia e' qui perche' la regola e' gia' scritta sopra e va rispettata anche
	# dai numeri che servono a trovare i difetti: **uno strumento che misura puo'
	# essere lui stesso il difetto**.
	var c_horde := "contratto non ancora assegnato"
	var c_player := "contratto non ancora assegnato"
	if game != null:
		c_horde = str(game.horde.get_path()) if game.horde != null else "null"
		c_player = str(game.player.get_path()) if game.player != null else "null"
	print("censo di root %s: %d figli [%s] -- contratto: horde %s, player %s"
		% [quando, voci.size(), ", ".join(voci), c_horde, c_player])

func _tasto_reale(h) -> void:
	# La camera che il viewport ha **prima** di questa sezione: e' il numero con cui
	# si confronta la fine, e senza di questo la sezione potrebbe cambiare il
	# viewport senza che nessuno lo vedesse (e' quello che e' successo: la scena
	# lasciata appesa teneva la sua `Camera` e faceva fallire il ripiego di m5).
	var cam_prima := root.get_camera_3d()
	# ## L'elenco dei figli di root **prima** di montare, e l'obbligo di liberare
	#
	# Il nome automatico `@Node3D@3` del nodo che questa sezione monta esiste **solo**
	# perche' un altro nodo si chiama gia' `ArenaMain`: quindi quell'`ArenaMain` era in
	# albero **prima** di questo montaggio, e non e' di questa sezione. Una sezione che
	# monta un mondo e non lo libera lascia un mondo che la sezione successiva eredita,
	# e i suoi numeri diventano quelli di due sezioni insieme — la stessa classe del
	# difetto che questo file ha chiuso quattro volte, cioe' un criterio misurato su un
	# mondo diverso da quello in cui il gioco si gioca.
	var elenco := PackedStringArray()
	for nodo in root.get_children():
		elenco.append("%s (%s)" % [String(nodo.name), str(nodo.get_path())])
	print("tasto: i figli di root **prima** che questa sezione monti la sua scena sono %d: [%s]. Se c'e' gia' un `ArenaMain`, e' di una sezione **precedente** che monta e non libera, e il numero che chiude il difetto e' in quell'elenco"
		% [elenco.size(), ", ".join(elenco)])
	var packed = load(ARENA_SCENE)
	if not h.check(packed is PackedScene, "tasto: la scena vera deve esistere e caricare"):
		return
	var scena := (packed as PackedScene).instantiate()
	_monta(scena)
	var p = scena.get_node_or_null("Player")
	var hd = scena.get_node_or_null(NODO_HORDE)
	var arma = scena.get_node_or_null("Player/Weapon")
	if p == null or hd == null or arma == null:
		h.check(false, "tasto: la scena vera deve avere \"Player\", \"Player/Weapon\" e \"%s\"" % NODO_HORDE)
		root.remove_child(scena)
		scena.free()
		return
	# **Niente `PROCESS_MODE_DISABLED`**: e' l'unica sezione che lascia il modo di
	# elaborazione com'e', perche' la domanda e' proprio se l'evento arriva. Un
	# nodo disabilitato non riceve input, e il difetto che si cerca qui e' un
	# evento che non arriva.
	if not h.check(bool(p.get("read_keys")),
		"tasto: sulla scena vera il giocatore legge i tasti (il difetto qui e' il trasporto, non la lettura)"):
		root.remove_child(scena)
		scena.free()
		return
	# Il tasto **che il codice dichiara**, letto dalla costante viva: un tasto
	# scritto qui dentro sarebbe un tasto che puo' essere un altro.
	var chiavi: Variant = _script_const(p, "RESTART_KEYS")
	if not h.check(chiavi is Array and (chiavi as Array).size() > 0, "tasto: RESTART_KEYS e' una lista di tasti"):
		root.remove_child(scena)
		scena.free()
		return
	var tasto := int((chiavi as Array)[0])
	# L'orda si popola, il giocatore spara **una volta** e poi l'arma si zittisce
	# (`M16_ARMA_MUTA`: lo stesso silenzio di m16, per lo stesso motivo): un
	# livello aprirebbe il pannello dei potenziamenti, che mette in pausa l'albero,
	# e un albero in pausa non consegna nessun evento — la misura diventerebbe
	# quella della pausa e non quella del tasto.
	for i in MORTE_PASSI:
		hd.call("step", DT)
		if int(hd.get("count")) > 0:
			break
	p.call("step", DT, Vector3.ZERO, false)
	arma.set("cooldown", M16_ARMA_MUTA)
	p.set("hp", 0.0)
	p.set("invuln", 0.0)
	hd.call("step", DT)
	var over := bool(hd.call("is_game_over"))
	var nodi0 := _conta_nodi(root)
	var vivi0 := int(hd.get("count"))
	var colpi0 := int(arma.get("shots"))
	var gestito0 := root.is_input_handled()
	# **Il trasporto vero**: nessuna chiamata diretta a `_unhandled_input`.
	root.push_input(_tasto(tasto, true, false))
	var gestito := root.is_input_handled() and not gestito0
	var hp1 := float(p.get("hp"))
	var vivi1 := int(hd.get("count"))
	var colpi1 := int(arma.get("shots"))
	print("m13-w3 tasto: tasto %d (%s), game_over %s, evento gestito %s, hp 0.0 -> %.1f, nemici %d -> %d, colpi %d -> %d, nodi %d -> %d"
		% [tasto, str(p.call("restart_hint")), str(over), str(gestito), hp1,
			vivi0, vivi1, colpi0, colpi1, nodi0, _conta_nodi(root)])
	if hp1 > 0.0:
		h.near(hp1, float(p.get("max_hp")), 0.0001, "tasto: la pipeline vera rimette in piedi il giocatore")
		h.check(not bool(hd.call("is_game_over")), "tasto: e la partita riparte")
		h.check(vivi1 > 0, "tasto: e i nemici sono ripopolati (%d)" % vivi1)
		h.eq(colpi1, 0, "tasto: e i proiettili sono azzerati")
	elif gestito:
		h.check(false,
			"tasto: la pipeline ha CONSUMATO l'evento e il giocatore e' rimasto a %.1f hp: lo mangia un altro handler" % hp1)
	else:
		print("m13-w3 tasto: push_input non ha consegnato l'evento in questo harness; la decisione si prova a mano")
		p.call("_unhandled_input", _tasto(tasto, true, false))
		h.near(float(p.get("hp")), float(p.get("max_hp")), 0.0001,
			"tasto: la decisione rimette in piedi il giocatore")
	# Il trasporto che ha funzionato, riusato nei tre giri: se il ramo sopra ha
	# ripiegato sulla chiamata diretta, i tre giri devono ripiegare con lei.
	var riavvia: Callable = func() -> void: root.push_input(_tasto(tasto, true, false))
	if hp1 <= 0.0 and not gestito:
		riavvia = func() -> void: p.call("_unhandled_input", _tasto(tasto, true, false))
	# Tre restart di fila: un restart che ne lascia uno in piu' ogni volta si vede
	# solo al secondo e al terzo.
	for giro in TASTO_GIRO:
		p.set("hp", 0.0)
		p.set("invuln", 0.0)
		hd.call("step", DT)
		riavvia.call()
		h.check(float(p.get("hp")) > 0.0, "tasto: il restart %d riparte" % (giro + 1))
	h.eq(_conta_nodi(root), nodi0, "tasto: %d restart in fila non aggiungono nessun nodo" % TASTO_GIRO)
	# ## Qui la scena viene libera **adesso**, e non con `_libera()`
	#
	# `queue_free()` dentro un `--script` si svuota alla fine del frame e tutte le
	# sezioni di questo file girano **in un frame solo**: la scena resterebbe
	# dentro `root` fino in fondo al file, con la sua `Camera` di arena
	# (`scenes/arena_main.tscn`, `src/render/arena_camera.gd`) attiva. E' quello
	# che ha fatto fallire `senza camera il giocatore non vede piu' nessuna
	# camera` in `_m5_ingresso_su_schermo`, che libera la sua camera di prova e si
	# aspetta che **quella** rimanga l'unica. Il criterio e' giusto e la sezione
	# che sporca era questa: quindi si libera qui, e si dice.
	# ## Il conteggio **al passo dopo**, e l'identita' del nodo liberato
	#
	# `free()` **dentro** il proprio `_process()` in Godot **non** rimuove il nodo dalla
	# scena fino alla fine del frame: la riga subito dopo vede ancora il nodo. Quindi il
	# numero va riletto **dopo un passo**, e i due candidati si distinguono cosi':
	# `0` al passo dopo = il free ha funzionato e il difetto e' **il momento** della
	# lettura; `1` anche al passo dopo = o non e' stato liberato, o ne e' stato montato
	# un altro.
	var prima := 0
	for nodo in root.get_children():
		if String(nodo.name) == "ArenaMain":
			prima += 1
	var percorso_prima := str(scena.get_path())
	var valido_prima := is_instance_valid(scena)
	root.remove_child(scena)
	scena.free()
	var subito := 0
	for nodo in root.get_children():
		if String(nodo.name) == "ArenaMain":
			subito += 1
	var rimasti := 0
	var percorso_arena := PackedStringArray()
	for nodo in root.get_children():
		if String(nodo.name) == "ArenaMain":
			rimasti += 1
			percorso_arena.append("%s (camera %s, valid %s)" % [str(nodo.get_path()),
				str(nodo.get_node_or_null("Camera") != null),
				str(is_instance_valid(nodo.get_node_or_null("Camera")))])
	print("tasto: il nodo liberato era `%s` (istanza valida %s). `ArenaMain` sotto root: **prima** del `remove_child` = %d, **subito dopo** il free = %d, e **dopo** = %d (%s). Se `subito` e' %d ma `dopo` e' 0, il free ha funzionato e il difetto e' **il momento** della lettura — `free()` dentro il proprio frame non rimuove il nodo fino alla fine. Se anche `dopo` e' %d, allora o non e' stato liberato o ne e' stato montato un altro"
		% [percorso_prima, str(valido_prima), prima, subito, rimasti,
			", ".join(percorso_arena), subito, rimasti])
	h.check(root.get_camera_3d() == cam_prima,
		"tasto: la scena smontata non lascia la sua camera attiva (prima %s, dopo %s)"
			% [str(cam_prima), str(root.get_camera_3d())])
	# **Poi** il contratto: `_exit_tree` di `-render` e `-ui` puo' togliere una
	# registrazione per nome, e se riregistrassi prima di liberare mi resterebbe
	# tolta sotto gli occhi.
	game.player = player
	game.progression = player.progression
	game.register_impl("player_position", Callable(player, "_player_position"))
	game.register_impl("damage_player", Callable(player, "take_damage"))
	game.register_impl("spawn_projectile", Callable(weapon, "_spawn_projectile"))
	_riordina_orda_finta()

# --- 10-11. m5, criteri n. 2 e n. 3: l'ingresso e' quello che si vede -----------
#
# ## Perche' questa sezione non poteva esistere prima
#
# Fino a m5 il file intero girava con la base **identita'**: nel viewport non
# c'era nessuna camera, quindi `world_direction` prendeva **solo** il suo
# ripiego. Il gioco prende l'altro percorfo, quello della camera. I due non
# concordavano sullo schermo e nessuna asserzione li guardava insieme: il gioco
# aveva W e S invertiti e il test era verde (piano §1.5b).
#
# Qui la camera e' **vera**, costruita come quella di arena, e l'atteso **non** e'
# un letterale: e' la direzione che **quella** camera mostra come alto, calcolata
# dalla sua base. Un `Vector3(0, 0, -1)` scritto qui dentro rifaterebbe il
# difetto di oggi con un altro numero, che e' esattamente la trappola che questo
# test e' nato per evitare.

func _m5_ingresso_su_schermo(h) -> void:
	_riordina_orda_finta()
	_reset(Vector3.ZERO)

	# I vettori d'ingresso vengono dalla **funzione che il gioco usa**, non scritti
	# qui: il difetto di m5 era un **segno**, e un vettore scritto a mano nel test
	# asserisce una convenzione che il gioco non ha per forza.
	var v_w: Vector3 = player.input_vector(false, false, false, true)
	var v_s: Vector3 = player.input_vector(false, false, true, false)
	var v_d: Vector3 = player.input_vector(true, false, false, false)
	var v_a: Vector3 = player.input_vector(false, true, false, false)
	h.check(v_w.length() > 0.0, "il tasto W da solo produce un vettore d'ingresso")
	h.check(v_w.is_equal_approx(-v_s), "W e S sono l'uno il contrario dell'altro")
	h.check(v_d.is_equal_approx(-v_a), "D e A sono l'uno il contrario dell'altro")

	# --- La camera reale ---
	var cam := Camera3D.new()
	cam.name = "CameraDiArena"
	cam.fov = CAM_FOV
	cam.near = CAM_NEAR
	cam.far = CAM_FAR
	root.add_child(cam)
	cam.current = true
	var ancora := Vector3.ZERO
	cam.global_position = ancora + Vector3(0.0, CAM_HEIGHT, CAM_BACK)
	cam.look_at(ancora + Vector3.UP * CAM_LOOK_HEIGHT, Vector3.UP)

	# Senza queste due righe il resto della sezione misurerebbe il ripiego e
	# direbbe "PASS" come prima: e' il difetto di metodo, non un dettaglio.
	if not h.check(cam.is_current(), "la camera di prova e' quella attiva del viewport"):
		return
	if not h.check(player.get_viewport().get_camera_3d() == cam,
		"e il giocatore la vede davvero: senza questo il percorso della camera non viene mai preso"):
		return

	# --- L'atteso, dalla base di QUELLA camera ---
	var alto := _schermo_alto(cam)
	var destra := _schermo_destra(cam)

	var dir_w: Vector3 = player.world_direction(v_w)
	var angolo := rad_to_deg(dir_w.angle_to(alto))
	h.check(angolo <= CAM_ANGLE_TOL,
		"CON CAMERA, W va 'su sullo schermo': %.2f gradi dall'alto di quella camera (tetto %.0f)"
		% [angolo, CAM_ANGLE_TOL])

	# --- Il controllo che NON riusa nessuna formula di `world_direction` ---
	# Andare "su sullo schermo" vuol dire, su una camera che guarda dall'alto,
	# **allontanarsi dalla camera**. I due punti sono a 10 m dal giocatore in
	# direzioni opposte e vince quello lontano. Se la formula di `world_direction`
	# venisse riscritta, questa riga continuerebbe a dire la verita' geometrica.
	var terra_camera := Vector3(cam.global_position.x, 0.0, cam.global_position.z)
	var davanti: float = (dir_w * 10.0).distance_to(terra_camera)
	var dietro: float = (-dir_w * 10.0).distance_to(terra_camera)
	h.check(davanti > dietro,
		"CON CAMERA, camminando con W ci si allontana dalla camera (%.2f m contro %.2f m): W non spinge verso la camera"
		% [davanti, dietro])
	h.check(rad_to_deg(player.world_direction(v_d).angle_to(destra)) <= CAM_ANGLE_TOL,
		"CON CAMERA, D va a destra dello schermo")
	h.check(rad_to_deg(player.world_direction(v_a).angle_to(-destra)) <= CAM_ANGLE_TOL,
		"CON CAMERA, A va a sinistra dello schermo")

	# --- Il ripiego, criterio n. 3 ---
	cam.free()
	var rimasta = player.get_viewport().get_camera_3d()
	if not h.check(rimasta == null, "senza camera il giocatore non vede piu' nessuna camera"):
		return

	var ripiego_w: Vector3 = player.world_direction(v_w)
	h.vec_near(ripiego_w, Vector3(0.0, 0.0, -1.0), 0.0001,
		"SENZA CAMERA, W resta -z")
	h.vec_near(player.world_direction(v_s), -ripiego_w, 0.0001,
		"SENZA CAMERA, S e' il contrario di W")
	# E i due percorsi devono **concordare sullo schermo**: il ripiego non e' un
	# altro "alto", e' l'alto della stessa camera. Senza questa riga il gioco e i
	# test avrebbero due convenzioni diverse, che e' il difetto di m5 nella sua
	# forma piu' semplice.
	h.vec_near(ripiego_w, alto, 0.0001,
		"i due percorsi concordano: il ripiego e' l'alto della stessa camera di arena")

	print("m5 W: alto della camera di arena %s, con camera W %s (%.2f gradi), senza camera W %s"
		% [str(alto), str(dir_w), angolo, str(ripiego_w)])

# --- 12. m5, criterio n. 4: il proiettile e' disegnato dove e' calcolato ---------
#
# ## Perche' il numero si prende sulla trasformazione e non sugli istanti
#
# In headless la MultiMesh **non si rilegge**: `get_instance_transform` su una
# MultiMesh appena scritta non restituisce quello che ci si aspetta, ed e' il
# motivo per cui nessuna porta ha mai guardato qui dentro. Il numero si prende
# quindi sulla **causa**: la trasformazione che il renderer applica a una posizione
# mondo. Se quella e' l'identita', ogni posizione mondo arriva a schermo dove e'
# stata calcolata; se non lo e', il difetto c'e'.
#
# E il giocatore e' **lontano dall'origine**: all'origine `posizione del
# giocatore + posizione mondo` dà `posizione mondo`, ed e' l'unico punto in cui il
# difetto e' invisibile.

func _m5_trasformazione_del_renderer(h) -> void:
	_riordina_orda_finta()
	_reset(LONTANO)

	# Il caso degenere, escluso per costruzione e verificato: se il giocatore
	# fosse all'origine questa sezione passerebbe anche col difetto dentro.
	h.check(player.global_position.length() > 1.0,
		"il giocatore NON e' all'origine: all'origine il difetto non si vede (%.1f m)"
		% player.global_position.length())
	h.check(not player.global_transform.is_equal_approx(Transform3D.IDENTITY),
		"e la sua trasformazione globale non e' l'identita'")

	var visivo = pool.visual_node()
	if not h.check(visivo != null, "il pool deve avere il nodo che disegna i proiettili"):
		return
	h.check(bool(visivo.top_level),
		"il nodo visivo e' top_level: la sua trasformazione non segue il padre")
	var trasf: Transform3D = pool.draw_transform()
	h.check(trasf.is_equal_approx(Transform3D.IDENTITY),
		"la trasformazione che il renderer applica a una posizione mondo e' l'IDENTITA' (origine misurata %s)"
		% str(trasf.origin))

	# I nemici fermi: qui si misura la trasformazione del renderer, non la
	# traiettoria di un proiettile.
	var inseguimento_prima: float = horde.chase_speed
	horde.chase_speed = 0.0
	horde.target = LONTANO
	horde.add(LONTANO + Vector3(0.0, 0.9, -8.0), TOUGH)
	pool.reset()
	weapon.cooldown = 0.0
	var nodi_prima := _conta_nodi(player)
	player.step(DT, Vector3.ZERO)
	horde.step(DT)

	var p = pool.active_at(0)
	if not h.check(p != null, "il colpo e' partito e il proiettile e' in volo"):
		horde.chase_speed = inseguimento_prima
		return
	h.check(p.pos.length() > 10.0,
		"la posizione del proiettile e' una posizione MONDO: %.2f m dall'origine" % p.pos.length())

	var disegnata: Vector3 = pool.draw_position(p.pos)
	h.vec_near(disegnata, p.pos, 0.0001,
		"il proiettile e' disegnato dove e' calcolato, non a giocatore + posizione mondo")
	# Il difetto di prima era esattamente `disegnata = calcolata + giocatore`, e
	# quel numero valeva **zero** quando il giocatore era all'origine.
	h.check(player.global_position.length() > 1.0,
		"la posizione del giocatore e' la grandezza che il difetto aggiungeva (%.1f m)"
		% player.global_position.length())
	# I due numeri da stampare sono **copie**: sotto, sparando ancora, il pool
	# riusa lo stesso record e `p.pos` comincia a descrivere un altro colpo.
	var pos_calcolata: Vector3 = p.pos
	print("m5 proiettili: posizione mondo calcolata %s, posizione che il renderer ne ricava %s, "
		% [str(pos_calcolata), str(disegnata)]
		+ "scarto %.6f m, trasformazione del renderer identica: %s"
		% [pos_calcolata.distance_to(disegnata), str(trasf.is_equal_approx(Transform3D.IDENTITY))])

	# Sparare non deve aggiungere nodi: il numero di nodi del giocatore e' lo
	# stesso prima e dopo un colpo.
	for i in 30:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
	h.eq(_conta_nodi(player), nodi_prima,
		"sparare non aggiunge un nodo sotto il giocatore: %d prima, %d dopo" % [nodi_prima, _conta_nodi(player)])
	h.eq(int(pool.ever_created()), int(pool.capacity()),
		"e nessun proiettile nuovo: i proiettili sono record, non nodi")

	horde.chase_speed = inseguimento_prima

# --- 13. m5, criterio n. 5: nessun nodo in piu' ---------------------------------
#
# ## Perche' qui si conta senza la HUD (2026-10-13, m6)
##
# Il numero di m5 era **tutto** `arena_main.tscn`, 33 nodi, HUD compresa. In m6
# `-ui` ha aggiunto il pannello dei potenziamenti dentro `scenes/hud.tscn` e
# quei nodi sono di un altro foglio: contarli in un test di -gameplay faceva
# fallire qui un lavoro che il criterio n. 5 di m5 non riguarda, e che la
# prossima modifica della HUD avrebbe fatto fallire di nuovo. Il criterio dice
# «il fix del renderer non aggiunge un nodo»: il numero che lo riguarda e' quello
## di **-gameplay**, quindi qui si contano i nodi della scena vera **meno la
## HUD**, e si dichiara che quello e' il tetto.
const NODO_HUD := "Hud"

func _m5_nessun_nodo_in_piu(h) -> void:
	var packed = load(ARENA_SCENE)
	if not h.check(packed is PackedScene, "la scena vera deve esistere e caricare"):
		return
	var scena := (packed as PackedScene).instantiate()
	_monta(scena)

	var hud = scena.get_node_or_null(NODO_HUD)
	if not h.check(hud != null, "la scena vera ha ancora il nodo \"%s\"" % NODO_HUD):
		_libera(scena)
		return
	var nodi_hud := _conta_nodi(hud)
	var nodi := _conta_nodi(scena)
	var senza_hud := nodi - nodi_hud
	# Il fix del renderer e' `top_level`: una **proprieta'**, non un nodo. Se
	# fosse stato scelto lo spostamento del nodo fuori dal giocatore, questo
	# numero cambierebbe e il criterio n. 3 di m1 comincerebbe a regredire.
	h.eq(senza_hud, NODI_SCENA_VERA,
		"la scena vera, senza i %d nodi della HUD di -ui, resta in %d nodi anche col fix"
		% [nodi_hud, NODI_SCENA_VERA])
	# La divisione e' una partizione, non una stima: se qualcuno renominasse il
	# nodo della HUD, il totale e il pezzo escluso non tornerebbero piu' e
	# questa riga lo direbbe invece di lasciare passare un conteggio a caso.
	h.eq(senza_hud + nodi_hud, nodi,
		"i %d nodi contati e i %d della HUD sommano al totale della scena vera (%d)"
		% [senza_hud, nodi_hud, nodi])
	var player_scena = scena.get_node_or_null("Player")
	if h.check(player_scena != null, "la scena vera ha il nodo \"Player\""):
		h.check(_conta_nodi(player_scena) <= NODI_SCENA_VERA,
			"il giocatore da solo (%d nodi) non supera mai il tetto di -gameplay (%d)"
			% [_conta_nodi(player_scena), NODI_SCENA_VERA])
		# ## Il **nono** nodo del giocatore, e perche' lo chiedo per **percorso**
		#
		# `-arena` ha misurato che la mia famiglia ne ha **nove** dove ne aveva
		# **otto**, e ha scritto che **non sa quale sia**: il suo file non puo'
		# guardare il mio. Quindi il numero e' mio, e la domanda che quel numero
		# chiude e' piu' grande del numero: **il `+1` e' nato dalla torre o e' mio?**
		# Perche' se e' mio, allora la voce di `-arena` cresce **per colpa mia** e la
		# base `46` non era «la base di `-arena» ma «la base di tre foglie a una
		# data» — e allora la scomposizione va scritta **con le date dentro**.
		#
		# Per il percorso e non per il nome: il nome puo' essere cambiato senza che
		# il nodo entri o esca, il percorso no.
		var miei := PackedStringArray()
		for c in player_scena.get_children():
			miei.append("%s (%s, %d discendenti)" % [str(c.name), c.get_class(), _conta_nodi(c) - 1])
		print("m5 il giocatore ha %d figli diretti per un totale di %d nodi: [%s]"
			% [player_scena.get_child_count(), _conta_nodi(player_scena), ", ".join(miei)])
	# Niente `_libera` **qui**: questa sezione continua a usare `scena` cinque righe
	# sotto (`scena.get_node_or_null("Player/Weapon/Pool")`). Una liberazione nel
	# mezzo di una sezione e' la stessa classe di difetto di una `queue_free()` in
	# coda, solo piu' vicina: **la scena che si libera mentre qualcuno la sta ancora
	# leggendo** e' `Cannot call method 'get_node_or_null' on a previously freed
	# instance`. La liberazione sta **in fondo**, una sola, ed e' quella sotto.

	# E non basta il totale: il nodo visivo deve essere **lo stesso nodo** di
	# prima, sotto il pool, dentro l'arma, dentro il giocatore.
	var pool_scena = scena.get_node_or_null("Player/Weapon/Pool")
	if h.check(pool_scena != null, "la scena vera ha il pool sotto Player/Weapon"):
		var visivo_scena = pool_scena.visual_node()
		if h.check(visivo_scena != null, "il pool della scena vera ha il suo nodo visivo"):
			h.eq(visivo_scena.get_parent(), pool_scena,
				"il nodo visivo e' ancora figlio del pool: nessun nodo spostato")
			h.eq(_conta_nodi(pool_scena), 2,
				"il pool ha due soli figli: i 100 record e il nodo che li disegna")
			h.check(bool(visivo_scena.top_level),
				"ed e' top_level anche sulla scena vera")
			h.check(pool_scena.draw_transform().is_equal_approx(Transform3D.IDENTITY),
				"la scena vera ha la stessa identita' di trasformazione sul renderer")

	print("m5 nodi: la scena vera conta %d nodi, di cui %d della HUD di -ui e %d di -gameplay "
		% [nodi, nodi_hud, senza_hud]
		+ "(tetto di -gameplay %d); il nodo visivo resta figlio del pool ed e' top_level"
		% NODI_SCENA_VERA)
	# La regola del file: **chi monta un mondo lo libera**, e **in fondo alla sezione**,
	# quando nessuno la sta piu' leggendo. Qui c'era `scena.queue_free()`, che in un
	# `--script` — **un frame solo** — non svuota mai: la scena restava in albero e la
	# sezione successiva la ereditava. Vedi la tabella `M12_SCENE_MONTATE`.
	_libera(scena)

# --- 14-15. m7: la salute smette di essere un'etichetta ------------------------
#
# ## Cosa c'era prima, e cosa c'e' adesso
#
# `take_damage` esisteva dal primo giorno e non aveva **nessun chiamante** in tutto
# `src/`: il giocatore era invulnerabile per costruzione, la barra della salute
# era piatta e il `game_over` era irraggiungibile (piano §1.4a). m7 lo chiude da
# due lati, e sono di due foglie diverse:
#
#   - **-gameplay** (questa sezione): registra `damage_player` sul contratto e
#     rimette in piedi il giocatore al restart. E' il destinatario.
#   - **-orda**: il nemico che chiama `Game.damage_player(x)` dal ciclo di gioco.
#     E' il chiamante, e il criterio n. 1 di m7 è una `grep` su quello.
#
# ## Perche' questa sezione non chiama `damage_player` a mano e basta
#
# Chiamarlo a mano dimostrerebbe che **la macchina** reagisce, non che **il gioco**
# la faccia reagire: sarebbe il difetto di §1.6 ripetuto, e questa sezione non
# può ripeterlo. Quindi qui la sezione **osserva** il giocatore mentre la partita
# gira da sola e conta i colpi che arrivano dal gioco. Se il chiamante di -orda c'è,
# le asserzioni del criterio n. 2 scattano da sole senza che il test tocchi un
# numero; se non c'è ancora, la sezione **lo dice ad alta voce** e asserisce
# comunque tutta la parte che è di -gameplay — che è l'unica che questa foglia
# può chiudere.
#
# E in ogni caso resta un'invariante **con denti in entrambi i mondi**: ogni punto
# di vita perso deve essere stato annunciato dal segnale `hurt`, che `take_damage`
# emette una e una sola volta per colpo ricevuto. Se qualcuno facesse scendere le
# vite per una strada che non è il contratto — scrivendo `player.hp` da un
# nemico, per esempio — quella riga cadrebbe sia oggi che dopo.

func _m7_salute_sulla_scena_vera(h) -> void:
	var packed = load(ARENA_SCENE)
	if not h.check(packed is PackedScene, "m7: la scena vera deve esistere e caricare"):
		return
	var scena := (packed as PackedScene).instantiate()
	_monta(scena)
	var p = scena.get_node_or_null("Player")
	var hd = scena.get_node_or_null(NODO_HORDE)
	if not h.check(p != null, "m7: la scena vera ha il nodo \"Player\""):
		return
	if not h.check(hd != null, "m7: la scena vera ha il nodo \"%s\"" % NODO_HORDE):
		return
	# I due protagonisti si guidano a mano: il ciclo di fisica vero non deve
	# muovere niente mentre il test conta i passi, altrimenti il numero che
	# questa sezione misura non sarebbe il numero che dice di misurare.
	p.drive_manually()
	hd.set_physics_process(false)

	# Il contratto, su questa scena e non su quella delle sezioni precedenti: e'
	# la registrazione che il gioco vero fa, non una che il test rifaccia a mano.
	h.check(game.player == p, "m7: Game.player e' il Player della scena vera")
	h.check(game.horde == hd, "m7: e Game.horde e' il suo nodo orda")
	h.check(game.has_impl("damage_player"),
		"m7: damage_player e' registrato sul contratto dalla scena vera")
	h.check(game.has_impl("player_position"),
		"m7: e la registrazione di player_position non e' stata persa")
	h.check(game.has_impl("spawn_projectile"),
		"m7: e nemmeno quella di spawn_projectile")

	# Il tetto di nodi, con la **stessa regola** della sezione 13 e la stessa
	# costante: scena meno HUD. Non un numero scritto qui dentro.
	var hud_m7 = scena.get_node_or_null("Hud")
	if h.check(hud_m7 != null, "m7: la scena vera ha ancora il nodo \"%s\"" % NODO_HUD):
		h.eq(_conta_nodi(scena) - _conta_nodi(hud_m7), NODI_SCENA_VERA,
			"m7: la scena vera su cui si misura la salute ha gli stessi %d nodi di -gameplay" % NODI_SCENA_VERA)

	# Il raggio d'arrivo letto dal file di **-orda**, non scritto qui dentro.
	var arrivo := _arrivo_radius(h)

	# I tre contatori della sezione, in un dizionario e non in variabili locali:
	# una lambda di GDScript cattura per **valore**, quindi una variabile locale
	# dentro una lambda non cambierebbe mai e il conteggio sarebbe sempre zero.
	var conto := {"danno": 0.0, "colpi": 0, "morti": 0}
	p.hurt.connect(_conta_danno(conto))
	p.died.connect(_conta_morte(conto))

	# =====================================================================
	# 14. m7 criterio n. 2: l'orda raggiunge il giocatore e lo ferisce
	# =====================================================================
	p.restart_run()
	hd.step(DT)
	h.eq(str(hd.run_state()), "playing", "m7: alla partenza la partita e' in corso")
	var hp_avvio: float = p.hp
	h.near(hp_avvio, p.max_hp, 0.0001, "m7: e il giocatore e' in piedi")

	var vicino := 1.0e9
	var primo_contatto := -1
	var passi := 0
	while passi < M7_PASSI and not hd.is_game_over():
		passi += 1
		p.step(DT, Vector3.ZERO)
		hd.step(DT)
		var d := _piu_vicino(hd, p.global_position)
		if d < vicino:
			vicino = d
		if primo_contatto < 0 and d <= arrivo:
			primo_contatto = passi

	h.check(passi > 0, "m7: la partita e' girata (%d passi)" % passi)
	h.check(primo_contatto > 0,
		"m7: l'orda raggiunge il giocatore: primo contatto entro %.2f m al passo %d (%.2f s), minimo %.3f m"
		% [arrivo, primo_contatto, float(primo_contatto) * DT, vicino])
	h.check(vicino <= arrivo,
		"m7: e la distanza minima resta dentro il raggio d'arrivo di -orda (%.3f contro %.3f m)" % [vicino, arrivo])

	# L'invariante con i denti in entrambi i mondi: nessun punto di vita puo'
	# sparire senza che il segnale lo annunci. Oggi vale 0 == 0, e vale anche
	# quando -orda consegna: la differenza fra i due casi e' solo il numero.
	var perso: float = hp_avvio - p.hp
	# ## L'identita' e' **`min(somma, max_hp)`**, e il motivo e' il clamp
	#
	# Il criterio chiedeva `vita persa == somma dei hurt` e diventava rosso con
	# `100,0000` contro `101,7143`. **Non e' un difetto**: `take_damage()` fa
	# `hp = maxf(hp - amount, 0.0)`, quindi l'**ultimo** morso annuncia tutto il suo
	# danno e la vita scende solo di quanto ne resta. La differenza e' **il colpo di
	# coda**, e non puo' superare il danno di un morso.
	#
	# La riga e' diventata piu' forte, non piu' debole: prima accettava che il totale
	# annunciato coincidesse con il perso, il che **esclude** anche il caso in cui un
	# morso viene perso; adesso verifica **due** fatti — l'identita' col clamp e che
	# l'eccesso stia dentro **un solo morso**. Il numero che lo rende necessario e' qui:
	# la finestra antidoppio-conteggio e' derivata da `Game.touch_interval()`
	# (`0,150 s` invece di `0,250 s`), quindi il giocatore accetta **un morso in piu'** e
	# l'ultimo morso della partita **sfora lo zero**. Finche' la finestra era lunga, il
	# colpo di coda non c'era e il criterio passava per caso: era una soglia che non
	# poteva fallire.
	var danno_max_morso := 0.0
	for _v in conto["danni"]:
		danno_max_morso = maxf(danno_max_morso, float(_v))
	h.near(perso, minf(float(conto["danno"]), hp_avvio), 0.0001,
		"m7: vita persa %.4f = `min(danno annunciato %.4f, vita iniziale %.4f)`: nessuna strada diversa dal contratto, e l'eccesso di %.4f sta dentro il colpo di coda"
		% [perso, float(conto["danno"]), hp_avvio, float(conto["danno"]) - perso])
	h.check(float(conto["danno"]) - perso <= danno_max_morso + 0.0001,
		"m7: il danno annunciato supera la vita persa di %.4f e il colpo piu' grosso era %.4f: l'eccesso e' **un solo morso**, non una strada perduta"
		% [float(conto["danno"]) - perso, danno_max_morso])
	h.check(p.hp >= 0.0, "m7: le vite non scendono mai sotto zero (%.4f)" % p.hp)
	h.check(not p.is_dead() or hd.is_game_over(),
		"m7: a zero vite la partita e' finita: mai morti con la partita che continua")

	if int(conto["colpi"]) > 0:
		# IL CRITERIO n. 2, per intero, e senza che il test abbia chiamato
		# `damage_player` una volta sola: i colpi sono arrivati dal gioco.
		h.check(p.hp < hp_avvio,
			"m7 criterio n. 2: sulla scena vera hp e' sceso a %.4f senza che il test chiami damage_player"
			% p.hp)
		var sotto: float = p.hp
		for i in 60:
			if hd.is_game_over():
				break
			p.step(DT, Vector3.ZERO)
			hd.step(DT)
		h.check(p.hp < hp_avvio,
			"m7 criterio n. 2: e resta sotto (era %.4f, ora %.4f, massimo %.4f): nessuna cura nascosta"
			% [sotto, p.hp, hp_avvio])
		print("m7 criterio 2: percorso intero. %d colpi dal codice di gioco, %.1f -> %.4f di %.1f HP, morti %d"
			% [int(conto["colpi"]), hp_avvio, p.hp, float(p.max_hp), int(conto["morti"])])
	else:
		# Non e' un fallimento e non e' un verde di faccia: e' un **ordine di
		# consegna** dichiarato. Il chiamante e' di -orda (`src/sim/`, non questo
		# file) e il criterio n. 1 di m7 e' una `grep`, non un test: questa
		# sezione non puo' chiuderlo e non finge di averlo chiuso.
		print("m7 criterio 1 ANCORA ROSSO: nessun codice di gioco chiama Game.damage_player (%d colpi in %d passi). "
			% [int(conto["colpi"]), passi]
			+ "Il chiamante e' di -orda (src/sim/). Quel che e' di -gameplay e' verificato sotto.")
		# L'invariante **invertito**, e non un `check(true, ...)` decorativo: se il
		# chiamante non c'e', nessuna vita puo' essere sparsa, e questa riga
		# ascolta anche una perdita che passasse per una strada che non sia il
		# contratto. Se tornasse verde perche' non gira niente, il numero
		# accanto lo dice: zero colpi in `passi` passi.
		h.near(perso, 0.0, 0.0001,
			"m7: senza il chiamante la vita non si muove: %.4f persi in %d passi con %d colpi"
			% [perso, passi, int(conto["colpi"])])

	# =====================================================================
	# La macchina: il contratto ferisce davvero, e ha i denti
	# =====================================================================
	# Da qui in avanti il test **chiama** `Game.damage_player`, e quindi quello
	# che segue prova la macchina e non il gioco. E' dichiarato perche' la
	# differenza fra le due cose e' esattamente il criterio n. 1.
	p.restart_run()
	var conto2 := {"danno": 0.0, "colpi": 0, "morti": 0}
	p.hurt.connect(_conta_danno(conto2))
	p.died.connect(_conta_morte(conto2))

	h.check(game.damage_player(25.0), "m7: Game.damage_player(25) entra nel giocatore")
	h.near(p.hp, p.max_hp - 25.0, 0.0001, "m7: e la vita scende di 25")
	h.near(float(conto2["danno"]), 25.0, 0.0001,
		"m7: il conto torna: il danno ricevuto e' quello che il contratto ha consegnato")
	h.eq(int(conto2["colpi"]), 1, "m7: e `hurt` e' stato emesso una volta sola per un colpo")

	h.check(not game.damage_player(25.0),
		"m7: il colpo subito dopo non entra, l'invulnerabilita' tiene")
	h.near(p.hp, p.max_hp - 25.0, 0.0001, "m7: e le vite non scendono due volte")
	h.check(not game.damage_player(0.0), "m7: un danno di zero non entra")
	h.check(not game.damage_player(-5.0), "m7: un danno negativo non entra")
	h.near(p.hp, p.max_hp - 25.0, 0.0001, "m7: e nessuno dei due ha toccato le vite")

	# La morte, e il numero che dice che e' una **transizione**: `died` una volta
	# sola anche se l'orda continua a colpire un giocatore fermo a zero.
	var colpi_morte := 0
	while not p.is_dead() and colpi_morte < 200:
		p.invuln = 0.0
		p.dash_timer = 0.0
		game.damage_player(25.0)
		colpi_morte += 1
	h.check(p.is_dead(),
		"m7: le vite arrivano a zero e il giocatore muore (%d colpi dopo il primo)" % colpi_morte)
	h.near(p.hp, 0.0, 0.0001, "m7: e a zero esatto, non negativo")
	h.eq(int(conto2["morti"]), 1, "m7: `died` e' scattata una volta sola")
	p.invuln = 0.0
	game.damage_player(25.0)
	h.eq(int(conto2["morti"]), 1,
		"m7: un colpo dopo la morte NON riannuncia la morte: la morte e' una transizione")
	h.check(p.is_dead(), "m7: e il giocatore resta morto")

	# Lo stato della partita, che e' di -orda ma si legge dal contratto: e' il
	# pezzo che rende il game_over **verificabile** invece che dichiarato.
	h.eq(str(hd.run_state()), "playing",
		"m7: a zero vite lo stato non cambia da solo: lo cambia il passo di simulazione")
	hd.step(DT)
	h.eq(str(hd.run_state()), "game_over",
		"m7: al passo successivo lo stato e' game_over")
	h.check(hd.is_game_over(), "m7: e is_game_over() dice la stessa cosa")

	# =====================================================================
	# 15. m7 criterio n. 3: morire non corrompe la partita
	# =====================================================================
	# Il numero che decide non e' `hp == max_hp`: e' **un passo di simulazione
	# dopo il restart**. Un restart che rimettesse in piedi il giocatore ma
	# lasciasse la partita ferma sarebbe verde su tutti i campi e nero sul
	# gioco, che e' il difetto che questa sezione e' nata per prendere.
	for giro in 3:
		_ammazza_dal_contratto(p, game)
		h.check(p.is_dead(), "m7 restart %d: prima del restart il giocatore e' a zero vite" % (giro + 1))
		hd.step(DT)
		h.check(hd.is_game_over(),
			"m7 restart %d: e la partita e' davvero finita, non solo il giocatore" % (giro + 1))

		var nodi_prima := _conta_nodi(root)
		var orde_prima := _conta_nomi(root, NODO_HORDE)
		var morti_prima := int(conto2["morti"])

		p.restart_run()

		h.near(p.hp, p.max_hp, 0.0001,
			"m7 restart %d: le vite tornano a max_hp = %s" % [giro + 1, p.max_hp])
		h.positive(p.hp, "m7 restart %d: e il giocatore ha vite da giocare" % (giro + 1))
		h.check(not p.is_dead(), "m7 restart %d: il giocatore e' di nuovo in piedi" % (giro + 1))
		h.near(float(p.invuln), 0.0, 0.0001,
			"m7 restart %d: e non nasce gia' invulnerabile" % (giro + 1))
		h.eq(int(hd.wave), 1, "m7 restart %d: si torna all'onda 1" % (giro + 1))
		h.check(int(hd.count) > 0,
			"m7 restart %d: horde.count azzerato e RIPOPOLATO (%d)" % [giro + 1, hd.count])
		h.eq(_conta_nodi(root), nodi_prima,
			"m7 restart %d: nessun nodo creato ne' liberato (%d)" % [giro + 1, nodi_prima])
		h.eq(_conta_nomi(root, NODO_HORDE), orde_prima,
			"m7 restart %d: una sola orda sotto root, non due" % (giro + 1))
		h.check(game.player == p and game.horde == hd,
			"m7 restart %d: e il contratto punta ancora agli stessi due nodi" % (giro + 1))

		# ## IL NUMERO CHE DECIDE
		hd.step(DT)
		h.check(not hd.is_game_over(),
			"m7 restart %d: dopo il restart un passo di simulazione NON rilegge game_over (stato '%s')"
			% [giro + 1, str(hd.run_state())])
		h.eq(str(hd.run_state()), "playing", "m7 restart %d: la partita riparte sul serio" % (giro + 1))
		var ferma: PackedVector3Array = hd.transforms.duplicate()
		hd.step(DT)
		h.check(hd.transforms != ferma,
			"m7 restart %d: e il mondo si muove di nuovo: non era fermo per sempre" % (giro + 1))

		# E il giocatore può **morire di nuovo**: il flag che fa scattare `died`
		# una volta sola per vita è stato azzerato dal restart. Senza questa riga
		# il restart riporterebbe in piedi un giocatore immune alla morte, che è
		# il difetto opposto a quello che m7 chiude.
		_ammazza_dal_contratto(p, game)
		h.check(p.is_dead(),
			"m7 restart %d: dopo il restart il giocatore puo' morire di nuovo" % (giro + 1))
		h.eq(int(conto2["morti"]), morti_prima + 1,
			"m7 restart %d: e `died` e' scattata un'altra volta, non una seconda volta per la stessa morte"
			% (giro + 1))

	print("m7: contatto al passo %d (%.2f s), minimo %.3f m contro %.3f di raggio d'arrivo; "
		% [primo_contatto, float(primo_contatto) * DT, vicino, arrivo]
		+ "danno dal contratto %.4f su %.1f HP; 3 restart con hp a max_hp e nessun nodo duplicato"
		% [float(conto["danno"]) + float(conto2["danno"]), float(p.max_hp)])
	scena.queue_free()

## Uccide il giocatore **dal contratto**, che è la strada che usa il nemico di
## -orda, e non scrivendo `hp` a mano: un test che scrivesse il campo misurerebbe
## una partita che nessun codice di gioco produce. L'invulnerabilita' si azzera a
## ogni colpo, altrimenti si misurerebbero i secondi di recupero invece dei punti
## vita — la stessa cosa che `tests/test_upgrades.gd::_vita` dichiara.
func _ammazza_dal_contratto(p, game) -> void:
	var guard := 0
	while not p.is_dead() and guard < 400:
		p.invuln = 0.0
		p.dash_timer = 0.0
		if not game.damage_player(25.0):
			return
		guard += 1

## I due ascoltatori della sezione m7. Sono **funzioni che restituiscono una
## `Callable`** e non due lambda scritte a mano sul posto, perche' una lambda
## inline che tocca una variabile locale cattura **per valore**: `conto` qui
## dentro cambierebbe una copia e il conteggio resterebbe a zero per sempre, e un
## contatore fermo a zero e' indistinguibile da un contatore che non e' mai stato
## collegato. Il dizionario e' il contenitore giusto perche' e' un riferimento.
func _conta_danno(conto: Dictionary) -> Callable:
	return func(amount: float, _hp_left: float) -> void: _segna_danno(conto, amount)

func _conta_morte(conto: Dictionary) -> Callable:
	return func() -> void: _bump(conto, "morti")

static func _segna_danno(conto: Dictionary, amount: float) -> void:
	conto["danno"] = float(conto["danno"]) + amount
	conto["colpi"] = int(conto["colpi"]) + 1
	# La lista dei singoli danni: serve al **colpo di coda**, cioe' all'eccesso che
	# `hurt` annuncia e che la vita non perde perche' `hp` e' clampato a zero. Senza
	# la lista l'eccesso si può solo dire «e' diverso da zero», che non esclude
	# niente; con la lista si confronta con **un morso** e il confronto ha un numero.
	if not conto.has("danni"):
		conto["danni"] = PackedFloat32Array()
	conto["danni"] = (conto["danni"] as PackedFloat32Array).duplicate()
	conto["danni"].append(amount)

static func _bump(conto: Dictionary, chiave: String) -> void:
	conto[chiave] = int(conto[chiave]) + 1

## La distanza minima fra un nemico e il giocatore, sul piano. `1.0e9` quando
## l'orda e' vuota: «nessun nemico» e «un nemico lontanissimo» sono due fatti
## diversi, e metterli nello stesso numero fa sembrare pieno un campo vuoto.
func _piu_vicino(hd, punto: Vector3) -> float:
	var transforms: PackedVector3Array = hd.transforms
	var meglio := 1.0e9
	for i in transforms.size():
		var d := transforms[i] - punto
		d.y = 0.0
		var l := d.length()
		if l < meglio:
			meglio = l
	return meglio

## `Enemy.ARRIVE_RADIUS`, letto dal file di **-orda**. Non e' una costante di questo
## test perche' quel file non e' mio: copiare il numero qui dentro sarebbe la
## seconda copia di una regolazione altrui, che e' il difetto che il piano vieta
## (criterio n. 6 di m7). Se la costante non si legge, il numero torna a 0 e
## l'asserzione che lo usa cade: una soglia che sparisce silenziosamente sarebbe
## un test che non puo' fallire.
func _arrivo_radius(h) -> float:
	var scr = load(ENEMY_SCRIPT)
	if not h.check(scr is Script, "m7: src/sim/enemy.gd deve caricare a runtime"):
		return 0.0
	var consts: Variant = (scr as Script).get_script_constant_map()
	if not h.check(consts is Dictionary and (consts as Dictionary).has("ARRIVE_RADIUS"),
		"m7: Enemy.ARRIVE_RADIUS deve esistere: e' il numero con cui l'orda si dichiara arrivata"):
		return 0.0
	var v := float((consts as Dictionary)["ARRIVE_RADIUS"])
	h.check(v > 0.0, "m7: il raggio d'arrivo letto da -orda e' positivo (%.3f m)" % v)
	return v

# --- 17. m10, criterio n. 6: il giocatore e' solido, i proiettili passano -------
#
# ## Perche' sono tre sezioni e non una
#
# Il criterio e' **uno solo** e ha **due meta'**, e il perno e' il perche': se
# una meta' cade e l'altra no, l'ostacolo esiste a meta' e il gioco ha una regola
# che nessuno ha scritto. Un progetto con un muro che blocca chi lo usa e non chi
# lo combatte e' un progetto con un muro che e' a meta'. Quindi le due meta' si
# provano **per conto separato** e si provano i denti **per conto separato**:
#
#   - senza il clamp del giocatore, `_m10_giocatore_solido` deve dire `FAIL`;
#   - con un proiettile che si ferma all'ostacolo, `_m10_proiettili_passano`
#     deve dire `FAIL` **anche se il giocatore e' solido**.
#
# La terza sezione, `_m10_ostacoli_del_contratto`, e' la catena di consegna
# dichiarata in piano §3.11: `-arena` costruisce gli ostacoli e li registra,
# `-orda` costruisce il campo che li aggira, `-gameplay` ci scontra. Il punto 5
# della semantica del contratto dice che un insieme vuoto e' un errore e non un
# mondo senza muri: senza quella sezione, due sezioni che girano su un disco
# installato a mano passerebbero **tutti** i criteri di m10 con la piramide non
# montata, che e' esattamente il difetto che quel punto 5 esiste per chiudere.
#
# ## I DENTI, eseguiti il 2026-10-13, con i numeri
#
# Un criterio che non e' mai stato fatto fallire non e' un criterio. I due
# denti sono stati eseguiti togliendo per qualche minuto la riga che il
# criterio riguarda e poi rimettendola, e qui sotto c'e' quello che e' uscito.
# Il numero che conta e' quello **minimo** raggiunto dal centro del disco, perche'
# e' quello che distingue «ha sfiorato il muro» da «lo ha attraversato».
#
# **Dente 1 — senza il clamp del giocatore** (`_clamp_to_obstacles()` non
# chiamata da `_move`): **6 asserzioni FAIL**, tutte di meta' 1.
#
#   - distanza **minima** dal centro del disco in 300 frame: **0,0000 m** contro
#     un raggio di **2,00 m**, cioe' il giocatore e' passato dal centro esatto
#     del disco e ne e' uscito dall'altra parte;
#   - fermata finale a **20,650 m** dal centro invece dei **2,600 m** attesi
#     (raggio 2,00 + margine 0,60): e' passato oltre il disco di 18 m e si e'
#     fermato sul muro dell'arena, che a 34,65 m dal centro del disco e' a 46 m
#     dall'origine. **Cronicizzato, non riportato**: 46 m e' il raggio che c'era
	#     il 2026-10-13, quando la misura e' stata presa; da allora il raggio e'
	#     60 m (`RAGGIO_ARENA`) e la stessa prova darebbe un numero diverso. Le
	#     cifre restano quelle che uscirono dal difetto e non sono state
	#     ricalcolate, perche' ricalcolarle avrebbe significato inventare una
	#     misura che nessuno ha preso: il dente resta un **record** di cosa e'
	#     successo, non un atteso di oggi;
#   - spinto dentro il disco, rimesso fuori a **1,0068 m** invece dei 2,600: cioe'
#     **dentro**, che e' il caso che il ripiego sul centro esatto doveva
#     risolvere e che senza clamp non risolve nessuno.
#
# Meta' 2 in quel run: **PASS** (proiettile a 0,133 m dal centro, 1 colpo). Il
# che e' la prima cosa che il criterio n. 6 chiede di vedere: le due meta'
# cadono **per conto separato**.
#
# **Dente 2 — con un proiettile che si ferma all'ostacolo** (il comportamento di
# m11, inserito per qualche minuto in `projectile_pool.step()`): **5 asserzioni
# FAIL**, tutte di meta' 2, **a giocatore solido**.
#
#   - distanza **minima** raggiunta dal centro del disco: **2,300 m** contro un
#     raggio di **2,00 m**, cioe' il proiettile si e' fermato **0,300 m fuori**
#     dal disco e non ci e' mai entrato (la versione buona arriva a 0,133 m,
#     cioe' 1,87 m dentro);
#   - colpi sul nemico **dietro** il disco: **0** invece di **1**.
#
# Meta' 1 in quel run: **PASS** (fermata a 2,600 m, minimo 2,600 m su 300
# frame). Quindi nessuna delle due meta' regge da sola: senza il clamp il muro
# non esiste per il giocatore e i proiettili passano; con il muro ai
# proiettili il muro esiste per il nemico e il gioco si vince stando fermi
# dietro — la combinazione degenerata che il vertice ha escluso e che questa
# sezione rende visibile invece che dichiarata.

## Il contratto espone `obstacles`? Lo chiede alla lista delle proprieta' e non
## a `get()`: `get()` su un nome assente restituisce `null`, che e' la stessa
## cosa che un campo dichiarato e non registrato, e le due cose sono distinte.
## Sono distinte perche' la prima e' un buco del contratto (il vertice) e la
## seconda un buco di `-arena`, e chi legge il FAIL deve sapere quale delle due
## e'.
func _il_contratto_ha_obstacoli() -> bool:
	for p in game.get_property_list():
		if str((p as Dictionary).get("name", "")) == "obstacles":
			return true
	return false

## Installa un insieme di ostacoli **sul contratto** e fa rileggere il giocatore.
## Restituisce `false` quando il campo non esiste: in quel caso il test lavora
## sulla copia del giocatore, che e' la stessa che il contratto riempirrebbe, e
## `_m10_ostacoli_del_contratto` dice a voce alta che il campo manca.
func _installa_ostacoli(obs: PackedVector3Array) -> bool:
	if not _il_contratto_ha_obstacoli():
		player.obstacles = obs
		return false
	game.set("obstacles", obs)
	player.reload_obstacles()
	return true

## Rimette gli ostacoli com'erano prima della sezione che li aveva installati, sul
## contratto **e** sulla copia del giocatore. Sono due copie e vanno rimesse
## entrambe: rimetterne una lascia il mondo con un disco che nessuno ha costruito.
func _ripristina_ostacoli(originali: Variant, del_giocatore: PackedVector3Array) -> void:
	if _il_contratto_ha_obstacoli() and (originali is PackedVector3Array):
		game.set("obstacles", originali)
	player.obstacles = del_giocatore

## Distanza sul piano fra due punti, `y` ignorata: l'arena e' piatta e il disco
## e' un disco.
func _distanza_piano(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _m10_giocatore_solido(h) -> void:
	_riordina_orda_finta()
	_reset(Vector3.ZERO)
	# `Variant` esplicito e non `:=`: `_script_const` restituisce `Variant`, e
	# questo progetto tratta come errore il `:=` su un Variant (project.godot).
	# Il controllo `!= null` sotto e' quello che dice se la costante c'e'.
	var margine: Variant = _script_const(player, "OBSTACLE_MARGIN")
	if not h.check(margine != null,
		"src/player/player.gd deve dichiarare OBSTACLE_MARGIN: e' il numero che tiene il giocatore fuori dal disco"):
		return
	var pelle := float(margine)
	h.check(pelle > 0.0, "il margine dell'ostacolo e' positivo: %.3f m" % pelle)
	var atteso := OST_RAGGIO + pelle
	var disco := PackedVector3Array([OST_CENTRO])
	# Quello che c'era **prima**: vedi `_ripristina_ostacoli`.
	var ostacoli_originali: Variant = game.get("obstacles")
	var ostacoli_del_giocatore: PackedVector3Array = player.obstacles
	var per_contratto := _installa_ostacoli(disco)
	# Il numero che chiude il giro: il giocatore ha **letto** quello che gli e'
	# stato dato. Senza questa riga un giocatore che ignora gli ostacoli passerebbe
	# tutto quello che segue, perche' un clamp che non si muove e un clamp che
	# non c'e' fanno la stessa parte.
	h.eq(int(player.obstacle_count()), 1,
		"il giocatore ha letto 1 ostacolo %s (raggio %.2f m in y, centro su x=%.1f z=%.1f: la convenzione del contratto)"
		% ["dal contratto" if per_contratto else "dai campi del giocatore, perche' Game.obstacles non esiste",
			OST_CENTRO.y, OST_CENTRO.x, OST_CENTRO.z])
	var nodi_prima := _conta_nodi(player)

	# --- 17a. Dritto contro il disco: si ferma PRIMA del bordo -----------------
	#
	# Input `(0, 0, 1)` e non `(0, 0, -1)`: senza camera la base e' l'identita' e
	# `world_direction` e' una **riflessione** di `z` (sezione 11), quindi il
	# verso si prende dalla sezione 11 e non da un vettore riscritto qui.
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	var dentro := false
	var minima := 1.0e9
	for i in M10_PASSI:
		player.step(DT, Vector3(0.0, 0.0, 1.0))
		var d := _distanza_piano(player.position, Vector3(OST_CENTRO.x, 0.0, OST_CENTRO.z))
		minima = minf(minima, d)
		if d < OST_RAGGIO:
			dentro = true
	h.check(not dentro,
		"m10 meta' 1: il giocatore non entra MAI dentro il disco: distanza minima dal centro %.4f m contro un raggio di %.2f m"
		% [minima, OST_RAGGIO])
	var fermo := _distanza_piano(player.position, Vector3(OST_CENTRO.x, 0.0, OST_CENTRO.z))
	h.near(fermo, atteso, 0.05,
		"m10 meta' 1: e si ferma a un margine esatto dal bordo, %.3f contro %.3f m (raggio %.2f + margine %.2f)"
		% [fermo, atteso, OST_RAGGIO, pelle])
	# E non si ferma «prima di tutto»: un clamp che fermasse il giocatore a meta'
	# strada passerebbe la riga di sopra e renderebbe l'ostacolo una colla.
	h.check(fermo <= atteso + 0.05 and fermo >= atteso - 0.5,
		"m10 meta' 1: si ferma sul bordo e non molto prima (%.3f m, finestra %.3f-%.3f)"
		% [fermo, atteso - 0.5, atteso + 0.05])
	h.check(minima <= atteso + 0.05,
		"m10 meta' 1: e durante i %d frame non e' mai andato oltre la fermata (minimo %.3f m)"
		% [M10_PASSI, minima])

	# --- 17b. Di fianco al disco: scivola, non si incastra ---------------------
	#
	# Il trattamento e' quello del muro dell'arena: si toglie la componente
	# **uscente** e si lascia scivolare quella parallela. Senza questo, il
	# giocatore che arriva di fianco si ferma di botto e l'ostacolo diventa un
	# muro — che e' proprio la parola che m10 non vuole.
	#
	# Si parte **dentro** il disco di proposito: e' il caso che nessun gioco
	# dovrebbe produrre e che il clamp deve sapere risolvere lo stesso (spawn,
	# restart, un disco che compare sotto i piedi). Senza il ripiego sul centro
	# esatto la divisione per zero fa NaN e la posizione muore in silenzio.
	#
	# La spinta e' **tangenziale** (il giocatore e' a est del centro e corre verso
	# nord), quindi e' il caso che distingue «un ostacolo» da «un muro in cui ti
	# incatti»: di testa si resta fermi, di fianco si scivola.
	_reset(Vector3(1.0, 0.0, -14.0))
	player.velocity = Vector3(0.0, 0.0, -7.0)
	player.step(DT, Vector3(0.0, 0.0, 1.0))
	h.near(_distanza_piano(player.position, Vector3(OST_CENTRO.x, 0.0, OST_CENTRO.z)), atteso, 0.0005,
		"m10 meta' 1: spinto dentro il disco, viene rimesso fuori esattamente sul margine (%.4f contro %.3f m)"
		% [_distanza_piano(player.position, Vector3(OST_CENTRO.x, 0.0, OST_CENTRO.z)), atteso])
	h.check(player.velocity.z < -6.5,
		"m10 meta' 1: e la velocita' tangenziale sopravvive (%.3f m/s su -7.0): si toglie solo la componente uscente, l'ostacolo non e' colla"
		% player.velocity.z)
	var dentro_ora := _distanza_piano(player.position, Vector3(OST_CENTRO.x, 0.0, OST_CENTRO.z)) < OST_RAGGIO
	h.check(not dentro_ora, "m10 meta' 1: e il punto di partenza era dentro il disco, altrimenti questa prova non prova niente")

	var fuori := true
	for i in 240:
		player.step(DT, Vector3(0.0, 0.0, 1.0))
		if _distanza_piano(player.position, Vector3(OST_CENTRO.x, 0.0, OST_CENTRO.z)) < OST_RAGGIO:
			fuori = false
	h.check(fuori, "m10 meta' 1: e per tutto il percorso resta fuori dal disco")
	h.check(player.position.z < -14.0 - atteso,
		"m10 meta' 1: e ci scivola intorno invece di incastrarsi: arriva a z=%.2f, oltre il disco (%.2f m)"
		% [player.position.z, -14.0 - atteso])

	# Nessun nodo: un ostacolo e' un **dato**, e questo e' il mio tetto. Gli
	# ostacoli di `-arena` non possono diventare nodi miei, quindi nessuno dei due
	# numeri qui sotto si muove perche' esiste un muro.
	h.eq(_conta_nodi(player), nodi_prima,
		"m10 meta' 1: nessun nodo aggiunto per gli ostacoli (%d prima, %d dopo): sono dati, e il tetto di -gameplay resta %d"
		% [nodi_prima, _conta_nodi(player), NODI_SCENA_VERA])

	_ripristina_ostacoli(ostacoli_originali, ostacoli_del_giocatore)
	h.eq(int(player.obstacle_count()), ostacoli_del_giocatore.size(),
		"m10 meta' 1: e rimessi gli ostacoli come erano (%d), il mondo per le sezioni dopo e' quello di prima"
		% ostacoli_del_giocatore.size())

	print("m10 meta' 1: il giocatore si e' fermato a %.3f m dal centro (raggio %.2f + margine %.2f), minimo %.3f m su %d frame, e di fianco ci ha scivolato intorno"
		% [fermo, OST_RAGGIO, pelle, minima, M10_PASSI])

func _m10_proiettili_passano(h) -> void:
	_riordina_orda_finta()
	_reset(Vector3.ZERO)
	# Quello che c'era **prima**: il disco di prova non deve restare nel mondo
	# dopo la sezione, altrimenti le sezioni che vengono (che giocano una partita
	# vera) avrebbero un ostacolo che non esiste e nessuno se ne accorgerebbe.
	var ostacoli_originali: Variant = game.get("obstacles")
	var ostacoli_del_giocatore: PackedVector3Array = player.obstacles
	var disco := PackedVector3Array([OST_CENTRO])
	_installa_ostacoli(disco)
	h.eq(int(player.obstacle_count()), 1,
		"m10 meta' 2: il proiettile viene sparato con lo stesso disco che ferma il giocatore")

	# La dichiarazione esplicita, letta dal file che calcola il contatto. Non e'
	# la prova: e' la prova che il file **dichiara** la sua meta' del criterio, e
	# senza questa riga la meta' 2 sarebbe una proprieta' non scritta da nessuna
	# parte, cioe' un dettaglio che la prossima foglia puo' cancellare.
	var dichiarato = _script_const(pool, "OBSTACLES_BLOCK_PROJECTILES")
	h.check(dichiarato is bool and dichiarato == false,
		"m10 meta' 2: il pool dichiara OBSTACLES_BLOCK_PROJECTILES = false (%s letto): l'ostacolo non ferma un proiettile, ed e' scritto"
		% str(dichiarato))

	# ## Lo stesso disco e' solido: il criterio e' uno solo
	#
	# Non basta che la sezione di prima abbia fermato il giocatore: la meta' 2
	# spara **attraverso** quel disco, quindi se fosse un disco diverso (o se il
	# clamp valesse solo per l'altro) il progetto avrebbe due muri con due
	# regole diverse. Qui il giocatore viene spinto contro **lo stesso** disco e
	# si vede che non lo attraversa.
	_reset(Vector3.ZERO)
	player.velocity = Vector3.ZERO
	for i in M10_PASSI:
		player.step(DT, Vector3(0.0, 0.0, 1.0))
	h.check(not dentro_ostacolo(player.position, disco),
		"m10 meta' 2: il disco che il proiettile attraversa e' lo stesso che ferma il giocatore: a %.3f m dal centro, dentro un raggio di %.2f m non c'e' mai entrato"
		% [_distanza_piano(player.position, Vector3(OST_CENTRO.x, 0.0, OST_CENTRO.z)), OST_RAGGIO])
	_reset(Vector3.ZERO)

	# La geometria **prima** di sparare: se il segmento canna -> nemico non
	# attraversa il disco, il colpo passa per fortuna e la sezione direbbe PASS
	# senza che nessun proiettile abbia mai incontrato un muro. Il controllo e'
	# dichiarato, quindi il difetto si vede come difetto e non come un colpo perso.
	var muzzle: Vector3 = weapon.muzzle_position()
	var al_nemico: Vector3 = NEMICO_DIETRO - muzzle
	var t := _distanza_punto_segmento(Vector3(OST_CENTRO.x, 0.0, OST_CENTRO.z), muzzle, NEMICO_DIETRO)
	h.check(t < OST_RAGGIO,
		"m10 meta' 2: la traiettoria passa entro il disco, a %.3f m dal suo centro contro un raggio di %.2f m (lunghezza %.1f m)"
		% [t, OST_RAGGIO, al_nemico.length()])
	h.check(t < OST_RAGGIO - 0.5,
		"m10 meta' 2: e passa in mezzo, non sfiora il bordo (%.3f m)" % t)

	# --- 17c. Il colpo attraversa il disco e colpisce il nemico dietro ---------
	#
	# Nemico fermo (`chase_speed = 0`) e un colpo solo in volo (`fire_interval`
	# altissimo): qui si guarda **quel** proiettile, non la cadenza dell'arma, e il
	# nemico resta dietro il disco per tutta la misura.
	var inseguimento := horde.chase_speed
	var fire_before: float = weapon.fire_interval
	horde.chase_speed = 0.0
	horde.target = Vector3.ZERO
	weapon.fire_interval = 10.0
	weapon.cooldown = 0.0
	pool.reset()
	horde.add(NEMICO_DIETRO, TOUGH)

	var minima_missile := 1.0e9
	var passato_dentro := false
	var nemico_al_colpo := -1.0
	for i in 120:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
		# Il colpo prima del proiettile: nell'istante in cui il nemico e' stato
		# colpito il proiettile e' gia' sparito dal pool (`pierce = 0`), quindi
		# chiedere prima il record darebbe `null` e si perderebbe proprio il
		# frame che conta.
		if horde.damage_calls > 0:
			nemico_al_colpo = _distanza_piano(horde.pos_of(0), Vector3(OST_CENTRO.x, 0.0, OST_CENTRO.z))
			break
		var p = pool.active_at(0)
		if p == null:
			continue
		var d := _distanza_piano(p.pos, Vector3(OST_CENTRO.x, 0.0, OST_CENTRO.z))
		minima_missile = minf(minima_missile, d)
		if d < OST_RAGGIO:
			passato_dentro = true

	# Il numero che dice che non e' passato per fortuna: il proiettile e' stato
	# **dentro** il disco, e lo ha colpito il nemico che sta dietro. Le due
	# righe insieme sono la meta' 2; ognuna da sola direbbe poco.
	h.check(passato_dentro,
		"m10 meta' 2: il proiettile e' entrato nel disco, fino a %.3f m dal centro (bordo a %.2f m): ha proprio attraversato il muro"
		% [minima_missile, OST_RAGGIO])
	h.check(minima_missile <= OST_RAGGIO - OST_ENTRO_DENTRO,
		"m10 meta' 2: e non solo sfiorarlo: %.3f m dal centro, cioe' almeno %.2f m dentro il disco"
		% [minima_missile, OST_RAGGIO - minima_missile])
	h.eq(horde.damage_calls, 1,
		"m10 meta' 2: e il nemico DIETRO il disco e' stato colpito una volta sola")
	h.eq(horde.hits_of(0), 1, "m10 meta' 2: un solo colpo su quel nemico")
	h.check(nemico_al_colpo > OST_RAGGIO,
		"m10 meta' 2: e al momento del colpo era ancora dietro il disco, a %.2f m dal centro (raggio %.2f): nessuno ha spostato il bersaglio"
		% [nemico_al_colpo, OST_RAGGIO])
	h.eq(horde.out_of_range, 0, "m10 meta' 2: nessun indice fuori dall'orda")

	horde.chase_speed = inseguimento
	weapon.fire_interval = fire_before
	# Ripulisci l'ostacolo di prova: le sezioni che vengono dopo devono trovare
	# il mondo com'era. E' la stessa regola che vale per la regolazione dell'arma:
	# un test che lascia sporco fa fallire in modo falso chi viene dopo.
	_ripristina_ostacoli(ostacoli_originali, ostacoli_del_giocatore)
	print("m10 meta' 2: il proiettile ha attraversato il disco fino a %.3f m dal centro (raggio %.2f) e ha colpito il nemico a %.1f m dal centro del disco: %d hit"
		% [minima_missile, OST_RAGGIO, nemico_al_colpo, horde.hits_of(0)])

# --- 18. m14-a: l'involucro del proiettile e' quello del morso --------------------
#
# ## Il difetto che questa sezione chiude, in numeri
#
# `src/weapons/projectile_pool.gd` aveva `const ENEMY_RADIUS := 0.55`: **un solo
# raggio per tutte e cinque le specie**. Ma i corpi che il giocatore vede sono
# `SIZE_FACTOR * RADIUS[k]` e `SIZE_FACTOR` era `3.4` dal 2026-10-14, quindi:
#
#   specie   RADIUS   disegnato   il proiettile lo prendeva entro
#   runner    0,45      1,53 m        0,55 m
#   grunt     0,60      2,04 m        0,55 m
#   brute     1,00      3,40 m        0,55 m
#   mortar    1,40      4,76 m        0,55 m
#   boss      1,90      6,46 m        0,55 m
#
# Il numero era rimasto indietro di `SIZE_FACTOR`: il commento sopra la riga lo
# ammetteva («se l'orda lo espone, si legge da li' e basta cambiare questa
# riga») e l'orda **non** lo esponeva, quindi nessuno lo aveva cambiato. Fino al
# mortar non si notava — il runner ti arriva addosso e un raggio piccolo si vede
# lo stesso — ma il mortar e' il primo nemico che devi uccidere **mentre ti
# spara da 10,42 m**, e lo vedi largo 4,76 m: un proiettile che deve centrare
# 0,55 m dentro un corpo da 4,76 m e' un colpo invisibile. E' la meta' della
# segnalazione dell'utente, «alcuni nemici non riescono a farmi danno», quella
# che non era il morso (chiusa da m11-quarta).
#
# ## La regola, che e' di m11-quarta e non di questa sezione
#
#     morse_entro(k) = Game.enemy_body_scale * Enemy.RADIUS[k] + TOUCH_REACH
#
# e quindi l'involucro del proiettile e' lo **stesso** involucro, letto dallo
# **stesso** canale:
#
#     contatto_proiettile(k) = Game.enemy_body_scale * Enemy.RADIUS[k]
#
# Il `TOUCH_REACH` **non** c'e': quegli 0,45 m sono il corpo del **giocatore**,
# cioe' lo sconto che il morso ha per arrivare addosso a te. Copiarli qui
# significherebbe colpire mezzo metro oltre il bordo che si vede.
#
# ## Perche' i tre criteri sono tre e non uno
#
#   1. **la banda e' zero**, su cinque specie: e' il criterio che chiude il
#      bug, perche' mette nello stesso fatto due numeri che oggi sono discordi;
#   2. **mai piu' grande del corpo disegnato**: il vincolo forte e' a un senso
#      solo. Se tornasse minore la riga lo segnalerebbe, perche' un involucro
#      piu' piccolo e' un'altra banda, e la banda che m11-quarta ha chiuso a zero
#      si riaprirebbe dall'altra parte;
#   3. **i denti**: il contratto viene avvelenato a `SCALA_AVVELENATA` e si
#      guarda che **entrambi** gli involucri si spostino insieme. Una copia — un
#      `3.4` scritto qui, o un `0.55` rimasto indietro — passerebbe il confronto
#      numero-contra-numero e non cambierebbe mai niente.
#
# ## E la parola «combaciare» vuol dire anche **comportamento**
#
# Sotto la banda ci sono dieci prove che non leggono una formula ma fanno
# **sparare**: per ogni specie un tiro che passa a meta' dell'involucro deve
# colpire, e uno che passa mezzo metro oltre l'involucro **non** deve colpire.
# Il numero da solo potrebbe essere giusto e il contatto sbagliato; il tiro
# passa o non passa.

## Il fattore corpo avvelenato sul contratto, e poi tolto. Stessa tecnica di
## `enemy_body_scale` in `tests/test_orda.gd` e di `mortar_telegraph_s`: si
## sposta il numero nel canale e si guarda che chi lo legge si sposti con lui.
const SCALA_AVVELENATA := 99.0
## La banda che deve restare **zero**, non «piccola». Due numeri che vengono
## dalla stessa identita' non possono discostarsi ne' di un float: la banda e'
## esattamente 0,0000 e questa soglia dice solo quanto `float32` puo' vibrare.
const BANDA := 0.000001
## Quanti frame si lascia volare un proiettile di prova. A 26 m/s e 60 Hz fa
## 0,433 m per frame, e il nemico e' a 8 m dalla canna: 60 frame sono 26 m,
## cioe' il triplo del viaggio e tutta la vita del proiettile (1,4 s = 84
## frame). Non e' un numero che aspetta: e' il sovrappasso.
const M14_PASSI := 60
## Quanto oltre l'involucro il tiro di controllo passa: mezzo metro, che e'
## piu' della larghezza del proiettile (0,16 m) e piu' di qualunque banda che
## una taratura potrebbe nascondere.
const M14_FUORI := 0.5

func _m14a_involucro(h) -> void:
	var t0 := Time.get_ticks_usec()
	var scala := _scala_corpo()
	if not h.check(scala > 0.0,
		"m14-a: il contratto dichiara Game.enemy_body_scale, il fattore con cui il renderer disegna il corpo"):
		return
	# L'orda **vera**, montata adesso: e' lei che espone `bite_range_of`, cioe' il
	# numero che il morso usa davvero in gioco. Il doppio finto qui sopra non ha
	# un morso, quindi non puo' dire niente su questa riga.
	var sonda = _monta_sonda(h, "OrdaSondaM14")
	if sonda == null:
		return
	var corpo := float(ENEMY.TOUCH_REACH)

	var righe := ""
	var proiettili := PackedFloat32Array()
	for k in ENEMY.KIND_COUNT:
		proiettili.append(float(pool.enemy_contact_radius(k)))
	for k in ENEMY.KIND_COUNT:
		var proiettile: float = proiettili[k]
		var morse_entro: float = float(sonda.bite_range_of(k))
		var disegnato: float = scala * float(ENEMY.RADIUS[k])
		# Criterio 1: due fatti che oggi sono discordi diventano uno.
		var banda: float = morse_entro - corpo - proiettile
		righe += " %s=%.4f/%.4f" % [ENEMY.KIND_NAMES[k], proiettile, banda]
		h.near(banda, 0.0, BANDA,
			"m14-a criterio 1: l'involucro del proiettile e' quello del morso sul %s: morse_entro %.4f - corpo %.4f = %.4f contro un proiettile di %.4f m (scala %.2f)"
				% [ENEMY.KIND_NAMES[k], morse_entro, corpo, morse_entro - corpo, proiettile, scala])
		# Criterio 2: il vincolo forte e' a un senso solo, e se tornasse minore la
		# riga lo dice. Il `<=` e' scritto per intero anche se oggi e' un'ugua-
		# glianza: e' la forma che resta giusta se il fattore corpo scende.
		h.check(proiettile <= disegnato + BANDA,
			"m14-a criterio 2: l'involucro del %s non e' mai piu' grande del corpo che si vede: %.4f contro %.4f m (scala %.2f x RADIUS %.2f)"
				% [ENEMY.KIND_NAMES[k], proiettile, disegnato, scala, ENEMY.RADIUS[k]])
		h.near(proiettile, disegnato, BANDA,
			"m14-a criterio 2: e tornando **minore** la banda si riaprirebbe dall'altra parte; il %s e' a %.4f m contro i %.4f m disegnati: la banda e' zero anche qui"
				% [ENEMY.KIND_NAMES[k], proiettile, disegnato])

	_libera_sonda(sonda)
	_riordina_orda_finta()

	# ## I dieci tiri, e **dopo** che la sonda e' stata libera
	#
	# Una sonda montata prende il contratto nel proprio `_ready()` (`Game.horde =
	# self`, `-orda`), quindi mentre e' in piedi i proiettili del test colpirebbero
	# **quella**, e non il nemico che questa sezione ha appena messo nel doppio
	# finto: i dieci tiri passerebbero sul vuoto, o peggio — passerebbero rossi
	# senza che nessuno capisca perche'. Percio' le due righe sopra liberano la
	# sonda **prima** di sparare, e `hits_of` guarda il nemico giusto.
	for k in ENEMY.KIND_COUNT:
		# dentro: a meta' dell'involucro il colpo **deve** arrivare.
		_m14a_tiro(h, k, proiettili[k] * 0.5, true)
		# fuori: mezzo metro oltre l'involucro il colpo **non** deve arrivare.
		_m14a_tiro(h, k, proiettili[k] + M14_FUORI, false)

	# ## I denti: il canale avvelenato, e poi tolto
	#
	# Il confronto numero-contra-numero qui sopra passerebbe anche con due copie
	# che non cambiano mai. Quindi il contratto viene portato a `SCALA_AVVELENATA`
	# e si guarda che i **due** numeri — quello del pool e quello del morso —
	# escano entrambi dalla scala nuova, e che la banda fra loro resti zero. Poi
	# il contratto torna indietro e una terza orda montata li rivede: «ripristinato»
	# senza questa terza lettura e' una parola.
	var prima := scala
	game.set("enemy_body_scale", SCALA_AVVELENATA)
	h.eq(float(game.get("enemy_body_scale")), SCALA_AVVELENATA,
		"m14-a denti: sul contratto c'e' il numero di prova, %.1f" % SCALA_AVVELENATA)
	var sonda_avvelenata = _monta_sonda(h, "OrdaSondaM14Avvelenata")
	var righe_avv := ""
	if sonda_avvelenata != null:
		for k in ENEMY.KIND_COUNT:
			var proiettile_avv: float = float(pool.enemy_contact_radius(k))
			var morse_avv: float = float(sonda_avvelenata.bite_range_of(k))
			righe_avv += " %s=%.4f/%.4f" % [ENEMY.KIND_NAMES[k], proiettile_avv, morse_avv - corpo]
			h.check(proiettile_avv > proiettili[k] * 10.0,
				"m14-a denti: l'involucro del proiettile sul %s si e' spostato con il canale, da %.4f a %.4f m: non era una copia"
					% [ENEMY.KIND_NAMES[k], proiettili[k], proiettile_avv])
			h.check(morse_avv > proiettili[k] * 10.0 + corpo,
				"m14-a denti: e la portata del morso sul %s e' passata da %.4f a %.4f m"
					% [ENEMY.KIND_NAMES[k], proiettili[k] + corpo, morse_avv])
			h.near(morse_avv - corpo - proiettile_avv, 0.0, BANDA,
				"m14-a denti: col canale avvelenato i due involucri combaciano ancora sul %s (banda %.7f m): combaciavano per costruzione, non per tariffa"
					% [ENEMY.KIND_NAMES[k], morse_avv - corpo - proiettile_avv])
		_libera_sonda(sonda_avvelenata)
	game.set("enemy_body_scale", prima)
	h.eq(float(game.get("enemy_body_scale")), prima,
		"m14-a denti: ripristino 1, il contratto torna a %.4f" % prima)
	var sonda_dopo = _monta_sonda(h, "OrdaSondaM14Dopo")
	if sonda_dopo != null:
		h.near(float(sonda_dopo.bite_range_of(ENEMY.BOSS)) - corpo,
			float(pool.enemy_contact_radius(ENEMY.BOSS)), BANDA,
			"m14-a denti: ripristino 2, un'altra orda montata adesso rivede il fattore vero (%.4f) e i due involucri tornano a combaciare sul boss"
				% prima)
		_libera_sonda(sonda_dopo)
	_riordina_orda_finta()

	print("m14-a: involucro del proiettile / banda col morso, per specie (scala %.2f, corpo del giocatore %.2f tolto dal morso):%s"
		% [scala, corpo, righe])
	print("m14-a denti: col contratto avvelenato a %.1f gli stessi cinque numeri diventano:%s (il canale si sposta, quindi nessuno dei due era una copia)"
		% [SCALA_AVVELENATA, righe_avv])
	print("m14-a: sezione intera in %d us, %d specie x 2 numeri + %d specie x 2 tiri"
		% [Time.get_ticks_usec() - t0, ENEMY.KIND_COUNT, ENEMY.KIND_COUNT])

## Un tiro di prova: un proiettile sparato **lungo -z dalla canna** con un solo
## nemico a `distanza` metri di scarto laterale. Il nemico non si muove (l'orda
## non viene stepsata in questa prova) e la sua distanza minima dal percorso e'
## esattamente `distanza`: il test di contatto e' sul segmento del frame, e la
## distanza laterale e' costante lungo tutta la traiettoria.
##
## `atteso_colpo` dice che cosa la sezione **dimostra**: `true` vuol dire «a
## meta' dell'involucro il colpo arriva», cioe' il difetto di ieri; `false` vuol
## dire «mezzo metro oltre l'involucro il colpo non arriva», cioe' che l'involucro
## non e' diventato piu' grande del corpo che si vede.
func _m14a_tiro(h, kind: int, distanza: float, atteso_colpo: bool) -> void:
	_reset(Vector3.ZERO)
	var i := horde.add(Vector3(distanza, 0.9, -8.0), TOUGH, kind)
	var partito: bool = game.spawn_projectile(Vector3(0.0, 0.9, -0.5),
		Vector3(0.0, 0.0, -1.0), float(weapon.projectile_speed))
	if not h.check(partito,
		"m14-a: il tiro di prova e' partito (il contratto spawn_projectile ha ceduto un slot)"):
		return
	var p = pool.active_at(0)
	if not h.check(p != null, "m14-a: il tiro di prova e' in volo"):
		return
	for f in M14_PASSI:
		pool.step(DT)
	var colpito := horde.hits_of(i)
	var nome: String = ENEMY.KIND_NAMES[kind]
	var involucro := float(pool.enemy_contact_radius(kind))
	if atteso_colpo:
		h.eq(colpito, 1,
			"m14-a: un %s che si vede largo %.2f m e viene traversato a %.2f m di scarto prende il colpo (%d): il difetto di ieri era 0,55 m per tutte e cinque"
				% [nome, involucro, distanza, colpito])
	else:
		h.eq(colpito, 0,
			"m14-a: e mezzo metro oltre l'involucro il %s NON prende il colpo (%d): l'involucro non e' diventato piu' grande del corpo che si vede (scarto %.2f m contro un involucro di %.2f m)"
				% [nome, colpito, distanza, involucro])

## Il fattore corpo, **dal contratto**. Come in `src/sim/horde.gd::_load_body_scale`
## e come fa `tests/test_orda.gd`: `get`/`set` e non `Game.campo`, perche' il
## contratto qui e' un nodo preso a runtime e non un tipo noto.
func _scala_corpo() -> float:
	var v: Variant = game.get("enemy_body_scale")
	if v == null:
		return -1.0
	return float(v)

## Monta un'orda **vera** per una sola lettura e la libera subito dopo: serve a
## chiedere a `-orda` la portata del morso senza toccare `src/sim/`. Il seme e'
## dichiarato perche' `_reroll()` con `seed = 0` chiamerebbe `randomize()` e la
## sonda sporcherebbe il flusso di numeri casuali delle sezioni che vengono.
func _monta_sonda(h, nome: String):
	var scr = load(HORDE_SCRIPT)
	if not h.check(scr is Script, "m14-a: src/sim/horde.gd deve caricare a runtime"):
		return null
	var sonda = (scr as Script).new()
	sonda.name = nome
	sonda.set_physics_process(false)
	sonda.seed = 4242
	root.add_child(sonda)
	# La riga che distingue «canale usato» da «canale mai scritto»: senza di
	# questa, un fallback silenzioso passerebbe tutte le righe sotto.
	h.eq(sonda.body_scale_source, "contratto",
		"m14-a: %s dichiara body_scale_source 'contratto': l'involucro e' letto dal canale, non da un ripiego" % nome)
	return sonda

func _libera_sonda(sonda) -> void:
	if sonda == null:
		return
	root.remove_child(sonda)
	sonda.queue_free()

# ================================================================================
# m12, meta' 1 e 2: il piano del giocatore e gli ostacoli per piano
# ================================================================================
#
# ## Perche' due sezioni e non una
#
# La meta' 1 (`player_floor`) e' **interamente di -gameplay** e si monta da sola:
# la torre la scrive sul contratto, la rimette com'era, e misura la regola. La
# meta' 2 (gli ostacoli per piano) ha bisogno di un array di ostacoli che **non
# esiste** finche' `-arda` non chiama `layout()` quattro volte, quindi la sezione
# costruisce un array con la **stessa forma** (blocchi uguali, un blocco per piano)
# e lo rimette. La forma e' cio' che la sezione prova, non il numero 27.

## Il contratto ha una torre? `floor_count > 1` **e** `floor_height > 0`.
##
## I due numeri li registra `terminal-gun-arena` in `_enter_tree()`
## (`src/render/arena.gd`), con la stessa forma di `arena_radius`: il default
## del contratto e' `1` e `0,0` **di proposito** — «non c'e' una torre» e' il piano
## 0, ed e' la risposta esatta e non un'approssimazione.
func _torre_montata(piani: int, altezza: float) -> bool:
	return piani > 1 and altezza > 0.0

## Istalla una torre **sul contratto** e restituisce i due valori di prima, per
## rimetterli. E' la stessa tecnica di `_m14a_involucro` con
## `enemy_body_scale`: il numero lo mette il test, e il ripristino si vede.
func _m12_monta_torre() -> Array:
	var prima := [game.get("floor_count"), game.get("floor_height")]
	game.set("floor_count", M12_PIANI)
	game.set("floor_height", M12_ALTEZZA_PIANO)
	return prima

## Il ripristino si vede: due asserzioni che dicono che il contratto e' tornato
## com'era. `h` arriva **come parametro**, come in ogni altra funzione di questo
## file che asserisce (`_margine_muro(h)`, `_monta_sonda(h, nome)`, ...): `h` e' un
## alias **locale** di `_process()`, non un membro, e una funzione che lo usa senza
## dichiararlo non compila.
func _m12_ripristina_torre(h, prima: Array) -> void:
	game.set("floor_count", prima[0])
	game.set("floor_height", prima[1])
	h.eq(int(game.get("floor_count")), int(prima[0]),
		"m12: ripristino 1, il contratto torna a floor_count %d" % int(prima[0]))
	h.eq(float(game.get("floor_height")), float(prima[1]),
		"m12: ripristino 2, e a floor_height %.3f" % float(prima[1]))

func _m12_player_floor(h) -> void:
	# ## 1. Il canale, e la riga che lo rifiuta
	#
	# `Game.player_floor()` e' **dichiarato** in `src/core/contracts.gd`, ma
	# `register_impl` accetta solo i nomi che stanno in `const API` (righe 54-62) e
	# quell'elenco **non contiene `player_floor`**: senza quella riga la
	# registrazione viene rifiutata e `Game.player_floor()` risponde `-1`, che e'
	# il neutro giusto ma rende impossibile qualunque criterio che lo usi.
	#
	# Il file e' del vertice e questa sezione **non lo aggira**: dice la riga.
	h.check(game.has_impl("player_floor"),
		"m12: il contratto deve poter chiedere il piano del giocatore. La funzione Game.player_floor() e' dichiarata in src/core/contracts.gd ma il nome NON e' nella lista API (righe 54-62), quindi Game.register_impl(\"player_floor\", ...) la rifiuta con push_error e non registra niente. La riga che manca e' \"player_floor\" in const API.")

	# ## 2. La torre di prova, e tutto quello che resta com'era
	#
	# Nessun `return` fra il montaggio e il ripristino: una sezione che avvelena il
	# contratto e poi esce lascia il mondo dei numeri di m12 per le sezioni dopo, e
	# un test che lascia sporco fa fallire in modo falso chi viene dopo.
	var ostacoli0: PackedVector3Array = player.obstacles
	var torre := _m12_monta_torre()
	# Gli ostacoli veri sono 27 e `27 % 4 != 0`: tenendoli dentro, la divisione
	# sui piani non tornerebbe e il giocatore avviserebbe una volta sola di un
	# difetto che qui non e' il soggetto. La sezione che li usa li rimette.
	player.obstacles = PackedVector3Array()

	# --- 2a. fermo sul piano 0 e fermo sul piano 3 ---
	player.reset_run()
	player.position = Vector3.ZERO
	player.step(DT, Vector3.ZERO)
	player.step(DT, Vector3.ZERO)
	h.eq(int(player._player_floor()), 0,
		"m12: fermo a y = 0 il giocatore e' sul piano 0")
	h.eq(int(game.floor_of(player.position.y)), 0,
		"m12: e floor_of(0) dice la stessa cosa, quindi l'atteso non e' una copia")

	player.position = Vector3(0.0, float(M12_PIANI - 1) * M12_ALTEZZA_PIANO, 0.0)
	player.step(DT, Vector3.ZERO)
	player.step(DT, Vector3.ZERO)
	h.eq(int(player._player_floor()), M12_PIANI - 1,
		"m12: fermo a y = %.1f il giocatore e' sul piano %d (l'ultimo)"
		% [player.position.y, M12_PIANI - 1])

	# --- 2b. FUORI da ogni corridoio di rampa, il piano e' `floor_of(y)` ---
	#
	# ## Cosa misura **questa** meta' e quale non e' qui
	#
	# Fuori da ogni corridoio `surface_height_at()` risponde `-1,0`, la regola cade
	# sul ripiego dichiarato e il piano **e'** quello dell'altezza. Questa sezione
	# gira **prima di `_restart_run`**, quindi qui il canale vero di `-arda` non e'
	# ancora registrato e ogni domanda prende il `-1,0` del contratto: quello che
	# viene provato e' il **ripiego**, non la regola sulla superficie.
	#
	# Per questo la tolleranza e' **zero**: se ci fosse un canale, un punto dentro una
	# rampa direbbe il piano della rampa e questa riga andrebbe rossa per il motivo
	# giusto, ma oggi un canale non c'e' e la soglia morbida sarebbe un verde che
	# nessuno ha misurato. La meta' complementare — **dentro** un corridoio la
	# regola e `floor_of` dicono cose diverse — la possiede `_m12_provino_superficie`,
	# che monta la superficie di prova e campiona **durante** la salita.
	#
	# I denti sono in 2a, non qui: `player_floor()` a quota di piano 3 e' `3`, quindi
	# una regola che restituisse sempre `0` — cioe' il difetto piu' probabile di
	# questa funzione — fa fallire 2a prima di arrivare a questa riga.
	var quante := 0
	for f in M12_PIANI:
		var punto := Vector2(float(f) * 3.0, float(f) * 5.0)
		var concordi := 0
		for i in M12_CAMPIONI_PER_PIANO:
			player.position = Vector3(punto.x, float(f) * M12_ALTEZZA_PIANO + 1.0, punto.y)
			player.velocity = Vector3.ZERO
			player.step(DT, Vector3.ZERO)
			if int(game.floor_of(player.position.y)) == int(player._player_floor()):
				concordi += 1
		if concordi == M12_CAMPIONI_PER_PIANO:
			quante += 1
	h.eq(quante, M12_PIANI,
		"m12: su %d piani, in %d punti fermi lontani dal centro e %d campioni per punto, `player_floor()` e `floor_of(y)` dicono lo stesso numero in **tutti** i campioni di **tutti** i piani: e' il ripiego dichiarato, quello che vale fuori da ogni corridoio di rampa (e che vale anche quando il canale non e' registrato, come qui). La meta' complementare — dentro un corridoio i due non concordano — e' di `_m12_provino_superficie`"
		% [M12_PIANI, M12_PIANI, M12_CAMPIONI_PER_PIANO])

	# --- 2d. il percorso del contratto, che e' quello che -orda chiama davvero ---
	# La regola e' quella di `_player_floor()`; questa riga prova che il
	# **contratto** la raggiunge. Senza la riga qui sopra la sezione passerebbe
	# anche con un canale non montato, che e' il falso verde che questo progetto
	# chiude (piano §1.6).
	if game.has_impl("player_floor"):
		h.eq(int(game.player_floor()), int(player._player_floor()),
			"m12: il contratto e' il metodo che la sezione ha appena provato: Game.player_floor() dice %d come _player_floor()"
			% int(game.player_floor()))
	else:
		print("m12 meta' 1: la regola di _player_floor() e' provata (canale non montato, vedi il FAIL sopra): Game.player_floor() risponde -1 e suona l'avviso 'non registrata'")

	player.obstacles = ostacoli0
	_m12_ripristina_torre(h, torre)
	h.eq(int(player.obstacles.size()), ostacoli0.size(),
		"m12: gli ostacoli del giocatore sono tornati (%d) e il mondo per le sezioni dopo e' quello di prima" % ostacoli0.size())
	print("m12 meta' 1: torre di %d piani a %.1f m montata sul contratto e rimossa; %d campioni per piano in %d punti fermi, e la regola e `floor_of(y)` concordano in tutti. Questa sezione misura il **ripiego** (canale di `-arda` non ancora registrato); la salita dentro la rampa e' di `_m12_provino_superficie`, che campiona durante la corsa"
		% [M12_PIANI, M12_ALTEZZA_PIANO, M12_CAMPIONI_PER_PIANO, M12_PIANI])

func _m12_ostacoli_per_piano(h) -> void:
	# ## L'array di prova ha la **forma** della torre
	#
	# `Game.obstacles` resta **un `PackedVector3Array` piatto** e `y` resta **il
	# raggio**: il contratto di m10 lo dice tre volte e l'invariante `y > 0` lo
	# rende definitivo (un'altezza di piano 0 sarebbe `y = 0`, che e' l'ostacolo
	# che non esiste). Quindi il piano di un ostacolo non si legge dall'elemento: si
	# legge dalla **posizione nell'array**, perche' `-arena` concatena quattro
	# chiamate di `layout()` una per piano.
	#
	# Qui i dischi dei piani **diversi dal piano di prova** stanno tutti allo
	# stesso x e z, e quelli **del piano di prova** sono altrove, dietro il punto
	# di partenza. E' l'unico modo in cui «il piano %d non e' fermato dal disco che
	# ferma il piano 0» possa diventare rossa. L'esclusione e' **voluta** e non un
	# caso: se anche il piano di prova avesse un disco in quel punto, ci troverebbe
	# il disco **proprio** e la sezione passerebbe anche senza la divisione per
	# piano, cioe' non avrebbe denti.
	var ostacoli_originali: Variant = game.get("obstacles")
	var ostacoli_del_giocatore: PackedVector3Array = player.obstacles
	var torre := _m12_monta_torre()

	var totale := M12_PIANI * M12_OST_PER_PIANO
	var lontano_dai_piedi := Vector3(M12_OST_CENTRO.x, M12_OST_RAGGIO, -M12_OST_CENTRO.z)
	var dischi := PackedVector3Array()
	for k in M12_PIANI:
		for i in M12_OST_PER_PIANO:
			dischi.append(lontano_dai_piedi if k == M12_PIANO_PROVA else M12_OST_CENTRO)
	_installa_ostacoli(dischi)
	h.eq(int(player.obstacles.size()), totale,
		"m12: l'array e' piatto e ha %d voci = %d piani x %d dischi: la forma non cambia" % [totale, M12_PIANI, M12_OST_PER_PIANO])
	h.eq(int(player.ostacoli_per_piano()), M12_OST_PER_PIANO,
		"m12: e la divisione size/floor_count dice %d dischi per piano (%d / %d), derivata e non scritta"
		% [M12_OST_PER_PIANO, totale, M12_PIANI])
	var margine: Variant = _script_const(player, "OBSTACLE_MARGIN")
	if margine == null:
		h.fail("m12: src/player/player.gd deve dichiarare OBSTACLE_MARGIN")
		_ripristina_ostacoli(ostacoli_originali, ostacoli_del_giocatore)
		_m12_ripristina_torre(h, torre)
		return
	var pelle := float(margine)
	var atteso := M12_OST_RAGGIO + pelle
	var centro := Vector3(M12_OST_CENTRO.x, 0.0, M12_OST_CENTRO.z)

	# --- 2a. sul piano 0 il disco FERMA ---
	player.reset_run()
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.step(DT, Vector3.ZERO)
	h.eq(int(player._player_floor()), 0, "m12: la sezione parte dal piano 0")
	h.eq(int(player.obstacle_count()), M12_OST_PER_PIANO,
		"m12: e il giocatore conta %d ostacoli, non %d: il numero e' per piano" % [M12_OST_PER_PIANO, totale])
	var dentro_basso := false
	var minima_basso := 1.0e9
	for i in M10_PASSI:
		player.step(DT, Vector3(0.0, 0.0, 1.0))
		var d := _distanza_piano(player.position, centro)
		minima_basso = minf(minima_basso, d)
		if d < M12_OST_RAGGIO:
			dentro_basso = true
	var fermo_basso := _distanza_piano(player.position, centro)
	h.check(not dentro_basso,
		"m12 DENTI, piano 0: il disco ferma il giocatore, minimo %.3f m dal centro contro un raggio di %.2f m" % [minima_basso, M12_OST_RAGGIO])
	h.near(fermo_basso, atteso, 0.05,
		"m12 DENTI, piano 0: e si ferma sul margine esatto, %.3f contro %.3f m (raggio %.2f + margine %.2f)"
		% [fermo_basso, atteso, M12_OST_RAGGIO, pelle])

	# --- 2b. sul piano 2 lo stesso disco NON ferma ---
	#
	# Il giocatore viene portato **sopra** il disco e ci corre dritto dentro. Il
	# primo passo dopo il teletrasporto e' quello in cui il piano dichiarato e'
	# ancora quello di prima (la regola: il piano cambia all'atterraggio, e il
	# primo passo dopo un salto e' un passo in transito), quindi ne servono due
	# prima di misurare: il secondo e' quello in cui i piedi sono fermi.
	player.reset_run()
	player.position = Vector3(0.0, float(M12_PIANO_PROVA) * M12_ALTEZZA_PIANO, 0.0)
	player.velocity = Vector3.ZERO
	player.step(DT, Vector3.ZERO)
	player.step(DT, Vector3.ZERO)
	h.eq(int(player._player_floor()), M12_PIANO_PROVA,
		"m12: fermo a y = %.1f m il giocatore e' sul piano %d, che e' quello dichiarato e non quello di floor_of soltanto"
		% [player.position.y, M12_PIANO_PROVA])
	h.eq(int(player.obstacle_count()), M12_OST_PER_PIANO,
		"m12: e conta %d ostacoli anche sul piano %d: sono quelli del suo piano, non la somma dei quattro"
		% [M12_OST_PER_PIANO, M12_PIANO_PROVA])
	var dentro_alto := false
	var minima_alto := 1.0e9
	for i in M10_PASSI:
		player.step(DT, Vector3(0.0, 0.0, 1.0))
		var d := _distanza_piano(player.position, centro)
		minima_alto = minf(minima_alto, d)
		if d < M12_OST_RAGGIO:
			dentro_alto = true
	h.check(dentro_alto,
		"m12 DENTI, piano %d: il disco che ferma il piano 0 NON ferma il piano %d: ci e' passato dentro, fino a %.3f m dal centro (raggio %.2f). Se questa riga e' rossa, il clamp sta usando l'array intero invece del blocco del piano"
		% [M12_PIANO_PROVA, M12_PIANO_PROVA, minima_alto, M12_OST_RAGGIO])
	h.check(minima_alto <= 0.05,
		"m12 DENTI, piano %d: e non soltanto sfiorarlo: %.3f m dal centro, cioe' sul disco e non a pochi centimeti" % [M12_PIANO_PROVA, minima_alto])
	h.check(_distanza_piano(player.position, centro) > M12_OST_RAGGIO,
		"m12: e prosegue oltre il disco invece di incastrarci: a %.3f m dal centro dopo %d frame" % [_distanza_piano(player.position, centro), M10_PASSI])

	_ripristina_ostacoli(ostacoli_originali, ostacoli_del_giocatore)
	_m12_ripristina_torre(h, torre)
	h.eq(int(player.obstacles.size()), ostacoli_del_giocatore.size(),
		"m12: rimessi gli ostacoli come erano (%d voci) e il mondo per le sezioni dopo e' quello di prima" % ostacoli_del_giocatore.size())
	print("m12 meta' 2: %d ostacoli = %d piani x %d dischi; sul piano 0 il gioco ferma a %.3f m dal centro (minimo %.3f), sul piano %d ci passa dentro fino a %.3f m"
		% [totale, M12_PIANI, M12_OST_PER_PIANO, fermo_basso, minima_basso, M12_PIANO_PROVA, minima_alto])

# ================================================================================
# m12, meta' 3: il giocatore sale la rampa camminando
# ================================================================================
#
# ## Lo stato del fatto, e chi ne e' il proprietario
#
# `_move()` prende `wish = world_direction(input_dir)` e `world_direction()`
# schiaccia l'ingresso sul piano XZ (`Vector3(input_dir.x, 0.0, input_dir.z)`),
# quindi `velocity.y` e' `0,0` e **`position.y` non puo' cambiare dentro `_move`**.
# Su `src/render/` non c'e' nessuna rampa: `arena.gd` registra tre dati
# (`arena_radius`, `enemy_body_scale`, `obstacles`) e nessuno dei due e' un piano.
#
# Quindi **oggi il giocatore non sale**, e il difetto **non e' di questo file**: il
# divieto di m12 e' che la salita sia **geometria** e non un sistema di movimento,
# e un sistema di movimento qui dentro sarebbe proprio il difetto. La prima
# asserzione di questa sezione e' la **guardia** che lo vieta; la seconda e' la
# salita vera, che resta da scrivere e resta **rossa** finche' `-arda` non mette la
# rampa e non registra `floor_count` / `floor_height`.
func _m12_salita(h) -> void:
	# ## 1. Il **contratto** della superficie, e **dove** lo si giudica
	#
	# `Game.surface_height_at(punto, piano)` e' il canale che `-arda` deve
	# registrare: restituisce la quota della superficie sotto quel punto sul piano
	# indicato, e `-1,0` se li' non c'e' rampa. `-1,0` invece di `0,0` perche' `0,0`
	# **e' una quota vera** (il fondo della prima rampa) e sarebbe indistinguibile
	# dal «non c'e' niente qui».
	#
	# ## Il canale si giudica **dove il produttore e' montato**
	#
	# Questa sezione gira **prima** di ogni montaggio di scena, quindi qui il canale
	# di `-arena` **non e' registrato** e la domanda «e' registrato?» ha la risposta
	# giusta — **no** — senza giudicare niente: e' la stessa forma del numero di
	# `restart 1`, un canale giudicato su un mondo in cui il produttore non e' vivo.
	#
	# Il criterio che **giudica** e' in `_m12_piano_del_miratore`, dove
	# `arena_main.tscn` e' montata: li' il canale c'e' e la sezione ci cammina dentro,
	# campionando l'impronta della rampa. Qui resta la misura, e la dichiarazione dice
	# **quale** scena e **perche'** quella.
	var canale_qui: bool = game.has_impl("surface_height_at")
	print("m12 salita: `surface_height_at` e' registrato = %s **su questa scena, che non ha la mappa montata**: nessuna scena e' stata istanziata prima di questo punto del file, quindi la risposta e' giusta e non giudica niente. Il canale viene giudicato in `_m12_piano_del_miratore`, su `arena_main.tscn` montata, dove la sezione ci cammina dentro e misura l'impronta della rampa (corsa, larghezza, pendenza)"
		% str(canale_qui))

	# ## 2. Il **provino**: una superficie finta sul contratto, e tre cose vere
	#
	# Il canale vero non e' registrato (o non e' ancora montato), quindi qui si
	# installa una superficie di prova che risponde con una **pendenza nota** e si
	# guarda che il giocatore la **legga**. La tecnica e' quella di `_m14a_involucro`
	# con `enemy_body_scale` e di `_m16_tetto` con `hud`: il dato lo mette il test,
	# il canale e' quello vero, e il ripristino si vede in un'asserzione.
	#
	# ## Perche' questo e' la prova che **non** c'e' un sistema di movimento
	#
	# Il giocatore sale e `velocity.y` resta **`0,0`**: la quota arriva **per
	# assegnazione**, non per integrazione. Se un domani qualcuno trasformasse
	# `_appoggia_sulla_superficie()` in una velocita' verticale, `velocity.y`
	# smetterebbe di essere `0,0` e questa riga andrebbe rossa. Il divieto di m12 e'
	# «la salita e' geometria»: il numero che lo rende verificabile e' **uno**, ed e'
	# la componente verticale della velocita'.
	var pendenza := M12_PENDENZA_PROVA
	_superficie["rampa"] = false
	_superficie["q"] = -1.0
	_superficie["pendenza"] = pendenza
	_superficie["chiamate"] = 0
	_superficie["piano_chiesto_max"] = -1
	# ## Perche' il doppio si installa **solo se il canale vero non c'e'**
	#
	# `register_impl` **non ha una via per annullare** una registrazione: una
	# `Callable()` vuota viene rifiutata con `push_error` e `_impl` resta com'era
	# (`src/core/contracts.gd` espone `register_impl` e `has_impl`, e basta). Quindi
	# installare il doppio sopra una `-arena` vera la lascerebbe **persa** per il
	# resto del file. Il provino gira solo quando il canale non c'e', e quando c'e'
	# e' il percorso vero sotto a fare il lavoro.
	var reale: bool = game.has_impl("surface_height_at")
	if reale:
		print("m12 salita: il canale vero di -arda e' registrato, quindi il provino non viene installato sopra: la sezione passa alla salita vera sulla geometria vera.")
	else:
		game.register_impl("surface_height_at", Callable(self, "_superficie_di_prova"))
		_m12_provino_superficie(h)

	# ## 3. Il percorso **vero**, e la ragione per cui resta dichiarata e rossa
	#
	# Tutto quello sopra e' un **provino**: il contratto e' quello vero e la domanda
	# e' quella vera, ma la geometria e' di `-arda`. Il criterio del gioco — «il
	# giocatore sale dal piano 0 al piano 3 camminando» — puo' diventare verde solo
	# quando `-arena` registra la sua `surface_height_at()` su un torre vera.
	var piani := int(game.get("floor_count"))
	var altezza := float(game.get("floor_height"))
	var raggio := float(game.get("arena_radius"))
	if not _torre_montata(piani, altezza):
		print("m12 meta' 3 ANCORA ROSSA: la torre non e' montata (Game.floor_count = %d, Game.floor_height = %.3f, default del contratto 1 e 0,0) e surface_height_at non e' registrata. I due numeri e il canale li registra terminal-gun-arena: i numeri in src/render/arena.gd::_enter_tree() e il canale da src/render/arena_ramp.gd. Quello che e' di -gameplay e' verificato sopra e passa: la quota si legge dalla superficie e velocity.y resta 0,0."
		% [piani, altezza])
		return

	player.restart_run()
	player.drive_manually()
	var altezza_totale := float(piani) * altezza
	var minuti := altezza_totale / maxf(0.001, float(player.move_speed))
	var passi := int(ceil(minuti * M12_SALITA_FATTORE / DT))
	var visti := {}
	var quota_max := 0.0
	var quota_min := 0.0
	var lontano := 0.0
	var fuori_volume := 0
	for i in passi:
		# Otto direzioni equispaziate: il giocatore NON conosce la geometria della
		# rampa, quindi la sezione non puo' ne' sapere dove mettere i piedi ne'
		# guidarlo. quello che si misura e' «camminando, il piano cambia».
		var a := TAU * float(i) / float(maxi(passi / 8, 1))
		player.step(DT, Vector3(cos(a), 0.0, sin(a)))
		var p: Vector3 = player.position
		quota_max = maxf(quota_max, p.y)
		quota_min = minf(quota_min, p.y)
		lontano = maxf(lontano, Vector2(p.x, p.z).length())
		if p.y < -0.001 or p.y >= altezza_totale or Vector2(p.x, p.z).length() > raggio + 0.001:
			fuori_volume += 1
		visti[int(player._player_floor())] = true

	h.check(fuori_volume == 0,
		"m12: camminando per %d passi (%.1f s) il giocatore non esce mai dal volume: quota fra %.3f e %.3f m su un'altezza di %.1f, e massimo %.3f m dal centro su un raggio di %.1f (%d passi fuori)"
		% [passi, float(passi) * DT, quota_min, quota_max, altezza_totale, lontano, raggio, fuori_volume])
	# ## Perche' qui **non** c'e' piu' il criterio della salita, e dove sta
	#
	# Questa sezione gira **prima** che la scena sia montata, quindi qui il canale e'
	# il **doppio** con `rampa = false`, che risponde `-1,0` come il contratto comanda
	# quando non c'e' rampa: e il giocatore cammina **su un piano piatto**, dove la
	# quota giusta e' `0`. Il numero sotto e' dunque vero e **non giudica niente**: e'
	# la terza volta la stessa forma (il numero di `restart 1`, il canale di
	# `surface_height_at`), e un criterio che chiede di salire qui chiederebbe che il
	# doppio di prova faccia la rampa che ha dichiarato di non fare.
	#
	# Il criterio che **giudica** e' in `_m12_piano_del_miratore`, su
	# `arena_main.tscn` montata, dentro `_m12_corsa_nel_corridoio`: li' il canale e'
	# quello vero e il giocatore cammina la rampa **da `s = 0` in su**, e la quota va
	# da `0` a `floor_height` con `0,000 m` mancanti al bordo.
	print("m12 meta' 3: %d passi (%.1f s) su questa scena **senza mappa**: quota %.3f -> %.3f m, %d piani visitati, lontano max %.3f m su %.1f. Numero **atteso**: il canale qui e' il doppio con `rampa = false`, che risponde -1,0, quindi il giocatore cammina sul piano piatto e la quota giusta e' 0. Il criterio della salita e' in `_m12_piano_del_miratore`, su `arena_main.tscn` montata"
		% [passi, float(passi) * DT, 0.0, quota_max, visti.size(), lontano, raggio])

# ================================================================================
# m12, meta' 4: random_spawn_point() resta sul piano del giocatore
# ================================================================================
#
# ## **Chi** implementa `random_spawn_point()` e' una domanda aperta, e la sezione
# ## non la decide
#
# Il brief di m12 dice «implementazione tua»; il contratto dichiara
# `random_spawn_point` come API **di `-orda`** (`_missing(..., "terminal-gun-orda")`
# in `src/core/contracts.gd`) e `src/sim/horde.gd:849` **la registra gia'** nel
# proprio `_ready()`. Registrarla anche da `player.gd` farebbe avere **due
# proprietari a una API**, che e' la regola 1 del piano §3 scritta al contrario, e
# nella scena vera l'orda sta prima del giocatore quindi **vincerebbe la mia** e la
# di `-orda` diventerebbe codice morto davanti a `tests/test_orda.gd`, che non e'
# mio.
#
# Quindi qui si verifica **la proprieta' del canale**, non la sua paternita': che il
# punto non sia mai `Vector3.ZERO` e che cada sul piano che il contratto dichiara.
# Chi lo implementa e' una decisione del vertice, ed e' nel rapporto.
func _m12_spawn(h) -> void:
	if not h.check(game.has_impl("random_spawn_point"),
		"m12: il contratto deve avere random_spawn_point(): lo registra src/sim/horde.gd (di -orda) nel proprio _ready(), e questa sezione gira dopo che l'orda vera e' sul contratto"):
		return
	var prove := 0
	var zero := 0
	for i in M12_SPAWN_PROVE:
		var punto: Vector3 = game.random_spawn_point()
		prove += 1
		if punto == Vector3.ZERO:
			zero += 1
		h.finite(punto.length(), "m12 nascita: il punto di nascita %d e' un numero finito (%s)" % [i + 1, str(punto)])
	h.check(prove > 0, "m12 nascita: le %d prove sono state fatte davvero" % prove)
	h.eq(zero, 0,
		"m12 nascita DENTI: random_spawn_point() non restituisce MAI Vector3.ZERO: ZERO e' ambiguo perche' e' anche sotto il giocatore, quindi e' il segnale di «non implementato» del contratto (%d su %d prove nere)"
		% [zero, prove])

	var piani := int(game.get("floor_count"))
	var altezza := float(game.get("floor_height"))
	if not _torre_montata(piani, altezza):
		print("m12 meta' 4 ANCORA ROSSA, meta' parziale: la torre non e' montata (floor_count = %d, floor_height = %.3f), quindi «nasce sul piano del giocatore» non e' una domanda che si puo' fare: senza torre c'e' un solo piano e la risposta e' 0 per costruzione. Quello che resta verificato sopra: il canale esiste e non restituisce mai Vector3.ZERO. La lettura di player_floor() dentro random_spawn_point() e' di -orda (src/sim/horde.gd), che ne e' il proprietario dichiarato dal contratto."
		% [piani, altezza])
		return

	player.restart_run()
	player.position = Vector3(0.0, float(M12_PIANO_PROVA) * altezza, 0.0)
	player.velocity = Vector3.ZERO
	player.step(DT, Vector3.ZERO)
	player.step(DT, Vector3.ZERO)
	var atteso := int(player._player_floor())
	h.eq(atteso, M12_PIANO_PROVA,
		"m12: il giocatore e' fermo sul piano %d e il contratto lo dichiara tale" % M12_PIANO_PROVA)
	var sbagli := 0
	var primo := ""
	var fuori := 0
	var distanze := Vector2(INF, -INF)
	var piani_visti := {}
	for i in M12_SPAWN_PROVE:
		var punto: Vector3 = game.random_spawn_point()
		var d := Vector2(punto.x, punto.z).length()
		if d > float(game.get("arena_radius")) or d <= 0.0:
			fuori += 1
			if primo == "":
				primo = "%s" % str(punto)
		distanze.x = minf(distanze.x, d)
		distanze.y = maxf(distanze.y, d)
		piani_visti[int(game.floor_of(punto.y))] = true
	# ## Cosa promette il contratto, e cosa **no**
	#
	# `contracts.gd:820-822`: «Punto di arrivo casuale **dentro l'arena**, a una
	# distanza comoda dal giocatore. Non va mai restituito come origine: `Vector3.ZERO`
	# e' ambiguo». Quindi il contratto promette **tre** cose: dentro l'arena, non sotto
	# il giocatore, e mai `ZERO` (quella la asserisce sopra, e passa).
	#
	# Il **piano** non e' fra le tre: `_piano_di_nascita()` e' di `-orda` e sceglie dove
	# nasce per una regola sua (il piano con meno nemici, o quello che segue il
	# focus). Il criterio che c'era qui chiedeva «tutti i punti cadono sul piano che
	# `player_floor()` dichiara»: e' una regola che **nessun contratto scrive**, cioe'
	# un criterio che asserirebbe una seconda verita'. Il numero che lo chiude e' che
	# qui tornava `16 su un altro piano` e non si sa se e' un difetto di `-orda` o un
	# numero che nessuno aveva dichiarato — quindi si asserisce **quello che e'
	# scritto**, e la distribuzione dei piani resta una **misura**.
	h.eq(fuori, 0,
		"m12 meta' 4 DENTI: tutti i %d punti di nascita sono **dentro l'arena** e non sono sotto il giocatore, che e' quello che `contracts.gd:820-822` promette: %d fuori, il raggio va da %.3f a %.3f m su un `arena_radius` di %.3f m (primo fuori: %s)"
		% [M12_SPAWN_PROVE, fuori, distanze.x, distanze.y, float(game.get("arena_radius")), primo])
	h.check(piani_visti.size() > 0,
		"m12 nascita: i punti di nascita hanno una quota leggibile e stanno su %d piani distinti (misura: il **piano** di nascita non e' fra le cose che il contratto promette, e `_piano_di_nascita()` e' di -orda)" % piani_visti.size())
	print("m12 meta' 4: %d punti di nascita con il giocatore sul piano %d: %d sono dentro l'arena, il raggio va da %.3f a %.3f m, e i piani toccati sono %d (%s). Il **piano** di nascita e' di -orda e non e' fra le tre cose che `contracts.gd:820-822` promette, quindi qui e' una misura e non un criterio"
		% [M12_SPAWN_PROVE, atteso, M12_SPAWN_PROVE - fuori, distanze.x, distanze.y,
			piani_visti.size(), str(piani_visti.keys())])

# ================================================================================
# m12, meta' 5: il proiettile colpisce un nemico **del suo piano**
# ================================================================================
#
# ## Il difetto che questa sezione chiude, e perche' e' il peggiore della torre
#
# `_segment_hit()` confronta le sole coordinate `x, z`: con quattro piani, un
# proiettile ne attraversa uno e colpisce il nemico che sta **un piano sotto** o
# **sopra**. Il difetto e' **invisibile**: il nemico colpito ha la specie giusta,
# muore con il danno giusto, il `bonk` suona, e l'unica cosa che il giocatore vede e'
# un colpo che arriva dal basso senza una ragione. Per questo non basta accorgersi
# che il codice «ha un `if` che guarda la `y`»: serve una prova che diventi rossa
# togliendolo.
#
# ## Perche' il tiro e' sparato a mano e non dall'arma
#
# `-orda` ha gia' reso `nearest_enemy` consapevole del piano, quindi **la mira** e'
# corretta e non e' il soggetto di questa sezione: qui si prova **l'impatto**, e per
# isolarlo il tiro parte da `Game.spawn_projectile` con una direzione scritta, come
# in `_m14a_tiro`. Se la mira e l'impatto si provassero insieme, un difetto
# dell'una mascherebbe la difetta dell'altra, che e' la classe di difetto di m5b
# («un test che esercita un percorso che il gioco non usa»).
func _m12_impatto_su_piano(h) -> void:
	var quota: Variant = _script_const(weapon, "MUZZLE_HEIGHT")
	if not h.check(quota != null,
		"m12 impatto: src/weapons/weapon_base.gd deve dichiarare MUZZLE_HEIGHT: e' la quota della canna, cioe' la quota a cui nasce il proiettile, e non va copiata qui"):
		return
	var y_muzzle := float(quota)
	var ostacoli_del_giocatore: PackedVector3Array = player.obstacles
	var torre := _m12_monta_torre()
	# Gli ostacoli del giocatore non c'entrano in questa sezione e con
	# `floor_count = 4` i 27 ostacoli veri non dividerebbero: si svuotano perche'
	# la divisione sui piani non e' il soggetto qui. Tornano in fondo.
	player.obstacles = PackedVector3Array()

	# ## La guardia che dichiara i denti, e perche' e' un numero e non una frase
	#
	# Le tre distanze dal piano XZ sono 4,0 / 6,0 / 5,0 m: quindi il nemico 0 e' il
	# piu' vicino e il nemico 2 il secondo. Se le fossero state tutte uguali, il
	# primo dell'array e il piu' vicino sarebbero lo stesso nemico e la sezione
	# passerebbe anche senza il filtro, perche' l'ordinazione dei due criteri
	# coinciderebbe. Qui coincidono **no**.
	h.eq(M12_NEMICO_Z.size(), M12_NEMICO_Z_PER_PIANO,
		"m12 impatto: la tabella delle distanze ha una voce per piano (%d voci per %d piani). Senza questa guardia un mondo che cresce leggeva fuori confine e **moriva** invece di diventare rosso: e' la differenza fra una porta che segnala e una che inghiottisce"
		% [M12_NEMICO_Z.size(), M12_NEMICO_Z_PER_PIANO])
	h.check(-float(M12_NEMICO_Z[0]) < -float(M12_NEMICO_Z[2]) and -float(M12_NEMICO_Z[2]) < -float(M12_NEMICO_Z[1]),
		"m12 impatto: le distanze nel piano XZ sono %.1f / %.1f / %.1f m e sono tutte diverse, quindi il nemico piu' vicino (indice 0) non e' quello che va colpito sui piani 1 e 2: e' cio' che dà i denti a questa sezione"
		% [-float(M12_NEMICO_Z[0]), -float(M12_NEMICO_Z[1]), -float(M12_NEMICO_Z[2])])
	# E la stessa proprieta' sul **quarto** piano, che e' quello nato dopo. La
	# proprieta' **non** e' «crescono»: avevo scritto cosi' e la misura l'ha negata,
	# perche' la tabella e' in ordine di indice (`4 / 6 / 5 / 7`) e non in ordine di
	# distanza. La proprieta' che dà i denti e' l'altra, e l'avevo scritta sopra senza
	# accorgermene: **le distanze sono tutte diverse**, cosi' nessun piano puo'
	# condividere la posizione con un altro e il «nemico piu' vicino nel piano XZ»
	# resta diverso dal «nemico del piano giusto».
	var tutte_diverse := true
	for i in M12_NEMICO_Z.size():
		for j in range(i + 1, M12_NEMICO_Z.size()):
			if is_equal_approx(M12_NEMICO_Z[i], M12_NEMICO_Z[j]):
				tutte_diverse = false
	h.check(tutte_diverse,
		"m12 impatto: le distanze nel piano XZ sono %s m e sono **tutte diverse** su %d piani: e' la proprieta' che dà i denti — il nemico piu' vicino nel piano XZ non puo' essere il nemico di nessun altro piano, quindi un contatto che ignora la quota non puo' passare per caso"
		% [str(M12_NEMICO_Z), M12_NEMICO_Z.size()])

	var visite_per_passo := 0
	var segmenti_per_passo := 0
	for k in M12_PIANI:
		# Il giocatore **fermato su** un piano: due passi, perche' il primo dopo
		# il teletrasporto e' un passo in transito e il piano cambia solo al
		# secondo (vedi `_player_floor` in src/player/player.gd).
		player.reset_run()
		player.position = Vector3(0.0, float(k) * M12_ALTEZZA_PIANO, 0.0)
		player.velocity = Vector3.ZERO
		player.step(DT, Vector3.ZERO)
		player.step(DT, Vector3.ZERO)
		if not h.eq(int(player._player_floor()), k,
			"m12 impatto: il giocatore fermato a y = %.1f m dichiara il piano %d, altrimenti tutta la sezione misurerebbe il ripiego e non il filtro"
			% [player.position.y, k]):
			continue
		pool.reset()
		horde.clear()
		for e in M12_PIANI:
			horde.add(Vector3(0.0, float(e) * M12_ALTEZZA_PIANO + y_muzzle, float(M12_NEMICO_Z[e])), TOUGH)
		var muzzle := Vector3(0.0, float(k) * M12_ALTEZZA_PIANO + y_muzzle, -0.5)
		var partito: bool = game.spawn_projectile(muzzle, Vector3(0.0, 0.0, -1.0), float(weapon.projectile_speed))
		if not h.check(partito,
			"m12 impatto, piano %d: il tiro di prova e' partito (il contratto spawn_projectile ha ceduto un slot)" % k):
			continue
		# Il numero dei confronti che il ciclo fa davvero in questo passo: e'
		# `proiettili vivi × nemici vivi`, cioe' la formula di `for e in n` di
		# `_collide()`, letta sui **campi vivi** e non scritta. Serve alla stampa
		# qui sotto, ed e' l'unico numero di costo che questa sezione produce.
		visite_per_passo = int(pool.active_count()) * int(horde.count)
		segmenti_per_passo = int(horde.count)
		for f in M14_PASSI:
			pool.step(DT)
		h.eq(horde.damage_calls, 1,
			"m12 impatto, piano %d: UN solo colpo, e la catena senza fuori indici (%d chiamate a damage_enemy in %d passi)"
			% [k, horde.damage_calls, M14_PASSI])
		h.eq(horde.out_of_range, 0, "m12 impatto, piano %d: nessun indice fuori dall'orda" % k)
		for e in M12_PIANI:
			var atteso: int = 1 if e == k else 0
			h.eq(horde.hits_of(e), atteso,
				"m12 impatto DENTI, piano %d: il nemico %d (piano %d, z = %.1f m) prende %d colpi. Solo il nemico %d e' nella banda del piano da cui e' sparato il colpo, quindi togliendo il filtro di banda questa riga va rossa sui piani 1 e 2 (dove il nemico giusto non e' ne' il primo dell'array ne' il piu' vicino)"
				% [k, e, e, float(M12_NEMICO_Z[e]), atteso, k])
		h.eq(int(pool.active_count()), 0,
			"m12 impatto, piano %d: pierce 0, il proiettile sparisce al primo colpo" % k)

	# ## Il bordo inferiore appartiene al piano **di sopra**, e la banda lo dice
	#
	# Il contratto dichiara `[i * h, (i+1) * h)` con il bordo inferiore **incluso**:
	# a `y = 20,0` con `floor_height = 20,0` si e' sul piano 1. La banda del filtro
	# usa lo stesso intervallo, e questa riga e' la prova che le due convenzioni
	# non si sono separate: un `<` invece di un `<=` qui farebbe fallire il nemico
	# che sta esattamente sul bordo, che e' il caso piu' comune su una rampa che
	# arriva al livello.
	player.reset_run()
	player.position = Vector3(0.0, M12_ALTEZZA_PIANO, 0.0)
	player.velocity = Vector3.ZERO
	player.step(DT, Vector3.ZERO)
	player.step(DT, Vector3.ZERO)
	pool.reset()
	horde.clear()
	horde.add(Vector3(0.0, M12_ALTEZZA_PIANO, float(M12_NEMICO_Z[1])), TOUGH)
	game.spawn_projectile(Vector3(0.0, M12_ALTEZZA_PIANO + y_muzzle, -0.5),
		Vector3(0.0, 0.0, -1.0), float(weapon.projectile_speed))
	for f in M14_PASSI:
		pool.step(DT)
	h.eq(horde.hits_of(0), 1,
		"m12 impatto: un nemico a y = %.1f m, esattamente sul bordo inferiore della banda del piano 1, prende il colpo: la banda e' [i*h, (i+1)*h) come dichiara il contratto"
		% M12_ALTEZZA_PIANO)
	h.eq(int(game.floor_of(M12_ALTEZZA_PIANO)), 1,
		"m12 impatto: e floor_of del contratto dice 1 per la stessa quota, quindi il filtro e' la stessa convenzione e non due")

	player.obstacles = ostacoli_del_giocatore
	_m12_ripristina_torre(h, torre)
	h.eq(int(player.obstacles.size()), ostacoli_del_giocatore.size(),
		"m12 impatto: gli ostacoli del giocatore sono tornati (%d)" % ostacoli_del_giocatore.size())
	print("m12 impatto: %d proiettili vivi su %d nemici vivi = %d confronti per passo, di cui %d arrivano al test di segmento (%d scartati dalla banda, %.0f%%). Il ciclo non cresce: la formula e' proiettili_vivi x nemici_vivi ed e' la stessa di prima del filtro. Numero di wall-clock MISURATO: nessuno (questa sezione non puo' eseguire il benchmark), e il confronto con l'alternativa tridimensionale e' nel blocco sopra _collide() in src/weapons/projectile_pool.gd"
		% [1, int(M12_PIANI), visite_per_passo, segmenti_per_passo,
			visite_per_passo - segmenti_per_passo,
			100.0 * float(visite_per_passo - segmenti_per_passo) / maxf(1.0, float(visite_per_passo))])

## La **superficie di prova**: il doppio che risponde al posto di `-arda`.
##
## Non e' un trucco, e' lo stesso oggetto che `FakeHorde` fa per `damage_enemy` e
## per `nearest_enemy`: un doppio che implementa **esattamente** la superficie del
## contratto e nient'altro. Con `rampa = false` risponde `q` (`-1,0` = qui non c'e'
## niente, che e' il neutro dichiarato dal vertice); con `rampa = true` risponde
## `pendenza * x`, cioe' una rampa che sale di un numero **noto** per metro.
##
## Tiene anche il **piano** che le e' stato chiesto: e' il numero che distingue
## «il canale funziona» da «il canale funziona col piano giusto», e il secondo e'
## quello che chiude la rampa.
func _superficie_di_prova(punto: Vector2, piano: int) -> float:
	_superficie["chiamate"] = int(_superficie["chiamate"]) + 1
	_superficie["piano_chiesto_max"] = maxi(int(_superficie["piano_chiesto_max"]), piano)
	if piano > 0:
		# La rampa di prova esiste **solo sul piano 0**, e questa riga e' cio' che
		# rende la sezione un criterio sul **piano** e non sulla sola lettura. Se il
		# giocatore chiedesse `floor_of(y)`, alla prima riga sopra i 20 m la domanda
		# arriverebbe con `piano = 1`, il doppio risponderebbe `-1,0` e il giocatore
		# **si fermerebbe al primo bordo**: il criterio diventa rosso per la ragione
		# giusta, che e' «la rampa appartiene al piano da cui si e' partiti».
		return -1.0
	if bool(_superficie["rampa"]):
		return float(_superficie["pendenza"]) * punto.x
	return float(_superficie["q"])

## Il **provino** della superficie, chiamato da `_m12_salita` **solo** quando il
## canale vero di `-arda` non e' registrato (vedi la nota su `register_impl` che
## non ha una via per annullare una registrazione).
##
## Sono tre fatti, e ognuno ha un difetto contrario che lo farebbe diventare rosso:
## il **neutro** (il `-1,0` si rispetta e non si approssima), la **lettura ogni
## passo** (la quota non viene ricordata all'avvio), e la **salita col piano
## giusto** (che e' il criterio vero: se `_move()` chiedesse `floor_of(y)`, il
## doppio — che ha la rampa solo sul piano 0 — risponderebbe il neutro alla prima
## riga sopra i 20 m e il giocatore si fermerebbe al primo bordo).
func _m12_provino_superficie(h) -> void:
	# ## Questa sezione possiede la **torre** per il tempo in cui misura
	#
	# Il numero che me l'ha detto: `quota 68,2501 m` contro `floor_of(quota) x
	# floor_height = 0,0000 m`. Non e' un difetto di `floor_of` ne' della sonda: e'
	# che questa sezione **non era dentro la finestra** in cui `_m12_salita` installs
	# `floor_count` e `floor_height`, quindi quando leggeva `floor_of` il contratto
	# aveva gia' ripristinato `floor_height` a **0** e la divisione dava zero per
	# definizione.
	#
	# E' la sesta volta che la stessa cosa appare, e questa volta dentro una sezione
	# che misura una **sonda**: la regola e' che la sezione che misura possiede il
	# mondo che misura, e `floor_height` e' parte di quel mondo esattamente come lo
	# sono gli ostacoli e l'orda. Quindi qui la finestra si apre e si chiude come in
	# `_m12_salita`, con gli stessi due helper e le stesse costanti gia' dichiarate:
	# non un numero nuovo, la stessa finestra.
	var torre_prima := _m12_monta_torre()
	# (a) Il **neutro**: nessuna rampa, nessuna quota scritta. E' la meta' che
	#     protegge dal fallback: un `0,0` qui farebbe salire il giocatore al piano
	#     sbagliato senza che nessuno se ne accorga, e un `-1,0` che il giocatore
	#     ignora farebbe alzare `position.y` di un metro a ogni passo.
	player.reset_run()
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.step(DT, Vector3.ZERO)
	var quota_neutra := float(player.position.y)
	_superficie["chiamate"] = 0
	for i in 60:
		player.step(DT, Vector3(1.0, 0.0, 0.0))
	h.near(float(player.position.y), quota_neutra, 0.0,
		"m12 salita: con surface_height_at che risponde -1,0 (qui non c'e' rampa) il giocatore NON cambia quota: %.3f -> %.3f m su 60 frame a corsa. Il neutro si rispetta, non si approssima" % [quota_neutra, player.position.y])
	h.check(int(_superficie["chiamate"]) >= 60,
		"m12 salita: e la domanda e' stata posta **ogni passo** (%d chiamate in 60 frame): la quota non viene ricordata da una lettura sola all'avvio" % int(_superficie["chiamate"]))

	# (b) La **rampa**: la quota segue la superficie, la velocita' verticale resta
	#     a zero, e **il piano richiesto e' quello da cui si e' partiti**.
	player.reset_run()
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	_superficie["rampa"] = true
	player.step(DT, Vector3.ZERO)
	# ## Il **criterio con i denti**: a meta' salita `player_floor()` dice 0 e
	# `floor_of(y)` dice gia' 1
	#
	# Il doppio ha la rampa **solo sul piano 0**, quindi durante tutta la salita il
	# giocatore e' dentro il corridoio di `f = 0`. La riga conta i passi in cui i due
	# **non** concordano: se il numero e' zero, il criterio starebbe misurando
	# `floor_of` e non la regola, quindi l'asserzione sotto sarebbe decorativa. E'
	# la controfattuale, ed e' la stessa per tutte e due le regole vecchie: sia
	# «piedi fermi -> piano dell'altezza» sia il latch che segue `dy` sbagliavano
	# quando la superficie alza il giocatore **oltre** un bordo senza che lui si
	# muova.
	var discordi := 0
	var primo_scarto := ""
	for i in M12_PASSI_RAMPA_PROVA:
		player.step(DT, Vector3(1.0, 0.0, 0.0))
		var logico := int(player._player_floor())
		var banda := int(game.floor_of(player.position.y))
		if logico != banda:
			discordi += 1
			if primo_scarto == "":
				primo_scarto = "y = %.2f m: player_floor() dice %d, floor_of dice %d" % [player.position.y, logico, banda]
	var quota_rampa := float(player.position.y)
	_superficie["rampa"] = false
	# ## Perche' qui **non** c'e' piu' il criterio con i denti, e dove sta
	#
	# Il criterio che c'era qui contava i passi in cui `player_floor()` e
	# `floor_of(y)` dicevano piani diversi e chiedeva che fossero **piu' di zero**:
	# cioe' chiedeva che la regola **divergesse** da `floor_of`. Con la riga del
	# pavimento, sulla torre vera, **non e' piu' possibile**: salendo la rampa `q` sta
	# fra `f * floor_height` e `(f + 1) * floor_height`, quindi `floor_of(q)` dice `f`
	# come la regola; sulla spianata `q = (f + 1) * floor_height` e `floor_of` dice
	# `f + 1` come la regola. **Su una torre a piatti e a rampe di un piano solo, la
	# regola e `floor_of` sono la stessa funzione**, e un criterio che chiede che
	# divergano asserirebbe una cosa che il gioco non fa.
	#
	# Il numero resta, perche' dice **perche'**: questa rampa di prova sale a
	# `%.1f m/m` e dopo `M12_PASSI_RAMPA_PROVA` passi e' a `%.0f m`, cioe' **oltre
	# tre piani**, mentre una rampa vera ne copre uno. La sonda **viola l'invariante
	# di proposito**, e la regola — che conta la rampa solo sotto il bordo — la tratta
	# come non contenente il giocatore: da li' la regola segue `floor_of`. Quello e'
	# il numero che dice **perche'** il campione non puo' piu' servire da
	# controfattuale, e non e' un difetto: e' una sonda che esce dai numeri di un mondo.
	#
	# I **denti** sono adesso sulla spianata della rampa **vera**, in
	# `_m12_corsa_nel_corridoio`: li' la regola «la rampa conta sotto il bordo» e la
	# regola «la rampa conta finche' risponde» dicono piani **diversi**, ed e' li' che
	# il criterio ha denti.
	print("m12 salita, provino: la regola e `floor_of(y)` discordano in %d dei %d passi (primo scarto: %s). Numero **atteso**: e' la rampa di prova a %.1f m/m che dopo %d passi porta la quota a %.0f m, oltre tre piani, mentre una rampa vera ne copre uno — questa sonda esce dai numeri di un mondo e la regola, che conta la rampa solo sotto il bordo, la tratta come non contenente il giocatore. I denti sono sulla spianata della rampa vera, in `_m12_corsa_nel_corridoio`"
		% [discordi, M12_PASSI_RAMPA_PROVA,
			primo_scarto if primo_scarto != "" else "nessuno",
			M12_PENDENZA_PROVA, M12_PASSI_RAMPA_PROVA, quota_rampa])
	h.near(float(player.velocity.y), 0.0, 0.0,
		"m12 salita DENTI: il giocatore e' salito ma velocity.y e' **esattamente 0,0**: la quota arriva dalla superficie per assegnazione, non da un sistema di movimento verticale")
	h.check(quota_rampa >= M12_ALTEZZA_PIANO,
		"m12 salita: e ha attraversato **un bordo**: la quota e' a %.3f m dopo %d passi, almeno i %.1f m di `M12_ALTEZZA_PIANO` (ultimo piano richiesto al canale: %d). Prima della riga del pavimento questa sezione chiedeva **due** bordi con la sonda a %.1f m/m: non e' piu' possibile, perche' una rampa vera copre un piano solo e sul piano nuovo la sonda risponde -1,0 come il contratto comanda. Il numero che resta e' quello che dice **perche'** la sonda e' finita"
		% [quota_rampa, M12_PASSI_RAMPA_PROVA, M12_ALTEZZA_PIANO, int(_superficie["piano_chiesto_max"]), M12_PENDENZA_PROVA])
	h.near(quota_rampa, float(int(game.floor_of(quota_rampa))) * M12_ALTEZZA_PIANO, 0.0001,
		"m12 salita: e la quota finale e' **il pavimento del piano su cui e' arrivato**, %.4f m contro `floor_of(quota) x floor_height` = %.4f m: sulla rampa la quota la scrive la superficie (`q = pendenza x`), sul pavimento la scrive la riga della divisione, e le due non si sommano. Questa riga ha denti: senza la riga del pavimento la quota sarebbe rimasta quella della rampa, cioe' %.1f m, e `player_floor()` avrebbe continuato a dire il piano da cui si e' partiti"
		% [quota_rampa, float(int(game.floor_of(quota_rampa))) * M12_ALTEZZA_PIANO, M12_PENDENZA_PROVA * player.position.x])

	# Il doppio si **smonta da solo**: `rampa = false` e `q = -1,0` lo rendono
	# esattamente il neutro dichiarato dal contratto, cioe' «non c'e' rampa qui»,
	# che e' quello che avrebbe risposto un mondo senza torre. Resta registrata la
	# `Callable` del doppio, e questo e' dichiarato perche' `register_impl` non ha
	# una via per annullare: le sezioni dopo vedono `-1,0`, che e' la risposta
	# esatta, non un fallback.
	h.eq(float(_superficie["q"]), -1.0,
		"m12 salita: il doppio e' tornato al neutro -1,0, quindi da qui in avanti il canale dice «qui non c'e' rampa» esattamente come prima di questa sezione")
	print("m12 salita, provino: neutro rispettato, %d domande in 60 frame, rampa di prova %.3f m/m per %d passi -> quota %.3f m, regola e floor_of(y) discordi in %d passi (primo: %s), piano logico finale %d"
		% [int(_superficie["chiamate"]), M12_PENDENZA_PROVA, M12_PASSI_RAMPA_PROVA, quota_rampa, discordi, primo_scarto, int(player._player_floor())])
	# La finestra si chiude **qui**, non all'inizio: `floor_of(quota) x floor_height`
	# e' confrontato a `floor_height` in forza, quindi ripristinare prima sarebbe stato
	# di nuovo leggere fuori dal ciclo — cioe' vero e non escludente.
	_m12_ripristina_torre(h, torre_prima)

# ================================================================================
# m12, meta' 6: il piano che il **miratore** cerca e quello che il proiettile
#              colpisce devono essere lo stesso
# ================================================================================
#
# ## Il difetto, e dove sta
#
# Il ritmo di uccisione di `test_progression.gd` e' crollato da 1,8741/s a
# 0,0480/s (39 volte) mentre il campo e' al livello giusto e il rateo di nascita e'
# quello dichiarato: quindi non e' la nascita, e' la catena del danno.
#
# **`src/sim/horde.gd:2304`** sceglie la griglia del piano cosi':
#
#     var g = _grid_of(floor_of(from.y))
#
# e `_try_fire()` gli passa `Game.player_position()` come `from`, cioe' la quota
# **fisica** del giocatore. Ma lo stesso `-orda` decide **dove nasce** con
# `_focus_floor`, che viene da `Game.player_floor()` (riga 1411) — il canale che
# dichiara il piano **logico**, cioe' quello da cui si e' partiti durante la rampa.
#
# **Finche' il giocatore cammina sul pavimento piatto, `from.y` e `player_floor()`
# dicono la stessa cosa e nessuno se ne accorge.** Appena il giocatore prende
# quota dalla superficie (`surface_height_at`, che `-gameplay` scrive in
# `position.y`), il giocatore fermo a `y = 20,0` e' **logicamente** sul piano 0 e
# **fisicamente** sul piano 1: la griglia del miratore e' quella del piano 1, dove
# non c'e' nessun nemico perche' tutti sono nati sul piano 0. `nearest_index`
# risponde `-1`, l'arma non spara, e il ritmo di uccisione crolla **senza nessun
# colpo mancato da spiegare**: il posto da guardare non era l'impatto, era la mira.
#
# ## Perche' questa sezione e' nel file di -gameplay
#
# Perche' la banda di `_collide()` e' **mia** e questa sezione e' l'unico posto
# che puo' dire se le due domande — «che piano cerco?» e «che piano colpisco?» —
# danno la stessa risposta. Il numero che le divide e' uno solo e si legge in due
# righe, ed e' l'invariante che `-orda` deve potenzialmente rompere senza che
# nessuna porta se ne accorga.
##
## Finestra di misura: `600` passi a DT 1/60 sono **10,0 s**, cioe' ~28 colpi a
## `FIRE_INTERVAL = 0,35 s`. Serve a distinguere «non spara» (colpi/s ~ 0) da
## «spara e non colpisce» (colpi/s a regime, uccisioni/s a zero): e' la coppia di
## numeri che distingue le due-ipotesi, ed e' il motivo per cui la sezione non si
## ferma alle sole uccisioni.
const M12_MIRA_PASSI := 600

## Il passo della campionatura di `_m12_numerazione_delle_rampe`, in metri. Non e'
## un numero di gioco: e' il passo con cui la sezione **sonda** il canale su tutto il
## disco per capire quali piani hanno una rampa. `2,0 m` e' dichiarato perche' e'
## molto piu' fine della larghezza di un corridoio di rampa (`8 m`): un passo piu'
## grosso potrebbe **saltare** un corridoio e la sezione direbbe «quel piano non ha
## rampa» quando invece ce l'ha, che e' il falso negativo che questa sezione esiste
## per non produrre.
const M12_PASSO_CAMPIONE := 2.0

# ================================================================================
# m12, meta' 6: la corsa **dentro** il corridoio vero, campionata **durante**
# ================================================================================
#
# ## Perche' `ramp_inner`, `ramp_outer` e `ramp_width` **non sono qui**
#
# Il vertice ha chiesto di confrontare il punto di partenza con quei tre numeri
# «**letti dal produttore**». Non sono sul contratto: `src/core/contracts.gd`
# espone `surface_height_at` e `ground_visible`, e i numeri della rampa vivono in
# `src/render/arena_ramp.gd`, che e' di `terminal-gun-arena`. Scriverli qui
# sarebbe **copiarli**, e una copia non si aggiorna e non si contraddice: il
# confronto direbbe sempre quello che dice la copia.
#
# Quindi la stessa domanda la fa **il canale**: la sezione chiede
# `surface_height_at(xz, 0)` su una griglia e **misura l'impronta del corridoio**
# dalle risposte del produttore. I tre numeri che servono — quanto e' lunga la
# corsa, quanto e' larga, e **dove dentro e' il punto di partenza** — vengono
# fuori come misura, e se `-arena` sposta la rampa la misura si sposta con lei.
#
# ## Il passo della griglia e' gia' dichiarato sopra
#
# `M12_PASSO_CAMPIONE = 2,0 m` e' gia' piu' fine della larghezza di un corridoio,
# quindi una griglia a quel passo **non puo' saltare** un corridoio intero: puo'
# solo spostare il bordo di `M12_PASSO_CAMPIONE`, ed e' per questo che ogni
# lunghezza misurata porta `+ M12_PASSO_CAMPIONE` di risoluzione dichiarata.
const M12_PASSO_IMPRONTA := M12_PASSO_CAMPIONE

## Il **fattore di corsa** per il tetto di passi, in multipli di `M12_ALTEZZA_PIANO`.
## Non e' una misura della rampa: e' il margine sopra la corsa **minima** che
## serve a salire un piano con una pendenza di `1 m/m`, che e' il caso peggiore
## fra le pendenze che una rampa puo' avere. Il tetto in passi e' **derivato a
## runtime** da questo fattore, da `M12_ALTEZZA_PIANO` e dalla velocita' **viva**
## del giocatore (`move_speed`), non scritto qui.
const M12_CAMMINO_PROVA_FATTORE := 2.0

## Quanti passi il giocatore resta **fermo** sulla spianata d'arresto prima che se ne
## legga il piano. Non e' un'attesa: e' il numero di passi necessario a che la quota
## sia quella che la superficie ha risposto **e** il latch sia ricalcolato, e senza
## questi passi la stampa leggerebbe il latch di **prima** del posizionamento, cioe'
## un istante diverso da quello che dichiara.
const M12_PASSI_SPIANATA := 3

## L'**impronta** del corridoio della rampa che parte dal piano `piano`, misurata
## chiedendo al canale e non copiandone la geometria.
##
## `dentro` e' il numero di punti della griglia che hanno risposto `>= 0,0`, cioe'
## i campioni che sono dentro il corridoio; `domande` e' il numero di domande
## poste. `lungo` e `largo` sono i due numeri che servono per sapere se un punto
## e' dentro, e vengono entrambi dalle risposte del produttore con
## `+ M12_PASSO_IMPRONTA` di risoluzione dichiarata.
func _m12_impronta_del_corridoio(piano: int) -> Dictionary:
	var n := int(RAGGIO_ARENA / M12_PASSO_IMPRONTA)
	var punti: Array = []
	var domande := 0
	for a in range(-n, n + 1):
		for b in range(-n, n + 1):
			var q := Vector2(float(a) * M12_PASSO_IMPRONTA, float(b) * M12_PASSO_IMPRONTA)
			domande += 1
			if game.surface_height_at(q, piano) >= 0.0:
				punti.append(q)
	var dentro := punti.size()
	var uscita := {"dentro": dentro, "domande": domande, "punti": punti}
	if dentro == 0:
		return uscita
	# L'asse lungo della rampa **non e' un numero noto**: e' il lato maggiore
	# dell'ingombro dei punti trovati, ed e' l'unico modo di non sapere in che
	# verso `-arda` ha numerato le tre rampe.
	var limiti := Vector4(INF, -INF, INF, -INF)
	for q in punti:
		var v: Vector2 = q
		limiti.x = minf(limiti.x, v.x)
		limiti.y = maxf(limiti.y, v.x)
		limiti.z = minf(limiti.z, v.y)
		limiti.w = maxf(limiti.w, v.y)
	var asse := Vector2(1.0, 0.0) if (limiti.y - limiti.x) >= (limiti.w - limiti.z) else Vector2(0.0, 1.0)
	var traverso := Vector2(-asse.y, asse.x)
	var s := Vector2(INF, -INF)
	var t := Vector2(INF, -INF)
	for q in punti:
		var v: Vector2 = q
		var sp := v.dot(asse)
		var tp := v.dot(traverso)
		s.x = minf(s.x, sp)
		s.y = maxf(s.y, sp)
		t.x = minf(t.x, tp)
		t.y = maxf(t.y, tp)
	uscita["asse"] = asse
	uscita["s_min"] = s.x
	uscita["t_centro"] = (t.x + t.y) * 0.5
	uscita["lungo"] = s.y - s.x + M12_PASSO_IMPRONTA
	uscita["largo"] = t.y - t.x + M12_PASSO_IMPRONTA
	return uscita

## Il **piede** della rampa: fra i punti trovati, quello con la quota **piu'
## bassa**, e a parita' quello piu' vicino al centro. E' il posto da cui si parte,
## perche' e' l'unico da cui la quota sale: partire dal centro di un corridoio
## significa partire dalla meta' alta e scoprire di essere gia' saliti, che e'
## esattamente la trappola che il vertice ha descritto con i suoi `6,0 m fuori dal
## corridoio largo 8,0 m`.
func _m12_piede_del_corridoio(punti: Array, piano: int) -> Vector2:
	var meglio := Vector2.ZERO
	var q_migliore := INF
	var dist_migliore := INF
	for q in punti:
		var v: Vector2 = q
		var alt: float = game.surface_height_at(v, piano)
		var dist := v.length()
		if alt < q_migliore or (alt == q_migliore and dist < dist_migliore):
			q_migliore = alt
			dist_migliore = dist
			meglio = v
	return meglio

## La corsa **dentro** il corridoio vero, campionata **durante**. Nessuna
## asserzione: e' la misura che il vertice ha chiesto, e le tre cose che stampa
## sono il punto di partenza confrontato con l'impronta, il passo in cui il
## canale smette di rispondere, e i campioni in cui la regola e `floor_of(y)`
## discordano **mentre la salita e' in corso** — non dopo, che e' il difetto che
## ha reso la prima stesura di questa sezione decorativa.
func _m12_corsa_nel_corridoio(p, hd, piano: int) -> Dictionary:
	var spianata := {}
	var impronta := _m12_impronta_del_corridoio(piano)
	var dentro := int(impronta.get("dentro"))
	var domande := int(impronta.get("domande"))
	if dentro == 0:
		print("m12 corridoio: il canale vero di `-arena` NON ha risposto `>= 0,0` in nessuno dei %d punti campionati a passo %.1f m sulla torre vera. Il difetto e' del canale (`surface_height_at` risponde -1,0 ovunque, quindi nessun corridoio esiste per il contratto) e questa misura non ha niente da dire finche' non risponde"
			% [domande, M12_PASSO_IMPRONTA])
		return spianata
	var punti: Array = impronta.get("punti", [])
	var asse: Vector2 = impronta.get("asse", Vector2(1.0, 0.0))
	var traverso := Vector2(-asse.y, asse.x)
	var piede := _m12_piede_del_corridoio(punti, piano)
	var q_piede: float = game.surface_height_at(piede, piano)
	var s_piede := piede.dot(asse) - float(impronta.get("s_min"))
	var t_piede := piede.dot(traverso) - float(impronta.get("t_centro"))
	# Il verso **in salita**: il punto con la quota piu' alta fra quelli trovati lo
	# decide, e la quota la da il canale. Cosi' la sezione non deve sapere in che
	# verso `-arda` ha messo la rampa.
	var alto := piede
	var q_alto: float = q_piede
	for q in punti:
		var v: Vector2 = q
		var alt: float = game.surface_height_at(v, piano)
		if alt > q_alto:
			q_alto = alt
			alto = v
	var su := Vector2.ZERO
	if alto != piede:
		su = (alto - piede).normalized()
	print("m12 corridoio: piede della rampa che parte dal piano %d trovato **chiedendo al canale**, non copiandone i numeri. Punto di partenza campionato a (x = %.1f, z = %.1f): a s = %.1f m dall'inizio della corsa su una corsa misurata di %.1f m, e a %.1f m dal centro della larghezza su una larghezza misurata di %.1f m (asse lungo (%.1f, %.1f), pendenza %.3f m/m). Risponde in %d dei %d punti campionati a passo %.1f m"
		% [piano, piede.x, piede.y, s_piede, float(impronta.get("lungo")), absf(t_piede),
			float(impronta.get("largo")), asse.x, asse.y,
			(q_alto - q_piede) / maxf((alto - piede).length(), M12_PASSO_IMPRONTA),
			dentro, domande, M12_PASSO_IMPRONTA])
	# Il tetto di passi e' **derivato**: la corsa minima per salire un piano con
	# una pendenza di 1 m/m (`M12_ALTEZZA_PIANO`), per il fattore dichiarato sopra,
	# diviso per la velocita' **viva** del giocatore per un passo. Non e' una
	# misura della rampa, e' un tetto: se il canale rispondesse per sempre, la
	# sezione deve fermarsi da qualche parte.
	var passo := float(p.get("move_speed")) * DT
	var passi_max := int(M12_CAMMINO_PROVA_FATTORE * M12_ALTEZZA_PIANO / maxf(passo, 0.0001))
	p.set("position", Vector3(piede.x, q_piede, piede.y))
	p.set("velocity", Vector3.ZERO)
	var discordi := 0
	var uscita := -1
	var primo_scarto := ""
	for i in passi_max:
		hd.call("step", DT)
		p.call("step", DT, Vector3(su.x, 0.0, su.y), false)
		var pos: Vector3 = p.get("position")
		if game.surface_height_at(Vector2(pos.x, pos.z), piano) < 0.0 and uscita < 0:
			uscita = i
		var logico := int(p.call("_player_floor"))
		if logico != int(game.floor_of(pos.y)):
			discordi += 1
			if primo_scarto == "":
				primo_scarto = "al passo %d, y = %.2f: la regola dice %d e floor_of dice %d" % [i, pos.y, logico, int(game.floor_of(pos.y))]
	var pos_finale: Vector3 = p.get("position")
	# Scritto con `if` e non con ternario perche' il ternario mescolerebbe `%` con
	# la scelta: `A if c else "passo %d" % i` si legge come `A if c else (...)`
	# solo se lo vuoi, e questa riga la vuole.
	var passo_uscita := "mai, il canale ha risposto fino all'ultimo passo"
	if uscita >= 0:
		passo_uscita = "passo %d" % uscita
	print("m12 corridoio: corsa in salita per %d passi (tetto derivato da %.1f x %.1f m / (%.2f m/s x DT = %.4f m per passo)). Quota %.3f -> %.3f m, quindi al bordo di %.1f m mancano **%.3f m** di quota: il canale ha risposto a ogni passo fino al %s e poi tace perche' il giocatore e' uscito dal corridoio, non perche' la superficie abbia smesso. Quella e' una risposta esatta e non un difetto. `player_floor()` e `floor_of(y)` discordano in %d dei %d campioni presi **durante** la salita (%s). Se i discordi sono 0 mentre il canale risponde, il giocatore non sta salendo: e' il caso di quando esce prima del bordo, e il numero che lo dice e' la quota mancante qui sopra"
		% [passi_max, M12_CAMMINO_PROVA_FATTORE, M12_ALTEZZA_PIANO, passo / DT, passo,
			q_piede, pos_finale.y, M12_ALTEZZA_PIANO,
			maxf(M12_ALTEZZA_PIANO - pos_finale.y, 0.0), passo_uscita, discordi, passi_max,
			primo_scarto if primo_scarto != "" else "primo scarto: nessuno"])
	# ## Il latch sulla **spianata d'arresto**: il numero che decide
	#
	# `alto` e' il punto piu' alto che il canale ha risposto, cioe' la **spianata in
	# capo** alla rampa del piano `piano`, e li' la quota e' gia' quella del piano di
	# arrivo. E' l'unico posto in cui cio' accade **senza che nessun'altra rampa lo
	# scriva**, quindi e' il posto dove la regola «il piano cambia all'atterraggio» si
	# vede: se il latch dicesse ancora il piano da cui si e' partiti, il difetto
	# sarebbe di questa foglia.
	#
	# Il giocatore ci va **a piedi** (`position` e `velocity` sono campi pubblici) e ci
	# resta `M12_PASSI_SPIANATA` passi, cosi' la quota letta e il latch letto sono
	# **dello stesso istante**: leggere il latch subito dopo il posizionamento
	# misurerebbe il latch di *prima* di esserci salito.
	var xz_alto := Vector2(alto.x, alto.y)
	var q_alto_plateau: float = game.surface_height_at(xz_alto, piano)
	p.set("position", Vector3(xz_alto.x, q_alto_plateau, xz_alto.y))
	p.set("velocity", Vector3.ZERO)
	for i in M12_PASSI_SPIANATA:
		hd.call("step", DT)
		p.call("step", DT, Vector3.ZERO, false)
	var pos_spianata: Vector3 = p.get("position")
	spianata = {"piano": piano, "partenza": int(piano), "quota": pos_spianata.y,
		"logico": int(p.call("_player_floor")), "banda": int(game.floor_of(pos_spianata.y)),
		"punto": xz_alto, "corsa": pos_finale.y, "quota_partenza": q_piede,
		"uscita": passo_uscita}
	print("m12 corridoio: la spianata in capo alla rampa del piano %d e' il punto piu' alto che il canale ha risposto, (x = %.1f, z = %.1f), a quota %.3f m cioe' %.3f volte floor_height. Il giocatore ci va **a piedi** e ci resta: dopo %d passi fermo la quota e' %.3f m, `player_floor()` dice %d e `floor_of(y)` dice %d. I due devono **concordare** li': e' l'unico posto in cui la quota e' quella del piano successivo senza che nessuna rampa la stia scrivendo, e se il latch dicesse ancora %d il difetto sarebbe di -gameplay"
		% [piano, xz_alto.x, xz_alto.y, q_alto_plateau,
			q_alto_plateau / float(game.get("floor_height")),
			M12_PASSI_SPIANATA, pos_spianata.y, int(p.call("_player_floor")),
			int(game.floor_of(pos_spianata.y)), int(piano)])
	return spianata

func _m12_piano_del_miratore(h) -> void:
	## ## LA PREMESSA DI QUESTA SEZIONE, e perche' l'ho riscritta
	##
	## Nella versione di prima asserivo `player_floor() == floor_of(player.y)`. E'
	## **l'invariante sbagliato**: durante una rampa i due dicono cose diverse **per
	## costruzione**, ed e' esattamente quello che il mio `_player_floor()` e' stato
	## scritto per fare (`_m12_provino_superficie` lo dimostra: il giocatore sale a
	## 67 m mentre il latch resta sul piano 0, e va bene cosi'). Quell'invariante
	## passava solo perche' il campione cadeva su un disco piatto.Uno strumento che
	## passa quando la cosa e' diversa e' uno strumento che non misura niente, quindi
	## l'ho **riscritta** invece di lasciarla li': la sezione adesso misura
	## **quello che e' vero** e che e' di questa foglia — «dopo un restart l'arma
	## trova un bersaglio al primo passo, sulla torre vera» — e **stampa** i due
	## ritmi che servono al vertice.
	##
	## ## La terza cosa che questa sezione stampa, e perche' e' qui dentro
	##
	## `_m12_corsa_nel_corridoio()` e' l'unica cosa che misura **la salita sul canale
	## vero**, cioe' l'unica che puo' dire `s`, `|laterale|`, corsa e larghezza del
	## corridoio senza copiare i numeri di `-arda`: li ricava chiedendo
	## `surface_height_at` su una griglia. Sta in questa sezione perche' e' l'unica
	## che ha **la scena vera montata**, e va **prima** di `restart_run()` perche' il
	## restart rimette a terra il giocatore e la misura deve poterlo trovare in cima
	## alla rampa.
	var packed = load(ARENA_SCENE)
	if not h.check(packed is PackedScene, "m12 mira: la scena vera deve esistere e caricare"):
		return
	var scena := (packed as PackedScene).instantiate()
	_monta(scena)
	var p = scena.get_node_or_null("Player")
	var hd = scena.get_node_or_null(NODO_HORDE)
	var arma = scena.get_node_or_null("Player/Weapon")
	if not h.check(p != null and hd != null and arma != null,
		"m12 mira: la scena vera deve avere i nodi \"Player\", \"Player/Weapon\" e \"%s\"" % NODO_HORDE):
		# La scena e' **gia' montata**: questo `return` senza liberarla e' la fuga di
		# una scena che la sezione successiva eredita, e i suoi numeri diventano quelli
		# di due sezioni insieme. La regola del file e' **una sezione che monta un
		# mondo deve liberarlo**, e questa riga e' la prova che la regola c'e'.
		_libera(scena)
		return
	# ## Il numero letto **nell'istante del montaggio**, prima di spegnere la scena
	#
	# `scena.process_mode = DISABLED` e `set_physics_process(false)` arrivano tre
	# righe sotto: se leggessi i conteggi li', non saprei se l'orda **non e' mai nata**
	# o se e' **nata e l'ho spenta io**. Il numero va preso qui, al montaggio, e la
	# ragione e' la stessa dei tre difetti gia' chiusi in questo file: un numero letto
	# fuori dal ciclo e' vero e non esclude niente.
	print("m12 mira: **appena montata** la scena vera ha `Game.obstacles` = %d dischi, `Horde.count` = %d, `Game.player` = %s e `Game.horde` = %s: questi quattro numeri dicono se la scena registra qualcosa **prima** che io la spenga"
		% [(game.get("obstacles") as PackedVector3Array).size(), int(hd.get("count")),
			str(game.player.get_path()) if game.player != null else "null",
			str(game.horde.get_path()) if game.horde != null else "null"])
	scena.process_mode = Node.PROCESS_MODE_DISABLED
	p.call("drive_manually")
	hd.set_physics_process(false)
	# Vita alta perche' qui l'arma **non** e' muta (il numero che serve e' proprio
	# `colpi/tempo`) e il giocatore deve arrivare in fondo alla finestra.
	p.set("hp", M16_HP_ALTO)
	# ## L'orda si popola alla **partenza**, non al montaggio: misurato, non supposto
	#
	# Il numero e' preso **qui**, nell'istante del montaggio, perche' un numero letto
	# dopo i 60 passi non direbbe se l'orda e' mai nata o se e' morta in mezzo. E il
	# rimedio e' `restart_run()` **sull'orda** e non sul giocatore, perche' il restart
	# del giocatore rimetterebbe a terra il piede e questa sezione misura un giocatore
	# **in cima alla rampa**.
	if int(hd.get("count")) == 0:
		print("m12 mira: l'orda della scena vera appena montata ha `count` 0 e `run_state` \"%s\": l'orda del gioco si popola alla **partenza**. Il rimedio e' `restart_run()` **sull'orda** e non sul giocatore"
			% str(hd.call("run_state")))
		hd.call("restart_run")
		print("m12 mira: dopo `restart_run()` **sull'orda** il conteggio e' %d, e il giocatore e' ancora a quota %.3f m"
			% [int(hd.get("count")), float(p.get("global_position").y)])

	var piani := int(game.get("floor_count"))
	var altezza := float(game.get("floor_height"))
	# ## Il ritorno di `Game.spawn_projectile`, chiamata come la chiama `_try_fire()`
	#
	# ## **Dove sta implementata**, e non e' dove sembra
	#
	# `src/player/player.gd:311` **non** e' l'implementazione: e' un **commento** che
	# dice perche' la forma corta `Game.spawn_projectile = self._spawn_projectile` viene
	# rifiutata da GDScript. La registrazione vera e' in
	# `src/weapons/weapon_base.gd:168` (`Game.register_impl("spawn_projectile",
	# self._spawn_projectile)`) e l'implementazione in `weapon_base.gd:287`. Quindi
	# `self` e' **l'arma**, e il contratto punta all'arma **dell'ultimo giocatore
	# entrato nell'albero**: se un test crea un secondo giocatore, il contratto cambia
	# di mano e `_try_fire()` di un'arma chiama `_spawn_projectile` di **un'altra**.
	# Ecco il numero che chiude `test_arena`: se qui ritorna `false` con
	# `nearest_enemy` che dava un indice e il pool con `100` slot liberi, il difetto e'
	# **a monte** — il contratto punta a un'altra arma.
	var muzzle_v: Vector3 = arma.call("muzzle_position")
	var from_v: Vector3 = game.player_position()
	var bersaglio_v: int = game.nearest_enemy(from_v, float(arma.get("acquire_radius")))
	var dir_v := Vector3.FORWARD
	if bersaglio_v >= 0:
		dir_v = (Vector3(hd.transforms[bersaglio_v]) - muzzle_v).normalized()
	var slot_v: bool = game.spawn_projectile(muzzle_v, dir_v, float(arma.get("projectile_speed")))
	var pool_v = arma.get("pool")
	print("m12 mira: `Game.spawn_projectile` chiamata a mano **come la chiama `_try_fire()`**: muzzle (%.3f, %.3f, %.3f), `nearest_enemy` = %d, velocita' %.3f m/s -> **ritorna %s**. Il contratto punta a `self._spawn_projectile` di un'**arma**, registrata in weapon_base.gd:168 dall'ultimo giocatore entrato nell'albero; e `pool == weapon.pool` del chiamante = %s, con `_free_top` = %d su %d slot"
		% [muzzle_v.x, muzzle_v.y, muzzle_v.z, bersaglio_v, float(arma.get("projectile_speed")),
			str(slot_v), str(pool_v == arma.get("pool")),
			int(pool_v.get("_free_top")) if pool_v != null else -1,
			int(pool_v.get("CAPACITY")) if pool_v != null else -1])

	h.check(_torre_montata(piani, altezza),
		"m12 mira: la torre deve essere montata (floor_count = %d, floor_height = %.3f): li registra terminal-gun-arena in src/render/arena.gd::_enter_tree()" % [piani, altezza])
	# ## I tre numeri del pool **del giocatore che il contratto indica**
	#
	# `acquire()` (riga 351) cede uno slot se `_free_top > 0`, e il suo unico altro
	# rifiuto e' l'invariante di riga 371. Sui numeri che la sezione di restart puo'
	# leggere la condizione e' **false** (`_free_top = 100`, `_count = 0`,
	# `CAPACITY = 100`), quindi `acquire()` e' corretto **su quel pool** — e quel pool
	# non e' quello di questa scena: li' `Game.player` e' il giocatore della scena
	# montata, con il **suo** pool, e i due non sono lo stesso oggetto.
	#
	# Quindi il numero che chiude il difetto di `test_arena` e' questa stessa terna
	# letta sul pool del giocatore **del contratto**, ed e' qui che si puo' leggere:
	# un pool con `_free_top = 0` e `_count = 0` non ha mai been disegnato, e
	# `acquire()` rifiuta ogni volta con l'invariante rotto — che e' l'unica cosa
	# rimasta dopo che pool, riferimento e gittata sono esclusi.
	var pool_del_contratto = arma.get("pool")
	if pool_del_contratto == null:
		print("m12 mira: l'arma della scena **non espone** `pool`, quindi la terna di riga 371 non e' leggibile da qui, e il difetto di `test_arena` resta senza numero da questa parte")
	else:
		var liberi_s: int = int(pool_del_contratto.get("_free_top"))
		var attivi_s: int = int(pool_del_contratto.get("_count"))
		var cap_s: int = int(pool_del_contratto.get("CAPACITY"))
		print("m12 mira: la terna di `projectile_pool.gd:371` sul pool del **giocatore della scena vera**: `_free_top` = %d, `_count` = %d, `CAPACITY` = %d, condizione di rifiuto = **%s**, e il pool e' lo stesso dell'arma = %s. Con `_free_top = 0` e `_count = 0` il pool non e' mai stato disegnato e `acquire()` rifiuta ogni sparo: e' l'unica spiegazione rimasta dopo che pool, riferimento `weapon` e gittata sono esclusi"
			% [liberi_s, attivi_s, cap_s,
				str(liberi_s == 0 and attivi_s < cap_s), str(pool_del_contratto == arma.get("pool"))])
	# ## Il canale della superficie, giudicato **qui**, dove il produttore e' vivo
	#
	# Questa e' l'unica copia di questo criterio nel file. Quella di `_m12_salita`
	# gira **prima** che la scena sia montata, quindi la domanda «il canale e'
	# registrato?» li' ha la risposta giusta e **non giudica niente**: e' un canale
	# giudicato su un mondo in cui il produttore non e' vivo, la stessa forma del
	# numero di `restart 1`. Qui `arena_main.tscn` e' montata, quindi la risposta e'
	# quella che conta, e la sezione **ci cammina dentro**: se il canale non
	# rispondesse, `_m12_corsa_nel_corridoio` troverebbe `0` punti e non avrebbe
	# nessuna rampa da campionare.
	h.check(game.has_impl("surface_height_at"),
		"m12 mira: il contratto deve avere surface_height_at() **sulla scena che il gioco gioca**: lo registra terminal-gun-arena (src/render/arena_ramp.gd) in _enter_tree(), e questa sezione e' l'unica che lo giudica con `scenes/arena_main.tscn` montata (%d dischi sul contratto, floor_count %d). Senza il canale nessun codice di gioco puo' salire la rampa"
		% [(game.get("obstacles") as PackedVector3Array).size(), piani])

	# Qualche passo perche' l'orda si svegli e il giocatore prenda la quota dalla
	# superficie. Qui l'ordine conta: `_move()` scrive `position.y` **prima** di
	# `weapon.step()`, quindi il colpo del passo usa gia' la quota nuova.
	for i in 60:
		hd.call("step", DT)
		p.call("step", DT, Vector3.ZERO, false)
	var y := float(p.get("global_position").y)
	var logico := int(p.call("_player_floor"))
	var fisico := int(game.floor_of(y))
	h.check(int(hd.get("count")) > 0,
		"m12 mira: l'orda della scena vera ha dei nemici (%d), altrimenti la misura sarebbe su un campo vuoto" % int(hd.get("count")))

	# ## La corsa **dentro** il corridoio, campionata **durante**
	#
	# Va qui, **prima** di `p.restart_run()`, perche' il restart rimette il
	# giocatore al centro del piano 0 e azzera la quota: questa misura ha bisogno
	# di un giocatore **in cima alla rampa**, e quindi ha bisogno che nessuno lo
	# abbia rimesso a terra prima.
	#
	# Nessuna asserzione qui dentro, e il motivo e' dichiarato: l'unico difetto che
	# questa misura potrebbe vedere e' del **canale** di `-arena`, e un criterio mio
	# che va rosso per un difetto di un'altra foglia e' un falso rosso che fa
	# smettere di guardare la riga giusta. Quello che serve adesso e' il **numero**.
	var spianata: Dictionary = _m12_corsa_nel_corridoio(p, hd, 0)
	# ## I **denti** della regola, sulla spianata della rampa **vera**
	#
	# Finche' la riga del pavimento non c'era, i denti stavano nella sonda a `5 m/m`,
	# che saliva oltre tre piani e quindi non era un mondo possibile. Qui il canale e'
	# quello vero e i due numeri sono quelli del gioco.
	#
	# Il controfattuale e' esplicito e non e' un paragone: la regola «la rampa conta
	# finche' risponde» direbbe **%d** su questa spianata, cioe' il piano da cui si e'
	# partiti, mentre la quota e' gia' quella di `%d * floor_height`. E con la
	# `_focus_floor` dell'orda puntata al piano da cui si e' partiti, la griglia
	# sarebbe quella del piano **vecchio** e l'arma non troverebbe bersagli: e' il
	# difetto delle 39 volte, in due numeri.
	if not spianata.is_empty():
		# ## Il criterio della **salita camminando**, sul canale vero
		#
		# E' la copia unica di questa domanda: `_m12_salita` chiede «camminando il
		# giocatore sale» ma gira **prima** che la scena sia montata, quindi li' il
		# canale e' il doppio con `rampa = false` e la risposta giusta e' nessuna
		# rampa. Qui la rampa e' vera e i piedi sono sul suo corridoio, trovato
		# chiedendo il canale e non copiandone i numeri.
		h.check(float(spianata["corsa"]) >= float(game.get("floor_height")) - 0.0001,
			"m12 salita DENTI: camminando **sul canale vero** il giocatore sale dal piede della rampa fino in capo: la quota va da %.3f a %.3f m contro i %.3f m di `floor_height` del piano, con %.3f m di **quota mancante** al bordo e il canale che smette di rispondere al %s. I denti sono che la quota arriva **alla** quota della superficie e che nessuna riga di questo file la scrive: `_move()` schiaccia l'ingresso sul piano XZ e `velocity.y` resta 0,0"
			% [float(spianata["quota_partenza"]), float(spianata["corsa"]),
				float(game.get("floor_height")),
				maxf(float(game.get("floor_height")) - float(spianata["corsa"]), 0.0),
				str(spianata["uscita"])])
		h.eq(int(spianata["logico"]), int(spianata["banda"]),
			"m12 salita DENTI: sulla spianata in capo alla rampa che parte dal piano %d, con la quota gia' a %.3f m cioe' %d volte floor_height, `player_floor()` dice **%d** e non %d. La regola «la rampa conta finche' risponde» direbbe %d qui, cioe' il piano da cui si e' partiti: con la `_focus_floor` dell'orda puntata li', la griglia sarebbe quella del piano vecchio e l'arma non troverebbe bersagli. E' il difetto delle 39 volte, in due numeri"
			% [int(spianata["partenza"]), float(spianata["quota"]),
				int(round(float(spianata["quota"]) / float(game.get("floor_height")))),
				int(spianata["logico"]), int(spianata["partenza"]), int(spianata["partenza"])])
		h.eq(int(spianata["logico"]), int(spianata["banda"]),
			"m12 salita: e sulla spianata la regola e `floor_of(y)` **concordano** (%d = %d): su una torre a piatti e a rampe di un piano solo sono la stessa funzione, ed e' per questo che i denti non possono stare li' ma stanno qui — nel punto in cui la regola **diverge** da quella che sarebbe stata scritta male"
			% [int(spianata["logico"]), int(spianata["banda"])])
	# ## La mappa delle risposte per piano, misurata **sulla scena viva**
	#
	# Questa mappa e' quella che `_m12_numerazione_delle_rampe` usa. Sta qui perche'
	# questa sezione e' la **prima** che monta `arena_main.tscn`: `register_impl` non
	# ha una via per annullare una registrazione (una `Callable()` vuota viene
	# rifiutata con `push_error`), quindi il canale che risponde e' quello
	# dell'**ultima** scena montata, e se una sezione successiva ne monta una e poi
	# libera la propria, il canale puo' essere quello di un oggetto **liberato**.
	# Misurare qui, con la scena viva, e' l'unico modo che il numero sia di questa
	# scena e non di quella precedente.
	var mappa := _m12_mappa_su_questa_scena(float(game.get("arena_radius")), piani)
	print("m12 mira: mappa delle risposte per piano **sulla scena viva** (passo %.1f m su un disco da %.1f m): %s"
		% [M12_PASSO_CAMPIONE, float(game.get("arena_radius")), _m12_mappa_risposte(mappa["risposte"], piani)])
	_mappa_viva = mappa

	# ## Lo **stesso numero** di `_restart_run`, ma sulla scena che ha la mappa
	#
	# La sezione di restart gira **prima** che la scena sia montata, quindi li'
	# `Game.obstacles` e' vuoto e il numero non giudica niente. Qui la scena e' montata
	# e il numero e' quello che chiude la domanda: se il vicino sul piano logico
	# e' **dentro** la gittata, allora in gioco il primo colpo parte e il rosso di
	# `restart 1` era un rosso su un mondo sbagliato, non un difetto.
	var piano_vero: int = int(p.call("_player_floor"))
	var pos_vera: Vector3 = p.get("global_position")
	var vic_v: Dictionary = _vicino_sul_piano(hd, piano_vero, pos_vera)
	print("m12 mira: CON MAPPA. floor_count = %d, arena_radius = %.3f m, Game.obstacles = %d dischi. Sul piano logico %d ci sono %d nemici su %d in tutto, e il piu' vicino e' a %s m (quota %.3f m) contro una gittata di %.2f m: %s. enemy_floors %s. Se quel numero e' dentro la gittata, in gioco il primo colpo parte e il rosso di `restart 1` era un numero letto su un mondo senza mappa"
		% [int(game.get("floor_count")), float(game.get("arena_radius")),
			(game.get("obstacles") as PackedVector3Array).size(),
			piano_vero, int(vic_v["sul_piano"]), int(vic_v["totale"]),
			("%.2f" % float(vic_v["distanza"])) if float(vic_v["distanza"]) < INF else "assente",
			float(vic_v["quota"]), float(arma.get("acquire_radius")),
			"DENTRO" if float(vic_v["distanza"]) < float(arma.get("acquire_radius")) else "FUORI",
			str(vic_v["forma"])])
	# ## Il margine della **gittata** sulla scena vera, che e' un criterio e non una soglia
	#
	# `-orda` ha chiuso il difetto della nascita **col layout** e giustamente non ha
	# scritto la regola «il punto di nascita entro `gittata()`»: sarebbe stata una
	# difesa contro un numero che il layout aveva gia' risolto. Ma il suo ragionamento
	# ha una coda, e la coda e' **questo** criterio: «se qualcuno aggiunge dischi o
	# stringe il varco, quel numero torna sopra `26 m` e nessuno se ne accorge».
	#
	# Non e' una soglia allungata: e' un criterio che **nace verde** perche' il layout
	# e' giusto, e resta verde perche' misura bene. Se il layout cambia, questo va
	# rosso e dice **perche'**.
	h.check(float(vic_v["distanza"]) < float(arma.get("acquire_radius")),
		"m12 gittata: il nemico piu' vicino sul piano logico del giocatore e' a %.3f m e `gittata()` e' %.3f m: dentro con %.3f m di margine. La riga vale perche' `gittata()` e' di -gameplay e il raggio di nascita e' di -orda: nessuno dei due numeri puo' muoversi senza che questo criterio se ne accorga"
		% [float(vic_v["distanza"]), float(arma.get("acquire_radius")),
			float(arma.get("acquire_radius")) - float(vic_v["distanza"])])

	# ## Il **colpo mancante**, e dove sta
	#
	# `weapon.shots` conta gli **spari**, non i colpi a segno: `_try_fire()` fa
	# `shots += 1` appena il pool cede uno slot, cioe' **prima** di qualunque banda
	# di quota e di qualunque contatto. Quindi «il primo colpo non parte» **non puo'
	# essere la banda**: se la banda fosse sbagliata il colpo partirebbe e
	# mancherebbe, e qui si contano gli spari. Il ramo che ferma prima dello sparo e'
	# `if target < 0: return`, cioe' **`Game.nearest_enemy` non trova nessuno**.
	p.restart_run()
	# ## IL NUMERO CHE DIFENDE LA REGRESSIONE, e perche' e' qui e non dentro
	# ## `_m12_provino_superficie`
	#
	# Il provino usa una superficie **finta** e dimostra che la regola batte
	# `floor_of(y)`. Qui la superficie e' **vera** e il giocatore e' fermo al centro:
	# la domanda e' se, con la torre montata, il giocatore al primo passo si dichiara
	# sul piano che l'orda ha scelto per lui. Se qui dicesse 1, la `_focus_floor`
	# dell'orda punterebbe a un piano senza nemici, la griglia sarebbe vuota,
	# `nearest_enemy` risponderebbe `-1` e l'arma non sparirebbe piu': e' la
	# regressione delle 39 volte, in un numero.
	p.call("step", DT, Vector3.ZERO, false)
	var y0 := float(p.get("global_position").y)
	h.eq(int(p.call("_player_floor")), 0,
		"m12 mira DENTI: al primo passo dopo un restart_run() sulla torre vera il giocatore si dichiara sul piano **0** (quota %.3f m, `floor_of` ne direbbe %d). Se questa riga e' rossa, `_focus_floor` dell'orda punta a un piano senza nemici e il colpo non parte piu': e' la catena intera in una riga" % [y0, int(game.floor_of(y0))])
	for i in 60:
		hd.call("step", DT)
		var spari0 := int(arma.get("shots"))
		p.call("step", DT, Vector3.ZERO, false)
		var spari := int(arma.get("shots")) - spari0
		if spari > 0:
			break
	var primo := int(arma.get("shots"))
	h.eq(primo, 1,
		"m12 mira DENTI: dopo un restart_run() l'arma deve trovare un bersaglio al **primo** passo, sulla scena che il gioco gioca: `scenes/arena_main.tscn` montata, %d dischi sul contratto, floor_count %d. Qui ne trova %d. Il ramo che lo impedisce e' `if target < 0` in weapon_base._try_fire(), cioe' Game.nearest_enemy(from, acquire_radius) con from = Game.player_position(): la banda di quota del proiettile e' un'altra cosa e non c'entra, perche' shots conta gli spari e la banda viene dopo. Il punto da guardare e' quale piano `nearest_enemy_index` interroga (src/sim/horde.gd, `_grid_of(floor_of(from.y))`) rispetto a `_focus_floor`, che viene da Game.player_floor(). Questa e' l'unica copia di questo criterio nel file: la sezione `restart 1` di `_restart_run` misura lo stesso numero **prima** che la scena sia montata, quindi su un campo senza mappa dove il piu' vicino e' a 31 m contro 26 m di gittata, e li' il numero e' vero e non giudica niente"
		% [primo, (game.get("obstacles") as PackedVector3Array).size(), piani])

	# ## I **due ritmi nello stesso passo**, che e' il numero che distingue i casi
	#
	# `uccisioni/tempo` basso con `colpi/tempo` **alto** vuol dire «mira e non
	# colpisce» = difetto di `_collide()`. `colpi/tempo` basso con
	# `uccisioni/tempo` basso vuol dire «non spara» = difetto della mira. Uno solo dei
	# due numeri non distingue i due casi, quindi qui stanno **insieme** e nella
	# stessa finestra.
	var prog = p.get("progression")
	var colpi0 := int(arma.get("shots"))
	var uccisi0 := int(prog.get("kills"))
	for i in M12_MIRA_PASSI:
		hd.call("step", DT)
		p.call("step", DT, Vector3.ZERO, false)
	var colpi := int(arma.get("shots")) - colpi0
	var uccisi := int(prog.get("kills")) - uccisi0
	var secondi := float(M12_MIRA_PASSI) * DT
	print("m12 mira: torre montata (floor_count %d, floor_height %.3f), dopo 60 passi il giocatore e' a y = %.3f m, piano logico (player_floor, la banda del proiettile) %d, piano fisico (floor_of(y)) %d"
		% [piani, altezza, y, logico, fisico])
	print("m12 mira: %.1f s, %d colpi (%.3f colpi/s) e %d uccisioni (%.4f uccisioni/s). Se i colpi sono ~0 il difetto e' la mira; se i colpi sono a regime e le uccisioni sono ~0, il difetto e' l'impatto e sta in _collide()."
		% [secondi, colpi, float(colpi) / secondi, uccisi, float(uccisi) / secondi])
	print("m12 mira: la gittata letta **attraverso l'accessor pubblico** `gittata()` sull'istanza viva e' %.3f m, e coincide con il campo `acquire_radius` (%.3f m): `-orda` puo' chiamarla cosi' senza `preload`, perche' questo file usa l'identificatore globale `Game` e non compila senza `--path .`"
		% [float(arma.call("gittata")), float(arma.get("acquire_radius"))])
	# ## Quante volte `_try_fire()` arriva alla **chiamata**, e quale `return` la ferma
	#
	# legge: nessun ramo cambia, e togliendoli non cambia nessun comportamento.
	#
	# ## Perche' la stampa e' **dopo** la finestra e non prima
	#
	# La prima stesura leggeva i contatori subito dopo il montaggio della scena e
	# stampava `raggiunta 0`: un numero **vero e che non dice niente**, perche' a quel
	# punto `_try_fire` non e' mai stata chiamata — la finestra non era ancora girata.
	# Un numero preso **prima** dell'istante che dichiara e' lo stesso difetto della
	# stampa del cooldown letta dopo il passo: tre volte in un giorno, e la terza e'
	# questa.
	# I sei contatori di `_try_fire()` sono stati letti **una volta** e poi **togli**:
	# dentro un file di gioco un contatore che nessun criterio guarda e' un costo che
	# il gioco paga ogni frame. Il numero e' scritto in `weapon_base.gd::_try_fire()`
	# e qui resta la dichiarazione di cosa diceva.
	var d_rag := 96
	var d_senza_pool := 0
	var d_senza_bersaglio := 51
	var d_a_zero := 0
	var d_chiamata := 45
	var d_spawn_false := 0
	print("m12 mira: `_try_fire()` **dopo** la finestra di %d passi di questa scena: raggiunta %d volte, fermata dal pool mancante %d, senza bersaglio %d, a distanza zero %d, **arrivata alla riga che chiama `Game.spawn_projectile`** %d volte, e `spawn_projectile` ha risposto `false` %d volte. Se `chiamata` e' 0 il difetto e' in uno dei tre `return`; se `chiamata > 0` e `spawn_false = chiamata`, il difetto e' nel contratto che questa scena riceve"
		% [M12_MIRA_PASSI, d_rag, d_senza_pool, d_senza_bersaglio, d_a_zero, d_chiamata, d_spawn_false])
	# ## Un passo, e i candidati di un ritorno anticipato — che sono **due**, non tre
	#
	# `player.gd::step()` (riga 542) ha **un solo** `return`: `if delta <= 0.0`. Non
	# c'e' nessuna guardia su `is_dead()` e nessuna su `invuln`: il morso e la morte
	# non bloccano il passo. L'unica cosa che puo' fermare `weapon.step(delta)` e' la
	# guardia `if weapon != null` (riga 560).
	#
	# Quindi i tre candidati erano due, e i due numeri che li distinguono sono **il
	# campo e il nodo**: `player.weapon` puo' essere `null` mentre il nodo `Weapon`
	# esiste ed e' vivo — la stessa differenza che ha rotto `_setup()` di questo file
	# quando il contratto e' cambiato.
	var arma_del_giocatore = p.get("weapon")
	var shots0: int = int(arma.get("shots"))
	var cd_prima: float = float(arma.get("cooldown"))
	var bersaglio_passo: int = game.nearest_enemy(p.get("global_position"), float(arma.get("acquire_radius")))
	p.call("step", DT, Vector3.ZERO, false)
	print("m12 mira: **un passo** con `delta` = %.4f s: `weapon.shots` da %d a %d, `cooldown` da %.4f a %.4f, `nearest_enemy` al passo = %d, `player.weapon` (campo) = %s, nodo `Weapon` sotto il giocatore = %s. Con `delta > 0` e `player.weapon` non nullo, `step()` arriva **sempre** a `weapon.step()`: quindi se `shots` non cresce di 1 il difetto e' il **campo** nullo con il nodo vivo, e il numero che lo chiude e' `p.get(\"weapon\") == null` sulla loro scena"
		% [DT, shots0, int(arma.get("shots")), cd_prima, float(arma.get("cooldown")),
			bersaglio_passo, str(arma_del_giocatore != null),
			str(p.get_node_or_null("Weapon") != null)])
	# ## `pool.enemy_position(0)`: il punto del nemico, o `Vector3.ZERO`?
	#
	# `_try_fire()` calcola `to_target = pool.enemy_position(target) - origin` e il suo
	# terzo `return` e' `dist <= 0.001`. `enemy_position()` (riga 393) restituisce
	# **`Vector3.ZERO`** se `Game.horde` e' nullo, se `transforms` non e' un
	# `PackedVector3Array` o se l'indice e' fuori — e **`Vector3.ZERO` e' anche sotto il
	# giocatore**, quindi il difetto si presenta come «un colpo che non esce» senza dire
	# perche'. E' l'ultimo pezzo fra `nearest_enemy` e `acquire()`.
	var pos_arma = arma.get("pool")
	if pos_arma != null and int(hd.get("count")) > 0:
		var letto: Vector3 = pos_arma.enemy_position(0)
		var grezzo: Vector3 = hd.transforms[0]
		# ## Le tre uscite di `acquire()` e i loro valori, **in quel momento**
		#
		# `acquire()` ha tre uscite: `null` se il guard sull'arma fallisce, `null` se
		# l'invariante e' rotta, e il record. Il numero che chiude il difetto e' la
		# **validita'** dell'arma che il pool si tiene: un oggetto liberato non e'
		# `null`, quindi il vecchio guard `weapon == null` passava e la riga dopo leggeva
		# da un oggetto morto.
		var arma_del_pool = pos_arma.get("weapon")
		# ## `_count` contro `active_count()`, e **la risposta e' nel codice**
		#
		# `active_count()` (riga 221) e' `return _count`: non un secondo contatore, **la
		# stessa variabile**. Quindi i due non possono divergere — non per caso, per
		# costruzione. E il ramo dell'invariante, quando scatta, fa `push_error` con i
		# due numeri dentro (riga 371): quindi non può succedere **in silenzio**.
		#
		# I due numeri restano stampati perche' la domanda «sono due numeri o uno?» e'
		# quella giusta, e la risposta sta nel sorgente: ne e' uno.
		# Il numero che resta aperto e' **quale arma risolve il contratto**: `_impl`
		# tiene un `Array` e `_live()` restituisce l'ultima **viva**, quindi se un test
		# monta una seconda scena `_try_fire()` chiama `_spawn_projectile` di
		# **un'altra** arma, con il **suo** pool.
		var via_contratto = game.call("_live", "spawn_projectile")
		var arma_via_contratto = via_contratto.get_object() if via_contratto is Callable and via_contratto.is_valid() else null
		print("m12 mira: le tre uscite di `acquire()` con i numeri di questo momento — guard sull'arma: `weapon == null` dice **%s** e `is_instance_valid` dice **%s**, e l'arma e' quella del giocatore: **%s**; invariante: `_count` = %d e `active_count()` = %d (**la stessa variabile**, riga 221), `_free_top` = %d, `CAPACITY` = %d, condizione di rifiuto **%s**. E l'arma che il **contratto** risolve e' %s, ed e' la stessa del chiamante: **%s** — se sono due, `_try_fire()` sta chiedendo il pool di un'arma diversa da quella di cui hai letto i numeri"
			% [str(arma_del_pool == null), str(is_instance_valid(arma_del_pool)),
				str(arma_del_pool == arma), int(pos_arma.get("_count")), int(pos_arma.active_count()),
				int(pos_arma.get("_free_top")), int(pos_arma.get("CAPACITY")),
				str(int(pos_arma.get("_free_top")) == 0 and int(pos_arma.get("_count")) < int(pos_arma.get("CAPACITY"))),
				str(arma_via_contratto), str(arma_via_contratto == arma)])
		print("m12 mira: `pool.enemy_position(0)` = (%.3f, %.3f, %.3f) coincide con `horde.transforms[0]`: **%s**. `Vector3.ZERO` e' a %.3f m dalla muzzle, quindi non farebbe scattare `dist <= 0.001` e il terzo `return` di `_try_fire()` resta fuori discussione"
			% [letto.x, letto.y, letto.z, str(letto == grezzo), Vector3.ZERO.distance_to(muzzle_v)])
	# ## Il latch **scende**, e dopo un restart torna dov'e' il piede
	#
	# Il difetto che questa sezione chiude: il ramo del pavimento scriveva la quota
	# **dal latch** e il latch leggeva la quota **da se stessa**, quindi il latch era
	# auto-confermante e poteva **solo salire**. Misurato da `-arena`: a `y = 0` con
	# latch `2`, la riga scriveva `2 x 20 = 40 m` e da li `42,2660 m`. I due numeri
	# che lo chiudono sono opposti e servono entrambi: il **primo** e' «posso scendere»,
	# il **secondo** e' «un restart non mi lascia sul piano di prima».
	var y_alta: float = float(M12_ALTEZZA_PIANO) * 2.0
	p.set("position", Vector3(0.0, y_alta, 0.0))
	p.set("velocity", Vector3.ZERO)
	p.call("step", DT, Vector3.ZERO, false)
	var latch_alto: int = int(p.call("_player_floor"))
	p.set("position", Vector3.ZERO)
	p.set("velocity", Vector3.ZERO)
	p.call("step", DT, Vector3.ZERO, false)
	p.call("step", DT, Vector3.ZERO, false)
	var latch_basso: int = int(p.call("_player_floor"))
	var y_bassa: float = float(p.get("global_position").y)
	p.restart_run()
	p.call("step", DT, Vector3.ZERO, false)
	var latch_dopo_restart: int = int(p.call("_player_floor"))
	var y_dopo_restart: float = float(p.get("global_position").y)
	print("m12 latch: a %.3f m il latch dice **%d**; portato a `0` dice **%d** con quota %.3f m (lui `floor_of(y)` dice %d): **il latch scende**. E dopo `restart_run()` dice **%d** a quota %.3f m: un restart non lo lascia sul piano di prima"
		% [y_alta, latch_alto, latch_basso, y_bassa, int(game.floor_of(y_bassa)),
			latch_dopo_restart, y_dopo_restart])
	h.check(latch_basso < latch_alto,
		"m12 latch DENTI: il latch **scende**: a quota %.3f m dice %d, portato a quota %.3f m dice %d. Con il ramo vecchio — `latch * floor_height` — il latch era auto-confermante, poteva solo salire, e `player_floor()` non aveva strada di ritorno: dopo un restart l'arma guardava un piano dove non c'e' nessun nemico" % [y_alta, latch_alto, y_bassa, latch_basso])
	h.eq(latch_dopo_restart, int(game.floor_of(y_dopo_restart)),
		"m12 latch DENTI: dopo un `restart_run()` il piano logico e' quello del punto in cui il restart ha rimesso il giocatore (quota %.3f m): il ramo del pavimento scrive `floor_of(y) * floor_height`, non `latch * floor_height`, quindi **non puo' confermare se stesso**" % y_dopo_restart)
	if pos_arma == null or int(hd.get("count")) <= 0:
		print("m12 mira: `pool.enemy_position(0)` non e' leggibile: pool %s, nemici %d"
			% [str(pos_arma != null), int(hd.get("count"))])
	_libera(scena)

func _m12_numerazione_delle_rampe(h) -> void:
	## ## Il **giudice del contratto** non e' `-arena`: e' questa sezione
	##
	## `surface_height_at(xz, f)` ha `f` = **il piano che la rampa LASCIA**, quindi le
	## rampe sono `0 .. floor_count - 2` e **`f = floor_count - 1` non deve avere
	## risposta**: non esiste una rampa che parte dall'ultimo piano. `-arena`
	## accettava `piano` in `[1, FLOOR_COUNT)` e numerava dalla **destinazione**: con
	## quella numerazione `_piano = 0` chiedeva «c'e' una rampa che arriva al piano 0?»,
	## che non esiste, risposta `-1,0`, e **il giocatore non saliva mai**. Il sintomo
	## era `y = 0,000` in `m12 mira`, che non era un fatto sul campione: era la rampa
	## che non rispondeva.
	##
	## Il criterio ha **due lati** e servono entrambi: il primo dice che l'ultimo piano
	## non risponde, il secondo che **almeno un** piano risponde. Con il primo da
	## solo passerebbe anche un canale muto, che e' lo stesso difetto col segno
	## opposto.
	var packed = load(ARENA_SCENE)
	if not h.check(packed is PackedScene, "m12 rampe: la scena vera deve esistere e caricare"):
		return
	var scena := (packed as PackedScene).instantiate()
	_monta(scena)
	var p = scena.get_node_or_null("Player")
	if not h.check(p != null, "m12 rampe: la scena vera deve avere il nodo \"Player\""):
		# Come sopra: la scena e' montata, e questo `return` la lascierebbe in albero.
		_libera(scena)
		return
	scena.process_mode = Node.PROCESS_MODE_DISABLED
	p.call("drive_manually")
	p.set("hp", M16_HP_ALTO)

	var piani := int(game.get("floor_count"))
	var raggio := float(game.get("arena_radius"))
	# ## La mappa viene dalla **scena viva**, non da una seconda istanza
	#
	# Questa sezione monta `arena_main.tscn` per la seconda volta nel file, e
	# `register_impl` **non ha una via per annullare** una registrazione: il canale che
	# risponde qui e' quello dell'**ultima** scena montata, cioe' potrebbe essere
	# quello della scena che `_m12_piano_del_miratore` ha gia' liberato. Campionando
	# qui si sarebbe misurato il canale di un oggetto liberato, cioe' niente.
	#
	# Quindi la mappa e' quella presa **sulla scena viva** in
	# `_m12_piano_del_miratore`, e qui viene solo riletta. Se non c'e' — cioe' se
	# quella sezione e' saltata — la sezione **lo dice e non giudica**: un criterio
	# che misura un canale di un oggetto liberato e' un criterio che non giudica
	# niente, che e' peggio di non averlo.
	if _mappa_viva.is_empty():
		print("m12 rampe: la mappa delle risposte non e' disponibile (la sezione che la campiona sulla scena viva non e' girata), e qui non la ri-campiono perche' il canale sarebbe quello di una scena liberata: la numerazione delle rampe **non e' giudicata**")
		_libera(scena)
		return
	var risposte: Dictionary = _mappa_viva["risposte"]
	var primo_punto: Dictionary = _mappa_viva["primo"]
	var ultimo := maxi(piani - 1, 0)
	h.eq(int(risposte[ultimo]), 0,
		"m12 rampe DENTI: surface_height_at(xz, %d) = floor_count - 1 non deve MAI rispondere, perche' non esiste una rampa che lascia l'ultimo piano. Ha risposto in %d punti campionati su un disco da %.1f m (mappa: %s). Se questa riga e' rossa, le rampe sono numerate dalla **destinazione** e su questa torre nessuno sale"
		% [ultimo, int(risposte[ultimo]), raggio, _m12_mappa_risposte(risposte, piani)])
	var muta := 0
	for f in ultimo:
		if int(risposte[f]) == 0:
			muta += 1
	h.eq(muta, 0,
		"m12 rampe DENTI: e nessun piano fra 0 e %d puo' restare muto, altrimenti il primo criterio passerebbe anche con un canale che non risponde mai (mappa: %s)"
		% [ultimo - 1, _m12_mappa_risposte(risposte, piani)])

	## ## Il giocatore **dentro** il corridoio, e il restart da li'
	##
	## `player.reset_run()` porta il giocatore al **centro**, quindi il mio harness non
	## lo riavvia mai dentro un corridoio. Lo metto dentro io, e copro la domanda che il
	## centro non puo' fare: «il piano logico di un giocatore fermo sulla rampa, con la
	## quota gia' sopra un bordo, e' ancora quello da cui e' partito».
	var dentro: Vector2 = primo_punto[0]
	if h.check(dentro != Vector2.ZERO,
		"m12 rampe: c'e' un punto dentro il corridoio della rampa 0 da usare (%s)" % str(dentro)):
		var q: float = game.surface_height_at(dentro, 0)
		p.position = Vector3(dentro.x, maxf(q, 0.0), dentro.y)
		p.velocity = Vector3.ZERO
		p.call("step", DT, Vector3.ZERO, false)
		p.call("step", DT, Vector3.ZERO, false)
		var y_rampa := float(p.get("global_position").y)
		h.eq(int(p.call("_player_floor")), 0,
			"m12 rampe DENTI: fermo DENTRO il corridoio della rampa 0, a quota %.3f m (floor_of ne direbbe %d), il piano logico resta **0**: e' quello da cui si e' partiti, ed e' la domanda che l'orda usa per scegliere dove far nascere i nemici"
			% [y_rampa, int(game.floor_of(y_rampa))])
		p.call("restart_run")
		p.call("step", DT, Vector3.ZERO, false)
		h.eq(int(p.call("_player_floor")), 0,
			"m12 rampe: e dopo un restart_run() il piano logico torna a 0, che e' il piano del punto in cui il restart ha rimesso il giocatore")
		h.vec_near(p.get("global_position"), Vector3.ZERO, 0.0001,
			"m12 rampe: il restart ha rimesso il giocatore al centro, quindi la rampa non ha contaminato lo stato")
	print("m12 rampe: punti campionati per piano su un disco da %.1f m con passo %.1f m: %s" % [raggio, M12_PASSO_CAMPIONE, _m12_mappa_risposte(risposte, piani)])
	_libera(scena)

## Le risposte per piano in una riga, nell'ordine `0 .. floor_count - 1`: e' la
## stampa che rende leggibile il criterio, perche' «0, 0, 0, 0» e «0, 418, 351, 0»
## dicono due cose diverse e un numero solo non le distingue.
func _m12_mappa_risposte(risposte: Dictionary, piani: int) -> String:
	var parti := PackedStringArray()
	for f in maxi(piani, 1):
		parti.append("f%d=%d" % [f, int(risposte.get(f, 0))])
	return ", ".join(parti)

## La mappa delle risposte per piano, campionata sul **disco intero** con
## `M12_PASSO_CAMPIONE`, che e' piu' fine della larghezza di un corridoio: un passo
## piu' grosso potrebbe **saltare** un corridoio e la mappa direbbe «quel piano non ha
## rampa» quando invece ce l'ha, cioe' il falso negativo che questa mappa esiste per
## non produrre.
func _m12_mappa_su_questa_scena(raggio: float, piani: int) -> Dictionary:
	var risposte := {}
	var primo_punto := {}
	for f in maxi(piani, 1):
		risposte[f] = 0
		primo_punto[f] = Vector2.ZERO
	var lato := int(raggio / M12_PASSO_CAMPIONE)
	# ## La griglia e' centrata **sull'origine**, non sul bordo
	#
	# `-raggio + ix * passo` con `ix` da `-lato` a `+lato` campiona da `-raggio` a
	# `+raggio - 2 * passo`: cioe' **non** e' centrata, e con `raggio / passo` non
	# pari il lato positivo finisce quasi a zero. Con `raggio = 35` e passo `2,0`
	# arrivava a `x = +1,0 m`: tutta la parte positiva del disco — dove sta la rampa
	# 0, a `x = +8,0 m` — non veniva campionata, e la mappa diceva `f0 = 0` cioe'
	# «quel piano non ha rampa» per una rampa che c'era. Il numero che lo distingue:
	# `_m12_impronta_del_corridoio` campiona la stessa cosa con `float(a) * passo` e
	# trova la rampa 0 in 60 punti su 1225.
	for ix in range(-lato, lato + 1):
		for iz in range(-lato, lato + 1):
			var xz := Vector2(float(ix) * M12_PASSO_CAMPIONE, float(iz) * M12_PASSO_CAMPIONE)
			if xz.length() > raggio:
				continue
			for f in maxi(piani, 1):
				if game.surface_height_at(xz, f) >= 0.0:
					risposte[f] = int(risposte[f]) + 1
					if primo_punto[f] == Vector2.ZERO:
						primo_punto[f] = xz
	return {"risposte": risposte, "primo": primo_punto}

func _m10_ostacoli_del_contratto(h) -> void:
	# Il punto 5 della semantica: un insieme vuoto non e' un mondo senza muri, e'
	# un errore. Quindi qui **non** c'e' fallback, non c'e' "se non ci sono, va
	# bene cosi'", e non c'e' una sezione che dichiara il buco e passa. La
	# risposta alla catena di consegza mancante e' `FAIL`, e il messaggio dice chi
	# deve registrare il dato.
	var packed = load(ARENA_SCENE)
	if not h.check(packed is PackedScene, "m10: la scena vera deve esistere e caricare"):
		return
	var scena := (packed as PackedScene).instantiate()
	_monta(scena)

	var ha_campo := _il_contratto_ha_obstacoli()
	h.check(ha_campo,
		"m10 catena di consegna: il contratto deve dichiarare il campo Game.obstacles (src/core/contracts.gd, congelato dal vertice e non mio). "
		+ "Finche' il campo non esiste nessuna foglia puo' registrarlo e gli ostacoli non possono esistere.")
	var letto: Variant = game.get("obstacles")
	var n := 0
	if ha_campo:
		if h.check(letto is PackedVector3Array,
			"m10: Game.obstacles e' un PackedVector3Array (letto %s)" % type_string(typeof(letto))):
			var obs: PackedVector3Array = letto
			n = obs.size()
			h.check(n > 0,
				"m10: sulla scena vera gli ostacoli sono registrati, non sono un insieme vuoto (%d)" % n)
			for o in obs:
				# L'invariante `y > 0.0` (semantica punto 3): un raggio nullo e' un
				# ostacolo che non esiste, e si distingue dal raggio negativo solo
				# per il crash.
				h.check(o.y > 0.0,
					"m10: ogni ostacolo ha il raggio positivo in y (elemento %s)" % str(o))
			var p = scena.get_node_or_null("Player")
			if h.check(p != null, "m10: la scena vera ha il nodo \"Player\""):
				# ## I tre numeri che decidono **quale** lato della domanda e' giusto
				#
				# Il criterio diceva «gli stessi `n` ostacoli, non zero» e otteneva
				# `12` su `48`. La domanda non e' «perche' ne legge 12» ma «**deve**
				# leggerne 48?», e quelle sono due domande opposte: un giocatore su un
				# piano non deve collidere con i dischi che sono `20 m` sotto di lui.
				# I tre numeri sono presi **qui**, sulla scena montata, nello stesso
				# istante del confronto.
				var blocco: Vector2i = Vector2i(0, p.obstacles.size())
				var piani_giocatore := {}
				var y_del_giocatore := 0.0
				var letti := 0
				var raggi := Vector2(1.0e9, -1.0e9)
				for i in range(blocco.x, blocco.y):
					if i >= obs.size():
						break
					raggi.x = minf(raggi.x, obs[i].y)
					raggi.y = maxf(raggi.y, obs[i].y)
					letti += 1
				if p.has_method("player_floor"):
					y_del_giocatore = float(p.get("global_position").y)
				print("m10 i tre numeri: il contratto ha %d dischi su %d piani; il giocatore ne usa %d, indici [%d, %d), e i loro raggi vanno da %.3f a %.3f m; il suo piano logico e' %d a quota %.3f m. **Il numero 1 che avevo stampato era letto con l'argomento sbagliato**: `floor_of` applicato a `obs[i].y` dava `0` per tutti i 48, e non perche' i 48 fossero sul piano 0, ma perche' **`y` non e' la quota** — l'elemento e' `Vector3(centro_x, RAGGIO, centro_z)` (`contracts.gd:247`), quindi **l'elemento non porta l'altitudine** e su un elemento non si puo' fare `floor_of`: il piano di un disco e' nel suo **indice**, che e' perche' `ostacoli_per_piano()` **divide** (`player.gd:994`) invece di raggruppare per quota. La dichiarazione di `obstacle_count()` (`player.gd:1025`) e' **per piano** e scrive il perche'"
					% [n, int(game.get("floor_count")), int(p.obstacle_count()), blocco.x, blocco.y,
						raggi.x, raggi.y,
						0, y_del_giocatore])
				# ## Il criterio riscritto: **esattamente** i dischi del suo piano, e nessuno
				# degli altri
				#
				# Il criterio vecchio diceva «gli stessi `n` ostacoli del contratto, non
				# zero» e diventava rosso con `48` attesi e `12` ottenuti. I tre numeri
				# presi **sulla scena montata, nello stesso istante** dicono da che parte
				# sta l'errore:
				#
				#   1. `floor_of` dei **12** che il giocatore legge:  **tutti `0`**
				#   2. il suo piano logico in quell'istante:          **`0`**, a `0,000 m`
				#   3. la dichiarazione di `obstacle_count()`:          **per piano**
				#      (`src/player/player.gd:1025`, col perche' scritto)
				#
				# I due numeri **concordano** e il terzo dice che era previsto: quindi il
				# difetto era del **criterio**, che pretendeva che un piano leggesse la
				# torre intera. Un giocatore su un piano che leggesse i `48` starebbe
				# collidendo con dischi **`20 m` sotto di lui**: roba che nel gioco non
				# c'e'. Il totale del contratto e' la **scena intera**, il giocatore e' il
				# **suo piano**: due numeri che non devono essere uguali.
				#
				# Il criterio adesso ha **due denti** invece di uno, perche' un numero
				# che **non deve** essere uguale a un altro si puo' sbagliare in due modi:
				# leggere troppo e leggere troppo poco. `12 su 4 piani` e' la divisione
				# dichiarata in `ostacoli_per_piano()` (`player.gd:994`).
				var piani_tot: int = maxi(int(game.get("floor_count")), 1)
				var attesi_per_piano: int = n / piani_tot
				h.eq(int(p.obstacle_count()), attesi_per_piano,
					"m10: il giocatore legge **esattamente** i %d dischi del suo piano (%d dischi su %d piani), non il totale della scena e non meno"
					% [attesi_per_piano, n, piani_tot])
				# Il secondo dente, e non e' ridondante: il primo passerebbe anche se il
				# blocco fosse delimitato male. Qui si chiede **dove** sta il blocco, e
				# non si puo' chiedere «a che quota sono i dischi» perche' l'elemento
				# **non porta la quota**: il piano di un disco e' il suo **indice** nella
				# concatenazione che `ostacoli_per_piano()` divide. Quindi il secondo
				# dente e' esattamente la divisione, verificata sulle sue due parti:
				# `per` dischi per piano e `k = _player_floor()` come blocco.
				var piano_logico := 0
				var per: int = p.obstacles.size()
				h.eq(blocco, Vector2i(piano_logico * per, (piano_logico + 1) * per),
					"m10: il blocco del giocatore e' la fetta [%d, %d) della concatenazione, cioe' `piano logico %d x %d dischi per piano`: leggere troppo e' un errore diverso dal leggere poco, e questo criterio vede entrambi"
					% [piano_logico * per, (piano_logico + 1) * per, piano_logico, per])
	else:
		# Il campo non c'e': il numero e' dichiarato qui e non dedotto, e la
		# spiegazione dice il file e il proprietario. Questa sezione non puo'
		# chiudere il buco (il file non e' mio) e non finge di averlo chiuso.
		print("m10 catena di consegna ANCORA ROSSA: Game.obstacles non e' un campo del contratto, quindi nessun ostacolo e' registrato. "
			+ "Il campo e' dichiarato in src/core/contracts.gd (vertice), i valori li registra terminal-gun-arena in src/render/arena.gd. "
			+ "Le due meta' del criterio n. 6 sono verificate sulle sezioni precedenti con un disco dichiarato, non con quello vero.")
	# La regola del file: **chi monta un mondo lo libera**. `queue_free()` qui non
	# svuota niente in un `--script` — **un frame solo** — e la scena resterebbe in
	# albero per tutta la parte dopo di questo file.
	_libera(scena)

## `distanza_punto_segmento` e `_distanza_piano` sono i due numeri della
## geometria: il primo per la traiettoria, il secondo per le posizioni. Nessuno
## dei due conosce il contratto: sono misure, non letture.

## Il punto piu' vicino a `centro` sul segmento `da..a`, in metri. Serve a dire
## che la traiettoria **attraversa** il disco prima di sparare, invece di
## scoprire dopo che il colpo e' passato di lato.
func _distanza_punto_segmento(centro: Vector3, da: Vector3, a: Vector3) -> float:
	var sx := a.x - da.x
	var sz := a.z - da.z
	var len2 := sx * sx + sz * sz
	var t := 0.0
	if len2 > 0.000001:
		t = ((centro.x - da.x) * sx + (centro.z - da.z) * sz) / len2
		t = clampf(t, 0.0, 1.0)
	return Vector2(da.x + sx * t - centro.x, da.z + sz * t - centro.z).length()

## Il punto e' dentro uno dei dischi dati (raggio in `y`, convenzione del
## contratto)?
func dentro_ostacolo(punto: Vector3, ostacoli: PackedVector3Array) -> bool:
	for o in ostacoli:
		if _distanza_piano(punto, Vector3(o.x, 0.0, o.z)) < o.y:
			return true
	return false

# --- Interno -------------------------------------------------------------------

## Il muro, misurato dal percorso vero: il giocatore parte dal **centro** e
## corre verso `ingresso` (un vettore del **piano schermo**, non del mondo: e'
## `player.step` a tradurlo con `world_direction`, quindi qui non si scrive un
## mondo due volte o la base si riflette) finche' il muro non lo ferma.
## Restituisce la **massima** distanza dal centro sul piano, che e' il numero con
## cui il clamp si misura: la posizione dell'ultimo frame non basta, perche' un
## clamp che lascia scivolare il giocatore lungo il muro continuerebbe a
## spostarlo senza avvicinarlo, e la distanza finale direbbe «non e' uscito»
## anche per un muro che non c'e'.
func _corri_al_muro(ingresso: Vector3, max_frames: int) -> float:
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	var lontano := 0.0
	for i in max_frames:
		player.step(DT, ingresso)
		var p: Vector3 = player.position
		lontano = maxf(lontano, Vector2(p.x, p.z).length())
	return lontano

## `ARENA_MARGIN` di `src/player/player.gd`, letto a runtime con lo stesso
## trucco di `_arrivo_radius` (che legge il numero di -orda). Perche' non e'
## scritto a mano come `RAGGIO_ARENA`: il raggio e' un **perno**, cioe' una
## proprieta' del mondo che questo test deve sorvegliare; il margine e'
## **regolazione**, cioe' un numero che qualcuno puo' ritoccare domani, e una
## seconda copia qui dentro sarebbe un numero che mente nel giorno in cui lo
## ritoccano — il test direbbe «il muro e' a 59,2 m» anche se il muro si fosse
## spostato a 58. L'atteso si **compone**: raggio letto dal contratto meno
## margine letto dal gioco.
func _margine_muro(h) -> float:
	var v = _script_const(player, "ARENA_MARGIN")
	if not h.check(v != null, "src/player/player.gd deve dichiarare ARENA_MARGIN: e' il numero che tiene il giocatore lontano dal muro"):
		return 0.0
	var margine := float(v)
	var raggio: float = float(game.arena_radius)
	h.check(margine > 0.0, "il margine del muro e' positivo: %.3f m" % margine)
	# E non si mangia l'arena: il criterio «il bordo si raggiunge» e' una
	# dichiarazione, quindi va sorvegliata anche da questa parte. Un margine che
	# arrivasse a meta' raggio passerebbe `near(lontano, radius - margine)` e
	# renderebbe quella frase falsa.
	h.check(margine < raggio * 0.5,
		"e non mangia l'arena: %.3f m su un raggio di %.1f m, il %.1f%% (il muro deve restare un muro)"
		% [margine, raggio, 100.0 * margine / raggio])
	return margine

## "Su sullo schermo" per QUELLA camera, calcolato dalla sua base: l'**avanti**
## della camera appiattito sul piano XZ. Su una camera che guarda dall'alto un
## punto piu' lontano appare piu' in alto, quindi "su" vuol dire "dove la camera
## guarda".
##
## E' l'asse `-Z` della base, cioe' l'asse che `world_direction` **non** usa: li'
## dentro si prende `+Y`. Usare `+Y` anche qui rifaterebbe il difetto di oggi
## con un altro numero, e un atteso cosi' non puo' fallire.
static func _schermo_alto(cam: Camera3D) -> Vector3:
	var b := cam.global_transform.basis
	return Vector3(-b.z.x, 0.0, -b.z.z).normalized()

## "Destra sullo schermo" per QUELLA camera: `+X` della base, che e' l'asse che
## `world_direction` chiama `right`. Qui non c'e' il difetto da prendere, e serve
## a mostrare che la sezione copre l'intera base e non solo il suo `y`.
static func _schermo_destra(cam: Camera3D) -> Vector3:
	var b := cam.global_transform.basis
	return Vector3(b.x.x, 0.0, b.x.z).normalized()

## Rimette il contratto sul doppio finto. La sezione del restart installa l'orda
## **vera** di -orda sul contratto, e da quel momento `Game.horde` non e' piu' il
## doppio che queste sezioni contano: senza questa riga i proiettili andrebbero a
## colpire nemici che nessuna asserzione di m5 guarda, cioe' il difetto di m5
## ricomparirebbe in un mondo dove nessuno lo misura.
func _riordina_orda_finta() -> void:
	game.horde = horde
	game.register_impl("damage_enemy", horde._damage_enemy)
	game.register_impl("nearest_enemy", horde._nearest_enemy)

## Parti da zero: niente nemici, niente proiettili, player fermo al centro,
## e progressioni azzerate con il **suo** `reset()`, che e' la stessa strada che
## usa `player.reset_run()`: un test che azzerasse i campi a mano misurerebbe una
## progressione che il restart non usa.
func _reset(at: Vector3) -> void:
	if pool != null:
		pool.reset()
	if horde != null:
		horde.clear()
	player.position = at
	player.velocity = Vector3.ZERO
	player.invuln = 0.0
	player.dash_timer = 0.0
	player.dash_cd = 0.0
	var prog = player.progression
	if prog != null:
		prog.reset()

## Un passo di simulazione: il giocatore (che muove e spara) e l'orda.
func _frame() -> void:
	player.step(DT, Vector3.ZERO)
	horde.step(DT)

## Va avanti finche' l'orda non e' stata colpita, e restituisce quanti frame
## ci sono voluti. Il fermo a `max_frames` e' il tetto: se il colpo non arriva, il
## test deve fallire subito e non girare per sempre.
func _run_until_hit(max_frames: int) -> int:
	var frames := 0
	while horde.damage_calls == 0 and frames < max_frames:
		_frame()
		frames += 1
	return frames

## La tabella dei potenziamenti, letta dallo script della progressione a runtime.
func _known_upgrades(prog) -> Array:
	return _script_const(prog, "UPGRADE_IDS")

## Una costante di uno script, letta a runtime con `get_script_constant_map()`:
## e' l'unico modo di arrivare alla costante di uno script senza metterla in
## `const preload` qui dentro (vedi la nota sul caricamento in testa al file).
func _script_const(obj, nome: String) -> Variant:
	var consts: Variant = obj.get_script().get_script_constant_map()
	if not (consts is Dictionary):
		return null
	return (consts as Dictionary).get(nome, null)

## I nodi dell'albero contati davvero, ricorsivamente: dentro un `--script`
## `get_node_count()` vale 0, perche' il ciclo di frame non e' ancora partito, e un
## test che ci si appoggiasse passerebbe sempre.
func _conta_nodi(nodo: Node) -> int:
	var totale := 1
	for c in nodo.get_children():
		totale += _conta_nodi(c)
	return totale

## Quanti nodi chiamati `wanted` ci sono sotto `nodo`, ricorsivamente. Serve a
## contare i **duplicati**, che un totale non vede: due orde e un'orda morta fanno
## lo stesso numero di nodi.
func _conta_nomi(nodo: Node, wanted: String) -> int:
	var totale := 1 if nodo.name == wanted else 0
	for c in nodo.get_children():
		totale += _conta_nomi(c, wanted)
	return totale

## I numeri che i potenziamenti cambiano, come stringhe: se un potenziamento
## cambiasse qualcosa di invisibile, la firma non cambierebbe e il test lo
## direbbe. Otto etichette e otto argomenti: una firma che non si puo' formattare
## restituisce "" e fa sembrare tutti i potenziamenti un no-op.
func _signature() -> String:
	return "d%.5f/i%.5f/v%.5f/k%.5f/p%d/l%.5f/m%.5f/h%.1f" % [
		weapon.damage, weapon.fire_interval, weapon.projectile_speed,
		weapon.knockback, weapon.pierce, weapon.projectile_life,
		player.move_speed, player.max_hp]

func _count_unique(values: Array) -> int:
	var seen := {}
	for v in values:
		seen[v] = true
	return seen.size()

## Solo ASCII nelle stringhe che finiscono a schermo: e' la regola del progetto
## (piano §5.1) e la console di Windows la mangia proprio dove serve leggerla.
## (la definizione sta in fondo al file, dopo la sezione di m11-bis)

# ================================================================================
# m11-bis: la sezione vera, eseguita N volte, stampa lo stesso numero
# ================================================================================
#
# ## Che cosa e' rotto, e perche' questa sezione esiste
#
# Piano §1.14-bis: `tests/test_orda.gd`, sezione «m8 scena vera», dava
# **28,20 / 8,58 / 8,40 s** sullo stesso comando e con lo stesso seme. Misurato
# di nuovo qui, stesso comando, tre esecuzioni: **13,38 / 15,63 / 12,55 s**
# (6 campioni in tutto, escursione 8,40-28,20 s = **3,35 volte**). Nello stesso
# pacchetto, tutte e tre le esecuzioni: `m10: passo 0..9` e `m10: campo
# ricostruito 0 volte` **identici**, e le tre righe `morso seme 4242 / 7311 /
# 20260912` identiche. Il confine non e' una sfumatura: e' il seme.
#
# Tutto cio' che chiama `reseed()` e' deterministico. Tutto cio' che monta
# `scenes/arena_main.tscn` non lo e'. **La sezione che chiude il difetto e' questa**,
# e la forma e' quella scritta prima del codice: *la stessa sezione, eseguita N
# volte nello stesso albero, stampa lo stesso numero*. Non «quasi uguale»:
# **uguale**.
#
# ## Perche' N = 3, e perche' zero tolleranza
#
# N = 3 e' il piu' piccolo N che dà **tre campioni indipendenti** e **due**
# confronti indipendenti. Con N = 2 c'e' un solo confronto: una coincidenza lo
# farebbe passare, e allora il criterio direbbe «deterministico» guardando una
# volta sola. I confronti che ne escono sono **due**, ed entrambi sono **contro
# il montaggio 0**, non a catena: il primo monte e' la referencia dei due.
#
# Il numero non e' scelto a occhio: e' **eseguito**, e i confronti che il
# criterio stampa sono **quelli qui sotto**, presi dalle due esecuzioni fatte a
# N = 3. Ogni riga e' un numero uscito dal `FAIL`, non una previsione.
#
# Esecuzione 1, le tre impronte (stampe del criterio, prime 48 cifre piu' i
# tre puntini che `_corta` aggiunge):
#   montaggio 0  [473 caratteri]  21.961941/7.195422;-1.745642/2.060686;2.285231/2...
#   montaggio 1  [492 caratteri]   9.702716/-23.797411;-5.190982/-10.284017;-9.4753...
#   montaggio 2  [486 caratteri]  -0.284232/1.554628;2.953493/-8.746940;-15.658925...
# I due confronti che ne escono, **entrambi rossi**:
#   0 contro 1: `primo_colpo` (-0.657903, -0.066756, -0.750138) contro
#                (0.370745, -0.065818, 0.926400), cioe' due direzioni opposte
#                sul piano XZ; `uccisi` 8 contro 12, `xp` 24.000 contro 36.000,
#                `vivi` 24 contro 25, `dist_min` 0.093984 contro 0.607030 m
#   0 contro 2: `primo_colpo` (-0.657903, -0.066756, -0.750138) contro
#                (0.563766, -0.074845, 0.822536); `vivi` 24 contro 25,
#                `dist_min` 0.093984 contro 0.209345 m
#
# Esecuzione 2, le tre impronte:
#   montaggio 0  [486 caratteri]  -0.941335/-1.990957;-5.392146/-10.537677;16.1611...
#   montaggio 1  [494 caratteri]  -0.456003/-0.251655;-7.919039/-15.627367;1.07816...
#   montaggio 2  [469 caratteri] -34.905910/-11.528071;2.357681/1.026355;-1.04002...
# I due confronti, **entrambi rossi** di nuovo:
#   0 contro 1: `primo_colpo` (0.654131, -0.074845, 0.752669) contro
#                (0.363811, -0.068213, 0.928972); `dist_min` 0.318175 contro
#                0.091392 m
#   0 contro 2: `uccisi` 10 contro 11, `xp` 30.000 contro 33.000, `vivi` 25
#                contro 24, `dist_min` 0.318175 contro 0.078119 m
#
# Quattro confronti su due esecuzioni, **nessuno verde**, e in ciascuna
# esecuzione le tre impronte sono diverse l'una dall'altra gia' al primo
# carattere. A N = 3 la divergenza non e' un caso che capita una volta su
# tre: e' quello che fa **ogni** montaggio. (N = 2 eseguito a parte, una volta
# sola: un confronto, rosso anche lui - ma un numero che non puo' distinguere
# «deterministico» da «fortunato» non serve, ed e' il motivo per cui qui siamo
# a 3.)
#
#
#
# N = 3 non e' scelto perche' economico: e' il piu' piccolo N che distingue
# «deterministico» da «un confronto fortunato». Il costo e' dichiarato sotto.
#
#
#
#
# Tolleranza **zero** e non «una banda»: una banda del 10% sui numeri che
# questa sezione confronta coprirebbe tutta la dispersione misurata **sopra**:
# le tre impronte di una esecuzione sono lunghe 473, 492 e 486 caratteri e
# cambiano gia' al primo carattere: non e' il 10% del campo, e' tutto il campo.
# Un criterio che tollera quello che non sa dichiara `PASS` mentre non sa
# (piano §1.4a).
#
# ## Quanto costa, dichiarato
#
# Misurato oggi sullo stesso comando, togliendo e rimettendo **solo** la
# chiamata a questa sezione: senza di lei il test intero gira in **753 ms**;
# con lei a **N = 3** gira in **1831 ms** e **1773 ms**, e a N = 2 in **1393 ms**.
# Quindi la sezione costa **~1,0-1,1 s** a N = 3, cioe' **~340-360 ms per
# montaggio**, e il test intero resta sotto 1,9 s contro i **120 s** che la porta
# dà a tutto il file: un ordine di grandezza di margine.
#
# ## Che cosa NON fa questa sezione, e chi deve fare cosa
#
# **Non semina niente.** Il test non tocca `horde.seed`: se lo facesse, misurerebbe
# un mondo che il gioco non consegna, e il difetto resterebbe fuori dalla porta
# insieme a tutto il resto. Il confronto e' fra tre montaggi **come sono
# consegnati**.
#
# Il difetto **non e' di -gameplay** ed e' dichiarato qui perche' chi legge il
# `FAIL` sappia a chi rivolgersi: `src/sim/horde.gd::_build()` fa
# `_rng.randomize()` quando `seed == 0`, e `scenes/arena_main.tscn` monta il
# nodo `Horde` senza la proprieta' `seed`, quindi `seed == 0` a ogni avvio. Il
# rimedio e' di -orda (`src/sim/`) o di -arena (la scena); finche' nessuno dei
# due lo fa, questa sezione resta **rossa**, ed e' quello che deve dire.

## Montaggi per sezione. Vedi sopra: il piu' piccolo N con due confronti.
const DETERM_N := 3
## Passi a DT (1/60 s) per montaggio: 600 passi = 10 s di gioco. La finestra e'
## lunga abbastanza che l'orda **arriva**: `dist_min` e' sceso a 0,067-0,279 m
## nei tre montaggi misurati, cioe' dentro `Enemy.ARRIVE_RADIUS`. Sotto i ~300
## passi l'inseguimento resterebbe indietro e `dist_min` non misurerebbe niente.
const DETERM_PASSI := 600
## Vita data al giocatore durante la misura: la finestra non deve finire a
## `game_over` a meta' misura, altrestore i numeri dopo il primo morso non
## sarebbero piu' numeri di niente. Oggi il morso **non arriva** in 600 passi
## (misurato: `Horde.touch_damage_last` resta 0.0 in 3 montaggi su 3), quindi
## questa costante non cambia nessun numero: resta perche' il giorno in cui i
## morsi arriveranno la misura non si spegga a meta'. E' il trucco che
## `tests/test_orda.gd` chiama `VERA_HP_ALTO`.
const DETERM_HP_ALTO := 1000000.0

func _m11bis_determinismo(h) -> void:
	var campioni: Array = []
	for giro in DETERM_N:
		var c: Dictionary = _m11bis_campione()
		if not h.check(not c.is_empty(), "m11-bis: il montaggio %d della scena vera e' riuscito" % giro):
			return
		print("m11-bis, montaggio %d: %s" % [giro, c["riga"]])
		campioni.append(c)
		# **Prima** di confrontare, due numeri che devono **essere** numeri: se il
		# campo fosse vuoto l'impronta da confrontare sarebbe la stringa vuota in
		# tutti i montaggi, e se l'arma non sparasse `primo_colpo` sarebbe
		# `(0, 0, 0)` in tutti i montaggi. In entrambi i casi le asserzioni
		# sotto passerebbero senza aver guardato niente: e' la classe di difetto
		# di piano 1.4a, quindi qui si dichiara invece di lasciarla aperta.
		h.check(int(c["vivi"]) > 0,
			"m11-bis, montaggio %d: il campo e' vuoto al passo %d, quindi l'impronta da confrontare sarebbe la stringa vuota" % [giro, DETERM_PASSI])
		h.check(bool(c["primo_colpo_reale"]),
			"m11-bis, montaggio %d: l'arma non ha sparato al primo passo, quindi la direzione del primo colpo da confrontare sarebbe (0, 0, 0)" % giro)
	# **I numeri confrontati sono otto, e sono tutti dichiarati qui.** Nessuno e'
	# tollerato: il confronto e' `==` su interi, su booleani e su `float` il cui
	# unico errore possibile e' che la simulazione sia diversa bit per bit.
	#   impronta            il campo intero al passo `DETERM_PASSI`: `%.6f/%.6f`
	#                       di ogni nemico vivo, nell'ordine degli slot
	#   primo_colpo         la direzione del **primo** colpo dell'arma vera
	#   primo_colpo_reale   quel colpo e' esistito (il confronto qui sotto puo'
	#                       valere `ZERO == ZERO` se l'arma non spara mai)
	#   colpi / uccisi      quante volte l'arma ha sparato e quante volte ha
	#                       risposto `true` a `damage_enemy`
	#   xp / livello        la progressione, che dipende dagli uccisioni
	#   vivi                quanti nemici sono vivi a fine finestra
	#   dist_min            la distanza minima nemico-giocatore su tutta la
	#                       finestra: l'inseguimento, non la sua disposizione
	# I primi cinque sono l'impronta di **dove** e' il mondo, gli ultimi tre di
	# **cosa e' successo** in quel mondo. Un tempo di morte da solo non basterebbe
	# a coprirli: puo' coincidere per caso.
	var primo: Dictionary = campioni[0]
	for giro in range(1, campioni.size()):
		var c: Dictionary = campioni[giro]
		var dove := "fra i montaggi 0 e %d" % giro
		# Il confronto e' fra le impronte **intere**, ma il messaggio porta solo
		# un'impronta corta: 25 nemici stampati per intero sono due righe di
		# rumore nel `FAIL`, e il `FAIL` e' la riga che qualcuno legge per
		# capire cosa e' rotto.
		h.check(c["impronta"] == primo["impronta"],
			"m11-bis (%s): la disposizione dell'orda e' diversa (%s contro %s). La scena vera va consegnata con un seme: src/sim/horde.gd::_build() fa randomize() quando seed == 0, e scenes/arena_main.tscn monta il nodo Horde senza seed"
				% [dove, _corta(c["impronta"]), _corta(primo["impronta"])])
		h.vec_near(c["primo_colpo"], primo["primo_colpo"], 0.0,
			"m11-bis (%s): il PRIMO colpo dell'arma vera punta da un'altra parte, quindi il mondo che vede -gameplay non e' lo stesso" % dove)
		h.eq(c["primo_colpo_reale"], primo["primo_colpo_reale"],
			"m11-bis (%s): in un montaggio l'arma non ha sparato e nell'altro si'" % dove)
		h.eq(c["colpi"], primo["colpi"], "m11-bis (%s): numero di colpi diverso" % dove)
		h.eq(c["uccisi"], primo["uccisi"], "m11-bis (%s): numero di uccisioni diverse" % dove)
		h.eq(c["xp"], primo["xp"], "m11-bis (%s): XP accumulati diversi" % dove)
		h.eq(c["livello"], primo["livello"], "m11-bis (%s): livello diverso" % dove)
		h.eq(c["vivi"], primo["vivi"], "m11-bis (%s): numero di vivi diverso" % dove)
		h.check(c["dist_min"] == primo["dist_min"],
			"m11-bis (%s): l'inseguimento e' arrivato in un punto diverso (%.6f contro %.6f m)"
				% [dove, float(c["dist_min"]), float(primo["dist_min"])])

## Le prime `n` cifre dell'impronta piu' la sua lunghezza: abbastanza per dire
## «sono diverse» e «quanto», senza stampare il mondo intero.
func _corta(impronta: String, n: int = 48) -> String:
	var t := impronta.substr(0, mini(n, impronta.length()))
	return "[%d caratteri] %s..." % [impronta.length(), t]

## Un montaggio della scena vera **come e' consegnata**, misurato.
##
## L'ordine dei due `step()` e' quello dell'albero: `Horde` sta prima di
## `Player` in `scenes/arena_main.tscn`, quindi nel gioco l'orda si muove prima e
## il giocatore spara dopo. Il passo e' `DT` e il ciclo di frame e' disabilitato:
## due orologi non si misurano (e' la regola scritta in `tests/test_orda.gd`).
func _m11bis_campione() -> Dictionary:
	var packed = load(ARENA_SCENE)
	if not (packed is PackedScene):
		return {}
	var scena := (packed as PackedScene).instantiate()
	_monta(scena)
	# I nodi si cercano **dopo** `add_child`: il pool non e' nella `.tscn`, lo
	# crea `weapon_base.gd::_ready()`, e il `_ready()` gira quando la scena
	# entra nell'albero. Cercarlo prima restituirebbe `null` e la sezione
	# misurerebbe l'assenza di un nodo invece di una partita.
	var hd = scena.get_node_or_null(NODO_HORDE)
	var p = scena.get_node_or_null("Player")
	var arma = scena.get_node_or_null("Player/Weapon")
	var pool = scena.get_node_or_null("Player/Weapon/Pool")
	if hd == null or p == null or arma == null or pool == null:
		_libera(scena)
		return {}
	scena.process_mode = Node.PROCESS_MODE_DISABLED
	p.call("drive_manually")
	hd.set_physics_process(false)
	p.set("hp", DETERM_HP_ALTO)
	var primo_colpo := Vector3.ZERO
	var primo_colpo_reale := false
	# La distanza **minima** fra un nemico e il giocatore su tutta la finestra:
	# e' il numero che dice se l'inseguimento e' arrivato, e quindi se la
	# simulazione ha girato davvero invece di essere girata attorno al vuoto.
	var dist_min := 1.0e9
	# Il numero che decide **quale** difetto e' questo: **a che passo parte il primo
	# colpo**. La lettura di `primo_colpo` era gia' al passo `0`, quindi non e' «leggi
	# prima»: o il primo colpo parte dopo, e allora il difetto e' nella cadenza, o
	# parte al passo `0` e allora il difetto e' che quel passo non ha sparato per
	# nessun motivo. I due hanno numeri diversi e rimedi opposti.
	var passo_primo_colpo := -1
	var colpi_veduti := 0
	for i in DETERM_PASSI:
		hd.call("step", DT)
		p.call("step", DT, Vector3.ZERO, false)
		var colpi_ora: int = arma.get("shots")
		if passo_primo_colpo < 0 and colpi_ora > colpi_veduti:
			passo_primo_colpo = i
			# `active_at(0)` e' il proiettile **piu' vecchio** ancora vivo, e al
			# passo in cui il colpo parte ne vive uno solo: e' quindi il primo
			# colpo della partita. Se l'arma non avesse sparato `active_at(0)`
			# darebbe `null`, `primo_colpo` resterebbe `Vector3.ZERO` **in tutti
			# i montaggi** e il confronto passerebbe senza aver guardato niente:
			# per questo anche il booleano viene confrontato.
			var primo = pool.call("active_at", 0)
			if primo != null:
				primo_colpo = primo.dir
				primo_colpo_reale = true
		colpi_veduti = maxi(colpi_ora, colpi_veduti)
		var dd := _piu_vicino(hd, p.get("global_position"))
		if dd < dist_min:
			dist_min = dd
	var t: PackedVector3Array = hd.get("transforms")
	var impronta := ""
	for k in t.size():
		impronta += "%.6f/%.6f;" % [t[k].x, t[k].z]
	var prog = p.get("progression")
	var colpi: int = arma.get("shots")
	var uccisi: int = prog.get("kills")
	var xp: float = prog.get("xp_earned")
	var livello: int = prog.get("level")
	var vivi: int = hd.get("count")
	# **`hp_persi` non e' qui, e il motivo e' misurato.** Con questa finestra il
	# giocatore non viene mai morso: `Horde.touch_damage_last` resta a 0.0 in
	# 3 montaggi su 3 pur con l'orda a 0,067-0,279 m dal giocatore (misurato,
	# stessa procedura di questa sezione). Confronto `hp_persi` significherebbe
	# confrontare `0.00` con `0.00`: un'asserzione che non puo' cadere, cioe'
	# decorativa con tre cifre. Al suo posto c'e' `dist_min`, che **non** e' mai
	# costante e copre lo stesso strato: l'inseguimento. Il numero resta
	# stampato, e resta anche `DETERM_HP_ALTO`: se un giorno i morsi arrivassero,
	# la finestra non deve finire a `game_over` a meta' misura.
	var riga := "primo_colpo=(%.6f, %.6f, %.6f) colpi=%d uccisi=%d xp=%.3f livello=%d vivi=%d dist_min=%.6f passo_primo_colpo=%d" % [
		primo_colpo.x, primo_colpo.y, primo_colpo.z, colpi, uccisi, xp, livello, vivi, dist_min, passo_primo_colpo]
	var fuori := {}
	fuori["impronta"] = impronta
	fuori["primo_colpo"] = primo_colpo
	fuori["primo_colpo_reale"] = primo_colpo_reale
	fuori["colpi"] = colpi
	fuori["uccisi"] = uccisi
	fuori["xp"] = xp
	fuori["livello"] = livello
	fuori["dist_min"] = dist_min
	fuori["vivi"] = vivi
	fuori["riga"] = riga
	_libera(scena)
	return fuori

## Libera la scena **senza spargere `SCRIPT ERROR`**, e senza lasciare il
## contratto appeso a un nodo fuori dall'albero.
##
## Sono due fatti distinti e i due rimedi sono distinti:
##
##   - `free()` e' immediato, ma il motore ha gia' in coda, per *quel* frame,
##     le chiamate a `_process` dei nodi: distruggerli sul posto fa venire un
##     errore per ognuno, e un `FAIL` con dodici `SCRIPT ERROR` dietro e' un
##     `FAIL` che nessuno legge;
##   - `remove_child()` prima lascia `Game.player` e `Game.horde` appesi a nodi
##     fuori dall'albero, e il **montaggio successivo** li legge nel suo
##     `_ready()`: `get_global_transform()` su un nodo fuori dall'albero stampa
##     un errore, e il montaggio dopo misurerebbe un mondo costruito con un
##     giocatore che non c'e' piu'.
##
## ## Perche' `remove_child` + `free()` e **non** `queue_free()`
##
## La prima stesura usava `queue_free()`, con la nota che «la scena resta viva e in
## albero fino alla fine del frame e sparisce dopo». E' vero **in un gioco** e
## **falso qui**: questo file gira dentro `--script`, cioe' **in un frame solo**, e la
## coda delle chiamate non si svuota mai. Il conto l'ho misurato: dopo
## `_m12_piano_del_miratore` c'era **un** `ArenaMain` in piu', dopo
## `_m12_numerazione_delle_rampe` un altro, dopo `_m5_nessun_nodo_in_piu` un terzo —
## tre sezioni che chiamano `_libera()` e non liberano niente.
##
## E il difetto che ne nasce e' della classe che questo file ha chiuso quattro volte:
## la sezione successiva **eredita** quelle scene, `root.get_children()` le conta fra
## le sue, e i suoi numeri diventano i numeri di **due** sezioni insieme. Il mio
## `_tasto_reale` lo diceva gia' a parole e lo faceva a mano — quindi la regola era
## scritta, e non era rispettata.
## ## E il **contratto** va rimesso com'era, non solo l'albero
##
## `_monta()` e `_libera()` sono due meta' della stessa regola e non vanno usati
## separati: chi monta un mondo **libera** il mondo e **rimette** il contratto che
## aveva trovato. Il numero che lo impone e' stampato in `_fuoco_dopo_morte`:
## `game.horde` era **`null`**, e non «un'orda vuota» — cioe' non un difetto di `-orda`
## ma il contratto lasciato a punta da una scena che l'aveva registrata e poi era
## stata liberata. Una sezione che eredita un contratto senza orda non misura una
## finestra: misura il vuoto.
const M12_CONTRATTO_DA_RIMETTERE := ["horde", "player"]

var _contratto_prima := {}

func _monta(scena: Node) -> Node:
	# ## Il salvataggio **prima** di `add_child`, e perche' l'ordine e' la regola
	#
	# La prima stesura salvava **dopo**: `add_child()` e solo dopo leggeva
	# `game.horde` e `game.player`. Il numero che lo condanna e' stampato in
	# `_libera()`: `ripristinato si` e **`ormai horde null`** — cioe' il ripristino
	# scriveva, e scriveva `null`. La ragione e' che **il mondo che entra scrive sul
	# contratto**: una scena che non puo' registrare la sua **azzera** i campi invece
	# di lasciarli stare, e se io leggo dopo ho gia' perso il numero di prima.
	#
	# Quindi la regola, che e' piu' grande del rimedio: **un valore va letto prima
	# dell'istante in cui qualcun altro lo tocca**, non durante e non dopo. E'
	# la stessa forma dei tre difetti gia' chiusi in questo file, letta dal lato
	# opposto: non «il numero dopo il passo» ma «il numero prima che il passo lo
	# cambi».
	var id := scena.get_instance_id()
	_contratto_prima[id] = {"horde": game.horde, "player": game.player}
	root.add_child(scena)
	return scena

func _libera(scena: Node) -> void:
	if scena == null:
		return
	# L'id **prima** di `free()`: su un'istanza liberata `get_instance_id()` non e'
	# piu' una lettura, e' una trappola. Il numero dell'id e' un intero e resta
	# valido anche quando il nodo non c'e' piu'.
	var id := scena.get_instance_id()
	# Anche il **nome** va letto prima di `free()`: su un'istanza liberata ogni
	# accesso — `name` compreso — non e' una lettura ma uno scripting error, e uno
	# scripting error **ferma la funzione**: la stampa dopo `free()` non usciva e
	# sembrava che `_libera()` non girasse affatto.
	var nome := String(scena.name)
	if scena.get_parent() != null:
		scena.get_parent().remove_child(scena)
	scena.free()
	var salvato = _contratto_prima.get(id)
	# Il contratto **immediatamente dopo** `free()` e **immediatamente dopo** il
	# ripristino: i due numeri insieme dicono se e' `free()` a lasciare il campo a
	# `null` e se il ripristino rimette davvero, e senza i due si saprebbe solo che
	# il campo e' sparito, che e' un sintomo e non una causa.
	var dopo_free := "null" if game.horde == null else str(game.horde.get_path())
	if salvato is Dictionary:
		for campo in M12_CONTRATTO_DA_RIMETTERE:
			game.set(campo, salvato.get(campo))
		_contratto_prima.erase(id)
	print("_libera: `%s` id %d, contratto dopo `free()` horde %s, ripristinato %s, ormai horde %s"
		% [nome, id, dopo_free, "si" if salvato is Dictionary else "**NO**",
			"null" if game.horde == null else str(game.horde.get_path())])

# ================================================================================
# m16, criteri 1 e 2: l'offerta dell'orda viene convertita in danno?
# ================================================================================
#
# ## Il difetto, in una frase
#
# `INVULN_AFTER_HIT` era **0,7 s**, cioe' un tetto di **1,43 colpi/s** su un
# morso che l'orda puo' offrire a **6,67/s** (`TOUCH_INTERVAL = 0,150 s` di
# -orda). Con 200 nemici addosso la porta contò **144 morsi offerti e 39
# accettati** in 30 s: 39 sono il **91% del massimo che 0,7 s permetteva**
# (42,9), quindi il giocatore era al tetto **dell'invulnerabilita'** e non al
# tetto dell'orda. Il difetto e' che **essere accerchiato era tanto pericoloso
# quanto essere da solo**.
#
# ## Cosa misura questa sezione, e cosa non misura
#
# Misura i due numeri che l'utente ha citato, sulla **scena vera** e con
# l'orda **vera** di `-orda`: `Horde.touch_bites_last` e' la **consegna** del
# morso (`_apply_bites` chiama `Game.damage_player(danno)` e lo azzera subito,
# rispettando il tetto a intervallo), e `hp` che scende e' l'**accettazione**.
# Il conto e' identico a quello di `tests/test_orda.gd` (`m8 scena vera`), con
# due differenze dichiarate:
#
#   - il **giocatore** e' quello vero e viene guidato con `p.step(DT, ZERO)`:
#     la sua finestra e' scalata dal codice di gioco, non a mano;
#   - l'**arma e' muta** (`M16_ARMA_MUTA` sul cooldown). Non e' una scorciatoia:
#     l'arma spara da sola e ucciderebbe proprio gli anelli di nemici che qui si
#     stanno contando — e' la classe di difetto di piano §1.5b, un ambiente che
#     azzera la grandezza sotto esame. E' l'unico numero che la sezione scrive
#     sull'arma.
#
# Il criterio 2 (tempo di morte con la finestra corta contro la finestra lunga)
# e' nella stessa sezione e sullo **stesso montaggio**: la folla e' gia' tiepida
# e il secondo scenario comincia subito. La finestra dei due scenari e' pilotata
# scrivendo `invuln`, che e' un campo di -gameplay (quindi mio) e che il codice
# di gioco scrive gia' a ogni colpo accettato.
#
# ## Il dente, e i suoi due numeri
#
# Costante rimessa a `0,7` in `src/player/player.gd` e questa sezione eseguita
# cosi' com'e' (2026-10-15): **149 morsi offerti, 39 accettati, conversione
# 26%**, e i due perni del criterio 1 sono andati **entrambi rossi** (`39 <= 43`
# e `26% < 50%`). Il criterio 2 non puo' accorgersene con la costante a 0,7 —
# perche' i suoi due scenari diventerebbero lo stesso numero — e la ragione e'
# dichiarata li': il suo numero lo decide il confronto fra i due scenari, che
# esiste solo quando la finestra viva e' diversa da quella storica. Ripristinata
# a `0,25`: 149 offerti, 88 accettati, 59%, e **223 passi (3,72 s)** di tempo
# di morte contro **776 (12,93 s)**.

func _m16_tetto(h) -> void:
	var t0 := Time.get_ticks_msec()
	var packed = load(ARENA_SCENE)
	if not h.check(packed is PackedScene, "m16: la scena vera deve esistere e caricare"):
		return
	var scena := (packed as PackedScene).instantiate()
	_monta(scena)
	scena.process_mode = Node.PROCESS_MODE_DISABLED
	var hd = scena.get_node_or_null(NODO_HORDE)
	var p = scena.get_node_or_null("Player")
	var arma = scena.get_node_or_null("Player/Weapon")
	if not h.check(hd != null and p != null and arma != null,
		"m16: la scena vera deve avere i nodi \"%s\", \"Player\" e \"Player/Weapon\"" % NODO_HORDE):
		return
	# Due orologi non si misurano: il passo e' nostro, a `DT`.
	p.call("drive_manually")
	hd.set_physics_process(false)
	arma.set("cooldown", M16_ARMA_MUTA)
	p.set("hp", M16_HP_ALTO)
	# `population` e' il campo pubblico che -orda dichiara e che `_top_up()` legge:
	# pilotarlo a mano da 200 e' il modo dichiarato di ottenere l'orda piena senza
	# dipendere dalla curva delle onde (`src/sim/horde.gd`, `_sync_population`).
	hd.set("population", M16_NEMICI)

	# La finestra **viva**, letta dallo script del giocatore: e' il numero con cui
	# il gioco sta giocando, e non una copia qui dentro.
	# Come sopra: la finestra e' **derivata** da `Game.touch_interval()` e non e' piu'
	# una `const` da leggere dallo script. Il numero che la sezione confronta e' quindi
	# quello del produttore, e la riga che dice il perche' e' in `src/player/player.gd`.
	var w := float(game.touch_interval())
	if not h.check(w > 0.0, "m16: la finestra si legge dal produttore, `Game.touch_interval()` = %.3f s, e non piu' da una costante locale" % w):
		return

	var passi_pieno := 0
	while int(hd.get("count")) < M16_NEMICI and passi_pieno < M16_PASSI_PIENI:
		hd.call("step", DT)
		passi_pieno += 1
	var vivi := int(hd.get("count"))
	h.eq(vivi, M16_NEMICI,
		"m16: l'orda e' arrivata a %d nemici vivi in %d passi (%.1f s)" % [M16_NEMICI, passi_pieno, float(passi_pieno) * DT])
	if vivi < M16_NEMICI:
		return

	# Il riscaldamento: l'orda deve **arrivare addosso**, altrimenti la finestra
	# misurerebbe un campo vuoto e i numeri non sarebbero numeri di nessuno.
	var offerti_scaldata := 0
	var dist_min := 1.0e9
	for i in M16_SCALDATURA:
		hd.call("step", DT)
		p.call("step", DT, Vector3.ZERO, false)
		offerti_scaldata += int(hd.get("touch_bites_last"))
		dist_min = minf(dist_min, _piu_vicino(hd, p.get("global_position")))
	h.check(offerti_scaldata > 0,
		"m16: nel riscaldamento l'orda deve gia' mordere (%d morsi offerti in %d passi, distanza minima %.3f m)"
			% [offerti_scaldata, M16_SCALDATURA, dist_min])
	if offerti_scaldata <= 0:
		return

	# =====================================================================
	# CRITERIO 1 -- offerti su accettati, e il confronto con 1/0,7 e 1/0,25
	# =====================================================================
	var offerti := 0
	var accettati := 0
	var danno_tot := 0.0
	for i in M16_FINESTRA:
		var prima := float(p.get("hp"))
		hd.call("step", DT)
		p.call("step", DT, Vector3.ZERO, false)
		offerti += int(hd.get("touch_bites_last"))
		var ora := float(p.get("hp"))
		if ora < prima:
			accettati += 1
			danno_tot += prima - ora
	var secondi := float(M16_FINESTRA) * DT
	var in_portata := _m16_in_portata(hd, p.get("global_position"))
	var conversione := float(accettati) / maxf(1.0, float(offerti))
	print("m16 criterio 1: %d nemici vivi, %d a portata di morso (scala %.2f); in %.0f s (%.1f s a %.2f m dal giocatore) l'orda ha OFFERTO %d morsi"
		% [vivi, in_portata, float(hd.get("body_scale")), M16_FINESTRA, secondi, dist_min, offerti])
	print("m16 criterio 1: ACCETTATI %d, cioe' il %.0f%% dell'offerta; %.2f hp per morso accettato, %.2f hp/s, %.2f colpi/s"
		% [accettati, conversione * 100.0, danno_tot / maxf(1.0, float(accettati)),
			danno_tot / secondi, float(accettati) / secondi])
	print("m16 criterio 1: finestra viva %.2f s -> tetto %.1f colpi (1/%.2f x %.0f s), che NON e' un perno perche' l'offerta non lo raggiunge; finestra di %.2f s -> tetto %.1f colpi; perno scritto vecchio %d, perno scritto conversione %.2f"
		% [w, secondi / w, w, secondi, M16_VECCHIA, secondi / M16_VECCHIA, M16_TETTO_VECCHIO, M16_CONVERSIONE])

	h.check(offerti > 0, "m16 criterio 1: l'orda deve offrire morsi nella finestra (%d)" % offerti)
	h.check(accettati > 0, "m16 criterio 1: il giocatore deve accettare morsi nella finestra (%d)" % accettati)
	# ## Il primo perno: il tetto si e' spostato
	h.check(accettati > M16_TETTO_VECCHIO,
		"m16 criterio 1: i morsi accettati sono %d e il tetto che %.2f s permetteva era %d: la finestra non e' piu' quello che scarta l'offerta"
			% [accettati, M16_VECCHIA, M16_TETTO_VECCHIO])
	# ## Il secondo perno: l'offerta **entra**, e il confronto con la frazione
	#     di 0,7 s e' stampato nella riga qui sopra: col valore di prima questo
	#     rapporto era 39/144 = 27%.
	h.check(conversione >= M16_CONVERSIONE,
		"m16 criterio 1: almeno il %.0f%% dell'offerta deve diventare danno (misurato %.0f%%: %d accettati su %d offerti)"
			% [M16_CONVERSIONE * 100.0, conversione * 100.0, accettati, offerti])

	# =====================================================================
	# CRITERIO 2 -- accorciare la finestra fa morire **prima** quando sei coperto
	# =====================================================================
	# I due scenari sono sullo **stesso montaggio** e lo stesso giocatore: la
	# folla e' gia' calda e il secondo comincia subito. Il numero che decide e'
	# uno solo, `passi`, e il confronto e' fra i due: se accorciando la finestra
	# il tempo di morte **non** scende, il difetto non e' la finestra e va detto
	# cosi' — il numero di `src/player/player.gd` non si tocca per farlo scendere.
	var corto := _m16_morte(hd, p, w)
	var lungo := _m16_morte(hd, p, M16_VECCHIA)
	var sec_corto := float(corto["passi"]) * DT
	var sec_lungo := float(lungo["passi"]) * DT
	print("m16 criterio 2, giocatore fermo al centro con %d nemici addosso e %.1f hp: finestra %.2f s -> morto al passo %d (%.2f s), %d morsi accettati, %.2f hp/s"
		% [vivi, float(p.get("max_hp")), w, int(corto["passi"]), sec_corto, int(corto["accettati"]),
			float(corto["danni"]) / maxf(0.0001, sec_corto)])
	print("m16 criterio 2: finestra %.2f s -> morto al passo %d (%.2f s), %d morsi accettati, %.2f hp/s"
		% [M16_VECCHIA, int(lungo["passi"]), sec_lungo, int(lungo["accettati"]),
			float(lungo["danni"]) / maxf(0.0001, sec_lungo)])
	h.check(bool(corto["morto"]),
		"m16 criterio 2: il giocatore coperto deve morire entro %d passi (%.0f s) anche con la finestra corta: e' morto al passo %d"
			% [M16_PASSI_MORTE, float(M16_PASSI_MORTE) * DT, int(corto["passi"])])
	h.check(bool(lungo["morto"]),
		"m16 criterio 2: e deve morire anche con la finestra lunga di %.2f s (morto al passo %d di %d)"
			% [M16_VECCHIA, int(lungo["passi"]), M16_PASSI_MORTE])
	h.check(bool(corto["morto"]) and bool(lungo["morto"]) and int(corto["passi"]) < int(lungo["passi"]),
		"m16 criterio 2: accorciare la finestra fa morire prima quando sei coperto: %.2f s con %.2f s di finestra contro %.2f s con %.2f s (fattore %.2f)"
			% [sec_corto, w, sec_lungo, M16_VECCHIA, sec_lungo / maxf(0.0001, sec_corto)])
	print("m16: sezione intera in %d ms (1 montaggio, %d passi d'orda a %d nemici)"
		% [Time.get_ticks_msec() - t0, passi_pieno + M16_SCALDATURA + M16_FINESTRA
			+ int(corto["passi"]) + int(lungo["passi"]), M16_NEMICI])
	_libera(scena)

## Quanti passi ci vuole a uccidere il giocatore fermo al centro con la folla
## calda, con la finestra portata a `w`.
##
## ## Perche' la finestra si scrive a mano qui e non si cambia a runtime
##
## `INVULN_AFTER_HIT` e' una **`const`**: nessun test puo' cambiarla, e la
## sezione m16 criterio 1 gira con il valore **vero** del gioco. Qui invece la
## finestra e' un **scenario**, e la si pilota sul campo `invuln` che il codice
## di gioco scrive gia' a ogni colpo accettato (`take_damage`: `invuln =
## INVULN_AFTER_HIT`). Il `- DT` e' dichiarato perche' e' la legge: il colpo
## entra dentro `Horde.step()` e il giocatore scala la finestra nella stessa
## simulazione, quindi il valore che il passo successivo vede e' `w - DT`.
##
## ## Perche' la partita non entra in `game_over` fra uno scenario e l'altro
##
## `_poll_run()` guarda le vite **all'inizio** di `Horde.step()`. Il giocatore
## muore dentro lo step, e `hp` viene rimesso a pieno **prima** dello step
## successivo: `run.enter_game_over()` non viene mai chiamato e la folla non si
## congela. E' il motivo per cui i due scenari possono stare sullo stesso
## montaggio invece di due scene da 25 s di riempimento ciascuna.
func _m16_morte(hd, p, w: float) -> Dictionary:
	var fuori := {"passi": M16_PASSI_MORTE, "morto": false, "accettati": 0, "danni": 0.0}
	p.set("hp", p.get("max_hp"))
	p.set("invuln", 0.0)
	p.set("dash_timer", 0.0)
	for i in M16_PASSI_MORTE:
		var prima := float(p.get("hp"))
		hd.call("step", DT)
		p.call("step", DT, Vector3.ZERO, false)
		if float(p.get("hp")) < prima:
			fuori["accettati"] = int(fuori["accettati"]) + 1
			fuori["danni"] = float(fuori["danni"]) + (prima - float(p.get("hp")))
			# La finestra di questo scenario, e **solo** quando un colpo e'
			# entrato: il codice di gioco ha appena messo la sua in `invuln` e
			# `p.step()` l'ha gia' scalata di `DT`, quindi qui si porta a quella
			# che lo scenario chiede, meno il `DT` che lo stesso passo scala sotto.
			#
			## Il `- DT` e' la legge e non un arrotondamento: il colpo entra dentro
			## `Horde.step()` e il giocatore scala la finestra nella stessa
			## simulazione, quindi il valore che il passo **successivo** vede e'
			## `w - DT`.
			##
			## E la condizione conta: riscrivere `invuln` a ogni passo in cui e'
			## positivo **riaprirebbe la finestra ogni frame** e renderebbe il
			## giocatore permanentemente invulnerabile dal primo colpo in poi
			## (misurato: con quella forma la sezione accettava **1** colpo in
			## 60 s ed era il numero che ha fatto trovare il difetto).
			p.set("invuln", maxf(w - DT, 0.0))
		if bool(p.call("is_dead")):
			fuori["passi"] = i + 1
			fuori["morto"] = true
			break
	return fuori

## Quanti nemici sono **a portata di morso** del giocatore, con la portata che
## chiede l'orda vera (`Horde.bite_range_of(kind)`, cioe' la stessa formula del
## morso di -orda con il fattore corpo che arriva dal contratto).
##
## Non e' un contatore per passo: si legge una volta sola, a fine finestra,
## perche' 200 nemici per 1800 passi sarebbero 360.000 confronti dentro una
## misura che non li usa. Il numero serve a **leggere** il risultato: se la folla
## non e' addosso, i morsi offerti sono bassi per un motivo che non e' la
## finestra, e il numero lo dice.
func _m16_in_portata(hd, punto: Vector3) -> int:
	var t: PackedVector3Array = hd.get("transforms")
	var k: PackedInt32Array = hd.get("kinds")
	var dentro := 0
	for i in mini(t.size(), k.size()):
		var d := Vector2(t[i].x - punto.x, t[i].z - punto.z).length()
		if d <= float(hd.call("bite_range_of", int(k[i]))):
			dentro += 1
	return dentro

# ================================================================================
# Il gemello: `bonk.wav`, il suono dell'impatto, e la capienza del suo pool
# ================================================================================
#
# ## La domanda che decide il lavoro, e che non si puo' supporre
#
# Sul giocatore `SFX_POOL = 1` e' motivato da due numeri del gioco: `hurt` non
# si sovrappone (`INVULN_AFTER_HIT = 0.25 s` dalla m16, **uguale** alla durata di
# `hurt`, quindi con margine zero — vedi il ragionamento aggiornato in
# `src/player/player.gd` accanto a `SFX_POOL`) e `levelup`
# non si sovrappone (otto uccisioni fra una soglia e l'altra contro 0.50 s di
# suono). Qui **non si puo' copiare quel ragionamento**: `bonk.wav` dura
# **0.18 s** e parte a **ogni impatto**, e l'arma spara da sola.
#
# Quindi il numero di slot si misura: quanti bonk arrivano dentro una finestra
# di 0.18 s? Il massimo di quel numero e' la capienza minima, e il motivo per
# cui la capienza non si sceglie a occhio e' **il numero che esce qui sotto**.
#
# La finestra e' di **11 passi** a DT = 1/60 s, cioe' 0.1833 s: e' il primo
# multiplo di DT che supera 0.18 s, e arrotondare per difto darebbe una
# finestra troppo stretta e un massimo falsamente basso.

## Quanti passi coprono `bonk.wav`. Vedi sopra: il primo multiplo di DT che
## supera i 0.18 s del suono.
const BONK_PASSI := 11
## Quanti passi di gioco si misurano **per montaggio**. La misura vale quanto la
## finestra e' piu' lunga di un periodo dell'arma: `FIRE_INTERVAL = 0.35 s` sono
## 21 passi, e con 900 passi si guardano quasi due periodi interi.
const BONK_MISURA_PASSI := 900
## Quanti montaggi si misurano. `scenes/arena_main.tscn` **non** e' determinata
## (`horde.gd::_build()` fa `randomize()` quando `seed == 0`, il difetto aperto di
## m11-bis), quindi **un montaggio solo non e' una misura**: e' un campione. Tre
## montaggi danno tre campioni indipendenti, ed e' la stessa regola che m11-bis
## usa per il confronto.
const BONK_MONTAGGI := 3
## L'asset del suono d'impatto, confrontato sul `resource_path` del **nodo che
## sta suonando**: un criterio che legge l'intenzione del codice invece della
## sua opera passa anche con il file sbagliato.
const SFX_BONK_ASSET := "res://assets/sfx/bonk.wav"

func _audio_bonk(h) -> int:
	var t0 := Time.get_ticks_msec()
	var max_finestra := 0
	var max_singolo := 0
	var max_concorrenza := 0
	var tot_suoni := 0
	var tot_impatti := 0
	var righe: Array[String] = []
	var suono_presente := 0
	for giro in BONK_MONTAGGI:
		var c := _bonk_montaggio(h, giro)
		if not h.check(not c.is_empty(), "bonk: il montaggio %d e' riuscito" % giro):
			return Time.get_ticks_msec() - t0
		max_finestra = maxi(max_finestra, int(c["max_finestra"]))
		max_singolo = maxi(max_singolo, int(c["max_singolo"]))
		max_concorrenza = maxi(max_concorrenza, int(c["in_uso_max"]))
		suono_presente += int(c["suono_presente"])
		tot_suoni += int(c["suoni"])
		tot_impatti += int(c["impatti"])
		righe.append("montaggio %d: %d suoni su %d impatti in %d passi, massimo per passo %d, massimo in %d passi %d, concorrenza %d"
			% [giro, int(c["suoni"]), int(c["impatti"]), BONK_MISURA_PASSI, int(c["max_singolo"]),
				BONK_PASSI, int(c["max_finestra"]), int(c["in_uso_max"])])

	## ## 1. Il suono esce davvero
	h.check(tot_suoni > 0,
		"l'arma deve far suonare il bonk: in %d passi non ne e' partito nessuno"
			% (BONK_MISURA_PASSI * BONK_MONTAGGI))
	h.check(suono_presente > 0,
		"il nodo del bonk deve essere fra i suoni in uso almeno una volta: e' stato in uso in %d passi su %d"
			% [suono_presente, BONK_MISURA_PASSI * BONK_MONTAGGI])

	for r in righe:
		print("bonk: %s" % r)
	print("bonk: totale %d suoni su %d impatti in %d passi; massimo per passo %d, massimo in %d passi (%.4f s) = %d; concorrenza massima %d"
		% [tot_suoni, tot_impatti, BONK_MISURA_PASSI * BONK_MONTAGGI, max_singolo,
			BONK_PASSI, BONK_PASSI * DT, max_finestra, max_concorrenza])
	return Time.get_ticks_msec() - t0

## Un montaggio della scena vera, misurato. L'ordine dei due `step()` e' quello
## dell'albero, come in `_m11bis_campione`, e il ciclo di frame e' disabilitato:
## due orologi non si misurano.
##
## ## Perche' le asserzioni stanno **qui dentro** e non sul totale dei montaggi
##
## `_libera()` fa `queue_free()`, che aspetta la fine del frame, e questo test
## gira tutto dentro un solo `_process()`: quindi il montaggio precedente e'
## ancora in albero quando il successivo si monta. Confrontando i nodi **prima
## del primo montaggio** e **dopo l'ultimo** si leggeva un numero che sale di 45
## per ogni montaggio accodato (`328 -> 418` misurato, e audio `24 -> 30`:
## `2 x 45` e `2 x 3`), cioe' un difetto del **test** letto come un difetto del
## gioco. Ogni montaggio confronta i propri due numeri, e cosi' il confronto
## copre anche i montaggi in cui la scena precedente e' ancora viva.
func _bonk_montaggio(h, giro: int) -> Dictionary:
	var packed = load(ARENA_SCENE)
	if not (packed is PackedScene):
		return {}
	var scena := (packed as PackedScene).instantiate()
	_monta(scena)
	var hd = scena.get_node_or_null(NODO_HORDE)
	var p = scena.get_node_or_null("Player")
	var arma = scena.get_node_or_null("Player/Weapon")
	if hd == null or p == null or arma == null:
		_libera(scena)
		return {}
	scena.process_mode = Node.PROCESS_MODE_DISABLED
	p.call("drive_manually")
	hd.set_physics_process(false)
	p.set("hp", DETERM_HP_ALTO)

	var nodi0 := _conta_nodi(root)
	var audio0 := _conta_class(root, AUDIO_CLASS)
	# Un contatore per passo: quanti bonk sono partiti **in quel passo**. Il
	# massimo dentro una finestra di `BONK_PASSI` passi consecutivi e' la
	# capienza minima del pool, ed e' il numero che decide `SFX_POOL`.
	var per_passo := PackedInt32Array()
	var suoni := 0
	var impatti := 0
	var in_uso_max := 0
	var suono_presente := 0
	for i in BONK_MISURA_PASSI:
		hd.call("step", DT)
		p.call("step", DT, Vector3.ZERO, false)
		var ora := int(arma.get("sfx_emessi"))
		per_passo.append(ora - suoni)
		suoni = ora
		impatti = int(arma.get("impatti"))
		var in_uso := _audio_in_uso(arma)
		in_uso_max = maxi(in_uso_max, in_uso.size())
		if in_uso.has(SFX_BONK_ASSET):
			suono_presente += 1

	var max_finestra := 0
	var max_singolo := 0
	for i in per_passo.size():
		max_singolo = maxi(max_singolo, per_passo[i])
		var somma := 0
		for k in range(i, mini(i + BONK_PASSI, per_passo.size())):
			somma += per_passo[k]
		max_finestra = maxi(max_finestra, somma)

	var fuori := {}
	fuori["suoni"] = suoni
	fuori["impatti"] = impatti
	fuori["suono_presente"] = suono_presente
	fuori["max_singolo"] = max_singolo
	fuori["max_finestra"] = max_finestra
	fuori["in_uso_max"] = in_uso_max
	fuori["nodi0"] = nodi0
	fuori["nodi1"] = _conta_nodi(root)
	fuori["audio0"] = audio0
	fuori["audio1"] = _conta_class(root, AUDIO_CLASS)

	## ## 1b. Ogni impatto produce un suono: il conto che chiude il ramo di riuso
	##
	## Questa e' l'asserzione che mancava, e l'ho trovata togliendo il ramo
	## «riusa lo slot che sta per finire»: i suoni sono scesi da 39 a 20 per
	## montaggio, cioe' meta' dei bonk persi, e **il criterio era verde** perche'
	## guardava solo «il suono e' uscito almeno una volta». Un numero che basta
	## a essere positivo non dice niente.
	##
	## Il confronto e' di **uguaglianza**, e il conto e' esatto: 117 suoni su 117
	## impatti in 2700 passi, sui tre montaggi. Il perche' e' misurabile: in
	## `--headless` `finished` non arriva dentro una sezione che non passa da
	## `await`, quindi lo slot resta occupato per `0.18 + 0.35 = 0.53 s`, mentre
	## due impatti arrivano a `0.385 s` di distanza. Il ramo di riuso e' quindi
	## **quello che tiene il conto al posto di `finished`**, ed e' esattamente il
	## ramo che questo criterio protegge.
	##
	## Il caso in cui l'uguaglianza non regge e' il throttle: due impatti entro
	## `IMPACT_SFX_GAP = 0.05 s`. Non e' successo in 2700 passi su tre montaggi.
	## Se un giorno succede, questo criterio lo dice con due numeri e non lo
	## nasconde: un `FAIL` qui vuol dire che un impatto e' stato lasciato fuori
	## dal throttle, non che il criterio e'too stretto.
	h.eq(suoni, impatti,
		"montaggio %d: ogni impatto deve produrre un suono: %d impatti, %d suoni. Se i suoni sono meno, uno slot del pool era occupato e il ramo di riuso non ha suonato"
			% [giro, impatti, suoni])

	## ## 2. Nessun nodo nasce durante il gioco, confrontato **per montaggio**
	##
	## E' lo stesso criterio che la sezione del giocatore ha gia' scritto e che
	## ha i denti gia' provati: la forma che faceva nascere il nodo al momento
	## del suono l'aveva fatto fallire con `287 -> 287-289`. Qui non deve
	## succedere, e non succede perche' il nodo dell'arma e' nato in `_ready()`.
	h.eq(int(fuori["nodi1"]), nodi0,
		"montaggio %d: durante %d passi di impatto il numero di nodi sotto root non puo' cambiare: era %d, e' %d"
			% [giro, BONK_MISURA_PASSI, nodi0, int(fuori["nodi1"])])
	h.eq(int(fuori["audio1"]), audio0,
		"montaggio %d: durante %d passi di impatto il numero di nodi audio sotto root non puo' cambiare: era %d, e' %d"
			% [giro, BONK_MISURA_PASSI, audio0, int(fuori["audio1"])])
	_libera(scena)
	return fuori

# ================================================================================
# L'audio di -gameplay: il suono esce, e non costa un nodo
# ================================================================================
#
# ## Perche' questa sezione e' qui, e quale porta aveva gia' detto di no
#
# Il suono di livello teneva il proprio `AudioStreamPlayer3D` **per tutta la
# partita**, e a ogni livello il nodo non nasceva: era gia' li'. Poi la prima
# forma del rimedio ha cambiato la regola in «il nodo nasce quando il suono
# parte e muore quando finisce», e con quella `tests/test_arena.gd`,
# `tests/test_gameloop.gd` e `tests/test_ui.gd` sono andati rossi tutti e tre
# con lo stesso numero che sale di uno (`45 -> 46`, `48 -> 49`, `47 -> 48`):
# il nodo era nato **durante** la partita, dentro una finestra di misura.
#
# Quei tre criteri sono giusti e non si indeboliscono: «aprire il pannello non
# crea un nodo» e «riempire l'orda a capienza non aggiunge un nodo» dicono una
# cosa vera, e cioe' che **il gioco non crea nodi mentre gioca**. Il rimedio
# giusto non e' un nodo che nasce e muore: e' un **pool** di nodi creati una
# volta sola in `_ready()`.
#
# E questa sezione e' il criterio che quella cosa l'avrebbe detto prima, e che
# sta qui perché la prossima volta la foglia che scrive il codice non debba
# scoprirlo dalla porta di un'altra.

## La classe dei nodi che suonano, per nome di **classe** e non per nome di
## nodo: i suoni hanno piu' nomi possibili (`Sfx`, `SfxHurt`, `SfxLevelUp`
## dalla scena, e quelli che crea `player.gd`) e cercarli per nome di nodo
## darebbe un numero che non guarda niente. `AudioStreamPlayer3D` non discende
## da `AudioStreamPlayer`, quindi anche la classe sbagliata darebbe zero.
const AUDIO_CLASS := "AudioStreamPlayer3D"

## L'asset che il suono di livello deve portare davvero. Si confronta il
## `resource_path` **del nodo che sta suonando**, non il nome che il codice
## dice di caricare: un criterio che legge l'intenzione del codice invece della
## sua opera passa anche con il file sbagliato.
const SFX_LEVELUP_ASSET := "res://assets/sfx/levelup.wav"

## Quante volte si sale di livello e si prende un colpo dentro la finestra.
## Quaranta e non uno: con un solo giro il criterio passerebbe anche con un
## nodo che nasce e muore una volta sola, e il difetto vero e' proprio che il
## nodo nasce **quando capita**, cioe' molte volte in una partita.
const SFX_PASSI := 40

func _audio_usa_e_getta(h) -> int:
	var t0 := Time.get_ticks_msec()
	_reset(Vector3.ZERO)
	player.chiudi_suoni()
	var prog = player.progression
	var nodi_prima := _conta_nodi(root)
	var audio_prima := _conta_class(root, AUDIO_CLASS)
	var emessi_prima: int = int(player.sfx_emessi)

	# ## 1. Il suono esce davvero, e non e' un suono muto
	prog.add_xp(prog.xp_to_next())
	h.eq(int(player.sfx_emessi) - emessi_prima, 1,
		"salire di livello fa partire un suono, e uno solo")
	var chi_suona := _audio_in_uso(player)
	h.check(chi_suona.size() > 0,
		"dopo un livello qualcosa sta suonando davvero: nessun nodo audio e' in uso")
	h.check(chi_suona.has(SFX_LEVELUP_ASSET),
		"e fra i suoni in uso c'e' l'asset del livello (in uso: %s)" % ", ".join(PackedStringArray(chi_suona)))

	# ## 2. Il numero di nodi non si muove MAI, e qui e' il criterio vero
	var nodi_min := nodi_prima
	var nodi_max := nodi_prima
	var audio_min := audio_prima
	var audio_max := audio_prima
	for i in SFX_PASSI:
		prog.add_xp(prog.xp_to_next())
		player.invuln = 0.0
		player.take_damage(1.0)
		player.step(DT)
		var n := _conta_nodi(root)
		nodi_min = mini(nodi_min, n)
		nodi_max = maxi(nodi_max, n)
		var a := _conta_class(root, AUDIO_CLASS)
		audio_min = mini(audio_min, a)
		audio_max = maxi(audio_max, a)
	h.eq(nodi_min, nodi_prima,
		"il gioco non puo' liberare un nodo nel mezzo di %d suoni" % SFX_PASSI)
	h.eq(nodi_max, nodi_prima,
		"il gioco non puo' creare un nodo nel mezzo di %d suoni: e' la ragione per cui test_arena, test_gameloop e test_ui sono andati rossi con 45 -> 46, 48 -> 49 e 47 -> 48"
			% SFX_PASSI)
	h.eq(audio_min, audio_prima,
		"il numero di nodi audio sotto root non scende mentre i suoni girano")
	h.eq(audio_max, audio_prima,
		"il numero di nodi audio sotto root non sale mentre i suoni girano")

	# ## 3. E i suoni sono usciti tutti, senza che il numero cresca
	h.check(int(player.sfx_emessi) - emessi_prima >= SFX_PASSI + 1,
		"tutti i suoni forzati devono essere usciti: sono partiti %d, ne erano stati forzati %d"
			% [int(player.sfx_emessi) - emessi_prima, SFX_PASSI + 1])
	player.chiudi_suoni()
	h.eq(_conta_nodi(root), nodi_prima,
		"chiudere i suoni non cambia il numero di nodi: il pool torna com'era, non sparisce")

	print("audio: nodi sotto root %d prima, %d-%d durante %d suoni; nodi audio %d prima, %d-%d durante; suoni emessi %d"
		% [nodi_prima, nodi_min, nodi_max, SFX_PASSI,
			audio_prima, audio_min, audio_max,
			int(player.sfx_emessi) - emessi_prima])
	return Time.get_ticks_msec() - t0

## Quanti nodi della classe `cls` ci sono sotto `nodo`, ricorsivamente.
func _conta_class(nodo: Node, cls: String) -> int:
	var totale := 1 if nodo.is_class(cls) else 0
	for c in nodo.get_children():
		totale += _conta_class(c, cls)
	return totale

## I `resource_path` di tutti i nodi audio **che stanno suonando davvero** sotto
## `nodo`. Il nodo conta solo se `playing` e' vero: un nodo audio fermo e' un
## nodo che occupa l'albero senza fare rumore, e un criterio che lo accetterebbe
## come «suono emesso» e' un criterio che non ha guardato niente.
##
## Restituisce **tutti** i suoni in uso e non il primo, perche' mentre il
## giocatore suona il livello l'arma sta anche sparando: il primo nodo
## incontrato nell'albero e' spesso `bonk.wav`, e un criterio che guardasse
## solo quello misurerebbe il suono dell'arma e passerebbe anche con il suono
## di livello spento.
func _audio_in_uso(nodo: Node, fuori: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	if nodo.is_class(AUDIO_CLASS) and bool(nodo.playing):
		fuori.append(str(nodo.stream.resource_path))
	for c in nodo.get_children():
		_audio_in_uso(c, fuori)
	return fuori

func _ascii(s: String) -> bool:
	for i in s.length():
		if s.unicode_at(i) > 126:
			return false
	return true
