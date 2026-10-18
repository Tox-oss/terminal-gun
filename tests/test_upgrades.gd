extends SceneTree
## Criterio n. 3 della milestone 2: **un potenziamento cambia il comportamento
## misurabile**. -gameplay, `tests/test_upgrades.gd`. Piano sez. 1.1, riga 3.
##
## Il criterio, tradotto in numeri:
##
##   1. applicato un potenziamento, il **danno o la cadenza cambiano di almeno
##      il 2%**, misurato sulla scena vera;
##   2. **un potenziamento che non muove nessun numero e' decorativo e fallisce**:
##      ognuno degli id dichiarati da `progression.gd` deve spostare qualcosa di
##      almeno il 2%;
##   3. un id **inesistente** non applica niente e non muove niente;
##   4. `weapon.reset()` riporta **tutto** alla regolazione di partenza.
##
## ## Perche' nessuna misura e' la lettura di un campo
##
## Il giro precedente aveva gia' provato la strada "leggere `weapon.damage` prima
## e dopo": e' una prova che non prova niente, perche' il numero e' li' per
## dichiarazione. Qui ogni voce e' un numero che **esce dal gioco**:
##
##   danno       quanti HP ha perso davvero l'orda a un colpo (somma degli HP
##               dell'orda prima e dopo). Vale **solo se nessuno e' morto** nel
##               mezzo, perche' `_kill` toglie il nemico con lo scambio con
##               l'ultimo e la somma cambierebbe di due cose insieme: quindi il
##               test controlla `horde.count` e `horde.kills` e se qualcuno muore
##               **non usa la misura** e riprova;
##   cadenza     quanti passi servono al sesto colpo dell'arma che spara da sola;
##   corsa       metri percorsi dal giocatore in 120 passi con un input noto;
##   velocita'   metri che copre in un passo il proiettile che l'arma ha appena
##               sparato;
##   spinta      quanto slancio in m/s ha preso davvero il nemico colpito, letto
##               come differenza fra la sua velocita' prima e dopo il colpo (la
##               differenza, **non** la velocita': il nemico insegue gia');
##   vita        quanti colpi da 10 il giocatore regge prima di morire;
##   perforante  quanti nemici un **solo** proiettile colpisce;
##   gittata     per quanti passi un proiettile sopravvive in un campo vuoto.
##
## ## Il poligono: perche' l'orda viene riordinata
##
## Le misure della spinta e della perforante darebbero numeri diversi a seconda
## della specie colpita (resistenza 0 / 0.20 / 0.55 / 0.90) e a seconda di chi
## sta dietro: su un'orda piena che si muove, "spinta" e "perforante" sarebbero
## rumore, e un potenziamento decorativo passerebbe il confronto per caso.
## Quindi il test **riordina l'orda in un poligono**: un bersaglio grosso davanti
## (un bruto con vita altissima, che non muore mai durante le misure) e una fila
## di otto bersagli dietro, e tutto il resto dell'orda portata a 39 m. Si toccano
## i tre array pubblici che il piano dichiara come "massa" di -orda, e si fa
## **un** passo di simulazione perche' la griglia spaziale venga ricostruita:
## `nearest_enemy` su una griglia vecchia darebbe indici sbagliati e ogni misura
## sarebbe falsa.
##
## Il numero di nemici di cui il poligono ha bisogno e' `1 + N_BERSAGLI` = 9, e
## viene controllato come **precondizione** (l'unico numero scritto a mano in
## questa sezione, e con il perche' nel messaggio): e' il numero di slot che il
## poligono scrive, non la dimensione della curva di `-orda`.
##
## Questo e' impalcatura, non sostituzione: la scena e' quella vera, l'arma e'
## quella vera, i proiettili sono quelli veri, il danno passa da
## `Game.damage_enemy` e la mira da `Game.nearest_enemy`. Non e' un doppio.
##
## ## La trappola del `const preload` (piano sez. 5.3)
## `scenes/arena_main.tscn` si carica con `load()` **dentro il corpo del test**,
## mai in `const`. `res://src/sim/run.gd` invece e' un `RefCounted` che non
## nomina mai l'identificatore nudo `Game`: li' il `const preload` e' sicuro, ed
## e' la strada che gia' usano `tests/test_orda.gd` e `tests/test_gameloop.gd`
## per non copiare la tabella delle onde.
##
## ## Perche' qui non c'e' piu' nessun numero scritto a mano
##
## Fino a m4 questo file asseriva `count == 200` all'avvio e `count == 200` dopo
## il poligono. Poi `-orda` ha messo la curva per onda in `src/sim/run.gd` e
## l'avvio e' sceso a `Run.POP_BASE`: la cifra e' cambiata, il criterio no.
## Sostituire `200` con `25` avrebbe fatto passare il gate e lasciato un test da
## riscrivere alla prossima milestone che tocca la curva. Quindi l'avvio e'
## asserito come **relazione** (`_popolazione_davvio`) e il poligono asserisce
## `count` **invariato**: il numero esce dalla misura ed e' stampato.
##
## Stringhe a schermo solo ASCII: la console di Windows e il pipe di
## `OS.execute` sono in codepage e mangiano gli accenti.

const H = preload("res://tools/test_harness.gd")
## La tabella delle onde di -orda, letta a runtime. Nessuna copia qui dentro.
const Run = preload("res://src/sim/run.gd")

const DT := 1.0 / 60.0
const ARENA_SCENE := "res://scenes/arena_main.tscn"
const NODO_HORDE := "Horde"
const NODO_PLAYER := "Player"

## Tetto del criterio: 2%. Sotto questa soglia una variazione non e' una
## variazione, e' arrotondamento.
const SOGLIA := 0.02

## Punti vita persi a ogni colpo nella misura `vita`, cioe' il denominatore con
## cui i colpi contati diventano punti vita. Serve a confrontare l'incremento
## secco della carta «Vita massima +20» con una misura che conta **colpi**:
## la conversione e' dichiarata qui e non scritta dentro l'asserzione.
const DANNO_PER_COLPO := 10.0

## Le due misure contate in **frame interi**, dove un passo di confine sposta il
## numero di `1 / N`. Le altre (danno, corsa, velocita', spinta) sono continue e
## non hanno quell'errore. Vedi `_tol_voce`.
const MISURE_IN_FRAME := ["cadenza", "gittata"]

## Tolleranza del confronto fra una percentuale **misurata** e il numero scritto
## sulla carta. La carta arrotonda all'intero, quindi mezzo punto e' gia' dentro
## il numero che viene confrontato: il resto non e' tolleranza inventata qui.
const TOL_PERCENTUALE := 0.5

