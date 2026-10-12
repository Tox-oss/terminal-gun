extends SceneTree
## Test di arena di terminal-gun. E' il test del **criterio n. 3** della milestone:
##
##     200 nemici vivi, SENZA un nodo per nemico:  node_count < 120  con
##     horde.count == 200
##
## ## Perche' questo test carica `scenes/arena_main.tscn` per intero
##
## Nella prima stesura non poteva: `src/sim/horde.gd` (-orda) e
## `scenes/player.tscn` (-gameplay) si scrivevano in parallelo a questo file, e
## un test che li carica sarebbe fallito per un file non ancora finito. Il modo
## piu' veloce di farlo passare sarebbe stato sostituirli con un placeholder: la
## maniera piu' veloce di mentire alla porta. I due sono adesso finiti e verdi,
## quindi qui si carica la scena **vera**, con l'orda **vera**: nessun finto, e
## si controlla anche che le tre foglie si agganciano davvero.
##
## ## La trappola del `const preload` (piano 5.3)
##
## `scenes/arena_main.tscn` si carica con `load()` **dentro `_process()`**, mai
## con un `const`. Un `const preload` risolve i suoi script a tempo di
## compilazione, PRIMA che `Main` aggiunga gli autoload al nome globale, e a quel
## punto `Game` non e' ancora registrato: `player.gd` e `weapon_base.gd` usano
## l'identificatore nudo `Game` e non compilerebbero. Caricandoli a runtime
## l'identificatore c'e'. Solo `tools/test_harness.gd` e' in `const`, e non
## tocca il contratto.
##
## Stringhe a schermo solo ASCII: la console di Windows e il pipe di
## `OS.execute` sono in codepage e un accento diventa spazzatura proprio nel
## messaggio che serve a capire un fallimento.

const H = preload("res://tools/test_harness.gd")

const ARENA_SCENE := "res://scenes/arena_main.tscn"
const ARENA_SCRIPT := "res://src/render/arena.gd"

## Il numero del criterio n. 3.
const ENEMY_TARGET := 200
const NODE_BUDGET := 120
## Quanta capienza fissa ha la MultiMesh dei nemici: se l'orda ne chiede di
## piu', il renderer deve fermarsi qui e non crescere.
const ENEMY_CAPACITY := 256
const ARENA_RADIUS := 28.0
## Quanto sopra il terreno il renderer mette il centro di un nemico.
const BASE_LIFT := 0.75
## Ampiezza dell'oscillazione verticale: sotto questa soglia il test non
## distingue il bob dal pavimento.
const BOB_TOLERANCE := 0.1
## Le API del contratto, e di chi sono.
const ORDA_APIS := ["nearest_enemy", "damage_enemy", "random_spawn_point"]
const GAMEPLAY_APIS := ["spawn_projectile", "player_position"]

var _h: H = null
var _ran: bool = false
var T_T0: int = 0


## Niente qui dentro. Il corpo del test gira al **primo frame**, non in
## `_initialize()`: un nodo aggiunto a `root` durante `_initialize()` non ha
## ancora il `_ready` (la radice non e' ancora dentro la scena), e tutto quello
## che questo test verifica sta nel `_ready`: la registrazione di
## `Game.arena_radius`, la costruzione della MultiMesh, il terreno.
func _initialize() -> void:
	_h = H.new()

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	T_T0 = Time.get_ticks_msec()
	_run()
	return true


func _run() -> void:
	var h := _h

	var game := root.get_node_or_null("Game")
	if not h.check(game != null, "l'autoload Game non e' stato istanziato: questo test non puo' girare"):
		quit(h.finish("test_arena"))
		return

	# Prima, da solo: che cosa registra arena quando gli altri nodi non ci sono.
	_arena_alone(h, game)

	var arena = _load_arena(h, game)
	if arena == null:
		quit(h.finish("test_arena"))
		return

	_wiring(h, arena, game)
	_criterion_3(h, arena, game)
	_terrain(h, arena)
	_camera(h, arena)
	_hud(h, arena, game)
	# Per ultima: e' l'unica sezione che cambia lo stato dell'orda e della
	# regolazione dell'arma, e non deve trovarsi in mezzo a quelle che contano i
	# nodi e le piastrelle.
	_criterion_4(h, arena, game)
	# m3: per ultima anche rispetto a `_criterion_4`, perche' riscrive la
	# disposizione dell'orda della scena vera e crea e libera piu' copie della
	# scena, quindi sposta `Game.horde` e `Game.player` su nodi diversi.
	_milestone_3(h, arena)
	# m4: per ultima anche rispetto a `_milestone_3`, perche' crea e libera
	# un'orda isolata e riscrive la disposizione di quella vera.
	_milestone_4(h, arena, game)

	_cleanup(arena)
	print("TESTARENA TEMPO TOTALE %d ms" % (Time.get_ticks_msec() - T_T0))
	quit(h.finish("test_arena"))

# --- 1. Che cosa registra arena, da solo ---------------------------------------

## Arena registra **un solo dato** e nessun metodo. Registrarne per procura le
## API delle altre foglie produrrebbe una doppia registrazione, e nel piano 5.1
## l'ultima che registra vince in silenzio: il difetto che nessun test vede.
##
## Il contratto e' pulito in questo momento (nessun altro nodo e' ancora dentro
## la scena), quindi "nessuna API registrata" qui vuol dire "arena non l'ha
## registrata" e non "qualcun altro l'ha registrata prima".
func _arena_alone(h, game: Node) -> void:
	game.arena_radius = 12.0
	var bare := Node3D.new()
	bare.name = "ArenaAlone"
	bare.set_script(load(ARENA_SCRIPT))
	root.add_child(bare)

	h.near(_contract_float(game, "arena_radius"), ARENA_RADIUS, 0.0001,
		"arena deve registrare Game.arena_radius = 28.0 all'avvio, prima che i figli costruiscano")
	h.check(game.get("player") == null, "arena non deve registrare Game.player: e' di -gameplay")
	h.check(game.get("horde") == null, "arena non deve registrare Game.horde: e' di -orda")
	for api in ORDA_APIS + GAMEPLAY_APIS:
		h.check(not game.has_impl(api),
			"arena non deve registrare l'API \"%s\": non e' sua" % api)

	root.remove_child(bare)
	bare.free()

# --- 2. La scena vera ----------------------------------------------------------

## `scenes/arena_main.tscn` caricata a runtime, non in `const` (vedi la trappola
## in testa al file). Il raggio parte da un valore che **non** e' 28.0, cosi'
## l'asserzione dimostra che arena ha registrato e non che il contratto partiva
## gia' cosi'.
func _load_arena(h, game: Node):
	game.arena_radius = 12.0
	if not ResourceLoader.exists(ARENA_SCENE):
		h.fail("manca %s: senza la scena non c'e' niente da contare" % ARENA_SCENE)
		return null
	var res = load(ARENA_SCENE)
	if not (res is PackedScene):
		h.fail("%s non e' una PackedScene" % ARENA_SCENE)
		return null
	var arena = (res as PackedScene).instantiate()
	if not (arena is Node3D):
		h.fail("%s non istanzia un Node3D" % ARENA_SCENE)
		return null
	root.add_child(arena)
	return arena as Node3D

## I nodi che la scena deve avere, i file di -orda e -gameplay **incollati** (non
## dei finti) e il contratto popolato da tutte e tre le foglie. E' la verifica che
## nella prima stesura non si poteva fare: fino a ieri la scena non esisteva.
func _wiring(h, arena: Node3D, game: Node) -> void:
	for node_name in ["WorldEnvironment", "Sun", "Ground", "Horde", "Enemies",
			"Player", "Camera", "Hud"]:
		h.check(arena.get_node_or_null(node_name) != null,
			"arena_main.tscn deve avere il nodo \"%s\"" % node_name)

	var horde = arena.get_node_or_null("Horde")
	var player = arena.get_node_or_null("Player")
	if h.check(horde != null, "manca il nodo Horde") and h.check(player != null, "manca il nodo Player"):
		h.eq(_script_path(horde), "res://src/sim/horde.gd",
			"il nodo Horde deve avere incollato src/sim/horde.gd: un finto passerebbe lo stesso test e non giocherebbe")
		h.eq(_script_path(player), "res://src/player/player.gd",
			"il nodo Player deve venire da scenes/player.tscn")
		h.check(game.get("horde") == horde,
			"Game.horde deve essere il nodo Horde della scena: e' cosi' che il renderer trovi l'orda")
		h.check(game.get("player") == player,
			"Game.player deve essere il nodo Player della scena")

	for api in ORDA_APIS:
		h.check(game.has_impl(api),
			"caricando la scena, l'API \"%s\" di -orda deve risultare registrata" % api)
	for api in GAMEPLAY_APIS:
		h.check(game.has_impl(api),
			"caricando la scena, l'API \"%s\" di -gameplay deve risultare registrata" % api)

# --- 3. Il criterio n. 3 -------------------------------------------------------

## Il cuore del test: `node_count < 120` **con** `horde.count == 200`, e i nodi
## non crescono quando i nemici crescono. E' la differenza fra "disegnare 200
## nemici" e "avere 200 nemici".
func _criterion_3(h, arena: Node3D, game: Node) -> void:
	# Variabili senza tipo: `horde` e' un `Node` e i suoi tre campi non sono
	# campi di `Node`, quindi l'accesso deve restare dinamico.
	var horde = arena.get_node("Horde")
	var enemies = arena.get_node("Enemies")

	# Orologio congelato: con il tempo che scorre il renderer aggiunge il bob e
	# la rotazione, e la geometria scritta nel buffer smette di essere prevedibile.
	enemies.set_time(0.0)
	enemies.set_horde(horde)

	h.eq(horde.count, ENEMY_TARGET, "l'orda deve avere 200 nemici vivi al primo frame")

	# Conto i nodi con l'orda vuota e poi con l'orda piena: la differenza deve
	# essere zero. E' un'affermazione piu' forte di "il totale sta sotto 120",
	# perche' non si puo' passare con un totale piccolo che pero' cresce.
	_kill_all(h, horde)
	enemies.refresh()
	var bare_nodes := _count_nodes(arena)

	_refill(horde)
	enemies.refresh()
	var loaded_nodes := _count_nodes(arena)

	print("test_arena: node_count=%d horde.count=%d" % [loaded_nodes, horde.count])

	h.eq(horde.count, ENEMY_TARGET, "l'orda si e' svuotata e non e' tornata a 200")
	h.eq(enemies.drawn_count(), ENEMY_TARGET, "il renderer deve aver disegnato tutti i 200 nemici")
	h.eq(loaded_nodes, bare_nodes, "200 nemici non devono aggiungere ne' un nodo")
	h.check(loaded_nodes < NODE_BUDGET,
		"node_count deve essere < 120 con 200 nemici vivi: e' %d" % loaded_nodes)
	h.check(enemies.get_child_count() == 0,
		"il renderer dei nemici non deve avere figli: un nodo per nemico e' esattamente il difetto che il criterio vieta")

	var mm = enemies.multimesh
	h.check(mm != null, "il renderer deve aver costruito la MultiMesh")
	if mm != null:
		h.check(mm.use_colors, "la MultiMesh deve avere i colori per istanza: e' cosi' che la tinta per specie arriva all'arena")
		h.eq(mm.visible_instance_count, ENEMY_TARGET,
			"la MultiMesh deve mostrare 200 istanze, non 200 nodi")
		h.check(mm.instance_count <= ENEMY_CAPACITY,
			"la capienza deve restare fissa, non crescere con l'orda")

		# La geometria deve arrivare dall'orda. Il controllo e' su
		# `instance_transform()`, la funzione che il ciclo di gioco chiama per
		# ogni nemico: il buffer della MultiMesh non si rilegge in headless (e'
		# uno storage buffer del RenderingDevice, che nel backend "dummy" non
		# esiste) e `get_instance_transform()` restituisce silenziosamente una
		# trasformazione vuota. Leggere indietro il buffer qui avrebbe fatto
		# passare il test su un renderer che non scrive niente.
		var last := ENEMY_TARGET - 1
		var placed: Transform3D = enemies.instance_transform(horde.transforms[last], last)
		var expected: Vector3 = horde.transforms[last]
		h.near(placed.origin.x, expected.x, 0.001,
			"la posizione x del nemico deve arrivare dall'orda")
		h.near(placed.origin.z, expected.z, 0.001,
			"la posizione z del nemico deve arrivare dall'orda")
		h.near(placed.origin.y, expected.y + BASE_LIFT, BOB_TOLERANCE,
			"il nemico deve stare sopra il terreno, non affondato")

	# Oltre la capienza fissa: si ferma, non cresce e non legge fuori dal vettore.
	# Ultimo controllo del test perche' sovrascrive gli array dell'orda vera.
	var saved_n = horde.count
	var saved_x: PackedVector3Array = horde.transforms.duplicate()
	var saved_c: PackedColorArray = horde.colors.duplicate()
	horde.count = ENEMY_CAPACITY * 4
	horde.transforms.resize(horde.count)
	horde.colors.resize(horde.count)
	enemies.refresh()
	h.eq(enemies.drawn_count(), ENEMY_CAPACITY,
		"oltre la capienza fissa il renderer deve fermarsi alla capienza, non crescere")
	h.eq(_count_nodes(arena), bare_nodes, "un'orda da 1024 non deve aggiungere nodi")
	horde.count = saved_n
	horde.transforms = saved_x
	horde.colors = saved_c

