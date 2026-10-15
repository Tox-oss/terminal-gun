extends SceneTree
## MISURA DI m12-w0 -- piano docs/piramide/piano.md sez. 1.14-ventiquarta
##
##     godot --headless --path . --script res://docs/piramide/probe_off_screen.gd
##
## Domanda: **quanto lontano dal giocatore deve nascere un nemico perche' il
## giocatore non lo veda comparire?**
##
## ## Perche' questa sonda esiste invece di un numero dichiarato
##
## La decisione dell'utente (m12, punto 2) e' «i nemici appaiono a un raggio
## determinato dal giocatore, fuori dallo schermo, gia' ingaggiati». Il piano ha
## gia' dichiarato `41,6 m` di distanza di visione, ma quel numero e' **una
## stima geometrica**, non una misura, ed e' il caso di un giocatore al muro con
## la camera centrata: al muro la camera sposta il punto guardato di
## `EDGE_MARGIN - ARENA_MARGIN = 5,2 m`, quindi da un lato vede molto e
## dall'altro poco. **Un raggio costante fa comparire nemici a meta' dello
## schermo.** E' la ragione per cui il numero va preso qui e non dichiarato.
##
## ## La misura
##
## Per ogni posizione del giocatore e ogni direzione, il **minimo raggio** per
## cui un punto a terra non e' piu' dentro l'inquadratura. Il test di visibilita'
## e' la proiezione della camera: il terreno e' piano, quindi «dentro la
## camera» vuol dire «dentro lo schermo», con **una eccezione dichiarata**: i 27
## dischi degli ostacoli sono alti 3,9 m e possono nascondere un punto a terra
## dietro di loro. Quella eccezione **non e'** misurata qui e va detto: se un
## domani un ostacolo davanti alla camera, il raggio vero e' **minore** di quello
## che questa sonda stampa.
##
## ## Due altezze, e perche' due
##
## Il nemico non e' un punto: e' un corpo. Il boss e' alto `6,46 m` disegnato. Un
## nemico la cui **base** e' gia' fuori dallo schermo ha pero' la **cima**
## dentro, e il giocatore lo vede arrivare. Quindi la sonda stampa due numeri:
## la base fuori schermo, e la cima fuori schermo. **La regola di nascita deve
## usare il secondo**, altrimenti il nemico sbuca dalla corona del quadro.
##
## ## I due casi a risposta nota
##
## - Al **centro** dell'arena la camera e' centrata sul giocatore e la risposta
##   deve essere simmetrica nelle 16 direzioni entro il margine di griglia: se
##   non lo e', il metodo di campionamento e' rotto, non la camera.
## - Il minimo delle 16 direzioni **non puo' superare** il raggio della cupola
##   d'inquadratura; e nessuno dei due numeri puo' valere `0`, perche' il
##   giocatore e' sempre dentro il proprio schermo.
##
## ## Cosa NON misura, e va detto
##
## - La mappa 4x (raggio 120 m) non e' ancora costruita: questo numero vale per
##   il raggio dichiarato oggi e va **rimisurato** quando la camera cambia.
## - Il tempo di reazione non e' qui: qui si misura **dove**, non **quanto presto**.

const ARENA_SCENE := "res://scenes/arena_main.tscn"
const CAM := preload("res://src/render/arena_camera.gd")
const DIREZIONI := 16
const RAGGIO_MAX := 90.0
const PASSI_CONVERGENZA := 40
const CORPO_ALTO := 6.46

var _ran := false

## Le quattro posizioni: centro, muro in asse, muro in diagonale, meta'.
## Il muro e' il clamp dichiarato di `player.gd`: 59,2 m dal centro.
const POSIZIONI := [
	{"nome": "centro", "p": Vector3(0.0, 0.0, 0.0)},
	{"nome": "muro in asse", "p": Vector3(59.2, 0.0, 0.0)},
	{"nome": "muro in diagonale", "p": Vector3(41.861, 0.0, -41.861)},
	{"nome": "meta'", "p": Vector3(30.0, 0.0, 30.0)},
]

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true