## Quanti colpi si contano per la cadenza. Sei e' il minimo che tiene la misura
## lontana dal bordo di un passo: a `fire_interval` 0.35 il sesto colpo arriva
## al passo 106 e con il -15% del potenziamento al passo 91.
const COLPI_CADENZA := 6
## Passi di corsa della misura `corsa`: a 7 m/s fanno 14 m, abbastanza sotto il
## muro (28 - 0.8) da non tagliarlo, e abbastanza da non stare nella spinta.
const PASSI_CORSA := 120

## Distanza del bersaglio grosso, in metri dal giocatore al centro.
const RAGGIO_BERSAGLIO := 4.0
## Passo della fila di bersagli dietro. Il secondo e' a 12 m: con la gittata di
## codice (26 m/s per 1.4 s = 36 m) e' abbastanza vicino da essere colpito e
## abbastanza lontano da essere raggiunto insieme al primo.
const PASSO_BERSAGLI := 8.0
## Quanti bersagli dietro. Bastano due per provare la perforante: uno resta
## colpito, con la perforante sale a due.
const N_BERSAGLI := 8
## Vita del bersaglio grosso. Non muore mai durante le misure: e' il motivo per
## cui la somma degli HP dell'orda e' confrontabile, e nessuna misura di questa
## sezione dipende da un nemico che sparisce. `float32` la rappresenta esatta.
const VITA_BERSAGLIO := 100000.0
## Vita dei bersagli della fila. **Immortale anche questa**: nessuna misura di
## questo file uccide un nemico, e un'uccisione porterebbe XP, salirebbe un
## livello e rullerebbe le offerte, confonendo la sezione delle scelte con un
## numero che questo test non ha prodotto. La perforante si conta con
## `horde.hit_count`, che conta le chiamate a `damage_enemy` e non le morti.
const VITA_BERSAGLIO_FILA := 100000.0
## Dove finisce il resto dell'orda: 39 m, oltre la gittata di un proiettile
## (36 m) e dentro l'estensione della griglia (28 * 1.5 = 42 m).
const LONTANO := 39.0

## Quale voce deve muoversi per ciascun potenziamento. Non e' una copia dei
## numeri di `progression.gd`: e' il ponte fra "id dichiarato" e "comportamento
## misurato", e senza il ponte un id che toccasse un campo che nessuno guarda
## passerebbe tutto.
const MISURA_DI := {
	"damage": "danno",
	"fire_rate": "cadenza",
	"move_speed": "corsa",
	"projectile_speed": "velocita",
	"knockback": "spinta",
	"pierce": "perforante",
	"vitality": "vita",
	"range": "gittata",
}
## Ordine di stampa della tabella delle misure.
const MISURE := ["danno", "cadenza", "corsa", "velocita", "spinta", "perforante", "vita", "gittata"]

var _h
var _ran := false
var _t0 := 0

var _arena: Node3D = null
var _game: Node
var _horde: Node
var _player: Node3D
var _weapon
var _prog
var _pool

## Nemici vivi **misurati** all'avvio della scena vera. E' il riferimento del
## poligono ("il riordino non ha ammazzato nessuno") e vale qualunque curva
## scelga `-orda`: nessuna cifra scritta a mano. `-1` = non misurato.
var _vivi_avvio: int = -1

## Quanti potenziamenti hanno emesso `upgrade_applied` dall'ultimo azzeramento.
## Serve al controllo negativo: un id inesistente che emettesse il segnale
## mentirebbe all'interfaccia anche senza toccare nessun numero.
var _emessi := 0

func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	_h = H.new()

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	var h = _h
	_game = root.get_node_or_null("Game")
	if not h.check(_game != null,
			"l'autoload Game non e' stato istanziato: nessun test delle foglie puo' partire"):
		quit(h.finish("test_upgrades"))
		return true

	var arena = _apri_arena(h)
	if arena != null:
		_prova(h)
		_chiudi(arena)

	print("upgrades: test terminato in %d ms" % (Time.get_ticks_msec() - _t0))
	quit(h.finish("test_upgrades"))
	return true

# --- Il corpo ------------------------------------------------------------------

func _prova(h) -> void:
	_horde = _arena.get_node_or_null(NODO_HORDE)
	_player = _arena.get_node_or_null(NODO_PLAYER)
	if not h.check(_horde != null,
			"la scena vera deve avere il nodo \"%s\" (src/sim/horde.gd)" % NODO_HORDE):
		return
	if not h.check(_player != null,
			"la scena vera deve avere il nodo \"%s\" (src/player/player.gd)" % NODO_PLAYER):
		return
	_weapon = _player.weapon
	if not h.check(_weapon != null, "il giocatore della scena vera ha un'arma"):
		return
	_pool = _weapon.pool
	if not h.check(_pool != null, "l'arma ha il pool dei proiettili"):
		return
	_prog = _game.get("progression")
	if not h.check(_prog != null,
			"Game.progression e' registrato: senza, nessun potenziamento e' raggiungibile per contratto"):
		return
	h.check(_prog == _player.progression, "Game.progression e' la progressione del giocatore")

	# Il passo di simulazione lo guida questo test, a mano: senza questo un tick
	# di fisica fra l'avvio della scena e il primo `_process` sposterebbe i nemici
	# una volta senza che nessuno l'abbia chiesto.
	_horde.set_physics_process(false)
	_player.set_physics_process(false)
	_player.drive_manually()
	_player.upgrade_applied.connect(func(_id: String) -> void: _emessi += 1)

	_popolazione_davvio(h, _horde)
	h.eq(int(_horde.wave), 1, "sull'onda 1, dove la scala delle vite e' 1.0")

	if not _poligono(h):
		return
	_tutte(h)
	_uno_per_uno(h)
	_id_inesistente(h)
	_ritorno_alla_base(h)
	_scelta_del_livello(h)
	_descrizione_misurata(h)
	_indice_relativo_a_offers(h)

# --- La popolazione d'avvio: una relazione, non una cifra ----------------------

