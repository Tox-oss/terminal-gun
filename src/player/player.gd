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
const PIPELINE_SCRIPT := preload("res://src/player/weapon_pipeline.gd")

## Suoni: se il file non c'è, nessun rumore e nessun errore.
const SFX_HURT := "res://assets/sfx/hurt.wav"
const SFX_LEVELUP := "res://assets/sfx/levelup.wav"

## ## Il suono di questo file è un **usa e getta**, e `SFX_SICUREZZA` è il numero
## che lo governa
##
## Non è un nodo che vive per sempre: il nodo nasce quando il suono parte e
## viene liberato quando il suono è finito. Il motivo è **misurato**: l'uscita
## del motore scriveva `2 ObjectDB instances were leaked at exit` e
## `1 resources still in use at exit`, e `--verbose` diceva che i due oggetti
## sono un `AudioStreamPlaybackWAV` e il suo `AudioStreamWAV` di `levelup.wav`.
## Un `AudioStreamPlayer3D` che ha suonato e non è mai stato liberato tiene il
## playback registrato nell'`AudioServer`, e alla fine della partita il playback
## è ancora li dentro.
##
## Cosa **non** funziona, misurato, e non viene ritentata qui:
##   - `stop()` sul nodo ancora in albero: stesse due righe del motore;
##   - `stop()` dentro `_exit_tree()`: a quel punto il nodo è **gia' fuori
##     dall'albero** e `stop()` fa un return anticipato su `!is_inside_tree()`;
##   - `stream = null` dentro `_exit_tree()`: provato, non chiude.
## Il modo che chiude è **liberare il nodo mentre è ancora in albero**: quando
## il suono è finito (`finished`) o quando il suo tempo è passato (`step()`).
##
## `SFX_SICUREZZA` è quanto tempo il nodo vive **oltre** la lunghezza del
## suono. Non è un tempo di suono: è la rete per il giorno in cui `finished`
## non arrivasse. In `--headless` `finished` **arriva** (misurato: 75-82 frame
## di processo, ~550 ms, per `levelup.wav` che dura 0.500 s), quindi questa rete
## non scatta li'. Esiste perché `finished` non è un contratto che questo file
## possa dare per garantito, e un `await finished` che non si risolve
## bloccherebbe la partita per sempre.
const SFX_SICUREZZA := 0.35
## I nomi dei nodi che suonano. Sono i nomi con cui `scenes/player.tscn` li
## porta gia': il pool li **riusa**, non li duplica, quindi nella scena vera
## questi tre nomi ci sono una volta sola e il totale dei nodi resta quello di
## prima. Sono qui e non a lettera spagliata nel codice perche' un nome che
## cambia e una scena che non lo cambia piu' si vedono solo al primo criterio
## che li confronta.
const NOME_SFX_HURT := "SfxHurt"
const NOME_SFX_LEVELUP := "SfxLevelUp"

## Quanti nodi tiene il pool di ciascun suono. Vedi sotto: uno basta, e la
## ragione e' `INVULN_AFTER_HIT` e la soglia di `progression.gd`, non l'occhio.
const SFX_POOL := 1

## ## `SFX_POOL` e' 1 perche' i due suoni non si sovrappongono mai, e il numero
## non e' scelto a occhio
##
## Sono due i modi in cui due suoni dello stesso tipo si sovrappongono:
##
##   - **`hurt`**: `take_damage()` mette la finestra antidoppio-conteggio — **non piu'
##     una costante**: e' `Game.touch_interval()` (vedi sotto, m12 2026-10-18) —
##     a ogni colpo preso, e `hurt.wav` dura **esattamente 0,25 s** (11025 campioni a
##     44100 Hz, misurati sull'asset). Con la finestra derivata (`0,150 s`) due `hurt`
##     **possono** sovrapporsi di `0,100 s`. Il numero che lo dichiara e' qui, e non e'
##     un difetto dell'antidoppio-conteggio: sono due finestre con due scopi diversi,
##     e la finestra audio e' quella che si accorcia per prima.
##   - **`levelup`**: la soglia di `progression.gd` parte da `XP_BASE = 8.0` e
##     cresce di livello in livello, quindi due salite di livello sono separate
##     da almeno otto uccisioni. `levelup.wav` dura 0.500 s: non c'e' una
##     partita in cui due `levelup` suonano insieme.
##
## Quindi un nodo per suono basta, e un nodo in piu' sarebbe un nodo che
## occupa l'albero per non servire a niente. Il `while` che chiude non c'e':
## se un domani i due suoni cominciassero a sovrapporsi, il difetto si vede
## come **un suono che ricomincia** — la semantica che aveva il nodo unico
## storico — e non come un nodo che manca.

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
##
## ## m16: 0,7 s -> 0,25 s, e i due numeri che lo dicono
##
## Non è una scelta di equilibrio: è la **misura** che l'utente ha chiesto
## dopo aver giocato («quando sono coperto di nemici non mi uccidono
## rapidamente, essere sopraffatti non deve lasciare troppe occasioni»).
## I due fatti, presi sulla scena vera con 200 nemici:
##
##   - **200 nemici, 30 s: 144 morsi offerti e 39 accettati.** 39 è il **91%
##     del massimo che 0,7 s permetteva** (`1/0,7 = 1,43` colpi/s -> 42,9 in
##     30 s): il giocatore era al tetto dell'**invulnerabilità**, non al tetto
##     dell'orda.
##   - il tetto di cadenza del morso, misurato in m11-quarta, è
##     `TOUCH_INTERVAL = 0,150 s`: **0,7 s è 4,7 volte quella**, quindi dei
##     144 morsi offerti circa 105 venivano scartati da un timer e non dal
##     numero di nemici che il giocatore aveva addosso.
##
## Il difetto è che **essere accerchiato è esattamente tanto pericoloso quanto
## essere da solo**: la vita non scala con quanti nemici hai addosso, e
## l'utente l'ha visto giocando. `0,25 s` è circa la cadenza minima di morso
## più un passo — quando sei coperto i morsi **entrano quasi tutti** — e resta
## abbastanza corto da non essere una seconda vita.
##
## Le misure sono in `tests/test_gameplay.gd::_m16_tetto`, e i **denti** sono
## stati eseguiti, non supposti. Con `INVULN_AFTER_HIT` a `0,25`:
## **149 morsi offerti, 88 accettati** (59% dell'offerta, 2,93 colpi/s) e
## **morte al passo 223 (3,72 s)** da fermo al centro con 200 nemici addosso.
## Con questa costante rimessa a `0,7`, sullo stesso codice e nella stessa
## scena: **149 offerti, 39 accettati** (26% dell'offerta, 1,30 colpi/s) e
## **morte al passo 776 (12,93 s)** — fattore **3,5**. Il numero del vertice
## (39 su 144 offerti, 27%) e' stato riprodotto.
## ## m12, 2026-10-18: la finestra **non e' piu' una costante libera**, e' derivata
##
## Il difetto che la stesura precedente aveva scritto e misurato: `0,25 s` **contro**
## `TOUCH_INTERVAL = 0,150 s` dell'orda, cioe' il primo **piu' lungo** del secondo,
## che e' la direzione sbagliata per un antidoppio-conteggio. Numeri di questa sezione:
## `35` morsi accettati su `66` offerti, intervallo minimo fra due accettati
## **`0,2667 s`** — il giocatore **non puo' mai prendere due morsi di fila** per
## quanto sia accerchiato, e la finestra non era una clemenza: era un **limitatore di
## frequenza**.
##
## Il principio, che e' piu' grande del numero: **una costante che compie una funzione
## se non ce n'e' un'altra sola non deve essere libera.** Se sono indipendenti, ognuna
## puo' essere giusta e insieme sbagliate. `INVULN_AFTER_HIT` esiste **perche'**
## `TOUCH_INTERVAL` esiste, quindi si **deriva**: `Game.touch_interval()`.
##
## ## I due numeri che il giorno dopo qualcuno li paragonera', e la riga che li separa
##
##   - **dichiarato**: `0,150 s` — la costante di `src/sim/horde.gd:519`, quella che
##     il contratto dichiara e che questo file **deriva**;
##   - **esercitato**: **`0,1667 s`** — misurato in `tests/test_progression.gd`: e'
##     un decimo passo di ritardo accumulato in virgola mobile dentro
##     `_apply_bites()`, non la griglia dei passi (`0,150 s` sono `9/60` esatti).
##
## `-orda` ha misurato che riparare l'accumulo rende l'orda **piu' veloce** e mangia
## un margine dell'11,1%, e **non l'ha fatto**: e' una modifica di gioco, non un
## rimedio. Quindi i due numeri restano **diversi e giusti entrambi**, e questa riga e'
## quello che impedisce di chiamare bug uno dei due il giorno che si paragonano.
const TOUCH_INTERVAL_DICHIARATO := 0.15

