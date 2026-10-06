extends SceneTree
## Test di gameplay di terminal-gun. -gameplay.
##
## Dimostra la parte di criterio n. 4 della milestone che e' **di -gameplay**: il
## player spara da solo, il proiettile viaggia, e il danno viene applicato **una
## e una sola volta**. Tutto con numeri, non con parole.
##
## Le sette cose che il test dimostra:
##   0. il contratto e' davvero interrogato: `nearest_enemy` e `damage_enemy`
##      chiamati a mano dal test arrivano al doppio, con la semantica giusta
##      (indice, `-1` = nessun bersaglio, `true` = ucciso);
##   1. il player si muove di un delta noto con un input noto, e resta clampato
##      dentro `Game.arena_radius`;
##   2. l'arma spara da sola: entro 60 frame c'e' un proiettile in volo, e la
##      sua direzione e' entro 5 gradi dalla direzione del nemico piu' vicino;
##   3. un proiettile che attraversa un nemico gli applica il danno **una e una
##      sola volta**, e il caso difficile e' esplicito: due nemici
##      **sovrapposti**, un proiettile lento dentro di loro per una quindicina di
##      frame. Se la guardia manca, quel test riceve una quindicina di danni per
##      nemico invece di uno;
##   4. il knockback che l'arma consegna al contratto e' un **impulso in m/s**
##      grezzo, rivolto via dal player, e arriva una volta sola per colpo. Il
##      tetto di 0.3 unita' di spostamento **non** e' asserito qui: quello e'
##      gia' asserito per specie sulla scena vera in `tests/test_arena.gd`, e su
##      un doppio misurerebbe una ricostruzione del gioco. Vedi la nota lunga
##      sopra `_knockback_impulse`, che spiega perche' e' stato tolto;
##   5. dieci uccisioni fatte **attraverso il percorso vero** (`damage_enemy` che
##      risponde `true`) fanno salire di livello, e il livello offre
##      **esattamente 3** potenziamenti, tutti e tre applicabili;
##   6. 300 colpi non allocano niente: il pool non cresce mai e i conteggi di
##      nodi e di oggetti restano quelli di prima.
##
## L'orda e' un **doppio finto** definito qui sotto (`FakeHorde`), non
## `src/sim/horde.gd`: questo test non deve aspettare che -orda abbia finito.
## Il finto implementa esattamente la superficie che -gameplay puo' usare del
## contratto, e nient'altro:
##   - `Game.horde = self` con i due campi pubblici `count` e `transforms`;
##   - `Game.register_impl("damage_enemy", ...)`, che applica `amount` agli HP,
##     **somma** alla velocita' del nemico `knockback * (1 - resist)` e risponde
##     `true` se l'ha ucciso (e' da quel `true` che nasce l'XP: vedi
##     `_xp_and_upgrades`).
##   - `Game.register_impl("nearest_enemy", ...)`, che e' la domanda che l'arma
##     fa per mirare, e di cui `-1` significa "nessun bersaglio".
##
## NOTA SUL CARICAMENTO (piano §5.3): nessuno script di gioco e' in `const
## preload` qui. Un `const preload` in un file lanciato con `--script` risolve
## i suoi script a tempo di compilazione, PRIMA che `Main` aggiunga gli autoload
## ai nomi globali, e `player.gd`/`weapon_base.gd`/`projectile_pool.gd` usano
## l'identificatore nudo `Game`: verrebbero compilati troppo presto e il test
## morirebbe con `Identifier not found: Game`. Per questo'qui gli script si
## caricano a **runtime**, dentro `_process()`, e i valori di gioco si leggono
## dai **campi delle istanze vive** (`player.accel`, `player.move_speed`,
## `weapon.damage`), non dalle costanti degli script.

const H = preload("res://tools/test_harness.gd")

const DT := 1.0 / 60.0
const PLAYER_SCENE := "res://scenes/player.tscn"
const PLAYER_SCRIPT := "res://src/player/player.gd"
## Percorso **stringa**: vedi la nota sul caricamento in testa al file. Serve solo
## per chiedere al suo script la tabella dei potenziamenti, non per preloaderlo.
const PROGRESSION_SCRIPT := "res://src/player/progression.gd"
## La resistenza al knockback del boss: 0.90 in `src/sim/enemy.gd`. Serve alla
## sezione `_knockback_impulse` per provare che e' **il contratto** a decidere
## quanto il colpo sposta, e non -gameplay a pre-scalare l'impulso.
const BOSS_RESIST := 0.90
## HP alti nel test: cosi' l'attenzione va sulla regola del colpo singolo e non
## su chi muore per primo.
const TOUGH := 100000.0

