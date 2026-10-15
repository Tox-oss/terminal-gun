extends SceneTree
## Test dell'orda (terminal-gun-orda). Dimostra con numeri il criterio n. 3 della
## milestone: 200 nemici vivi senza un nodo per nemico.
##
## Verifica, in ordine:
##   1. `count == 200` al riempimento iniziale e `transforms.size() == count`;
##   2. la griglia restituisce **gli stessi indici** di una scansione lineare
##      (stessa distribuzione, stesse query, risultati identici): una griglia
##      piu' veloce ma sbagliata non e' una griglia;
##   3. `nearest_enemy_index` sull'indice atteso, e -1 quando il raggio e' vuoto;
##   4. 1000 query di prossimita' su 200 nemici in meno di 50 ms, e la griglia
##      piu' rapida della scansione lineare: misurati su 8 giri e riportati come
##      minimo e mediana, perche' una corsa sola e' rumore e fallirebbe a caso;
##   5. 600 aggiornamenti in headless: nessun SCRIPT ERROR, nessuna crescita di
##      nodi, oggetti e memoria;
##   6. `damage_enemy` uccide e il conteggio scende, per scambio-ultimo;
##   7. m11-bis-b: dopo `restart_run()` due partite consecutive hanno
##      **disposizioni diverse** (criterio n. 2 di §1.14-ter), e `reseed` resta
##      riproducibile: il rimedio non può aver scambiato «ogni misura è un
##      campione» con «ogni partita è la stessa».
##
## ## m9: il raggio dell'arena è in sei copie, e due di queste sono mie
##
## La fonte del raggio è `src/render/arena.gd:ARENA_RADIUS` (**60.0** dal 2026-10-14,
## era **46.0** dal 2026-10-13), il numero di oggi è uscito dalla sonda
## `docs/piramide/probe_survive.gd` (piano §1.14-quinque) e le altre cinque copie
## sono fallback dichiarati o default (la tabella è in §1.12-bis). Di questa foglia:
##
##   - `src/sim/horde.gd` è la copia n. 3: un **fallback dichiarato**, che vale
##     solo quando il contratto non c'è ancora. La sezione 13 lo asserisce
##     leggendo **dal sorgente** e confrontandolo col default del contratto. Con
##     il passaggio a 60 m questa sezione è quella che è andata **rossa** per
##     prima: il contratto diceva già 60,0 m e il fallback diceva ancora 46,0 m.
##   - il **campionamento delle query** di questo file campionava un quadrato
##     `±28` scritto a mano. Non asseriva il raggio, quindi **non è diventata
##     rossa** quando l'arena è passata a 46: campionava metà del disco, il
##     benchmark restava verde e la copertura si era dimezzata in silenzio. È la
##     classe di difetto di §3.6-bis, e la sezione 7 lo chiude.
##
## ## m11: perché 46,0 -> 60,0, e cosa misura il raggio nuovo
##
## Il **prima** e il **dopo** nella stessa frase, perché un raggio non è una
## costante di stile: è la geometria su cui converge tutta la simulazione, e
## quattro numeri ne discendono per costruzione, non per scelta.
##
##   - **prima 46,0 m** (m9): dalla sonda `probe_arena_density.gd` (piano §1.12) —
##     a 200 nemici lo spazio libero passava dall'85,2% al 94,6% e la bolla sicura
##     più grande da 9,5 a 19,1 m;
##   - **dopo 60,0 m** (m11): dalla sonda `probe_survive.gd` (piano
##     §1.14-quinque), che misura la **sopravvivenza** di uno schivatore al variare
##     del raggio, tre semi per raggio e con due casi a risposta nota (a R = 12 m,
##     dove non si può schivare, lo strumento **deve** morire: è morto a 61,20 s).
##     Caso peggiore **55,33 s a 46 m** contro **146,72 s a 60 m**, fattore
##     **2,65**; da 60 a 75 m il fattore è **1,07**, quindi il ginocchio è a circa
##     60 m e oltre non si compra niente.
##
## Nessuna costante di `src/sim/` è cambiata per il passaggio: è cambiata la
## geometria. Le quattro cose che ne derivano sono **rimisurate nello stesso
## lancio, a 46,0 m e a 60,0 m, dalla stessa funzione** (sezione 13e-bis): la
## griglia del campo, i dischi, la griglia dei vicini e il costo per passo.
##
## ## LA MISURA DEL PRIMA, e perche' questo file la porta in testa
##
## Il numero di sotto e' la base di tutta la milestone 4, ed e' stato misurato
## **prima** di toccare una riga di `src/sim/`. Strumento: questo stesso file,
## con un blocco di misura temporaneo poi rimosso, sull'orda isolata con il fuoco
## al centro dell'arena (raggio 28 m) e passo fisso 1/60 s.
##
## | cosa si misura | prima di m4 | dopo m4 |
## |---|---|---|
## | nemici vivi al **primo frame** | **200** | **25** (`Run.POP_BASE`) |
## | tempo per arrivare alla popolazione piena, dall'avvio | **0.0000 s** (0 passi: era gia' pieno) | 0.0000 s (25, che e' il tetto dell'onda 1) |
## | tempo per riempire **dopo uno svuotamento totale** | **0.0167 s** (1 passo, da 0 a 200) | **3.13 s** (188 passi, da 0 a 25) |
## | primo contatto, nessun vivo entro 3 m dal bersaglio | **t = 0.02 s** | **t = 2.28 s** |
## | 25 nemici entro 6 m dal bersaglio | **t = 1.68 s** | **t = 5.52 s** |
## | a regime (t = 20 s) con 200 vivi | **104 entro 6 m** (52%) | 76 entro 6 m su 160 vivi (il campo e' ancora in rampa) |
##
## **Perche' la riporta questo file e non `run.gd`.** `run.gd` dichiara i numeri
## che sono usciti da questa misura, e dichiarare una derivazione senza la
## misura sarebbe un numero scelto a occhio: `run.gd` rimanda a qui, e qui la
## tabella e' scritta per prima, coi numeri di allora.
##
## ## Perche' il test continua a volere 200 nemici
##
## La capacita' e' un criterio di m1 e resta un criterio: questo file pilota
## **la propria** `population` (`horde.population = HORDE.MAX_ENEMIES`) e la porta
## a 200 col ritmo di `run.spawn_rate()`, quindi non dipende dalla curva delle
## onde e non smette di esistere quando la curva cambia. Il tempo che ci mette e'
## anche una misura: viene stampato, ed e' il numero che rende visibile che
## raggiungere 200 ora costa dei secondi e non un passo.
##
## Nota sul contratto: `nearest_enemy` e' `-> int` e `damage_enemy` e' `-> bool`
## (piano 5.2), quindi qui si chiama **anche** il contratto, non solo
## `horde.nearest_enemy_index(...)`: se le due strade dessero risposte diverse,
## il gioco in partita punterebbe a un nemico diverso da quello che il test
## crede di aver colpito.
##
## ## `--quit-after` in headless NON e' un misurino
##
## Resta qui perche' e' costata una notte di prove false. `--quit-after N` conta
## **frame**, non passi di fisica: sotto `--headless --script` il motore gira
## senza orologio, quindi 300 iterazioni sono state 132 passi di fisica reali --
## e quel rapporto si sposta col carico della macchina, non col codice. Ne
## segue che due esecuzioni consecutive dello stesso comando, a configurazione di
## gioco identica, danno numeri diversi: durante il bisect del leak la traccia
## e' comparsa ed e' sparita senza che nessuna riga di `src/sim/` cambiasse. Le
## prime due prove erano rumore, e il colpevole vero era un suono da 0,18 s
## ancora in riproduzione all'uscita del motore.
##
## **La regola.** Un numero preso con `--quit-after` in headless e' un numero
## che cambia col carico: se qualcuno lo usa come misurino, deve saperlo prima
## di fidarsi, e non puo' confrontarlo con una corsa precedente perche' le due
## corse non hanno girato lo stesso numero di passi. Per misurare si guida un
## passo di fisso dal test -- e' il `DT` qui sotto, 1/60 s, lo stesso di
## `tests/test_gameloop.gd` -- e si contano i passi, non le iterazioni.

const H = preload("res://tools/test_harness.gd")
const HORDE = preload("res://src/sim/horde.gd")
const RUN = preload("res://src/sim/run.gd")
const GRID = preload("res://src/sim/spatial_grid.gd")
const POOL = preload("res://src/sim/object_pool.gd")
const ENEMY = preload("res://src/sim/enemy.gd")
const FLOW = preload("res://src/sim/flow_field.gd")
const OBST = preload("res://src/sim/obstacles.gd")
const SPAWNER = preload("res://src/sim/spawner.gd")

## ## I NUMERI DI m10: la geometria e la risoluzione del campo
##
## Nessuna cifra e' scritta sopra nel piano (§1.13) e nessuna e' scritta sopra
## qui: sono la **misura** del criterio n. 2 e il prodotto della misura. Quello
## che segue e' la misura, e quello che segue la misura e' la scelta.
##
## Strumento: questo stesso file, sezione 13, ordine a 200 nemici, seme 4242,
## passo fisso 1/60 s, 600 passi di assestamento e 1800 passi di finestra, con
## la geometria dichiarata in `src/sim/obstacles.gd` montata sul campo.
##
## ### La geometria (`src/sim/obstacles.gd`)
##
## Il **prima** e il **dopo** nelle stesse righe, e la ragione per cui la
## tabella ha quattro colonne invece di tre: in m11 il raggio e' passato da 46,0
## a 60,0 m e **nessuna costante di questo file e' cambiata** (vedi sotto).
##
## | numero | a 46,0 m (m9/m10) | a 60,0 m (m11) | da dove viene |
## |---|---|---|---|
## | ostacoli | **27** dischi, tutti uguali | **27**, invariati | 6 + 9 + 12 su tre anelli: abbastanza da mettere un muro davanti a chi arriva da fuori, non abbastanza da chiudere un anello. Il **numero non e' stato ritoccato** e la riga dell'area dice perche' |
## | raggio del disco | **2,99 m** | **3,90 m** | `0,065 x R`, cioe' una **frazione**: il disco cresce con l'arena da solo. Era 1,6 volte la sagoma del boss (1,90 m), e' ora 2,1 volte: un disco piu' piccolo del nemico piu' grosso si aggira senza sembrare un muro, e questo resta vero |
## | anelli | **15,18 / 27,14 / 39,10 m** | **19,80 / 35,40 / 51,00 m** | frazioni 0,33 / 0,59 / 0,85 di R. Il piu' interno lascia **19,80 m** liberi al centro, e `MIN_SPAWN_GAP` e' 12,0: nessuno spawn del contratto puo' quindi nascere dentro un ostacolo, come a 46 m |
## | dischi piu' vicini | **11,97 m** | **15,61 m** | misurati con `OBST.min_separation`, non progettati: sono la distanza fra due centri su due anelli diversi |
## | passaggio utile | **5,99 m** = 1,58x il boss | **7,81 m** = **2,06x** il boss | `distanza minima - 2 x raggio`: e' la **pista** che il nemico deve attraversare, e a 60 m **cresce**. I dischi non diventano piu' fitti: si allargano con l'arena e lasciano fra loro un corridoio piu' largo, quindi le costanti di questo file restano quelle di m10 |
## | area coperta | **11,4%** del disco | **11,4%** | `27 x 0,065^2` non dipende da R: la copertura areale e' la stessa ai due raggi (la tabella di m10 scriveva 11,5%, stesso numero con un arrotondamento diverso), ed e' per questo che **numero e frazione non vanno ritoccati** per allungare il raggio |
##
## ### Il campo (`src/sim/flow_field.gd`)
##
## | numero | a 46,0 m (m9/m10) | a 60,0 m (m11) | da dove viene |
## |---|---|---|---|
## | cella | **2,0 m** | **2,0 m** | la griglia dei vicini e' 4,0 m: quella elenca chi c'e', questa dice da che parte andare, e due domande diverse non si pagano con la stessa risoluzione |
## | griglia | **55 x 55 = 3.025 celle**, 53,2 KB | **69 x 69 = 4.761 celle**, **83,7 KB** | `arena_radius + 8 m` di margello a celle da 2 m, quindi **1,57 volte** le celle e **+30,5 KB**. Sono 18 byte per cella (`blocked` e `fuori` un byte, `cost`, `dir_x`, `dir_z`, `queue` quattro), presi **una volta sola** dentro `build()` e mai piu': la memoria cresce col raggio, il costo per passo no (vedi sotto) |
## | gonfiatura | **6,65 m** | **7,56 m** | raggio del disco + corpo del **boss** (1,90 m) + 0,35 m di margine + 0,71 m di meta' diagonale della cella |
## | celle bloccate | **584** su 3.025 (19,3%) | **800** su 4.761 (16,8%) | la frazione **scende**: i dischi ingrandiscono, ma il disco dell'arena ingrandisce di piu' |
## | ricostruzione | solo se il bersaglio si e' muove di **6,0 m** | idem, non e' cambiata | da fermo (che e' il caso in cui il gioco si vorrebbe vincere) il campo costa **zero**: misurato in sezione 13b e rimisurato in 13e-bis |
##
## **Nessuna riga di `src/sim/flow_field.gd` e' cambiata in m11**, e il file non e'
## di questa foglia: la griglia e' gia' dimensionata sul raggio che riceve
## (`build(obs, arena_radius, ...)`), quindi al raggio nuovo e' il codice di
## sempre che produce il numero nuovo. Quello che resta **misurato** e' il
## costo, perche' una BFS su 4.761 celle costa piu' di una su 3.025.
##
## ### La frazione che deve aggirare, e **su che cosa e' misurata**
##
## Il numero che conta non e' l'area coperta, e' **quanta parte dell'orda deve
## aggirare**: la frazione di nemici la cui retta verso il giocatore e'
## interrotta da un disco gonfiato del corpo del boss.
##
## **Su che cosa e' campionata, e la correzione che l'ha reso misurabile.** Il
## campione parte dall'orda piena e copre `M10_WARMUP + M10_WINDOW` = 2400 passi
## (40 s), ogni 10 passi, per 48 000 segmenti. Il campione di **prima** copriva
## solo gli ultimi 1800, cioe' il periodo di regime, e dava **3,4%**: quel numero
## non era una misura della deviazione, era una misura di **quanto era lontano il
## nemico**. A regime `t_primo` e `t_meta` sono entrambi **0,00 s**, cioe' meta'
## dell'orda e' gia' dentro `ARRIVE_RADIUS` al primo passo campionato: un nemico
## a 2 m dal bersaglio ha una retta di 2 m e il disco piu' vicino e' a 12,19 m, e
## la domanda «la mia retta e' interrotta?» ha risposta **no** qualunque sia la
## geometria. Il tetto superiore della banda («non piu' del 60%, altrimenti
## l'orda si muove a ondate») su quella domanda non poteva parlare di ondate.
##
## I due numeri vengono stampati **entrambi** a ogni lanzo (sezione 13b), e la
## banda e' scritta sul primo, dichiarando quale dei due e'.
##
## | numero misurato | a 46,0 m (m10) | a 60,0 m (m11) | da dove viene |
## |---|---|---|---|
## | retta interrotta, **tutto il percorso** | **14,1%** (6787 su 48 000) | **13,0%** (6223 su 48 000) | il numero che governa la banda `M10_DEVIA_MIN/MAX`: resta dentro, e la banda non e' stata mossa |
## | retta interrotta, **solo finestra di regime** | **3,4%** (1216 su 36 000) | **2,1%** (769 su 36 000) | il numero di prima era quanto lontano l'orda, non quanto devia; a 60 m scende perche' nella finestra di regime l'orda e' meno addensata (arrivare al centro da 60 m ci mette piu' tempo) |
##
## **Il 13,0% e' piu' alto dell'11,4% di area coperta, ed e' giusto**: la domanda
## non e' «quanto disco c'e'» ma «quante rette ci passano dentro», e una retta
## sposta un disco di 3,90 m su una fascia di 6,15 m gonfiata del corpo del boss
## (2,99 m e 5,24 m a 46 m: la stessa domanda, numeri diversi).
## Il rapporto fra le due domande e' il rapporto fra l'area di un disco e la
## lunghezza del corridoio che quello disco chiude: la copertura areale non puo'
## essere il tetto della banda, e non lo e'.
##
## La banda resta **5% - 60%**, e i numeri non sono stati abbassati per far passare:
## il 13,0% sta a 2,6 volte il pavimento e a 4,6 volte dal tetto, quindi una
## geometria che coprasse il doppio o che si azzerasse del tutto andrebbe rossa.
## Sotto il 5% la milestone e' invisibile (l'orda attraversa i dischi come se non
## ci fossero); sopra il 60% l'orda si muove a ondate e il gioco diventa un
## labirinto.

## Passo di simulazione: quello di `tests/test_gameloop.gd`, cosi' i due numeri
## di -orda sono confrontabili. Un passo fisso e' l'unica misura riproducibile.
const DT := 1.0 / 60.0
## Seme della disposizione con cui il benchmark di griglia viene misurato.
## Vedi `_population`: serve a tornare alla condizione ad anelli e a rendere il
## numero di oggi confrontabile con quello di m1.
const SEME_CAPACITY := 20260912

## Bersaglio dei nemici in questo test: il centro dell'arena, perche' -gameplay
## non e' registrato in questo processo.
const FOCUS := Vector3.ZERO
## Un punto in cui non c'e' e non puo' esserci nessun nemico. Non e' una copia
## del raggio: e' un punto **fuori dal campo**, a circa 15 raggi di distanza con
## l'arena da 60 m, e resta fuori qualunque arena che possa stare qui dentro.
const LONTANO := Vector3(900.0, 0.0, 900.0)

## Oggetto del pool: serve solo per contare, non ha comportamento.
class Thing extends RefCounted:
	var tag: int = 0

## Solo l'inserimento nell'albero. Il corpo del test gira al **primo frame**, in
## `_process`: sotto `--script` l'entrata nell'albero di un nodo aggiunto a
## `root` dalla `_initialize()` passa dalla coda di messaggi, quindi
## `horde._ready()` non e' ancora partito quando `_initialize()` finisce e il
## test leggerebbe `count == 0` su un'orda che non si e' ancora costruita.
## L'orda sotto test. Campo e non variabile di `_initialize()` perche' il corpo
## del test gira al primo frame, e a quel punto `_initialize()` e' gia' tornata.
var _horde: HORDE = null

func _initialize() -> void:
	_horde = HORDE.new()
	_horde.name = "Orda"
	# Il test vuole vedere il conteggio scendere quando un nemico muore: senza
	# questo, `_top_up()` lo riemPIREbbe entro lo stesso passo.
	_horde.auto_respawn = false
	root.add_child(_horde)

## `SceneTree._process` restituisce `true` per chiudere il ciclo: e' il `quit()`
## del test, e non viene prima perche' a questo punto l'orda e' viva.
func _process(_delta: float) -> bool:
	_run()
	return true

func _run() -> void:
	# Il costo di tutto il file: `TEST_TIMEOUT_MS` e' 120 s e l'utente ha deciso
	# che non si alza, quindi il numero che dice se c'e' margine va stampato a ogni
	# lancio e non misurato a mano quando serve.
	var t0 := Time.get_ticks_msec()
	var h := H.new()
	var horde: HORDE = _horde
	if horde == null:
		h.fail("l'orda aggiunta in _initialize() non e' piu' nell'albero")
		quit(h.finish("orda"))
		return

	_population(h, horde)
	_no_node_per_enemy(h, horde)
	_registration(h, horde)
	_copie_del_raggio(h, horde)
	_grid_matches_linear(h)
	_nearest(h, horde)
	_spawn_points(h, horde)
	_query_budget(h, horde)
	_object_pool(h)
	_burn_in(h, horde)
	_damage_kills(h, horde)
	# m10: gli ostacoli. Le sezioni 13 girano **prima** di `_touch`, che registra
	# uno spia al posto del giocatore: qui il bersaglio e' `set_focus`, quindi
	# nessun morso si accende e la misura resta di geometria e di movimento.
	_ostacoli(h, horde)
	_aggira(h, horde)
	_incastrati(h, horde)
	_denti_del_criterio(h, horde)
	_spawn_sicuro(h, horde)
	# m11: il raggio 46 -> 60. Sta qui perche' rimette a posto contratto,
	# geometria, campo e seme prima che `_touch` misuri il morso: `_misura_morso`
	# non ripopola da zero e troverebbe l'orda nel raggio lasciato dalla sezione
	# precedente invece che in quello dichiarato.
	_raggio_60(h, horde)
	_touch(h, horde)
	# m11-quarta: il morso e la taglia disegnata. Sta **dopo** `_touch` perche'
	# la condizione del morso si accende solo con un giocatore registrato, e lo
	# spia di `_touch` e' l'unico che questo file abbia: prima di lui nessun
	# morso puo' partire e la sezione misurerebbe il vuoto. Sta **prima** di
	# `_reroll` perche' quella chiama `restart_run()` e rimetterebbe a posto
	# l'orda che qui e' stata ridotta a un nemico per specie.
	_banda_morso(h, horde)
	# m11-bis-b: il reroll della sezione 14. Sta qui, dopo `_touch` e **prima**
	# di `_scena_vera`, e il posto e' dichiarato nella sezione: sulla scena vera un
	# restart rimescolerebbe proprio il numero che il criterio n. 1 di 1.14-ter
	# confronta fra montaggi.
	_reroll(h, horde)
	# m11-ter: la cucitura di misura dell'apertura. Sta qui perche' e' l'unica
	# sezione che **cambia** un numero di gioco e lo rimette: prima di
	# `_scena_vera`, che deve trovare l'orda costruita dal suo codice e non una
	# raddrizzata a mano, e dopo `_reroll`, che usa `restart_run()` e avrebbe
	# potuto assorbire una delle tre scale che questa sezione prova.
	_scala_nei_file(h)
	_scala_popolazione(h, horde)
	# I due cammini della miscela. Sta **qui**, dopo `_scala_popolazione` (che
	# rimette a posto `population` e `population_scale`) e prima di `_scena_vera`
	# (che monta la scena vera e registra l'orda e il giocatori del gioco): la
	# sezione deve parlare con l'orda isolata, e deve poter cambiare onda e
	# riempire il campo senza che nessuno dopo trovi l'orda com'era.
	_miscela_respawn(h, horde)
	# Per ultima, e non per caso: `_scena_vera` carica `scenes/arena_main.tscn`,
	# che registra sul contratto l'orda e il giocatore **veri**. Farla prima
	# significherebbe che le sezioni precedenti parlassero con l'altra orda senza
	# accorgersene, quindi va in fondo e poi rimette a posto il contratto.
	_scena_vera(h, horde)
	# E l'ultima di tutte, perche' e' l'unica che guarda **il contratto**:
	# `Game.obstacles` lo scrive `-arena` in `_enter_tree()`, quindi il dato
	# esiste solo dopo che la scena vera e' entrata nell'albero.
	_ostacoli_contratto(h, horde)

	print("orda: tutto il file in %d ms, ne restano %d dei 120000 del test" \
		% [Time.get_ticks_msec() - t0, 120000 - (Time.get_ticks_msec() - t0)])
	quit(h.finish("orda"))

# --- 11. Il morso: il nemico chiama Game.damage_player (milestone 7) ----------
#
# ## La sezione che dimostra il criterio n. 1 di m7
#
# Il criterio n. 1 e' una `grep`, non un'asserzione: il chiamante di
# `damage_player` deve stare in `src/`, e un chiamante solo in `tests/`
# dimostrerebbe che la funzione **funziona** e non che **qualcuno la chiami**
# (piano sez. 1.6). Qui sotto ci sono tre prove, e nessuna e' "chiamo la
# funzione e guardo che cosa fa":
#
#   1. una `grep` vera sul disco: fra i file di `src/`, `damage_player`
#      compare solo nel contratto (che lo dichiara) e in `src/sim/horde.gd`
#      (che lo chiama);
#   2. lo **spia** di sotto riceve le chiamate ma non le fa: e' il giocatore,
#      non il nemico. Il totale che arriva allo spia viene confrontato con il
#      totale che l'orda dichiara di aver consegnato (`touch_damage_last`), e
#      i due numeri devono coincidere passo per passo;
#   3. ogni numero che arriva allo spia deve essere **uno dei quattro** della
#      tabella delle specie: nessun numero di danno scritto a mano qui dentro
#      (criterio n. 6 di m7).
#
# ## Il giocatore finto e' una spia, non un giocatore
#
# `player_position` e `damage_player` sono le due API che registra -gameplay.
# Non sono un trucco per far funzionare il test: sono il contrattino che il
# nemico si trova davvero davanti in partita, e registrarle e' l'unico modo di
# misurare senza toccare `src/player/`, che non e' di questa foglia.

## Dove sta il giocatore finto. Non e' l'origine: `_player_focus()` rifiuta un
## punto a distanza quasi nulla e ripiega sul fuoco dell'orda, quindi un
## giocatore finto all'origine misurerebbe una cosa diversa dal gioco.
const FAKE_PLAYER := Vector3(3.0, 0.0, -5.0)

## Passi di misura dell'economia del morso. 1800 passi a DT = 1/60 sono 30 s,
## dieci volte il periodo massimo di morso (boss ~2.9 s): la finestra contiene
## molti periodi e non un numero che dipende dalla fase.
const TOUCH_STEPS := 1800

## Vita massima del giocatore di riferimento, **solo per tradurre un danno al
## secondo in secondi di sopravvivenza**. Non e' un numero di gioco: nessuna
## riga di `src/` lo usa e nessuno puo' leggerlo da qui. Il valore (100.0) e'
## misurato sulla scena vera, e serve a dare un'unita' leggibile ai numeri.
const PLAYER_HP_REFERENCE := 100.0

