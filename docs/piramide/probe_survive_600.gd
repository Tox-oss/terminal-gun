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
## - scala 1.00: il riferimento e' **26,42 s**, misurato il 2026-10-15 con la
##   stessa sonda dopo m14-a e m14-b e **dopo** che questa sonda ha imparato a
##   guardare la cupola rossa. Sostituisce il 41,73 s, RITIRATO: dopo quel
##   numero sono arrivate due cose che lo spostano, entrambe misurate e
##   intenzionali.
##     - m14-a: l'involucro del proiettile e' passato da 0,55 m a 1,53-6,46 m.
##       L'onda 1 si chiude in 46,68 s invece di 56,78 s.
##     - m14-b: il mortar e' spendibile al 5,75% e fa 65,83 hp/s da solo.
##   I riferimenti precedenti sono gia' stati sostituiti due volte (82,03 s a un
##   morso che non era quello disegnato, 44,20 s a un gioco col boss
##   nell'apertura), e usarli come risposta nota aveva fatto sembrare rotta una
##   sonda che era solo vecchia. **Questa volta il numero nuovo e' anche il primo
##   dopo che lo strumento ha smesso di essere cieco**, quindi non e' confrontabile
##   coi tre precedenti come se fosse la sola cosa cambiata: e' cambiato anche chi
##   schiva. Va detto, altrimenti il confronto mente.
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
const SCALE := [0.0, 0.25, 0.50, 1.00]

## ## m14-c: LA SONDA ERA CIECA AL MORTAR, e va detto prima del numero
##
## Questa sonda e' stata scritta prima che il mortar esistesse e **non leggeva
## `horde.mortar_shots`**: il suo steering sceglieva la direzione che
## massimizza la distanza dal nemico piu' vicino, e un colpo in arrivo non
## cambiava niente del punteggio. Con il mortar in gioco al 5,75% quello
## significa che **i 65,83 hp/s che lo uccidono sarebbero arrivati addosso a
## uno schivatore che guarda solo in terra**. Il numero che ne sarebbe uscito
## non avrebbe descritto nessun giocatore: avrebbe descritto uno che non guarda
## la cupola rossa, che e' esattamente la cosa che nessuno fa.
##
## Quindi qui il termine della cupola e' **deliberatamente esagerato**: non si
## prova a essere un giocatore bravo, si prova a essere **uno che guarda in
## alto**, cosi' il confronto fra «prima» e «dopo» non e' offuscato da quanto
## questo criterio e' generoso. Se con un criterio generoso la taratura serve
## ancora, allora serve davvero.

const E := preload("res://src/sim/enemy.gd")

## Velocita' del giocatore, la stessa delle due righe di stampa
## (`LOOKAHEAD_S * 13.65`). Serve alla domanda «quanto lontano posso essere
## quando il colpo cade».
const VELOCITA := 13.65
## Prudenza oltre il raggio del colpo: il colpo copre `mortar_blast_m` e il
## giocatore e' considerato al sicuro piu' in la' di quello. Non e' il raggio.
const FUGA_M := 0.45
const PENALITA_MORTAR := 3.0

var _game
## La penalita' massima mai calcolata e il numero di passi in cui c'erano cupole
## in volo. Serve a **non poter ripetere in silenzio** il difetto del termine
## identicamente nullo: se ci sono state cupole e la penalita' e' rimasta a
## zero, la sonda lo dice ad alta voce invece di produrre un numero che sembra
## misurato e non lo e'.
var _penalita_max := 0.0
var _passi_con_cupola := 0

const SEMI := [4242, 7311, 20260912]

var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true

