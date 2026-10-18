extends Node3D
## Il terreno **chiuso**: pavimento, muro, casse. Tre `MultiMesh`, tre nodi,
## qualunque sia la dimensione **e quantunque sia il numero di piani**.
##
## Una `MultiMeshInstance3D` per `assets/models/ground_tile.glb` e una per
## `crate.glb`: i due modelli sono gia' stati generati in w1, qui non li
## rigenero e non li modifico, li solo uso come mesh.
##
## Il pavimento e' una MultiMesh e non un `GridMap` o 900 nodi: la regola "un
## nodo per cosa'" del progetto vale anche per il terreno, e a 35 m di raggio
## (78 m di lato, 1521 piastrelle **per piano**) un pavimento a nodi da solo
## mangerebbe il budget del criterio n. 3 da solo — e la torre ne ha **quattro**.
##
## ## m12: IL TERRENO E' UN VOLUME, E NON QUATTRO TERRENI
##
## Tre MultiMesh e tre nodi **come prima**: i quattro piani sono quattro
## gruppi di istanze dentro gli stessi tre buffer. Il numero di nodi **non
## cresce con il numero di piani**, che e' la regola che conta: un `GridMap`
## per piano, o 1521 nodi per pavimento, avrebbero fatto salire `node_count`
## di quattro volte da solo.
##
## Ogni piano `i` copre `y` in `[i * floor_height, (i+1) * floor_height)` e il
## **bordo inferiore e' del piano di sotto** (`contracts.gd::floor_of`). I due
## numeri (`floor_count`, `floor_height`) **non sono scritti qui**: li registra
## `src/render/arena.gd`, che e' la fonte unica, e questo file li **legge** dal
## contratto — la stessa forma di `arena_radius()` qui sotto.

const FLOOR_SCENE := "res://assets/models/ground_tile.glb"
const CRATE_SCENE := "res://assets/models/crate.glb"
## Il piano delle rampe. Lo stesso `preload` che `src/render/arena.gd` fa di
## `src/sim/obstacles.gd`: il **proprietario** e' dichiarato, il dato ha **un
## solo produttore**, e quello che ci metto dentro — il buco nel pavimento — e'
## mio. Se il produttore cambiasse la forma della rampa, qui dentro il buco
## cambierebbe da solo. Non e' una copia: e' una lettura.
const ARAMP := preload("res://src/render/arena_ramp.gd")

