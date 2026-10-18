extends SceneTree
## MISURA DI m13-w1 -- piano docs/piramide/piano.md sez. 1.14-ventiquartesima
##
##     godot --headless --path . --script res://docs/piramide/probe_ostacoli_bloccano.gd
##
## Domanda: **l'utente ha detto che i cubi «non mi bloccano». Il codice dice che
## bloccano. Chi ha ragione?**
##
## Il giocatore e' solido per disegno (`_clamp_to_obstacles()`, `player.gd:662`):
## la posizione viene spinta fuori fino a `raggio + OBSTACLE_MARGIN` e la
## componente di velocità verso il centro viene tolta. E c'e' `obstacle_count()`
## scritto apposta perché un test verifichi che il giocatore abbia letto i dischi.
##
## Tre cose pero' possono rendere vero il report **senza che nessun codice sia
## sbagliato**, e sono le tre che questa sonda separa:
##
## 1. **il giocatore non ha letto i dischi**: `obstacle_count() == 0` con la scena
##    vera montata. Sarebbe un difetto del canale, non della geometria.
## 2. **i dischi bloccano davvero**, ma il cubo **disegnato** e' piu' piccolo del
##    disco che ti ferma: cammini nel cubo e ti blocchi piu' avanti, che si legge
##    come «non blocca».
## 3. **i dischi non bloccano**: `min distanza` ben sotto `raggio + margine`.
##
## Il caso 3 e' l'unico che sarebbe un difetto di codice, ed e' quello che la
## sonda deve poter dichiarare.

const ARENA_SCENE := "res://scenes/arena_main.tscn"
const PASSI := 120
const VEL := 13.65

var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true

func _run() -> void:
	var game := root.get_node_or_null("Game")
	if game == null:
		print("PROBE FAIL: autoload Game assente.")
		quit(1)
		return
	var res = load(ARENA_SCENE)
	if not (res is PackedScene):
		print("PROBE FAIL: %s non e' una PackedScene." % ARENA_SCENE)
		quit(1)
		return
	var arena = (res as PackedScene).instantiate()
	var player = arena.get_node_or_null("Player")
	if player == null:
		print("PROBE FAIL: Player assente nella scena.")
		quit(1)
		return
	root.add_child(arena)
	player.drive_manually()

	# ## CASO 1: il giocatore ha letto i dischi?
	var letti: int = player.obstacle_count()
	var dichiarati: PackedVector3Array = game.obstacles
	print("PROBE: ostacoli sul contratto %d, letti dal giocatore %d"
		% [dichiarati.size(), letti])
	if letti != dichiarati.size():
		print("PROBE: CASO 1 -- il giocatore NON ha letto tutti i dischi: %d su %d. Difetto del canale."
			% [letti, dichiarati.size()])
	else:
		print("PROBE: CASO 1 escluso: il giocatore ha letto tutti i dischi.")

	if dichiarati.is_empty():
		print("PROBE: nessun disco da provare.")
		quit(1)
		return

	# ## CASO 3: camminare dritto addosso a ogni disco e misurare quanto ci si ferma lontano.
	print("PROBE: cammino dritto verso il centro di ogni disco e misuro l'avvicinamento minimo.")
	print("PROBE: un disco che BLOCCA deve fermarmi a `raggio + OBSTACLE_MARGIN`, e non di meno.")
	var peggiore := 1.0e9
	var peggiore_i := -1
	for i in dichiarati.size():
		var o: Vector3 = dichiarati[i]
		var r: float = o.y
		var c := Vector3(o.x, 0.0, o.z)
		# Parto a 12 m dal centro, lungo una direzione che non e' quella di nessun
		# altro disco: se parto verso il centro di un disco, l'angolo conta e il
		# risultato dipende da dove si trova rispetto agli altri.
		var direzione := Vector3(cos(float(i) * 2.399963), 0.0, sin(float(i) * 2.399963)).normalized()
		player.position = c + direzione * (r + 12.0)
		player.velocity = -direzione * VEL
		var minimo := 1.0e9
		for _k in PASSI:
			player.read_keys = false
			player.step_for_probe(1.0 / 60.0, -direzione)
			minimo = minf(minimo, Vector2(player.position.x - c.x, player.position.z - c.z).length())
			if player.position.distance_to(c) > r + 20.0:
				break
		var limite: float = r + _margine(player)
		if minimo < peggiore:
			peggiore = minimo
			peggiore_i = i
		print("PROBE:   disco %2d r=%.2f m | avvicinamento minimo %.3f m | limite atteso %.3f m | scarto %+.3f m"
			% [i, r, minimo, limite, minimo - limite])
	print("PROBE: peggiore scarto: disco %d, %.3f m" % [peggiore_i, peggiore - _raggio(dichiarati, peggiore_i) - _margine(player)])

	# ## CASO 2: il cubo DISEGNATO e' della taglia giusta?
	var nodi := _trova(arena, "Obstacles")
	if nodi == null:
		print("PROBE: nodo dei dischi non trovato: confronto visivo non possibile.")
	else:
		var mm = nodi.get("multimesh")
		if mm == null:
			print("PROBE: il nodo dei dischi non ha un MultiMesh: confronto visivo non possibile.")
		else:
			print("PROBE: MultiMesh dei dischi: %d istanze" % (mm.mesh != null and 1 or 0))
	print("PROBE: il confronto fra cubo disegnato e disco che blocca e' il CASO 2 e va fatto leggendo arena_obstacles.gd.")
	quit(0)

func _raggio(l: PackedVector3Array, i: int) -> float:
	if i < 0 or i >= l.size():
		return 0.0
	return l[i].y

## Legge OBSTACLE_MARGIN dalla classe del giocatore, senza scriverlo qui: se il
## numero cambiasse, questa sonda continuerebbe a confrontare contro il vecchio.
func _margine(player) -> float:
	var s := player.get_script()
	if s == null:
		return 0.0
	for costante in s.get_script_constant_map().keys():
		if String(costante) == "OBSTACLE_MARGIN":
			return float(s.get_script_constant_map()[costante])
	return 0.0

func _trova(nodo: Node, nome: String) -> Node:
	if nodo.name == nome:
		return nodo
	for c in nodo.get_children():
		var t := _trova(c, nome)
		if t != null:
			return t
	return null