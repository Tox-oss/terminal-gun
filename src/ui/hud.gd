extends CanvasLayer
## L'HUD: vite, punteggio, livello, nemici vivi, stato dell'arma, **barra XP,
## contatore d'onda e schermata di game over**. -ui (m2).
##
## ## Cosa e' di chi
##
## In m1 questo file era di -arena e l'HUD era "vite, punteggio, livello,
## nemici, arma". In m2 l'HUD ha tre numeri nuovi e -arena ha gia' chiuso il suo
## scope: perche' riaprire un file a un agente che ha finito e' il difetto che
## la regola 1 vieta, `scenes/hud.tscn` e `src/ui/` sono passati a -ui (piano
## sez. 3.3 e 4.1).
##
## **Non tengo nessun dato di gameplay e non decido nulla.** L'XP e la curva dei
## livelli sono di -gameplay (`src/player/progression.gd`), la scala delle onde
## e' di -orda (`src/sim/`). Qui leggo i loro numeri e li disegno: la curva non
## e' mia, il numero d'onda non e' mio, la soglia di "quando finisce
## l'onda" non e' mia.
##
## ## I due modi in cui l'HUD riceve un numero
##
## 1. **`set_state(...)`**, chiamato da `src/render/arena.gd` ogni frame: vite,
##    punteggio, livello, nemici e arma. Firma **invariata** da m1, perche'
##    `tests/test_arena.gd` la chiama e quel test non e' mio.
## 2. **`refresh()`**, che legge il contratto: XP e numero d'onda. Serve perche'
##    nessuna foglia chiama `set_state` con la XP: `-arena` non lavora in m2 e non
##    ha un ramo "XP" da scrivere. Il canale dichiarato per arrivare ai numeri
##    delle altre foglie e' il contratto, ed e' lo stesso che usa `src/render/
##    arena.gd` per i suoi: il campo dati `Game.player` e il campo dati
##    `Game.horde`, non un `get_node("../..")` (piano sez. 5, regola 3).
##
## ## Perche' un HUD che si informa da solo non e' un HUD che conosce le foglie
##
## `refresh()` legge **campi pubblici per nome, con un valore di riserva**, come
## fa gia' `src/render/arena.gd`: se domani `-gameplay` o `-orda` cambiano un
## nome, l'HUD mostra il valore di riserva e resta un HUD, invece di spaccare il
## gioco. Il difetto che resta e' l'inverso, ed e' dichiarato: un nome cambiato
## in silenzio fa mostrare un numero sbagliato. Per questo il campo del numero
## d'onda (`Game.horde.wave`) e' scritto qui sotto in un posto solo, e
## `tests/test_ui.gd` verifica che il numero che l'HUD espone sia quello che
## l'orda espone: il silenzio e' trasformato in un test rosso.
##
## ## Il punto numero uno della milestone 2: la divisione per zero
##
## `xp_ratio()` divide `xp` per `xp_next`. Se `xp_next` arriva a zero il
## risultato e' `INF`, la barra ha una larghezza infinita e il test passa lo
## stesso perche' confronta solo che il valore sia "qualcosa". Per questo la
## guardia e' nel codice di `xp_ratio()` e il test verifica il caso esplicitamente,
## **XP non finito compreso**: un `INF` o un `NaN` che entra da `set_progression`
## esce come `0.0`, non come una barra invisibile.
##
## ## Stringhe a schermo
##
## Solo ASCII: l'HUD viene letto anche nei log di `--headless`, e la console di
## Windows e il pipe di `OS.execute` sono in codepage.

const DEFAULT_MAX_HEALTH := 100.0
## Sotto questa vita la barra diventa rossa: e' l'unico colore che cambia.
const LOW_HEALTH_RATIO := 0.3
## La prima onda e' la 1. Un contatore che parte da 0 non distingue "nessuna
## onda" da "prima onda", e il piano (sez. 1.1, criterio n. 4) chiede che al
## restart si torni a `wave 1`: quindi `wave` non scende mai sotto 1.
const WAVE_FIRST := 1
## Soglia sotto la quale "quanto manca al livello successivo" non e' un numero
## su cui dividere. Non e' il valore con cui si disegna: e' il tetto sotto il
## quale si smette di dividere.
const XP_MIN_SPAN := 0.0001

# --- Numeri di m1. Firme e campi invariati: li chiama tests/test_arena.gd -----
var health: float = DEFAULT_MAX_HEALTH
var health_max: float = DEFAULT_MAX_HEALTH
var score: int = 0
var level: int = 1
var weapon_text: String = "-"
var enemies: int = 0