## `ground_tile.glb` e' un piano di 2x2 metri, generato in w1.
const TILE := 2.0
## Quante file di piastrelle in alto ha il muro di **un piano**. Dieci file sono
## venti metri, cioe' **un piano intero**: e' il numero che tiene la torre
## chiusa. Prima di m12 erano due file (quattro metri), abbastanza per chiudere
## un'arena **piatta**; in una torre quattro metri di muro lasciano vedere il
## vuoto fra un piano e l'altro, quindi il numero e' salito con l'altezza del
## piano e `tests/test_arena.gd` verifica che `WALL_ROWS * TILE` sia **esattamente**
## `Game.floor_height`: un muro che non arriva in fondo e' il difetto.
const WALL_ROWS := 10
## Crate sparse dentro l'arena. Poche e deterministiche: sono un segnalibro, non
## un labirinto. Dal m12 sono **sui quattro piani** e il totale resta questo.
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
## Quante volte si ritenta la posizione di una cassa che e' finita dentro il
## rettangolo di una rampa. Un **tetto**, non un ciclo: nessun `while` che possa
## non finire dentro `_build()`. Il buco e' una striscia di 8 m su un anello di
## 31 m, quindi la probabilita' di un colpo al primo giro e' bassa e il numero
## serve solo a garantire che la costruzione **termini**.
const CRATE_TENTATIVI := 6
## ## I 28 SU QUATTRO PIANI: PER FLOOR E NON UN NUMERO NUOVO
##
## `28 / 4 = 7`, quindi la divisione **torna esatta** e non c'e' nessun resto da
## spartire. Il numero per piano non e' scritto qui: e' `CRATE_COUNT / floor_count`
## letto dal contratto, quindi se il vertice cambiasse il numero di piani le casse
## seguirebbero da sole. Se la divisione **non** tornasse, questo file non
## arrotonda in silenzio: avvisa una volta sola e dice il numero che non torna,
## e `tests/test_arena.gd` va rosso su un criterio che richiede un totale uguale
## a `CRATE_COUNT` **e** un blocco per piano.
##
## Le casse di un piano sono **un blocco consecutivo**, come i blocchi dei piani
## degli ostacoli: il chiamante legge `crate_transform(i)` e sa in che piano e'
## con `i / per_floor`, senza che nessuno debba dirglielo.
##
## ## PERCHE' UNA CASSA NON NASCE SU UN BUCO
##
## Il pavimento di un piano ha il **buco** della rampa che arriva su quel piano
## (`arena_ramp.gd::in_corridor`), e una cassa dentro il buco sarebbe **un cubo
## sospeso nel vuoto** sopra la rampa: geometria che l'occhio vede e che nessuno
## calpesta. Quindi il criterio di posizione di una cassa e' tre cose insieme:
## dentro l'anello dichiarato, **fuori** dal rettangolo di ogni rampa che buca
## questo stesso pavimento, e con l'altezza giusta per il piano che le e' stato
## assegnato. Il secondo e' quello che m12 aggiunge, e senza di esso il difetto
## sarebbe **fuori da ogni porta**: nessuna asserzione del progetto guardava la
## posizione delle casse, quindi si sarebbe visto solo giocando.
##
## ## FALLBACK RADIUS: un fallback **dichiarato**, non una fonte (criterio n. 2 di m9)
##
## Vive **solo** quando il contratto non e' ancora raggiungibile. In partita non
## viene mai usato: il valore vero arriva da `Game.arena_radius`, e quel campo lo
## scrive `src/render/arena.gd`, che e' la **fonte unica** del numero (piano
## 1.12-bis, copia 5 di 6).
##
## Perche' 35.0 e non il numero di prima: un terreno costruito con il fallback
## vecchio su una torre di 35 m avrebbe un muro a 60 m **fuori** dal campo di
## gioco e un pavimento che copre un disco che non esiste, cioe' l'errore piu'
## sproporzionato di tutti, perche' qui il fallback non nasconde un numero ma
## **costruisce la geometria**. Il numero non e' scelto qui: e' quello della
## fonte, `src/render/arena.gd`, con la tabella e il motivo scritti accanto.
##
## Non puo' divergere: `tests/test_arena.gd` legge questa riga dal sorgente e la
## confronta con la fonte, quindi cambiarla da sola porta la porta rossa con i
## due numeri nel messaggio.
const FALLBACK_RADIUS := 35.0
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
## Le trasformazioni dei **pavimenti** e dei **muri**, scritte nei buffer. Stesso
## motivo di `_written_crates` (il buffer di un `MultiMesh` non si rilegge in
## headless): e' l'unico posto dove si puo' dire **quante piastrelle ha un
## piano** e **se una piastrella manca perche' e' un buco di rampa**.
var _written_floor: Array[Transform3D] = []
var _written_wall: Array[Transform3D] = []
var _contract_cache: Node = null
var _built: bool = false
## I tre numeri della torre, **letti una volta sola** dal contratto all'avvio e tenuti
## qui. Non e' una copia: `_build()` gira una volta e il contratto non cambia; ma
## senza questi campi `_in_il_buco()` chiamerebbe `game.get()` **per ogni piastrella**
## (circa 6000 volte) e il costo di un `Object.get` in un ciclo di costruzione
## nasce cosi'. Il valore resta quello del contratto perche' `_source_*()` continua a
## rileggerlo da li' quando serve sapere se qualcuno l'ha cambiato.
var _floors: int = 1
var _height: float = 0.0
var _radius: float = 0.0

func _ready() -> void:
	_build()

# --- Costruzione --------------------------------------------------------------

