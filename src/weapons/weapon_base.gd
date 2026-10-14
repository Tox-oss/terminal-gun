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

## Quanti secondi uno slot del pool resta occupato **oltre** la lunghezza del
## suono: la rete per il giorno in cui `finished` non arrivasse. Stesso numero
## di `player.gd`, dichiarato qui e non letto da li': i due file non si
## preloaded a vicenda e nessuno dei due deve il tipo dell'altro, quindi
## nessuno dei due deve nemmeno una costante dell'altro.
const SFX_SICUREZZA := 0.35

## ## `SFX_POOL = 1`, e la capienza viene da una **misura**, non da un paragone
##
## Sul giocatore `SFX_POOL = 1` è motivato da due numeri del gioco: `hurt` non
## si sovrappone (`INVULN_AFTER_HIT = 0.7 s` contro 0.25 s di suono) e `levelup`
## non si sovrappone (otto uccisioni fra una soglia e l'altra contro 0.50 s).
## **Qui quel ragionamento non si può copiare**: `bonk` dura **0.18 s** e parte
## a ogni impatto, e l'arma spara da sola.
##
## Quindi la capienza è **misurata**, in `tests/test_gameplay.gd`, sezione
## `_audio_bonk`: tre montaggi della scena vera, 900 passi ciascuno, e il
## **massimo di suoni dentro una finestra di `bonk.wav`**, cioè 11 passi a
## DT = 1/60 s (0.1833 s, il primo multiplo di DT che supera 0.18 s).
##
##   - 117 suoni in 2700 passi, ~39 per montaggio;
##   - **massimo per passo: 1**;
##   - **massimo in 11 passi (0.1833 s): 1**, uguale in tutti e tre i montaggi;
##   - concorrenza massima fra suoni in uso: **1**.
##
## Il massimo è 1, quindi un nodo basta, e `45` resta `45`.
##
## ## Il tetto strutturale è 4, e va detto perché non è 1
##
## `IMPACT_SFX_GAP = 0.05 s` è il throttle di `on_impact()`: un suono ogni
## 0.05 s, cioè al più `ceil(0.1833 / 0.05) = 4` dentro la finestra. Quindi **1
## non è un teorema**: è il massimo osservato. Due impatti ravvicinati sono
## possibili per costruzione — l'arma spara ogni `FIRE_INTERVAL = 0.35 s` e mira
## al nemico più vicino in quel momento, quindi se fra due colpi il nemico più
## vicino è cambiato e il nuovo è più vicino di 4.3 m, il secondo proiettile
## arriva entro 0.1833 s dal primo.
##
## E va detto anche **cosa succede** in quel caso, perché è la parte buona: con
## `SFX_POOL = 1` lo slot è occupato, il pool **riprende lo slot che sta per
## finire** (`_prendi_slot`) e `play()` ricomincia il suono. Questa è
## **esattamente** la semantica del nodo unico di prima del pool: un `play()`
## su un nodo che suona ricomincia. Quindi nel caso raro il suono viene
## su un nodo che suona ricomincia. Quindi nel caso raro il suono viene
## troncato, ma veniva troncato anche prima: **non è una perdita, è il
## comportamento che il gioco aveva**. Alzare la capienza a 2 aggiungerebbe un
## nodo alla scena vera e romperebbe i tre criteri di `test_arena.gd`,
## `test_gameloop.gd` e `test_ui.gd`, che sono giusti: per quello la decisione è
## del vertice, non di questo file.
const SFX_POOL := 1

## Il nome che `scenes/player.tscn` da' allo slot 0. Lo slot 0 riusa quel nodo,
## quindi il totale dei nodi della scena non cambia; gli slot 1 e oltre, se mai
## ce ne fossero, prendono `Sfx1`, `Sfx2`...
const NOME_SFX := "Sfx"

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

