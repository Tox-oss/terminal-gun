extends Node3D
## Il giocatore. -gameplay.
##
## WASD, camera-relativo, chiuso nell'arena, e l'arma che spara da sola.
##
## Tre scelte che tengono insieme il file:
##
## 1. **Nessuna `get_node("../..")`.** Il giocatore conosce l'arma per la
##    scena (o se la crea se manca, una volta sola all'avvio) e l'arma non
##    conosce il giocatore se non attraverso `Game.player_position()`. Nessuna
##    dipendenza circolare (piano §5, regola 3).
##
## 2. **`step(delta, input)` invece di leggere l'input da solo.** La logica di
##    movimento e' una funzione che prende l'input e restituisce una posizione:
##    il `_physics_process` le passa WASD, il test le passa un vettore noto e
##    ottiene un delta noto. Il gioco e il test fanno lo stesso codice, non due
##    versioni diverse di quello.
##
## 3. **Il movimento è relativo alla camera**, ma con un ripiego esplicito: in
##    test non c'è nessuna camera e la base è l'identità, così il test non
##    dipende da nessuna altra foglia e ottiene esattamente il delta che dice.

const PROGRESSION_SCRIPT := preload("res://src/player/progression.gd")
const WEAPON_SCRIPT := preload("res://src/weapons/weapon_base.gd")

## Suoni: se il file non c'è, nessun rumore e nessun errore.
const SFX_HURT := "res://assets/sfx/hurt.wav"
const SFX_LEVELUP := "res://assets/sfx/levelup.wav"

# --- Regolazione del gioco. Sono numeri, non segreti. --------------------------

## Velocita' di corsa, in m/s.
const MOVE_SPEED := 7.0
## Accelerazione, in m/s^2. Non si parte a scatto istantaneo: 60 e' il tempo
## per arrivare alla velocita' piena in poco piu' di un decimo di secondo,
## abbastanza da sentire il peso e non da sembrare un treno.
const ACCEL := 60.0
## Decelerazione quando si molla un tasto, in m/s^2.
const FRICTION := 40.0
const MAX_HP := 100.0
## Secondi di immunità dopo un colpo. Non è un animazione: è la finestra in
## cui l'orda non ti può prendere mentre ti rialzi.
const INVULN_AFTER_HIT := 0.7
## Secondi di scatto.
const DASH_TIME := 0.16
## Velocita' dello scatto, in m/s.
const DASH_SPEED := 22.0
## Secondi fra due scatti.
const DASH_COOLDOWN := 1.1
## Metri di margine dal muro. Il giocatore si ferma un filo prima: l'occhio
## deve poter vedere il bordo, non restare appiccicato.
const ARENA_MARGIN := 0.8

## Un nemico e' morto. Chiamata dall'arma, che lo ha saputo da
## `Game.damage_enemy` che ha risposto `true` (piano §5.2): l'uccisione la dice
## il contratto, non si indovina dal calo di `horde.count`. Prima che
## `damage_enemy` restituisse `bool` qui c'era un ponte che contava la
## differenza di `horde.count`, e non sapeva *chi* era morto: cancellato.
func on_enemy_killed() -> void:
	progression.on_kill(1)

## Il giocatore ha preso un colpo: `amount` e' il danno subito.
signal hurt(amount: float, hp_left: float)
## Vita a zero.
signal died()
## Sale di livello: l'interfaccia mostra le tre scelte.
signal leveled_up(level: int)
## Un potenziamento e' stato applicato.
signal upgrade_applied(id: String)

# --- Stato. Campi e non costanti: sono cio' che i potenziamenti cambiano.
var hp := MAX_HP
var max_hp := MAX_HP
var move_speed := MOVE_SPEED
## Accelerazione corrente, in m/s^2. Campo e non costante: e' un numero di
## regolazione che un test deve poter leggere, e che un potenziamento potrebbe
## voler toccare.
var accel := ACCEL
var velocity := Vector3.ZERO
var invuln := 0.0
var dash_timer := 0.0
var dash_cd := 0.0
## L'arma. Senza tipo di classe: `player.gd` conosce `weapon_base.gd` solo per
## crearla, e nessuno dei due deve il tipo dell'altro.
var weapon
var progression
## True se la tastiera guida il giocatore. Il test la spegne e passa l'input a
## mano, cosi' lo stesso codice serve a entrambi.
var read_keys := true

