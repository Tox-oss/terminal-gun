extends Node3D
## La radice dell'arena: `scenes/arena_main.tscn`. Terreno, ostacoli, orda,
## nemici, giocatore, camera, HUD, e tre registrazioni sul contratto.
##
## ## Le tre cose che arena registra
##
##     Game.arena_radius      = 60.0   # m9, e' la fonte unica del raggio
##     Game.obstacles          = [...]  # m10, i dischi su cui si scontra
##     Game.enemy_body_scale   = 3.4    # m11, il fattore di calibrazione del corpo
##
## Sono tre **dati**, quindi assegnazione diretta, una volta sola all'avvio (piano
## 5.1). Li registro in `_enter_tree()` e non in `_ready()`: i figli di questa
## scena costruiscono il terreno, gli ostacoli e l'orda nel loro `_ready()`, che
## gira prima del mio. Il commento di `_enter_tree()` spiega perche'.
##
## Non registro metodi: `nearest_enemy`, `damage_enemy` e `random_spawn_point`
## sono di -orda, `spawn_projectile` e `player_position` di -gameplay.
## Registrarne qualcuno per procura produrrebbe una doppia registrazione, e il
## piano 5.1 dice che l'ultima registrazione vince in silenzio: un bug che non
## si vede.
##
## Non registro neanche `Game.player` e `Game.horde`: sono dati di altre foglie e
## arena li **legge**, non li scrive.

## ## IL RAGGIO DELL'ARENA: l'unica fonte del numero (criterio n. 1 e n. 2 di m9)
##
## Il raggio e' stato scritto sei volte in sei file (piano 1.12-bis) e cinque
## copie potevano dire un numero diverso dalla sesta senza che nessuna porta lo
## vedesse. Qui e' **la fonte**: le altre cinque sono o un default di contratto
## che questa registrazione sovrascrive, o un **fallback dichiarato** che vale
## solo quando il contratto non e' ancora raggiungibile, e sono tutte tenute
## allineate da `tests/test_arena.gd` (criterio n. 2, sulla **deriva**: se una
## delle copie si discosta da questa, la porta va rossa).
##
## ## LA STORIA DEL NUMERO, IN DUE TEMPI, E PERCHE' 60.0 ERA IL NUMERO DI PRIMA
##
## ### Il numero di prima: 46.0, scelto da m9 con la sonda della DENSITA'
##
## Sonda `docs/piramide/probe_arena_density.gd` del vertice (piano 1.12): mette
## l'orda a regime e chiede **quanto spazio l'orda concede**, non quanto ne
## sembra. "Spazio libero" e' definito col numero che morde: un punto e' libero
## se dista da ogni nemico piu' di `RADIUS[kind] + TOUCH_REACH`. Griglia 0,5 m,
## DT 1/60, seme 4242, 900 passi di assestamento col giocatore fermo al centro.
##
##     popolazione    R=28            R=34            R=40            R=46
##     1 nemico       99,9%  14,5 m   99,9%  17,7 m  100,0% 20,9 m  100,0% 24,0 m
##     25  (onda 1)   97,5%  12,7 m    98,3%  16,1 m   98,7%  19,1 m   99,0%  22,2 m
##     200 (onda 8)   85,2%   9,5 m    90,3%  12,6 m   92,8%  15,6 m   94,6%  19,1 m
##
##     R       area        libera     disco libero max   tempo till il muro
##     28      2463 m2     85,2%       9,5 m             1,4 s
##     46      6648 m2     94,6%      19,1 m             2,7 s
##
## **Perche' 46 e non 40, e perche' il guadagno e' nella bolla e non nell'area.**
## Il tempo till il muro e' `(R - 9,4) / 13,65 m/s`: l'orda forma un anello di
## ~9,4 m intorno al giocatore, e **R compare nel numeratore mentre quel 9,4 no**.
## Percio' il guadagno e' **lineare nel raggio e lineare solo nella bolla**:
## la percentuale di area libera si muove poco (85,2% -> 94,6%, era gia' alta),
## mentre il **disco libero piu' grande raddoppia** (9,5 -> 19,1 m) e i secondi
## per scappare passano da 1,4 a 2,7. Passare da 40 a 46 e' mettere quegli
## stessi secondi davanti a un numero che si ricorda.
##
## ### Il numero di oggi: 60.0, scelto da m11 con la sonda della SOPRAVVIVENZA
##
## La sonda di m9 chiedeva «quanto spazio c'e'». L'utente ha chiesto **due volte**
## una mappa piu' grande, e la domanda giusta non e' quella: e' «quanto tempo ci si
## resta dentro». Sonda `docs/piramide/probe_survive.gd` del vertice (piano
## 1.14-quinque), sedici raggi, puntamento a 20,5 m avanti, penalita' del muro in
## metri e ritorno al centro oltre il 70%: tre semi per raggio, e **due casi a
## risposta nota** senza i quali la tabella non avrebbe diritto di esistere.
##
##     R=12 m (riferimento)  lo strumento DEVE morire     -> morto a   61,20 s
##     R=46 m (consegnato)   il caso peggiore di 1.12     ->           55,33 s
##     R=60 m (oggi)         il ginocchio della curva     ->          146,72 s
##     R=75 m                oltre il ginocchio           ->          156,33 s
##
##     da a          fattore sul caso peggiore
##     12 -> 46 m              0,90
##     46 -> 60 m             **2,65**
##     60 -> 75 m              1,07
##
## **Perche' 60 e non 75**: il ginocchio e' a circa 60 m. Da 46 a 60 il caso
## peggiore guadagna **2,65 volte** — l'istinto dell'utente era giusto, e due
## volte. Da 60 a 75 il fattore e' **1,07**: oltre il ginocchio non si compra
## niente, si paga solo spazio. Quindi la mappa va **dimensionata sul ginocchio**,
## non allungata.
##
## **Quello che questo numero NON risolve, dichiarato perche' nessuno ricreda fra
## sei mesi che 60 sia stato scelto a occhio**: (1) anche al raggio 75, che e'
## 1,63 volte quello di prima, il caso peggiore muore a 156,33 s, cioe' **la
## mappa da sola non basta** e il fattore mancante e' un altro; (2) **tutte le
## morti cadono sull'onda 1**, con 25 nemici vivi: non e' che le onde tardive
## siano dure, e' che l'apertura ammazza. Quei due numeri sono di `-orda` e del
## vertice, non sono di questo file: qui il raggio e' **la mappa**, e la mappa e' stata
## portata sul ginocchio che le misure indicano.
##
## ## m12, 2026-10-17: `60,0 -> 35,0 m`, E LA RAGIONE **NON** E' IL SOPRAVVIVENZA
##
## Il ginocchio della curva di sopravvivenza era a 60 m e il numero qui sopra
## l'aveva preso. Qui non lo si riprende, e il motivo e' un altro, ed e'
## geometrico: **la mappa non e' piu' un disco, e' un volume di quattro dischi**.
##
## `-orda` ha misurato la soglia che chiude le due garanzie di m10, e sono la
## **stessa** disuguaglianza scritta due volte:
##
##     disco   > boss     <=>  0,065 R > 1,90   <=>  R > 29,23 m
##     passaggio > boss   <=>  0,13  R > 3,80   <=>  R > 29,23 m
##
## `RADIUS_FRACTION` e' una **frazione** del raggio, quindi gli ostacoli passano
## a `2,275 m` e l'occupazione areale resta `11,4%` a qualunque raggio: non sono
## i dischi che vanno ingranditi, e' il raggio che va abbassato sotto la soglia.
##
##     a R = 35,0 m   raggio ostacolo   2,275 m   = 1,20x il boss  (+19,7%)
##                     passaggio utile   4,55  m   = 1,20x il boss  (+19,7%)
##                     larghezza 70 m  contro  altezza 80 m  ->  «su» e' 1,14 volte
##                     la larghezza
##
## **35 e' il primo raggio tondo che raddoppia il margine invece di sfiorarlo**:
## a 30 m il margine sarebbe del `2,6%`, cioe' una specie un poco piu' grossa lo
## richiuderebbe.
##
## **E' PROVVISORIO, e non va difeso come se fosse definitivo.** Il vertice lo
## porta all'utente e puo' cambiarlo; se lo cambiasse, il numero da cambiare e'
## questa riga e **null'altro**: i due fallback di `arena_camera.gd` e
## `arena_ground.gd` sono copie dichiarate tenute allineate da
## `tests/test_arena.gd` (criterio n. 2 di m9), e il default del contratto
## (`src/core/contracts.gd`) e' **del vertice** e va cambiato da lui, perche'
## quel file non e' di questa foglia.
const ARENA_RADIUS := 35.0

