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
##      dentro `Game.arena_radius`. **m9**: il raggio non e' piu' 28 m ma 46, e
##      «non uscire» non basta piu' come prova: su un disco 2,7 volte piu' grande
##      la sezione dice anche **dove** il muro ferma il giocatore — a 45,2 m dal
##      centro sull'asse, sugli stessi 45,2 m in diagonale, con `x` e `z` entrambi
##      a 31,97 m. Un clamp **quadrato** si tradirebbe li' (arriverebbe a 63,9 m,
##      cioe' 17,9 m oltre il muro);
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
##  16. **m9, criterio n. 1**: il raggio dell'arena è **46 m** e quel numero è
##      un **letterale scritto qui** (`RAGGIO_ARENA`), non letto dalla fonte: «il
##      raggio vale 46 m» è un perno e un perno può esistere solo scritto. Il
##      criterio opposto — le copie del raggio non divergono fra loro — sta in
##      `tests/test_arena.gd`, che è di `-arena`: li' si confrontano le copie e
##      non si sa se il numero sia quello giusto. Le due domande non si dicono, e
##      per questo stanno in due file.
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
##   - `Game.horde = self` con i due campi pubblici `count` e `transforms`;
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
## La resistenza al knockback del boss: 0.90 in `src/sim/enemy.gd`. Serve alla
## sezione `_knockback_impulse` per provare che e' **il contratto** a decidere
## quanto il colpo sposta, e non -gameplay a pre-scalare l'impulso.
const BOSS_RESIST := 0.90
## HP alti nel test: cosi' l'attenzione va sulla regola del colpo singolo e non
## su chi muore per primo.
const TOUGH := 100000.0

# --- m9: il raggio dell'arena, scritto qui e non letto dalla fonte ----------------
#
# Il 46 e' un **letterale**, e resta un letterale per un motivo preciso: «il raggio
# dell'arena vale 46 m» e' un **perno**. Se lo leggessi dal contratto — o da
# `src/render/arena.gd`, che e' la copia che vince — questa asserzione non
# potrebbe piu' fallire: qualcuno cambierebbe il numero, il test lo leggerebbe
# junto e passerebbe insieme a lui. Un perno si puo' fare solo con un valore
# scritto.
#
# Il criterio **opposto** — «le copie del raggio non divergono fra loro» — non e'
# questo, e non puo' essere questo: sta in `tests/test_arena.gd`, che e' di
# `-arena`, perche' li' si confrontano le copie e quel file non ha modo di sapere
# se il numero che confronta e' quello giusto. Sono due domande diverse, con due
# file diversi che possono dare due risposte diverse, ed e' per questo che qui il
# numero resta scritto a mano invece di essere letto (piano §1.12-bis).
#
## Il **perche'** 46 e non 40 e' la tabella di densita' di piano §1.12: a 200
## nemici il disco libero piu' grande passa da 9,5 m (R=28) a 19,1 m (R=46),
# mentre la percentuale di area libera resta quasi quella (85,2% -> 94,6%). Il
## guadagno e' lineare nel raggio e non nell'area, perche' l'orda forma un
## anello di ~9,4 m intorno al giocatore e il muro e' la sola cosa che si
# allontana: e il 40, con 3,5 m di anello in piu', non compra niente.
const RAGGIO_ARENA := 46.0

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
## ## Perche' questo numero resta, e non diventa un assoluto
##
## Non e' un assoluto: e' una **ripartizione** fra le foglie, e una ripartizione
## si muove quando qualcuno aggiunge un nodo ** dichiarando l'incremento qui**.
## Quello che non si muove e' il **tetto vero**, il 120 di `node_count` del
## criterio n. 7, e quello resta il criterio. Questa riga ha un solo difetto
## possibile e resta quello di prima: se **-gameplay** aggiungesse un nodo,
## questa asserzione andrebbe rossa — ed e' quello che deve fare, perche'
## nessun nodo di -gameplay si giustifica da solo.
const NODI_SCENA_VERA := 20

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

	func add(pos: Vector3, hp_value: float = 1000.0) -> int:
		transforms.append(pos)
		hp.append(hp_value)
		hits.append(0)
		vel.append(Vector3.ZERO)
		resist.append(0.0)
		count += 1
		return count - 1

	func clear() -> void:
		count = 0
		transforms = PackedVector3Array()
		hp = PackedFloat32Array()
		hits = PackedInt32Array()
		vel = PackedVector3Array()
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
		resist[index] = resist[count]