## Svuota l'orda con l'API vera di -orda, `damage_enemy`, che toglie il nemico
## dal vettero subito. Non si scrive `horde.count = 0` a mano: cosi' il test
## verificherebbe se stesso invece di verificare il gioco.
##
## L'indice che si uccide viene rimpiazzato dall'ultimo, quindi una passata sola
## non basta: il ciclo esterno ripete finche' non e' vuoto.
func _kill_all(h, horde) -> void:
	var guard := 0
	while horde.count > 0 and guard < 64:
		guard += 1
		for i in range(horde.count):
			if horde.count == 0:
				break
			horde.damage_enemy(i, 1000000.0, Vector3.ZERO)
	h.check(horde.count == 0,
		"l'orda non si e' svuotata: %d nemici rimasti dopo %d passate" % [horde.count, guard])

## Il contrario di `_kill_all`: un passo di simulazione e l'orda si riempie da
## sola, perche' `auto_respawn` e' acceso. Sempre l'orda vera, mai una aritmetica
## di array scritta qui.
func _refill(horde) -> void:
	horde.step(1.0 / 60.0)

# --- 4. Il terreno chiuso ------------------------------------------------------

## Il muro deve coprire la circonferenza e il pavimento il quadrato: se no,
## l'arena non e' chiusa e si vede il vuoto.
func _terrain(h, arena: Node3D) -> void:
	var ground = arena.get_node("Ground")
	h.eq(ground.get_child_count(), 3,
		"il terreno deve essere tre MultiMesh (pavimento, muro, casse): uno per mesh, non uno per piastrella")
	h.check(ground.floor_instances() > 0, "il pavimento deve avere piastrelle")
	h.check(ground.wall_instances() > 0, "il muro deve avere piastrelle")
	h.check(ground.crate_instances() > 0, "le casse devono essere disposte")
	h.check(ground.wall_coverage() >= TAU * ARENA_RADIUS,
		"il muro deve coprire la circonferenza: %.1f m di piastrelle per %.1f m di circonferenza"
			% [ground.wall_coverage(), TAU * ARENA_RADIUS])
	h.check(ground.floor_covered_side() >= ARENA_RADIUS * 2.0,
		"il pavimento deve coprire almeno il diametro dell'arena: %.1f m per %.1f m"
			% [ground.floor_covered_side(), ARENA_RADIUS * 2.0])

# --- 5. La camera --------------------------------------------------------------

func _camera(h, arena: Node3D) -> void:
	var cam = arena.get_node("Camera")
	cam.track(Vector3(10.0, 0.0, 0.0), 1.0)
	h.near(cam.global_position.x, 10.0, 0.001,
		"la camera deve stare sopra il punto che guarda")
	h.near(cam.global_position.y, 34.0, 0.001,
		"la camera deve guardare l'arena dall'alto")
	h.check(cam.global_position.z > 0.0,
		"la camera deve stare indietro rispetto al bersaglio, altrimenti non si vede dove va il giocatore")
	h.check(cam.current, "la camera dell'arena deve essere quella attiva")

	# Oltre il muro la camera non guarda nel vuoto: spinge il punto guardato
	# indietro. Si controlla l'ancora e non la posizione della camera: la camera
	# porta con se' i suoi 24 metri di ritardo, quindi esce dal raggio anche
	# quando il punto che guarda e' dentro.
	cam.track(Vector3(500.0, 0.0, 500.0), 1.0)
	var anchor: Vector3 = cam.anchor()
	var anchor_flat := Vector2(anchor.x, anchor.z)
	h.check(anchor_flat.length() <= ARENA_RADIUS + 0.001,
		"il punto guardato non deve uscire dall'arena: %.1f m dal centro" % anchor_flat.length())
	h.near(cam.global_position.y, anchor.y + 34.0, 0.001,
		"la camera deve restare 34 m sopra il punto che guarda")
	h.near(cam.global_position.z, anchor.z + 24.0, 0.001,
		"la camera deve restare 24 m indietro rispetto al punto che guarda")

# --- 6. L'HUD ------------------------------------------------------------------

func _hud(h, arena: Node3D, game: Node) -> void:
	var hud = arena.get_node("Hud")
	h.check(hud.has_method("set_state"), "l'HUD deve accettare i numeri con set_state()")

	# Prima alimentata dalla scena vera: arena chiama `set_state()` dai numeri
	# che legge sul contratto, quindi qui si esegue il suo `_process` e si legge
	# quello che c'e' scritto. E' il collegamento HUD <-> contratto, verificato
	# con l'orda e il giocatore veri e non con un `set_state()` a mano.
	arena.call("_process", 0.0)
	h.check(hud.enemy_text().contains("200"),
		"la HUD alimentata dalla scena deve mostrare i 200 nemici dell'orda vera: \"%s\"" % hud.enemy_text())
	h.check(hud.weapon_state_text().contains("DMG"),
		"la HUD alimentata dalla scena deve mostrare lo stato dell'arma vera: \"%s\"" % hud.weapon_state_text())

	# E adesso pilotata a mano, per i valori che la scena non produce da sola.
	hud.set_state(12.0, 100.0, 345, "DMG 10.0 every 0.35s", 200, 3)
	h.near(hud.health_ratio(), 0.12, 0.001, "la barra delle vite deve seguire i dati")
	h.check(hud.score_text().contains("345"), "il punteggio deve comparire nella HUD: \"%s\"" % hud.score_text())
	h.check(hud.enemy_text().contains("200"), "i nemici vivi devono comparire nella HUD: \"%s\"" % hud.enemy_text())
	h.check(hud.weapon_state_text().contains("DMG"), "lo stato dell'arma deve comparire nella HUD: \"%s\"" % hud.weapon_state_text())
	h.eq(hud.level, 3, "il livello deve arrivare alla HUD")

	# Vita a zero e vita negative: la barra e' un valore, non un'etichetta.
	hud.set_state(-5.0, 100.0, 0, "-", 0, 1)
	h.near(hud.health_ratio(), 0.0, 0.001, "vite negative non possono dare una barra negativa")

	# E `max_hp` a zero non deve dividere per zero.
	hud.set_state(50.0, 0.0, 0, "-", 0, 1)
	h.finite(hud.health_ratio(), "con max_hp a zero il rapporto vite resta un numero")

# --- 7. Il criterio n. 4, sull'orda vera ---------------------------------------

## Il tetto del criterio n. 4, in unita' di spostamento.
const KNOCKBACK_MIN := 0.3
## Il passo di simulazione. Uno solo per tutto il file: uno spostamento misurato
## con passi diversi non e' uno spostamento, e confronto con il test di -gameplay
## solo se il passo e' lo stesso.
const DT := 1.0 / 60.0
## La finestra e' **quella di `tests/test_gameplay.gd`**: 5 passi di durata fissa,
## misurati sulla posizione. Confronto e non casualita': se le due finestre
## divergessero, il numero di quel test e questo non sarebbero paragonabili e il
## primo non potrebbe fare da riferimento al secondo.
const KNOCKBACK_FRAMES := 5
## Frame di assestamento prima di sparare. Servono a far convergere la velocita'
## del nemico a regime: il suo tempo caratteristico e' `1/ACCEL` = 0.125 s.
const SETTLE_FRAMES := 60
## Tetto di frame perche' il colpo arrivi. A 26 m/s e 12 m di distanza bastano ~18
## frame: 240 e' un margine che non maschera un colpo che non parte.
const FIRE_FRAMES := 240
## Passi **dopo** l'impatto, senza piu' spari. Con `pierce` a 3 il proiettile
## continua a volare: e' la finestra in cui una guardia assente ripeterebbe il
## danno sullo stesso nemico.
const AFTER_HIT_FRAMES := 30
## Lontananza minima del nemico dal player quando nasce, in metri. Deve reggere
## l'assestamento (60 frame a 6.6 m/s sono 6.6 m persi) e il viaggio del
## proiettile senza mai entrare nella zona d'arrivo di `src/sim/enemy.gd`, dove il
## nemico insegue a meta' velocita' e la previsione sotto non vale piu'.
const MIN_SPAWN_DISTANCE := 14.0
## Specie per cui il knockback **deve** funzionare: runner e grunt, che sono
## l'80% dell'onda (`Spawner.KIND_WEIGHTS`) e hanno resistenza 0 e 0.20.
const KINDS_MUST_KNOCK := [0, 1]
## Specie misurate ma **non** sottoposte al tetto: brute e boss hanno resistenza
## 0.55 e 0.90, sono cioe' **progettati** per non volare sotto i colpi. Il numero
## c'e' ed e' stampato, ma se la soglia di 0.3 debba valere anche per loro e' una
## domanda di piano, non di test: qui non si stringe l'asserzione per farla passare
## e non si allarga per farla fallire.
const KINDS_MEASURED := [2, 3]
## `ACCEL` e `SPEED_MAX` di `src/sim/enemy.gd`. Non sono campi dell'orda e non si
## possono leggere da qui: sono la costante di tempo del suo smorzamento e il
## tetto della sua velocita'. Servono solo alla previsione in `_predicted_moved`,
## e la previsione **controllata contro la misura**: se il codice di -orda
## cambiasse questi due numeri, l'asserzione di combaciazione qui sotto fallirebbe
## invece di passare in silenzio.
const REAL_ACCEL := 8.0
const REAL_SPEED_MAX := 18.0