## La finestra che protegge dal doppio conteggio: **l'intervallo con cui l'orda
## morde**, letto dal contratto e non scritto qui.
##
## Il numero nudo e' giusto perche' `take_damage()` non e' chiamato da un orologio
## ma dall'orda: `_apply_bites()` offre un morso e poi non ne offre un altro per
## `TOUCH_INTERVAL`, quindi il produttore **ha gia' garantito** che due morsi non
## arrivino nella stessa finestra. La finestra qui dentro e' la **seconda** garanzia,
## e perche' copra esattamente il periodo del produttore non serve renderla piu'
## lunga — renderla piu' lunga e' stato **il difetto**: `0,25 s` contro `0,150 s`
## significava che dei morsi offerti il giocatore ne poteva accettare al massimo uno
## ogni `0,25 s`, cioe' la finestra ** decideva il ritmo con cui l'orda poteva
## mordere** invece di contare i morsi.
##
## Se `touch_interval()` non e' registrata il contratto risponde `-1,0` e avvisa: qui
## si **usa il numero dichiarato** e si **dice una volta sola**, perche' un ripiego
## silenzioso sarebbe una seconda costante libera travestita da derivazione.
func _finestra_antidoppio_conteggio() -> float:
	var t := float(Game.touch_interval())
	if t > 0.0:
		return t
	if not _warned_touch_interval:
		_warned_touch_interval = true
		push_warning("player: Game.touch_interval() non e' registrata, quindi la finestra antidoppio-conteggio cade sul numero DICHIARATO %.3f s invece che su quello esercitato. Il produttore e' terminal-gun-orda (src/sim/horde.gd:519): senza quel canale questa finestra torna a essere una costante libera, che e' il difetto che m12 chiude."
			% TOUCH_INTERVAL_DICHIARATO)
	return TOUCH_INTERVAL_DICHIARATO

var _warned_touch_interval := false
## Secondi di scatto.
const DASH_TIME := 0.16
## Velocita' dello scatto, in m/s.
const DASH_SPEED := 22.0
## Secondi fra due scatti.
const DASH_COOLDOWN := 1.1
## Metri di margine dal muro. Il giocatore si ferma un filo prima: l'occhio
## deve poter vedere il bordo, non restare appiccicato.
const ARENA_MARGIN := 0.8

# --- m10: gli ostacoli, e il giocatore che ci si arresta ------------------------
#
# Il contratto dichiara `Game.obstacles : PackedVector3Array`, un elemento per
# ostacolo, con la convenzione **il raggio sta in `y`**:
#
#     elemento = Vector3(centro_x, RAGGIO, centro_z)
#
# `y` NON e' un'altezza e `z` NON e' una profondita': sono il raggio e la seconda
# coordinata del centro. Lo dice `src/core/contracts.gd` tre volte perche' e' la
# cosa che si sbaglia per prima.

## Metri di margine dal **bordo di un ostacolo**, come `ARENA_MARGIN` e' un
## margine e non un raggio: il giocatore si ferma un filo PRIMA del disco, cosi'
## il modello non ci entra dentro. E' l'unico numero di -gameplay che serve al
## criterio n. 6 di m10, e `tests/test_gameplay.gd` lo **legge da qui** invece
## di copiarlo: una copia nel test sarebbe un numero che mente il giorno in cui
## lo si ritocca.
const OBSTACLE_MARGIN := 0.6
## Quante volte il clamp puo' correggere la posizione dentro un frame. Serve a
## un solo caso, due ostacoli sovrapposti: dopo una passata il giocatore puo'
## essere stato spinto dentro il secondo, e il secondo lo rimette fuori. Quattro
## passate sono un **tetto**, non un ciclo: nessun `while` che possa non
## finire dentro il passo di simulazione.
const OBSTACLE_PASSES := 4

# --- m12: la torre, e i due numeri che NON sono miei ----------------------------
#
# **Non c'e' nessun numero della torre in questo file.** `Game.floor_count` (quanti
# piani) e `Game.floor_height` (metri per piano) li registra `terminal-gun-arena`
# in `_enter_tree()`, come `arena_radius` e `enemy_body_scale`: la fonte e' il
# contratto, questa foglia **legge**. E la divisione per `floor_height` la fa
# `Game.floor_of()`, che e' l'unica del progetto — copiarla qui sarebbe la terza
# versione che concorda finche' non c'e' una torre, che e' esattamente il difetto
# che il contratto dichiara di voler evitare (`contracts.gd`, sopra `floor_of`).
#
# Quello che invece e' **mio**, e non e' un numero ma una **regola**, e' il piano
# su cui il giocatore si trova: `_player_floor()` sotto. Durante una rampa o una
# caduta il giocatore e' **fra due piani**, e `floor_of(y)` su un'altezza di mezzo
# piano risponderebbe con sicurezza sbagliata. Per rispondere serve sapere se sta
# salendo o scivolando, e questo lo sa solo chi possiede il giocatore.

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
## Gli ostacoli **in uso**, copiati dal contratto (m10). Sono un dato e non un
## nodo: nessun ostacolo aggiunge un nodo a questo sottoalbero, quindi il tetto
## di nodi di -gameplay non cambia perche' esistono. Il campo e' pubblico perche'
## e' un dato di gioco come `hp` e `velocity`, e perche' `reload_obstacles()`
## ne fa la copia dal contratto una volta sola.
var obstacles: PackedVector3Array = PackedVector3Array()
## L'arma. Senza tipo di classe: `player.gd` conosce `weapon_base.gd` solo per
## crearla, e nessuno dei due deve il tipo dell'altro.
var weapon
var progression
## Pipeline RAM: slot limitati di nodi di codice. Il numero di slot e' la
## regolazione del gioco, non un segreto.
const PIPELINE_CAPACITY := 4
const OVERFLOW_DAMAGE := 15.0
const OVERFLOW_COOLDOWN := 0.6
var pipeline
var pipeline_slots: Array[String] = []
var pipeline_capacity: int = PIPELINE_CAPACITY
var buffer_overflowed := false
## True se la tastiera guida il giocatore. Il test la spegne e passa l'input a
## mano, cosi' lo stesso codice serve a entrambi.
var read_keys := true

## Il **pool** dei nodi che suonano, e le scadenze dei suoi slot.
##
## Un `Array` di nodi e una `PackedFloat32Array` di scadenze, per suono: sono i
## due pezzi di un pool a capienza fissa, e la capienza e' `SFX_POOL`. La
## scadenza di uno slot e' `0.0` quando lo slot e' **libero**, e i secondi
## che mancano al `SFX_SICUREZZA` quando e' occupato.
##
## Nessuna delle due liste cresce mai: `_suona_usa_e_getta()` **prende** uno
## slot, non ne crea uno. E' la differenza fra la prima forma di questo
## meccanismo (il nodo nasceva quando il suono partiva) e questa: la prima ha
## fatto fallire `tests/test_arena.gd`, `tests/test_gameloop.gd` e
## `tests/test_ui.gd` con lo stesso numero che saliva di uno, perche' il gioco
## creava un nodo **durante** la partita.
var _sfx_hurt: Array[AudioStreamPlayer3D] = []
var _sfx_hurt_scadenza := PackedFloat32Array()
var _sfx_levelup: Array[AudioStreamPlayer3D] = []
var _sfx_levelup_scadenza := PackedFloat32Array()
## Quanti suoni questo giocatore ha fatto partire, in tutto. Il test ci fa caso
## per una ragione sola: **un meccanismo che libera il nodo puo' passare anche
## con un gioco che non suona niente**, quindi questo numero è la prova che il
## suono è uscito davvero e non è stato soltanto dimenticato.
var sfx_emessi := 0
var _camera: Camera3D
var _cam_basis := Basis.IDENTITY
## `died` e' gia' stato emesso per questa vita. Si azzera in `reset_run()` e non
## altrove: e' il flag che distingue «e' appena morto» da «e' gia' morto», che
## e' la differenza fra emettere la morte una volta e una volta per colpo.
var _dead_signalled := false
## Un solo avviso per la lettura degli ostacoli, e uno per l'invariante del
## raggio. Vedi `reload_obstacles()`: sono due difetti diversi e non si confondono.
var _warned_no_obstacles := false
var _warned_obstacle_radius := false

