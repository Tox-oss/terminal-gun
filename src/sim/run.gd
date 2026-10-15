extends RefCounted
## La partita: **stato** (in corso o `game_over`) e **scala delle onde**.
## terminal-gun-orda, `src/sim/run.gd`.
##
## ## Perche' un oggetto e non un nodo
##
## Niente `Node3D`, niente da mettere nella scena, niente da liberare: e' un
## oggetto che `horde.gd` tiene in un campo e crea una volta sola in `_build()`.
## Il criterio n. 4 della milestone 2 chiede che un restart non lasci **nessun
## nodo duplicato**: questa forma lo soddisfa per costruzione, invece che perche'
## qualcuno si e' ricordato di liberare qualcosa.
##
## Non conosce `src/sim/horde.gd`: l'orda non e' un tipo con cui fare un
## `preload`, e quindi non c'e' nessun riferimento circolare (piano sez. 5,
## regola 3).
##
## ## I due numeri che tengono insieme tutto
##
## `wave_total` e `wave_killed`. La **barra dell'onda** e' la loro differenza:
## quanti nemici restano da ammazzare nell'onda corrente. Quando arriva a zero
## l'onda e' finita e si passa alla successiva.
##
## `wave_total` NON e' `population`, e la distinzione e' tutta qui. `population`
## e' quanti nemici sono vivi **contemporaneamente** (200 al massimo: e' il tetto
## del criterio n. 3 di m1). `wave_total` e' quanti ne devi ammazzare **in
## tutto**. Un'onda da 230 uccisioni con 200 vivi significa che il campo si
## riempie mentre uccidi, ed e' quello che distingue un bullet heaven da un
##'orda sola di 230 nemici che si vedono tutti insieme: 200 vivi non e' un tetto
## di nemici da ammazzare.

## La partita e' in corso.
const PLAYING := "playing"
## La partita e' finita: il giocatore non ha piu' vite.
const GAME_OVER := "game_over"

## Uccisioni che chiudono l'onda 1. Sono i 200 nemici che si vedono al primo
## frame: la barra parte gia' piena e non c'e' nessun pezzo di partita "gratis"
## ne' un numero che il test deve andare a cercare.
const WAVE_BASE := 200
## Quante uccisioni in piu' a ogni onda.
const WAVE_GROWTH := 30
## Tetto delle uccisioni per onda. Serve a due cose: a non far crescere la barra
## all'infinito, e a non mettere un numero che nessuno puo' davvero ammazzare.
const WAVE_MAX := 900

## Moltiplicatore di vita dell'onda 1: 1.0 esatto, cioe' le tabelle di
## `src/sim/enemy.gd` come sono. Il criterio n. 4 della milestone 1 e' tarato su
## quei numeri e non puo' cambiare.
const HP_SCALE_BASE := 1.0
## Quanto cresce la vita a ogni onda.
const HP_SCALE_STEP := 0.25
## Tetto del moltiplicatore: oltre, un'onda non diventa piu' difficile, solo
## piu' lunga, e una partita non ha fine.
const HP_SCALE_MAX := 4.0