# --- I tre numeri di m2 -------------------------------------------------------
## XP non ancora speso, come lo tiene `-gameplay` in `progression.xp`.
var xp: float = 0.0
## XP che mancano al livello successivo, come `progression.xp_to_next()`. Il
## valore di riserva e' **zero**, non uno: se nessuno dice quanta XP manca, la
## barra non e' in grado di dire niente e lo dice showing zero invece di
## inventare un denominatore.
var xp_next: float = 0.0
## Numero dell'onda, di `-orda`. Parte da `WAVE_FIRST` e non scende sotto.
var wave: int = WAVE_FIRST
## La barra dell'onda, di `-orda`: 1.0 all'inizio dell'onda, 0.0 quando e'
## finita. Parte da 1.0 e non da 0.0 perche' l'HUD nasce all'inizio di un'onda, e
## un HUD che nasce con la barra vuota sembra un'onda gia' finita.
var wave_progress: float = 1.0
## `-orda` dice che la partita e' finita (`horde.is_game_over()`). Secondo
## cancello accanto alla vita a zero: oggi i due dicono la stessa cosa, ma uno dei
## due puo' mancare e la schermata deve essere quella che il gioco dice.
var round_over: bool = false
## La partita e' finita? Di `-gameplay`. Se `false` ma la vita e' a zero, la
## schermata compare lo stesso: l'HUD conosce la vita perche' `set_state` gliela
## da, e non deve aspettare che qualcuno si ricordi di chiamare un setter.
var game_over: bool = false
## Onda raggiunta al momento della morte, per la schermata. Copiata quando la
## schermata compare, non riletta ogni frame: dopo la morte l'onda non conta
## piu' niente e un ricalco darebbe un testo diverso dal momento in cui e' morto.
var wave_at_death: int = WAVE_FIRST

var _health: ProgressBar = null
var _health_text: Label = null
var _score: Label = null
var _level: Label = null
var _weapon: Label = null
var _enemies: Label = null
var _xp_bar: ProgressBar = null
var _xp_text: Label = null
var _wave: Label = null
var _wave_bar: ProgressBar = null
var _game_over_panel: Control = null
var _game_over_text: Label = null

var _contract_node: Node = null
var _warned_no_xp: bool = false
var _warned_no_wave: bool = false

func _ready() -> void:
	# Percorsi espliciti invece di `%Nome`: se una Label si cancella, l'HUD
	# deve mostrare un HUD incompleto, non spegnersi con un errore.
	_health = get_node_or_null("Root/Health") as ProgressBar
	_health_text = get_node_or_null("Root/HealthText") as Label
	_score = get_node_or_null("Root/Score") as Label
	_level = get_node_or_null("Root/Level") as Label
	_weapon = get_node_or_null("Root/Weapon") as Label
	_enemies = get_node_or_null("Root/Enemies") as Label
	# I quattro nodi di m2. Nomi in chiaro, non `%X`: vedi sopra.
	_xp_bar = get_node_or_null("Root/Xp") as ProgressBar
	_xp_text = get_node_or_null("Root/XpText") as Label
	_wave = get_node_or_null("Root/Wave") as Label
	_wave_bar = get_node_or_null("Root/WaveBar") as ProgressBar
	_game_over_panel = get_node_or_null("Root/GameOver") as Control
	_game_over_text = get_node_or_null("Root/GameOver/GameOverText") as Label
	redraw()

func _process(_delta: float) -> void:
	refresh()

## Il punto d'ingresso di arena. Numeri, non nodi. Firma di m1, **invariata**:
## `tests/test_arena.gd` la chiama con sei argomenti e quel test non e' mio.
func set_state(p_health: float, p_health_max: float, p_score: int,
		p_weapon_text: String, p_enemies: int, p_level: int) -> void:
	health = p_health
	# Una `max_hp` a zero o negativo viene dal chiamante sbagliato: senza il
	# tetto qui sotto, `health / health_max` darebbe un infinito e la barra
	# mostrerebbe numeri a caso.
	health_max = maxf(p_health_max, 0.0001)
	score = p_score
	weapon_text = p_weapon_text
	enemies = p_enemies
	level = p_level
	redraw()