func _build() -> void:
	if _built:
		return
	_built = true
	_floors = maxi(floor_count(), 1)
	_height = floor_height()
	_radius = arena_radius()
	if _height <= 0.0:
		# Senza `Game.floor_height` non c'e' una torre: questo file **non** decide
		# un'altezza di piano al posto del vertice, avvisa una volta sola e costruisce
		# un solo piano, che e' il mondo di prima di m12. Il test va rosso perche'
		# il numero che legge non e' quello dichiarato.
		push_warning("arena_ground: Game.floor_height non e' un numero (letto %.3f m): la torre non e' montata e il terreno resta un piano solo. Il campo e' dichiarato in src/core/contracts.gd e lo registra src/render/arena.gd"
			% _height)
		_floors = 1
	var radius := _radius

	_floor = _add_multimesh("Floor", FLOOR_SCENE)
	_build_floor(_floor, radius)

	_wall = _add_multimesh("Wall", FLOOR_SCENE)
	_build_wall(_wall, radius)

	_crates = _add_multimesh("Crates", CRATE_SCENE)
	_build_crates(_crates, radius)

	# L'ingranaggio di culling, per **ultimo**: `custom_aabb` sostituisce la
	# scatola che il motore calcola dalla mesh, e il valore scritto a mano nel
	# 2026-10-13 (+/-50 m all'arena da 46 m) era **piu' piccolo del pavimento**
	# (+/-70,7 m): la corona di piastrelle piu' esterna spariva quando usciva
	# dalla scatola. Lo si deriva dai numeri della torre perche' un numero scritto
	# qui accanto a un raggio che cambia e' la stessa classe di difetto di un
	# fallback che diverge.
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

## La scatola che il motore usa per decidere se disegnare, **derivata dai numeri
## della torre** invece che scritta a mano.
##
## Mezza diagonale del pavimento: il pavimento e' un quadrato di
## `radius * 2 + FLOOR_MARGIN`, quindi il suo punto piu' lontano dal centro e' a
## `side / 2 * sqrt(2)`, non a `side / 2`. Arrotondare a `radius + FLOOR_MARGIN`
## avrebbe tagliato il cantone, e il cantone tagliato e' il difetto che nessuna
## asserzione headless vede.
##
## **m12: in alto non c'e' piu' il muro ma tutta la torre.** Il riquadro deve
## arrivare a `floor_count * floor_height` — **80,0 m** — e non a
## `WALL_ROWS * TILE`: con il riquadro vecchio l'intera torre sarebbe stata
## **fuori** dalla scatola, cioe' cullata dal motore, e nessuna asserzione
## headless lo vedrebbe perche' un `MultiMesh` cullata continua a riportare il
## numero di istanze che gli e' stato scritto. In giu' mezzo metro sotto il
## pavimento della torre per la cassa appoggiata.
func _fit_aabbs(radius: float) -> void:
	var side := radius * 2.0 + FLOOR_MARGIN
	var half := side * 0.5 * sqrt(2.0)
	var top := float(_floors) * _height + 1.0
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

## I quattro pavimenti, in un solo `MultiMesh`.
##
## `per_side` arrotonda in eccesso: un pavimento un pelo piu' largo costa quattro
## piastrelle, un pavimento piu' stretto costa il buco nero. Il totale e' la somma
## dei quattro piani **meno** le piastrelle cadute nei buchi delle rampe, e
## quindi il numero che esce non e' `per_side^2 * floor_count`: e' **la misura**,
## e il test la rilegge e la confronta con il conto che lui stesso rifa.
##
## Il buco: la rampa che **arriva** su questo piano e' la `piano - 1`, e il suo
## rettangolo e' quello di `arena_ramp.gd::in_corridor`. Una piastrella il cui
## **centro** cade dentro quel rettangolo non viene scritta: il pavimento sopra
## la rampa deve essere aperto, altrimenti la rampa finisce contro il soffitto.
func _build_floor(mi: MultiMeshInstance3D, radius: float) -> void:
	var mm := _multimesh_of(mi)
	if mm == null:
		return
	var floors := _floors
	var side := radius * 2.0 + FLOOR_MARGIN
	var per_side := int(ceil(side / TILE))
	var origin := -side * 0.5
	var flat := Basis.IDENTITY
	var transforms: Array[Transform3D] = []
	for piano in floors:
		var base := float(piano) * _height
		for ix in per_side:
			for iz in per_side:
				var x := origin + (float(ix) + 0.5) * TILE
				var z := origin + (float(iz) + 0.5) * TILE
				if _in_il_buco(piano, Vector2(x, z)):
					continue
				transforms.append(Transform3D(flat, Vector3(x, base, z)))
	mm.instance_count = transforms.size()
	var n := 0
	for t in transforms:
		mm.set_instance_transform(n, t)
		n += 1
	mm.visible_instance_count = transforms.size()
	_written_floor = transforms

