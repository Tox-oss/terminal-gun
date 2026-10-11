extends SceneTree
## Test di gameplay di terminal-gun. -gameplay.
##
## Dimostra la parte di criterio n. 4 della milestone che e' **di -gameplay**: il
## player spara da solo, il proiettile viaggia, e il danno viene applicato **una
## e una sola volta**. Tutto con numeri, non con parole.
##
## Le sette cose della milestone 1 che il test dimostra, e le tre di m2:
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
##      nodi e di oggetti restano quelli di prima;
##   9. **criterio n. 4 di m2, meta' di -gameplay**: `reset_run()` rimette in
##      piedi il giocatore, `restart_run()` rimette in piedi la partita intera, e
##      nessun nodo viene duplicato. Il numero che decide e' uno solo: dopo il
##      restart, un passo di simulazione **non** rilegge `game_over`.
##
## ## I DUE TEST DI m2 CHE HANNO UN FILE LORO
##
## Il criterio n. 2 (l'XP) e' in `tests/test_progression.gd` e il criterio n. 3
## (i potenziamenti) e' in `tests/test_upgrades.gd`: sono file separati per il
## piano §3.3, e qui non ci sono piu'. Prima stavano in questo file solo perche'
## su questa macchina non si poteva creare un file nuovo; il permesso e' stato
## riparato e i due file esistono.
##
## Quello che resta qui e' la parte che **non** e' loro: il livello che offre
## esattamente tre potenziamenti applicabili (criterio n. 4 di m1) e il restart.
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
## L'orda **vera** di -orda, caricata a runtime dalla sezione del restart. E' uno
## script, quindi non ha bisogno della cache di import: e' l'unica parte del
## percorso vero che questo test usa senza `scenes/arena_main.tscn`, che
## `tests/test_progression.gd` e `tests/test_upgrades.gd` caricano per intero.
const HORDE_SCRIPT := "res://src/sim/horde.gd"
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
var _t0 := 0
## La regolazione **di partenza**, letta dall'istanza viva subito dopo l'avvio e
## prima che una sola sezione la sporchi.
##
## ## Perche' esiste, e il difetto che ha scoperto
##
## Il restart era confrontato contro uno `vita0`/`corsa0`/`spinta0` letti **all'inizio
## della sezione del restart**, e a quel punto la sezione 5 aveva gia' applicato tre
## potenziamenti: la spinta era 23.4 (18 x 1.3, il prodotto di un rialzo
## deliberato), la vita massima 120 (100 + 20) e la corsa 8.47. Il test si
## aspettava quindi quei numeri sporchi e il codice, che riporta tutto alla
## **regolazione di partenza** (18.0, 100.0, 7.0, i valori di `weapon_base.gd` e
## `player.gd`), falliva su un difetto che non aveva.
##
## Il riferimento giusto e' l'unico che non dipende dall'ordine delle sezioni: lo
## stato **vergine**, preso qui sotto. Ed e' anche la prova che `KNOCKBACK` non e'
## stato alzato in m2 (piano §1.2, conseguenza n. 2): il numero di partenza e'
## 18.0 e resta 18.0 dopo il restart.
var _prima: Dictionary = {}

## Niente qui dentro. Il corpo del test gira al primo frame, non in
## `_initialize()`: un nodo aggiunto a `root` **durante** `_initialize()` non ha
## ancora il `_ready` (la radice non e' ancora dentro la scena), e tutta la parte
## importante di questo progetto - la registrazione sul contratto - sta nel
## `_ready`. Verificarlo in un ordine sbagliato farebbe fallire un test sulle
## cose che funzionano.
func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
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
		# Criterio n. 4 di m2, meta' di -gameplay. Instala l'orda **vera** di
		# -orda, che prende il contratto: da qui in avanti questa sezione parla
		# con l'orda vera e non piu' con il doppio finto delle altre.
		_restart_run(h)
	print("gameplay: test terminato in %d ms" % (Time.get_ticks_msec() - _t0))
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

	# Qui il giocatore e' **vergine**: nessuna sezione e' ancora passata di qui, e
	# quindi nessun potenziamento e' stato applicato. E' l'unico posto in cui la
	# regolazione di partenza si puo' leggere senza dipendere dall'ordine delle
	# sezioni (vedi `_prima` in testa al file).
	_prima = _numeri()
	h.check(float(_prima["damage"]) > 0.0, "il danno di partenza esiste ed e' positivo")
	h.check(float(_prima["knockback"]) > 0.0, "la spinta di partenza esiste ed e' positiva")
	h.positive(float(_prima["move_speed"]), "la velocita' di corsa di partenza esiste")
	h.positive(float(_prima["max_hp"]), "la vita massima di partenza esiste")
	h.near(float(_prima["hp"]), float(_prima["max_hp"]), 0.0001,
		"e alla partenza la vita e' piena")

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

