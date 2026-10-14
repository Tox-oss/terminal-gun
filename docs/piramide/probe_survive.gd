extends SceneTree
## ESPERIMENTO DEL VERTICE (m11) - piano docs/piramide/piano.md sez. 1.14.
##
##     godot --headless --path . --script res://docs/piramide/probe_survive.gd
##
## Domanda: **dieci minuti sono raggiungibili? E se no, il vincolo e' la PISTA o la
## DIFFICOLTA'?**
##
## Il piano non scrive un numero di durata prima di aver misurato (§1.4b: «nessuna cifra
## di questa milestone e' scritta sopra»). Questo probe non cambia niente: misura quanto
## vive un giocatore che schiva davvero, e poi misura la **stessa** schivatrice al variare
## del raggio dell'arena.
##
## Il primo giro ha detto: **163,77 s**, cioe' 2,73 minuti, e i 600 s dell'utente sono
## 3,66 volte tanto. Ed e' morto **all'onda 1, con 25 nemici vivi**: la rampa non e' il
## problema, perche' non si arriva all'onda 8.
##
## Il secondo giro e' quello che decide, e separa due rimedi **opposti**:
##
##   - se la sopravvivenza **cresce** con il raggio, il vincolo e' la **pista**: uno che
##     fugge in un disco chiuso finisce contro il muro, e la mappa piu' grande e' il
##     rimedio. (E sarebbe la **seconda volta** che la misura corregge la conclusione di
##     m9: li' il numero era giusto e la conclusione no, perche' m9 guardava l'**area
##     libera** e questa guarda la **distanza di fuga**.)
##   - se la sopravvivenza **non si muove**, il vincolo e' la **difficolta'**: l'onda 1 e'
##     troppo dura e la mappa non c'entra.
##
## ## Che cos'e' lo «schivatore», e che cosa NON puo' dire
##
## Il giocatore e' **uno che ho scritto io**, e quindi puo' dire **che cosa e' possibile**
## e non **che cosa e' divertente**. L'utente lo sa e ha accettto esplicitamente («basta
## correre, vediamo che dice la misura»), quindi il numero e' una **soglia di
## fattibilita'**. E' dichiarato qui perche' un numero senza questa riga viene citato
## l'anno prossimo come se fosse una misura di giocabilta'.
##
## Il giocatore e' **quello vero**, non un finto: `drive_manually()` e `player.step()` passano
## dal codice di -gameplay, quindi velocita', accelerazione, clamp all'arena e clamp agli
## ostacoli sono quelli del gioco. Il nemico e' quello vero, l'arma e' quella vera e spara
## da sola, la scena e' quella vera con i 27 ostacoli.
##
## Solo la **direzione** e' mia: otto raggi, e vince quello che **aumenta** la distanza dal
## nemico piu' vicino. Nessuna memoria, nessuna previsione, nessun path. Uno schivatore che
## guarda solo il nemico piu' vicino e' **peggio** di uno bravo, e percio' il numero che esce
## e' una soglia **bassa**: se dieci minuti sono raggiungibili cosi', lo sono anche per un
## giocatore vero.

const ARENA_SCENE := "res://scenes/arena_main.tscn"

const DT := 1.0 / 60.0
## Dieci minuti e un pezzo oltre, cosi' la misura dice anche che cosa succede **dopo**.
## **Accorciato a 300 s** rispetto al giro precedente, e per un motivo dichiarato: la
## domanda e' binaria («muore presto» oppure «regge oltre i 5 minuti»), e 720 s non
## aggiunge informazione a una risposta che e' gia' arrivata al tetto.
const TMAX := 300.0
## Una stampa ogni 60 s: abbastanza per vedere la curva, non tanto da costare il probe.
const REPORT_EVERY := 60.0
## Otto raggi e non sedici: sedici costerebbe il doppio per un guadagno che la stampa
## non distingue.
const RAYS := 8

## I raggi su cui la stessa schivatrice viene misurata. **Solo il raggio cambia**: stesso
## codice, stesso numero di raggi, stesso tetto di tempo.
const RAGGI := [46.0, 60.0, 75.0]
## I semi. **Tre, non uno**, e questo e' l'insegnamento del giro precedente: a un solo
## seme il risultato era 124 / 720 / 91 / 127 s, cioe' una **bimodale** che non
## distingueva niente, perche' a decidere era il layout iniziale e non il raggio. Tre
## semi non fanno una media: fanno una **distribuzione**, e quello che si riporta e' il
## minimo, che e' il numero che conta perche' e' la partita peggiore.
const SEMI := [4242, 7311, 20260912]

var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true

