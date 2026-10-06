extends MultiMeshInstance3D
## L'orda intera disegnata da **un solo nodo**.
##
## `src/sim/horde.gd` tiene i nemici come record in array e li espone con tre
## campi pubblici (`count`, `transforms`, `colors`), non con metodi: leggere la
## massa non e' una query. Qui quei tre campi finiscono in **una**
## `MultiMeshInstance3D`, quindi il numero di nodi non dipende dal numero di
## nemici. E' il criterio n. 3 della milestone:
##
##     node_count < 120  con  horde.count == 200
##
## Per averlo, l'aggiornamento per frame non puo' creare nodi: la capacita' e'
## assegnata una volta sola in `_ready()` e non cresce mai. Un nemico che
## nasce non aggiunge niente, un nemico che muore non toglie niente: si scrive
## dentro il buffer, punto.
##
## Non registro niente sul contratto. `Game.horde` e' di -orda, le API dei
## metodi sono sue e di -gameplay. L'unica cosa che arena registra e'
## `Game.arena_radius`, e lo fa `src/render/arena.gd`.

## Il modello low-poly dei nemici. Va letto una volta sola: non lo rigenero e non
## lo modifico, e nessuna Mesh per nemico.
const ENEMY_SCENE := "res://assets/models/enemy_small.glb"

## Capacita' fissa della MultiMesh. 200 nemici piu' un margine: non cresce a
## runtime, altrimenti `instance_count` cambierebbe da solo e il motore
## ricreerebbe il buffer proprio nel frame in cui si combatte di piu'.
const CAPACITY := 256

## Scala dell'istanza. `enemy_small.glb` e' un icosfere di raggio 0.5, quindi
## questa scala porta il nemico a circa 1.5 m di diametro.
const BASE_SCALE := 1.5

## Quanto il nemico sta sopra il pavimento: `transforms[i].y` e' 0, il centro del
## modello no, e mezzo nemico dentro il terreno non si vede.
const BASE_LIFT := 0.75

## Rotazione lenta dell'insieme: 200 nemici fermi sembrano 200 pedine appoggiate.
const SPIN_SPEED := 0.7

## Oscillazione verticale, sfalsata per indice.
const BOB_SPEED := 5.0
const BOB_AMPLITUDE := 0.09

## L'orda da cui leggere. Se non e' impostata si prende `Game.horde`.
var _horde: Node = null
var _contract_cache: Node = null
## Tengo la scena sorgente viva finche' questo nodo vive: se il probe istanziato
## viene liberato e la cache delle risorse un giorno non lo tiene, la Mesh non
## deve poter sparire da sotto la MultiMesh.
var _source: PackedScene = null

var _time: float = 0.0
var _built: bool = false
var _last_drawn: int = 0
var _basis: Basis = Basis.IDENTITY
var _basis_time: float = -1.0

func _ready() -> void:
	_build()

func _process(delta: float) -> void:
	_time += delta
	refresh()

# --- Costruzione --------------------------------------------------------------

## Fatta una volta sola. Nessun nodo, nessuna instanziazione dopo questo punto.
func _build() -> void:
	if _built:
		return
	_built = true
	var mesh := _load_mesh(ENEMY_SCENE)
	if mesh == null:
		push_warning("horde_renderer: nessuna mesh in %s, l'orda non si vede" % ENEMY_SCENE)
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# I colori per istanza sono il motivo per cui il contratto espone `colors`:
	# e' cosi' che l'arena distingue la specie senza sapere cosa sia un nemico.
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = CAPACITY
	multimesh = mm
	material_override = _flat_material()
	# Il riquadro lo dichiaro invece di lasciarlo calcolare dal buffer: il
	# nemico piu' alto si trova a 28 m dal centro e il motore deve sapere che la
	# scena da disegnare arriva almeno li'.
	custom_aabb = AABB(Vector3(-34.0, -2.0, -34.0), Vector3(68.0, 12.0, 68.0))
	for i in CAPACITY:
		mm.set_instance_transform(i, _hidden_transform())
		mm.set_instance_color(i, Color.WHITE)

## Il materiale che mette in atto il flat shading del piano 9 (niente texture,
## niente PBR costoso): tinte piatte dai vertex color dei modelli, e le tinte per
## istanza che arrivano dall'orda.
func _flat_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	m.metallic = 0.0
	return m

## Trasformazione "fuori scena" per le istanze non ancora usate. Non e' che le
## nasconda: e' `visible_instance_count` a dire quante sono vere. Questa serve
## solo per il primo fotogramma e per il caso di un conteggio che torna su,
## dopo che una guardia di capacita' ha spinto qualcosa oltre `CAPACITY`.
func _hidden_transform() -> Transform3D:
	return Transform3D(Basis.IDENTITY.scaled(Vector3(0.0, 0.0, 0.0)), Vector3(0.0, -1000.0, 0.0))

