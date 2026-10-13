extends CanvasLayer
## L'HUD: vite, punteggio, livello, nemici vivi, stato dell'arma, **barra XP,
## contatore d'onda, schermata di game over** e **il pannello delle carte**.
## -ui (m2, m6).
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
## ## Il passo delle barre: `step = 0.0`, dichiarato in `scenes/hud.tscn`
##
## ## Perche' questo difetto e' peggiore di una divisione per zero
##
## Una divisione per zero fa sparire la barra e il test la vede subito, perche'
## il valore disegnato non sta dentro il suo denominatore. Il difetto di
## `Range.step` e' il contrario: **il numero arriva giusto e non si vede**.
## `step` vale 0.01 per default e il nodo arrotonda a scatti quello che gli
## viene scritto, quindi `hud.wave_ratio()` diceva 0.995 mentre
## `Root/WaveBar.value` diceva 1.0. Un HUD che si ispeciona sembra a posto e a
## schermo mente, ed e' per questo che `tests/test_ui.gd` confronta **anche** il
## valore disegnato letto dal nodo e non solo il campo.
##
## Il caso che l'ha fatto scattare e' la barra dell'onda, e la scala la decide
## `-orda`: `wave_bar_ratio()` vale `1 - uccise/popolazione`, e su 200 nemici
## una uccisione vale 0.005, meta' scatto. La barra restava ferma per meta'
## dell'onda. Qui dentro non c'e' nessun `200`, per la stessa ragione per cui in
## `tests/test_ui.gd` non c'e' nessun `200`: la risoluzione del dato non e' di
## questa foglia, e per questo il fix non puo' essere "abbasso lo step a 0.005".
##
## ## Perche' `step = 0.0` su tutte e tre, e non solo su quella dell'onda
##
## Il passo e' una griglia che il nodo impone a un numero che **non e' suo**, e
## qui non e' niente di mio: e' di `-gameplay` (XP) o di `-orda` (vita lo e' del
## player, ma la barra la disegno io). L'HUD e' un display, senza cursore e senza
## animazione: non ha nessuna ragione di ri-arrotondare un numero che gli e'
## stato detto, quindi non arrotonda.
##
## La barra della vita e quella dell'XP **oggi** non soffrono: il loro
## `max_value` e' 100 e la soglia del livello, e uno scatto da 0.01 ci sta
## dentro un decimo di pixel. Quindi si salvano per **scala**, non perche' il
## nodo non arrotondi, e questa e' la ragione per cui il fix e' dichiarato su
## tutte e tre e non solo su quella che falliva: un difetto che sopravvive per
## caso di scala e' un difetto che aspetta la milestone che cambia la scala, ed e'
## esattamente quello che e' successo qui con `Run.population_of`.
##
## Nota sul numero intero: `step = 0.01` **non** vuol dire "uno scatto per HP
## intero", vuol dire "uno scatto per centesimo di HP", quindi sulla barra della
## vita non c'e' nemmeno uno snap a HP intero da difendere. L'intero c'e' gia' e
## lo fa la Label, con `roundi`, che e' il posto giusto per arrotondare: la
## barra disegna il numero vero e la Label dice quello che si legge. Se un giorno
## si volesse la barra ad HP interi, la snap si decide qui e si dichiara, non e'
## un effetto collaterale del default di `Range`.
##
## Il valore vive nella **scena** e non qui perche' `step` e' una proprieta' del
## nodo, come `show_percentage = false` che sta due righe sotto: dichiararlo nel
## codice che *scrive* sul nodo lo renderebbe un valore che si puo' perdere
## senza che nessuno se ne accorga, che e' il difetto che questo file e' fatto
## per evitare.

