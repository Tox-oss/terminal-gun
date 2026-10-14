extends SceneTree
## MISURA DI m11-ter -- piano docs/piramide/piano.md sez. 1.14-undicesima
##
##     godot --headless --path . --script res://docs/piramide/probe_survive_600.gd
##
## Domanda: **quali scale di apertura permettono al giocatore di durare 600 s?**
##
## ## Che cosa cambia rispetto a probe_survive.gd
##
## TMAX e' alzato a 600 s. La tabella ha scale aggiuntive tra 0.25 e 0.50 per
## separare chi tocca il tetto dai 600 s da chi muore prima. Il resto dello
## scheletro e' identico: stessi semi, stesso schivatore, stessa scena vera.
##
## ## I due casi a risposta nota
##
## - scala 0.00: senza nemici non si puo' morire, DEVE arrivare al tetto 600 s.
##   Se non ci arriva, lo strumento e' rotto e nessun numero vale.
## - scala 1.00: gioco di oggi, 82,03 s sul caso peggiore (misurato).
##   Il minimo deve riprodurlo al secondo decimale.
##
## ## La trappola dell'ordine (gia' pagata)
##
## population_scale va scritto PRIMA di root.add_child(arena), perche' _build()
## gira in _ready() con add_child. Scriverlo dopo misurerebbe il caso 1.0 due volte.
##
## ## MORTO vs TETTO
##
## Sono due risultati diversi e vanno distinti:
##   MORTO  = hp <= 0, il giocatore e' caduto prima del tetto
##   TETTO  = ha raggiunto TMAX con hp > 0

const ARENA_SCENE := "res://scenes/arena_main.tscn"

const DT := 1.0 / 60.0
const TMAX := 600.0
const REPORT_EVERY := 60.0

const RAYS := 16
const LOOKAHEAD_S := 1.5
const EDGE_SAFE_M := 0.8
const WALL_PENALTY := 3.0
const EDGE_OSTACOLO := 2.5
const OSTACOLO_PENALITA := 4.0
const CENTRE_PULL := 0.70
const RAGGIO := 60.0

## Scale: 0.00 riferimento, 0.25/0.30/0.35/0.40 zona grigia (a 300 erano tutte al tetto),
## 0.50 e 1.00 gia' misurate. Matrice ridotta per stare in 120 s: 8 scale x 3 semi = 24 sessioni.
## Se la corsa supera il timeout, si riduce ulteriormente.
const SCALE := [0.0, 0.25, 0.30, 0.35, 0.40, 0.50, 1.00]

const SEMI := [4242, 7311, 20260912]

var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true

func _run() -> void:
	print("PROBE: m11-ter, apertura a 600 s. Leva: population_scale.")
	print("PROBE: DT=%.5f, %d raggi, sguardo %.1f s (%.1f m), margine %.1f m"
		% [DT, RAYS, LOOKAHEAD_S, LOOKAHEAD_S * 13.65, EDGE_SAFE_M])
	print("PROBE: raggio %.1f m, scena vera 27 ostacoli, arma vera." % RAGGIO)
	print("PROBE: TMAX=%.0f s. MORTO=caduto prima del tetto, TETTO=sopravvissuto." % TMAX)
	print("PROBE: scala 0.00 DEVE toccare il tetto (nessun nemico = non si muore).")
	print("PROBE: scala 1.00 DEVE dare minimo 82.03 s (gioco di oggi, gia' misurato).")
	print("")

	var risultati := PackedFloat32Array()         # minimo per scala
	var stati := []                               # "MORTO" o "TETTO" per il minimo
	var riferimento_ok := false

	for si in SCALE.size():
		var s: float = SCALE[si]
		var campioni := PackedFloat32Array()
		var campioni_stato := []

		for sd in SEMI:
			var esito := _una_sessione(int(sd), s)
			campioni.append(esito[0])
			campioni_stato.append(esito[1])

		# ordina per tempo (non cambia lo stato del campione peggiore, solo l'ordine)
		# ordinamento manuale per tenere i pari seme-stato
		for a in campioni.size():
			for b in range(a + 1, campioni.size()):
				if campioni[a] > campioni[b]:
					var tmp_t: float = campioni[a]
					campioni[a] = campioni[b]
					campioni[b] = tmp_t
					var tmp_s = campioni_stato[a]
					campioni_stato[a] = campioni_stato[b]
					campioni_stato[b] = tmp_s

		var peggiore_t: float = campioni[0]
		var peggiore_stato: String = campioni_stato[0]
		var migliore_t: float = campioni[campioni.size() - 1]
		risultati.append(peggiore_t)
		stati.append(peggiore_stato)

		print("PROBE: RISULTATO scala %.2f | 3 semi: %s | MIN %6.2f s [%s] | MAX %6.2f s"
			% [s, _lista(campioni, campioni_stato), peggiore_t, peggiore_stato, migliore_t])

		if is_zero_approx(s):
			riferimento_ok = (peggiore_stato == "TETTO")
			if riferimento_ok:
				print("PROBE: RIFERIMENTO scala 0.00: TETTO a %.2f s COME DEVE. Strumento in piedi." % peggiore_t)
			else:
				print("PROBE: RIFERIMENTO scala 0.00 NON ha toccato il tetto: strumento ROTTO. Interrompo.")
				quit(1)
				return

		if is_equal_approx(s, 1.0):
			print("PROBE: scala 1.00 (oggi): minimo %.2f s vs 82.03 s noti." % peggiore_t)

	print("")
	print("PROBE: LETTURA FINALE")
	for si in SCALE.size():
		var s: float = SCALE[si]
		print("PROBE:   scala %.2f | MIN %6.2f s | %s" % [s, risultati[si], stati[si]])
	print("")
	print("PROBE: VERDETTO")
	for si in SCALE.size():
		var s: float = SCALE[si]
		if stati[si] == "TETTO":
			print("PROBE:   scala %.2f -> TETTO (>= 600 s): compatibile con 600 s di partita." % s)
		else:
			print("PROBE:   scala %.2f -> MORTO a %.2f s: NON compatibile con 600 s." % [s, risultati[si]])
	print("")
	print("PROBE: I 600 s dell'utente sono %.2f volte il minimo a scala 1.00 (oggi)."
		% (600.0 / maxf(risultati[SCALE.size() - 1], 0.001)))
	quit(0)