# --- Stato del test ------------------------------------------------------------

var game: Node
var horde: FakeHorde
var player: Node3D
var weapon
var pool

var _h
var _ran := false
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
	_setup(h)
	# Se il cablaggio non c'e', le sezioni seguenti crasherebbero una dopo l'altra:
	# si esce subito e il FAIL e' il messaggio vero, non un errore a cascata che
	# coprirebbe la causa.
	if player != null and weapon != null and pool != null:
		_movement(h)
		_autofire(h)
		_single_hit(h)
		_overlapping_enemies(h)
		_knockback_impulse(h)
		_damage_and_iframes(h)
		_xp_and_upgrades(h)
		_no_allocation(h)
		# m10, criterio n. 6. Vanno qui, **prima** delle sezioni che istanziano
		# `scenes/arena_main.tscn`: quelle lasciano il contratto puntato su un
		# giocatore e su un'orda che non sono quelli, e una sezione che spara
		# misurerebbe la muzzle di un giocatore che non e' il suo.
		_m10_giocatore_solido(h)
		_m10_proiettili_passano(h)
		# Criterio n. 4 di m2, meta' di -gameplay. Instala l'orda **vera** di
		# -orda, che prende il contratto: da qui in avanti questa sezione parla
		# con l'orda vera e non piu' con il doppio finto delle altre.
		_restart_run(h)
		# m5: i due difetti che nessuna porta poteva vedere, e i due test che
		# oggi li vedono. Vanno per ultimi perche' toccano il contratto e
		# l'albero degli attori.
		_m5_ingresso_su_schermo(h)
		_m5_trasformazione_del_renderer(h)
		_m5_nessun_nodo_in_piu(h)
		# m7: la salute sulla **scena vera**. Va per ultima perche' installa un
		# secondo giocatore e una seconda orda sul contratto, e le sezioni di m5
		# contano i nodi di quella che hanno appena liberato.
		_m7_salute_sulla_scena_vera(h)
		# m10, criterio n. 6, terza meta': il **contratto**. Va per ultima
		# perche' instanzia la scena vera come fanno gia' le due sezioni
		# precedenti, e dopo questa riga non resta piu' nessuna sezione che
		# guardi il contratto con la scena sotto.
		_m10_ostacoli_del_contratto(h)
	print("gameplay: test terminato in %d ms" % (Time.get_ticks_msec() - _t0))
	quit(h.finish("test_gameplay"))
	return true

# --- 0. La porta, la registrazione, e la prova che il contratto lavori ----------