## XP e livello, da chi conosce la progressione. `p_level` e' facoltativo perche'
## il livello arriva gia' da `set_state`: chi chiama questo metodo di solito ha
## solo la barra da aggiornare.
##
## La firma ha tre argomenti con il terzo opzionale, cosi' un chiamante che ha
## solo i due numeri della barra non deve mentire scrivendo `1` come livello.
func set_progression(p_xp: float, p_xp_next: float, p_level: int = -1) -> void:
	_apply_xp(p_xp, p_xp_next)
	if p_level > 0:
		level = p_level
	redraw()

## Il numero dell'onda. Clampato a `WAVE_FIRST`: un'onda 0 o un'onda negativa
## non sono uno stato del gioco, sono un chiamante sbagliato, e mostrarle
## significa far leggere "nessuna onda" dove l'HUD non lo sa.
func set_wave(p_wave: int) -> void:
	wave = maxi(p_wave, WAVE_FIRST)
	redraw()

## La barra dell'onda, da 0.0 a 1.0: 1.0 all'inizio dell'onda, 0.0 quando e'
## finita. Il numero e' di `-orda` (`horde.wave_bar_ratio()`) e non e' ricostruito
## qui: una barra dell'onda fatta con `horde.count / population` sarebbe una
## **seconda** definizione di "quanto manca all'onda", e le due divergerebbero
## senza che nessuno lo notasse.
func set_wave_progress(p_ratio: float) -> void:
	wave_progress = clampf(_finite_or_zero(p_ratio), 0.0, 1.0)
	redraw()

## La partita e' finita. Accettare il chiamante che lo sa e' una courtesy, non un
## requisito: vedi `is_game_over()`.
func set_game_over(p_over: bool) -> void:
	game_over = p_over
	redraw()

## 0.0 a 1.0, sempre. Anche con vite a zero o negative.
func health_ratio() -> float:
	return clampf(health / maxf(health_max, 0.0001), 0.0, 1.0)

## Quanto del livello corrente e' fatto, da 0.0 a 1.0, **sempre finito**.
##
## Le due guardie sono il criterio n. 2 di m2 reso codice:
##   - `xp_next` non finito o non positivo: non si divide. Si restituisce 0.0,
##     cioe' "l'HUD non sa quanto manca", che e' un numero che una barra puo'
##     disegnare. `INF` qui dentro diventerebbe una barra con larghezza infinita.
##   - `xp` non finito: diventa 0.0. Un `NaN` propagato qui dentro resterebbe
##     `NaN` anche dopo `clampf`, perche' ogni confronto con `NaN` e' falso: e'
##     il caso che fa fallire `h.finite()` su un HUD che sembra funzionare.
func xp_ratio() -> float:
	var have := _finite_or_zero(xp)
	var need := _finite_or_zero(xp_next)
	if need <= 0.0:
		return 0.0
	return clampf(have / need, 0.0, 1.0)

## La barra dell'onda, da 0.0 a 1.0, **sempre finita**. Come per la barra
## dell'XP la guardia e' nel codice e non nella speranza: qui il rischio e' il
## contrario, cioe' un numero non finito che lascerebbe la barra a meta' strada con
## un valore che non e' mai stato raggiunto.
func wave_ratio() -> float:
	return clampf(_finite_or_zero(wave_progress), 0.0, 1.0)

## Il valore che la barra dell'onda sta disegnando, letto dal nodo.
func wave_bar_value() -> float:
	return _wave_bar.value if _wave_bar != null else 0.0

## Cosa c'e' scritto, per il test: leggo le Label invece di ricostruire qui la
## stringa che metterei dentro.
func score_text() -> String:
	return _score.text if _score != null else ""

func enemy_text() -> String:
	return _enemies.text if _enemies != null else ""

func weapon_state_text() -> String:
	return _weapon.text if _weapon != null else ""

func xp_text() -> String:
	return _xp_text.text if _xp_text != null else ""

func wave_text() -> String:
	return _wave.text if _wave != null else ""

## Il numero d'onda come intero, non come stringa: e' il numero che il piano
## chiede (`wave 1` al riavvio) ed e' quello che un confronto puo' fare.
func wave_number() -> int:
	return wave

## Il valore che la barra sta davvero disegnando, letto dal nodo e non
## ricalcolato: serve al test per verificare che il numero e il disegno dicano
## la stessa cosa.
func xp_bar_value() -> float:
	return _xp_bar.value if _xp_bar != null else 0.0

func xp_bar_max() -> float:
	return _xp_bar.max_value if _xp_bar != null else 0.0