## L'orda finta. Doppio di -orda: `count` + `transforms` come dati, e i due
## metodi registrati sul contratto.
class FakeHorde extends Node:
	## NOTA PER IL VERTICE (piano §5.3): questo file non puo' usare l'identificatore
	## nudo `Game` nella sua classe interna, e non per il contesto ma per il
	## **momento**: vedi la nota sul caricamento in testa al test. Il contratto
	## `Game` qui e' un campo, passato dal test con `root.get_node_or_null`.
	var game
	## I due campi pubblici che il piano dichiara come "massa".
	var count: int = 0
	var transforms := PackedVector3Array()
	## Paralleli a `transforms`, tutti indicizzati come i nemici.
	var hp := PackedFloat32Array()
	var hits := PackedInt32Array()
	var vel := PackedVector3Array()
	## Quanto knockback il nemico si mangia, come fa `damage_enemy` in -orda:
	## `vel += knockback * (1 - resist)`. Le resistenze vere sono 0 / 0.20 /
	## 0.55 / 0.90 per runner, grunt, brute, boss (`Enemy.KNOCKBACK_RESIST`), e
	## quel file non e' mio: qui si mettono a mano i due valori che servono,
	## `0.0` di default e quello del boss dove il test prova che la scala e' del
	## contratto.
	var resist := PackedFloat32Array()
	## La dinamica qui sotto e' quella **vera** di `src/sim/enemy.gd`: smorzamento
	## di primo ordine, non un `drag`. La prima versione di questo file aveva un
	## `drag` scritto a mano e misurava il knockback su quello: era una fisica
	## che in gioco non esiste, e il numero che ne usciva non diceva niente del
	## gioco. Lo sa anche `tests/test_arena.gd`, che lo dice a sua volta.
	var chase_speed := 6.6      ## m/s, `Enemy.SPEED[runner]`, il piu' veloce
	var accel := 8.0            ## 1/s, `Enemy.ACCEL` (tau = 0.125 s)
	## Sottoinsieme dichiarato, perche' un doppio che mente e' peggio di un
	## doppio che manca: qui dentro si muove **un** nemico solo, lontano dal
	## muro, e nessuna asserizione di questo file guarda la sua traiettoria. Quindi
	## mancano di proposito `SPEED_MAX`, `ARRIVE_RADIUS`, la separazione e la banda
	## elastica sul bordo. Se un domani volesse misurare qui dentro lo
	## spostamento di un nemico, questa lista e' il primo posto da rileggere: la
	## misura vera e' in `tests/test_arena.gd`, sulla scena vera.
	## Cosa insegue. Il giocatore di turno e' a zero.
	var target := Vector3.ZERO
	## Contatori, per il test.
	var damage_calls := 0
	## Quante volte `damage_enemy` ha risposto `true`. E' il numero che l'XP
	## deve combaciare: se l'XP salisse senza che il contratto avesse detto
	## "morto", qui resterebbe a zero e il test se ne accorgerebbe.
	var kill_signals := 0
	var deaths := 0
	var out_of_range := 0
	## L'impulso di knockback **come il gameplay lo ha consegnato**, prima che
	## questa classe vi applichi la resistenza: e' cosi' che il test guarda il
	## numero di -gameplay e non quello riscalato dal doppio.
	var last_knockback := Vector3.ZERO
	## La velocita' del nemico subito prima e subito dopo l'ultimo colpo. Servono
	## perche' il nemico **insegue gia'**: la sua velocita' quando arriva il colpo
	## non e' l'impulso, e' l'inseguimento piu' l'impulso. Leggendo la velocita'
	## come se fosse l'impulso si misurerebbe di nuovo l'inseguimento, che e' uno
	## dei due errori gia' documentati in piano 5.4. La **differenza** delle due
	## e' l'impulso tenuto, ed e' quello che il contratto promette.
	var vel_before_hit := Vector3.ZERO
	var vel_after_hit := Vector3.ZERO

	func _ready() -> void:
		# Registrazione vera, con il nome vero: se il gameplay sbaglia la
		# registrazione, `damage_calls` resta a zero e il test se ne accorge.
		game.horde = self
		game.register_impl("damage_enemy", self._damage_enemy)
		game.register_impl("nearest_enemy", self._nearest_enemy)

	func add(pos: Vector3, hp_value: float = 1000.0) -> int:
		transforms.append(pos)
		hp.append(hp_value)
		hits.append(0)
		vel.append(Vector3.ZERO)
		resist.append(0.0)
		count += 1
		return count - 1

	func clear() -> void:
		count = 0
		transforms = PackedVector3Array()
		hp = PackedFloat32Array()
		hits = PackedInt32Array()
		vel = PackedVector3Array()
		resist = PackedFloat32Array()
		damage_calls = 0
		kill_signals = 0
		deaths = 0
		out_of_range = 0
		last_knockback = Vector3.ZERO
		vel_before_hit = Vector3.ZERO
		vel_after_hit = Vector3.ZERO

	## Quanto impulso ha tenuto davvero l'ultimo colpo, in m/s: la differenza
	## fra la velocita' di prima e quella di dopo, non la velocita' di dopo.
	func charge() -> float:
		return (vel_after_hit - vel_before_hit).length()

	func resist_of(i: int) -> float:
		return resist[i] if i >= 0 and i < count else -1.0

	## La resistenza si mette a mano **dopo** `add()`, perche' `add()` deve
	## tenere gli array paralleli della stessa lunghezza e chi le riempie non e'
	## questo test.
	func set_resist(i: int, value: float) -> void:
		if i >= 0 and i < count:
			resist[i] = value

	func hp_of(i: int) -> float:
		return hp[i] if i >= 0 and i < count else -1.0

	func hits_of(i: int) -> int:
		return hits[i] if i >= 0 and i < count else -1

	func pos_of(i: int) -> Vector3:
		return transforms[i] if i >= 0 and i < count else Vector3.ZERO

	## La velocita' del nemico, come il contratto ce l'ha lasciata dopo avervi
	## sommato l'impulso di knockback.
	func vel_of(i: int) -> Vector3:
		return vel[i] if i >= 0 and i < count else Vector3.ZERO

	## Il contratto (piano §5.2): danno agli HP, spinta, e `true` se il nemico e'
	## morto. Il ritorno e' la cosa che -gameplay usa per l'XP: se questo
	## finto non lo restituisse, l'XP del test non salirebbe e si vedrebbe.
	## `knockback` e' gia' un vettore con la velocita' dentro (m/s), non una
	## direzione da normalizzare: e' quello che si aspetta `weapon_base.gd`, e
	## quello che rende il knockback leggibile in 2-3 frame invece che
	## impercettibile. Il suo modulo NON e' la misura del criterio n. 4: la
	## misura e' lo spostamento, e lo misura il test.
	func _damage_enemy(index: int, amount: float, knockback: Vector3) -> bool:
		damage_calls += 1
		if index < 0 or index >= count:
			out_of_range += 1
			return false
		hits[index] += 1
		hp[index] -= amount
		last_knockback = knockback
		vel_before_hit = vel[index]
		vel[index] += knockback * (1.0 - resist[index])
		vel_after_hit = vel[index]
		if hp[index] <= 0.0:
			_remove(index)
			deaths += 1
			kill_signals += 1
			return true
		return false

	## Il contratto (piano §5.2): l'INDICE del nemico piu' vicino, `-1` se non
	## c'e' nessuno. E' lo stesso indice che `damage_enemy` accetta, quindi il
	## gameplay non deve fare nessuna conversione.
	func _nearest_enemy(from: Vector3, radius: float) -> int:
		var best := -1
		var best_d2 := radius * radius
		for i in count:
			var d := transforms[i] - from
			d.y = 0.0
			var d2 := d.length_squared()
			if d2 <= best_d2:
				best_d2 = d2
				best = i
		return best

	## Un frame di orda: insegue e si lascia spingere, con la **stessa legge** di
	## `src/sim/enemy.gd`, cioe' `vel += (wanted - vel) * min(1, dt * ACCEL)`.
	## Non c'e' nessun `drag` nell'orda vera e nessun `drag` qui: e' quello il
	## campo che non esisteva e che aveva fatto fallire questo file.
	func step(delta: float) -> void:
		var k: float = minf(1.0, delta * accel)
		for i in count:
			var toward := target - transforms[i]
			toward.y = 0.0
			var dir := Vector3.ZERO
			if toward.length() > 0.001:
				dir = toward / toward.length()
			vel[i] += (dir * chase_speed - vel[i]) * k
			transforms[i] += vel[i] * delta

	## Mossa con lo swap con l'ultimo, come l'orda vera: e' il caso che
	## sposta gli indici sotto i piedi del gameplay.
	func _remove(index: int) -> void:
		count -= 1
		if index == count:
			return
		transforms[index] = transforms[count]
		hp[index] = hp[count]
		hits[index] = hits[count]
		vel[index] = vel[count]
		resist[index] = resist[count]