var _sfx_hurt: AudioStreamPlayer3D
var _sfx_levelup: AudioStreamPlayer3D
var _camera: Camera3D
var _cam_basis := Basis.IDENTITY

func _ready() -> void:
	# Piano §5.1: i dati con l'assegnazione diretta, i metodi con
	# `register_impl`. `Game.spawn_projectile = self._spawn_projectile` viene
	# RIFIUTATO da GDScript e interrompe questo `_ready`: la foglia crede di
	# aver registrato e non ha registrato niente.
	Game.player = self
	Game.register_impl("player_position", self._player_position)

	progression = PROGRESSION_SCRIPT.new()
	progression.bind(self)
	progression.leveled_up.connect(_on_leveled_up)
	progression.upgrade_applied.connect(func(id: String) -> void: upgrade_applied.emit(id))

	# Contratto di m2: `Game.progression` e' il **dato** che -ui e la verifica di
	# `verify_m2_surface()` leggono per nome, e non tramite `Game.player`.
	#
	## Perche' qui e non in `_enter_tree()` (piano sez. 5.1): la regola dice
	# `_enter_tree()` per chi ha **figli che leggono il dato nel proprio avvio**.
	# Qui i figli sono `Model`, `Weapon` e i due `AudioStreamPlayer3D`, e nessuno
	# dei quattro legge `Game.progression`: l'HUD, che e' l'unico lettore, e' un
	# fratello del giocatore dentro `scenes/arena_main.tscn` e lo legge da
	# `_process`, non dal suo `_ready()`. Inoltre l'oggetto non esiste ancora prima
	# di questa riga: registrarlo in `_enter_tree()` pubblicherebbe `null` e il
	# contratto direbbe "manca" per un dato che c'e' un istante dopo.
	#
	## Senza questa riga le dieci voci di `M2_SURFACE` che puntano a `progression`
	## restano irraggiungibili e `Game.progression` vale `null`: il gate resta
	## verde e la superficie di m2 no. Un verde che copre meno di quel che dice e'
	## il difetto peggiore di una porta.
	Game.progression = progression

	weapon = get_node_or_null("Weapon")
	if weapon == null:
		# Senza scena (porta su uno script solo, o test): l'arma la creiamo qui,
		# una volta sola all'avvio. Nel gioco e' `scenes/player.tscn` a portarla,
		# cosi' si vede nella scena e si puo' toccare senza toccare il codice.
		weapon = WEAPON_SCRIPT.new()
		weapon.name = "Weapon"
		add_child(weapon)
	# L'arma deve sapere chi e' il giocatore solo per l'XP: nessun tipo, cosi'
	# `player.gd` e `weapon_base.gd` non si preloaded a vicenda.
	weapon.player = self

	_sfx_hurt = _sound(get_node_or_null("SfxHurt"), SFX_HURT)
	_sfx_levelup = _sound(get_node_or_null("SfxLevelUp"), SFX_LEVELUP)

## Disattiva il pilotaggio automatico: da qui in avanti il movimento lo guida
## `step(delta, input)`. Lo usa il test, che non ha una tastiera.
func drive_manually() -> void:
	read_keys = false
	set_physics_process(false)

# --- Il restart: la meta' di -gameplay ------------------------------------------
#
# `horde.restart_run()` (di -orda) azzera l'orda e la partita e **non tocca il
# giocatore**: se le vite restano a zero, il passo di simulazione successivo
# rilegge `game_over` e la partita si ferma di nuovo. Quindi il restart ha due
# meta' e questa e' la mia.
#
# Nessun nodo viene creato ne' liberato: sono numeri in campi che esistono gia',
# e per il criterio n. 4 ("nessun nodo duplicato") il numero di nodi non puo'
# cambiare invece di dover essere controllato.

## Rimette in piedi il giocatore: vita piena, statistiche ai numeri di codice,
## progressione azzerata, arma riportata alla regolazione di partenza.
func reset_run() -> void:
	hp = MAX_HP
	max_hp = MAX_HP
	move_speed = MOVE_SPEED
	accel = ACCEL
	velocity = Vector3.ZERO
	invuln = 0.0
	dash_timer = 0.0
	dash_cd = 0.0
	# Al centro dell'arena: una partita nuova comincia dal centro, e la camera
	# dell'arena parte gia' li'. Il nemico piu' vicino e' a `Game.nearest_enemy`
	# nell'arma, quindi la posizione non cambia nulla di quello che segue.
	position = Vector3.ZERO
	if progression != null:
		progression.reset()
	if weapon != null:
		weapon.reset()

