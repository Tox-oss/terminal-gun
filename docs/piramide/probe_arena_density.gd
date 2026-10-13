extends SceneTree
## ESPERIMENTO DEL VERTICE (m9-w0) - piano docs/piramide/piano.md sez. 1.10 e 1.12.
##
##     godot --headless --path . --script res://docs/piramide/probe_arena_density.gd
##
## Domanda: **l'arena da 28 m e' davvero il vincolo?**
##
## Il piano non scrive un raggio nuovo prima di aver misurato (sez. 1.4b: «nessuna cifra
## di questa milestone e' scritta sopra»). Quindi questo probe non cambia niente: misura
## lo **spazio libero** al variare del raggio di simulazione, e lascia che il numero
## scelga il raggio.
##
## "Spazio libero" e' definito con lo stesso numero che morde, non con un altro: un punto
## e' libero se **nessun nemico lo puo' mordere**, cioe' se la distanza da ogni nemico e'
## maggiore di `RADIUS[kind] + TOUCH_REACH` per quel nemico. Quindi la misura risponde
## alla domanda del giocatore («ho dove muovermi?») con il numero che gli fa male.
##
## ## Perche' l'esperimento non tocca il codice di -arena
##
## `arena.gd` registra `Game.arena_radius = ARENA_RADIUS` nel proprio `_enter_tree()`, quindi
## scrivere il campo **prima** di istanziare la scena verrebbe sovrascritto. Invece:
##
##     horde.arena_radius = R      # il campo dell'orda, non quello del contratto
##     horde.reseed(S)             # -> _populate(), che legge il campo e NON rilegge il contratto
##
## `reseed` e' la **superficie congelata in m3**, e la sua semantica dichiarata (punto 3)
## dice «ripopola a `population` con lo stesso percorso del primo frame»: quindi l'esperimento
## usa la disposizione vera di -orda, non una sua ricostruzione.
##
## ## Cosa NON e' questo probe
##
## Il terreno e il muro restano a 28 m: sono disegnati da `arena.gd` a partire dal
## contratto, che il probe non tocca. Quindi qui si misura lo **spazio che l'orda concede**,
## non quello che si vede. E' la misura giusta per la domanda, ed e' dichiarata perche' un
## numero senza questo paragrafo parla di una cosa diversa da quella che misura.

const ARENA_SCENE := "res://scenes/arena_main.tscn"
## Le tabelle di -orda, lette e **non copiate**: se il numero del morso cambia, questa
## sonda cambia con lui invece di riportare un numero vecchio.
const E = preload("res://src/sim/enemy.gd")

const DT := 1.0 / 60.0
## Risoluzione della griglia di campionamento, in metri. 0.5 m: sotto questa scala un
## nemico da 1 m e una portata da 0.45 m non hanno piu' forma.
const STEP := 0.5
## Passi di assestamento col giocatore fermo al centro: l'orda deve **convergere**, non
## restare nella disposizione di partenza. 900 passi = 15 s, oltre i 275 s che servono a
## riempire l'onda 8, e l'anello intorno al giocatore e' gia' saturo.
const SETTLE := 900
## I raggi da confrontare. 28.0 e' il valore di codice; gli altri sono **ipotesi di lavoro**
## per vedere la pendenza, non una scelta.
const RADII := [28.0, 34.0, 40.0, 46.0]
## Tre popolazioni: **un nemico**, l'onda 1 e l'onda 8.
##
## Il caso da 1 nemico e' il **riferimento con risposta ovvia**: se la sonda non sa dire
## «praticamente tutta l'arena e' libera», non ha diritto di dire «il 2,5%». Uno strumento
## non verificato non e' una misura, e' un ricordo (§11.11).
const POPS := [1, 25, 200]
const SEED := 4242

var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true

func _run() -> void:
	var game := root.get_node_or_null("Game")
	if game == null:
		print("PROBE FAIL: l'autoload Game non c'e'")
		quit(1)
		return

	var res = load(ARENA_SCENE)
	if not (res is PackedScene):
		print("PROBE FAIL: %s non e' una PackedScene" % ARENA_SCENE)
		quit(1)
		return
	var arena = (res as PackedScene).instantiate()
	root.add_child(arena)

	var horde = arena.get_node_or_null("Horde")
	var player = arena.get_node_or_null("Player")
	if horde == null or player == null:
		print("PROBE FAIL: la scena non ha Horde/Player")
		quit(1)
		return

	# Il giocatore non si muove e non deve morire: e' il caso peggiore («non riesco a
	# muovermi») reso misurabile. Il mondo resta intero per tutta la misura, altrimenti
	# il game_over fermerebbe il riempimento e la densita' cadrebbe per motivi sbagliati.
	player.drive_manually()
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.max_hp = 1.0e9
	player.hp = 1.0e9

	print("PROBE: m9, spazio libero al variare del raggio. Sema %d, DT=%.5f, griglia %.1f m, %d passi di assestamento"
		% [SEED, DT, STEP, SETTLE])
	print("PROBE: libero = nessun nemico puo' mordere quel punto (RADIUS[kind] + TOUCH_REACH = %.2f m sul runner)"
		% (E.RADIUS[E.RUNNER] + E.TOUCH_REACH))
	print("PROBE: il terreno e il muro restano a 28 m: qui si misura lo spazio che l'ORDA concede")

	for pop in POPS:
		for radius in RADII:
			_run_case(horde, player, pop, radius)

	if arena.get_parent() != null:
		arena.get_parent().remove_child(arena)
	arena.free()
	quit(0)