# --- Stato del test ------------------------------------------------------------

var game: Node
var horde: FakeHorde
var player: Node3D
var weapon
var pool

var _h
var _ran := false

## Niente qui dentro. Il corpo del test gira al primo frame, non in
## `_initialize()`: un nodo aggiunto a `root` **durante** `_initialize()` non ha
## ancora il `_ready` (la radice non e' ancora dentro la scena), e tutta la parte
## importante di questo progetto - la registrazione sul contratto - sta nel
## `_ready`. Verificarlo in un ordine sbagliato farebbe fallire un test sulle
## cose che funzionano.
func _initialize() -> void:
	_h = H.new()

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	var h: H = _h
	_setup(h)
	# Se il cablaggio non c'e', le sezioni seguenti crasherebbero una dopo l'altra:
	# si esce subito e il FAIL e' il messaggio vero, non un errore a cascata che
	# coprirebbe la causa.
	if player != null and weapon != null and pool != null:
		_movement(h)
		_autofire(h)
		_single_hit(h)
		_overlapping_enemies(h)
		_knockback_impulse(h)
		_damage_and_iframes(h)
		_xp_and_upgrades(h)
		_no_allocation(h)
	quit(h.finish("test_gameplay"))
	return true

# --- 0. La porta, la registrazione, e la prova che il contratto lavori ----------

func _setup(h) -> void:
	game = root.get_node_or_null("Game")
	if not h.check(game != null, "l'autoload Game manca: nessun test delle foglie puo' partire"):
		return
	h.near(game.arena_radius, 28.0, 0.001, "arena_radius di default")

	horde = FakeHorde.new()
	horde.name = "FakeHorde"
	horde.game = game
	root.add_child(horde)
	h.check(game.horde == horde, "l'orda finta registra Game.horde")
	h.check(game.has_impl("damage_enemy"), "l'orda registra damage_enemy sul contratto")
	h.check(game.has_impl("nearest_enemy"), "l'orda registra nearest_enemy sul contratto")

	# mezzo del criterio n. 4: il contratto deve essere **interrogato davvero**,
	# non solo registrato con il nome giusto. Un doppio che si registra e non
	# viene mai chiamato passerebbe tutte le sezioni sotto senza aver provato
	# niente: nessun `damage_calls`, nessun danno, nessun knockback, e il test
	# direbbe lo stesso "PASS". Qui lo si chiama a mano, attraverso `game`, e si
	# controlla che arrivi indietro la risposta giusta.
	horde.add(Vector3(0.0, 0.9, -10.0), TOUGH)
	horde.add(Vector3(9.0, 0.9, -10.0), TOUGH)
	h.eq(game.nearest_enemy(Vector3.ZERO, 26.0), 0,
		"nearest_enemy via contratto: l'indice del nemico piu' vicino")
	h.eq(game.nearest_enemy(Vector3.ZERO, 5.0), -1,
		"fuori raggio nearest_enemy risponde -1, che vuol dire nessun bersaglio")
	h.eq(horde.damage_calls, 0, "e nessun colpo e' partito solo per aver fatto la domanda")

	var knock := Vector3(0.0, 0.0, -9.0)
	var killed_by_contract: bool = game.damage_enemy(0, 7.0, knock)
	h.eq(horde.damage_calls, 1, "damage_enemy via contratto arriva davvero al doppio")
	h.eq(horde.hits_of(0), 1, "e ha colpito una volta sola")
	h.near(horde.hp_of(0), TOUGH - 7.0, 0.0001, "gli HP scendono dell'importo passato")
	h.check(not killed_by_contract,
		"un colpo che non uccide risponde false (piano 5.2: il ritorno e' 'e' morto')")
	h.vec_near(horde.vel_of(0), knock, 0.0001,
		"knockback e' un impulso in m/s sommato alla velocita', non normalizzato")
	h.eq(game.damage_enemy(-1, 7.0, knock), false,
		"-1 non e' un bersaglio: damage_enemy lo rifiuta e risponde false")
	h.eq(horde.out_of_range, 1, "e il rifiuto viene registrato, non ignorato in silenzio")
	h.eq(horde.kill_signals, 0, "nessuna delle due chiamate ha ucciso qualcosa")
	horde.clear()

	# La scena vera quando il modello c'e', altrimenti lo script nudo: il test
	# non deve dipendere dalla cache di import di nessuno.
	# Nota: `load()` e NON `const preload`, vedi la nota sul caricamento in testa
	# al file. Uno script caricato qui e' gia' compilato con gli autoload vivi.
	if FileAccess.file_exists("res://assets/models/player.glb"):
		var packed = load(PLAYER_SCENE)
		if h.check(packed is PackedScene, "scenes/player.tscn deve esistere e caricare"):
			player = (packed as PackedScene).instantiate()
	if player == null:
		var player_script = load(PLAYER_SCRIPT)
		if h.check(player_script is Script, "src/player/player.gd deve caricare"):
			player = (player_script as Script).new()
			player.name = "Player"
	root.add_child(player)
	player.drive_manually()

	h.check(game.player == player, "registrazione dati: Game.player = self (piano 5.1)")
	h.check(game.has_impl("player_position"), "registrazione metodi: player_position")
	h.check(game.has_impl("spawn_projectile"), "registrazione metodi: spawn_projectile")
	h.vec_near(game.player_position(), Vector3.ZERO, 0.0001, "player_position all'avvio")

	weapon = player.weapon
	h.check(weapon != null, "il player deve avere un'arma")
	if weapon == null:
		return
	pool = weapon.pool
	h.check(pool != null, "l'arma deve avere il pool dei proiettili")
	if pool != null:
		h.eq(pool.capacity(), 100, "il pool nasce con 100 proiettili")
		h.eq(pool.ever_created(), 100, "e li ha creati tutti e 100 una volta sola")
		pool.reset()

