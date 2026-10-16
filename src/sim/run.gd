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

# --- m14: LA LEGGE DI SCALA, e i tre soffitti che chiude -----------------------
#
# ## Il difetto che l'utente ha trovato giocando (2026-10-15), detto come l'ha detto
#
#     «sono al livello 61 e con i potenziamenti di danno, rateo e gittata posso
#      stare fermo al centro e cancellare tutto allo spawn»
#
# Non era una percezione: qui sotto c'era scritto `HP_SCALE_STEP = 0,25` con
# `HP_SCALE_MAX = 4,0`, cioe' **la vita smetteva di crescere all'onda 13**
# (1 + 12 x 0,25 = 4,0) e da li' in poi erano `4,0x` **per sempre**. La
# popolazione era gia' ferma dall'onda 8 (`POP_SATURATION`). Il giocatore invece
# non aveva tetto: `src/player/progression.gd` gli dava un potenziamento a ogni
# livello, e i fattori sono **moltiplicativi**. Quindi dall'onda 13 la
# difficolta' era **costante per costruzione** e il livello 61 ne era la
# conseguenza, non la causa.
#
# ## Il terzo soffitto: quello che **nessuno aveva scritto**
#
# E' il punto piu' importante di questa sezione, perche' spiega perche' la
# prima volta che l'abbiamo toccato il difetto e' **tornato identico**: alzare (o
# togliere) il tetto sulla vita **non basta**.
#
# Il danno che l'orda consegna al giocatore e' `enemy.gd::touch_damage_of(kind)`:
# la tabella delle specie, **identica a ogni onda**. Quindi anche con la vita
# illimitata il danno al secondo che l'orda porta resta
#
#     (1 / horde.TOUCH_INTERVAL) x TOUCH_DAMAGE_BASE = (1/0,15) x 1,6 = 10,67 hp/s
#
# cioe' una **costante**. Il criterio di m14 — «alla fine della partita la
# pressione in ingresso non e' inferiore a quella in uscita» — sarebbe stato
# **impossibile per qualunque numero messo sulla vita**. Il soffitto vero era
# questo: **l'orda non aveva un secondo canale di difficolta'**.
#
# Percio' da qui la scala e' **una sola legge** e vale per **due** numeri: la vita
# (`hp_scale_of`) e il morso (`touch_scale_of`). Se crescessero con due leggi
# diverse, la piu' lenta dei due riportarebbe il difetto senza che nessuno lo
# vedesse: e' la ragione per cui `scale_of()` e' l'unica funzione che calcola.

## Moltiplicatore dell'onda 1: 1.0 esatto, cioe' le tabelle di `src/sim/enemy.gd`
## come sono. Il criterio n. 4 della milestone 1 e' tarato su quei numeri e non
## puo' cambiare, e `scale_of(1)` vale esattamente questo: **non un tetto, una
## base**.
const HP_SCALE_BASE := 1.0

## ## L'onda a cui finisce la partita, e la soglia del criterio
##
## Non e' un numero di design: e' il numero che l'utente ha citato («sono al
## livello 61») e la wave su cui il criterio di m14 si chiude. Tutto quello che
## segue e' ancorato a qui, quindi cambiarlo cambia la difficolta' **in modo
## dichiarato** invece che di nascosto.
const END_WAVE := 61

## ## I cinque numeri che la legge **copia** da altre foglie, e perche' sono onesti
##
## `run.gd` non puo' fare `preload` di `src/player/progression.gd` ne' di
## `src/sim/horde.gd`: il secondo perche' `horde.gd` preloada `run.gd` e il primo
## perche' e' una foglia di gioco dentro una foglia di simulazione. Quindi qui
## sotto ci sono le **copie** dei numeri da cui la legge dipende, e ognuna porta
## il nome del posto da cui viene. La copia e' onesta perche'
## `tests/test_orda.gd::_difficolta` **asserisce che siano uguali a quelle**:
## come `POP_MAX` contro `Horde.MAX_ENEMIES`, che e' il controllo che rende una
## copia accettabile invece che pericolosa. Se `-gameplay` cambia una di queste
## cifre, la porta va rossa **e dice quale**.

