extends MultiMeshInstance3D
## Il colpo del mortar **che cade**: il pezzo che mancava, e che e' di -arena.
##
## ## LA FOTOGRAFIA DEL DIFETTO (2026-10-15)
##
## `src/render/mortar_renderer.gd` disegna la **cupola a terra** e nient'altro: il
## giocatore vede *dove* cade il colpo e non vede *da dove arriva*. E' la classe di
## difetto piu' grave che qui si puo' fare, perche' un avvertimento senza causa e'
## un avvertimento che si puo' imparare a ignorare: la cupola resta li', il
## nemico che l'ha chiamata si vede, e dopo due colpi il giocatore smette di
## guardare. Col corpo in volo la cupola diventa invece la **punta** di una traiettoria
## che l'occhio puo' seguire dal cielo fino a terra.
##
## Il canale e' **lo stesso** di quello delle cupole, scritto da `-orda` e letto con
## i suoi metodi: `horde.mortar_shot_count`, `horde.mortar_shot_at(i)`,
## `horde.mortar_shot_left(i)`. Nessun campo nuovo, nessuna superficie nuova: e'
## la via che `mortar_renderer.gd` dichiara gia' e che questa onda non allarga.
##
## ## LA QUOTA DI PARTENZA: PERCHE' 26 m E NON 2 m E NON 200 m
##
## Il vertice ha posto la domanda con i due numeri che decidono: **il nemico e'
## alto 1,000 m** (AABB di `enemy_small.glb`, misurato: 0,894425 x 1,000000 x
## 0,850640 m) e **l'arena ha 60 m di raggio**. Da quei due numeri, e dalla
## moltiplicazione `SIZE_FACTOR x RADIUS[k]` del renderer, si ricava la banda in cui
## un colpo e' **fuori dal campo visivo**:
##
##   - **2 m**: il corpo piu' alto che il gioco disegna e' il boss,
##     `3,4 x 1,90 = 6,46 m`, e la cupola che ne segnala la caduta ha raggio
##     `Game.mortar_blast_m = 5,2100 m`. Un colpo a 2 m sta **dentro la propria
##     cupola** e sotto la testa di 145 nemici su 200: si vede il tetto di una forma
##     rossa e non il colpo. E' il difetto che questa sezione chiude.
##   - **200 m**: la camera sta a 34 m sopra l'ancora (`arena_camera.gd::HEIGHT`)
##     con 41,6 m di distanza di vista; un colpo a 200 m sarebbe **fuori dal
##     frustum** per la quasi totalita' del telegrrafo, che e' 0,8293 s = 49,8 passi
##     a 60 Hz: il giocatore vedrebbe un lampo e poi niente.
##   - **26 m**: `26 / 6,46 = 4,03` volte il corpo piu' alto e `26 / 5,21 = 4,99`
##     volte il raggio della cupola, quindi **fuori dalla folla e fuori dal proprio
##     avvertimento**; e `26 / 34 = 0,765` dell'altezza della camera, quindi
##     **dentro l'inquadratura** per tutta la caduta. La sua taglia (1,20 m di
##     diametro) e' 17,3 px alla distanza di vista tipica, quindi non e' la
##     dimensione il problema: e' l'altezza.
##
## Il numero e' **derivato** da quei tre (6,46 m, 5,21 m, 34 m) e dichiarato qui
## accanto al motivo; `tests/test_arena.gd` lo rilegge dalla costante e verifica che
## stia sopra `2 x corpo piu' alto` e sotto l'altezza della camera, quindi non puo'
## diventare un numero decorativo.
const START_HEIGHT := 26.0
##
## ## LA CADUTA: LINEARE, E PERCHE' L'ERRORE E' ZERO PER COSTRUZIONE
##
##     quota(t) = START_HEIGHT x (t / mortar_telegraph_s)
##
## Il canale porta **quanti secondi mancano** alla caduta, quindi `t = 0` e'
## **esattamente** l'istante in cui `-orda` fa esplodere il colpo
## (`horde.gd::_mortar_impact`). Una quota che e' funzione **pura** di `t` e' zero
## in quell'istante e non prima: non c'e' un orologio che possa andare storto, e non
## c'e' un secondo numero da accordare. Il tempo di caduta **disegnato** e'
## `START_HEIGHT / START_HEIGHT x mortar_telegraph_s = mortar_telegraph_s`, quindi
## lo scarto fra la cupola e l'impatto e' **0,000000000 s**, cioe' sotto il passo di
## simulazione per costruzione e non per taratura.
##
## **Lineare e non accelerato**: con la caduta lineare la velocita' e' costante
## (`26 / 0,8293 = 31,35 m/s`) e quindi **l'altezza del colpo e' l'orologio**: due
## colpi con la stessa quota cadono dalla stessa altezza e l'occhio impara a leggere
## il tempo che manca senza conoscere il numero. Una caduta che accelera passerebbe
## piu' tempo in aria buia (dentro la folla) e accelererebbe proprio nell'ultimo
## mezzo secondo, cioe' dove la lettura conta di piu'.
##
## Il tempo di caduta non e' scritto qui: `mortar_telegraph_s` arriva **dal
## contratto a ogni refresh** (`_contract_telegraph()`), come il raggio della cupola
## fa con `mortar_blast_m`. Un numero messo in un campo prenderebbe il valore giusto
## al primo frame e mentirebbe per tutta la partita se il contratto cambiasse.
##
## ## LA FORMA: un cono con la punta in basso, e perche' un cono
##
## `CylinderMesh` e' una primitiva del motore, non un asset: questa milestone non ne
## aggiunge uno e non tocca `assets/`. Il cono ha **16 triangoli** (8 di mantello + 8
## di fondo, il tetto del progetto e' 20-40 per *corpo* e questo non e' un corpo) e
## tre motivi, tutti di lettura a colpo d'occhio:
##   - la **punta in basso** dice in che direzione cade, senza dover seguire una
##     scia o un'ombra;
##   - a fine caduta la punta e' **esattamente** sull'impronta della cupola, quindi
##     quello che l'occhio vede e' quello che colpisce (la stessa regola che vale
##     per il raggio in `mortar_renderer.gd`);
##   - **non illuminata** (`SHADING_MODE_UNSHADED`) e ambra: la cupola rossa non deve
##     essere leggibile nella zona d'ombra del muro e il colpo no.
##
## ## UN SOLO NODO, COME LE CUPOLA E COME L'ORDA
##
## Un colpo in volo e' un dato, non un oggetto di scena: se ogni colpo fosse un
## `Node3D` il `node_count` salirebbe col fuoco dell'orda, che e' il tetto che questo
## progetto ha gia' violato una volta con i nemici. Qui il costo e' **un nodo** e un
## solo buffer: **47 nodi a vuoto e 47 con sette colpi in volo** (`tests/test_arena.gd`
## lo stampa misurato ogni esecuzione). Il tetto assoluto resta 120.