func _run_case(horde, player, pop: int, radius: float) -> void:
	horde.population = pop
	horde.arena_radius = radius
	horde.reseed(SEED)
	if horde.count != pop:
		print("PROBE: R %.0f, pop %d: conteggio %d diverso dalla richiesta, caso saltato"
			% [radius, pop, horde.count])
		return

	for i in SETTLE:
		horde.step(DT)

	var stats := _free_space(horde, radius)
	var in_reach := 0
	for i in horde.count:
		if _flat(horde.transforms[i] - player.global_position).length() <= E.RADIUS[horde.kinds[i]] + E.TOUCH_REACH:
			in_reach += 1

	print("PROBE: R %5.1f m, pop %3d | area %8.1f m2 | libera %8.1f m2 (%5.1f%%) | disco libero max %5.1f m | a portata di morso sul centro %3d/%3d"
		% [radius, pop, stats.area, stats.free_area, 100.0 * stats.free_ratio,
			stats.max_disc, in_reach, horde.count])

## Spazio libero, calcolato sulla griglia. Nessun nemico viene proiettato: per ogni
## nemico si marcano le celle entro la sua portata, che e' un quadrato piccolo. Ogni
## nemico costa ~(2*portata/STEP)^2 celle, non una scansione della griglia intera.
##
## `state` dice tre cose e le tiene distinte, ed e' la correzione di un difetto reale: la
## prima versione usava lo stesso valore per «fuori dall'arena» e per «minacciato», e il
## totale delle celle contava anche quelle fuori. Il risultato era che **un nemico solo
## lasciava il 2,5% di area libera**: impossibile, perche' un nemico da 0,9 m di portata
## copre al massimo 2,5 m² su 2463. Il riferimento a 1 nemico esiste perche' quello e' un
## caso in cui la risposta giusta e' nota e la sonda puo' sbagliare.
##
## 0 = dentro all'arena e nessuno lo morde
## 1 = fuori dall'arena (non e' area, e non e' nemmeno spazio percorribile)
## 2 = dentro all'arena ma un nemico lo puo' mordere
func _free_space(horde, radius: float) -> Dictionary:
	var n := int(ceil(2.0 * radius / STEP)) + 1
	var state := PackedByteArray()
	state.resize(n * n)
	var inside_cells := 0
	for gz in n:
		for gx in n:
			var x := -radius + gx * STEP
			var z := -radius + gz * STEP
			if Vector2(x, z).length() > radius:
				state[gz * n + gx] = 1
			else:
				inside_cells += 1

	for i in horde.count:
		var c: Vector3 = horde.transforms[i]
		var reach: float = E.RADIUS[horde.kinds[i]] + E.TOUCH_REACH
		var span := int(ceil(reach / STEP))
		var gx0 := int(floor((c.x - reach + radius) / STEP))
		var gz0 := int(floor((c.z - reach + radius) / STEP))
		for gz in range(maxi(0, gz0), mini(n, gz0 + 2 * span + 2)):
			for gx in range(maxi(0, gx0), mini(n, gx0 + 2 * span + 2)):
				var idx := gz * n + gx
				if state[idx] != 0:
					continue
				var px := -radius + gx * STEP
				var pz := -radius + gz * STEP
				if Vector2(px - c.x, pz - c.z).length() > reach:
					continue
				state[idx] = 2

	var free_cells := 0
	for idx in n * n:
		if state[idx] == 0:
			free_cells += 1

	return {
		"area": PI * radius * radius,
		"free_area": free_cells * STEP * STEP,
		"free_ratio": 0.0 if inside_cells == 0 else float(free_cells) / float(inside_cells),
		"max_disc": _max_free_disc(state, n),
	}

## Distanza di chamfer a due passate sulla griglia: distanza di ogni cella libera dalla
## cella **bloccata** piu' vicina. Il massimo e' il raggio del disco libero piu' grande
## **dentro l'arena**: fuori dall'arena e' bloccata anch'essa, altrimenti il numero
## misurerebbe una zona in cui il giocatore non puo' nemmeno andare (e' il difetto della
## prima versione, che dava 30,0 m su un'arena di raggio 28).
func _max_free_disc(state: PackedByteArray, n: int) -> float:
	var dist := PackedFloat32Array()
	dist.resize(n * n)
	for idx in n * n:
		dist[idx] = INF if state[idx] == 0 else 0.0

	var diag := STEP * 1.41421356
	for gz in n:
		for gx in n:
			var idx := gz * n + gx
			if dist[idx] == 0.0:
				continue
			var best := dist[idx]
			if gx > 0: best = minf(best, dist[idx - 1] + STEP)
			if gz > 0: best = minf(best, dist[idx - n] + STEP)
			if gx > 0 and gz > 0: best = minf(best, dist[idx - n - 1] + diag)
			if gx < n - 1 and gz > 0: best = minf(best, dist[idx - n + 1] + diag)
			dist[idx] = best
	for gz in range(n - 1, -1, -1):
		for gx in range(n - 1, -1, -1):
			var idx := gz * n + gx
			if dist[idx] == 0.0:
				continue
			var best := dist[idx]
			if gx < n - 1: best = minf(best, dist[idx + 1] + STEP)
			if gz < n - 1: best = minf(best, dist[idx + n] + STEP)
			if gx < n - 1 and gz < n - 1: best = minf(best, dist[idx + n + 1] + diag)
			if gx > 0 and gz < n - 1: best = minf(best, dist[idx + n - 1] + diag)
			dist[idx] = best

	var best_disc := 0.0
	for idx in n * n:
		if state[idx] == 0:
			best_disc = maxf(best_disc, dist[idx])
	return best_disc

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)