# --- LA CURVA DELLA POPOLAZIONE (milestone 4) --------------------------------
#
# `population` e' quanti nemici sono vivi **contemporaneamente** nell'onda `w`.
# Fino a m4 non esisteva una curva: `horde.gd::_build()` riempiva a
# `MAX_ENEMIES` e `_top_up()` riportava a quel numero **a ogni passo**, quindi
# l'arena era gia' piena al primo frame e nessun colpo la svuotava. Era una
# scelta di design travestita da criterio di test.
#
# ## LA MISURA DEL PRIMA, e da dove escono i numeri qui sotto
#
# Misurata il 2026-10-12 su `tests/test_orda.gd` **prima** di toccare una riga,
# sull'orda isolata, con il fuoco al centro dell'arena (28 m) e passo fisso
# 1/60 s:
#
# | cosa si misura | numero |
# |---|---|
# | tempo dall'avvio alla popolazione piena | **0.0000 s**: 200 vivi al primo frame, 0 passi |
# | tempo per riempire dopo uno svuotamento totale | **1 passo = 0.0167 s** (da 0 a 200) |
# | primo contatto (nessun vivo entro 3 m dal bersaglio) | **t = 0.02 s** |
# | 25 nemici vivi entro 6 m dal bersaglio | **t = 1.68 s** |
# | a regime (t = 20 s), con 200 vivi | **104 entro 6 m**, cioe' il 52% della popolazione |
# | la stessa frazione a 25 / 50 / 100 vivi | 100% / 90% / 63% / 52% |
#
# La riga che lega tutte e due le tabelle e' una sola: **la frazione della
# popolazione che si ritrova addosso al giocatore e' circa costante**, quindi la
# pressione e' **lineare** in `population`. Ridurre la popolazione riduce la
# pressione nella stessa proporzione, e non c'e' nessun altro numero da indovinare.
#
# ## POP_BASE = 25
#
# Un ottavo della pressione misurata (104 entro 6 m -> 25 -> 13). Perche' un
# ottavo e non meta': a meta' (100) resterebbero ~52 nemici addosso, cioe' meta'
# del sintomo che la milestone sta correggendo; a un quarto (50) resterebbero 45,
# che e' gia' piu' di quanti ne occorrono per coprire l'arena in un'onda. Un
# ottavo lascia un campo che si guarda e che si spara, ed e' la prima cifra che
# il piano non scriveva e che il gioco non aveva mai visto applicata.
#
# ## POP_STEP = 25
#
# Passa da 25, 50, 75, 100, 125, 150, 175 a 200: cresce di POP_BASE ogni onda,
# cioe' raddoppia in quattro onde e satura all'onda 8. Il numero viene dal
# **budget di uccisioni** misurato nella stessa tabella: le prime 7 onde chiedono
# 200+230+260+290+320+350+380 = **2030 uccisioni**, che al ritmo di 10/s usato
# nella colonna dei tempi sono 203 s, cioe' poco piu' di 3 minuti di partita.
# La capacita' di 200 arriva quindi a meta' partita e non alla fine: e' quello che
# serve al criterio di m1 (che chiede 200 *durante* la partita) e quello che un
# giocatore deve poter vedere prima che la partita finisca.
#
# ## Gli invarianti che questa tabella deve soddisfare
#
#   1. `population` e' **strettamente crescente** dall'onda 1 all'onda
#      `POP_SATURATION` e poi sta al tetto: una sequenza di interi bounded non puo'
#      crescere per sempre, e la soglia che si dichiara e' quella onda, non "per
#      sempre". `tests/test_gameloop.gd` asserisce le due metà separatamente.
#   2. `population` **non supera mai** `POP_MAX`, che vale `Horde.MAX_ENEMIES`.
#   3. `population` non puo' saltare da 0 a tutto in un passo: e' il compito di
#      `SPAWN_RATE` qui sotto e di `horde.gd::_top_up`.

## Nemici vivi contemporaneamente sull'onda 1: un ottavo della capienza.
const POP_BASE := 25
## Quanti in piu' vivi a ogni onda.
const POP_STEP := 25
## Tetto della popolazione: **deve valere `Horde.MAX_ENEMIES`**, ed e' scritto
## qui perche' `run.gd` non puo' fare `preload` di `horde.gd` (sarebbe un
## riferimento circolare, piano sez. 5 regola 3). Due copie di un numero in due
## file divergono senza che nessuno se ne accorga, quindi `tests/test_gameloop.gd`
## verifica che siano uguali: e' il controllo che rende la copia onesta.
const POP_MAX := 200
## Prima onda in cui la popolazione arriva al tetto. Da questa in poi la curva e'
## piatta perche' non puo' crescere oltre: dichiararlo e' parte dell'invariante 1.
const POP_SATURATION := 8