## ## I DUE NUMERI DELLA TORRE, e perche' stanno qui e non nel contratto
##
##     floor_count     = 4       quanti piani
##     floor_height    = 20,0 m  metri per piano, 80,0 m in tutto
##
## La decisione e' dell'utente (piano m12, «Quattro piani, uno per bioma»):
## quattro dischi di raggio 20 m impilati, 20 m ciascuno, `80 m` in tutto, e la
## salita si fa a rampa. Sono **geometrici** e hanno lo stesso statuto di
## `ARENA_RADIUS`: la **fonte** e' questo file, che li registra nel proprio
## `_enter_tree()`; **`-orda`, `-gameplay` e `-ui` li leggono** e non li possiedono.
##
## Il piano `i` copre `y` in `[i * floor_height, (i+1) * floor_height)` e **il
## bordo inferiore e' del piano di sotto**: a `y = 20,0` si e' sul piano 1. La
## convenzione **non e' qui dentro**, e' `Game.floor_of()` in
## `src/core/contracts.gd`, che e' il file del vertice e che la dichiara tre
## volte: copiare qui la divisione sarebbe la terza versione che concorda finche'
## non c'e' una torre.
const FLOOR_COUNT := 4
const FLOOR_HEIGHT := 20.0

## ## LA GEOMETRIA DEGLI OSTACOLI: i numeri sono di `-orda`, e qui vengono LETTI
##
## Il piano 3.11 fissa l'ordine di consegna di m10: «la geometria la sceglie
## `-orda` e la costruisce `-arena`», perche' il criterio n. 2 e' suo e «un numero
## che una foglia non ha misurato non lo deve scrivere». Il canale dei dati e'
## dichiarato in `src/core/contracts.gd` ed e' **una riga**:
##
##     -orda possiede i NUMERI:  src/sim/obstacles.gd -> layout(arena_radius)
##     -arena possiede la FORMA e LEGGE quei numeri, non li ricopia
##
## Quindi qui sotto **non c'e' un numero scritto**: c'e' il posto dove il numero va
## a essere letto, e `OBSTACLE_LAYOUT` ne e' il risultato — `OBSTACLE_COUNT` dischi
## su due anelli **per piano**, che cambiano **insieme** al raggio perche'
## `src/sim/obstacles.gd` li dichiara come frazioni (`RADIUS_FRACTION = 0,065`,
## `RING_RADII = 0,36 / 0,78`) e non in metri.
##
## ## IL NUMERO DEI DISCHI E' CAMBIATO DURANTE QUESTA MILESTONE, E NON E' MIO
##
## `OBSTACLE_COUNT` e' passato da **27 a 19** e `RING_RADII` da tre anelli a **due**,
## perche' a `R = 35,0 m` tre anelli **non ci stanno**: `6 x 4,525 + 4 x 2,00 =
## 35,15 m` contro `35,00 m` disponibili, fuori di `15 cm`. Il produttore e' di
## `-orda`, la decisione e' dell'utente, e **qui dentro non c'e' nessuna cifra**:
## il totale e' `OBSTACLE_COUNT x floor_count` e quindi **76** con i numeri di oggi,
## letto e non dichiarato.
##
## Questo e' il motivo per cui `tests/test_arena.gd` non asserisce `108` da nessuna
## parte e confronta invece contro `OBST.OBSTACLE_COUNT`: un numero cambiato in
## silenzio e' il falso verde peggiore, e la difesa non e' allargare il criterio ma
## togliere la copia. I numeri che **erano** stampati qui nel 2026-10-13 (raggio
## 2,99 m su anelli a 15,18 / 27,14 / 39,10 m) erano misurati con l'arena a 46 m;
## al raggio di oggi il produttore da' **2,275 m** su anelli a **12,60 / 27,30 m**,
## e `tests/test_arena.gd` li stampa **ogni volta**, letti dal produttore.
##
## ## m12: QUATTRO CHIAMATE E UNA CONCATENAZIONE, e l'errore che aspetta
##
##     layout(radius)          ->  OBSTACLE_COUNT dischi su UN piano    (prima)
##     layout(radius, floor)   ->  OBSTACLE_COUNT dischi del piano     (adesso)
##
## Prendere **solo il primo risultato** e' l'errore che non si vede: la scena
## sembrerebbe montata e i tre piani superiori avrebbero un campo senza muri. Quindi
## qui sotto quattro chiamate, una per piano, **concatenate in un unico
## `PackedVector3Array`** — la forma di `Game.obstacles` **non cambia** e resta
## quella che leggono tre foglie.
##
## ## IL PIANO DI UN OSTACOLO E' LA **POSIZIONE NELL'ARRAY**, e non `floor_of()`
##
## Nell'elemento `Vector3(centro_x, RAGGIO, centro_z)` il raggio sta in `y`: `y`
## **non e' la quota del piano**. `floor_of(element.y)` con `floor_height = 20,0`
## vale `0` per **tutti** i dischi di tutti e quattro i piani, perche'
## `2,275 / 20,0 = 0`: quindi la torre che «non attraversa il pavimento»
## attraverserebbe i muri. Il taglio e' per **indice** — `OBST.slice_floor()` di
## `-orda` e `size() / floor_count` di `-gameplay` convergono gia' su questo, e non
## se ne sceglie un terzo modo — e questa e' la **forma** che `-arena` mette in
## scena: `arena_obstacles.gd` alza il disco `i` alla quota del suo piano letta dallo
## stesso indice.
##
## ## LA CONVENZIONE, detta quattro volte perche' e' l'unica cosa che si sbaglia
##
##     elemento = Vector3(centro_x, RAGGIO, centro_z)
##
## **Il raggio sta in `y`.** `y` non e' un'altezza e `z` non e' una profondita':
## sono la seconda e la terza coordinata del centro del disco sul piano XZ.
## `elemento.y > 0.0` e' un **invariante**, non una convenzione (punto 3 della
## semantica congelata), e `obstacles_payload()` lo rifiuta invece di registrarlo.
##
## Il **numero** di ostacoli e il **raggio** sono di `-orda`; la **forma** disegnata
## (cilindro) e il **colore** sono di -arena e stanno in
## `src/render/arena_obstacles.gd`.
##
## ## Perche' un `preload` del file di un'altra foglia, qui, e non altrove
##
## La regola di 5 vieta prendere con `get_node("../..")` un dato che l'API non
## espone, perche' quello e' copiare una conoscenza. Qui la differenza e' tre,
## e tutte dichiarate: il **proprietario** del dato (`src/sim/obstacles.gd` e' di
## `-orda`), il fatto che ne esista **un solo produttore**, e il fatto che quello
## che ci metto dentro — il cilindro, l'altezza, i 12 segmenti, il colore — e'
## mio. Il file di `-orda` non viene toccato: e' una dipendenza dichiarata, che
## e' il contrario di una copia.
const OBST := preload("res://src/sim/obstacles.gd")