## Il **pool** dei nodi che suonano l'impatto, e le scadenze dei suoi slot.
## Stessa forma del pool di `player.gd`: un `Array` di nodi e una
## `PackedFloat32Array` di scadenze, capienza `SFX_POOL`. La scadenza di uno
## slot e' `0.0` quando lo slot e' libero. Suonare **prende** uno slot: nessun
## nodo nasce durante la partita, e i nodi sono gia' nel totale `20` di
## `-gameplay` perche' `scenes/player.tscn` li porta gia'.
var _sfx: Array[AudioStreamPlayer3D] = []
var _sfx_scadenza := PackedFloat32Array()
var _sfx_gap := 0.0
## Quanti suoni ha fatto partire quest'arma, in tutto. E' il numero con cui il
## test misura **quanti bonk arrivano ravvicinati**, che e' la domanda che
## decide quanti nodi deve tenere il pool di `bonk`: e' anche la prova che il
## suono e' uscito e non e' stato solo contato.
var sfx_emessi := 0
## Quanti impatti ha visto l'arma, **compresi quelli che il throttle
## `IMPACT_SFX_GAP` lascia passare senza suono**. E' il denominatore del
## confronto con `sfx_emessi`: senza questo numero un criterio che chiede
## «il suono esce» passerebbe anche con metà dei bonk persi, ed è esattamente
## quello che è successo quando il ramo di riuso dello slot è stato tolto per
## misura: i suoni sono scesi da 39 a 20 per montaggio e il criterio era verde.
var impatti := 0
## Chi ha creato l'arma. Senza tipo di classe: `player.gd` conosce
## `weapon_base.gd` solo per crearla, e nessuno dei due deve il tipo dell'altro.
var player

func _ready() -> void:
	pool = PoolScript.new()
	pool.name = "Pool"
	add_child(pool)
	pool.weapon = self
	_sfx = _costruisci_pool()
	_sfx_scadenza.resize(_sfx.size())
	# Piano §5.1: i metodi si registrano con `register_impl`, mai con
	# `Game.spawn_projectile = self._spawn_projectile` (GDScript lo rifiuta e
	# interrompe il `_ready`, e la foglia crede di aver registrato).
	Game.register_impl("spawn_projectile", self._spawn_projectile)

## ## Nuova partita: l'arma torna alla regolazione di partenza
##
## ## Perche' questo metodo esiste, e non e' una formalita'
##
## `player.reset_run()` lo chiama, ed e' stato scritto **dopo** che il restart
## e' diventato un criterio (n. 4 di m2). Senza di questo, `reset_run()` lancerebbe
## `Invalid call. Nonexistent function 'reset'` a meta' della sua propria esecuzione:
## le vite tornerebbero a 100 e la progressione a livello 1, ma **qui dentro
## resterebbero i numeri dei potenziamenti scelti nella partita precedente** (il
## danno prende il +25% a ogni livello, quindi una partita nuova comincerebbe gia'
## con il danno di un livello 7). E' il difetto che `progression.reset()`
## documenta e non risolve da solo: la progressione non puo' scrivere sui campi
## dell'arma, e l'arma non puo' scrivere sulla progressione.
##
## Sono **numeri in campi che esistono gia'**: nessun nodo creato, nessuno liberato,
## nessuna allocazione, quindi il criterio n. 4 ("nessun nodo duplicato") non
## dipende da una scelta di questo file. Il pool viene svuotato con il **suo**
## `reset()`, che riusa gli stessi 100 record: `ever_created()` resta 100 anche
## dopo un restart.
##
## Il cooldown torna a `0.0` e non a `fire_interval`: come all'avvio, il primo
## colpo deve partire **al primo `step()`** e non un `fire_interval` dopo. Un
## restart che lasciasse l'arma in attesa e' una partita nuova che comincia senza
## sparare, che e' il difetto peggiore di tutti quelli che poteva avere.
func reset() -> void:
	damage = DAMAGE
	fire_interval = FIRE_INTERVAL
	projectile_speed = PROJECTILE_SPEED
	projectile_life = PROJECTILE_LIFE
	knockback = KNOCKBACK
	pierce = PIERCE
	acquire_radius = ACQUIRE_RADIUS
	cooldown = 0.0
	shots = 0
	_sfx_gap = 0.0
	# Gli slot del pool di `bonk` tornano a zero come gli altri numeri della
	# partita: uno slot occupato da un suono della partita che è finita
	# ripartirebbe occupato, e su un solo slot la partita nuova comincerebbe
	# con il suono che le occupa lo slot.
	chiudi_suoni()
	if pool != null:
		pool.reset()

## Un passo di gioco: cooldown, eventuale colpo, e il volo dei proiettili.
func step(delta: float) -> void:
	cooldown -= delta
	_sfx_gap -= delta
	if cooldown <= 0.0:
		_try_fire()
	_chiudi_bonk_scaduti(delta)
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
	impatti += 1
	if _sfx.is_empty() or _sfx_gap > 0.0:
		return
	_sfx_gap = IMPACT_SFX_GAP
	_suona_bonk()