# --- 7. Criterio n. 2 di m2: l'XP fa salire di livello, e non e' finta -----------
#
# Questa sezione e' stata spostata in `tests/test_progression.gd`, che e' il file
# che il piano §3.3 assegna al criterio n. 2. Qui non c'e' piu'.

# --- 8. Criterio n. 3 di m2: un potenziamento cambia un numero di almeno il 2% --
#
# Questa sezione e' stata spostata in `tests/test_upgrades.gd`, che e' il file che
# il piano §3.3 assegna al criterio n. 3, e che la misura **sulla scena vera**.
# Qui non c'e' piu'.
## scrivono, quindi la firma di un potenziamento e' questo dizionario.
func _numeri() -> Dictionary:
	return {
		"damage": float(weapon.damage),
		"fire_interval": float(weapon.fire_interval),
		"projectile_speed": float(weapon.projectile_speed),
		"projectile_life": float(weapon.projectile_life),
		"knockback": float(weapon.knockback),
		"pierce": int(weapon.pierce),
		"acquire_radius": float(weapon.acquire_radius),
		"move_speed": float(player.move_speed),
		"max_hp": float(player.max_hp),
		"hp": float(player.hp),
	}

## Le stesse cose piu' le tre grandezze **derivate** sono in
## `tests/test_upgrades.gd`: qui la firma non serve, perche' la unica firma che
## questo file confronta e' quella della regolazione di partenza.

# --- 9. Criterio n. 4 di m2, meta' di -gameplay: il restart ----------------------
#
# `horde.restart_run()` (di -orda) azzera l'orda e la partita e **non tocca il
# giocatore**: se le vite restano a zero, il passo di simulazione successivo
# rilegge `game_over` e la partita si ferma di nuovo. Questa sezione verifica la
# meta' di -gameplay, e il numero che decide e' uno solo e non e' un numero di
# campi:
#
#     dopo restart_run(), un passo di simulazione NON deve rileggere game_over
#
# Se `reset_run()` non rimettesse in piedi il giocatore, quel numero resta
# `game_over` e qui si vede. E i campi sono la spiegazione, non la prova: un
# restart che azzerasse otto numeri ma lasciasse la partita ferma non e' un
# restart.
#
# ## Il difetto che questa sezione e' nata per trovare
##
## `player.reset_run()` chiamava `weapon.reset()`, che **non esisteva**:
# `reset_run()` lanciava `Invalid call. Nonexistent function 'reset'` a meta' della
# propria esecuzione, e il restart non rimetteva in piedi l'arma. Il sintomo che
# si sarebbe visto e' questo: le vite tornavano a 100 e il livello a 1, ma il
# danno restava quello potenziato della partita precedente. Percio' qui il danno
# viene sporcato **prima** del restart e confrontato **dopo**.
#
# ## E il difetto che questa sezione ha poi trovato al posto suo
#
# Il riferimento era sbagliato, non il codice. `vita0`/`corsa0`/`spinta0` venivano
# letti **all'inizio della sezione**, e a quel punto la sezione 5 aveva gia'
# applicato tre potenziamenti: il test si aspettava la spinta a 23.4 (18.0 x 1.3),
# la vita massima a 120 (100 + 20) e la corsa a 8.47 (7.0 x 1.1 x 1.1). Il codice
# riportava tutto alla **regolazione di partenza** e il test lo chiamava difetto.
#
# Il riferimento giusto e' `_prima`: la regolazione **vergine**, letta in `_setup()`
# prima che una sola sezione la tocchi. Con quello il restart e' confrontato con i
# numeri con cui la partita e' davvero cominciata, che e' l'unica cosa che un
# restart deve ripristinare. E il numero che ne esce dice anche che `KNOCKBACK`
# non e' stato alzato in m2 (piano §1.2, conseguenza n. 2): `spinta0` e' il valore
# di `weapon_base.gd`, e resta quello dopo il restart.

