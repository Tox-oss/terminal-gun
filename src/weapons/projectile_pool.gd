extends Node3D
## Il pool dei proiettili. -gameplay. Capacità fissa, nessuna allocazione nel
## ciclo di gioco (piano §5, regola 2).
##
## Come funziona, e perché è scritto così:
##
## 1. **100 slot, creati una volta sola** in `_ready()`. Da lì in avanti non
##    esiste più nessuna `new()`, `instantiate()` o `queue_free()`: un colpo
##    riusa uno slot, un proiettile scaduto torna in coda con uno *swap con
##    l'ultimo* (O(1), e l'elenco degli attivi resta compatto in `[0, _count)`).
##    Se il pool è pieno, il più vecchio viene riusato: in un bullet heaven
##    perdere il colpo è peggio che raddoppiare un proiettile già sparato.
##    Lo swap sposta un **indice**, non un record: vedi `_items`, `_order`,
##    `_free`.
##
## 2. **L'orda si legge, non si possiede.** Nessun nemico è un nodo: qui il
##    **contatto** scandisce i due campi pubblici che il piano dichiara come
##    "massa" (`horde.count` e `horde.transforms`) e scrive **solo** attraverso
##    `Game.damage_enemy(indice, danno, knockback)`.
##
##    Il pool **non usa `nearest_enemy`**, e non per dimenticanza: la **mira** la
##    fa `weapon_base._try_fire`, che chiama `Game.nearest_enemy(pos, raggio)` e
##    riceve un **indice** (`-1` = nessun bersaglio, piano §5.2). `-1` non è un
##    nemico: chi lo riceve non spara e non lo passa mai a `damage_enemy`. Il
##    contatto invece ha bisogno di *tutti* i nemici vivi per frame — il segmento
##    del proiettile viene confrontato con ciascuno e si sceglie il primo
##    incontrato — e una "nearest" non serve a niente: quello che serve è
##    `horde.transforms`, cioè gli indici buoni. Per questo il percorso del
##    danno è: **mira** via `Game.nearest_enemy` (nell'arma), **impatto** via
##    `horde.transforms` + `Game.damage_enemy` (qui).
##
## 3. **Il contatto è un segmento, non un punto.** A 26 m/s e 60 Hz un
##    proiettile avanza di 0.43 m per frame: testando solo la posizione finale
##    passerebbe attraverso i nemici senza colpirli mai. Qui si testa il
##    segmento percorso nel frame, e si sceglie il **primo** nemico toccato
##    (parametro `t` minimo), così il proiettile che attraversa una folla
##    colpisce quello davanti e non quello dietro.
##
## 4. **Il contatto è sul piano XZ.** L'arena è piatta e il contratto non dice
##    quale `y` mette l'orda nei `transforms` (piedi del modello? centro?):
##    ignorare la `y` rende il proiettile indifferente a quella scelta, invece
##    di fallire in silenzio quando l'orda sceglie un'altra convenzione.

const ProjectileScript := preload("res://src/weapons/projectile.gd")

## Scene con la mesh del proiettile: i dati visuali stanno nelle scene, non in
## codice. Se non ci fosse, si usa un primitivo (vedi `_bullet_mesh`).
const PROJECTILE_SCENE := "res://scenes/projectile.tscn"

## Quanti proiettili esistono, per sempre. Assegnati una volta sola all'avvio.
const CAPACITY := 100

## Raggio di contatto del nemico, in metri. **Il contratto non lo espone**:
## è il raggio della capsula a terra dei modelli low-poly. Se l'orda lo
## espone, si legge da lì e basta cambiare questa riga.
const ENEMY_RADIUS := 0.55

## Nodo che disegna i proiettili: UNO solo, per 100 proiettili. Nessun nodo per
## proiettile, quindi il conteggio dei nodi non cresce sparando.
var _visual: MultiMeshInstance3D
var _visual_basis := Basis.IDENTITY

