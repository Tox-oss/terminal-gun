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
## ## LA TRAIETTORIA: PARTE DAL MORTAR, ARRIVA ALLA CUPOLA, E ATTERRA PUNTUALE
##
## La richiesta dell'utente (2026-10-15) e' una riga: «il colpo parte dal mortar e
## arriva alla cupola, lungo una parabola, e atterra esattamente quando
## `mortar_telegraph_s` finisce». Tre cose, e sono tre cose diverse:
##
##   - **da dove**: dal **mortar**, cioe' dal nemico che ha sparato. Non da un punto
##     inventato: e' l'unica cosa che rende la curva leggibile, perche' l'occhio
##     segue il colpo e arriva alla cupola sapendo *chi* ha tirato. `-orda` ha
##     portato la fermata del mortar a `3 x mortar_blast_m` = **15,63 m**, quindi la
##     distanza che il colpo attraversa **si vede**.
##   - **che forma**: una **parabola**. Non un dettaglio estetico: e' il nome
##     dell'arma. Un proiettile che sale e poi scende e' esattamente quello che fa
##     un mortaio, quindi qui la traiettoria non e' un effetto: e' l enemy's name.
##   - **quando**: al tempo che dice il contratto, non al tempo che dice qui.
##
## ### LA PARABOLA: TRE PUNTI NOTI, E LO SCARTO ZERO PER COSTRUZIONE
##
## Con `s` = frazione **volata** (`0` al lancio, `1` all'impatto, e
## `s = 1 - remaining / mortar_telegraph_s`), l'arco e' la curva che passa per
## `(0, LAUNCH_HEIGHT)`, `(1/2, APEX_HEIGHT)` e `(1, 0)`:
##
##     quota(s) = (1 - s) x ( LAUNCH_HEIGHT x (1 - 2 s) + 4 x APEX_HEIGHT x s )
##
## I tre coefficienti non sono tarati: sono **la soluzione** di quei tre punti, e per
## costruzione `quota(1) = 0` esattamente, cioe' l'istante in cui `-orda` fa
## esplodere il colpo (`horde.gd::_mortar_impact`). Il tempo di caduta **disegnato**
## e' `mortar_telegraph_s` letto **dal contratto a ogni refresh**
## (`_contract_telegraph()`), quindi lo scarto fra la cupola e l'impatto e' **0 s**:
## non c'e' un orologio che possa andare storto e non c'e' un secondo numero da
## accordare. Un numero messo in un campo prenderebbe il valore giusto al primo frame
## e mentirebbe per tutta la partita se il contratto cambiasse.
##
## Il canale porta **quanti secondi mancano** alla caduta, quindi `remaining = 0`
## e' l'impatto e `remaining = mortar_telegraph_s` e' il lancio: sono gli stessi due
## estremi di prima, e la lettura e' la stessa di sempre.
##
## ### I TRE PARAMETRI, E DA CHE NUMERI SONO USCITI
##
## **1. L'altezza di lancio dal suolo: `LAUNCH_HEIGHT = 9,52 m`.** E' il **doppio
## del corpo del mortar che spara**: `SIZE_FACTOR x RADIUS[MORTAR]` =
## `3,4 x 1,40` = **4,76 m** (`RADIUS` e' di `-orda`, `SIZE_FACTOR` e' di m11 e la
## moltiplicazione e' quella che m8 ha chiuso). Il vincolo che decide e' un altro e
## e' dichiarato: nei **primi passi** il colpo e' vicino al mortar e i corpi sono
## alti fino a `SIZE_FACTOR x RADIUS[BOSS]` = `3,4 x 1,90` = **6,46 m**, quindi un
## lancio piu' basso di 6,46 m metterebbe il colpo **dentro la folla** per qualche
## passo proprio quando l'occhio lo sta cercando. `9,52 / 6,46 = 1,47` volte il corpo
## piu' alto, e `9,52 / 4,76 = 2,00` volte il corpo che spara: la bocca del tubo e'
## sopra la testa del tubo e sopra la testa di chiunque altro. `tests/test_arena.gd`
## rilegge la costante e verifica la disuguaglianza, quindi non puo' diventare un
## numero decorativo.
##
## **2. L'altezza dell'apice: `APEX_HEIGHT = 28,0 m`.** Il tetto e' quello della
## camera, e la camera e' dichiarata in `src/render/arena_camera.gd`: guarda da
## `anchor + (0, 34, 24)`, quindi **oltre 34 m il colpo esce dall'inquadratura** nel
## momento in cui il giocatore ha piu' bisogno di vederlo. Il numero e' la camera
## meno il suo margine dichiarato, `HEIGHT - EDGE_MARGIN` = `34 - 6` = **28,0 m**:
## l'apice sta 6 m sotto l'obiettivo, cioe' dentro il quadro con un margine che non
## e' un filo. `28 / 6,46 = 4,33` volte il corpo piu' alto (l'apice e' lontano dalla
## folla) e `28 / 15,63 = 1,79` volte la distanza percorsa in orizzontale (l'arco e'
## piu' alto che largo, ed e' quello che da dalla **camera in alto** si vede come
## una curva e non come una riga).
##
## **3. Da che lato si vede partire: dal mortar.** Il punto di lancio **non** e' un
## numero qui dentro: e' la posizione del **mortar piu' vicino a quella cupola**,
## letta dall'orda con i due canali che l'orda espone gia' e che questo file non
## allarga (`kinds`, `transforms`) — `_mortar_piu_vicino()`. Il caso in cui il punto
## di lancio **non** e' il mortar e' uno solo ed e' dichiarato: se l'orda non espone
## quelle due tabelle, o non ha nessun mortar vivo, il lancio cade **sulla cupola
## stessa** e il colpo sale diritto e la riattraversa. Meglio un tiro che non sa da
## dove arriva di un tiro che parte da un punto inventato: il difetto che questa
## sezione chiude non si ri-apre dalla parte opposta.
##
## I tre parametri sono **quelli descritti sopra** e sono i tre numeri che questa
## sezione dichiara: `LAUNCH_HEIGHT` (doppio del corpo del mortar, `9,52 m`),
## `APEX_HEIGHT` (la camera meno il suo margine, `34 - 6 = 28,0 m`) e il **mortar
## piu' vicino alla cupola**, che non e' un numero ma' una lettura dell'orda.
const LAUNCH_HEIGHT := 9.52
const APEX_HEIGHT := 28.0