## Quanti nemici al secondo l'orda puo' **guadagnare** (`horde.gd::_top_up`).
##
## Il numero e' stretto da due fatti misurati, non scelto a occhio:
##
## - **Il pavimento.** `wave_total` dell'onda 1 e' 200 uccisioni e quelle devono
##   poter arrivare. Con 5 al secondo l'onda 1 durerebbe almeno 40 s, che e'
##   gia' il caso peggiore misurato **prima** di m4 (criterion 1.4b): sotto questa
##   soglia la curva renderebbe la prima onda piu' lenta di com'e' adesso, e il
##   giocatore non potrebbe piu' accorciarla con l'arma. Quindi `>= 5/s`.
## - **Il soffitto.** Prima di m4 un campo vuoto si riempiva in 1 passo. La
##   misura del contatto e' 1.68 s per arrivare a 25 nemici entro 6 m: con
##   `SPAWN_RATE` nemici al secondo, in quella finestra ne arrivano
##   `1.68 * SPAWN_RATE`, e il tetto e' che siano **meno dei 25** misurati allora,
##   altrimenti un campo svuotato ti riaddossa la folla piu' in fretta di quella
##   che ti si era appena liberata. Da qui `SPAWN_RATE < 15`.
##
## **8/s**: sta dentro la finestra (25 passerebbero in 3.1 s) e tiene l'onda 1 a
## un pavimento di 200/8 = **25 s**, dentro la banda 5-40 s misurata prima di m4.
const SPAWN_RATE := 8.0

# --- Stato --------------------------------------------------------------------

## `PLAYING` o `GAME_OVER`. Campo pubblico e non metodo: e' una parola, e un
## metodo che rispondesse `state()` accanto al campo `state` non si potrebbe
## scrivere in GDScript.
var state: String = PLAYING
## Numero dell'onda, da 1. Sale di uno a ogni cambio.
var wave: int = 1
## Uccisioni necessarie a chiudere l'onda corrente.
var wave_total: int = WAVE_BASE
## Uccisioni cadute nell'onda corrente.
var wave_killed: int = 0
## ## m17: i secondi di partita, e perche' esiste **adesso**
##
## Prima di m17 questo file non aveva **nessun segnale di tempo trascorso**: la
## barra dell'onda sapeva quante uccisioni mancavano, la HUD mostrava l'avanzamento
## dell'onda, e nessuno sapeva «quanti secondi di partita sono passati». Quindi un
## numero che dipende dal tempo non aveva dove scriversi, e una soglia come
## «il terzo minuto» non aveva modo di esistere: si poteva solo scrivere «dalla
## terza onda», che e' una parola diversa da quello che il giocatore misura.
##
## `elapsed_s` e' l'orologio, ed e' **un addendo per passo**, non un contatore
## ricostruito: `advance(delta)` e' l'unico posto in cui cresce, e `restart()` e'
## l'unico posto in cui torna a zero (`horde.restart_run()` chiama `restart()`).
##
## ## Perche' un orologio e non un numero d'onda
##
## Misurato il 2026-10-15, l'onda 1 e' passata da **56,78 s a 46,68 s** (-19%)
## quando `-gameplay` ha cambiato l'involucro del proiettile (m14-a). Una soglia
## scritta «dalla terza onda» avrebbe continuato a chiamarsi «terzo minuto» mentre
## non lo era piu', **senza che nessuno se ne accorgesse**: il numero dell'onda non
## si muove quando il tempo si muove, quindi la soglia avrebbe continuato a
## mentire sul nome che ha. Il tempo e' l'unica grandezza che il giocatore misura
## davvero, e l'unica che sopravvive a `-gameplay`.
var elapsed_s: float = 0.0

func _init() -> void:
	wave_total = wave_size(1)