## Cosa resta vero qualunque numero scelga `-orda` domani, e cosa il criterio
## chiede davvero (che l'avvio sia **coerente con la curva dichiarata**, non che
## la curva valga un numero fissato da questo test):
##
##     count      == population                il campo e' pieno al suo tetto
##     population == Run.population_of(1)      il tetto e' quello che chiede la curva
##
## Il numero **esce** dalla misura ed e' stampato e messo in `_vivi_avvio`, che e'
## il riferimento del poligono: nessuna cifra scritta a mano nell'asserzione.
## Fino a m4 qui c'era `count == 200`; sostituire quella riga con `count == 25`
## avrebbe fatto passare il gate e lasciato un test da riscrivere alla prossima
## milestone che tocca la curva, che e' gia' successo.
##
## Il secondo `check` e' voluto: `population` deve essere **positivo**, altrimenti
## la prima relazione (`count == population == 0`) passerebbe su un'orda vuota.
func _popolazione_davvio(h, horde) -> void:
	var tetto: Variant = horde.get("population")
	if not h.check(typeof(tetto) == TYPE_INT,
			"l'orda dichiara il campo `population`: senza, non si sa a cosa debba essere pieno"):
		_vivi_avvio = -1
		return
	_vivi_avvio = int(horde.count)
	h.eq(_vivi_avvio, int(tetto),
		"l'orda della scena vera parte piena al suo tetto di popolazione")
	h.eq(int(tetto), Run.population_of(1),
		"e il tetto e' quello che chiede la curva delle onde sull'onda 1 (Run.population_of)")
	h.check(int(tetto) > 0,
		"un'onda che parte vuota non e' un'onda: %d nemici vivi" % int(tetto))
	print("upgrades: avvio, onda %d, %d nemici vivi = tetto di popolazione %d "
		% [int(horde.wave), _vivi_avvio, int(tetto)]
		+ "(Run.population_of(1) = %d, Run.POP_BASE = %d)" % [Run.population_of(1), Run.POP_BASE])

# --- Il poligono ---------------------------------------------------------------

## Riordina l'orda in una posizione di tiro ripetibile. Vedi la nota lunga in
## testa al file: e' impalcatura dichiarata, e senza la griglia ricostruita
## `nearest_enemy` darebbe indici di una disposizione che non esiste piu'.
##
## Ritorna `false` solo se il campo e' troppo piccolo per il poligono: e' l'unico
## numero scritto a mano qui dentro (`1 + N_BERSAGLI` slot da riempire), ed e'
## una **precondizione** con il perche' scritto, non una stima della curva di
## `-orda`. Senza questo controllo, una curva che scendesse sotto 9 farebbe
## scrivere fuori dagli array e le misure che vengono dopo sarebbero tutte
## numeri inventati.
func _poligono(h) -> bool:
	var slot := 1 + N_BERSAGLI
	if not h.check(_vivi_avvio >= slot,
			"l'orda deve avere almeno %d nemici per il poligono (1 bersaglio + %d fila), ne' ha %d: Run.population_of(1) = %d"
			% [slot, N_BERSAGLI, _vivi_avvio, Run.population_of(1)]):
		return false
	var tr: PackedVector3Array = _horde.transforms.duplicate()
	var kin: PackedInt32Array = _horde.kinds.duplicate()
	var hp: PackedFloat32Array = _horde.hp.duplicate()
	for i in _horde.count:
		tr[i] = Vector3(LONTANO, 0.9, 0.0)
		kin[i] = 0
		hp[i] = VITA_BERSAGLIO_FILA
	tr[0] = Vector3(RAGGIO_BERSAGLIO, 0.9, 0.0)
	kin[0] = 2
	hp[0] = VITA_BERSAGLIO
	for j in N_BERSAGLI:
		tr[1 + j] = Vector3(RAGGIO_BERSAGLIO + PASSO_BERSAGLI * float(1 + j), 0.9, 0.0)
	_horde.transforms = tr
	_horde.kinds = kin
	_horde.hp = hp

	# Un passo di simulazione: ricostruisce la griglia spaziale. Senza, il
	# `nearest_enemy` dell'arma cercherebbe nella disposizione di prima del
	# riordino e ogni misura sarebbe falsa.
	_horde.step(DT)

	# Gli indici delle specie sono quelli di `src/sim/enemy.gd` e non sono
	# ricopiati qui: vengono verificati con l'accessore **di -orda**, e **dopo**
	# l'assegnazione (prima direbbero solo quali specie erano gia' li').
	h.eq(str(_horde.kind_name(0)), "brute",
		"l'indice 2 nella tabella di -orda e' il bruto: e' il bersaglio grosso davanti")
	h.eq(str(_horde.kind_name(1)), "runner",
		"l'indice 0 nella tabella di -orda e' il runner: e' la fila dietro")
	# Il riferimento e' il **conteggio di prima**, misurato all'avvio: il
	# riordino sposta e rietichetta, non ammazza e non crea. Scrivere qui un
	# numero fisso (era 200) legava il test alla curva di -orda; la relazione
	# richiesta e' "tutti i nemici che c'erano ci sono ancora", e nient'altro.
	h.eq(int(_horde.count), _vivi_avvio,
		"il poligono ha lasciato vivi tutti i nemici che c'erano")
	h.eq(int(_horde.count), int(_horde.get("population")),
		"e il campo e' ancora pieno al suo tetto di popolazione")
	var iprimo: int = _game.nearest_enemy(_player.position, 26.0)
	h.eq(iprimo, 0, "e il nemico piu' vicino e' il bersaglio grosso davanti")
	h.near(float(_horde.hp[0]), VITA_BERSAGLIO, 0.01,
		"il bersaglio grosso ha vita altissima: non puo' morire e falsare la somma degli HP")
	h.eq(int(_horde.hit_count), 0, "e nessun colpo e' partito durante l'allestimento")
	print("upgrades: poligono di %d slot su %d nemici vivi, il resto a %.0f m"
		% [slot, int(_horde.count), LONTANO])
	return true

# --- Tutte le misure, insieme --------------------------------------------------

## Le otto misure in un colpo, **senza** rimettere nulla a posto: il chiamante
## decide quando parte da base. `-1.0` vuol dire "questa misura non e' stata
## possibile", e il chiamante lo segnala invece di confrontare numeri inventati.
func _tutte(h) -> Dictionary:
	var m := {}
	m["danno"] = _danno(h)
	m["cadenza"] = _cadenza(h)
	m["corsa"] = _corsa(h)
	m["velocita"] = _velocita(h)
	m["spinta"] = _spinta(h)
	m["perforante"] = float(_perforante(h))
	m["vita"] = float(_vita(h))
	m["gittata"] = float(_gittata(h))
	for k in MISURE:
		h.check(float(m[k]) >= 0.0,
			"la misura '%s' e' stata possibile, altrimenti il confronto sarebbe su un -1" % k)
	return m

