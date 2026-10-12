extends SceneTree
## Test dell'orda (terminal-gun-orda). Dimostra con numeri il criterio n. 3 della
## milestone: 200 nemici vivi senza un nodo per nemico.
##
## Verifica, in ordine:
##   1. `count == 200` al riempimento iniziale e `transforms.size() == count`;
##   2. la griglia restituisce **gli stessi indici** di una scansione lineare
##      (stessa distribuzione, stesse query, risultati identici): una griglia
##      piu' veloce ma sbagliata non e' una griglia;
##   3. `nearest_enemy_index` sull'indice atteso, e -1 quando il raggio e' vuoto;
##   4. 1000 query di prossimita' su 200 nemici in meno di 50 ms, e la griglia
##      piu' rapida della scansione lineare: misurati su 8 giri e riportati come
##      minimo e mediana, perche' una corsa sola e' rumore e fallirebbe a caso;
##   5. 600 aggiornamenti in headless: nessun SCRIPT ERROR, nessuna crescita di
##      nodi, oggetti e memoria;
##   6. `damage_enemy` uccide e il conteggio scende, per scambio-ultimo.
##
## E poi la milestone 4, che e' un esperimento su **una costante**
## (`BUCKET_SLOTS` in `src/sim/spatial_grid.gd`) e segue l'ordine dichiarato:
##   7. `grid_dropped()` dice il numero giusto e **non zero** su un traboccamento
##      costruito, e si azzera in `begin_frame()`;
##   8. le tre query danno gli stessi indici della scansione lineare **anche con
##      traboccamento forzato**, e anche senza;
##   9. il tetto dichiarato da m3 sulla scena vera resta sotto la costante, con
##      margine oltre l'escursione del suo campione;
##  10. il costo del riscaldamento e' **misurato** (celle vere della griglia di
##      produzione, non stimate) e stampato;
##  11. la densita' che obbliga la costante e' l'orda isolata che converge, e il
##      numero e' riproducibile perche' la disposizione ha un seme fisso.
##
## Nota sul contratto: `nearest_enemy` e' `-> int` e `damage_enemy` e' `-> bool`
## (piano 5.2), quindi qui si chiama **anche** il contratto, non solo
## `horde.nearest_enemy_index(...)`: se le due strade dessero risposte diverse,
## il gioco in partita punterebbe a un nemico diverso da quello che il test
## crede di aver colpito.

const H = preload("res://tools/test_harness.gd")
const HORDE = preload("res://src/sim/horde.gd")
const GRID = preload("res://src/sim/spatial_grid.gd")
const POOL = preload("res://src/sim/object_pool.gd")
const ENEMY = preload("res://src/sim/enemy.gd")

## Bersaglio dei nemici in questo test: il centro dell'arena, perche' -gameplay
## non e' registrato in questo processo.
const FOCUS := Vector3.ZERO
## Un punto in cui non c'e' e non puo' esserci nessun nemico.
const LONTANO := Vector3(900.0, 0.0, 900.0)

## Oggetto del pool: serve solo per contare, non ha comportamento.
class Thing extends RefCounted:
	var tag: int = 0

## Solo l'inserimento nell'albero. Il corpo del test gira al **primo frame**, in
## `_process`: sotto `--script` l'entrata nell'albero di un nodo aggiunto a
## `root` dalla `_initialize()` passa dalla coda di messaggi, quindi
## `horde._ready()` non e' ancora partito quando `_initialize()` finisce e il
## test leggerebbe `count == 0` su un'orda che non si e' ancora costruita.
## L'orda sotto test. Campo e non variabile di `_initialize()` perche' il corpo
## del test gira al primo frame, e a quel punto `_initialize()` e' gia' tornata.
var _horde: HORDE = null

## Picco di `worst_bucket()` su **tutto** il percorso di 600 passi: e' la
## misura di densita' dell'orda isolata che m4 confronta con quella della scena
## vera. Va raccolto passo per passo perche' `worst_bucket()` torna a zero a
## ogni ricostruzione della griglia: campionato a tratti perderebbe i picchi,
## che sono esattamente la cosa che si vuole misurare.
var _picco: int = 0

func _initialize() -> void:
	_horde = HORDE.new()
	_horde.name = "Orda"
	# Il test vuole vedere il conteggio scendere quando un nemico muore: senza
	# questo, `_top_up()` lo riemPIREbbe entro lo stesso passo.
	_horde.auto_respawn = false
	root.add_child(_horde)

## `SceneTree._process` restituisce `true` per chiudere il ciclo: e' il `quit()`
## del test, e non viene prima perche' a questo punto l'orda e' viva.
func _process(_delta: float) -> bool:
	_run()
	return true

func _run() -> void:
	var h := H.new()
	var horde: HORDE = _horde
	if horde == null:
		h.fail("l'orda aggiunta in _initialize() non e' piu' nell'albero")
		quit(h.finish("orda"))
		return

	_population(h, horde)
	_no_node_per_enemy(h, horde)
	_registration(h, horde)
	_grid_matches_linear(h)
	_nearest(h, horde)
	_spawn_points(h, horde)
	_query_budget(h, horde)
	_object_pool(h)
	_burn_in(h, horde)

	# m4: lo strumento di misura, poi il costo, poi il tetto. La densita' e il
	# valore stanno in fondo, su un percorso proprio a seme fisso: vedi la nota
	# in `_m4_densita` perche' non puo' stare sul percorso casuale di sopra.
	_m4_contatore(h, horde)
	_m4_query(h)
	_m4_tetto(h)
	_m4_costo(h, horde)

	_damage_kills(h, horde)

	_m4_densita(h, horde)

	quit(h.finish("orda"))

# --- 1. Popolazione -----------------------------------------------------------