## ## `_piano = -1` non e' un fallback, e la ragione sta nel contratto
##
## Il neutro ** dichiarato** di `Game.player_floor()` e' `-1`, perche' `0` e' un
## piano **valido** e un neutro a `0` passerebbe in silenzio la prova che chiede
## «il nemico e' nato sul piano del giocatore». Quindi `-1` qui dentro significa
## solo **«non ho ancora campionato nessuna quota»**, e la prima risposta non e'
## un numero scelto: e' `floor_of(y)` sulla quota in cui il giocatore si trova.
## `_piano_valido` e' la riga che tiene separate le due cose.



func _ready() -> void:
	# Piano §5.1: i dati con l'assegnazione diretta, i metodi con
	# `register_impl`. `Game.spawn_projectile = self._spawn_projectile` viene
	# RIFIUTATO da GDScript e interrompe questo `_ready`: la foglia crede di
	# aver registrato e non ha registrato niente.
	Game.player = self
	Game.register_impl("player_position", self._player_position)
	Game.register_impl("player_floor", self._player_floor)

	## ## m7: la via che il danno prende (`contracts.gd`, "damage_player")
	##
	## **Perche' la forma lunga e non quella corta.** La forma corta di piano §5.1
	## risolve a `self.<nome API>()`, quindi `register_impl("damage_player", self)`
	## cercherebbe `self.damage_player()`, che questo file non ha e non deve avere:
	## il metodo si chiama **`take_damage`** e l'API si chiama **`damage_player`**.
	## I due nomi hanno una faccia sola e non combaciano, quindi qui la forma
	## lunga non e' una scelta di stile: e' l'unica che registra il metodo giusto.
	## Con la forma lunga il contratto chiama `take_damage(amount)` e riceve il
	## `bool` che `take_damage` gia' restituiva.
	##
	## Fin qui questa riga non c'era e il giocatore era **invulnerabile per
	## costruzione**: `take_damage` non aveva nessun chiamante in tutto `src/`
	## (misurato il 2026-10-13 con una `grep`: una riga, la definizione). Il
	## chiamante vero e' di **-orda**, che chiama `Game.damage_player(x)` dal ciclo
	## di gioco: qui si registra il destinatario, e non si registra nessun chiamante.
	Game.register_impl("damage_player", self.take_damage)

	progression = PROGRESSION_SCRIPT.new()
	progression.bind(self)
	progression.leveled_up.connect(_on_leveled_up)
	progression.upgrade_applied.connect(func(id: String) -> void: upgrade_applied.emit(id))

	pipeline = PIPELINE_SCRIPT.new()
	pipeline.player = self
	if weapon != null:
		pipeline.weapon = weapon
	pipeline.capacity = pipeline_capacity

	# Contratto di m2: `Game.progression` e' il **dato** che -ui e la verifica di
	# `verify_m2_surface()` leggono per nome, e non tramite `Game.player`.
	#
	## Perche' qui e non in `_enter_tree()` (piano sez. 5.1): la regola dice
	# `_enter_tree()` per chi ha **figli che leggono il dato nel proprio avvio**.
	# Qui i figli sono `Model` e `Weapon`: i due suoni del giocatore sono usa e
	# getta e nascono solo quando suonano (vedi `SFX_SICUREZZA`), quindi non
	# sono figli stabili. Nessuno dei due legge `Game.progression`: l'HUD, che
	# e' l'unico lettore, e' un
	# fratello del giocatore dentro `scenes/arena_main.tscn` e lo legge da
	# `_process`, non dal suo `_ready()`. Inoltre l'oggetto non esiste ancora prima
	# di questa riga: registrarlo in `_enter_tree()` pubblicherebbe `null` e il
	# contratto direbbe "manca" per un dato che c'e' un istante dopo.
	#
	## Senza questa riga le dodici voci di `M2_SURFACE` che puntano a `progression`
	## restano irraggiungibili e `Game.progression` vale `null`: il gate resta
	## verde e la superficie di m2 no. Un verde che copre meno di quel che dice e'
	## il difetto peggiore di una porta. Sono dodici e non dieci dalla m6, che ne ha
	## dichiarate due in piu' (`offer_label`, `offer_effect`).
	Game.progression = progression

	# m10: gli ostacoli si leggono **una volta sola** (semantica punto 1 del
	# contratto: sono statici) e si copiano qui. `-arena` li registra nel proprio
	# `_enter_tree()`, che scende prima del mio `_ready()`, quindi quando questa
	# riga gira il dato e' gia' dentro. Se non lo fosse, il giocatore si
	# muoverebbe senza muri e nessuno se ne accorgerebbe: per quello
	# `reload_obstacles()` **non** e' silenzioso quando non trova niente.
	reload_obstacles()

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
	if pipeline != null:
		pipeline.weapon = weapon

	# I due suoni sono un **pool** di nodi, e i nodi sono quelli che porta
	# gia' `scenes/player.tscn`: il pool li riusa, non li aggiunge. Il numero
	# di nodi della scena vera resta quindi quello di prima, e nessun nodo
	# nasce durante la partita — che e' il difetto che aveva la forma precedente.
	_sfx_hurt = _costruisci_pool(SFX_HURT, NOME_SFX_HURT)
	_sfx_hurt_scadenza.resize(_sfx_hurt.size())
	_sfx_levelup = _costruisci_pool(SFX_LEVELUP, NOME_SFX_LEVELUP)
	_sfx_levelup_scadenza.resize(_sfx_levelup.size())

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
#
# ## m7, criterio n. 3: «morire non corrompe la partita»
#
# Il debito era dichiarato e aperto (`tests/test_gameloop.gd` lo stampava ad alta
# voce: dopo il restart le vite erano ancora `0.0` e l'orda ripiombava in
# `game_over` al passo successivo). La meta' e' di -gameplay perche' a rimettere
# in piedi **un giocatore** puo' essere solo il giocatore: l'orda non ne tiene uno.
# Le tre cose che il criterio chiede sono qui sotto, in tre righe, e nessuna
# delle tre e' un ramo: sono numeri in campi, quindi il numero di nodi non puo'
# cambiare e non c'e' niente da duplicare.

## Rimette in piedi il giocatore: vita piena, statistiche ai numeri di codice,
## progressione azzerata, arma riportata alla regolazione di partenza.
func reset_run() -> void:
	# `max_hp` PRIMA di `hp`: il criterio n. 3 di m7 chiede che `hp` torni a
	# `max_hp`, e con `hp = max_hp` quella e' un'identita' invece di una
	# coincidenza fra due costanti che qualcuno ha cambiato solo da una parte.
	max_hp = MAX_HP
	hp = max_hp
	var _hr = Game.horde
	if _hr != null and is_instance_valid(_hr):
		var _hr_prop = _hr.get("firewall_max_hp")
		if _hr_prop != null:
			_hr.firewall_max_hp = max_hp
	move_speed = MOVE_SPEED
	accel = ACCEL
	velocity = Vector3.ZERO
	invuln = 0.0
	dash_timer = 0.0
	dash_cd = 0.0
	# Gli ostacoli **non** si rileggono: sono statici e il giocatore e' sempre
	# lo stesso. Rileggerli qui cambierebbe la geometria di mezzo a una partita
	# se qualcuno registrasse l'arena un istante dopo il restart.
	# La vita e' tornata: la morte di questa partita e' finita, e il prossimo
	# colpo che porta a zero deve poter emettere `died` di nuovo. Senza questa
	# riga il restart riporterebbe in piedi un giocatore che non si puo' piu'
	# morire, che e' il difetto opposto a quello che m7 chiude.
	_dead_signalled = false
	# Al centro dell'arena: una partita nuova comincia dal centro, e la camera
	# dell'arena parte gia' li'. Il nemico piu' vicino e' a `Game.nearest_enemy`
	# nell'arma, quindi la posizione non cambia nulla di quello che segue.
	position = Vector3.ZERO
	if progression != null:
		progression.reset()
	if weapon != null:
		weapon.reset()
	clear_pipeline()
	buffer_overflowed = false
	# I due suoni vengono chiusi **alla fine**, e il posto e' dichiarato: uno slot
	# occupato da un suono della partita che e' appena finita resta occupato se
	# nessuno lo rimette a zero, e il restart allora riparte con uno slot che non
	# e' suo. Sta **dopo** `progression.reset()` perche' quella non emette
	# `leveled_up` e quindi non puo' riaprire uno slot che qui chiudo.
	#
	# Non e' `stop()`: e' `chiudi_suoni()`, cioe' il tempo che il suono occupa lo
	# slot che si rimette a zero. Il suono **finisce di suonare** — non e' un
	# silenzio — e lo slot torna libero come tornerebbe dopo `finished`.
	chiudi_suoni()

