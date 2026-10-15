extends MultiMeshInstance3D
## La cupola rossa che segnala dove cade il colpo del mortar.
##
## ## LA RICHIESTA DELL'UTENTE, 2026-10-15
##
## «viene segnalato con una cupola rossa dove atterra il colpo dando la possibility
## di schivare al giocatore».
##
## Tre pezzi, e due sono di `-orda`: il colpo cade dopo `mortar_telegraph_s`
## secondi (`src/sim/enemy.gd::telegraph_for`), e `-orda` espone **dove** cade e
## **quando manca** con `horde.mortar_shot_count`, `horde.mortar_shot_at(i)` e
## `horde.mortar_shot_left(i)`. Il pezzo di **-arena** e' solo questo file: la
## forma che si vede, e nient'altro.
##
## Il tempo e il raggio attraversano il contratto (`Game.mortar_telegraph_s`,
## `Game.mortar_blast_m`) perche' sono **due foglie e un solo istante**: se ognuna
## avesse il suo, la cupola direbbe «schiva qui» e il colpo cadrebbe altrove,
## che e' la classe di difetto delle sei copie di m9, gia' pagata una volta.
##
## ## PERCHE' IL RAGGIO E' `mortar_blast_m` E NON UNA CIFRA
##
## Il criterio e' che la cupola **misurata in metri** sia quella che il colpo
## colpisce. Una cupola piu' piccola mente per difetto («sei schivato» mentre sei
## dentro), una piu' grande mente per eccesso («schivati» mentre ti ha preso):
## quindi il raggio qui non e' una scelta di disegno, e' `Game.mortar_blast_m`
## **riletto a ogni refresh** e mai ricopiato in un campo. `_contract_blast()` e'
## l'unica lettura, ed e' dichiarata perche' non ce ne sia una seconda.
##
## ## LA FORMA: una semisfera, e perche' una semisfera
##
## `SphereMesh` e' una primitiva del motore, non un asset: questa milestone non ne
## aggiunge uno e non tocca `assets/`, che non e' di -arena. Il raggio della sfera
## e' `MESH_RADIUS` e l'altezza il doppio, quindi l'istanza scala tutto: e' la
## stessa forma di `obstacle_transform()` in `arena_obstacles.gd`, che scala un
## cilindro unitario sul raggio del disco che blocca.
##
## La cupola e' **appoggiata sul pavimento** (`origin.y = 0`), quindi l'impronta a
## terra ha raggio esattamente `mortar_blast_m` e il criterio la misura li' con
## `basis.get_scale().x`. Una sfera intera che affonda meta' sotto il terreno
## mostrerebbe lo stesso disco a occhio e sarebbe un'altra cosa: quello che
## l'esplosione colpisce deve essere **quello che si vede**, ed e' la meta' di
## -arena del criterio n. 6 di m10, qui ripetuto sulle cupole.
##
## ## UN SOLO NODO, COME I DISCHI E COME L'ORDA
##
## Una cupola in volo e' un dato, non un oggetto di scena: se ogni colpo fosse un
## `Node3D` il `node_count` salirebbe con il fuoco dell'orda, che e' il tetto che
## questo progetto ha gia' violato una volta con i nemici. Qui il costo e' **un
## nodo** e un solo buffer, con `visible_instance_count` che dice quante cupole ci
## sono: 46 nodi con zero colpi in volo e 46 con sette.

## ## LA CAPACITA', e perche' non e' il numero di una foglia
##
## Il tetto e' dichiarato qui e non letto a runtime, perche' un tetto che dipende
## da un valore letto non e' un tetto. Il valore che **lo giustifica** e' di
## `-orda`: un nemico non puo' avere due colpi in volo (`ricarica > telegrrafo`,
## scritto in `src/sim/horde.gd::_mortar_spara`) e i nemici sono `MAX_ENEMIES`, che
## `tests/test_arena.gd` rilegge dal codice di `-orda` e confronta con questa riga:
## se `-orda` alzasse il tetto oltre questa capienza, quella sezione va rossa invece
## di lasciare la cupola **sotto-disegnata e senza dirlo**.
const CAPACITY := 256

## Segmenti e anelli della sfera. Il tetto di triangoli del progetto e' 20-40 per
## corpo e questa cupola ne usa meno di 100: non e' una scia, e' un segnale da
## leggere in mezzo a duecento nemici. Dieci lati si leggono meglio di una sfera
## liscia da 64, e il bordo della cupola resta quello che il giocatore vede.
const DOME_SEGMENTS := 10
const DOME_RINGS := 4