## Il produttore della **forma** della rampa, di questa stessa foglia.
##
## Non e' una copia e non e' una dipendenza circolare: `arena_ramp.gd` non
## preloada niente (il suo `TILE` lo **legge a runtime**), quindi qui dentro il
## `preload` non richiama nulla. La stessa forma di `OBST` sopra, ma con il
## proprietario dentro la stessa foglia: `_surface_height_at()` **chiama**
## `in_corridor()`, `ramp_inner()`, `ramp_outer()` e `ramp_axis()` invece di
## rifare la corsa della rampa a mano.
const RAMP := preload("res://src/render/arena_ramp.gd")

## I dischi che l'arena mette in scena: **derivati**, non scritti.
##
## Non e' una `const` perche' `layout()` e' una funzione, e questa e' una
## dipendenza che si risolve **una volta sola**, all'avvio del nodo, prima di
## `_enter_tree()`. Da li' in poi la lista non cambia (punto 1 della semantica
## congelata: gli ostacoli sono statici), quindi nel ciclo di gioco non si
## rilegge niente e non si ricostruisce niente.
##
## ## m12: QUATTRO CHIAMATE, UNA PER PIANO, **CONCATENATE**
##
##     for f in FLOOR_COUNT:
##         flat.append_array(OBST.layout(ARENA_RADIUS, f))
##
## `Game.obstacles` resta **un `PackedVector3Array` piatto**: la forma non cambia
## e i tre lettori (`player.gd`, `horde.gd`, `flow_field.gd`) non si accorgono di
## nulla. Il totale e' `OBST.OBSTACLE_COUNT x FLOOR_COUNT` e nessuna cifra qui
## sotto; il taglio in quattro blocchi **consecutivi** e' l'unico posto in cui il
## taglio e' scritto per legge: `OBST.slice_floor(obs, f, FLOOR_COUNT)` di `-orda` e
## `size() / floor_count` di `-gameplay` convergono gia' su questo, quindi qui non se ne
## sceglie un terzo modo.
##
## ## LA RIGA E' **VUOTA** ALL'ISTANTE, E QUESTO E' IL PUNTO
##
## Era `var OBSTACLE_LAYOUT: PackedVector3Array = _quattro_piani()`. Un inizializzatore
## di `var` gira **all'istanziazione** del nodo, cioe' quando `arena_main.tscn` viene
## `instantiate()`, e quindi **prima** di `_enter_tree()` e **prima** che
## `_register_floors(game)` scriva `floor_count` e `floor_height` nel contratto.
##
## La conseguenza non era un crash, era il difetto peggiore: `OBST.layout()` legge
## `Game.floor_count` **durante** la costruzione, trovava il **default** dichiarato
## (`1`) e lanciava l'errore che giustamente diceva «chiedo il piano 1 ma il
## contratto ne conosce 1». E non solo i dischi erano nel posto sbagliato: anche
## `Game.ramp_angle(f)` — che `-orda` usa per la fase degli anelli e che **questa
## foglia** usa per l'asse delle rampe — leggeva `floor_count`, quindi anche il mio
## angolo era quello di una torre inesistente.
##
## Quindi l'array si **riempie in `_register_obstacles()`**, che `_register()` chiama
## **dopo** `_register_floors(game)`. Non e' tolleranza e non e' un ordine fra pari:
## `game.set("floor_count", ...)` deve essere **avvenuto** prima che la lista si
## costruisca, e l'unico posto in cui questo e' garantibile e' la sequenza di
## `_register()`.
var OBSTACLE_LAYOUT: PackedVector3Array = PackedVector3Array()

## Le quattro chiamate al produttore, in un unico array.
##
## E' una **funzione** e non un blocco di codice dentro l'inizializzatore perche'
## l'inizializzatore di un `var` non ammette un `for` con `append_array`: la
## forma che ammette e' la chiamata a una funzione, e la funzione sta qui sotto.
##
## ## PERCHE' IL PIANO VIENE DA `FLOOR_COUNT` E NON DA `Game.floor_count`
##
## Il ciclo e' su `FLOOR_COUNT`, la **costante di questa foglia**, e non sul valore
## che il contratto sta per ricevere: se leggesse il contratto, e il contratto
## non fosse ancora stato scritto, il ciclo farebbe **zero iterazioni** e produrrebbe
## una lista vuota — cioe' esattamente il difetto che questa funzione e' stata
## spostata per chiudere. La costante e' la dichiarazione di *quanti piani questa
## torre ha*; il contratto ne riceve la notizia **subito dopo**, e da lì in poi i
## due devono coincidere. Che coincidano e' un criterio, non un'assunzione.
static func _quattro_piani() -> PackedVector3Array:
	var flat := PackedVector3Array()
	for piano in FLOOR_COUNT:
		flat.append_array(OBST.layout(ARENA_RADIUS, piano))
	return flat

## ## IL FATTORE CORPO: `SIZE_FACTOR` e' di -arena, e lo registra questo file
##
## E' l'ennesima volta la stessa forma, e questa volta **il numero e' mio**: lo
## dichiara `src/render/horde_renderer.gd`, che e' di questa stessa foglia.
##
## Il contratto (`src/core/contracts.gd`, m11) dichiara
## `Game.enemy_body_scale` perche' `-orda` ne ha bisogno: senza quel canale la
## simulazione non sa **quanto e' grosso il corpo che si vede**, quindi per
## mordere alla distanza giusta dovrebbe **copiare** `3.4` da qui, e una copia
## mente alla prima riga cambiata — il difetto delle sei copie di m9, gia' pagato
## una volta.
##
## Quindi qui sotto **non c'e' un numero scritto**: c'e' il posto dove va letto.
## `3.4` compare in due punti del progetto — la `const SIZE_FACTOR` del renderer
## e il **default dichiarato** del contratto — ed e' esattamente cosi' che devono
## stare: il default e' il valore **di prima** che l'arena si registri (che e' la
## condizione per cui la scena si carica anche senza nessuna piramide montata), e
## non una seconda fonte. Se i due divergessero, nessuno se ne accorgerebbe: il
## canale funziona **finche' coincidono per caso**, e la coincidenza non e' un
## contratto. `tests/test_arena.gd` chiude il canale: mette il campo a `99.0`
## **prima** di montare la scena, e il valore che si legge dopo puo' essere solo
## quello che esce da qui sotto.
##
## Il `preload` e' lecito per la stessa ragione di `OBST` qui sopra: il
## **proprietario** del numero e' dichiarato ed e' lo stesso file di -arena, il
## dato ha **un solo produttore**, e quello che ci metto dentro (la registrazione)
## e' mio. Se il renderer cambiasse il fattore, il contratto cambierebbe da solo.
const RENDERER := preload("res://src/render/horde_renderer.gd")