## Capienza fissa, come quella delle cupole e dei nemici: non cresce a runtime,
## altrimenti `instance_count` cambierebbe da solo nel frame in cui si combatte di
## piu'. Il numero che la **giustifica** e' di `-orda`: un nemico non puo' avere due
## colpi in volo (`ricarica > telegrrafo`, in `src/sim/horde.gd::_mortar_spara`) e i
## nemici sono `MAX_ENEMIES`. Se `-orda` alzasse il tetto oltre questa capienza,
## `tests/test_arena.gd` confronta i due numeri e va rossa invece di lasciare un
## colpo **sotto-disegnato e senza dirlo**.
const CAPACITY := 256

## Raggio e altezza della mesh **non modificata** (`_mesh()`): e' l'unita' in cui la
## trasformazione dell'istanza e' scritta, quindi i due numeri vivono qui e non dentro
## `_mesh()`. Vivono qui perche' `shell_transform()` deve poterli misurare: un numero
## che sta in una riga sola e in un'altra e' una copia che un giorno diverge.
const MESH_RADIUS := 1.2
const MESH_HEIGHT := 1.6

## Segmenti del mantello. Otto lati si leggono meglio di una sfera liscia: la
## silhouette e' quella che distingue il conio da una macchia, e otto lati bastano.
const MESH_SEGMENTS := 8

