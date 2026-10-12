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
## ## LA MISURA DEL PRIMA, e perche' questo file la porta in testa
##
## Il numero di sotto e' la base di tutta la milestone 4, ed e' stato misurato
## **prima** di toccare una riga di `src/sim/`. Strumento: questo stesso file,
## con un blocco di misura temporaneo poi rimosso, sull'orda isolata con il fuoco
## al centro dell'arena (raggio 28 m) e passo fisso 1/60 s.
##
## | cosa si misura | prima di m4 | dopo m4 |
## |---|---|---|
## | nemici vivi al **primo frame** | **200** | **25** (`Run.POP_BASE`) |
## | tempo per arrivare alla popolazione piena, dall'avvio | **0.0000 s** (0 passi: era gia' pieno) | 0.0000 s (25, che e' il tetto dell'onda 1) |
## | tempo per riempire **dopo uno svuotamento totale** | **0.0167 s** (1 passo, da 0 a 200) | **3.13 s** (188 passi, da 0 a 25) |
## | primo contatto, nessun vivo entro 3 m dal bersaglio | **t = 0.02 s** | **t = 2.28 s** |
## | 25 nemici entro 6 m dal bersaglio | **t = 1.68 s** | **t = 5.52 s** |
## | a regime (t = 20 s) con 200 vivi | **104 entro 6 m** (52%) | 76 entro 6 m su 160 vivi (il campo e' ancora in rampa) |
##
## **Perche' la riporta questo file e non `run.gd`.** `run.gd` dichiara i numeri
## che sono usciti da questa misura, e dichiarare una derivazione senza la
## misura sarebbe un numero scelto a occhio: `run.gd` rimanda a qui, e qui la
## tabella e' scritta per prima, coi numeri di allora.
##
## ## Perche' il test continua a volere 200 nemici
##
## La capacita' e' un criterio di m1 e resta un criterio: questo file pilota
## **la propria** `population` (`horde.population = HORDE.MAX_ENEMIES`) e la porta
## a 200 col ritmo di `run.spawn_rate()`, quindi non dipende dalla curva delle
## onde e non smette di esistere quando la curva cambia. Il tempo che ci mette e'
## anche una misura: viene stampato, ed e' il numero che rende visibile che
## raggiungere 200 ora costa dei secondi e non un passo.
##
## Nota sul contratto: `nearest_enemy` e' `-> int` e `damage_enemy` e' `-> bool`
## (piano 5.2), quindi qui si chiama **anche** il contratto, non solo
## `horde.nearest_enemy_index(...)`: se le due strade dessero risposte diverse,
## il gioco in partita punterebbe a un nemico diverso da quello che il test
## crede di aver colpito.

const H = preload("res://tools/test_harness.gd")
const HORDE = preload("res://src/sim/horde.gd")
const RUN = preload("res://src/sim/run.gd")
const GRID = preload("res://src/sim/spatial_grid.gd")
const POOL = preload("res://src/sim/object_pool.gd")
const ENEMY = preload("res://src/sim/enemy.gd")

## Passo di simulazione: quello di `tests/test_gameloop.gd`, cosi' i due numeri
## di -orda sono confrontabili. Un passo fisso e' l'unica misura riproducibile.
const DT := 1.0 / 60.0
## Seme della disposizione con cui il benchmark di griglia viene misurato.
## Vedi `_population`: serve a tornare alla condizione ad anelli e a rendere il
## numero di oggi confrontabile con quello di m1.
const SEME_CAPACITY := 20260912

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
	_damage_kills(h, horde)

	quit(h.finish("orda"))

# --- 1. Popolazione -----------------------------------------------------------