## ## m6: il pannello delle scelte, e perche' sta in questo file
##
## `choose()` non era chiamato da nessuna parte del gioco (piano sez. 1.6): si
## saliva di livello, si sentiva un suono, e non succedeva niente. Il buco e'
## chiuso qui dentro: quando `progression.pending() > 0` il pannello mostra le
## offerte e **il gioco** sceglie, non il test.
##
## Tre fatti che vengono dall'API di `-gameplay` e non da una scelta di questa
## foglia, e che è percio' che vanno ricommentati qui invece che nel piano:
##
## 1. **Tre offerte, e se ne applicano tre.** `progression.gd:188-190` dice che
##    le altre pending restano. Quindi `pending()` va 3 -> 2 -> 1 -> 0 e il
##    pannello si ritira da solo quando arriva a zero.
## 2. **Gli indici si spostano.** `choose(index)` fa `offers.remove_at(index)`:
##    dopo una scelta l'offerta successiva **scivola** nella posizione
##    precedente. Per questo le carte sono rilegge da `offers` a ogni apertura e
##    non sono mai tenute in testa fra una scelta e l'altra. E' la trappola di
##    questa milestone: un pannello che conserva gli indici di prima applica
##    due volte la stessa carta e una terza offerta non la vede nessuno.
## 3. **Il numero scritto non e' mio.** Nome ed effetto arrivano da
##    `offer_label(index)` e `offer_effect(index)`, dichiarati in
##    `src/core/contracts.gd`. Qui dentro non c'e' nessun "+25%": quel numero
##    e' di `-gameplay` e una copia mente alla prima riga cambiata in `apply()`.
##
## ## Perche' la pausa e' mia e non di `-gameplay`
##
## `get_tree().paused` e' una variabile **globale**: se la tenesse `-gameplay`,
## il simulacro dovrebbe sapere che il pannello e' aperto e il pannello sapere
## che il simulacro ha chiesto la pausa, cioe' due foglie con una variabile
## globale in comune. In mano a `-ui` la pausa e' locale e il criterio n. 2 si
## verifica da un posto solo (piano sez. 3.8).
##
## ## `PROCESS_MODE_ALWAYS`: un pannello che non si puo' cliccare
##
## Con `paused = true` un nodo col process mode di default smette di elaborare
## **e smette di ricevere input**: il pannello resterebbe aperto a schermo e
## non reagirebbe a nessun clic. Il difetto e' invisibile guardandolo, perche'
## sembra funzionante: si vede, e' aperto, e non fa niente. Per questo il
## process mode e' dichiarato nella scena su tre livelli (radice, pannello,
## pulsanti) e non solo sulla radice, e `tests/test_ui.gd` verifica sia la
## dichiarazione sia il fatto.

## ## m7: la barra della salute segue `hp`, e il numero sotto e' quello vero
##
## Fino a m6 la barra era **piatta**, e non perche' mancasse un filo: il filo
## c'era dal primo giorno. `src/render/arena.gd::_health()` legge
## `Game.player.hp`, `_health_max()` legge `Game.player.max_hp`, e `_process` chiama
## `set_state(...)` **ogni frame** (arena.gd:83, 87, 91). Il numero che arriva qui
## era semplicemente sempre quello di prima, perche' nessun codice di gioco
## scriveva `hp`. Quindi qui dentro non c'e' nessuna aritmetica sulla vita da
## correggere: la barra disegna il numero che le e' stato dato e la Label lo
## arrotonda con `roundi`.
##
## Tre cose che qui **non** si decidono, e che `tests/test_ui.gd` verifica invece:
##
## 1. **La metafora e' dell'utente** (RAM disponibile), quindi il testo non e' mio.
##    Nessuna verifica confronta la stringa: confronta i **numeri** che ci sono
##    dentro, cosi' "HP 67 / 100" e "RAM 67% di 100" sono lo stesso HUD, mentre un
##    HUD che scrive 100 mentre il giocatore ha 67 vite e' un HUD che mente. Il
##    numero sotto la barra e' quello che `roundi(health)` produce: e' l'unico
##    arrotondamento dichiarato di questa foglia, e sta nella Label e non nella
##    barra perche' la barra e' un display e la Label e' la cosa che si legge.
## 2. **`max_hp` non e' un numero fisso**: il potenziamento "vita massima" lo alza,
##    quindi il denominatore della barra non puo' essere una costante di questa
##    foglia ne' un `100` scritto qui dentro. Per questo arriva da `set_state` e il
##    test lo confronta con il numero che il giocatore espone adesso, non con una
##    copia.
## 3. **La soglia `LOW_HEALTH_RATIO` non e' una percentuale di danno**: e' il punto
##    in cui il colore cambia, e sta in una costante sola. Il criterio n. 6 di m7
##    chiede che nessun numero di danno sia scritto a mano in due posti: qui non ce
##    n'e' nessuno, e questo file non ne aggiunge.

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