## L'amarra del colpo. Non e' il rosso della cupola (`src/sim/enemy.gd` dichiara il
## mortar ciano **apposta** perche' il rosso e' della cupola: «una specie colorata
## come il proprio avvertimento renderebbe il segnale illeggile»): qui il colore che
## resta libero e' l'ocra, che e' lontano sia dal rosso della cupola sia dal ciano
## del mortar che lo ha sparato.
const SHELL_COLOR := Color(0.98, 0.78, 0.12)

## Quanto il riquadro di disegno e' piu' largo del punto di caduta piu' esterno, in
## metri. Stessa regola di `mortar_renderer.gd`: il riquadro e' **derivato dai
## colpi** e prende il raggio in argomento, non va a cercarlo in un campo.
const AABB_MARGIN := 1.0

## Le trasformazioni **scritte nel buffer**, tenute per la verifica: il buffer della
## `MultiMesh` **non si rilegge in headless** (in Godot 4.7 le trasformazioni stanno
## in uno storage buffer del RenderingDevice che nel backend "dummy" di `--headless`
## non esiste, e `get_instance_transform` restituisce silenziosamente una
## trasformazione vuota). Quindi l'unico modo di controllare *che cosa* e' stato
## scritto e' ricordarlo qui: allocata una volta sola e non cresce mai.
var _written: Array[Transform3D] = []

## L'orda da cui leggere il canale. Se non e' impostata si prende `Game.horde`.
var _horde: Node = null
var _contract_cache: Node = null
var _built: bool = false

## I numeri dell'ultimo `refresh()`, per il test e per il debug.
var _last_drawn: int = 0
var _last_asked: int = 0
var _last_telegraph: float = -1.0

## Tre avvisi emessi **una volta sola**: un canale assente e' un difetto di `-orda`,
## non un rumore da ripetere ogni frame (cfr. `_warned_radii` in
## `horde_renderer.gd`).
var _warned_horde: bool = false
var _warned_surface: bool = false
var _warned_telegraph: bool = false

func _ready() -> void:
	_build()

func _process(_delta: float) -> void:
	refresh()

# --- Costruzione --------------------------------------------------------------

## Fatta una volta sola. Nessun nodo, nessuna instanziazione dopo questo punto.
## Qui dentro si impostano **anche** il formato e il materiale: nel ciclo di gioco,
## sotto, ci stanno solo scritture dentro il buffer gia' allocato.
func _build() -> void:
	if _built:
		return
	_built = true
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# Nessun colore per istanza: il colpo e' un colpo, e un canale in piu' da
	# riempire e' un canale in piu' che `-orda` dovrebbe conoscere.
	mm.use_colors = false
	mm.mesh = _mesh()
	mm.instance_count = 0
	multimesh = mm
	material_override = _material()
	# `_aabb` prende **solo** i punti: il secondo argomento che qui c'era era un
	# raggio, e il corpo di `_aabb` non lo leggeva (usa `AABB_MARGIN`). Il raggio
	# non serve perche' i punti che arrivano sono le **origini delle trasformazioni**
	# gia' scalate da `shell_transform()`, quindi la dimensione e' gia' dentro
	# `t.origin`: aggiungere un raggio non avrebbe allargato nulla.
	custom_aabb = _aabb([])