## La schermata di game over e' **visibile**? Letto dal nodo, non dal flag: se il
## flag dice `true` e il pannello non si vede, l'HUD e' rotto e il test deve
## accorgersene.
func game_over_visible() -> bool:
	return _game_over_panel != null and _game_over_panel.visible

## La partita e' finita per l'HUD se **uno** di tre lo dice: un chiamante esplicito,
## la vita a zero (che l'HUD conosce gia' perche' `set_state` gliela da), o la
## simulazione (`Game.horde.is_game_over()`). Una schermata che compare solo se il
## chiamante si ricorda di chiamare un setter e' una schermata che nella partita
## vera compare a meta' delle morti.
func is_game_over() -> bool:
	return game_over or round_over or health <= 0.0

# --- Il contratto, letto per nome e con riserva -------------------------------

## Ricalcola i numeri che l'HUD prende dal contratto. `_process` la chiama ogni
## frame; il test la chiama a mano, perche' in un test sotto `--script` non
## esiste un frame da aspettare e aspettarlo renderebbe il test dipendente dal
## tempo.
func refresh() -> void:
	var game := _contract()
	if game == null:
		return
	_refresh_xp(game)
	_refresh_wave(game)

## XP e soglia del livello da `Game.player.progression`, che e' di -gameplay.
## Entrambi opzionali: se non ci sono, il valore di riserva resta e l'HUD non si
## accorge di niente, che e' il comportamento giusto per una foglia che non
## possiede quei numeri.
func _refresh_xp(game: Node) -> void:
	var player = game.get("player")
	if not (player is Object):
		return
	var progression = (player as Object).get("progression")
	if not (progression is Object):
		return
	var prog := progression as Object

	var raw_xp = prog.get("xp")
	var have := 0.0
	if typeof(raw_xp) == TYPE_FLOAT or typeof(raw_xp) == TYPE_INT:
		have = float(raw_xp)
	else:
		if not _warned_no_xp:
			_warned_no_xp = true
			push_warning("hud: Game.player.progression non espone \"xp\": la barra resta a zero finche' -gameplay non lo dichiara")

	# La soglia e' un metodo (`xp_to_next`), non un campo: si chiama solo se c'e',
	# e con `has_method` perche' `call()` su un nome assente stampa un errore.
	var need := 0.0
	if prog.has_method("xp_to_next"):
		var raw_need = prog.call("xp_to_next")
		if typeof(raw_need) == TYPE_FLOAT or typeof(raw_need) == TYPE_INT:
			need = float(raw_need)

	if have == xp and need == xp_next:
		return
	_apply_xp(have, need)
	redraw()

## Il numero d'onda da `Game.horde`, che e' di -orda.
##
## ⚠ Il **nome del campo e' il punto di accoppiamento** di questa foglia con
## `-orda`, ed e' qui in un posto solo perche' un nome diverso si cambi in una
## riga e non in quattro. Se `Game.horde` non espone `wave`, l'HUD tiene `1` e lo
## dice una volta sola con un `push_warning`: meglio una riga di rumore che un
## contatore fermo a 1 senza che nessuno lo noti.
func _refresh_wave(game: Node) -> void:
	var horde = game.get("horde")
	if not (horde is Object):
		return
	if not is_instance_valid(horde):
		# L'orda precedente e' stata liberata e il contratto punta ancora a lei:
		# succede a ogni restart, se chi fa il restart non pulisce il contratto.
		# Chiamare un metodo su un'istanza liberata stampa un errore a ogni frame,
		# quindi questa guardia e' quello che tiene pulito il log del gioco.
		return
	var raw_wave = (horde as Object).get("wave")
	if typeof(raw_wave) == TYPE_INT or typeof(raw_wave) == TYPE_FLOAT:
		var value := maxi(int(raw_wave), WAVE_FIRST)
		if value != wave:
			set_wave(value)
	else:
		if not _warned_no_wave:
			_warned_no_wave = true
			push_warning("hud: Game.horde non espone \"wave\": il contatore resta su %d finche' -orda non dichiara il campo. Il nome e' in _refresh_wave" % WAVE_FIRST)
	# La barra e lo stato della partita si continuano a leggere anche se `wave`
	# non c'e': sono tre API diverse di `-orda` e una mancante non deve
	# spegnere le altre due.
	_refresh_wave_progress(horde as Object)
	_refresh_round(horde as Object)

