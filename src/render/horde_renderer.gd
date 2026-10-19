extends MultiMeshInstance3D
## L'orda intera disegnata da **tre nodi, uno per modello**.
##
## `src/sim/horde.gd` tiene i nemici come record in array e li espone con cinque
## campi pubblici (`count`, `transforms`, `colors`, `radii`, `kinds`), non con
## metodi: leggere la massa non e' una query. Qui quei campi finiscono in **tre**
## `MultiMeshInstance3D` — una per modello, perche' dal 2026-10-15 le cinque specie
## non sono piu' tutte lo stesso GLB (vedi `KIND_SLOT`) — quindi il numero di nodi
## non dipende dal numero di nemici. E' il criterio n. 3 della milestone:
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

## ## I MODELLI: TRE MESH, CINQUE SPECIE, E LA DISTRIBUZIONE DICHIARATA
##
## Prima di m15 le cinque specie erano **lo stesso GLB** (`enemy_small.glb`) tinte per
## istanza. E' la cosa piu' economica che si possa fare e anche la piu' fragile: la
## tinta da sola non distingue un mortar da un brute a mezzo campo, e l'utente ha
## guardato il gioco e **non e' riuscito** a distinguerlo. Il difetto non era la
## tinta, era che la tinta era l'unico segnale.
##
## Quindi **forma diversa, non solo colore**: tre modelli gia' presenti in
## `assets/models/` che nessuno caricava, e una tabella che dice quale va a chi.
##
##     slot 0  enemy_small.glb  icosfera grossolana, 20 triangoli, tonda
##             -> runner (0) e grunt (1)
##     slot 1  enemy_big.glb    cubo, 12 triangoli, spigoli duri
##             -> brute (2) e mortar (4)
##     slot 2  enemy_boss.glb   icosfera fine, 80 triangoli, la piu' dettagliata
##             -> boss (3)
##
## ### LA COPPIA CHE CONDIVIDE: `runner` e `grunt`, e perche' quelle due
##
## Sono le due specie **piu' numerose e le piu' piccole**: sul campione di m8 sono 83
## e 62 su 200 (72% dell'orda) e disegnano 1,53 m e 2,04 m, una differenza di 0,51 m
## che si vede senza dover guardare la forma. Non hanno bisogno di essere identificate
## **a distanza**: sono la folla che arriva addosso al giocatore e che si distingue per
## la tinta e per la taglia gia' dal primo passo di m8. Dar loro il modello da 20
## triangoli tiene inoltre il costo della folla a meta': il boss da 80 triangoli
## raggiunge 6 corpi su 200, il cubo da 12 ne raggiunge 49.
##
## ### LA COPPIA PEGGIORE: `boss` e `mortar`, e perche' non si toccano
##
## Sono le due uniche specie che il giocatore deve **decidere** da lontano, e le due
## decisioni sono opposte: il mortar ti dice *schiva da qui*, il boss ti dice *vieni
## qui e spara*. Sono anche le due piu' grandi (`RADIUS` 1,90 e 1,40, cioe' 6,46 m e
## 4,76 m disegnati) e hanno raggi di morso diversi (3,10 m contro 2,42 m): due corpi
## della stessa forma e della stessa taglia con due morsi diversi e' il modo piu'
## economico di far sbagliare una schivata. E' la coppia che questo file non mette
## insieme, ed e' l'unica giudicabile dall'occhio senza un numero.
##
## ## LA TABELLA DEGLI INDICI, e perche' non e' una settima copia
##
## `KIND_SLOT` e' una lista per **indice di specie**, e l'indice di specie e' di
## `-orda` (`src/sim/enemy.gd::KIND_NAMES`). Non lo si ricopia in un `Dictionary`
## per nome: 200 ricerche di stringa in un frame non sono un dettaglio. Quindi
## l'indice e' una copia **dichiarata**, e `tests/test_arena.gd` la confronta voce per
## voce con `KIND_NAMES` letto dal file di `-orda`: se `-orda` aggiungesse una sesta
## specie o riordinasse le prime cinque, questa sezione va rossa invece di assegnare
## una mesh a una specie che non e' piu' quella.
const MESH_SCENES := [
	"res://assets/models/enemy_small.glb",
	"res://assets/models/enemy_big.glb",
	"res://assets/models/enemy_boss.glb",
	"res://assets/models/enemy_trojan.glb",
	"res://assets/models/enemy_wurm_segment.glb",
]