## Il criterio n. 4 ("il player spara e uccide: danno una volta sola, knockback >=
## 0.3 unita'") finora l'aveva verificato solo `tests/test_gameplay.gd`, e
## **contro un orda finta**: una `FakeHorde` con `drag = 0.18` e `chase_speed =
## 3.0` scritti a mano, e una `KNOCKBACK` alzata da 14 a 18 perche' con quel finto
## si misuravano 0.2985 unita', sotto il tetto. Una messa a punto tarata su una
## fisica che non e' quella del gioco.
##
## Qui non c'e' niente di finto: l'arma chiama `Game.nearest_enemy` per mirare, il
## proiettile viaggia e chiama `Game.damage_enemy`, e il nemico che si sposta e' un
## record di `src/sim/horde.gd` mosso dalla sua stessa `step()` con le sue vere
## tabelle di specie.
##
## Il perimetro di questa sezione e' tutto di -gameplay e -orda, che non si tocca:
## qui si guidano i loro metodi pubblici (`step`, `damage_enemy`, `pool.reset`,
## `weapon.cooldown`, ...) e si misura il risultato.
func _criterion_4(h, arena: Node3D, game: Node) -> void:
	var horde = arena.get_node("Horde")
	var player = arena.get_node("Player")
	var weapon = player.get("weapon")
	if not h.check(weapon != null, "il player della scena deve avere un'arma"):
		return
	var pool = weapon.pool
	if not h.check(pool != null, "l'arma della scena deve avere il suo pool di proiettili"):
		return
	# Il player smette di leggere la tastiera e si guida a mano: altrimenti
	# l'input della testiera finirebbe dentro la misura.
	player.drive_manually()
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO

	# I valori toccati sono **campi**: salvati e rimessi a posto sempre, anche se
	# un'asserzione qui dentro fallisce, perche' `check()` non interrompe.
	var population_before: int = horde.population
	var respawn_before: bool = horde.auto_respawn
	var fire_before: float = weapon.fire_interval
	var pierce_before: int = weapon.pierce
	# Un colpo solo per tutta la sezione: qui si prova che **quel** proiettile non
	# ripete il danno, non che l'arma smetta di sparare.
	weapon.fire_interval = 10.0

	var knockback: float = weapon.knockback
	var damage: float = weapon.damage
	h.positive(knockback, "l'arma deve avere un knockback non nullo")
	h.positive(damage, "l'arma deve avere un danno non nullo")

	var rows: Array[String] = []
	var charges: Array[String] = []
	for kind in KINDS_MUST_KNOCK + KINDS_MEASURED:
		var r := _knockback_of_kind(h, horde, player, weapon, pool, kind)
		if r.is_empty():
			continue
		var moved: float = r["moved"]
		var name := str(r["name"])
		rows.append("%s %.4f" % [name, moved])
		charges.append("%s %.4f/%.4f" % [name, r["measured_charge"], r["full_charge"]])
		if KINDS_MUST_KNOCK.has(kind):
			h.check(moved >= KNOCKBACK_MIN,
				"knockback >= %.1f unita' entro %d frame sul %s vero: misurate %.4f"
					% [KNOCKBACK_MIN, KNOCKBACK_FRAMES, name, moved])
			h.check(float(r["away_dot"]) > 0.0,
				"il %s deve essere spinto lontano dal player, non verso (dot %.4f, "
				% [name, r["away_dot"]]
				+ "distanza %.2f -> %.2f m, velocita' dopo l'impatto %.2f m/s, "
				% [r["d_before"], r["d_after"], r["v_after_hit"]]
				+ "spostamento %.4f)" % moved)
			# La misura deve combaciare con la previsione ricavata dalla fisica
			# vera di -orda: e' la prova che i tre numeri che il vertice chiede
			# sono quelli del codice in gioco e non una ricostruzione del test.
			h.near(moved, float(r["predicted"]), 0.01,
				"lo spostamento misurato sul %s deve combaciare con la previsione "
				% name
				+ "(%.4f dalla sua ACCEL %.1f e dal suo tetto %.1f m/s): se la "
				% [r["predicted"], REAL_ACCEL, REAL_SPEED_MAX]
				+ "fisica di src/sim/enemy.gd e' diversa, e' qui che si vede")

	# Riporta e lascia l'orda com'era: population e auto_respawn tornano ai
	# valori veri e un passo la riporta a 200.
	horde.population = population_before
	horde.auto_respawn = respawn_before
	weapon.fire_interval = fire_before
	weapon.pierce = pierce_before
	horde.step(DT)
	h.eq(horde.count, ENEMY_TARGET, "la sezione knockback deve lasciare l'orda a 200 nemici")

	print("criterio 4, knockback reale: %s unita' in %d frame (tetto %.1f)"
		% [", ".join(rows), KNOCKBACK_FRAMES, KNOCKBACK_MIN])
	print("criterio 4, fisica reale: KNOCKBACK %.1f m/s dall'arma, inseguimento %s m/s, impulso tenuto %s"
		% [knockback, _chase_list(horde), ", ".join(charges)])
	print("criterio 4, attenuazione: -orda non ha un 'drag' ma un ACCEL di %.1f 1/s "
		% REAL_ACCEL
		+ "(tempo caratteristico %.3f s) e un tetto SPEED_MAX di %.1f m/s; "
		% [1.0 / REAL_ACCEL, REAL_SPEED_MAX]
		+ "lo smorzamento e' cioe' quello di primo ordine v += (wanted - vel) * min(1, dt*ACCEL)")

## Un nemico solo, dell'orda vera, della specie `kind`.
##
## **Un** nemico perche' con 200 la misura non misurerebbe niente: la forza di
## separazione dell'orda vale 11 m/s ed e' piu' grande dell'inseguimento di
## qualsiasi specie, quindi dentro una folla lo spostamento di un singolo nemico e'
## rumore di folla, non knockback. Il nemico nasce dal percorso vero di -orda
## (`population = 1` e un passo della sua `step()`, che chiama `_top_up` ->
## `_spawn_one` -> `Spawner.spawn_point`): nessun record scritto a mano.
func _knockback_of_kind(h, horde, player, weapon, pool, kind: int) -> Dictionary:
	_solo_enemy(h, horde, player, kind)
	if horde.count != 1:
		return {}

	var name := str(horde.kind_name(0))
	var chase: float = horde.speed_of_kind(kind)
	h.positive(chase, "il %s deve avere una velocita' d'inseguimento" % name)

	# Prima di ogni misura il nemico deve essere **a regime**: la sua velocita' di
	# inseguimento ci mette `1/ACCEL` = 0.125 s a arrivarci, e leggere la
	# velocita' di un nemico appena nato significa leggere zero e non sapere niente
	# di quello che l'orda accetterebbe al suo posto.
	for i in SETTLE_FRAMES:
		horde.step(DT)

	# Quanto dell'impulso l'orda **tiene davvero**: `damage_enemy` somma
	# `knockback * (1 - KNOCKBACK_RESIST[kind])` e la resistenza e' di -orda.
	# La misuro invece di leggerla, perche' le sue tabelle sono `static var` di uno
	# script che non e' mio: e' la sonda `damage_enemy(0, 0.0, ...)`, che non
	# uccide niente e non muove niente tranne la velocita'.
	var away := _away_dir(horde, player)
	var settled: Vector3 = horde.velocities[0]
	var probed: bool = horde.damage_enemy(0, 0.0, away * weapon.knockback)
	var after_probe: Vector3 = horde.velocities[0]
	# Quanto dell'impulso e' finito davvero nella velocita', in m/s. E' il numero
	# che spiega perche' due specie con lo stesso colpo si spostano in modo diverso.
	var charged: float = (after_probe - settled).length()
	var kept: float = 0.0
	if weapon.knockback > 0.0001:
		kept = charged / weapon.knockback
	h.check(not probed, "una sonda con danno 0 non deve uccere nessuno")
	h.check(kept > 0.0 and kept <= 1.001,
		"il %s deve tenere una parte dell'impulso fra 0 e 1: tenuto %.3f" % [name, kept])
	h.check(absf(settled.dot(away)) >= 0.9 * chase,
		"il %s deve essere a regime e inseguire verso il player a %.1f m/s: misurati %.3f"
			% [name, chase, absf(settled.dot(away))])
	# La sonda e' una perturbazione: si rimette a posto la velocita' e basta. Un
	# passo solo, non un assestamento intero: `damage_enemy` non sposta il nemico,
	# e rimettere la velocita' rimette lo stato. Un secondo assestamento intero
	# qui dentro costerebbe 6.6 m al runner, che a quel punto e' addosso al player e
	# la misura non vale piu' niente.
	horde.velocities[0] = settled
	horde.timers[0] = 0.0
	horde.step(DT)

	# Il colpo, per il percorso vero: `player.step` -> `weapon.step` ->
	# `Game.nearest_enemy` per mirare, `Game.spawn_projectile` per partire, e nel
	# pool il segmento del proiettile contro `horde.transforms` e
	# `Game.damage_enemy` per colpire.
	pool.reset()
	weapon.pierce = 3
	weapon.cooldown = 0.0
	var hp_before: float = horde.hp[0]
	var frames := 0
	while frames < FIRE_FRAMES and horde.hp[0] >= hp_before:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
		frames += 1
	if not h.check(horde.hp[0] < hp_before,
			"il colpo sul %s non e' arrivato in %d frame (HP %.1f)" % [name, FIRE_FRAMES, hp_before]):
		return {}

	# **Danno una volta sola**: gli HP scendono di esattamente un colpo.
	var hp_after: float = horde.hp[0]
	h.near(hp_after, hp_before - weapon.damage, 0.0001,
		"il %s deve prendere UN colpo e non uno a frame: HP %.1f -> %.1f, un colpo fa %.1f"
			% [name, hp_before, hp_after, weapon.damage])

	# **La misura del criterio**: posizione subito dopo il frame d'impatto, poi
	# esattamente `KNOCKBACK_FRAMES` passi di orda di durata fissa, e la **delta di
	# posizione**. Il modulo dell'impulso non e' la misura (piano §5.2).
	#
	# Sta QUI e non dopo la finestra di nessun secondo colpo: l'impulso ha un tempo
	# caratteristico di 0.125 s, quindi dopo trenta frame di ordine e' gia' sparito
	# e quello che si misurerebbe e' l'inseguimento del nemico verso il player, non
	# il knockback. (E' successo, e la difesa era che il tempo caratteristico si
	# dichiara in testa al file invece di essere indovinato qui.)
	var before: Vector3 = horde.transforms[0]
	var v_at_before: Vector3 = horde.velocities[0]
	var d_before: float = _flat(before - player.global_position).length()
	for i in KNOCKBACK_FRAMES:
		horde.step(DT)
	var after: Vector3 = horde.transforms[0]
	var moved: float = before.distance_to(after)
	var d_after: float = _flat(after - player.global_position).length()
	var away_dot: float = _flat(after - before).dot(_flat(away))
	h.finite(moved, "lo spostamento del %s e' finito" % name)
	# Sotto `ARRIVE_RADIUS` il nemico rallenta perche' e' arrivato addosso al
	# player: la previsione sotto presuppone l'inseguimento a pieno regime, quindi
	# la misura e la previsione non sarebbero piu' confrontabili.
	h.check(d_before >= 3.5,
		"il %s deve essere colpito a pieno inseguimento: era a %.2f m dal player, "
		% [name, d_before]
		+ "sotto i 3.5 m il nemico rallenta e la previsione non vale")

	# E non ricomincia: il proiettile continua a volare perche' ha ancora pierce,
	# quindi questi frame sono la finestra in cui una guardia assente spammerebbe.
	for i in AFTER_HIT_FRAMES:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
	h.near(horde.hp[0], hp_after, 0.0001,
		"nessun secondo colpo sul %s nei %d frame dopo l'impatto: HP %.1f -> %.1f"
			% [name, AFTER_HIT_FRAMES, hp_after, horde.hp[0]])

	return {
		"name": name,
		"moved": moved,
		"away_dot": away_dot,
		"d_before": d_before,
		"d_after": d_after,
		"v_after_hit": v_at_before.length(),
		# Quanto impulso e' arrivato addosso al nemico, e quanto gliene avevano
		# dato. Il rapporto e' la resistenza di -orda, misurata e non letta.
		"measured_charge": charged,
		"full_charge": weapon.knockback,
		"predicted": _predicted_moved(settled, away, charged),
	}