## Ogni id dichiarato dalla progressione, uno alla volta, dalla base: prima si
## misura tutto, poi si applica, poi si rimisura tutto.
func _uno_per_uno(h) -> void:
	var noti := _costanti(_prog)
	if not h.check(noti.has("UPGRADE_IDS"), "la progressione dichiara la tabella degli id"):
		return
	var ids: Array = noti["UPGRADE_IDS"]
	h.check(ids.size() > 0, "la tabella degli id non e' vuota")
	h.eq(ids.size(), MISURA_DI.size(),
		"a ogni id dichiarato corrisponde una voce misurata qui dentro")

	for id in ids:
		var chiave := str(id)
		if not h.check(MISURA_DI.has(chiave),
				"l'id '%s' ha una voce misurata che lo riguarda: un potenziamento che nessuno guarda e' decorativo"
				% chiave):
			continue
		var voce: String = MISURA_DI[chiave]

		_a_base()
		var prima := _tutte(h)
		var grezzi_prima := _numeri_grezzi()

		var applicato: bool = _prog.apply(chiave)
		h.check(applicato, "apply('%s') risponde true: il potenziamento e' applicabile" % chiave)
		h.eq(int(_emessi), 1,
			"'%s': il segnale upgrade_applied e' partito una volta sola" % chiave)

		var dopo := _tutte(h)
		var grezzi_dopo := _numeri_grezzi()

		# 1. la voce giusta si muove di almeno il 2%
		var a := float(prima[voce])
		var b := float(dopo[voce])
		h.check(_cambiato(a, b),
			"'%s': la %s passa da %.3f a %.3f (%.1f%%), e il tetto del criterio e' %.0f%%"
			% [chiave, voce, a, b, _percento(a, b), SOGLIA * 100.0])

		# 2. nessun potenziamento decorativo: almeno una misura si muove
		var mosse := _mosse(prima, dopo)
		h.check(mosse > 0,
			"'%s': almeno una misura si sposta di almeno il 2%%, altrimenti e' un potenziamento decorativo"
			% chiave)
		h.check(not _grezzi_uguali(grezzi_prima, grezzi_dopo),
			"'%s': e almeno un numero grezo dell'arma o del giocatore e' cambiato" % chiave)

		_emessi = 0
		_stampa_riga(chiave, prima, dopo)
		_a_base()
		h.check(_grezzi_uguali(grezzi_prima, _numeri_grezzi()),
			"'%s': dopo il confronto tutti i numeri sono tornati alla base" % chiave)

# --- 3. Il controllo negativo ---------------------------------------------------

## Un id che non esiste non applica niente, non muove nessun numero e non
## emette nessun segnale. E' il caso in cui la tabella degli id e quella del
## codice cominciano a divergere: senza questo controllo un refuso passerebbe
## perche' `apply()` avrebbe semplicemente fatto `return false` in silenzio.
func _id_inesistente(h) -> void:
	_a_base()
	var prima := _numeri_grezzi()
	var offerte_prima := int(_prog.pending())
	_emessi = 0

	h.check(not _prog.apply("potenziamento_che_non_esiste"),
		"apply() con un id inesistente risponde false")
	h.check(_grezzi_uguali(_numeri_grezzi(), prima),
		"e non muove un solo numero, ne' di un nanometro")
	h.eq(int(_prog.pending()), offerte_prima, "ne' cambia le offerte in sospeso")
	h.eq(int(_emessi), 0, "ne' emette il segnale che l'interfaccia ascolta")

	# Lo stesso per una scelta fuori dall'intervallo delle offerte.
	h.eq(str(_prog.choose(0)), "", "choose(0) con il menu vuoto non applica niente")
	h.check(_grezzi_uguali(_numeri_grezzi(), prima), "e non muove nessun numero")
	h.eq(str(_prog.choose(-1)), "", "choose(-1) non applica niente")

	# E i due potenziamenti che non hanno bisogno dell'arma: devono funzionare
	# anche senza un bersaglio, e devono spostare il numero giusto.
	h.check(_prog.apply("move_speed"), "apply('move_speed') funziona: non dipende dall'arma")
	h.check(_prog.apply("vitality"), "apply('vitality') funziona: non dipende dall'arma")
	h.check(float(_player.move_speed) > float(prima["corsa"]),
		"e i due spostano davvero il giocatore: %.2f contro %.2f"
		% [_player.move_speed, float(prima["corsa"])])
	h.check(float(_player.max_hp) > float(prima["vita_max"]),
		"l'uno la corsa e l'altro la vita massima: %.1f contro %.1f"
		% [_player.max_hp, float(prima["vita_max"])])
	_a_base()

# --- 4. `weapon.reset()` riporta tutto alla base --------------------------------

## Il numero che decide: dopo `reset()` la firma dei numeri grezzi e' **uguale
## bit per bit** a quella di partenza. Un potenziamento che sopravvivesse al
## reset farebbe cominciare la partita nuova gia' potenziata, che e' l'unico
## modo che un restart non sia un restart.
func _ritorno_alla_base(h) -> void:
	_a_base()
	var base := _numeri_grezzi()
	var misure_base := _tutte(h)

	# Gli otto potenziamenti insieme, e **senza** nessun reset in mezzo: qui i
	# numeri devono essere diversi, altrimenti la sezione dopo non misurerebbe
	# niente.
	for id in ["damage", "fire_rate", "move_speed", "projectile_speed",
			"knockback", "pierce", "vitality", "range"]:
		_prog.apply(str(id))
	var sporco := _numeri_grezzi()
	h.check(not _grezzi_uguali(base, sporco),
		"gli otto potenziamenti insieme sporcano davvero la firma")
	var mosse := 0
	for k in base.keys():
		if float(base[k]) != float(sporco[k]):
			mosse += 1
	h.check(mosse >= 6,
		"e la sporcano in almeno sei numeri (ne sporchano %d di %d): un potenziamento che non muove nulla e' decorativo"
		% [mosse, base.size()])

	# E adesso il reset.
	_a_base()
	h.check(_weapon.has_method("reset"),
		"l'arma espone reset(): e' il metodo che player.reset_run() chiama e che una volta non esisteva")
	h.check(_grezzi_uguali(_numeri_grezzi(), base),
		"weapon.reset() riporta **tutti** i numeri dell'arma alla regolazione di partenza")
	h.near(float(_weapon.damage), 10.0, 0.0001, "il danno torna a 10.0")
	h.near(float(_weapon.fire_interval), 0.35, 0.0001, "l'intervallo fra i colpi torna a 0.35 s")
	h.near(float(_weapon.projectile_speed), float(base["velocita"]), 0.0001, "la velocita' del proiettile torna a 26 m/s")
	h.near(float(_weapon.projectile_life), 1.4, 0.0001, "la gittata torna a 1.4 s")
	h.near(float(_weapon.knockback), 18.0, 0.0001,
		"la spinta torna a 18.0 m/s: m2 non l'ha alzata per stare comodo (piano sez. 1.2)")
	h.eq(int(_weapon.pierce), 0, "la perforante torna a 0")
	h.near(float(_weapon.acquire_radius), 26.0, 0.0001, "la gittata di mira torna a 26 m")
	h.near(float(_weapon.cooldown), 0.0, 0.0001, "l'arma e' pronta a sparare al primo passo")

	# I due numeri che stanno sul giocatore e non sull'arma li riporta
	# `player.reset_run()`, che e' la meta' di -gameplay dentro il restart.
	_player.max_hp = 137.0
	_player.move_speed = 9.5
	_player.reset_run()
	h.check(_grezzi_uguali(_numeri_grezzi(), base),
		"e player.reset_run() riporta alla base anche i numeri del giocatore")
	var misure_ora := _tutte(h)
	for k in MISURE:
		h.near(float(misure_ora[k]), float(misure_base[k]), 0.0001,
			"la %s e' tornata al numero di partenza: %.3f contro %.3f"
			% [k, float(misure_ora[k]), float(misure_base[k])])
	_a_base()