func _run() -> void:
	print("PROBE: m11, la pista e' il vincolo? Stessa schivatrice, solo il raggio cambia.")
	print("PROBE: DT=%.5f, %d raggi, tmax %.0f s, scena vera con i 27 ostacoli e l'arma vera"
		% [DT, RAYS, TMAX])
	print("PROBE: sotto il raggio di codice il terreno e il muro restano disegnati a 46 m,")
	print("PROBE: perche' sono costruiti da arena.gd al proprio avvio. Qui si misura lo SPAZIO")
	print("PROBE: che l'orda concede e la PISTA che il giocatore ha, non quello che si vede.")

	var risultati := PackedFloat32Array()
	for r in RAGGI:
		var campioni := PackedFloat32Array()
		for s in SEMI:
			var t := _una_sessione(float(r), int(s))
			campioni.append(t)
		campioni.sort()
		var peggiore: float = campioni[0]
		var migliore: float = campioni[campioni.size() - 1]
		risultati.append(peggiore)
		print("PROBE: RISULTATO R %5.1f m | 3 semi: %s | MINIMO %6.2f s = %5.2f minuti"
			% [r, _lista(campioni), peggiore, peggiore / 60.0])
		if peggiore >= TMAX:
			print("PROBE:   almeno uno dei semi ha raggiunto il tetto di %.0f s: al R %.0f la pista basta"
				% [TMAX, r])
		else:
			print("PROBE:   i 600 s dell'utente sono %5.2f volte il MINIMO, e il minimo e' la partita peggiore"
				% (600.0 / maxf(peggiore, 0.001)))

	print("PROBE: LETTURA")
	for i in RAGGI.size():
		if i == 0:
			continue
		print("PROBE:   da R %.0f a R %.0f il minimo passa da %.2f a %.2f s: fattore %.2f"
			% [RAGGI[i - 1], RAGGI[i], risultati[i - 1], risultati[i], risultati[i] / maxf(risultati[i - 1], 0.001)])
	print("PROBE: se i minimi non crescono monotonamente con R, **la pista non e' il vincolo**")
	print("PROBE: e il numero che resta da spiegare e' la difficolta' dell'onda 1.")
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

	# Il raggio e' **due** numeri, non uno, ed e' il punto che fa fallire il tentativo la
	# prima volta: `arena.gd` registra 46.0 sul contratto nel proprio `_enter_tree()`, e quel
	# valore finisce sia nel clamp del giocatore (`player.gd` lo legge vivo a ogni passo)
	# sia nel fallback dell'orda. Impostando solo il campo dell'orda si avrebbe un'orda
	# da 90 m dentro un disco dove il giocatore resta a 46: la misura sarebbe del muro,
	# non della pista.
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

	# La vita resta quella del gioco: **non la alzo**. Il tempo di morte e' il numero che si
	# cerca, e alzare la vita trasformerebbe la misura in una domanda diversa.
	var t := 0.0
	var next_report := REPORT_EVERY
	while t < TMAX:
		var direzione := _direzione(horde, player)
		player.step(DT, Vector3(direzione.x, 0.0, direzione.y))
		horde.step(DT)
		t += DT
		if t >= next_report:
			print("PROBE:   R %5.1f | %5.0f s | hp %6.2f | vivi %3d | onda %2d | uccisi %4d"
				% [R, t, player.hp, horde.count, horde.wave, horde.kills])
			next_report += REPORT_EVERY
		if player.hp <= 0.0:
			break

	print("PROBE:   R %5.1f terminata a %6.2f s | onda %2d | uccisi %4d | %d vivi"
		% [R, t, horde.wave, horde.kills, horde.count])

	if arena.get_parent() != null:
		arena.get_parent().remove_child(arena)
	arena.free()
	return t

## Gli otto raggi e la scelta del migliore. Vince il raggio che **aumenta** la distanza
## dal nemico piu' vicino; a parita' vince il primo, e il primo e' l'avanti. Non c'e'
## memoria e non c'e' previsione: e' quello che si dichiara e nient'altro.
func _direzione(horde, player) -> Vector2:
	var p := _flat(player.global_position)
	var meglio := Vector2(0.0, -1.0)
	var meglio_d := _distanza_minima(horde, p)
	for i in RAYS:
		if i == 0:
			continue
		var a := TAU * float(i) / float(RAYS)
		var d := Vector2(cos(a), sin(a))
		var dd := _distanza_minima(horde, p + d * 2.0)
		if dd > meglio_d:
			meglio_d = dd
			meglio = d
	return meglio

## Distanza dal nemico piu' vicino: scansione lineare sul record, non sulla griglia.
## Sono 200 nemici e la sonda gira fino a 43 000 volte: la griglia costerebbe di piu' a
## costruirla che a leggerla, e qui non c'e' un criterio di prestazioni da rispettare.
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