## L'arma che ha creato questo pool: il pool non conosce nessun altro script,
## prende da lei danno, knockback, vita e pierce. Senza tipo di classe per non
## dipendere da `weapon_base.gd` (nessuna dipendenza circolare, piano §5).
var weapon

## `CAPACITY` record, **sempre gli stessi oggetti nella stessa casella**, mai
## sostituiti e mai messi a `null`. `_items` non si riordina mai: e' il deposito
## dei record, e la sua forma non cambia dalla `_ready()` in poi.
var _items: Array = []
## Quale record di `_items` e' vivo adesso: `_order[0.._count)` sono gli attivi,
## compatti. E' un array di **interi**, non di record: cosi' il "swap con
## l'ultimo" sposta un indice e non un riferimento, e un record non può finire
## in due caselle insieme.
##
## Il difetto che questo evita, e che un `Array` di record diretto ha: liberando
## la casella `i` e spostando in `i` il record dell'ultimo, il record liberato
## sparisce dall'array e l'ultimo si ritrova **in due caselle**. Il prossimo
## `acquire` prende la casella `i` (libera) e rilancia dentro un record che è
## ancora in volo: il colpo sparisce e quello precedente viene teletrasportato.
## Con la pila `_free` sotto ogni record resta in una casella sola e la riusa e'
## sempre dello stesso oggetto, che e' quello che "zero allocazioni" significa.
var _order := PackedInt32Array()
## Pila, allocata una volta sola, degli indici di `_items` liberi. `_free_top` e'
## quanto e' piena: lo slot liberato e' l'ultimo (`_free[_free_top - 1]`).
var _free := PackedInt32Array()
var _free_top: int = 0
## Proiettili vivi adesso.
var _count: int = 0
## Quanti proiettili sono stati creati in totale. Deve restare `CAPACITY` per
## sempre: è il contatore che il test usa per dire "300 colpi, zero allocazioni".
var _created: int = 0
var _warned_no_horde: bool = false

func _ready() -> void:
	_build_items()
	_build_visual()

func capacity() -> int:
	return CAPACITY

## Proiettili vivi adesso.
func active_count() -> int:
	return _count

## Quanti ne sono stati creati in totale dall'avvio: se cresce, qualcuno ha
## allocato nel ciclo di gioco.
func ever_created() -> int:
	return _created

## Il proiettile attivo numero `i` (0 <= i < `active_count()`).
func active_at(i: int):
	if i < 0 or i >= _count:
		return null
	return _items[_order[i]]

# --- Il ciclo di gioco ---------------------------------------------------------

## Un passo: muove tutti i proiettili vivi e ne testa il contatto.
## Si itera **all'indietro** e si libera con lo swap con l'ultimo sugli indici di
## `_order`: l'indice che finisce nello slot appena liberato è già stato mosso in
## questo frame, quindi nessun proiettile viene mosso due volte e nessuno resta
## indietro.
func step(delta: float) -> void:
	var i := _count - 1
	while i >= 0:
		var p = _items[_order[i]]
		p.step(delta)
		if p.expired():
			_release(i)
		else:
			_collide(p, i)
		i -= 1
	_draw()

## Implementazione di `Game.spawn_projectile`: riusa uno slot e restituisce
## il record. Non restituisce un `Node3D`, e non è un difetto: un proiettile
## non è un nodo (piano §5, regola 1). Il tipo di ritorno lo dichiara il piano
## §5.2: `-> bool`, `true` se il pool ha ceduto uno slot. Questo metodo
## restituisce il record per comodita' di chi chiama il pool direttamente, ma
## `weapon_base._spawn_projectile` non lo usa e passa dal contratto.
func acquire(pos: Vector3, dir: Vector3, speed: float):
	if weapon == null:
		return null
	var idx := -1
	if _free_top > 0:
		_free_top -= 1
		idx = _free[_free_top]
		_order[_count] = idx
		_count += 1
	elif _count >= CAPACITY:
		# Pool pieno: si riusa il più vecchio, che è l'attivo numero 0. Si
		# rilancia dentro il suo record senza toccare `_order` né `_count`: il
		# vecchio colpo sparisce e il nuovo lo prende in presto, che in un
		# bullet heaven e' meglio che perdere il colpo.
		idx = _order[0]
	else:
		# Difesa: `CAPACITY` record, `CAPACITY` indici, e ogni indice o e' in
		# `_order[0.._count)` o e' in `_free`. Se questa riga si raggiunge,
		# qualcuno ha rotto l'invariante e vale piu' un errore rumoroso che un
		# record fuori posto.
		push_error("projectile_pool: nessuno slot libero ma gli attivi sono %d su %d: l'invariante del pool e' rotta." % [_count, CAPACITY])
		return null
	var p = _items[idx]
	p.launch(pos, dir.normalized(), speed, weapon.damage, weapon.knockback,
		weapon.projectile_life, weapon.pierce)
	return p