## ## IL ROSSO, e perche' questo rosso
##
## `src/sim/enemy.gd` dichiara il **mortar ciano** apposta perche' il rosso e' di
## questa cupola: «una specie colorata come il proprio avvertimento renderebbe il
## segnale illeggibile». Quindi il canale qui e' l'unico del progetto che puo'
## essere rosso, e questa tinta puo' saturare quanto le serve.
##
## **Non illuminata** (`SHADING_MODE_UNSHADED`): la cupola deve dire la stessa
## cosa nella zona d'ombra del muro e sotto il sole, altrimenti il segnale che
## serve a schivare dipenderebbe da dove cade l'ombra.
##
## **Trasparente**: il giocatore da schivare sta **dentro** la cupola, e una cupola
## opaca lo nasconderebbe proprio nel momento in cui lo si deve guardare.
const DOME_COLOR := Color(0.95, 0.10, 0.07, 0.42)

## Quanto la cupola si abbassa e si rialza, come frazione dell'altezza piena.
##
## **La scala XZ non si muove mai**: `DOME_MIN_HEIGHT` moltiplica solo `y`, quindi
## l'impronta a terra resta `mortar_blast_m` in ogni istante del pulsare. Il
## criterio lo verifica — `drawn_radius()` non cambia mai e `drawn_height_ratio()`
## sì' — perche' una cupola che pulsa anche in diametro smetterebbe di dire
## *dove* cade il colpo e direbbe solo «qui vicino».
const DOME_MIN_HEIGHT := 0.45

## Colpi di pulsazione al secondo. Il canale porta **quanti secondi mancano**, e il
## ritmo e' ancorato a quel numero e non a un orologio di -arena: due istanti con
## lo stesso `remaining` danno la stessa cupola, quindi una misura fatta dal test
## e' ripetibile e il difetto non si nasconde in una fase qualsiasi.
const DOME_PULSE_HZ := 2.4

## Il raggio della mesh non modificata, in metri. Vive qui e non dentro `_mesh()`
## perche' `dome_transform()` deve poterlo misurare: un numero che sta in una
## riga sola e in un'altra e' una copia che un giorno diverge.
const MESH_RADIUS := 1.0

## Quanto il riquadro di disegno e' piu' largo della cupola piu' esterna, in metri.
## Derivato dal margine di -arena sui muri, non scritto a occhio: un riquadro
## stretto qui cancella la cupola senza dire niente (vedi `_fit_aabbs()` in
## `arena_ground.gd`).
const AABB_MARGIN := 1.0

## Le trasformazioni **scritte nel buffer**, tenute per la verifica.
##
## Non e' una copia della geometria di gioco: e' la traccia di quello che questo
## renderer ha messo sul serio nel `MultiMesh`, e serve perche' il buffer **non si
## rilegge in headless** (in Godot 4.7 le trasformazioni stanno in uno storage
## buffer del RenderingDevice che nel backend "dummy" di `--headless` non esiste,
## e `get_instance_transform` restituisce silenziosamente una trasformazione
## vuota). Quindi l'unico modo di controllare davvero *che cosa* e' stato scritto e'
## ricordarlo qui: e' allocata una volta sola e non cresce mai.
var _written: Array[Transform3D] = []

## L'orda da cui leggere il canale. Se non e' impostata si prende `Game.horde`.
var _horde: Node = null
var _contract_cache: Node = null
var _built: bool = false

## I numeri dell'ultimo `refresh()`, per il test e per il debug.
var _last_drawn: int = 0
var _last_asked: int = 0
var _last_blast: float = -1.0

## Tre avvisi emessi **una volta sola**: un canale assente e' un difetto di
## `-orda`, non un rumore da ripetere ogni frame (cfr. `_warned_radii` in
## `horde_renderer.gd`).
var _warned_horde: bool = false
var _warned_surface: bool = false
var _warned_blast: bool = false

func _ready() -> void:
	_build()

func _process(_delta: float) -> void:
	refresh()

# --- Costruzione --------------------------------------------------------------

