extends MultiMeshInstance3D
## L'orda intera disegnata da **un solo nodo**.
##
## `src/sim/horde.gd` tiene i nemici come record in array e li espone con quattro
## campi pubblici (`count`, `transforms`, `colors`, `radii`), non con metodi:
## leggere la massa non e' una query. Qui quei campi finiscono in **una**
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

## ## Il fattore di calibrazione della taglia (milestone 8)
##
## Prima di m8 il nemico aveva **una sola taglia** (`BASE_SCALE = 1.5`, qui sotto
## la sua storia) e le quattro specie si distinguevano **solo di tinta**. Quindi
## un runner da 45 cm e un boss da 190 cm erano identici alla vista, mentre il
## boss mordeva fino a 3.10 m dal centro: la taglia che il giocatore vedeva non
## era quella che lo mordeva.
##
## Il numero che si moltiplica qui e' `horde.radii[i]`, il raggio del corpo che
## `-orda` espone gia' (`RADIUS[kind]`, che vive in `src/sim/enemy.gd` e in
## nessun altro posto). **Il raggio non e' scritto qui**: se lo fosse, la copia
## mentirebbe alla prima riga cambiata in `enemy.gd`, che e' esattamente il difetto
## che m8 chiude.
##
## Il fattore e' **libero** e l'invariante che m8 dichiara e' la
## **proporzionalita'**, non la taglia assoluta:
##
##     disegnato_i / disegnato_j  ==  radii[i] / radii[j]
##
## Cambiare questo numero non falsifica l'invariante e non riapre l'onda.
##
## ## COME E' STATO SCELTO: sulla misura, e il numero che produce
##
## Base = **la taglia che si vede oggi**, cioe' il difetto. Misurata sul modello
## vero il 2026-10-13 (AABB di `enemy_small.glb` = 0.894425 x 1.000000 x 0.850640
## m) con la costante di allora `BASE_SCALE = 1.5`, l'estensione maggiore del
## corpo disegnato era **1.500000 m**.
##
## Il requisito non e' che resti identica, e' che **non regredisca**: nessuna
## specie puo' diventare piu' piccola di quanto era ieri. La specie piu' piccola e'
## quella col raggio minimo, quindi il fattore e' **1.5 / raggio minimo**, e da li'
## si sale di un margine dichiarato perche' il numero non deve stare su un filo.
##
##     SIZE_FACTOR = 3.4  ->  la piu' piccola specie disegna 1.53 m  (+2% di 1.50)
##
## Il resto della tabella e' **il prodotto di questo fattore per i raggi veri
## dell'orda**, e quei numeri li stampa `tests/test_arena.gd` ad ogni esecuzione:
## il file che li contiene non li ricopia, li misura. Quindi la tabella qui sotto
## non e' una seconda copia di `RADIUS`: e' l'effetto del fattore, e se
## `RADIUS[kind]` cambiasse i numeri qui sotto smetterebbero di valere senza che
## nessuno li stia guardando -- che e' il motivo per cui il test li ricalcola.
const SIZE_FACTOR := 3.4

