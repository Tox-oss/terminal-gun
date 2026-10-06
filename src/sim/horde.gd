extends Node3D
## L'orda: 200 nemici vivi **senza un nodo per nemico**.
##
## Un nemico e' un record in `transforms` (dove sta) piu' quattro array paralleli
## (velocita', hp, specie, timer), non un `Node3D`. Il criterio della milestone e'
## `node_count < 120` con `horde.count == 200`: un nodo per nemico, da solo,
## farebbe fallire il criterio.
##
## ## L'API "massa" non passa da funzioni
##
## Disegnare 200 nemici non e' una query, e' un `MultiMeshInstance3D` che legge
## tre campi. Per questo sono campi pubblici e non metodi:
##
##     horde.count        # quanti nemici vivi
##     horde.transforms   # PackedVector3Array, posizione mondo di ciascuno
##     horde.colors       # PackedColorArray, tinta per specie
##
## `transforms.size() == colors.size() == count`, sempre: l'invariante e' quello
## che permette all'arena di non controllare nulla.
##
## ## Le tre API del contratto (registrate in `_ready`)
##
##     Game.horde = self
##     Game.register_impl("nearest_enemy", self.nearest_enemy_index)
##     Game.register_impl("damage_enemy", self.damage_enemy)
##     Game.register_impl("random_spawn_point", self.random_spawn_point)
##
## Forma lunga (`register_impl` con la Callable), non `Game.nearest_enemy = ...`:
## GDScript rifiuta l'assegnazione a un nome che e' gia' un `func` e l'errore
## interromperebbe il `_ready()` (piano 5.1).
##
## `player_position` NON e' registrata qui: e' di -gameplay, e registrarne due
## impl per lo stesso nome e' una doppia registrazione.
##
## ## Perche' qui il contratto si prende con `get_node_or_null` e non con `Game.`
##
## Questo file viene compilato anche dai processi di test lanciati con
## `--script`, e in quel contesto l'autoload `Game` non e' ancora fra le
## costanti globali di GDScript: l'identificatore nudo `Game` non risolve e la
## compilazione si ferma con `Compile Error: Identifier not found: Game`,
## **prima** che una riga di questo file venga eseguita. Il nodo che si ottiene
## e' lo stesso identico singleton: si aggira la compilazione, non il
## contratto. Vedi `_contract()` e piano 5.3.

const E = preload("res://src/sim/enemy.gd")
const Grid = preload("res://src/sim/spatial_grid.gd")
const Spawner = preload("res://src/sim/spawner.gd")

## Capienza massima: decisa qui, una volta sola, e mai piu' cambiata.
const MAX_ENEMIES := 200
## Quanti colpi recenti si ricordano per sfx e flash, in un anello di capienza fissa.
const HITS_KEPT := 64
## Raggio entro cui due nemici si spingono, e quanti vicini si controllano per
## ciascuno. Il tetto e' quello che tiene il costo costante.
const SEPARATION_RADIUS := 1.6
const SEPARATION_CHECKS := 6
const SEPARATION_FORCE := 11.0
## Dalla zona dei colpi dello sparo, un nemico non deve arrivare addosso.
const MIN_SPAWN_GAP := 12.0
## Popolazione a cui si riporta l'orda quando un nemico muore.
var population: int = MAX_ENEMIES
## Se falsa, l'orda non si riempie da sola: serve al test per vedere il
## conteggio scendere davvero.
var auto_respawn: bool = true
## Seed della disposizione. 0 = casuale a ogni avvio; un numero = riproducibile.
var seed: int = 0

# --- API massa (piano 5) -------------------------------------------------------

## Nemici vivi. Vale sempre `transforms.size() == colors.size() == count`.
var count: int = 0
## Posizione mondo di ogni nemico vivo. Cio' che arena legge per il MultiMesh.
var transforms: PackedVector3Array = PackedVector3Array()
## Tinta per nemico (per specie).
var colors: PackedColorArray = PackedColorArray()

# --- Dati per nemico: array paralleli, tutti lunghi `count` --------------------

var velocities: PackedVector3Array = PackedVector3Array()
var hp: PackedFloat32Array = PackedFloat32Array()
var kinds: PackedInt32Array = PackedInt32Array()
## Secondi di pausa dopo un colpo. Colpisce solo l'animazione, non la fisica.
var timers: PackedFloat32Array = PackedFloat32Array()

# --- Telemetria ---------------------------------------------------------------