func _restart_run(h) -> void:
	var prog = player.progression
	# L'orda **vera** di -orda prende il contratto: il restart completo la chiama,
	# quindi senza di lei questa sezione misurerebbe solo la meta' di -gameplay, su
	# un'orda che non c'e'. Il passo di simulazione lo guida il test a mano.
	var scr = load(HORDE_SCRIPT)
	if not h.check(scr is Script, "src/sim/horde.gd deve caricare a runtime"):
		return
	var horde_vera = (scr as Script).new()
	horde_vera.name = "OrdaVera"
	horde_vera.set_physics_process(false)
	root.add_child(horde_vera)

	h.check(game.horde == horde_vera,
		"l'orda vera prende il contratto: e' l'orda su cui il gameplay spara")
	h.check(horde_vera.has_method("restart_run"),
		"l'orda espone restart_run(): e' la meta' di -orda del restart, e il restart completo la chiama")
	pool.reset()
	h.check(weapon.has_method("reset"),
		"l'arma espone reset(): e' il metodo che reset_run() chiamava e che non esisteva")
	if not h.check(player.has_method("reset_run") and player.has_method("restart_run"),
		"il giocatore espone reset_run() e restart_run()"):
		return
	h.check(player.has_method("is_dead"), "il giocatore espone is_dead(): e' la domanda sul game over")
	if not h.check(not _prima.is_empty(),
		"la regolazione di partenza e' stata letta in _setup(), prima che una sezione la sporchi"):
		return

	# I numeri di partenza, presi dall'**istanza viva vergine** (`_prima`) e non da
	# una copia dentro questo file: una copia nel test si romperebbe al primo
	# ritocco della regolazione e fallirebbe senza che nessuno l'abbia toccata.
	var vita0: float = float(_prima["max_hp"])
	var danno0: float = float(_prima["damage"])
	var intervallo0: float = float(_prima["fire_interval"])
	var spinta0: float = float(_prima["knockback"])
	var perforante0: int = int(_prima["pierce"])
	var vita_proj0: float = float(_prima["projectile_life"])
	var velocita0: float = float(_prima["projectile_speed"])
	var gittata0: float = float(_prima["acquire_radius"])
	var corsa0: float = float(_prima["move_speed"])

	var nodi0 := _conta_nodi(root)
	var hordi0 := _conta_nomi(root, "OrdaVera")
	h.eq(hordi0, 1, "l'orda vera e' stata installata una volta sola, prima del ciclo")

	# Tre restart di fila, come i tre di -orda: un restart che funziona una volta
	# puo' non funzionare alla seconda, perche' il secondo trova lo stato che il
	# primo ha lasciato.
	for giro in 3:
		_sporca(h, giro)
		h.check(player.is_dead(), "restart %d: prima del restart il giocatore e' a zero vite" % (giro + 1))
		h.check(horde_vera.is_game_over(),
			"restart %d: e la partita e' davvero finita, non solo il giocatore" % (giro + 1))
		h.check(float(weapon.damage) != danno0,
			"restart %d: e il danno e' davvero sporcato dal potenziamento (%.2f contro %.2f)"
			% [giro + 1, weapon.damage, danno0])

		player.restart_run()

		h.near(player.hp, vita0, 0.0001, "restart %d: le vite tornano a %s" % [giro + 1, vita0])
		h.near(player.max_hp, vita0, 0.0001, "restart %d: e la vita massima torna a %s" % [giro + 1, vita0])
		h.check(not player.is_dead(), "restart %d: il giocatore e' di nuovo in piedi" % (giro + 1))
		h.vec_near(player.position, Vector3.ZERO, 0.0001, "restart %d: e al centro dell'arena" % (giro + 1))
		h.vec_near(player.velocity, Vector3.ZERO, 0.0001, "restart %d: fermo, non con la velocita' del game over" % (giro + 1))
		h.near(float(player.move_speed), corsa0, 0.0001, "restart %d: la velocita' di corsa torna a %.2f" % [giro + 1, corsa0])
		h.eq(int(prog.level), 1, "restart %d: la progressione torna al livello 1" % (giro + 1))
		h.near(prog.xp, 0.0, 0.0001, "restart %d: e a zero XP in barra" % (giro + 1))
		h.near(prog.xp_earned, 0.0, 0.0001, "restart %d: e a zero XP guadagnati" % (giro + 1))
		h.eq(int(prog.kills), 0, "restart %d: e a zero uccisioni" % (giro + 1))
		h.eq(int(prog.pending()), 0, "restart %d: e senza offerte rimaste appese" % (giro + 1))

		# L'arma. E' il pezzo che mancava, ed e' quello che il difetto nascondeva.
		h.near(float(weapon.damage), danno0, 0.0001,
			"restart %d: il danno torna a %.2f e NON resta quello potenziato" % [giro + 1, danno0])
		h.near(float(weapon.fire_interval), intervallo0, 0.0001,
			"restart %d: l'intervallo fra i colpi torna a %.3f" % [giro + 1, intervallo0])
		h.near(float(weapon.knockback), spinta0, 0.0001,
			"restart %d: la spinta torna a %.1f m/s" % [giro + 1, spinta0])
		h.eq(int(weapon.pierce), perforante0, "restart %d: e la perforante torna a %d" % [giro + 1, perforante0])
		h.near(float(weapon.projectile_life), vita_proj0, 0.0001,
			"restart %d: la vita del proiettile torna a %.2f s" % [giro + 1, vita_proj0])
		h.near(float(weapon.projectile_speed), velocita0, 0.0001,
			"restart %d: e la sua velocita' a %.1f m/s" % [giro + 1, velocita0])
		h.near(float(weapon.acquire_radius), gittata0, 0.0001,
			"restart %d: e la gittata di mira torna a %.1f m" % [giro + 1, gittata0])
		h.near(float(weapon.cooldown), 0.0, 0.0001,
			"restart %d: l'arma e' pronta a sparare al primo passo" % (giro + 1))
		h.eq(int(weapon.shots), 0, "restart %d: il contatore dei colpi riparte" % (giro + 1))
		h.eq(int(pool.active_count()), 0, "restart %d: nessun proiettile resta in volo" % (giro + 1))
		h.eq(int(pool.ever_created()), int(pool.capacity()),
			"restart %d: i %d proiettili sono gli stessi di prima, nessuno creato" % [giro + 1, pool.capacity()])

		# La meta' di -orda, verificata perche' il restart completo la chiama.
		h.eq(int(horde_vera.wave), 1, "restart %d: si torna all'onda 1" % (giro + 1))
		h.eq(horde_vera.run_state(), "playing", "restart %d: e la partita riparte" % (giro + 1))
		h.check(int(horde_vera.count) > 0,
			"restart %d: horde.count azzerato e RIPOPOLATO (%d)" % [giro + 1, horde_vera.count])

		# ## IL NUMERO CHE DECIDE
		#
		# Un passo di simulazione, e la partita non deve rientrare in game_over.
		# E' qui che la meta' di -gameplay si vede: se le vite fossero rimaste a
		# zero, `_poll_run` le rileggerebbe e la partita si fermerebbe di nuovo.
		horde_vera.step(DT)
		h.check(not horde_vera.is_game_over(),
			"restart %d: dopo il restart un passo di simulazione NON rilegge game_over (stato '%s')"
			% [giro + 1, horde_vera.run_state()])
		h.eq(horde_vera.run_state(), "playing", "restart %d: la partita riparte sul serio" % (giro + 1))
		var ferma: PackedVector3Array = horde_vera.transforms.duplicate()
		horde_vera.step(DT)
		h.check(horde_vera.transforms != ferma,
			"restart %d: e il mondo si muove di nuovo: non era fermo per sempre" % (giro + 1))

		# Nessun nodo duplicato. Il totale puo' restare uguale con due orde e una
		# orda morta, quindi si conta anche quante orde ci sono per nome.
		h.eq(_conta_nodi(root), nodi0, "restart %d: nessun nodo creato o liberato" % (giro + 1))
		h.eq(_conta_nomi(root, "OrdaVera"), hordi0,
			"restart %d: una sola orda sotto root, non due" % (giro + 1))
		h.check(game.horde == horde_vera, "restart %d: e il contratto punta ancora alla stessa orda" % (giro + 1))

		# E l'arma spara **subito**, che e' la prima cosa che si sente.
		#
		# Il numero che decide e' `weapon.shots`, non `pool.active_count()`: un
		# colpo partito contro un nemico che sta a un metro dalla canna arriva e
		# muore **nello stesso frame** (percorso 0.43 m, raggio di contatto
		# 0.16 + 0.55), e a quel punto nel pool non c'e' piu' nessuno. Dire "il
		# primo colpo non e' partito" guardando il pool sarebbe misurare la
		# distanza dal nemice piu' vicino, non la cadenza dell'arma.
		var colpi_prima: int = int(weapon.shots)
		player.step(DT, Vector3.ZERO)
		h.eq(int(weapon.shots), colpi_prima + 1,
			"restart %d: il primo colpo parte al primo passo, senza aspettare l'intervallo" % (giro + 1))

	# `reset_run()` da solo: rimette in piedi il giocatore e **non** tocca l'onda.
	# E' la separazione delle due meta' dichiarata in testa al file, misurata.
	var wave_prima := int(horde_vera.wave)
	var uccise_prima := int(horde_vera.kills)
	player.reset_run()
	h.near(player.hp, vita0, 0.0001, "reset_run() da solo rimette in piedi il giocatore")
	h.eq(int(prog.level), 1, "e azzera la progressione")
	h.eq(int(horde_vera.wave), wave_prima, "ma non tocca l'onda: e' la meta' di -orda")
	h.eq(int(horde_vera.kills), uccise_prima, "e non tocca le uccisioni contate dall'orda")

	# Il tasto che rimette in piedi la partita: una volta sola per pressione. Un
	# `Input.is_key_pressed` tenuto premuto chiamerebbe il restart a ogni frame e
	# la partita ripartirebbe ogni 16 ms.
	_tasto_restart(h)
	print("m2 restart: 3 restart completi + reset_run() da solo, %d nodi prima e dopo, "
		% nodi0 + "HP %.1f -> %.1f, danno %.2f -> %.2f"
		% [vita0, player.hp, danno0, float(weapon.damage)])