## `progression.gd::XP_PER_KILL`.
const XP_PER_KILL := 3.0
## `progression.gd::XP_BASE`.
const XP_BASE := 8.0
## `progression.gd::XP_STEP`.
const XP_STEP := 6.0
## `progression.gd::UPGRADES["damage"]["numero"]`.
const UPGRADE_DAMAGE := 1.25
## `progression.gd::UPGRADES["fire_rate"]["numero"]`, che e' un fattore
## **sull'intervallo** fra due colpi (`inversa: true`): la cadenza cresce di
## `1/0,85`.
const UPGRADE_FIRE_RATE := 0.85
## `weapon_base.gd::DAMAGE` al livello 1, prima di qualunque potenziamento.
const WEAPON_DAMAGE := 10.0
## `weapon_base.gd::FIRE_INTERVAL` al livello 1.
const WEAPON_FIRE_INTERVAL := 0.35
## `enemy.gd::TOUCH_DAMAGE_BASE`: il morso del runner, a ogni onda, per sempre.
const TOUCH_DAMAGE_BASE := 1.6
## `horde.gd::TOUCH_INTERVAL`: il tetto di cadenza dei morsi, l'unico capace di
## limitare il danno al secondo che l'orda consegna.
const TOUCH_INTERVAL := 0.15

## ## La dotazione dichiarata del giocatore: **tre carte, in ciclo**
##
## Il criterio di m14 confronta due numeri in hp/s, quindi il lato del giocatore
## deve essere **dichiarato**, non ottimistico: qui si dichiara la rotazione
## `[danno, cadenza, gittata]`, una carta per livello a partire dal livello 2, che
## e' esattamente la rotazione che l'utente ha citato playing («i potenziamenti
## di danno rateo e gittata»).
##
## La **gittata** non compare nel conto perche' `range` allunga
## `weapon.projectile_life` e non la cadenza ne' il danno: contarla sarebbe
## inventare potenza. Quindi su `POWER_CYCLE` carte, `POWER_CYCLE - 1` fanno
## danno al secondo e una no.
const POWER_CYCLE := 3

## ## La correzione dichiarata, e **da dove viene il numero**
##
## Con la legge `scale_of()` cosi' com'e', il rapporto fra la pressione che l'orda
## consegna e quella che il giocatore produce resterebbe **costante**, e sotto 1:
## all'onda 1 il giocatore fa `WEAPON_DAMAGE / WEAPON_FIRE_INTERVAL = 28,57` hp/s
## e l'orda ne puo' consegnare al massimo `10,67`. Serve quindi che la scala
## dell'orda cresca **oltre** la curva del giocatore, e di quanto e' **contato**:
##
##     necessario = (WEAPON_DAMAGE / WEAPON_FIRE_INTERVAL)
##                / ((1 / TOUCH_INTERVAL) * TOUCH_DAMAGE_BASE)   =  2,679
##
## e poi `necessario * CATCHUP_SAFETY`, distribuito **linearmente** su
## `END_WAVE - 1` onde. `CATCHUP_SAFETY` e' il margine dichiarato: `1 /
## TOUCH_INTERVAL` e' una cadenza **massima** teorica, e nessun giocatore che si
## muove la raggiunge mai, quindi il confronto va fatto con un margine e non sul
## carta. E' l'unico numero qui sotto che non sia derivato, ed e' dichiarato come
## tale perche' un numero che non si sa da dove viene e' il difetto di partenza.
const CATCHUP_SAFETY := 4.0

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
	return scale_of(w)