func _run() -> void:
	_game = root.get_node_or_null("Game")
	if _game == null:
		print("PROBE FAIL: autoload Game assente.")
		quit(1)
		return
	print("PROBE: m14-c, apertura a 600 s col mortar in gioco. Leva: population_scale.")
	print("PROBE: DT=%.5f, %d raggi, sguardo %.1f s (%.1f m), margine %.1f m"
		% [DT, RAYS, LOOKAHEAD_S, LOOKAHEAD_S * 13.65, EDGE_SAFE_M])
	print("PROBE: raggio %.1f m, scena vera 27 ostacoli, arma vera." % RAGGIO)
	print("PROBE: TMAX=%.0f s. MORTO=caduto prima del tetto, TETTO=sopravvissuto." % TMAX)
	print("PROBE: scala 0.00 DEVE toccare il tetto (nessun nemico = non si muore).")
	print("PROBE: scala 1.00 DEVE dare minimo 26.42 s (misurato il 2026-10-15, m14-a+b, sonda con cupola).")
	print("PROBE: lo steering guarda la cupola rossa (m14-c): termine pesante, dichiarato esagerato.")
	print("")

	var risultati := PackedFloat32Array()         # minimo per scala
	var stati := []                               # "MORTO" o "TETTO" per il minimo
	var uccisori_scala := []                     # specie dell'ultimo morso, per seme
	var presenze_scala := []                      # specie a portata ai morsi
	var morsi_scala := []
	var riferimento_ok := false

	for si in SCALE.size():
		var s: float = SCALE[si]
		var campioni := PackedFloat32Array()
		var campioni_stato := []
		var uccisori := []
		var presenze_somma := {"runner": 0, "grunt": 0, "brute": 0, "boss": 0, "mortar": 0}
		var morsi_tot := 0
		var colpi_tot := 0

		for sd in SEMI:
			var esito := _una_sessione(int(sd), s)
			campioni.append(esito[0])
			campioni_stato.append(esito[1])
			uccisori.append(esito[2])
			morsi_tot += int(esito[4])
			colpi_tot += int(esito[5])
			for nome in E.KIND_NAMES:
				presenze_somma[nome] += int(esito[3][nome])

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
		uccisori_scala.append(uccisori)
		presenze_scala.append(presenze_somma)
		morsi_scala.append(morsi_tot)

		print("PROBE: RISULTATO scala %.2f | 3 semi: %s | MIN %6.2f s [%s] | MAX %6.2f s"
			% [s, _lista(campioni, campioni_stato), peggiore_t, peggiore_stato, migliore_t])
		print("PROBE:   morsi totali %d e colpi del mortar %d in tre semi | ultimo danno, per seme: %s"
			% [morsi_tot, colpi_tot, _lista_uccisori(uccisori)])
		print("PROBE:   specie a portata quando e' avvenuto un morso, somma dei tre semi: %s"
			% _conta(presenze_somma))
		print("PROBE:   danno per evento, somma dei tre semi: %s"
			% _danno(presenze_somma, colpi_tot))

		if is_zero_approx(s):
			riferimento_ok = (peggiore_stato == "TETTO")
			if riferimento_ok:
				print("PROBE: RIFERIMENTO scala 0.00: TETTO a %.2f s COME DEVE. Strumento in piedi." % peggiore_t)
			else:
				print("PROBE: RIFERIMENTO scala 0.00 NON ha toccato il tetto: strumento ROTTO. Interrompo.")
				quit(1)
				return

		if is_equal_approx(s, 1.0):
			print("PROBE: scala 1.00 (oggi): minimo %.2f s vs 41.73 s noti." % peggiore_t)

	print("")
	print("PROBE: LETTURA FINALE")
	for si in SCALE.size():
		var s: float = SCALE[si]
		print("PROBE:   scala %.2f | MIN %6.2f s | %s" % [s, risultati[si], stati[si]])
	print("")
	print("PROBE: IL TERMINE DELLA CUPOLA HA LAVORATO?")
	print("PROBE:   passi con almeno una cupola in volo: %d | penalita' massima mai calcolata: %.4f"
		% [_passi_con_cupola, _penalita_max])
	if _passi_con_cupola > 0 and _penalita_max <= 0.0:
		print("PROBE:   **AVVERTENZA: cupole in volo e penalita' SEMPRE ZERO.** Il termine non sta")
		print("PROBE:   schivando niente e i numeri qui sotto valgono come caso CIECO. Non fidarti.")
	else:
		print("PROBE:   il termine ha inciso su almeno una scelta di direzione: i numeri qui sotto")
		print("PROBE:   sono di uno schivatore che guarda in alto.")

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

	# m11-ter-quarta: la domanda che chiude l'ipotesi. Non e' chi morde di piu' in
	# assoluto, e' chi morde quando il giocatore cade: una specie puo' essere la piu'
	# frequente ai morsi e non essere quella che ha finito la partita.
	print("")
	print("PROBE: CHI UCCIDE")
	for si in SCALE.size():
		var s: float = SCALE[si]
		if stati[si] == "TETTO":
			print("PROBE:   scala %.2f -> nessuna caduta: nessun uccisore da dichiarare." % s)
			continue
		var pres: Dictionary = presenze_scala[si]
		var dominante := "-"
		var peggiore := -1
		for k in E.KIND_NAMES:
			if int(pres[k]) > peggiore:
				peggiore = int(pres[k])
				dominante = k
		var uccisori_ebbene := {}
		for u in uccisori_scala[si]:
			uccisori_ebbene[u] = int(uccisori_ebbene.get(u, 0)) + 1
		var lista := ""
		for k in E.KIND_NAMES:
			if int(uccisori_ebbene.get(k, 0)) > 0:
				if lista != "":
					lista += ", "
				lista += "%s %d su 3" % [k, int(uccisori_ebbene[k])]
		print("PROBE:   scala %.2f -> uccisori: %s | specie piu' presente ai morsi: %s"
			% [s, lista, dominante])
	quit(0)

