extends Node3D
## Il terreno **chiuso**: pavimento, muro, casse. Tre `MultiMesh`, tre nodi,
## qualunque sia la dimensione.
##
## Una `MultiMeshInstance3D` per `assets/models/ground_tile.glb` e una per
## `crate.glb`: i due modelli sono gia' stati generati in w1, qui non li
## rigenero e non li modifico, li solo uso come mesh.
##
## Il pavimento e' una MultiMesh e non un `GridMap` o 900 nodi: la regola "un
## nodo per cosa'" del progetto vale anche per il terreno, e a 46 m di raggio
## (100 m di lato, 2500 piastrelle) un pavimento a nodi da solo mangerebbe il
## budget del criterio n. 3 da solo.

const FLOOR_SCENE := "res://assets/models/ground_tile.glb"
const CRATE_SCENE := "res://assets/models/crate.glb"

## `ground_tile.glb` e' un piano di 2x2 metri, generato in w1.
const TILE := 2.0
## Quante file di piastrelle in alto ha il muro. Due file sono quattro metri:
## abbastanza per chiudere l'arena senza nascondere l'orizzonte.
const WALL_ROWS := 2
## Crate sparse dentro l'arena. Poche e deterministiche: sono un segnalibro, non
## un labirinto.
const CRATE_COUNT := 28

## ## IL SEME DELLE CASSE: 20240502, dichiarato perche' e' un numero nuovo
##
## `RandomNumberGenerator.new()` nasce **gia' casuale** in Godot 4.7: misurato qui,
## due generatori freschi di fila danno `seed` diversi (`3613518067136908358` e
## `-265288651179134434`) e tirano numeri diversi. Quindi `rng.seed = CRATE_SEED`
## sotto non e' una formalita': senza quella riga le 28 casse cambiano disposizione
## **a ogni montaggio della scena**, e la scena non e' riproducibile nemmeno a
## occhio.
##
## Il numero resta quello di allora (una data, 2024-05-02): nessuna ragione di
## cambiarlo qui dentro, e cambiarlo sposterebbe 28 casse per un motivo che nessuno
## ha. Quello che mancava non era il valore ma la **dichiarazione**: la costante
## era gia' li' dalla chiusura di m1 (`0d5b0c5`), con una riga di commento che
## diceva solo «sono un segnalibro, non un labirinto».
##
## ## PERCHE' NON E' IL 4242 DELLA SCENA, E NON PER DIMENTICANZA
##
## Sono due flussi separati e devono restarlo. L'orda e' **simulazione**: il suo
## seme e' il default che `-orda` tira da capo a ogni `restart_run()`. Le casse
## sono **scenografia**: si costruiscono una volta sola in `_ready()` e non si
## muovono mai, ne' al restart ne' al death/respawn. Un numero solo per i due
## toglierebbe la distinzione e inviterebbe esattamente l'errore da evitare, cioe'
## far scivolare la scena insieme al dado della simulazione.
##
## ## COSA RENDE POSSIBILE
##
## Rende l'arena riproducibile **anche a occhio**, che e' la meta' che nessuna
## porta puo' guardare: nessuna asserzione del progetto legge le posizioni delle
## casse, quindi senza questo numero il difetto starebbe **fuori da ogni porta** e
## si vedrebbe solo da chi lancia il gioco due volte. Con il numero, la scena che
## si vede e' una funzione di un numero dichiarato, come quella che si misura.
const CRATE_SEED := 20240502
## ## FALLBACK RADIUS: un fallback **dichiarato**, non una fonte (criterio n. 2 di m9)
##
## Vive **solo** quando il contratto non e' ancora raggiungibile. In partita non
## viene mai usato: il valore vero arriva da `Game.arena_radius`, e quel campo lo
## scrive `src/render/arena.gd`, che e' la **fonte unica** del numero (piano
## 1.12-bis, copia 5 di 6).
##
## Perche' 46.0 e non 28.0: un terreno costruito con il fallback vecchio su
## un'arena di 46 avrebbe un muro a 28 m dentro il campo di gioco e 18 m di
## pavimento fuori dal muro, cioe' l'errore piu' sproporzionato di tutti,
## perche' qui il fallback non nasconde un numero ma **costruisce la geometria**.
## Il numero non e' scelto qui: e' quello della sonda
## `docs/piramide/probe_arena_density.gd`, con la tabella e il motivo scritti
## accanto alla fonte in `src/render/arena.gd`.
##
## Non puo' divergere: `tests/test_arena.gd` legge questa riga dal sorgente e la
## confronta con la fonte, quindi cambiarla da sola porta la porta rossa con i
## due numeri nel messaggio.
const FALLBACK_RADIUS := 46.0
## Metri di pavimento oltre il muro, per non vedere il vuoto ai bordi.
const FLOOR_MARGIN := 8.0
## Il raggio dentro cui il terreno non mette ostacoli al giocatore.
const CRATE_INNER := 7.0
const CRATE_OUTER_GAP := 4.0