## Il restart **completo**: io e -orda, in quest'ordine. Prima il giocatore e poi
## l'orda, cosi' nell'istante in cui la partita torna `playing` nessuno e' a zero
## vite e nessuno puo' rileggere `game_over`.
##
## L'ordine non e' una scelta di stile e non e' invertibile: `horde.restart_run()`
## chiama `run.restart()` e ripopola l'orda **rispetto a `Game.player_position()`**,
## cioe' rispetto al giocatore. Se l'orda fosse prima, i nemici nascerebbero dove
## il giocatore **era** e il restart riporterebbe in gioco un mondo fatto da solo.
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
##
## ## `R` e' il primo, e perche' l'ordine non e' un capriccio
##
## `Enter` e' **`ui_accept`** in Godot: in un contesto di UI puo' essere consumato
## prima che `_unhandled_input()` lo veda, cioe' esattamente il difetto che
## l'utente ha segnalato («non esiste un modo per riavviare dal gioco»). Un tasto
## che il motore puo' mangiare non puo' essere il **primo** di una lista che
## l'interfaccia mostra: il richiamo a schermo e' il primo della lista (e' la
## scelta di -ui leggerlo da qui), e quindi deve essere il piu' affidabile dei
## tre. `KEY_SPACE` c'è perche' e' il tasto che il genere ha gia' deciso; sotto un
## pannello aperto l'albero e' fermo e questa riga non gira, quindi la carta di un
## potenziamento non puo' diventare un restart.
const RESTART_KEYS := [KEY_R, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
## Tasto che apre il menu della pipeline RAM: spostare i comandi mette in pausa.
const PIPELINE_MENU_KEYS := [KEY_B]

## Il tasto del restart **in parole**, per l'interfaccia: il numero dei tasti e'
## di questo file e l'interfaccia deve scrivere quello che qui e' dichiarato, non
## scegliere un tasto suo che qui non e' fra quelli e quindi non fa niente. Il
## primo della lista e' quello che l'interfaccia mostra, quindi qui e' in testa.
func restart_hint() -> String:
	return "R / INVIO / SPAZIO"

## Il menu della pipeline e' aperto? Campo di stato, non un nodo: aprire e
## chiudere non crea nodi.
var pipeline_menu_open := false
var _pipeline_menu_paused_by := false

func open_pipeline_menu() -> void:
	if pipeline_menu_open:
		return
	pipeline_menu_open = true
	_set_pipeline_menu_paused(true)

func close_pipeline_menu() -> void:
	if not pipeline_menu_open:
		return
	pipeline_menu_open = false
	_set_pipeline_menu_paused(false)

func toggle_pipeline_menu() -> void:
	if pipeline_menu_open:
		close_pipeline_menu()
	else:
		open_pipeline_menu()

func is_pipeline_menu_open() -> bool:
	return pipeline_menu_open

func _set_pipeline_menu_paused(on: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	if on:
		if not tree.paused:
			tree.paused = true
			_pipeline_menu_paused_by = true
		return
	if _pipeline_menu_paused_by and tree.paused:
		tree.paused = false
	_pipeline_menu_paused_by = false

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	# Restart solo quando si e' morti.
	if read_keys and is_dead():
		if RESTART_KEYS.has(key.physical_keycode):
			restart_run()
			var vp := get_viewport()
			if vp != null:
				vp.set_input_as_handled()
			return
	# Menu pipeline con B, solo in vita.
	if read_keys and not is_dead():
		if PIPELINE_MENU_KEYS.has(key.physical_keycode):
			toggle_pipeline_menu()
			var vp2 := get_viewport()
			if vp2 != null:
				vp2.set_input_as_handled()
			return

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
	# Mappa mobile: il firewall usa la vita massima **vera** del giocatore, non
	# un 100 fisso, perche' i potenziamenti di vitalita' la cambiano. Il canale
	# di danno resta Game.damage_player (il contratto), e qui si tiene allineato
	# solo il numero da cui l'orda calcola il 20%/s.
	var _h = Game.horde
	if _h != null and is_instance_valid(_h):
		var _h_prop = _h.get("firewall_max_hp")
		if _h_prop != null:
			_h.firewall_max_hp = max_hp
	_chiudi_suoni_scaduti(delta)
	if weapon != null:
		weapon.step(delta)

## WASD e frecce, in un vettore del piano schermo. Non usa `Input.get_vector`
## perche' `project.godot` non ha una InputMap e non e' mio: `InputMap.has_action`
## avrebbe stampato un errore a ogni frame.
##
## Qui dentro c'e' **solo** la lettura della tastiera: il verso del vettore sta in
## `input_vector`, che e' una funzione **pura** e che il test chiama con i quattro
## stati a mano. Non e' comodo, e' la ragione per cui il difetto di m5 era
## invisibile: un test che si scrive a mano il vettore di W, senza passare dalla
## funzione che lo costruisce, asserisce una cosa diversa da quella che il gioco
## fa, e un difetto di **segno** è proprio il difetto che un vettore scritto a
## mano nasconde.
func read_input() -> Vector3:
	return input_vector(
		Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT),
		Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT),
		Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN),
		Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))

## Il vettore dello schermo per i quattro stati dei tasti: `x` a destra,
## `z` **in avanti sullo schermo**, cioè verso l'alto di quello che si vede.
##
## ## Il segno di `z`, e dove stava la doppia negazione (piano §1.5a)
##
## `world_direction` traduce questo vettore con `right * x + up * z`, dove `up`
## è, **per costruzione**, la direzione che la camera mostra come *alto*: su una
## camera che guarda dall'alto è la sua `y` proiettata sul piano, e il ripiego
## (una camera in piano, dove la `y` non ha parte orizzontale) è il suo avanti,
## che in orizzontale è la stessa cosa. Quindi `z` deve valere `+1` per andare
## **su**: `W` era `-1`, e quello è una doppia negazione che riportava il
## giocatore **verso la camera**, cioè **giù sullo schermo**.
##
## La correzione sta **qui** e non in `world_direction`: la formula di
## `world_direction` è quella giusta — `right` è la destra dello schermo, `up` è
## l'alto dello schermo, e il vettore d'ingresso è espresso in quegli stessi due
## assi — quindi l'unica riga che aveva il verso sbagliato era questa.
## `read_input()` e `world_direction()` dichiaravano la convenzione in due posti e
## i due posti non concordavano; quello che si corregge è il secondo, perché il
## primo è quello da cui si legge il significato.
##
## Il criterio n. 2 di m5 tiene anche il ripiego: senza camera `W` resta `-z`,
## che è l'avanti della camera identità, e con la camera di arena (dietro e in
## alto) i due percorsi dicono la **stessa** cosa sullo schermo.
func input_vector(destra: bool, sinistra: bool, indietro: bool, avanti: bool) -> Vector3:
	var v := Vector3.ZERO
	if destra:
		v.x += 1.0
	if sinistra:
		v.x -= 1.0
	if indietro:
		v.z -= 1.0
	if avanti:
		v.z += 1.0
	return v.limit_length(1.0)