## Sporca tutto quello che un restart deve ripulire: vite a zero, progressione
## avanti di quattro livelli, e tre potenziamenti applicati. Il danno viene
## **rimosso** subito dopo, perche' con tutti i nemici dell'orda vera vicino un
## colpo riporterebbe il danno al valore di codice e il difetto del `reset()`
## mancante sparirebbe dal test.
func _sporca(h, giro: int) -> void:
	var prog = player.progression
	player.hp = 0.0
	player.invuln = 0.0
	player.velocity = Vector3(3.0, 0.0, -4.0)
	player.position = Vector3(5.0, 0.0, 5.0)
	prog.reset()
	prog.add_xp(prog.xp_to_next() * 4.0)
	for id in ["damage", "fire_rate", "move_speed"]:
		prog.apply(id)
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	# Qualche passo di gioco: il cooldown e il contatore dei colpi non devono
	# essere gia' a zero, altrimenti il restart non avrebbe nulla da rimettere a
	# posto su quei due campi.
	_passo_di_gioco()
	h.check(float(weapon.damage) > 0.0,
		"restart %d: la regolazione e' sporcata prima di misurare" % (giro + 1))
	h.check(float(weapon.shots) > 0,
		"restart %d: e sono partiti colpi, cosi' il contatore da azzerare esiste" % (giro + 1))

