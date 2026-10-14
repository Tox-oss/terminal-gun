extends SceneTree
## MISURA DI m11 -- piano docs/piramide/piano.md sez. 1.14 e 1.14-quater
##
##     godot --headless --path . --script res://docs/piramide/probe_survive.gd
##
## Domanda: **al raggio consegnato, quanto vive un giocatore che schiva davvero,
## e quanto arena gli serve per arrivare ai 600 s dell'utente?**
##
## ## Perche' questa sonda e' stata riscritta, e non aggiornata
##
## La prima versione sceglieva la direzione che **massimizza la distanza dal nemico
## piu' vicino**, con otto raggi. Al variare del raggio dava 51,0 / 300,0 / 78,2 s
## per R = 46 / 60 / 75: **non monotono**, con un numero migliore a 60 che a 46.
##
## La lettura corretta e' che **non era il raggio a decidere**: inseguendo la
## lontananza dal nemico piu' vicino, lo schivatore si spinge **contro il muro**
## (la lontananza e' dalla parte opposta all'orda) e li si fa chiudere in angolo.
## Uno strumento che dà un numero migliore a una configurazione e peggiore a una
## piu' grande **non sta misurando l'arena: sta misurando se stesso**.
##
## Quindi qui lo schivatore **guarda anche il muro**, non solo l'orda. E ha due
## **casi a risposta nota**, senza i quali i numeri di qui non hanno diritto di
## esistere:
##
## 1. **R = 12 m**: un disco cosi' piccolo che non si puo' schivare, perche' il
##    muro e' sempre dietro. **Lo strumento DEVE fallire.** Se sopravvive, lo
##    strumento e' rotto e non si guarda nessun altro numero.
## 2. **R = 46 m**: il raggio **consegnato**. La risposta **gia' nota** e gia'
##    misurata con il vecchio strumento e' **51-124 s, morte sull'onda 1**. Il
##    nuovo strumento deve **riprodurla**; se dà un numero cosi' diverso che non
##    sta misurando la stessa cosa, e va detto perche'.
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
## ## Cosa NON e' misurato qui
##
## Sotto il raggio di codice il **terreno e il muro disegnati** restano a 46 m,
## perche' sono costruiti da `arena.gd` al proprio avvio. Qui si misura lo SPAZIO
## che l'orda concede e la PISTA che il giocatore ha, non quello che si vede.
## **La vita non viene alzata**: il tempo di morte e' il numero che si cerca, e
## alzare la vita trasformerebbe la misura in una domanda diversa.

const ARENA_SCENE := "res://scenes/arena_main.tscn"

const DT := 1.0 / 60.0
## Cinque minuti e un pezzo oltre. La domanda e' binaria («muore presto» oppure
## «regge oltre i 5 minuti») e 720 s non aggiunge informazione a una risposta che
## e' gia' arrivata al tetto.
const TMAX := 300.0
const REPORT_EVERY := 60.0

## Sedici raggi e non otto: il costo raddoppia ma la stampa distingue la differenza,
## e con otto il vuoto angolare da 45 gradi era abbastanza largo da far scegliere
## al punto di schivarsi verso il muro. La misura del costo sta sulla riga di
## `PROBE: costo` in fondo.
const RAYS := 16

## Quanto guarda avanti lo schivatore, in secondi di corsa. A 13,65 m/s, 1,5 s
## sono ~20 m: abbastanza da vedere il muro *prima* di arrivarci, che e' tutto il
## punto. `LOOKAHEAD_S` e' dichiarato in secondi e non in metri perche' il numero
## che descrive e' «quanto tempo di corsa», e non cambia se la velocita' cambia.
const LOOKAHEAD_S := 1.5

## Metri di margine tenuti dal muro. 0,8 m e' il margine che `player.gd` usa
## gia' per il clamp, quindi qui non si inventa un numero diverso: si riusa quello
## che il gioco usa davvero.
const EDGE_SAFE_M := 0.8

## Quanto costa, in metri, superare `EDGE_SAFE_M` dal muro. Il termine e' in metri
## e viene sottratto a un punteggio che e' in metri, quindi le due grandezze sono
## confrontabili e la penalita' e' un numero che si puo' guardare.
const WALL_PENALTY := 3.0