## kind -> slot. L'ordine e' quello di `KIND_NAMES` in `src/sim/enemy.gd`, e il test
## lo verifica. Vedi la dichiarazione sopra.
const KIND_SLOT := [0, 0, 1, 2, 1, 3, 4]

## Il path del modello del **slot** `slot`, cioe' l'indice in `MESH_SCENES`.
##
## Fuori tabella restituisce `""`: `ResourceLoader.exists("")` e' falso, quindi
## `_load_mesh` torna `null` e `_build()` dice il path che non ha trovato. Uno slot
## sbagliato in scena deve essere **un avviso con il nome del file**, non un crash
## nel primo fotogramma e non un nemico disegnato con la mesh sbagliata.
func _mesh_path(slot: int) -> String:
	if slot < 0 or slot >= MESH_SCENES.size():
		return ""
	return MESH_SCENES[slot]

## Quale modello disegna il nemico di **indice di specie** `kind`, cioe' la
## traduzione di un indice di `-orda` in uno slot di questo file.
##
## Fuori tabella restituisce `-1`, che non e' nessuno dei tre slot: quel nemico non
## viene disegnato da nessuno dei tre nodi invece che essere disegnato con un modello
## che non gli appartiene. Non si prende il modulo per farlo entrare in tabella:
## il modulo e' una mesh **sbagliata** che il giocatore non puo' distinguere da
## quella giusta, e un nemico invisible e' un difetto che si vede; una mesh
## sbagliata e' un difetto che non si vede ed e' per questo che va evitato.
func slot_of_kind(kind: int) -> int:
	if kind < 0 or kind >= KIND_SLOT.size():
		return -1
	return KIND_SLOT[kind]

## Quale dei tre modelli disegna **questo** nodo. Lo mette la scena
## (`scenes/arena_main.tscn`), non un campo scritto qui: un nodo per mesh e' un
## numero che si vede nella scena, e tre nodi sono tre nodi **con zero nemici** come
## con duecento. Il tetto e' dichiarato dove nasce il criterio: `_build()`.
@export var mesh_slot: int = 0

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
## **Dal 2026-10-15 questo numero sopravvive ai tre modelli**: l'istanza e' scalata
## di `SIZE_FACTOR x RADIUS[k] / mesh_span` (vedi `_mesh_span`), quindi il prodotto
## `scala x lato maggiore della mesh` e' ancora `3,4 x RADIUS[k]` per tutte e tre le
## mesh. Il numero che m8 ha tarato non e' stato ritoccato: e' stato salvato dalla
## normalizzazione, che e' l'unico modo per avere tre forme senza avere tre taglie.
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

## ## LA NORMALIZZAZIONE PER MESH: `1 / mesh_span`, e perche' e' la cosa che
## ## tiene insieme «che cosa vedi» e «che cosa morde»
##
## I tre modelli hanno AABB diverse (misurate il 2026-10-15: `enemy_small`
## 0,894425 x 1,000000 x 0,850640 m, `enemy_big` 1,2 x 1,2 x 1,2 m, `enemy_boss`
## 1,902116 x 2,000000 x 2,000000 m). Scalando tutti e tre con lo stesso
## `SIZE_FACTOR x RADIUS[k]` il boss diventerebbe **il doppio** di come e' oggi
## (12,92 m invece di 6,46 m) e il rapporto `disegnato / raggio` non sarebbe piu' lo
## stesso numero per tutti: si riaprirebbe esattamente il difetto che m8 ha chiuso,
## cioe' un corpo che morde a 3,10 m e ne disegna 12,92.
##
## Quindi l'istanza e' scalata di `SIZE_FACTOR x RADIUS[k] / mesh_span`, dove
## `mesh_span` e' **il lato maggiore della mesh** e non un numero scritto qui: e'
## misurato una volta sola, in `_build()`, dalla stessa mesh che viene disegnata.
## Il prodotto `scala x mesh_span` e' allora `SIZE_FACTOR x RADIUS[k]` per **tutti e
## tre** i modelli, cioe' esattamente il numero di oggi: l'impronta a terra e
## l'altezza restano quelle che il morso e la cupola del mortar gia' misuravano, e
## cambia solo **quale forma** ci sta dentro.
var _mesh_span: float = 1.0
var _mesh_size: Vector3 = Vector3.ONE

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
var _scroll_offset: Vector3 = Vector3.ZERO
var _built: bool = false
var _last_drawn: int = 0
var _last_radius: float = -1.0
var _basis: Basis = Basis.IDENTITY
var _basis_time: float = -1.0
## Avviso emesso una volta sola: `radii` mancante e' un difetto di -orda, non un
## rumore da ripetere ogni frame (vedi `_radii_of`).
var _warned_radii: bool = false
## Avviso emesso una volta sola: `kinds` mancante significa che tutti i nemici
## avrebbero la stessa forma, cioe' il difetto che m15 chiude.
var _warned_kinds: bool = false
## Quanti nemici di **questo** modello non sono entrati nel buffer all'ultimo
## `refresh()`. Il numero che il test stampa accanto alla capienza.
var _last_clamped: int = 0