var _floor: MultiMeshInstance3D = null
var _wall: MultiMeshInstance3D = null
var _crates: MultiMeshInstance3D = null
var _sources: Array[PackedScene] = []
## Le trasformazioni delle casse **cosi' come sono state scritte nel buffer**. Non
## e' una copia della geometria: e' la traccia di quello che questo file ha messo
## sul serio, e serve perche' il buffer di un `MultiMesh` **non si rilegge in
## headless** (in Godot 4.7 sta in uno storage buffer del RenderingDevice che nel
## backend "dummy" di `--headless` non esiste, e `get_instance_transform`
## restituisce silenziosamente una trasformazione vuota). Stesso motivo e stesso posto
## di `written_transform()` in `arena_obstacles.gd`: 28 elementi, allocati una volta
## sola all'avvio, che non crescono mai.
var _written_crates: Array[Transform3D] = []
var _contract_cache: Node = null
var _built: bool = false

func _ready() -> void:
	_build()

# --- Costruzione --------------------------------------------------------------

func _build() -> void:
	if _built:
		return
	_built = true
	var radius := arena_radius()

	_floor = _add_multimesh("Floor", FLOOR_SCENE)
	_build_floor(_floor, radius)

	_wall = _add_multimesh("Wall", FLOOR_SCENE)
	_build_wall(_wall, radius)

	_crates = _add_multimesh("Crates", CRATE_SCENE)
	_build_crates(_crates, radius)

	# L'ingranaggio di culling, per **ultimo**: `custom_aabb` sostituisce la
	# scatola che il motore calcola dalla mesh, e con l'arena a 46 m il valore
	# scritto a mano (+/-44 m) era **piu' piccolo del pavimento** (+/-50 m): la
	# corona di piastrelle più esterna spariva quando usciva dalla scatola. Lo
	# si deriva dal raggio perche' un numero scritto qui accanto a un raggio che
	# cambia e' la stessa classe di difetto di un fallback che diverge.
	_fit_aabbs(radius)

func _add_multimesh(node_name: String, scene_path: String) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.name = node_name
	add_child(mi)
	var mesh := _load_mesh(scene_path)
	if mesh == null:
		push_warning("arena_ground: nessuna mesh in %s, resta solo il nodo %s" % [scene_path, node_name])
		return mi
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = false
	mm.mesh = mesh
	mm.instance_count = 1
	mi.multimesh = mm
	mi.material_override = _flat_material()
	# `custom_aabb` lo rimette `_fit_aabbs()` appena il raggio e' noto: qui il
	# valore non puo' essere giusto perche' la mesh non e' ancora disposta.
	mi.custom_aabb = AABB()
	return mi

## La scatola che il motore usa per decidere se disegnare, **derivata dal
## raggio** invece che scritta a mano.
##
## Mezza diagonale del pavimento: il pavimento e' un quadrato di
## `radius * 2 + FLOOR_MARGIN`, quindi il suo punto piu' lontano dal centro e' a
## `side / 2 * sqrt(2)`, non a `side / 2`. Con `FLOOR_MARGIN` = 8 e raggio 46
## quello e' 70,7 m: arrotondare a `radius + FLOOR_MARGIN` avrebbe tagliato il
## cantone, e il cantone tagliato e' il difetto che nessuna asserzione headless
## vede. In su c'e' il muro (`WALL_ROWS * TILE`), in giu' mezzo metro sotto il
## pavimento per la cassa appoggiata.
func _fit_aabbs(radius: float) -> void:
	var side := radius * 2.0 + FLOOR_MARGIN
	var half := side * 0.5 * sqrt(2.0)
	var top := float(WALL_ROWS) * TILE + 1.0
	var box := AABB(Vector3(-half, -0.5, -half), Vector3(half * 2.0, top + 0.5, half * 2.0))
	for mi in [_floor, _wall, _crates]:
		if mi != null:
			(mi as MultiMeshInstance3D).custom_aabb = box

func _flat_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.95
	m.metallic = 0.0
	return m

func _build_floor(mi: MultiMeshInstance3D, radius: float) -> void:
	var mm := _multimesh_of(mi)
	if mm == null:
		return
	# Un quadrato che copre il disco piu' il margine. `per_side` arrotonda in
	# eccesso: un pavimento un pelo piu' largo costa quattro piastrelle, un
	# pavimento piu' stretto costa il buco nero.
	var side := radius * 2.0 + FLOOR_MARGIN
	var per_side := int(ceil(side / TILE))
	var total := per_side * per_side
	var origin := -side * 0.5
	mm.instance_count = total
	var flat := Basis.IDENTITY
	var n := 0
	for ix in per_side:
		for iz in per_side:
			var x := origin + (float(ix) + 0.5) * TILE
			var z := origin + (float(iz) + 0.5) * TILE
			mm.set_instance_transform(n, Transform3D(flat, Vector3(x, 0.0, z)))
			n += 1
	mm.visible_instance_count = total