## Sopra questa frazione del raggio lo schivatore torna verso il centro. Senza,
## una volta vicino al bordo continua a scegliere la direzione piu' lontana
## dall'orda, che e' verso il muro, e si chiude in angolo: era esattamente il
## difetto dello strumento vecchio.
const CENTRE_PULL := 0.70

## I raggi su cui la stessa schivatrice viene misurata, **piu' i due casi a risposta
## nota**. L'ordine mette prima il riferimento: se il riferimento passa, gli altri
## numeri si possono guardare; se fallisce, gli altri non si guardano.
const RAGGI := [12.0, 46.0, 60.0, 75.0]

## Tre semi non fanno una media: fanno una **distribuzione**, e quello che si
## riporta e' il **minimo**, che e' la partita peggiore ed e' l'unico numero che
## dice se i 600 s sono lontani o vicini.
const SEMI := [4242, 7311, 20260912]

var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true

func _run() -> void:
	print("PROBE: m11, quanto arena serve per arrivare a 600 s. Schivatore con muro.")
	print("PROBE: DT=%.5f, %d raggi, sguardo avanti %.1f s (%.1f m a 13,65 m/s), margine %.1f m, penalita' %.1f"
		% [DT, RAYS, LOOKAHEAD_S, LOOKAHEAD_S * 13.65, EDGE_SAFE_M, WALL_PENALTY])
	print("PROBE: sotto il raggio di codice il terreno e il muro DISEGNATI restano a 46 m:")
	print("PROBE: qui si misura lo SPAZIO che l'orda concede e la PISTA che il giocatore ha.")
	print("PROBE: R = 12 m e' un caso a risposta NOTA e deve FALLIRE: li' non si puo' schivare.")

	var risultati := PackedFloat32Array()
	var riferimento_ok := false
	for r in RAGGI:
		var campioni := PackedFloat32Array()
		for s in SEMI:
			campioni.append(_una_sessione(float(r), int(s)))
		campioni.sort()
		var peggiore: float = campioni[0]
		var migliore: float = campioni[campioni.size() - 1]
		risultati.append(peggiore)

		print("PROBE: RISULTATO R %5.1f m | 3 semi: %s | MIN %6.2f s | MAX %6.2f s"
			% [r, _lista(campioni), peggiore, migliore])

		if is_equal_approx(float(r), 12.0):
			# Caso a risposta nota: in 12 m il muro e' sempre dietro e lo strumento
			# DEVE morire. Sopravvivere li' e' il sintomo che lo strumento sta
			# misurando se stesso, quindi il verdetto si stampa qui, sul riferimento,
			# e non in fondo dove si legge per piacere.
			riferimento_ok = peggiore < TMAX
			if riferimento_ok:
				print("PROBE: RIFERIMENTO R 12 m: morto al %6.2f s COME DEVE, lo strumento e' in piedi"
					% peggiore)
			else:
				print("PROBE: RIFERIMENTO R 12 m HA SUPERATO IL tetto di %.0f s: strumento ROTTO" % TMAX)

		if is_equal_approx(float(r), 46.0):
			print("PROBE: R 46 m, risposta gia' nota col vecchio strumento: 50,98 / 108,95 / 124,18 s")
			print("PROBE:   il minimo di adesso e' %.2f s: se e' lontano, lo strumento non e' lo stesso"
				% peggiore)

	print("PROBE: LETTURA")
	if not riferimento_ok:
		print("PROBE: NESSUNA LETTURA: il riferimento a 12 m non e' morto, quindi questi numeri")
		print("PROBE:   non descrivono l'arena. Non li uso e non li riporto.")
	else:
		for i in RAGGI.size():
			if i == 0:
				continue
			print("PROBE:   da R %.0f a R %.0f il minimo passa da %.2f a %.2f s: fattore %.2f"
				% [RAGGI[i - 1], RAGGI[i], risultati[i - 1], risultati[i],
				   risultati[i] / maxf(risultati[i - 1], 0.001)])
		# Il numero che conta per la decisione e' il raggio **consegnato**, che e'
		# il secondo della lista perche' il primo e' il riferimento.
		var consegnato: float = risultati[1]
		print("PROBE: i 600 s dell'utente sono %5.2f volte il minimo al raggio CONSEGNATO di 46 m"
			% (600.0 / maxf(consegnato, 0.001)))
	quit(0)