## ## m17: **180,0 s** — il terzo minuto, e la soglia che rende spendibile il mortar
##
## Prima nasceva dall'onda 1 (m14, `Spawner.MORTAR_WEIGHT` in ogni onda). Da qui in
## poi il mortar **non e' spendibile** prima di questo numero di secondi, e solo
## lui: il **brute** e il **boss** non hanno soglia e restano quelli che erano.
##
## | | prima (m14, per onda) | adesso (m17, per tempo) |
## |---|---|---|
## | soglia | nessuna: nasceva dall'onda 1 | `elapsed_s >= 180,0 s` |
## | chi la guarda | `Spawner.wave_weights(wave)` | `Run.mortar_unlocked()` |
##
## Il numero e' **180,0 s** e non «l'onda N» perche' l'onda 1 non dura piu' 180 s
## al ritmo di oggi (vedi `elapsed_s` qui sopra): «terzo minuto» deve dire il
## terzo minuto anche se `-gameplay` cambia ancora il ritmo dell'onda 1.
static var MORTAR_AFTER_S := 180.0

## Un passo di partita: il tempo passa **qui e solo qui**.
##
## Nessuna allocazione, nessun nodo, un solo `+=`. E' chiamata da `horde.step()`
## **dopo** il controllo di `game_over`: a partita finita l'orologio si ferma con
## il gioco, invece di continuare a scorrere mentre nessuno gioca piu'.
func advance(delta: float) -> void:
	if delta > 0.0:
		elapsed_s += delta

## Il mortar e' spendibile? E' l'unica domanda che questo file fa al tempo, ed e'
## scritta qui e non in `horde.gd` perche' e' **la stessa soglia** che il test
## avvelena per accendere i denti: se la soglia vivesse nella foglia che spawna,
## avvelenarla significherebbe toccare il codice di produzione.
func mortar_unlocked() -> bool:
	return elapsed_s >= MORTAR_AFTER_S

# --- I numeri dell'onda --------------------------------------------------------

## Quante uccisioni chiudono l'onda `w`. **Statica** perche' la tabella e' una
## domanda, non uno stato: il test la puo' chiedere (`Run.wave_size(4)`) senza
## costruire una partita e senza dipendere dall'onda in corso.
static func wave_size(w: int) -> int:
	return clampi(WAVE_BASE + (maxi(w, 1) - 1) * WAVE_GROWTH, 1, WAVE_MAX)

## Quanta vita in piu' hanno i nemici dell'onda `w` rispetto alle tabelle di
## `src/sim/enemy.gd`. Sull'onda 1 e' esattamente 1.0.
static func hp_scale_of(w: int) -> float:
	return clampf(HP_SCALE_BASE + float(maxi(w, 1) - 1) * HP_SCALE_STEP,
		HP_SCALE_BASE, HP_SCALE_MAX)

## Quanti nemici vivi **contemporaneamente** sull'onda `w`.
##
## Non e' `wave_size(w)`: quello e' il numero di **uccisioni** che chiudono
## l'onda, questo e' quanti se ne vedono insieme. Sull'onda 1 sono 25 vivi e 200
## uccisioni da fare, ed e' la differenza fra un bullet heaven e un'orda sola.
##
## **Statica**, come `wave_size`: la curva e' una domanda, non uno stato, e il
## test deve poter chiederla per un'onda qualsiasi senza costruire una partita.
##
## Strettamente crescente da `POP_BASE` fino a `POP_SATURATION`, poi `POP_MAX`.
## Il `clampi` finale e' quello che rende vero l'invariante 2 (mai sopra il
## tetto) e insieme quello che rende la coda piatta: dichiararlo e' un invariante
## con denti, non una scivolinata.
static func population_of(w: int) -> int:
	var n := maxi(w, 1)
	if n >= POP_SATURATION:
		return POP_MAX
	return mini(POP_BASE + (n - 1) * POP_STEP, POP_MAX)

