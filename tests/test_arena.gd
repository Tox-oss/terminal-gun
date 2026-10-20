extends SceneTree
const H = preload("res://tools/test_harness.gd")

var _h: H = null
var _frames: int = 0
var _arena: Node = null

func _initialize() -> void:
	_h = H.new()

func _process(_delta: float) -> bool:
	if _frames == 0:
		var scene := load("res://scenes/arena_main.tscn")
		if scene != null:
			_arena = scene.instantiate()
			root.add_child(_arena)
	_frames += 1
	if _frames < 300:
		return false
	_run_checks()
	return true

func _run_checks() -> void:
	var h := _h
	h.check(_arena != null, "arena_main.tscn non si carica")
	var game := root.get_node_or_null("Game")
	h.check(game != null, "autoload Game mancante")
	var horde = game.get("horde") if game != null else null
	h.check(horde != null, "Game.horde mancante")
	var count := 0
	if horde != null:
		count = int(horde.get("count"))
	h.check(count > 0, "horde.count deve essere > 0")
	# node count
	var nodes := 0
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		nodes += 1
		for c in n.get_children():
			stack.append(c)
	h.check(nodes < 120, "troppi nodi: %d" % nodes)
	# HUD
	var hud = _arena.get_node_or_null("Hud") if _arena != null else null
	if hud != null and hud.has_method("enemy_text"):
		h.check(str(hud.call("enemy_text")) != "", "HUD enemies vuoto")
		h.check(str(hud.call("clock_text")) != "", "HUD timer vuoto")
		h.check(str(hud.call("xp_text")) != "", "HUD xp vuoto")
	# rendering: ogni specie ha un renderer dedicato (Trojan e Wurm inclusi)
	const R = preload("res://src/render/horde_renderer.gd")
	h.check(R.KIND_SLOT.size() == 8, "KIND_SLOT non copre le 8 specie")
	var handled: Array = []
	for _k in range(8):
		handled.append(false)
	var _stack: Array[Node] = [_arena]
	while _stack.size() > 0:
		var _n: Node = _stack.pop_back()
		if _n is MultiMeshInstance3D and _n.has_method("handles_kind"):
			for _k in range(8):
				if bool(_n.call("handles_kind", _k)):
					handled[_k] = true
		for _c in _n.get_children():
			_stack.append(_c)
	for _k in range(8):
		h.check(bool(handled[_k]), "specie %d non renderizzata" % _k)
	# piano unico: nessuna rampa, nessun nodo torre
	h.check(_arena.get_node_or_null("Ramp") == null, "nodo Ramp presente")
	h.check(_arena.get_node_or_null("ArenaRamp") == null, "nodo ArenaRamp presente")
	# scorrimento: campo scroll_offset presente
	var so = _arena.get("scroll_offset") if _arena != null else null
	h.check(so is Vector3, "scroll_offset mancante")
	# firewall: stato iniziale non dentro
	if horde != null:
		h.check(horde.get("firewall_inside") == false, "firewall_inside deve partire false")
	quit(h.finish("test_arena"))