## Fatta una volta sola. Nessun nodo, nessuna instanziazione dopo questo punto.
##
## Qui dentro si impostano **anche** il formato, i colori per istanza e il
## materiale: nel ciclo di gioco, sotto, ci stanno solo scritture dentro il buffer
## gia' allocato.
func _build() -> void:
	if _built:
		return
	_built = true
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# Nessun colore per istanza: la tinta e' una scelta di -arena e vale per tutte
	# le cupole, quindi non ha bisogno di un canale. E se ne aggiungesse uno, il
	# numero dei canali di -arena che `-orda` deve riempire cresce a ogni
	# milestone, e il contratto diventa un posto dove si scrive a mano.
	mm.use_colors = false
	mm.mesh = _mesh()
	mm.instance_count = 0
	multimesh = mm
	material_override = _material()
	custom_aabb = _aabb([], 0.0)

## La mesh della cupola: una sfera di raggio `MESH_RADIUS` e altezza doppia, cioe'
## la semisfera unitaria che `dome_transform()` scala sul raggio vero del colpo.
##
## Non e' un asset: `SphereMesh` e' una primitiva del motore, e questa milestone non
## ne aggiunge uno (`assets/` non e' di -arena e questa onda non lo apre).
func _mesh() -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = MESH_RADIUS
	m.height = MESH_RADIUS * 2.0
	m.radial_segments = DOME_SEGMENTS
	m.rings = DOME_RINGS
	return m

func _material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = DOME_COLOR
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Si vede anche da dentro: la camera puo' finire dentro una cupola quando il
	# giocatore ci entra, e una cupola che sparisce quando ci sei dentro e' una
	# cupola che sparisce quando serve.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Due cupole sovrapposte non devono scrivere la profondita': altrimenti la
	# seconda taglia la prima e l'ordine delle istanze diventa geometria.
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.roughness = 1.0
	m.metallic = 0.0
	return m

## La scatola che il motore usa per decidere se disegnare, **derivata dai colpi** e
## dal raggio appena letto dal contratto. Prende il raggio in argomento e non lo va
## a cercare in un campo: con il raggio in un campo, il riquadro dell'ultimo frame
## sarebbe quello del frame in cui il contratto aveva un altro valore.
func _aabb(points: Array, radius: float) -> AABB:
	if points.is_empty():
		return AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0))
	var r: float = maxf(radius, 0.0)
	var lo := Vector3(INF, -AABB_MARGIN, INF)
	var hi := Vector3(-INF, radius, -INF)
	for p in points:
		var v: Vector3 = p
		lo = Vector3(minf(lo.x, v.x - r), lo.y, minf(lo.z, v.z - r))
		hi = Vector3(maxf(hi.x, v.x + r), hi.y, maxf(hi.z, v.z + r))
	return AABB(lo - Vector3(AABB_MARGIN, 0.0, AABB_MARGIN),
		hi - lo + Vector3(2.0 * AABB_MARGIN, 2.0, 2.0 * AABB_MARGIN))

# --- Lettura del canale --------------------------------------------------------

## Da quale nodo prendere il canale. Di norma `Game.horde`; il test vi inietta un
##'orda finta con la stessa forma. Non e' un `get_node("../..")`: e' un dato, non
## una dipendenza fra foglie.
func set_horde(horde: Node) -> void:
	_horde = horde