## Quanti nemici al secondo l'orda puo' guadagnare. Vedi `SPAWN_RATE`, che
## dichiara la misura da cui viene.
func spawn_rate() -> float:
	return SPAWN_RATE

## Il moltiplicatore di vita dell'onda in corso.
func hp_scale() -> float:
	return hp_scale_of(wave)

## **La barra wave**, in interi: quanti nemici restano da ammazzare. Non puo'
## scendere sotto zero. Quando le uccisioni sorpassano il bersaglio l'onda e'
## gia' finita, e dire "-4 rimasti" sarebbe un numero che non esiste: la barra e'
## piu' vicina allo zero che si puo' scrivere, non la piu' lontana.
##
## Il `maxi` e' anche il motivo per cui un'onda si chiude sempre: le uccisioni
## arrivano a ondate (il proiettile trafora tre nemici nello stesso frame), e il
## totale puo' superare il bersaglio di piu' di uno. Salire senza fermarsi a
## `wave_total` lascerebbe la barra negativa e l'onda non finirebbe mai.
func wave_remaining() -> int:
	return maxi(0, wave_total - wave_killed)

## La barra wave come rapporto da 0 a 1, per l'interfaccia. 1.0 all'inizio
## dell'onda e 0.0 quando e' finita, e sono gli stessi due numeri che
## `wave_remaining()` dà: l'HUD non puo' mostrare una barra diversa da quella
## che la simulazione conta.
func bar_ratio() -> float:
	if wave_total <= 0:
		return 0.0
	return clampf(float(wave_remaining()) / float(wave_total), 0.0, 1.0)

## La barra e' a zero: l'onda e' finita e va contata la successiva.
func wave_cleared() -> bool:
	return wave_killed >= wave_total

# --- Il ciclo ------------------------------------------------------------------

## `n` nemici ammazzati nell'onda corrente.
func register_kill(n: int = 1) -> void:
	if n > 0:
		wave_killed += n

## L'onda successiva: il contatore sale di uno e la barra torna piena.
##
## Non tocca lo stato: passare all'onda dopo e' finita e' una cosa normale, e
## scrivere qui dentro `PLAYING` sarebbe una porta per uscire dal `game_over`
## senza un restart.
func next_wave() -> void:
	wave += 1
	wave_total = wave_size(wave)
	wave_killed = 0

## Il giocatore non ha piu' vite: la partita e' finita. Restituisce `true` solo
## alla prima chiamata, cosi' chi chiama sa se ha cambiato qualcosa.
##
## **Da solo, non si torna indietro**: l'unica strada che riporta a `PLAYING` e'
## `restart()`. Un nemico che si risana da solo non e' un nemico che si e' curato,
## e' un nemico che e' tornato vivo senza essere stato ucciso.
func enter_game_over() -> bool:
	if state == GAME_OVER:
		return false
	state = GAME_OVER
	return true

func is_game_over() -> bool:
	return state == GAME_OVER

## Nuova partita: onda 1, barra piena, niente `game_over`.
##
## Non svuota nessun array e non tocca nessun nodo: chi deve ripopolare e'
## l'orda, che lo fa riscrivendo array che hanno gia' la capienza
## (`horde._populate`).
func restart() -> void:
	state = PLAYING
	wave = 1
	wave_total = wave_size(1)
	wave_killed = 0
	# ## m17: l'orologio riparte da zero **qui**, non in `horde.restart_run()`
	#
	# Perche' qui e non li': `horde.restart_run()` chiama `restart()`, quindi
	# scriverlo anche li' sarebbe una seconda riga che dice la stessa cosa e che
	# un giorno qualcuno toglie da una delle due. E perche' il restart della
	# **partita** e' il solo modo di tornare a `PLAYING` (vedi `enter_game_over`):
	# se ci fosse un'altra strada, l'orologio ripartirebbe da solo
	# e la soglia dei 180 s cambierebbe da una partita all'altra.
	elapsed_s = 0.0