var _hud: Node = null
var _registered: bool = false
var _warned_no_hud: bool = false
var _warned_no_contract: bool = false
## Due avvisi di m10, emessi una volta sola. Sono `push_warning` e non
## `push_error` perche' dicano il difetto **senza** sporcare il log di un errore di
## GDScript: la porta che deve andare rossa su questo e' `tests/test_arena.gd`, che
## nomina il difetto e il suo rimedio, e non un avviso che nessuno legge.
var _warned_no_obstacles_field: bool = false
var _warned_empty_layout: bool = false
## Lo stesso per il fattore corpo di m11: se il vertice toglie il campo dal
## contratto, l'assegnazione qui sotto diventa un SCRIPT ERROR e il canale
## semplicemente non esiste, in silenzio.
var _warned_no_body_scale_field: bool = false
## Gli stessi due avvisi per i due campi della torre. Vedi `_register_floors()`:
## il difetto di quei due campi e' **piu' subdolo** di quello degli ostacoli,
## perche' il ripiego (`floor_count = 1`, `floor_height = 0,0`) e' un mondo
## **piu' piccolo** e non un insieme vuoto: passa tutto e non dice niente.
var _warned_no_floor_count_field: bool = false
var _warned_no_floor_height_field: bool = false
## La camera risolta **pigramente** al primo richiamo di `ground_visible()`, e il
## motivo sta accanto a `_register_apis()`: in `_enter_tree()` il nodo `Camera`
## non e' ancora dentro l'albero, quindi una `Callable` legata a **lui** sarebbe
## una `Callable` su un nodo che non esiste, e il contratto la scarterebbe al
## primo richiamo (`_live()`). Legata a `self`, che vive, e risolvibile.
var _camera_cache: Node3D = null
var _warned_no_camera: bool = false
var _warned_no_surface: bool = false

func _enter_tree() -> void:
	# `_enter_tree()`, non `_ready()`, e la ragione sta nell'ordine.
	#
	# I figli di questa scena costruiscono roba in `_ready()`: il terreno legge
	# `arena_radius` per decidere quanto e' largo il pavimento e il muro, e
	# l'orda lo legge per disporre i suoi 200 nemici. Ma il `_ready()` di un
	# padre viene DOPO il `_ready()` di tutti i suoi figli: registrarsi in
	# `_ready()` significava che i figli costruivano leggendo il valore che il
	# contratto aveva per caso, e il contratto lo dichiara per comodita'. Il
	# risultato era un'arena costruita con il raggio sbagliato appena
	# qualcosa scriveva un altro valore prima del caricamento.
	#
	# `_enter_tree()` scende: arriva prima del `_ready()` di ogni figlio.
	# Resta un'unica registrazione, fatta all'avvio e non nel ciclo di gioco,
	# che e' cio' che il piano 5.1 chiede: un dato dell'owner, assegnato una
	# volta sola.
	_register()

func _ready() -> void:
	_hud = get_node_or_null("Hud")
	# Idempotente: se qualcuno ha registrato il raggio prima di questo punto,
	# `_register()` non fa niente. Se invece non e' ancora successo, questa e'
	# l'ultima occasione.
	_register()

func _register() -> void:
	if _registered:
		return
	_registered = true
	var game := _contract()
	if game == null:
		if not _warned_no_contract:
			_warned_no_contract = true
			push_warning("arena: autoload Game non trovato, l'arena resta senza raggio")
		return
	game.arena_radius = ARENA_RADIUS
	# ## m12: i due numeri della torre, **accanto al raggio e nella stessa forma**.
	#
	# Stessa regola, stesso `_enter_tree()`, stessa fonte unica: se i due non
	# fossero qui, `-orda` leggerebbe `floor_count = 1` e `floor_height = 0,0` (i
	# **default** dichiarati del contratto) e costruirebbe **una** griglia e **un**
	# campo di percorrenza: la torre non si accende e nessuna asserzione lo
	# direbbe, perche' il valore di default e' un numero plausibile.
	#
	# I campi si scrivono con `game.set(...)` e non con `game.floor_count = ...`
	# perche' se il vertice li toglie dal contratto l'assegnazione diretta diventa
	# un SCRIPT ERROR e **tutto** l'avvio della scena si porta via, mentre `set()`
	# lascia un avviso e il resto del mondo regge. E' la stessa difesa di
	# `_register_body_scale()` e `_register_obstacles()` qui sotto, e lo stesso
	# difetto che quelle due sezioni chiudono.
	_register_floors(game)
	_register_body_scale(game)
	_register_obstacles(game)
	_register_apis(game)

## ## I DUE NUMERI DELLA TORRE: `Game.floor_count` e `Game.floor_height`
##
## `game.set()` invece dell'assegnazione diretta, e il motivo e' scritto sopra: un
## campo che il vertice toglie non deve portare via l'avvio della scena. Qui pero'
## la difesa e' doppia, perche' il difetto di questa registrazione e' **piu'
## subdolo** di quello degli ostacoli: se `floor_count` non arrivasse, `-orda`
## leggerebbe `1`, che e' **un numero valido** — un piano solo — e continuerebbe a
## girare senza errori con una griglia sola. Non e' un insieme vuoto che fa
## fallire un test: e' un mondo **piu' piccolo** di quello che si crede, e
## l'unica cosa che lo scopre e' un criterio che legge il valore registrato.
func _register_floors(game: Node) -> void:
	var piano = game.get("floor_count")
	if not (typeof(piano) == TYPE_INT or typeof(piano) == TYPE_FLOAT):
		if not _warned_no_floor_count_field:
			_warned_no_floor_count_field = true
			push_warning("arena: il contratto NON dichiara il campo `floor_count`. `src/core/contracts.gd` e' del vertice e -arena non lo tocca: senza `var floor_count: int` l'assegnazione qui sotto e' un SCRIPT ERROR, -orda legge il default 1 e costruisce una griglia sola, e la torre non esiste senza che nessuna porta se ne accorga.")
		return
	var quota = game.get("floor_height")
	if not (typeof(quota) == TYPE_FLOAT or typeof(quota) == TYPE_INT):
		if not _warned_no_floor_height_field:
			_warned_no_floor_height_field = true
			push_warning("arena: il contratto NON dichiara il campo `floor_height`. Senza `var floor_height: float` l'assegnazione qui sotto e' un SCRIPT ERROR e `Game.floor_of()` restituisce 0 perche' divide per 0,0: tutti i piani diventano il piano 0. Il campo e' dichiarato in src/core/contracts.gd, che e' del vertice.")
		return
	game.set("floor_count", FLOOR_COUNT)
	game.set("floor_height", FLOOR_HEIGHT)