## Il restart **completo**: io e -orda, in quest'ordine. Prima il giocatore e poi
## l'orda, cosi' nell'istante in cui la partita torna `playing` nessuno e' a zero
## vite e nessuno puo' rileggere `game_over`.
func restart_run() -> void:
	reset_run()
	var horde = Game.horde
	if horde == null or not is_instance_valid(horde):
		# Nessuna orda: il giocatore e' comunque in piedi, ma la partita non
		# riparte. Non e' un errore (i test possono girare senza orda), quindi
		# niente rumore: lo dice solo `push_warning` se l'orda c'e' e non sa
		# ripartire, che quello sì e' un difetto di -orda.
		return
	if not horde.has_method("restart_run"):
		push_warning("player: Game.horde non espone restart_run(): l'orda non riparte. "
			+ "La meta' di -orda e' src/sim/horde.gd::restart_run().")
		return
	horde.call("restart_run")

## Il giocatore e' morto: la meta' di **-gameplay** dello stato `game_over`. Lo
## stato della partita intero e' di -orda (`horde.is_game_over()`), ma a decidere
## che il giocatore e' morto e' la sua vita, e questa e' la domanda che il
## restart e il game over guardano.
func is_dead() -> bool:
	return hp <= 0.0

## Il tasto che rimette in piedi la partita, una volta sola per pressione (non
## un `Input.is_key_pressed` tenuto premuto: quello chiamerebbe il restart a ogni
## frame finche' il tasto resta giù, e la partita ripartirebbe ogni 16 ms).
const RESTART_KEYS := [KEY_ENTER, KEY_KP_ENTER, KEY_R]

func _unhandled_input(event: InputEvent) -> void:
	if not read_keys or not is_dead():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if not RESTART_KEYS.has(key.physical_keycode):
		return
	restart_run()
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()

# --- Il ciclo di gioco ---------------------------------------------------------

func _physics_process(delta: float) -> void:
	var input := read_input() if read_keys else Vector3.ZERO
	var dash := read_keys and (Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT))
	step(delta, input, dash)

## Un passo: timers, scatto, moto, muro, e poi l'arma. L'ordine e' quello che
## si sente: il colpo parte nello stesso frame in cui l'arma e' pronta, e il
## giocatore si muove prima che i proiettili volino.
func step(delta: float, input_dir: Vector3 = Vector3.ZERO, dash: bool = false) -> void:
	if delta <= 0.0:
		return
	invuln = maxf(invuln - delta, 0.0)
	dash_cd = maxf(dash_cd - delta, 0.0)
	if dash_timer > 0.0:
		dash_timer = maxf(dash_timer - delta, 0.0)
	if dash and dash_cd <= 0.0 and dash_timer <= 0.0 and input_dir.length_squared() > 0.0001:
		_start_dash(input_dir)
	var wish := world_direction(input_dir)
	_move(delta, wish)
	if weapon != null:
		weapon.step(delta)

## WASD e frecce, in un vettore del piano schermo: `x` a destra, `z` in
## avanti sullo schermo (quindi -1 con W). Non usa `Input.get_vector` perche'
## `project.godot` non ha una InputMap e non e' mio: `InputMap.has_action`
## avrebbe stampato un errore a ogni frame.
func read_input() -> Vector3:
	var v := Vector3.ZERO
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.z += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.z -= 1.0
	return v.limit_length(1.0)

## Il vettore di input del piano schermo tradotto nel mondo, secondo la camera.
## Se non c'e' camera (test headless, o i primi frame) la base e' l'identita' e il
## risultato e' quello che il test si aspetta: +x = est, -z = nord.
func world_direction(input_dir: Vector3) -> Vector3:
	var flat := Vector3(input_dir.x, 0.0, input_dir.z)
	if flat.length_squared() <= 0.000001:
		return Vector3.ZERO
	flat = flat.normalized()
	var b := _camera_basis()
	var right := Vector3(b.x.x, 0.0, b.x.z)
	# "Su sullo schermo" proiettato sul piano. Su una camera che guarda
	# dall'alto e' la sua `y`; su una camera in piano la `y` non ha parte
	# orizzontale, e il ripiego e' il suo avanti.
	var up := Vector3(b.y.x, 0.0, b.y.z)
	if up.length_squared() < 0.01:
		up = Vector3(-b.z.x, 0.0, -b.z.z)
	if right.length_squared() < 0.0001 or up.length_squared() < 0.0001:
		return Vector3.ZERO
	var dir := (right.normalized() * flat.x) + (up.normalized() * flat.z)
	return dir.limit_length(1.0)