# --- 1. Movimento con delta noto, e clampato all'arena -------------------------

func _movement(h) -> void:
	_reset(Vector3.ZERO)
	# I numeri di regolazione si leggono dall'istanza viva, non dalle costanti
	# degli script: `player.accel` e' il valore con cui il player si sta davvero
	# muovendo in questo frame, ed e' quello che un potenziamento cambierebbe.
	var accel: float = player.accel
	h.positive(accel, "il player deve avere un'accelerazione")
	var x0 := player.position.x
	player.step(DT, Vector3(1.0, 0.0, 0.0))
	h.near(player.velocity.x, accel * DT, 0.0001,
		"un frame di accelerazione: la velocita' e' accel*dt")
	# Euler semi-implicito: la velocita' e' gia' accel*dt quando la posizione
	# viene aggiornata, quindi lo spostamento del primo frame e' accel*dt^2. Non
	# e' "un po' piu' a destra": e' la legge esatta.
	h.near(player.position.x - x0, accel * DT * DT, 0.0001,
		"lo spostamento del primo frame e' accel*dt^2")
	h.near(player.position.z, 0.0, 0.0001, "input su x non sposta su z")

	# A regime, un frame vale esattamente move_speed*dt.
	for i in 120:
		player.step(DT, Vector3(1.0, 0.0, 0.0))
	var x1 := player.position.x
	player.step(DT, Vector3(1.0, 0.0, 0.0))
	h.near(player.position.x - x1, player.move_speed * DT, 0.0002,
		"a regime un frame di corsa vale move_speed*dt")
	h.near(player.position.x - x1, 0.116667, 0.001, "e cioe' 7 m/s a 60 Hz")

	# Input opposto: la velocita' si annulla, non si ribalta di colpo.
	for i in 60:
		player.step(DT, Vector3(-1.0, 0.0, 0.0))
	h.check(player.velocity.x <= 0.0, "l'input opposto frena il player")

	# Il muro: dall'orlo, verso fuori, due secondi.
	var radius: float = game.arena_radius
	player.position = Vector3(radius - 1.0, 0.0, 0.0)
	player.velocity = Vector3.ZERO
	var escaped := false
	var far := 0.0
	for i in 120:
		player.step(DT, Vector3(1.0, 0.0, 0.0))
		var d := player.position.length()
		far = maxf(far, d)
		if d > radius + 0.001:
			escaped = true
			break
	h.check(not escaped, "il player non esce mai dall'arena (massima distanza %.3f, raggio %.1f)" % [far, radius])
	h.check(far <= radius + 0.001, "la distanza resta sotto arena_radius")
	h.check(far >= radius - 2.0, "e non si ferma troppo prima del muro (%.3f)" % far)
	h.finite(player.position.x, "la posizione dopo il muro e' finita")
	h.near(player.velocity.x, 0.0, 0.5, "e il player non corre piu' contro il muro")

# --- 2. L'arma spara da solo ---------------------------------------------------

func _autofire(h) -> void:
	_reset(Vector3.ZERO)
	horde.target = Vector3.ZERO
	horde.add(Vector3(0.0, 0.9, -8.0), TOUGH)
	weapon.cooldown = 0.0
	var ever_active := false
	var peak := 0
	for i in 60:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
		if pool.active_count() > 0:
			ever_active = true
		peak = maxi(peak, pool.active_count())
	h.check(ever_active, "entro 60 frame dal caricamento deve esserci un proiettile in volo")
	h.check(peak > 0, "il pool deve aver trattenuto dei proiettili (picco %d)" % peak)
	h.eq(horde.out_of_range, 0, "nessuna chiamata a damage_enemy con indice fuori dall'orda")

	# Il colpo parte nello stesso frame in cui l'arma e' pronta: cooldown a 0 e
	# nessun Timer, quindi il primo step spara. Non al secondo frame.
	# Il cooldown viene messo a zero a mano perche' e' un **campo**: e' il
	# countdown che l'arma decrementa, e metterlo a 0 e' esattamente dire "l'arma
	# e' pronta adesso". Il test non aspetta che il cooldown torni a zero per
	# caso: quello dipenderebbe da quanti frame sono passati e non dimostrerebbe
	# nulla sulla temporizzazione del colpo.
	pool.reset()
	weapon.cooldown = 0.0
	player.step(DT, Vector3.ZERO)
	h.eq(pool.active_count(), 1, "il primo colpo esce al primo frame, non al secondo")
	var p = pool.active_at(0)
	if h.check(p != null, "il proiettile appena sparato deve esistere"):
		var muzzle: Vector3 = weapon.muzzle_position()
		var to_target: Vector3 = horde.pos_of(0) - muzzle
		var angle := rad_to_deg(p.dir.angle_to(to_target.normalized()))
		h.check(angle <= 5.0, "il proiettile punta al nemico piu' vicino: %.2f gradi (tetto 5)" % angle)
		h.check(p.prev_pos.distance_to(p.pos) > 0.0, "e il proiettile si e' gia' mosso")

	# Senza nessun nemico nel raggio l'arma non spara: niente spari a vuoto.
	_reset(Vector3.ZERO)
	weapon.cooldown = 0.0
	horde.add(Vector3(0.0, 0.9, -400.0), TOUGH)
	for i in 30:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
	h.eq(pool.active_count(), 0, "nessun nemico entro acquire_radius: nessun colpo")
	h.eq(horde.damage_calls, 0, "e nessun colpo sparato a vuoto")