## ## LE DUE API DI `-arena`: `ground_visible` e `surface_height_at`
##
## Entrambe stanno qui, in `_enter_tree()`, e **non** in `_ready()`, per una
## ragione che non e' stile: i figli di questa scena hanno `_ready()` **prima**
## del padre, e fra loro c'e' `-orda`, che chiama `Game.ground_visible()` dal suo
## `_ready()` quando costruisce il campo di percorrenza. Registrata qui sotto, in
## `_ready()`, la regola di nascita fuori schermo avrebbe letto il **neutro
## dichiarato** del contratto — `true`, «il punto si vede, scartalo» — e
## l'orda avrebbe **scartato ogni candidato**: zero nemici, e nessun errore.
##
## ## LA FORMA LUNGA, e perche' `self` non basta
##
## `register_impl("ground_visible", self)` risolve `self.ground_visible()`, che
## questo file non ha: i due metodi si chiamano `_ground_visible` e
## `_surface_height_at`. Quindi la forma lunga, `self._ground_visible`, non e' una
## scelta di stile ma l'unica che registra il metodo giusto — e' la stessa nota
## che c'e' in `player.gd::_enter_tree()` per `player_floor`.
func _register_apis(game: Node) -> void:
	game.register_impl("ground_visible", self._ground_visible)
	game.register_impl("surface_height_at", self._surface_height_at)

## ## IL FATTORE CORPO: la registrazione di `Game.enemy_body_scale` (m11)
##
## Va in `_enter_tree()` come il raggio e come gli ostacoli, e per la **stessa**
## ragione: `-orda` legge questo numero per decidere a che distanza morre, e se
## l'arena lo registrasse in `_ready()` il lettore avrebbe gia' costruito il campo
## di percorrenza sopra il **default** del contratto. Il default e' dichiarato
## uguale al valore reale apposta perche' la scena si carichi anche da sola, ma
## «il default dice la stessa cosa» **non e'** «il canale funziona»: sono due
## numeri che oggi coincidono e che nessuno guarderebbe se smettessero.
##
## E' **idempotente** per costruzione: `_register()` non fa niente una seconda
## volta, quindi qui dentro c'e' una riga sola e non una per tentativo.
func _register_body_scale(game: Node) -> void:
	if not _contract_has_body_scale(game):
		if not _warned_no_body_scale_field:
			_warned_no_body_scale_field = true
			push_warning("arena: il contratto NON dichiara il campo `enemy_body_scale`. La superficie di m11 e' documentata in src/core/contracts.gd ma il campo non e' dichiarato: senza la riga `var enemy_body_scale: float` l'assegnazione qui sotto e' un SCRIPT ERROR e il fattore corpo non viene mai registrato, quindi -orda leggerebbe il default e morrebbe alla distanza sbagliata senza che nessuna porta lo veda. Il file e' del vertice: -arena non lo tocca.")
		return
	game.set("enemy_body_scale", RENDERER.SIZE_FACTOR)

## Il contratto dichiara `enemy_body_scale`?
##
## Come per gli ostacoli, la risposta si prende dal **valore** e non dalla lista
## delle proprieta'. Il campo e' un `float` dichiarato con un default, quindi un
## contratto che lo dichiara restituisce un numero e un contratto che non lo
## dichiara restituisce `null`: i due si distinguono col `typeof` senza dover
## conoscere il nome del file del vertice. Il valore **non** viene confrontato qui:
## se il vertice cambiasse il default, il confrontatore e' `tests/test_arena.gd`,
## che legge entrambi i numeri e li stampa.
func _contract_has_body_scale(game: Node) -> bool:
	var v = game.get("enemy_body_scale")
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT

## ## L'OSTACOLO: la registrazione di `Game.obstacles` (m10)
##
## Va in `_enter_tree()` come il raggio, e per la **stessa** ragione: il nodo
## `Obstacles` costruisce il suo buffer nel proprio `_ready()`, e i figli leggono
## prima del padre. Quindi se l'ordinasse qui dentro, l'orda troverebbe un array
## vuoto e costruirebbe il campo di percorrenza **sopra una mappa senza muri**, che
## e' il difetto che il punto 5 della semantica congelata nomina con parole.
##
## E' **idempote** per costruzione: `_register()` non fa niente una seconda volta.
func _register_obstacles(game: Node) -> void:
	# ## LA LISTA SI COSTRUISCE **QUI**, E `game.floor_count` DEVE GIA' ESSERCI
	#
	# `_register()` chiama `_register_floors(game)` **prima** di questa funzione, e
	# l'ordine non e' una convenzione: `OBST.layout()` e `Game.ramp_angle()` leggono
	# `Game.floor_count` **durante** la costruzione della lista. Se questa riga stesse
	# in un inizializzatore di `var`, girerebbe all'istanziazione del nodo — prima di
	# `_enter_tree()`, quindi prima della registrazione — e costruirebbe quattro piani
	# con un contratto che ne conosce uno. Non si allarga la guardia di `-orda`: si
	# mette la costruzione **dopo** la registrazione, che e' l'unico ordine in cui la
	# guardia ha ragione di tacere.
	#
	# Il `if` e' una difesa, non una forma: `_register()` e' idempotente, quindi qui si
	# arriva una volta sola. Se un domani qualcuno chiamasse `_register_obstacles()` due
	# volte, la seconda non deve ricalcolare e **soprattutto** non deve farlo a metà,
	# quando il contratto ha un altro `floor_count`.
	if OBSTACLE_LAYOUT.is_empty():
		OBSTACLE_LAYOUT = _quattro_piani()
	if not _contract_has_obstacles(game):
		if not _warned_no_obstacles_field:
			_warned_no_obstacles_field = true
			push_warning("arena: il contratto NON dichiara il campo `obstacles`. La superficie di m10 e' documentata in src/core/contracts.gd ma il campo non e' dichiarato: senza la riga `var obstacles: PackedVector3Array` l'assegnazione qui sotto e' un SCRIPT ERROR e gli ostacoli non si registrano. Il file e' del vertice: -arena non lo tocca.")
		return
	game.set("obstacles", obstacles_payload())

## Il contratto dichiara `obstacles`?
##
## La risposta si prende dal **valore**, non dalla lista delle proprieta': un campo
## dichiarato e non inizializzato restituisce una `PackedVector3Array` **vuota**, e
## una `PackedVector3Array` vuota e' diversa da `null`. Quindi `get()` distingue i
## due casi senza bisogno di una seconda fonte, e la registrazione comincia a
## funzionare da sola il giorno che il vertice aggiunge la riga — senza che
## nessun file di -arena debba essere cambiato.
func _contract_has_obstacles(game: Node) -> bool:
	return game.get("obstacles") is PackedVector3Array