## La piastrella `(x, z)` del piano `piano` cade in un buco di rampa?
##
## Il buco del piano `piano` e' quello della rampa che **arriva** su quel piano,
## cioe' la rampa di indice `piano - 1`. Sul piano 0 non arriva nessuna rampa e
## il pavimento e' pieno: e' il caso di prima di m12, quindi questa funzione
## restituisce `false` per ogni punto e non cambia nessun numero.
func _in_il_buco(piano: int, p: Vector2) -> bool:
	if piano < 1:
		return false
	return ARAMP.in_corridor(piano - 1, _floors, _radius, TILE, p)

## I muri, uno **per piano**, alti un piano intero.
##
## Un muro di 4 metri su una torre di 80 lascia vedere il vuoto fra un piano e
## l'altro: da fuori, sopra il muro del piano 0, si vede il **bordo** del
## pavimento del piano 1 e la sua parete interna. Quindi `WALL_ROWS` e' dieci
## file, cioe' `floor_height`, e il test verifica che i due numeri coincidano.
func _build_wall(mi: MultiMeshInstance3D, radius: float) -> void:
	var mm := _multimesh_of(mi)
	if mm == null:
		return
	# Un segmento per piastrella di circonferenza: il muro chiude davvero, senza
	# buchi e senza sporgenze.
	var segments := maxi(8, int(ceil(TAU * radius / TILE)))
	var transforms: Array[Transform3D] = []
	for piano in _floors:
		var base := float(piano) * _height
		for i in segments:
			var angle := TAU * float(i) / float(segments)
			var outward := Vector3(cos(angle), 0.0, sin(angle))
			var tangent := Vector3(-sin(angle), 0.0, cos(angle))
			# Il piano del modello giace nel piano XZ con normale su Y: per metterlo
			# in piedi la sua Y deve diventare la normale orizzontale e la sua Z
			# l'altezza. Le tre colonne cosi' formano una base destrorsa.
			var basis := Basis(tangent, outward, Vector3.UP)
			for row in WALL_ROWS:
				var y := base + (float(row) + 0.5) * TILE
				transforms.append(Transform3D(basis, outward * radius + Vector3(0.0, y, 0.0)))
	mm.instance_count = transforms.size()
	var n := 0
	for t in transforms:
		mm.set_instance_transform(n, t)
		n += 1
	mm.visible_instance_count = transforms.size()
	_written_wall = transforms

## Le 28 casse, **sui quattro piani**, in blocchi consecutivi.
##
## Il blocco e' dichiarato subito sopra `CRATE_SEED`: `per_floor = CRATE_COUNT /
## floor_count` e la cassa `i` sta sul piano `i / per_floor`. Se la divisione non
## tornasse — cioe' se il vertice cambiasse il numero di piani in modo che `28` non
## vi si divida — non si arrotonda: si dice una volta sola, col numero che non
## torna, e `tests/test_arena.gd` va rosso.
##
## Il terzo criterio di posizione e' **fuori dai buchi**: una cassa dentro il
## rettangolo della rampa che buca questo stesso pavimento sarebbe un cubo
## sospeso nel vuoto.
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
	var floors := _floors
	var per := crates_per_floor()
	var outer := maxf(CRATE_INNER + 1.0, radius - CRATE_OUTER_GAP)
	for i in CRATE_COUNT:
		var piano := i / maxi(per, 1)
		if piano >= floors:
			piano = floors - 1
		var angle := rng.randf() * TAU
		var r := rng.randf_range(CRATE_INNER, outer)
		var p := Vector2(cos(angle) * r, sin(angle) * r)
		# Dentro il buco non si mette niente. Si **ricalcola** l'angolo invece di
		# scartare la cassa: scartarla cambierebbe il numero di casse per piano e
		# quindi il totale, che e' dichiarato. Il tentativo e' limitato e dichiarato
		# qui perche' il buco e' una striscia sottile e il primo giro basta quasi
		# sempre; se il limite si esaurisce la cassa resta **dentro** l'anello e
		# sopra il buco, e il difetto e' visibile a occhio e stampato dal test.
		for tentativo in CRATE_TENTATIVI:
			if not _in_il_buco(piano, p):
				break
			angle = rng.randf() * TAU
			r = rng.randf_range(CRATE_INNER, outer)
			p = Vector2(cos(angle) * r, sin(angle) * r)
		# `crate.glb` e' un cubo di 0.9 centrato nell'origine: mezzo lato in alto
		# lo appoggia al pavimento **del suo piano** invece di affondarlo.
		var pos := Vector3(p.x, float(piano) * _height + TILE * 0.225, p.y)
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pos)
		mm.set_instance_transform(i, t)
		_written_crates.append(t)
	mm.visible_instance_count = CRATE_COUNT