## Riduce l'orda vera a **un** nemico della specie `kind`. Lo svuota con
## `damage_enemy` (l'API di -orda), abbassa `population` e lascia che sia la sua
## `step()` a rifarlo nascere: nessun record scritto a mano.
##
## Lo spawn e' casuale e puo' cadere addosso al player, perche' `Spawner.spawn_point`
## accetta il fallback dopo 8 tentative: un nemico dentro la zona d'arrivo insegue
## a meta' velocita' e la misura cambierebbe da specie a specie per il motivo
## sbagliato. Si riprova finche' non e' lontano.
func _solo_enemy(h, horde, player, kind: int) -> void:
	horde.population = 0
	_kill_all(h, horde)
	horde.population = 1
	var attempt := 0
	while attempt < 8:
		horde.step(DT)
		if horde.count == 0:
			continue
		horde.kinds[0] = kind
		horde.velocities[0] = Vector3.ZERO
		if _flat(horde.transforms[0] - player.global_position).length() >= MIN_SPAWN_DISTANCE:
			break
		horde.damage_enemy(0, 1000000.0, Vector3.ZERO)
		horde.population = 1
		attempt += 1
	h.check(horde.count == 1,
		"l'orda deve essere scesa a un nemico solo, ne' sono rimasti %d" % horde.count)
	if horde.count == 1:
		h.check(_flat(horde.transforms[0] - player.global_position).length() >= MIN_SPAWN_DISTANCE,
			"il nemico di prova deve nascere a %.0f m dal player: lo spawn di -orda e' "
			% MIN_SPAWN_DISTANCE
			+ "casuale e puo' cadere addosso, dove l'inseguimento rallenta")

## Lo spostamento che la fisica vera di `src/sim/enemy.gd` prevede per questi
## numeri, calcolato a passi discreti con la sua stessa formula:
## `vel += (wanted - vel) * min(1, delta * ACCEL)` e il tetto `SPEED_MAX`.
##
## Non serve a misurare: serve a **controllare** la misura. Se i due combaciano,
## i tre numeri che il vertice chiede (`KNOCKBACK`, inseguimento, attenuazione)
## sono quelli del codice in gioco; se non combaciano, la differenza e' la prova
## che la fisica reale non e' quella che il test crede.
##
## `at_impact` e' la velocita' subito prima che il colpo la tocchi: quella a
## regime piu' l'impulso, perche' e' cosi' che la costruisce `damage_enemy`.
## `impulse_dir` e' la direzione dell'impulso; `chase_vec` la velocita' a regime.
func _predicted_moved(chase_vec: Vector3, impulse_dir: Vector3, impulse: float) -> float:
	var alpha := minf(1.0, DT * REAL_ACCEL)
	var wanted := chase_vec.dot(impulse_dir)
	var vel := wanted + impulse
	# Il frame d'impatto: l'ho gia' contato nella posizione `before`, quindi qui
	# si simula solo per arrivare alla velocita' da cui partono i frame misurati.
	vel = clampf(vel + (wanted - vel) * alpha, -REAL_SPEED_MAX, REAL_SPEED_MAX)
	var x := 0.0
	for i in KNOCKBACK_FRAMES:
		vel = clampf(vel + (wanted - vel) * alpha, -REAL_SPEED_MAX, REAL_SPEED_MAX)
		x += vel * DT
	return absf(x)

## La velocita' d'inseguimento reale di ogni specie, dall'orda viva. E' il numero
## che nella `FakeHorde` di -gameplay era un campo scritto a mano.
func _chase_list(horde) -> String:
	var parts: Array[String] = []
	for kind in KINDS_MUST_KNOCK + KINDS_MEASURED:
		parts.append("%.1f" % horde.speed_of_kind(kind))
	return "/".join(parts)

## La direzione di spinta: dal player verso il nemico, sul piano. E' la direzione
## del proiettile, e quindi quella che `damage_enemy` riceve come knockback.
func _away_dir(horde, player) -> Vector3:
	var d := _flat(horde.transforms[0] - player.global_position)
	return d.normalized() if d.length() > 0.001 else Vector3.FORWARD

## Sul piano XZ: la `y` qui non c'entra, l'arena e' piatta e il nemico non vola.
func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

# --- 8. Milestone 3: la disposizione dell'orda e' una funzione del seme ---------
#
# ## Il debito che questa sezione chiude
#
# `src/sim/spatial_grid.gd:32-39` dichiara che la densita' che fa traboccare un
# secchiello e' stata misurata sull'orda **isolata** (`BUCKET_SLOTS` 12 -> 32 sul
# picco di 19). Ma l'orda della **scena vera** gira con `seed = 0` e nessuna
# asserzione guardava la sua `grid_overflowed()`: il traboccamento vero poteva
# accadere e nessuno lo avrebbe saputo. Non era un test che fallisce a caso, era
# un test che non esisteva.
#
# La causa non era la casualita', era un buco di API: `horde.seed` era un campo
# pubblico documentato «0 = casuale, un numero = riproducibile», ma `_build()` lo
# leggeva **una volta sola** dentro `_ready()`, e sulla scena vera l'orda la crea
# `scenes/arena_main.tscn`: nessun codice esterno poteva scriverlo prima che la
# disposizione fosse gia' nata. Il campo sembrava la riproducibilita' e sulla scena
# vera era irraggiungibile. `horde.reseed(s)` chiude il buco.
#
# ## La semantica che questo test usa, e come l'ho letta
#
# `horde.worst_bucket()` e' dichiarato in `src/sim/horde.gd` come **il picco del
# frame (griglia) appena ricostruito**, cioe' NON un massimo storico: dentro
# `spatial_grid.gd` il contatore e' un massimo storico che si azzera solo in
# `setup()`, e `_rebuild_grid()` lo azzera a ogni ricostruzione perche' altrimenti,
# dopo un `reseed`, il numero direbbe ancora il picco della disposizione
# **precedente** invece di quella appena scritta.
#
# Quindi qui: la lettura avviene **subito dopo `reseed`**, che per contratto (punto
# 5) ricostruisce gia' la griglia, e il numero che ne esce e' il picco di **quel**
# seme e non un massimo accumulato. Se un domani la semantica tornasse storica, le
# letture di questo sweep continuerebbero a essere valide ma monotone: ogni valore
# sarebbe il massimo di tutti i precedenti. Il numero di semi traboccati e la
# somma delle posizioni, invece, resterebbero gli stessi. La differenza si vede,
# quindi non e' una scelta invisibile.
#
# ## Perche' `BUCKET_SLOTS` non e' il tetto
#
# Il tetto NON puo' essere 32: `insert()` aggiorna il contatore solo con
# `n < BUCKET_SLOTS`, quindi `worst_bucket() <= 32` e' una tautologia che non puo'
# fallire. Il segnale che il traboccamento e' avvenuto e' `grid_overflowed()`, e la
# **misura di densita'** va confrontata con un tetto **proprio, sotto 32**, derivato
# da una misura. E' quello che c'e' sotto.

## I tre membri che `src/core/contracts.gd` dichiara congelati nella sezione
## "Supersficie di milestone 3". Non sono API registrate: sono metodi pubblici
## dell'orda della scena vera, e il contratto li dichiara perche' m3 e' la prima
## onda che mette due foglie sullo stesso oggetto di simulazione.
const M3_SURFACE := ["reseed", "worst_bucket", "grid_overflowed"]

## I due semi della riproducibilita'. Due numeri lontani e non consecutivi: con
## `SEED_A` e `SEED_A + 1` un `reseed` che ignorasse il seme e producesse sempre
## la stessa disposizione passerebbe lo stesso, perche' i due semi si somigliano
## piu' di quanto credibile. `7311` non ha nessun rapporto con `4242`.
const SEED_A := 4242
const SEED_B := 7311

## Quanti semi nello sweep, e come sono scelti. `SWEEP_COUNT` semi a passo
## `SWEEP_STEP` da `SWEEP_FIRST`: 24 semi fra 1 e 231, cioe' la stessa banda che
## `tests/test_gameloop.gd` aveva gia' percorso sull'orda isolata (semi 1..240),
## ma qui sul mondo vero.
##
## Il passo serve a coprire la banda, non a fare un campione fitto: ogni coppia
## di semi consecutivi **dello sweep** viene confrontata posizione per posizione e
## il risultato e' stampato sotto (misurato 23 coppie diverse su 23), quindi non
## si sta campionando ventiquattro volte la stessa disposizione. Il passo 1
## costerebbe il doppio delle query di griglia per coprire 24 semi su metta' banda.
const SWEEP_COUNT := 24
const SWEEP_FIRST := 1
const SWEEP_STEP := 10