## Nemici ammazzati dall'inizio della partita.
var kills: int = 0
## Raggio utile dell'arena, ripreso dal contratto a ogni passo.
var arena_radius: float = 28.0
## Ultimi colpi ricevuti, in un anello di capienza fissa: `hit_count` quanti
## sono validi. Serve a sfx/flash senza toccare gli array e senza allocare.
var hit_count: int = 0
var hit_positions: PackedVector3Array = PackedVector3Array()
var hit_kinds: PackedInt32Array = PackedInt32Array()
## Numero di celle mai viste dalla griglia: dopo il riscaldamento deve restare 0.
var grid_unknown_cells: int = 0

# --- Interno ------------------------------------------------------------------

var _grid = null
var _grid_extent: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Bersaglio dei nemici. Se -gameplay ha registrato `player_position` e' la sua
## posizione, altrimenti il centro dell'arena.
var _focus: Vector3 = Vector3.ZERO
var _sep_buf: PackedInt32Array = PackedInt32Array()
var _built: bool = false
var _registered: bool = false
var _grid_dirty: bool = true
var _contract_node: Node = null

func _ready() -> void:
	_build()
	_register()

## Il contratto, come nodo. Vedi la nota in testa al file: `Game.` non compila
## sotto `--script`, `get_node_or_null("Game")` si'. Va risolto una volta sola:
## nel ciclo di gioco una ricerca per nome a ogni frame sarebbe sprecata.
func _contract() -> Node:
	if _contract_node == null and is_inside_tree():
		_contract_node = get_tree().root.get_node_or_null("Game")
	return _contract_node

## Raggio utile dell'arena, letto dal contratto. Se il contratto non c'e' ancora
## si tiene il valore gia' in campo: meglio un raggio che uno zero.
func _contract_radius() -> float:
	var game := _contract()
	if game != null:
		var r: float = game.arena_radius
		return maxf(r, 6.0)
	return maxf(arena_radius, 6.0)

func _physics_process(delta: float) -> void:
	step(delta)

# --- Costruzione --------------------------------------------------------------

func _build() -> void:
	if _built:
		return
	_built = true
	arena_radius = _contract_radius()
	if seed != 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	# La griglia si riscalda su un quadrato piu' largo dell'arena: i nemici non
	# escono mai, ma il knockback puo' spingerli oltre il raggio utile.
	# `_sync_grid()` fa `setup()` solo quando l'estensione cambia davvero:
	# `setup()` ricrea tutti i secchielli, quindi rifarlo ogni frame sarebbe
	# esattamente l'allocazione nel ciclo di gioco che questo file evita.
	_grid = Grid.new()
	_sync_grid()
	_sep_buf.resize(SEPARATION_CHECKS)
	hit_positions.resize(HITS_KEPT)
	hit_kinds.resize(HITS_KEPT)

	_resize_arrays(MAX_ENEMIES)
	population = clampi(population, 0, MAX_ENEMIES)
	# Disposizione iniziale a pieno: 200 nemici vivi al primo frame.
	for i in MAX_ENEMIES:
		_apply_spawn(i, Spawner.layout_point(arena_radius, i, MAX_ENEMIES, _rng),
			Spawner.pick_kind(_rng))
	count = MAX_ENEMIES
	_resize_arrays(count)
	_rebuild_grid()

func _register() -> void:
	if _registered:
		return
	var game := _contract()
	if game == null:
		push_error("Horde: l'autoload Game non c'e': nessuna API registrata sul contratto")
		return
	_registered = true
	# Dato (piano 5.1): assegnazione diretta del campo.
	game.horde = self
	# Metodi (piano 5.1): forma lunga, perche' GDScript rifiuta l'assegnazione
	# a un nome che e' gia' un `func` del contratto.
	game.register_impl("nearest_enemy", self.nearest_enemy_index)
	game.register_impl("damage_enemy", self.damage_enemy)
	game.register_impl("random_spawn_point", self.random_spawn_point)

func _resize_arrays(n: int) -> void:
	transforms.resize(n)
	colors.resize(n)
	velocities.resize(n)
	hp.resize(n)
	kinds.resize(n)
	timers.resize(n)

func _apply_spawn(i: int, pos: Vector3, kind: int) -> void:
	transforms[i] = pos
	velocities[i] = Vector3.ZERO
	kinds[i] = kind
	hp[i] = E.hp_of(kind)
	timers[i] = 0.0
	colors[i] = E.color_of(kind)