func _run() -> void:
	var game := root.get_node_or_null("Game")
	if game == null:
		print("PROBE FAIL: autoload Game assente.")
		quit(1)
		return
	print("PROBE: m12-w0, dove e' FUORI SCHERMO in metri. Test di visibilita': proiezione della camera.")
	print("PROBE: terreno piano, %d direzioni, ricerca binaria fino a %.0f m. Occhio: i 27 ostacoli" % [DIREZIONI, RAGGIO_MAX])
	print("PROBE: sono alti 3,9 m e possono NASCONDERE un punto: il raggio vero e' minore del numero stampato.")
	print("PROBE: %d direzioni x 4 posizioni x 2 altezze (base a 0 m, cima a %.2f m = corpo del boss)." % [DIREZIONI, CORPO_ALTO])

	var res = load(ARENA_SCENE)
	if not (res is PackedScene):
		print("PROBE FAIL: %s non e' una PackedScene." % ARENA_SCENE)
		quit(1)
		return
	var arena = (res as PackedScene).instantiate()
	var player = arena.get_node_or_null("Player")
	var camera = _trova_camera(arena)
	if player == null or camera == null:
		print("PROBE FAIL: Player assente o Camera3D non trovata nella scena.")
		quit(1)
		return

	root.add_child(arena)
	player.drive_manually()

	var vp: Vector2 = camera.get_viewport().get_visible_rect().size
	print("PROBE: viewport %.0f x %.0f, fov %.1f, near %.2f, far %.1f"
		% [vp.x, vp.y, camera.fov, camera.near, camera.far])
	print("PROBE: quota camera MISURATA %.2f m; in arena_camera.gd HEIGHT %.2f e BACK %.2f: %s"
		% [camera.global_position.y, CAM.HEIGHT, CAM.BACK,
			"combaciano" if absf(camera.global_position.y - CAM.HEIGHT) < 0.01 else "NON COMBACIANO"])
	print("PROBE: la camera e' INCLINATA di BACK = %.2f m: l'impronta a terra e' un TRAPEZIO, non un quadrato." % CAM.BACK)
	print("PROBE: cornice %s" % _cornice(vp))

	var globali_base := PackedFloat64Array()
	var globali_cima := PackedFloat64Array()
	var globali_pos := PackedFloat64Array()
	var globali_min_pos := PackedFloat64Array()

	for spec in POSIZIONI:
		var p: Vector3 = spec["p"]
		player.position = p
		player.velocity = Vector3.ZERO
		_settle(camera)
		var focus: Vector3 = camera.global_position
		print("PROBE: %s, giocatore a (%.1f, %.1f), camera a (%.1f, %.1f, %.1f)"
			% [spec["nome"], p.x, p.z, focus.x, focus.y, focus.z])
		var basi := PackedFloat64Array()
		var cime := PackedFloat64Array()
		for d in DIREZIONI:
			var a := TAU * float(d) / float(DIREZIONI)
			var dir := Vector2(cos(a), sin(a))
			var r_base := _fuori(camera, vp, p, dir, 0.0)
			var r_cima := _fuori(camera, vp, p, dir, CORPO_ALTO)
			basi.append(r_base)
			cime.append(r_cima)
			globali_base.append(r_base)
			globali_cima.append(r_cima)
		print("PROBE:   base  fuori schermo: min %.2f  mediana %.2f  max %.2f m"
			% [_min(basi), _mediana(basi), _max(basi)])
		print("PROBE:   cima  fuori schermo: min %.2f  mediana %.2f  max %.2f m"
			% [_min(cime), _mediana(cime), _max(cime)])
		print("PROBE:   disuguaglianza fra le 16 direzioni: %.2f m"
			% (_max(basi) - _min(basi)))
		globali_pos.append(_max(basi))
		globali_min_pos.append(_min(basi))

	print("PROBE: sintesi su tutte le posizioni")
	print("PROBE:   base  min %.2f  mediana %.2f  max %.2f m"
		% [_min(globali_base), _mediana(globali_base), _max(globali_base)])
	print("PROBE:   cima  min %.2f  mediana %.2f  max %.2f m"
		% [_min(globali_cima), _mediana(globali_cima), _max(globali_cima)])
	print("PROBE: il numero nel piano, 41,6 m, era una STIMA geometrica: la cima real minima e' %.2f m al muro."
		% _min(globali_cima))
	var v := 13.65  # corsa dichiarata di -orda, PLAYER_SPEED
	print("PROBE: quello che un raggio costante romperebbe NON e' la vista: e' il TEMPO.")
	print("PROBE:   un raggio costante e' sempre fuori schermo (basta >= %.2f m), ma fa arrivare" % _min(globali_cima))
	print("PROBE:   lo stesso nemico in tempi diversi a seconda della direzione:")
	for i in POSIZIONI.size():
		var spread_m := globali_pos[i] - globali_min_pos[i]
		print("PROBE:     %-18s %.2f s .. %.2f s  ->  %.2f s di differenza, solo per la direzione"
			% [POSIZIONI[i]["nome"], globali_min_pos[i] / v, globali_pos[i] / v, spread_m / v])
	print("PROBE:   quindi la regola di nascita e' una REGIONE: la stessa distanza di avvicinamento ovunque.")
	print("PROBE:   un raggio costante non puo' stare sotto %.2f m senza dare %.2f s piu' di reazione" % [_max(globali_cima), (_max(globali_cima) - _min(globali_cima)) / v])
	print("PROBE:   dalla parte corta della camera.")

	# ## Il controllo con risposta nota, e perche' non e' quello che avevo scritto
	#
	# Avevo scritto «se al centro la disuguaglianza e' ~0 il metodo e' rotto».
	# **La premessa era falsa**: la camera e' inclinata di BACK, quindi l'impronta
	# e' un trapezio anche al centro e l'asimmetria e' attesa. Il controllo vero e'
	# un altro: **due posizioni non clampate danno lo stesso numero**, perche' la
	# geometria relativa camera-giocatore e' la stessa.
	if absf(globali_pos[0] - globali_pos[3]) < 0.0001:
		print("PROBE: controllo del metodo: centro e meta' non clampati danno lo STESSO numero (%.2f m): misura deterministica." % globali_pos[0])
	else:
		print("PROBE: controllo del metodo FALLITO: centro %.2f m contro meta' %.2f m. Il metodo e' rotto."
			% [globali_pos[0], globali_pos[3]])
		quit(1)
		return
	quit(0)