## Copia il canale nel buffer. Chiamata una volta per frame: il numero di scritture
## e' il numero di cupole a schermo, che sono poche e non sono mai 200, e qui non
## c'e' `new()`, non c'e' `resize` e non c'e' un nodo.
func refresh() -> void:
	if not _built or multimesh == null:
		return
	var horde := _resolve_horde()
	if horde == null:
		if not _warned_horde:
			_warned_horde = true
			push_warning("mortar_renderer: nessuna orda registrata (Game.horde), quindi nessuna cupola da disegnare. Resta un nodo solo e nessuna cupola: e' la piramide non montata, non un mondo senza avvertimenti.")
		_clear()
		return
	# La superficie congelata di m13. I tre nomi stanno in `src/sim/horde.gd` e
	# sono dichiarati in `src/core/contracts.gd`; qui si usano i **metodi** e non
	# l'array grezzo perche' `mortar_shot_at(i)` restituisce il punto **del mondo**
	# con la convenzione `(x, z, secondi)` gia' disfatta: `-orda` ha scritto quel
	# metodo perche' la trappia di m10 (il raggio del disco sta in `y`) si ripete
	# anche qui, e questo file non deve portarsela dentro.
	if not _surface_ok(horde):
		if not _warned_surface:
			_warned_surface = true
			push_warning("mortar_renderer: l'orda non espone `mortar_shot_count`, `mortar_shot_at(i)` e `mortar_shot_left(i)`: senza il canale di m13 nessuna cupola puo' essere disegnata, perche' il punto di caduta e' l'unica cosa che distingue «schiva qui» da una macchia rossa a caso. La superficie e' congelata in src/core/contracts.gd e lo scrive -orda.")
		_clear()
		return
	# ## Il raggio viene riletto **a ogni refresh**, mai messo in un campo
	#
	# Il numero che deve combaciare con quello che l'esplosione colpisce e' uno solo
	# e cambia solo se cambia il contratto: leggerlo una volta sola prenderebbe il
	# valore giusto al primo frame e continuerebbe a mentire per tutta la partita.
	# `tests/test_arena.gd` avvelena il campo e verifica che la cupola lo riveda.
	var blast := _contract_blast()
	if not (blast > 0.0):
		if not _warned_blast:
			_warned_blast = true
			push_warning("mortar_renderer: il contratto non dichiara `mortar_blast_m` (letto %.4f): senza il raggio di esplosione la cupola direbbe una dimensione che nessuno misura, quindi e' meglio nessuna cupola di una cupola che mente." % blast)
		_clear()
		return

	var asked: int = int(horde.get("mortar_shot_count"))
	var wanted: int = asked
	# Due guardie, e non una sola di `_build()`. L'invariante
	# `mortar_shot_count <= mortar_shots.size()` e' di `-orda` e vale nel suo test,
	# non nel mio: se un giorno non valesse, il renderer accorcia invece di leggere
	# fuori dal vettore, perche' un errore in questo ciclo di gioco e' un crash in
	# mezzo all'onda.
	if wanted < 0:
		wanted = 0
	if wanted > CAPACITY:
		wanted = CAPACITY

	# La capienza si assegna **prima** di scrivere: `set_instance_transform(i)` su un
	# indice che non esiste ancora non scrive niente e non avvisa nessuno.
	multimesh.instance_count = wanted
	var points: Array = []
	for i in wanted:
		var world: Vector3 = horde.mortar_shot_at(i)
		var left: float = float(horde.mortar_shot_left(i))
		var t := dome_transform(world, left, blast)
		multimesh.set_instance_transform(i, t)
		points.append(t.origin)
		if i < _written.size():
			_written[i] = t
		else:
			_written.append(t)
	# La casella di colore e' l'ultima: e' quella che dice al motore **quante**
	# cupole ci sono, e senza questa riga le istanze sopravvissute dal frame prima
	# resterebbero visibili quando il canale si e' svuotato.
	multimesh.visible_instance_count = wanted
	custom_aabb = _aabb(points, blast)
	if wanted == 0:
		_written.clear()
	_last_drawn = wanted
	_last_asked = asked
	_last_blast = blast

## Nessuna cupola a schermo. E' una funzione e non un valore: una cupola che resta
## dopo l'impatto dice «schivati» a chi e' gia' stato colpito, ed e' il difetto piu'
## grave che qui si puo' fare.
func _clear() -> void:
	if multimesh == null:
		return
	multimesh.instance_count = 0
	multimesh.visible_instance_count = 0
	custom_aabb = _aabb([], 0.0)
	_written.clear()
	_last_drawn = 0
	_last_asked = 0

## La superficie di m13 c'e' tutta? Un canale a meta' e' un canale che non esiste:
## senza `mortar_shot_at` la cupola non saprebbe ne' dove mettersi ne' cosa
## distingue una cupola da un disco.
func _surface_ok(horde) -> bool:
	return horde.has_method("mortar_shot_at") and horde.has_method("mortar_shot_left") \
		and typeof(horde.get("mortar_shot_count")) == TYPE_INT

## ## IL RAGGIO, LETTO E NON RICOPIATO
##
## Passa per `get()` e non per `Game.mortar_blast_m` per la stessa ragione che vale
## in `horde_renderer.gd` con `radii`: il campo e' scritto da `-orda` e questa onda
## lavora **in parallelo** a lui. Con l'accesso diretto un campo non ancora arrivato
## interromperebbe il ciclo di gioco con un errore a runtime nel mezzo della
## partita; con `get()` arriva `-1.0` e la guardia di `refresh()` lo dichiara una
## volta sola, con il nome del campo.
func _contract_blast() -> float:
	var game := _contract()
	if game == null:
		return -1.0
	var value = game.get("mortar_blast_m")
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return -1.0

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