## Bande di misura, non soglie di robustezza: i numeri che escono sono scritti
## sotto questa sezione e vengono ricontrollati a ogni lancio.
##
## La cadenza: sotto `BITE_RATE_MIN` nessuno morderebbe (e il chiamante di m7
## sarebbe sparito senza che nessuno se ne accorga), sopra `BITE_RATE_MAX` il
## tetto `TOUCH_INTERVAL` non terrebbe, perche' `1/0.40 = 2.5`.
##
## ## Le tre bande sono state cambiate due volte, e i valori di prima sono qui
##
## **Una volta in m8**, quando il numero che le muove e' `TOUCH_REACH`, sceso da
## **1.2** a **0.45**: la derivazione e' in `src/sim/enemy.gd` e la misura sulla
## scena vera e' nella sezione 12. Accorciare la portata toglie corpi a portata, e
## i morsi arrivano meno spesso.
##
## **E una volta in m9**, quando il numero che le muove e' **il raggio
## dell'arena, da 28 a 46** (la fonte e' `src/render/arena.gd:ARENA_RADIUS`, il
## numero e' uscito dalla sonda `docs/piramide/probe_arena_density.gd`, piano
## §1.12). Nessuna riga di `src/sim/` e' cambiata: e' cambiata **la geometria su
## cui la simulazione converge**. Nessuna delle due estremita' della banda si e'
## mossa da sola, e vanno guardate insieme perche' il rapporto e' un quoziente.
##
## **E una terza volta in m11**, quando il raggio e' passato da **46 a 60**
## (piano §1.14-quinque). Di nuovo nessuna riga di `src/sim/`: e' la stessa
## forma del passaggio di m9, ed e' per questo che la colonna si aggiunge invece
## di sostituire una costante.
##
## | banda | m7 (1.2, R=28) | m8 (0.45, R=28) | m9 (0.45, R=46) | **m11 (0.45, R=60)** | perche' |
## |---|---|---|---|---|---|
## | cadenza misurata | 1.07-1.57 morsi/s | 0.60-1.17 | 0.50-1.07 | **0.57-1.03** | 3-5 corpi a portata invece di 5-20; poi l'anello su un disco 2,7 volte piu' largo |
## | danno al secondo | 3.3-8.5 hp/s | 3.42-11.19 | 2.39-14.37 | **3.37-14.17** | le due estremita' vanno in **direzioni opposte** |
## | sopravvivenza massima | 16.5 s | 29.2 s | 41.8 s | **29.7 s** | segue la cadenza dell'onda piccola |
## | rapporto danno pieno/piccolo | 2.56 | 3.27 | 6.01 | **4.21** | vedi sotto: non e' l'orda piena che e' cresciuta |
##
## **Le quattro colonne, e cosa dice il passaggio a 60 m.** Il quoziente scende
## da 6,01 a **4,21** e il tetto `DPS_RATIO_MAX = 7.5` **non e' stato toccato**:
## il numero si e' mosso da solo, verso il basso, perche' il denominatore e'
## risalito (2,39 -> 3,37 hp/s sull'onda piccola) e il numeratore e' sceso di poco
## (14,37 -> 14,17 hp/s sull'orda piena). La ragione e' la stessa di m9 e si vede
## nel campione dei morsi (caso seme 4242, 25 vivi): a 46 m l'onda piccola tirava
## **4 runner su 15 morsi**, a 60 m ne tira **0 su 17** e tutti e 17 sono **brute**
## da 5,94 hp: il disco piu' largo diluisce l'anello di contatto e il morso cade
## sui corpi piu' grossi, che mordono piu' forte ma molto meno spesso. La banda resta quindi quella dichiarata, con lo stesso tetto e lo
## stesso pavimento, e il criterio continua a poter fallire.
##
## **Le due estremita' del rapporto, con i numeri.** L'onda piena fa **1.37 volte**
## il danno di prima (10.51 -> 14.37 hp/s) e l'onda piccola fa **0.70** (3.42 ->
## 2.39 hp/s): il quoziente passa da 3.27 a 6.01 senza che nessuno dei due numeri
## sia impazzito. Il campione dei morsi spiega il calo: a 28 m l'onda piccola li
## tirava quasi tutti di **boss** (13.71 hp, 17 morsi su 18), a 46 m ne tira **4
## su 15 di runner** (1.60 hp) — su un disco largo l'anello intorno al giocatore
## ha piu' posto e il morso tocca piu' spesso un corpo piccolo. Quindi il 6.01 non
## vuol dire "l'orda piena e' sei volte l'onda piccola": vuol dire che **il
## denominatore e' sceso**, e il numero storico di ~5.7 volte (senza
## `TOUCH_INTERVAL`) non e' piu' un metro con cui confrontare, perche' e' stato
## scritto su un'altra arena.
##
## **E in m11 il tetto non e' sceso**, e la ragione e' la regola di §1.2 applicata
## al caso che nessuno aveva previsto: con R = 60 la misura dà **4,21** (era 6,01
## a R = 46) e `DPS_RATIO_MAX` resta **7,5**. Un tetto si alza quando il numero
## sale e **non si abbassa quando il numero scende**: abbassarlo toglie al
## criterio la capacita' di fallire su un'orda che si riempie di corpi grossi. Il
## numero e' sceso perche' l'anello di contatto si e' diluito sul disco piu'
## largo, non perche' il gioco faccia meno danno: le due cose si somigliano nel
## quoziente e non sono la stessa cosa.
##
## Il **valore di m8 non e' una regressione e non e' difeso**: e' la richiesta
## dell'utente, e il piano lo dichiara (§1.11, "cosa cambia nella difficolta'").
##
## ## Perche' i margini sono quelli che sono
##
## Un caso da 30 s contiene **15-32 morsi**: un morso in piu' o in meno sposta il
## danno al secondo del 5-20%, e sul rapporto del 20% e oltre. Una soglia a un
## morso dal numero misurato non e' una soglia: e' un caso fortunato che fallisce
## a caso. Percio' i tre numeri qui sotto stanno **lontani** dalla misura, non
## appiccicati: il pavimento di cadenza e' a meta' del minimo misurato e il tetto
## del rapporto e' un quarto sopra il massimo misurato. Restano tetr**i** lo stesso:
## un morso che sparisce del tutto, un tetto a intervallo che non tiene e un'orda
## piena che diventa cinque volte la piccola vanno rossi tutti e tre.
const BITE_RATE_MIN := 0.25
const BITE_RATE_MAX := 2.5
## Secondi che un giocatore regge **fermo al centro dell'orda** con 100 hp.
const SURVIVAL_MIN := 5.0
const SURVIVAL_MAX := 50.0
## L'orda da 200 vivi puo' fare al massimo questo multiple del danno al secondo
## dell'orda piccola. **Il primo tetto dichiarato era 2.0 ed era sbagliato**:
## la misura sul campione qui sotto dava 2.56, e la differenza non e' rumore ma
## il campione dei morsi: con 25 vivi il contatto lo fanno quasi solo brute
## (5.94 hp), con 200 vivi quasi solo boss (13.71 hp), perche' l'anello intorno
## al giocatore si riempie dei nemici piu' grossi. Era 3.0 fino a m7; con
## `TOUCH_REACH` a 0.45 e R=28 la misura dava **3.27** e il tetto era 4.0. In m9,
## con R=46, la misura da' **6.01** e il tetto sale a 7.5 — col paragrafo sopra,
## che spiega perche' il quoziente e' salito e da dove. Il tetto resta un tetto
## vero: **senza** `TOUCH_INTERVAL` il campione crescerebbe ancora, ma la stima
## di ~5.7 volte era di un'altra arena e non viene riportata qui come se fosse
## ancora un riferimento. **In m11, con R=60, la misura da' 4,21 e il tetto resta
## 7,5**: un tetto non si abbassa quando il numero scende, perche' cosi' perderebbe
## la capacita' di fallire (paragrafo sopra).
const DPS_RATIO_MAX := 7.5

## ## Cosa misura questa sezione, e cosa non misura
##
## Misura **la produzione dell'orda**: quanti morsi tira e quanto danno consegna a
## chi riceve. Lo spia accetta ogni morso, quindi qui il numero e' il massimo
## che l'orda puo' dare. Quello che il **giocatore** sente e' circa la meta':
## `player.gd::take_damage` scarta meta' dei morsi per `INVULN_AFTER_HIT`. Sono
## due fatti diversi, e la sezione 12 misura quello vero.

## I quattro casi misurati: semi e popolazione. I primi due sono l'onda 1 (25
## vivi) su due semi diversi, il terzo la curva a meta' strada, il quarto
## l'onda 8 (200 vivi). Primo e quarto sono i due estremi che il piano dichiara.
const TOUCH_CASES := [[4242, 25], [7311, 25], [20260912, 75], [20260912, 200]]

## Accumuli dello spia. Sono **campi** e non variabili locali di questa funzione:
## una lambda di GDScript cattura per valore, e la callback qui e' un metodo,
## quindi i campi sono l'unica forma che funziona.
var _totale_danno := 0.0
var _morsi := 0
## Quante volte e' arrivato **quello** numero di danno. Le chiavi sono i valori
## della tabella delle specie: se ne compare uno che non e' in tabella, vuol
## dire che qualcuno ha scritto un danno a mano.
var _per_morso := {}
## L'ultimo numero di danno che e' arrivato allo spia. Serve a confrontarlo, in
## ogni passo in cui un morso arriva, con `horde.touch_damage_last`: i due
## numeri vengono da due conti indipendenti e devono coincidere.
var _ultimo_danno := 0.0

## Lo spia. E' **il giocatore**, non il nemico: il chiamante di `damage_player`
## e' `src/sim/horde.gd`, e questo file non chiama `damage_player` una volta
## sola, solo la registra.
func _spia_damage_player(amount: float) -> bool:
	_totale_danno += amount
	_morsi += 1
	_ultimo_danno = amount
	_per_morso[amount] = int(_per_morso.get(amount, 0)) + 1
	return true

## La posizione del giocatore finto, letta dal contratto come in partita.
func _spia_player_position() -> Vector3:
	return FAKE_PLAYER

func _touch(h, horde: HORDE) -> void:
	_touch_table(h)
	_touch_caller(h)

	# Da qui in poi l'orda ha un giocatore davanti: questa sezione va per ultima
	# apposta, perche' le precedenti misurano un'orda senza bersaglio.
	var game := _game()
	game.register_impl("player_position", _spia_player_position)
	game.register_impl("damage_player", _spia_damage_player)
	h.check(game.has_impl("damage_player"),
		"il contratto accetta damage_player: e' l'API che -gameplay registra")

	var misure: Array = []
	for caso in TOUCH_CASES:
		misure.append(_misura_morso(h, horde, int(caso[0]), int(caso[1])))
	_touch_economia(h, misure)
	_touch_game_over(h, horde)

# --- 11a. La tabella del morso ------------------------------------------------

## Il danno e la cadenza di ogni specie devono uscire dalla tabella `MASS` e da
## nient'altro. E' il criterio n. 6 di m7 (un numero in un posto solo) reso
## verificabile: se qualcuno sostituisce la formula con una tabella di danni per
## specie, qui viene fuori che non e' piu' la stessa cosa.
func _touch_table(h) -> void:
	h.check(ENEMY.TOUCH_DAMAGE_BASE > 0.0, "il morso base e' positivo")
	h.check(ENEMY.TOUCH_PERIOD > 0.0, "il periodo base e' positivo")
	h.check(ENEMY.TOUCH_REACH > 0.0, "la portata del morso e' positiva")
	h.near(ENEMY.touch_damage_of(ENEMY.RUNNER), ENEMY.TOUCH_DAMAGE_BASE, 0.000001,
		"il runner e' la base del morso: la formula e' ancorata a lui")
	h.near(ENEMY.touch_period_of(ENEMY.RUNNER), ENEMY.TOUCH_PERIOD, 0.000001,
		"e del periodo")
	for k in ENEMY.KIND_COUNT:
		var atteso := ENEMY.TOUCH_DAMAGE_BASE * ENEMY.MASS[k] / ENEMY.MASS[ENEMY.RUNNER]
		h.near(ENEMY.touch_damage_of(k), atteso, 0.000001,
			"il morso di %s esce dalla tabella MASS, non da una tabella sua"
				% ENEMY.KIND_NAMES[k])
		var periodo := ENEMY.TOUCH_PERIOD * sqrt(ENEMY.MASS[k] / ENEMY.MASS[ENEMY.RUNNER])
		h.near(ENEMY.touch_period_of(k), periodo, 0.000001,
			"la cadenza di %s esce dalla stessa tabella" % ENEMY.KIND_NAMES[k])
		if k > 0:
			h.check(ENEMY.touch_damage_of(k) > ENEMY.touch_damage_of(k - 1),
				"piu' pesante morde piu' forte: %s (%.2f) sopra %s (%.2f)"
					% [ENEMY.KIND_NAMES[k], ENEMY.touch_damage_of(k),
						ENEMY.KIND_NAMES[k - 1], ENEMY.touch_damage_of(k - 1)])
			h.check(ENEMY.touch_period_of(k) > ENEMY.touch_period_of(k - 1),
				"piu' pesante morde piu' lento: %s (%.2f s) sopra %s (%.2f s)"
					% [ENEMY.KIND_NAMES[k], ENEMY.touch_period_of(k),
						ENEMY.KIND_NAMES[k - 1], ENEMY.touch_period_of(k - 1)])
	# nessun morso uccide da solo: il capo e' la specie piu' pesante e quindi
	# quella che morde piu' forte, ed e' il numero che tiene sotto il tetto.
	h.check(ENEMY.touch_damage_of(ENEMY.BOSS) <= PLAYER_HP_REFERENCE / 4.0,
		"il morso peggiore (%s, %.2f hp) non uccide da solo il giocatore da 100 hp"
			% [ENEMY.KIND_NAMES[ENEMY.BOSS], ENEMY.touch_damage_of(ENEMY.BOSS)])
	# e nessuna specie morde piu' di una volta al secondo: sotto il periodo base.
	for k in ENEMY.KIND_COUNT:
		h.check(ENEMY.touch_period_of(k) >= ENEMY.TOUCH_PERIOD,
			"%s non morde piu' di una volta al secondo (periodo %.2f s)"
				% [ENEMY.KIND_NAMES[k], ENEMY.touch_period_of(k)])

# --- 1. Popolazione -----------------------------------------------------------

func _population(h, horde: HORDE) -> void:
	# ## Perche' questo test continua a volere 200 e l'avvio no
	#
	# `_build()` riempie a `Run.population_of(1)` = 25 dal primo di m4, e la
	# prima cosa che questo test verifica e' proprio quello: l'avvio **non** e'
	# pieno. Poi il test pilota la propria `population` e la porta a
	# `HORDE.MAX_ENEMIES`, perche' la capacita' e' un criterio di m1 e non
	# diventa inesistente quando la curva delle onde cambia.
	h.eq(horde.wave, 1, "l'orda appena costruita e' sull'onda 1")
	h.eq(horde.population, RUN.population_of(1),
		"alla costruzione la popolazione e' quella che chiede la curva")
	h.eq(horde.population, RUN.POP_BASE, "che sull'onda 1 e' Run.POP_BASE")
	h.eq(horde.count, horde.population, "e il campo e' gia' a quel numero")
	h.check(horde.count < HORDE.MAX_ENEMIES,
		"l'avvio NON e' gia' pieno: %d vivi su %d di capienza" % [horde.count, HORDE.MAX_ENEMIES])

	# La rampa fino alla capienza, **misurata**: e' il numero che rende
	# visibile che 200 nemici ora costa dei secondi e non un passo.
	horde.auto_respawn = true
	horde.population = HORDE.MAX_ENEMIES
	var passi := 0
	while horde.count < HORDE.MAX_ENEMIES and passi < 6000:
		horde.step(DT)
		passi += 1
	h.eq(horde.count, HORDE.MAX_ENEMIES, "%d nemici vivi per il criterio di m1" % HORDE.MAX_ENEMIES)
	h.check(passi > 1,
		"la capienza NON si raggiunge in un passo: %d passi = %.2f s"
			% [passi, float(passi) * DT])
	# e nessun passo ne aggiunge piu' di uno
	var aggiunti_max := 0
	for _i in 30:
		var prima := horde.count
		horde.step(DT)
		aggiunti_max = maxi(aggiunti_max, horde.count - prima)
	h.eq(aggiunti_max, 0, "a pieno non si aggiunge niente")
	horde.auto_respawn = false

	# La rampa appena fatta ha lasciato i primi nemici **convergi sul centro**:
	# il campo che il benchmark di sotto misura sarebbe un grappolo addensato, e
	# il confronto griglia/scansione cambierebbe di numero per un motivo che non
	# ha a che fare con la griglia. `reseed()` ridisegna la disposizione a 200
	# nemici ad anelli, che e' la condizione con cui quel confronto e' stato
	# misurato in m1, e rende il numero di oggi confrontabile con quello di
	# allora. Il seme e' fisso perche' il benchmark legga un numero, non una
	# disposizione casuale.
	horde.reseed(SEME_CAPACITY)
	h.eq(horde.count, HORDE.MAX_ENEMIES, "dopo il reseed ci sono ancora %d nemici" % HORDE.MAX_ENEMIES)
	h.eq(horde.transforms.size(), horde.count, "e gli array sono allineati")
	h.eq(horde.grid_unknown_cells, 0, "il reseed non ha creato celle nuove")

	h.eq(horde.transforms.size(), horde.count,
		"transforms e' lunga quanto count: e' l'invariante che arena usa per il MultiMesh")
	h.eq(horde.colors.size(), horde.count, "un colore per nemico")
	h.eq(horde.radii.size(), horde.count,
		"m8: un raggio di corpo per nemico, allineato come transforms e colors")
	h.eq(horde.velocities.size(), horde.count, "velocita': array parallelo allineato")
	h.eq(horde.hp.size(), horde.count, "hp: array parallelo allineato")
	h.eq(horde.kinds.size(), horde.count, "specie: array parallelo allineato")
	h.eq(horde.timers.size(), horde.count, "timer: array parallelo allineato")
	h.eq(horde.bites.size(), horde.count, "morso: array parallelo allineato")
	h.eq(horde.bite_timers.size(), horde.count, "timer del morso: array parallelo allineato")

	var census := horde.census()
	var somma := 0
	for k in census:
		somma += k
	h.eq(somma, horde.count, "il censimento conta tutti i nemici")
	h.eq(census.size(), ENEMY.KIND_COUNT, "censimento: una voce per specie")

	# un giro solo, con i numeri fuori: 200 assertioni sullo stesso dato
	# costerebbero piu' di quanto dicano
	var dentro := 0
	var finiti := 0
	var vivi := 0
	var specie_ok := 0
	var piu_esterno := 0.0
	for i in horde.count:
		var p := horde.transforms[i]
		var distanza := Vector2(p.x, p.z).length()
		if distanza <= horde.arena_radius + 0.001:
			dentro += 1
		piu_esterno = maxf(piu_esterno, distanza)
		if is_finite(p.x) and is_finite(p.y) and is_finite(p.z):
			finiti += 1
		if horde.hp[i] > 0.0:
			vivi += 1
		if horde.kinds[i] >= 0 and horde.kinds[i] < ENEMY.KIND_COUNT:
			specie_ok += 1
	h.eq(dentro, horde.count, "tutti i nemici nascono dentro l'arena")
	h.eq(finiti, horde.count, "nessuna posizione spazzatura")
	h.eq(vivi, horde.count, "nessun nemico nasce morto")
	h.eq(specie_ok, horde.count, "ogni specie e' in tabella")
	# E il raggio non e' solo un numero che l'orda si tiene: **la disposizione lo
	# usa**. Il vincolo e' sul bordo perche' e' li' che si vede, e senza questa
	# riga un `layout_point` nutrito con un raggio suo passerebbe tutto il resto
	# del file: il campo direbbe 46 e l'orda nascerebbe a 28.
	# La frazione non e' un numero scelto a occhio: `Spawner.layout_point` mette
	# l'indice 0 sul bordo (`rr = radius`) e ci mette sopra un jitter del 5% del
	# raggio, quindi il massimo su 200 e' il bordo meno poco e la soglia sta
	# sotto quel massimo, non sopra.
	h.check(piu_esterno > horde.arena_radius * 0.8,
		"la disposizione arriva al bordo: il nemico piu' esterno e' a %.1f m su %.1f"
			% [piu_esterno, horde.arena_radius])
	h.check(census[ENEMY.RUNNER] > 0, "qualche runner")
	h.check(census[ENEMY.BOSS] < horde.count / 4,
		"il boss resta raro: %d su %d" % [census[ENEMY.BOSS], horde.count])
	print("orda: avvio a %d nemici (Run.POP_BASE), portati a %d in %d passi = %.2f s "
		% [RUN.POP_BASE, horde.count, passi, float(passi) * DT]
		+ "(Run.SPAWN_RATE = %.1f/s)" % RUN.SPAWN_RATE)
	print("orda: %d nemici su %d celle, specie %s, raggio %.1f m"
		% [horde.count, horde.occupied_cells(), str(census), horde.arena_radius])

# --- 2. Nessun nodo per nemico ------------------------------------------------

func _no_node_per_enemy(h, horde: HORDE) -> void:
	var nodi := _count_nodes(root)
	print("orda: %d nemici vivi con %d nodi in tutta la scena (criterio: sotto 120)"
		% [horde.count, nodi])
	h.check(nodi < 120,
		"node_count deve stare sotto 120 con 200 nemici vivi: sono %d" % nodi)
	h.eq(horde.count, HORDE.MAX_ENEMIES, "e i nemici sono davvero 200 mentre si conta")
	h.eq(horde.get_child_count(), 0,
		"l'orda non ha figli: nessun nodo per nemico, nemmeno per accenderlo")

# --- 3. Registrazione sul contratto ------------------------------------------

func _registration(h, horde: HORDE) -> void:
	var game := _game()
	h.check(game != null, "l'autoload Game deve esistere: horde.gd si registra su di lui")
	h.check(game.horde == horde, "Game.horde = self nel _ready")
	for api in ["nearest_enemy", "damage_enemy", "random_spawn_point"]:
		h.check(game.has_impl(api), "register_impl(%s) deve aver registrato l'API" % api)
	h.check(not game.has_impl("player_position"),
		"player_position e' di -gameplay: registrarla qui sarebbe una doppia registrazione")

# --- 3b. Le copie del raggio (criterio n. 2 di m9) -----------------------------
#
# ## Cosa controlla, e perche' una `grep` e non un campo
#
# Il raggio vive in sei copie (§1.12-bis). La fonte e' `src/render/arena.gd`; la
# copia di questa foglia e' `horde.arena_radius`, un **fallback dichiarato** che
# vale solo quando il contratto non c'e' ancora. Il campo, pero', a runtime non la
# lascia vedere: `_contract_radius()` lo sovrascrive alla costruzione, quindi un
# test che confrontasse `horde.arena_radius` col contratto starebbe confrontando
# una copia col valore che l'ha appena sovrascritta, e passerebbe sempre. Per
# questo il fallback si legge **dal sorgente**, con la stessa forma della `grep`
# di `damage_player` nella sezione 11b: se la riga di `horde.gd` deriva dal
# default del contratto, questa sezione va rossa.
#
# Il criterio di m9 e' sulla **deriva**, non sull'assenza di `28.0`: un numero che
# sparisce non lascia traccia, un numero che si discosta lascia una porta rossa.

## Il raggio che il contratto dichiara adesso.
##
## In questo processo l'arena vera non e' ancora caricata (`_scena_vera` sta in
## fondo), quindi il valore letto qui e' il **default dichiarato** in
## `src/core/contracts.gd`, non quello che `-arena` registra dopo. E' proprio il
## confronto che serve: il fallback dell'orda deve dire la stessa cosa del
## contratto che lo sovrascrive.
func _raggio_contratto() -> float:
	var game := _game()
	return 0.0 if game == null else float(game.arena_radius)

## Il raggio dichiarato in `src/sim/horde.gd`, letto dal sorgente. `-1.0` se la
## riga non c'e' piu': un fallback che sparisce e' una copia che non dice piu'
## niente, e una copia che non dice niente non si puo' confrontare con nessuna.
func _raggio_fallback_orda() -> float:
	var testo := FileAccess.get_file_as_string("res://src/sim/horde.gd")
	for riga in testo.split("\n"):
		var t := str(riga).strip_edges()
		if t.begins_with("var arena_radius"):
			return float(t.split("=")[1].strip_edges())
	return -1.0

func _copie_del_raggio(h, horde: HORDE) -> void:
	var contratto := _raggio_contratto()
	var fallback := _raggio_fallback_orda()
	h.check(contratto > 0.0,
		"il contratto dichiara un raggio positivo: %.1f m" % contratto)
	h.check(fallback > 0.0,
		"src/sim/horde.gd dichiara ancora `var arena_radius`: letto %.3f" % fallback)
	h.eq(fallback, contratto,
		"criterio n. 2 di m9: il fallback di horde.gd e' il default del contratto, "
		+ "non due raggi che divergono in silenzio")
	h.near(horde.arena_radius, contratto, 0.0001,
		"e l'orda in memoria porta il raggio del contratto, non quello dichiarato in sorgente")
	print("orda: raggio dal contratto %.1f m, fallback dichiarato in horde.gd %.1f m"
		% [contratto, fallback])

# --- 4. La griglia contro la scansione lineare -------------------------------

## Distribuzione nota: un incrocio sulle celle (nomi di confine), una griglia
## regolare, un mucchio a caso. Se un nemico finisce nella cella sbagliata, o se
## un secchiello perde un indice, qui si vede.
func _grid_matches_linear(h) -> void:
	h.eq(GRID.CELL, 4.0, "il piano fissa la cella a 4 unita'")
	var pts := _distribution(400)
	var grid: GRID = GRID.new()
	grid.setup(GRID.CELL, 30.0)
	h.eq(grid.unknown_cells, 0, "il riscaldamento ha creato le celle")

	grid.begin_frame()
	for i in pts.size():
		grid.insert(i, pts[i])
	h.eq(grid.unknown_cells, 0,
		"tutti i punti della distribuzione stanno nelle celle riscaldate")

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260906
	var vuoti := 0
	var sbagliati := 0
	var discordi := 0
	var primo_motivo := ""
	var atteso := PackedInt32Array()
	var got := PackedInt32Array()
	for t in 300:
		var q := Vector3(rng.randf_range(-32.0, 32.0), 0.0, rng.randf_range(-32.0, 32.0))
		var r := rng.randf_range(0.5, 9.0)
		GRID.linear_fill_radius(atteso, q, r, pts, pts.size())
		grid.fill_radius(got, q, r, pts)
		atteso.sort()
		got.sort()
		if atteso.is_empty():
			vuoti += 1
		if not _same_indices(got, atteso):
			sbagliati += 1
			if primo_motivo == "":
				primo_motivo = "q=(%.2f, %.2f) r=%.2f: griglia %d indici, lineare %d" \
					% [q.x, q.z, r, got.size(), atteso.size()]
		var lin := GRID.linear_nearest(q, r, pts, pts.size())
		var gidx := grid.nearest_index(q, r, pts)
		if gidx != lin:
			discordi += 1
			var dl := 1e9 if lin < 0 else q.distance_squared_to(pts[lin])
			var dg := 1e9 if gidx < 0 else q.distance_squared_to(pts[gidx])
			if absf(dl - dg) > 0.000001 and primo_motivo == "":
				primo_motivo = "nearest discorda su q=(%.2f, %.2f): griglia %d (d2 %.6f), lineare %d (d2 %.6f)" \
					% [q.x, q.z, gidx, dg, lin, dl]
	h.check(sbagliati == 0,
		"300 query con raggio: la griglia deve dare gli stessi indici della scansione"
		+ ("" if primo_motivo == "" else "; prima discordanza: " + primo_motivo))
	h.check(discordi == 0,
		"300 query: il piu' vicino deve coincidere con la scansione lineare"
		+ ("" if primo_motivo == "" else "; " + primo_motivo))
	h.check(vuoti > 0, "il confronto deve contenere anche query con raggio vuoto")
	print("orda: griglia e scansione lineare coincidono su 300 query (%d con raggio vuoto)" % vuoti)

	# Fuori dal quadrato riscaldato la cella non esiste, ma la risposta deve
	# essere giusta lo stesso: e' il caso in cui una griglia "ottimizzata"
	# perde un nemico, e meglio che se ne accorga qui.
	var fuori := Vector3(500.0, 0.0, 500.0)
	grid.begin_frame()
	grid.insert(pts.size(), fuori)
	h.eq(grid.unknown_cells, 1, "una cella nuova fuori dal riscaldamento: contata")
	h.eq(grid.nearest_index(fuori + Vector3(1.0, 0.0, 0.0), 5.0, _plus_one(pts, fuori)),
		pts.size(), "un nemico fuori dal quadrato riscaldato deve essere trovato lo stesso")