## La mesh del colpo: un cono di **raggio 1/2 e altezza 1**, cioe' la primitiva
## unitaria che `shell_transform()` scala su `MESH_RADIUS` e `MESH_HEIGHT`. Non e'
## un asset: `CylinderMesh` e' una primitiva del motore, e questa milestone non ne
## aggiunge uno (`assets/` non e' di -arena e questa onda non lo apre).
##
## I due numeri vivono in `_mesh()` e in `shell_transform()` perche' sono la stessa
## cosa detta due volte: qui la **forma** (unita'), li' la **misura** (metri). Se la
## primitiva crescesse senza che `shell_transform()` lo venisse a sapere, il colpo
## raddopperebbe e nessuna asserzione del mondo se ne accorgerebbe.
func _mesh() -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = 0.5
	m.height = 1.0
	m.radial_segments = MESH_SEGMENTS
	m.rings = 1
	# In alto il raggio e' zero: non c'e' niente da chiudere, e il coperchio sarebbe
	# un triangolo degenere per ogni lato. In basso c'e' il fondo piatto, che e'
	# quello che la camera vede guardando **dall'alto**.
	m.cap_top = false
	m.cap_bottom = true
	return m

func _material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = SHELL_COLOR
	# Non illuminata, come la cupola: l'avvertimento non deve dipendere da dove
	# cade l'ombra del muro.
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	m.metallic = 0.0
	return m

## La scatola che il motore usa per decidere se disegnare, **derivata dai punti dei
## colpi** e dalla quota di partenza. Prende i punti in argomento e non va a
## cercarli in un campo: con i punti in un campo, il riquadro dell'ultimo frame
## sarebbe quello del frame in cui il canale aveva un'altra forma.
func _aabb(points: Array) -> AABB:
	if points.is_empty():
		return AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0))
	var lo := Vector3(INF, -AABB_MARGIN, INF)
	var hi := Vector3(-INF, START_HEIGHT + MESH_HEIGHT + AABB_MARGIN, -INF)
	for p in points:
		var v: Vector3 = p
		lo = Vector3(minf(lo.x, v.x - AABB_MARGIN), lo.y, minf(lo.z, v.z - AABB_MARGIN))
		hi = Vector3(maxf(hi.x, v.x + AABB_MARGIN), hi.y, maxf(hi.z, v.z + AABB_MARGIN))
	return AABB(lo, hi - lo)

# --- Lettura del canale --------------------------------------------------------

## Da quale nodo prendere il canale. Di norma `Game.horde`; il test vi inietta un
## canale finto con la stessa forma. Non e' un `get_node("../..")`: e' un dato, non
## una dipendenza fra foglie.
func set_horde(horde: Node) -> void:
	_horde = horde