# --- Il pannello delle scelte (m6) ---------------------------------------------
## Il pannello e le carte. I `Button` sono in un array **perche' il numero di
## carte e' un fatto di layout**: quante carte ci stanno sullo schermo lo
## decide questa foglia, quindi lo legge dalla scena e non da una costante.
## Quante **offerte** ci sono, invece, non lo decido io: viene da `pending()`.
var _upgrade_panel: Control = null
var _upgrade_title: Label = null
var _cards: Array[Button] = []
var _card_titles: Array[Label] = []
var _card_effects: Array[Label] = []
## Il pannello e' aperto? Un campo e non `panel.visible`, perche' il criterio n.
## 5 chiede che aprire e chiudere il pannello non crei e non liberi nodi: se il
## flag vivesse solo nel nodo, un pannello che non si vede perche' e' sparito
## sarebbe indistinguibile da uno chiuso.
var _panel_open: bool = false
## La pausa e' **mia**: `true` solo se sono stato io a mettere in pausa
## l'albero. Se il gioco era gia' fermo per un motivo che non e' mio, il pannello
## non si spaccia di essere lui ad aver fermato tutto, e soprattutto non toglie
## una pausa che non ha messo.
var _paused_by_panel: bool = false

var _contract_node: Node = null
var _warned_no_xp: bool = false
var _warned_no_wave: bool = false
## Avviso una volta sola se `offer_label`/`offer_effect` non ci sono ancora: e'
## la superficie che il vertice ha dichiarato in `src/core/contracts.gd` e che
## `-gameplay` scrive. Senza quei due metodi le carte mostrano il loro indice e
## il pannello continua a funzionare, ma il numero sulla carta non e' piu' di
## nessuno: meglio una riga di rumore che una carta con un numero inventato.
var _warned_no_offer_text: bool = false
## Avviso una volta sola se le offerte sono piu' delle carte che ci stanno:
## con piu' di tre il giocatore non potrebbe scegliere tutto quello che il
## livello gli ha dato, che e' una partita che si chiude da sola.
var _warned_too_many_cards: bool = false

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
	_upgrade_panel = get_node_or_null("Root/Upgrade") as Control
	_upgrade_title = get_node_or_null("Root/Upgrade/UpgradeTitle") as Label
	_collect_cards()
	redraw()

## Le carte, per nome in chiaro e in ordine: `Card0`, `Card1`, ... La lista
## finisce quando un nome non esiste piu', quindi **il numero di carte lo dice la
## scena**. Ogni bottone e' collegato al suo indice con `bind(index)`: l'indice
## che arriva al gestore e' quello che il pulsante occupa **adesso**, che e'
## l'unico indice che vale (vedi la nota sugli indici che si spostano).
func _collect_cards() -> void:
	var slot := 0
	while true:
		var path := "Root/Upgrade/Card%d" % slot
		var card := get_node_or_null(path) as Button
		if card == null:
			break
		_cards.append(card)
		_card_titles.append(get_node_or_null(path + "/Title") as Label)
		_card_effects.append(get_node_or_null(path + "/Effect") as Label)
		# Nascoste dal primo frame, come il pannello che le contiene. Non e'
		# cosmetico: `visible` e' la proprieta' che l'interfaccia usa per dire
		# "questa carta c'e'", e una carta "visibile" dentro un pannello
		# invisibile e' una carta che un test direbbe offerta senza che nessuno
		# l'abbia offerta.
		card.visible = false
		if not card.pressed.is_connected(_on_card_pressed):
			card.pressed.connect(_on_card_pressed.bind(slot))
		slot += 1

func _process(_delta: float) -> void:
	refresh()

## Uscendo dall'albero, l'HUD restituisce la pausa che aveva preso.
##
## Non e' un dettaglio: `get_tree().paused` e' una variabile **globale** e un HUD
## che sparisce mentre l'albero e' fermo lascia l'albero fermo per sempre, senza
## piu' nessuno che possa toglierla. Lo si vede in un test che esce subito
## dopo (`--script`): il motore chiude l'albero in pausa e non scarica la coda
## dei messaggi, e il processo esce con `2 ObjectDB instances were leaked` e
## `1 resources still in use`. In gioco non si vede, perche' nessuno chiude
## l'HUD, ma il difetto e' lo stesso: una pausa che nessuno piu' possiede.
func _exit_tree() -> void:
	_set_paused(false)

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