func _ready() -> void:
	_build()

func _process(delta: float) -> void:
	_time += delta
	_update_scroll_offset()
	refresh()

# --- Costruzione --------------------------------------------------------------

## Fatta una volta sola. Nessun nodo, nessuna instanziazione dopo questo punto.
func _build() -> void:
	if _built:
		return
	_built = true
	var path: String = _mesh_path(mesh_slot)
	var mesh := _load_mesh(path)
	if mesh == null:
		push_warning("horde_renderer: nessuna mesh in %s, l'orda non si vede" % path)
		return
	# L'altezza e il lato maggiore del modello servono a tenere i piedi del nemico
	# sul pavimento e a **normalizzare** la scala fra modelli diversi (vedi
	# `_mesh_span`). Si misurano qui, una volta sola: sono un dato della mesh, non un
	# numero scritto a mano, quindi restano veri se domani il modello cambia.
	_mesh_size = mesh.get_aabb().size
	_mesh_height = maxf(_mesh_size.y, 0.0)
	_mesh_span = maxf(_mesh_size.x, maxf(_mesh_size.y, _mesh_size.z))
	if not (_mesh_span > 0.0):
		# Una mesh senza spessore non si scala: si accavalla. Meglio una taglia di
		# 1,0000 che dichiarata qui che un nemico che non si vede e nessuno che lo
		# dica, e il valore resta comunque proporzionale al raggio.
		push_warning("horde_renderer: %s ha AABB di lato massimo %.6f m: la normalizzazione per mesh non e' possibile e si scala di 1" % [path, _mesh_span])
		_mesh_span = 1.0
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

## Quanti nemici **di questo modello** l'ultimo `refresh()` ha scartato perche' il
## buffer era pieno. Stessa ragione di `drawn_count()`: il test deve poter dire il
## numero che e' stato scartato senza rileggerlo da un campo.
func clamped_count() -> int:
	return _last_clamped

## Il percorso del modello che **questo nodo** sta disegnando, cioe' `_mesh_path()`
## applicata a `mesh_slot`. Pubblico perche' e' l'unica lettura che distingue una
## tabella giusta da una scena che non la usa: se i tre nodi portassero lo stesso
## `mesh_slot`, il gioco mostrerebbe un modello solo mentre il file ne dichiara tre.
func mesh_path() -> String:
	return _mesh_path(mesh_slot)

## Le dimensioni della mesh di questo nodo, **misurate** in `_build()` e non
## ricopiate. Il test le moltiplica per la scala della trasformazione per ottenere
## l'estensione disegnata: se il valore venisse da una costante, la normalizzazione
## di `_mesh_span` smetterebbe di essere verificata da qualcosa.
func mesh_size() -> Vector3:
	return _mesh_size

