extends SceneTree
## MISURA DI m11-ter -- piano docs/piramide/piano.md sez. 1.14-nona e 1.14-decima
##
##     godot --headless --path . --script res://docs/piramide/probe_survive.gd
##
## Domanda: **quanto deve scendere l'onda 1 perché il giocatore arrivi all'onda 2?**
##
## ## Perché questa sonda, e non quella sul raggio
##
## Il raggio e' gia' stato consegnato a 60,0 m e la tabella sul raggio e' in
## 1.14-quinque e 1.14-seque. Ma li' si e' letto che **tutte le morti cadono
## sull'onda 1 con 25 nemici vivi**, mai sulla 2, e che anche a 75 m il caso
## peggiore muore a 123,13 s. Quindi **la mappa non e' il vincolo: l'apertura lo
## e'**, e la leva dell'apertura e' `population_scale`, la cucitura di m11-ter.
##
## ## La leva, e il suo caso a risposta nota
##
## `population_scale` ha default **1.0** e a 1.0 combacia con
## `Run.population_of`, quindi **scala 1.00 e' il gioco di oggi**: la risposta e'
## gia' nota, **82,03 s** sul caso peggiore.
##
## **Scala 0.00 e' il riferimento**: senza nemici il giocatore **non puo' morire**,
## quindi lo strumento **DEVE arrivare al tetto**. Se non ci arriva, non sta
## guardando la leva, e i numeri qui sotto non valgono niente: e' per questo che la
## verifica sta sul riferimento e non in fondo, dove si legge per piacere.
##
## ## L'ordine che conta, e che e' costato un tentativo
##
## `population_scale` va scritto **PRIMA** che la scena entri nell'albero. La
## popolazione dell'onda 1 e' decisa dentro `_build()`, che gira in `_ready()`,
## che parte con `add_child`. Scriverlo dopo non cambia niente: e' il caso 1.0 che
## si misura due volte. Quindi qui: `instantiate()`, si scrive sul nodo **non
## ancora in albero**, e solo dopo `add_child`.
##
## ## Che cos'e' lo schivatore, e che cosa NON puo' dire
##
## Il giocatore e' **quello vero**: `drive_manually()` e `player.step()` passano
## dal codice di -gameplay, quindi velocita', accelerazione, clamp all'arena e
## clamp agli ostacoli sono quelli del gioco. Il nemico e' quello vero, l'arma e'
## quella vera e spara da sola, la scena e' quella vera con i 27 ostacoli.
##
## Solo la **direzione** e' mia. E quindi il numero che esce e' una **soglia di
## fattibilita'**: dice che cosa e' **possibile**, non che cosa e' **divertente**.
## Uno schivatore cosi' e' peggio di uno bravo, quindi il numero e' **basso**: se
## i 600 s sono raggiungibili cosi', lo sono anche per un giocatore vero.
##
## ## I due termini che lo rendono uno strumento e non una sonda
##
## - **il muro**, con `EDGE_SAFE_M = 0.8` che e' il margine che `player.gd` usa
##   gia', e `WALL_PENALTY = 3.0`;
## - **gli ostacoli**, con `EDGE_OSTACOLO = 2.5` e `OSTACOLO_PENALITA = 4.0`.
##   Il secondo e' arrivato dopo che la consegna del raggio avesse rivelato che il
##   punteggio guardava il muro e i nemici e **ignorava i dischi**: uno strumento
##   che non vede un ostacolo non puo' dire quanto e' grande un disco. E' la
##   seconda volta che questo strumento misurava se stesso.

const ARENA_SCENE := "res://scenes/arena_main.tscn"

const DT := 1.0 / 60.0
## Cinque minuti. La domanda e' binaria («muore presto» oppure «regge») e 720 s
## non aggiunge informazione a una risposta che e' gia' arrivata al tetto.
const TMAX := 300.0
const REPORT_EVERY := 60.0

## Sedici raggi. Con otto il vuoto angolare da 45 gradi era abbastanza largo da
## far scegliere al punto di schivarsi verso il muro, che era il difetto della
## prima versione.
const RAYS := 16

## Quanto guarda avanti lo schivatore, in secondi di corsa. A 13,65 m/s, 1,5 s
## sono ~20 m: abbastanza da vedere il muro *prima* di arrivarci. Dichiarato in
## secondi e non in metri perche' descrive «quanto tempo di corsa».
const LOOKAHEAD_S := 1.5