func _setup(h) -> void:
	game = root.get_node_or_null("Game")
	if not h.check(game != null, "l'autoload Game manca: nessun test delle foglie puo' partire"):
		return
	# IL PERNO di m9. Il numero e' scritto qui (`RAGGIO_ARENA`, in testa al file)
	# e non letto da `src/render/arena.gd`: leggerlo renderebbe questa riga
	# incapace di fallire, perche' seguirebbe il numero invece di sorvegliarlo.
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
	# delle due ha a che fare con `arena_radius` (che a m9 e' 46). Sono due numeri
	# diversi e si vedono diversi: il primo trova i due nemici a 10 m e 13,5 m, il
	# secondo non trova nessuno perche' 5 m < 10 m, quindi il contratto onora il
	# raggio che riceve. Sul disco da 46 m coprono il 57% e l'11% del raggio:
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

	h.check(game.player == player, "registrazione dati: Game.player = self (piano 5.1)")
	h.check(game.has_impl("player_position"), "registrazione metodi: player_position")
	h.check(game.has_impl("spawn_projectile"), "registrazione metodi: spawn_projectile")
	h.vec_near(game.player_position(), Vector3.ZERO, 0.0001, "player_position all'avvio")

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
	# ferma, e su un disco 2,7 volte piu' grande quella frase da sola dice ancora
	# meno di prima. Due agguagli, dichiarati perche' un test che non li dichiara
	# fa sembrare forte un asserzione che e' debole:
	#
	#   - `far <= radius + 0.001` ha **0,8 m di margine**, perche' il clamp ferma
	#     il giocatore *dentro* il raggio: quella riga, da sola, cade solo se il
	#     muro sparisce del tutto (a 46 m, due secondi a 7 m/s porterebbero a
	#     59 m, tredici oltre il muro). Resta vera, ma da sola non dimostra che
	#     il bordo sia raggiungibile: e su un raggio 2,7 volte piu' grande la
	#     differenza fra «clamp a 45,2 m» e «clamp a 3 m» e' la stessa in
	#     assoluto e molto piu' piccola in percentuale.
	#   - `far >= radius - 2.0` invece si e' **irrigata**: la finestra e' di 2 m
	#     sia a 28 che a 46, ma sul raggio e' il 7,1% di prima e il 4,3% di adesso.
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

	# (a) Dal centro verso +x, dieci secondi. A 7 m/s il muro di un'arena da 46 m
	#     e' a 6,46 s: i 600 frame arrivano, e i due secondi finali servono a
	#     vedere che il giocatore **resta** fermo li' invece di scivolare fuori.
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
	#     un clamp per assi fermerebbe a 45,2 m su `x` **e** su `z`, cioe' a
	#     63,9 m dal centro, 17,9 m oltre il muro (a 28 m la stessa prova sarebbe
	#     stata 11,6 m oltre).
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

	print("m9 muro: raggio %.1f m (perno scritto: %.1f m), il giocatore si ferma a %.3f m sull'asse e a %.3f m in diagonale, cioe' (%.3f, 0.00, %.3f): margine %.2f m letto da -gameplay"
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
	h.eq(known.size(), 8, "la progressione dichiara 8 potenziamenti possibili")

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
		var ferma: PackedVector3Array = horde_vera.transforms.duplicate()
		horde_vera.step(DT)
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
		var colpi_prima: int = int(weapon.shots)
		player.step(DT, Vector3.ZERO)
		h.eq(int(weapon.shots), colpi_prima + 1,
			"restart %d: il primo colpo parte al primo passo, senza aspettare l'intervallo" % (giro + 1))

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
	# Qualche passo di gioco: il cooldown e il contatore dei colpi non devono
	# essere gia' a zero, altrimenti il restart non avrebbe nulla da rimettere a
	# posto su quei due campi.
	_passo_di_gioco()
	h.check(float(weapon.damage) > 0.0,
		"restart %d: la regolazione e' sporcata prima di misurare" % (giro + 1))
	h.check(float(weapon.shots) > 0,
		"restart %d: e sono partiti colpi, cosi' il contatore da azzerare esiste" % (giro + 1))

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
	root.add_child(scena)

	var hud = scena.get_node_or_null(NODO_HUD)
	if not h.check(hud != null, "la scena vera ha ancora il nodo \"%s\"" % NODO_HUD):
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
	scena.queue_free()

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
	root.add_child(scena)
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
	h.near(perso, float(conto["danno"]), 0.0001,
		"m7: vita persa %.4f = danno annunciato da hurt %.4f: nessuna strada diversa dal contratto"
		% [perso, float(conto["danno"])])
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
#     dall'origine;
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
	root.add_child(scena)

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
				h.eq(int(p.obstacle_count()), n,
					"m10: e il giocatore della scena vera ha letto dal contratto gli stessi %d ostacoli, non zero" % n)
	else:
		# Il campo non c'e': il numero e' dichiarato qui e non dedotto, e la
		# spiegazione dice il file e il proprietario. Questa sezione non puo'
		# chiudere il buco (il file non e' mio) e non finge di averlo chiuso.
		print("m10 catena di consegna ANCORA ROSSA: Game.obstacles non e' un campo del contratto, quindi nessun ostacolo e' registrato. "
			+ "Il campo e' dichiarato in src/core/contracts.gd (vertice), i valori li registra terminal-gun-arena in src/render/arena.gd. "
			+ "Le due meta' del criterio n. 6 sono verificate sulle sezioni precedenti con un disco dichiarato, non con quello vero.")
	scena.queue_free()

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
## ritoccano — il test direbbe «il muro e' a 45,2 m» anche se il muro si fosse
## spostato a 44. L'atteso si **compone**: raggio letto dal contratto meno
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
func _ascii(s: String) -> bool:
	for i in s.length():
		if s.unicode_at(i) > 126:
			return false
	return true