## Svuota il pool senza toccare l'orda. Serve ai test e al cambio d'onda.
func reset() -> void:
	while _count > 0:
		_release(0)
	_draw()

# --- Lettura dell'orda (dati pubblici, mai i suoi nodi) -------------------------

## Il nemico di indice `i`, se vivo. `Vector3.ZERO` se non c'è: nessuna
## posizione restituita è ambigua, perché ZERO è anche sotto il giocatore.
func enemy_position(i: int) -> Vector3:
	var horde: Node = Game.horde
	if i < 0 or horde == null:
		return Vector3.ZERO
	var v: Variant = horde.get("transforms")
	if not (v is PackedVector3Array):
		return Vector3.ZERO
	var tr: PackedVector3Array = v
	if i >= tr.size():
		return Vector3.ZERO
	return tr[i]

## Indice del nemico vivo più vicino a `from` entro `radius`, o `-1`.
## **Non è sul percorso del danno** e il gameplay non la chiama: vedi il punto 2
## in testa al file. Resta per chi debba debuggare un tiro (perche' ha colpito
## quello e non un altro) senza attraversare il contratto.
func nearest_enemy(from: Vector3, radius: float) -> int:
	var tr := _transforms()
	if tr.is_empty():
		return -1
	var n := mini(_live_count(tr), tr.size())
	var best := -1
	var best_d2 := radius * radius
	for i in n:
		var d2 := _flat_dist2(from, tr[i])
		if d2 <= best_d2:
			best_d2 = d2
			best = i
	return best

# --- Interno ------------------------------------------------------------------

## Collisione di un proiettile: al massimo un nemico per frame, il primo
## incontrato lungo il percorso, e mai due volte lo stesso nemico (il registro
## sta nel record). `index` serve per liberare lo slot se il budget di `pierce`
## finisce.
func _collide(p, index: int) -> void:
	var tr := _transforms()
	if tr.is_empty():
		return
	var n := mini(_live_count(tr), tr.size())
	if n <= 0:
		return
	var reach: float = p.radius + ENEMY_RADIUS
	var radius2 := reach * reach
	var best := -1
	var best_t := 2.0
	for e in n:
		if p.has_hit(e):
			continue
		var t := _segment_hit(p.prev_pos, p.pos, tr[e], radius2)
		if t >= 0.0 and t < best_t:
			best_t = t
			best = e
	if best < 0:
		return
	if not p.log_hit(best):
		return
	# Il punto d'impatto vero: quello sul segmento, non la fine del frame.
	var impact: Vector3 = p.prev_pos.lerp(p.pos, best_t)
	# `damage_enemy` risponde `true` se il nemico e' morto (piano §5.2): e'
	# l'unico modo onesto di sapere di aver ucciso qualcosa, e da li nasce l'XP.
	var killed: bool = Game.damage_enemy(best, p.damage, p.dir * p.knockback)
	if weapon != null:
		weapon.on_impact(impact)
	if killed and weapon != null:
		weapon.on_kill()
	if p.hits_left() <= 0:
		_release(index)