## L'indice di specie del mortar in `horde.kinds`. E' una **copia dichiarata** di
## `MORTAR` in `src/sim/enemy.gd`, come `KIND_SLOT` in `horde_renderer.gd` lo e' di
## tutta la tabella delle specie: nessuno dei due file scrive il numero «4» per
## conto proprio in un posto diverso, e `tests/test_arena.gd` confronta questa copia
## con la fonte voce per voce, quindi una sesta specie o un riordino la farebbe
## diventare rossa invece di far cercare il lancio sulla voce sbagliata.
const MORTAR_KIND := 4
##
## Il canale e' **lo stesso** di quello delle cupole, scritto da `-orda` e letto con
## i suoi metodi: `horde.mortar_shot_count`, `horde.mortar_shot_at(i)`,
## `horde.mortar_shot_left(i)`. Nessun campo nuovo, nessuna superficie nuova.
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
## Quanti colpi dell'ultimo `refresh()` sono partiti **dalla cupola** invece che da un
## mortar, cioe' quante volte e' scattato il ramo di riserva di
## `_mortar_piu_vicino()`. Non serve a disegnare: serve a dire **quale ramo e' stato
## preso**, e senza questo numero un criterio che gira su un canale finto senza
## mortar passerebbe misurando il fallback senza dirlo — che e' la classe di difetto
## che questo file chiude in ogni sezione.
var _last_fallback: int = 0
## L'esito dell'ultima `_mortar_piu_vicino()`. Un campo e non un valore di ritorno
## doppio: il ciclo di `refresh()` gira una volta per frame e non puo' allocare.
var _lancio_era_una_cupola: bool = false

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
	var hi := Vector3(-INF, APEX_HEIGHT + MESH_HEIGHT + AABB_MARGIN, -INF)
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
	var ramo_cupola := 0
	for i in wanted:
		var world: Vector3 = horde.mortar_shot_at(i)
		var left: float = float(horde.mortar_shot_left(i))
		# Il punto di lancio e' una **lettura dell'orda**, non un numero di questo
		# file: il mortar piu' vicino a quella cupola. Nessuna allocazione e nessuna
		# tabella intermedia: un colpo in volo sono poche decine al massimo e
		# l'orda e' al massimo `MAX_ENEMIES`, quindi il ciclo e' `colpi x nemici`.
		var lancia := _mortar_piu_vicino(horde, world)
		if _lancio_era_una_cupola:
			ramo_cupola += 1
		var t := shell_transform(world, left, telegraph, lancia)
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
	_last_fallback = ramo_cupola

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
	_last_fallback = 0

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
## cioe' con `y` gia' a zero e gia' nel suo ordine vero: e' la **cupola**, cioe' il
## punto d'impatto. `remaining` sono i secondi che mancano alla caduta, `telegraph` e'
## `Game.mortar_telegraph_s` rilesso adesso, e `launch` e' il **mortar** da cui il
## colpo parte (quello piu' vicino a questa cupola).
##
## Il piano e' `lerp(mortar, cupola, s)`: **`s = 0` e' il lancio e `s = 1` e' l'impatto**,
## quindi l'ordine degli argomenti e' il verso del tiro. Scritto al contrario (`lerp` da
## `world`) il colpo **partiva dalla cupola e atterrava sul mortar**: la cupola e la
## quota erano giuste, la curva girata, e la sola riga che se ne accorgeva era il
## confronto del punto di lancio col mortar. Perche' non torni e' `tests/test_arena.gd`,
## che asserisce **entrambi** gli estremi nella stessa tolleranza.
##
## L'origine e' il **centro** del cono e la punta sta a `quota` metri dal terreno: la
## punta e' la parte che tocca, quindi e' la quota che deve arrivare a zero nello
## stesso istante in cui i secondi residui arrivano a zero. Il centro e' mezza
## altezza piu' in su, e `tip_height()` sottrae esattamente quella meta'.
##
## La `Basis` ruota di 180 gradi attorno a X e **non** ruota con la tangente
## dell'arco: la punta deve restare **sotto** il centro perche' e' la quota del
## `tip_height()` a definire l'impatto, e un cono inclinato farebbe dipendere quella
## quota dalla funzione che calcola la punta invece che dall'altezza scritta.
func shell_transform(world: Vector3, remaining: float, telegraph: float, launch: Vector3) -> Transform3D:
	var s := 1.0 if telegraph <= 0.0 else clampf(1.0 - remaining / telegraph, 0.0, 1.0)
	var punta := arc_height(s)
	var b := Basis(Vector3.RIGHT, PI).scaled(Vector3(MESH_RADIUS, MESH_HEIGHT, MESH_RADIUS))
	var piano := Vector3(launch.x, 0.0, launch.z).lerp(Vector3(world.x, 0.0, world.z), s)
	return Transform3D(b, Vector3(piano.x, punta + 0.5 * MESH_HEIGHT, piano.z))