## Questo nodo disegna la specie `kind`? E' la domanda posta **al nodo** e non alla
## tabella, perche' un nodo che non usa `KIND_SLOT` e' un difetto che la tabella
## sola non puo' vedere.
func handles_kind(kind: int) -> bool:
	return slot_of_kind(kind) == mesh_slot

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

	var positions: PackedVector3Array = horde.transforms
	var tints: PackedColorArray = horde.colors
	# ## IL QUINTO ARRAY PARALLELO: `kinds`, e perche' adesso serve anche a -arena
	#
	# `kinds[i]` e' l'indice di specie del nemico `i`, dichiarato nella superficie di
	# m8 accanto a `radii`, ed e' l'unica cosa che sa **quale modello** disegnare.
	# Passa per `get()` come `radii`, per la stessa ragione: il campo e' scritto da
	# `-orda` e questa onda lavora in parallelo a lui, quindi un campo non ancora
	# arrivato deve diventare un avviso una volta sola e non un crash nel mezzo
	# dell'orda.
	var kinds = horde.get("kinds")
	if not (kinds is PackedInt32Array):
		if not _warned_kinds:
			_warned_kinds = true
			push_warning("horde_renderer: horde.kinds non e' un PackedInt32Array (misurato %s): senza l'indice di specie tutti i nemici sarebbero lo stesso modello, cioe' il difetto che m15 chiude. Il campo e' la superficie congelata di m8 in src/core/contracts.gd e lo scrive -orda."
				% type_string(typeof(kinds)))
		multimesh.visible_instance_count = 0
		_last_drawn = 0
		_last_radius = -1.0
		return
	var indici: PackedInt32Array = kinds
	# Cinque guardie, e non una sola di `_build`: l'invariante `transforms.size()
	# == colors.size() == radii.size() == kinds.size() == count` e' di -orda e vale
	# nel suo test, non nel mio. Se un giorno non valesse, il renderer accorcia
	# invece di leggere fuori dal vettore: un errore in questo ciclo di gioco e' un
	# crash in mezzo all'onda.
	var scan: int = horde.count
	if scan > positions.size():
		scan = positions.size()
	if scan > tints.size():
		scan = tints.size()
	if scan > sizes.size():
		scan = sizes.size()
	if scan > indici.size():
		scan = indici.size()

	# Il ciclo e' piatto: una passata sugli array gia' allocati, niente allocazione e
	# niente nodi. Ogni nodo **passa** tutta l'orda e scrive solo i nemici del suo
	# modello, quindi il costo totale sono `3 confronti per nemico`, non `3 scritture`:
	# il confronto e' un'intera su un array, la scrittura nel buffer e' un aggiornamento
	# di storage. La rotazione la tiene in piedi `instance_transform` per un frame
	# intero; la **scala no**, perche' da m8 cambia da nemico a nemico.
	var drawn := 0
	var accorciati := 0
	for i in scan:
		if slot_of_kind(indici[i]) != mesh_slot:
			continue
		if drawn >= CAPACITY:
			# Oltre la capienza di **questo** nodo: il nemico esiste, il suo modello
			# e' gia' pieno, e il numero accorciato viene detto invece di far sparire
			# un nemico senza avviso.
			accorciati += 1
			continue
		multimesh.set_instance_transform(drawn, instance_transform(positions[i], sizes[i], i))
		multimesh.set_instance_color(drawn, tints[i])
		_last_radius = sizes[i]
		drawn += 1
	multimesh.visible_instance_count = drawn
	_last_drawn = drawn
	_last_clamped = accorciati
	if drawn == 0:
		_last_radius = -1.0

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
	# La scala e' `raggio x fattore di calibrazione`, divisa per il lato maggiore
	# della **mesh di questo nodo**: e' la normalizzazione di `_mesh_span`, e senza
	# di essa un boss (AABB 2,000000 m) disegnerebbe il doppio di un runner
	# (AABB 1,000000 m) a parita' di raggio, cioe' il corpo che morde a 3,10 m
	# diventerebbe un corpo che ne disegna 12,92. Il prodotto `scala x lato maggiore`
	# resta `SIZE_FACTOR x RADIUS[k]` per tutte e tre le mesh.
	var s: float = maxf(radius, 0.0) * SIZE_FACTOR / _mesh_span
	# La sollevata segue la scala: meta' dell'altezza effettiva del corpo, cosi'
	# i piedi restano sul pavimento a ogni taglia invece che a una sola.
	var lift: float = 0.5 * s * _mesh_height
	return Transform3D(_shared_rotation().scaled(Vector3(s, s, s)),
		Vector3(pos.x - _scroll_offset.x, pos.y + lift + bob, pos.z - _scroll_offset.z))

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

func _update_scroll_offset() -> void:
	var game := _contract()
	var p := Vector3.ZERO
	if game != null and game.has_method("player_position"):
		p = game.player_position()
	elif game != null:
		var pl = game.get("player")
		if pl is Node3D:
			p = (pl as Node3D).global_position
	_scroll_offset = Vector3(0.0, 0.0, p.z)

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