## Tetto dichiarato di `worst_bucket()` sulla scena vera.
##
## ## COME E' STATO DERIVATO (misura prima del numero)
##
## Sweep di 24 semi (1, 11, ..., 231) sulla **scena vera**, stampato dalla sezione
## 8.2 di questo stesso file:
##
##     worst_bucket: min 4, mediana 5, max 7; semi traboccati 0 su 24
##
## Il tetto e' **11**, e si deriva in tre passi, tutti sul numero misurato:
##
##   1. base = 7, il **massimo misurato**. Non il minimo (4): un tetto poggiato
##      sul minimo cadrebbe appena la densita' torna alla norma, e direbbe piu'
##      del gioco di quanto il gioco sappia fare. Non la mediana (5): un tetto
##      sulla mediana cadrebbe alla meta' dei semi, cioe' non piu' che rumore.
##   2. margine dichiarato = **+4 slot**. L'escursione fra minimo e massimo
##      misurati e' di 3 slot (4 -> 7), quindi il margine e' ** maggiore
##      dell'escursione dell'intero campione**: anche dimezzandolo (tetto 9) tutti
##      i 24 semi starebbero sotto. Il tetto non e' tarato sul caso peggiore, e'
##      tarato su uno scarto che un cambiamento di densita' deve superare.
##   3. coerenza col codice: `BUCKET_SLOTS` = 32, e 11 ne lascia **21 slot** di
##      margine prima del punto in cui le query cadono davvero a scansione
##      lineare. Un balzo della densita' deve quindi essere di quasi tre volte
##      perche' questo tetto cada, e non e' un numero che si puo' spostare di un
##      passo senza accorgersene.
##
## ## PERCHE' NON `BUCKET_SLOTS - 1`
##
## `spatial_grid.gd::insert` aggiorna il contatore solo con `n < BUCKET_SLOTS`,
## quindi `worst_bucket()` **non puo' superare 32**: un tetto a 31 non puo' mai
## fallire e non starebbe misurando niente. Il segnale che il traboccamento
## e' avvenuto e' `grid_overflowed()`, ed e' un'asserzione separata qui sotto.
##
## ## I DENTI SONO STATI PROVATI, DUE VOLTE, E POI RIMOSSI
##
## Protocollo di m2-w3: una prova che non sa fallire non e' un'asserzione. Il
## blocco che forza il traboccamento **non e' in questo file**: fu rimosso dopo.
## Quello che faceva, con la sola API di massa che il piano dichiara
## (`count`/`transforms`/`colors`, `horde.gd:94-101`), era scrivere posizioni e un
## `count` piu' grande dentro una **sola cella da 4 m** e far ricostruire la griglia
## chiamando `nearest_enemy_index(...)`, che passa da `_ensure_grid()`. `count`,
## `transforms` e `colors` venivano salvati e rimessi **sempre**: `check()` non
## interrompe, quindi un'asserzione fallita a meta' avrebbe lasciato l'orda sporca
## per le sezioni successive.
##
## 1. **Tutti i 200 nemici in una cella** -> `worst_bucket` 32, `grid_overflowed()`
##    a vero. Le tre asserzioni di 8.2 hanno detto **FAIL** una per una
##    ("nessun seme deve traboccare...", "deve stare sotto il tetto dichiarato
##    11: massimo misurato 32", e il controllo di semantica che ha visto che il
##    seme 1 non riproduceva piu' 32). Uscita 1.
## 2. **12 nemici in una cella** -> `worst_bucket` 13 e `grid_overflowed()` resta
##    **falso**. E' la prova che conta per il tetto di densita': l'asserzione del
##    traboccamento era green e **quella del tetto ha detto FAIL** lo stesso.
##    Senza questo, il tetto 11 potrebbe essere portato dalla sola segnalazione di
##    traboccamento e non starebbe misurando la densita'. Uscita 1.
const GRID_CEILING := 11

## Quante posizioni devono cambiare fra due semi **diversi**: il criterio n. 2 di
## m3 dice "seme diverso -> diversi", e senza un numero minimo quella frase
## accetterebbe anche una disposizione fissa con due nemici spostati.
##
## ## COME E' STATO DERIVATO (misura prima del numero)
##
## Misurato con `SEED_A` = 4242 contro `SEED_B` = 7311: **200 posizioni diverse
## su 200**. La disposizione iniziale e' ad anelli e l'angolo di ogni nemico esce
## da `_rng`, quindi con un altro seme si muove **tutti**: e' il massimo possibile,
## non un caso.
##
## Il tetto e' **180**, cioe' il 90%. Non 200: un numero che pretende che tutti i
## 200 si muovano rende l'asserzione fragile per un motivo che non c'entra (due
## nemici che si toccano e restano fermi insieme). Non 1: quello e' la parola
## "diversi" del criterio riscritta in codice, e non aggiunge niente.
const REPRO_DIFF_MIN := 180

func _milestone_3(h, arena: Node3D) -> void:
	var horde = arena.get_node_or_null("Horde")
	if not h.check(horde != null, "m3: la scena vera non ha il nodo Horde"):
		return
	# Superficie congelata: se uno dei tre non c'e', il resto della sezione
	# misurerebbe un'altra cosa e fallirebbe con un messaggio che non dice quale
	# dei tre manca. Non e' uno stub: e' la guardia che dice il numero giusto.
	for m in M3_SURFACE:
		if not h.check(horde.has_method(m),
				"m3: l'orda della scena vera non espone \"%s()\": e' la superficie congelata in src/core/contracts.gd, sezione \"Supersficie di milestone 3\"" % m):
			return
	_riproducibilita(h, horde)
	_sweep(h, horde)

## ## 8.1 Riproducibilita': stesso seme due volte IDENTICO, seme diverso DIVERSO
##
## Entrambe le asserzioni, perche' una sola e' a denti nulli: la prima da sola
## passerebbe anche con un `reseed` che riscrive sempre la stessa disposizione, la
## seconda da sola passerebbe anche con un `reseed` che mette un rumore casuale
## sopra una disposizione fissa. Insieme dicono "funzione del seme".
func _riproducibilita(h, horde) -> void:
	horde.reseed(SEED_A)
	var a: PackedVector3Array = horde.transforms.duplicate()
	var a_colors: PackedColorArray = horde.colors.duplicate()
	h.eq(horde.count, ENEMY_TARGET,
		"m3: dopo reseed l'orda deve avere 200 nemici vivi, come all'avvio")
	h.eq(horde.transforms.size(), horde.count,
		"m3: transforms.size() deve combaciare con count dopo un reseed")
	h.eq(horde.colors.size(), horde.count,
		"m3: colors.size() deve combaciare con count dopo un reseed")

	# Stesso seme, di nuovo: il percorso e' lo stesso, quindi la disposizione
	# deve tornare **identica**, non "vicina". Il confronto e' elemento per
	# elemento, e sotto anche la somma delle coordinate: se un solo nemico
	# differisse di un epsilon, il primo confronto lo prenderebbe, e la somma
	# dice in che direzione si e' mosso.
	horde.reseed(SEED_A)
	var b: PackedVector3Array = horde.transforms.duplicate()
	h.eq(b.size(), a.size(),
		"m3: lo stesso seme due volte deve produrre lo stesso numero di nemici")
	h.check(b == a,
		"m3: stesso seme due volte -> transforms IDENTICI: %d posizioni su %d diverse"
			% [_differing(a, b), mini(a.size(), b.size())])
	h.near(_checksum(b), _checksum(a), 0.0,
		"m3: stesso seme due volte -> la somma delle posizioni deve essere la stessa")
	h.check(horde.colors == a_colors,
		"m3: stesso seme due volte -> anche i colori devono essere identici")

	# Seme diverso: la disposizione deve essere un'altra, e lo deve essere per
	# gran parte dei nemici, non per uno.
	horde.reseed(SEED_B)
	var c: PackedVector3Array = horde.transforms.duplicate()
	var moved := _differing(a, c)
	h.check(moved >= REPRO_DIFF_MIN,
		"m3: due semi diversi devono dare disposizioni DIVERSE: %d posizioni su %d diverse, tetto dichiarato %d"
			% [moved, mini(a.size(), c.size()), REPRO_DIFF_MIN])

	print("test_arena: m3 riproducibilita': seme %d due volte -> %d/%d posizioni diverse, somma %.6f; seme %d -> %d/%d diverse"
		% [SEED_A, _differing(a, b), a.size(), _checksum(a), SEED_B, moved, mini(a.size(), c.size())])

## ## 8.2 Lo sweep: N semi sulla scena vera, `worst_bucket()` misurato
##
## La misura che m2-w3 aveva rimandato per iscritto e che nessuno aveva fatta: il
## traboccamento vero, sull'orda vera, dentro l'arena vera. Non su un'orda isolata
## con una griglia costruita a mano.
##
## Il tetto e' `GRID_CEILING`, e sotto ne c'e' il commento che dice come e' stato
## derivato dalla misura che questo sweep stampa. Nessun numero qui e' scritto
## prima di averlo misurato: e' la lezione di piano 1.2, dove un'ipotesi sul margine
## si e' rivelata sbagliata solo dopo misurata.
func _sweep(h, horde) -> void:
	var samples: Array[int] = []
	var raw: Array[int] = []
	var seeds: Array[int] = []
	var overflowed: Array[int] = []
	var dirty_cells: Array[int] = []
	var steps_differ := 0
	var steps_alike: Array = []
	var prev: PackedVector3Array = PackedVector3Array()
	for i in SWEEP_COUNT:
		var s: int = SWEEP_FIRST + i * SWEEP_STEP
		seeds.append(s)
		horde.reseed(s)
		# Il seme e' davvero un ingresso: due semi consecutivi dello sweep
		# producono due disposizioni diverse, o il campione non sta misurando
		# niente. Non e' una riga che si lascia supporre: sotto il numero e'
		# contato, e sotto l'asserzione lo richiede **tutto**.
		var here: PackedVector3Array = horde.transforms.duplicate()
		if i > 0:
			var d := _differing(prev, here)
			if d >= REPRO_DIFF_MIN:
				steps_differ += 1
			else:
				steps_alike.append("%d/%d:%d" % [seeds[i - 1], s, d])
		prev = here
		# `reseed` ricostruisce gia' la griglia (punto 5 del contratto di m3),
		# quindi la lettura successiva parla della disposizione appena scritta.
		# `nearest_enemy_index` passa comunque da `_ensure_grid()`: e' l'unica
		# API pubblica che garantisce la ricostruzione, costa una query e rende
		# la misura indipendente da **quando** -orda ha deciso di farlo. (Il
		# nome sull'orda e' `nearest_enemy_index`: `nearest_enemy` e' il nome
		# dell'API **del contratto**, che -orda registra su `Game`.)
		horde.nearest_enemy_index(Vector3.ZERO, 12.0)
		h.eq(horde.count, ENEMY_TARGET,
			"m3: il seme %d deve lasciare 200 nemici vivi" % s)
		var w: int = horde.worst_bucket()
		if horde.grid_overflowed():
			overflowed.append(s)
		if int(horde.get("grid_unknown_cells")) != 0:
			dirty_cells.append(s)
		raw.append(w)

	samples = raw.duplicate()
	samples.sort()
	var lo: int = samples[0]
	var hi: int = samples[samples.size() - 1]
	# Mediana = elemento di indice floor(n/2) della lista ordinata. Su n pari
	# e' il medio-alto, non la media dei due centrali: la media dei due centrali
	# sarebbe un numero che nessuna disposizione ha avuto, e qui si vuole
	# riportare una disposizione **misurata**, non una sintesi.
	var med: int = samples[samples.size() / 2]

	print("test_arena: m3 sweep, %d semi sulla scena vera (%d, %d, ... %d): worst_bucket = %s"
		% [SWEEP_COUNT, seeds[0], seeds[1], seeds[seeds.size() - 1], str(raw)])
	print("test_arena: m3 sweep: min %d, mediana %d, max %d; semi traboccati %d su %d; celle sconosciute %d su %d"
		% [lo, med, hi, overflowed.size(), SWEEP_COUNT, dirty_cells.size(), SWEEP_COUNT])
	print("test_arena: m3 sweep: coppie di semi consecutivi con disposizione diversa %d su %d%s"
		% [steps_differ, SWEEP_COUNT - 1, ("" if steps_alike.is_empty() else "; simili: %s" % str(steps_alike))])

	# Il campione non sta misurando sempre la stessa disposizione sotto vestiti
	# diversi. La soglia e' **tutte** le coppie: misurate 23 su 23, e sotto un
	# seme diverso tutti i 200 nemici si muovono, quindi una coppia simile
	# sarebbe un difetto di `reseed` e non una coincidenza.
	h.check(steps_differ == SWEEP_COUNT - 1,
		"m3: ogni coppia di semi consecutivi dello sweep deve dare una disposizione diversa (almeno %d posizioni su %d): %d su %d, e le coppie simili sono %s"
			% [REPRO_DIFF_MIN, ENEMY_TARGET, steps_differ, SWEEP_COUNT - 1, str(steps_alike)])

	# Il traboccamento e' il fatto vero, e la sua segnalazione e' dedicata:
	# `worst_bucket()` non puo' superare `BUCKET_SLOTS` e non puo' dire da solo
	# che un secchiello e' traboccato.
	h.check(overflowed.is_empty(),
		"m3: nessun seme deve traboccare la griglia sulla scena vera: traboccano i semi %s (picco %d su %d slot)"
			% [str(overflowed), hi, 32])
	h.check(dirty_cells.is_empty(),
		"m3: la griglia non deve scaldare celle nuove nel ciclo di gioco: semi %s" % str(dirty_cells))
	# E il tetto di densita', derivato dalla misura sopra e non da `BUCKET_SLOTS`.
	h.check(hi <= GRID_CEILING,
		"m3: worst_bucket sulla scena vera deve stare sotto il tetto dichiarato %d: massimo misurato %d sui semi %s"
			% [GRID_CEILING, hi, str(seeds)])

	_semantica_worst_bucket(h, horde, seeds, raw)