# --- Simulazione --------------------------------------------------------------

## Un passo. Chiamato da `_physics_process`; il test lo chiama direttamente
## per non dipendere dal ciclo di frame.
##
## Nel corpo di questa funzione non c'e' `new()`, `instantiate()` o `queue_free()`:
## si scrive dentro array gia' di capienza e dentro la griglia gia' riscaldata.
func step(delta: float) -> void:
	if not _built or delta <= 0.0:
		return
	arena_radius = _contract_radius()
	# Se l'arena e' cambiata, la griglia va riscaldata di nuovo, altrimenti le
	# celle nuove costerebbero un'allocazione per frame.
	_sync_grid()

	_rebuild_grid()
	hit_count = 0
	var focus := _player_focus()
	for i in count:
		E.step(i, delta, focus, _separation(i), transforms, velocities, timers,
			kinds, arena_radius)
	_sweep_dead()
	_top_up()

## Rimette a posto i nemici rimasti senza vita. `damage_enemy` li toglie subito,
## quindi di norma non trova niente: e' la rete di sicurezza, non il caso normale.
func _sweep_dead() -> void:
	var i := 0
	while i < count:
		if hp[i] <= 0.0:
			_kill(i)
			continue
		i += 1

## Se la popolazione e' scesa, riporta l'orda a `population`.
func _top_up() -> void:
	if not auto_respawn:
		return
	var guard := MAX_ENEMIES
	while count < population and guard > 0:
		guard -= 1
		_spawn_one()

func _spawn_one() -> void:
	if count >= MAX_ENEMIES:
		return
	var kind := Spawner.pick_kind(_rng)
	var pos := Spawner.spawn_point(arena_radius, _player_focus(), _rng, MIN_SPAWN_GAP)
	count += 1
	_resize_arrays(count)
	_apply_spawn(count - 1, pos, kind)
	_grid_dirty = true

## Uccisione per **scambio con l'ultimo**: `transforms[i] = transforms[last]` e
## `resize(count - 1)`. Non si cancella dal vettore: spostare 200 elementi per
## ogni nemico ammazzato costerebbe piu' della query che l'ha ucciso.
func _kill(i: int) -> void:
	var last := count - 1
	if i != last:
		transforms[i] = transforms[last]
		colors[i] = colors[last]
		velocities[i] = velocities[last]
		kinds[i] = kinds[last]
		hp[i] = hp[last]
		timers[i] = timers[last]
	count = last
	_resize_arrays(count)
	kills += 1
	_grid_dirty = true

# --- Griglia ------------------------------------------------------------------

## Riscalda la griglia solo quando l'estensione cambia. `setup()` ricrea tutti i
## secchielli: chiamarlo ogni frame sarebbe l'allocazione nel ciclo di gioco che
## questo file evita, quindi la soglia e' volutamente grossolana.
func _sync_grid() -> void:
	var extent := arena_radius * 1.5
	if absf(extent - _grid_extent) < 0.5:
		return
	_grid_extent = extent
	_grid.setup(Grid.CELL, extent)
	_grid_dirty = true

func _rebuild_grid() -> void:
	_grid.begin_frame()
	for i in count:
		_grid.insert(i, transforms[i])
	grid_unknown_cells = _grid.unknown_cells
	_grid_dirty = false

## Una morte o uno spawn rendono la griglia vecchia. La query la sistema da
## sola invece di ricostruirla 30 volte per frame solo perche' un nemico e'
## morto.
func _ensure_grid() -> void:
	if _grid_dirty:
		_rebuild_grid()

func _separation(i: int) -> Vector3:
	if count < 2:
		return Vector3.ZERO
	var p := transforms[i]
	# `found` con tipo esplicito: `_grid` e' una variabile senza tipo (perche' la
	# griglia si crea in `_build()`), e `:=` su un chiamata che non ha tipo
	# dichiarato non compila.
	var found: int = _grid.collect_into(_sep_buf, p, SEPARATION_RADIUS, transforms,
		SEPARATION_CHECKS)
	var acc := Vector3.ZERO
	for k in found:
		var j: int = _sep_buf[k]
		if j == i:
			continue
		var away := p - transforms[j]
		var l2 := away.length_squared()
		if l2 > 0.0001 and l2 < SEPARATION_RADIUS * SEPARATION_RADIUS:
			acc += away / l2
	if acc.length_squared() <= 0.000001:
		return Vector3.ZERO
	return acc.normalized() * (SEPARATION_FORCE / E.mass_of(kinds[i]))