func _lista(campioni: PackedFloat32Array, stati_c: Array) -> String:
	var out := ""
	for i in campioni.size():
		if i > 0:
			out += " / "
		out += "%.1f s[%s]" % [campioni[i], stati_c[i]]
	return out

## Ritorna [tempo_float, "MORTO"|"TETTO", specie_che_ha_morso_l_ultima, presenze, morsi]
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

	# MISURA m11-ter-quarta: chi morde. Il vertice non puo' modificare src/, quindi
	# l'attribuzione e' osservata e non instrumentata: ad ogni calo di hp leggo chi
	# era a portata di morso in quell'istante. Dichiarato come inferenza, non come
	# fatto: se piu' nemici sono in portata nello stesso passo registro TUTTI e non
	# scelgo, e l'ultimo morso e' attribuito al piu' vicino con la sua distanza.
	var presenze := {"runner": 0, "grunt": 0, "brute": 0, "boss": 0, "mortar": 0}
	var morsi := 0
	var colpi := 0
	var uccisore := "-"
	var uccisore_colpo := false
	var dist_ultimo := INF

	var t := 0.0
	var next_report := REPORT_EVERY
	var hp_prec: float = player.hp
	while t < TMAX:
		var direzione := _direzione(horde, player, ostacoli)
		## m14-c: la distanza dalla cupola piu' vicina va letta **prima** del
		## passo, perche' dopo il colpo e' gia' sparito dal canale. E' l'unico
		## modo di dire "colpito a N metri dalla cupola" senza instrumentare
		## l'orda, che non e' di questa sonda.
		var dist_dome := _distanza_dome_minima(horde, _flat(player.global_position))
		player.step(DT, Vector3(direzione.x, 0.0, direzione.y))
		horde.step(DT)
		t += DT

		if player.hp < hp_prec:
			## Due fonti, non una. `touch_damage_last` vale 0 quando in questo
			## passo nessun morso e' andato a segno; `mortar_impacts_last` conta
			## i colpi caduti. Nello stesso passo possono accadere entrambe: in
			## quel caso si registrano **entrambe** e non si sceglie. Dichiarato,
			## non nascosto.
			var morso: bool = horde.touch_damage_last > 0.0
			var colpo: bool = horde.mortar_impacts_last > 0
			if morso:
				morsi += 1
				var chi := _chi_morde(horde, _flat(player.global_position))
				for nome in chi["in_portata"]:
					presenze[nome] += 1
				uccisore = chi["vicino"]
				uccisore_colpo = false
				dist_ultimo = chi["distanza"]
			if colpo:
				colpi += 1
				## Il nome che va in `uccisore` deve essere **uno di `KIND_NAMES`**:
				## il riepilogo finale confronta per nome, quindi scrivere
				## "mortar (colpo)" qui faceva comparire una lista di uccisori
				## **vuota** mentre le sessioni dicevano il contrario. Il flag
				## porta la distinzione, il nome resta pulito.
				if not morso:
					uccisore = "mortar"
					uccisore_colpo = true
					dist_ultimo = dist_dome
		hp_prec = player.hp

		if t >= next_report:
			print("PROBE:     | %5.0f s | hp %6.2f | vivi %3d | onda %2d | uccisi %4d"
				% [t, player.hp, horde.count, horde.wave, horde.kills])
			next_report += REPORT_EVERY
		if player.hp <= 0.0:
			print("PROBE:     MORTO a %.2f s | ultimo danno: %s%s a distanza %s m | %d morsi e %d colpi del mortar in tutto"
				% [t, uccisore, " (colpo)" if uccisore_colpo else "",
					("%.2f" % dist_ultimo) if dist_ultimo < INF else "?", morsi, colpi])
			print("PROBE:     a portata durante i morsi: %s"
				% _conta(presenze))
			if arena.get_parent() != null:
				arena.get_parent().remove_child(arena)
			arena.free()
			return [t, "MORTO", uccisore, presenze, morsi, colpi]

	if arena.get_parent() != null:
		arena.get_parent().remove_child(arena)
	arena.free()
	return [t, "TETTO", uccisore, presenze, morsi, colpi]