## ## 8.3 La semantica dichiarata, verificata invece che supposta
##
## `worst_bucket()` e' dichiarato in `src/sim/horde.gd` come **il picco del frame
## (griglia) appena ricostruito**: dentro `spatial_grid.gd` il contatore e' un
## massimo storico che si azzera solo in `setup()`, e `_rebuild_grid()` lo azzera
## a ogni ricostruzione perche' altrimenti direbbe ancora il picco della
## disposizione precedente.
##
## Il modo economico per distinguere le due semantiche non e' leggerne il
## commento: e' chiedere al numero di **scendere**. Si riscrive la disposizione
## peggiore dello sweep e poi quella migliore: se il numero torna indietro sta
## parlando dell'ultima disposizione scritta; se risale, o resta fermo al massimo,
## sta accumulando da `setup()` e tutte le letture dello sweep sono una curva
## sola. E' l'unica parte di questa sezione che puo' fallire se -orda cambia
## idea sulla semantica senza dirlo, ed e' per questo che c'e'.
func _semantica_worst_bucket(h, horde, seeds: Array[int], raw: Array[int]) -> void:
	var i_hi := 0
	var i_lo := 0
	for i in raw.size():
		if raw[i] > raw[i_hi]:
			i_hi = i
		if raw[i] < raw[i_lo]:
			i_lo = i
	horde.reseed(seeds[i_hi])
	h.eq(horde.worst_bucket(), raw[i_hi],
		"m3: riscrivere la disposizione peggiore (%d) deve riprodurre il suo picco %d"
			% [seeds[i_hi], raw[i_hi]])
	horde.reseed(seeds[i_lo])
	var back: int = horde.worst_bucket()
	h.eq(back, raw[i_lo],
		"m3: riscrivere la disposizione migliore (%d) deve riprodurre il suo picco %d, non il massimo di prima"
			% [seeds[i_lo], raw[i_lo]])
	h.check(back < raw[i_hi],
		"m3: worst_bucket() e' dichiarato per-frame, non storico: dopo il seme %d deve scendere a %d dal %d del seme %d. "
		% [seeds[i_lo], back, raw[i_hi], seeds[i_hi]]
		+ "Se resta fermo al massimo, il numero sta accumulando da setup() e ogni lettura di questo test e' sbagliata")
	print("test_arena: m3 semantica worst_bucket(): dopo il seme %d (picco %d) il seme %d lo riporta a %d: e' il picco del frame ricostruito, non un massimo storico"
		% [seeds[i_hi], raw[i_hi], seeds[i_lo], back])

## Quante posizioni di due disposizioni sono diverse. Il confronto e' esatto
## (`!=` su `Vector3`), non una tolleranza: "identici" nel criterio n. 2 di m3
## vuol dire identici, e una tolleranza qui lascerebbe passare un `reseed` che
## sposta ogni nemico di mezzo centimetro.
func _differing(a: PackedVector3Array, b: PackedVector3Array) -> int:
	var n := mini(a.size(), b.size())
	var d := 0
	for i in n:
		if a[i] != b[i]:
			d += 1
	return d

## Una somma delle coordinate. Non serve a misurare niente: serve a dare un
## secondo modo di vedere che due disposizioni sono la stessa cosa, e che il primo
## confronto non e' passato per un caso. Con `near(..., 0.0)` la tolleranza e' zero:
## due somme identiche o non sono.
func _checksum(pts: PackedVector3Array) -> float:
	var acc := 0.0
	for i in pts.size():
		var p := pts[i]
		acc += p.x * 3.0 + p.z * 7.0 + p.y * 11.0
	return acc

# --- 9. Milestone 4: `BUCKET_SLOTS`, e quale caso la obbliga --------------------
#
# ## La domanda, e cio' che NON e'
#
# Non e' "abbasso `BUCKET_SLOTS`" (piano 1.4b). La domanda e': **quale dei due
# numeri che il piano mette uno contro l'altro obbliga la costante** -- il **19**
# dell'orda isolata o il **7** della scena vera -- e con quali numeri oggi.
# L'esito puo' essere anche «il valore corrente era giusto», e va **riferito**,
# non corretto.
#
# ## Il buco che questa sezione chiude
#
# m3 ha misurato `worst_bucket()` **subito dopo `reseed`**, cioe' sulla
# disposizione ad anelli del primo frame. E' una misura giusta di *quello*, ed e'
# il primo frame: sotto e' scritto con i numeri in che passi la densita' supera
# il 7 e da li' in poi non torna piu' sotto. Nessuno lo aveva misurato, perche'
# `worst_bucket()` **non puo' superare `BUCKET_SLOTS`**: li' il numero smette di
# essere una densita' e diventa il tetto del secchiello, cioe' la costante che
# questa sezione sta esaminando.
#
# Per questo sotto la densita' viene contata **direttamente dalle posizioni**
# (`_occupancy_max`) e non letta dalla griglia: e' l'unico modo di sapere
# quanto e' affollata una cella quando la griglia ha gia' smesso di contare.
#
# ## I tre regimi, e perche' sono tre
#
# | regime | cosa misura | chi l'aveva citato |
# |---|---|---|
# | `iniziale` | disposizione a `reseed`, 24 semi, un passo | il **7** di m3 |
# | `isolata` | orda senza giocatore, 900 passi | il **19** di `spatial_grid.gd` |
# | `convergente` | orda vera che insegua il giocatore, 900 passi | **nessuno**: e' il buco |
#
# Il terzo e' lo stato in cui il gioco sta davvero, ed e' l'unico dei tre che
# nessuno aveva guardato.

## La superficie che `src/core/contracts.gd` dichiara congelata per m4. Quattro
## membri: tre esistono gia' dalla m3, il quarto e' quello che `-orda` scrive in
## questa stessa onda.
const M4_SURFACE := ["grid_dropped", "grid_overflowed", "worst_bucket", "reseed"]

## Quanti passi di simulazione per regime. 900 a `DT` = 1/60 sono **15 secondi di
## gioco**: la densita' smette di salire intorno al secondo 8-15 (misurato: il
## primo rifiuto arriva al passo 351, l'ultimo campione che trabocca al 874), e
## una finestra piu' corta non misurerebbe il caso che obbliga.
const CONVERGE_STEPS := 900

## Semi dell'orda **isolata**. Il 177 e' il seme che `tests/test_gameloop.gd`
## dichiara e asserisce; il 1 e' il primo dello sweep di m3. Due perche' il primo
## da solo non basta: un solo seme e' un numero, non una banda.
const ISO_SEEDS := [177, 1]