## Il vettore di input del piano schermo tradotto nel mondo, secondo la camera:
## `right * x + up * z`, dove `right` e `up` sono i due assi **dello schermo**
## della camera (vedi `input_vector` per il verso di `z`).
## Se non c'e' camera (test headless, o i primi frame) la base e' l'identita' e il
## risultato e' quello che il test si aspetta: +x = est, -z = nord.
##
## ## m12: le **direzioni di input**, e perche' il numero non e' un costo
##
## ### Nessuna riga di gioco: solo la dichiarazione e la misura
##
## Il vertice non ha ancora scritto le direzioni di input nel piano, quindi qui non
## c'e' una regolazione da cambiare: scrivere un numero **usato** adesso sarebbe una
## seconda verita' rispetto al piano, cioe' la stessa classe di difetto che ha
## prodotto `ramp_angle`. Il numero qui sotto e' quindi **dichiarato e non
## applicato**, e quando il vertice scrivera' il numero di disegno va preso da qui.
##
## ### La misura, tutta chiedendo il canale di `-arena` e non copiandone i numeri
##
## Sulla torre vera, con `tests/test_gameplay.gd::_m12_corsa_nel_corridoio` che
## campiona `surface_height_at(xz, 0)` su una griglia a passo `M12_PASSO_IMPRONTA`:
## il corridoio della rampa che parte dal piano 0 e' lungo **24,0 m** e largo
## **8,0 m** (la stampa dice `10,0 m` perche' conta anche i `2,0 m` di risoluzione
## della griglia), la pendenza e' **0,820 m/m**, e il piede e' a `s = 0,0 m`.
##
## Il giocatore che cammina con **8 direzioni** esce dal corridoio **prima** di
## arrivare al bordo del piano: quota `0,833 -> 19,103 m` in 194 passi, cioe'
## `0,897 m` di quota mancanti (`M12_ALTEZZA_PIANO`, costante di
## `tests/test_gameplay.gd`). Non e' un difetto della superficie — il canale ha
## risposto a ogni passo fino a quando il giocatore e' stato dentro — e' la
## **deriva laterale** di un input a 8 direzioni dentro un corridoio largo 8 m.
##
## ### Il conto, e **perche' `10` non basta**
##
## Con `D` direzioni equispaziate l'errore angolare peggiore e' `180 / D`, e la
## deriva su una corsa `L` e' `L * tan(180 / D)`. Con `L = 24 m` e semi-larghezza
## `4,0 m`:
##
##   D =  8   errore 11,25 gradi   deriva 4,77 m   oltre il muro
##   D = 10   errore  9,00 gradi   deriva 3,80 m   dentro, ma margine 0,20 m = 5%
##   D = 12   errore  7,50 gradi   deriva 3,16 m   dentro, margine 0,84 m = 21%
##
## `10` non basta perche' la formula **sotto**stima il misurato: `-arena` ha
## misurato `5,9234 m` di deriva su `26 m` con 8 direzioni, cioe' `12,84 gradi`
## contro gli `11,25` della formula — uno scarto del **13%**, e un margine del 5%
## non sopravvive a uno scarto del 13%.
##
## ### Il numero e' una **risoluzione**, e oggi non e' applicabile
##
## **L'angolo e' dell'input analogico, non un conteggio** — questo principio e' vero,
## e su questo progetto e' **falso come fatto**. `read_input()` chiama
## `input_vector()` con quattro booleani di tastiera, `input_vector()` mette
## `+-1,0` nei componenti, e delle sedici combinazioni escono quattro cardinali e
## quattro diagonali: **otto direzioni**, misurate in
## `tests/test_gameplay.gd::_m12_direzioni_input()` (`90, 270, 180, 135, 225, 0,
## 45, 315`). Non c'e' `InputMap`, non c'e' `Input.get_vector`, non c'e' un asse
## analogico. Quindi **non c'e' nessun pollice che dia l'angolo**, e `12` direzioni
## sarebbero quattro vettori **irraggiungibili**: un conteggio che il gioco non puo'
## esercitare e' la copia che non si contraddice, cioe' esattamente il difetto che
## questa dichiarazione vieta.
##
## ## La conseguenza che conta: la deriva e' di **gioco**
##
## La deriva che `-arena` ha misurato (`5,9234 m` su `26 m` con `8` direzioni) e'
## gia' misurata qui dentro: il giocatore che cammina con le **stesse otto**
## direzioni che un umano puo' premere con due dita esce dal corridoio al passo
## `194` con `0,897 m` di quota mancanti. **Non e' un difetto del pilota automatico
## del test**: e' il difetto che un giocatore vero incontra salendo. Quindi la scelta
## non e' «il test simula male»: e' «il gioco offre otto direzioni e un corridoio che
## ne pretende di piu'».
##
## Le due leve, e il numero di ciascuna. Il corridoio deve essere largo quanto la
## deriva che 8 direzioni producono, e la deriva si misura sulla corsa:
## `deriva = corsa * tan(angolo)`.
##   - col **misurato** di `-arena` (`5,9234 m` su `26 m`, cioe' `12,84 gradi`,
##     `tan = 0,2284`): su una corsa di `24 m` la deriva e' `5,48 m` per lato, cioe'
##     semi-larghezza `5,48 m` e **larghezza piena 10,96 m** invece di `8,00 m`.
##     Il numero e' di `terminal-gun-arena`;
##   - col **peggiore** della formula (`180/8 = 22,5 gradi`, `tan = 0,4142`): `9,94 m`
##     per lato, cioe' **larghezza piena 19,89 m**. E' il tetto, non il numero: il
##     cammino non parte sempre dall'angolo peggiore e per questo il misurato e'
##     metà del peggiore;
##   - **una sorgente che dia l'angolo** (un asse analogico, o un input che legga la
##     posizione dei tasti su un continuum), che allora rende `12` applicabile e
##     gratuito. Non c'e' `InputMap` in `project.godot` e quel file non e' mio.
##
## Finche' nessuna delle due e' scritta, `12` resta **dichiarato e non applicato**:
## nessuna riga di `input_vector()` o `world_direction()` quantizza l'input, e
## applicarlo ora metterebbe in gioco quattro direzioni che nessun tasto produce.
const N_DIREZIONI_INPUT_DICHIARATE := 12
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
##
## È l'implementazione che il contratto chiama con `Game.damage_player(x)`, e il
## suo `bool` è la risposta che il contratto promette: `true` se la mossa ha
## fatto scendere `hp`, `false` altrimenti (danno nullo, invulnerabilità, corsa).
##
## ## `died` una volta sola, e perché (m7)
##
## Prima di m7 questa riga emetteva `died` **ogni volta** che `hp` restava a
## zero, cioè una volta ogni `INVULN_AFTER_HIT` finché l'orda ti ha accerchiato:
## il segnale della morte poteva sparare quattro, cinque volte per la stessa
## morte. Non se ne accorgeva nessuno perche' nessuno moriva (piano §1.4a: il
## chiamante di `take_damage` non esisteva), e `died` non aveva ascoltatori in
## tutto `src/`. Da m7 il chiamante c'è — è di -orda — quindi il difetto è
## diventato raggiungibile, e la spinta è una sola variabile: la morte è una
## **transizione**, non uno stato che si ri-annuncia a ogni colpo.
func take_damage(amount: float) -> bool:
	if amount <= 0.0 or is_invulnerable():
		return false
	hp = maxf(hp - amount, 0.0)
	invuln = _finestra_antidoppio_conteggio()
	_suona_hurt()
	hurt.emit(amount, hp)
	if hp <= 0.0 and not _dead_signalled:
		_dead_signalled = true
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

## Piano unico: nessun piano da campionare, nessuna divisione per piano.
## Gli ostacoli sono tutti quelli registrati dal contratto.

# --- Pipeline RAM: nodi di codice in slot limitati -------------------------------

func _pipeline_sync() -> void:
	if pipeline != null:
		pipeline_slots = pipeline.slots.duplicate()
		pipeline_capacity = pipeline.capacity

func _trigger_buffer_overflow() -> void:
	buffer_overflowed = true
	if hp > 0.0:
		take_damage(OVERFLOW_DAMAGE)
	if weapon != null:
		weapon.cooldown = maxf(float(weapon.cooldown), OVERFLOW_COOLDOWN)
	if pipeline != null:
		pipeline.overflowed = true

func pipeline_add(node_id: String) -> bool:
	if pipeline == null:
		pipeline = PIPELINE_SCRIPT.new()
		pipeline.player = self
		pipeline.weapon = weapon
		pipeline.capacity = pipeline_capacity
	var ok := bool(pipeline.add_node(node_id))
	_pipeline_sync()
	if not ok:
		_trigger_buffer_overflow()
	return ok

func add_pipeline_node(node_id: String) -> bool:
	return pipeline_add(node_id)

func add_node(node_id: String) -> bool:
	return pipeline_add(node_id)