func _conta(presenze: Dictionary) -> String:
	var out := ""
	for k in E.KIND_NAMES:
		if out != "":
			out += ", "
		out += "%s %d" % [k, presenze[k]]
	return out


func _danno(presenze: Dictionary, colpi_tot: int) -> String:
	var out := ""
	for k in E.KIND_NAMES:
		if out != "":
			out += ", "
		out += "%s %.2f" % [k, float(presenze[k]) * E.touch_damage_of(E.KIND_NAMES.find(k))]
	# m14-c: i **colpi** del mortar sono una riga a se'. Prezarli dentro la voce
	# `mortar` insieme ai morsi avrebbe detto che il mortar fa 13,71 hp a ogni
	# sua presenza, che e' falso: il suo morso vale 7,31 come gli altri, il colpo
	# vale 13,71 e arriva al momento dell'impatto. Due fatti, due prezzi.
	out += ", mortar-colpi %d (%.2f hp)" % [colpi_tot, float(colpi_tot) * E.MORTAR_BLAST_HP]
	return out


func _lista_uccisori(uccisori: Array) -> String:
	var out := ""
	for i in uccisori.size():
		if i > 0:
			out += " / "
		out += "%s %s" % [SEMI[i], uccisori[i]]
	return out


## Chi era a portata di morso del giocatore in questo istante, e chi era il piu'
## vicino. Lettura di horde.kinds / horde.transforms e di bite_range_of, quindi la
## portata che vede la sonda e' la stessa che usa la simulazione, non una ricostruita.
func _chi_morde(horde, p: Vector2) -> Dictionary:
	var ts: PackedVector3Array = horde.transforms
	var in_portata: Array = []
	var vicino := "-"
	var vicino_d := INF
	for i in horde.count:
		var k: int = horde.kinds[i]
		var d := p.distance_to(Vector2(ts[i].x, ts[i].z))
		if d <= horde.bite_range_of(k):
			var nome: String = E.KIND_NAMES[E.clamp_kind(k)]
			in_portata.append(nome)
			if d < vicino_d:
				vicino_d = d
				vicino = nome
	return {"vicino": vicino, "in_portata": in_portata, "distanza": vicino_d}

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

		## m14-c: **la cupola rossa**. Il punteggio guarda solo dove il giocatore
		## ha un nemico addosso, quindi senza questo termine un colpo in arrivo non
		## cambia niente e arriva sempre. E' il termine che distingue questa sonda
		## da una che gira a caso.
		punteggio -= _penalita_mortar(horde, p, q)

		if p.length() > RAGGIO * CENTRE_PULL:
			punteggio += (limite - q.length()) * 0.5

		if punteggio > miglior_punteggio:
			miglior_punteggio = punteggio
			meglio = d
	return meglio