## La barra dell'onda. Numero di `-orda` (`wave_bar_ratio()`), non ricostruito
## qui. Solo se il valore e' un numero **finito**: un valore non finito lascia
## sul posto quello buono invece di far saltare la barra a caso.
func _refresh_wave_progress(horde: Object) -> void:
	if not horde.has_method("wave_bar_ratio"):
		return
	var raw = horde.call("wave_bar_ratio")
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		return
	var value := float(raw)
	if not is_finite(value) or value == wave_progress:
		return
	wave_progress = clampf(value, 0.0, 1.0)
	redraw()

## La partita e' finita secondo `-orda`. Con `has_method` perche' `call()` su un
## nome assente stampa un errore a ogni frame, e un errore a ogni frame e' il
## modo piu' economico di rendere il gioco illeggibile.
func _refresh_round(horde: Object) -> void:
	if not horde.has_method("is_game_over"):
		return
	var over: bool = horde.call("is_game_over")
	if over == round_over:
		return
	round_over = over
	redraw()

# --- Disegno ------------------------------------------------------------------

func redraw() -> void:
	var ratio := health_ratio()
	if _health != null:
		_health.max_value = health_max
		_health.value = clampf(health, 0.0, health_max)
	if _health_text != null:
		_health_text.text = "HP %d / %d" % [roundi(health), roundi(health_max)]
		_health_text.modulate = Color(1.0, 0.45, 0.4) if ratio <= LOW_HEALTH_RATIO else Color.WHITE
	if _score != null:
		_score.text = "SCORE %d" % score
	if _level != null:
		_level.text = "LV %d" % level
	if _weapon != null:
		_weapon.text = "WEAPON %s" % weapon_text
	if _enemies != null:
		_enemies.text = "ENEMIES %d" % enemies
	_redraw_xp()
	_redraw_wave()
	_redraw_game_over()

## La barra dell'XP. `max_value` prende il denominatore **finito e positivo** e
## `value` viene clampato dentro: e' il secondo posto in cui una divisione per
## zero fa un HUD che non si vede, perche' qui non si divide ma si moltiplica per
## la larghezza del controllo.
func _redraw_xp() -> void:
	var need := _finite_or_zero(xp_next)
	var span := maxf(need, XP_MIN_SPAN)
	if _xp_bar != null:
		_xp_bar.max_value = span
		_xp_bar.value = clampf(_finite_or_zero(xp), 0.0, span)
	if _xp_text != null:
		_xp_text.text = "XP %d / %d" % [roundi(_finite_or_zero(xp)), roundi(need)]

func _redraw_wave() -> void:
	if _wave != null:
		_wave.text = "WAVE %d" % wave
	if _wave_bar != null:
		_wave_bar.max_value = 1.0
		_wave_bar.value = wave_ratio()

func _redraw_game_over() -> void:
	var over := is_game_over()
	if over and not game_over_visible():
		# Copiata **una volta sola**, al momento in cui la schermata compare.
		wave_at_death = wave
	if _game_over_panel != null:
		_game_over_panel.visible = over
	if _game_over_text != null:
		_game_over_text.text = "GAME OVER - WAVE %d" % wave_at_death

# --- Interno ------------------------------------------------------------------

## Applica i due numeri dell'XP senza ridisegnare: `set_progression` e
## `_refresh_xp` li mettono in campo e ridisegnano una volta sola.
func _apply_xp(p_xp: float, p_xp_next: float) -> void:
	xp = _finite_or_zero(p_xp)
	xp_next = _finite_or_zero(p_xp_next)

## Un numero non finito diventa zero. `is_finite` e' una funzione globale di
## GDScript: qui non si scrive `xp.is_finite()` perche' `INF.is_finite()` su un
## float funziona, ma `clampf(NAN, 0.0, 1.0)` restituisce `NAN` e li vorremmo
## eliminati **prima** del clamp, non dopo.
func _finite_or_zero(value: float) -> float:
	return 0.0 if not is_finite(value) else value

## Il contratto, come nodo, e non come identificatore nudo `Game`: vedi la nota
## di `src/sim/horde.gd`. Questo file viene compilato anche dai processi di test
## lanciati con `--script`, dove l'autoload non e' fra le costanti globali di
## GDScript. Il nodo che si ottiene e' lo stesso identico singleton: si aggira la
## compilazione, non il contratto (piano sez. 5.3).
func _contract() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	if _contract_node == null:
		_contract_node = tree.root.get_node_or_null("Game")
	return _contract_node