# --- 3. Danno una volta sola ---------------------------------------------------

func _single_hit(h) -> void:
	_reset(Vector3.ZERO)
	horde.target = Vector3.ZERO
	# Un colpo solo in volo per tutta la sezione: qui si prova che **quel**
	# proiettile non ripete il danno, e non che l'arma smetta di sparare.
	# Con il cooldown di serie (0.35 s) il secondo colpo arriverebbe dentro la
	# finestra dei 30 frame e il test misurerebbe la cadenza, non la guardia.
	var fire_before: float = weapon.fire_interval
	weapon.fire_interval = 10.0
	weapon.cooldown = 0.0
	horde.add(Vector3(0.0, 0.9, -6.0), 1000.0)
	var frames := _run_until_hit(120)
	h.check(horde.damage_calls == 1,
		"un proiettile che attraversa un nemico lo colpisce UNA volta sola: %d chiamate in %d frame"
		% [horde.damage_calls, frames])
	h.eq(horde.hits_of(0), 1, "un solo colpo su quel nemico")
	h.near(horde.hp_of(0), 1000.0 - weapon.damage, 0.0001,
		"gli HP scendono di un colpo e non di uno di piu'")
	h.eq(horde.out_of_range, 0, "nessun indice fuori dall'orda")

	# E non ricomincia: 30 frame dopo l'impatto nessun altro danno.
	for i in 30:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
	h.eq(horde.damage_calls, 1, "nessun secondo danno nei 30 frame dopo l'impatto")
	weapon.fire_interval = fire_before

## Il caso che separa un test che prova qualcosa da uno che passa a vuoto:
## due nemici **sovrapposti** e un proiettile lento che resta dentro di loro per
## una quindicina di frame. Una guardia assente qui non fa fallire nient'altro:
## fa solo che il nemico si becca quindici colpi invece di uno, e il test
## "colpisce una volta sola" passa lo stesso perche' guarda un solo nemico.
func _overlapping_enemies(h) -> void:
	_reset(Vector3.ZERO)
	horde.target = Vector3.ZERO
	# I valori di qui sotto sono **campi** dell'arma viva, non costanti degli
	# script: vengono salvati prima e rimessi a posto dopo. Sono regolazione del
	# gioco e un test che li lascia sporchi fa fallire in modo falso la sezione
	# successiva, che si aspetta il proiettile veloce di prima.
	var fire_before: float = weapon.fire_interval
	var pierce_before: int = weapon.pierce
	var speed_before: float = weapon.projectile_speed

	# Due nemici sulla stessa testa: l'orda non distingue i due, quindi il
	# gameplay deve distinguerli per indice e non per posizione.
	horde.add(Vector3(0.0, 0.9, -2.0), TOUGH)
	horde.add(Vector3(0.0, 0.9, -2.0), TOUGH)
	weapon.fire_interval = 10.0
	weapon.cooldown = 0.0
	weapon.pierce = 5
	weapon.projectile_speed = 6.0
	var peak_active := 0
	for i in 60:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
		peak_active = maxi(peak_active, pool.active_count())
	h.eq(horde.damage_calls, 2,
		"due nemici sovrapposti: due colpi in tutto, uno per nemico, non uno per frame")
	h.eq(horde.hits_of(0), 1, "il primo nemico prende un colpo solo")
	h.eq(horde.hits_of(1), 1, "il secondo nemico prende un colpo solo")
	h.eq(horde.deaths, 0, "in questo caso nessuno deve morire (HP alti apposta)")
	h.check(peak_active >= 1, "il proiettile lento doveva essere in volo (%d)" % peak_active)

	# Lo stesso caso con pierce 0: un colpo e il proiettile sparisce.
	_reset(Vector3.ZERO)
	horde.add(Vector3(0.0, 0.9, -2.0), TOUGH)
	horde.add(Vector3(0.0, 0.9, -2.0), TOUGH)
	weapon.fire_interval = 10.0
	weapon.cooldown = 0.0
	weapon.pierce = 0
	weapon.projectile_speed = 6.0
	for i in 60:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
	h.eq(horde.damage_calls, 1, "senza pierce il proiettile colpisce una volta sola e muore")
	h.eq(horde.hits_of(1), 0, "e il secondo nemico sovrapposto resta intatto")

	# Ripulisci: un test che lascia la regolazione sporca fa fallire in modo
	# falso chi viene dopo, e questo file e' la prova che non va fatto.
	weapon.fire_interval = fire_before
	weapon.pierce = pierce_before
	weapon.projectile_speed = speed_before