## Margine tenuto dal muro: 0,8 m e' il margine che `player.gd` usa gia' per il
## clamp, quindi qui non si inventa un numero diverso.
const EDGE_SAFE_M := 0.8
const WALL_PENALTY := 3.0
const EDGE_OSTACOLO := 2.5
const OSTACOLO_PENALITA := 4.0

## Sopra questa frazione del raggio lo schivatore torna verso il centro: senza,
## una volta vicino al bordo continua a scegliere la lontananza dall'orda, che e'
## verso il muro, e si chiude in angolo.
const CENTRE_PULL := 0.70

## Il raggio **consegnato**: la mappa e' gia' stata portata a 60,0 m e qui non
## si varya piu', perche' la domanda di questa sonda e' un'altra.
const RAGGIO := 60.0

## Le scale della leva. `0.00` e' il riferimento a risposta nota, `1.00` e' il
## gioco di oggi. Le due in mezzo sono i passi che contano.
const SCALE := [0.0, 0.25, 0.50, 1.00]

## Tre semi non fanno una media: fanno una **distribuzione**, e quello che si
## riporta e' il **minimo**, che e' la partita peggiore.
const SEMI := [4242, 7311, 20260912]

var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true

func _run() -> void:
	print("PROBE: m11-ter, l'apertura. La leva e' population_scale, non il raggio.")
	print("PROBE: DT=%.5f, %d raggi, sguardo avanti %.1f s (%.1f m a 13,65 m/s), margine %.1f m"
		% [DT, RAYS, LOOKAHEAD_S, LOOKAHEAD_S * 13.65, EDGE_SAFE_M])
	print("PROBE: raggio fisso a %.1f m, scena vera con i 27 ostacoli e l'arma vera" % RAGGIO)
	print("PROBE: scala 0.00 e' un caso a risposta NOTA e deve SOPRAVVIVERE: senza nemici non si muore.")
	print("PROBE: scala 1.00 e' il gioco di oggi, risposta gia' nota: 82,03 s sul caso peggiore.")

	var risultati := PackedFloat32Array()
	var riferimento_ok := false
	for s in SCALE:
		var campioni := PackedFloat32Array()
		for sd in SEMI:
			campioni.append(_una_sessione(float(sd), float(s)))
		campioni.sort()
		var peggiore: float = campioni[0]
		var migliore: float = campioni[campioni.size() - 1]
		risultati.append(peggiore)

		print("PROBE: RISULTATO scala %.2f | 3 semi: %s | MIN %6.2f s | MAX %6.2f s"
			% [s, _lista(campioni), peggiore, migliore])

		if is_zero_approx(float(s)):
			riferimento_ok = peggiore >= TMAX
			if riferimento_ok:
				print("PROBE: RIFERIMENTO scala 0.00: sopravvissuto a %6.2f s COME DEVE, lo strumento e' in piedi"
					% peggiore)
			else:
				print("PROBE: RIFERIMENTO scala 0.00 NON ha superato il tetto di %.0f s: strumento ROTTO" % TMAX)

		if is_equal_approx(float(s), 1.0):
			print("PROBE: scala 1.00, gioco di oggi: il minimo di adesso e' %.2f s contro gli 82,03 s noti" % peggiore)

	print("PROBE: LETTURA")
	if not riferimento_ok:
		print("PROBE: NESSUNA LETTURA: il riferimento a scala 0.00 non ha sopravvissuto, quindi")
		print("PROBE:   questi numeri non descrivono l'apertura. Non li uso e non li riporto.")
	else:
		for i in SCALE.size():
			if is_zero_approx(float(SCALE[i])):
				continue
			print("PROBE:   da scala %.2f a %.2f il minimo passa da %.2f a %.2f s: fattore %.2f"
				% [SCALE[i - 1], SCALE[i], risultati[i - 1], risultati[i],
				   risultati[i] / maxf(risultati[i - 1], 0.001)])
		print("PROBE: i 600 s dell'utente sono %5.2f volte il minimo al gioco di oggi (scala 1.00)"
			% (600.0 / maxf(risultati[SCALE.size() - 1], 0.001)))
	quit(0)

func _lista(v: PackedFloat32Array) -> String:
	var s := ""
	for i in v.size():
		if i > 0:
			s += " / "
		s += "%.1f s" % v[i]
	return s