func _population(h, horde: HORDE) -> void:
	# ## Perche' questo test continua a volere 200 e l'avvio no
	#
	# `_build()` riempie a `Run.population_of(1)` = 25 dal primo di m4, e la
	# prima cosa che questo test verifica e' proprio quello: l'avvio **non** e'
	# pieno. Poi il test pilota la propria `population` e la porta a
	# `HORDE.MAX_ENEMIES`, perche' la capacita' e' un criterio di m1 e non
	# diventa inesistente quando la curva delle onde cambia.
	h.eq(horde.wave, 1, "l'orda appena costruita e' sull'onda 1")
	h.eq(horde.population, RUN.population_of(1),
		"alla costruzione la popolazione e' quella che chiede la curva")
	h.eq(horde.population, RUN.POP_BASE, "che sull'onda 1 e' Run.POP_BASE")
	h.eq(horde.count, horde.population, "e il campo e' gia' a quel numero")
	h.check(horde.count < HORDE.MAX_ENEMIES,
		"l'avvio NON e' gia' pieno: %d vivi su %d di capienza" % [horde.count, HORDE.MAX_ENEMIES])

	# La rampa fino alla capienza, **misurata**: e' il numero che rende
	# visibile che 200 nemici ora costa dei secondi e non un passo.
	horde.auto_respawn = true
	horde.population = HORDE.MAX_ENEMIES
	var passi := 0
	while horde.count < HORDE.MAX_ENEMIES and passi < 6000:
		horde.step(DT)
		passi += 1
	h.eq(horde.count, HORDE.MAX_ENEMIES, "%d nemici vivi per il criterio di m1" % HORDE.MAX_ENEMIES)
	h.check(passi > 1,
		"la capienza NON si raggiunge in un passo: %d passi = %.2f s"
			% [passi, float(passi) * DT])
	# e nessun passo ne aggiunge piu' di uno
	var aggiunti_max := 0
	for _i in 30:
		var prima := horde.count
		horde.step(DT)
		aggiunti_max = maxi(aggiunti_max, horde.count - prima)
	h.eq(aggiunti_max, 0, "a pieno non si aggiunge niente")
	horde.auto_respawn = false

	# La rampa appena fatta ha lasciato i primi nemici **convergi sul centro**:
	# il campo che il benchmark di sotto misura sarebbe un grappolo addensato, e
	# il confronto griglia/scansione cambierebbe di numero per un motivo che non
	# ha a che fare con la griglia. `reseed()` ridisegna la disposizione a 200
	# nemici ad anelli, che e' la condizione con cui quel confronto e' stato
	# misurato in m1, e rende il numero di oggi confrontabile con quello di
	# allora. Il seme e' fisso perche' il benchmark legga un numero, non una
	# disposizione casuale.
	horde.reseed(SEME_CAPACITY)
	h.eq(horde.count, HORDE.MAX_ENEMIES, "dopo il reseed ci sono ancora %d nemici" % HORDE.MAX_ENEMIES)
	h.eq(horde.transforms.size(), horde.count, "e gli array sono allineati")
	h.eq(horde.grid_unknown_cells, 0, "il reseed non ha creato celle nuove")

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
	print("orda: avvio a %d nemici (Run.POP_BASE), portati a %d in %d passi = %.2f s "
		% [RUN.POP_BASE, horde.count, passi, float(passi) * DT]
		+ "(Run.SPAWN_RATE = %.1f/s)" % RUN.SPAWN_RATE)
	print("orda: %d nemici su %d celle, specie %s, raggio %.1f m"
		% [horde.count, horde.occupied_cells(), str(census), horde.arena_radius])

# --- 2. Nessun nodo per nemico ------------------------------------------------

func _no_node_per_enemy(h, horde: HORDE) -> void:
	var nodi := _count_nodes(root)
	print("orda: %d nemici vivi con %d nodi in tutta la scena (criterio: sotto 120)"
		% [horde.count, nodi])
	h.check(nodi < 120,
		"node_count deve stare sotto 120 con 200 nemici vivi: sono %d" % nodi)
	h.eq(horde.count, HORDE.MAX_ENEMIES, "e i nemici sono davvero 200 mentre si conta")
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

	# ## Il riempimento automatico: NON da 0 a 200 in un passo
	#
	# Questo e' il criterio n. 4 della milestone 4, dal lato della macchina: un
	# campo svuotato torna a `population` **al ritmo di `run.spawn_rate()`**, e
	# `population` nel frattempo e' cambiata con l'onda (svuotare l'orda ha
	# chiuso l'onda 1, quindi siamo sull'onda 2).
	horde.auto_respawn = true
	horde.step(DT)
	h.eq(horde.count, 0,
		"un passo dopo lo svuotamento il campo e' ancora vuoto: nessuna raffica")
	h.eq(horde.population, RUN.population_of(horde.wave),
		"e la popolazione inseguita e' quella della curva sull'onda corrente")

	var passi_pieno := 0
	while horde.count < horde.population and passi_pieno < 6000:
		horde.step(DT)
		passi_pieno += 1
	h.eq(horde.count, horde.population, "l'orda arriva a `population`, e non oltre")
	h.check(passi_pieno > 1,
		"e ci mette piu' di un passo: %d passi = %.2f s" % [passi_pieno, float(passi_pieno) * DT])
	h.eq(horde.transforms.size(), horde.count, "allineata dopo il riempimento")
	h.eq(horde.colors.size(), horde.count, "colori allineati dopo il riempimento")
	h.eq(horde.grid_unknown_cells, 0, "i %d spawn nuovi non hanno creato celle" % horde.count)
	h.check(horde.nearest_enemy_index(Vector3.ZERO, 100.0) >= 0,
		"dopo il riempimento si trova qualcuno")

	# e adesso la capienza, di nuovo pilotata a mano, con lo stesso ritmo
	horde.population = HORDE.MAX_ENEMIES
	var passi_capienza := 0
	while horde.count < HORDE.MAX_ENEMIES and passi_capienza < 6000:
		horde.step(DT)
		passi_capienza += 1
	h.eq(horde.count, HORDE.MAX_ENEMIES, "la capienza si raggiunge anche per riempimento")
	h.check(passi_capienza > 1, "anche da %d vivi ci mette piu' di un passo: %d passi = %.2f s"
		% [RUN.population_of(horde.wave), passi_capienza, float(passi_capienza) * DT])
	h.eq(horde.count, HORDE.MAX_ENEMIES, "e non la supera")
	print("orda: svuotata e riempita di nuovo, uccisioni in tutto %d, specie %s"
		% [horde.kills, str(horde.census())])
	print("orda: da 0 a %d in %.2f s, da %d a %d in %.2f s (Run.SPAWN_RATE = %.1f/s)"
		% [RUN.population_of(horde.wave), float(passi_pieno) * DT,
			RUN.population_of(horde.wave), HORDE.MAX_ENEMIES,
			float(passi_capienza) * DT, RUN.SPAWN_RATE])

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