## ## I DISCHI CHE -ARENA REGISTRA: la lista che esce dal produttore unico
##
## Non si ricopia niente: `OBSTACLE_LAYOUT` e' gia' il risultato di
## `OBST.layout(ARENA_RADIUS)`. Qui si fa solo la **validazione** e la conversione
## al tipo del contratto, che e' un'altra operazione (validare non e' copiare:
## copiare sarebbe riscrivere i numeri a mano, e il punto 5 della semantica
## congelata chiede che un insieme vuoto sia un **errore**, non un mondo senza
## muri).
##
## Non si scarta l'elemento cattivo e si registra il resto: un ostacolo non
## registrato e' un muro **invisibile**, cioe' il difetto esatto che il criterio n.
## 6 mette per meta' di -arena («l'ostacolo deve essere **visibile** dove e'
## solido»). Quindi una lista con un raggio nullo o negativo **non viene registrata
## tutta**: e' un difetto di scrittura, e si dice con un `push_error` che nomina
## l'indice invece di produrre una mappa che sembra chiusa e non lo e'.
func obstacles_payload() -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in OBSTACLE_LAYOUT.size():
		var e: Vector3 = OBSTACLE_LAYOUT[i]
		if not (e.y > 0.0):
			push_error("arena: OBSTACLE_LAYOUT[%d] ha raggio %.3f: il raggio sta in `y` e deve essere > 0. L'elenco non viene registrato per intero." % [i, e.y])
			return PackedVector3Array()
		out.append(e)
	if out.is_empty() and not _warned_empty_layout:
		_warned_empty_layout = true
		push_error("arena: OBST.layout(%.1f) ha restituito **zero** dischi, quindi nessun ostacolo viene registrato ne' disegnato. Un insieme vuoto non e' un mondo senza muri: e' la piramide non montata. Il produttore e' src/sim/obstacles.gd (-orda), il canale e' dichiarato in src/core/contracts.gd." % ARENA_RADIUS)
	return out

# --- Le due API di -arena ------------------------------------------------------
#
# ## PERCHE' SONO QUI E NON IN UN ALTRO FILE
#
# `ground_visible` e `surface_height_at` sono **entrambe** di questa foglia e
# rispondono entrambe a una domanda sulla **mia** geometria: «da questo punto, a
# questa quota, cosa c'e' sotto?». Dividerle fra due file avrebbe messo la camera
# in un file e la rampa in un altro per un motivo che non e' un motivo. Quindi
# stanno accanto ai dati che le rendono possibili, e `Camera` e `Ramps` sono
# **figli di questo stesso nodo**: una ricerca `get_node_or_null` verso il basso,
# mai `get_node("../..")` — che e' la dipendenza circolare che il piano vieta.

## ## `Game.ground_visible(punto)`: IL PUNTO E' FUORI SCHERMO?
##
## **Non e' un raggio.** Il contratto lo dice e il motivo e' scritto accanto: la
## camera e' inclinata di `BACK`, quindi l'impronta a terra e' un **trapezio** e la
## distanza fuori schermo va da una parte all'altra a **3,47 volte** la stessa
## distanza. Un raggio costante farebbe nascere un nemico a 1,37 s da una parte e a
## 4,84 s dall'altra.
##
## Percio' qui **non c'e' nessun numero**: si chiede alla **camera**, che e' il
## posto da cui nasce quel trapezio, se il punto ci sta dentro. La camera ha gia'
## `is_position_in_frustum()` e questa funzione **non ne riscrive una copia**: una
## copia andrebbe stale al primo ritocco di `HEIGHT`, `BACK` o `fov`, e il difetto
## di m9 (numeri copiati in piu' posti) tornerebbe qui sotto un altro nome.
##
## ## E PERCHE' IL PIANO E' **RELATIVO AL GIOCATORE**
##
## Il contratto passa il punto con `y = 0` (`contracts.gd::ground_visible`
## scrive `Vector3(punto.x, 0.0, punto.z)`), quindi la `y` **non porta
## informazione**: il piano da cui misurare **non puo' venire dal punto** e viene
## dal **giocatore**. Ed e' l'unica scelta giusta: la domanda che il chiamante fa
## e' «questo punto si vede **adesso**?», e «adesso» e' il piano su cui sta
## guardando la camera, cioe' quello del giocatore.
##
## Il difetto che questo chiude e' concreto: con la camera ferma a quota zero e
## `floor_height = 20,0`, l'impronta a terra e' quella **del piano 0**, e un punto
## a 30 m dal centro **sul piano 3** — che e' dentro l'impronta della camera che
## guarda il piano 3 — verrebbe dichiarato fuori schermo. Il chiamante lo
## scarterebbe e il nemico non nascerebbe **dove si vede**.
##
## ## **LA REGOLA NON E' ANCORA MONTATA**, e questa riga e' la dichiarazione
##
## Misurato il 2026-10-17 con una `grep` su tutto `src/`: **`ground_visible` non ha un
## solo chiamante**. Quindi il canale e' registrato, risponde, e **nessuno lo chiede**:
## la regola di nascita fuori schermo di §1.14-ventiquarta («i nemici nascono fuori
## dallo schermo») **non e' in produzione**.
##
## Non e' un difetto di questa funzione e non e' un difetto di `-orda`: il chiamante
## naturale e' lo `Spawner`, che sceglie dove far nascere un nemico, e la sua scelta
## compete con «fuori mappa», che e' un vincolo **nuovo** di m12. Collegarlo e' una
## decisione di `-orda` e si fa quando si collega l'onda delle armi.
##
## **Perche' la dichiarazione sta qui e non solo nel piano**: un canale registrato
## sembra una funziona viva, e fra sei mesi chi legge `register_impl("ground_visible")`
## puo' credere che la regola sia montata. Il sintomo di quell'equivoco e' silenzioso —
## nessun errore, i nemici nascono dove nascevano prima — quindi la dichiarazione deve
## stare **dove il canale si registra**, accanto al codice che lo rende disponibile.
func _ground_visible(punto: Vector3) -> bool:
	var cam := _camera()
	if cam == null:
		# Il **neutro dichiarato** del contratto e' `true` («si vede, scartalo») e
		# non `false`: non registrata, la funzione direbbe «non si vede», tutti i
		# candidati passerebbero e i nemici comparirebbero a schermo senza che
		# nessuna porta se ne accorga. Qui si restituisce lo stesso neutro e si
		# dice **perche'** una volta sola. Il risultato e' zero nemici: si vede.
		if not _warned_no_camera:
			_warned_no_camera = true
			push_warning("arena: nessuna Camera3D sotto questa arena, quindi ground_visible() non puo' rispondere e restituisce il neutro dichiarato del contratto (true, «si vede»: il chiamante scarta il punto). Il risultato e' **zero nemici**, e la regola di nascita fuori schermo non e' montata. La camera e' src/render/arena_camera.gd.")
		return true
	var piano := _piano_del_giocatore()
	var quota := float(piano) * _floor_height_del_contratto()
	return bool(cam.call("is_position_in_frustum", Vector3(punto.x, quota, punto.z)))

## Il piano su cui il giocatore e' **fermato**, non quello in cui sta **passando**.
##
## Il contratto dichiara `player_floor()` per questa esatta domanda
## (`contracts.gd`, sopra `player_floor`): durante una rampa il giocatore e'
## **fra due piani** e `floor_of(y)` su un'altezza di meta' banda restituirebbe il
## piano sbagliato **con sicurezza**. Quindi qui si chiede l'API, e solo se non
## c'e' si ripiega su `floor_of()`: il ripiego e' dichiarato perche' e' un mondo
## senza `-gameplay` (una porta su uno script solo), non un silenzio.
func _piano_del_giocatore() -> int:
	var game := _contract()
	if game == null:
		return 0
	if game.has_impl("player_floor"):
		return clampi(int(game.player_floor()), 0, FLOOR_COUNT - 1)
	return clampi(int(game.floor_of(_y_del_giocatore())), 0, FLOOR_COUNT - 1)

