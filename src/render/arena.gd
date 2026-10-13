extends Node3D
## La radice dell'arena: `scenes/arena_main.tscn`. Terreno, orda, nemici,
## giocatore, camera, HUD, e una sola registrazione sul contratto.
##
## ## L'unica cosa che arena registra
##
##     Game.arena_radius = 46.0
##
## E' un **dato**, quindi assegnazione diretta, una volta sola all'avvio (piano
## 5.1). Lo registro in `_enter_tree()` e non in `_ready()`: i figli di questa
## scena costruiscono il terreno e l'orda nel loro `_ready()`, che gira prima
## del mio. Il commento di `_enter_tree()` spiega perche'.
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
## ## PERCHE' 46.0: il numero non e' stato scelto, e' stato **misurato**
##
## Sonda `docs/piramide/probe_arena_density.gd` del vertice (piano 1.12): mette
## l'orda a regime e chiede **quanto spazio l'orda concede**, non quanto ne
## sembra. "Spazio libero" e' definito col numero che morde: un punto e' libero
## se dista da ogni nemico piu' di `RADIUS[kind] + TOUCH_REACH`. Griglia 0,5 m,
## DT 1/60, seme 4242, 900 passi di assestamento col giocatore fermo al centro.
## Sul terreno e sul muro a 28 m: la sonda misura lo spazio che l'orda concede,
## non quello che si vede.
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
## **Quello che questo numero NON risolve**, dichiarato perche' nessuno ricreda
## fra sei mesi che 46 sia stato scelto a occhio: lo spazio libero resta
## **frammentato in tasche** e l'anello di ~9,4 m intorno al giocatore **non si
## assottiglia**, perche' e' un numero di **simulazione** (popolazione e
## separazione, `SEPARATION_CHECKS = 6`) e non di mappa. Raddoppiare l'arena non
## scioglie l'orda: e' per questo che 46 e' un numero di simulazione e non una
## correzione di mappa.
const ARENA_RADIUS := 46.0

var _hud: Node = null
var _registered: bool = false
var _warned_no_hud: bool = false
var _warned_no_contract: bool = false

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