## Quante volte piu' fa male **un morso** sull'onda `w`.
##
## ## Perche' questa funzione esiste ed e' la parte che chiude il difetto
##
## Fino a m13 il morso era `enemy.gd::touch_damage_of(kind)`, cioe' la tabella
## delle specie: **uguale a ogni onda**. Quindi il danno al secondo che l'orda
## porta al giocatore era una costante, e la difficolta' non poteva crescere per
## nessun valore della vita. `tests/test_orda.gd::_difficolta` lo misura e lo
## chiama «pressione in ingresso»: senza questa funzione quel numero non
## esisterebbe e il criterio sarebbe irraggiungibile.
static func touch_scale_of(w: int) -> float:
	return scale_of(w)

## **La legge, e l'unica.** La scala dell'onda `w` e':
##
##     scala(w) = curva_di_potenza(livello_a_cui_si_era_all'inizio_di_w) x recupero(w)
##
##cioe' due fattori, e sono due perche' ciascuno copre un difetto diverso:
##
##   - **la curva di potenza** segue il giocatore. I potenziamenti sono
##     moltiplicativi e non hanno tetto, quindi la crescita della potenza del
##     giocatore e' **esponenziale nel livello** e il livello cresce con le
##     uccisioni, cioe' con l'onda (`player_level_at`). Una legge lineare in `w`
##     — quella di prima — non puo' stare al passo con una curva esponenziale:
##     e' il motivo per cui il numero giusto non si trova alzando un tetto.
##   - **il recupero** e' l'unico fattore che non viene dal giocatore, e copre il
##     divario di partenza fra quello che il giocatore fa e quello che l'orda puo'
##     consegnare (vedi `CATCHUP_SAFETY`).
##
## ## Perche' il livello e' quello di **inizio** onda e non quello di fine
##
## Perche' e' il livello con cui quell'onda e' stata impostata: il giocatore sale
## di livello **durante** l'onda, e il giudizio di m14 e' fra la scala che
## l'orda dichiara e la potenza che aveva quando l'onda e' cominciata. Con il
## livello di fine onda la scala inseguirebbe il giocatore con un'onda di ritardo
## e il divario si aprirebbe proprio dove il criterio guarda.
##
## ## Perche' non c'e' un tetto qui
##
## Non perche' «non serve»: un tetto qui sarebbe di nuovo lo stesso difetto con
## un altro numero. Il tetto che c'era era `HP_SCALE_MAX` e l'ha scelto il caso
## invece della legge; adesso non c'e' niente da scegliere, c'e' solo la legge da
## capire. `tests/test_orda.gd` asserisce che la scala **cresca strettamente** a
## ogni onda fino a `END_WAVE`: e' il criterio che oggi mancava, e senza di lui
## il tetto si potrebbe reintrodurre in un pomeriggio di qualcun altro.
static func scale_of(w: int) -> float:
	var n := maxi(w, 1)
	var potenza := power_ratio_of(player_level_at(n - 1))
	return HP_SCALE_BASE * potenza * catchup_of(n)

## ## La curva di potenza: quanti potenziamenti ha preso il giocatore
##
## `at_level - 1` carte, cioe' uno per livello **dal livello 2 in poi** (il
## livello 1 e' quello di partenza e non ha scelto niente). Le carte girano in
## `POWER_CYCLE`: una di danno, una di cadenza, una di gittata. Solo le prime due
## contano, perche' la gittata non cambia danno ne' cadenza.
##
## Il risultato e' **un moltiplicatore di danno al secondo**, non di vita: e' il
## numero con cui la scala dell'orda e' confrontabile, e percio' e' l'unico che
## va messo in paragone con la pressione in uscita.
static func power_ratio_of(at_level: int) -> float:
	var prese := float(maxi(at_level - 1, 0))
	var cicli := floori(prese / float(POWER_CYCLE))
	var resto := prese - float(cicli) * float(POWER_CYCLE)
	# `resto` e' 0, 1 o 2. I due `+1` sono la carta di danno e quella di cadenza
	# dentro il ciclo non ancora finito.
	var n_danno := float(cicli) + (1.0 if resto >= 0.5 else 0.0)
	var n_cadenza := float(cicli) + (1.0 if resto >= 1.5 else 0.0)
	return pow(UPGRADE_DAMAGE, n_danno) / pow(UPGRADE_FIRE_RATE, n_cadenza)