## Il valore e il massimo che la barra della **vita** sta disegnando, letti dal
## nodo e non ricalcolati, come per le altre due.
##
## Esistono perche' la decisione "`step = 0.0` su tutte e tre le barre" non puo'
## restare un commento: se domani qualcuno rimette il default di `Range` solo
## sulla barra della vita, la difetta sarebbe invisibile finche' la scala non
## la espone, e un difetto invisibile non e' un difetto che si e' deciso di
## correggere. Vedi `tests/test_ui.gd::_health_bar`.
func health_bar_value() -> float:
	return _health.value if _health != null else 0.0

func health_bar_max() -> float:
	return _health.max_value if _health != null else 0.0

## Il numero **sotto** la barra della vita, letto dalla Label e non
## ricostruito qui dentro.
##
## Esiste dal primo giorno ma nessuna verifica lo leggeva, e la ragione per cui
## la si legge adesso e' il criterio n. 4 di m7: «il numero sotto la barra sia
## quello vero». Il test non confronta la **stringa** (la metafora e' dell'utente e
## qui il testo non si decide) ma i **numeri** che ci sono dentro: cosi' la
## verifica resta vera qualunque metafora l'utente scelga, e un HUD con un numero
## scritto dentro non la passerebbe lo stesso.
func health_text() -> String:
	return _health_text.text if _health_text != null else ""

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
	_refresh_upgrades(game)

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

# --- Il pannello delle scelte (m6) ---------------------------------------------
#
# `choose()` non era chiamato da nessuna parte del gioco (piano sez. 1.6): uccidi,
# sali di livello, senti un suono, e non succede niente. Qui sotto c'e' il
# chiamante che mancava, e nient'altro: nessuna regola di gioco, nessuna soglia,
# nessun numero di potenziamento scritto a mano.

## Rilegge il contratto e tiene il pannello allineato alle offerte che ci sono
## **adesso**. Chiamata da `refresh()`, quindi ogni frame.
##
## Il pannello e' aperto se e solo se `pending() > 0`: e' la stessa domanda che
## si fa `choose()`, quindi non c'e' una seconda definizione di "quante scelte
## restano" che possa divergere dalla prima.
func _refresh_upgrades(game: Node) -> void:
	_sync_upgrade_panel(_progression(game))

## L'oggetto di progressione, per contratto.
##
## Prima `Game.progression`, che e' il dato che il vertice ha dichiarato per
## questa milestone; poi `Game.player.progression`, che e' la strada che gia'
## usa `_refresh_xp`. Due porte e non una perche' le due possono non coincidere
## durante un restart, e in quel mezzo frame un pannello che sparisce e
## riappare e' meno peggio di uno che non vede piu' le offerte.
func _progression(game: Node) -> Object:
	if game == null:
		return null
	var direct = game.get("progression")
	if direct is Object and is_instance_valid(direct):
		return direct as Object
	var player = game.get("player")
	if not (player is Object) or not is_instance_valid(player):
		return null
	var prog = (player as Object).get("progression")
	if prog is Object and is_instance_valid(prog):
		return prog as Object
	return null

## Quante scelte non ancora prese. `-1` significa "non lo so", che e' diverso da
## zero: zero vuol dire "il livello e' stato speso", non lo sa vuol dire "non ho
## nessuno da cui chiederlo". Il pannello si chiude solo nel primo caso.
func _pending(prog: Object) -> int:
	if prog == null or not prog.has_method("pending"):
		return -1
	var raw = prog.call("pending")
	if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
		return -1
	return maxi(int(raw), 0)

## Apre, riallinea o chiude il pannello. Un posto solo, cosi' la regola "aperto
## se e solo se ci sono scelte" non e' scritta in due punti.
func _sync_upgrade_panel(prog: Object) -> void:
	var left := _pending(prog)
	if left <= 0:
		_close_upgrade_panel()
		return
	_open_upgrade_panel(prog, left)