# --- Le offerte del livello ----------------------------------------------------

## Il legame fra i due criteri di m2: il livello offre **esattamente tre**
## potenziamenti e sceglierne uno applica un potenziamento che si vede. Il numero
## che decide e' che `choose(0)` sposta almeno una misura di almeno il 2%, non
## che restituisca una stringa.
##
## ## Una scelta sola (regola dell'utente, 2026-10-13)
##
## Si sale di livello, si sceglie **uno**, gli altri due si buttano: `pending()`
## va da 3 a 0 in un colpo. Questa sezione non asserisce solo il 3 -> 0, asserisce
## anche i due numeri che lo circondano e che il 3 -> 0 da solo non prova: che i
## due scartati non si applicano piu', e che al livello dopo ne arrivano tre
## nuove. Il secondo e' la ragione meccanica della regola: `add_xp` rulla solo
## con la coda vuota, quindi e' lo svuotamento a rilanciare il ciclo.
func _scelta_del_livello(h) -> void:
	_a_base()
	h.eq(int(_prog.pending()), 0, "a partita nuova non c'e' nessuna offerta in sospeso")
	h.eq(int(_prog.kills), 0,
		"nessuna misura ha ucciso un nemico: le offerte non possono riempirsi da sole")

	var salita: int = _prog.add_xp(float(_prog.xp_to_next(1)))
	h.eq(salita, 1, "un livello salito con la soglia del livello 2")
	h.eq(int(_prog.level), 2, "il livello e' 2")
	h.eq(int(_prog.pending()), 3, "e il livello offre esattamente 3 potenziamenti")

	var prima := _tutte(h)
	var scelto: String = _prog.choose(0)
	h.check(scelto != "", "choose(0) applica uno dei tre: '%s'" % scelto)
	h.eq(int(_prog.pending()), 0,
		"e la coda si svuota in un colpo: si sceglie UNO e gli altri due si buttano")
	h.eq(int(_emessi), 1, "un solo segnale per una scelta")
	_emessi = 0
	var dopo := _tutte(h)
	h.check(_mosse(prima, dopo) > 0,
		"la scelta dal menu cambia il comportamento come fa l'applicazione diretta (%d misure mosse)"
		% _mosse(prima, dopo))

	# ## I due scartati non si applicano piu'
	#
	# Sotto la regola nuova (`progression.gd::choose`: una scelta e gli altri due
	# si buttano) le due offerte rimaste non sono "in attesa": sono **buttate**.
	# Il numero che lo dimostra e' che con la coda svuotata nessun tentativo
	# successivo muove un numero, quindi i due potenziamenti scartati non
	# arriveranno mai al giocatore per quella via.
	var grezzi := _numeri_grezzi()
	h.eq(str(_prog.choose(0)), "", "una seconda scelta non trova niente da scegliere")
	h.eq(str(_prog.choose(1)), "", "e neppure una terza, con lo stesso indice o con un altro")
	h.eq(int(_prog.pending()), 0, "la coda resta svuotata")
	h.check(_grezzi_uguali(_numeri_grezzi(), grezzi),
		"le offerte scartate non si applicano piu': nessun numero si e' mosso")
	h.eq(int(_emessi), 0, "e nessun segnale e' partito")

	# ## Il ciclo torna, ed e' lo svuotamento a rilanciarlo
	#
	# `add_xp` chiama `roll()` solo con `gained > 0 and offers.is_empty()`. Se
	# `choose()` tenesse le due pending quella riga non scatterebbe piu' e il
	# ciclo dei livelli si fermerebbe: e' il difetto che la regola nuova chiude.
	var offerte_prima := int(_prog.pending())
	_prog.add_xp(float(_prog.xp_to_next()))
	h.eq(int(_prog.pending()), 3,
		"al livello dopo tornano tre offerte nuove (prima della salita erano %d): la coda svuotata e' la condizione che rilancia il ciclo"
		% offerte_prima)
	_a_base()

# --- m6, criterio n. 4: la descrizione e' dichiarata, non ricopiata -----------