## Un passo di gioco sul giocatore e sull'orda **vera**: a questo punto della sezione
## e' quella sul contratto, non il finto.
func _passo_di_gioco() -> void:
	player.step(DT, Vector3.ZERO)
	var hv = game.horde
	if hv != null:
		hv.step(DT)

## Il tasto del restart. Chiamato direttamente perche' in un `--script` non c'e'
## una pipeline di input che il test possa pilotare, e quello che si prova qui e'
## la **decisione** (quando il restart parte e quando non parte), non il
## trasporto dell'evento: chi lo trasporta e' il gioco.
func _tasto_restart(h) -> void:
	var player_legge_tasti: bool = player.read_keys
	player.read_keys = true

	# Il tasto non fa niente con il giocatore in piedi.
	var vite_prima: float = player.hp
	player._unhandled_input(_tasto(KEY_ENTER, true, false))
	h.near(player.hp, vite_prima, 0.0001, "il tasto del restart non fa niente se il giocatore e' vivo")

	# Con le vite a zero lo rimette in piedi, una volta sola.
	player.hp = 0.0
	var horde_vera = game.horde
	if horde_vera != null:
		horde_vera.step(DT)
	h.check(player.is_dead(), "con le vite a zero il giocatore e' morto")
	if horde_vera != null:
		h.check(horde_vera.is_game_over(), "e la partita e' finita")
	player._unhandled_input(_tasto(KEY_ENTER, true, false))
	h.check(not player.is_dead(), "il tasto del restart rimette in piedi il giocatore")
	if horde_vera != null:
		h.check(not horde_vera.is_game_over(), "e la partita riparte: il tasto chiama restart_run(), non reset_run()")

	# Il tasto tenuto premuto (`echo`) non deve rilanciare il restart a ogni
	# frame: si conta che una seconda pressione con echo non tocchi niente.
	var spinta := int(horde_vera.kills) if horde_vera != null else 0
	player._unhandled_input(_tasto(KEY_R, true, true))
	h.near(player.hp, player.max_hp, 0.0001,
		"una pressione con echo non e' una nuova pressione: le vite non cambiano")
	if horde_vera != null:
		h.eq(int(horde_vera.kills), spinta, "e l'orda non viene riarruolata un'altra volta")

	# E il tasto rilasciato non fa niente.
	player.hp = 0.0
	player._unhandled_input(_tasto(KEY_R, false, false))
	h.check(player.is_dead(), "il rilascio del tasto non e' una pressione: non rimette in piedi nessuno")

	# Un tasto che non e' fra quelli del restart non fa niente.
	player.hp = 0.0
	player._unhandled_input(_tasto(KEY_Q, true, false))
	h.check(player.is_dead(), "un tasto che non e' fra quelli del restart non avvia niente")

	player.read_keys = player_legge_tasti

