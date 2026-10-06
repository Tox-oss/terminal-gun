extends Node3D
## L'arma: spara **da sola**, verso il nemico più vicino. -gameplay.
##
## Il giocatore non preme il grilletto, in un bullet heaven non c'è un pulsante:
## il divertimento è correre per restare vivo mentre l'arma lavora. Quindi qui
## non ci sono input di sparo, solo un cooldown.
##
## La regola di ritmo che conta: **il colpo parte nello stesso frame in cui
## l'arma è pronta**. Il cooldown parte a `0.0` e viene contato a mano, non con
## un `Timer` e non con `await`: un `Timer` aspetta il frame di fisica
## successivo, e un frame di ritardo sul primo colpo è un frame di ritardo su
## tutti. Per la stessa ragione `step()` è pubblico e si può chiamare a mano:
## è così che il test guida il gioco, frame per frame, senza dipendere dalla
## velocità con cui gira il `SceneTree`.
##
## Nessuna dipendenza circolare: l'arma conosce il giocatore solo attraverso
## `Game.player_position()` (il contratto), e conosce il pool attraverso
## `preload`. Del giocatore non sa nemmeno il tipo.

const PoolScript := preload("res://src/weapons/projectile_pool.gd")

## Il suono dell'impatto. Se il file non c'è nessun rumore e nessun errore:
## un test non deve fallire perché manca un asset.
const SFX_IMPACT := "res://assets/sfx/bonk.wav"

# --- Regolazione del gioco. Sono numeri, non segreti. --------------------------

## Secondi fra due colpi. 0.35 = quasi 3 colpi al secondo.
const FIRE_INTERVAL := 0.35
## Danno per proiettile.
const DAMAGE := 10.0
## Velocità del proiettile, in m/s. A 60 Hz sono 0.43 m per frame: il test di
## contatto è sul segmento del frame, altrimenti il proiettile "salta" i nemici.
const PROJECTILE_SPEED := 26.0
## Vita del proiettile, in secondi: a 26 m/sCopre 36 m, tutta l'arena.
const PROJECTILE_LIFE := 1.4
## Spinta data al nemico colpito, **in m/s**, non un vettore normalizzato.
## `Game.damage_enemy` deve sommarla alla velocita' del nemico e non
## normalizzarla.
##
## Il numero e' tarato sul **criterio n. 4** ("knockback >= 0.3 unita' entro 5
## frame"), misurato come delta di posizione e non come modulo dell'impulso: a
## 14 m/s il nemico che insegue a 3 m/s si sposta di 0.31 unita' in 5 frame,
## cioe' di misura. Il modulo dell'impulso non c'entra niente (e' uno scatto di
## velocita', non uno spostamento), ma la sensazione che il numero produce sì:
## 18 dà al colpo la spinta di un calcio e non di un dito, e al nemico resta
## qualche decimo di secondo di deriva prima che l'inseguimento lo riprenda.
const KNOCKBACK := 18.0
## Quanti nemici extra attraversa un proiettile prima di sparire. 0 = un colpo
## e via, come in un bullet heaven.
const PIERCE := 0
## Fin dove l'arma si mette in cerca di un bersaglio, in metri dal giocatore.
const ACQUIRE_RADIUS := 26.0
## Altezza della canna sopra il giocatore: il proiettile esce da qui e non dal
## centro del modello, altrimenti si vede uscire dai piedi.
const MUZZLE_HEIGHT := 0.9
## Due impatti nello stesso frame non suonano due volte: 0.05 s di attesa tra
## un "bonk" e l'altro, il tempo di un'orecchia.
const IMPACT_SFX_GAP := 0.05

# --- Stato. Tutto qui è un campo perché sono cose che i potenziamenti cambiano.
var damage := DAMAGE
var fire_interval := FIRE_INTERVAL
var projectile_speed := PROJECTILE_SPEED
var projectile_life := PROJECTILE_LIFE
var knockback := KNOCKBACK
var pierce := PIERCE
var acquire_radius := ACQUIRE_RADIUS
## Countdown del proiettile successivo. Parte a `0.0`: il primo colpo esce al
## primo `step()`.
var cooldown := 0.0
## Quanti colpi sono partiti dal caricamento. Il test ci fa caso.
var shots := 0
## Il pool: 100 proiettili, nessun nodo per proiettile. Senza tipo di classe,
## così questo file non deve niente a `projectile_pool.gd` e viceversa.
var pool

