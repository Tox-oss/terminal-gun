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
## ## LA STORIA DEL NUMERO, IN DUE TEMPI, E PERCHE' 60.0
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
const ARENA_RADIUS := 60.0

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
## a essere letto, e `OBSTACLE_LAYOUT` ne e' il risultato — 27 dischi su tre
## anelli, che cambiano **insieme** al raggio perche' `src/sim/obstacles.gd`
## li dichiara come frazioni (`RADIUS_FRACTION = 0,065`, `RING_RADII = 0,33 /
## 0,59 / 0,85`) e non in metri. I numeri che erano stampati qui nel 2026-10-13
## (raggio 2,99 m su anelli a 15,18 / 27,14 / 39,10 m) erano misurati **con
## l'arena a 46 m**; a 60 m il produttore dà 3,90 m su anelli a 19,80 / 35,40 /
## 51,00 m, e `tests/test_arena.gd` li stampa ogni volta. Scriverli qui sarebbe la
## sesta copia di un numero che m9 ha gia' chiuso una volta (sei copie di `28.0`,
## nessuna porta rossa): due copie di un raggio che divergono sono il difetto, e
## la copia mente alla prima riga cambiata.
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

## I dischi che l'arena mette in scena: **derivati**, non scritti.
##
## Non e' una `const` perche' `layout()` e' una funzione, e questa e' una
## dipendenza che si risolve **una volta sola**, all'avvio del nodo, prima di
## `_enter_tree()`. Da li' in poi la lista non cambia (punto 1 della semantica
## congelata: gli ostacoli sono statici), quindi nel ciclo di gioco non si
## rilegge niente e non si ricostruisce niente.
var OBSTACLE_LAYOUT: PackedVector3Array = OBST.layout(ARENA_RADIUS)

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
	_register_body_scale(game)
	_register_obstacles(game)

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
	if player is Node:
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