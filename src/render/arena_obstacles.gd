extends MultiMeshInstance3D
## Gli ostacoli dell'arena: **dischi sul piano XZ**, disegnati da **un solo nodo**.
##
## Un disco per ostacolo, il raggio in metri, e la geometria che ne nasce e' un
## **cilindro basso**: la forma e' mia (criterio n. 1 di m10 mi dà forma e colore),
## i numeri sono di `-orda`. Qui dentro non c'e' nessun numero di geometria scritto
## per conto mio: l'unica cosa che leggo e' `Game.obstacles`, la superficie
## congelata in `src/core/contracts.gd`.
##
## ## Perche' UN nodo e non uno per ostacolo
##
## E' la stessa regola che ha fatto passare m8 con i 200 nemici, e vale con la
## stessa forza perche' il tetto e' lo stesso: `node_count < 120`. Un disco sono
## un'istanza di una `MultiMesh`, quindi il numero di nodi **non dipende dal numero
## di ostacoli**. Il costo e' un solo nodo e un solo buffer, scritto **una volta
## sola** all'avvio: gli ostacoli sono statici (punto 1 della semantica congelata),
## quindi nel ciclo di gioco qui non gira niente.
##
## ## Perche' un cilindro e non una forma qualsiasi
##
## Il vertice ha deciso il disco perche' la geometria che il campo di percorrenza
## deve risolvere e' un **test di distanza**. Disegnarlo con un cilindro mantiene
## quella promessa anche a occhio: cio' che si vede ha lo stesso ingombro del disco
## che blocca, e puo' essere **verificato** (vedi `written_transform()`), che e' la
## meta' di -arena del criterio n. 6: «il giocatore e' solido e i proiettili
## passano» vale solo se l'ostacolo che blocca e' **quello che si vede**.
##
## Il raggio in `y` e' la convenzione del contratto: `Vector3(cx, RAGGIO, cz)`.
## `y` **non** e' un'altezza e `z` **non** e' una profondita'. La sola cosa che
## questo file deve sbagliare e' non sbagliare questa riga.

## ## LA FORMA: tre numeri, e sono scelti qui apposta
##
##   - `OBSTACLE_HEIGHT`: quanto sono alti. **2,4 m** e' un'altezza **magggiore
##     della sagoma del nemico piu' comune** (il piu' piccolo disegna 1,53 m, vedi
##     `SIZE_FACTOR` in `horde_renderer.gd`) e **minore del boss** (6,46 m): con
##     questa altezza un disco non si confonde con un nemico in nessuna delle
##     quattro specie, e non nasconde l'orizzonte.
##   - `RADIAL_SEGMENTS`: **12**. Dodici lati danno ~34 triangoli per ostacolo: la
##     fascia «low-poly» del progetto (20-40 triangoli) e non un tubo liscio che
##     costerebbe quattro volte tanto per una differenza che a questa distanza di
##     camera non si vede.
##   - `OBSTACLE_COLOR`: un grigio caldo **chiaro e poco saturo**. Chiaro perche'
##     stia sopra il pavimento in ogni punto della scena, poco saturo perche' non
##     si confonda con la tinta di una specie nemica: con duecento nemici in
##     campo la lettura deve essere «massa» e non «dettaglio».
const OBSTACLE_HEIGHT := 2.4
## ## m12: IL PIANO DI UN DISCO E' LA **POSIZIONE NELL'ARRAY**, e non `floor_of()`
##
## `y` e' il **raggio** (2,275 m al raggio di oggi) e non la quota, quindi
## `floor_of(element.y)` vale `0` per **tutti** i dischi di **tutti** i piani: una
## torre che mettesse i quattro piani alla stessa quota avrebbe i muri dei piani
## 1, 2 e 3 **appesi a mezz'aria**, e il campo di percorrenza di ogni piano
## avrebbe ostacoli che il giocatore incontra venti metri piu' in la'.
##
## Il taglio e' per **indice**, ed e' lo stesso per tre foglie:
## `OBST.per_floor(n, floors)` di `-orda` — che e' anche la funzione che
## `slice_floor()` usa per tagliare l'array — e `size() / floor_count` di
## `-gameplay`. Qui sotto si chiama **quella**, e non se ne scrive una quarta.
##
## Il **perche'** conta: due foglie che tagliano lo stesso array in punti diversi si
## evitano ostacoli del piano sbagliato. E' la classe di difetto delle copie, e la
## difesa qui e' **una funzione sola**, non quattro righe che concordano finche'
## nessuno le tocca.
const OBST := preload("res://src/sim/obstacles.gd")
const RADIAL_SEGMENTS := 12
const OBSTACLE_COLOR := Color(0.88, 0.84, 0.76)