func _milestone_4(h, arena: Node3D, game: Node) -> void:
	var horde = arena.get_node_or_null("Horde")
	if not h.check(horde != null, "m4: la scena vera non ha il nodo Horde"):
		return

	# `BUCKET_SLOTS` **letta dal codice**, non scritta qui: se `-orda` cambia il
	# valore, le asserzioni sotto parlano del valore nuovo e il test non diventa
	# un involucro di una costante che non esiste piu'. `spatial_grid.gd` non ha
	# `class_name` leggibile da qui, quindi la costante arriva dalla mappa delle
	# costanti dello script.
	var slots := _bucket_slots(h)
	var cell := _grid_cell(h)
	if not h.check(slots > 0 and cell > 0.0,
			"m4: non si legge BUCKET_SLOTS/CELL da src/sim/spatial_grid.gd: senza quei due numeri questa sezione misurerebbe la densita' con un tetto sbagliato"):
		return

	# Superficie congelata. `grid_dropped()` e' l'unico membro che `-orda`
	# scrive in questa onda e che questo test chiama: la dipendenza e'
	# dichiarata, non una corsa. La sezione **non si ferma** quando manca:
	# sotto si misura tutto quello che non dipende dal contatore, cosi' la parte
	# che non ha la dipendenza dichiarata e' verificata lo stesso invece di
	# aspettare che il contatore arrivi. La porta resta rossa, e lo dice con il
	# nome del membro e non con un `Invalid call` senza spiegazione.
	var drop := Callable(horde, "grid_dropped")
	if not h.check(drop.is_valid(),
			"m4: l'orda della scena vera non espone \"grid_dropped()\": e' la superficie congelata in src/core/contracts.gd, sezione \"Superficie di milestone 4\", che terminal-gun-orda scrive nella stessa onda. Qui sotto si misura tutto quello che NON dipende dal contatore"):
		pass
	for m in M4_SURFACE:
		if m != "grid_dropped":
			h.check(horde.has_method(m),
				"m4: l'orda della scena vera non espone \"%s()\": e' la superficie congelata di m4" % m)

	# Il giocatore non deve muoversi da solo: la densita' che si misura e' quella
	# di un'orda che converge **su un punto fermo**, e il punto fermo e' l'unica
	# cosa che questa sezione puo' dichiarare. `_criterion_4` lo ha gia' messo al
	# centro e ha spento la sua guida da tastiera.
	_player_quieto(arena)

	# --- Regime 1: disposizione iniziale (il 7 di m3) --------------------------
	var iniz_worst: Array[int] = []
	var iniz_occ: Array[int] = []
	for i in SWEEP_COUNT:
		var s: int = SWEEP_FIRST + i * SWEEP_STEP
		horde.reseed(s)
		iniz_worst.append(horde.worst_bucket())
		iniz_occ.append(_occupancy_max(horde.transforms, cell))
	# --- Regime 3: la scena vera convergente sul giocatore ------------------
	#
	# `horde.step()` chiama `_rebuild_grid()` **prima** di muovere chiunque, quindi
	# `worst_bucket()` letto dopo il passo descrive le posizioni di inizio frame,
	# mentre l'occupazione contata dalle posizioni e' di fine passo. Sono la stessa
	# densita' a un passo di distanza, e il passo e' `DT`: un nemico a 18 m/s
	# sposta 0.3 m per passo, meno di un decimo di cella.
	var conv_occ: Array[int] = []
	var conv_drop: Array[int] = []
	var conv_over: Array[int] = []
	var primo_oltre_tetto := -1
	var primo_rifiuto := -1
	var contraddizioni := 0
	var contraddizioni_dove: Array[String] = []
	var campionati := 0
	var t0 := Time.get_ticks_msec()
	for i in SWEEP_COUNT:
		var s: int = SWEEP_FIRST + i * SWEEP_STEP
		horde.reseed(s)
		var occ_peak := 0
		var drop_max := 0
		var over := 0
		for f in CONVERGE_STEPS:
			horde.step(DT)
			var w: int = horde.worst_bucket()
			if w > occ_peak:
				occ_peak = w
			# Il conto diretto si paga solo dove serve: sotto `BUCKET_SLOTS` il
			# numero della griglia coincide gia' con l'occupazione, quindi la
			# densita' vera conta solo nei frame in cui la griglia ha smesso di
			# distinguere. Fuori da li' `occ_peak` tiene gia' il numero giusto.
			if w >= slots:
				var occ := _occupancy_max(horde.transforms, cell)
				if occ > occ_peak:
					occ_peak = occ
			if w > GRID_CEILING and primo_oltre_tetto < 0:
				primo_oltre_tetto = f
			if drop.is_valid():
				var d: int = drop.call()
				campionati += 1
				if d > drop_max:
					drop_max = d
				if d > 0 and primo_rifiuto < 0:
					primo_rifiuto = f
				if d > 0 and not horde.grid_overflowed():
					contraddizioni += 1
					if contraddizioni_dove.size() < 4:
						contraddizioni_dove.append("seme %d passo %d (%d rifiutati, flag falso)"
							% [s, f, d])
			if horde.grid_overflowed():
				over += 1
		conv_occ.append(occ_peak)
		conv_drop.append(drop_max)
		conv_over.append(over)
	# --- Regime 2: l'orda isolata, il caso su cui la costante e' tarata ---
	#
	# `horde.gd` **senza** nessun giocatore: `_player_focus()` cade su `_focus`,
	# che e' il centro dell'arena, quindi l'orda converge al centro esattamente
	# come converge sul giocatore fermo. E' il caso di cui `spatial_grid.gd:32-39`
	# scrive «picco di 19 nemici in una sola cella» e su cui `tests/test_gameloop.gd`
	# asserisce l'assenza di traboccamento con il seme 177.
	var iso_occ: Array[int] = []
	var horde_script = load("res://src/sim/horde.gd")
	for s in ISO_SEEDS:
		var iso = horde_script.new()
		iso.seed = s
		iso.set_physics_process(false)
		root.add_child(iso)
		var peak := 0
		for f in CONVERGE_STEPS:
			iso.step(DT)
			var w: int = iso.worst_bucket()
			if w > peak:
				peak = w
			if w >= slots:
				var occ := _occupancy_max(iso.transforms, cell)
				if occ > peak:
					peak = occ
		iso_occ.append(peak)
		root.remove_child(iso)
		iso.free()
		# Il contratto e' stato riscritto dall'orda appena liberata: `Game.horde`
		# e le tre API resterebbero su un nodo morto, e la m2-w2 ha gia' registrato
		# il caso in cui un test misura un puntatore liberato invece del
		# contratto. Si rimette l'orda vera, che e' quella che il resto del test
		# usa e che `_cleanup` libera alla fine.
		game.horde = horde
		game.register_impl("nearest_enemy", horde.nearest_enemy_index)
		game.register_impl("damage_enemy", horde.damage_enemy)
		game.register_impl("random_spawn_point", horde.random_spawn_point)

	# --- 9.1 La dichiarazione: quale caso obbliga la costante ------------------
	var ini := _stat(iniz_occ)
	var iso := _stat(iso_occ)
	var con := _stat(conv_occ)

	var regime := "iniziale"
	var picco: int = ini[2]
	if int(iso[2]) > picco:
		regime = "isolata"
		picco = iso[2]
	if int(con[2]) > picco:
		regime = "convergente"
		picco = con[2]

	print("test_arena: m4 densita' per regime, %d semi (o %d), %d passi a DT=1/60, celle da %.1f m: iniziale min %d mediana %d max %d | isolata min %d mediana %d max %d | convergente min %d mediana %d max %d"
		% [SWEEP_COUNT, ISO_SEEDS.size(), CONVERGE_STEPS, cell, ini[0], ini[1], ini[2], iso[0], iso[1], iso[2], con[0], con[1], con[2]])
	var prec := _precedente(regime, ini, iso, con)
	print("test_arena: m4 il caso che OBBLIGA la costante e' il regime \"%s\" con picco %d nemici in una cella da %.1f m (BUCKET_SLOTS %d); il regime piu' affollato fra gli altri (\"%s\") arriva a %d, e la disposizione iniziale a %d"
		% [regime, picco, cell, slots, prec[0], prec[1], ini[2]])
	print("test_arena: m4 sul regime convergente: primo frame sopra il tetto di m3 (%d) al passo %d, primo rifiuto al passo %d (il rifiuto segue di un frame la densita', perche' la griglia e' ricostruita prima di muovere chiunque). La disposizione iniziale, %d..%d, e' lo stato dei primi passi e non torna piu' sotto"
		% [GRID_CEILING, primo_oltre_tetto, primo_rifiuto, ini[0], ini[2]])

	# Il caso che obbliga non e' quello che m3 ha misurato: e' il numero della
	# sezione, e ha denti perche' forza il regime davvero.
	h.check(regime != "iniziale",
		"m4: il caso che obbliga la costante non puo' essere la disposizione iniziale (picco %d): e' lo stato dei primi passi, non quello in cui il gioco sta. Campione: iniziale max %d, isolata max %d, convergente max %d"
			% [ini[2], ini[2], iso[2], con[2]])
	h.check(con[2] > ini[2],
		"m4: la densita' della scena vera convergente deve superare quella della disposizione iniziale: %d contro %d. Se le due fossero uguali la dichiarazione sopra non distinguerebbe i due numeri del piano"
			% [con[2], ini[2]])

	_nessun_nemico_perso(h, horde, drop, conv_drop, conv_over, contraddizioni,
		contraddizioni_dove, campionati)
	_tetto_non_tautologico(h, slots, con, ini, iso)
	print("test_arena: m4 sezione completata in %d ms" % (Time.get_ticks_msec() - t0))

## 9.2 Nessun nemico perso: il contatore e' il fatto, il flag e' la sua ombra.
##
## Sul **sweep di semi** della scena vera il contatore deve essere zero: e' la
## lettura che il criterio n. 2 di m4 chiede, ed e' la stessa disposizione su cui
## m3 ha tarato il tetto di densita'. Sul regime **convergente** lo stesso
## contatore viene letto e **stampato** ogni passo, e non e' un asserimento:
## quel numero e' il primo dei due del piano, e la sezione 9.1 lo dichiara.
func _nessun_nemico_perso(h, horde, drop: Callable, conv_drop: Array[int],
		conv_over: Array[int], contraddizioni: int, dove: Array[String],
		campionati: int) -> void:
	var persi: Array[int] = []
	var pesi: Array[int] = []
	for i in SWEEP_COUNT:
		var s: int = SWEEP_FIRST + i * SWEEP_STEP
		horde.reseed(s)
		var d: int = 0
		if drop.is_valid():
			d = drop.call()
		if d != 0:
			persi.append(s)
			pesi.append(d)
	h.check(persi.is_empty(),
		"m4: nessun seme dello sweep deve perdere un nemico sulla scena vera: perdono i semi %s con i conteggi %s"
			% [str(persi), str(pesi)])

	# Il flag e' il predetto debole del contatore e i due non possono discordare.
	# Il controllo gira su **ogni passo campionato** del regime convergente, che
	# e' dove il contatore e' davvero diverso da zero: qui l'implicazione e'
	# esercitata su dati veri e non su numeri scritti a mano.
	h.eq(contraddizioni, 0,
		"m4: grid_dropped() > 0 deve sempre implicare grid_overflowed(): %d frame in contraddizione su %d campionati%s"
			% [contraddizioni, campionati, ("" if dove.is_empty() else "; esempi: " + "; ".join(dove))])

	# E la regola stessa deve saper respingere una contraddizione. Senza queste
	# tre righe l'asserzione sopra passerebbe anche se la regola fosse `true`:
	# nessun frame reale la contraddice finche' il codice e' corretto, quindi il
	# suo unico modo di accorgersi che e' falsa e' chiederglielo.
	h.check(not _coerente(1, false),
		"m4: la regola 'un nemico rifiutato implica il flag di traboccamento' deve respingere (1, false): se questa riga cade, la regola sotto non sta controllando niente")
	h.check(_coerente(0, false),
		"m4: nessun nemico rifiutato e nessun traboccamento e' uno stato legittimo")
	h.check(_coerente(7, true),
		"m4: piu' nemici rifiutati con il flag acceso e' uno stato legittimo")

	var persi_conv: Array[String] = []
	for i in SWEEP_COUNT:
		if conv_drop[i] > 0:
			persi_conv.append("seme %d: fino a %d rifiutati, %d frame traboccanti"
				% [SWEEP_FIRST + i * SWEEP_STEP, conv_drop[i], conv_over[i]])
	if persi_conv.is_empty():
		print("test_arena: m4 nessun nemico perso nel regime convergente: %d passi x %d semi, contatore sempre a zero"
			% [CONVERGE_STEPS, SWEEP_COUNT])
	else:
		print("test_arena: m4 ATTENZIONE, sul regime CONVERGENTE la scena vera perde nemici: %d semi su %d perdono almeno un nemico, %s"
			% [persi_conv.size(), SWEEP_COUNT, "; ".join(persi_conv)])

## La regola del criterio n. 2 di m4, isolata in una funzione perche' deve essere
## provabile da sola: il caso interessante e' la contraddizione, che nessun frame
## reale produce finche' il codice e' corretto.
func _coerente(dropped: int, overflowed: bool) -> bool:
	return not (dropped > 0 and not overflowed)