## Un colpo. Restituisce true se è entrato: mentre si è invulnerabili non entra,
## e questa è la difesa contro l'orda che ti ammazza in tre frame.
func take_damage(amount: float) -> bool:
	if amount <= 0.0 or is_invulnerable():
		return false
	hp = maxf(hp - amount, 0.0)
	invuln = INVULN_AFTER_HIT
	if _sfx_hurt != null:
		_sfx_hurt.play()
	hurt.emit(amount, hp)
	if hp <= 0.0:
		died.emit()
	return true

func is_invulnerable() -> bool:
	return invuln > 0.0 or dash_timer > 0.0

## Cura. Clampata a `max_hp`, e sparisce se la morte è già avvenuta: rianimare
## un morto è un bug, non una feature.
func heal(amount: float) -> float:
	if hp <= 0.0 or amount <= 0.0:
		return 0.0
	var before := hp
	hp = minf(hp + amount, max_hp)
	return hp - before

## XP per un nemico ucciso. Chiamata da chi scopre l'uccisione.
func grant_xp(amount: float) -> int:
	return progression.add_xp(amount)

## Quanta vita manca, da 0 a 1. Per l'interfaccia.
func health_ratio() -> float:
	return 0.0 if max_hp <= 0.0 else clampf(hp / max_hp, 0.0, 1.0)

# --- Interno ------------------------------------------------------------------

func _player_position() -> Vector3:
	return global_position

func _move(delta: float, wish: Vector3) -> void:
	var speed := move_speed
	var accel_rate := accel
	if dash_timer > 0.0:
		speed = DASH_SPEED
		accel_rate = accel * 3.0
	elif wish.length_squared() <= 0.000001:
		accel_rate = FRICTION
	var target := wish * speed
	var dv := target - velocity
	var step_len := accel_rate * delta
	if dv.length() <= step_len:
		velocity = target
	else:
		velocity += dv.normalized() * step_len
	position += velocity * delta
	_clamp_to_arena()

## Il muro. Non si annulla la velocita' uscente: si toglie la componente che
## esce e si lascia scivolare quella parallela, altrimenti il giocatore si
## "incastra" nell'angolo e si ferma di botto.
func _clamp_to_arena() -> void:
	var limit := maxf(Game.arena_radius - ARENA_MARGIN, 0.5)
	var flat := Vector3(position.x, 0.0, position.z)
	var d := flat.length()
	if d <= limit:
		return
	var normal := flat / d
	position.x = normal.x * limit
	position.z = normal.z * limit
	var outward := velocity.dot(normal)
	if outward > 0.0:
		velocity -= normal * outward

func _start_dash(input_dir: Vector3) -> void:
	dash_timer = DASH_TIME
	dash_cd = DASH_COOLDOWN
	var dir := world_direction(input_dir)
	if dir.length_squared() > 0.000001:
		velocity = dir * DASH_SPEED

## La base della camera, ricalcolata solo quando la camera cambia.
func _camera_basis() -> Basis:
	var vp := get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp != null else null
	if cam != _camera:
		_camera = cam
		_cam_basis = cam.global_transform.basis if cam != null else Basis.IDENTITY
	return _cam_basis

func _on_leveled_up(new_level: int) -> void:
	if _sfx_levelup != null:
		_sfx_levelup.play()
	leveled_up.emit(new_level)

func _sound(existing, path: String) -> AudioStreamPlayer3D:
	var node: AudioStreamPlayer3D = existing as AudioStreamPlayer3D
	if node == null:
		node = AudioStreamPlayer3D.new()
		node.name = path.get_file().get_basename()
		add_child(node)
	if node.stream == null and ResourceLoader.exists(path):
		var res = load(path)
		node.stream = res as AudioStream
	return node