## La quota `y` del giocatore, dal contratto: `Game.player_position()` se c'e',
## altrimenti il campo `Game.player` — **entrambi dati dichiarati**, mai un
## `get_node("../..")`.
func _y_del_giocatore() -> float:
	var game := _contract()
	if game == null:
		return 0.0
	if game.has_impl("player_position"):
		return (game.player_position() as Vector3).y
	var player = game.get("player")
	if player is Node3D:
		return (player as Node3D).global_position.y
	return 0.0

## ## `Game.surface_height_at(punto, piano)`: LA QUOTA DELLA RAMPA
##
## E' il canale che fa salire il giocatore, e `-gameplay` ne ha gia' scritto il
## lato suo: `player.gd::_move()` chiama questo metodo e, se la risposta e' `>= 0`,
## scrive `position.y = quota`. **La quota arriva per assegnazione, non per
## integrazione**: `velocity.y` resta `0,0` e nessuna gravita' e' comparsa. Quindi
## il divieto di «nessun sistema di movimento» e' rispettato per costruzione e non
## per dichiarazione.
##
## ## LA FIRMA, E IL SUO SIGNIFICATO IN DUE RIGHE
##
##     _surface_height_at(punto: Vector2, piano: int) -> float
##
## `piano` e' **il piano che la rampa LASCIA**, e va da `0` a `FLOOR_COUNT - 2`:
## sono le **transizioni**, non i piani. La domanda che il chiamante fa e' «**c'e'
## una rampa che parte** dal mio piano?», e l'ultimo piano e' una destinazione: non ha
## niente sopra di se', quindi `surface_height_at(punto, FLOOR_COUNT - 1)` ha una sola
## risposta possibile, `-1,0`. Vedi la nota sotto perche' l'avevo letta al contrario e
## cosa e' costato.
##
## ## PERCHE' `-1,0` E NON `0,0`, E PERCHE' LA RAGIONE E' DICHIARATA QUI
##
## `0,0` **e' una quota vera** — il fondo della prima rampa e' esattamente `y = 0`
## — e sarebbe indistinguibile dal «non c'e' niente qui». Un chiamante che
## scrivesse `position.y = q` senza guardare il segno **teletrasporterebbe il
## giocatore a quota zero** da qualunque parte dell'arena. Quindi il `-1,0` non e'
## un fallback silenzioso: e' l'unico modo di dire «qui non c'e' superficie», e il
## chiamante lo guarda (`q >= 0.0`).
##
## ## LA RISPOSTA E' **DERIVATA**, NON SCRITTA
##
## La domanda «il punto e' sotto la rampa?» ha una risposta sola ed e'
## `RAMP.in_superficie()`, e la quota e' l'interpolazione sulla stessa corsa con cui
## la mesh e' stata costruita (`RAMP.ramp_inner()` / `RAMP.ramp_outer()`). Nessuna
## formula nuova qui dentro: se il produttore cambiasse la forma della rampa,
## questa risposta cambierebbe da sola.
##
## ## PERCHE' `in_superficie()` E NON `in_corridor()`, CHE E' IL SUO SOTTOSET
##
## `in_corridor()` e' la striscia **ritagliata** e risponde al buco nel pavimento.
## Qui la domanda e' un'altra — «c'e' superficie su cui stare?» — e la differenza e'
## la **spianata d'arresto**, che e' superficie ma **non** e' buco. Con
## `in_corridor()` la testa della rampa era il punto piu' alto raggiungibile, cioe'
## `floor_height * (1 - passo/corsa)`: il giocatore **non poteva mai essere
## esattamente sul piano di arrivo**, e `player_floor()` — che cambia solo
## all'atterraggio — restava sul piano di sotto **per sempre**. Non e' un
## arrotondamento, e' **il tetto del predicato**.
##
## ## `piano` E' **IL PIANO CHE LA RAMPA LASCIA**, e l'errore di mezzo era qui
##
## Il vincolo e' dichiarato dal vertice ed e' l'opposto di come l'avevo letto io:
##
##     rampa 0   parte dal piano 0  e arriva al piano 1
##     rampa 1   parte dal piano 1  e arriva al piano 2
##     rampa 2   parte dal piano 2  e arriva in cima al piano 3
##
## Il chiamante di `-gameplay` fa la domanda che ha senso: «**c'e' una rampa che
## parte** dal mio piano?». Con la numerazione che avevo scritto — `piano` = il piano
## di **arrivo**, indice `piano - 1` — un giocatore sul piano 0 chiedeva la rampa che
## **arriva** al piano 0, che non esiste: risposta `-1,0` e **il giocatore non saliva
## mai**. Il sintomo era una riga di stampa: `dopo 60 passi il giocatore e' a y =
## 0,000 m` sulla torre vera.
##
## Quindi `piano` va da **`0` a `FLOOR_COUNT - 2`**: l'ultimo piano e' una
## **destinazione**, non ha niente sopra di se', e chiedere una rampa che lo lascia
## ha una sola risposta possibile, `-1,0`.
##
## ## PERCHE' I **BUCHI** NON SI SPOSTANO, e questa e' la parte delicata
##
## Il buco nel pavimento e' sul piano di **arrivo**: `_in_il_buco(piano)` chiama
## `in_corridor(piano - 1, ...)` in `arena_ground.gd`, e cosi' deve restare. Il
## collider del prisma e' sulla rampa `i`, e cosi' deve restare. **Cambia solo chi
## domanda**: il buco chiede «dov'e' la rampa che arriva su di me» e il canale
## risponde «dov'e' la rampa che parte da me». Se si spostasse anche il buco,
## pavimento e rampa si disaccorderebbero — ed e' esattamente il difetto che
## `tests/test_arena.gd::_torre_terreno` conta piastrella per piastrella.
func _surface_height_at(punto: Vector2, piano: int) -> float:
	# ## LA VALIDITA' DEL PIANO: `[0, FLOOR_COUNT - 1)`, cioe' le transizioni.
	if piano < 0 or piano > FLOOR_COUNT - 2:
		return -1.0
	var tile := _tile_size()
	if tile <= 0.0:
		if not _warned_no_surface:
			_warned_no_surface = true
			push_warning("arena: non riesco a leggere TILE da src/render/arena_ground.gd, quindi surface_height_at() risponde -1,0 a tutto e nessuno sale la rampa. Il produttore della geometria e' src/render/arena_ramp.gd e la scala e' src/render/arena_ground.gd.")
		return -1.0
	# ## L'INDICE DELLA RAMPA E' **IL PIANO STESSO**
	if not RAMP.in_superficie(piano, FLOOR_COUNT, ARENA_RADIUS, tile, punto):
		return -1.0
	var dentro := RAMP.ramp_inner(ARENA_RADIUS, tile)
	# ## LA CORSA VIENE DA `ramp_run()`, E IL `maxf` DI PRIMA ERA UN NASCONDIGLIO
	#
	# Qui c'era `maxf(ramp_outer - dentro, 0.001)`: se il produttore della geometria
	# avesse spinto la coda oltre la testa, quel `maxf` avrebbe sostituito «questa
	# rampa non esiste» con «questa rampa e' alta zero metri» e la quota sarebbe
	# uscita come una divisione per `0,001`, cioe' un numero enorme, senza che
	# nessuno lo vedesse. Oggi la corsa e' `RAMP.ramp_run()`, che restituisce anche
	# il numero negativo, e il `clampf` sotto tiene la risposta in `[0, 1]` anche se
	# la corsa fosse negativa.
	var corsa := RAMP.ramp_run(ARENA_RADIUS, tile)
	# ## L'ASSE E' **DI DUE DIMENSIONI**, e lo dice il produttore
	#
	# `punto` e' un punto a terra (`Vector2`) e l'asse della rampa e' una direzione:
	# la proiezione si fa in due dimensioni. E' `RAMP.axis2()`, che e' **normalizzata**,
	# perche' `ramp_inner`/`ramp_outer` sono soglie **in metri**: se l'asse non fosse
	# unitario la quota sarebbe una distanza contratta e la risposta non combacerebbe
	# con il buco ritagliato dal terreno — due copie della stessa proiezione, una
	# normalizzata e una no, e il sintomo sarebbe un pavimento e una rampa che non
	# combaciano. Per questo le due copie sono una sola funzione.
	var asse := RAMP.axis2(piano, FLOOR_COUNT)
	if asse == Vector2.ZERO:
		return -1.0
	var s := punto.dot(asse)
	var t := clampf((s - dentro) / corsa, 0.0, 1.0)
	# La quota parte dal pavimento **di partenza** e finisce a quello **di arrivo**.
	return float(piano) * FLOOR_HEIGHT + t * FLOOR_HEIGHT