## Il recupero di `CATCHUP_SAFETY`, lineare in `w` e valido **1,0 all'onda 1**.
##
## Il `maxi(..., 1)` nel denominatore e' perche' `END_WAVE` e' dichiarato e puo'
## essere portato a 2 da qualcuno: senza, la divisione per zero renderebbe tutta
## la legge `INF` e il difetto si ripresenterebbe come un crash invece che come
## una difficolta' sbagliata.
static func catchup_of(w: int) -> float:
	var n := float(maxi(w, 1) - 1)
	var tetto := (1.0 / TOUCH_INTERVAL) * TOUCH_DAMAGE_BASE
	var necessario := (WEAPON_DAMAGE / WEAPON_FIRE_INTERVAL) / maxf(tetto, 0.000001)
	return 1.0 + necessario * CATCHUP_SAFETY * n / float(maxi(END_WAVE - 1, 1))

## Quante uccisioni chiude l'onda `w` in tutto, dalla prima all'ultima: il
## **numeratore** del livello del giocatore. Statico perche' e' una domanda sulla
## tabella, non uno stato in corso.
static func uccisioni_fino_a(w: int) -> int:
	var tot := 0
	for i in range(1, maxi(w, 0) + 1):
		tot += wave_size(i)
	return tot

## A che livello e' il giocatore **finita** l'onda `w`.
##
## ## Il ponte fra le due metà del criterio
##
## Il criterio di m14 confronta due numeri che vivono su due assi diversi: la
## scala dell'orda e' un indice di **onda**, la potenza del giocatore e' una
## funzione del **livello**. Il ponte e' questo: `XP_PER_KILL` per uccisione e
## soglie `XP_BASE + XP_STEP x (livello - 1)`, cioe' esattamente le curve di
## `src/player/progression.gd`.
##
## `player_level_at(0)` vale 1, e quindi `scale_of(1)` non moltiplica per nessuna
## potenza: e' il motivo per cui l'onda 1 resta a `1.0` esatto come chiede il
## criterio n. 4 della milestone 1.
static func player_level_at(w: int) -> int:
	var xp_tot := XP_PER_KILL * float(uccisioni_fino_a(maxi(w, 0)))
	var livello := 1
	var speso := 0.0
	while true:
		var soglia := XP_BASE + XP_STEP * float(livello - 1)
		if speso + soglia > xp_tot:
			break
		speso += soglia
		livello += 1
	return livello

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
##
## ## La cache, e perche' `scale_of(w)` va calcolata una volta sola
##
## `scale_of` chiama `player_level_at`, che chiama `uccisioni_fino_a`, che chiama
## `wave_size` in un ciclo: sono poche decine di operazioni, ma `hp_scale()` viene
## chiamata **una volta per nemico che nasce** (`horde.gd::_apply_spawn`). Non e'
## un costo che si vede, e' un costo che cresce con la difficolta' che stiamo per
## mettere: `scale_of(61)` chiama `wave_size` sessantuno volte. La cache e' due
## numeri e una domanda, e la parola chiave e' `static` perche' `player_level_at`
## resta una domanda sulla tabella e non uno stato.
var _scala_onda: int = -1
var _scala_valore: float = 1.0

func hp_scale() -> float:
	return touch_scale()

## ## Perche' i due metodi sono lo stesso numero
##
## Vita e morso crescono con **una** legge: se il morso crescesse piu' piano
## della vita, la difficolta' che il giocatore sente sarebbe quella del morso e
## il tetto che m14 chiude tornerebbe, spostato di una riga. Il criterio di
## `tests/test_orda.gd::_difficolta` confronta i due numeri e fallirebbe.
func touch_scale() -> float:
	if _scala_onda != wave:
		_scala_onda = wave
		_scala_valore = scale_of(wave)
	return _scala_valore

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