# --- 4. Knockback: l'impulso che -gameplay consegna -----------------------------
#
# `knockback` e' un **impulso in m/s** (piano 5.2) e i numeri sono di -gameplay.
# Qui quindi si asserisce la parte che e' sua, e sono tre cose che tornano a
# leggersi nel sorgente di `weapon_base.gd`:
#   1. l'impulso arriva **grezzo**, cioe' col modulo di `weapon.knockback` e non
#      normalizzato: un vettore normalizzato avrebbe modulo 1 e il colpo non si
#      sentirebbe;
#   2. va **via dal player**, mai verso: il nemico scattato addosso a chi spara
#      e' l'opposto del "bonk";
#   3. arriva **una volta sola per colpo**, insieme al danno, e con la scala
#      della resistenza ce la mette **il contratto**, non -gameplay.
#
# PERCHE' IL TETTO DI 0.3 UNITA' NON E' ASSERITO QUI (era qui, e l'ho tolto).
# Lo spostamento del nemico e' una proprieta' della fisica di -orda: tempo
# caratteristico, tetto di velocita', resistenza per specie. Misurarlo su un
# doppio significa misurare il doppio. La prima versione di questa sezione lo
# faceva, e cosi' ha fatto due cose sbagliate in una: si e' inventata un `drag`
# che nell'orda non esiste, e ha tarato `KNOCKBACK` (14 -> 18) per far passare
# la propria soglia invece di quella del gioco. Il tetto in unita' e' asserito
# per specie sulla **scena vera** in `tests/test_arena.gd`, su runner e grunt,
# che sono le specie su cui il knockback e' progettato per funzionare (brute e
# boss lo resistono per progetto, piano 5.4). Il margine residuo del runner e'
# accoppiato a `SPEED_MAX` e ad `ACCEL` di -orda: e' un fatto registrato e aperto
# nel piano, e non si prova a coprirlo da qui.

func _knockback_impulse(h) -> void:
	_reset(Vector3.ZERO)
	horde.target = Vector3.ZERO
	# Un colpo solo in volo per tutta la sezione, come in `_single_hit`: qui si
	# guarda l'impulso di **quel** colpo, non la cadenza dell'arma.
	var fire_before: float = weapon.fire_interval
	weapon.fire_interval = 10.0
	weapon.cooldown = 0.0
	horde.add(Vector3(0.0, 0.9, -6.0), 1000.0)
	var frames := _run_until_hit(120)
	h.check(horde.damage_calls == 1 and horde.hits_of(0) == 1,
		"il colpo e' arrivato una volta sola: %d chiamate a damage_enemy in %d frame, %d hit"
		% [horde.damage_calls, frames, horde.hits_of(0)])

	# L'impulso **come il gameplay lo ha consegnato**, cioe' prima che questo
	# doppio vi applichi la resistenza: se fosse gia' riscalato qui dentro si
	# leggerebbe il numero sbagliato.
	var impulse := horde.last_knockback
	h.finite(impulse.length(), "l'impulso e' finito")
	h.check(impulse.length() > 0.0, "il colpo deve consegnare un impulso non nullo")
	h.near(impulse.length(), weapon.knockback, 0.0001,
		"l'impulso e' il numero di -gameplay, non un vettore normalizzato: %.3f contro %.3f m/s"
		% [impulse.length(), weapon.knockback])
	# Il nemico e' a z negativo e il player a zero: la spinta deve andare verso z
	# piu' negativo, cioe' allontanarlo.
	h.check(impulse.z < 0.0,
		"la spinta e' rivolta lontano dal player, non verso: %s" % str(impulse))
	# Deve battere l'inseguimento, altrimenti il numero non produce nessuna
	# sensazione. Il confronto e' con la specie piu' veloce dell'orda (6.6 m/s),
	# non solo con quella che si trova in questa sezione.
	h.check(weapon.knockback > horde.chase_speed,
		"l'impulso deve battere l'inseguimento piu' veloce (%.1f m/s): ne ha %.1f m/s"
		% [horde.chase_speed, weapon.knockback])
	# E l'impulso tiene una volta sola, non due: e' la **differenza** fra la
	# velocita' di prima e quella di dopo il colpo, perche' il nemico insegue
	# gia' e la sua velocita' non e' l'impulso.
	h.vec_near(horde.vel_after_hit - horde.vel_before_hit,
		impulse * (1.0 - horde.resist_of(0)), 0.0001,
		"il nemico senza resistenza tiene l'impulso per intero, una volta sola: %.3f m/s"
		% horde.charge())

	# Lo stesso colpo su un nemico che lo resiste quasi tutto (0.90: il boss di
	# -orda). Se -gameplay pre-scalasse l'impulso, il boss si muoverebbe come un
	# runner e il criterio sui runner passerebbe senza volerlo: quindi la scala
	# deve accadere **qui**, nel contratto.
	_reset(Vector3.ZERO)
	horde.target = Vector3.ZERO
	horde.add(Vector3(0.0, 0.9, -6.0), 1000.0)
	horde.set_resist(0, BOSS_RESIST)
	weapon.cooldown = 0.0
	_run_until_hit(120)
	h.eq(horde.damage_calls, 1, "il colpo sul nemico che resiste arriva una volta sola")
	h.eq(horde.hits_of(0), 1, "e lo prende un colpo solo")
	var charged := horde.charge()
	h.near(charged, weapon.knockback * (1.0 - BOSS_RESIST), 0.0001,
		"il nemico che resiste %.2f tiene solo il %.0f%% dell'impulso: %.3f di %.3f m/s"
		% [BOSS_RESIST, (1.0 - BOSS_RESIST) * 100.0, charged, weapon.knockback])
	weapon.fire_interval = fire_before
	print("criterio 4, danno e impulso: 1 hit per colpo, %.1f m/s consegnati al contratto una volta sola"
		% weapon.knockback)
	print("criterio 4, scala: e' il contratto a ridurre l'impulso (resistenza 0 -> %.1f m/s, %.2f -> %.3f m/s)"
		% [weapon.knockback, BOSS_RESIST, charged])
	print("criterio 4, spostamento: non e' asserito qui perche' e' una fisica di -orda; "
		+ "lo asserisce per specie tests/test_arena.gd sulla scena vera")