## Il numero che decide: **il numero scritto sulla carta e' quello che `apply()`
## fa davvero, misurato**. Si mette in coda un id, si legge `offer_effect(0)`,
## si applica l'id e si rimisura **dal gioco** la grandezza che l'id tocca: se la
## carta dicesse «+25%` mentre il danno crescesse del 30%, qui fallirebbe anche se
## le due cifre sembrassero vicine.
##
## Il confronto e' su tutte e otto le voci, non solo sul danno, perche' il difetto
## che questa sezione chiude non e' "una sbagliata" ma "una copiata a mano": e'
## la stessa regola per tutti e otto i numeri.
##
## ## Perche' qui si scrive `offers` a mano
##
## `roll()` non lascia scegliere quale id arriva, e per provare tutti e otto gli
## id serve arrivarci uno alla volta. `_prog.offers = [id]` e' **impalcatura**,
## non una scorciatoia: quello che viene confrontato e' il numero della stringa
## contro la misura, non la coda contro se stessa, e qui sotto nessuna asserzione
## e' soddisfatta da una `choose()` chiamata a mano.
func _descrizione_misurata(h) -> void:
	var noti := _costanti(_prog)
	if not h.check(noti.has("UPGRADE_IDS"), "la progressione dichiara la tabella degli id"):
		return
	var ids: Array = noti["UPGRADE_IDS"]
	for id in ids:
		var chiave := str(id)
		_a_base()
		_prog.offers = [chiave]
		var nome := str(_prog.offer_label(0))
		var effetto := str(_prog.offer_effect(0))
		h.eq(int(_prog.pending()), 1, "'%s': l'offerta da descrivere e' in coda" % chiave)
		h.check(nome != "" and _ascii(nome),
			"'%s': la carta ha un nome leggibile e solo ASCII: '%s'" % [chiave, nome])
		h.check(effetto != "" and _ascii(effetto),
			"'%s': e un effetto leggibile e solo ASCII: '%s'" % [chiave, effetto])
		var carta := _numero_della_carta(effetto)
		if not h.check(carta.size() == 2,
				"'%s': l'effetto '%s' si sa leggere come numero, e come percentuale sì o no"
				% [chiave, effetto]):
			continue
		var numero := float(carta[0])
		var percentuale := bool(carta[1])
		h.check(numero > 0.0, "'%s': e il numero promesso e' positivo (%s)" % [chiave, numero])

		var voce := str(MISURA_DI[chiave])
		var prima := _tutte(h)
		h.check(_prog.apply(chiave), "apply('%s') risponde true: la carta descrive qualcosa di applicabile"
			% chiave)
		var dopo := _tutte(h)
		var a := float(prima[voce])
		var b := float(dopo[voce])
		if percentuale:
			# La cadenza si misura in **frame per N colpi**: meno frame vuol dire
			# piu' cadenza, quindi il segno e' opposto rispetto alla carta e si
			# confronta il valore assoluto. E' il caso in cui la misura ha piu'
			# rumore degli altri, perche' il numero di frame e' intero.
			var misurato := _percento(a, b)
			var scarto := absf(absf(misurato) - numero)
			var tolleranza := _tol_voce(voce, a)
			h.check(scarto <= tolleranza,
				"'%s': la carta promette %+.0f%% e la %s va da %.3f a %.3f (%+.1f%% misurati), scarto %.2f su una tolleranza di %.2f"
				% [chiave, numero, voce, a, b, misurato, scarto, tolleranza])
		else:
			# Incremento secco: la carta promette un numero in unita' proprie
			# (punti vita, nemici), e la misura conta colpi o nemici. La
			# conversione e' dichiarata in `_unita_per_id`, non qui dentro.
			var promesso := (b - a) * _unita_per_id(chiave)
			h.check(absf(promesso - numero) <= TOL_PERCENTUALE,
				"'%s': la carta promette %+.0f in unita' sue e la %s promette %.3f (da %.3f a %.3f)"
				% [chiave, numero, voce, promesso, a, b])
		_stampa_carta(chiave, nome, effetto, voce, prima, dopo)
	_a_base()

## L'indice di `offer_label`/`offer_effect` e' relativo a `offers` **adesso**:
## lo stesso id dice le stesse due stringhe in qualunque posizione, e due id
## diversi dicono due coppie diverse. E' il contratto con il pannello di `-ui`,
## che deve rileggere `offers` **prima** di disegnarle e non dopo: `choose(index)`
## applica la scelta e svuota la coda, quindi un pannello che tenesse la lista
## delle carte disegnata mostrerebbe tre bottoni su cui non si puo' piu' cliccare.
func _indice_relativo_a_offers(h) -> void:
	_a_base()
	_prog.offers = ["damage"]
	var primo_nome := str(_prog.offer_label(0))
	var primo_effetto := str(_prog.offer_effect(0))
	_prog.offers = ["pierce"]
	var secondo_nome := str(_prog.offer_label(0))
	var secondo_effetto := str(_prog.offer_effect(0))
	h.check(primo_nome != secondo_nome,
		"due id diversi dicono due nomi diversi anche offerti da soli: '%s' e '%s'"
		% [primo_nome, secondo_nome])
	h.check(primo_effetto != secondo_effetto,
		"e due effetti diversi: '%s' e '%s'" % [primo_effetto, secondo_effetto])

	_prog.offers = ["damage", "pierce", "damage"]
	h.eq(str(_prog.offer_label(1)), secondo_nome,
		"l'id alla posizione 1 descritto da solo e descritto in coda dicono la stessa cosa")
	h.eq(str(_prog.offer_effect(1)), secondo_effetto,
		"e l'effetto pure: '%s'" % secondo_effetto)
	h.eq(str(_prog.offer_label(2)), primo_nome,
		"l'indice 2 e' il terzo elemento, non il primo: '%s'" % primo_nome)
	h.eq(str(_prog.offer_label(3)), "",
		"l'indice 3 non esiste: la coda ne ha tre e la risposta e' una stringa vuota")
	h.eq(str(_prog.offer_effect(3)), "", "e anche l'effetto e' vuoto")
	_a_base()

# --- Le misure ------------------------------------------------------------------

## Quanta vita ha perso davvero l'orda a un colpo. La somma degli HP vale **solo
## se nessuno e' morto**: `_kill` toglie il nemico con lo scambio con l'ultimo,
## e la somma cambierebbe di due cose insieme. Quindi il controllo e' su
## `horde.count` e `horde.kills`, e se qualcuno muore la misura si rifa.
func _danno(h) -> float:
	for _tent in 12:
		_al_centro()
		_pool.reset()
		_horde.hit_count = 0
		var prima := _hp_totali()
		var vivi0 := int(_horde.count)
		var morti0 := int(_horde.kills)
		# Il colpo lo spara l'arma stessa, al primo passo; da li in poi e' ferma,
		# cosi' nella finestra della misura c'e' una e una sola `damage_enemy`.
		_pronta()
		_player.step(DT, Vector3.ZERO)
		_ferma()
		var g := 1
		while int(_horde.hit_count) == 0 and g < 120:
			_player.step(DT, Vector3.ZERO)
			g += 1
		if int(_horde.hit_count) != 1:
			# Nessun colpo, o piu' di uno: nessuna misura, si riprova.
			continue
		if int(_horde.count) != vivi0 or int(_horde.kills) != morti0:
			# Qualcuno e' morto: la somma non vale niente, si riprova.
			continue
		return prima - _hp_totali()
	return -1.0

## Quanti passi servono al sesto colpo. L'arma spara **da sola** e il conteggio
## e' `weapon.shots`, non il pool: un colpo partito contro un nemico addosso
## arriva e muore nello stesso passo, e guardare il pool misurerebbe la distanza
## dal bersaglio invece che la cadenza.
func _cadenza(h) -> float:
	_al_centro()
	_pronta()
	var partenza := int(_weapon.shots)
	var g := 0
	while int(_weapon.shots) - partenza < COLPI_CADENZA and g < 600:
		_player.step(DT, Vector3.ZERO)
		g += 1
	if int(_weapon.shots) - partenza < COLPI_CADENZA:
		return -1.0
	return float(g)