## ## LA TRASFORMAZIONE DI UNA CUPOLA: pubblica e pura
##
## E' l'unico posto dove il raggio del contratto diventa geometria, e il ciclo di
## `refresh()` passa di qui per ogni colpo: quindi e' anche la funzione che il test
## verifica, e non una ricostruzione parallela di quello che il renderer dovrebbe
## fare.
##
## `world` e' il punto **del mondo** come lo restituisce `horde.mortar_shot_at(i)`,
## cioe' con `y` gia' a zero e gia' nel suo ordine vero. `remaining` sono i secondi
## che mancano alla caduta e servono **solo** al ritmo del pulsare: non spostano la
## cupola e non ne cambiano l'impronta. `blast` e' `Game.mortar_blast_m`, e il
## raggio dell'impronta e' esattamente quel numero.
func dome_transform(world: Vector3, remaining: float, blast: float) -> Transform3D:
	var r: float = maxf(blast, 0.0) * MESH_RADIUS
	var h: float = r * _height_ratio(remaining)
	return Transform3D(Basis.IDENTITY.scaled(Vector3(r, h, r)),
		Vector3(world.x, 0.0, world.z))

## Quanto la cupola e' alta rispetto al pieno, in `[DOME_MIN_HEIGHT, 1]`.
##
## Funzione **del solo canale**, non di un orologio: due istanti con lo stesso
## `remaining` danno la stessa cupola. Il segno e' negativo perche' `remaining`
## **scende**: cosi' la cupola parte bassa e si alza fino all'impatto, che e' il
## gesto che dice «sta per cadere». Una pulsazione che comincia e finisce senza
## significato non aggiunge niente e sembra un effetto.
func _height_ratio(remaining: float) -> float:
	if remaining <= 0.0:
		return 1.0
	var fase: float = 0.5 + 0.5 * sin(-remaining * TAU * DOME_PULSE_HZ)
	return DOME_MIN_HEIGHT + (1.0 - DOME_MIN_HEIGHT) * fase

# --- Lettura (per il test e per il debug) -------------------------------------

## La trasformazione della cupola `i` **cosi' com'e' stata scritta nel buffer**.
func written_transform(i: int) -> Transform3D:
	if i < 0 or i >= _written.size():
		return Transform3D.IDENTITY
	return _written[i]

## Il raggio **disegnato**, in metri: quello che l'occhio vede a terra, e va
## confrontato con il raggio che l'esplosione colpisce.
func drawn_radius(i: int) -> float:
	var t := written_transform(i)
	return maxf(t.basis.get_scale().x, 0.0)

## L'altezza disegnata **sul raggio**. Serve per dire che il pulsare cambia la
## cupola e non la sua impronta.
func drawn_height_ratio(i: int) -> float:
	var t := written_transform(i)
	var r: float = maxf(t.basis.get_scale().x, 0.0)
	if r <= 0.0:
		return 0.0
	return t.basis.get_scale().y / r

## Quante cupole sono state messe sul serio nel buffer all'ultimo `refresh()`.
func drawn_count() -> int:
	return _last_drawn

## Quante il canale ne chiedeva all'ultimo `refresh()`. E' la **precondizione** e
## non il risultato: senza questo una prova passerebbe anche con un canale finto che
## non chiede niente, che e' il difetto che `FakeHorde.drawn_asked()` chiude per
## l'orda.
func requested_count() -> int:
	return _last_asked

## Quante ne sono state **accorciate** dalla guardia di capienza.
func clamped_count() -> int:
	return maxi(0, _last_asked - _last_drawn)

## Il raggio di esplosione **letto dal contratto** all'ultimo `refresh()`, o `-1.0`
## se non e' arrivato. Non serve al ciclo di gioco: esiste perche'
## `tests/test_arena.gd` debba poter dire *quale* valore ha prodotto la cupola
## **misurandolo**, invece di rileggerlo dalla costante che lo produce.
func blast_used() -> float:
	return _last_blast

## La cupola e' stata costruita? Serve al test per dire «il difetto e' che non
## esiste» invece di misurare un nodo che non ha costruito niente.
func is_built() -> bool:
	return _built

# --- Interno ------------------------------------------------------------------

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