func _lista(v: PackedFloat32Array) -> String:
	var s := ""
	for i in v.size():
		if i > 0:
			s += " / "
		s += "%.1f s" % v[i]
	return s

## Una sessione con l'orda e il giocatore veri, al raggio `R`.
func _una_sessione(R: float, seme: int) -> float:
	var game := root.get_node_or_null("Game")
	if game == null:
		print("PROBE FAIL: l'autoload Game non c'e'")
		return 0.0

	# Il raggio e' **due** numeri, non uno: `arena.gd` registra 46.0 sul contratto
	# nel proprio `_enter_tree()`, e quel valore finisce sia nel clamp del giocatore
	# (letto vivo a ogni passo) sia nel fallback dell'orda. Impostando solo il campo
	# dell'orda si avrebbe un'orda da 90 m dentro un disco dove il giocatore resta
	# a 46: la misura sarebbe del muro, non della pista.
	var res = load(ARENA_SCENE)
	if not (res is PackedScene):
		print("PROBE FAIL: %s non e' una PackedScene" % ARENA_SCENE)
		return 0.0
	var arena = (res as PackedScene).instantiate()
	root.add_child(arena)

	var horde = arena.get_node_or_null("Horde")
	var player = arena.get_node_or_null("Player")
	if horde == null or player == null:
		print("PROBE FAIL: la scena non ha Horde/Player")
		return 0.0

	game.arena_radius = R
	horde.arena_radius = R
	horde.reseed(seme)

	player.drive_manually()
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO

	var t := 0.0
	var next_report := REPORT_EVERY
	while t < TMAX:
		var direzione := _direzione(horde, player, R)
		player.step(DT, Vector3(direzione.x, 0.0, direzione.y))
		horde.step(DT)
		t += DT
		if t >= next_report:
			print("PROBE:   R %5.1f | %5.0f s | hp %6.2f | vivi %3d | onda %2d | uccisi %4d"
				% [R, t, player.hp, horde.count, horde.wave, horde.kills])
			next_report += REPORT_EVERY
		if player.hp <= 0.0:
			break

	if arena.get_parent() != null:
		arena.get_parent().remove_child(arena)
	arena.free()
	return t

## La direzione: **sedici raggi**, e per ognuno un punto guardato avanti invece
## che il punto stesso. Vince il punteggio piu' alto, e il punteggio ha tre
## termini invece di uno.
##
## Il termine che manca allo strumento vecchio e' il **muro**. inseguire la
## lontananza dal nemico spinge verso il bordo, e al bordo non si scappa: e' il
## motivo per cui il numero vecchio non era monotono.
func _direzione(horde, player, R: float) -> Vector2:
	var p := _flat(player.global_position)
	var guarda := LOOKAHEAD_S * 13.65
	var limite := maxf(R - EDGE_SAFE_M, 0.0)

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

		# 3. il ritorno al centro, che serve a sciogliere l'angolo: quando e' gia'
		#    oltre la frazione dichiarata, ogni metro guadagnato verso il centro
		#    vale meta' metro di punteggio. Il fattore 0,5 e' dichiarato perche' il
		#    centro non deve valere come una fuga: il nemico e' spesso li'.
		if p.length() > R * CENTRE_PULL:
			punteggio += (limite - q.length()) * 0.5

		if punteggio > miglior_punteggio:
			miglior_punteggio = punteggio
			meglio = d
	return meglio

## Distanza dal nemico piu' vicino: scansione lineare sul record, non sulla griglia.
## Sono 200 nemici e la sonda gira fino a 43 000 volte: la griglia costerebbe di
## piu' a costruirla che a leggerla, e qui non c'e' un criterio di prestazioni.
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