## Metri percorsi in `PASSI_CORSA` passi con un input noto. Il giocatore parte dal
## centro e non arriva al muro: 120 passi a 7 m/s sono 14 m, il muro e' a 27.2 m.
func _corsa(h) -> float:
	_al_centro()
	for _i in PASSI_CORSA:
		_player.step(DT, Vector3(1.0, 0.0, 0.0))
	return Vector2(_player.position.x, _player.position.z).length()

## Metri che copre in **un passo** il proiettile che l'arma ha appena sparato.
## Si chiama `_try_fire()` e non si lascia girare il pool: quello che si vuole
## misurare e' il passo del proiettile, non il contatto. Il tiro pero' e' quello
## vero dell'arma, e passa da `Game.spawn_projectile`.
func _velocita(h) -> float:
	_al_centro()
	_pool.reset()
	_weapon.cooldown = 0.0
	_weapon._try_fire()
	var p = _pool.active_at(0)
	if p == null:
		return -1.0
	p.step(DT)
	return p.pos.distance_to(p.prev_pos)

## Quanto slancio ha preso davvero il nemico colpito. Si legge la **differenza**
## fra la sua velocita' prima e dopo il colpo, non la velocita' dopo: il nemico
## insegue gia', e leggere la velocita' come se fosse l'impulso misurerebbe
## l'inseguimento (l'errore che il piano descrive al sez. 5.4). Il colpo lo
## impartisce il test stesso attraverso il contratto, con l'arma in attesa lunga,
## cosi' nel passo c'e' una e una sola `damage_enemy` e la differenza e' pulita.
func _spinta(h) -> float:
	_al_centro()
	_pool.reset()
	_ferma()
	_horde.hit_count = 0
	var v0: PackedVector3Array = _horde.velocities.duplicate()
	var muzzle: Vector3 = _weapon.muzzle_position()
	if not _game.spawn_projectile(muzzle, Vector3(1.0, 0.0, 0.0), float(_weapon.projectile_speed)):
		return -1.0
	var g := 0
	while g < 180 and int(_pool.active_count()) > 0:
		_player.step(DT, Vector3.ZERO)
		g += 1
	var meglio := 0.0
	for i in _horde.count:
		meglio = maxf(meglio, (_horde.velocities[i] - v0[i]).length())
	return meglio

## Quanti nemici colpisce **un solo** proiettile. Il conteggio e'
## `horde.hit_count`, che `damage_enemy` incrementa una volta per ogni nemico
## toccato: il campo si azzera a mano perche' nella simulazione viene rimesso a
## zero a ogni passo, e qui i passi di simulazione non li chiamo.
func _perforante(h) -> int:
	_al_centro()
	_pool.reset()
	_ferma()
	_horde.hit_count = 0
	# Il colpo lo spara l'arma, al primo passo. Il ciclo parte **dopo** il primo
	# passo e non "finche' il pool e' vuoto": al primo giro il pool e' gia' vuoto
	# perche' nessun proiettile e' ancora partito, e la prima versione non faceva
	# un solo passo e misurava sempre zero.
	_pronta()
	_player.step(DT, Vector3.ZERO)
	_ferma()
	var g := 1
	while g < 240 and int(_pool.active_count()) > 0:
		_player.step(DT, Vector3.ZERO)
		g += 1
	return int(_horde.hit_count)

## Quanti colpi da 10 regge il giocatore prima di morire. L'invulnerabilita' viene
## azzerata a ogni colpo, altrimenti il secondo colpo non entra e la misura
## conterebbe i secondi di recupero invece dei punti vita.
func _vita(h) -> int:
	_al_centro()
	_player.hp = _player.max_hp
	var n := 0
	while not _player.is_dead() and n < 500:
		_player.invuln = 0.0
		_player.dash_timer = 0.0
		_player.take_damage(DANNO_PER_COLPO)
		n += 1
	return n

# --- Lettura delle carte (m6) --------------------------------------------------

## Solo ASCII nelle stringhe che finiscono a schermo: e' la regola del progetto
## (piano §5.1) e la console di Windows la mangia proprio dove serve leggerla.
func _ascii(s: String) -> bool:
	for i in s.length():
		if s.unicode_at(i) > 126:
			return false
	return true

## Il numero che una carta promette, e se lo promette in percentuale.
## «+25%» -> `[25.0, true]`, «+1 nemico» -> `[1.0, false]`, una stringa senza
## numeri -> `[]`. Si legge la stringa e non un campo di `progression.gd`: e' la
## stringa che il pannello mostra, quindi e' quella che va confrontata.
func _numero_della_carta(s: String) -> Array:
	var inizio := s.find("+")
	if inizio < 0:
		return []
	var cifre := ""
	var i := inizio + 1
	while i < s.length() and s[i] >= "0" and s[i] <= "9":
		cifre += s[i]
		i += 1
	if cifre == "":
		return []
	return [float(cifre), s.substr(i).begins_with("%")]

## Quanti punti della misura valgono **una unita'** di quelle che la carta
## promette. La vita promette punti vita e la misura conta colpi da
## `DANNO_PER_COLPO` punti; la perforante conta gia' nemici, e la carta promette
## nemici, quindi la conversione e' uno. Nessun numero e' scritto dentro
## l'asserzione: sta qui, una volta sola.
func _unita_per_id(id: String) -> float:
	return DANNO_PER_COLPO if id == "vitality" else 1.0

## La tolleranza con cui una percentuale misurata si confronta con il numero
## scritto sulla carta. La carta arrotonda all'intero, quindi mezzo punto e'
## gia' nel numero confrontato. Le due misure contate in **frame interi**
## (`cadenza`, `gittata`) aggiungono un passo di confine, che vale `100 / N`
## punti percentuali su una misura di N frame: anche questo numero esce dalla
## misura, non e' una tolleranza tarata per far passare qualcosa.
func _tol_voce(voce: String, prima: float) -> float:
	if voce in MISURE_IN_FRAME:
		return TOL_PERCENTUALE + 100.0 / maxf(absf(prima), 1.0)
	return TOL_PERCENTUALE + 0.0001

## La tabella del confronto: cosa promette la carta e quanto fa il gioco. Come
## `_stampa_riga`, non e' una stampa decorativa: e' il numero che chi legge il
## FAIL deve poter vedere senza aprire il codice.
func _stampa_carta(id: String, nome: String, effetto: String, voce: String,
		prima: Dictionary, dopo: Dictionary) -> void:
	print("upgrades: carta '%s' / '%s' -> %s %.3f->%.3f (%+.1f%%)"
		% [nome, effetto, voce, float(prima[voce]), float(dopo[voce]),
			_percento(float(prima[voce]), float(dopo[voce]))])