## `n` punti: incrocio sulle celle, griglia regolare, mucchio a caso.
##
## **Questa distribuzione non e' una copia del raggio dell'arena e non lo segue
## per scelta**: e' la distribuzione **nota** del confronto griglia/scansione
## (criterio n. 2 di m1) e porta con se' la sua griglia, `setup(GRID.CELL, 30.0)`,
## che e' piu' stretta del disco da 46 m. Il confronto chiede che le due strade
## diano gli stessi indici su un campo che **entrambe** vedono: dei punti fuori
## dalla griglia farebbero misurare il ripiego a scansione lineare invece della
## griglia, e il numero che verrebbe fuori non sarebbe quello di m1. Il raggio
## dell'arena non c'entra, e il ±26 qui dentro non e' un 28 rimasto indietro.
func _distribution(n: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234567
	# un incrocio: coordinate su multipli esatti della cella, e due celle vicine
	pts.append(Vector3(4.0, 0.0, 4.0))
	pts.append(Vector3(8.0, 0.0, 4.0))
	pts.append(Vector3(4.0, 0.0, 8.0))
	pts.append(Vector3(-8.0, 0.0, -8.0))
	pts.append(Vector3(0.0, 0.0, 0.0))
	# una griglia regolare, un punto per cella
	for gz in 12:
		for gx in 12:
			pts.append(Vector3(float(gx) * 2.0 - 12.0, 0.0, float(gz) * 2.0 - 12.0))
	# il mucchio a caso
	for _i in maxi(0, n - pts.size()):
		pts.append(Vector3(rng.randf_range(-26.0, 26.0), 0.0, rng.randf_range(-26.0, 26.0)))
	return pts

func _plus_one(pts: PackedVector3Array, extra: Vector3) -> PackedVector3Array:
	var out := pts.duplicate()
	out.append(extra)
	return out

func _same_indices(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true

# --- 5. nearest ---------------------------------------------------------------

func _nearest(h, horde: HORDE) -> void:
	var k := 37
	h.check(k < horde.count, "indice di prova dentro la folla")
	var q := horde.transforms[k] + Vector3(0.03, 0.0, 0.03)
	var got := horde.nearest_enemy_index(q, 1.5)
	h.eq(got, k, "nearest_enemy_index deve dare l'indice atteso")
	h.eq(got, GRID.linear_nearest(q, 1.5, horde.transforms, horde.count),
		"l'indice coincide con la scansione lineare")

	# il vicino cambia: la risposta deve seguire l'indice, non restare ferma
	h.eq(horde.nearest_enemy_index(horde.transforms[90] + Vector3(0.02, 0.0, 0.0), 1.0),
		90, "un altro nemico e' il piu' vicino")

	# raggio vuoto: -1, mai un indice a caso
	h.eq(horde.nearest_enemy_index(LONTANO, 4.0), -1, "fuori dall'arena il risultato e' -1")
	h.eq(horde.nearest_enemy_index(LONTANO, 0.001), -1,
		"un millimetro di raggio non contiene nessuno")
	h.eq(horde.nearest_enemy_index(horde.transforms[0], 0.0), -1,
		"raggio zero non e' una ricerca")
	h.eq(horde.nearest_enemy_index(Vector3.ZERO, -3.0), -1, "raggio negativo: niente")

	# stessa domanda attraverso il contratto: `as int` su un int non deve dare
	# "Invalid cast", e l'indice deve essere lo stesso (piano 5.2)
	h.eq(_game().nearest_enemy(q, 1.5), k,
		"Game.nearest_enemy (-> int) restituisce lo stesso indice")
	h.eq(_game().nearest_enemy(LONTANO, 4.0), -1,
		"Game.nearest_enemy (-> int) fuori raggio restituisce -1")

# --- 6. Punti di spawn --------------------------------------------------------

func _spawn_points(h, horde: HORDE) -> void:
	var peggiore := 0.0
	var rotte := 0
	for _i in 400:
		var p := horde.random_spawn_point()
		if p == Vector3.ZERO:
			rotte += 1
			continue
		peggiore = maxf(peggiore, Vector2(p.x, p.z).length())
		# Il vuoto dal giocatore e' `HORDE.MIN_SPAWN_GAP`, letto dalla costante e
		# non scritto qui: era `12.0` in questa riga, cioe' una copia che poteva
		# derivare dal contratto di spawn senza che nessuna porta lo dicesse.
		if p.distance_to(FOCUS) < HORDE.MIN_SPAWN_GAP - 0.001 \
				or Vector2(p.x, p.z).length() > horde.arena_radius + 0.001:
			rotte += 1
	h.eq(rotte, 0,
		"random_spawn_point: mai ZERO, sempre dentro l'arena e lontano dal giocatore")
	h.positive(peggiore, "i punti di spawn si spargono sull'arena")
	# ## La soglia del bordo, e perche' 0.9 e non 0.5
	#
	# `Spawner.spawn_point` tira `radius * sqrt(u)` (uniforme in area) e al massimo
	# `radius * 0.96` quando il tiro e' lontano dal giocatore, quindi su 400 punti
	# il massimo e' **0.96-1.0 del raggio**: la frazione non dipende dalla
	# dimensione dell'arena, e a 46 m resta quella che era a 28 m. **Misurato:
	# 0.958 del raggio** (44.09 m su 46.0). La soglia a meta' raggio era pero' una
	# soglia che non mordeva piu': con un disco 2,7 volte piu' grande, 0.5 * 46 =
	# 23 m e un campionamento che si fermasse a meta' passerebbe lo stesso.
	# Qui si richiede **0.9**: il numero che deve restare sensibile e' la frazione
	# del raggio, non i metri.
	h.check(peggiore > horde.arena_radius * 0.9,
		"i punti di spawn arrivano al bordo: %.2f su %.1f = %.3f del raggio"
			% [peggiore, horde.arena_radius, peggiore / maxf(1.0, horde.arena_radius)])

# --- 7. Budget di 1000 query --------------------------------------------------
#
# Perche' piu' giri e non uno: una corsa sola e' rumore. Il scheduling del
# processore, la frequenza che sale e scende e la cache che si scalda spostano
# due misure consecutive del 20-30%, e un'asserzione con 180 us di margine su
# un numero che gira attorno a 9000 fallisce a caso. Qui si gira piu' volte
# prendendo il **minimo**: il minimo di N corse e' la stima piu' vicina a "quanto
# costa davvero", perche' tutto quello che c'e' dentro e' rumore che si somma solo.

## Giri misurati, oltre a quello di scaldamento.
const BENCH_ROUNDS := 8
## Query per giro: il criterio della milestone parla di 1000.
const BENCH_PER_ROUND := 1000
## Raggio delle query, metri.
const BENCH_RADIUS := 6.0

func _query_budget(h, horde: HORDE) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	# ## Il quadrato campionato si legge dal contratto, e si dichiara
	#
	# Qui c'era `randf_range(-28.0, 28.0)`: un numero scritto a mano che non
	# asseriva il raggio e quindi **non e' diventato rosso** quando l'arena e'
	# passata da 28 a 46. Il benchmark restava verde e campionava 56x56 m dentro
	# un disco di 92x92: meta' della copertura, in silenzio (§3.6-bis).
	# Il mezzo del quadrato e' adesso il raggio che il contratto dichiara, e
	# sotto ci sono le tre asserzioni che lo rendono un numero e non una
	# speranza: il quadrato contiene il disco, contiene **tutti i nemici vivi**,
	# e le query trovano davvero qualcuno.
	var semi := _raggio_contratto()
	h.check(semi >= horde.arena_radius - 0.0001,
		"il quadrato campionato contiene tutto il disco: mezzo %.1f m su raggio %.1f m"
			% [semi, horde.arena_radius])
	var fuori := 0
	for i in horde.count:
		var p := horde.transforms[i]
		if absf(p.x) > semi or absf(p.z) > semi:
			fuori += 1
	h.eq(fuori, 0,
		"il quadrato campionato contiene tutti i %d nemici vivi: %d fuori" % [horde.count, fuori])

	var queries := PackedVector3Array()
	queries.resize(BENCH_PER_ROUND)
	for i in BENCH_PER_ROUND:
		queries[i] = Vector3(rng.randf_range(-semi, semi), 0.0, rng.randf_range(-semi, semi))

	# Quanta copertura c'e' davvero: quante query cadono dentro il disco e
	# quante trovano un nemico entro `BENCH_RADIUS`. E' il numero che il ±28
	# nascondeva, perche' campionava la parte di disco che c'era e ignorava il
	# resto. Il pavimento e' basso (una su dieci) perche' il buco centrale di
	# `Spawner.LAYOUT_INNER` e' fatto: pretendere che ogni query trovi un nemico
	# significherebbe misurare la disposizione, non la griglia.
	var nell_arena := 0
	var con_vicino := 0
	for q in queries:
		if Vector2(q.x, q.z).length() <= horde.arena_radius:
			nell_arena += 1
		if horde.nearest_enemy_index(q, BENCH_RADIUS) >= 0:
			con_vicino += 1
	h.check(con_vicino * 10 >= BENCH_PER_ROUND,
		"almeno una query su dieci trova un nemico entro %.1f m: %d su %d"
			% [BENCH_RADIUS, con_vicino, BENCH_PER_ROUND])
	print("orda: campionamento su un quadrato di %.1f m di mezzo (raggio %.1f m): "
		% [semi, horde.arena_radius]
		+ "%d query su %d dentro il disco, %d con un vicino entro %.1f m"
			% [nell_arena, BENCH_PER_ROUND, con_vicino, BENCH_RADIUS])

	# Scaldamento di **entrambe** le strade: senza, la scansione lineare paga la
	# prima volta il costo di una funzione mai chiamata e il confronto esce
	# falsamente a suo favore.
	for i in BENCH_PER_ROUND:
		horde.nearest_enemy_index(queries[i], BENCH_RADIUS)
		GRID.linear_nearest(queries[i], BENCH_RADIUS, horde.transforms, horde.count)

	var griglia := PackedInt64Array()
	var lineare := PackedInt64Array()
	griglia.resize(BENCH_ROUNDS)
	lineare.resize(BENCH_ROUNDS)
	for giro in BENCH_ROUNDS:
		# ordine alternato: se la CPU e' piu' veloce alla fine di un giro, non
		# puo' favorire sempre la stessa delle due
		var inverti := giro % 2 == 1
		if inverti:
			var a := _tempo_lineare(queries, horde)
			var b := _tempo_griglia(queries, horde)
			lineare[giro] = a
			griglia[giro] = b
		else:
			var a := _tempo_griglia(queries, horde)
			var b := _tempo_lineare(queries, horde)
			griglia[giro] = a
			lineare[giro] = b

	var g_min := _minimo(griglia)
	var l_min := _minimo(lineare)
	var g_med := _mediano(griglia)
	var l_med := _mediano(lineare)
	var rapporto := float(l_min) / maxf(1.0, float(g_min))
	var rapporto_med := float(l_med) / maxf(1.0, float(g_med))

	print("orda: %d query x %d giri su %d nemici, raggio %.1f m"
		% [BENCH_PER_ROUND, BENCH_ROUNDS, horde.count, BENCH_RADIUS])
	print("orda: griglia min %d us, mediana %d us | lineare min %d us, mediana %d us"
		% [g_min, g_med, l_min, l_med])
	print("orda: la griglia e' %.2f volte piu' rapida sul minimo, %.2f sulla mediana"
		% [rapporto, rapporto_med])
	print("orda: griglia per giro %s" % str(griglia))
	print("orda: lineare per giro %s" % str(lineare))
	print("orda: secchiello piu' affollato %d su %d, traboccamenti: %s"
		% [horde.worst_bucket(), GRID.BUCKET_SLOTS, str(horde.grid_overflowed())])

	h.check(not horde.grid_overflowed(),
		"nessun secchiello traboccato durante le query: la griglia stava cadendo a scansione lineare")
	h.check(g_min < 50000,
		"%d query di prossimita' su %d nemici sotto i 50 ms: %d us (minimo di %d giri)"
			% [BENCH_PER_ROUND, horde.count, g_min, BENCH_ROUNDS])
	h.check(g_med < 50000,
		"e anche la mediana dei giri sta sotto i 50 ms: %d us" % g_med)
	h.check(rapporto > 1.0,
		"la griglia deve battere la scansione lineare: %.2f volte (minimo su minimo su %d giri)"
			% [rapporto, BENCH_ROUNDS])
	h.check(rapporto_med > 1.0,
		"e deve batterla anche sulla mediana dei giri, non solo sul caso fortunato: %.2f volte"
			% rapporto_med)

func _tempo_griglia(queries: PackedVector3Array, horde: HORDE) -> int:
	var t0 := Time.get_ticks_usec()
	for i in queries.size():
		horde.nearest_enemy_index(queries[i], BENCH_RADIUS)
	return Time.get_ticks_usec() - t0

func _tempo_lineare(queries: PackedVector3Array, horde: HORDE) -> int:
	var t0 := Time.get_ticks_usec()
	for i in queries.size():
		GRID.linear_nearest(queries[i], BENCH_RADIUS, horde.transforms, horde.count)
	return Time.get_ticks_usec() - t0

func _minimo(values: PackedInt64Array) -> int:
	var m := values[0]
	for v in values:
		if v < m:
			m = v
	return m

## Mediana: copia, ordina, prende il centro. Fuori dal ciclo di gioco (e' un
## benchmark), quindi qui l'allocazione non e' un peccato.
func _mediano(values: PackedInt64Array) -> int:
	var copie := values.duplicate()
	copie.sort()
	return copie[copie.size() / 2]

# --- 8. Pool ------------------------------------------------------------------

func _object_pool(h) -> void:
	var pool: POOL = POOL.new()
	pool.configure(func() -> Object: return Thing.new(), 32)
	h.eq(pool.created(), 32, "il riscaldamento crea gli oggetti una volta sola")
	h.eq(pool.free_count(), 32, "all'inizio sono tutti liberi")
	h.eq(pool.live(), 0, "nessuno e' in uso all'inizio")

	var presi: Array = []
	for _i in 32:
		var oggetto: Object = pool.acquire()
		h.check(oggetto != null, "acquire entro capienza restituisce un oggetto")
		presi.append(oggetto)
	h.eq(pool.live(), 32, "tutti in uso")
	h.eq(pool.created(), 32, "acquire non ha creato niente")
	h.check(pool.acquire() == null, "a capienza piena acquire da null, non crea")
	h.eq(pool.rejected(), 1, "l'acquire a vuoto e' contato")

	for oggetto in presi:
		h.check(pool.release(oggetto), "release di un oggetto del pool")
	h.eq(pool.live(), 0, "tutti rilasciati")
	h.eq(pool.free_count(), 32, "la capienza e' tornata quella di prima")

	# 100000 cicli acquire/release: created() non deve muoversi di una unita'
	for _i in 100000:
		var oggetto: Object = pool.acquire()
		pool.release(oggetto)
	h.eq(pool.created(), 32,
		"100000 cicli non devono creare un solo oggetto nuovo: created() e' %d" % pool.created())
	h.eq(pool.live(), 0, "nessuna perdita di oggetti dopo 100000 cicli")
	print("orda: pool, 100000 cicli acquire/release, oggetti creati in tutto: %d" % pool.created())

# --- 9. 600 aggiornamenti -----------------------------------------------------

func _burn_in(h, horde: HORDE) -> void:
	h.eq(horde.count, 200, "si parte da 200")
	var nodi0 := _count_nodes(root)
	var obj0 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var mem0 := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var passati := 0
	var morti := 0
	var morsi := 0

	for s in 600:
		horde.step(1.0 / 60.0)
		passati += 1
		morsi += horde.touch_bites_last
		# una morte ogni 5 passi: lo scambio-ultimo viene esercitato 120 volte,
		# quindi i 600 passi non sono una passeggiata
		if s % 5 == 0 and horde.count > 40:
			horde.damage_enemy(s % 37, 9999.0, Vector3(2.0, 0.0, 0.0))
			morti += 1

	h.eq(passati, 600, "600 aggiornamenti in headless senza SCRIPT ERROR")
	h.eq(morti, 120, "una morte ogni 5 passi")
	h.eq(horde.count, 200 - morti, "il conteggio scende di uno per ogni morte")
	h.eq(horde.transforms.size(), horde.count, "transforms resta allineata a count dopo le morti")
	h.eq(horde.colors.size(), horde.count, "colors resta allineata a count dopo le morti")
	h.eq(horde.hp.size(), horde.count, "anche hp resta allineata a count")
	# m8: lo scambio-ultimo sposta **anche** il raggio. Un nemico che eredita la
	# posizione di un altro e si disegna con il raggio del morto e' esattamente
	# il difetto che `radii` doveva chiudere.
	h.eq(horde.radii.size(), horde.count,
		"m8: radii resta allineata a count dopo 120 scambi-ultimo")
	var raggi_sbagliati := 0
	for i in horde.count:
		if absf(horde.radii[i] - ENEMY.RADIUS[horde.kinds[i]]) > 0.000001:
			raggi_sbagliati += 1
	h.eq(raggi_sbagliati, 0,
		"m8: ogni radii[i] e' il RADIUS della sua specie, anche dopo lo scambio-ultimo")
	h.eq(horde.kills, morti, "il contatore delle uccisioni")

	var dentro := 0
	var vivi := 0
	for i in horde.count:
		var p := horde.transforms[i]
		if is_finite(p.x) and is_finite(p.y) and is_finite(p.z):
			dentro += 1
		if horde.hp[i] > 0.0:
			vivi += 1
	h.eq(dentro, horde.count, "nessun nemico rimasto con una posizione spazzatura")
	h.eq(vivi, horde.count, "nessun nemico sopravvisso con hp negativo")
	h.check(horde.worst_bucket() <= GRID.BUCKET_SLOTS,
		"nessun secchiello traboccato: il piu' affollato ne aveva %d su %d"
		% [horde.worst_bucket(), GRID.BUCKET_SLOTS])
	h.check(not horde.grid_overflowed(), "nessuna caduta a scansione lineare")
	h.eq(horde.grid_unknown_cells, 0,
		"nessuna cella nuova dopo 600 passi: nel ciclo di gioco non si alloca")

	var nodi1 := _count_nodes(root)
	var obj1 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var mem1 := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	h.eq(nodi1, nodi0, "600 passi non aggiungono nodi")
	# Il ramo negativo del morso: in questo processo **non c'e' un giocatore**
	# (`player_position` non e' registrata, perche' e' di -gameplay), quindi
	# nessun nemico deve mordere il centro vuoto dell'arena. E' la prova che
	# l'accensione del morso dipende da `has_impl("player_position")` e non da
	# un `if` che la birra di qualcun altro.
	h.eq(morsi, 0, "senza un giocatore registrato, in 600 passi non e' arrivato un morso")
	h.eq(horde.touch_damage_last, 0.0, "e l'orda non dichiara nessun danno")
	h.eq(horde.bites.size(), horde.count, "bites allineato a count")
	h.eq(horde.bite_timers.size(), horde.count, "bite_timers allineato a count")
	h.check(obj1 <= obj0 + 16,
		"600 passi non aggiungono oggetti: %d contro %d" % [obj1, obj0])
	h.check(mem1 - mem0 < 4 * 1024 * 1024,
		"600 passi non gonfiano la memoria: +%d KB" % ((mem1 - mem0) / 1024))
	print("orda: 600 passi e %d morti, nodi %d -> %d, oggetti %d -> %d, memoria +%d KB"
		% [morti, nodi0, nodi1, obj0, obj1, (mem1 - mem0) / 1024])

# --- 10. damage_enemy uccide --------------------------------------------------

func _damage_kills(h, horde: HORDE) -> void:
	var prima := horde.count
	h.eq(prima, 80, "si riparte dagli 80 superstiti")

	var buco := 5
	var ultimo := horde.transforms[prima - 1]
	var hp_ultimo := horde.hp[prima - 1]
	var kind_ultimo := horde.kinds[prima - 1]
	var uccisioni := horde.kills

	var ucciso: bool = _game().damage_enemy(buco, 9999.0, Vector3.ZERO)
	h.check(ucciso, "Game.damage_enemy (-> bool) restituisce true quando il nemico muore")
	h.eq(horde.count, prima - 1, "damage_enemy uccide e il conteggio scende subito")
	h.eq(horde.transforms.size(), prima - 1, "transforms accorciata con lo scambio-ultimo")
	h.eq(horde.hp.size(), prima - 1, "anche hp e' accorciata")
	h.eq(horde.radii.size(), prima - 1, "m8: anche radii e' accorciata")
	h.eq(horde.kills, uccisioni + 1, "il contatore delle uccisioni e' salito")
	h.vec_near(horde.transforms[buco], ultimo, 0.0001,
		"scambio-ultimo: nel buco deve esserci il vecchio ultimo, non uno zero")
	h.eq(horde.hp[buco], hp_ultimo, "scambio-ultimo: anche hp spostato")
	h.eq(horde.kinds[buco], kind_ultimo, "scambio-ultimo: anche la specie spostata")
	h.near(horde.radii[buco], ENEMY.RADIUS[kind_ultimo], 0.000001,
		"m8 scambio-ultimo: nel buco c'e' il raggio del vecchio ultimo")

	# fuori indice: nessun crash, nessun effetto e `false` (il contratto fa
	# `as bool` sul valore di ritorno: con `void` andrebbe in errore in partita)
	h.check(not _game().damage_enemy(prima, 10.0, Vector3.ZERO),
		"indice == count: false, nessun crash")
	h.check(not _game().damage_enemy(-1, 10.0, Vector3.ZERO),
		"indice negativo: false, nessun crash")
	h.check(not _game().damage_enemy(999999, 10.0, Vector3.ZERO),
		"indice assurdo: false, nessun crash")
	h.eq(horde.count, prima - 1, "un indice fuori range non tocca niente")

	# knockback: almeno 0.3 unita' sul nemico colpito (criterio n. 4 della
	# milestone, verificato dal lato dell'orda perche' e' qui che la spinta
	# viene applicata)
	var j := 4
	var v0 := horde.velocities[j]
	var hp0 := horde.hp[j]
	var sopravvive: bool = _game().damage_enemy(j, 1.0, Vector3(4.0, 0.0, 0.0))
	h.check(not sopravvive, "Game.damage_enemy (-> bool) su un colpo non letale da' false")
	var spinta := (horde.velocities[j] - v0).length()
	h.check(spinta >= 0.3, "knockback di almeno 0.3 unita': %.3f" % spinta)
	h.near(horde.hp[j], hp0 - 1.0, 0.0001, "un colpo toglie hp")
	h.eq(horde.count, prima - 1, "un colpo non letale non ammazza nessuno")
	h.check(horde.hit_count > 0, "i colpi vengono ricordati per sfx e flash")
	h.check(ENEMY.KIND_NAMES.has(horde.kind_name(j)), "kind_name da' un nome in tabella")
	h.eq(horde.kind_name(99999), "-", "kind_name fuori range non crasha")

	# svuotare l'orda: -1 quando non resta nessuno
	var svuotati := 0
	while horde.count > 0:
		horde.damage_enemy(0, 9999.0, Vector3.ZERO)
		svuotati += 1
		if svuotati > 100:
			break
	h.eq(horde.count, 0, "orda svuotata")
	h.eq(horde.transforms.size(), 0, "transforms vuota")
	h.eq(horde.colors.size(), 0, "colors vuota")
	h.eq(horde.radii.size(), 0, "m8: anche radii si svuota con l'orda")
	h.eq(horde.nearest_enemy_index(Vector3.ZERO, 1000.0), -1,
		"senza nemici la vicina piu' vicina da' -1")

	# ## Il riempimento automatico: NON da 0 a 200 in un passo
	#
	# Questo e' il criterio n. 4 della milestone 4, dal lato della macchina: un
	# campo svuotato torna a `population` **al ritmo di `run.spawn_rate()`**, e
	# `population` nel frattempo e' cambiata con l'onda (svuotare l'orda ha
	# chiuso l'onda 1, quindi siamo sull'onda 2).
	horde.auto_respawn = true
	horde.step(DT)
	h.eq(horde.count, 0,
		"un passo dopo lo svuotamento il campo e' ancora vuoto: nessuna raffica")
	h.eq(horde.population, RUN.population_of(horde.wave),
		"e la popolazione inseguita e' quella della curva sull'onda corrente")

	var passi_pieno := 0
	while horde.count < horde.population and passi_pieno < 6000:
		horde.step(DT)
		passi_pieno += 1
	h.eq(horde.count, horde.population, "l'orda arriva a `population`, e non oltre")
	h.check(passi_pieno > 1,
		"e ci mette piu' di un passo: %d passi = %.2f s" % [passi_pieno, float(passi_pieno) * DT])
	h.eq(horde.transforms.size(), horde.count, "allineata dopo il riempimento")
	h.eq(horde.colors.size(), horde.count, "colori allineati dopo il riempimento")
	h.eq(horde.radii.size(), horde.count,
		"m8: radii si ricompone insieme agli altri nel riempimento, non dopo")
	h.eq(horde.grid_unknown_cells, 0, "i %d spawn nuovi non hanno creato celle" % horde.count)
	h.check(horde.nearest_enemy_index(Vector3.ZERO, 100.0) >= 0,
		"dopo il riempimento si trova qualcuno")

	# e adesso la capienza, di nuovo pilotata a mano, con lo stesso ritmo
	horde.population = HORDE.MAX_ENEMIES
	var passi_capienza := 0
	while horde.count < HORDE.MAX_ENEMIES and passi_capienza < 6000:
		horde.step(DT)
		passi_capienza += 1
	h.eq(horde.count, HORDE.MAX_ENEMIES, "la capienza si raggiunge anche per riempimento")
	h.check(passi_capienza > 1, "anche da %d vivi ci mette piu' di un passo: %d passi = %.2f s"
		% [RUN.population_of(horde.wave), passi_capienza, float(passi_capienza) * DT])
	h.eq(horde.count, HORDE.MAX_ENEMIES, "e non la supera")
	print("orda: svuotata e riempita di nuovo, uccisioni in tutto %d, specie %s"
		% [horde.kills, str(horde.census())])
	print("orda: da 0 a %d in %.2f s, da %d a %d in %.2f s (Run.SPAWN_RATE = %.1f/s)"
		% [RUN.population_of(horde.wave), float(passi_pieno) * DT,
			RUN.population_of(horde.wave), HORDE.MAX_ENEMIES,
			float(passi_capienza) * DT, RUN.SPAWN_RATE])

# --- 11c. L'economia del morso, misurata -------------------------------------

## Un caso di misura: dispone `pop` nemici intorno al giocatore finto, li lascia
## arrivare, warm-up, e poi guarda per `TOUCH_STEPS` passi.
##
## L'onda viene bloccata a 1 (`run.wave` e `wave_killed`) perche' altrimenti
## l'onda avanza durante il warm-up, `_sync_population()` alza `population` e il
## caso "25 vivi" finisce a misurarne 75: una misura che non descrive quello che
## dice di descrivere e' rumore, non una misura.
func _misura_morso(h, horde: HORDE, seme: int, pop: int) -> Dictionary:
	horde.auto_respawn = true
	horde.set_focus(FAKE_PLAYER)
	horde.run.wave = 1
	horde.run.wave_killed = 0
	horde.reseed(seme)
	horde.population = pop
	while horde.count > 0:
		horde.damage_enemy(0, 9999.0, Vector3.ZERO)
	var passi_pieno := 0
	while horde.count < pop and passi_pieno < 6000:
		horde.step(DT)
		passi_pieno += 1
	h.eq(horde.count, pop, "il caso seme %d e' arrivato a %d vivi" % [seme, pop])
	# warm-up: l'orda deve **arrivare**, non essere gia' addosso al primo passo
	for _i in 1800:
		horde.step(DT)

	_totale_danno = 0.0
	_morsi = 0
	_per_morso = {}
	var fuori_tabella := 0
	var delta := TOUCH_STEPS * DT
	var in_contatto := 0
	var morse_passo_max := 0
	var gap_min := 1.0e9
	var ultimo := -1
	for s in TOUCH_STEPS:
		var prima := _morsi
		horde.step(DT)
		var caduti := _morsi - prima
		if caduti > 0:
			h.eq(caduti, 1,
				"seme %d: al massimo un morso che arriva per passo (tetto a intervallo)" % seme)
			h.eq(_ultimo_danno, horde.touch_damage_last,
				"seme %d: il danno che lo spia riceve e' quello che l'orda dichiara" % seme)
			if ultimo >= 0:
				gap_min = minf(gap_min, float(s - ultimo) * DT)
			ultimo = s
		morse_passo_max = maxi(morse_passo_max, horde.touch_bites_last)
		h.eq(horde.bites.size(), horde.count, "seme %d: bites allineato a count" % seme)
		h.eq(horde.bite_timers.size(), horde.count, "seme %d: bite_timers allineato a count" % seme)
	fuori_tabella = _valori_fuori_tabella()
	h.eq(fuori_tabella, 0,
		"seme %d: ogni numero di danno arrivato allo spia e' un numero di tabella" % seme)

	for i in horde.count:
		var p := horde.transforms[i]
		var d := Vector2(p.x, p.z).distance_to(Vector2(FAKE_PLAYER.x, FAKE_PLAYER.z))
		if d <= ENEMY.RADIUS[horde.kinds[i]] + ENEMY.TOUCH_REACH:
			in_contatto += 1

	var campi := {
		"seme": seme, "pop": pop, "vivi": horde.count, "in_contatto": in_contatto,
		"morsi": _morsi, "cadenza": float(_morsi) / delta,
		"dps": _totale_danno / delta,
		"per_morso": _totale_danno / maxf(1.0, float(_morsi)),
		"sopravvivenza": PLAYER_HP_REFERENCE / maxf(0.001, _totale_danno / delta),
		"gap_min": gap_min, "morse_passo_max": morse_passo_max,
	}
	print("orda: morso seme %d, %d vivi: %d a portata, %.2f morsi/s, %.2f hp per morso, %.2f hp/s, %.1f s da fermo"
		% [seme, horde.count, in_contatto, float(campi["cadenza"]),
			float(campi["per_morso"]), float(campi["dps"]), float(campi["sopravvivenza"])])
	print("orda: morso seme %d, morsi per specie:%s" % [seme, _riparto_morsi()])
	return campi

## Quanti numeri di danno arrivati allo spia **non** sono un numero di tabella.
## Il conto e' fatto durante il caso, non dopo: e' l'unico modo per beccare un
## numero scritto a mano che arriva una volta sola su quattrocento.
func _valori_fuori_tabella() -> int:
	var fuori := 0
	for a in _per_morso:
		var riconosciuto := false
		for k in ENEMY.KIND_COUNT:
			if absf(float(a) - ENEMY.touch_damage_of(k)) < 0.000001:
				riconosciuto = true
		if not riconosciuto:
			fuori += 1
	return fuori

## Quanti morsi per specie, in ordine di specie. Legge i numeri che sono
## **arrivati allo spia** e li riconosce confrontandoli con la tabella.
func _riparto_morsi() -> String:
	var testo := ""
	for k in ENEMY.KIND_COUNT:
		var atteso := ENEMY.touch_damage_of(k)
		var trovati := 0
		for a in _per_morso:
			if absf(float(a) - atteso) < 0.000001:
				trovati = int(_per_morso[a])
		testo += " %s(%.2f hp) x%d" % [ENEMY.KIND_NAMES[k], atteso, trovati]
	return testo

# --- 11b. Il chiamante --------------------------------------------------------

## Il criterio n. 1 di m7, che e' una `grep`, resa asserzione.
##
## Un chiamante che sta solo in `tests/` **fallisce** il criterio: significherebbe
## che la funzione funziona, non che qualcuno nel gioco la chiami. Quindi qui si
## guarda il disco e non si chiama la funzione.
##
## Il confronto e' fatto sulla **chiamata** `game.damage_player(`, col ricevente in
## minuscolo: il contratto e i commenti scrivono `Game.damage_player(x)` con la G
## maiuscola, quindi il confronto non li conta. Se un giorno la chiamata cambia
## forma, questo test lo dice col nome del file: e' il segnale che la `grep` del
## vertice va rilanciata.
func _touch_caller(h) -> void:
	var citano := PackedStringArray()
	var chiamano := PackedStringArray()
	for path in _file_gdc_in("res://src"):
		if _contiene(path, "damage_player("):
			citano.append(path)
		if _contiene(path, "game.damage_player("):
			chiamano.append(path)
	citano.sort()
	chiamano.sort()
	# I tre file che possono legittimamente contenere la parola: il contratto che
	# la dichiara, `player.gd` che registra l'implementazione, e l'orda che
	# chiama. Qualunque altro nome significa che una quarta foglia e' entrata in
	# mezzo, e allora il criterio n. 1 va riletto.
	const AMMESSI := ["res://src/core/contracts.gd", "res://src/player/player.gd",
		"res://src/sim/horde.gd"]
	for path in citano:
		h.check(AMMESSI.has(path),
			"in src/ damage_player compare solo nel contratto, in player.gd e in horde.gd: trovato %s"
				% path)
	h.check(citano.has("res://src/sim/horde.gd"),
		"src/sim/horde.gd deve contenere damage_player: trovati %s" % str(citano))
	h.eq(chiamano.size(), 1,
		"in src/ deve esserci UN solo file che chiama davvero damage_player")
	h.check(chiamano.size() == 1 and chiamano[0] == "res://src/sim/horde.gd",
		"e deve essere src/sim/horde.gd, non un test: trovati %s" % str(chiamano))

## Le asserzioni sull'economia del morso, e la stampa del numero finale.
##
## Sono **bande**, non soglie: i numeri che escono sono dichiarati nella sezione
## 11 e questa funzione li ricontrolla a ogni lancio. Una banda che si stringe
## fino a diventare un numero esatto smetterebbe di misurare la cosa che
## descrive e comincerebbe a misurare il caso fortunato.
func _touch_economia(h, misure: Array) -> void:
	for m in misure:
		var seme_i := int(m["seme"])
		var pop_i := int(m["pop"])
		h.check(float(m["cadenza"]) >= BITE_RATE_MIN,
			"seme %d (%d vivi): il nemico morde davvero, %.2f morsi/s non puo' essere sotto %.1f"
				% [seme_i, pop_i, float(m["cadenza"]), BITE_RATE_MIN])
		h.check(float(m["cadenza"]) <= BITE_RATE_MAX,
			"seme %d: la cadenza rispetta il tetto TOUCH_INTERVAL (1/%.2f = %.1f morsi/s), misurata %.2f"
				% [seme_i, HORDE.TOUCH_INTERVAL, BITE_RATE_MAX, float(m["cadenza"])])
		h.check(int(m["morsi"]) > 0,
			"seme %d: almeno un morso in %d passi" % [seme_i, TOUCH_STEPS])
		h.eq(int(m["morse_passo_max"]), 1,
			"seme %d: mai piu' di un morso che arriva nello stesso passo" % seme_i)
		h.check(float(m["gap_min"]) >= HORDE.TOUCH_INTERVAL - DT - 0.000001,
			"seme %d: due morsi consecutivi distano almeno TOUCH_INTERVAL (%.4f s misurati)"
				% [seme_i, float(m["gap_min"])])
		var sopr := float(m["sopravvivenza"])
		h.check(sopr >= SURVIVAL_MIN and sopr <= SURVIVAL_MAX,
			"seme %d (%d vivi): %.1f s da fermo al centro deve stare fra %.0f e %.0f"
				% [seme_i, pop_i, sopr, SURVIVAL_MIN, SURVIVAL_MAX])
		h.check(int(m["in_contatto"]) > 0,
			"seme %d: qualcuno e' davvero a portata di morso (%d)" % [seme_i, int(m["in_contatto"])])

	# Il confronto che chiude la curva: il danno al secondo dell'orda piena non
	# e' un multiplo di quello dell'onda piccola. E' la ragione per cui il tetto
	# e' a intervallo e non per passo.
	var piccola := 1.0e9
	var grande := 0.0
	for m in misure:
		piccola = minf(piccola, float(m["dps"]))
		grande = maxf(grande, float(m["dps"]))
	var rapporto := grande / maxf(0.001, piccola)
	h.check(rapporto <= DPS_RATIO_MAX,
		"l'orda piena fa al massimo %.1f volte il danno al secondo dell'onda piccola: misurato %.2f"			% [DPS_RATIO_MAX, rapporto])
	print("orda: morso, %.0f s per caso: %.2f-%.2f hp/s, %.2f-%.2f morsi/s, %.1f-%.1f s da fermo con 100 hp, orda piena %.2f volte l'onda piccola"
		% [float(TOUCH_STEPS) * DT, piccola, grande,
			float(misure[0]["cadenza"]), float(misure[3]["cadenza"]),
			float(misure[3]["sopravvivenza"]), float(misure[0]["sopravvivenza"]),
			rapporto])

## A `game_over` la simulazione e' ferma, quindi nessun morso: il giocatore morto
## non e' un bersaglio che continua a prendere colpi. E' la continuazione della
## regola di `step()` ("lo stato della partita si guarda PRIMA di muovere
## chiunque"), vista dal lato del morso.
func _touch_game_over(h, horde: HORDE) -> void:
	var morti := _morsi
	h.check(horde.run.enter_game_over(), "la partita entra in game_over")
	h.check(horde.is_game_over(), "e horde.is_game_over() lo dice")
	for _i in 300:
		horde.step(DT)
	h.eq(_morsi, morti, "in game_over nessun morso arriva addosso")
	h.eq(horde.touch_damage_last, 0.0, "e l'orda non dichiara nessun danno")
	horde.restart_run()
	h.check(not horde.is_game_over(), "il restart rimette la partita in corso")
	h.eq(horde.touch_damage_last, 0.0, "e azzera il danno dell'ultimo passo")
	# Punto 3 del contratto di m8: `radii` si ricompone **negli stessi punti** degli
	# altri array paralleli, e il restart e' uno di quelli.
	h.eq(horde.radii.size(), horde.count,
		"m8: radii e' allineata a count dopo restart_run")
	var raggi_dopo_restart := 0
	for i in horde.count:
		if absf(horde.radii[i] - ENEMY.RADIUS[horde.kinds[i]]) > 0.000001:
			raggi_dopo_restart += 1
	h.eq(raggi_dopo_restart, 0,
		"m8: dopo il restart ogni nemico ha il raggio della sua specie")

# --- 12. m8: la portata del morso rimisurata sulla scena vera ------------------
#
# ## Perche' una sezione nuova e non una riga cambiata in `TOUCH_REACH`
#
# Il valore di prima, **1.2**, era dichiarato «misurato» in `src/sim/enemy.gd`,
# ed era misurato **sull'orda isolata di questo file**, con uno **spia** al posto
# del giocatore. Uno spia accetta ogni morso. Il giocatore vero no:
# `player.gd::take_damage` scarta il danno durante l'invulnerabilita' dopo un
# colpo (`INVULN_AFTER_HIT = 0.7 s`). Quindi la misura di m7 era **la produzione
# dell'orda**, non **l'ingestione del giocatore**, ed e' su quella che `TOUCH_REACH`
# era stato scelto. Qui sotto la scena e' vera, il giocatore e' vero, e i numeri
# che escono sono quelli che il giocatore sente.
#
# ## Cosa misura, e in che ordine
#
# 1. **Il corpo che il giocatore vede**: mezzo ingombro orizzontale del modello
#    vero, in metri. E' l'unico numero che puo' volere la parola «contatto»:
#    due corpi si toccano quando la somma dei loro raggi e' la distanza, e se il
#    nemico e' `RADIUS[kind]` allora il margine che resta al giocatore e' **il
#    suo raggio**, non una costante messa li' per andare bene.
# 2. **Dove si ferma davvero l'orda** a 200 vivi: la scala delle portate conta i
#    corpi entro `RADIUS[kind] + r`, quindi dice esattamente quanti nemici
#    morderebbero a ogni candidato. La scala contiene **0.0** (nessun margine)
#    e il **valore di prima, 1.2**: scegliere senza aver guardato entrambi
#    sarebbe scegliere a occhio.
# 3. **L'ingestione vera**: hp persi dal giocatore vero in 30 s a regime, e poi
#    il tempo fino alla morte con 100 hp.
#
# Il passo e' **fisso** (`DT`) e lo guida questo test, non il ciclo di frame:
# un passo fisso e' l'unica misura riproducibile (vedi la nota in testa al
# file). La scena resta vera — stessi nodi, stesso orda, stesso giocatore,
# stesso renderer — ma il suo `process_mode` e' disabilitato perche' due orologi
# non si misurano.

const ARENA_SCENE := "res://scenes/arena_main.tscn"
const NODO_HORDE := "Horde"
const NODO_PLAYER := "Player"

## Le portate da contare sulla scena vera. Vedi il punto 2 sopra.
const LADDER_REACH := [0.0, 0.15, 0.30, 0.45, 0.60, 0.90, 1.20]
## Passi di riscaldamento e di finestra: 1800 passi a DT sono 30 s.
const VERA_WARMUP := 1800
const VERA_WINDOW := 1800
## Vita data al giocatore vero **mentre si misura la geometria e l'ingestione**,
## cosi' il riscaldamento non finisce a `game_over` a meta' misura. `hp` e' un
## campo pubblico sul contratto di m2 ed e' gia' pilotato allo stesso modo da
## `tests/test_gameloop.gd`; nessun'altra proprieta' del giocatore e' toccata.
const VERA_HP_ALTO := 1000000.0

## La distanza minima mai vista fra il **punto** del giocatore e il **bordo del
## corpo** di un nemico (`dist - RADIUS[kind]`), su tutta la scena vera.
var _gap_min_vera := 1.0e9
## Gli stessi scarti dei nemici entro 6 m dal giocatore, campione del contatto.
var _gap_vicini := PackedFloat32Array()

## ## Lo stato di m10 **dell'orda che gioca**, letto dalla scena vera
##
## Campi e non variabili di `_scena_vera`: la scena viene liberata prima che
## `_ostacoli_contratto` torni a guardare, e un riferimento a un nodo liberato non
## e' un numero che si puo' confrontare con niente. Qui dentro finiscono i quattro
## valori, presi **mentre il nodo e' vivo**; la sezione 13e asserisce su questi e
## dichiara perche' non asserisce sull'orda isolata di questo file.
var _vera_flow_obstacles := -1
var _vera_flow_problem := "(non letta: la scena vera non e' stata aperta)"
var _vera_flow_active := false
var _vera_flow_rebuilds := -1

func _scena_vera(h, isolate: HORDE) -> void:
	var arena = _apri_arena(h)
	if arena == null:
		return
	# Due oroli non si misurano: la scena non gira da sola, il passo e' nostro.
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var horda: HORDE = arena.get_node_or_null(NODO_HORDE) as HORDE
	var giocatore = arena.get_node_or_null(NODO_PLAYER)
	if not h.check(horda != null and giocatore != null,
			"la scena vera deve avere i nodi %s e %s" % [NODO_HORDE, NODO_PLAYER]):
		_chiudi(arena)
		_ripristina(h, isolate)
		return

	giocatore.hp = VERA_HP_ALTO
	horda.population = HORDE.MAX_ENEMIES
	var passi_pieno := 0
	while horda.count < HORDE.MAX_ENEMIES and passi_pieno < 6000:
		_passo_vera(horda, giocatore, DT)
		passi_pieno += 1
	h.eq(horda.count, HORDE.MAX_ENEMIES,
		"scena vera: l'orda arriva a %d nemici vivi, non a 25" % HORDE.MAX_ENEMIES)
	h.eq(horda.radii.size(), horda.count,
		"scena vera: anche radii e' allineata a count con 200 vivi")
	h.eq(horda.transforms.size(), horda.count, "scena vera: transforms allineata")

	# 1. il corpo che il giocatore vede, e il criterio n. 2 di m8
	var corpo := _corpo_visivo(giocatore)
	h.positive(corpo,
		"scena vera: il giocatore ha un corpo visibile di raggio positivo")
	# L'invariante, non il numero: `TOUCH_REACH` deve **uguale** il raggio del
	# corpo che il giocatore vede. E' scritto cosi' e non "vicino a 0.45" perche'
	# se il modello del giocatore cambia il numero deve cambiare con lui, e
	# l'unita' che se ne accorge e' questo assert. Rimettere `TOUCH_REACH` al
	# valore di prima (1.2) qui deve dire FAIL: e' il dente del criterio n. 2.
	h.near(ENEMY.TOUCH_REACH, corpo, 0.0001,
		"criterio n. 2: TOUCH_REACH (%.4f) e' il raggio del corpo che il giocatore VEDE (%.4f)"
			% [ENEMY.TOUCH_REACH, corpo])
	# E la forma del criterio: per **ogni** specie, la frontiera del morso e' il
	# bordo del nemice che tocca il bordo del giocatore. Nessuna specie e'
	# esclusa, quindi il numero non vale solo per il runner.
	for k in ENEMY.KIND_COUNT:
		h.near(ENEMY.RADIUS[k] + ENEMY.TOUCH_REACH, corpo + ENEMY.RADIUS[k], 0.0001,
			"criterio n. 2: il %s morde fino a %.2f m = bordo del nemico %.2f + bordo del giocatore %.2f"
				% [ENEMY.KIND_NAMES[k], ENEMY.RADIUS[k] + ENEMY.TOUCH_REACH,
					ENEMY.RADIUS[k], corpo])
	# Il numero del raggio e' **uno solo** (criterio n. 4 di m8): quello che
	# l'orda espone dev'essere quello della tabella, non una sua copia.
	var raggi_non_di_tabella := 0
	for i in horda.count:
		if absf(horda.radii[i] - ENEMY.RADIUS[horda.kinds[i]]) > 0.000001:
			raggi_non_di_tabella += 1
	h.eq(raggi_non_di_tabella, 0,
		"criterio n. 4: horde.radii[i] e' RADIUS[kinds[i]] per tutti i %d vivi" % horda.count)

	# 2. dove si ferma l'orda: scala delle portate e scarto minimo mai visto
	_gap_min_vera = 1.0e9
	_gap_vicini = PackedFloat32Array()
	for _i in VERA_WARMUP:
		_passo_vera(horda, giocatore, DT)
		_campiona_gap(horda, giocatore.global_position)
	var contatti := _conta_contatti(horda, giocatore.global_position)
	var ordinati := _gap_vicini.duplicate()
	ordinati.sort()
	var dentro := int(contatti[float(ENEMY.TOUCH_REACH)])

	print("m8 scena vera: corpo visibile del giocatore, raggio %.4f m" % corpo)
	print("m8 scena vera: scarto minimo mai visto (giocatore - bordo del corpo) %.4f m"
		% _gap_min_vera)
	if ordinati.size() > 0:
		print("m8 scena vera: scarto dei %d nemici entro 6 m -- min %.4f, mediana %.4f, max %.4f m"
			% [ordinati.size(), ordinati[0], ordinati[ordinati.size() / 2],
				ordinati[ordinati.size() - 1]])
	for r in LADDER_REACH:
		print("m8 scena vera: portata %.2f m -> %d nemici a portata di morso su %d"
			% [float(r), int(contatti[float(r)]), horda.count])
	h.check(dentro > 0,
		"scena vera: con TOUCH_REACH = %.2f qualcuno e' davvero a portata (%d su %d)"
			% [ENEMY.TOUCH_REACH, dentro, horda.count])

	# 3. l'ingestione vera: hp persi in 30 s, e poi il tempo fino alla morte
	var hp0 := float(giocatore.hp)
	var offerti := 0
	var accettati := 0
	for _i in VERA_WINDOW:
		var prima := float(giocatore.hp)
		_passo_vera(horda, giocatore, DT)
		offerti += horda.touch_bites_last
		if float(giocatore.hp) < prima:
			accettati += 1
	var persi := hp0 - float(giocatore.hp)
	var finestra := float(VERA_WINDOW) * DT
	var cadenza := float(offerti) / finestra
	var danno_morso := persi / maxf(1.0, float(accettati))
	var dps := persi / finestra
	print("m8 scena vera: %d morsi offerti in %.0f s (%.2f/s), %d accettati dal giocatore, %.2f hp persi"
		% [offerti, finestra, cadenza, accettati, persi])
	print("m8 scena vera: %.2f hp per morso accettato, %.2f hp/s, %d morsi su %d scartati dall'invulnerabilita'"
		% [danno_morso, dps, offerti - accettati, offerti])

	giocatore.hp = PLAYER_HP_REFERENCE
	var passi_morte := 0
	while float(giocatore.hp) > 0.0 and passi_morte < 6000:
		_passo_vera(horda, giocatore, DT)
		passi_morte += 1
	var morto := float(giocatore.hp) <= 0.0
	var secondi := float(passi_morte) * DT
	print("m8 scena vera: giocatore fermo al centro, %d vivi: %s dopo %.2f s (calcolato %.2f s)"
		% [horda.count, "morto" if morto else "VIVO", secondi,
			PLAYER_HP_REFERENCE / maxf(0.0001, dps)])
	h.check(morto,
		"scena vera: il giocatore vero deve morire fermo al centro con l'orda piena")
	h.check(secondi > 0.0, "scena vera: il tempo di sopravvivenza e' positivo")

	# ## Lo stato di m10 di **questa** orda, letto adesso che e' viva
	#
	# `horda` e' l'orda che gioca: e' quella che `-arena` ha costruito **dopo** che
	# il contratto aveva gia' i 27 dischi, quindi e' l'unica su cui
	# `flow_problem == ""` ha un significato. Qui sotto viene liberata con tutta la
	# scena, e i quattro numeri restano per la sezione 13e.
	_vera_flow_obstacles = horda.obstacle_count()
	_vera_flow_problem = horda.flow_problem
	_vera_flow_active = horda.flow_active()
	_vera_flow_rebuilds = horda.flow_rebuilds

	_chiudi(arena)
	_ripristina(h, isolate)

## Un passo della scena vera, a passo fisso.
##
## Della scena si guida **l'orda sola**. Del giocatore si scalda **un solo
## timer**, `invuln`, ed e' una scelta dichiarata e non una scorciatoia:
##
##   - `invuln` e' l'unica cosa che `player.gd::step` fa che riguarda il morso.
##     Senza scalarlo il giocatore vero resta **permanentemente invulnerabile**
##     dal primo colpo in poi, e la misura dell'ingestione dava 0.00 hp persi su
##     51 morsi offerti: era la prima stesura di questa sezione, ed e' il numero
##     che ha fatto capire che il valore di prima era misurato su uno spia che
##     accettava tutto.
##   - chiamare `step()` per intero porterebbe dentro la misura una **seconda
##     macchina**: l'arma che spara da sola ucciderebbe proprio gli anelli di
##     nemici che qui si stanno contando. Sarebbe la classe di difetto di
##     piano 1.5b: un ambiente che azzera la grandezza sotto esame.
##
## `invuln` e' un campo pubblico del nodo, come `hp`: qui sotto si scrivono due
## campi pubblici di un'altra foglia e non si chiama nessun suo metodo.
func _passo_vera(horda, giocatore, delta: float) -> void:
	giocatore.invuln = maxf(0.0, float(giocatore.invuln) - delta)
	horda.step(delta)

## Il contratto torna a puntare sull'orda isolata di questo file. Senza questo la
## scena vera, appena liberata, lascerebbe il contratto con `horde` e tre API
## che non portano piu' da nessuna parte: un test che viene dopo leggerebbe un
## numero e lo chiamerebbe «l'orda».
func _ripristina(h, isolate: HORDE) -> void:
	var game := _game()
	if game == null or isolate == null:
		return
	game.horde = isolate
	game.register_impl("nearest_enemy", isolate.nearest_enemy_index)
	game.register_impl("damage_enemy", isolate.damage_enemy)
	game.register_impl("random_spawn_point", isolate.random_spawn_point)
	h.check(game.horde == isolate,
		"dopo la scena vera il contratto torna a puntare all'orda isolata")

## Distanza fra il punto del giocatore e il **bordo del corpo** del nemico `i`:
## `dist - radii[i]`. E' la grandezza che `TOUCH_REACH` e' chiamato a coprire,
## e su di lei e' costruita la scala delle portate.
func _gap(horda: HORDE, centro: Vector3, i: int) -> float:
	return Vector2(horda.transforms[i].x - centro.x,
			horda.transforms[i].z - centro.z).length() - horda.radii[i]

## Campiona gli scarti: il minimo di tutti e il campione dei nemici entro 6 m.
func _campiona_gap(horda: HORDE, centro: Vector3) -> void:
	for i in horda.count:
		var g := _gap(horda, centro, i)
		_gap_min_vera = minf(_gap_min_vera, g)
		if g <= 6.0:
			_gap_vicini.append(g)

## Quanti corpi sono entro `RADIUS + r`, per ogni r della scala. Conteggio
## geometrico e quindi esatto: non serve cambiare `TOUCH_REACH` per sapere chi
## morderebbe a un portata data, basta contare gli scarti.
func _conta_contatti(horda: HORDE, centro: Vector3) -> Dictionary:
	var out := {}
	for r in LADDER_REACH:
		out[float(r)] = 0
	for i in horda.count:
		var g := _gap(horda, centro, i)
		for r in LADDER_REACH:
			if g <= float(r):
				out[float(r)] = int(out[float(r)]) + 1
	return out

## Il raggio del corpo **visibile** del giocatore: mezzo ingombro orizzontale del
## suo modello, con la scala del nodo gia' dentro. Cio' che l'occhio chiama
## «corpo del giocatore». Non e' un numero di questa foglia: e' una lettura
## della scena vera, ed e' per questo che vale come riferimento e non come
## costante duplicata da qualche parte.
func _corpo_visivo(nodo: Node) -> float:
	var mesh: Array[MeshInstance3D] = []
	_cerca_mesh(nodo, mesh)
	var semi := 0.0
	for m in mesh:
		if m.mesh == null:
			continue
		var aabb: AABB = m.mesh.get_aabb()
		var s := m.global_transform.basis.get_scale()
		semi = maxf(semi, maxf(aabb.size.x * 0.5 * absf(s.x), aabb.size.z * 0.5 * absf(s.z)))
	return semi

func _cerca_mesh(nodo: Node, out: Array[MeshInstance3D]) -> void:
	for c in nodo.get_children():
		if c is MeshInstance3D:
			out.append(c as MeshInstance3D)
		_cerca_mesh(c, out)

## `scenes/arena_main.tscn` caricata a runtime, mai in `const`: un `const preload`
## risolve i suoi script **prima** che l'autoload `Game` sia fra le costanti
## globali di GDScript, e `player.gd` usa l'identificatore nudo `Game`
## (piano 5.3, la trappola).
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
	return arena as Node3D

## Libera la scena **subito**: `remove_child` e poi `free`, non `queue_free`, cosi'
## l'albero e' pulito quando la funzione torna e il conteggio dei nodi dopo e' un
## numero e non una promessa.
func _chiudi(arena) -> void:
	if arena == null:
		return
	if arena.get_parent() != null:
		arena.get_parent().remove_child(arena)
	arena.free()


## Tutti i file `.gd` sotto `dir_path`, ricorsivamente. Serve alla `grep` della
## sezione 11b: il chiamante di `damage_player` va cercato in **tutto** `src/`,
## non nella directory che questa foglia si aspetta di scrivere.
func _file_gdc_in(dir_path: String) -> PackedStringArray:
	return _file_con_estensione(dir_path, ".gd")

## Tutti i file con estensione `ext` sotto `dir_path`, ricorsivamente.
##
## La sezione 15 (`population_scale`) cerca anche dentro `res://scenes`, e le
## scene sono `.tscn`: la stessa ricorsione serve per due estensioni diverse, e
## due copie della stessa funzione sarebbero due numeri che possono divergere.
func _file_con_estensione(dir_path: String, ext: String) -> PackedStringArray:
	var trovati := PackedStringArray()
	var d := DirAccess.open(dir_path)
	if d == null:
		return trovati
	for nome in d.get_files():
		if nome.ends_with(ext):
			trovati.append(dir_path.path_join(nome))
	for sotto in d.get_directories():
		trovati.append_array(_file_con_estensione(dir_path.path_join(sotto), ext))
	return trovati

## Quante volte `ago` compare **in codice** dentro `path`, cioe' fuori dai
## commenti.
##
## ## Perche' conta solo il codice
##
## Il nome della cucitura e' scritto in decine di righe di documentazione dentro
## `src/sim/horde.gd`, e quelle righe sono il **perche'** del campo: contarle
## insieme al codice darebbe un numero che cambia ogni volta che qualcuno
## spiega meglio, cioe' un criterio che va rosso per un-commento. Quindi ogni
## riga viene troncata al primo `#` e il segno viene cercato solo nel pezzo
## rimasto.
##
## `-1` quando il file non si apre: e' un file che non esiste, e un `-1` che
## passerebbe un `== 2` non sarebbe un numero ma un difetto.
func _occorrenze_di_codice(path: String, ago: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var n := 0
	for riga in f.get_as_text().split("\n"):
		n += riga.split("#")[0].count(ago)
	return n

func _contiene(path: String, ago: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	return f.get_as_text().contains(ago)

## Il contratto, via nodo e non via identificatore nudo.
##
## Sotto `--script` il file principale viene compilato **prima** che l'autoload
## `Game` sia registrato fra le costanti globali di GDScript: `Game.horde` qui
## dentro non da un errore di logica, da
## `Compile Error: Identifier not found: Game`, e il test morirebbe su quello
## prima di eseguire un solo assert. Il nodo che si ottiene e' lo stesso
## identico su cui horde.gd si registra, quindi la strada aggira la
## compilazione, non il contratto (piano 5.3).
func _game() -> Node:
	return root.get_node_or_null("Game")

func _m10_libero(p: Vector3, obs: PackedVector3Array) -> float:
	var skin := ENEMY.radius_of(ENEMY.BOSS)
	var m := 1.0e9
	for k in obs.size():
		var ob := obs[k]
		m = minf(m, Vector2(p.x - ob.x, p.z - ob.z).length() - (ob.y + skin))
	return m

## La traccia del peggiore colpevole: dieci passi, uno per riga, **per sempre**.
##
## Non e' una sonda e non sta in un file a parte: e' la parte che rende
## citabile la sezione 13c. Il criterio n. 4 dice «peggiore = 12 passi», e quel
## numero senza nessun contesto e' un rosso che nessuno sa spiegare. Qui il
## colpevole si chiama, si stampa dieci passi della sua vita — posizione,
## distanza dal bordo dell'arena, velocita', distanza dal disco piu' vicino,
## linea diretta libera o interrotta, e direzione che il campo gli da' — e cosi'
## la sezione 13c si cita per nome e per numero.
##
## Dieci passi e non uno: un singolo passo dice dove il nemico e', non **come ci
## e' arrivato**: la firma di un incastrato e' che posizione e velocita' restano
## le stesse per piu' campioni di fila, e una riga non puo' distinguerla da un
## nemico che ci sta solo passando davanti.
func _incastrato_dettaglio(horde: HORDE, campo: FLOW, obs: PackedVector3Array,
		i: int, peggiore: int) -> void:
	if i < 0 or i >= horde.count:
		return
	print("m10: colpevole i=%d (%s, r=%.2f m), fermo sotto %.2f m/s per %d passi di fila: traccia di 10 passi"
		% [i, horde.kind_name(i), horde.radii[i], STUCK_SPEED, peggiore])
	for s in 10:
		var p := horde.transforms[i]
		var v := horde.velocities[i]
		var st := campo.steer(p, Vector3.ZERO)
		print("m10:   passo %d p=(%8.3f,%8.3f) |p|=%6.2f v=(%7.3f,%7.3f) |v|=%.4f disco=%7.3f clear=%s steer=(%6.3f,%6.3f)"
			% [s, p.x, p.z, Vector2(p.x, p.z).length(), v.x, v.z, v.length(),
				_m10_libero(p, obs), str(campo.clear_line(p, Vector3.ZERO)), st.x, st.z])
		horde.step(DT)

## Conta i nodi dell'albero a mano. `get_node_count()` dentro un `--script` vale
## 0 (il ciclo di frame non e' ancora partito), quindi un test che ci si
## appoggiasse passerebbe sempre: meglio contarli davvero.
func _count_nodes(nodo: Node) -> int:
	var totale := 1
	for c in nodo.get_children():
		totale += _count_nodes(c)
	return totale

# --- 13. m10: gli ostacoli, e il nemico che li aggira davvero -----------------
#
# ## Cosa c'e' in questa sezione, e in che ordine
#
#   `_ostacoli`             i numeri dichiarati e le loro garanzie (criterio n. 1)
#   `_aggira`               **il criterio n. 2**: quanti nemici sono dentro un
#                          ostacolo, durante una partita vera, e quanto tempo
#                          ci mettono ad arrivare al giocatore
#   `_incastrati`           il criterio n. 4: nessuno fermo in un angolo
#   `_spawn_sicuro`         il criterio n. 5: nessuno nasce dentro un disco
#   `_ostacoli_contratto`   la catena: `Game.obstacles` esiste davvero
#
# ## Il trucco di montare il campo, e perche' non e' un trucco
#
# `horde.flow_field` e' un campo pubblico di questa simulazione, e questa sezione
# ci scrive dentro quando il contratto **non** e' ancora montato. Non e' un
# fallback del gioco: `horde._build()` non ha questa strada e non la vuole, il
# gioco legge solo il contratto, e il punto e' che senza questa riga i numeri di
# m10 non si potrebbero **misurare** finche' il vertice non aggiunge il campo al
# contratto. La sezione `_ostacoli_contratto` esiste perche' questa misura non
# sostituisce la catena: e' la porta che va rossa quando la catena manca.
#
# Quando il contratto sara' montato la misura userà **automaticamente** gli
# ostacoli registrati invece di quelli dichiarati qui, e i numeri stampati
# cambieranno se `-arena` avra' scelto una forma diversa: e' per questo che sono
# stampati e non asseriti come costanti.

## Il seme della disposizione su cui e' misurato m10. Fisso perche' una misura
## senza seme non e' confrontabile con la corsa successiva.
const M10_SEME := 4242
## Passi di assestamento e passi di finestra, a DT = 1/60: 10 s e 30 s.
const M10_WARMUP := 600
const M10_WINDOW := 1800
## Banda sulla frazione di nemici con la retta al giocatore interrotta, misurata
## **su tutto il percorso, avvicinamento incluso** (vedi la tabella in testa al
## file, e `_aggira`). I numeri sono **quelli che escono**: 14,1% misurati, e la
## banda sta a 2,8 volte il pavimento e a 4,2 volte dal tetto. Non e' una banda
## abbassata per far passare: e' la banda dichiarata che il numero rispetta con
## margine da entrambe le parti, e la tabella in testa dice perche' il campione di
## regime (3,4%) non poteva governarla.
const M10_DEVIA_MIN := 5.0
const M10_DEVIA_MAX := 60.0
## Passi entro i quali **qualcuno** deve arrivare a portata di morso, e passi
## entro i quali devono arrivarne meta'. Sono le due stime del «tempo per
## arrivare al giocatore» che il criterio n. 2 chiede di misurare: il primo e'
## il tempo del piu' veloce, il secondo e' il tempo della folla.
const M10_ARRIVO_MAX := 900
const M10_META_MAX := 3600
## Quanti semi di disposizione il criterio n. 5 deve coprire. Ventiquattro e'
## lo stesso campione con cui m3 ha misurato la densita': un campione che non
## cambia da una milestone all'altra e' confrontabile.
const M10_SEMI := 24
## Quanti punti di spawn casuale per ogni seme.
const M10_PUNTI := 200

## Il raggio con cui un punto viene giudicato «dentro»: il **corpo del nemico
## piu' grosso**, non quello della specie. E' il criterio n. 5 sul minimo dei
## tre, non sul massimo.
func _m10_skin() -> float:
	return ENEMY.radius_of(ENEMY.BOSS)

## Il punto e' dentro un disco, corpo compreso? Stessa domanda che si pone il
## campo e che si pone il gioco: e' l'unica definizione di «dentro» che vale.
func _m10_dentro(p: Vector3, obs: PackedVector3Array, skin: float) -> bool:
	for k in obs.size():
		var ob := obs[k]
		var rr := ob.y + skin
		var dx := p.x - ob.x
		var dz := p.z - ob.z
		if dx * dx + dz * dz < rr * rr:
			return true
	return false

## La geometria su cui misurare, e il campo montato sopra.
##
## Se il contratto e' montato si usa **quella**; altrimenti quella dichiarata in
## `src/sim/obstacles.gd`, che e' la stessa che `-arena` registrera' quando
## potra'. La riga di stampa dice quale delle due e' in gioco: una misura che
## non dice su che cosa e' stata fatta e' un numero senza significato.
func _m10_monta(horde: HORDE) -> PackedVector3Array:
	if horde.obstacle_count() > 0:
		print("m10: ostacoli dal contratto, %d dischi" % horde.obstacle_count())
		return horde.obstacles
	var dichiarati := OBST.layout(horde.arena_radius)
	var campo: FLOW = FLOW.new()
	campo.build(dichiarati, horde.arena_radius, _m10_skin())
	campo.rebuild(Vector3.ZERO)
	horde.obstacles = dichiarati
	horde.flow_field = campo
	print("m10: contratto NON montato, misuro sui %d dischi dichiarati in src/sim/obstacles.gd"
		% dichiarati.size())
	return dichiarati

# --- 13a. I numeri dichiarati e le loro garanzie (criterio n. 1) ----------------

## Perche' questa sezione guarda i numeri **scritti** e non quelli registrati:
## il numero e' di `-orda` (§3.11), quindi qui si controlla che la misura del
## criterio n. 2 sia ancora quella che e' stata scritta. Se `-arena` sceglie
## qualcos'altro, la sezione `_ostacoli_contratto` lo dice con i suoi numeri e la
## decisione torna al vertice.
func _ostacoli(h, horde: HORDE) -> void:
	var R := horde.arena_radius
	var dichiarati := OBST.layout(R)
	h.eq(dichiarati.size(), OBST.OBSTACLE_COUNT,
		"m10: la geometria dichiarata contiene tutti gli ostacoli dichiarati")
	h.check(dichiarati.size() > 0, "m10: la geometria dichiarata non e' vuota")

	# Punto 3 del contratto: `y` e' il raggio, ed e' positivo. Un raggio nullo e'
	# un ostacolo che non esiste, e si distingue dal negativo solo per il crash.
	var raggi_bassi := 0
	var fuori := 0
	for k in dichiarati.size():
		var e: Vector3 = dichiarati[k]
		if not (e.y > 0.0):
			raggi_bassi += 1
		if Vector2(e.x, e.z).length() + e.y > R:
			fuori += 1
	h.eq(raggi_bassi, 0, "m10: ogni ostacolo ha `y` > 0, cioe' un raggio positivo")
	h.eq(fuori, 0, "m10: ogni ostacolo e' intero dentro l'arena")

	var r := OBST.radius_for(R)
	# Il raggio in metri: 2,99 a R = 46. La soglia e' sul **rapporto con il nemico
	# piu' grosso**, non sul numero assoluto: un disco deve essere piu' largo
	# della sagoma del boss, altrimenti non e' un muro e non si vede che e' un
	# muro.
	h.check(r > ENEMY.RADIUS[ENEMY.BOSS],
		"m10: il disco (%.2f m) e' piu' largo del nemico piu' grosso (%.2f m)"
			% [r, ENEMY.RADIUS[ENEMY.BOSS]])
	h.check(r < R * 0.12,
		"m10: il disco (%.2f m) resta un ostacolo e non un campo minato: sotto il 12%% del raggio"
			% r)
	print("m10: %d dischi di raggio %.2f m su un'arena di %.1f m" % [dichiarati.size(), r, R])

	## ## La garanzia che tiene aperto il campo: nessuna fessura stretta
	##
	## Due dischi che si toccano sono un muro solo, e una fessura piu' stretta
	## della sagoma del boss e' un incastrato che aspetta solo un nemico grosso.
	## Il numero e' la distanza fra due centri: deve superare `2 * raggio +
	## diametro del boss`, e allora il passaggio utile e' piu' largo di qualsiasi
	## nemico che ci passi.
	var sep := OBST.min_separation(dichiarati)
	var utile := sep - 2.0 * r
	h.check(sep > 2.0 * r + 2.0 * ENEMY.RADIUS[ENEMY.BOSS],
		"m10: i due dischi piu' vicini sono a %.2f m: il passaggio utile (%.2f m) e' piu' largo del boss (%.2f m)"
			% [sep, utile, 2.0 * ENEMY.RADIUS[ENEMY.BOSS]])
	print("m10: dischi piu' vicini a %.2f m, passaggio utile %.2f m (boss: %.2f m)"
		% [sep, utile, 2.0 * ENEMY.RADIUS[ENEMY.BOSS]])

	## ## Il campo: nessuna cella libera irraggiungibile
	##
	## Una cella che il campo non sa raggiungere e' un posto dove il campo non sa
	## dire niente, e il nemico che ci finisce e' un nemico fermo. Il numero si
	## guarda **dopo** aver costruito il campo e averlo ricostruito dal bersaglio
	## al centro, che e' la posizione da cui parte il giocatore.
	var campo: FLOW = FLOW.new()
	campo.build(dichiarati, R, _m10_skin())
	campo.rebuild(Vector3.ZERO)
	h.check(campo.unreachable == 0,
		"m10: nessuna cella libera e' irraggiungibile dal centro (irraggiungibili: %d su %d)"
			% [campo.unreachable, campo.cells_x * campo.cells_z])
	h.check(campo.blocked_cells() > 0, "m10: il campo ha davvero celle bloccate")
	print("m10: campo %dx%d celle da %.1f m, %d bloccate, gonfiatura %.2f m"
		% [campo.cells_x, campo.cells_z, FLOW.CELL, campo.blocked_cells(), campo.inflate])

	## Il campo da fermo non costa niente: e' la promessa di `GOAL_MOVE`, e una
	## promessa non verificata e' una decorazione.
	var prima := campo.rebuilds
	for _i in 60:
		if campo.needs_rebuild(Vector3.ZERO):
			campo.rebuild(Vector3.ZERO)
	h.eq(campo.rebuilds, prima,
		"m10: 60 richieste di campo a bersaglio fermo non ricostruiscono niente")
	# E muovendo il bersaglio di `GOAL_MOVE` il campo torna, altrimenti
	# l'evitamento inseguirebbe un giocatore fermo e non uno che corre.
	h.check(campo.needs_rebuild(Vector3(FLOW.GOAL_MOVE + 0.5, 0.0, 0.0)),
		"m10: il campo si ricostruisce quando il bersaglio si sposta oltre %.1f m" % FLOW.GOAL_MOVE)

# --- 13b. Il criterio n. 2: nessun nemico dentro un ostacolo ------------------

func _aggira(h, horde: HORDE) -> void:
	var obs := _m10_monta(horde)
	h.check(obs.size() > 0, "m10: la geometria da misurare non e' vuota")
	var campo: FLOW = horde.flow_field
	if not h.check(campo != null, "m10: il campo e' montato sulla simulazione"):
		return

	horde.set_focus(Vector3.ZERO)
	horde.auto_respawn = true
	# L'onda viene bloccata a 1 per la stessa ragione della sezione 11c: con
	# l'onda che avanza, `population` cresce e la misura finisce descrivendo
	# un'orda diversa da quella che si voleva misurare.
	horde.run.wave = 1
	horde.run.wave_killed = 0
	horde.reseed(M10_SEME)
	horde.population = HORDE.MAX_ENEMIES
	var passi := 0
	while horde.count < HORDE.MAX_ENEMIES and passi < 6000:
		horde.step(DT)
		passi += 1
	h.eq(horde.count, HORDE.MAX_ENEMIES, "m10: la misura parte da %d nemici" % HORDE.MAX_ENEMIES)
	h.eq(horde.inside_obstacles(), 0,
		"m10: al primo passo nessuno e' gia' dentro un ostacolo (disposizione e' fatta fuori)")

	# ## La frazione di deviazione si campiona su **tutto** il percorso, avvicinamento
	# ## incluso, e non solo sulla finestra: la finzione che prima la nascondeva
	# ##
	# Il campione di prima contava i segmenti interrotti **dentro la finestra**, cioe'
	# dopo 10 s di avvicinamento. Ma a quel punto l'orda e' gia' addosso al
	# giocatore: `t_primo` e `t_meta` sono entrambi **0.00 s**, cioe' meta' dell'orda
	# e' dentro `ARRIVE_RADIUS` al primo passo campionato. Un nemico a 2 m dal
	# bersaglio ha una retta lunga 2 m, e il disco piu' vicino e' a 12,19 m: la
	# domanda «la mia retta e' interrotta?» ha la risposta **no** per costruzione,
	# qualunque sia la geometria. Il numero che ne usciva (3,9%) non era una misura
	# della deviazione: era una misura di **quanto era lontano il nemico**, cioe'
	# una misura della velocita' dell'orda. E il tetto superiore della banda
	# («non piu' del 60%, altrimenti l'orda si muove a ondate») su quella domanda
	# non poteva mai parlare di ondate.
	#
	# Quindi il campione parte dall'orda piena appena riempita e copre
	# `M10_WARMUP + M10_WINDOW` passi: l'avvicinamento e' **il** momento in cui il
	# nemico incontra i dischi, e una misura che lo salta misura il vuoto.
	# I due numeri vengono stampati **entrambi** (avvicinamento e finestra), e la
	# banda e' scritta sul primo, dichiarando quale dei due e'.
	var campioni := 0
	var deviati := 0
	var campioni_fin := 0
	var deviati_fin := 0
	var dentro_tot := 0
	var dentro_max := 0
	var dentro_passi := 0
	var t_primo := -1
	var t_meta := -1
	var meta := horde.count / 2
	# Campionamento dei due numeri sulla stessa passata, senza pagare due volte i
	# segmenti: ogni 10 passi (1/6 di secondo) la disposizione cambia lentamente
	# rispetto al passo, quindi il campione non perde nessun evento.
	for s in M10_WARMUP + M10_WINDOW:
		horde.step(DT)
		if s >= M10_WARMUP:
			# Il criterio n. 2 (nessuno dentro un ostacolo) e' dichiarato sulla
			# finestra: e' la condizione di regime, non quella di avvicinamento.
			var dentro := _conta_dentro(horde, campo)
			if dentro > 0:
				dentro_tot += dentro
				dentro_passi += 1
			dentro_max = maxi(dentro_max, dentro)
			if t_primo < 0 and _in_contatto(horde, Vector3.ZERO) > 0:
				t_primo = s - M10_WARMUP
			if t_meta < 0 and _in_contatto(horde, Vector3.ZERO) >= meta:
				t_meta = s - M10_WARMUP
		if s % 10 == 0:
			var in_finestra := s >= M10_WARMUP
			for i in horde.count:
				campioni += 1
				if not campo.clear_line(horde.transforms[i], Vector3.ZERO):
					deviati += 1
					if in_finestra:
						deviati_fin += 1
			if in_finestra:
				campioni_fin += horde.count

	# Il numero che il piano chiede al criterio n. 2: **quanti nemici sono
	# dentro un ostacolo**, durante una partita vera. Zero, e non "pochi".
	h.eq(dentro_tot, 0,
		"m10 criterio n. 2: nessun nemico dentro un ostacolo in %d passi a %d vivi (rilevati %d, in %d passi, picco %d)"
			% [M10_WINDOW, HORDE.MAX_ENEMIES, dentro_tot, dentro_passi, dentro_max])
	h.eq(dentro_passi, 0, "m10: nessun passo con un nemico dentro un ostacolo")
	h.check(t_primo >= 0, "m10: qualcuno arriva al giocatore (il campo non blocca l'orda)")
	if t_primo >= 0:
		h.check(t_primo < M10_ARRIVO_MAX,
			"m10: il primo arrivo avviene entro %.0f s (misurati %.2f s)"
				% [float(M10_ARRIVO_MAX) * DT, float(t_primo) * DT])
	if t_meta >= 0:
		h.check(t_meta < M10_META_MAX,
			"m10: meta' dell'orda arriva entro %.0f s (misurati %.2f s)"
				% [float(M10_META_MAX) * DT, float(t_meta) * DT])

	var fraz := 100.0 * float(deviati) / maxf(1.0, float(campioni))
	var fraz_fin := 100.0 * float(deviati_fin) / maxf(1.0, float(campioni_fin))
	print("m10: finestra %.0f s a %d vivi: %d nemici dentro un ostacolo, picco %d in un passo"
		% [float(M10_WINDOW) * DT, horde.count, dentro_tot, dentro_max])
	print("m10: retta interrotta, tutto il percorso (avvicinamento incluso): %.1f%% (%d su %d campioni)"
		% [fraz, deviati, campioni])
	print("m10: retta interrotta, solo finestra di regime: %.1f%% (%d su %d campioni)"
		% [fraz_fin, deviati_fin, campioni_fin])
	print("m10: primo arrivo %.2f s, meta' dell'orda %.2f s"
		% [float(maxi(0, t_primo)) * DT, float(maxi(0, t_meta)) * DT])
	print("m10: campo ricostruito %d volte in %d passi (bersaglio fermo al centro)"
		% [horde.flow_rebuilds, M10_WARMUP + M10_WINDOW])

	## ## Il tempo per arrivare **passando attorno**, dichiarato
	##
	## Il primo arrivo e' il numero del criterio n. 2, ma da solo non distingue
	## «ha aggirato» da «era gia' vicino»: la banda sotto e' quella che lo dice.
	h.check(fraz >= M10_DEVIA_MIN,
		"m10: almeno il %.1f%% dell'orda deve aggirare davvero, altrimenti la milestone e' invisibile (misurato %.1f%%)"
			% [M10_DEVIA_MIN, fraz])
	h.check(fraz <= M10_DEVIA_MAX,
		"m10: non piu' del %.1f%% deve aggirare, altrimenti l'orda si muove a ondate e il gioco e' un labirinto (misurato %.1f%%)"
			% [M10_DEVIA_MAX, fraz])

## Nemici dentro un ostacolo, con un accorto che rende la misura possibile.
##
## Il test esatto e' quello di `flow_field.gd::contains` e resta il riferimento,
## ma chiamarlo per 200 nemici ogni passo sono 5.400 confronti: la griglia del
## campo dice prima se il punto e' anche solo **vicino** a un disco, e il
## confronto esatto si fa solo su quelli. La scorciatoia non viene creduta: sotto
## e' asserito che sui punti dove la griglia dice «puo' essere dentro» il test
## esatto e il conteggio danno lo stesso numero.
func _conta_dentro(horde: HORDE, campo: FLOW) -> int:
	var n := 0
	for i in horde.count:
		if _forse_dentro(horde.transforms[i], campo) and campo.contains(horde.transforms[i], horde.radii[i]):
			n += 1
	return n

func _forse_dentro(p: Vector3, campo: FLOW) -> bool:
	var cx := int(floor((p.x - campo.origin_x) / FLOW.CELL))
	var cz := int(floor((p.z - campo.origin_z) / FLOW.CELL))
	if cx < 0 or cz < 0 or cx >= campo.cells_x or cz >= campo.cells_z:
		return true
	return campo.blocked[cz * campo.cells_x + cx] != 0

## Quanti nemici sono a portata di morso del bersaglio: `RADIUS + TOUCH_REACH`,
## cioe' la stessa frontiera che `src/sim/enemy.gd` usa per mordere.
func _in_contatto(horde: HORDE, centro: Vector3) -> int:
	var n := 0
	for i in horde.count:
		var p := horde.transforms[i]
		var d := Vector2(p.x - centro.x, p.z - centro.z).length()
		if d <= horde.radii[i] + ENEMY.TOUCH_REACH:
			n += 1
	return n

# --- 13c. Il criterio n. 4: nessuno si incastra -------------------------------
#
# ## Perche' questa sezione esiste e come puo' fallire
#
# Il difetto tipico di un campo di percorrenza e' l'**incastrato**: il nemico
# che si ferma in un angolo e non si muove piu'. Non produce errori, non crasha,
# e nessuna asserzione sul «dentro un ostacolo» lo vede — perche' un nemico
# incastrato e' un nemico *benissimo* dal punto di vista del criterio n. 2: e'
# fuori dall'ostacolo, e li' fermo e immobile. Per questo il criterio e' scritto
# sulla velocita' e su quanti passi di fila la tiene bassa.
#
# ## La soglia e i passi, e perche' sono questi
#
# `ARRIVE_RADIUS = 3.0` in `src/sim/enemy.gd`: un nemico **dentro** quella
# distanza rallenta di proposito (`arrive = dist / 3`), e a 0,1 m dal bersaglio
# un runner avanza a 0,22 m/s. Non e' incastrato: e' arrivato. Percio' il
# criterio si applica ai nemici **fuori** dall'arrivo, e la soglia di velocita'
# puo' stare sotto quella di un runner che arriva senzache nessuno lo confonda
# con un nemico fermo.
#
# `STUCK_STEPS = 90` sono **1,5 s** a DT = 1/60: sopra, un nemico che rallenta
# per la folla che gli passa addosso e un nemico incastrato non si distinguono
# piu', e il criterio comincerebbe a misurare il rumore della separazione.

## Soglia di velocita' sotto la quale un nemico che non e' arrivato e' fermo, m/s.
const STUCK_SPEED := 0.30
## Passi di fila sotto la soglia prima che il nemico sia dichiarato incastrato.
const STUCK_STEPS := 90

func _incastrati(h, horde: HORDE) -> void:
	var obs := _m10_monta(horde)
	var campo: FLOW = horde.flow_field
	if not h.check(campo != null, "m10: il campo e' montato sulla simulazione"):
		return
	h.check(obs.size() > 0, "m10: la geometria da misurare non e' vuota")

	horde.set_focus(Vector3.ZERO)
	horde.auto_respawn = true
	horde.run.wave = 1
	horde.run.wave_killed = 0
	horde.reseed(M10_SEME)
	horde.population = HORDE.MAX_ENEMIES
	var passi := 0
	while horde.count < HORDE.MAX_ENEMIES and passi < 6000:
		horde.step(DT)
		passi += 1

	# Il contatore e' per **indice**, e gli indici cambiano a ogni morte: qui
	# non muore nessuno (nessun colpo nella finestra), quindi l'indice e' lo
	# stesso nemico per tutta la misura. E' scritto perche' la regola vale
	# finche' e' vero, e non perche' sia comodo.
	var lenti := PackedInt32Array()
	lenti.resize(horde.count)
	var peggiore := 0
	var peggiore_i := -1
	var colpevoli := 0
	var campioni_lenti := 0
	for _i in M10_WARMUP:
		horde.step(DT)
	for s in M10_WINDOW:
		horde.step(DT)
		var fuori_arrivo := 0
		var lenti_passo := 0
		for i in horde.count:
			var p := horde.transforms[i]
			if Vector2(p.x, p.z).length() <= ENEMY.ARRIVE_RADIUS + horde.radii[i]:
				# arrivato: rallenta di proposito, non e' incastrato
				lenti[i] = 0
				continue
			fuori_arrivo += 1
			if horde.velocities[i].length() < STUCK_SPEED:
				lenti[i] += 1
				lenti_passo += 1
			else:
				lenti[i] = 0
		campioni_lenti += lenti_passo
		if lenti_passo > 0:
			for i in horde.count:
				if lenti[i] > peggiore:
					peggiore = lenti[i]
					peggiore_i = i
					colpevoli = 1
				elif lenti[i] == peggiore and peggiore > 0:
					colpevoli += 1
	h.check(peggiore <= STUCK_STEPS,
		"m10 criterio n. 4: nessun nemico fermo sotto %.2f m/s per piu' di %d passi di fila (misurati %d)"
			% [STUCK_SPEED, STUCK_STEPS, peggiore])
	print("m10: in %.0f s nessun nemico e' restato fermo piu' di %d passi (%.1f s); passo peggiore %d su %d"
		% [float(M10_WINDOW) * DT, STUCK_STEPS, float(STUCK_STEPS) * DT, peggiore, STUCK_STEPS])
	print("m10: sotto %.2f m/s fuori dall'arrivo, %d campioni su %d (%d nemici-passo su %d)"
		% [STUCK_SPEED, campioni_lenti, M10_WINDOW * HORDE.MAX_ENEMIES,
			campioni_lenti, M10_WINDOW * HORDE.MAX_ENEMIES])
	if peggiore > 0:
		_incastrato_dettaglio(horde, campo, obs, peggiore_i, peggiore)

# --- 13c-bis. I denti del criterio n. 3: che cosa misura davvero ----------------
#
# ## Perche' questa sezione esiste, e che cosa sarebbe una prova falsa
# ##
# Il criterio n. 3 della milestone dice: «`horde.flow_field = null` deve dire
# FAIL con i numeri». Il **dente** di un criterio non e' il verde: e' la prova che
# il rosso e' raggiungibile. Un criterio che misura `dentro == 0` passa anche se
# nella simulazione non c'e' mai nessun ostacolo, e anche se `contains` restituisce
# `false` perche' e' scritto male. E' la classe di difetto di §1.6, ed e' la
# ragione per cui il punto 5 della semantica di m10 («un insieme vuoto e' un
# errore») esiste come frase.
# ##
# Quindi qui la **stessa** geometria, lo **stesso** seme e lo **stesso** passo
# girano due volte: una col campo montato e una con `flow_field = null`. Il primo
# caso deve dare `dentro == 0` (e lo ridice, perche' la sezione 13b lo fa
# dichiarato); il secondo deve dare `dentro > 0`. Se il secondo desse zero, il
# criterio n. 2 non starebbe misurando niente e questa sezione andrebbe rossa.
#
# Il conteggio del braccio spento usa un **campo separato**, costruito qui sulla
# stessa geometria: con `flow_field = null` non c'e' nessun campo su cui chiamare
# `contains`, e chiamare `horde.inside_obstacles()` restituirebbe sempre 0 per la
# guardia `if flow_field != null`. Il numero che deve crescere e' il punto, e il
# punto si conta con un metodo che non dipende dal fatto che il campo sia montato.

func _denti_del_criterio(h, horde: HORDE) -> void:
	var obs := OBST.layout(horde.arena_radius)
	# Il campo che **conta**: stessa geometria, stesso raggio del nemico piu'
	# grosso. Non e' quello della simulazione, che qui e' spento di proposito.
	var conta: FLOW = FLOW.new()
	conta.build(obs, horde.arena_radius, _m10_skin())
	conta.rebuild(Vector3.ZERO)
	var montato = horde.flow_field
	horde.flow_field = null
	horde.set_focus(Vector3.ZERO)
	horde.auto_respawn = true
	horde.run.wave = 1
	horde.run.wave_killed = 0
	horde.reseed(M10_SEME)
	horde.population = HORDE.MAX_ENEMIES
	var passi := 0
	while horde.count < HORDE.MAX_ENEMIES and passi < 6000:
		horde.step(DT)
		passi += 1
	var dentro_tot := 0
	var dentro_max := 0
	var dentro_passi := 0
	for _s in M10_WARMUP + M10_WINDOW:
		horde.step(DT)
		var dentro := _conta_dentro(horde, conta)
		if dentro > 0:
			dentro_tot += dentro
			dentro_passi += 1
		dentro_max = maxi(dentro_max, dentro)
	horde.flow_field = montato
	h.check(dentro_tot > 0,
		"m10 criterio n. 3: col campo spento il criterio n. 2 deve andare ROSSO (rilevati %d nemici dentro un ostacolo in %d passi, picco %d)"
			% [dentro_tot, dentro_passi, dentro_max])
	h.check(montato != null and horde.flow_field == montato,
		"il campo e' stato rimesso dopo la prova: la sezione 13b resta quella che misura")
	print("m10: denti del criterio n. 2 -- campo spento: %d nemici dentro un ostacolo in %d passi su %d (picco %d in un passo); a R=46,0 m erano 17524 in 1306 passi (picco 55)"
		% [dentro_tot, dentro_passi, M10_WARMUP + M10_WINDOW, dentro_max])
	print("m10: denti del criterio n. 2 -- campo acceso (sezione 13b): 0 nemici dentro un ostacolo a R=%.1f m, come a R=46,0 m" % horde.arena_radius)

# --- 13d. Il criterio n. 5: nessuno nasce dentro un disco ---------------------

func _spawn_sicuro(h, horde: HORDE) -> void:
	var obs := _m10_monta(horde)
	if not h.check(obs.size() > 0, "m10: la geometria da misurare non e' vuota"):
		return
	var skin := _m10_skin()
	var dentro_layout := 0
	var dentro_spawn := 0
	var semi := 0
	var punti := 0
	# Ventiquattro semi, non uno: la disposizione cambia a ogni seme e un punto
	# di nascita dentro un disco su ventiquattro disposizioni e' un punto di
	# nascita dentro un disco in partita vera.
	for s in M10_SEMI:
		var seme := 1 + s * 10
		horde.reseed(seme)
		semi += 1
		for i in horde.count:
			if _m10_dentro(horde.transforms[i], obs, skin):
				dentro_layout += 1
		for _k in M10_PUNTI:
			var p := horde.random_spawn_point()
			punti += 1
			if _m10_dentro(p, obs, skin):
				dentro_spawn += 1
	h.eq(dentro_layout, 0,
		"m10 criterio n. 5: nessun nemico della disposizione iniziale dentro un disco, su %d semi" % semi)
	h.eq(dentro_spawn, 0,
		"m10 criterio n. 5: nessun punto di spawn casuale dentro un disco, %d punti su %d semi"
			% [punti, semi])
	# Il vincolo e' sul **corpo del nemico piu' grosso**, quindi un disco puo'
	# essere libero per un runner e pieno per un boss. Il numero sotto e' la
	# frazione di punti che ci cadono dentro: se fosse zero, il criterio non
	# starebbe misurando niente e la soglia sarebbe decorativa.
	print("m10: %d semi, %d punti di spawn e %d posizioni iniziali, nessuno dentro un disco (raggio %.2f m)"
		% [semi, punti, semi * horde.count, skin])

# --- 13e-bis. m11: il raggio 46 -> 60, misurato dalle due parti ----------------
#
# ## Perche' questa sezione esiste invece di una riga cambiata
#
# Il passaggio da 46,0 a 60,0 m non e' una costante: e' **la geometria su cui la
# simulazione converge**, quindi cambia quattro cose che nessun `assert` su una
# costante vedrebbe — la griglia del campo, la griglia dei vicini, la misura
# della pista fra i dischi e il costo per passo. Ognuna di queste ha un numero
# di prima, e un numero di prima che non e' stampato accanto a quello di dopo e'
# una riga che qualcuno fra tre mesi legge come se fosse sempre stata cosi'.
#
# ## Il metodo: le due misure nello stesso processo, con lo stesso codice
#
# Il numero di prima **non** e' rileggi da un file di log e non e' ricordato a
# memoria: e' rimisurato qui, a 46,0 m, dalla stessa identica funzione che
# rimisura il dopo a 60,0 m, nello stesso lancio e sullo stesso processore. Il
# solo modo in cui si cambia qualcosa in mezzo e' `Game.arena_radius`, che e'
# l'unica sorgente del raggio (contratto di m9), e il valore dichiarato viene
# rimesso **e asserito** prima che la sezione successiva legga qualcosa.
#
# ## Cosa non e' dentro il confronto, e perche'
#
# Il **criterio n. 2 con il campo spento** (i denti) gira una volta sola, a
# 60,0 m: due bracci da 2400 passi sono esattamente quello che ha fatto scadere
# il timeout di 120 s in m11. Il suo numero di prima (17 524 a 46 m) e' il
# valore dichiarato nella tabella in testa al file, e qui sotto la sezione 13c-bis
# lo stampa accanto al numero di oggi: e' l'unico dei quattro criteri di m10 che
# non e' rimisurato due volte, ed e' dichiarato perche'.
#
# ## I due picchi della griglia dei vicini, e non sono uno
#
# `worst_bucket()` dice due cose diverse a due momenti diversi, e il raggio nuovo
# le sposta in due direzioni opposte:
#
#   - **sulla disposizione iniziale** (`reseed`, primo frame): e' la griglia che
#     m3 ha campionato su 24 semi e su cui `GRID_CEILING = 8` e' dichiarato. Il
#     disco piu' grande la **raffredda**: piu' spazio, meno nemici per cella;
#   - **a regime**, con i 200 addensati sul bersaglio: e' il caso peggiore in
#     assoluto, ed e' la misura che ha fatto scegliere `BUCKET_SLOTS = 32` in m1
#     (picco 19 allora, con la sola separazione). Anche questo scende a 60 m, e
#     per la stessa ragione: l'anello che si stringe intorno al giocatore e'
#     limitato dal primo anello di dischi, che a 46 m e' a 15,18 m dal centro e a
#     60 m e' a 19,80 m.
#
# Il tetto `GRID_CEILING = 8` vive in `tests/test_arena.gd`, che e' di `-arena`:
# questa sezione **stampa** i due numeri e non tocca la costante, perche' la
# costante va riderivata dalla chi la possiede quando quella chiude la porta
# rossa. Dichiararlo qui sarebbe la copia che m9 ha imparato a contare.
#
# ## Il raggio di prima, dichiarato come nome e non come copia del contratto
#
# `RAGGIO_PRIMA` e' il raggio che m9 ha consegnato: e' il valore che questa sezione
# deve poter rimettere sul contratto per confrontare, non il raggio di oggi scritto
# due volte. Se il vertice tornasse a 46,0 m, questa sezione continuerebbe a
# confrontare 46 contro 60 e a dire che sono la stessa cosa: ed e' esattamente la
# difetta che il criterio n. 2 di m9 chiude, quindi la sezione comincia anche da
# un'asserzione che i due numeri siano **diversi**.

## Il raggio di m9, il valore che questa sezione rimette sul contratto per fare
## il confronto. Non e' una copia del raggio di oggi: e' il numero di **prima**,
## e senza di questo la sezione misurerebbe 60 contro 60 e chiamerebbe «uguali»
## due numeri che non si sommano.
const RAGGIO_PRIMA := 46.0
## Passi di assestamento e passi misurati, **per ogni raggio**, a DT = 1/60.
##
## L'assestamento serve perche' il costo per passo dipende dallo **stato**:
## un'orda ancora sparsa sul disco costa meno di un'orda da 200 addensata sul
## giocatore, e confrontare 46 m a folla con 60 m a folla e' l'unico confronto
## che dice qualcosa. 600 passi sono 10 s, e a 60 m il nemico piu' esterno parte
## dal bordo e arriva al centro in meno di 9 s: quindi la misura parte da un
##'orda **arrivata** in entrambi i casi. I 240 passi misurati sono 4 s, dieci
## volte il periodo di ricostruzione del campo (GOAL_MOVE a 13,65 m/s = 0,44 s),
## e sono presi col **minimo** per il motivo gia' dichiarato in `_query_budget`:
## tutto quello che c'e' dentro una singola corsa e' rumore che si somma solo.
const RAGGIO_WARMUP := 600
const RAGGIO_PASSI := 240
## Quanti byte occupa una cella del campo: `blocked` e `fuori` sono un byte,
## `cost`, `dir_x`, `dir_z` e `queue` sono quattro. Serve per dire che cosa
## costa in memoria il raggio nuovo, che e' il numero che il raggiovecchio
## non aveva.
const BYTE_PER_CELLA := 18

## Ostacoli e campo **costruiti per un raggio dato**, montati sulla simulazione.
##
## `src/sim/flow_field.gd` non viene toccato: `build()` deriva **tutto** dal
## raggio che riceve (dimensione della griglia, gonfiatura, maschera del muro),
## quindi l'unica cosa che serve per confrontare due raggi e' chiamarlo con il
## raggio giusto. Il perche' questa funzione esiste e non sta dentro la sezione
## e' che serve **due volte**, una per ciascun raggio.
func _monta_raggio(horde: HORDE, r: float) -> FLOW:
	var obs := OBST.layout(r)
	var campo: FLOW = FLOW.new()
	campo.build(obs, r, _m10_skin())
	campo.rebuild(Vector3.ZERO)
	horde.obstacles = obs
	horde.flow_field = campo
	return campo

## Una misura completa al raggio `r`: griglia del campo, dischi, griglia dei
## vicini, criterio n. 2 e costo per passo. Restituisce i numeri e non li
## asserisce, perche' sono **due** misure da confrontare e la frase che le
## confronta e' una sola.
func _misura_raggio(h, horde: HORDE, game: Node, r: float) -> Dictionary:
	# L'unica sorgente del raggio e' il contratto: e' quello che `_contract_radius()`
	# rilegge a ogni passo, quindi e' quello che si scrive. La copia dell'orda
	# (`horde.arena_radius`) la ricalcola da sola al primo passo.
	game.arena_radius = r
	horde.arena_radius = r
	var campo := _monta_raggio(horde, r)
	# Il contatore del campo parte da qui: quello che conta e' quante volte si
	# ricostruisce **durante i passi**, e non quante volte l'ha costruito questa
	# sezione per misurarlo.
	var ricostruite_all_inizio: int = campo.rebuilds
	horde.set_focus(Vector3.ZERO)
	horde.auto_respawn = true
	# L'onda bloccata a 1 per la stessa ragione delle sezioni 11c e 13b: con
	# l'onda che avanza, `population` cresce e la misura finisce descrivendo
	# un'orda diversa da quella che si voleva confrontare.
	horde.run.wave = 1
	horde.run.wave_killed = 0
	horde.population = HORDE.MAX_ENEMIES
	# `reseed` ripopola **a `population`** senza dover fare la rampa degli 8/s:
	# un confronto di costo che includesse il riempimento misurerebbe il ritmo
	# di spawn e non il passo.
	horde.reseed(M10_SEME)
	h.eq(horde.count, HORDE.MAX_ENEMIES,
		"m11: a R=%.1f la misura parte da %d nemici" % [r, HORDE.MAX_ENEMIES])
	# Il picco **della disposizione** e' il numero su cui `GRID_CEILING` e'
	# dichiarato, quindi va preso qui, sul primo frame dopo `reseed`: e' la
	# griglia che m3 ha campionato con 24 semi. Il picco **a regime**, che si
	# legge piu' sotto, e' un'altra grandezza e va detto quale e': e' l'orda da
	# 200 addensata sul bersaglio, cioe' il caso peggiore, non quello che il tetto
	# di densita' descrive.
	var picco_disposizione := horde.worst_bucket()

	for _i in RAGGIO_WARMUP:
		horde.step(DT)

	# Il **minimo** del costo per passo e' la stima piu' vicina a «quanto costa
	# davvero»: il resto e' il carico della macchina, che cambia da un giro
	# all'altro e che nessuno deve confondere con il codice.
	var costo_min := 1 << 40
	var costo_tot := 0
	var picco := 0
	var traboccati := 0
	for _i in RAGGIO_PASSI:
		var t0 := Time.get_ticks_usec()
		horde.step(DT)
		var dt_us := Time.get_ticks_usec() - t0
		costo_min = mini(costo_min, dt_us)
		costo_tot += dt_us
		picco = maxi(picco, horde.worst_bucket())
		if horde.grid_overflowed():
			traboccati += 1

	var dentro := horde.inside_obstacles()
	h.eq(dentro, 0,
		"m11: a R=%.1f nessun nemico dentro un ostacolo dopo %d passi a %d vivi"
			% [r, RAGGIO_WARMUP + RAGGIO_PASSI, horde.count])
	h.eq(horde.grid_unknown_cells, 0,
		"m11: a R=%.1f la griglia dei vicini non ha creato celle nuove" % r)
	h.eq(traboccati, 0,
		"m11: a R=%.1f nessun passo e' caduto a scansione lineare" % r)
	h.eq(campo.unreachable, 0,
		"m11: a R=%.1f nessuna cella libera del campo e' irraggiungibile (%d su %d)"
			% [r, campo.unreachable, campo.cells_x * campo.cells_z])

	var obs: PackedVector3Array = horde.obstacles
	var disco := OBST.radius_for(r)
	var vicini := OBST.min_separation(obs)
	var area := 100.0 * float(obs.size()) * disco * disco / maxf(1.0, r * r)
	return {
		"r": r,
		"celle": campo.cells_x, "celle_tot": campo.cells_x * campo.cells_z,
		"bloccate": campo.blocked_cells(), "gonfiatura": campo.inflate,
		"celle_vicini": horde.occupied_cells(), "picco": picco,
		"picco_disposizione": picco_disposizione,
		"dentro": dentro, "ricostruzioni": campo.rebuilds - ricostruite_all_inizio,
		"disco": disco, "vicini": vicini, "passaggio": vicini - 2.0 * disco,
		"boss": 2.0 * ENEMY.RADIUS[ENEMY.BOSS], "area": area,
		"costo_min": float(costo_min) / 1000.0,
		"costo_med": float(costo_tot) / float(RAGGIO_PASSI) / 1000.0,
		"vivi": horde.count,
	}

## La sezione: due misure, una frase per numero.
##
## Il contratto torna al raggio dichiarato **prima** di tornare: sotto c'e' la
## riga che asserisce che il valore dichiarato e' ancora quello di prima della
## sezione, e che l'orda in memoria lo riporta al primo passo. Una sezione che
## lascia il contratto su un raggio di comodo lascerebbe tutte le sezioni
## successive una simulazione su un numero che nessuno ha dichiarato.
func _raggio_60(h, horde: HORDE) -> void:
	var game := _game()
	if not h.check(game != null, "m11: nessun contratto: il raggio non si puo' confrontare"):
		return
	var dichiarato := _raggio_contratto()
	h.check(dichiarato > RAGGIO_PRIMA,
		"m11: il contratto dichiara %.1f m e il confronto gira su %.1f m: senza i due numeri "
			% [dichiarato, RAGGIO_PRIMA]
		+ "diversi questa sezione misurerebbe un numero contro se stesso")

	var prima := _misura_raggio(h, horde, game, RAGGIO_PRIMA)
	var dopo := _misura_raggio(h, horde, game, dichiarato)

	# Rimessa a posto: il contratto al valore dichiarato, la geometria e il campo
	# al raggio di oggi, l'orda sul seme che le sezioni dopo si aspettano.
	game.arena_radius = dichiarato
	_monta_raggio(horde, dichiarato)
	horde.set_focus(Vector3.ZERO)
	horde.run.wave = 1
	horde.run.wave_killed = 0
	horde.population = HORDE.MAX_ENEMIES
	horde.reseed(M10_SEME)
	horde.step(DT)
	h.near(float(game.arena_radius), dichiarato, 0.0001,
		"m11: il contratto e' tornato al raggio dichiarato (%.1f m)" % dichiarato)
	h.near(horde.arena_radius, dichiarato, 0.0001,
		"m11: e l'orda in memoria riporta il raggio del contratto al primo passo")

	# ## Le quattro frasi, ognuna con il prima e il dopo nella stessa riga
	#
	# Il costo per passo e' l'unico dei quattro che **deve** peggiorare: il disco
	# e' 1,30 volte piu' grande e la griglia del campo ha 1,57 volte le celle. Il
	# numero e' scritto accanto a quello di prima perche' un peggioramento
	# dichiarato e' informazione e un peggioramento nascosto dietro «e' accettabile»
	# e' una decisione presa senza dirlo.
	print("m11: griglia del campo -- R=%.1f m: %dx%d = %d celle da %.1f m, %d bloccate, gonfiatura %.2f m (%.1f KB) | R=%.1f m: %dx%d = %d celle, %d bloccate, gonfiatura %.2f m (%.1f KB)"
		% [float(prima["r"]), int(prima["celle"]), int(prima["celle"]), int(prima["celle_tot"]),
			FLOW.CELL, int(prima["bloccate"]), float(prima["gonfiatura"]),
			float(prima["celle_tot"]) * BYTE_PER_CELLA / 1024.0,
			float(dopo["r"]), int(dopo["celle"]), int(dopo["celle"]), int(dopo["celle_tot"]),
			int(dopo["bloccate"]), float(dopo["gonfiatura"]),
			float(dopo["celle_tot"]) * BYTE_PER_CELLA / 1024.0])
	print("m11: ostacoli -- R=%.1f m: %d dischi di %.2f m, i due piu' vicini a %.2f m, passaggio utile %.2f m (%.2fx il boss), area %.1f%% | R=%.1f m: %d dischi di %.2f m, i due piu' vicini a %.2f m, passaggio utile %.2f m (%.2fx il boss), area %.1f%%"
		% [float(prima["r"]), OBST.OBSTACLE_COUNT, float(prima["disco"]),
			float(prima["vicini"]), float(prima["passaggio"]),
			float(prima["passaggio"]) / maxf(0.001, float(prima["boss"])), float(prima["area"]),
			float(dopo["r"]), OBST.OBSTACLE_COUNT, float(dopo["disco"]),
			float(dopo["vicini"]), float(dopo["passaggio"]),
			float(dopo["passaggio"]) / maxf(0.001, float(dopo["boss"])), float(dopo["area"])])
	print("m11: griglia dei vicini -- disposizione iniziale: R=%.1f m: %d celle riscaldate, picco %d | R=%.1f m: %d celle riscaldate, picco %d (GRID_CEILING = 8 e' la costante di tests/test_arena.gd, file di -arena: questa sezione la stampa e non la tocca, e i due numeri ci stanno sotto)"
		% [float(prima["r"]), int(prima["celle_vicini"]), int(prima["picco_disposizione"]),
			float(dopo["r"]), int(dopo["celle_vicini"]), int(dopo["picco_disposizione"])])
	print("m11: griglia dei vicini -- a regime, 200 addensati sul bersaglio: R=%.1f m: picco %d | R=%.1f m: picco %d, nessun traboccamento su %d slot (e' la misura che ha fatto scegliere BUCKET_SLOTS = 32, e non il numero che descrive GRID_CEILING)"
		% [float(prima["r"]), int(prima["picco"]), float(dopo["r"]), int(dopo["picco"]),
			GRID.BUCKET_SLOTS])
	print("m11: criterio n. 2 e campo fermo -- R=%.1f m: %d nemici dentro un ostacolo, campo ricostruito %d volte | R=%.1f m: %d nemici dentro un ostacolo, campo ricostruito %d volte (in %d passi a %d vivi, bersaglio fermo al centro)"
		% [float(prima["r"]), int(prima["dentro"]), int(prima["ricostruzioni"]),
			float(dopo["r"]), int(dopo["dentro"]), int(dopo["ricostruzioni"]),
			RAGGIO_WARMUP + RAGGIO_PASSI, HORDE.MAX_ENEMIES])
	print("m11: costo per passo con %d nemici -- R=%.1f m: min %.3f ms, medio %.3f ms | R=%.1f m: min %.3f ms, medio %.3f ms (%.2f volte il minimo di prima; a 46 m il numero dichiarato era 3,2 ms, il 19%% di un core a 60 fps, e a 60 m un core e' %.3f ms)"
		% [HORDE.MAX_ENEMIES, float(prima["r"]), float(prima["costo_min"]), float(prima["costo_med"]),
			float(dopo["r"]), float(dopo["costo_min"]), float(dopo["costo_med"]),
			float(dopo["costo_min"]) / maxf(0.0001, float(prima["costo_min"])), 1000.0 / 60.0])

# --- 13e. La catena: `Game.obstacles` esiste davvero ---------------------------
#
# ## Questa e' la sezione che tiene la trappola dell'onda chiusa
#
# Tutte le sezioni sopra possono passare con **zero ostacoli**: «nessun ostacolo
# blocca nessuno» e' vero anche quando non ce n'e'. Sarebbe una macchina
# verificata che il gioco non chiama (§1.6), e il punto 5 della semantica
# congelata lo dice con parole: un insieme vuoto e' un errore, non un mondo
# senza muri. Quindi qui si asserisce la **catena**, non l'algoritmo:
#
#   -arena costruisce -> -orda costruisce il campo -> -gameplay ci scontra.
#
# Le tre righe sotto sono la parte di questa sezione che resta rossa finche' il
# vertice non aggiunge `var obstacles: PackedVector3Array` in
# `src/core/contracts.gd`, e il motivo e' scritto nel messaggio.

func _ostacoli_contratto(h, horde: HORDE) -> void:
	var game := _game()
	if game == null:
		h.fail("m10: nessun contratto: gli ostacoli non possono esistere")
		return
	var raw = game.get("obstacles")
	h.check(raw is PackedVector3Array,
		"m10: il contratto dichiara Game.obstacles : PackedVector3Array. Trovato %s. "
			% type_string(typeof(raw))
		+ "La superficie di m10 e' documentata in src/core/contracts.gd ma il campo non c'e': "
		+ "senza quella riga -arena non registra niente, -orda costruisce il campo sul nulla "
		+ "e -gameplay non ha muri. Il file e' del vertice: nessuna foglia lo tocca.")
	if not (raw is PackedVector3Array):
		return
	var letti: PackedVector3Array = raw
	h.check(letti.size() > 0,
		"m10 criterio n. 1: gli ostacoli esistono. Un insieme vuoto e' un errore, non un mondo senza muri (contratto di m10, punto 5)")
	if letti.is_empty():
		return
	var radii := 0
	var bassi := 0
	for k in letti.size():
		radii += 1
		if not (letti[k].y > 0.0):
			bassi += 1
	h.eq(bassi, 0,
		"m10 criterio n. 1: ogni ostacolo registrato ha `y` > 0, cioe' il raggio e' in `y` e positivo")
	var sep := OBST.min_separation(letti)
	h.check(sep > 2.0 * OBST.radius_for(horde.arena_radius),
		"m10 criterio n. 1: nessuna coppia di dischi si tocca (min %.2f m, diametro %.2f m)"
			% [sep, 2.0 * OBST.radius_for(horde.arena_radius)])

	# ## L'orda che **gioca**, e non l'orda che il test ha costruito
	#
	# L'assersione qui sotto guardava `horde`, cioe' l'orda isolata di questo file.
	# Quella orda nasce in `_initialize()`, **prima** che `-arena` carichi la scena e
	# registri i 27 dischi sul contratto: quando il suo `_build()` gira,
	# `Game.obstacles` e' ancora vuoto, quindi `flow_problem` dice giustamente
	# «Game.obstacles e' vuoto» e l'evitamento e' spento. Il rosso che ne veniva
	# accusava il gioco di non aver montato il campo, e il gioco lo aveva montato:
	# accusava una **macchina** invece di un gioco. E' la differenza che questa
	# sezione esiste per dichiarare.
	#
	# I numeri sono presi **mentre l'orda della scena vera e' viva** (vedi
	# `_scena_vera`): dopo `_chiudi()` il nodo e' liberato e non c'e' piu' niente
	# da leggere, quindi la lettura avviene l'i' e il confronto qui.
	h.eq(_vera_flow_obstacles, letti.size(),
		"m10: l'orda che gioca ha letto dal contratto gli stessi %d ostacoli registrati" % letti.size())
	h.eq(_vera_flow_problem, "",
		"m10: l'orda che gioca ha costruito il campo: horde.flow_problem e' vuoto. Letto su %s"
			% _vera_flow_problem)
	h.check(_vera_flow_active, "m10: horde.flow_active() e' vero in partita")
	h.eq(_vera_flow_rebuilds, 0,
		"m10: a bersaglio fermo il campo non si ricostruisce (fuori dai %d passi che misurano il pieno)"
			% (M10_WARMUP + M10_WINDOW))
	print("m10: contratto -- %d ostacoli registrati, raggio %.2f m, i due piu' vicini a %.2f m"
		% [letti.size(), letti[0].y, sep])
	print("m10: orda che gioca -- %d ostacoli, flow_problem vuoto, campo attivo, %d ricostruzioni"
		% [_vera_flow_obstacles, _vera_flow_rebuilds])

# --- 14. m11-bis-b: il reroll della partita (criterio n. 2 di §1.14-ter) ---------
#
# ## Il difetto che questa sezione chiude, e la sua direzione
# #
# # Il fatto, verificato e scritto in piano §1.14-ter
# #
# `src/sim/horde.gd::_build()` fa `_rng.randomize()` quando `seed == 0`, e
# `scenes/arena_main.tscn` montava il nodo `Horde` **senza la proprietà `seed`**:
# quindi `seed == 0` a ogni montaggio e **ogni montaggio della scena vera era una
# partita diversa**. Non un difetto di `-gameplay` né di `-weapons`: misurato,
# `primo_colpo` e `dist_min` davano numeri diversi a ogni montaggio dello stesso
# comando (28,20 s / 8,58 s / 8,40 s di sopravvivenza: ampiezza 3,3×).
# #
# # Il rimedio, e perché è in due pezzi di due foglie
# #
# | chi | cosa possiede | cosa dichiara |
# |---|---|---|
# | `-arena`, `scenes/arena_main.tscn` | il **default** della scena | un `seed` **fisso** sulla scena |
# | `-orda`, `src/sim/horde.gd` | il **reroll** di partita | `restart_run()` **randomizza esplicitamente** |
# | `-arena`, `src/render/arena_ground.gd` | le casse | lo stesso seme, dichiarato |
# #
# **Il pezzo di questa foglia è il secondo, ed è quello che tiene insieme il
# progetto.** Con la scena a seme fisso e senza il reroll il gioco sarebbe
# **sempre identico**: si sarebbe scambiato un difetto con un altro, da «ogni
# misura è un campione» a «ogni partita è la stessa», che per un bullet heaven è
# peggio. Sono **un invariante e la sua faccia rossa**:
# #
#   - **criterio n. 1** — la scena vera montata N volte stampa lo stesso numero.
#     È di `-arena` e sta in `tests/test_gameplay.gd`: il seme fisso sulla scena.
#   - **criterio n. 2** — dopo `restart_run()` due partite consecutive hanno
#     disposizioni diverse. È **di questa sezione**.
# #
# Il criterio 2 da solo sarebbe un test verde sopra un gioco sempre uguale, che
# è la classe di difetto di §1.4a: per questo qui sotto c'è anche il suo
# **controllo** (la stessa disposizione, riperdotta a seme fisso, deve tornare
# identica) e non solo la faccia «diverse».
#
# ## Il metodo è quello di m3, non uno nuovo
# #
# Il confronto è **elemento per elemento** su `transforms`, con tolleranza zero,
# ed è il metodo a risposta nota con cui `tests/test_arena.gd` confronta due
# disposizioni (criterio n. 2 di m3): `_differing` sotto, e il tetto in
# `REROLL_FRACTIONE`, che è la frazione che m3 ha **misurata e dichiarata**
# (200 posizioni diverse su 200 con due semi diversi). Il confronto non passa
# per una somma di coordinate: una somma si può riequilibrare e sembrare uguale
# (`worst_bucket()` di §1.12 ha la stessa forma di argomento), e qui si vuole
# sapere se **i nemici** si sono spostati, non se il totale torna.
#
# ## Perché l'orda isolata e non la scena vera
# #
# Sulla scena vera il reroll si può misurare, ma **non in questa sezione**: un
# `restart_run()` a metà della sezione «m8 scena vera» cambierebbe la
# disposizione sotto la finestra di misura e renderebbe di nuovo un **campione**
# proprio il numero che il criterio n. 1 confronta fra montaggi. Il reroll si
# verifica dove è economico e dove non rompe niente: qui, su un'orda che ha una
# disposizione nota (`reseed(SEME_CAPACITY)`) e costa cinque disposizioni e
# **zero passi di simulazione**.
#
# ## Quanto costa
# #
# Cinque ripopolamenti da 25 nemici e zero `step()`: il tempo è stampato sotto,
# in microsecondi di motore. Il timeout di `tools/gate.gd` è 120 s e questo file
# gira già vicino: un criterio che si mangia secondi non è un criterio che si
# può eseguire.

## Quante posizioni devono moversi fra la disposizione di una partita e quella
## della successiva, in frazione dei nemici vivi.
##
## **Non è un numero scritto qui per far passare.** È la frazione che m3 ha
## dichiarato e misurata (`REPRO_DIFF_FRACTION` in `tests/test_arena.gd`, 0,9,
## derivata da 200 posizioni diverse su 200 con due semi diversi), ripresa perché
## la domanda è la stessa: «due disposizioni diverse, di quanto?». La ragione
## della frazione è quella di m3 — la disposizione è ad anelli e l'angolo di ogni
## nemico esce da `_rng`, quindi **tutti** si muovono — e il `maxi(1, ...)` tiene
## la forma di m3: un tetto di zero posizioni sarebbe un'asserzione che non può
## fallire, cioè la cosa che questa sezione sta cercando di evitare.
const REROLL_FRACTIONE := 0.9

func _reroll(h, horde: HORDE) -> void:
	var t0 := Time.get_ticks_usec()

	# ## 1. La disposizione che l'orda **consegna**
	#
	# `reseed(SEME_CAPACITY)` fa esattamente quello che fa `_build()` quando la
	# scena monta l'orda con un `seed` fisso: è la condizione in cui il difetto è
	# visibile, cioè un'orda con seme dichiarato che al restart **non** cambia.
	horde.reseed(SEME_CAPACITY)
	h.eq(horde.seed, SEME_CAPACITY,
		"m11-bis-b: reseed(s != 0) scrive il campo pubblico `seed` con s (punto 1 del contratto di m3)")
	var fissa: PackedVector3Array = horde.transforms.duplicate()
	var colori_fissi: PackedColorArray = horde.colors.duplicate()
	var vivi := horde.count
	var minimo := _tetto_diverse(vivi)

	# ## 2. Il reroll: **lo stesso punto di partenza, due restart**
	#
	# È la riga che dà i denti al criterio, e la ragione per cui non basta
	# confrontare due restart di fila.
	#
	# Il confronto «prima restart, seconda restart» **passerebbe anche senza
	# reroll**: `_populate` tira da `_rng`, e `_rng` dopo un ripopolamento è avanti,
	# quindi anche un restart che non rimescola niente produce una disposizione
	# diversa dalla precedente. Quel test sarebbe verde sopra un gioco in cui il
	# restart **non** cambia niente, che è la classe di difetto di §1.4a.
	#
	# Qui invece i due restart partono **dallo stesso stato**: fra i due si rimette
	# la disposizione a seme dichiarato, cioè `_rng` torna esattamente dove era.
	# Senza reroll i due restart darebbero quindi la **stessa** disposizione, bit
	# per bit, e questa riga andrebbe a 0/25 diverse; col reroll sono due estrazioni
	# indipendenti e non coincidono. La stessa identica disposizione è l'unica
	# risposta che sa distinguere «rimescolato» da «non rimescolato».
	#
	## Sono tre restart in tutta la sezione (B, B', C) e non uno: è il minimo che
	# dà **due** confronti indipendenti invece di uno solo, per il motivo che
	# `-gameplay` ha già dichiarato per `DETERM_N` nella sua sezione di §1.14-bis.
	## Il costo di un restart in più è 25 spawn e ~0,3 ms.
	var prima_partita := _restart_e_disposizione(h, horde, "B", vivi)
	horde.reseed(SEME_CAPACITY)
	var seconda_partita := _restart_e_disposizione(h, horde, "B'", vivi)
	var d := _differing(prima_partita, seconda_partita)
	h.check(d >= minimo,
		"criterio n. 2 (1.14-ter): due restart dallo STESSO punto di partenza devono dare disposizioni diverse, altrimenti il restart non ha rimescolato niente: %d posizioni diverse su %d, tetto ripreso da m3 il %.0f%% = %d"
			% [d, mini(prima_partita.size(), seconda_partita.size()),
				REROLL_FRACTIONE * 100.0, minimo])

	# ## 3. Il criterio come lo scrive il piano: due partite consecutive
	#
	# La stessa domanda nella forma che il piano usa, e con lo stesso metodo: la
	# partita dopo `restart_run()` non puo' essere la partita di prima.
	var terza_partita := _restart_e_disposizione(h, horde, "C", vivi)
	var d2 := _differing(seconda_partita, terza_partita)
	h.check(d2 >= minimo,
		"criterio n. 2 (1.14-ter): due partite consecutive dopo restart_run() hanno disposizioni diverse: %d posizioni diverse su %d, tetto ripreso da m3 il %.0f%% = %d"
			% [d2, mini(seconda_partita.size(), terza_partita.size()),
				REROLL_FRACTIONE * 100.0, minimo])

	# ## 4. Il controllo: il seme dichiarato riproduce ancora
	#
	# È la parte che dimostra che il reroll **non ha mangiato** la
	# riproducibilità, cioè che l'invariante dell'altra metà della specifica
	# (criterio n. 1, di `-arena`) è ancora raggiungibile: dopo due restart
	# casuali, tornare al seme dichiarato deve ridare la disposizione **di prima**,
	# posizione per posizione. Se il confronto di sopra potesse dire «diverse» senza
	# guardare, qui direbbe «diverse» anche per due copie dello stesso mondo — e
	# questa riga è quella che se lo accorgesse.
	horde.reseed(SEME_CAPACITY)
	h.eq(_differing(fissa, horde.transforms), 0,
		"m11-bis-b: dopo il reroll, tornare al seme %d deve ridare la disposizione di prima, identica: %d posizioni diverse su %d"
			% [SEME_CAPACITY, _differing(fissa, horde.transforms), fissa.size()])
	h.check(horde.colors == colori_fissi,
		"m11-bis-b: tornati al seme dichiarato anche i colori sono quelli di prima")
	h.eq(horde.seed, SEME_CAPACITY,
		"m11-bis-b: reseed(s) rimette il campo `seed` a s: il campo descrive sempre la disposizione in campo")

	# Una sezione che non stampa i propri numeri è una sezione di cui il lettore
	# deve fidarsi. Il costo è stampato con i numeri, perché qui il vincolo è il
	# timeout di 120 s e non la bellezza dell'asserzione.
	print("orda: m11-bis-b, %d vivi: due restart dallo stesso punto di partenza %d/%d diverse, due partite consecutive %d/%d diverse, tetto %d"
		% [vivi, d, mini(prima_partita.size(), seconda_partita.size()),
			d2, mini(seconda_partita.size(), terza_partita.size()), minimo])
	print("orda: m11-bis-b: controllo a seme %d dopo il reroll, %d/%d diverse (identiche: era %s)"
		% [SEME_CAPACITY, _differing(fissa, horde.transforms), fissa.size(),
			str(_differing(fissa, horde.transforms) == 0)])
	print("orda: m11-bis-b: sezione intera in %d us, %d ripopolamenti da %d nemici, nessun passo di simulazione"
		% [Time.get_ticks_usec() - t0, 6, vivi])

## Un `restart_run()` e la disposizione che ne esce, con le tre cose che il
## reroll deve aver fatto e che tornano a ogni restart.
func _restart_e_disposizione(h, horde: HORDE, nome: String, vivi: int) -> PackedVector3Array:
	horde.restart_run()
	# Il campo `seed` deve **descrivere** la disposizione in campo: dopo un
	# reroll è `0`, cioè «casuale». Se restasse il seme della scena il campo
	# direbbe «questa disposizione si rifa da 4242» per una disposizione che
	# 4242 non produce.
	h.eq(horde.seed, 0,
		"m11-bis-b (%s): dopo il restart `seed` vale 0, il suo significato dichiarato di 'casuale'" % nome)
	h.eq(horde.count, horde.population,
		"m11-bis-b (%s): il reroll non ha cambiato il numero di vivi (%d su %d, attesi %d)"
			% [nome, horde.count, horde.population, vivi])
	h.eq(horde.transforms.size(), horde.count,
		"m11-bis-b (%s): transforms allineata a count dopo il reroll" % nome)
	h.eq(horde.radii.size(), horde.count,
		"m11-bis-b (%s): anche radii allineata a count dopo il reroll" % nome)
	return horde.transforms.duplicate()

## Quante posizioni devono moversi fra due disposizioni, su `live` nemici vivi.
## Stessa forma e stessa derivazione di `_diff_min` in `tests/test_arena.gd`
## (criterio n. 2 di m3): la frazione arrotondata per eccesso, e `maxi(1, ...)`
## perché un tetto di zero posizioni non può mai fallire.
func _tetto_diverse(live: int) -> int:
	return maxi(1, int(ceil(REROLL_FRACTIONE * float(live))))

## Quante posizioni di due disposizioni sono diverse.
##
## **Il metodo è quello di m3**, non uno inventato qui: elemento per elemento,
## `!=` su `Vector3`, **toleranza zero**. Una tolleranza lascerebbe passare un
## reroll che sposta ogni nemico di mezzo centimetro, e il criterio vuole sapere
## se i nemici si sono spostati, non se sono «quasi gli stessi».
func _differing(a: PackedVector3Array, b: PackedVector3Array) -> int:
	var n := mini(a.size(), b.size())
	var d := 0
	for i in n:
		if a[i] != b[i]:
			d += 1
	return d

# --- 15. m11-ter: `population_scale`, la cucitura di misura dell'apertura --------
#
# ## Che cosa e' e da dove viene
#
# La sonda `docs/piramide/probe_survive.gd` ha misurato che al raggio consegnato
# di 60,0 m **tutte le morti cadono sull'onda 1 con 25 nemici vivi**, mai sulla 2
# (piano §1.14-seque). Quindi la leva non e' il fondo: e' **l'apertura**. Per
# misurare quanto deve essere morbida serve poter variare la popolazione
# dell'onda 1 **a runtime**, e prima di m11-ter non si poteva: `Run.POP_BASE`
# e' una `const`.
#
# Questa sezione non cambia il gioco. Cambia **quello che e' verificabile** di una
# riga che il vertice usera' per misurare, e la divide in tre domande che sono
# tre difetti diversi:
#
#   1. **il default e' 1.0** e nessuna riga di gioco lo cambia — criterio
#      **statico**: il nome compare in due punti di codice in tutto `src/`, e in
#      nessuna scena;
#   2. **a 1.0 le popolazioni sono quelle di prima**, onda per onda — e' la prova
#      che la riga e' un no-op sul comportamento, cioe' che i quattro numeri delle
#      milestone non si sono spostati di una unita';
#   3. **a 0.5 le dimezza davvero**, e non solo «la variabile esiste».
#
# ## Perche' il punto 3 e' quello che regge gli altri due
#
# «La variabile esiste» e' un fatto, e un fatto non si puo' usare per misurare.
# Se il `* population_scale` sparisse dalla riga di `_sync_population()`, o se
# qualcuno lo rendesse no-op con una soglia (`if population_scale > 1.0`), i
# punti 1 e 2 continuerebbero a essere veri: il default ci sarebbe e a 1.0
# mancherebbe niente. Solo la domanda a 0.5 distingue «c'e' una leva» da «c'e' un
# campo». E' il dente, ed e' per questo che sta per ultima e non come una nota.
#
# ## Il percorso e' quello di gioco, non una chiamata privata
#
# Le popolazioni sotto non sono scritte a mano e `_sync_population()` non viene
# chiamata da qui dentro: l'onda 1 si ottiene da `restart_run()` e le successive
# chiudendo l'onda con `step()`, cioe' passando dagli stessi tre punti in cui il
# gioco chiama `_sync_population()`. Se la sezione chiamasse il metodo privato
# accetterebbe anche un'orda in cui quel ramo e' morto: e' la classe di difetto
# di §1.6, una macchina verificata che il gioco non chiama.
#
# ## Perche' anche le scene
#
# Un `population_scale = 1.0` scritto su `scenes/arena_main.tscn` non e' codice e
# nessuna `grep` sui `.gd` lo vede, ma e' una **seconda copia del default**: e due
# copie di un numero in due file divergono senza che nessuno se ne accorga, che
# e' la ragione per cui `Run.POP_MAX` e' dichiarato due volte e controllato due
# volte. Quindi anche `res://scenes` e' guardata, e la riga che lo afferma dice
# cosa fare se un giorno dovesse diventare rossa: si toglie la proprieta' dalla
# scena, non si allarga il criterio.

## Il default dichiarato in `src/sim/horde.gd`. Non e' una copia: e' il numero
## che il campo deve avere **dopo** che il percorso di gioco ci ha passato
## sopra, e il criterio 1 lo confronta con quello che il file dichiara.
const SCALA_DEFAULT := 1.0
## La scala con cui si misura che la leva **morde**. Meta': il numero che
## distingue «la variabile esiste» da «la variabile fa qualcosa», e non un
## valore che servirebbe al gioco (il gioco non la tocca, e li' e' dichiarato).
const SCALA_PROVA := 0.5
## Quante onde si percorrono per scala. `Run.POP_SATURATION` = 8, quindi 10
## copre tutta la crescita **e** la coda piatta oltre il tetto: una scala che
## funzionasse solo sull'onda 1 sarebbe una scala che la sonda puo' usare solo
## per la prima Seconds, che e' proprio il difetto che la riga deve chiudere.
const SCALA_ONDE := 10

## Le tre asserzioni statiche sul nome: un file solo in `src/`, un file solo che
## lo nomina in codice, nessuna scena che lo scriva.
func _scala_nei_file(h) -> void:
	var citano := PackedStringArray()
	for path in _file_gdc_in("res://src"):
		if _contiene(path, "population_scale"):
			citano.append(path)
	citano.sort()
	h.check(citano.size() == 1 and citano[0] == "res://src/sim/horde.gd",
		("m11-ter: in src/ il nome population_scale compare solo in "
			+ "src/sim/horde.gd, perche' il gioco non la tocca. Trovato in: "
			+ str(citano))
			+ ". Se una foglia di gioco lo usa, la cucitura ha smesso di essere una "
			+ "cucitura e va tolta da li', non allargato questo criterio.")

	# I **due** punti sono la dichiarazione e `_sync_population()`. Un terzo punto
	# in codice significa che qualcuno scrive il campo da un'altra parte
	# (`_build()`, `restart_run()`, un `step()`): il difetto che la sezione 14 ha
	# appena chiuso sul seme, ripetuto sul numero.
	h.eq(_occorrenze_di_codice("res://src/sim/horde.gd", "population_scale"), 2,
		"m11-ter: in src/sim/horde.gd il nome compare in DUE punti di codice, la "
			+ "dichiarazione e _sync_population(). Tre o piu' significa che qualcuno "
			+ "la scrive altrove (per esempio in restart_run) e il default non e' piu' "
			+ "l'unico posto in cui il valore si decide.")

	# ## Le scene, e la guardia che rende questa riga non decorativa
	#
	# Se `res://scenes` non si aprisse, `scene` sarebbe vuoto e `scene.size() == 0`
	# passerebbe **senza aver guardato niente**: un criterio che passa qualunque
	# cosa non vale niente. Percio' prima si conta quante scene ci sono state
	# guardata, e si asserisce che siano piu' di zero: il vuoto che viene dopo e'
	# allora un numero, non una mancata apertura.
	var scene_trovate := _file_con_estensione("res://scenes", ".tscn")
	h.check(scene_trovate.size() > 0,
		"m11-ter: la scansione delle scene ha guardato almeno una .tscn, altrimenti "
			+ "il criterio 'nessuna scena scrive population_scale' passerebbe senza "
			+ "aver aperto niente")
	var scene := PackedStringArray()
	for path in scene_trovate:
		if _contiene(path, "population_scale"):
			scene.append(path)
	scene.sort()
	h.eq(scene.size(), 0,
		("m11-ter: nessuna delle %d scene scrive population_scale, perche' il default "
			% scene_trovate.size())
			+ "vive in un posto solo (src/sim/horde.gd). Trovato in: " + str(scene)
			+ ". Se una scena dovesse impostarlo, si toglie la proprieta' dalla scena: "
			+ "due copie di un default divergono senza che nessuno se ne accorga.")

## Il numero di default, letto dal **file**, non da una copia scritta qui.
## E' quello che rende la riga di sopra un confronto e non un tautologia: se il
## campo cambiasse default e questa costante no, le due cose non starebbero piu'
## nella stessa frase.
func _scala_default_dichiarata() -> float:
	var f := FileAccess.open("res://src/sim/horde.gd", FileAccess.READ)
	if f == null:
		return -1.0
	for riga in f.get_as_text().split("\n"):
		if riga.begins_with("var population_scale"):
			return float(riga.split("=")[-1].strip_edges())
	return -1.0

## La sezione: il default, il no-op a 1.0, il dente a 0.5.
func _scala_popolazione(h, horde: HORDE) -> void:
	var t0 := Time.get_ticks_usec()
	var respawn_prima := horde.auto_respawn
	# La sezione non vuole misurare la rampa degli 8/s: `restart_run()` riempie
	# gia' a `population`, quindi il numero che si confronta e' la curva e non il
	# ritmo di spawn. Il flag torna com'e' alla fine, perche' le sezioni dopo
	# devono trovare l'orda com'era.
	horde.auto_respawn = false

	# 1. il default, com'e' lo ha lasciato costruire `_build()`
	#
	# Questa e' l'asserzione che rende la prima meta' del criterio 1 non
	# dichiarativa: il campo non e' 1.0 perche' il test l'ha messo a 1.0, e'
	# 1.0 perche' nessuno l'ha toccato. E il confronto e' con il valore **letto
	# dal sorgente**, non con una copia scritta qui accanto.
	h.eq(horde.population_scale, SCALA_DEFAULT,
		"m11-ter: l'orda appena costruita ha la cucitura al suo default")
	h.eq(_scala_default_dichiarata(), SCALA_DEFAULT,
		"m11-ter: il default dichiarato in src/sim/horde.gd e' quello che il test "
			+ "usa come riferimento, quindi qui non c'e' una seconda copia del numero")

	# 2. `restart_run()` non la tocca
	#
	# Il percorso che il vertice esercita a ogni tentativo di sonda e' proprio
	# questo: se un restart riallineasse la scala, la sonda misurerebbe una
	# partita che non e' quella che sta descrivendo, e il difetto sarebbe
	# invisibile perche' i numeri restano plausibili.
	horde.restart_run()
	h.eq(horde.population_scale, SCALA_DEFAULT,
		"m11-ter: restart_run() non tocca la cucitura")
	h.eq(horde.population, RUN.population_of(1),
		"m11-ter: e la popolazione resta quella della curva")
	h.eq(horde.count, horde.population,
		"m11-ter: il campo e' a quel numero")

	# 3. a 1.0 non cambia niente, onda per onda
	#
	# E' la risposta nota della sezione, nella forma della 13e-bis: le stesse
	# popolazioni di `Run.population_of`, lette dall'orda, sugli stessi numeri che
	# la funzione da', senza scrivere niente a mano.
	var intera := _popolazioni_scala(horde, SCALA_DEFAULT)
	var dimezzata := _popolazioni_scala(horde, SCALA_PROVA)
	# `range(1, N + 1)` e non `for w in N`: `for w in N` va da 0 a N-1, e
	# `Run.population_of(0)` vale `population_of(1)` per il `maxi` — quindi il
	# confronto partirebbe dall'onda 1 due volte e finirebbe all'onda 9, senza
	# accorgersene. Qui l'indice delle due sequenze e' `w - 1`, e deve.
	for w in range(1, SCALA_ONDE + 1):
		var atteso := RUN.population_of(w)
		h.eq(intera[w - 1], atteso,
			"m11-ter: a scala %.2f l'onda %d ha la popolazione della curva"
				% [SCALA_DEFAULT, w])
		h.eq(dimezzata[w - 1], roundi(float(atteso) * SCALA_PROVA),
			"m11-ter: a scala %.2f l'onda %d ha la curva moltiplicata"
				% [SCALA_PROVA, w])
		# Il numero deve essere **minore**, non diverso: una scala che sposta il
		# numero senza abbassarlo non e' una leva sull'apertura.
		h.check(dimezzata[w - 1] < atteso,
			"m11-ter: a scala %.2f l'onda %d ha meno nemici della curva (%d su %d)"
				% [SCALA_PROVA, w, dimezzata[w - 1], atteso])

	## 4. il dente: a 0.5 l'apertura e' davvero piu' sottile **in campo**
	##
	## Fin qui il confronto e' su `population`, un campo. La riga che conta e'
	## l'altra: quanti **corpi** ci sono quando l'onda parte. `restart_run()`
	## riempie a `population` senza passare dalla rampa, quindi il numero e'
	## leggibile subito, e a 0.5 deve essere metà della curva sull'onda 1.
	horde.population_scale = SCALA_PROVA
	horde.restart_run()
	h.eq(horde.count, roundi(float(RUN.population_of(1)) * SCALA_PROVA),
		"m11-ter: a scala %.2f il campo parte con la meta' dei nemici della curva"
			% SCALA_PROVA)
	h.check(horde.count < RUN.POP_BASE,
		"m11-ter: a scala %.2f l'apertura e' piu' sottile di quella di oggi (%d su %d)"
			% [SCALA_PROVA, horde.count, RUN.POP_BASE])
	h.eq(horde.transforms.size(), horde.count,
		"m11-ter: a scala %.2f gli array restano allineati a count" % SCALA_PROVA)

	## 5. rimessa a posto, e dichiarato
	horde.population_scale = SCALA_DEFAULT
	horde.restart_run()
	horde.auto_respawn = respawn_prima
	h.eq(horde.population_scale, SCALA_DEFAULT,
		"m11-ter: la sezione rimette la cucitura al default prima di restituire l'orda")
	h.eq(horde.population, RUN.population_of(1),
		"m11-ter: e l'orda torna alla popolazione della curva")
	h.eq(horde.count, horde.population,
		"m11-ter: e il campo torna a quel numero")

	# Una sezione che non stampa i propri numeri e' una sezione di cui il lettore
	# deve fidarsi. Il costo e' stampato con i numeri perche' qui il vincolo e' il
	# tetto di 120 s di `tools/gate.gd` e non la bellezza dell'asserzione.
	print("orda: m11-ter, scala %.2f -- onde 1..%d: %s | Run.population_of: %s | scala %.2f: %s"
		% [SCALA_DEFAULT, SCALA_ONDE, _sequenza(intera), _sequenza_curve(),
			SCALA_PROVA, _sequenza(dimezzata)])
	print("orda: m11-ter: onda 1 in campo %d nemici a scala 1.0 e %d a scala %.2f "
		% [RUN.population_of(1), roundi(float(RUN.population_of(1)) * SCALA_PROVA),
			SCALA_PROVA]
		+ "(Run.POP_BASE = %d, MAX_ENEMIES = %d)" % [RUN.POP_BASE, HORDE.MAX_ENEMIES])
	print("orda: m11-ter: sezione intera in %d us (5 restart_run() e %d step(), zero "
		% [Time.get_ticks_usec() - t0, 2 * (SCALA_ONDE - 1)]
		+ "allocazioni nel ciclo di gioco)")

## Le popolazioni che l'orda si assegna sulle prime `SCALA_ONDE` onde, con la
## scala `scala` sopra.
##
## L'onda 1 arriva da `restart_run()` e le successive da `step()` con l'onda
## chiusa: sono i tre punti in cui `_sync_population()` e' chiamata dal gioco, e
## non una chiamata a `_sync_population()` scritta qui dentro. Con
## `auto_respawn = false` un passo e' solo il passo: nessuna rampa, nessun costo
## che non sia il confronto.
func _popolazioni_scala(horde: HORDE, scala: float) -> PackedInt32Array:
	var fuori := PackedInt32Array()
	horde.population_scale = scala
	horde.restart_run()
	fuori.append(horde.population)
	for _i in (SCALA_ONDE - 1):
		# Chiudere l'onda e' quello che fa il gioco quando la barra arriva a
		# zero: `wave_cleared()` e' vero e `step()` passa all'onda dopo.
		horde.run.wave_killed = horde.run.wave_total
		horde.step(DT)
		fuori.append(horde.population)
	return fuori

## La stessa sequenza, calcolata dalla funzione dichiarata in `src/sim/run.gd`
## invece che dall'orda. Serve solo da stampata: il confronto vero e' quello
## fatto sopra, onda per onda.
func _sequenza_curve() -> String:
	var fuori := PackedInt32Array()
	for w in range(1, SCALA_ONDE + 1):
		fuori.append(RUN.population_of(w))
	return _sequenza(fuori)

## I numeri di una sequenza in interi, separati da `/`, per una riga di stampa.
func _sequenza(a: PackedInt32Array) -> String:
	var parti := PackedStringArray()
	for v in a:
		parti.append(str(v))
	return "/".join(parti)

# --- 16. m11-quarta: il morso e la taglia disegnata ----------------------------
#
# ## Il difetto segnalato dall'utente, in una riga
#
# Il corpo che si vede e' `SIZE_FACTOR * RADIUS[kind]` e la portata del morso
# era `RADIUS[kind] + TOUCH_REACH`, quindi la banda di sovrapposizione **a vuoto**
# era `(SIZE_FACTOR - 1) * RADIUS[kind]`: 1,08 m sul runner, 1,44 sul grunt, 2,40
# sul brute e **4,56 m sul boss** — e cresceva con la specie, che e' l'opposto di
# quello che serve. Il boss ti sta dentro e non morde.
#
# ## La regola, che e' del contratto e non di questa sezione
#
# Punto 1b di `src/core/contracts.gd`, emendato il 2026-10-14: il morso non puo'
# cadere **piu' tardi** del contatto visibile, cioe'
#
#     morse_entro(k) >= taglia_disegnata(k) + taglia_disegnata_giocatore
#
# e la banda deve essere **zero per ogni specie**: non «non negativa», zero. Non
# e' una soglia da tarare, e' un'identita' che si ottiene derivando la portata
# del morso dalla taglia disegnata.
#
# ## Perche' il coefficiente non e' libero
#
# `corpo_giocatore` **e' gia'** `TOUCH_REACH = 0.45`, perche' il criterio n. 2 di
# m8 asserisce che la taglia misurata sulla scena vera e' **uguale** a
# `TOUCH_REACH` (lo asserisce la sezione 12, e quella asserzione non si tocca).
# Quindi basta `morse_entro(k) = SIZE_FACTOR * RADIUS[k] + TOUCH_REACH` e la banda
# va a zero **per costruzione**. Nessun fattore «in attesa di misura»: metterne uno
# sarebbe mettere un numero a caso.
#
# ## I tre denti, e cosa ognuno esclude
#
#   1. **il comportamento**: un nemico che si vede addosso al giocatore **morde**.
#      Non e' la formula riscritta: e' `src/sim/enemy.gd` che decide, in un passo,
#      su 200 nemici veri. Se questa riga va verde per un difetto di questo file,
#      il numero che si legge non descrive piu' il gioco e va riletto sul sorgente;
#   2. **la banda e' zero**, non «positiva»: l'identita' e' quella e il criterio
#      del contratto parla di zero;
#   3. **`RADIUS x 7` non cambia il verdetto**: se il rimedio fosse stato
#      «ingrandire `RADIUS` finche' la banda torna vicina a zero», questo dente va
#      rosso. Esclude **per iscritto** la strada dell'ingrandimento.
#
# ## Il canale, e perche' qui non c'e' un `3.4`
#
# `SIZE_FACTOR` e' di `-arena` (`src/render/horde_renderer.gd`) e arriva nel
# contratto come `Game.enemy_body_scale`. `-orda` **lo legge**: copiarlo sarebbe
# una copia che mente, che e' il difetto delle sei copie di m9 e la ragione per
# cui il vertice ha aperto il canale.

## Il fattore di calibrazione del corpo **dal contratto**, non da una copia.
func _scala_corpo() -> float:
	var game := _game()
	if game == null:
		return -1.0
	var v = game.get("enemy_body_scale")
	if v == null:
		return -1.0
	return float(v)

## Il default che il contratto dichiara, letto **dal sorgente**: serve a dire se
## il valore in campo e' quello che `-arena` ha registrato o e' ancora il default
## dichiarato. Un test che non lo distingue chiama «canale» un numero che nessuno
## ha mai scritto.
func _scala_corpo_dichiarata() -> float:
	var f := FileAccess.open("res://src/core/contracts.gd", FileAccess.READ)
	if f == null:
		return -1.0
	for riga in f.get_as_text().split("\n"):
		var t := str(riga).strip_edges()
		if t.begins_with("var enemy_body_scale"):
			return float(t.split("=")[1].strip_edges())
	return -1.0

## Il fattore di calibrazione del corpo, avvelenato sul contratto e poi ripreso.
##
## Il numero dichiarato in `src/core/contracts.gd` e `SIZE_FACTOR` di `-arena` sono
## **lo stesso valore**, quindi «il contratto dice 3,4» non distingue «-arena ha
## scritto 3,4» da «3,4 e' il default e nessuno ha scritto niente»: era la frase
## che questo file stampava fino al 2026-10-15, ed e' un numero che il prossimo
## avrebbe letto come se fosse vivo. Il canale si dimostra **movendo il numero**:
## prima si avvelena il contratto, poi si monta un'altra orda e si guarda che cosa
## legge, e alla fine si rimette tutto indietro con due asserzioni.
const SCALA_AVVELENATA := 99.0

## Monta un'orda di prova, legge il fattore che ha preso, e la rimette giu'.
func _sonda_corpo(h, nome: String) -> float:
	var sonda := HORDE.new()
	sonda.name = nome
	# `seed = 0` fa `_reroll()`: la sonda non deve sporcare il flusso di numeri
	# casuali di nessuno, quindi ha un seme suo e dichiarato.
	sonda.seed = 4242
	root.add_child(sonda)
	var letta := sonda.body_scale
	h.eq(sonda.body_scale_source, "contratto",
		"%s dichiara body_scale_source 'contratto': un fallback qui sarebbe silenzioso" % nome)
	root.remove_child(sonda)
	sonda.queue_free()
	return letta

## Il fattore **arriva** dal contratto. Ritorna il numero che l'orda sonda ha
## letto con `SCALA_AVVELENATA` in campo, cosi' la stampa sotto lo riporta invece
## di dedurlo da una uguaglianza che non distingue niente.
func _scala_corpo_avvelenata(h, horde: HORDE) -> float:
	var game := _game()
	if game == null:
		h.fail("il contratto non c'e': la prova che il fattore arriva non puo' girare")
		return -1.0
	var prima := float(game.get("enemy_body_scale"))
	game.set("enemy_body_scale", SCALA_AVVELENATA)
	h.eq(float(game.get("enemy_body_scale")), SCALA_AVVELENATA,
		"avvelenamento: sul contratto c'e' il numero di prova, %.1f" % SCALA_AVVELENATA)
	var avvelenata := _sonda_corpo(h, "OrdaSonda")
	h.eq(avvelenata, SCALA_AVVELENATA,
		"una orda montata col contratto avvelenato legge %.1f: il fattore **arriva** "
			% SCALA_AVVELENATA
			+ "da SIZE_FACTOR e non e' una copia del %.4f dichiarato" % prima)
	game.set("enemy_body_scale", prima)
	# Ripristino, due asserzioni e sono due fatti: il numero e' tornato indietro, e
	# il canale **rifunziona** dopo che e' stato avvelenato (una terza orda montata
	# adesso deve rivedere il numero vero, altrimenti «ripristinato» e' una parola).
	h.eq(float(game.get("enemy_body_scale")), prima,
		"ripristino 1: il contratto torna al numero che aveva, %.4f" % prima)
	var dopo := _sonda_corpo(h, "OrdaSondaDopo")
	h.eq(dopo, prima,
		"ripristino 2: un'altra orda montata dopo il ripristino rivede %.4f" % prima)
	# La sonda ha registrato se' e tre API sul contratto: tornano all'orda del test,
	# altrimenti le sezioni dopo leggerebbero la sonda e non l'orda.
	_ripristina(h, horde)
	return avvelenata

func _banda_morso(h, horde: HORDE) -> void:
	var t0 := Time.get_ticks_usec()
	var scala := _scala_corpo()
	h.check(scala > 0.0,
		"il contratto dichiara Game.enemy_body_scale, il fattore con cui il renderer "
		+ "disegna il corpo del nemico")
	var dichiarata := _scala_corpo_dichiarata()
	# ## L'orda non ha una copia del fattore: lo legge
	#
	# Due righe, e sono il canale. Se `horde.body_scale` fosse un numero suo, il
	# test passerebbe anche quando il renderer ha cambiato fattore: la banda
	# sarebbe zero **fra due numeri sbagliati**.
	h.eq(horde.body_scale, scala,
		"l'orda prende il fattore del corpo dal contratto, non da una copia sua")
	h.eq(horde.body_scale_source, "contratto",
		"e lo dichiara: senza questa riga un fallback silenzioso passerebbe")
	# ## E il numero arriva davvero, non per uguaglianza
	#
	# `scala` e `dichiarata` sono lo stesso valore, quindi le tre righe qui sopra
	# passerebbero anche se il contratto non fosse mai stato scritto da `-arena`.
	# L'avvelenamento e' la prova che distingue i due casi, e sta subito qui sotto.
	var avvelenata := _scala_corpo_avvelenata(h, horde)
	h.eq(horde.bite_range_of(ENEMY.BOSS), ENEMY.bite_range_of(ENEMY.BOSS, horde.body_scale),
		"la portata che l'orda espone e' quella che calcola la simulazione")
	# ## E il numero non e' scritto a mano da questa parte
	#
	# Un `3.4` in `src/sim/` sarebbe una copia che mente; un `SIZE_FACTOR` in
	# `src/sim/` sarebbe il nome di un'altra foglia. Le due `grep` sono la difesa
	# di m9 (criterio n. 2) applicata a questo canale, e guardano **solo il
	# codice**: i commenti parlano di `SIZE_FACTOR` e devono poterlo fare, altrimenti
	# la documentazione che spiega il canale farebbe fallire il canale.
	if dichiarata >= 1.0:
		for path in ["res://src/sim/enemy.gd", "res://src/sim/horde.gd"]:
			h.eq(_occorrenze_di_codice(path, "SIZE_FACTOR"), 0,
				"il nome SIZE_FACTOR e' di -arena e non compare in codice in %s" % path)
			h.eq(_occorrenze_di_codice(path, str(dichiarata)), 0,
				"il numero %s del fattore non e' scritto a mano in %s"
					% [str(dichiarata), path])
	else:
		h.fail("il contratto non dichiara un fattore corpo >= 1: la difesa "
			+ "contro la copia scritta a mano non puo' girare")
	# ## Il corpo del giocatore: `TOUCH_REACH`, e perche' non un altro numero
	#
	# Il criterio n. 2 di m8 asserisce che il raggio **misurato** sulla scena vera
	# del giocatore e' uguale a `TOUCH_REACH`, e quella asserzione e' nella sezione
	# 12: qui dentro quindi non si rimisura un numero che gia' e' legato. Se un
	# giorno il modello del giocatore cambia, e' quella riga che va rossa per
	# prima, e questa ne segue il valore.
	var corpo := ENEMY.TOUCH_REACH

	var righe := ""
	for k in ENEMY.KIND_COUNT:
		var disegnato := scala * ENEMY.RADIUS[k]
		var morse_entro := horde.bite_range_of(k)
		# Il contatto **visibile**: il bordo del nemico che tocca il bordo del
		# giocatore. E' il numero che l'occhio chiama "dentro".
		var visibile := disegnato + corpo
		# La banda di sovrapposizione **a vuoto**: quanti metri il nemico puo'
		# stare dentro il giocatore senza mordere. Positiva = difetto.
		var banda := visibile - morse_entro
		righe += " %s=%.2f/%.2f" % [ENEMY.KIND_NAMES[k], morse_entro, banda]
		# Dente 1: il **comportamento**, non la formula. Un nemico di questa
		# specie a 1 mm dal contatto visibile si vede addosso al giocatore: se non
		# morde, il nemico e' dentro di te e non fa niente, che e' esattamente la
		# segnalazione dell'utente. Se un giorno questa riga va verde perche' il
		# file non guarda piu' qui, il numero stampato sotto non descrive piu' il
		# gioco e va riletto sul sorgente di `src/sim/enemy.gd`.
		h.check(_morde_a_distanza(h, horde, k, visibile - 0.001),
			"il %s si vede addosso al giocatore a %.2f m e deve mordere: banda di "
				% [ENEMY.KIND_NAMES[k], visibile - 0.001]
				+ "sovrapposizione a vuoto %.2f m, quindi finche' e' positiva il nemico "
				% banda
				+ "sta dentro e non morde")
		# e NON morde quando e' fuori dal contatto visibile: altrimenti la riga di
		# sopra passerebbe con una portata a chilometri.
		h.check(not _morde_a_distanza(h, horde, k, visibile + 0.5),
			"il %s NON morde a %.2f m, che e' %.2f m oltre il contatto visibile"
				% [ENEMY.KIND_NAMES[k], visibile + 0.5, visibile + 0.5 - morse_entro])
		# Dente 2: la banda e' **zero** per questa specie, non «non negativa».
		h.near(banda, 0.0, 0.000001,
			"criterio 1b: la banda del %s e' zero, non negativa: morse %.4f m contro disegnato %.4f + corpo %.4f"
				% [ENEMY.KIND_NAMES[k], morse_entro, disegnato, corpo])
		# Dente 3: `RADIUS x 7` non cambia il verdetto. Se il rimedio fosse stato
		# «ingrandire RADIUS finche' la banda torna piccola», questa riga andava
		# rossa: e' la strada che il criterio esclude per iscritto.
		var ragione7 := ENEMY.RADIUS[k] * 7.0
		var banda7 := (scala * ragione7 + corpo) - ENEMY.bite_range_for(ragione7, horde.body_scale)
		h.near(banda7, 0.0, 0.000001,
			"criterio 1b: con RADIUS x 7 (%.2f m invece di %.2f) la banda e' ancora zero: il rimedio non e' stato 'ingrandire RADIUS'"
				% [ragione7, ENEMY.RADIUS[k]])

	print("orda: m11-quarta, fattore corpo %.4f (default dichiarato sul contratto %.4f, "
			% [scala, dichiarata]
		+ "e NON e' una copia: il test avvelena il contratto a %.1f e l'orda montata "
			% SCALA_AVVELENATA
		+ "in quel momento legge %.1f, poi il contratto torna a %.4f e un'altra orda "
			% [avvelenata, scala]
		+ "lo rivede: il canale da SIZE_FACTOR funziona nei due sensi)")
	print("orda: m11-quarta, morsi entro / banda per specie (scala %.2f):%s"
		% [scala, righe])
	print("orda: m11-quarta: sezione intera in %d us, 8 passi di un passo, "
		% (Time.get_ticks_usec() - t0)
		+ "%d specie x 2 distanze" % ENEMY.KIND_COUNT)

	# ## L'orda torna com'era, e non e' una cortesia
	#
	# La sezione ha ridotto il campo a un nemico per specie e ha scritto dentro
	# `kinds`/`radii`. Senza questo `restart_run()` la sezione 14 ripopolerebbe a
	# `population = 1` e confronterebbe una disposizione di un nemico con un'altra di
	# un nemico: passerebbe, e misurerebbe niente. Quindi si rimette a posto
	# esattamente dai tre punti del gioco, come vuole la sezione 15.
	horde.population = RUN.population_of(1)
	horde.restart_run()
	h.eq(horde.count, RUN.population_of(1),
		"m11-quarta: la sezione rimette l'orda alla popolazione della curva")
	h.eq(horde.transforms.size(), horde.count,
		"m11-quarta: e gli array restano allineati a count")
	# La sezione ha scritto dentro `kinds` e `radii` per costruire il nemico di
	# prova, quindi dopo il ripristino ogni raggio deve tornare a essere quello
	# della sua specie: se il ripristino lasciasse un raggio fuori tabella, il
	# numero qui sotto sarebbe quello e non quello del gioco.
	var raggi_fuori_tabella := 0
	for i in horde.count:
		if absf(horde.radii[i] - ENEMY.RADIUS[horde.kinds[i]]) > 0.000001:
			raggi_fuori_tabella += 1
	h.eq(raggi_fuori_tabella, 0,
		"m11-quarta: dopo il ripristino ogni nemico ha il raggio della sua specie")

## Mette **un** nemico di specie `kind` alla distanza `distanza` dal giocatore
## finto e dice se in **un passo** morde.
##
## Un passo solo, e la ragione e' dichiarata: la condizione del morso in
## `src/sim/enemy.gd` guarda la posizione di **inizio** del passo, quindi la
## risposta e' esatta e non una media di trenta secondi. E il timer del morso e'
## un array parallelo **pubblico**, quindi si carica a mano: la domanda e' «morde
## qui», non «ha avuto tempo di caricare».
##
## ## Perche' la risposta si legge su `touch_bites_last` e non su `bites[0]`
##
## `bites[i]` e' la **decisione** del passo e `touch_bites_last` e' la
## **consegna**: `_apply_bites` la azzera subito e rispetta il tetto a intervallo
## `TOUCH_INTERVAL`, quindi con il tetto scarico `bites[0]` vale 0 **anche quando
## il nemico ha morso**. Leggendo il numero sbagliato questa funzione avrebbe
## detto «non morde» a tutte e quattro le specie e il dente sarebbe passato (o
## fallito) per il motivo sbagliato.
##
## ## E perche' il nemico viene prima mandato lontano
##
## Perche' il tetto a intervello si scarichi. Senza quei passi la risposta sarebbe
## «no» perche' un morso di troppo fa meno di 0.40 s, non perche' la distanza e'
## quella giusta: un test che misura il tetto quando vuole misurare la distanza
## e' un test che non misura niente.
func _morde_a_distanza(h, horde: HORDE, kind: int, distanza: float) -> bool:
	var respawn := horde.auto_respawn
	while horde.count > 0:
		horde.damage_enemy(0, 9999.0, Vector3.ZERO)
	horde.population = 1
	horde.auto_respawn = true
	var passi := 0
	while horde.count < 1 and passi < 60:
		horde.step(DT)
		passi += 1
	if horde.count != 1:
		horde.auto_respawn = respawn
		return false
	horde.kinds[0] = kind
	horde.radii[0] = ENEMY.RADIUS[kind]
	horde.hp[0] = ENEMY.hp_of(kind)
	# Lontano e fermo: nessun morso possibile, e il tetto a intervallo si
	# scarica. 40 m stanno dentro l'arena da 60 m anche spostandosi di qualche
	# metro verso il centro.
	horde.transforms[0] = FAKE_PLAYER + Vector3(40.0, 0.0, 0.0)
	horde.velocities[0] = Vector3.ZERO
	for _i in int(ceil(HORDE.TOUCH_INTERVAL / DT)) + 2:
		horde.transforms[0] = FAKE_PLAYER + Vector3(40.0, 0.0, 0.0)
		horde.step(DT)
	# Adesso la posizione e il timer del morso, e un passo solo.
	horde.velocities[0] = Vector3.ZERO
	horde.transforms[0] = FAKE_PLAYER + Vector3(distanza, 0.0, 0.0)
	horde.bite_timers[0] = ENEMY.touch_period_of(kind)
	horde.step(DT)
	var morso := horde.touch_bites_last == 1
	horde.auto_respawn = respawn
	return morso

# --- 17. I due cammini della miscela: popolazione iniziale e respawn -------------
#
# ## Il difetto, come stava, in due righe di `src/sim/horde.gd`
#
# | cammino | chi sceglie la specie | da dove prende i pesi |
# |---|---|---|
# | popolazione iniziale dell'onda | `_populate` -> `_pick_kind()` | `Spawner.wave_weights(run.wave)` |
# | **respawn durante l'onda** | `_spawn_one` -> `Spawner.pick_kind(_rng)` | `Spawner.KIND_WEIGHTS` piatto |
#
# La miscela che entrava nel campo a meta' partita era quindi mezza regola: la
# scala delle onde governava il primo nemico dell'onda e non gli altri.
#
# ## Perche' qui si misurano due onde, e non solo l'onda 1
#
# **Sull'onda 1 i due cammini erano gia' lo stesso numero.** `wave_weights(1)` e'
# `KIND_WEIGHTS` voce per voce (`[50, 30, 17, 3]`), perche' l'unico termine che
# dipende dall'onda e' `n = wave - 1` e a `wave = 1` vale zero: nessuna delle
# due funzioni puo' tirare fuori un numero diverso dall'altra.
#
# Quindi un criterio scritto **solo sull'onda 1 non puo' andare rosso** con il
# difetto ancora dentro: sarebbe verde per costruzione, cioe' nato verde, che e'
# la classe di difetto che questa sezione esiste per chiudere. Per questo l'onda 1
# si misura e si stampa (e' la misura richiesta, ed e' quella che dimostra che la
# correzione **non sposta niente li'**), e il criterio con i denti sta sull'onda
# `ONDA_MISELA = 8`, dove `wave_weights(8)` e' `[32.5, 30, 29.6, 17]` e la tabella
# piatta e' `[50, 30, 17, 3]`: due numeri diversi, e la frazione dei respawn
# descrive uno solo dei due.
#
# I denti sono provati, non dichiarati: con `_spawn_one` rimesso sulla chiamata
# diretta a `Spawner.pick_kind(_rng)` questa sezione va **rossa** sull'onda 8
# (le frazioni scendono a quelle piatte) e resta **verde** sull'onda 1, che e'
# esattamente la coppia di comportamenti che la distingue dal difetto.

## I semi della misura, dichiarati. Quattro, e nessuno e' "quello di prima".
const SEMI_MISELA := [4242, 7311, 20260912, 13579]

## Quanti campioni per cammino si chiedono, e **perche' questo numero e non un
## altro**.
##
## Il confronto e' fra **due campioni**, quindi la differenza fra le due frazioni
## ha deviazione `sqrt(p(1-p)/n + p(1-p)/n)`: con `n = 4800` e `p = 0.3` vale
## **0.011**, e la banda di `TOLERANZA_MISELA` (0.05) sta a **4.5 deviazioni**,
## dove il falso rosso e' ~1e-5 per specie. Con i 75 campioni di un giro solo la
## banda sarebbe a 0.6 deviazioni, cioe' il criterio andrebbe rosso **a caso** due
## volte su tre: e' la ragione per cui il campione e' dichiarato e non trovato.
const CAMPIONE_MISELA := 4800

## L'onda con i denti. Vedi la dichiarazione della sezione: alla 1 i due pesi sono
## lo stesso identico numero, quindi la' il criterio sarebbe nato verde.
const ONDA_MISELA := 8

## Il passo del riempimento. `Run.SPAWN_RATE` e' 8/s e con `DT = 1/60` un
## riempimento da 200 nemici ci mette **25 s**: qui si misura **quale specie
## sceglie lo spawn**, non quanto camminano i nemici, quindi il passo e' piu'
## grosso e la sezione costa secondi invece di minuti. Il codice di `_top_up` e' lo
## stesso in ogni caso: e' lo stesso credito, lo stesso `int()` e lo stesso tetto.
const DELTA_RIPRESO := 0.5

## La banda della frazione, **0.05 assoluta**, e la ragione e' il rumore del
## campione (vedi `CAMPIONE_MISELA`), non il difetto che si vuole vedere.
##
## Il difetto che deve restare fuori e' lontanissimo: sull'onda 8 le frazioni
## dichiarate sono `0.298 / 0.275 / 0.271 / 0.156` contro `0.50 / 0.30 / 0.17 /
## 0.03`. Tre specie su quattro sono fuori banda da sole (runner 0.202, brute
## 0.101, boss 0.126); **il grunt e' il caso debole** e va detto per iscritto: il
## suo scarto e' 0.025, dentro la banda, e da solo non farebbe fallire niente.
## Il criterio e' per specie e tutte e quattro devono stare dentro, quindi basta
## una delle tre forti.
const TOLERANZA_MISELA := 0.05

func _miscela_respawn(h, horde: HORDE) -> void:
	var t0 := Time.get_ticks_usec()
	var respawn_precedente := horde.auto_respawn
	horde.auto_respawn = true
	# L'onda 1 per la via dichiarata: dalla barra a zero di `run.gd`, non scritta a
	# mano. `_popolazioni_scala` (sezione 15) chiude l'onda allo stesso modo.
	horde.population = RUN.population_of(1)
	horde.restart_run()
	_porta_onda(h, horde, 1)

	# ## L'onda 1: la misura richiesta, e il fatto per cui resta verde comunque
	var uno := _due_cammini(h, horde, 1)
	var piatte := SPAWNER.KIND_WEIGHTS
	var dell_onda := SPAWNER.wave_weights(1)
	var stesse := true
	for k in ENEMY.KIND_COUNT:
		if absf(piatte[k] - dell_onda[k]) > 0.000001:
			stesse = false
	h.check(stesse,
		"sull'onda 1 wave_weights(1) e' KIND_WEIGHTS voce per voce (%s): i due cammini "
			% _pesi(dell_onda)
			+ "sono lo stesso numero, quindi qui il criterio non puo' distinguere nulla "
			+ "ed e' per questo che la misesta' e' sull'onda %d" % ONDA_MISELA)
	_confronta_cammini(h, 1, uno[0], uno[1])

	# ## L'onda `ONDA_MISELA`: il criterio che ha i denti
	_porta_onda(h, horde, ONDA_MISELA)
	var otto := _due_cammini(h, horde, ONDA_MISELA)
	_confronta_cammini(h, ONDA_MISELA, otto[0], otto[1])

	# ## L'orda torna com'era
	#
	# La sezione ha cambiato onda, riempimenti e semi: senza questa riga la
	# `_scena_vera` monterebbe la scena vera sopra un'orda a meta' riempimento
	# dell'onda 8, e un test che misura il mondo vero misurerebbe una distrazione
	# creata da questo file.
	horde.auto_respawn = respawn_precedente
	horde.population = RUN.population_of(1)
	horde.restart_run()
	h.eq(horde.wave, 1, "m11-ter/quinta: la sezione rimette l'orda all'onda 1")
	h.eq(horde.count, horde.population, "e alla popolazione della curva")
	print("orda: miscela, sezione intera in %d us, %d semi x 2 cammini x 2 onde, "
			% [Time.get_ticks_usec() - t0, SEMI_MISELA.size()]
		+ "banda %.2f, campione %d per cammino" % [TOLERANZA_MISELA, CAMPIONE_MISELA])

## Porta l'orda sull'onda `w` dalla strada vera del gioco: la barra a zero e
## `wave_cleared()`. Scrivere `run.wave` a mano sarebbe un'altra misura: qui i
## pesi li ricalcola `_wave_tick`, che e' il posto in cui il gioco li cambia.
func _porta_onda(h, horde: HORDE, w: int) -> void:
	var guardie := 0
	while horde.run.wave < w and guardie < 40:
		horde.run.wave_killed = horde.run.wave_total
		horde.step(DT)
		guardie += 1
	h.eq(horde.run.wave, w,
		"l'orda e' arrivata all'onda %d dalla strada del gioco (barra a zero)" % w)
	h.eq(horde.wave, w, "onda %d: il campo pubblico `wave` e' allineato a `run.wave`" % w)
	h.eq(horde.population, RUN.population_of(w),
		"onda %d: la popolazione e' quella dichiarata dalla curva" % w)

## I due cammini, con l'orda **gia'** sull'onda in cui si trova. Ritorna i due
## conteggi per specie: `[popolazione iniziale, respawn]`.
##
## Il numero di riempimenti non e' dichiarato a caso: viene da `CAMPIONE_MISELA`
## diviso per i semi e per la popolazione dell'onda, cosi' la banda di 0.05 resta
## a 4.5 deviazioni anche sull'onda 1, dove la popolazione e' 25 e un giro solo non
## direbbe niente.
func _due_cammini(h, horde: HORDE, w: int) -> Array:
	var iniziale := _zero_specie()
	var respawn := _zero_specie()
	var giri := maxi(1, int(ceil(float(CAMPIONE_MISELA)
		/ (float(SEMI_MISELA.size()) * float(horde.population)))))
	for s in SEMI_MISELA:
		var per_seme_iniziale := _zero_specie()
		var per_seme_respawn := _zero_specie()
		for g in giri:
			# ## Cammino A, la popolazione iniziale: `_populate` -> `_pick_kind()`
			#
			# `reseed` e' l'unica API pubblica che chiama `_populate` senza
			# cambiare la partita, e il seme e' `s + g * 7919` perche' ripetere lo
			# stesso seme darebbe lo stesso numero: un campione deve essere un
			# campione, non la stessa riga quattro volte.
			horde.reseed(int(s) + g * 7919)
			var a := _conta_specie(horde)
			for k in ENEMY.KIND_COUNT:
				iniziale[k] += a[k]
				per_seme_iniziale[k] += a[k]
		for g in giri:
			# ## Cammino B, i respawn: `_top_up` -> `_spawn_one`
			while horde.count > 0:
				horde.damage_enemy(0, 9999.0, Vector3.ZERO)
			# Uccidere tutta la popolazione porta la barra dell'onda a zero (ogni
			# morte chiama `run.register_kill()`), e senza questa riga l'onda
			# salirebbe **a meta' riempimento**: i due cammini misurerebbero due
			# onde diverse e il confronto non significherebbe niente. E' la stessa
			# mossa di `_misura_morso`, che blocca l'onda a 1 per lo stesso motivo.
			horde.run.wave_killed = 0
			var passi := 0
			while horde.count < horde.population and passi < 400:
				horde.step(DELTA_RIPRESO)
				passi += 1
			h.eq(horde.count, horde.population,
				"onda %d seme %d giro %d: il campo si e' riempito fino a `population` (%d in %d passi)"
					% [w, int(s), g, horde.count, passi])
			h.eq(horde.run.wave, w,
				"onda %d seme %d giro %d: l'onda non e' scivolata mentre si riempiva"
					% [w, int(s), g])
			var b := _conta_specie(horde)
			for k in ENEMY.KIND_COUNT:
				respawn[k] += b[k]
				per_seme_respawn[k] += b[k]
		print("orda: miscela onda %d seme %d (%d giri per cammino) -- iniziale:%s | respawn:%s"
			% [w, int(s), giri, _riga_specie(per_seme_iniziale), _riga_specie(per_seme_respawn)])
	return [iniziale, respawn]

## Il criterio: la frazione di specie dei **respawn** deve coincidere con quella
## della **popolazione iniziale della stessa onda**, entro `TOLERANZA_MISELA`.
## Per specie, e non in media: in media un peso sbagliato su una specie si
## nasconderebbe dietro le altre tre che tornano.
func _confronta_cammini(h, w: int, iniziale: PackedInt32Array, respawn: PackedInt32Array) -> void:
	var ni := 0
	for v in iniziale:
		ni += v
	var nr := 0
	for v in respawn:
		nr += v
	h.check(ni > 0 and nr > 0,
		"onda %d: i due campioni non sono vuoti (%d dalla popolazione iniziale, %d dai respawn)"
			% [w, ni, nr])
	for k in ENEMY.KIND_COUNT:
		var fi := float(iniziale[k]) / maxf(1.0, float(ni))
		var fr := float(respawn[k]) / maxf(1.0, float(nr))
		h.near(fr, fi, TOLERANZA_MISELA,
			"onda %d, %s: la frazione dei respawn (%.3f su %d respawn) deve coincidere con "
				% [w, ENEMY.KIND_NAMES[k], fr, nr]
				+ "quella della popolazione iniziale della stessa onda (%.3f su %d) entro %.2f: "
					% [fi, ni, TOLERANZA_MISELA]
				+ "i due cammini dello spawn pesano le stesse cose")
	print("orda: miscela onda %d, iniziale (n=%d):%s" % [w, ni, _riga_specie(iniziale)])
	print("orda: miscela onda %d, respawn   (n=%d):%s | pesi dell'onda:%s | pesi piatti:%s"
		% [w, nr, _riga_specie(respawn), _pesi(SPAWNER.wave_weights(w)),
			_pesi(SPAWNER.KIND_WEIGHTS)])

func _zero_specie() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(ENEMY.KIND_COUNT)
	return out

## Quante volte ogni specie nel campo **adesso**.
func _conta_specie(horde: HORDE) -> PackedInt32Array:
	var out := _zero_specie()
	for i in horde.count:
		if horde.kinds[i] >= 0 and horde.kinds[i] < ENEMY.KIND_COUNT:
			out[horde.kinds[i]] += 1
	return out

## `nome 3/25=0.120` per ogni specie, con il totale come denominatore dichiarato:
## una frazione senza il numero che le sta sotto non e' confrontabile con niente.
func _riga_specie(a: PackedInt32Array) -> String:
	var totale := 0
	for v in a:
		totale += v
	var testo := ""
	for k in ENEMY.KIND_COUNT:
		testo += " %s %d/%d=%.3f" % [ENEMY.KIND_NAMES[k], a[k], totale,
			float(a[k]) / maxf(1.0, float(totale))]
	return testo

## I pesi di una tabella, per la stampa: `runner 32.5 grunt 30.0 ...`.
func _pesi(w: PackedFloat32Array) -> String:
	var testo := ""
	for k in w.size():
		testo += " %s %.1f" % [ENEMY.KIND_NAMES[k], w[k]]
	return testo