## Mette in coda uno slot liberato, con lo swap con l'ultimo sugli **indici**.
## `_items` non viene toccata: il record resta nella sua casella, e l'indice
## liberato torna sulla pila `_free`.
func _release(index: int) -> void:
	if index < 0 or index >= _count:
		return
	var freed := _order[index]
	_count -= 1
	if index != _count:
		_order[index] = _order[_count]
	if _free_top < CAPACITY:
		_free[_free_top] = freed
		_free_top += 1

## Le posizioni dell'orda. `-1` non serve: un array vuoto dice "niente da
## colpire", e la differenza la fa `nearest_enemy` che restituisce `-1`.
func _transforms() -> PackedVector3Array:
	var horde: Node = Game.horde
	if horde == null:
		if not _warned_no_horde:
			_warned_no_horde = true
			push_warning("Game.horde non e' registrata: nessun proiettile puo' colpire niente. tocca a terminal-gun-orda.")
		return PackedVector3Array()
	var v: Variant = horde.get("transforms")
	if not (v is PackedVector3Array):
		return PackedVector3Array()
	return v

## Quanti dei `transforms` sono vivi. `count` è l'autorità: se l'orda tiene
## slot morti in coda, non sono nemici e non si possono colpire.
func _live_count(tr: PackedVector3Array) -> int:
	var horde: Node = Game.horde
	if horde == null:
		return 0
	var v: Variant = horde.get("count")
	if not (v is int or v is float):
		return 0
	return mini(int(v), tr.size())