func _population(h, horde: HORDE) -> void:
	h.eq(horde.count, 200, "nemici vivi al riempimento iniziale")
	h.eq(horde.transforms.size(), horde.count,
		"transforms e' lunga quanto count: e' l'invariante che arena usa per il MultiMesh")
	h.eq(horde.colors.size(), horde.count, "un colore per nemico")
	h.eq(horde.velocities.size(), horde.count, "velocita': array parallelo allineato")
	h.eq(horde.hp.size(), horde.count, "hp: array parallelo allineato")
	h.eq(horde.kinds.size(), horde.count, "specie: array parallelo allineato")
	h.eq(horde.timers.size(), horde.count, "timer: array parallelo allineato")

	var census := horde.census()
	var somma := 0
	for k in census:
		somma += k
	h.eq(somma, horde.count, "il censimento conta tutti i nemici")
	h.eq(census.size(), ENEMY.KIND_COUNT, "censimento: una voce per specie")

	# un giro solo, con i numeri fuori: 200 assertioni sullo stesso dato
	# costerebbero piu' di quanto dicano
	var dentro := 0
	var finiti := 0
	var vivi := 0
	var specie_ok := 0
	for i in horde.count:
		var p := horde.transforms[i]
		if Vector2(p.x, p.z).length() <= horde.arena_radius + 0.001:
			dentro += 1
		if is_finite(p.x) and is_finite(p.y) and is_finite(p.z):
			finiti += 1
		if horde.hp[i] > 0.0:
			vivi += 1
		if horde.kinds[i] >= 0 and horde.kinds[i] < ENEMY.KIND_COUNT:
			specie_ok += 1
	h.eq(dentro, horde.count, "tutti i nemici nascono dentro l'arena")
	h.eq(finiti, horde.count, "nessuna posizione spazzatura")
	h.eq(vivi, horde.count, "nessun nemico nasce morto")
	h.eq(specie_ok, horde.count, "ogni specie e' in tabella")
	h.check(census[ENEMY.RUNNER] > 0, "qualche runner")
	h.check(census[ENEMY.BOSS] < horde.count / 4,
		"il boss resta raro: %d su %d" % [census[ENEMY.BOSS], horde.count])
	print("orda: %d nemici su %d celle, specie %s, raggio %.1f m"
		% [horde.count, horde.occupied_cells(), str(census), horde.arena_radius])

# --- 2. Nessun nodo per nemico ------------------------------------------------

func _no_node_per_enemy(h, horde: HORDE) -> void:
	var nodi := _count_nodes(root)
	print("orda: %d nemici vivi con %d nodi in tutta la scena (criterio: sotto 120)"
		% [horde.count, nodi])
	h.check(nodi < 120,
		"node_count deve stare sotto 120 con 200 nemici vivi: sono %d" % nodi)
	h.check(horde.count == 200, "e i nemici sono davvero 200 mentre si conta")
	h.eq(horde.get_child_count(), 0,
		"l'orda non ha figli: nessun nodo per nemico, nemmeno per accenderlo")

# --- 3. Registrazione sul contratto ------------------------------------------

func _registration(h, horde: HORDE) -> void:
	var game := _game()
	h.check(game != null, "l'autoload Game deve esistere: horde.gd si registra su di lui")
	h.check(game.horde == horde, "Game.horde = self nel _ready")
	for api in ["nearest_enemy", "damage_enemy", "random_spawn_point"]:
		h.check(game.has_impl(api), "register_impl(%s) deve aver registrato l'API" % api)
	h.check(not game.has_impl("player_position"),
		"player_position e' di -gameplay: registrarla qui sarebbe una doppia registrazione")

# --- 4. La griglia contro la scansione lineare -------------------------------

## Distribuzione nota: un incrocio sulle celle (nomi di confine), una griglia
## regolare, un mucchio a caso. Se un nemico finisce nella cella sbagliata, o se
## un secchiello perde un indice, qui si vede.
func _grid_matches_linear(h) -> void:
	h.eq(GRID.CELL, 4.0, "il piano fissa la cella a 4 unita'")
	var pts := _distribution(400)
	var grid: GRID = GRID.new()
	grid.setup(GRID.CELL, 30.0)
	h.eq(grid.unknown_cells, 0, "il riscaldamento ha creato le celle")

	grid.begin_frame()
	for i in pts.size():
		grid.insert(i, pts[i])
	h.eq(grid.unknown_cells, 0,
		"tutti i punti della distribuzione stanno nelle celle riscaldate")

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260906
	var vuoti := 0
	var sbagliati := 0
	var discordi := 0
	var primo_motivo := ""
	var atteso := PackedInt32Array()
	var got := PackedInt32Array()
	for t in 300:
		var q := Vector3(rng.randf_range(-32.0, 32.0), 0.0, rng.randf_range(-32.0, 32.0))
		var r := rng.randf_range(0.5, 9.0)
		GRID.linear_fill_radius(atteso, q, r, pts, pts.size())
		grid.fill_radius(got, q, r, pts)
		atteso.sort()
		got.sort()
		if atteso.is_empty():
			vuoti += 1
		if not _same_indices(got, atteso):
			sbagliati += 1
			if primo_motivo == "":
				primo_motivo = "q=(%.2f, %.2f) r=%.2f: griglia %d indici, lineare %d" \
					% [q.x, q.z, r, got.size(), atteso.size()]
		var lin := GRID.linear_nearest(q, r, pts, pts.size())
		var gidx := grid.nearest_index(q, r, pts)
		if gidx != lin:
			discordi += 1
			var dl := 1e9 if lin < 0 else q.distance_squared_to(pts[lin])
			var dg := 1e9 if gidx < 0 else q.distance_squared_to(pts[gidx])
			if absf(dl - dg) > 0.000001 and primo_motivo == "":
				primo_motivo = "nearest discorda su q=(%.2f, %.2f): griglia %d (d2 %.6f), lineare %d (d2 %.6f)" \
					% [q.x, q.z, gidx, dg, lin, dl]
	h.check(sbagliati == 0,
		"300 query con raggio: la griglia deve dare gli stessi indici della scansione"
		+ ("" if primo_motivo == "" else "; prima discordanza: " + primo_motivo))
	h.check(discordi == 0,
		"300 query: il piu' vicino deve coincidere con la scansione lineare"
		+ ("" if primo_motivo == "" else "; " + primo_motivo))
	h.check(vuoti > 0, "il confronto deve contenere anche query con raggio vuoto")
	print("orda: griglia e scansione lineare coincidono su 300 query (%d con raggio vuoto)" % vuoti)

	# Fuori dal quadrato riscaldato la cella non esiste, ma la risposta deve
	# essere giusta lo stesso: e' il caso in cui una griglia "ottimizzata"
	# perde un nemico, e meglio che se ne accorga qui.
	var fuori := Vector3(500.0, 0.0, 500.0)
	grid.begin_frame()
	grid.insert(pts.size(), fuori)
	h.eq(grid.unknown_cells, 1, "una cella nuova fuori dal riscaldamento: contata")
	h.eq(grid.nearest_index(fuori + Vector3(1.0, 0.0, 0.0), 5.0, _plus_one(pts, fuori)),
		pts.size(), "un nemico fuori dal quadrato riscaldato deve essere trovato lo stesso")

