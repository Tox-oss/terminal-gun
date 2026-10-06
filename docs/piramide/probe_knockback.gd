extends SceneTree
## ESPERIMENTO DEL VERTICE (m2-w0) - piano docs/piramide/piano.md sez. 1.2.
##
##     godot --headless --path . --script res://docs/piramide/probe_knockback.gd
##
## Domanda: `KNOCKBACK` = 18.0 e `SPEED_MAX` = 18.0 di -orda sono lo stesso numero.
## Se la velocita' del nemico e' saturata dal suo tetto, alzare il knockback non
## sposta niente, e il criterio n. 4 (>= 0.3 unita') risulta accoppiato a un
## numero che NON e' di -gameplay ma di -orda.
##
## Protocollo (sez. 1.2, eseguito letteralmente):
##   1. tre valori di KNOCKBACK, non uno: meta', attuale, doppio. Un solo punto non
##      distingue "saturato" da "cresce"
##   2. la procedura ESATTA di tests/test_arena.gd sez. 7: 5 passi a DT fisso,
##      misura della DELTA DI POSIZIONE, e MAI la velocita' letta prima
##      dell'assestamento
##   3. riporto dei tre numeri e della pendenza
##
## Non e' un finto: scena vera, orda vera, arma vera, percorso del proiettile vero.
## L'unica cosa che cambia rispetto a test_arena.gd e' il VALORE di
## `weapon.knockback`, che e' un campo d'istanza (inizializzato dalla const di
## weapon_base.gd) e quindi si varia a runtime senza toccare il file di -gameplay.
##
## Perche' sta in `docs/piramide/` e non in `tools/`: e' l'unica directory che il
## vertice puo' scrivere. Non e' codice del gioco, e' uno strumento di misura, e
## resta come artefatto riproducibile invece di sparire.

const ARENA_SCENE := "res://scenes/arena_main.tscn"

## Le stesse costanti di tests/test_arena.gd sez. 7. Due file che misurano lo
## stesso numero con finestre diverse non sono confrontabili.
const DT := 1.0 / 60.0
const KNOCKBACK_FRAMES := 5
const SETTLE_FRAMES := 60
const FIRE_FRAMES := 240
const AFTER_HIT_FRAMES := 30
const MIN_SPAWN_DISTANCE := 14.0
## Margine di parete: il nemico deve nascere ben dentro l'arena. Vicino al bordo
## `EDGE_PUSH` di enemy.gd sottrae velocita' radiale verso l'esterno, cioe'
## ESATTAMENTE nel verso del knockback, e la misura diventa rumore di muro. Il
## primo esperimento senza questa guardia ha dato 0.0118 sul grunt a 9.0 m/s,
## trenta volte meno del valore successivo: non era fisica, era il muro.
const WALL_MARGIN := 6.0

## I tre valori che sez. 1.2 punto 1 chiede: meta', attuale, doppio. Il quarto
## (72.0) NON e' richiesto dal piano e serve a una cosa sola: dimostrare il
## **pianoro**. Se 36 -> 72 non sposta niente, la saturazione esiste e il ginocchio
## e' a meta' strada, e allora il quesito di sez. 1.2 ha una risposta vera invece
## che "cresce, per ora".
const CHARGES := [9.0, 18.0, 36.0, 72.0]
## Specie su cui il knockback e' asseverato (resistenza 0 e 0.20, l'80% dell'onda).
const KINDS := [0, 1]

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

	game.arena_radius = 12.0
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
	var weapon = player.get("weapon")
	if weapon == null:
		print("PROBE FAIL: il player non ha un'arma")
		quit(1)
		return

	# Stessa preparazione di test_arena.gd sez. 7: il player non legge la tastiera
	# e il nemico e' uno solo (con 200 la misura sarebbe rumore di folla).
	player.drive_manually()
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO

	var pop_before: int = horde.population
	var respawn_before: bool = horde.auto_respawn
	var interval_before: float = weapon.fire_interval
	weapon.fire_interval = 10.0

	var real_kb: float = weapon.knockback
	print("PROBE: KNOCKBACK del codice = %.1f m/s, SPEED_MAX di -orda = 18.0 m/s"
		% real_kb)
	print("PROBE: delta di posizione in %d passi a DT=1/60, scena vera, "
		% KNOCKBACK_FRAMES
		+ "stessa procedura di tests/test_arena.gd")

	for charge in CHARGES:
		weapon.knockback = charge
		var line := "PROBE: KNOCKBACK %5.1f" % charge
		for kind in KINDS:
			var r := _measure(horde, player, weapon, kind, charge)
			if r < 0.0:
				line += " | %s MISURA FALLITA" % horde.kind_name(kind)
			else:
				line += " | %s %.4f" % [horde.kind_name(kind), r]
		print(line)

	weapon.knockback = real_kb
	horde.population = pop_before
	horde.auto_respawn = respawn_before
	weapon.fire_interval = interval_before

	if arena.get_parent() != null:
		arena.get_parent().remove_child(arena)
	arena.free()
	quit(0)