## Per quanti passi un proiettile sopravvive in un campo vuoto. Il tiro e' fatto
## **a mano** attraverso `Game.spawn_projectile` verso `-z`, la direzione in cui
## nel poligono non c'e' nessuno: l'orda e' tutta a `+x` e il resto e' a 39 m. Il
## colpo parte dal contratto, e il pool ci legge dentro la vita del proiettile,
## che e' il campo che il potenziamento "gittata" cambia.
func _gittata(h) -> float:
	_al_centro()
	_pool.reset()
	var muzzle: Vector3 = _weapon.muzzle_position()
	if not _game.spawn_projectile(muzzle, Vector3(0.0, 0.0, -1.0), float(_weapon.projectile_speed)):
		return -1.0
	var g := 0
	while g < 900 and int(_pool.active_count()) > 0:
		_pool.step(DT)
		g += 1
	return float(g)

# --- Interno -------------------------------------------------------------------

## L'arma pronta a sparare **adesso**: `cooldown` a zero e basta. Nessuna
## misura tocca `fire_interval`: quello e' un numero che i potenziamenti cambiano
## (`fire_rate`) e una misura che lo riscriverebbe starebbe misurando se stessa.
## La prima esecuzione di questo file faceva esattamente quello e misurava una
## cadenza di 111 passi **identica prima e dopo** il -15%: la firma del test era
## giusta, la misura no.
func _pronta() -> void:
	_weapon.cooldown = 0.0

## L'arma trattenuta dopo il colpo di una misura: il cooldown alto impedisce un
## secondo colpo, e nessun campo di regolazione viene toccato.
func _ferma() -> void:
	_weapon.cooldown = 100000.0

## Il giocatore al centro dell'arena, fermo e vivo. Serve a ogni misura: la
## posizione cambia durante la misura della corsa e la vita cambia durante quella
## della sopravvivenza, e una canna fuori dal poligono o un giocatore morto
## farebbero fallire in modo falso tutte le altre.
func _al_centro() -> void:
	_player.position = Vector3.ZERO
	_player.velocity = Vector3.ZERO
	_player.invuln = 0.0
	_player.dash_timer = 0.0
	_player.dash_cd = 0.0
	_player.hp = _player.max_hp

## Stato di partenza esatto: il giocatore e' quello vergine, l'arma e' quella
## vergine, la progressione e' a zero. Ogni id viene provato da qui, e il confronto
## prima/dopo non deve dipendere dall'ordine delle sezioni.
func _a_base() -> void:
	_weapon.reset()
	_player.hp = 100.0
	_player.max_hp = 100.0
	_player.move_speed = 7.0
	_player.accel = 60.0
	_al_centro()
	if _prog != null:
		_prog.reset()
	_emessi = 0

## La firma dei numeri **grezzi**: cio' che un potenziamento scrive sui campi.
## Serve al controllo negativo (deve essere identica bit per bit) e alla prova
## che `reset()` riporta **tutto** alla base, non solo i numeri che una misura
## guarda.
func _numeri_grezzi() -> Dictionary:
	return {
		"danno": float(_weapon.damage),
		"intervallo": float(_weapon.fire_interval),
		"velocita": float(_weapon.projectile_speed),
		"vita_proj": float(_weapon.projectile_life),
		"spinta": float(_weapon.knockback),
		"perforante": int(_weapon.pierce),
		"gittata_mira": float(_weapon.acquire_radius),
		"corsa": float(_player.move_speed),
		"accel": float(_player.accel),
		"vita_max": float(_player.max_hp),
	}

func _grezzi_uguali(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a.keys():
		if typeof(a[k]) != typeof(b[k]):
			return false
		if a[k] != b[k]:
			return false
	return true

func _hp_totali() -> float:
	var totale := 0.0
	var hp: PackedFloat32Array = _horde.hp
	for i in _horde.count:
		totale += float(hp[i])
	return totale

## La domanda del criterio: due numeri sono diversi se la differenza supera il
## 2%. Il riferimento e' il valore di partenza, non il maggiore: cosi' una cadenza
## che passa da 106 a 91 passi conta quanto un danno che passa da 10 a 12.5.
func _cambiato(a: float, b: float) -> bool:
	if a < 0.0 or b < 0.0:
		return false
	return absf(b - a) > SOGLIA * maxf(absf(a), 0.0001)

func _percento(a: float, b: float) -> float:
	if absf(a) < 0.0001:
		return 0.0
	return (b - a) / absf(a) * 100.0

func _mosse(prima: Dictionary, dopo: Dictionary) -> int:
	var n := 0
	for k in MISURE:
		if _cambiato(float(prima[k]), float(dopo[k])):
			n += 1
	return n

## La tabella, una riga per potenziamento: cosa e' cambiato e di quanto. Non e'
## solo una stampa: e' il numero che chi legge il FAIL deve poter vedere senza
## aprire il codice.
func _stampa_riga(id: String, prima: Dictionary, dopo: Dictionary) -> void:
	var voci := ""
	for k in MISURE:
		var a := float(prima[k])
		var b := float(dopo[k])
		voci += " %s %.3f->%.3f (%.1f%%)" % [k, a, b, _percento(a, b)]
	print("upgrades: %-16s%s" % [id, voci])

## Le costanti della progressione lette a runtime dallo **script vivo**: una
## copia qui dentro si romperebbe al primo ritocco della tabella e fallirebbe
## senza che nessuno l'abbia toccata.
func _costanti(prog) -> Dictionary:
	var m: Variant = prog.get_script().get_script_constant_map()
	return m as Dictionary if m is Dictionary else {}

# --- Scena ---------------------------------------------------------------------

## `scenes/arena_main.tscn` caricata a runtime, non in `const` (vedi la trappola
## in testa al file).
func _apri_arena(h):
	if not h.check(ResourceLoader.exists(ARENA_SCENE), "manca %s" % ARENA_SCENE):
		return null
	var res = load(ARENA_SCENE)
	if not h.check(res is PackedScene, "%s non e' una PackedScene" % ARENA_SCENE):
		return null
	var arena = (res as PackedScene).instantiate()
	if not h.check(arena is Node3D, "%s non istanzia un Node3D" % ARENA_SCENE):
		if arena != null:
			arena.free()
		return null
	root.add_child(arena)
	_arena = arena as Node3D
	return _arena

## Libera la scena senza lasciare appeso nessun nodo: `remove_child` e poi
## `free`, cosi' l'albero e' pulito **subito**.
func _chiudi(arena) -> void:
	if arena == null:
		return
	if arena.get_parent() != null:
		arena.get_parent().remove_child(arena)
	arena.free()