func assign_node(slot_index: int, node_id: String) -> bool:
	if pipeline == null:
		pipeline = PIPELINE_SCRIPT.new()
		pipeline.player = self
		pipeline.weapon = weapon
		pipeline.capacity = pipeline_capacity
	var ok := bool(pipeline.assign(slot_index, node_id))
	_pipeline_sync()
	if not ok:
		_trigger_buffer_overflow()
	return ok

func assign_pipeline_slot(slot_index: int, node_id: String) -> bool:
	return assign_node(slot_index, node_id)

func assign_to_pipeline(slot_index: int, node_id: String) -> bool:
	return assign_node(slot_index, node_id)

func set_pipeline(nodes: Array) -> bool:
	if pipeline == null:
		pipeline = PIPELINE_SCRIPT.new()
		pipeline.player = self
		pipeline.weapon = weapon
		pipeline.capacity = pipeline_capacity
	var ok := bool(pipeline.set_slots(nodes))
	_pipeline_sync()
	if not ok:
		_trigger_buffer_overflow()
	return ok

func set_pipeline_slots(nodes: Array) -> bool:
	return set_pipeline(nodes)

func pipeline_set(nodes: Array) -> bool:
	return set_pipeline(nodes)

func clear_pipeline() -> void:
	if pipeline != null:
		pipeline.clear()
	_pipeline_sync()
	buffer_overflowed = false

## Sposta un comando da uno slot all'altro senza creare o liberare nodi: la RAM
## resta entro la capacita' dichiarata. Restituisce false se la mossa rompe la
## stabilita' della pipeline o esce dai limiti.
func pipeline_move(from_index: int, to_index: int) -> bool:
	if pipeline == null:
		return false
	var ok := bool(pipeline.move(from_index, to_index))
	_pipeline_sync()
	return ok

func move_pipeline_node(from_index: int, to_index: int) -> bool:
	return pipeline_move(from_index, to_index)

func swap_pipeline_slots(a: int, b: int) -> bool:
	return pipeline_move(a, b)

func pipeline_clear() -> void:
	clear_pipeline()

func pipeline_is_stable() -> bool:
	if pipeline == null:
		return true
	return bool(pipeline.is_stable())

func is_pipeline_stable() -> bool:
	return pipeline_is_stable()

func check_buffer_overflow() -> bool:
	return buffer_overflowed

func buffer_overflow_now() -> void:
	_trigger_buffer_overflow()

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
	_clamp_to_obstacles()
	_appoggia_sulla_superficie()
	velocity.y = 0.0

## ## m12: la quota del giocatore **si legge**, non si calcola
##
## `world_direction()` schiaccia l'ingresso sul piano XZ, quindi `velocity.y` e'
## `0,0` **e resta `0,0` anche con la torre montata**: qui dentro non c'e' nessun
## sistema di movimento verticale, nessuna gravita', nessun salto, nessun
## ascensore. Il divieto di m12 e' esattamente questo, e questa funzione e' la
## prova che e' stato rispettato: l'unica cosa che scrive `position.y` e' una
## **risposta** a chi possiede la geometria.
##
## `Game.surface_height_at(punto, piano)` e' la stessa forma di
## `Game.ground_visible()`: una domanda di geometria al possessore della geometria,
## con un **neutro che rumora** (`-1,0` = qui non c'e' rampa) invece di un fallback.
## Con la torre non montata la risposta e' `-1,0` e questa funzione **non tocca
## niente**: il giocatore resta sul pavimento, che e' la risposta esatta per il
## mondo di prima di m12.
##
## ## Il `piano` passato e' **quello da cui si e' partiti**, e perche' conta
##
## Il chiamante e' `_player_floor()`, cioe' il latch: durante la salita restituisce
## il piano di partenza, non quello che dice `floor_of(y)`. Le tre rampe hanno assi
## diversi e su un disco da 35 m due corridoi di piani diversi **possono incrociarsi**:
## passare il piano sbagliato chiederebbe a `-arena` la quota di un'altra rampa che
## passa per lo stesso punto, e la risposta sarebbe giusta per l'altra rampa. Il
## parametro del contratto c'e' per questo, e questa riga e' il suo unico uso.
##
## ## Perche' sta **dopo** i due clamp
##
## I clamp cambiano `x` e `z` di qualche decimo di metro e portano il giocatore
## **fuori** dal disco o dal muro. Leggendo la superficie prima, la quota sarebbe
## quella di un punto che il giocatore ha appena lasciato: su una rampa larga 8 m e
## su un margine di 0,6 m non cambia niente, ma «la quota corrisponde a dove il
## giocatore e' adesso» e' una proprieta' che vale anche quando i margini crescono.
## Il costo e' che il blocco degli ostacoli di questo passo ha usato il piano del
## passo precedente: e' il ritardo di un passo gia' dichiarato sopra
## `_campiona_piano()`.


## Appoggia il giocatore sulla superficie del piano: la quota viene dalla
## superficie, non da un sistema di movimento verticale (m12).
func _appoggia_sulla_superficie() -> void:
	var xz := Vector2(position.x, position.z)
	var fc := maxi(int(Game.floor_count), 1)
	for f in fc:
		var q := Game.surface_height_at(xz, f)
		if q >= 0.0:
			position.y = q
			return
	var h := float(Game.floor_height)
	if h > 0.0:
		position.y = float(Game.floor_of(position.y)) * h
	else:
		position.y = 0.0

## Il piano su cui sta il giocatore (m12).
func _player_floor() -> int:
	var xz := Vector2(position.x, position.z)
	var fc := maxi(int(Game.floor_count), 1)
	for f in fc:
		if Game.surface_height_at(xz, f) >= 0.0:
			return f
	return Game.floor_of(position.y)

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

# --- m10: l'ostacolo, che e' solido solo per chi cammina -------------------------
#
# ## Il criterio n. 6 ha due meta' e sono una decisione, non una conseguenza
#
# Il giocatore e' **solido**: ci si arresta prima del bordo. I proiettili
# **passano**: in `src/weapons/` non c'e' nessun test di ostacolo, e non e' un
# dimenticanza. La combinazione «ostacolo che blocca anche i proiettili» lascia
# il giocatore che ci si mette dietro **al sicuro e irraggiungibile** per sempre,
# cioe' un gioco che si vince stando fermi. Fa l'ostacolo solido a chi cammina
# e resta un ostacolo vero; «proiettili che si fermano» e' **m11**.
#
# ## Perche' un trattamento solo e non uno stile diverso dal muro
#
# Il muro dell'arena toglie la componente di velocita' **uscente** e lascia
# scivolare quella parallela, altrimenti il giocatore si incastra nell'angolo e
# si ferma di botto. Lo stesso vale qui: un disco contro cui si sbatte di
# fianco deve **farlo scivolare intorno**, non tenerlo. E' la differenza fra un
# ostacolo e un muro in cui ti incatti, ed e' la stessa identica formula del
# muro: il criterio e' che il giocatore non resti fermo li'.

## Il muro dell'ostacolo: il giocatore si ferma a `raggio + OBSTACLE_MARGIN` dal
## centro e non entra mai nel disco. Un elemento con `y <= 0` e' **saltato**:
## l'invariante del contratto dice `y > 0`, e un raggio nullo non e' un ostacolo
## piccolo, e' un ostacolo che non esiste.
##
## ## m12: si ferma solo per gli ostacoli **del suo piano**
##
## `Game.obstacles` resta **un `PackedVector3Array` piatto** (contratto di m10, la
## forma non cambia) e con la torre contiene un ostacolo per ogni disco di ogni
## piano. Ma `y` **non e' l'altezza**: `y` e' il **raggio** del disco, e resta un
## raggio su tutti e quattro i piani. Quindi il piano di un ostacolo **non** si
## legge dall'elemento: si legge dalla **posizione nell'array**, perche' `-arena`
## concatena quattro chiamate di `layout()` una per piano (piano m12, «L'interfaccia
## degli ostacoli»). Il blocco di un piano sono quindi `size / floor_count` voci
## consecutive, e quel numero **e' derivato**, non scritto: vedi
## `ostacoli_per_piano()`.
##
## Senza questo il giocatore sul piano 2 si ferma contro un ostacolo che sta a 40 m
## sotto di lui, e la torre ha un muro per ogni piano che si vede solo dal piano
## sotto.
func _clamp_to_obstacles() -> void:
	if obstacles.is_empty():
		return
	var passate := 0
	while passate < OBSTACLE_PASSES:
		var mosso := false
		for i in range(0, obstacles.size()):
			var o := obstacles[i]
			var raggio := o.y
			if raggio <= 0.0:
				continue
			var centro := Vector3(o.x, 0.0, o.z)
			var d := Vector3(position.x - centro.x, 0.0, position.z - centro.z)
			var distanza := d.length()
			var limite := raggio + OBSTACLE_MARGIN
			if distanza >= limite:
				continue
			# Sul centro esatto la normale non c'e'. Il ripiego e' dichiarato e
			# non e' un caso: senza di esso la divisione per zero fa NaN e NaN
			# nella posizione e' l'unico risultato che non si vede.
			var normale := d / distanza if distanza > 0.0001 else Vector3(1.0, 0.0, 0.0)
			position.x = centro.x + normale.x * limite
			position.z = centro.z + normale.z * limite
			var verso := velocity.dot(normale)
			if verso > 0.0:
				velocity -= normale * verso
			mosso = true
		if not mosso:
			return
		passate += 1