func _lista(campioni: PackedFloat32Array, stati_c: Array) -> String:
	var out := ""
	for i in campioni.size():
		if i > 0:
			out += " / "
		out += "%.1f s[%s]" % [campioni[i], stati_c[i]]
	return out

## Ritorna [tempo_float, "MORTO"|"TETTO"]
func _una_sessione(seme: int, scala: float) -> Array:
	var game := root.get_node_or_null("Game")
	if game == null:
		print("PROBE FAIL: autoload Game assente.")
		return [0.0, "MORTO"]

	var res = load(ARENA_SCENE)
	if not (res is PackedScene):
		print("PROBE FAIL: %s non e' una PackedScene." % ARENA_SCENE)
		return [0.0, "MORTO"]
	var arena = (res as PackedScene).instantiate()

	var horde = arena.get_node_or_null("Horde")
	var player = arena.get_node_or_null("Player")
	if horde == null or player == null:
		print("PROBE FAIL: Horde o Player assente nella scena.")
		return [0.0, "MORTO"]

	# PRIMA di add_child: _build() gira in _ready() e decide la popolazione onda 1
	horde.population_scale = scala

	game.arena_radius = RAGGIO
	root.add_child(arena)

	horde.arena_radius = RAGGIO
	horde.reseed(seme)

	player.drive_manually()
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO

	var ostacoli: PackedVector3Array = game.obstacles
	print("PROBE:   scala %.2f seme %d | nemici %3d | ostacoli %d"
		% [scala, seme, horde.count, ostacoli.size()])

	var t := 0.0
	var next_report := REPORT_EVERY
	while t < TMAX:
		var direzione := _direzione(horde, player, ostacoli)
		player.step(DT, Vector3(direzione.x, 0.0, direzione.y))
		horde.step(DT)
		t += DT
		if t >= next_report:
			print("PROBE:     | %5.0f s | hp %6.2f | vivi %3d | onda %2d | uccisi %4d"
				% [t, player.hp, horde.count, horde.wave, horde.kills])
			next_report += REPORT_EVERY
		if player.hp <= 0.0:
			if arena.get_parent() != null:
				arena.get_parent().remove_child(arena)
			arena.free()
			return [t, "MORTO"]

	if arena.get_parent() != null:
		arena.get_parent().remove_child(arena)
	arena.free()
	return [t, "TETTO"]

func _raggio_max(ostacoli: PackedVector3Array) -> float:
	var m := 0.0
	for k in ostacoli.size():
		m = maxf(m, ostacoli[k].y)
	return m

func _direzione(horde, player, ostacoli: PackedVector3Array) -> Vector2:
	var p := _flat(player.global_position)
	var guarda := LOOKAHEAD_S * 13.65
	var limite := maxf(RAGGIO - EDGE_SAFE_M, 0.0)

	var meglio := Vector2(0.0, -1.0)
	var miglior_punteggio := -INF

	for i in RAYS:
		var a := TAU * float(i) / float(RAYS)
		var d := Vector2(cos(a), sin(a))
		var q := p + d * guarda

		var punteggio := _distanza_minima(horde, q)

		var sforo := q.length() - limite
		if sforo > 0.0:
			punteggio -= WALL_PENALTY * sforo

		for k in ostacoli.size():
			var c := Vector2(ostacoli[k].x, ostacoli[k].z)
			var rg: float = ostacoli[k].y
			var dentro := c.distance_to(q) - rg - EDGE_OSTACOLO
			if dentro < 0.0:
				punteggio -= OSTACOLO_PENALITA * (-dentro)

		if p.length() > RAGGIO * CENTRE_PULL:
			punteggio += (limite - q.length()) * 0.5

		if punteggio > miglior_punteggio:
			miglior_punteggio = punteggio
			meglio = d
	return meglio

func _distanza_minima(horde, p: Vector2) -> float:
	var m := INF
	var ts: PackedVector3Array = horde.transforms
	for i in horde.count:
		var d := p.distance_squared_to(Vector2(ts[i].x, ts[i].z))
		if d < m:
			m = d
	return sqrt(m)

func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)