# --- 4b. Danno al player e invulnerabilita' ------------------------------------

func _damage_and_iframes(h) -> void:
	_reset(Vector3.ZERO)
	horde.add(Vector3(0.0, 0.9, -6.0), TOUGH)
	player.invuln = 0.0
	player.hp = player.max_hp
	h.check(player.take_damage(30.0), "il player accetta un colpo")
	h.near(player.hp, player.max_hp - 30.0, 0.0001, "e perde 30 HP")
	h.check(player.is_invulnerable(), "dopo il colpo e' invulnerabile")
	h.check(not player.take_damage(30.0), "il secondo colpo nello stesso momento non entra")
	h.near(player.hp, player.max_hp - 30.0, 0.0001, "gli HP non scendono due volte")
	for i in 60:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
	h.check(not player.is_invulnerable(), "dopo un secondo non e' piu' invulnerabile")
	h.check(player.take_damage(30.0), "e il colpo successivo entra")
	h.near(player.hp, player.max_hp - 60.0, 0.0001, "HP dopo due colpi")

# --- 5. XP, livello, tre potenziamenti applicabili ------------------------------

func _xp_and_upgrades(h) -> void:
	var prog = player.progression
	if not h.check(prog != null, "il player deve avere la progressione"):
		return

	# La tabella dei potenziamenti si chiede allo **script della progressione**,
	# letto a runtime con `get_script_constant_map()`: e' l'unico modo di
	# arrivare alla costante di uno script senza metterla in `const preload` qui
	# dentro (vedi la nota sul caricamento in testa al file).
	var known := _known_upgrades(prog)
	h.eq(known.size(), 8, "la progressione dichiara 8 potenziamenti possibili")

	# I valori di qui sotto sono campi di orda e d'arma: salvati, cambiati per
	# rendere la misura pulita, e rimessi a posto **sempre**, anche se un'asserzione
	# qui sotto fallisce: `check()` non interrompe, quindi il ripristino e'
	# garantito e la sezione dopo non parte da numeri sporchi.
	var chase_before: float = horde.chase_speed
	var fire_before: float = weapon.fire_interval
	horde.target = Vector3.ZERO
	# I nemici devono stare fermi: con la legge vera di -orda (`chase_speed` a
	# zero e il solo smorzamento di primo ordine) la velocita' si scarica a zero e
	# loro restano dove sono, quindi la distanza non cambia durante la misura.
	horde.chase_speed = 0.0

	# --- 5a. La prova che l'XP arriva dal `true` di `damage_enemy` -----------
	# Un colpo che NON uccide non deve muovere niente. Se l'XP dipendesse da
	# qualcos'altro (un conteggio, una euristica, il solo fatto che il
	# proiettile e' arrivato) qui l'XP salirebbe e il test lo direbbe.
	_reset(Vector3.ZERO)
	horde.chase_speed = 0.0
	weapon.fire_interval = fire_before
	horde.add(Vector3(0.0, 0.9, -6.0), TOUGH)
	var earned_before: float = prog.xp_earned
	weapon.cooldown = 0.0
	_run_until_hit(120)
	h.eq(horde.damage_calls, 1, "il colpo e' arrivato")
	h.eq(horde.kill_signals, 0, "ma non ha ucciso nessuno: damage_enemy ha risposto false")
	h.eq(horde.deaths, 0, "e l'orda non ha perso nessuno")
	h.eq(prog.kills, 0, "una chiamata che risponde false non e' un'uccisione")
	h.near(prog.xp_earned, earned_before, 0.0001,
		"e non porta XP: l'XP viene dal `true`, non dall'aver colpito")

	# --- 5b. Dieci uccisioni attraverso il percorso vero ----------------------
	# Nemici con `hp = weapon.damage`: uno solo colpo li uccide, quindi ogni
	# `damage_enemy` deve rispondere `true`. Il cooldown e' piu' lungo del
	# viaggio del proiettile, cosi' in volo ce n'e' uno solo e le uccisioni sono
	# esattamente dieci, non "dieci piu' qualcosa": un'uccisione in piu' farebbe
	# fallire il confronto tra l'XP e i `true` ricevuti, che e' la prova.
	_reset(Vector3.ZERO)
	horde.target = Vector3.ZERO
	horde.chase_speed = 0.0
	weapon.fire_interval = 0.25
	weapon.cooldown = 0.0
	for i in 10:
		horde.add(Vector3(0.0, 0.9, -4.0), weapon.damage)
	var guard := 0
	while horde.deaths < 10 and guard < 900:
		_frame()
		guard += 1
	h.check(horde.deaths == 10,
		"dieci nemici uccisi attraverso il percorso vero, in %d frame (%d uccisi)" % [guard, horde.deaths])
	h.eq(horde.kill_signals, 10, "damage_enemy ha risposto true esattamente dieci volte")
	h.eq(horde.damage_calls, 10, "e non ha mai risposto false: nessun colpo sprecato")
	h.eq(horde.out_of_range, 0, "nessun indice fuori dall'orda")
	h.eq(prog.kills, 10, "la progressione ha contato le dieci uccisioni")
	# La prova che l'XP e' arrivato da `damage_enemy` che ha risposto `true`: il
	# totale guadagnato combacia, uccisione per uccisione, con i `true` che il
	# contratto ha restituito. Se l'XP venisse da una strada diversa, il
	# confronto qui fallirebbe anche se il livello salisse lo stesso.
	h.near(prog.xp_earned, prog.xp_per_kill * float(horde.kill_signals), 0.0001,
		"l'XP e' arrivato dalle %d chiamate a damage_enemy che hanno risposto true"
		% horde.kill_signals)
	h.check(prog.xp_earned >= prog.xp_to_next(1),
		"l'XP superato supera la soglia del livello 2 (%.0f): ne ha %.1f"
		% [prog.xp_to_next(1), prog.xp_earned])
	h.check(prog.level >= 2,
		"e il livello e' salito: %d (era 1)" % prog.level)

	# Il livello offre esattamente 3 potenziamenti, tutti diversi e tutti
	# applicabili: nessuno dei tre deve essere un no-op silenzioso.
	h.eq(prog.pending(), 3, "il level-up offre esattamente 3 potenziamenti")
	var offered: Array = prog.offers.duplicate()
	h.eq(_count_unique(offered), 3, "le tre offerte sono tre potenziamenti diversi")
	for id in offered:
		h.check(known.has(id), "l'offerta '%s' e' un potenziamento che esiste" % str(id))
	for i in 3:
		var signature_before := _signature()
		var chosen: String = prog.choose(0)
		h.check(chosen != "", "offerta %d applicabile (choose ha risposto '%s')" % [i + 1, chosen])
		h.check(_signature() != signature_before,
			"applicare '%s' cambia un numero davvero, non e' un no-op" % chosen)
	h.eq(prog.pending(), 0, "dopo tre scelte non resta nessuna offerta")
	h.eq(prog.choose(0), "", "e sceglere con il menu vuoto non applica niente")

	horde.chase_speed = chase_before
	weapon.fire_interval = fire_before