## Copia il canale nel buffer. Chiamata una volta per frame: il numero di scritture
## e' il numero di colpi in volo, che sono poche e non sono mai 200, e qui non c'e'
## `new()`, non c'e' `resize` e non c'e' un nodo.
func refresh() -> void:
	if not _built or multimesh == null:
		return
	var horde := _resolve_horde()
	if horde == null:
		if not _warned_horde:
			_warned_horde = true
			push_warning("mortar_shot_renderer: nessuna orda registrata (Game.horde), quindi nessun colpo da disegnare. Resta un nodo solo e nessun colpo: e' la piramide non montata, non un mondo senza avvertimenti.")
		_clear()
		return
	# Gli stessi tre nomi che `mortar_renderer.gd` legge, e per la stessa ragione:
	# i **metodi**, non l'array grezzo, perche' `mortar_shot_at(i)` restituisce il
	# punto **del mondo** con la convenzione `(x, z, secondi)` gia' disfatta.
	if not _surface_ok(horde):
		if not _warned_surface:
			_warned_surface = true
			push_warning("mortar_shot_renderer: l'orda non espone `mortar_shot_count`, `mortar_shot_at(i)` e `mortar_shot_left(i)`: senza il canale di m13 nessun colpo puo' essere disegnato, perche' il punto di caduta e' l'unica cosa che distingue «schiva qui» da una macchia a caso. La superficie e' congelata in src/core/contracts.gd e lo scrive -orda.")
		_clear()
		return
	# ## Il tempo di caduta viene riletto **a ogni refresh**, mai messo in un campo
	#
	# E' il numero che deve combaciare con quello che l'orda usa per far cadere il
	# colpo: leggerlo una volta sola prenderebbe il valore giusto al primo frame e
	# continuerebbe a mentire per tutta la partita. `tests/test_arena.gd` avvelena il
	# campo e verifica che il colpo lo riveda.
	var telegraph := _contract_telegraph()
	if not (telegraph > 0.0):
		if not _warned_telegraph:
			_warned_telegraph = true
			push_warning("mortar_shot_renderer: il contratto non dichiara `mortar_telegraph_s` (letto %.4f): senza il tempo di caduta il colpo cadrebbe ad un istante che nessuno misura, quindi e' meglio nessun colpo di un colpo che cade quando vuole." % telegraph)
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
	var punti: Array = []
	for i in wanted:
		var world: Vector3 = horde.mortar_shot_at(i)
		var left: float = float(horde.mortar_shot_left(i))
		var t := shell_transform(world, left, telegraph)
		multimesh.set_instance_transform(i, t)
		punti.append(t.origin)
		if i < _written.size():
			_written[i] = t
		else:
			_written.append(t)
	# La casella finale e' l'ultima: e' quella che dice al motore **quanti** colpi ci
	# sono, e senza questa riga le istanze sopravvissute dal frame prima resterebbero
	# visibili quando il canale si e' svuotato.
	multimesh.visible_instance_count = wanted
	custom_aabb = _aabb(punti)
	if wanted == 0:
		_written.clear()
	_last_drawn = wanted
	_last_asked = asked
	_last_telegraph = telegraph

## Nessun colpo a schermo. E' una funzione e non un valore: un colpo che resta dopo
## l'impatto e' un colpo che cade da solo nella cupola di un impatto che e' gia'
## avvenuto, ed e' il difetto piu' grave che qui si puo' fare.
func _clear() -> void:
	if multimesh == null:
		return
	multimesh.instance_count = 0
	multimesh.visible_instance_count = 0
	# Come in `_build()`: un solo argomento. Il riquadro di nessun colpo e' quello
	# di partenza, e `_aabb([])` lo dice senza misurare niente.
	custom_aabb = _aabb([])
	_written.clear()
	_last_drawn = 0
	_last_asked = 0

## La superficie di m13 c'e' tutta? Un canale a meta' e' un canale che non esiste:
## senza `mortar_shot_left` il colpo non saprebbe a che quota mettersi.
func _surface_ok(horde) -> bool:
	return horde.has_method("mortar_shot_at") and horde.has_method("mortar_shot_left") \
		and typeof(horde.get("mortar_shot_count")) == TYPE_INT

## ## IL TEMPO DI CADUTA, LETTO E NON RICOPIATO
##
## Passa per `get()` e non per `Game.mortar_telegraph_s` per la stessa ragione che
## vale in `mortar_renderer.gd` con `mortar_blast_m`: il campo e' scritto da `-orda` e
## questa onda lavora **in parallelo** a lui. Con l'accesso diretto un campo non
## ancora arrivato interromperebbe il ciclo di gioco con un errore a runtime nel
## mezzo della partita; con `get()` arriva `-1.0` e la guardia di `refresh()` lo
## dichiara una volta sola, con il nome del campo.
func _contract_telegraph() -> float:
	var game := _contract()
	if game == null:
		return -1.0
	var value = game.get("mortar_telegraph_s")
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