var _sfx: AudioStreamPlayer3D
var _sfx_gap := 0.0
## Chi ha creato l'arma. Senza tipo di classe: `player.gd` conosce
## `weapon_base.gd` solo per crearla, e nessuno dei due deve il tipo dell'altro.
var player

func _ready() -> void:
	pool = PoolScript.new()
	pool.name = "Pool"
	add_child(pool)
	pool.weapon = self
	_sfx = get_node_or_null("Sfx") as AudioStreamPlayer3D
	if _sfx == null:
		# La scena può non portare il nodo (la porta su un'arma sola): qui si
		# crea, una volta sola all'avvio, e l'impatto suona comunque.
		_sfx = AudioStreamPlayer3D.new()
		_sfx.name = "Sfx"
		add_child(_sfx)
		_sfx.stream = _stream(SFX_IMPACT)
	elif _sfx.stream == null:
		_sfx.stream = _stream(SFX_IMPACT)
	# Piano §5.1: i metodi si registrano con `register_impl`, mai con
	# `Game.spawn_projectile = self._spawn_projectile` (GDScript lo rifiuta e
	# interrompe il `_ready`, e la foglia crede di aver registrato).
	Game.register_impl("spawn_projectile", self._spawn_projectile)

## Un passo di gioco: cooldown, eventuale colpo, e il volo dei proiettili.
func step(delta: float) -> void:
	cooldown -= delta
	_sfx_gap -= delta
	if cooldown <= 0.0:
		_try_fire()
	if pool != null:
		pool.step(delta)

## La spinta auto: mira al nemico più vicino entro `acquire_radius`. Se non
## c'è nessuno nel raggio non spara: meglio una pausa che spazzare il vuoto.
## Il bersaglio si chiede al contratto con `nearest_enemy(from, radius) -> int`
## (piano §5.2: un indice, non un nodo) e l'indice e' lo stesso che
## `damage_enemy` accetta.
func _try_fire() -> void:
	if pool == null:
		return
	var from: Vector3 = Game.player_position()
	var target := Game.nearest_enemy(from, acquire_radius)
	# -1 e' "nessuno", e non e' un indice: da non passare mai a `damage_enemy`.
	if target < 0:
		return
	var origin := muzzle_position()
	var to_target: Vector3 = pool.enemy_position(target) - origin
	var dist := to_target.length()
	if dist <= 0.001:
		return
	# Si passa per il contratto e non per una chiamata diretta al pool: il
	# percorso che il gioco usa è lo stesso che il test e le altre foglie
	# verificano con `Game.spawn_projectile`.
	if Game.spawn_projectile(origin, to_target / dist, projectile_speed):
		shots += 1
	cooldown = fire_interval

## Implementazione di `Game.spawn_projectile` (piano §5.1, forma lunga).
## Restituisce `bool` dal §5.2: `true` se il pool ha ceduto uno slot. Non
## restituisce il record, perché nessuno nel progetto ha bisogno di un handle:
## tutto quello che serve del proiettile sta gia' nel pool.
func _spawn_projectile(pos: Vector3, dir: Vector3, speed: float) -> bool:
	if pool == null:
		return false
	return pool.acquire(pos, dir, speed) != null

## Da dove esce il colpo.
func muzzle_position() -> Vector3:
	return global_position + Vector3(0.0, MUZZLE_HEIGHT, 0.0)

## Chiamato dal pool su ogni impatto: qui è il momento del "bonk".
func on_impact(_where: Vector3) -> void:
	if _sfx == null or _sfx_gap > 0.0:
		return
	_sfx_gap = IMPACT_SFX_GAP
	_sfx.play()

## Chiamato dal pool quando `Game.damage_enemy` ha risposto che il nemico è
## morto. È l'unica strada dell'XP: nessuna euristica sul conteggio dell'orda.
func on_kill() -> void:
	if player != null:
		player.on_enemy_killed()

static func _stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var res = load(path)
	return res as AudioStream

## NOTA PER IL VERTICE (piano §5.3): l'identificatore nudo `Game` qui funziona,
## e il sospetto "non risolve sotto `--script`" va riformulato. Non è il
## **contesto** a decidere (nessuno dei miei usi è in `static func`, `const`,
## annotazione di tipo o `class_name`): è **quando** lo script viene compilato.
## Un `const preload` in testa al test risolve i suoi script a tempo di
## compilazione, PRIMA che `Main` aggiunga gli autoload al nome globale, e a quel
## punto l'identificatore non è ancora registrato. Caricando gli stessi script a
## runtime (`load()` dentro `_process`, dopo il primo frame) l'identificatore c'è
## e i miei file compilano senza nessun `_contract()`.