## Quanto il fondo del cilindro affonda sotto il pavimento, in metri. Il disco e'
## solido per chi cammina e va appoggiato al terreno: se il fondo restasse a zero
## il piano e il pavimento si toccerebbero su una faccia intera e si vedrebbe il
## difetto di z-fighting dal basso della camera. Il fondo affondato e' invisibile e
## il bordo resta **esattamente** sul raggio che blocca.
const OBSTACLE_SINK := 0.25
## ## `0,25` NON E' IL RAGGIO DEL DISCO NE' MEZZA `TILE`, ED E' MISURATO
##
## Misurato il 2026-10-17 sulla torre: `tests/test_arena.gd::_torre_ostacoli` ha
## misurato uno scarto **costante di `0,2500 m` su tutti e 76 i dischi**, e la
## costante e' questa. Il criterio confrontava per errore `fondo == suolo`, cioe'
## pretendeva che il disco appoggiasse **a quota** invece che affondato sotto: la riga
## era sbagliata, non il posizionamento. Uno scarto **costante su tutti i dischi**
## non e' un errore di piano — quello sarebbe di `20`, `40` o `60` metri — ma una
## cosa unica: e' il modo in cui il numero si fa riconoscere.
##
## Perche' la riga non si e' limitata ad **allargare la tolleranza**: un quarto di
## metro di banda avrebbe lasciato passare un disco affondato di due metri, cioe' un
## disco che sporge sotto un altro pavimento. Il criterio **rilegge questo numero** dalla
## mappa delle costanti di questo file e confronta contro di lui, quindi se il produttore
## cambiasse l'affondamento il criterio inseguirebbe il numero nuovo e continuerebbe a
## distinguere «affondato di quanto dichiarato» da «appoggiato al piano sbagliato» —
## che e' il difetto che la sezione cerca.

## Le trasformazioni **scritte nel buffer**, tenute per la verifica.
##
## Non e' una copia della geometria di gioco: e' la traccia di quello che questo
## renderer ha messo sul serio nel `MultiMesh`, e serve perche' il buffer **non si
## rilegge in headless** (in Godot 4.7 le trasformazioni stanno in uno storage
## buffer del RenderingDevice che nel backend "dummy" di `--headless` non esiste,
## e `get_instance_transform` restituisce silenziosamente una trasformazione
## vuota). Quindi l'unico modo di controllare davvero *che cosa* e' stato scritto e'
## ricordarlo qui, che e' allocato una volta sola all'avvio e non cresce mai.
var _written: Array[Transform3D] = []
var _built: bool = false
var _contract_cache: Node = null

func _ready() -> void:
	_build()

# --- Costruzione --------------------------------------------------------------

## Fatta una volta sola. Nessun nodo, nessuna istanziazione dopo questo punto.
func _build() -> void:
	if _built:
		return
	_built = true
	build(obstacles())

## Costruisce il buffer da una lista di dischi `Vector3(cx, RAGGIO, cz)`.
##
## Pubblica e **separata da `_ready()`** perche' il test ci arrivi con un proprio
## input e misuri quello che esce: e' la stessa forma di `set_horde()` in
## `horde_renderer.gd`, e serve allo stesso scopo — non ricostruire in parallelo
## quello che il renderer dovrebbe fare, ma chiamarlo.
##
## La lista e' un ingresso, **non** la geometria dell'arena: il test ci mette
## dentro casi che deve poter inventare (raggio nullo, disco fuori campo), e la
## geometria vera arriva da `Game.obstacles`.
func build(list: PackedVector3Array) -> void:
	_written.clear()
	var n := list.size()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# Nessun colore per istanza: la tinta e' una scelta di -arena e vale per
	# tutti i dischi, quindi non ha bisogno di un quarto canale.
	mm.use_colors = false
	mm.mesh = _mesh()
	mm.instance_count = n
	multimesh = mm
	material_override = _material()
	# `custom_aabb` e' derivato dai dischi e non scritto a mano: un riquadro
	# sbagliato qui taglia gli ostacoli senza dire niente (la stessa lezione
	# scritta accanto a `_fit_aabbs()` in `arena_ground.gd`).
	custom_aabb = _aabb(list)
	for i in n:
		var t := obstacle_transform(list[i])
		mm.set_instance_transform(i, t)
		_written.append(t)
	mm.visible_instance_count = n