## Una sessione con l'orda e il giocatore veri, alla scala `scala`.
func _una_sessione(seme: int, scala: float) -> float:
	var game := root.get_node_or_null("Game")
	if game == null:
		print("PROBE FAIL: l'autoload Game non c'e'")
		return 0.0

	var res = load(ARENA_SCENE)
	if not (res is PackedScene):
		print("PROBE FAIL: %s non e' una PackedScene" % ARENA_SCENE)
		return 0.0
	var arena = (res as PackedScene).instantiate()

	var horde = arena.get_node_or_null("Horde")
	var player = arena.get_node_or_null("Player")
	if horde == null or player == null:
		print("PROBE FAIL: la scena non ha Horde/Player")
		return 0.0

	# **PRIMA** di entrare nell'albero. `_build()` gira in `_ready()` e la' decide la
	# popolazione dell'onda 1: scriverlo dopo misurerebbe il caso 1.0 due volte.
	horde.population_scale = scala

	game.arena_radius = RAGGIO
	root.add_child(arena)

	# Il raggio e' **due** numeri: `arena.gd` registra il suo nel proprio
	# `_enter_tree()` e quel valore finisce sia nel clamp del giocatore, sia nel
	# fallback dell'orda. Impostando solo il campo dell'orda si avrebbe un'orda
	# grande dentro un disco dove il giocatore resta piccolo.
	horde.arena_radius = RAGGIO
	horde.reseed(seme)

	player.drive_manually()
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO

	# Gli ostacoli sono un **dato**, non una parte del raggio: vengono da
	# `arena.gd` e sono gli stessi per tutti i semi e per tutte le scale. Li leggo
	# una volta e li passo allo schivatore.
	var ostacoli: PackedVector3Array = game.obstacles
	print("PROBE:   scala %.2f seme %d | nemici all'avvio %3d | ostacoli %d, raggio massimo %.2f m"
		% [scala, seme, horde.count, ostacoli.size(), _raggio_max(ostacoli)])

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
			break

	if arena.get_parent() != null:
		arena.get_parent().remove_child(arena)
	arena.free()
	return t

## Il disco di ostacolo piu' grosso, per stamparlo. Il raggio sta in `y` e non e'
## un'altezza: e' la stessa forma del contratto, letta al contrario.
func _raggio_max(ostacoli: PackedVector3Array) -> float:
	var m := 0.0
	for k in ostacoli.size():
		m = maxf(m, ostacoli[k].y)
	return m

## Sedici raggi, e per ognuno un punto guardato avanti invece che il punto
## stesso. Vince il punteggio piu' alto, e il punteggio ha **tre** termini
## invece di uno: lontananza dal nemico piu' vicino guardata avanti, penalita' del
## muro in metri, penalita' degli ostacoli in metri, e ritorno al centro quando e'
## oltre `CENTRE_PULL`.
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

		# 1. lontananza dal nemico piu' vicino guardata **avanti**, non qui
		var punteggio := _distanza_minima(horde, q)

		# 2. il muro, in metri: quanto il punto guardato sborda
		var sforo := q.length() - limite
		if sforo > 0.0:
			punteggio -= WALL_PENALTY * sforo

		# 2b. gli ostacoli. Il contratto li registra come
		#     `Vector3(centro_x, RAGGIO, centro_z)`: il raggio sta in `y` e non
		#     e' un'altezza. Stessa forma del muro, stessa penalita' in metri, e
		#     quindi le due cose si sommano e si confrontano.
		for k in ostacoli.size():
			var c := Vector2(ostacoli[k].x, ostacoli[k].z)
			var rg: float = ostacoli[k].y
			var dentro := c.distance_to(q) - rg - EDGE_OSTACOLO
			if dentro < 0.0:
				punteggio -= OSTACOLO_PENALITA * (-dentro)

		# 3. il ritorno al centro, che serve a sciogliere l'angolo
		if p.length() > RAGGIO * CENTRE_PULL:
			punteggio += (limite - q.length()) * 0.5

		if punteggio > miglior_punteggio:
			miglior_punteggio = punteggio
			meglio = d
	return meglio

## Distanza dal nemico piu' vicino: scansione lineare sul record, non sulla
## griglia. Sono 200 nemici e la sonda gira fino a 43 000 volte: la griglia
## costerebbe di piu' a costruirla che a leggerla, e qui non c'e' un criterio di
## prestazioni da rispettare.
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
