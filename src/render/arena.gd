extends Node3D
## La radice dell'arena: `scenes/arena_main.tscn`. Terreno, orda, nemici,
## giocatore, camera, HUD, e una sola registrazione sul contratto.
##
## ## L'unica cosa che arena registra
##
##     Game.arena_radius = 28.0
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

const ARENA_RADIUS := 28.0

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
	# contratto aveva per caso, e il contratto lo dichiara come 28.0 per
	# comodita'. Il risultato era un'arena costruita con il raggio sbagliato
	# appena qualcosa scriveva un altro valore prima del caricamento.
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