## Quanti ostacoli il giocatore sta usando adesso, cioe' **quelli del suo piano**.
## E' la domanda che il test m10 fa sul contratto: un giocatore che ha letto zero
## ostacoli su una scena che ne ha, non e' un giocatore che si trova un mondo
## senza muri, e' un giocatore che non ha letto la geometria.
##
## ## Perche' il numero e' **per piano** e non il totale (m12)
##
## Con la torre, `size` e' la somma dei quattro piani: restituirlo direbbe al
## chiamante che ci sono ostacoli che **non esistono sul piano dove il giocatore
## sta**, e un chiamante che li usa per costruire un campo di percorrenza li
## metterebbe dove non c'e' niente. Con `floor_count = 1` — cioe' prima di m12, e
## senza torre — questo valore e' **il totale**, quindi nessuna asserizione di m10
## cambia numero.
func obstacle_count() -> int:
	return obstacles.size()

## ## m12: il piano su cui sta il giocatore
##
## **Non e' `floor_of(position.y)`**, e la ragione e' scritta nel contratto
## (`contracts.gd`, sopra `player_floor`): durante una rampa o una caduta il
## giocatore e' **fra due piani**, e `floor_of` su un'altezza di mezzo piano
## restituirebbe il piano sbagliato **con sicurezza** — restituirebbe un numero,
## non un «non lo so». Per rispondere serve sapere se il giocatore sta salendo o
## scivolando, e questo lo sa solo chi lo possiede: questa funzione.
##
## ## La regola, in tre righe
##
## Il piano si cambia **all'atterraggio**, e l'atterraggio e' l'unico momento in
## cui i piedi non si muovono:
##
##   - i piedi sono fermi (`dy == 0`) -> il piano e' quello dell'altezza: il
##     giocatore e' fermo **su** un piano, e la sua altezza lo dice senza ambiguita';
##   - i piedi si muovono **in su** e l'altezza e' gia' nella banda sopra -> sta
##     ancora **salendo la rampa**, quindi e' sul piano da cui e' partito: il piano
##     cambia quando tocca terra, non quando la rampa e' a meta';
##   - i piedi si muovono **in giu** e l'altezza e' gia' nella banda sotto -> sta
##     ancora **scivolando via** dal piano da cui e' partito, quindi e' su quel
##     piano: anche qui il piano cambia all'atterraggio.
##
## Il risultato e' che **durante il attraversamento la risposta resta quella del
## piano di partenza per tutta la banda**, e non e' `floor_of(y)`: e' la differenza
## fra questa funzione e quella, ed e' un piano intero di scarto, non un dettaglio
## al bordo.
##
## ## Perche' `dy == 0` e non una soglia
##
## Una soglia qui sarebbe **un numero scritto prima della sua misura**: servirebbe
## sapere quanto rumore in virgola mobile produce la rampa che scrive `y`, e quel
## numero e' di `-arda`, non mio. Con l'uguaglianza esatta la regola e' stabile:
## un piede che vibra attorno a un bordo non fa oscillare il piano (il ramo sotto
## richiede che il moto sia **contro** lo spostamento). Se un giorno la rampa
## producesse una `y` che cambia di un ulp a ogni passo, il sintomo sarebbe
## «il giocatore resta sul piano da cui e' partito», e il rimedio e' in
## `src/render/arena.gd`, non qui.
##
## ## Il `-1` non esce mai da qui
##
## Il contratto dichiara `-1` come neutro di `Game.player_floor()` perche' non
## registrata essa restituisca «non lo so». **Registrata** questa funzione non
## restituisce mai `-1`: il caso «non ho ancora campionato nessuna quota» non e'
## un fallback a `0`, e' `floor_of(y)` letto sull'altezza in cui il giocatore si
## trova, che nel mondo senza torre e' `0` **perche' e' la risposta vera**
## (contratto: «non c'e' una torre» e' il piano 0) e non perche' non so rispondere.
## Il piano **si chiede alla superficie**, e non si deduce da `y`.
##
## ## Perche' `dy` e' sparito
##
## La regola di prima era «piedi fermi (`dy == 0`) -> piano dell'altezza; in salita
## o in caduta -> resta quello da cui si e' partiti». Il secondo e il terzo caso
## erano giusti. **Il primo no**, e non perche' fosse scritto male: perche'
## prima di m12 `position.y` era **sempre `0,0`**, quindi «piedi fermi» e «piano
## dell'altezza» erano la stessa cosa. Da quando la quota la scrive
## `_appoggia_sulla_superficie()` un giocatore **fermo sulla rampa** ha `dy == 0` e
## `y = 20,0`, e quel ramo gli dichiarava il piano 1 mentre e' logicamente sul piano
## 0: la rampa che sta sollevando e' quella **del** piano 0.
##
## E' stato quello il difetto che ha fatto perdere 39 volte sulle uccisioni: la
## `_focus_floor` dell'orda (che viene da `player_floor()`) puntava al piano 1,
## dove non c'e' nessun nemico, la griglia era vuota, `nearest_enemy` rispondeva
## `-1` e l'arma non spariva piu'.
##
## `dy` non distingue piu' niente: non dice se il giocatore si e' mosso, dice solo
## se la superficie gli ha cambiato la quota sotto i piedi. **Quell'informazione
## non e' in `dy`**, e la regola che la usa sbagliava per costruzione.
##
## ## La regola, in tre righe
##
## Il piano e' una proprieta' **della superficie**: si chiede, con lo stesso canale
## che `_appoggia_sulla_superficie()` usa gia'. Per ogni piano `f` in
## `[0, floor_count)`:
##
##   - `surface_height_at(xz, f) >= 0,0`  ->  il giocatore e' **dentro il corridoio
##     della rampa di `f`**, e il suo piano logico e' **`f`**: la rampa e' il pezzo
##     di mondo che si **lascia** il piano `f` (`contracts.gd`, `surface_height_at`:
##     «la rampa appartiene a quello [il piano da cui si e' partiti]»);
##   - nessuna rampa lo contiene  ->  il piano e' `floor_of(y)` e non c'e' niente da
##     dire: il giocatore e' su un disco piano e la sua quota lo dice senza
##     ambiguita'.
##
## Il parametro `piano` del contratto serve perche' su un disco da 35 m i corridoi
## di piani diversi **si incrociano**: senza parametro un punto avrebbe piu' risposte
## e nessuna sarebbe sbagliata. Ed e' esatto **sul bordo**, che e' il posto dove una
## regola basata su `dy` sbagliava di sicuro: a `y = 20,0` sul ciglio della rampa,
## `floor_of` dice 1 e la rampa dice 0.