## La mesh del disco: un cilindro di un metro di raggio e di un metro di altezza,
## che `obstacle_transform()` scala al raggio vero dell'ostacolo.
##
## `CylinderMesh` e' una primitiva del motore, non un asset: questa milestone non
## ne aggiunge uno e non tocca `assets/`, che non e' di -arena. Il fondo e'
## chiuso e il coperchio no: il fondo affonda sotto il pavimento e il coperchio si
## vede, perche' e' la parte alta del disco che dice «qui non si passa» anche dal
## bordo della camera.
func _mesh() -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 1.0
	m.bottom_radius = 1.0
	m.height = 1.0
	m.rings = 1
	m.radial_segments = RADIAL_SEGMENTS
	m.cap_top = true
	m.cap_bottom = false
	return m

func _material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = OBSTACLE_COLOR
	m.roughness = 0.95
	m.metallic = 0.0
	return m

## La scatola che il motore usa per decidere se disegnare, **derivata dai dischi**
## e dalla torre.
##
## Il riquadro di prima era alto `OBSTACLE_HEIGHT` e partiva da `y = 0`: su una
## torre di 80 m avrebbe cullato **tutti** i dischi dei piani 1, 2 e 3, e in
## headless nessuna asserzione lo avrebbe visto, perche' un `MultiMesh` cullata
## continua a riportare il numero di istanze che le e' stato scritto. Quindi
## l'estensione verticale arriva fino a `floor_count * floor_height` — la stessa
## regola di `_fit_aabbs()` in `arena_ground.gd`.
func _aabb(list: PackedVector3Array) -> AABB:
	if list.is_empty():
		return AABB(Vector3(-1.0, 0.0, -1.0), Vector3(2.0, OBSTACLE_HEIGHT, 2.0))
	var lo := Vector3(INF, INF, 0.0)
	var hi := Vector3(-INF, -INF, 0.0)
	for i in list.size():
		var e := list[i]
		var r: float = maxf(e.y, 0.0)
		lo = Vector3(minf(lo.x, e.x - r), minf(lo.y, -OBSTACLE_SINK), minf(lo.z, e.z - r))
		hi = Vector3(maxf(hi.x, e.x + r), maxf(hi.y, OBSTACLE_HEIGHT), maxf(hi.z, e.z + r))
	return AABB(lo - Vector3(1.0, 0.0, 1.0), hi - lo + Vector3(2.0, 0.0, 2.0))

## ## LA TRASFORMAZIONE DI UN OSTACOLO: pubblica e pura
##
## E' l'unico posto dove la convenzione del contratto viene tradotta in
## geometria, e il ciclo di costruzione passa di qui per ogni disco: quindi e'
## anche la funzione che il test verifica, non una ricostruzione parallela.
##
## `entry` e' `Vector3(centro_x, RAGGIO, centro_z)` con il **raggio in `y`**.
## L'impronta del cilindro che ne esce ha semipiano esattamente `entry.y`: il
## disco che blocca e' quello che si vede, ed e' la meta' di -arena del criterio
## n. 6 («il giocatore e' solido e i proiettili passano» vale solo se l'ostacolo
## disegnato e' quello che blocca). Un raggio nullo qui produce una istanza
## schiacciata e **non viene tollerato**: e' un invariante del contratto (punto 3)
## e il chiamante lo rifiuta prima di arrivare.
##
## ## `base`: LA QUOTA DEL PIANO, E PERCHE' E' UN PARAMETRO
##
## Il secondo parametro e' **la quota del piano su cui il disco sta**, e non
## l'indice del piano, perche' il chiamante la calcola col produttore unico
## (`OBST.per_floor`) e la formula del pavimento resta **qui dentro, in un posto**.
## Il default `0.0` e' il mondo di prima di m12: chiamata con un solo argomento la
## funzione si comporta **esattamente** come si comportava, e il test che la chiama
## con un disco finto continua a misurare la stessa cosa.
##
## Perche' `base` e non `piano * FLOOR_HEIGHT`: perche' `FLOOR_HEIGHT` non e' scritto
## qui dentro. E' un numero del contratto, e questo file non lo possiede.
func obstacle_transform(entry: Vector3, base: float = 0.0) -> Transform3D:
	var r: float = maxf(entry.y, 0.0)
	var h := OBSTACLE_HEIGHT + OBSTACLE_SINK
	return Transform3D(Basis.IDENTITY.scaled(Vector3(r, h, r)),
		Vector3(entry.x, base + h * 0.5 - OBSTACLE_SINK, entry.z))