# --- API del contratto --------------------------------------------------------

## Indice del nemico vivo piu' vicino a `from` entro `radius`, oppure -1.
##
## Restituisce un **indice**, non un nodo: un nemico non e' un nodo (regola 1).
## L'indice e' esattamente quello che `damage_enemy(index, ...)` si aspetta, e il
## contratto fa `as int` su questo valore: si puo' chiamare
## `Game.nearest_enemy(pos, 12.0)` senza errori di cast (piano 5.2).
func nearest_enemy_index(from: Vector3, radius: float) -> int:
	if not _built or count == 0 or radius <= 0.0:
		return -1
	_ensure_grid()
	return _grid.nearest_index(from, radius, transforms)

## Applica `amount` di danno al nemico `index` e gli impartisce `knockback`.
## Se il nemico muore, viene tolto **subito**: dopo questa chiamata `count` e'
## gia' giusto, senza aspettare il frame dopo. Restituisce `true` se e' morto:
## e' l'unico modo per -gameplay di sapere **chi** e' morto senza aggiungere un
## segnale (piano 5.2).
##
## `knockback` e' un **impulso in m/s, gia' scalato dal chiamante**: qui non si
## normalizza e non si somma alla posizione, si somma alla velocita'.
func damage_enemy(index: int, amount: float, knockback: Vector3) -> bool:
	if not _built or index < 0 or index >= count:
		return false
	hp[index] -= amount
	if knockback.length_squared() > 0.000001:
		velocities[index] += knockback * (1.0 - E.knockback_resist_of(kinds[index]))
		timers[index] = 0.12
	_record_hit(transforms[index], kinds[index])
	if hp[index] <= 0.0:
		_kill(index)
		return true
	return false

## Punto di arrivo casuale dentro l'arena. Non puo' restituire `Vector3.ZERO`:
## il contratto usa ZERO come segnale di "non implementato".
func random_spawn_point() -> Vector3:
	if not _built:
		return Vector3(0.0, 0.0, _contract_radius() * 0.5)
	return Spawner.spawn_point(arena_radius, _player_focus(), _rng, MIN_SPAWN_GAP)

# --- Lettura per arena e ui ---------------------------------------------------

## Nome della specie, per un HUD o un log.
func kind_name(index: int) -> String:
	if index < 0 or index >= count:
		return "-"
	return E.KIND_NAMES[E.clamp_kind(kinds[index])]

## Velocita' massima di un tipo di nemico, per il render che deve animarli.
func speed_of_kind(kind: int) -> float:
	return E.speed_of(kind)

## Popolazione viva per specie.
func census() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(E.KIND_COUNT)
	for i in count:
		out[E.clamp_kind(kinds[i])] += 1
	return out

## Celle occupate dalla griglia, per diagnostica.
func occupied_cells() -> int:
	if _grid == null:
		return 0
	return _grid.occupied_cells()

## Qualche secchiello e' traboccato e le query stanno cadendo a scansione
## lineare? Non deve succedere, e il test lo controlla.
func grid_overflowed() -> bool:
	return _grid != null and _grid.overflowed

## Il nemico piu' occupato in una cella, in un frame.
func worst_bucket() -> int:
	return 0 if _grid == null else _grid.worst_bucket

# --- Interno ------------------------------------------------------------------

func _record_hit(pos: Vector3, kind: int) -> void:
	var slot := hit_count % HITS_KEPT
	hit_positions[slot] = pos
	hit_kinds[slot] = kind
	hit_count = mini(hit_count + 1, HITS_KEPT)

## Il bersaglio dei nemici. Se -gameplay ha registrato `player_position` si usa
## quella, altrimenti il centro dell'arena: nessuna dipendenza circolare, e
## nessun `push_warning` se il contratto non e' ancora popolato.
func _player_focus() -> Vector3:
	var game := _contract()
	if game != null and game.has_impl("player_position"):
		var p: Vector3 = game.player_position()
		if p.length_squared() > 0.000001:
			return p
	return _focus

## Se arena ha il giocatore ma non ha registrato `player_position`, puo' dirlo
## qui. Non e' un `get_node("../..")`: e' un dato, non una dipendenza.
func set_focus(pos: Vector3) -> void:
	_focus = pos