## ## PERCHE' LA SOLLEVATA E' ADESSO PER ISTANZA E NON UNA COSTANTE
##
## Finche' la taglia era una sola, `BASE_LIFT = 0.75` bastava: meta' dell'altezza
## disegnata (1.5 x 1.0 / 2 = 0.75 esatto), cioe' i piedi del nemico sul pavimento.
## Con la taglia **proporzionale al raggio** quella costante seppellirebbe il boss:
## un corpo di 6.46 m appoggiato su un centro a 0.75 m ha **2.5 metri sotto il
## pavimento**, e un nemico a meta' dentro il terreno non e' distinguibile da
## nessuno. Quindi l'altezza di mezzo corpo e' **misurata dalla mesh** (una volta
## sola, in `_build()`) e moltiplicata per la scala dell'istanza.
##
## Non e' una costante nuova: e' la stessa `BASE_LIFT` di prima, scritta come
## prodotto invece che come numero. Il valore di allora si riottiene esattamente.
var _mesh_height: float = 0.0

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
var _last_radius: float = -1.0
var _basis: Basis = Basis.IDENTITY
var _basis_time: float = -1.0
## Avviso emesso una volta sola: `radii` mancante e' un difetto di -orda, non un
## rumore da ripetere ogni frame (vedi `_radii_of`).
var _warned_radii: bool = false

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
	# L'altezza del modello serve a tenere i piedi del nemico sul pavimento
	# quando la taglia **cambia da nemico a nemico** (vedi `SIZE_FACTOR`). Si
	# misura qui, una volta sola: e' un dato della mesh, non un numero scritto a
	# mano, quindi resta vero se domani il modello cambia.
	_mesh_height = maxf(mesh.get_aabb().size.y, 0.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# I colori per istanza sono il motivo per cui il contratto espone `colors`:
	# e' cosi' che l'arena distingue le specie senza sapere cosa sia un nemico.
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

## Da quale nodo prendere `count`/`transforms`/`colors`/`radii`. Di norma
## `Game.horde`; il test vi inietta un orda finta con la stessa forma. Non e' un
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

## Il raggio del corpo che il renderer ha usato **per l'ennesimo nemico**, o `-1`
## se l'ultimo `refresh()` non ha disegnato nulla. Non serve al ciclo di gioco:
## esiste perche' `tests/test_arena.gd` deve poter dire *quale* numero ha prodotto
## il fattore di calibrazione **misurandolo**, invece di rileggerlo dalla costante
## che lo produce.
func last_radius_used() -> float:
	return _last_radius

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

	# `radii` e' il quarto array parallelo della massa (contratto di m8, punto 2:
	# `radii.size() == count`, allineato a `transforms`, `colors` e `kinds`) ed e'
	# l'unico che puo' dire **quanto e' grosso** un nemico. Senza di lui il
	# renderer puo' solo ridisegnare la taglia costante di prima, cioe'
	# reintrodurre esattamente il difetto che m8 chiude. Quindi qui **non** si
	# indietreggia su un valore di riserva: si dice una volta sola che manca e non
	# si disegna niente. Un nemico invisibile e' un difetto che si vede; un nemico
	# della taglia sbagliata e' un difetto che non si vede, ed e' quello di oggi.
	var radii = _radii_of(horde)
	if not (radii is PackedFloat32Array):
		if not _warned_radii:
			_warned_radii = true
			push_warning("horde_renderer: horde.radii non e' un PackedFloat32Array (misurato %s): senza il raggio del corpo l'orda non puo' essere disegnata, perche' la taglia deve essere proporzionale a lui. Il campo e' la superficie congelata di m8 in src/core/contracts.gd e lo scrive -orda."
				% type_string(typeof(radii)))
		multimesh.visible_instance_count = 0
		_last_drawn = 0
		_last_radius = -1.0
		return
	var sizes: PackedFloat32Array = radii

	var wanted: int = horde.count
	var positions: PackedVector3Array = horde.transforms
	var tints: PackedColorArray = horde.colors
	# Quattro guardie, e non una sola di `_build`: l'invariante `transforms.size()
	# == colors.size() == radii.size() == count` e' di -orda e vale nel suo test,
	# non nel mio. Se un giorno non valesse, il renderer accorcia invece di
	# leggere fuori dal vettore: un errore in questo ciclo di gioco e' un crash in
	# mezzo all'onda.
	if wanted > CAPACITY:
		wanted = CAPACITY
	if wanted > positions.size():
		wanted = positions.size()
	if wanted > tints.size():
		wanted = tints.size()
	if wanted > sizes.size():
		wanted = sizes.size()

	# Il ciclo e' piatto: 200 scritture dentro il buffer, niente allocazione e
	# niente nodi. La rotazione la tiene in piedi `instance_transform` per un
	# frame intero; la **scala no**, perche' da m8 cambia da nemico a nemico.
	for i in wanted:
		multimesh.set_instance_transform(i, instance_transform(positions[i], sizes[i], i))
		multimesh.set_instance_color(i, tints[i])
	multimesh.visible_instance_count = wanted
	_last_drawn = wanted
	_last_radius = sizes[wanted - 1] if wanted > 0 else -1.0

## Il raggio del corpo del nemico `i`, letto dall'orda.
##
## Passa per `get()` e non per `horde.radii` per una ragione sola: il campo e'
## scritto da `-orda` e questa onda lavora **in parallelo** a lui. Con l'accesso
## diretto, un campo non ancora arrivato interromperebbe il ciclo di gioco con un
## errore a runtime nel mezzo dell'orda; con `get()` arriva `null` e la guardia di
## `refresh()` lo dichiara una volta sola, con il nome del campo. Il nome non e'
## indovinato qui: e' congelato in `src/core/contracts.gd`, sezione "Supersficie di
## milestone 8".
func _radii_of(horde: Node) -> Variant:
	return horde.get("radii")

## La trasformazione del nemico `i` a partire dalla sua posizione e dal **raggio
## del suo corpo**.
##
## Pubblica e **pura**, e il ciclo di gioco passa di qui per ogni nemico: e'
## quindi la stessa funzione che il test verifica, non una ricostruzione parallela
## di quello che il renderer dovrebbe fare.
##
## `radius` e' `horde.radii[i]`, cioe' il raggio del corpo in metri. **Non e' una
## copia di `RADIUS[kind]`**: il renderer non conosce le specie e non deve
## saperlo, altrimenti il raggio di una specie vivrebbe in due posti.
##
## Serve perche' il buffer della MultiMesh non si rilegge in headless: in Godot
## 4.7 le trasformazioni stanno in uno storage buffer del RenderingDevice, che
## nel backend "dummy" di `--headless` non esiste, e `get_instance_transform`
## restituisce silenziosamente una trasformazione vuota. Verificare qui dentro e'
## l'unico modo di controllare davvero *cosa* viene scritto, senza leggere indietro
## quello che non e' stato scritto.
func instance_transform(pos: Vector3, radius: float, i: int) -> Transform3D:
	var bob: float = sin(_time * BOB_SPEED + float(i) * 0.37) * BOB_AMPLITUDE
	# La scala e' `raggio x fattore di calibrazione`: e' qui che la taglia
	# disegnata diventa proporzionale al corpo che morde. `BASE_SCALE` di prima
	# non e' sparito, e' diventato il fattore.
	var s: float = maxf(radius, 0.0) * SIZE_FACTOR
	# La sollevata segue la scala: meta' dell'altezza effettiva del corpo, cosi'
	# i piedi restano sul pavimento a ogni taglia invece che a una sola.
	var lift: float = 0.5 * s * _mesh_height
	return Transform3D(_shared_rotation().scaled(Vector3(s, s, s)),
		Vector3(pos.x, pos.y + lift + bob, pos.z))

## La rotazione che hanno in comune tutti i nemici. Cambia solo con l'orologio,
## quindi si ricostruisce una volta per frame e non una volta per nemico. Con 200
## nemici la differenza sono 199 costruzioni di matrice inutili in un solo frame.
##
## **Non** contiene piu' la scala: da m8 la scala e' per istanza, e tenerla qui
## costerebbe 200 copie di una matrice che devono essere diverse.
func _shared_rotation() -> Basis:
	if _basis_time != _time:
		_basis_time = _time
		_basis = Basis(Vector3.UP, _time * SPIN_SPEED)
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