## ## LA TRASFORMAZIONE DI UN COLPO: pubblica e pura
##
## E' l'unico posto dove il tempo di caduta del contratto diventa geometria, e il
## ciclo di `refresh()` passa di qui per ogni colpo: quindi e' anche la funzione che
## il test verifica, e non una ricostruzione parallela di quello che il renderer
## dovrebbe fare.
##
## `world` e' il punto **del mondo** come lo restituisce `horde.mortar_shot_at(i)`,
## cioe' con `y` gia' a zero e gia' nel suo ordine vero. `remaining` sono i secondi
## che mancano alla caduta; `telegraph` e' `Game.mortar_telegraph_s`, rilesso ora.
##
## L'origine e' il **centro** del cono e la punta sta a `height` metri dal terreno:
## la punta e' la parte che tocca, quindi e' la quota che deve arrivare a zero
## nello stesso istante in cui i secondi residui arrivano a zero. Il centro e' mezza
## altezza piu' in su, e `tip_height()` sottrae esattamente quella meta'.
func shell_transform(world: Vector3, remaining: float, telegraph: float) -> Transform3D:
	var punta := _height_of(remaining, telegraph)
	# La `Basis` ruota di 180 gradi attorno a X: il cono della primitiva ha la punta
	# in alto, e un colpo che cade con la punta in alto e' un colpo che sale.
	var b := Basis(Vector3.RIGHT, PI).scaled(Vector3(MESH_RADIUS, MESH_HEIGHT, MESH_RADIUS))
	return Transform3D(b, Vector3(world.x, punta + 0.5 * MESH_HEIGHT, world.z))

## La quota della **punta** sopra il terreno, in metri: funzione **pura** del solo
## canale e del contratto, quindi due istanti con lo stesso `remaining` danno lo
## stesso colpo e `remaining == 0` dà esattamente terra. Nessun orologio: un
## orologio qui sarebbe il secondo numero da accordare con quello di `-orda`, che e'
## il difetto che la sezione chiude.
func _height_of(remaining: float, telegraph: float) -> float:
	if remaining <= 0.0 or telegraph <= 0.0:
		return 0.0
	return START_HEIGHT * clampf(remaining / telegraph, 0.0, 1.0)

# --- Lettura (per il test e per il debug) -------------------------------------

## La trasformazione del colpo `i` **cosi' com'e' stata scritta nel buffer**.
func written_transform(i: int) -> Transform3D:
	if i < 0 or i >= _written.size():
		return Transform3D.IDENTITY
	return _written[i]

## La quota **disegnata** della punta sopra il terreno, in metri. E' il numero che
## l'occhio segue e che deve arrivare a zero nello stesso istante dell'impatto: il
## confronto con `mortar_shot_left` e' il criterio, il valore restituito e' quello
## che e' stato scritto.
func tip_height(i: int) -> float:
	var t := written_transform(i)
	return t.origin.y - 0.5 * absf(t.basis.get_scale().y)

## La quota di partenza dichiarata, perche' il test debba rileggerla dalla fonte e
## non da una copia scritta li'.
func start_height() -> float:
	return START_HEIGHT

## Quanti colpi sono stati messi sul serio nel buffer all'ultimo `refresh()`.
func drawn_count() -> int:
	return _last_drawn

## Quanti il canale ne chiedeva all'ultimo `refresh()`. E' la **precondizione** e
## non il risultato: senza questa una prova passerebbe anche con un canale finto che
## non chiede niente.
func requested_count() -> int:
	return _last_asked

## Quanti ne sono stati **accorciati** dalla guardia di capienza.
func clamped_count() -> int:
	return maxi(0, _last_asked - _last_drawn)

## Il tempo di caduta **letto dal contratto** all'ultimo `refresh()`, o `-1.0` se non
## e' arrivato. Serve perche' `tests/test_arena.gd` debba poter dire *quale* valore ha
## prodotto la caduta **misurandolo**, invece di rileggerlo dalla costante che lo
## produce.
func telegraph_used() -> float:
	return _last_telegraph

## Il renderer e' stato costruito? Serve al test per dire «il difetto e' che non
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