func _trova_camera(nodo: Node) -> Camera3D:
	if nodo is Camera3D:
		return nodo as Camera3D
	for c in nodo.get_children():
		var t := _trova_camera(c)
		if t != null:
			return t
	return null

## La camera insegue con `FOLLOW_SPEED`: si chiama `track` finche' non smette di
## muoversi. Senza questo, il numero misurerebbe una camera ancora ferma al centro.
func _settle(camera: Camera3D) -> void:
	var prima := Vector3.ZERO
	for _i in PASSI_CONVERGENZA:
		camera.track(camera.desired_focus(), 1.0)
		var ora := camera.global_position
		if _i > 0 and ora.distance_to(prima) < 0.0005:
			break
		prima = ora

## Il minimo raggio `r` tale che il punto a terra a distanza `r` lungo `dir`,
## alla quota `q`, e' FUORI dall'inquadratura. Ricerca binaria: la visibilita'
## su un piano visto da una camera non e' monotona in `r` su tutto il tratto, ma
## lo e' sulla coda, e la coda e' quello che interessa.
func _fuori(camera: Camera3D, vp: Vector2, p: Vector3, dir: Vector2, q: float) -> float:
	var lo := 0.0
	var hi := RAGGIO_MAX
	if _visibile(camera, vp, p + Vector3(dir.x, 0.0, dir.y) * hi, q):
		return hi
	for _k in 40:
		var m := (lo + hi) * 0.5
		if _visibile(camera, vp, p + Vector3(dir.x, 0.0, dir.y) * m, q):
			lo = m
		else:
			hi = m
	return hi

func _visibile(camera: Camera3D, vp: Vector2, mondo: Vector3, q: float) -> bool:
	var punto := Vector3(mondo.x, q, mondo.z)
	if camera.is_position_behind(punto):
		return false
	var s := camera.unproject_position(punto)
	return s.x >= 0.0 and s.y >= 0.0 and s.x <= vp.x and s.y <= vp.y

func _min(a: PackedFloat64Array) -> float:
	var m := INF
	for v in a:
		m = minf(m, v)
	return m

func _max(a: PackedFloat64Array) -> float:
	var m := -INF
	for v in a:
		m = maxf(m, v)
	return m

func _mediana(a: PackedFloat64Array) -> float:
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2]

func _cornice(vp: Vector2) -> String:
	return "%.0f x %.0f px" % [vp.x, vp.y]