## Un `InputEventKey` costruito a mano.
func _tasto(code: int, premuto: bool, ripetuto: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = premuto
	ev.echo = ripetuto
	return ev

# --- Interno -------------------------------------------------------------------

## Parti da zero: niente nemici, niente proiettili, player fermo al centro,
## e progressioni azzerate con il **suo** `reset()`, che e' la stessa strada che
## usa `player.reset_run()`: un test che azzerasse i campi a mano misurerebbe una
## progressione che il restart non usa.
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
		prog.reset()

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
	return _script_const(prog, "UPGRADE_IDS")

## Una costante di uno script, letta a runtime con `get_script_constant_map()`:
## e' l'unico modo di arrivare alla costante di uno script senza metterla in
## `const preload` qui dentro (vedi la nota sul caricamento in testa al file).
func _script_const(obj, nome: String) -> Variant:
	var consts: Variant = obj.get_script().get_script_constant_map()
	if not (consts is Dictionary):
		return null
	return (consts as Dictionary).get(nome, null)

## I nodi dell'albero contati davvero, ricorsivamente: dentro un `--script`
## `get_node_count()` vale 0, perche' il ciclo di frame non e' ancora partito, e un
## test che ci si appoggiasse passerebbe sempre.
func _conta_nodi(nodo: Node) -> int:
	var totale := 1
	for c in nodo.get_children():
		totale += _conta_nodi(c)
	return totale

## Quanti nodi chiamati `wanted` ci sono sotto `nodo`, ricorsivamente. Serve a
## contare i **duplicati**, che un totale non vede: due orde e un'orda morta fanno
## lo stesso numero di nodi.
func _conta_nomi(nodo: Node, wanted: String) -> int:
	var totale := 1 if nodo.name == wanted else 0
	for c in nodo.get_children():
		totale += _conta_nomi(c, wanted)
	return totale

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