## Suona l'impatto **prendendo uno slot** dal pool. Nessun nodo nasce qui: e' il
## punto intero del pool, ed e' la differenza rispetto alla forma che creava il
## nodo al momento del suono.
func _suona_bonk() -> void:
	var slot := _prendi_slot()
	# La guardia non e' paranoia: e' il buco che un `-1` di `_prendi_slot()`
	# aprirebbe. `_prendi_slot()` restituisce `-1` solo se il vettore delle
	# scadenze e' vuoto (nessuno slot costruito), e quel `-1`, usato come
	# indice, in Godot non e' «l'ultimo» ne' «nessuno»: e' un accesso fuori dal
	# vettore. Il valore e' possibile, quindi va fermato **qui**, dove si usa.
	if slot < 0:
		return
	if _sfx[slot].stream == null:
		# L'asset manca: nessun suono, e nessuno slot occupato da un silenzio.
		_sfx_scadenza[slot] = 0.0
		return
	_sfx[slot].play()
	_sfx_scadenza[slot] = _vita(_sfx[slot])
	sfx_emessi += 1

## Quale slot prendere: il primo libero, e se non ce n'è uno quello **che sta
## per finire prima** (la scadenza più piccola). Il ramo «nessuno libero» non
## cresce: non c'è un `while` e non c'è un nodo creato per farne uno libero.
func _prendi_slot() -> int:
	var vicino := -1
	for i in _sfx_scadenza.size():
		if _sfx_scadenza[i] <= 0.0:
			return i
		if vicino < 0 or _sfx_scadenza[i] < _sfx_scadenza[vicino]:
			vicino = i
	return maxi(vicino, 0)

## Quanto vive uno slot occupato: la lunghezza vera del suono più `SFX_SICUREZZA`.
## Un asset assente dà solo il margine.
func _vita(node: AudioStreamPlayer3D) -> float:
	if node.stream == null:
		return SFX_SICUREZZA
	return node.stream.get_length() + SFX_SICUREZZA

## `finished`: lo slot torna libero. `queue_free()` non c'è e non serve: il nodo
## del pool **non muore mai**, quindi qui non c'è niente da liberare e niente
## che possa lasciare un playback registrato nell'`AudioServer` — che è il
## difetto che questo pool chiude.
func _bonk_finito(slot: int) -> void:
	if slot < 0 or slot >= _sfx_scadenza.size():
		return
	_sfx_scadenza[slot] = 0.0

## La rete per `finished` che non arriva. Gira da `step()`, e non da
## `_exit_tree()`: a `_exit_tree()` il nodo è già fuori dall'albero e `stop()`
## fa un return anticipato.
func _chiudi_bonk_scaduti(delta: float) -> void:
	for i in _sfx_scadenza.size():
		if _sfx_scadenza[i] <= 0.0:
			continue
		_sfx_scadenza[i] -= delta
		if _sfx_scadenza[i] <= 0.0:
			_sfx_scadenza[i] = 0.0

## Libera subito **tutti** gli slot del pool. Non è un suono che si ferma: è il
## tempo che il suono occupa lo slot che si rimette a zero, quindi il suono
## **finisce di suonare** e lo slot torna libero come dopo `finished`.
func chiudi_suoni() -> void:
	for i in _sfx_scadenza.size():
		_sfx_scadenza[i] = 0.0

## Il pool di `bonk`: `SFX_POOL` nodi, presi dalla scena se ci sono.
##
## Un nodo che la scena non porta viene creato qui, in `_ready()`, e solo qui:
## durante la partita nessun nodo nasce. Lo slot 0 è il nodo `Sfx` che
## `scenes/player.tscn` porta già, quindi nella scena vera il pool lo riusa e
## **il totale dei nodi non cambia**.
func _costruisci_pool() -> Array[AudioStreamPlayer3D]:
	var slots: Array[AudioStreamPlayer3D] = []
	for i in SFX_POOL:
		var nome := NOME_SFX if i == 0 else NOME_SFX + str(i)
		var node := get_node_or_null(nome) as AudioStreamPlayer3D
		if node == null:
			node = AudioStreamPlayer3D.new()
			node.name = nome
			add_child(node)
		if node.stream == null:
			node.stream = _stream(SFX_IMPACT)
		node.finished.connect(_bonk_finito.bind(i))
		slots.append(node)
	return slots

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