## Il pannello si apre e mostra **le offerte disponibili, rilette adesso**.
##
## Il ciclo sui pulsanti invece che un `for i in pending()` fisso: quante carte
## ci sono lo dice la scena, e se `-gameplay` offrisse piu' di tre il pannello
## mostra le prime tre e **lo dice**, invece di lasciare il giocatore con delle
## scelte che non puo' prendere e non sapere che esistono.
func _open_upgrade_panel(prog: Object, left: int) -> void:
	var slots := _cards.size()
	if slots <= 0:
		return
	if left > slots and not _warned_too_many_cards:
		_warned_too_many_cards = true
		push_warning("hud: progression.pending()=%d e le carte nello schermo sono %d: "
			% [left, slots]
			+ "le ultime %d offerte non si possono prendere. Il numero di carte e' layout di -ui, in scenes/hud.tscn." % (left - slots))
	for i in slots:
		var card := _cards[i]
		var shown := i < left
		card.visible = shown
		if not shown:
			continue
		# Rilettura a ogni apertura: `choose()` toglie l'offerta scelta dalla
		# lista, quindi tutto quello che segue scivola di una posizione.
		if i < _card_titles.size() and _card_titles[i] != null:
			_card_titles[i].text = _offer_text(prog, i, "offer_label")
		if i < _card_effects.size() and _card_effects[i] != null:
			_card_effects[i].text = _offer_text(prog, i, "offer_effect")
	if _upgrade_title != null:
		_upgrade_title.text = "LEVEL UP - %d SCELTE" % left
	if _upgrade_panel != null and not _upgrade_panel.visible:
		_upgrade_panel.visible = true
	if not _panel_open:
		_panel_open = true
		_set_paused(true)

## Il pannello si ritira da solo quando non restano scelte: `pending() == 0` e'
## l'unico motivo per cui si chiude, quindi il gioco riprende da solo senza che
## nessuno debba ricordarsi di chiamare un metodo.
func _close_upgrade_panel() -> void:
	if _upgrade_panel != null:
		_upgrade_panel.visible = false
	for card in _cards:
		card.visible = false
	if not _panel_open:
		return
	_panel_open = false
	_set_paused(false)

