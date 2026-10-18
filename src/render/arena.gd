extends Node3D
const ARENA_RADIUS := 35.0

const OBST := preload("res://src/sim/obstacles.gd")
const RENDERER := preload("res://src/render/horde_renderer.gd")

var OBSTACLE_LAYOUT: PackedVector3Array = PackedVector3Array()

var _hud: Node = null
var _registered: bool = false
var _warned_no_hud: bool = false
var _warned_no_contract: bool = false
var _warned_no_obstacles_field: bool = false
var _warned_empty_layout: bool = false
var _warned_no_body_scale_field: bool = false
var _camera_cache: Node3D = null
var _warned_no_camera: bool = false
## Scorrimento orizzontale in direzione W: quanto il mondo si e' spostato
## lungo l'asse W (Z) man mano che il giocatore avanza. Parte da zero e segue
## la posizione del giocatore; in headless (nessun input) resta zero.
var scroll_offset: Vector3 = Vector3.ZERO

func _enter_tree() -> void:
	_register()

func _ready() -> void:
	_hud = get_node_or_null("Hud")
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
	_register_apis(game)

func _register_apis(game: Node) -> void:
	game.register_impl("ground_visible", self._ground_visible)
	game.register_impl("surface_height_at", self._surface_height_at)

func _register_body_scale(game: Node) -> void:
	if not _contract_has_body_scale(game):
		if not _warned_no_body_scale_field:
			_warned_no_body_scale_field = true
			push_warning("arena: il contratto NON dichiara il campo enemy_body_scale")
		return
	game.set("enemy_body_scale", RENDERER.SIZE_FACTOR)

func _contract_has_body_scale(game: Node) -> bool:
	var v = game.get("enemy_body_scale")
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT

func _register_obstacles(game: Node) -> void:
	if OBSTACLE_LAYOUT.is_empty():
		OBSTACLE_LAYOUT = OBST.layout(ARENA_RADIUS)
	if not _contract_has_obstacles(game):
		if not _warned_no_obstacles_field:
			_warned_no_obstacles_field = true
			push_warning("arena: il contratto NON dichiara il campo obstacles")
		return
	game.set("obstacles", obstacles_payload())

func _contract_has_obstacles(game: Node) -> bool:
	return game.get("obstacles") is PackedVector3Array

func obstacles_payload() -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in OBSTACLE_LAYOUT.size():
		var e: Vector3 = OBSTACLE_LAYOUT[i]
		if not (e.y > 0.0):
			push_error("arena: OBSTACLE_LAYOUT[%d] ha raggio %.3f" % [i, e.y])
			return PackedVector3Array()
		out.append(e)
	if out.is_empty() and not _warned_empty_layout:
		_warned_empty_layout = true
		push_error("arena: nessun ostacolo")
	return out

func _ground_visible(punto: Vector3) -> bool:
	var cam := _camera()
	if cam == null:
		if not _warned_no_camera:
			_warned_no_camera = true
			push_warning("arena: nessuna Camera3D")
		return true
	return bool(cam.call("is_position_in_frustum", Vector3(punto.x, 0.0, punto.z)))

func _surface_height_at(_punto: Vector2, _piano: int) -> float:
	return -1.0

func _camera() -> Node3D:
	if _camera_cache != null and is_instance_valid(_camera_cache):
		return _camera_cache
	_camera_cache = get_node_or_null("Camera") as Node3D
	return _camera_cache

func _process(_delta: float) -> void:
	_update_scroll_offset()
	if _hud == null or not _hud.has_method("set_state"):
		if not _warned_no_hud:
			_warned_no_hud = true
			push_warning("arena: nessun HUD con set_state()")
		return
	_hud.set_state(_health(), _health_max(), _kills(), _weapon_text(), _enemies(), _level())

func _update_scroll_offset() -> void:
	var p := _player()
	if p != null and is_instance_valid(p):
		# Scorrimento solo lungo W (Z): la direzione di avanzamento sullo schermo.
		scroll_offset = Vector3(0.0, 0.0, (p as Node3D).global_position.z)

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
	if is_instance_valid(player) and player is Node:
		return player
	return null

func _num(holder, key: String, fallback: float) -> float:
	if holder == null or not (holder is Object):
		return fallback
	var raw = (holder as Object).get(key)
	if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT:
		return float(raw)
	return fallback

func _contract() -> Node:
	var tree := get_tree()
	if tree != null:
		return tree.root.get_node_or_null("Game")
	return null