## Quanto costa questa direzione **perche' un colpo del mortar cade dove
## porta**. Non e' «dove saro fra `guarda` secondi» ma «dove saro **quando
## cade**»: al colpo restano `residui` secondi e il giocatore copre al massimo
## `residui x VELOCITA` metri, quindi la domanda e' se quella distanza lo
## lascia fuori. `mortar_blast_m` e `mortar_telegraph_s` vengono **dal
## contratto**, non da costanti qui: se il raggio del colpo cambiasse, questa
## funzione continuerebbe a dire la verita' senza toccare una riga.
##
## Il modello e' **a punto** — la posizione di arrivo e' valutata, non il
## percorso — e dichiarato tale: e' la stessa semplificazione gia' presente in
## questo steering, che valuta 16 punti e non 16 traiettorie.
## Distanza dalla cupola piu' vicina fra quelle in volo, o INF se non ce n'e'
## nessuna. Il canale e' `horde.mortar_shot_count` / `mortar_shot_at`, quindi
## la sonda guarda **lo stesso canale che guarda la cupola rossa a schermo**:
## non ricostruisce il punto di caduta, lo legge.
func _distanza_dome_minima(horde, p: Vector2) -> float:
	var m := INF
	for i in horde.mortar_shot_count:
		var s: Vector3 = horde.mortar_shot_at(i)
		m = minf(m, p.distance_to(Vector2(s.x, s.z)))
	return m

## Quanti punti del cammino vengono valutati. Vedi la trappola sotto: **uno non basta**.
const CAMPIONI := 4

## Quanto costa questa direzione **perche' un colpo del mortar cade dove
## porta**.
##
## ## LA TRAPPOLA, e ci sono cascato una volta
##
## La prima versione valutava **solo il punto di arrivo** `q`, a `guarda`
## metri, e chiedeva «arrivo prima che il colpo cada?». Ma `guarda` e' sempre
## 20,5 m, quindi il tempo d'arrivo e' sempre `LOOKAHEAD_S = 1,5 s`, e il
## telegrrafo e' `0,8293 s`: `1,5 > 0,8293` **sempre**, per ogni direzione e
## ogni colpo. La penalita' era **identicamente zero** e la sonda misurava di
## nuovo uno schivatore cieco, con un termine che sembrava fare il suo lavoro.
## Il sintomo era invisibile: nessun errore, solo un numero un po' peggiore.
##
## Quindi qui si valuta il **cammino**, non la destinazione: `CAMPIONI` punti
## fra `p` e `q`, ognuno con il suo istante, e ogni punto che il giocatore
## attraversa **prima** della caduta ed e' dentro la cupola costa.
##
## Il modello resta dichiaratamente a tratto retto: il giocatore va in linea
## retta verso `q`. E' la stessa semplificazione del resto dello steering, che
## valuta 16 raggi e non traiettorie morbide.
func _penalita_mortar(horde, p: Vector2, q: Vector2) -> float:
	var peggiore := 0.0
	var tele: float = _game.mortar_telegraph_s
	if tele <= 0.0:
		return 0.0
	var raggio: float = _game.mortar_blast_m + FUGA_M
	var passo := (q - p) / float(CAMPIONI)
	for i in horde.mortar_shot_count:
		var residui: float = horde.mortar_shot_left(i)
		var s: Vector3 = horde.mortar_shot_at(i)
		var centro := Vector2(s.x, s.z)
		for c in CAMPIONI:
			# istante in cui il giocatore e' su questo punto
			if float(c) * (LOOKAHEAD_S / float(CAMPIONI)) > residui:
				continue          # quel punto e' gia' dopo la caduta
			var dentro := raggio - (p + passo * float(c)).distance_to(centro)
			if dentro <= 0.0:
				continue
			# piu' il colpo e' vicino alla caduta, meno tempo c'e' per scegliere
			# bene: due colpi insieme non si schivano scegliendo la direzione
			# migliore al primo passo, quindi l'urgenza pesa.
			var urgenza := 1.0 + (1.0 - clampf(residui / tele, 0.0, 1.0)) * 2.0
			peggiore = maxf(peggiore, dentro * urgenza * PENALITA_MORTAR)
	if horde.mortar_shot_count > 0:
		_passi_con_cupola += 1
	_penalita_max = maxf(_penalita_max, peggiore)
	return peggiore

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