## Quante casse stanno su **un** piano: `CRATE_COUNT / floor_count`, cioe' il
## numero che il piano e' costretto a dichiarare. `-1` quando la divisione non
## torna: un numero arrotondato qui passerebbe un test che chiede «il totale
## resta 28 e ogni piano ne ha la stessa quantita'».
func crates_per_floor() -> int:
	var floors := maxi(_floors, 1)
	if CRATE_COUNT % floors != 0:
		return -1
	return CRATE_COUNT / floors

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

## Quanti piani ha la torre, **dal contratto**. Il ripiego e' **`1`**, il default
## dichiarato del contratto, e non `-1`: `maxi(-1, 1)` vale `1`, quindi `-1` non
## aggiungeva informazione, toglieva solo un numero che **non esiste in nessun
## mondo**. Vedi la nota lunga di `arena_obstacles.gd::floor_count()`, che e' lo
## stesso difetto e la stessa correzione: qui il difetto si vedeva in
## `_build()`, che con `-1` costruiva `maxi(-1, 1)` piani **senza dirlo**.
func floor_count() -> int:
	var game := _contract()
	if game == null:
		return 1
	var value = game.get("floor_count")
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return maxi(int(value), 1)
	return 1

## L'altezza di un piano, **dal contratto**. Ripiego **`0,0`**, il default dichiarato,
## per la stessa ragzione: `0,0` e' un mondo piatto — un piano a quota zero — che e'
## esattamente il mondo di prima di m12, mentre `-1,0` non e' un'altezza e non e' un
## mondo. Se un giorno il vertice toglie il campo, la porta che deve accorgersene e'
## `tests/test_arena.gd`, che confronta il valore **registrato** con quello che
## `arena.gd` dichiara: non un ripiego che finge.
func floor_height() -> float:
	var game := _contract()
	if game == null:
		return 0.0
	var value = game.get("floor_height")
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return 0.0

## A che quota comincia il piano `piano`: `piano * floor_height`. Il **bordo
## inferiore e' del piano di sotto**, quindi `floor_of(20,0)` vale `1` e non `0`
## (`contracts.gd`, `floor_of`).
func floor_base(piano: int) -> float:
	return float(maxi(piano, 0)) * floor_height()

## Quante **rampe** ci sono: `floor_count - 1`. Passa attraverso il produttore
## unico invece di rifare la sottrazione qui, cosi' la rampa che il terreno
## ritaglia e la rampa che il nodo `Ramps` disegna non possono divergere.
func ramp_count() -> int:
	return ARAMP.ramp_count(maxi(floor_count(), 1))

## L'altezza del punto piu' in alto della torre, cioe' `floor_count *
## floor_height`. E' il numero che chiude il riquadro di culling e quello che il
## test confronta con `floor_of()` per ogni punto scritto nei buffer.
func tower_height() -> float:
	return float(maxi(floor_count(), 1)) * floor_height()

func floor_instances() -> int:
	return _visible_count(_floor)

func wall_instances() -> int:
	return _visible_count(_wall)

func crate_instances() -> int:
	return _visible_count(_crates)