## Rilegge gli ostacoli dal contratto e restituisce quanti ne ha trovati. Gli
## ostacoli sono **statici** (semantica punto 1): si leggono una volta sola e da
## qui in avanti il giocatore lavora sulla copia, quindi il ciclo di gioco non
## copia un `PackedVector3Array` a ogni frame.
##
## ## Perche' `Game.get("obstacles")` e non `Game.obstacles`
##
## Il contratto dichiara il campo (`src/core/contracts.gd`, "Superficie di
## milestone 10"), ma quel file **non e' mio** e quel campo puo' non essere
## ancora dichiarato come membro. Su un autoload GDScript un membro inesistente
## non e' un errore a runtime: e' un errore **di compilazione**, e si porta via
## tutto l'albero invece di un numero. `Object.get()` su un nome assente
## restituisce `null` e basta, quindi qui sotto la difesa e' il **controllo del
## tipo**, non il nome. Se il campo verra' dichiarato, questa riga continua a
## funzionare identica.
##
## ## Perche' zero non vuol dire «nessun ostacolo» (punto 5 della semantica)
##
## «Nessun ostacolo blocca nessuno» e' vero **anche quando non ce n'è**: un
## giocatore che non scontra niente passerebbe tutti i criteri di m10 senza aver
## mai incontrato un muro. Quindi qui non c'e' fallback silenzioso: quando il
## contratto non ha il dato, il giocatore lo dice una volta, ad alta voce, con il
## nome di chi lo registra. E il numero torna lo stesso, cosi' un test lo vede.
func reload_obstacles() -> int:
	var letto: Variant = Game.get("obstacles")
	if not (letto is PackedVector3Array):
		obstacles = PackedVector3Array()
		if not _warned_no_obstacles:
			_warned_no_obstacles = true
			push_warning("player: Game.obstacles non e' un PackedVector3Array (letto %s), quindi nessun ostacolo blocca nessuno. "
				% type_string(typeof(letto))
				+ "Li registra terminal-gun-arena in _enter_tree(); il campo e' dichiarato in src/core/contracts.gd.")
		return 0
	obstacles = letto
	_controlla_raggi()
	return obstacles.size()

## L'invariante `elemento.y > 0.0` (semantica punto 3): un raggio nullo non e'
## un ostacolo piccolo, e' un ostacolo che non esiste, e si distingue dal raggio
## negativo solo per il crash. Il clamp sopra lo salta; qui si dice una volta che
## il dato e' sbagliato, perche' saltarlo in silenzio e' il difetto che un
## ostacolo invisible porta in un test.
func _controlla_raggi() -> void:
	if _warned_obstacle_radius:
		return
	for o in obstacles:
		if o.y > 0.0:
			continue
		_warned_obstacle_radius = true
		push_warning("player: un ostacolo ha raggio %f in y (elemento %s). Il contratto dice che y e' il raggio e che y > 0.0 e' un invariante."
			% [o.y, str(o)])
		return

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
	_suona_levelup()
	leveled_up.emit(new_level)

## I due suoni e il loro pool. `SFX_SICUREZZA` in testa al file spiega perche'
## il nodo torna nel pool e cosa non funziona; `SFX_POOL` spiega perche' il
## pool e' piccolo. Qui c'e' solo il come.
func _suona_hurt() -> void:
	_suona_dal_pool(_sfx_hurt, _sfx_hurt_scadenza, SFX_HURT)

func _suona_levelup() -> void:
	_suona_dal_pool(_sfx_levelup, _sfx_levelup_scadenza, SFX_LEVELUP)

## Il pool di `nome`: `SFX_POOL` nodi, presi dalla scena se ci sono.
##
## Un nodo che la scena non porta viene creato qui, in `_ready()`, e solo qui:
## durante la partita nessun nodo nasce. Il nome dello slot 0 e' il nome della
## scena (`SfxHurt`, `SfxLevelUp`), quindi nella scena vera il pool riusa i nodi
## che ci sono gia' e **il totale dei nodi non cambia**; senza scena — porta su
## uno script solo, o test — lo slot viene creato, che e' una volta sola.
func _costruisci_pool(path: String, nome: String) -> Array[AudioStreamPlayer3D]:
	var slots: Array[AudioStreamPlayer3D] = []
	for i in SFX_POOL:
		var node := get_node_or_null(nome if i == 0 else nome + str(i)) as AudioStreamPlayer3D
		if node == null:
			node = AudioStreamPlayer3D.new()
			node.name = nome if i == 0 else nome + str(i)
			add_child(node)
		if node.stream == null:
			node.stream = _stream(path)
		node.finished.connect(_suono_finito.bind(nome, i))
		slots.append(node)
	return slots

## Suona prendendo **uno slot** dal pool. Nessun nodo nasce qui: questo e' il
## punto intero del pool.
func _suona_dal_pool(pool: Array[AudioStreamPlayer3D], scadenze: PackedFloat32Array, path: String) -> void:
	if pool.is_empty():
		return
	var slot := _prendi_slot(scadenze)
	if pool[slot].stream == null:
		# L'asset manca proprio ora: nessun suono, e nessun nodo che occupa
		# l'albero per un silenzio.
		scadenze[slot] = 0.0
		return
	pool[slot].play()
	scadenze[slot] = _vita(pool[slot])
	sfx_emessi += 1

## Quale slot prendere: il primo libero, e se non ce n'e' uno quello **che
## sta per finire prima**. Il `minimo` e' la scadenza piu' piccola, cioe' il
## suono con meno vita davanti: riprendere quello e' la semantica che aveva il
## nodo unico storico, dove un `play()` su un nodo che suona ricomincia.
##
## Il ramo «nessuno libero» e' un ramo che **non cresce**: non c'e' un `while`
## che cerca uno slot e non c'e' un nodo che si crea per farne uno libero. Il
## pool e' chiuso e questo e' il suo unico modo di cedere.
func _prendi_slot(scadenze: PackedFloat32Array) -> int:
	var vicino := -1
	for i in scadenze.size():
		if scadenze[i] <= 0.0:
			return i
		if vicino < 0 or scadenze[i] < scadenze[vicino]:
			vicino = i
	return maxi(vicino, 0)

## Quanto vive uno slot occupato: la lunghezza vera del suono piu' il margone
## `SFX_SICUREZZA`. Un asset assente dà `SFX_SICUREZZA` e niente di piu'.
func _vita(node: AudioStreamPlayer3D) -> float:
	if node.stream == null:
		return SFX_SICUREZZA
	return node.stream.get_length() + SFX_SICUREZZA

## `finished`: il suono e' arrivato in fondo, lo slot torna libero. L'identita'
## e' confrontata perche' il segnale puo' arrivare da uno slot che non e' piu'
## quello che si crede: chiudere lo slot sbagliato taglierebbe un suono che
## qualcuno sta ancora ascoltando.
func _suono_finito(nome: String, slot: int) -> void:
	_scadenza_di(nome)[slot] = 0.0

## La rete per `finished` che non arriva. Gira da `step()`, cioè **mentre il
## nodo e' ancora in albero**: e' l'unico momento in cui liberare lo slot chiude
## il playback, perche' a `_exit_tree()` il nodo e' gia' fuori e `stop()` fa un
## return anticipato.
##
## **Nessuna lista costruita qui**: il ciclo scorre una `PackedFloat32Array`
## gia' fatta, e un valore è un valore, quindi non viene allocato niente nel
## passo di simulazione. La versione che costruiva un `[a, b]` a ogni frame
## era una allocazione per frame e l'ho tolta.
func _chiudi_suoni_scaduti(delta: float) -> void:
	_scadi(_sfx_hurt_scadenza, delta)
	_scadi(_sfx_levelup_scadenza, delta)

func _scadi(scadenze: PackedFloat32Array, delta: float) -> void:
	for i in scadenze.size():
		if scadenze[i] <= 0.0:
			continue
		scadenze[i] -= delta
		if scadenze[i] <= 0.0:
			scadenze[i] = 0.0

## Libera subito **tutti** gli slot dei due pool.
##
## Non è un suono che si ferma: è il tempo che il suono occupa lo slot che
## viene rimesso a zero, quindi il suono **finisce di suonare** e lo slot torna
## libero come dopo `finished`. E' pubblico perche' il test debba poter mettere
## il giocatore nella condizione nota «nessuno slot occupato» prima di aprire
## una finestra di conteggio nodi, ed e' anche quello che `reset_run()` chiude.
func chiudi_suoni() -> void:
	_azzera(_sfx_hurt_scadenza)
	_azzera(_sfx_levelup_scadenza)

func _azzera(scadenze: PackedFloat32Array) -> void:
	for i in scadenze.size():
		scadenze[i] = 0.0

## Le scadenze del pool `nome`, in un solo posto: `nome` arriva da un segnale e
## non puo' essere un riferimento a se' stesso.
func _scadenza_di(nome: String) -> PackedFloat32Array:
	return _sfx_hurt_scadenza if nome == NOME_SFX_HURT else _sfx_levelup_scadenza

## L'asset, o `null` se il file non c'e'. Un test non deve morire perche' manca
## un asset, e un suono che non c'e' non e' un errore da urlare a ogni frame.
static func _stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var res = load(path)
	return res as AudioStream