## La quota della **punta** sopra il terreno, in metri, alla frazione volata `s`:
## funzione **pura** dei tre punti noti dell'arco, quindi due istanti con lo stesso
## `s` danno lo stesso colpo e `s == 1` da' esattamente terra. Nessun orologio: un
## orologio qui sarebbe il secondo numero da accordare con quello di `-orda`, che e'
## il difetto che la sezione chiude.
##
##     quota(s) = (1 - s) x ( LAUNCH_HEIGHT x (1 - 2 s) + 4 x APEX_HEIGHT x s )
##
## I tre coefficienti sono la soluzione di `quota(0) = LAUNCH_HEIGHT`,
## `quota(1/2) = APEX_HEIGHT`, `quota(1) = 0`: non sono tarati e non si possono
## spostare senza rompere uno dei tre punti.
func arc_height(s: float) -> float:
	var u := clampf(s, 0.0, 1.0)
	return (1.0 - u) * (LAUNCH_HEIGHT * (1.0 - 2.0 * u) + 4.0 * APEX_HEIGHT * u)

## ## IL PUNTO DI LANCIO: il mortar piu' vicino alla cupola, letto dall'orda
##
## Due tabelle che l'orda **gia' espone** (`kinds`, `transforms`) e che questo file
## non allarga: nessun canale nuovo per `-orda`, nessuna superficie nuova. La scelta
## e' il **piu' vicino** e non «quello che ha sparito»: l'orda non dice quale dei suoi
## mortar ha sparato il colpo `i`, e fra due candidate la verita' geometrica e' che il
## colpo e' partito dal piu' vicino — il mortar e' **fermo** (`fermo` in
## `src/sim/enemy.gd`), quindi la risposta non cambia mentre il colpo e' in volo e il
## punto di lancio non sbandiera.
##
## Se l'orda non espone le due tabelle, o non ha un solo mortar vivo, la risposta e'
## la **cupola stessa**: il colpo sale diritto e la riattraversa. E' il caso
## dichiarato sopra, e non e' un fallback silenzioso: il test lo copre.
func _mortar_piu_vicino(horde, bersaglio: Vector3) -> Vector3:
	var kinds = horde.get("kinds")
	var tras = horde.get("transforms")
	if not (kinds is PackedInt32Array) or not (tras is PackedVector3Array):
		_lancio_era_una_cupola = true
		return bersaglio
	var meglio := bersaglio
	var distanza := INF
	var n: int = mini(kinds.size(), tras.size())
	for i in n:
		if int(kinds[i]) != MORTAR_KIND:
			continue
		var p: Vector3 = tras[i]
		var d := Vector2(p.x - bersaglio.x, p.z - bersaglio.z).length_squared()
		if d < distanza:
			distanza = d
			meglio = p
	_lancio_era_una_cupola = distanza == INF
	return meglio

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
## non da una copia scritta li'. Sono due numeri adesso (lancio e apice) e sono le
## due estremita' dell'arco: il test li rilegge entrambi dalla fonte.
func launch_height() -> float:
	return LAUNCH_HEIGHT

## L'altezza dell'apice dichiarata, per lo stesso motivo di `launch_height()`: e' il
## numero che il tetto della camera (34 m) tiene sotto di se'.
func apex_height() -> float:
	return APEX_HEIGHT

## Il **mortar** da cui parte il colpo `i`, cioe' il punto di lancio cosi' come e'
## stato scritto nel buffer, con `y` portato a zero perche' e' un punto del terreno
## e non una quota. E' il numero che il confronto con la posizione del mortar
## dell'orda misura: il criterio dice che il colpo parte da li', non da un punto
## che il test si e' scelto.
func launch_point(i: int) -> Vector3:
	var o := written_transform(i).origin
	return Vector3(o.x, 0.0, o.z)

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

## Quanti colpi dell'ultimo `refresh()` sono partiti dalla **cupola** invece che da
## un mortar, cioe' quante volte e' scattato il ramo di riserva. Il test ci mette le
## mani perche' un canale finto senza mortar porterebbe ogni criterio dell'arco a
## misurare il ramo di riserva senza che nessuno lo dica.
func fallback_launchs() -> int:
	return _last_fallback

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