func _load_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path)
	if not (packed is PackedScene):
		return null
	_source = packed as PackedScene
	var probe: Node = _source.instantiate()
	var found: Mesh = null
	# I .glb sono una scena sola, ma non prometto che resti una scena sola: se
	# un domani il modello lo annida, la mesh si trova comunque.
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

# --- Lettura dell'orda --------------------------------------------------------

## Da quale nodo prendere `count`/`transforms`/`colors`. Di norma `Game.horde`;
## il test vi inietta un orda finta con la stessa forma. Non e' un
## `get_node("../..")`: e' un dato, non una dipendenza fra foglie.
func set_horde(horde: Node) -> void:
	_horde = horde

## Congela l'orologio che muove bob e rotazione, cosi' la geometria scritta nel
## buffer e' prevedibile e il test puo' verificarla.
func set_time(t: float) -> void:
	_time = t

## Quanti nemici l'ultimo `refresh()` ha messo sul serio nel buffer.
func drawn_count() -> int:
	return _last_drawn

## Copia l'orda nel buffer. Chiamata una volta per frame: 200 scritture dentro
## array gia' allocati, zero nodi, zero `new()`.
func refresh() -> void:
	if not _built or multimesh == null:
		return
	var horde := _resolve_horde()
	if horde == null:
		# Nessuna orda registrata: niente nemici, ma resta un nodo solo.
		multimesh.visible_instance_count = 0
		_last_drawn = 0
		return

	var wanted: int = horde.count
	var positions: PackedVector3Array = horde.transforms
	var tints: PackedColorArray = horde.colors
	# Tre guardie, e non una sola di `_build`: l'invariante `transforms.size() ==
	# colors.size() == count` e' di -orda e vale nel suo test, non nel mio. Se un
	# giorno non valesse, il renderer accorcia invece di leggere fuori dal
	# vettore: un errore in questo ciclo di gioco e' un crash in mezzo all'onda.
	if wanted > CAPACITY:
		wanted = CAPACITY
	if wanted > positions.size():
		wanted = positions.size()
	if wanted > tints.size():
		wanted = tints.size()

	# Il ciclo e' piatto: 200 scritture dentro il buffer, niente allocazione e
	# niente nodi. La base comune la calcola `instance_transform`, che la tiene
	# in piedi per un frame intero.
	for i in wanted:
		multimesh.set_instance_transform(i, instance_transform(positions[i], i))
		multimesh.set_instance_color(i, tints[i])
	multimesh.visible_instance_count = wanted
	_last_drawn = wanted

## La trasformazione del nemico `i` a partire dalla sua posizione.
##
## Pubblica e **pura**, e il ciclo di gioco passa di qui per ogni nemico: e'
## quindi la stessa funzione che il test verifica, non una ricostruzione parallela
## di quello che il renderer dovrebbe fare.
##
## Serve perche' il buffer della MultiMesh non si rilegge in headless: in Godot
## 4.7 le trasformazioni stanno in uno storage buffer del RenderingDevice, che
## nel backend "dummy" di `--headless` non esiste, e `get_instance_transform`
## restituisce silenziosamente una trasformazione vuota. Verificare qui dentro e'
## l'unico modo di controllare davvero *cosa* viene scritto, senza leggere indietro
## quello che non e' stato scritto.
func instance_transform(pos: Vector3, i: int) -> Transform3D:
	var bob: float = sin(_time * BOB_SPEED + float(i) * 0.37) * BOB_AMPLITUDE
	return Transform3D(_shared_basis(), Vector3(pos.x, pos.y + BASE_LIFT + bob, pos.z))

## La base che hanno in comune tutti i nemici: rotazione e scala cambiano solo con
## l'orologio, quindi si ricostruisce una volta per frame e non una volta per
## nemico. Con 200 nemici la differenza sono 199 costruzioni di matrice inutili
## in un solo frame.
func _shared_basis() -> Basis:
	if _basis_time != _time:
		_basis_time = _time
		_basis = Basis(Vector3.UP, _time * SPIN_SPEED).scaled(Vector3(BASE_SCALE, BASE_SCALE, BASE_SCALE))
	return _basis

func _resolve_horde() -> Node:
	if _horde != null and is_instance_valid(_horde):
		return _horde
	var game := _contract()
	if game == null:
		return null
	var horde = game.get("horde")
	if horde is Node:
		return horde
	return null

# --- Interno ------------------------------------------------------------------

## L'autoload `Game`, preso dal campo `/root` invece che con l'identificatore
## nudo `Game`. Motivo: questi script vengono caricati a runtime con `load()`
## anche dai test in `--script`, e in quel contesto la risoluzione degli autoload
## in fase di compilazione non e' garantita (piano 5.3). Il campo e' pubblico e
## il valore e' un dato: nessuna dipendenza circolare.
func _contract() -> Node:
	if _contract_cache != null and is_instance_valid(_contract_cache):
		return _contract_cache
	var tree := get_tree()
	if tree != null:
		_contract_cache = tree.root.get_node_or_null("Game")
	return _contract_cache