func _build_wall(mi: MultiMeshInstance3D, radius: float) -> void:
	var mm := _multimesh_of(mi)
	if mm == null:
		return
	# Un segmento per piastrella di circonferenza: il muro chiude davvero, senza
	# buchi e senza sporgenze.
	var segments := maxi(8, int(ceil(TAU * radius / TILE)))
	var total := segments * WALL_ROWS
	mm.instance_count = total
	var n := 0
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		var tangent := Vector3(-sin(angle), 0.0, cos(angle))
		# Il piano del modello giace nel piano XZ con normale su Y: per metterlo
		# in piedi la sua Y deve diventare la normale orizzontale e la sua Z
		# l'altezza. Le tre colonne cosi' formano una base destrorsa.
		var basis := Basis(tangent, outward, Vector3.UP)
		for row in WALL_ROWS:
			var y := (float(row) + 0.5) * TILE
			mm.set_instance_transform(n, Transform3D(basis, outward * radius + Vector3(0.0, y, 0.0)))
			n += 1
	mm.visible_instance_count = total

func _build_crates(mi: MultiMeshInstance3D, radius: float) -> void:
	var mm := _multimesh_of(mi)
	if mm == null:
		return
	mm.instance_count = CRATE_COUNT
	_written_crates.clear()
	# Il seme e' dichiarato accanto a `CRATE_SEED`. Senza questa riga il
	# generatore nasce casuale (misurato in Godot 4.7: due generatori freschi
	# danno semi diversi) e le casse cambiano disposizione a ogni montaggio.
	var rng := RandomNumberGenerator.new()
	rng.seed = CRATE_SEED
	var outer := maxf(CRATE_INNER + 1.0, radius - CRATE_OUTER_GAP)
	for i in CRATE_COUNT:
		var angle := rng.randf() * TAU
		var r := rng.randf_range(CRATE_INNER, outer)
		# `crate.glb` e' un cubo di 0.9 centrato nell'origine: mezzo lato in alto
		# lo appoggia al pavimento invece di affondarlo.
		var pos := Vector3(cos(angle) * r, TILE * 0.225, sin(angle) * r)
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pos)
		mm.set_instance_transform(i, t)
		_written_crates.append(t)
	mm.visible_instance_count = CRATE_COUNT

# --- Lettura (per il test e per il debug) -------------------------------------

## Raggio utile dell'arena, dal contratto. Dato, non derivato dalla geometria:
## nessuno deve misurare la scena per sapere quanto e' larga l'arena.
func arena_radius() -> float:
	var game := _contract()
	if game == null:
		return FALLBACK_RADIUS
	var value = game.get("arena_radius")
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return maxf(float(value), 6.0)
	return FALLBACK_RADIUS

func floor_instances() -> int:
	return _visible_count(_floor)

func wall_instances() -> int:
	return _visible_count(_wall)

func crate_instances() -> int:
	return _visible_count(_crates)

## La trasformazione della cassa `i` **cosi' com'e' stata scritta nel buffer**.
##
## Come `written_transform()` in `arena_obstacles.gd`, e per lo stesso motivo: in
## headless il `MultiMesh` non si rilegge, quindi rileggere il buffer qui farebbe
## passare il test su un terreno che non scrive niente. Serve a `tests/test_arena.gd`
## per confrontare le casse della scena con quelle di un secondo terreno costruito
## li' accanto: e' l'unico posto dove la casualita' **scenografica** della scena e'
## guardabile, e finora non lo guardava nessuno.
func crate_transform(i: int) -> Transform3D:
	if i < 0 or i >= _written_crates.size():
		return Transform3D.IDENTITY
	return _written_crates[i]

## Metro quadrato di piastrelle che copre il muro: se e' piu' piccolo della
## circonferenza, il muro ha un buco.
func wall_coverage() -> float:
	return float(wall_instances()) * TILE

## Lato del quadrato di pavimento realmente coperto.
func floor_covered_side() -> float:
	return sqrt(float(floor_instances()) * TILE * TILE)

# --- Interno ------------------------------------------------------------------

func _multimesh_of(mi: MultiMeshInstance3D) -> MultiMesh:
	if mi == null:
		return null
	return mi.multimesh

func _visible_count(mi: MultiMeshInstance3D) -> int:
	if mi == null or mi.multimesh == null:
		return 0
	return mi.multimesh.visible_instance_count

## Vedi la nota in `horde_renderer.gd`: l'autoload lo prendo dal campo `/root`,
## perche' questi script possono essere caricati con `load()` anche dai test in
## `--script`, dove l'identificatore nudo non e' garantito (piano 5.3).
func _contract() -> Node:
	if _contract_cache != null and is_instance_valid(_contract_cache):
		return _contract_cache
	var tree := get_tree()
	if tree != null:
		_contract_cache = tree.root.get_node_or_null("Game")
	return _contract_cache

func _load_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path)
	if not (packed is PackedScene):
		return null
	_sources.append(packed as PackedScene)
	var probe: Node = (packed as PackedScene).instantiate()
	var found: Mesh = null
	var stack: Array[Node] = []
	stack.append(probe)
	while not stack.is_empty() and found == null:
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			found = (node as MeshInstance3D).mesh
		else:
			for child in node.get_children():
				stack.append(child)
	probe.free()
	return found