# --- Lettura (per il test e per il debug) -------------------------------------

## La trasformazione dell'ostacolo `i` **cosi' com'e' stata scritta nel buffer**.
func written_transform(i: int) -> Transform3D:
	if i < 0 or i >= _written.size():
		return Transform3D.IDENTITY
	return _written[i]

## Il semipiano dell'impronta **disegnata**, in metri: e' quello che l'occhio
## vede, e va confrontato con il raggio che blocca.
func drawn_radius(i: int) -> float:
	var t := written_transform(i)
	return maxf(t.basis.get_scale().x, 0.0)

## Quanti ostacoli sono stati messi sul serio nel buffer.
func drawn_count() -> int:
	return _written.size()


## I dischi che questo nodo deve disegnare: dal contratto, e **non** dalla scena.
##
## Passa per `get()` e non per `Game.obstacles` per la stessa ragione che vale in
## `horde_renderer.gd` con `radii`: `obstacles` e' un campo scritto nel contratto
## che questa onda lavora **in parallelo** a, e con l'accesso diretto un campo non
## ancora arrivato interromperebbe l'avvio della scena. Qui un campo assente non
## e' un errore e non lascia buchi: e' un array vuoto, e il chiamante lo dichiara.
func obstacles() -> PackedVector3Array:
	var game := _contract()
	if game == null:
		return PackedVector3Array()
	var value = game.get("obstacles")
	if value is PackedVector3Array:
		return value
	return PackedVector3Array()

# --- Interno ------------------------------------------------------------------

## Vedi la nota in `horde_renderer.gd`: l'autoload lo prendo dal campo `/root`,
## perche' questi script possono essere caricati con `load()` anche dai test in
## `--script`, dove l'identificatore nudo non e' garantito (piano 5.3).
func _contract() -> Node:
	if _contract_cache != null and is_instance_valid(_contract_cache):
		return _contract_cache
	# ## `get_tree()` QUI E' UN **ERRORE**, NON UN `null`
	#
	# `tests/test_arena.gd::_forma_del_disegno()` costruisce un
	# `MultiMeshInstance3D` con `set_script()` e non lo mette nell'albero, per non
	# sporcare la scena. Su un nodo **fuori dall'albero** `get_tree()` non restituisce
	# `null`: chiama `get_data()` su un `SceneTree` che non c'e' e il motore stampa
	# `ERROR: Parameter "data.tree" is null` **dodici volte** in una sola sezione.
	#
	# Il sintomo peggiore e' che l'errore **non interrompe**: `get_tree()` restituisce
	# comunque `null`, quindi il fallback scattava e il numero tornava lo stesso che
	# con la strada buona. Quindi la riga si poteva anche non aggiungere e nessuna
	# porta sarebbe caduta — e il log si riempiva di rumore che nessuno poteva
	# attribuire, perche' la sezione che lo produceva era **verde**.
	#
	# `Engine.get_main_loop()` funziona anche fuori dall'albero, e su un nodo
	# nell'albero restituisce esattamente lo stesso `SceneTree`. Vedi la stessa scelta
	# in `arena_ramp.gd::ramp_angle()`, che per lo stesso motivo non puo' usare
	# `Game` come identificatore.
	var loop := Engine.get_main_loop() as SceneTree
	if loop != null and loop.root != null:
		_contract_cache = loop.root.get_node_or_null("Game")
	return _contract_cache