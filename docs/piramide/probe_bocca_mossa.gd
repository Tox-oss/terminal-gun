extends SceneTree
## MISURA DI m11 -- piano docs/piramide/piano.md sez. 1.14-ottavadecima
##
##     godot --headless --path . --script res://docs/piramide/probe_bocca_mossa.gd
##
## Domanda, detta dall'utente il 2026-10-15 dopo aver provato l'eseguibile:
## «prendo danno solo quando sto fermo, posso correre attraverso orde di nemici
## senza problemi».
##
## ## Perche' questa domanda ha due risposte opposte
##
## La frase dell'utente puo' significare:
##
##   (a) **design**: in movimento il giocatore offre meno occasioni di morso,
##       perche' attraversa il corpo del nemico e passa oltre prima che il
##       timer di morso scatti. Il gioco e' piu' permissivo in corsa.
##   (b) **difetto**: il danno non viene applicato affatto quando il giocatore
##       si muove. Il nemico e' a portata ma il morso non parte mai.
##
## Le due hanno rimedi opposti: la prima si bilancia, la seconda si corregge.
## **Non si decide a parole**, e non si decide guardando che il giocatore
## sopravvive: sopravvive anche un bug.
##
## ## Che cosa distingue le due
##
## Il **conteggio delle opportunita'**: quanti passi di gioco ci sono stati in
## cui almeno un nemico era entro la propria portata di morso dal giocatore.
##
## - Se le opportunita' in corsa sono **zero**, il danno e' giustamente
##   assente: e' (a), e il numero da cambiare e' la portata o il timer.
## - Se le opportunita' in corsa sono **poche ma non zero** e i morsi sono
##   proporzionalmente radi, e' ancora (a), ma con una soglia.
## - Se le opportunita' in corsa sono **tante** e i morsi sono **zero**, e'
##   (b), ed e' un difetto: il nemico e' addosso e non morde.
##
## Il terzo numero, **quanti morsi in totale e quanto danno**, chiude la
## domanda dal lato del giocatore.
##
## ## Le tre condizioni, e perche' sono tre
##
## `fermo`: input nullo. E' il caso da cui l'utente dice di prendere danno.
##
## `gira`: corsa a velocita' piena con la direzione che ruota lentamente.
## E' lo schivatore: attraversa l'orda che lo insegue.
##
## `dritta`: corsa a velocita' piena con direzione costante, che si capovolge
## quando il giocatore si avvicina al muro. E' il «corro dritto» dell'utente.
##
## Se `gira` prende danno e `dritta` no, allora la differenza non e' «in
## movimento»: e' **dove** il giocatore guarda mentre corre, e il difetto e'
## altrove. Per questo ci sono tre condizioni e non due.
##
## ## I casi a risposta nota
##
## - `fermo` **DEVE** prendere danno: `test_orda` misura gia' che fermo al
##   centro con 200 vivi il giocatore muore in 22,62 s. Se `fermo` prendesse
##   zero danno, lo strumento non starebbe guardando il danno.
## - `fermo` e `dritta` devono dare lo **stesso numero dioccasioni** a parita'
##   di posizione: se il numero di occasioni cambia solo con la direzione,
##   allora il contatore sta misurando la posizione e non il danno.

const ARENA_SCENE := "res://scenes/arena_main.tscn"

const DT := 1.0 / 60.0
const FINESTRA := 30.0
const RAGGIO := 60.0
const MARGINE_MURO := 3.0
const SEMI := [4242, 7311, 20260912]
const SCALA := 1.0

const E := preload("res://src/sim/enemy.gd")

## La condizione e' una funzione che, dato il tempo, restituisce la direzione
## di corsa. Le tre sono diverse funzioni e non un intero: cosi' il file dice
## cosa fa ogni riga invece di dirlo solo al nome.
var _condizioni := [
	["fermo", func(_t: float) -> Vector2: return Vector2.ZERO],
	["gira", func(t: float) -> Vector2:
		var a := t * TAU / 8.0
		return Vector2(cos(a), sin(a))],
	["dritta", null],
]

var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true