## `get_tree().paused` e' globale, ma **solo se sono stato io** a metterla.
##
## Il caso che copre: il pannello si apre mentre l'albero era gia' fermo per un
## motivo che non e' di questa foglia (un cutscene, un menu futuro). Chiudendo il
## pannello l'HUD non deve togliere una pausa che non ha messo lui, altrimenti
## un pannello che si chiude "riattiva" un gioco che qualcun altro aveva fermato.
func _set_paused(on: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	if on:
		if not tree.paused:
			tree.paused = true
			_paused_by_panel = true
		return
	if _paused_by_panel and tree.paused:
		tree.paused = false
	_paused_by_panel = false

## Il pulsante di una carta e' stato premuto: **qui si chiama `choose()`**, e il
## chiamante e' il pannello, non il test. E' la riga che mancava dal gioco.
##
## `index` e' la posizione **di adesso**, non quella di quando il pannello si e'
## aperto: `choose()` toglie l'offerta scelta dalla lista, quindi l'offerta
## successiva scivola indietro di uno. Il pulsante passa il suo numero di slot e
## il pannello rilegge `offers` subito dopo, quindi le carte rimaste mostrano
## subito quello che resta davvero e non quello che avevano un secondo prima.
func _on_card_pressed(index: int) -> void:
	var tree := get_tree()
	var prog := _progression(_contract())
	if prog == null:
		return
	if not prog.has_method("choose"):
		if not _warned_no_offer_text:
			_warned_no_offer_text = true
			push_warning("hud: Game.progression non espone choose(): nessuna carta puo' essere scelta. "
				+ "Il metodo e' dichiarato in src/core/contracts.gd e lo scrive -gameplay.")
		return
	if tree != null and tree.paused == false and _panel_open:
		# Difensivo: il pannello aperto senza pausa non e' uno stato possibile,
		# e proseguire lascerebbe il gioco che corre sotto un menu aperto.
		_set_paused(true)
	prog.call("choose", index)
	# Rilegge tutto: le carte rimaste cambiano numero e testo, e se erano le
	# ultime il pannello si chiude e toglie la pausa da solo.
	_sync_upgrade_panel(prog)

## Il testo di una carta, preso dal metodo che espone `-gameplay`. Se il metodo
## non c'e' ancora, la carta mostra il suo numero e un avviso: meglio una carta
## che non promette niente di una carta con un numero inventato qui dentro.
func _offer_text(prog: Object, index: int, method: String) -> String:
	if not prog.has_method(method):
		if not _warned_no_offer_text:
			_warned_no_offer_text = true
			push_warning("hud: Game.progression non espone \"%s\": le carte mostrano il loro numero "
				% method
				+ "finche' -gameplay non dichiara il metodo. E' sulla superficie di src/core/contracts.gd.")
		return "CARTA %d" % (index + 1)
	var raw = prog.call(method, index)
	return _as_text(raw)

## Un valore di `-gameplay` diventato testo, senza sapere che tipo ha.
##
## Non e' difensivita' gratuita: il numero che la carta mostra **deve** essere il
## numero che `apply()` usa davvero (criterio n. 4 di m6), e l'unico modo di
## garantirlo e' non trasformare il valore qui dentro. Quindi `str()` per
## quello che e' gia' un numero o una stringa, e per un dizionario tutti i suoi
## valori in ordine di chiave: se domani `-gameplay` cambia la forma del dato,
## il testo cambia con lui invece di restare indietro.
func _as_text(raw: Variant) -> String:
	if raw == null:
		return ""
	if raw is String:
		return raw as String
	if raw is Dictionary:
		var keys: Array = (raw as Dictionary).keys()
		keys.sort()
		var parts: Array[String] = []
		for k in keys:
			parts.append(_as_text((raw as Dictionary)[k]))
		return " ".join(parts)
	return str(raw)

# --- La superficie del pannello, per il test ---------------------------------
#
# Il test non deve cercare i nodi per nome: se il pannello cambiasse
# struttura, il test deve fallire qui e non in silenzio.

## Il pannello delle carte e' **visibile**? Letto dal nodo, come `game_over_visible`.
func upgrade_panel_visible() -> bool:
	return _upgrade_panel != null and _upgrade_panel.visible

## Quante carte ci sono **adesso**: non quante carte ci sono nella scena.
func upgrade_cards_shown() -> int:
	var n := 0
	for card in _cards:
		if card.visible:
			n += 1
	return n

## Il nome della carta `index`, letto dalla Label e non ricalcolato qui.
func upgrade_card_title(index: int) -> String:
	if index < 0 or index >= _card_titles.size():
		return ""
	var label := _card_titles[index]
	return label.text if label != null else ""

## L'effetto della carta `index`, letto dalla Label. E' il numero con cui il
## criterio n. 4 confronta quello che `apply()` fa davvero.
func upgrade_card_effect(index: int) -> String:
	if index < 0 or index >= _card_effects.size():
		return ""
	var label := _card_effects[index]
	return label.text if label != null else ""

## Il percorso del pulsante della carta `index`, che il test usa per premere
## davvero il bottone invece di chiamare `_on_card_pressed`.
func upgrade_card_path(index: int) -> String:
	if index < 0 or index >= _cards.size():
		return ""
	return String(_cards[index].get_path())

## Il process mode **dichiarato** del nodo indicato dal percorso, o -1 se il
## percorso non esiste. Il test ci somma i padri per via di `PROCESS_MODE_INHERIT`
##: dichiarare la radice e non i pulsanti e' un difetto che questa funzione
## rende visibile.
func upgrade_process_mode_at(path: String) -> int:
	var node := get_node_or_null(path)
	return node.process_mode if node != null else -1

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
##
## Quello che qui NON si fa e' arrotondare: il nodo ha `step = 0.0` (dichiarato in
## `scenes/hud.tscn`, perche' perche' e' li'). Vedi la sezione sul passo in testa
## al file.
func _redraw_xp() -> void:
	var need := _finite_or_zero(xp_next)
	var span := maxf(need, XP_MIN_SPAN)
	if _xp_bar != null:
		_xp_bar.max_value = span
		_xp_bar.value = clampf(_finite_or_zero(xp), 0.0, span)
	if _xp_text != null:
		_xp_text.text = "XP %d / %d" % [roundi(_finite_or_zero(xp)), roundi(need)]

## Qui il `step = 0.0` non e' una scelta estetica ma e' il fix: con il default di
## `Range` questa barra arrotondava 0.995 a 1.0 e restava ferma per meta' di
## un'onda da 200 uccisioni. Vedi la sezione sul passo in testa al file.
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