## `n` punti: incrocio sulle celle, griglia regolare, mucchio a caso.
func _distribution(n: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234567
	# un incrocio: coordinate su multipli esatti della cella, e due celle vicine
	pts.append(Vector3(4.0, 0.0, 4.0))
	pts.append(Vector3(8.0, 0.0, 4.0))
	pts.append(Vector3(4.0, 0.0, 8.0))
	pts.append(Vector3(-8.0, 0.0, -8.0))
	pts.append(Vector3(0.0, 0.0, 0.0))
	# una griglia regolare, un punto per cella
	for gz in 12:
		for gx in 12:
			pts.append(Vector3(float(gx) * 2.0 - 12.0, 0.0, float(gz) * 2.0 - 12.0))
	# il mucchio a caso
	for _i in maxi(0, n - pts.size()):
		pts.append(Vector3(rng.randf_range(-26.0, 26.0), 0.0, rng.randf_range(-26.0, 26.0)))
	return pts

func _plus_one(pts: PackedVector3Array, extra: Vector3) -> PackedVector3Array:
	var out := pts.duplicate()
	out.append(extra)
	return out

func _same_indices(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true

# --- 5. nearest ---------------------------------------------------------------

func _nearest(h, horde: HORDE) -> void:
	var k := 37
	h.check(k < horde.count, "indice di prova dentro la folla")
	var q := horde.transforms[k] + Vector3(0.03, 0.0, 0.03)
	var got := horde.nearest_enemy_index(q, 1.5)
	h.eq(got, k, "nearest_enemy_index deve dare l'indice atteso")
	h.eq(got, GRID.linear_nearest(q, 1.5, horde.transforms, horde.count),
		"l'indice coincide con la scansione lineare")

	# il vicino cambia: la risposta deve seguire l'indice, non restare ferma
	h.eq(horde.nearest_enemy_index(horde.transforms[90] + Vector3(0.02, 0.0, 0.0), 1.0),
		90, "un altro nemico e' il piu' vicino")

	# raggio vuoto: -1, mai un indice a caso
	h.eq(horde.nearest_enemy_index(LONTANO, 4.0), -1, "fuori dall'arena il risultato e' -1")
	h.eq(horde.nearest_enemy_index(LONTANO, 0.001), -1,
		"un millimetro di raggio non contiene nessuno")
	h.eq(horde.nearest_enemy_index(horde.transforms[0], 0.0), -1,
		"raggio zero non e' una ricerca")
	h.eq(horde.nearest_enemy_index(Vector3.ZERO, -3.0), -1, "raggio negativo: niente")

	# stessa domanda attraverso il contratto: `as int` su un int non deve dare
	# "Invalid cast", e l'indice deve essere lo stesso (piano 5.2)
	h.eq(_game().nearest_enemy(q, 1.5), k,
		"Game.nearest_enemy (-> int) restituisce lo stesso indice")
	h.eq(_game().nearest_enemy(LONTANO, 4.0), -1,
		"Game.nearest_enemy (-> int) fuori raggio restituisce -1")

# --- 6. Punti di spawn --------------------------------------------------------

func _spawn_points(h, horde: HORDE) -> void:
	var peggiore := 0.0
	var rotte := 0
	for _i in 400:
		var p := horde.random_spawn_point()
		if p == Vector3.ZERO:
			rotte += 1
			continue
		peggiore = maxf(peggiore, Vector2(p.x, p.z).length())
		if p.distance_to(FOCUS) < 12.0 - 0.001 or Vector2(p.x, p.z).length() > horde.arena_radius + 0.001:
			rotte += 1
	h.eq(rotte, 0,
		"random_spawn_point: mai ZERO, sempre dentro l'arena e lontano dal giocatore")
	h.positive(peggiore, "i punti di spawn si spargono sull'arena")
	h.check(peggiore > horde.arena_radius * 0.5,
		"i punti di spawn arrivano fino al bordo: %d su %.1f" % [int(peggiore), horde.arena_radius])

# --- 7. Budget di 1000 query --------------------------------------------------
#
# Perche' piu' giri e non uno: una corsa sola e' rumore. Il scheduling del
# processore, la frequenza che sale e scende e la cache che si scalda spostano
# due misure consecutive del 20-30%, e un'asserzione con 180 us di margine su
# un numero che gira attorno a 9000 fallisce a caso. Qui si gira piu' volte
# prendendo il **minimo**: il minimo di N corse e' la stima piu' vicina a "quanto
# costa davvero", perche' tutto quello che c'e' dentro e' rumore che si somma solo.

## Giri misurati, oltre a quello di scaldamento.
const BENCH_ROUNDS := 8
## Query per giro: il criterio della milestone parla di 1000.
const BENCH_PER_ROUND := 1000
## Raggio delle query, metri.
const BENCH_RADIUS := 6.0

func _query_budget(h, horde: HORDE) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var queries := PackedVector3Array()
	queries.resize(BENCH_PER_ROUND)
	for i in BENCH_PER_ROUND:
		queries[i] = Vector3(rng.randf_range(-28.0, 28.0), 0.0, rng.randf_range(-28.0, 28.0))

	# Scaldamento di **entrambe** le strade: senza, la scansione lineare paga la
	# prima volta il costo di una funzione mai chiamata e il confronto esce
	# falsamente a suo favore.
	for i in BENCH_PER_ROUND:
		horde.nearest_enemy_index(queries[i], BENCH_RADIUS)
		GRID.linear_nearest(queries[i], BENCH_RADIUS, horde.transforms, horde.count)

	var griglia := PackedInt64Array()
	var lineare := PackedInt64Array()
	griglia.resize(BENCH_ROUNDS)
	lineare.resize(BENCH_ROUNDS)
	for giro in BENCH_ROUNDS:
		# ordine alternato: se la CPU e' piu' veloce alla fine di un giro, non
		# puo' favorire sempre la stessa delle due
		var inverti := giro % 2 == 1
		if inverti:
			var a := _tempo_lineare(queries, horde)
			var b := _tempo_griglia(queries, horde)
			lineare[giro] = a
			griglia[giro] = b
		else:
			var a := _tempo_griglia(queries, horde)
			var b := _tempo_lineare(queries, horde)
			griglia[giro] = a
			lineare[giro] = b

	var g_min := _minimo(griglia)
	var l_min := _minimo(lineare)
	var g_med := _mediano(griglia)
	var l_med := _mediano(lineare)
	var rapporto := float(l_min) / maxf(1.0, float(g_min))
	var rapporto_med := float(l_med) / maxf(1.0, float(g_med))

	print("orda: %d query x %d giri su %d nemici, raggio %.1f m"
		% [BENCH_PER_ROUND, BENCH_ROUNDS, horde.count, BENCH_RADIUS])
	print("orda: griglia min %d us, mediana %d us | lineare min %d us, mediana %d us"
		% [g_min, g_med, l_min, l_med])
	print("orda: la griglia e' %.2f volte piu' rapida sul minimo, %.2f sulla mediana"
		% [rapporto, rapporto_med])
	print("orda: griglia per giro %s" % str(griglia))
	print("orda: lineare per giro %s" % str(lineare))
	print("orda: secchiello piu' affollato %d su %d, traboccamenti: %s"
		% [horde.worst_bucket(), GRID.BUCKET_SLOTS, str(horde.grid_overflowed())])

	h.check(not horde.grid_overflowed(),
		"nessun secchiello traboccato durante le query: la griglia stava cadendo a scansione lineare")
	h.check(g_min < 50000,
		"%d query di prossimita' su %d nemici sotto i 50 ms: %d us (minimo di %d giri)"
			% [BENCH_PER_ROUND, horde.count, g_min, BENCH_ROUNDS])
	h.check(g_med < 50000,
		"e anche la mediana dei giri sta sotto i 50 ms: %d us" % g_med)
	h.check(rapporto > 1.0,
		"la griglia deve battere la scansione lineare: %.2f volte (minimo su minimo su %d giri)"
			% [rapporto, BENCH_ROUNDS])
	h.check(rapporto_med > 1.0,
		"e deve batterla anche sulla mediana dei giri, non solo sul caso fortunato: %.2f volte"
			% rapporto_med)

func _tempo_griglia(queries: PackedVector3Array, horde: HORDE) -> int:
	var t0 := Time.get_ticks_usec()
	for i in queries.size():
		horde.nearest_enemy_index(queries[i], BENCH_RADIUS)
	return Time.get_ticks_usec() - t0

func _tempo_lineare(queries: PackedVector3Array, horde: HORDE) -> int:
	var t0 := Time.get_ticks_usec()
	for i in queries.size():
		GRID.linear_nearest(queries[i], BENCH_RADIUS, horde.transforms, horde.count)
	return Time.get_ticks_usec() - t0

func _minimo(values: PackedInt64Array) -> int:
	var m := values[0]
	for v in values:
		if v < m:
			m = v
	return m

## Mediana: copia, ordina, prende il centro. Fuori dal ciclo di gioco (e' un
## benchmark), quindi qui l'allocazione non e' un peccato.
func _mediano(values: PackedInt64Array) -> int:
	var copie := values.duplicate()
	copie.sort()
	return copie[copie.size() / 2]

# --- 8. Pool ------------------------------------------------------------------

func _object_pool(h) -> void:
	var pool: POOL = POOL.new()
	pool.configure(func() -> Object: return Thing.new(), 32)
	h.eq(pool.created(), 32, "il riscaldamento crea gli oggetti una volta sola")
	h.eq(pool.free_count(), 32, "all'inizio sono tutti liberi")
	h.eq(pool.live(), 0, "nessuno e' in uso all'inizio")

	var presi: Array = []
	for _i in 32:
		var oggetto: Object = pool.acquire()
		h.check(oggetto != null, "acquire entro capienza restituisce un oggetto")
		presi.append(oggetto)
	h.eq(pool.live(), 32, "tutti in uso")
	h.eq(pool.created(), 32, "acquire non ha creato niente")
	h.check(pool.acquire() == null, "a capienza piena acquire da null, non crea")
	h.eq(pool.rejected(), 1, "l'acquire a vuoto e' contato")

	for oggetto in presi:
		h.check(pool.release(oggetto), "release di un oggetto del pool")
	h.eq(pool.live(), 0, "tutti rilasciati")
	h.eq(pool.free_count(), 32, "la capienza e' tornata quella di prima")

	# 100000 cicli acquire/release: created() non deve muoversi di una unita'
	for _i in 100000:
		var oggetto: Object = pool.acquire()
		pool.release(oggetto)
	h.eq(pool.created(), 32,
		"100000 cicli non devono creare un solo oggetto nuovo: created() e' %d" % pool.created())
	h.eq(pool.live(), 0, "nessuna perdita di oggetti dopo 100000 cicli")
	print("orda: pool, 100000 cicli acquire/release, oggetti creati in tutto: %d" % pool.created())

# --- 9. 600 aggiornamenti -----------------------------------------------------

func _burn_in(h, horde: HORDE) -> void:
	h.eq(horde.count, 200, "si parte da 200")
	var nodi0 := _count_nodes(root)
	var obj0 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var mem0 := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var passati := 0
	var morti := 0

	for s in 600:
		horde.step(1.0 / 60.0)
		# il picco della densita' si legge su **ogni** passo: il numero torna a
		# zero a ogni ricostruzione, quindi qui si chiude il campione di m4
		_picco = maxi(_picco, horde.worst_bucket())
		passati += 1
		# una morte ogni 5 passi: lo scambio-ultimo viene esercitato 120 volte,
		# quindi i 600 passi non sono una passeggiata
		if s % 5 == 0 and horde.count > 40:
			horde.damage_enemy(s % 37, 9999.0, Vector3(2.0, 0.0, 0.0))
			morti += 1

	h.eq(passati, 600, "600 aggiornamenti in headless senza SCRIPT ERROR")
	h.eq(morti, 120, "una morte ogni 5 passi")
	h.eq(horde.count, 200 - morti, "il conteggio scende di uno per ogni morte")
	h.eq(horde.transforms.size(), horde.count, "transforms resta allineata a count dopo le morti")
	h.eq(horde.colors.size(), horde.count, "colors resta allineata a count dopo le morti")
	h.eq(horde.hp.size(), horde.count, "anche hp resta allineata a count")
	h.eq(horde.kills, morti, "il contatore delle uccisioni")

	var dentro := 0
	var vivi := 0
	for i in horde.count:
		var p := horde.transforms[i]
		if is_finite(p.x) and is_finite(p.y) and is_finite(p.z):
			dentro += 1
		if horde.hp[i] > 0.0:
			vivi += 1
	h.eq(dentro, horde.count, "nessun nemico rimasto con una posizione spazzatura")
	h.eq(vivi, horde.count, "nessun nemico sopravvisso con hp negativo")
	h.check(horde.worst_bucket() <= GRID.BUCKET_SLOTS,
		"nessun secchiello traboccato: il piu' affollato ne aveva %d su %d"
		% [horde.worst_bucket(), GRID.BUCKET_SLOTS])
	h.check(not horde.grid_overflowed(), "nessuna caduta a scansione lineare")
	h.eq(horde.grid_unknown_cells, 0,
		"nessuna cella nuova dopo 600 passi: nel ciclo di gioco non si alloca")
	# i due numeri non possono discordare: nessun rifiuto significa nessun
	# traboccamento, e su un'orda che traboccasse la griglia non starebbe
	# guardando niente
	h.eq(horde.grid_dropped(), 0,
		"nessun nemico rifiutato dalla griglia in 600 passi")
	h.check(not horde.grid_overflowed(), "e nessun traboccamento")
	# NOTA: qui non si asserisce `worst_bucket() < BUCKET_SLOTS`: e' la
	# tautologia che m3 ha gia' registrato (il contatore si ferma a
	# `BUCKET_SLOTS` per costruzione). Il segnale che nessuno e' stato perso e'
	# il contatore qui sopra, che puo' dire solo la verita'.
	h.check(_picco > 0, "il percorso deve aver avuto un picco da misurare: %d" % _picco)

	var nodi1 := _count_nodes(root)
	var obj1 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var mem1 := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	h.eq(nodi1, nodi0, "600 passi non aggiungono nodi")
	h.check(obj1 <= obj0 + 16,
		"600 passi non aggiungono oggetti: %d contro %d" % [obj1, obj0])
	h.check(mem1 - mem0 < 4 * 1024 * 1024,
		"600 passi non gonfiano la memoria: +%d KB" % ((mem1 - mem0) / 1024))
	print("orda: 600 passi e %d morti, nodi %d -> %d, oggetti %d -> %d, memoria +%d KB"
		% [morti, nodi0, nodi1, obj0, obj1, (mem1 - mem0) / 1024])
	print("orda: densita' dell'orda isolata su 600 passi, picco %d nemici in una cella su %d slot, rifiuti %d"
		% [_picco, GRID.BUCKET_SLOTS, horde.grid_dropped()])

# --- 10. damage_enemy uccide --------------------------------------------------

func _damage_kills(h, horde: HORDE) -> void:
	var prima := horde.count
	h.eq(prima, 80, "si riparte dagli 80 superstiti")

	var buco := 5
	var ultimo := horde.transforms[prima - 1]
	var hp_ultimo := horde.hp[prima - 1]
	var kind_ultimo := horde.kinds[prima - 1]
	var uccisioni := horde.kills

	var ucciso: bool = _game().damage_enemy(buco, 9999.0, Vector3.ZERO)
	h.check(ucciso, "Game.damage_enemy (-> bool) restituisce true quando il nemico muore")
	h.eq(horde.count, prima - 1, "damage_enemy uccide e il conteggio scende subito")
	h.eq(horde.transforms.size(), prima - 1, "transforms accorciata con lo scambio-ultimo")
	h.eq(horde.hp.size(), prima - 1, "anche hp e' accorciata")
	h.eq(horde.kills, uccisioni + 1, "il contatore delle uccisioni e' salito")
	h.vec_near(horde.transforms[buco], ultimo, 0.0001,
		"scambio-ultimo: nel buco deve esserci il vecchio ultimo, non uno zero")
	h.eq(horde.hp[buco], hp_ultimo, "scambio-ultimo: anche hp spostato")
	h.eq(horde.kinds[buco], kind_ultimo, "scambio-ultimo: anche la specie spostata")

	# fuori indice: nessun crash, nessun effetto e `false` (il contratto fa
	# `as bool` sul valore di ritorno: con `void` andrebbe in errore in partita)
	h.check(not _game().damage_enemy(prima, 10.0, Vector3.ZERO),
		"indice == count: false, nessun crash")
	h.check(not _game().damage_enemy(-1, 10.0, Vector3.ZERO),
		"indice negativo: false, nessun crash")
	h.check(not _game().damage_enemy(999999, 10.0, Vector3.ZERO),
		"indice assurdo: false, nessun crash")
	h.eq(horde.count, prima - 1, "un indice fuori range non tocca niente")

	# knockback: almeno 0.3 unita' sul nemico colpito (criterio n. 4 della
	# milestone, verificato dal lato dell'orda perche' e' qui che la spinta
	# viene applicata)
	var j := 4
	var v0 := horde.velocities[j]
	var hp0 := horde.hp[j]
	var sopravvive: bool = _game().damage_enemy(j, 1.0, Vector3(4.0, 0.0, 0.0))
	h.check(not sopravvive, "Game.damage_enemy (-> bool) su un colpo non letale da' false")
	var spinta := (horde.velocities[j] - v0).length()
	h.check(spinta >= 0.3, "knockback di almeno 0.3 unita': %.3f" % spinta)
	h.near(horde.hp[j], hp0 - 1.0, 0.0001, "un colpo toglie hp")
	h.eq(horde.count, prima - 1, "un colpo non letale non ammazza nessuno")
	h.check(horde.hit_count > 0, "i colpi vengono ricordati per sfx e flash")
	h.check(ENEMY.KIND_NAMES.has(horde.kind_name(j)), "kind_name da' un nome in tabella")
	h.eq(horde.kind_name(99999), "-", "kind_name fuori range non crasha")

	# svuotare l'orda: -1 quando non resta nessuno
	var svuotati := 0
	while horde.count > 0:
		horde.damage_enemy(0, 9999.0, Vector3.ZERO)
		svuotati += 1
		if svuotati > 100:
			break
	h.eq(horde.count, 0, "orda svuotata")
	h.eq(horde.transforms.size(), 0, "transforms vuota")
	h.eq(horde.colors.size(), 0, "colors vuota")
	h.eq(horde.nearest_enemy_index(Vector3.ZERO, 1000.0), -1,
		"senza nemici la vicina piu' vicina da' -1")

	# il riempimento automatico: da 0 a 200 in un passo, senza allocare celle
	horde.auto_respawn = true
	horde.step(1.0 / 60.0)
	h.eq(horde.count, 200, "l'orda si riempie da sola fino a population")
	h.eq(horde.transforms.size(), horde.count, "allineata dopo il riempimento")
	h.eq(horde.colors.size(), horde.count, "colori allineati dopo il riempimento")
	h.eq(horde.grid_unknown_cells, 0, "i 200 spawn nuovi non hanno creato celle")
	h.check(horde.nearest_enemy_index(Vector3.ZERO, 100.0) >= 0,
		"dopo il riempimento si trova qualcuno")
	print("orda: svuotata e riempita di nuovo, uccisioni in tutto %d, specie %s"
		% [horde.kills, str(horde.census())])

# --- m4: BUCKET_SLOTS, il contatore dei rifiuti e il costo misurato ----------
#
# L'esperimento di m4 e' su **una costante**, `BUCKET_SLOTS` in
# `src/sim/spatial_grid.gd`, e segue l'ordine dichiarato dal piano: prima lo
# strumento di misura, poi il costo, poi la densita', e solo dopo il valore.
# Le quattro sezioni qui sotto sono in quell'ordine.
#
# ## Perche' il contatore viene prima del valore, e non e' pignoleria
#
# Il traboccamento e' un **fallback**, e il fallback e' corretto ma lento: le
# query cadono a scansione lineare e restituiscono gli stessi indici. Quindi
# abbassare `BUCKET_SLOTS` non puo' rompere la correttezza, puo' solo costare
# tempo e, se diventa sistematico, **nascondere nemici alle query**.
# `grid_overflowed()` e' un booleano e non distingue "un nemico perso" da
# "199 persi", quindi non basta a scegliere un valore: `grid_dropped()` e' il
# numero che distingue, e senza di esso la scelta sarebbe un'opinione.
#
## Lo strumento si dichiara **prima** dell'esperimento perche' se arrivasse
## dopo, il primo valore misurato sarebbe gia' stato preso con la riga vecchia
## e nessuno lo saprebbe.

## Nemici in piu' di `BUCKET_SLOTS` che il test mette nella **stessa cella**,
## per costruire un traboccamento vero invece di aspettarlo. Non e' una
## costante scelta a piacere: il numero atteso di rifiuti e' esattamente questo,
## quindi se `BUCKET_SLOTS` cambiasse il test continuerebbe a dire la verita'
## sul valore nuovo invece di misurare aria.
const RIFIUTI := 5

## Query per giro della batteria di m4.
const M4_QUERY := 200

## Tetto dichiarato da m3 sulla **scena vera** (`GRID_CEILING` in
## `tests/test_arena.gd`, che non e' di questa foglia) e l'escursione del suo
## campione: `worst_bucket` min 4, mediana 5, max 7. Servono a dire se
## `BUCKET_SLOTS` continua a stare sopra quel tetto **con margine**, che e' la
## condizione che m3 aveva dichiarato e che un valore piu' stretto avrebbe
## potuto invalidare. Copiati qui perche' il file di `-arena` non e' di questa
## foglia e non va importato: sono i due numeri del tetto, non il tetto stesso.
const TETTO_SCENA_VERA := 11
const ESCURSIONE_SCENA_VERA := 3

## Valori candidati della tabella dei rifiuti: il tetto della scena vera piu'
## margine, il campione dell'orda isolata, e la trappola da non scegliere
## (31 = `BUCKET_SLOTS - 1`, la costante tarata sul caso che si vuole evitare).
const CANDIDATI := [16, 24, 28, 31]

## Passo di simulazione, fisso. Il test guida il tempo a mano e i numeri
## devono essere gli stessi a ogni avvio.
const DT := 1.0 / 60.0

## Seme della disposizione con cui si misura la densita' in m4. Lo **stesso**
## che fissa `tests/test_gameloop.gd`: e' il seme della banda che il piano
## dichiara, e i numeri di questa sezione sono quindi confrontabili con quelli e
## riproducibili a ogni avvio. Sul seme 177 quel test misura un picco di 28.
const SEME_DENSITA := 177

# --- m4.1: il contatore dice il numero giusto, e non zero --------------------

## Il contatore su un caso **costruito**: `BUCKET_SLOTS + RIFIUTI` nemici nello
## stesso punto cadono nella stessa cella, `BUCKET_SLOTS` entrano e gli altri
## `RIFIUTI` vengono rifiutati. Il numero atteso e' calcolato dalla costante e
## non scritto a mano: un contatore cablato a zero, o un flag mascherato da
## contatore, qui dice FAIL.
func _m4_contatore(h, horde: HORDE) -> void:
	var punti := _m4_punti(GRID.BUCKET_SLOTS + RIFIUTI)
	var grid: GRID = GRID.new()
	grid.setup(GRID.CELL, 30.0)
	grid.begin_frame()
	for i in punti.size():
		grid.insert(i, punti[i])

	h.eq(grid.dropped, RIFIUTI,
		"il contatore deve dire quanti nemici ha rifiutato la cella piena: %d" % RIFIUTI)
	h.check(grid.dropped > 0,
		"e non deve essere zero quando qualcuno e' stato rifiutato")
	h.check(grid.overflowed,
		"un rifiuto accende anche il flag: i due non possono discordare")
	h.eq(grid.unknown_cells, 0,
		"nessuna cella nuova: il traboccamento e' dentro quelle riscaldate")

	# punto 3 del contratto congelato: si azzera in `begin_frame()`, non in
	# `insert()`, perche' `insert()` non conosce l'inizio di un frame
	grid.begin_frame()
	h.eq(grid.dropped, 0, "begin_frame() azzera il contatore dei rifiuti")
	h.check(not grid.overflowed, "e azzera anche il flag")
	grid.insert(0, punti[0])
	h.eq(grid.dropped, 0, "un insert in un secchiello vuoto non e' un rifiuto")

	# Sull'orda sotto test il caso normale: nessun rifiuto e nessun
	# traboccamento. Il caso con il traboccamento e' quello costruito qui
	# sopra: se si aspettasse che una partita trabocchi per misurare un
	# contatore, il contatore direbbe quasi sempre zero e non misurerebbe niente.
	h.eq(horde.grid_dropped(), 0,
		"sull'orda viva nessun nemico e' stato rifiutato dalla griglia")
	h.check(not horde.grid_overflowed(),
		"e nessun traboccamento: i due numeri non possono discordare")

## Il tetto dichiarato da m3 resta **non tautologico**: sotto `BUCKET_SLOTS`, e
## con un margine maggiore dell'escursione dell'intero campione da cui e' stato
## derivato. E' la condizione che un valore piu' stretto avrebbe potuto
## invalidare, quindi va verificata a ogni esecuzione e non dichiarata una volta.
func _m4_tetto(h) -> void:
	h.check(TETTO_SCENA_VERA < GRID.BUCKET_SLOTS,
		"il tetto dichiarato da m3 deve stare sotto la costante: %d contro %d"
			% [TETTO_SCENA_VERA, GRID.BUCKET_SLOTS])
	h.check(GRID.BUCKET_SLOTS - TETTO_SCENA_VERA > ESCURSIONE_SCENA_VERA,
		"e con un margine maggiore dell'escursione del suo campione (%d): %d - %d = %d"
			% [ESCURSIONE_SCENA_VERA, GRID.BUCKET_SLOTS, TETTO_SCENA_VERA,
				GRID.BUCKET_SLOTS - TETTO_SCENA_VERA])
	# e il tetto non deve essere una soglia arbitraria messa li' per far passare:
	# sotto di esso il campione della scena vera ci sta tutto
	h.check(GRID.BUCKET_SLOTS > TETTO_SCENA_VERA + ESCURSIONE_SCENA_VERA,
		"la costante deve stare sopra tetto piu' escursione")

# --- m4.2: il costo, misurato -------------------------------------------------
#
# Il numero di celle non si deduce da un commento: viene da
# `ceil(extent / CELL) + margin_cells`, con l'estensione che passa
# `_sync_grid()`, cioe' `arena_radius * 1.5`. Qui viene **letto** dalla griglia
# di produzione con `occupied_cells()` e confrontato con quella formula: se
# qualcuno cambia una delle due, il commento di `spatial_grid.gd` smette di
# valere e questo test lo dice invece di lasciarlo passare.

func _m4_costo(h, horde: HORDE) -> void:
	var extent := horde.arena_radius * 1.5
	var lato := ceili(extent / GRID.CELL) + 3 # 3 = margin_cells di default di setup()
	var celle_attese := (2 * lato + 1) * (2 * lato + 1)
	var celle := horde.occupied_cells()

	h.eq(celle, celle_attese,
		"le celle riscaldate sono quelle che setup() promette all'estensione data")
	h.eq(GRID.BUCKET_SIZE, GRID.BUCKET_SLOTS + 1,
		"il secchiello e' il contatore in testa piu' gli slot")
	var byte := celle * GRID.BUCKET_SIZE * 4

	# Il costo vero e' piu' del carico utile: il dizionario e l'intestazione di
	# ogni `PackedInt32Array` stannoanch'essi sull'heap. Si misura un delta,
	# che e' rumoroso e quindi solo stampato: quello che il commento dichiara e'
	# il carico utile, che e' l'unica parte che `BUCKET_SLOTS` controlla.
	var mem0 := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var replica: GRID = GRID.new()
	replica.setup(GRID.CELL, extent)
	var mem1 := int(Performance.get_monitor(Performance.MEMORY_STATIC))

	print("orda: m4 riscaldamento: extent %.1f = %.1f x 1.5, %d celle per lato, %d celle in tutto"
		% [horde.arena_radius, extent, lato, celle])
	print("orda: m4 riscaldamento: %d interi da 4 byte per secchiello, %d B di carico utile (%.1f KiB), heap misurato +%d KB"
		% [GRID.BUCKET_SIZE, byte, byte / 1024.0, (mem1 - mem0) / 1024])

	h.check(celle > 0, "il riscaldamento ha prodotto delle celle")
	h.check(byte > 0, "e il loro carico utile e' un numero")

# --- m4.3: la densita', e quale dei due casi obbliga --------------------------
#
# I due numeri che il piano mette uno contro l'altro misurano due cose diverse:
# il picco **sull'orda isolata** che converge tutta sul bersaglio, e il picco
# **sulla scena vera**. Nessuno dei due e' dichiarato come quello che **limita**.
# Qui si risponde con i numeri: il caso che obbliga e' l'orda isolata, perche' il
# suo picco sta sopra il tetto dichiarato della scena vera e sopra tutto il suo
# campione.

func _m4_densita(h, horde: HORDE) -> void:
	# ## Perche' qui si fissa il seme, e non si usa la disposizione del dado
	#
	# L'orda di questo test nasce con `seed = 0`, cioe' casuale a ogni avvio: il
	# suo picco di densita' cambia da lancio a lancio, e un'asserzione costruita
	# su quel numero andrebbe rossa a caso. E' la ragione per cui m2-w3 ha
	# fissato il seme 177 in `tests/test_gameloop.gd` dopo aver misurato un
	# fallimento su 175 lanci. Qui la misura si fa sulla **stessa** disposizione
	# che usa il gate, con lo stesso seme e con un'uccisione ogni due: i numeri
	# sono riproducibili e l'asserzione conserva i denti senza perderli.
	horde.reseed(SEME_DENSITA)
	var picco := 0
	var uccisi := 0
	for s in 600:
		horde.step(DT)
		picco = maxi(picco, horde.worst_bucket())
		if s % 2 == 0 and horde.count > 0:
			if horde.damage_enemy(0, 9999.0, Vector3.ZERO):
				uccisi += 1

	# Il caso che obbliga la costante e' ** questo**: l'orda isolata che converge
	# tutta sul bersaglio. Il numero qui sotto e' il suo picco, e quello che lo
	# dichiara e' il tetto che m3 ha messo sulla scena vera (su quel campione
	# min 4, mediana 5, max 7). Se il picco dell'orda isolata sta **sopra** il
	# tetto della scena vera, allora la scena vera non e' il caso che obbliga la
	# costante: dimensionare sul suo picco farebbe traboccare l'orda isolata, e
	# con il traboccamento ogni query tornerebbe a scansione lineare proprio
	# quando la densita' e' alta, cioe' quando la griglia serve.
	h.check(picco > 0, "il percorso a seme fisso deve avere un picco da misurare: %d" % picco)
	h.check(picco > TETTO_SCENA_VERA,
		"il picco dell'orda isolata (%d) deve stare sopra il tetto dichiarato della scena vera (%d): e' questo il caso che obbliga la costante"
			% [picco, TETTO_SCENA_VERA])
	h.check(GRID.BUCKET_SLOTS > TETTO_SCENA_VERA + ESCURSIONE_SCENA_VERA,
		"una costante tarata sulla scena vera (tetto %d piu' escursione %d = %d) starebbe sotto questa"
			% [TETTO_SCENA_VERA, ESCURSIONE_SCENA_VERA, TETTO_SCENA_VERA + ESCURSIONE_SCENA_VERA])

	print("orda: m4 densita' a seme %d, 600 passi con un'uccisione ogni due (%d uccisioni): picco %d nemici in una cella su %d slot"
		% [SEME_DENSITA, uccisi, picco, GRID.BUCKET_SLOTS])
	print("orda: m4 rifiuti dalla griglia su quel percorso: %d, traboccamento: %s"
		% [horde.grid_dropped(), str(horde.grid_overflowed())])
	print("orda: m4 confronto: orda isolata %d contro tetto della scena vera %d (su quel campione max 7): il caso che obbliga e' l'orda isolata"
		% [picco, TETTO_SCENA_VERA])

	# E la tabella: quanti nemici cadrebbero fuori dalle query, adesso, con una
	# costante candidata. Il conto e' sulle celle vere delle posizioni dell'orda.
	_m4_tabella(h, horde, picco)

## Quanti nemici la griglia **rifiuterebbe** in questo istante con una costante
## candidata, e in quante celle. Il numero e' `somma(max(0, occupazione -
## candidato))`: quello che `insert()` fa, scritto una volta per poterlo leggere
## invece di indovinarlo.
func _m4_tabella(h, horde: HORDE, picco: int) -> void:
	var per_cella := {}
	for i in horde.count:
		var c := Vector2i(floori(horde.transforms[i].x / GRID.CELL),
			floori(horde.transforms[i].z / GRID.CELL))
		per_cella[c] = int(per_cella.get(c, 0)) + 1

	var occupazione_max := 0
	for c in per_cella:
		occupazione_max = maxi(occupazione_max, int(per_cella[c]))

	for candidato in CANDIDATI:
		var rifiutati := 0
		var celle_piene := 0
		for c in per_cella:
			var n := int(per_cella[c])
			if n > candidato:
				rifiutati += n - candidato
				celle_piene += 1
		print("orda: m4 tabella: BUCKET_SLOTS = %d -> %d nemici fuori dalle query in %d celle, su %d celle e %d nemici"
			% [candidato, rifiutati, celle_piene, per_cella.size(), horde.count])

	# Il picco e' il massimo su tutti i passi, quindi non puo' essere minore
	# della cella piu' affollata dell'ultimo frame: se lo fosse, il picco sarebbe
	# stato misurato su un mondo diverso da quello che la tabella descrive.
	h.check(occupazione_max > 0, "c'e' almeno una cella occupata da guardare")
	h.check(occupazione_max <= picco,
		"la cella piu' affollata dell'ultimo frame (%d) non puo' superare il picco misurato (%d)"
			% [occupazione_max, picco])
	# E il conto fatto qui, da solo, deve concordare col contatore di produzione
	# sullo stesso istante: due derivazioni indipendenti dello stesso numero che
	# non possono divergere senza che qualcuno abbia mentito.
	var rifiutati_ora := 0
	for c in per_cella:
		var n := int(per_cella[c])
		if n > GRID.BUCKET_SLOTS:
			rifiutati_ora += n - GRID.BUCKET_SLOTS
	h.eq(rifiutati_ora, horde.grid_dropped(),
		"i rifiuti ricalcolati dalle posizioni devono essere quelli che il contatore dice")

# --- m4.4: le query danno gli stessi indici anche con traboccamento ----------

func _m4_query(h) -> void:
	# (a) traboccato: il fallback a scansione lineare deve dare gli stessi
	# indici della scansione lineare, e lo stesso della via normale
	_m4_batteria(h, "con traboccamento", GRID.BUCKET_SLOTS + RIFIUTI, true)
	# (b) pieno ma non traboccato: la via griglia deve dare gli stessi indici
	# della scansione lineare, quindi il valore scelto non cambia le risposte
	_m4_batteria(h, "senza traboccamento", GRID.BUCKET_SLOTS, false)

## Una batteria di query su una griglia costruita, con o senza traboccamento.
## Le tre strade (`nearest_index`, `collect_into`, `fill_radius`) devono dare
## **lo stesso insieme** di indici della scansione lineare.
func _m4_batteria(h, etichetta: String, in_cella: int, traboccato: bool) -> void:
	var punti := _m4_punti(in_cella)
	var grid: GRID = GRID.new()
	grid.setup(GRID.CELL, 30.0)
	grid.begin_frame()
	for i in punti.size():
		grid.insert(i, punti[i])

	h.eq(grid.overflowed, traboccato, "%s: traboccamento come atteso" % etichetta)
	h.eq(grid.dropped, maxi(0, in_cella - GRID.BUCKET_SLOTS),
		"%s: rifiuti come attesi" % etichetta)

	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var atteso := PackedInt32Array()
	var got := PackedInt32Array()
	var grepp := PackedInt32Array()
	grepp.resize(punti.size())
	var vuoti := 0
	var discordi := 0
	var motivo := ""
	for t in M4_QUERY:
		var q := Vector3(rng.randf_range(-30.0, 30.0), 0.0, rng.randf_range(-30.0, 30.0))
		var r := rng.randf_range(0.5, 10.0)
		GRID.linear_fill_radius(atteso, q, r, punti, punti.size())

		var n := grid.collect_into(grepp, q, r, punti, punti.size())
		var via_griglia := grepp.slice(0, n)
		via_griglia.sort()
		var via_lineare := atteso.duplicate()
		via_lineare.sort()
		if via_lineare.is_empty():
			vuoti += 1
		if not _same_indices(via_griglia, via_lineare):
			discordi += 1
			if motivo == "":
				motivo = "collect_into q=(%.2f, %.2f) r=%.2f: griglia %d, lineare %d" \
					% [q.x, q.z, r, via_griglia.size(), via_lineare.size()]
		grid.fill_radius(got, q, r, punti)
		got.sort()
		if not _same_indices(got, via_lineare):
			discordi += 1
			if motivo == "":
				motivo = "fill_radius q=(%.2f, %.2f) r=%.2f: griglia %d, lineare %d" \
					% [q.x, q.z, r, got.size(), via_lineare.size()]
		var ng := grid.nearest_index(q, r, punti)
		var nl := GRID.linear_nearest(q, r, punti, punti.size())
		if ng != nl:
			discordi += 1
			if motivo == "":
				motivo = "nearest_index q=(%.2f, %.2f): griglia %d, lineare %d" \
					% [q.x, q.z, ng, nl]

	h.check(discordi == 0,
		("%s: %d query, le tre strade devono dare gli stessi indici della scansione lineare"
			% [etichetta, M4_QUERY]) + ("" if motivo == "" else "; " + motivo))
	h.check(vuoti > 0,
		"%s: il confronto deve contenere anche query con raggio vuoto" % etichetta)
	print("orda: m4 %s: %d query (%d con raggio vuoto), tre strade d'accordo con la scansione lineare"
		% [etichetta, M4_QUERY, vuoti])

## `n` nemici **nello stesso punto** (l'unico modo di far traboccare una cella
## di proposito) piu' un anello di celle con un nemico per cella. Nessun punto
## dell'anello cade nella cella del mucchio, cosi' il numero dei rifiuti e'
## esattamente quello che il test dichiara e non dipende dalla casualita'.
func _m4_punti(n_in_cella: int) -> PackedVector3Array:
	var punti := PackedVector3Array()
	var mucchio := Vector3(5.0, 0.0, 5.0) # dentro la cella (1, 1)
	for _i in n_in_cella:
		punti.append(mucchio)
	for gz in range(-5, 6):
		for gx in range(-5, 6):
			if gx == 1 and gz == 1:
				continue
			punti.append(Vector3(float(gx) * 4.0, 0.0, float(gz) * 4.0))
	return punti

## ## Dove NON e' il forzamento
##
## Il traboccamento forzato sta qui, dentro il test, e da nessuna parte in
## `src/sim/`. `insert()` non sa che il test lo stia guardando e non ha nessun
## ramo di aiuto: il file di produzione contiene `dropped` come campo (una
## volta), come azzeramento in `setup()` e in `begin_frame()` (due) e come
## incremento nel ramo `else` (una), e nient'altro. I denti si provano qui e il
## forzamento si rimuove da qui, non si lascia nel codice di gioco.

# --- Interno ------------------------------------------------------------------

## Il contratto, via nodo e non via identificatore nudo.
##
## Sotto `--script` il file principale viene compilato **prima** che l'autoload
## `Game` sia registrato fra le costanti globali di GDScript: `Game.horde` qui
## dentro non da un errore di logica, da
## `Compile Error: Identifier not found: Game`, e il test morirebbe su quello
## prima di eseguire un solo assert. Il nodo che si ottiene e' lo stesso
## identico su cui horde.gd si registra, quindi la strada aggira la
## compilazione, non il contratto (piano 5.3).
func _game() -> Node:
	return root.get_node_or_null("Game")
## Conta i nodi dell'albero a mano. `get_node_count()` dentro un `--script` vale
## 0 (il ciclo di frame non e' ancora partito), quindi un test che ci si
## appoggiasse passerebbe sempre: meglio contarli davvero.
func _count_nodes(nodo: Node) -> int:
	var totale := 1
	for c in nodo.get_children():
		totale += _count_nodes(c)
	return totale