func _run() -> void:
	print("PROBE: m11-ottavadecima, danno in movimento. Leva: la corsa del giocatore.")
	print("PROBE: DT=%.5f, finestra %.0f s, scala %.2f, raggio %.1f m, scena vera"
		% [DT, FINESTRA, SCALA, RAGGIO])
	print("PROBE: scala 0.00 non serve qui: la leva non e' la popolazione.")
	print("PROBE: caso a risposta NOTA: 'fermo' DEVE prendere danno. Se prende zero,")
	print("PROBE: lo strumento non sta guardando il danno e i numeri non valgono.")
	print("")

	var _dritta := 0.0
	_condizioni[2][1] = func(t: float) -> Vector2:
		return Vector2(cos(_dritta), sin(_dritta))

	var tabella := []
	for cond in _condizioni:
		var nome: String = cond[0]
		var righe := []
		for sd in SEMI:
			righe.append(_una_sessione(nome, int(sd), cond[1]))
		tabella.append([nome, righe])

	print("PROBE: TABELLA, per condizione e per seme")
	print("PROBE:   condizione | seme | hp perso | morsi | occasioni (passi con un nemico a portata) | in portata per specie")
	for riga in tabella:
		var nome: String = riga[0]
		for i in (riga[1] as Array).size():
			var e: Dictionary = (riga[1] as Array)[i]
			print("PROBE:   %s | %d | %6.2f | %4d | %6d | %s"
				% [nome, SEMI[i], e["hp_perso"], e["morsi"], e["occasioni"], e["per_specie"]])
	print("")

	print("PROBE: LETTURA")
	var fermo_ok := true
	for riga in tabella:
		var nome: String = riga[0]
		var perduti := 0.0
		var morsi := 0
		var occ := 0
		for e in (riga[1] as Array):
			perduti += float(e["hp_perso"])
			morsi += int(e["morsi"])
			occ += int(e["occasioni"])
		var per_morso := 0.0 if morsi == 0 else perduti / float(morsi)
		print("PROBE:   %s: hp perso %6.2f sui tre semi, %d morsi, %d occasioni, %.2f hp per morso"
			% [nome, perduti, morsi, occ, per_morso])
		if nome == "fermo":
			fermo_ok = perduti > 0.0
			if not fermo_ok:
				print("PROBE:     CASO A RISPOSTA NOTA VIOLATO: fermo non prende danno.")
				print("PROBE:     Lo strumento non sta guardando il danno. Interrompo.")
				quit(1)
				return

	print("")
	print("PROBE: LA DOMANDA, in una riga per condizione")
	for riga in tabella:
		var nome: String = riga[0]
		var morsi := 0
		var occ := 0
		for e in (riga[1] as Array):
			morsi += int(e["morsi"])
			occ += int(e["occasioni"])
		if occ == 0:
			print("PROBE:   %s -> 0 occasioni: il danno manca perché il nemico non c'e' mai stato a portata. DESIGN." % nome)
		elif morsi == 0:
			print("PROBE:   %s -> %d occasioni e 0 morsi: il nemico e' addosso e NON morde. DIFETTO." % [nome, occ])
		else:
			print("PROBE:   %s -> %d occasioni e %d morsi (%.1f%% delle occasioni): DESIGN con soglia."
				% [nome, occ, morsi, 100.0 * float(morsi) / float(occ)])
	quit(0)

## Ritorna un dizionario con i numeri della finestra.
func _una_sessione(nome: String, seme: int, direzione: Callable) -> Dictionary:
	var game := root.get_node_or_null("Game")
	if game == null:
		print("PROBE FAIL: autoload Game assente.")
		return {"hp_perso": 0.0, "morsi": 0, "occasioni": 0, "per_specie": "-"}

	var res = load(ARENA_SCENE)
	var arena = (res as PackedScene).instantiate()
	var horde = arena.get_node_or_null("Horde")
	var player = arena.get_node_or_null("Player")
	if horde == null or player == null:
		print("PROBE FAIL: Horde o Player assente nella scena.")
		return {"hp_perso": 0.0, "morsi": 0, "occasioni": 0, "per_specie": "-"}

	# PRIMA di add_child: _build() gira in _ready() e decide la popolazione.
	horde.population_scale = SCALA
	game.arena_radius = RAGGIO
	root.add_child(arena)
	horde.arena_radius = RAGGIO
	horde.reseed(seme)
	player.drive_manually()
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO

	var occ := 0
	var morsi := 0
	var per_specie := {"runner": 0, "grunt": 0, "brute": 0, "boss": 0}
	var hp_iniziale: float = player.hp
	var hp_prec: float = player.hp
	var dir := Vector2(1.0, 0.0)
	var t := 0.0

	while t < FINESTRA:
		var d: Vector2 = direzione.call(t)
		var p := _flat(player.global_position)

		# opportunita': quante volte, in questo passo, almeno un nemico e'
		# entro la propria portata dal giocatore
		var chi := _chi_morde(horde, p)
		var in_portata: Array = chi["in_portata"]
		if in_portata.size() > 0:
			occ += 1
			for n in in_portata:
				per_specie[n] += 1

		# la direzione `dritta` si capovolge quando il giocatore e' vicino al muro
		if nome == "dritta" and p.length() > RAGGIO - MARGINE_MURO:
			dir = -dir
			d = dir

		player.step(DT, Vector3(d.x, 0.0, d.y))
		horde.step(DT)
		t += DT

		if player.hp < hp_prec:
			morsi += 1
		hp_prec = player.hp

	var hp_finale: float = player.hp
	if arena.get_parent() != null:
		arena.get_parent().remove_child(arena)
	arena.free()

	return {
		"hp_perso": hp_iniziale - hp_finale,
		"morsi": morsi,
		"occasioni": occ,
		"per_specie": _conta(per_specie),
	}

func _chi_morde(horde, p: Vector2) -> Dictionary:
	var ts: PackedVector3Array = horde.transforms
	var in_portata: Array = []
	for i in horde.count:
		var k: int = horde.kinds[i]
		var d := p.distance_to(Vector2(ts[i].x, ts[i].z))
		if d <= horde.bite_range_of(k):
			in_portata.append(E.KIND_NAMES[E.clamp_kind(k)])
	return {"in_portata": in_portata}

func _conta(per_specie: Dictionary) -> String:
	var out := ""
	for k in E.KIND_NAMES:
		if out != "":
			out += ", "
		out += "%s %d" % [k, per_specie[k]]
	return out

func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)