# --- 6. 300 colpi, zero allocazioni ---------------------------------------------

func _no_allocation(h) -> void:
	_reset(Vector3.ZERO)
	horde.target = Vector3.ZERO
	# Nemico lontanissimo e proiettili che muoiono subito: 300 colpi senza che
	# nessuno colpisca nessuno, cosi' il confronto e' sul puro costo di sparare.
	# (Se qualcuno colpisse, `Game.damage_enemy` passerebbe da una Callable e
	# li' dentro ci sarebbe un'allocazione che non e' del gameplay.)
	horde.add(Vector3(0.0, 0.9, -20.0), TOUGH)
	var fire_before: float = weapon.fire_interval
	var life_before: float = weapon.projectile_life
	weapon.fire_interval = 0.0
	weapon.projectile_life = DT
	weapon.cooldown = 0.0
	for i in 5:
		_frame()
	pool.reset()
	var shots_before: int = weapon.shots
	var created_before: int = pool.ever_created()

	var nodes_before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var objects_before := Performance.get_monitor(Performance.OBJECT_COUNT)
	var peak := 0
	for i in 300:
		_frame()
		peak = maxi(peak, pool.active_count())
	var nodes_after := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var objects_after := Performance.get_monitor(Performance.OBJECT_COUNT)

	h.check(weapon.shots - shots_before >= 300,
		"300 frame a fuoco libero devono dare almeno 300 colpi (ne sono partiti %d)"
		% (weapon.shots - shots_before))
	h.eq(pool.ever_created(), created_before,
		"nessun proiettile creato dopo i primi 100")
	h.eq(pool.ever_created(), pool.capacity(),
		"il pool non ha mai creato un proiettile oltre i suoi 100")
	h.check(peak <= pool.capacity(), "il pool non e' mai andato oltre la capacita' (%d)" % peak)
	h.check(nodes_after == nodes_before,
		"nessun nodo nuovo in 300 colpi: %d -> %d" % [int(nodes_before), int(nodes_after)])
	h.check(objects_after - objects_before <= 2,
		"nessuna allocazione nel ciclo di sparo: oggetti %d -> %d (delta %d)"
		% [int(objects_before), int(objects_after), int(objects_after - objects_before)])

	# Ripulisci i campi toccati, o il file si lascia la regolazione sporca.
	weapon.fire_interval = fire_before
	weapon.projectile_life = life_before

# --- Interno -------------------------------------------------------------------

## Parti da zero: niente nemici, niente proiettili, player fermo al centro,
## e progressioni azzerate.
func _reset(at: Vector3) -> void:
	if pool != null:
		pool.reset()
	if horde != null:
		horde.clear()
	player.position = at
	player.velocity = Vector3.ZERO
	player.invuln = 0.0
	player.dash_timer = 0.0
	player.dash_cd = 0.0
	var prog = player.progression
	if prog != null:
		prog.kills = 0
		prog.xp = 0.0
		prog.xp_earned = 0.0
		prog.level = 1
		prog.offers = []

## Un passo di simulazione: il giocatore (che muove e spara) e l'orda.
func _frame() -> void:
	player.step(DT, Vector3.ZERO)
	horde.step(DT)

## Va avanti finche' l'orda non e' stata colpita, e restituisce quanti frame
## ci sono voluti. Il fermo a `max_frames` e' il tetto: se il colpo non arriva, il
## test deve fallire subito e non girare per sempre.
func _run_until_hit(max_frames: int) -> int:
	var frames := 0
	while horde.damage_calls == 0 and frames < max_frames:
		_frame()
		frames += 1
	return frames

## La tabella dei potenziamenti, letta dallo script della progressione a runtime.
func _known_upgrades(prog) -> Array:
	var consts: Variant = prog.get_script().get_script_constant_map()
	if not (consts is Dictionary):
		return []
	for key in (consts as Dictionary):
		if str(key) == "UPGRADE_IDS":
			return (consts as Dictionary)[key]
	return []

## I numeri che i potenziamenti cambiano, come stringhe: se un potenziamento
## cambiasse qualcosa di invisibile, la firma non cambierebbe e il test lo
## direbbe. Otto etichette e otto argomenti: una firma che non si puo' formattare
## restituisce "" e fa sembrare tutti i potenziamenti un no-op.
func _signature() -> String:
	return "d%.5f/i%.5f/v%.5f/k%.5f/p%d/l%.5f/m%.5f/h%.1f" % [
		weapon.damage, weapon.fire_interval, weapon.projectile_speed,
		weapon.knockback, weapon.pierce, weapon.projectile_life,
		player.move_speed, player.max_hp]

func _count_unique(values: Array) -> int:
	var seen := {}
	for v in values:
		seen[v] = true
	return seen.size()