## L'altezza di un piano **dal contratto**, con un ripiego dichiarato: `-1.0`
## significa «non c'e' una torre» e chi lo chiama lo tratta come tale. Il valore
## non e' mai scritto qui dentro.
func _floor_height_del_contratto() -> float:
	var game := _contract()
	if game == null:
		return -1.0
	var v = game.get("floor_height")
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return float(v)
	return -1.0

## La camera dell'arena, risolta **una volta sola** e tenuta.
##
## Perche' `get_node_or_null("Camera")` e non un campo letto in `_enter_tree()`:
## in `_enter_tree()` il nodo `Camera` **non e' ancora dentro l'albero**, quindi una
## `Callable` legata a lui sarebbe una `Callable` su un nodo che non esiste e
## `contracts.gd::_live()` la scarterebbe al primo richiamo, con un messaggio che
## parla di registrazioni morte e non di camere. Legata a `self`, che vive, e
## risolta qui al primo uso.
func _camera() -> Node3D:
	if _camera_cache != null and is_instance_valid(_camera_cache):
		return _camera_cache
	_camera_cache = get_node_or_null("Camera") as Node3D
	return _camera_cache

## Il lato della piastrella, letto da `arena_ground.gd` e **non riscritto qui**: e'
## la stessa unita' con cui il terreno conta le piastrelle, e due copie di una scala
## che cambia sono la copia che mente (la classe di difetto di m9).
##
## `-1.0` se il file non e' piu' leggibile o non dichiara `TILE`.
static func _tile_size() -> float:
	var scr = load("res://src/render/arena_ground.gd")
	if scr == null or not (scr is Script):
		return -1.0
	if not scr.has_method("get_script_constant_map"):
		return -1.0
	var map: Dictionary = scr.get_script_constant_map()
	if not map.has("TILE"):
		return -1.0
	var v = map["TILE"]
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return float(v)
	return -1.0

# --- Il ciclo di gioco --------------------------------------------------------

## Una volta per frame tiene il HUD allineato ai dati. Il giocatore e l'orda li
## prendo **dal contratto**, non dal albero della scena: e' il modo dichiarato
## per non avere due foglie che si cercano a vicenda (piano 5.3, regola 3).
##
## Le letture dei campi del giocatore sono fatte per nome e con un valore di
## riserva: `hp`, `max_hp`, `weapon` e `progression` sono campi pubblici di
## -gameplay, non parte del contratto, e se un domani ne cambia il nome l'HUD
## deve mostrare il numero di default invece di spaccare il gioco.
func _process(_delta: float) -> void:
	if _hud == null or not _hud.has_method("set_state"):
		if not _warned_no_hud:
			_warned_no_hud = true
			push_warning("arena: nessun HUD con set_state(): scena arena_main.tscn incompleta")
		return
	_hud.set_state(_health(), _health_max(), _kills(), _weapon_text(), _enemies(), _level())

func _health() -> float:
	var player := _player()
	return _num(player, "hp", 100.0)

func _health_max() -> float:
	var player := _player()
	return maxf(_num(player, "max_hp", 100.0), 0.0001)

func _kills() -> int:
	var player := _player()
	if player == null:
		return 0
	return int(_num(player.get("progression"), "kills", 0.0))

func _level() -> int:
	var player := _player()
	if player == null:
		return 1
	return int(_num(player.get("progression"), "level", 1.0))

func _weapon_text() -> String:
	var player := _player()
	if player == null:
		return "-"
	var weapon = player.get("weapon")
	if weapon == null:
		return "-"
	return "DMG %.1f every %.2fs" % [_num(weapon, "damage", 0.0), _num(weapon, "fire_interval", 0.0)]

func _enemies() -> int:
	var game := _contract()
	if game == null:
		return 0
	return int(_num(game.get("horde"), "count", 0.0))

func _player() -> Node:
	var game := _contract()
	if game == null:
		return null
	var player = game.get("player")
	# ## `is` SU UN'ISTANZA **LIBERATA** LANCIA, E UN `_process()` CHE GIRA
	# DOPO LA PROPRIA SCENA LEGGE NODI MORTI
	#
	# Misurato il 2026-10-18: `Left operand of 'is' is a previously freed instance.` a
	# questa riga. Il campo `player` del contratto puo' puntare a un giocatore la cui
	# scena e' stata liberata, e un oggetto liberato **non e' `null`**: quindi la forma
	# `player == null` passerebbe — ed e' la stessa che `-gameplay` ha chiuso due volte
	# un livello piu' in basso, in `projectile_pool.acquire()`.
	#
	# La domanda giusta qui e' «**esiste ancora?**», ed `is_instance_valid` e' la
	# risposta. E non e' una difesa da test: `arena.gd` gira in `_process()` nella
	# partita vera, e senza questa riga ogni sezione che libera e rimonta una scena
	# lascia un `_process()` che legge nodi morti — cioe' un difetto di produzione che
	# i test stanno scoprendo, non un difetto dei test.
	if is_instance_valid(player) and player is Node:
		return player
	return null

## Un campo che non c'e' vale il valore di riserva. `Object.get()` su un nome
## assente restituisce `null` e basta: la difesa sta nel controllo del tipo, non
## nel nome.
func _num(holder, key: String, fallback: float) -> float:
	if holder == null or not (holder is Object):
		return fallback
	var raw = (holder as Object).get(key)
	if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT:
		return float(raw)
	return fallback

# --- Interno ------------------------------------------------------------------

## Vedi la nota in `horde_renderer.gd`: l'autoload lo prido dal campo `/root`,
## perche' questi script possono essere caricati con `load()` anche dai test in
## `--script`, dove l'identificatore nudo `Game` non e' garantito (piano 5.3).
func _contract() -> Node:
	var tree := get_tree()
	if tree != null:
		return tree.root.get_node_or_null("Game")
	return null