## La trasformazione della piastrella di pavimento `i`, **cosi' com'e' stata
## scritta nel buffer**. Serve al test per chiedere «questa piastrella c'e'?» e
## «di che piano e'?», che in headless non si puo' fare rileggendo il `MultiMesh`.
func floor_transform(i: int) -> Transform3D:
	if i < 0 or i >= _written_floor.size():
		return Transform3D.IDENTITY
	return _written_floor[i]

## Il **piano** di una quota, cioe' `Game.floor_of(y)`.
##
## ## LA TRAPPOLA, E IL NUMERO CHE L'AVEVA NASCOSTA
##
## La prima stesura di `floor_tiles_on()` scriveva `int(floor(t.origin.y)) == piano`:
## confrontava **l'altezza** con **l'indice del piano**. Al piano 0 il confronto
## tornava per caso (`int(floor(0.0)) == 0`), e ai piani 1, 2 e 3 non tornava mai —
## `int(floor(20.0))` vale `20`, non `1`. Il sintomo era quindi la piu' bugiarda delle
## tre forme: **«il piano 1 ha zero piastrelle»** su una torre che ne ha `1521`, e il
## piano 0 verde accanto. Un numero che torna per caso al primo caso e non torna
## mai dopo e' un numero che non e' stato confrontato con nessuno.
##
## Qui la divisione la fa **il contratto**, `Game.floor_of()`, che e' aritmetica pura
## e vive in `src/core/contracts.gd`: copiarla qui sarebbe una seconda versione che
## concorda finche' non c'e' una torre. Il ripiego sotto e' dichiarato e serve solo
## quando il contratto non e' raggiungibile — un mondo senza contratto e' un piano
## solo, e `0` e' la risposta **vera** in quel mondo, non una approssimazione.
func floor_of(y: float) -> int:
	var game := _contract()
	if game != null and game.has_method("floor_of"):
		return int(game.floor_of(y))
	var h := maxf(_height, 0.0)
	if h <= 0.0:
		return 0
	return clampi(int(floor(y / h)), 0, maxi(_floors - 1, 0))

## Quante piastrelle di pavimento ha **il piano `piano`**, contate fra quelle
## **scritte**: e' la misura, non un conto. Il confronto con
## `per_side * per_side` meno i buchi e' il criterio, e i due numeri devono
## combaciare voce per voce.
##
## Il piano di una piastrella si legge con `floor_of()` e **non** arrotondando
## l'altezza: vedi la nota sopra, che racconta perche' la forma sbagliata passava
## sul piano 0 e falliva su tutti gli altri.
func floor_tiles_on(piano: int) -> int:
	var n := 0
	for t in _written_floor:
		if floor_of(t.origin.y) == piano:
			n += 1
	return n

## Quante piastrelle di **muro** ha il piano `piano`, contate fra quelle scritte.
##
## Anche qui il piano viene da `floor_of()` e non da una divisione per `TILE` e per
## `WALL_ROWS`: la divisione per `TILE * WALL_ROWS` e' una **seconda** definizione di
## «un piano», e se il vertice cambiasse `FLOOR_HEIGHT` senza cambiare `WALL_ROWS`
## quella divisione conterebbe piani sbagliati senza dirlo.
func wall_tiles_on(piano: int) -> int:
	var n := 0
	for t in _written_wall:
		if floor_of(t.origin.y) == piano:
			n += 1
	return n

## Il piano su cui sta **la cassa `i`**: non `floor_of()` della sua quota — che
## darebbe la risposta giusta solo per caso — ma la **posizione nell'array**,
## cioe' `i / crates_per_floor()`, la stessa regola con cui le casse sono state
## scritte e quindi l'unica che non puo' mentire.
func crate_floor(i: int) -> int:
	var per := crates_per_floor()
	if per <= 0:
		return -1
	return i / per

## Quante casse sono finite **fuori** dal rettangolo di una rampa che buca il
## loro stesso piano. Il numero che **deve** essere zero: una cassa dentro il
## buco e' un cubo sospeso nel vuoto, e nessuna altra asserzione del progetto
## lo guarda.
func crates_inside_holes() -> int:
	var n := 0
	for i in _written_crates.size():
		if _in_il_buco(crate_floor(i), Vector2(_written_crates[i].origin.x, _written_crates[i].origin.z)):
			n += 1
	return n

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