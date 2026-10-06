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

func _init() -> void:
	wave_total = wave_size(1)

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