## 9.3 Il tetto di m3 non deve diventare una tautologia.
##
## Il criterio n. 5 di m4: `GRID_CEILING` resta **strettamente sotto**
## `BUCKET_SLOTS` e a distanza maggiore dell'escursione del campione, cosi' resta
## un tetto di densita' e non un'eco del traboccamento.
##
## ## Il campione di riferimento, e la lettura che questo test NON fa
##
## Qui il campione e' quello che **questa sezione dichiara e stampa**: il regime
## convergente, min %d e max %d misurati sopra. Sull'altra lettura possibile --
## l'unione dei tre regimi, min %d e max %d, escursione %d -- il margine di %d
## slot **non** basterebbe. Quel numero e' stampato qui sotto e la decisione che
## ne segue e' **di m3**, non di questo test: questo file **non ricalcola
## `GRID_CEILING`**, e se la legge diverse il vertice la prende per iscritto.
func _tetto_non_tautologico(h, slots: int, con: Array, ini: Array, iso: Array) -> void:
	var escursione: int = con[2] - con[0]
	var margine: int = slots - GRID_CEILING

	h.check(GRID_CEILING < slots,
		"m4: il tetto di m3 (%d) deve stare strettamente sotto BUCKET_SLOTS (%d): se lo raggiunge e' una tautologia, perche' insert() aggiorna il contatore solo con n < BUCKET_SLOTS"
			% [GRID_CEILING, slots])
	h.check(margine > escursione,
		"m4: il margine fra GRID_CEILING (%d) e BUCKET_SLOTS (%d) deve superare l'escursione del campione convergente (%d, da %d a %d): margine %d, escursione %d"
			% [GRID_CEILING, slots, escursione, con[0], con[2], margine, escursione])

	var uni_min: int = mini(ini[0], mini(iso[0], con[0]))
	var uni_max: int = maxi(ini[2], maxi(iso[2], con[2]))
	print("test_arena: m4 tetto di m3: GRID_CEILING %d, BUCKET_SLOTS %d, margine %d; escursione del campione convergente %d (min %d max %d) -> NON TAUTOLOGICO"
		% [GRID_CEILING, slots, margine, escursione, con[0], con[2]])
	print("test_arena: m4 lettura alternativa, unione dei tre regimi: escursione %d (min %d max %d) contro margine %d. Se il vertice conta cosi' l'intero campione, il tetto va ricalcolato per iscritto: questo test non lo ricalcola"
		% [uni_max - uni_min, uni_min, uni_max, margine])

func _player_quieto(arena: Node3D) -> void:
	var p = arena.get_node_or_null("Player")
	if p != null and p.has_method("drive_manually"):
		p.drive_manually()
	if p != null:
		p.set_physics_process(false)

## `BUCKET_SLOTS` letto dal codice, non scritto qui: se `-orda` cambia il valore
## midi, le asserzioni di questa sezione parlano del valore nuovo. `0` se non si
## legge, e in quel caso la sezione non misura niente e lo dice.
func _bucket_slots(h) -> int:
	var s = load("res://src/sim/spatial_grid.gd")
	if s == null:
		return 0
	var cm: Dictionary = s.get_script_constant_map()
	var v = cm.get(&"BUCKET_SLOTS", 0)
	return int(v) if (v is int or v is float) else 0

## `CELL` di `spatial_grid.gd`, letta per la stessa ragione di `BUCKET_SLOTS`: il
## conteggio diretto della densita' usa **la stessa** formula di cella della
## griglia, altrimenti si contano celle diverse da quelle che la griglia indicizza.
func _grid_cell(h) -> float:
	var s = load("res://src/sim/spatial_grid.gd")
	if s == null:
		return 0.0
	var cm: Dictionary = s.get_script_constant_map()
	var v = cm.get(&"CELL", 0.0)
	return float(v) if (v is int or v is float) else 0.0

## Il nemico piu' affollato di una cella, contato **dalle posizioni**.
##
## Non passa dalla griglia perche' la griglia non puo' rispondere: `insert()`
## scrive solo finche' `n < BUCKET_SLOTS`, quindi oltre il tetto il suo contatore
## restituisce il tetto e non la densita'. Il numero che cerca `BUCKET_SLOTS` e'
## proprio questo.
func _occupancy_max(pos: PackedVector3Array, cell: float) -> int:
	var occ: Dictionary = {}
	var best := 0
	for i in pos.size():
		var k := Vector2i(floori(pos[i].x / cell), floori(pos[i].z / cell))
		var n: int = occ.get(k, 0) + 1
		occ[k] = n
		if n > best:
			best = n
	return best

## Minimo, mediana e massimo di un campione: `[lo, med, hi]`. Mediana = elemento
## di indice `size()/2` della lista ordinata, come in 8.2: su n pari e' il
## medio-alto, e una sintesi che nessuna disposizione ha avuto non e' una misura.
func _stat(values: Array[int]) -> Array:
	var s: Array[int] = values.duplicate()
	s.sort()
	return [s[0], s[s.size() / 2], s[s.size() - 1]]

## Il regime immediatamente meno affollato di quello dichiarato: serve solo alla
## riga stampata, per dire **di quanto** il caso che obbliga batte quello che lo
## precede. Il secondo elemento dell'array restituito e' il suo picco.
func _precedente(regime: String, ini: Array, iso: Array, con: Array) -> Array:
	if regime == "convergente":
		var a: int = int(ini[2])
		if int(iso[2]) > a:
			a = iso[2]
		return ["il maggiore fra iniziale e isolata", a]
	if regime == "isolata":
		return ["iniziale", int(ini[2])]
	return ["nessuno", 0]

## ## 9.4 I DENTI DI QUESTA SEZIONE: provati, e poi rimossi
##
## Protocollo di m2-w3 e di m3: un'asserzione che non sa fallire non e' un
## asserzione. Il blocco che forzava il traboccamento **non e' piu' in questo
## file**: fu rimosso dopo la prova. La prova resta scritta qui, con i suoi
## numeri, come in m3.
##
## **Cosa faceva.** Scriveva tutti i 200 nemici dentro **una sola cella** da 4 m e
## li faceva entrare nella griglia con un passo di `horde.step()`, che
## ricostruisce la griglia **prima** di muovere chiunque. Usava solo l'API massa
## dichiarata dal piano (`count` e `transforms`): `transforms` veniva salvato,
## le posizioni riscritte su un reticolo 16x13 dentro `[0, cell)`, e rimesso
## **sempre**, anche con un'asserzione caduta, perche' `check()` non interrompe e
## una riga lasciata indietro avrebbe lasciato l'orda sporca per `_cleanup`.
##
## **Il numero che la prova ha prodotto** (200 nemici in una cella da 4 m):
##
##     occupazione 200, worst_bucket 32, grid_dropped 168, grid_overflowed true
##
## **Quattro asserzioni vere di questa sezione sono cadute**, una per una:
##
## 1. `grid_dropped() == 0` sullo sweep -> 168 contro 0;
## 2. nessun secchiello traboccato -> il flag e' andato a vero;
## 3. densita' sotto `GRID_CEILING` = 11 -> occupazione 200;
## 4. margine `BUCKET_SLOTS - GRID_CEILING` = 21 maggiore dell'escursione del
##    campione forzato -> escursione 170, cioe' 200 contro il minimo del
##    campione convergente, che e' 30.
##
## La quinta, la coerenza fra contatore e flag, e' **rimasta verde**, e doveva:
## 168 rifiutati con il flag acceso sono un **accordo**, non una contraddizione.
## E' esattamente la distinzione che conta: le prime quattro righe dicono che la
## griglia viene **bypassata**, la quinta dice che contatore e flag raccontano la
## stessa cosa. Senza questa prova non si saprebbe se la quinta cade per una
## contraddizione vera o soltanto per un bypass, e la sua verifica separata --
## `_coerente(1, false)` in 9.2, su numeri scritti a mano -- non coprirebbe il
## caso del forcing reale.
##
## Nota sul forcing: il primo tentativo non forzava **niente**, e le asserzioni
## restavano verte. Il motivo e' il copy-on-write che `spatial_grid.gd` dichiara
## gia' in testa -- scrivere in un `PackedVector3Array` tenuto in una variabile
## locale riscrive la copia e `horde.transforms` resta com'era -- ed e' un
## promemoria che vale per tutta la sezione: **un denti che non morde dimostra
## niente, e sembra verde mentre non sta guardando niente.**
	# >>> PROVA DEI DENTI: BLOBCO TEMPORANEO, DA RIMUOVERE <<<
	var saved: PackedVector3Array = horde.transforms.duplicate()
	# Scrive **attraverso `horde.transforms`**, non in una variabile locale: un
	# `PackedVector3Array` tenuto in una variabile e' copy-on-write, quindi
	# `pos[i] = v` riscriverebbe la copia locale e `horde.transforms` resterebbe
	# com'era. E' la stessa trappola che `spatial_grid.gd` dichiara in testa.
	#
	# Tutte e 200 dentro **una sola** cella: `cell_of` arrotonda per difetto, quindi
	# x e z restano in [0, cell) con un reticolo 16x13 che copre 208 posti.
	for i in horde.count:
		var gx := float(i % 16)
		var gz := float(i / 16)
		horde.transforms[i] = Vector3(cell * (0.01 + 0.98 * gx / 15.0), 0.0,
			cell * (0.01 + 0.98 * gz / 12.0))
	# `step()` ricostruisce la griglia **prima** di muovere chiunque, quindi il
	# passo seguente e' quello che mette i 200 nemici dentro la griglia
	horde.step(DT)
	var d: int = 0
	if drop.is_valid():
		d = drop.call()
	var w: int = horde.worst_bucket()
	var o: bool = horde.grid_overflowed()
	var occ := _occupancy_max(horde.transforms, cell)
	# --- Interno --- XXX
	# `PackedVector3Array` tenuto in una variabile e' copy-on-write, quindi
	# `pos[i] = v` riscriverebbe la copia locale e `horde.transforms` resterebbe
	# com'era. E' la stessa trappola che `spatial_grid.gd` dichiara in testa.
	#
	# Tutte e 200 dentro **una sola** cella: `cell_of` arrotonda per difetto, quindi
	# x e z restano in [0, cell) con un reticolo 16x13 che copre 208 posti.
	for i in horde.count:
		var gx := float(i % 16)
		var gz := float(i / 16)
		horde.transforms[i] = Vector3(cell * (0.01 + 0.98 * gx / 15.0), 0.0,
			cell * (0.01 + 0.98 * gz / 12.0))
	# `step()` ricostruisce la griglia **prima** di muovere chiunque, quindi il
	# passo seguente e' quello che mette i 200 nemici dentro la griglia
	horde.step(DT)
	var d: int = 0
	if drop.is_valid():
		d = drop.call()
	var w: int = horde.worst_bucket()
	# --- Interno -------------------------------------------------------------------

## Un nodo e tutto quello che ha sotto, ricorsivamente. Il tetto del criterio n.
## 3 e' su questo numero, quindi il conteggio non puo' essere quello di un altro.
func _count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_nodes(child)
	return total

## Il path dello script attaccato a un nodo, o "" se non ce n'e'. Serve a dire che
## il nodo `Horde` usa il file di -orda e non uno stub con gli stessi campi.
func _script_path(node: Node) -> String:
	if node == null:
		return ""
	var scr = node.get_script()
	if scr == null:
		return ""
	return str(scr.resource_path)

## Un campo del contratto letto per nome: `arena_radius` e `player` sono campi
## dello script di `contracts.gd`, non di `Node`, quindi l'accesso resta dinamico.
func _contract_float(game: Node, key: String) -> float:
	var value = game.get(key)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return -1.0

func _cleanup(arena: Node3D) -> void:
	if arena == null:
		return
	if arena.get_parent() != null:
		arena.get_parent().remove_child(arena)
	arena.free()