## Lo spostamento di UN nemico di specie `kind` colpito con impulso `charge`,
## con la procedura di test_arena.gd `_knockback_of_kind`. -1 = non misurabile.
func _measure(horde, player, weapon, kind: int, charge: float) -> float:
	_solo_enemy(horde, player, kind)
	if horde.count != 1:
		return -1.0

	# Assestamento: 60 passi. La velocita' di inseguimento ci mette 1/ACCEL a
	# arrivarci, e leggere la velocita' di un nemico appena nato significa
	# leggere zero e non sapere niente.
	for i in SETTLE_FRAMES:
		horde.step(DT)

	# Sonda con `damage_enemy(0, 0.0, ...)`: non uccide e non sposta, dice solo
	# quanto dell'impulso l'orda tiene davvero (la resistenza per specie).
	var away := _away_dir(horde, player)
	var settled: Vector3 = horde.velocities[0]
	horde.damage_enemy(0, 0.0, away * charge)
	var kept: float = (horde.velocities[0] - settled).length()
	# La sonda e' una perturbazione: si rimette a posto e si fa un passo solo.
	horde.velocities[0] = settled
	horde.timers[0] = 0.0
	horde.step(DT)

	var pool = weapon.pool
	pool.reset()
	weapon.pierce = 3
	weapon.cooldown = 0.0
	var hp_before: float = horde.hp[0]
	var frames := 0
	while frames < FIRE_FRAMES and horde.hp[0] >= hp_before:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
		frames += 1
	if horde.hp[0] >= hp_before:
		return -1.0

	# LA MISURA: posizione subito dopo l'impatto, poi esattamente
	# KNOCKBACK_FRAMES passi a durata fissa, e la delta di posizione. Sta qui e non
	# dopo la finestra di nessun secondo colpo: l'impulso ha tempo caratteristico
	# 0.125 s, quindi li' si misurerebbe l'inseguimento e non il knockback.
	var before: Vector3 = horde.transforms[0]
	# La traccia del modulo della velocita' dentro la finestra misurata: e' la
	# prova diretta di se il tetto di -orda morde. Se `SPEED_MAX` = 18.0 limitasse
	# davvero, qui si vedrebbe il modulo appiccicato a 18.0 e la pendenza piatta.
	var trace := "%.2f" % horde.velocities[0].length()
	for i in KNOCKBACK_FRAMES:
		horde.step(DT)
		trace += " -> %.2f" % horde.velocities[0].length()
	var after: Vector3 = horde.transforms[0]
	var moved: float = before.distance_to(after)

	# Finestra di guardia: nessun secondo colpo nei 30 frame dopo l'impatto.
	for i in AFTER_HIT_FRAMES:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
	if horde.hp[0] < hp_before - weapon.damage:
		print("PROBE:   ATTENZIONE %s ha preso un secondo colpo" % horde.kind_name(kind))

	print("PROBE:   %-6s impulso %.1f -> tenuto %.2f m/s (%.0f%%), spostamento %.4f"
		% [horde.kind_name(kind), charge, kept, 100.0 * kept / charge, moved])
	print("PROBE:     |v| nella finestra (tetto SPEED_MAX = 18.0): %s" % trace)
	return moved

## Orda ridotta a un nemico della specie richiesta, nato dal percorso vero di -orda
## (`population = 1` e un passo della sua `step()`): nessun record scritto a mano.
func _solo_enemy(horde, player, kind: int) -> void:
	horde.population = 0
	_kill_all(horde)
	horde.population = 1
	var attempt := 0
	while attempt < 24:
		horde.step(DT)
		if horde.count == 0:
			continue
		horde.kinds[0] = kind
		horde.velocities[0] = Vector3.ZERO
		var flat := _flat(horde.transforms[0] - player.global_position)
		var radial := _flat(horde.transforms[0]).length()
		if flat.length() >= MIN_SPAWN_DISTANCE and radial <= 28.0 - WALL_MARGIN:
			break
		horde.damage_enemy(0, 1000000.0, Vector3.ZERO)
		horde.population = 1
		attempt += 1
	var d: float = _flat(horde.transforms[0] - player.global_position).length()
	var r: float = _flat(horde.transforms[0]).length()
	print("PROBE:   spawn %-6s a %.1f m dal player, %.1f m dal centro, dopo %d tentativi"
		% [horde.kind_name(0), d, r, attempt])

func _kill_all(horde) -> void:
	var i: int = int(horde.count) - 1
	while i >= 0:
		horde.damage_enemy(i, 1000000.0, Vector3.ZERO)
		i -= 1

## La direzione di spinta: dal player verso il nemico, sul piano. E' la direzione
## del proiettile, e quindi quella che `damage_enemy` riceve come knockback.
func _away_dir(horde, player) -> Vector3:
	var d := _flat(horde.transforms[0] - player.global_position)
	return d.normalized() if d.length() > 0.001 else Vector3.FORWARD

## Sul piano XZ: la `y` qui non c'entra, l'arena e' piatta e il nemico non vola.
func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)