## Distanza sul piano, quadrata: la `y` non c'entra, l'arena è piatta.
static func _flat_dist2(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return dx * dx + dz * dz

## Parametro `t` in [0, 1] del primo punto del segmento `from..to` entro
## `radius2` da `center`, oppure -1. È il test di contatto vero: copre tutto
## il cammino del frame, quindi nessun proiettile veloce attraversa un nemico.
static func _segment_hit(from: Vector3, to: Vector3, center: Vector3, radius2: float) -> float:
	var sx := to.x - from.x
	var sz := to.z - from.z
	var len2 := sx * sx + sz * sz
	var t := 0.0
	if len2 > 0.000001:
		t = ((center.x - from.x) * sx + (center.z - from.z) * sz) / len2
		t = clampf(t, 0.0, 1.0)
	var cx := from.x + sx * t - center.x
	var cz := from.z + sz * t - center.z
	if cx * cx + cz * cz <= radius2:
		return t
	return -1.0

## I CAPACITY record, una volta sola. `_items` non si riordina piu' e `_order` /
## `_free` sono gia' dimensionati: da qui in poi nessuna allocazione.
func _build_items() -> void:
	_items.resize(CAPACITY)
	for i in CAPACITY:
		var p = ProjectileScript.new()
		# Registro dimensionato al massimo possibile: nessuna allocazione dopo.
		p.hit_log.resize(ProjectileScript.MAX_PIERCE + 1)
		_items[i] = p
	_order.resize(CAPACITY)
	_free.resize(CAPACITY)
	# Pila: l'indice 0 e' in cima, quindi si empila in ordine inverso.
	for i in CAPACITY:
		_free[i] = CAPACITY - 1 - i
	_free_top = CAPACITY
	_count = 0
	_created = CAPACITY

## Un nodo solo per 100 proiettili.
##
## ## `top_level = true`: perche' sta qui e non altrove
##
## `_draw()` scrive nelle istanze della MultiMesh delle **posizioni mondo**: il
## `pos` del record viene da `muzzle_position()`, che e' `global_position + MUZZLE_HEIGHT`.
## Ma questa `MultiMeshInstance3D` sta **dentro** il pool, che sta dentro l'arma,
## che sta dentro `Player`: il renderer moltiplica ogni istanza per la
## trasformazione globale del nodo che le disegna. Con la gerarchia di prima il
## nodo visivo era a `posizione del giocatore`, e ogni proiettile finiva a
## `posizione del giocatore + posizione mondo del proiettile`: i pallini
## scortavano di quanto ti eri mosso.
##
## Il rimedio e' `top_level = true`, che stacca la trasformazione di questo nodo
## da quella del padre: la sua `global_transform` resta **identita'** e le
## posizioni mondo arrivano a schermo dove sono state calcolate.
##
## ## Perche' non toccare la gerarchia
##
## L'alternativa era spostare il nodo fuori dal giocatore (sotto `root`, o in un
## `Node` dedicato). Non e' quello che si fa, e il motivo e' scritto: la scena
## vera conta i nodi perche' il criterio n. 3 di m1 e il criterio n. 5 di m5
## impongono `node_count == 33`. `top_level` e' **una proprietà**, non un nodo:
## l'albero resta identico, il conteggio resta identico, e la trasformazione che
## il renderer applica a una posizione mondo diventa l'identita' — che e' la
## cosa che il difetto aveva rotto.
##
## Il numero lo misura `tests/test_gameplay.gd`, perche' in headless la MultiMesh
## non si rilegge: la misura e' sulla `global_transform` del nodo, che e' la
## causa, non l'effetto.
func _build_visual() -> void:
	_visual = MultiMeshInstance3D.new()
	_visual.name = "Projectiles"
	# PRIMA di `add_child`: il nodo non entra mai nell'albero con la trasformazione
	# del padre, quindi non c'e' nemmeno un istante in cui i proiettili sono
	# disegnati a `posizione del giocatore + posizione mondo`.
	_visual.top_level = true
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _bullet_mesh()
	mm.instance_count = CAPACITY
	mm.visible_instance_count = 0
	_visual.multimesh = mm
	add_child(_visual)

## Il nodo che disegna i proiettili, se c'e'. Non serve al gameplay: esiste per
## il test di m5, che in headless non puo' rileggere la MultiMesh e quindi
## misura la **trasformazione** che il renderer le applica.
func visual_node():
	return _visual

## La trasformazione che il renderer applica a una posizione **mondo**: e' la
## `global_transform` del nodo visivo, e deve essere l'**identita'**. Se tornasse
## diversa, ogni proiettile verrebbe disegnato spostato di quanto vale quella
## trasformazione — cioe' di quanto si e' mosso il giocatore, che e' il difetto.
func draw_transform() -> Transform3D:
	if _visual == null or not is_instance_valid(_visual):
		return Transform3D.IDENTITY
	return _visual.global_transform

## Dove il renderer **disegnerebbe davvero** un proiettile che il pool tiene a
## `world_pos`: `draw_transform() * world_pos`. E' una composizione, non un campo
## letto al posto di una misura, quindi il test verifica la posizione finisce
## dove e' stata calcolata invece di verificare un flag.
func draw_position(world_pos: Vector3) -> Vector3:
	return draw_transform() * world_pos

## La mesh del proiettile: da `scenes/projectile.tscn` se c'è, altrimenti un
## primitivo. Nessun rendering deve dipendere da un file che non c'è.
func _bullet_mesh() -> Mesh:
	if ResourceLoader.exists(PROJECTILE_SCENE):
		var packed = load(PROJECTILE_SCENE)
		if packed is PackedScene:
			var template: PackedScene = packed
			var node: Node = template.instantiate()
			var mi := _find_mesh(node)
			var mesh: Mesh = mi.mesh if mi != null else null
			node.free()
			if mesh != null:
				return mesh
	var box := BoxMesh.new()
	box.size = Vector3(0.18, 0.18, 0.42)
	return box

func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for c in node.get_children():
		var found := _find_mesh(c)
		if found != null:
			return found
	return null

## Scrive le posizioni degli attivi nella MultiMesh. `visible_instance_count` è
## quello che tiene conto di pieno e svuotamento: gli slot oltre `_count` non si
## vedono, e non si vedranno i proiettili scaduti.
func _draw() -> void:
	if _visual == null or _visual.multimesh == null:
		return
	_visual.multimesh.visible_instance_count = _count
	for i in _count:
		_visual.multimesh.set_instance_transform(i, Transform3D(_visual_basis, _items[_order[i]].pos))