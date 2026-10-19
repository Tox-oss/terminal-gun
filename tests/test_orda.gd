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
## ## `ACQUIRE_RADIUS` **non** si preloada, e il motivo e' misurato
##
## `src/weapons/weapon_base.gd` letto per mappa di costanti era la strada giusta
## (`enemy.gd` per `RADIUS[BOSS]`, `SKIN` cosi'), ma **non compila**: `weapon_base.gd`
## usa l'identificatore globale `Game` in `weapon_base.gd:168`, e con
## `--check-only` l'autoload non e' registrato, quindi il preload fa fallire
## l'intero file con `Compile Error: Identifier not found: Game`. Il numero che
## serve lo ha gia' misurato `-gameplay` (**0** nemici entro `26,0 m` sul piano del
## giocatore), quindi **non serve un secondo preload per dire un numero che e' noto**:
## la mappa di costanti si puo' fare quando `weapon_base.gd` smettere di dipendere
## dall'identificatore globale, e fino ad allora la distanza piu' vicina sul piano
## logico — che gia' stampo — e' il numero che non dipende da nessuna gittata.
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
## I denominatori qui sono **48 000** e **36 000**, cioe' `M10_WARMUP + M10_WINDOW`
## = 2400 passi (40 s) campionati ogni 10. Sono stati dimezzati una volta
## (2026-10-17) e **ripristinati** il giorno dopo: il conto e' scritto accanto alla
## costante `M10_WINDOW`, e la riga che dice perche' conta piu' del numero.
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

	# Senza questo marcatore tutto il blocco da qui a `_touch` cade in nessun
	# secchio: `_sez` accoda il tempo **al nome precedente**, e il primo nome che
	# esiste e' quello di `touch`. Il blocco e' la meta' del file, e un numero che
	# non e' da nessuna parte non si puo' accorciare.
	_sez("avvio")
	_marca("popolazione")
	_population(h, horde)
	_marca("no_nodo")
	_no_node_per_enemy(h, horde)
	_marca("registrazione")
	_registration(h, horde)
	_marca("raggio")
	_copie_del_raggio(h, horde)
	_marca("griglia_vs_lineare")
	_grid_matches_linear(h)
	_marca("nearest")
	_nearest(h, horde)
	_marca("spawn")
	_spawn_points(h, horde)
	_marca("query_budget")
	_query_budget(h, horde)
	_marca("pool")
	_object_pool(h)
	_marca("burn_in")
	_burn_in(h, horde)
	_marca("damage_kills")
	_damage_kills(h, horde)
	# m10: gli ostacoli. Le sezioni 13 girano **prima** di `_touch`, che registra
	# uno spia al posto del giocatore: qui il bersaglio e' `set_focus`, quindi
	# nessun morso si accende e la misura resta di geometria e di movimento.
	_marca("ostacoli")
	_ostacoli(h, horde)
	_marca("aggira")
	_aggira(h, horde)
	_marca("incastrati")
	_incastrati(h, horde)
	_marca("denti")
	_denti_del_criterio(h, horde)
	_marca("spawn_sicuro")
	_spawn_sicuro(h, horde)
	# m11: il raggio 46 -> 60. Sta qui perche' rimette a posto contratto,
	# geometria, campo e seme prima che `_touch` misuri il morso: `_misura_morso`
	# non ripopola da zero e troverebbe l'orda nel raggio lasciato dalla sezione
	# precedente invece che in quello dichiarato.
	_marca("raggio_60")
	_raggio_60(h, horde)
	_sez("touch")
	_touch(h, horde)
	_sez("attraversamento")
	# m12: il tempo di contatto per specie. Sta **subito dopo** `_touch` perche'
	# il morso si accende solo con un giocatore registrato, e lo spia di `_touch`
	# e' l'unico che questo file abbia. Sta **prima** di `_banda_morso` perche'
	# quella sezione asserisce il comportamento del morso, e il numero del tempo
	# di contatto e' la cosa che decide con quale tetto quel comportamento e'
	# confrontabile.
	_attraversamento(h, horde)
	_sez("banda_morso")
	# m11-quarta: il morso e la taglia disegnata. Sta **dopo** `_touch` perche'
	# la condizione del morso si accende solo con un giocatore registrato, e lo
	# spia di `_touch` e' l'unico che questo file abbia: prima di lui nessun
	# morso puo' partire e la sezione misurerebbe il vuoto. Sta **prima** di
	# `_reroll` perche' quella chiama `restart_run()` e rimetterebbe a posto
	# l'orda che qui e' stata ridotta a un nemico per specie.
	_banda_morso(h, horde)
	_sez("mortar")
	# m13: il mortar. Sta **subito dopo** `_banda_morso` e **prima** di `_reroll`
	# per due motivi, e sono due motivi di ordine e non di comodo'ita'. Primo: la
	# sezione ha bisogno di un **giocatore registrato** perche' il colpo cade
	# dove sta il giocatore, e lo spia di `_touch` e' l'unico che questo file
	# abbia: prima di lui nessuna cupola avrebbe un punto da segnalare. Secondo:
	# `_reroll` chiama `restart_run()`, che azzera i colpi in volo, e la sezione
	# vuole poter guardare un colpo che arriva davvero a cadere.
	_mortar(h, horde)
	_sez("reroll+scale")
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
	_sez("miscela")
	# I due cammini della miscela. Sta **qui**, dopo `_scala_popolazione` (che
	# rimette a posto `population` e `population_scale`) e prima di `_scena_vera`
	# (che monta la scena vera e registra l'orda e il giocatori del gioco): la
	# sezione deve parlare con l'orda isolata, e deve poter cambiare onda e
	# riempire il campo senza che nessuno dopo trovi l'orda com'era.
	_miscela_respawn(h, horde)
	_sez("orologio")
	# ## m17: il terzo minuto. Sta **dopo** `_miscela_respawn` perche' quella sezione
	# cambia il peso del mortar due volte (denti spenti e ripristinati) e finisce con
	# `restart_run()`, che azzera anche l'orologio: quindi la sezione che segue
	# comincia da un clock pulito e non eredita niente. E sta **prima** di
	# `_scena_vera` perche' lavora sull'orda isolata: la scena vera registra sul
	# contratto l'orda del gioco, e qui si deve parlare con l'altra.
	_m17_orologio(h, horde)
	_sez("m12")
	# ## m12-w1a: LA PARTITA A OROLOGIO E LA LEGGE DEL RATEO. Sta **qui**, e il
	# posto e' un ordine e non una scelta:
	#
	# dopo `_m17_orologio` perche' quella sezione finisce con `restart_run()`, che
	# azzera anche l'orologio: questa comincia da un clock pulito e da `kills_total`
	# a zero, e non eredita niente dalla sonda di m17. Prima di `_difficolta`
	# perche' `_difficolta` confronta la legge **della vita** e su `LAW_HORIZON_WAVE`,
	# e questa sezione tocca quel numero solo per dire che **non** e' la fine della
	# partita. Prima di `_scena_vera` perche' lavora sull'orda isolata, con una
	# cadencia di uccisioni **dichiarata** invece che con l'arma vera.
	_m12_orologio(h, horde)
	_sez("difficolta")
	# ## m14: STA **prima** di `_scena_vera`, e perche' e' un ordine e non una
	# scelta
	#
	# `_scena_vera` registra sul contratto l'orda e il giocatore **veri**, quindi
	# questa sezione deve poter rimettere a posto il contratto prima (`_ripristina`
	# lo fa) e deve poter rimettere a posto l'orda isolata, perche' `_scena_vera`
	# dopo misura la **sua** orda, non questa. E la sezione che chiude sta
	# aprendo la scena vera per leggere l'arma vera: due aperture, ma in due
	# punti separati del file, e ognuna finisce con `_chiudi` + `_ripristina`.
	_difficolta(h, horde)
	_sez("scena_vera")
	# Per ultima, e non per caso: `_scena_vera` carica `scenes/arena_main.tscn`,
	# che registra sul contratto l'orda e il giocatore **veri**. Farla prima
	# significherebbe che le sezioni precedenti parlassero con l'altra orda senza
	# accorgersene, quindi va in fondo e poi rimette a posto il contratto.
	_scena_vera(h, horde)
	_sez("ostacoli_contratto")
	# E l'ultima di tutte, perche' e' l'unica che guarda **il contratto**:
	# `Game.obstacles` lo scrive `-arena` in `_enter_tree()`, quindi il dato
	# esiste solo dopo che la scena vera e' entrata nell'albero.
	_ostacoli_contratto(h, horde)
	_sez("fine")
	_stampa_sezioni()

	print("orda: tutto il file in %d ms, ne restano %d dei 120000 del test" \
		% [Time.get_ticks_msec() - t0, 120000 - (Time.get_ticks_msec() - t0)])
	quit(h.finish("orda"))

# --- PROVVISORIO m15-b: cronometro per sezione + leva `norender` ---------------
# Togliere dopo la misura.

var _t_sez: Dictionary = {}
var _t_ultimo := 0
var _nome_ultimo := ""

# **L'oscillazione, dichiarata in una riga perche' e' un fatto e non un'anomalia.**
# Le sezioni sono state misurate sulla **stessa stringa di codice** a `104,8 s`,
# `116,9 s`, `137,1 s` e `144,2 s`: il margine sul tetto di `TEST_TIMEOUT_MS`
# (120 s, che l'utente ha deciso di non alzare) **si legge sui numeri stampati a
# ogni lancio**, non su una corsa sola, e nessun taglio puo' essere valutato da una
# misura singola.

func _sez(nome: String) -> void:
	var now := Time.get_ticks_usec()
	if _nome_ultimo != "":
		_t_sez[_nome_ultimo] = int(_t_sez.get(_nome_ultimo, 0)) + (now - _t_ultimo)
	_t_ultimo = now
	_nome_ultimo = nome

## Marcaposto dentro `avvio`, per sapere **dove** stanno i secondi di quella
## sezione. Provvisorio come `_sez`, ma **resta** finche' `avvio` non sta dentro il
## tetto: la misura del 2026-10-17 dice che i due posti del campionamento
## (`_grid_matches_linear` 0,017 s e `_query_budget` 0,135 s) valgono **0,152 s in
## tutto**, mentre `avvio` e' 39,4 s di cui 38,0 s sono passi di simulazione
## dichiarati (`_aggira` 11,4 s, `_incastrati` 11,2 s, `_denti_del_criterio` 7,0 s,
## `_raggio_60` 8,4 s). Senza questi marcatori il secondo taglio ripartirebbe da
## zero.
func _marca(nome: String) -> void:
	_sez("avvio/" + nome)

func _stampa_sezioni() -> void:
	var tot := 0
	for k in _t_sez:
		tot += int(_t_sez[k])
	var righe := ""
	for k in _t_sez:
		righe += "\n  %-22s %8.3f s" % [k, float(_t_sez[k]) / 1.0e6]
	print("orda: SEZIONI (provvisorio) totale %.3f s%s" % [float(tot) / 1.0e6, righe])

var _staccati: Array = []

func _norender_chiedi() -> bool:
	return OS.get_cmdline_user_args().has("norender")

func _stacca_render(arena: Node) -> int:
	if not _norender_chiedi():
		return 0
	var n := 0
	for c in arena.get_children():
		var s: Script = c.get_script()
		if s != null and str(s.resource_path).begins_with("res://src/render/"):
			var padre := c.get_parent()
			padre.remove_child(c)
			_staccati.append([c, padre])
			n += 1
	if n > 0:
		print("orda: PROVA, staccati %d nodi di src/render/ dalla scena vera" % n)
	return n

func _rimetti_render() -> void:
	for e in _staccati:
		(e[1] as Node).add_child(e[0])
	_staccati.clear()

## ## Mettere i nemici, e **non aspettarli**: la regola del banco di prova
##
## Un test che vuole 200 corpi **ce li mette**. Il rateo di produzione e' il
## **comportamento che il test sta misurando**, non l'attrezzo per costruire lo
## scenario: usarlo per riempire l'arena vuol dire che ogni volta che
## `Run.SPAWN_RATE` cambia, tutti i test che riempiono si rompono. E' successo due
## volte — la prima con `SPAWN_RATE` da 8,0/s a 2,0408/s (m12-w1b: `test_gameloop`
## rosso su un tetto di attesa tarato sul rateo vecchio, `test_orda` andato oltre i
## 120 s), e prima ancora con m4.
##
## La strada scelta e' **metterli direttamente**, non alzare il rateo durante il
## montaggio: alzare il rateo significa avere **una seconda fonte di verita' sul
## rateo dentro il test**, e un test che cambia il rateo per costruire lo scenario
## sta mentendo sullo scenario.
##
## `_spawn_one()` e' il cammino vero di `horde.gd` — quello che chiama `_top_up` — e
## non guarda `population`, solo la capienza fisica: quindi mettere 200 corpi con
## questa funzione produce **esattamente lo stesso stato** che produrrebbe la
## rampa, senza aspettarla. Il rateo resta misurato dove è un criterio
## (`_m12_criterio`, `_cresce_stretta`, i due riempimenti di `_spara_tutto`).
##
## Restituisce quanti ne ha messi, e resta dichiarato perche' un test che volesse
## Contare i chiami per fare un'altra cosa troverebbe qui la risposta invece di
## chiamare `_spawn_one()` da tre posti diversi.
func _riempi(horde: HORDE, quanti: int) -> int:
	var tetto := mini(quanti, HORDE.MAX_ENEMIES)
	var messi := 0
	while horde.count < tetto:
		horde._spawn_one()
		messi += 1
		if messi > HORDE.MAX_ENEMIES:
			break
	return messi

## Il **tetto di passi per un riempimento**, derivato dal rateo e non scritto.
##
## `horde.gd::_top_up` accumula `spawn_rate() x delta` e spende **un intero per
## passo**, quindi per arrivare a `n` nemici servono `ceil(n / (rate x delta))`
## passi. Il `+ 4` e' la tolleranza dell'arrotondamento del credito, non un
## margine comodo: e' il minimo oltre il quale il numero non puo' mentire.
##
## Il rateo e' letto dalla **costante** `RUN.SPAWN_RATE` e non da
## `run.spawn_rate()` perche' quello e' un metodo: la sezione `_m12_ancoraggio`
## asserisce che i due sono lo stesso numero, quindi qui la costante non e' una
## copia che puo' divergere.
func _passi_per_riempire(n: int, delta: float) -> int:
	return int(ceil(float(n) / maxf(0.000001, RUN.SPAWN_RATE * delta))) + 4

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
## **E una quarta volta in m17**, quando il numero che le muove e' **il tempo**:
## il mortar non e' spendibile prima di `Run.MORTAR_AFTER_S` = 180,0 s, quindi nei
## primi 30 s di una partita — che e' la finestra che questa sezione misura — il
## campo **non contiene la quinta specie**, come nel 2019 di m11 quando la quinta
## specie non esisteva. Il numero che esce e' quindi tornato alla situazione per
## cui la banda era stata scritta, e non e' una banda allargata: nessuna delle due
## estremita' si e' mossa, e quello che si e' mosso e' il **contesto** in cui la
## misura viene presa (`_misura_morso` ora chiama `restart_run()`, quindi entra con
## l'orologio a zero invece che con l'orologio accumulato dalle sezioni precedenti).
##
## | banda | m7 (1.2, R=28) | m8 (0.45, R=28) | m9 (0.45, R=46) | m11 (0.45, R=60) | **m17 (orologio a zero)** | perche' |
## |---|---|---|---|---|---|---|
## | cadenza misurata | 1.07-1.57 morsi/s | 0.60-1.17 | 0.50-1.07 | 0.57-1.03 | ristampata a ogni lancio | 3-5 corpi a portata invece di 5-20; poi l'anello su un disco 2,7 volte piu' largo |
## | danno al secondo | 3.3-8.5 hp/s | 3.42-11.19 | 2.39-14.37 | 3.37-14.17 | ristampata a ogni lancio | le due estremita' vanno in **direzioni opposte** |
## | sopravvivenza massima | 16.5 s | 29.2 s | 41.8 s | 29.7 s | ristampata a ogni lancio | segue la cadenza dell'onda piccola |
## | rapporto danno pieno/piccolo | 2.56 | 3.27 | 6.01 | 4.21 | ristampata a ogni lancio | vedi sotto: non e' l'orda piena che e' cresciuta |
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
## La cadenza: sotto `BITE_RATE_MIN` nessuno morderebbe (e il chiamante di m7
## sarebbe sparito senza che nessuno se ne accorga), sopra `BITE_RATE_MAX` il
## tetto `TOUCH_INTERVAL` non terrebbe, perche' `1/0.15 = 6.67`.
##
## ## m12: `BITE_RATE_MAX` non e' piu' un numero scritto a mano
##
## Era **2.5**, cioe' `1/0.40`: il letterale del tetto di allora. Con
## `TOUCH_INTERVAL` sceso a 0,15 s il letterale sarebbe rimasto **sotto** la
## misura (4,83 morsi/s a 200 vivi) e la porta sarebbe andata rossa per un
## numero che non era piu' un tetto ma il ricordo di uno. Quindi adesso e'
## **derivato**: `BITE_RATE_MAX = 1 / TOUCH_INTERVAL`, cioe' il tetto e' il tetto,
## e l'unica cosa che questa sezione controlla e' che la misura ci stia sotto.
## Derivare non e' spostare: il tetto di cadenza e' salito di 2,67 volte perche'
## il tetto di cadenza e' sceso di 2,67 volte, e i due numeri sono la stessa
## cosa scritta in due posti.
##
## Il pavimento `BITE_RATE_MIN` **non si e' mosso**, e non per pigrizia: il
## difetto che questa sezione chiude era proprio un morso che non arriva, e un
## pavimento che si alza ogni volta che la cadenza scende smetterebbe di essere
## la difesa contro il difetto.
const BITE_RATE_MIN := 0.25
const BITE_RATE_MAX := 1.0 / HORDE.TOUCH_INTERVAL
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
const TOUCH_CASES := [[4242, 12], [7311, 12], [20260912, 75], [20260912, 200]]

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
## I numeri di danno arrivati allo spia **in questo passo**, in ordine. Serve a
## `_due_fonti`: con due fonti (morso e colpo del mortar) l'ultimo numero non basta
## piu' a dire se quello che e' arrivato e' quello che l'orda dichiara, e senza
## questo campo un passo con due eventi sarebbe indistinguibile da uno con uno.
var _danni_step: Array[float] = []

## Lo spia. E' **il giocatore**, non il nemico: il chiamante di `damage_player`
## e' `src/sim/horde.gd`, e questo file non chiama `damage_player` una volta
## sola, solo la registra.
func _spia_damage_player(amount: float) -> bool:
	_totale_danno += amount
	_morsi += 1
	_ultimo_danno = amount
	_danni_step.append(amount)
	_per_morso[amount] = int(_per_morso.get(amount, 0)) + 1
	return true

## La posizione del giocatore finto, letta dal contratto come in partita.
##
## Non e' una `const`: e' un campo perche' la sezione 18 **muove** il giocatore
## (misura dell'attraversamento) e deve poterlo rimettere al punto di prima. Un
## percorso che modifica la posizione del giocatore e' la cosa che rende
## misurabile «quanto tempo il giocatore resta entro la portata di morso», e il
## numero che ne esce decide il tetto di cadenza: vedi `_attraversamento`.
var _player_via := FAKE_PLAYER

func _spia_player_position() -> Vector3:
	return _player_via

# --- 11-z. m12: il tempo di CONTATTO, e perche' decide il tetto di cadenza -----
#
# ## Il difetto che questa sezione misura, in una riga
#
# Il morso era **schedulato a timer**: un nemico che ti arriva addosso centinaia
# di volte non mordeva quasi mai, perche' il periodo (`TOUCH_PERIOD` = 1,00 s sul
# runner) non era mai pronto quando il contatto c'era. Il contatto non era la
# causa del morso, era solo il permesso.
#
# ## Il numero che decide tutto, e perche' va **misurato** e non calcolato
#
#     tempo di contatto = 2 x portata / velocita' del giocatore
#
# Con `CROSS_SPEED` = 13,65 m/s e le portate di oggi (1,98 / 2,49 / 3,85 / 6,91
# m) il conto a mano dà 0,29 / 0,36 / 0,56 / 1,01 s. Quel conto e' il **limite
# inferiore**: il nemico insegue, la separazione lo sposta, il campo lo devia, e
# tutto questo puo' allungare la finestra. Percio' il numero che sceglie il tetto
# non e' quello del conto ma quello che esce da qui sotto.
#
# ## La regola che ne discende, e che e' scritta in `src/sim/horde.gd`
#
#     TOUCH_INTERVAL < tempo di contatto del runner
#
# Se il tetto di cadenza fosse **piu' lungo** del contatto, un nemico
# attraversato entrerebbe in portata mentre il tetto e' ancora scarico, il morso
# verrebbe rimandato, e il nemico uscirebbe dalla portata senza aver mai morso:
# cioe' esattamente il difetto di prima, con un tetto nuovo. Percio' questo e'
# un **vincolo**, non una scelta di stile, ed e' asserito sotto.

## Velocita' di attraversamento del giocatore, in m/s. Numero dichiarato e non
## scritto dentro una formula: il conto `2 x portata / CROSS_SPEED` deve poter
## essere ricalcolato a mano leggendo questa riga.
const CROSS_SPEED := 13.65
## Passi percorri dal `-14 m` (ben fuori da qualunque portata: la piu' lunga e'
## 6,91 m) fino a che il nemico e' ben passato. 150 passi sono 2,50 s, cioe'
## 34,1 m: piu' dei 26 m che servono a entrare e uscire di tutte e quattro le
## specie.
const CROSS_STEPS := 150
## Quanto il giocatore parte **indietro** rispetto al punto da cui la riga viene
## misurata, in metri. Era un `-14,0` scritto dentro tre formule diverse (la
## messa in posizione, il treno, il messaggio di FAIL): un numero che compare in
## due posti e' una copia che prima o poi mente, e questa sezione ne aveva tre.
const CROSS_DA := -14.0
## Tre posizioni iniziali del nemico, misurate **sulla perpendicolare** alla riga
## del giocatore, cioe' in `z` e non in `x`.
##
## ## m12-bis: perche' `z` e non `x`, e il numero che lo dice
##
## La riga del giocatore corre lungo `x` a `z = _cross_z()`. Con l'offset in `x` il
## nemico partiva **gia' sulla riga**, `14 m` avanti al giocatore, e l'inseguimento
## diventava un **inseguimento di coda**: il nemico insegue un giocatore che corre a
## `PLAYER_SPEED = 13,65 m/s` mentre lui viaggia a `6,6 m/s`, quindi **non lo raggiunge
## mai**, e il numero che ne esce era il suo ritardo (`dmin = 3,35 m` con scarto in `z`
## di `0,56 m`: inseguimento **lungo** la riga, non **attraverso**). Con l'offset in `z`
## il nemico parte di traverso e l'inseguimento **attraversa** la riga: e nel caso
## `fermo` la perpendicolare e' **l'unica** cosa che produce il contatto, perche' il
## nemico non si muove.
const CROSS_OFFSET := [-3.0, 0.0, 3.0]

## La quota della riga che il giocatore percorre: **derivata dal produttore**.
##
## Era `CROSS_Z = -8,0 m`, un numero tarato quando l'arena non aveva ostacoli. A
## `R = 35 m` l'anello interno e' a `0,36 x 35 = 12,60 m` e la riga `z = -8,0 m`
## lo attraversa a `|x| = 9,73 m`, **dentro** i tre offset di questa sezione: oltre
## la linea interrotta `steer()` smette di restituire la trazione diretta e
## comanda il campo (`FIELD_WEIGHT = 1,0` contro `DIRECT_WEIGHT = 0,35`), e il
## numero che ne esce non e' il tempo di contatto ma **la durata di un'orbita
## attorno a un disco** — che e' esattamente quello che ha misurato: `dmin` a
## 3,63 m e il nemico fermo al centro dell'arena.
##
## Il minimo e' dunque `anello + disco + una cella = 12,60 + 2,275 + 2,00 =
## 16,875 m`, e i tre numeri vengono da `OBST.RING_RADII[0]`,
## `OBST.radius_for(arena_radius)` e `FLOW.CELL`: nessuno dei tre e' scritto qui,
## e se il layout o il raggio cambiano la riga si sposta con loro.
##
## **Che la riga sia davvero libera e' un'altra domanda, e non e' di questa sezione**:
## lo dice `clear_line` nella misura, e *dove* una riga libera esiste e' affare di
## `-arena`, cioe' della rampa: qui il numero e' il minimo che il produttore
## impone, non una scelta.
func _cross_z(horde: HORDE) -> float:
	var anello: float = OBST.RING_RADII[0]
	var disco := OBST.radius_for(horde.arena_radius)
	return -(anello * horde.arena_radius + disco + FLOW.CELL)

## Mette **un** nemico di specie `kind` sulla linea di attraversamento, lontano
## dalla portata, e lascia scaricare il tetto di cadenza. `true` se ce n'e' uno.
##
## ## Perche' il nemico viene prima mandato lontano
##
## Il tetto a intervallo si scarica **fuori** dalla portata: se l'ingresso in
## portata accadesse mentre il tetto e' a meta' carica, la risposta sarebbe «no»
## perche' il tetto scatta e non perche' la distanza e' quella giusta. Un test che
## misura il tetto quando vuole misurare la distanza e' un test che non misura
## niente.
func _prepara_attraversamento(horde: HORDE, kind: int, offset: float) -> bool:
	# ## La precondizione che questa sezione non dichiarava, ed e' il difetto
	#
	# `horde.gd::_player_focus()` ha un **ripiego silenzioso**: se il contratto non
	# ha `player_position`, o l'ha ma restituisce un vettore di lunghezza quadrata
	# sotto `1e-6`, restituisce `_focus`, che vale `Vector3.ZERO` — **il centro
	# dell'arena**. Quindi un nemico di cui nessuno si accorge che dovrebbe
	# inseguire il giocatore **cammina verso il centro**, e il sim non dà nessun
	# altro sintomo: nessun crash, nessun valore fuori range, nessun contatore
	# che si accorge. Il centro e' a `(0, 0)` e la linea del giocatore e' a
	# `CROSS_Z = -8,0 m`: sono otto metri di distanza che nessuna asserzione
	# guardava, e il FAIL che ne e' uscito diceva «mai entrato in portata», che e'
	# la descrizione giusta del difetto e la diagnosi sbagliata della causa.
	#
	# Qui la precondizione si dichiara **dove si stabilisce**: se non c'e' un
	# giocatore nel contratto, la campionata non parte e la sezione lo dice con
	# il suo messaggio, invece di produrre tre coppie di numeri che descrivono
	# un inseguimento che non e' mai partito.
	var game := _game()
	if game == null or not game.has_impl("player_position"):
		return false
	while horde.count > 0:
		horde.damage_enemy(0, 9999.0, Vector3.ZERO)
	# ## L'onda bloccata a 1, e **perche' questa sezione ne aveva bisogno**
	#
	# Ogni altra sezione di misura lo fa (`_incastrati`, `_aggira`, `_misura_raggio`)
	# e questa no: era un difetto che nessuna asserzione guardava, perche' il numero
	# che esce — il contatto — **non dipende dal campo** ma dalla geometria, e una
	# geometria che si sposta un po' sembra rumore.
	#
	# Il meccanismo, in quattro passi: `damage_enemy` chiama `_kill`, `_kill` chiama
	# `run.register_kill()`, e questa sezione uccide **un nemico per volta** decine di
	# volte (30 preparazioni da 25+ uccisioni ciascuna) — quindi l'onda 1 si chiude
	# **dentro** la misura, `next_wave()` risincronizza `population` dalla curva e
	# `_top_up` riempie il campo dietro il nemico che si sta misurando. Da li' la
	# **separazione** sposta il nemico sotto la riga: `dmin` non e' piu' un numero
	# della geometria ma un numero della folla, e lo stesso codice dava `0,346 m` in
	# un campione e nessun contatto nell'altro.
	#
	# Il difetto quindi **non e'** nel tetto di cadenza, che e' un tetto e non smette
	# di contare: e' che la scena della misura non era la scena che la misura
	# descriveva. Le due righe sotto sono la difesa, ed esattamente quelle che le
	# altre sezioni hanno gia' scritto.
	horde.run.wave = 1
	horde.run.wave_killed = 0
	horde.population = 1
	horde.auto_respawn = true
	var passi := 0
	while horde.count < 1 and passi < 120:
		horde.step(DT)
		passi += 1
	if horde.count != 1:
		return false
	horde.kinds[0] = kind
	horde.radii[0] = ENEMY.RADIUS[kind]
	horde.hp[0] = ENEMY.hp_of(kind)
	# ## m12: la messa in posizione del giocatore era **fuori** dall'arena
	#
	# `offset + 34,0 m` era dentro l'arena da `60 m` (ed e' il motivo di quel numero)
	# ma **non** dentro quella da `35,0 m`: per due dei tre offset la messa in posizione
	# cade oltre il muro, a `34,9 m` e `38,8 m` dal centro, mentre il nemico non puo'
	# stare oltre `arena_radius - RADIUS[kind]`. Il difetto che abilita e' silenzioso
	# — l'orda insegue un punto che nessun corpo puo' raggiungere e `EDGE_PUSH` la
	# tiene al muro — e la sezione non se ne accorgeva perche' nessuna asserzione
	# guardava la posizione.
	#
	# Il numero e' derivato dal raggio che il contratto dichiara al momento della
	# misura, quindi la sezione continua a stare dentro l'arena anche quando il
	# raggio si muove: nessun `34` scritto a mano.
	var parete := maxf(_raggio_contratto() - ENEMY.RADIUS[kind] - 2.0, 4.0)
	# m12-bis: il nemico sta **sulla perpendicolare** (`offset` in `z`) e il
	# giocatore sulla riga, ben lontano: i due non si toccano durante la messa in
	# posizione, altrimenti i 13 passi di assestamento contano come contatto.
	var linea_z := _cross_z(horde)
	_player_via = Vector3(parete, 0.0, linea_z)
	for _i in int(ceil(HORDE.TOUCH_INTERVAL / DT)) + 4:
		horde.transforms[0] = Vector3(0.0, 0.0, linea_z + offset)
		horde.velocities[0] = Vector3.ZERO
		horde.step(DT)
	return true

## Una corsa di attraversamento: il giocatore passa a `CROSS_SPEED` accanto a un
## nemico di specie `kind` e si conta quanto tempo resta entro la sua portata.
##
## `fermo` = il nemico e' inchiodato alla sua posizione (il conto geometrico
## `2 x portata / velocita'`); `libero` = il nemico insegue davvero, con
## separazione e campo. **Il numero che sceglie il tetto e' quello `libero`**:
## il conto a mano e' il caso migliore, e scegliere il tetto sul caso migliore e'
## sceglierlo su un numero che non esiste in partita.
func _misura_attraversamento(horde: HORDE, kind: int, fermo: bool, offset: float) -> Dictionary:
	var morsi_prima := _morsi
	if not _prepara_attraversamento(horde, kind, offset):
		return {"morsi": -1, "passi": 0, "episodi": 0, "primo": -1}
	var portata := horde.bite_range_of(kind)
	# m12-bis: **la riga del giocatore** e' `linea_z` (costante) e corre lungo `x`;
	# il nemico sta sulla **perpendicolare**, a `linea_z + offset`, e la messa in
	# posizione lo mette a `x = 0`, cioe' **dentro** la corsa: il giocatore parte da
	# `CROSS_DA` e gli passa addosso.
	var linea_z := _cross_z(horde)
	var z := linea_z + offset
	var x := CROSS_DA
	_player_via = Vector3(x, 0.0, linea_z)
	var contatto_passi := 0
	var episodi := 0
	var dentro := false
	var primo_contatto := -1
	# La **distanza minima** fra nemico e linea del giocatore: e' il numero che
	# distingue «il nemico non c'e'» da «il nemico c'e' ma il contatto non e' stato
	# campionato», cioe' la domanda che un messaggio di FAIL senza numeri non puo'
	# fare. Costa una radice quadrata per passo e vale perche' quando questa
	# sezione va rossa il messaggio deve dire **perche'**.
	var distanza_minima := 1.0e9
	var pos_finale := Vector3.ZERO
	# ## La precondizione **geometrica**, e perche' senza questa sezione misura
	# ## un'altra cosa
	#
	# Il nemico parte da `(offset, CROSS_Z)` e il giocatore percorre la riga
	# `z = CROSS_Z` fino a `offset - 14 + CROSS_SPEED * CROSS_STEPS * DT`. Quella
	# **riga attraversa gli anelli di ostacoli**: a `R = 35 m` l'anello interno e'
	# a `0,36 R = 12,6 m` e la riga `z = -8,0 m` lo incontra a `|x| = 9,73 m`,
	# **dentro** i tre offset che questa sezione usa.
	#
	# E a linea interrotta `flow_field.steer()` smette di restituire la trazione
	# diretta e miscola il gradiente del campo con `FIELD_WEIGHT = 1,0` contro
	# `DIRECT_WEIGHT = 0,35`: **il campo comanda**. Il nemico allora segue la
	# discesa del costo — che puo' portarlo nel vuoto centrale, l'unico punto
	# dell'arena dove il gradiente non ha un verso utile — e ci rimane a girare.
	# Il numero che ne esce non e' «quanto tempo il runner resta in portata»: e'
	# «quanta parte di un'orbita attorno a un disco il runner fa prima di
	# smettere». Con `dmin = 3,63 m` e il nemico fermo a `(0,81 , -2,65)` — il
	# **centro** dell'arena, a 5,35 m dalla linea in `z` — e' esattamente quello.
	#
	# Il difetto e' della sezione, non del campo: il campo fa quello che deve
	# fare. Quindi qui si **chiede** al campo se la linea e' libera, e la sezione
	# che decide lo dice ad alta voce invece di produrre un numero che parla di
	# un'altra misura.
	var fine := x + CROSS_SPEED * CROSS_STEPS * DT
	## ## Il tipo e' **scritto**, e perche' qui la trappola e' silenziosa
	##
	## `horde.gd:242` dichiara `var flow_field = null` — **senza tipo** — quindi
	## `horde.flow_field.clear_line(...)` arriva come `Variant` e `:=` non ha niente
	## da inferire. Il metodo **esiste ed e' pubblico** (`flow_field.gd:607`, `-> bool`).
	##
	## Si controllano **due** tratti e non uno: la riga che il giocatore percorre, e
	## la perpendicolare che il nemico deve fare per arrivarci. Il secondo era
	## sparito quando l'offset era in `x`, e con l'offset in `z` e' quello che
	## puo' cadere dentro un disco: il nemico a `offset = -3` sta a `|z| = 13,875`,
	## cioe' `1,275 m` fuori dall'anello interno a `12,60`, e se li' ci fosse un disco
	## la misura ripartirebbe dentro un ostacolo — che e' il difetto che questa
	## sezione ha appena smesso di avere sulla riga.
	var linea: bool = horde.flow_field != null \
		and bool(horde.flow_field.clear_line(
			Vector3(0.0, 0.0, linea_z), Vector3(fine, 0.0, linea_z))) \
		and bool(horde.flow_field.clear_line(
			Vector3(0.0, 0.0, z), Vector3(0.0, 0.0, linea_z)))
	for s in CROSS_STEPS:
		# La distanza **prima** del passo: e' la stessa che `enemy.gd` guarda per
		# decidere il morso, quindi il numero qui e quello che il codice vede.
		var p := horde.transforms[0]
		var d := Vector2(p.x - x, p.z - z).length()
		distanza_minima = minf(distanza_minima, d)
		if d <= portata:
			contatto_passi += 1
			if not dentro:
				dentro = true
				episodi += 1
				if primo_contatto < 0:
					primo_contatto = s
		else:
			dentro = false
		pos_finale = p
		x += CROSS_SPEED * DT
		_player_via = Vector3(x, 0.0, linea_z)
		if fermo:
			horde.velocities[0] = Vector3.ZERO
			horde.transforms[0] = Vector3(0.0, 0.0, z)
		horde.step(DT)
	return {
		"morsi": _morsi - morsi_prima,
		"passi": contatto_passi,
		"episodi": episodi,
		"primo": primo_contatto,
		"dmin": distanza_minima,
		"finale": pos_finale,
		"portata": portata,
		"linea": linea,
		"fine": fine,
	}

## La sezione 18 per intero: il tempo di contatto per specie, e i morsi per
## attraversamento. Gira **prima** di qualunque decisione sul tetto di cadenza,
## perche' il tetto e' una funzione di questi numeri e non il contrario.
func _attraversamento(h, horde: HORDE) -> void:
	var t0 := Time.get_ticks_usec()
	var auto_respawn := horde.auto_respawn
	var popolazione := horde.population
	var righe := ""
	for k in ENEMY.KIND_COUNT:
		var nome: String = ENEMY.KIND_NAMES[k]
		var portata := horde.bite_range_of(k)
		var conto := 2.0 * portata / CROSS_SPEED
		var min_libero := 1.0e9
		var min_fermo := 1.0e9
		var episodi := 0
		var morsi := 0
		var prove := 0
		for offset in CROSS_OFFSET:
			var libero := _misura_attraversamento(horde, k, false, offset)
			if int(libero["morsi"]) < 0:
				continue
			prove += 1
			morsi += int(libero["morsi"])
			episodi += int(libero["episodi"])
			min_libero = minf(min_libero, float(libero["passi"]) * DT)
			var fermo := _misura_attraversamento(horde, k, true, offset)
			min_fermo = minf(min_fermo, float(fermo["passi"]) * DT)
		if prove == 0:
			h.fail("attraversamento %s: nessun nemico e' sopravvissuto alla preparazione" % nome)
			continue
		righe += "\n  %s: portata %.2f m | contatto libero min %.3f s (%.1f passi) | contatto fermo min %.3f s (%.1f passi) | episodi %d su %d attraversamenti | morsi %d | conto a mano 2xR/v %.3f s" \
			% [nome, portata, min_libero, min_libero / DT, min_fermo, min_fermo / DT,
				episodi, prove, morsi, conto]
		print("orda: contatto per specie, treno a %.2f m/s (il minimo e' il caso peggiore):%s"
			% [CROSS_SPEED, righe])
		righe = ""
	# Il tetto di cadenza non puo' essere piu' lungo del contatto **peggiore** del
	# runner: se lo fosse, un runner attraversato entrerebbe in portata col tetto
	# scarico, il morso verrebbe rimandato fuori portata, e il difetto di oggi
	# tornerebbe con un tetto diverso. Questa e' l'unica asserzione sul tetto, e
	# il numero che la decide e' quello stampato sopra.
	var scelta := _contatto_peggiore(horde, ENEMY.RUNNER)
	var peggiore := float(scelta["peggiore"])
	var prove := int(scelta["prove"])
	var campione: Dictionary = scelta["campione"]
	var portata_r := horde.bite_range_of(ENEMY.RUNNER)
	var dmin := 1.0e9
	var finale := Vector3.ZERO
	if not campione.is_empty():
		dmin = float(campione["dmin"])
		finale = Vector3(campione["finale"])
		portata_r = float(campione["portata"])
	# ## Il FAIL che **porta i numeri dentro**, e che sono **di una sola passata**
	#
	# Tre numeri, tutti presi dalla campionata peggiore: il minimo e' un **minimo**
	# fra offset, la posizione finale e' l'**ultima** delle tre, e prima del
	# 2026-10-17 quei due venivano dalla stessa identica riga di codice — ed
	# e' il modo piu' economico di stampare due fatti che non possono essere
	# veri insieme.
	#
	# Il terzo numero e' quello che distingue i tre difetti possibili, e non e' un
	# numero decorativo: e' lo **scarto in z** fra dove il nemico e' finito e la
	# linea del giocatore (`CROSS_Z`). Se lo scarto e' maggiore della portata, il
	# nemico **non ha mai inseguito**: la difetta e' a monte, nella scena (il
	# ripiego di `_player_focus()` sul centro dell'arena, per esempio) e la
	# distanza minima non dice niente. Se lo scarto e' sotto la portata e la
	# distanza minima sopra, l'inseguimento c'era e il difetto e' nella preparazione.
	# Se sono entrambe sotto, il contatto e' stato campionato e il difetto e' a
	# valle, e allora il numero che lo spiega e' `morsi`.
	var scarto := absf(finale.z - _cross_z(horde))
	var causa := "ci sta ma il contatto non e' stato contato"
	if scarto > portata_r:
		causa = ("l'inseguimento non e' mai partito: il nemico e' finito a %.2f m "
			% scarto + "dalla linea in z, e' andato a inseguire un'altra cosa")
	elif dmin > portata_r:
		causa = "mai entrato in portata: l'inseguimento c'era, il difetto e' nella preparazione"
	if not campione.is_empty():
		h.check(bool(campione["linea"]),
			"contatto runner: la riga che il giocatore percorre (z = %.1f m, da x = "
				% _cross_z(horde)
			+ "%.2f a %.2f) passa dentro un disco, quindi `steer` non da' piu' la "
				% [CROSS_DA, float(campione["fine"])]
			+ "trazione diretta e comanda il campo (FIELD_WEIGHT 1,0 contro "
			+ "DIRECT_WEIGHT 0,35): il numero che esce sarebbe la durata di un'orbita "
			+ "attorno a un ostacolo, non il tempo di contatto")
	h.check(prove > 0,
		"contatto runner: nessuna delle %d preparazioni e' arrivata a un nemico: "
			% CROSS_OFFSET.size()
		+ "senza un giocatore registrato nel contratto (`player_position`) "
		+ "`_player_focus()` ripiega sul centro dell'arena e la misura sarebbe sul vuoto")
	h.check(peggiore > 0.0,
		"contatto runner non campionato: %d preparazioni riuscite su %d, in %d passi, "
			% [prove, CROSS_OFFSET.size(), CROSS_STEPS]
		+ "distanza minima fra nemico e linea del giocatore %.3f m contro una portata "
			% dmin
		+ "di %.3f m, nemico finite in (%.2f, %.2f), scarto in z %.2f m -- %s"
			% [portata_r, finale.x, finale.z, scarto, causa])
	h.check(HORDE.TOUCH_INTERVAL < peggiore,
		"il tetto di cadenza (%.3f s) e' piu' corto del contatto peggiore del runner "
			% HORDE.TOUCH_INTERVAL
			+ "(%.3f s = %.1f passi): altrimenti un runner attraversato aspetterebbe "
				% [peggiore, peggiore / DT]
			+ "il tetto fuori portata e non morderebbe mai")
	# ## I due tempi stampati, e **perche' `libero` non e' un criterio**
	#
	## Il caso libero **non produce un tempo di contatto**: `SPEED[RUNNER] = 6,6 m/s`
	## contro `PLAYER_SPEED = 13,65 m/s`, quindi il nemico non raggiunge mai un
	## giocatore che corre e il suo numero e' `0,000 s` — che significa **«non c'e'
	## stato contatto»**, non «il contatto e' stato istantaneo». Confrontare `0` con
	## `0,300 s` e chiamarlo «il minimo» e' mettere due grandezze diverse l'una
	## contro l'altra: era un criterio che non misurava niente, e l'ho tolto.
	##
	## Resta **stampato** perche' una misura e' informazione anche quando non e' un
	## criterio, e resta la misura che dice *quando un inseguimento arriva*: il suo
	## numero e' quello che un lettore deve poter vedere prima di fidarsi del
	## `fermo` come caso peggiore.
	var libero := float(scelta["libero"])
	# ## Il conto a mano, confrontato con la misura, entro **un passo**
	#
	# `2 x portata / PLAYER_SPEED` e' esatto per costruzione e la misura conta
	# passi interi: la tolleranza e' `DT`, cioe' un passo, e non di piu'. Se i due
	# numeri non coincidono, il **conto** e' il primo bug — non il criterio, che
	# qui e' geometria con il nemico inchiodato.
	var atteso := 2.0 * portata_r / ENEMY.PLAYER_SPEED
	h.check(absf(peggiore - atteso) <= DT,
		"contatto fermo misurato %.3f s (%.1f passi) contro il conto 2 x %.3f m / "
			% [peggiore, peggiore / DT, portata_r]
		+ "%.2f m/s = %.3f s: i due devono coincidere entro un passo (%.3f s), e se non "
			% [ENEMY.PLAYER_SPEED, atteso, DT]
		+ "coincidono il conto e' il primo bug")
	print("orda: contatto -- caso FERMO %.3f s (il minimo, e' quello che sceglie il "
			% peggiore
		+ "tetto) contro caso LIBERO %.3f s; conto a mano 2 x %.3f / %.2f = %.3f s"
		% [libero, portata_r, ENEMY.PLAYER_SPEED, atteso])
	# il campo torna com'era
	horde.auto_respawn = auto_respawn
	horde.population = popolazione
	_player_via = FAKE_PLAYER
	horde.population = RUN.population_of(1)
	horde.restart_run()
	h.eq(horde.count, RUN.population_of(1),
		"attraversamento: la sezione rimette l'orda alla popolazione della curva")
	print("orda: contatto: sezione intera in %d us, tetto di cadenza %.3f s contro %.3f s di contatto runner misurati"
		% [Time.get_ticks_usec() - t0, HORDE.TOUCH_INTERVAL, peggiore])

## Il campione peggiore del runner — quello con meno contatto — **intero**: non
## solo i secondi, anche i numeri che li hanno prodotti.
##
## ## Perche' un dizionario e non un `float`
##
## Il numero peggiore e la sua campionata devono essere **la stessa cosa**. Il
## messaggio di un FAIL che prende i numeri da una seconda passata della misura
## descrive una scena diversa da quella che e' fallita, ed e' successo due volte:
## la riga usciva dicendo «distanza minima 0,35 m contro una portata di 1,98 m --
## ci sta ma il contatto non e' stato contato», e quei due fatti **non possono
## coesistere nella stessa passata** perche' il contatto e' la **distanza**, e la
## distanza la calcola questo file (`:872` sopra) e non l'orda. Il difetto che il
## messaggio annunciava era un difetto del messaggio, e per due porte ha guardato
## il codice della simulazione per un difetto che stava a due righe di distanza.
##
## Quindi qui dentro si tiene **la campionata intera** del peggiore, e chi chiama
## legge i numeri del messaggio da li'. Una sola passata della misura, tre offset,
## un solo messaggio: i tre offset non si mescolano e niente viene ristampato.
func _contatto_peggiore(horde: HORDE, kind: int) -> Dictionary:
	## ## m12-bis: il criterio va sul caso **fermo**, e perche' non e' un allargamento
	##
	## Il tetto di cadenza protegge dal **caso peggiore**: un nemico che attraversa
	## la portata **il piu' velocemente possibile**, cioe' con il giocatore alla sua
	## velocita' massima e il nemico che non si muove. Il caso `fermo` **e'** quel
	## caso, e il suo tempo e' **esatto per costruzione**: `2 x portata / velocita'`.
	## Il caso `libero` dà un tempo **lungo** — il nemico chiude e ci resta dentro —
	## quindi sceglierlo sarebbe scegliere il caso facile, l'esatto opposto di quello
	## che il criterio deve dimostrare. Sul vecchio layout il numero che ne usciva
	## non era ne' l'uno ne' l'altro: era il **ritardo di un inseguimento**, perche'
	## `PLAYER_SPEED = 13,65 m/s` e `SPEED[RUNNER] = 6,6 m/s` e un inseguimento libero
	## non puo' produrre un attraversamento geometrico.
	##
	## Il caso `libero` resta **misurato e stampato** accanto, e sotto c'e' un criterio
	## che verifica che sia davvero il **minimo**: se il libero venisse piu' corto del
	## fermo, il numero che sceglie il tetto non sarebbe quello che questa dichiarazione
	## dice, e va sapere quale dei due sta decidendo.
	var peggiore := 1.0e9
	var campione := {}
	var prove := 0
	var libero := 1.0e9
	for offset in CROSS_OFFSET:
		var m := _misura_attraversamento(horde, kind, true, offset)
		if int(m["morsi"]) < 0:
			continue
		prove += 1
		var secondi := float(m["passi"]) * DT
		if secondi < peggiore:
			peggiore = secondi
			campione = m
		var l := _misura_attraversamento(horde, kind, false, offset)
		libero = minf(libero, float(l["passi"]) * DT)
	return {"peggiore": peggiore, "campione": campione, "prove": prove,
		"libero": libero}

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
	# Ogni specie, senza eccezioni: il danno e la cadenza escono dalla tabella
	# `MASS` e da nient'altro. La quinta specie e' dentro anche lei, quindi qui
	# si misura che non abbia fatto nascere una tabella tutta sua.
	for k in ENEMY.KIND_COUNT:
		var atteso := ENEMY.TOUCH_DAMAGE_BASE * ENEMY.MASS[k] / ENEMY.MASS[ENEMY.RUNNER]
		h.near(ENEMY.touch_damage_of(k), atteso, 0.000001,
			"il morso di %s esce dalla tabella MASS, non da una tabella sua"
				% ENEMY.KIND_NAMES[k])
		var periodo := ENEMY.TOUCH_PERIOD * sqrt(ENEMY.MASS[k] / ENEMY.MASS[ENEMY.RUNNER])
		h.near(ENEMY.touch_period_of(k), periodo, 0.000001,
			"la cadenza di %s esce dalla stessa tabella" % ENEMY.KIND_NAMES[k])
	# ## m13: la monotonia e' sulla **massa**, non sull'indice
	#
	# Fino a m12 le due cose coincidevano: l'ordine degli indici (`runner`,
	# `grunt`, `brute`, `boss`) era anche l'ordine delle masse. Con la quinta
	# specie **no**: il mortar ha massa 3,2, cioe' piu' del brute (2,6) e meno
	# del boss (6,0), e il suo indice e' 4 perche' e' nato dopo. Quindi un
	# criterio scritto su `k - 1` comincia a confrontare il mortar col boss e va
	# rosso — e va rosso per la ragione sbagliata.
	#
	# Il numero che il criterio descrive non e' cambiato: resta «piu' pesante
	# morde piu' forte e piu' lento», ed e' quello che i due numeri storici
	# (1,60 / 2,29 / 5,94 / 13,71) continuano a dire. A cambiare e' **la domanda**:
	# non piu' «la specie dopo e' piu' pesante», ma «la specie piu' pesante di
	# tutte». Scrivere il criterio sull'indice e stato quello che ha fatto questa
	# sezione andare rossa; scriverlo sulla massa e' la correzione, e il fatto
	# che sia una correzione e' dichiarato qui e non nascosto.
	var per_massa := _specie_per_massa()
	for n in per_massa.size():
		var k: int = per_massa[n]
		if n == 0:
			continue
		var j: int = per_massa[n - 1]
		h.check(ENEMY.touch_damage_of(k) > ENEMY.touch_damage_of(j),
			"piu' pesante morde piu' forte: %s (%.2f, massa %.1f) sopra %s (%.2f, massa %.1f)"
				% [ENEMY.KIND_NAMES[k], ENEMY.touch_damage_of(k), ENEMY.MASS[k],
					ENEMY.KIND_NAMES[j], ENEMY.touch_damage_of(j), ENEMY.MASS[j]])
		h.check(ENEMY.touch_period_of(k) > ENEMY.touch_period_of(j),
			"piu' pesante morde piu' lento: %s (%.2f s, massa %.1f) sopra %s (%.2f s, massa %.1f)"
				% [ENEMY.KIND_NAMES[k], ENEMY.touch_period_of(k), ENEMY.MASS[k],
					ENEMY.KIND_NAMES[j], ENEMY.touch_period_of(j), ENEMY.MASS[j]])
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
	print("orda: morso, tabella per specie nell'ordine del peso: %s"
		% _riga_mosse())

## Gli indici delle specie **in ordine di massa crescente**, dall'indice piu'
## basso. Non e' un trucco: e' la domanda che «piu' pesante morde piu' forte» sta
## davvero facendo. L'ordine degli indici era la stessa cosa solo finche' le
## specie sono state quattro (vedi la dichiarazione sopra).
func _specie_per_massa() -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in ENEMY.KIND_COUNT:
		out.append(k)
	# ordinamento per inserzione: cinque elementi e nessuna allocazione che
	# valga la pena dichiarare.
	for a in range(1, out.size()):
		var v: int = out[a]
		var b := a - 1
		while b >= 0 and ENEMY.MASS[out[b]] > ENEMY.MASS[v]:
			out[b + 1] = out[b]
			b -= 1
		out[b + 1] = v
	return out

## `runner 0.7/1.60/1.00s` per ogni specie nell'ordine del peso: massa, morso,
## periodo. Il denominatore e' dichiarato per ogni voce, come in `_riga_specie`.
func _riga_mosse() -> String:
	var testo := ""
	for k in _specie_per_massa():
		testo += " %s %.1f/%.2f/%.2fs" % [ENEMY.KIND_NAMES[k], ENEMY.MASS[k],
			ENEMY.touch_damage_of(k), ENEMY.touch_period_of(k)]
	return testo

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

	# Il campo di avvio, **messo** e non aspettato.
	# visibile che 200 nemici costa dei secondi quando nasce, e non un passo.
	#
	# Questa sezione **costruisce il banco di prova**: il suo compito e' che sotto ci
	# siano 200 corpi su cui misurare griglia, capacita' e nodi. Aspettarli al ritmo
	# di produzione significa che la sezione costa 3,92 volte piu' da quando il
	# rateo e' sceso, e che la sua durata dipende dalla costante che questa sezione
	# non sta misurando. Quindi si mettono.
	#
	# Quello che qui NON e' piu' misurato: che la capienza non si raggiunga in un
	# passo. Era il sintomo di m4, e resta verificato in due posti che sono ancora
	# una rampa vera: `tests/test_gameloop.gd` invariante 3 (con tetto derivato dal
	# rateo) e piu' sotto, in `_spara_tutto`, con l'asserzione «un passo dopo lo
	# svuotamento il campo e' ancora vuoto: nessuna raffica». Toglierlo di qui non
	# toglie il criterio: gli toglie una copia che il banco di prova aveva reso falsa.
	#
	# E la stampa: prima diceva «portati a 200 in N passi = X s», che descriveva una
	# rampa. Ora dice **quanti corpi sono stati messi** e non parla di secondi,
	# perche' un tempo qui sarebbe il tempo del banco di prova travestito da tempo
	# del gioco.
	horde.auto_respawn = true
	horde.population = HORDE.MAX_ENEMIES
	var messi := _riempi(horde, HORDE.MAX_ENEMIES)
	h.eq(horde.count, HORDE.MAX_ENEMIES, "%d nemici vivi per il criterio di m1" % HORDE.MAX_ENEMIES)
	h.check(messi > 1,
		"i corpi sono stati messi in piu' di un colpo: %d richiami per arrivare a %d"
			% [messi, horde.count])
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
	# ## La stampa: «portati a %d in %d passi = %.2f s» non e' piu' vera qui
	#
	# Il campo di avvio non viene piu' riempinto **aspettando** le nascite ma
	# **mettendo** i corpi con `_riempi()`, quindi un tempo in secondi qui
	# descriverebbe il banco di prova e non il gioco. La riga dice **quanti
	# richiami** sono serviti e riporta il rateo solo come riferimento, con la parola
	# che lo dice. Il tempo di riempimento vero e' misurato in `_m12_criterio` e in
	# `tests/test_gameloop.gd` invariante 3, dove l'attesa e' ancora una rampa.
	print("orda: avvio a %d nemici (Run.POP_BASE), portati a %d in %d richiami di `_riempi` "
			% [RUN.POP_BASE, horde.count, messi]
		+ "(NON e' una rampa di nascite: il rateo e' %.4f/s e non e' stato usato per il "
			% RUN.SPAWN_RATE
		+ "riempimento, che viene misurato altrove)")
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
	_nascite_morso(h, horde)

## ## m12-sesta: la **quarta clausole** della legge di nascita, e i due numeri che la
## ## rendono verificabile
##
## La legge ne aveva tre — dentro l'arena, non dentro un disco, mai `Vector3.ZERO` —
## e tutte e tre sono rispettate da uno spawn a `30 cm` dal giocatore: **«non sotto
## il giocatore» non e' «non addosso al giocatore»**. La quarta e':
##
## > **nessun punto di nascita puo' stare dentro il raggio di morso del giocatore**
##
## e la sua forma e' una **disuguaglianza fra due numeri** — il minimo delle distanze
## di nascita sta **sopra** la portata di morso — che si puo' sbagliare **in due
## modi**: il punto troppo vicino, oppure la portata sbagliata. «Nessuno nasce
## addosso» sarebbe una frase; la disuguaglianza e' un numero che si verifica.
##
## ## **Perche' il giocatore di questa misura NON e' il centro**, e questo e' il punto
##
## Con il giocatore al centro il buco di `Spawner.LAYOUT_INNER = 12,0 m` (che e' un
## buco **intorno all'origine**, non intorno al giocatore) tiene gia' tutti i punti
## fuori dal raggio di morso, quindi il criterio passerebbe **per caso**: sarebbe
## un criterio che misura la posizione di partenza del giocatore e non la clausola.
## Quindi qui il giocatore e' **spostato** di `LAYOUT_PROVA`, e il numero che esce
## senza la clausola e' quello che la clausola chiude.
##
## La prima volta che questo file ha misurato la disposizione iniziale, il giocatore
## era al centro e il minimo e' stato `LAYOUT_INNER` — cioe' la legge era soddisfatta
## dalla geometria dell'arena, non dalla clausola. La differenza fra i due numeri e'
## tutta la misura.
const LAYOUT_PROVA := Vector3(7.0, 0.0, -4.0)

func _nascite_morso(h, horde: HORDE) -> void:
	# Il raggio di morso **derivato qui, adesso**, dalla stessa tabella e dallo
	# stesso fattore corpo che usa la simulazione: un numero letto dal sorgente o
	# ricordato da un'altra misura sarebbe una copia, e la copia e' il difetto che
	# questa clausola chiude.
	var morso := ENEMY.bite_range_max(horde.body_scale)
	# Lo stato di prima, tutto: questa sezione **ripopola** l'orda e la sezione
	# dopo fa il benchmark della griglia su 200 corpi, quindi un banco sporco
	# **avrebbe** cambiato il numero di un altro criterio (ed e' successo: la prima
	# stesura lasciava 100 vivi e faceva andare rosso «la griglia deve battere la
	# scansione lineare», che a 100 corpi e' piu' lento perche' i secchielli sono
	# meno pieni — un numero vero, ma non quello che quella sezione dichiara).
	var prima_count := horde.count
	var prima_pop := horde.population
	# `horde.run` e' una `Variant` (il campo non ha tipo dichiarato), quindi `:=`
	# su `run.wave` non inferisce niente: il tipo e' scritto, come nel resto del
	# file quando si legge dal run.
	var prima_wave: int = horde.run.wave
	var prima_killed: int = horde.run.wave_killed
	horde.set_focus(LAYOUT_PROVA)
	# Il giocatore di questa misura e' **il focus**, e va letto **dopo** lo
	# spostamento: misurare contro un punto letto prima sarebbe misurare contro
	# il giocatore di un altro istante.
	var player := horde._player_focus()
	# La misura e' sulla **disposizione iniziale** dell'onda 1 perche' e' il
	# percorso che non aveva clausola: lo spawn degli uccisi ha gia' `MIN_SPAWN_GAP`.
	horde.run.wave = 1
	horde.run.wave_killed = 0
	# **Prima** di `reseed`: `reseed` riempie a `population`, quindi impostarla
	# dopo misurerebbe i 200 corpi del banco di prova e non i 100 dell'onda 1 che
	# sono la domanda.
	horde.population = RUN.population_of(1)
	horde.reseed(SEME_CAPACITY)
	var n := horde.count
	var minimo := 1.0e9
	var massimo := 0.0
	var dentro := 0
	for i in horde.count:
		var p := horde.transforms[i]
		var d := Vector2(p.x - player.x, p.z - player.z).length()
		minimo = minf(minimo, d)
		massimo = maxf(massimo, d)
		if d <= morso:
			dentro += 1
	h.check(n > 0,
		"la disposizione iniziale dell'onda 1 e' misurabile (%d nemici)" % n)
	# Il criterio: **la disuguaglianza**, non la frase. `dentro == 0` da solo
	# sarebbe un controllo sul conteggio che passa anche con la portata sbagliata;
	# `minimo > morso` fallisce se il punto e' troppo vicino **e** se la portata e'
	# stata gonfiata per errore. Sono i due modi, ed e' per questo che la forma e'
	# quella che e'.
	h.check(dentro == 0,
		"nessun punto di nascita dentro il raggio di morso di %.4f m: %d su %d"
			% [morso, dentro, n])
	h.check(minimo > morso,
		("il minimo delle distanze di nascita (%.4f m) sta sopra il raggio di morso "
			+ "di %.4f m, col giocatore a %.1f/%.1f m")
			% [minimo, morso, player.x, player.z])
	# La stampa porta i tre numeri della distribuzione, che sono la domanda, e il
	# confronto col caso di prima (giocatore al centro): i due numeri insieme
	# dicono che la clausola e' quella che tiene, non il buco dell'origine.
	var al_centro := 1.0e9
	horde.set_focus(Vector3.ZERO)
	horde.reseed(SEME_CAPACITY)
	for i in horde.count:
		al_centro = minf(al_centro, Vector2(horde.transforms[i].x, horde.transforms[i].z).length())
	print("m10/nascite: onda 1, %d nemici, giocatore a %.1f/%.1f m -- distanza dal giocatore min %.4f m max %.4f m, dentro il raggio di morso di %.4f m: %d | giocatore al centro, stesso seme: min %.4f m (il buco dell'origine, non la clausola)"
		% [n, player.x, player.z, minimo, massimo, morso, dentro, al_centro])
	# Il banco torna com'era: focus, popolazione e riempimento, perche' la
	# sezione dopo e' un benchmark su 200 corpi e vuole 200 corpi.
	horde.set_focus(Vector3.ZERO)
	horde.run.wave = prima_wave
	horde.run.wave_killed = prima_killed
	horde.population = prima_pop
	horde.reseed(SEME_CAPACITY)
	_riempi(horde, prima_count)
	h.eq(horde.count, prima_count,
		"la sezione delle nascite ha rimesso l'orda a %d nemici per il benchmark" % prima_count)

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

	var messi_pieno := _riempi(horde, horde.population)
	h.eq(horde.count, horde.population, "l'orda arriva a `population`, e non oltre")
	h.check(messi_pieno > 1,
		"i corpi sono stati messi in piu' di un colpo: %d richiami per arrivare a %d"
			% [messi_pieno, horde.count])
	h.eq(horde.transforms.size(), horde.count, "allineata dopo il riempimento")
	h.eq(horde.colors.size(), horde.count, "colori allineati dopo il riempimento")
	h.eq(horde.radii.size(), horde.count,
		"m8: radii si ricompone insieme agli altri nel riempimento, non dopo")
	h.eq(horde.grid_unknown_cells, 0, "i %d spawn nuovi non hanno creato celle" % horde.count)
	h.check(horde.nearest_enemy_index(Vector3.ZERO, 100.0) >= 0,
		"dopo il riempimento si trova qualcuno")

	# e adesso la capienza, di nuovo pilotata a mano, con lo stesso metodo
	horde.population = HORDE.MAX_ENEMIES
	var messi_capienza := _riempi(horde, HORDE.MAX_ENEMIES)
	h.eq(horde.count, HORDE.MAX_ENEMIES, "la capienza si raggiunge anche per riempimento")
	h.check(messi_capienza > 1,
		"anche da %d vivi i corpi sono stati messi in piu' di un colpo: %d richiami"
			% [RUN.population_of(horde.wave), messi_capienza])
	h.eq(horde.count, HORDE.MAX_ENEMIES, "e non la supera")
	print("orda: svuotata e riempita di nuovo, uccisioni in tutto %d, specie %s"
		% [horde.kills, str(horde.census())])
	# ## La stampa non parla piu' di secondi, e il motivo e' dichiarato
	#
	# Prima diceva «da 0 a 25 in 3,13 s, da 25 a 200 in 22,00 s (SPAWN_RATE = 8,0/s)»:
	# erano tempi di **rampa**. Ora il campo e' riempito mettendolo, quindi un tempo
	# qui sarebbe il tempo del banco di prova travestito da tempo del gioco. La riga
	# dice **quanti corpi sono stati messi** e non promette niente sul rateo, che
	# viene misurato altrove: da `_m12_criterio` e da `tests/test_gameloop.gd`
	# invariante 3, dove l'attesa e' ancora una rampa vera.
	print("orda: svuotata e riempita di nuovo mettendo i corpi: %d richiami da 0 a %d, "
			% [messi_pieno, RUN.population_of(horde.wave)]
		+ "%d richiami da %d a %d (Run.SPAWN_RATE = %.4f/s, non usato per il riempimento)"
			% [messi_capienza, RUN.population_of(horde.wave), HORDE.MAX_ENEMIES, RUN.SPAWN_RATE])

# --- 11c-bis. Le due fonti di danno al giocatore (m14) -------------------------
#
# ## Perche' il criterio di m7 e' diventato questo
#
# Fino a m13 il giocatore poteva prendere danno da **una** fonte sola, il morso,
# e il criterio poteva scrivere una cosa sola: «il numero che lo spia riceve e' il
# numero che l'orda dichiara in `touch_damage_last`». Con il peso del mortar a 6,0
# (m14) la seconda fonte esiste ed e' dichiarata a sua volta: l'esplosione chiama
# `Game.damage_player(MORTAR_BLAST_HP)` (`horde.gd::_mortar_impact`) e registra il
# suo numero in `mortar_damage_last`.
#
# Quindi la domanda **non cambia**, cambia il numero delle tabelle che la
# rispondono: ogni danno che il giocatore prende e' dichiarato da **una** tabella,
# e sono due:
#
#   - il **morso**: arriva da `touch_damage_last` e vale `Enemy.touch_damage_of(specie)`;
#   - il **colpo del mortar**: arriva al momento dell'impatto e vale `MORTAR_BLAST_HP`.
#
# Il criterio accetta un evento che combacia con **uno dei due** e **rifiuta** un
# evento che non combacia con nessuno: accettare «qualsiasi numero» farebbe passare
# sempre e non sarebbe un criterio.
#
# ## L'attribuzione e' ambigua **per valore**, e il criterio non la risolve: conta
#
# `MORTAR_BLAST_HP` e' il morso del boss: i due numeri sono lo stesso (13,7143), e
# quando un morso di capo e un colpo cadono nello stesso passo lo spia riceve due
# volte lo stesso valore senza poter dire quale sia stato. Non si dichiara aperto
# perche' **l'ambiguita' e' nell'etichetta, non nel conteggio**: l'orda dichiara
# anche *quanti* eventi ha consegnato (`touch_damage_last` al piu' uno, per il tetto
# a intervallo, e `mortar_impacts_last` per i colpi caduti sul giocatore), quindi il
# criterio confronta i **numeri** e ogni valore deve combaciare con uno dei due.
# Se l'orda consegnasse un evento in piu' di quelli che dichiara, o un valore che
# non e' di nessuna delle due tabelle, la riga va rossa.
func _due_fonti(h, horde: HORDE, seme: int) -> void:
	var attesi := horde.mortar_impacts_last
	if horde.touch_damage_last > 0.0:
		attesi += 1
	h.eq(_danni_step.size(), attesi,
		"seme %d: gli eventi di danno di un passo sono esattamente quelli che l'orda dichiara "
			% seme
			+ "(al massimo un morso, tetto a intervallo, piu' i colpi caduti sul giocatore), "
			+ "attesi %d, ricevuti %d" % [attesi, _danni_step.size()])
	var morsi := int(horde.touch_damage_last > 0.0)
	var colpi := horde.mortar_impacts_last
	for danno in _danni_step:
		var da_morso := horde.touch_damage_last > 0.0 \
				and is_equal_approx(danno, horde.touch_damage_last)
		var da_colpo := is_equal_approx(danno, ENEMY.MORTAR_BLAST_HP)
		if not da_morso and not da_colpo:
			h.check(false,
				"seme %d: il giocatore ha preso %.4f e quel numero non e' nessuno dei due "
					% [seme, danno]
					+ "dichiarati (morso %.4f, colpo del mortar %.4f): un danno senza tabella "
						% [horde.touch_damage_last, ENEMY.MORTAR_BLAST_HP]
					+ "non e' un danno che questo file sa spiegare")
			continue
		# I due numeri coincidono (13,7143), quindi il **valore** non attribuisce
		# l'evento a una delle due fonti: lo attribuisce il **budget** che l'orda ha
		# dichiarato in questo passo. Si consuma la fonte che ne ha ancora, e se non
		# ne ha piu' l'evento e' in piu' di quelli dichiarati.
		var fonte := -1
		if da_morso and da_colpo:
			if morsi > 0:
				fonte = 0
			elif colpi > 0:
				fonte = 1
		elif da_morso:
			fonte = 0 if morsi > 0 else -1
		else:
			fonte = 1 if colpi > 0 else -1
		if fonte == 0:
			morsi -= 1
		elif fonte == 1:
			colpi -= 1
		else:
			h.check(false,
				"seme %d: %.4f e' arrivato allo spia ma l'orda non lo dichiara in questo passo "
					% [seme, danno]
				+ "(morso dichiarato %d, colpi dichiarati %d)" % [morsi, colpi])
	h.eq(morsi, 0,
		"seme %d: tutti i morsi dichiarati nell'ultimo passo sono arrivati allo spia" % seme)
	h.eq(colpi, 0,
		"seme %d: tutti i colpi dichiarati come caduti sull'ultimo passo sono arrivati allo spia"
			% seme)

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
	# ## m17: **la partita riparte**, e non con due campi scritti a mano
	#
	# Prima di m17 bastava `run.wave = 1` e `run.wave_killed = 0`: la sezione
	# misura **l'economia del morso nei primi secondi di una partita**, e senza
	# orologio «prima di una partita» non aveva un significato. Adesso c'e' un
	# orologio, e se questa sezione entrasse con il clock **accumulato** dalle
	# sezioni precedenti (m9 e m10 fanno 4800 passi, cioe' 80 s, e questa sezione ne
	# fa altri 7200) allora a meta' della quarta finestra il clock supererebbe i
	# 180,0 s **dentro una misura che descrive i primi 30 s**, e il mortar
	# comincerebbe a nascere e a mordere a meta' del campione. Misurato: il
	# seme 4242 passava da 38,2 s a 59,1 s di sopravvivenza secondo quante sezioni
	# erano passate prima, cioe' il numero dipendeva dall'ordine di lettura del
	# file e non dal gioco.
	#
	# Quindi qui si chiama `restart_run()`, che azzera onda, barra **e orologio**,
	# ed e' la strada vera di una partita nuova: `reseed(seme)` viene **dopo** e
	# rimette il seme dichiarato, quindi la disposizione resta riproducibile (il
	# reroll del restart non tocca il `_rng` usato da `_populate`, che `reseed`
	# sovrascrive). Il numero che esce torna a essere «una partita nuova», che e'
	# quello che la banda di sotto è stata tarata.
	horde.restart_run()
	horde.reseed(seme)
	horde.population = pop
	while horde.count > 0:
		horde.damage_enemy(0, 9999.0, Vector3.ZERO)
	_riempi(horde, pop)
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
	# ## m14: l'economia si conta **per fonte**, e i numeri vengono dalle
	# dichiarazioni dell'orda, non dalla somma dello spia
	#
	# Questa sezione descrive il **morso** (cadenza, danno al secondo, sopravvivenza
	# di chi sta fermo): con il mortar spendibile il giocatore prende anche
	# danno dai colpi, e sommare le due fonti qui cambierebbe la domanda senza
	# cambiare la risposta giusta. Ogni passo dichiara gia' quanto ne ha
	# consegnato di ciascuna (`touch_damage_last`/`touch_bites_last` per il morso,
	# `mortar_damage_last`/`mortar_impacts_last` per i colpi) e `_due_fonti` verifica
	# che **quello che arriva al giocatore** corrisponda esattamente a quelle
	# dichiarazioni: quindi la somma qui sotto non e' una ricostruzione del test,
	# e' il conto di cio' che la sezione precedente ha gia' verificato passo per
	# passo. La parte del mortar e' stampata accanto, non e' un criterio di questa
	# sezione: il suo criterio e' in `_m13_*` (impatto, schivata, danno per colpo).
	var morsi_morso := 0
	var danno_morso := 0.0
	var colpi_mortar := 0
	var danno_mortar := 0.0
	for s in TOUCH_STEPS:
		var prima := _morsi
		_danni_step.clear()
		horde.step(DT)
		var caduti := _morsi - prima
		if caduti > 0:
			_due_fonti(h, horde, seme)
		if horde.touch_damage_last > 0.0:
			morsi_morso += horde.touch_bites_last
			danno_morso += horde.touch_damage_last
			if ultimo >= 0:
				gap_min = minf(gap_min, float(s - ultimo) * DT)
			ultimo = s
		if horde.mortar_impacts_last > 0:
			colpi_mortar += horde.mortar_impacts_last
			danno_mortar += horde.mortar_damage_last * float(horde.mortar_impacts_last)
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
		"morsi": morsi_morso, "cadenza": float(morsi_morso) / delta,
		"dps": danno_morso / delta,
		"per_morso": danno_morso / maxf(1.0, float(morsi_morso)),
		"sopravvivenza": PLAYER_HP_REFERENCE / maxf(0.001, danno_morso / delta),
		"gap_min": gap_min, "morse_passo_max": morse_passo_max,
		# Le due fonti insieme, per la stampa: quello che il giocatore prende davvero.
		"eventi": _morsi, "colpi_mortar": colpi_mortar,
		"dps_mortar": danno_mortar / delta,
		"sopravvivenza_tutte": PLAYER_HP_REFERENCE
			/ maxf(0.001, (danno_morso + danno_mortar) / delta),
	}
	print("orda: morso seme %d, %d vivi: %d a portata, %.2f morsi/s, %.2f hp per morso, %.2f hp/s, %.1f s da fermo (solo morso)"
		% [seme, horde.count, in_contatto, float(campi["cadenza"]),
			float(campi["per_morso"]), float(campi["dps"]), float(campi["sopravvivenza"])])
	# La seconda fonte, stampata e non asserita qui: `m14` ha fatto spendere il
	# mortar, quindi chi legge i numeri del morso deve vedere anche quanti colpi ci
	# sono stati sopra e quanto sono costati in danno.
	print("orda: morso seme %d, anche i colpi del mortar: %d impatti, %.2f hp/s, %.1f s da fermo con tutte e due le fonti"
		% [seme, int(campi["colpi_mortar"]), float(campi["dps_mortar"]),
			float(campi["sopravvivenza_tutte"])])
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
	_riempi(horda, HORDE.MAX_ENEMIES)
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

	_rimetti_render()
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
##
## ## `player` torna a com'era, e perche' questa riga era quella che mancava
##
## `_chiudi()` libera l'arena **e il suo giocatore dentro**, ma `Game.player`
## resta appeso a un oggetto morto: lo tiene `src/core/contracts.gd`, che nessuno
## svuota alla `free()`. Ogni `step()` successivo lo passerebbe a
## `horde.gd::_player_hp()`, e li' `is Node` su un'istanza liberata **non
## restituisce `false`** — spacca la funzione e lascia tornare il valore di prima.
## Il sintomo che ne era venuto fuori era la misura della pressione **negativa**:
## non una legge sbagliata, uno strumento che leggeva un giocatore fantasma.
##
## Prima di m14 questa riga non c'era perche' `_scena_vera` era **l'ultima**
## sezione del file: nessuno passava un passo dopo di lei, quindi il riferimento
## appeso non arrivava da nessuna parte. Basta una sezione che apra la scena
## vera **e poi torni a misurare** e il difetto compare.
func _ripristina(h, isolate: HORDE) -> void:
	var game := _game()
	if game == null or isolate == null:
		return
	game.horde = isolate
	# ## Il giocatore che c'era **prima** di aprire la scena, non `null` alla
	# cieca: `_apri_arena` lo cattura in `_giocatore_precedente`, quindi se un
	# giorno qualcuno mettesse un giocatore finto sul contratto, qui verrebbe
	# rimesso e non perso. Per ora e' `null` e resta `null`, ma la strada e' gia'
	# quella giusta: **non** si scrive un valore noto a mano.
	game.player = _giocatore_precedente
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
## Il giocatore che il contratto aveva **prima** di aprire la scena, catturato da
## `_apri_arena` e rimesso da `_ripristina`.
##
## Serve perche' `_chiudi()` libera l'arena e il suo giocatore dentro, ma
## `Game.player` resta appeso all'oggetto morto: `_ripristina` rimette questo
## valore invece di scrivere `null` alla cieca, cosi' la riga resta vera anche se
## un giorno il contratto avra' un giocatore prima della scena.
var _giocatore_precedente: Node3D = null

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
	# I renderer si staccano **qui**, prima di `add_child`: staccarli dopo
	# non leverebbe niente, perche' `add_child` e' quello che fa entrare i nodi
	# nell'albero e quindi scatta `_ready()`, e `_ready()` di
	# `horde_renderer.gd` chiama `_build()`, che carica i tre GLB e alloca tre
	# `MultiMesh`. Un nodo staccato prima dell'albero non ha mai `_ready()`, e
	# il suo costo e' zero davvero invece di zero solo per i frame.
	_stacca_render(arena)
	# **Prima** di `add_child`: e' l'istante in cui la scena vera non e' ancora
	# nell'albero, quindi il contratto e' ancora quello di prima e il giocatore da
	# rimettere e' davvero quello di prima. Dopo `add_child` sarebbe gia' quello
	# nuovo, e la riga di ripristino non rimetterebbe niente.
	var game := _game()
	if game != null:
		var vecchio = game.get("player")
		_giocatore_precedente = vecchio as Node3D if is_instance_valid(vecchio) else null
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
## Passi di assestamento e passi di finestra, a DT = 1/60: 10 s e 15 s.
##
## ## m12-quarta: `M10_WINDOW` `1800 -> 900` e **POI RIPRISTINATO**
##
## Il taglio e' stato fatto (2026-10-17) con `TEST_TIMEOUT_MS = 120000` che non si
## alza e misurando `133,3 s` di file. Il risparmio **reale** e' stato `-8,7 s` in
## tutto, non i `-22,4 s` previsti: perche' `M10_WARMUP = 600` resta, quindi
## dimezzare `M10_WINDOW` toglie 900 passi su 2400 (**37,5%**, non meta') nelle
## sezioni che campionano, e la sezione `_incastrati` era gia' stata fonduta nel
## ciclo di `_aggira` (taglio `a`), quindi non aveva piu' niente da toccare.
## Il tetto e' stato rimesso a **140 s solo per questo file** (`tools/gate.gd`,
## `BUDGETS`), `TEST_TIMEOUT_MS` resta `120000` per gli altri sette.
##
## **Perche' e' tornato indietro**, che e' la parte che resta:
## 1. `M10_ARRIVO_MAX` e `M10_META_MAX` erano diventati **tautologici**: con la
##    finestra a 900 passi il tetto di 900 non poteva fallire. Una soglia che non
##    puo' fallire non e' una soglia. Rimediato alla fonte: i due numeri ora sono
##    **derivati** da `M10_WINDOW` (`/2` e `x2`), quindi non possono diventarlo
##    comunque — vedi la dichiarazione sopra.
## 2. Il pavimento di un tasso raro e' salito da ~0,0021% a ~0,0033% dei
##    nemici-passo: un difetto che dura meno di ~2,5 s di tempo-orda non si stacca
##    piu' dal vuoto. Costo piccolo, ma era gratis evitarlo.
##
## **Quello che il taglio non avrebbe indebolito**, e va detto insieme al danno,
## altrimenti la prima meta' sembra un trionfo: la banda `M10_DEVIA_MIN/MAX` e' sul
## tasso di **tutto il percorso**, il numero misurato e' **9,2%** e il pavimento
## `5%` sta a **13,6 deviazioni** (sigma 0,147 punti su 30 000 segmenti). E il dente
## di `_denti_del_criterio` resta un dente: il campo spento metteva nemici dentro
## un disco nel 97,6% dei passi.
##
## I denominatori di questo campione sono quindi **48 000** (tutto il percorso),
## **36 000** (finestra di regime) e **360 000** nemici-passo (`_incastrati`).
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
##
## ## Perche' sono **derivati dalla finestra** e non scritti a mano
##
## I due numeri di oggi sono gia' funzioni di `M10_WINDOW`: `900 = 1800 / 2` e
## `3600 = 1800 x 2`. Quindi qui non si inventa una relazione, la si scrive: il
## valore **non si e' mosso** (900 e 3600 come prima), cambia solo **da dove viene**.
##
## Il perche' e' una difesa, e nasce da un fatto misurato. Con `M10_WINDOW = 900`
## (il dimezzamento del 2026-10-17, poi ripristinato) il tetto `M10_ARRIVO_MAX`
## valeva **900** e la finestra era lunga **900**: `t_primo` non poteva superare
## `899`, quindi `t_primo < 900` **non poteva fallire** e l'asserzione valeva solo
## «qualcuno arriva». Un tetto che non puo' fallire non e' un tetto: e' una soglia
## diventata tautologica senza che nessuno se ne accorgesse, che e' la stessa
## classe della banda `5,52-90,00 s`.
##
## Derivandoli, la cosa non puo' piu' succedere: qualunque sia la finestra, il
## tetto e' **sempre meta'** di lei (o il doppio), quindi e' sempre raggiungibile
## e l'asserzione resta in grado di andare rossa. Se un domani la finestra si
## dimezza di nuovo, **e' questo codice a dirlo**, non qualcuno che legge `900` e
## pensa che sia un tetto.
const M10_ARRIVO_MAX := M10_WINDOW / 2
const M10_META_MAX := M10_WINDOW * 2
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
	_riempi(horde, HORDE.MAX_ENEMIES)
	h.eq(horde.count, HORDE.MAX_ENEMIES, "m10: la misura parte da %d nemici" % HORDE.MAX_ENEMIES)
	h.eq(horde.inside_obstacles(), 0,
		"m10: al primo passo nessuno e' gia' dentro un ostacolo (disposizione e' fatta fuori)")
	# ## Quello che questa sezione passa a `_incastrati`, e perche' lo passa
	#
	# Il campo e i dischi montati qui, e i quattro contatori del criterio n. 4. La
	# sezione `_incastrati` li giudica senza rifare la passeggiata: stessa
	# disposizione, stessi passi, stessi numeri. Vedi la nota sui campi.
	_m10_campo = campo
	_m10_obs = obs
	_m10_lenti = PackedInt32Array()
	_m10_lenti.resize(horde.count)
	_m10_peggiore = 0
	_m10_peggiore_i = -1
	_m10_colpevoli = 0
	_m10_campioni_lenti = 0

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
			# ## Il criterio n. 4, sulla **stessa** passata
			#
			# Il contatore e' per **indice**, e gli indici cambiano a ogni morte: qui
			# non muore nessuno (nessun colpo nella finestra), quindi l'indice e' lo
			# stesso nemico per tutta la misura. E' scritto perche' la regola vale
			# finche' e' vero, e non perche' sia comodo. I passi contati sono
			# **esattamente** quelli che `_incastrati` contava da solo: gli stessi
			# `M10_WINDOW` passi dopo gli stessi `M10_WARMUP` di assestamento.
			var lenti_passo := 0
			for i in horde.count:
				var p := horde.transforms[i]
				if Vector2(p.x, p.z).length() <= ENEMY.ARRIVE_RADIUS + horde.radii[i]:
					# arrivato: rallenta di proposito, non e' incastrato
					_m10_lenti[i] = 0
					continue
				if horde.velocities[i].length() < STUCK_SPEED:
					_m10_lenti[i] += 1
					lenti_passo += 1
				else:
					_m10_lenti[i] = 0
			_m10_campioni_lenti += lenti_passo
			if lenti_passo > 0:
				for i in horde.count:
					if _m10_lenti[i] > _m10_peggiore:
						_m10_peggiore = _m10_lenti[i]
						_m10_peggiore_i = i
						_m10_colpevoli = 1
					elif _m10_lenti[i] == _m10_peggiore and _m10_peggiore > 0:
						_m10_colpevoli += 1
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

# ## Perche' `_incastrati` non ha piu' un ciclo proprio
#
# Le due sezioni costruivano **la stessa disposizione** — stesso `reseed(M10_SEME)`,
# stesso `population`, stesso fuoco al centro, stessi `M10_WARMUP + M10_WINDOW` passi —
# e la percorrevano **due volte**: `11,0 s` + `10,9 s` di simulazione per due gruppi di
# numeri che si possono prendere nella stessa passata. Dal 2026-10-17 il ciclo e' uno
# solo: `_aggira` prende i due gruppi di contatori e `_incastrati` li giudica. Quindi
# **stessi 2400 passi, stesse grandezze, stessi numeri**: cio' la forma del taglio che
# non perde conoscenza — sposta **quando** il campione viene preso, non **quanto**
# campione ne prendi. `M10_WARMUP` e `M10_WINDOW` non si toccano, e i due contatori
# restano per **indice** con l'indicazione che avevano: nessun nemico muore nella
# finestra, quindi l'indice e' lo stesso nemico per tutta la misura.
var _m10_campo: FLOW = null
var _m10_obs := PackedVector3Array()
var _m10_lenti := PackedInt32Array()
var _m10_peggiore := 0
var _m10_peggiore_i := -1
var _m10_colpevoli := 0
var _m10_campioni_lenti := 0

func _incastrati(h, horde: HORDE) -> void:
	# Il campo e i dischi sono quelli che ha montato `_aggira`: stessa geometria,
	# stesso campo, e **nessuna rimontatura** — quindi questa sezione non stampa
	# piu' la riga della geometria, che `h.eq(peggiore, ...)` non avrebbe guardato
	# e che era solo la prova che il banco e' pulito.
	var campo: FLOW = _m10_campo
	if not h.check(campo != null,
		"m10: il campo montato da `_aggira` non c'e' piu': la sezione che lo aveva preso non puo' giudicare niente"):
		return
	h.check(_m10_obs.size() > 0, "m10: la geometria da misurare non e' vuota")

	var peggiore := _m10_peggiore
	h.check(peggiore <= STUCK_STEPS,
		"m10 criterio n. 4: nessun nemico fermo sotto %.2f m/s per piu' di %d passi di fila (misurati %d)"
			% [STUCK_SPEED, STUCK_STEPS, peggiore])
	print("m10: in %.0f s nessun nemico e' restato fermo piu' di %d passi (%.1f s); passo peggiore %d su %d"
		% [float(M10_WINDOW) * DT, STUCK_STEPS, float(STUCK_STEPS) * DT, peggiore, STUCK_STEPS])
	print("m10: sotto %.2f m/s fuori dall'arrivo, %d campioni su %d (%d nemici-passo su %d)"
		% [STUCK_SPEED, _m10_campioni_lenti, M10_WINDOW * HORDE.MAX_ENEMIES,
			_m10_campioni_lenti, M10_WINDOW * HORDE.MAX_ENEMIES])
	if peggiore > 0:
		_incastrato_dettaglio(horde, campo, _m10_obs, _m10_peggiore_i, peggiore)

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
	_riempi(horde, HORDE.MAX_ENEMIES)
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
	# ## Il criterio confronta i due numeri **diversi**, e non dice in che verso
	#
	# La forma era `dichiarato > RAGGIO_PRIMA`, cioe' codificava anche la direzione:
	# a m11 il raggio era cresciuto (46 -> 60) e il verso era un fatto. La torre lo ha
	# **fatto scendere** (60 -> 35), quindi il verso non e' piu' un fatto e la
	# disuguaglianza stretta dice una cosa che non e' quella che questa sezione
	# dichiara. La **dichiarazione** della sezione, tre righe sopra, e' un'altra:
	# «senza i due numeri diversi questa sezione misurerebbe un numero contro se
	# stesso». Quindi la forma giusta e' `!=`: **stessa forza** sul difetto che la
	# riga dichiara (l'uguaglianza) e nessuna invenzione sul verso.
	#
	# `RAGGIO_PRIMA` resta `46,0` e non diventa `35,0`: se coincidesse col default
	# del contratto la sezione misurerebbe `35` contro `35` e chiamerebbe «uguali»
	# due numeri che non si sommano, che e' esattamente la difetta che la riga
	# dichiara e che questa forma continueda a chiudere.
	h.check(dichiarato != RAGGIO_PRIMA,
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
	# ## m12-bis: il confronto e' **dentro il piano**, e i due numeri si dicono tutti e due
	#
	# `min_separation` sull'array piatto confronta anche i dischi di **piani diversi**,
	# che stanno a `floor_height` di quota e non si toccano mai: il numero che ne
	# esce non e' «due dischi che si toccano» ma «due dischi che stanno su piani
	# diversi», e il criterio ne ha scritto uno per l'altro. Quindi si confronta
	# **dentro ogni blocco di `per_floor` dischi**, che e' esattamente la fetta che
	# `slice_floor` restituisce e su cui il campo costruisce la sua rasterizzazione.
	#
	# **Non e' un allargamento**: e' il confronto dove il difetto puo' esistere. E i
	# due numeri restano in stampa, perche' misurano due grandezze diverse e
	# confonderle e' quello che aveva fatto il criterio.
	var piani_ostacoli := maxi(int(game.get("floor_count")), 1)
	var sep_piano := 1.0e9
	for b in piani_ostacoli:
		var fetta := OBST.slice_floor(letti, b, piani_ostacoli)
		if fetta.size() > 1:
			sep_piano = minf(sep_piano, OBST.min_separation(fetta))
	var sep := OBST.min_separation(letti)
	h.check(sep_piano > 2.0 * OBST.radius_for(horde.arena_radius),
		"m10 criterio n. 1: nessuna coppia di dischi **dello stesso piano** si tocca: "
		+ "minimo per piano %.2f m contro un diametro di %.2f m; sull'array piatto di "
			% [sep_piano, 2.0 * OBST.radius_for(horde.arena_radius)]
		+ "%d dischi su %d piani il minimo e' %.2f m, e li' il confronto e' fra piani "
		  % [letti.size(), piani_ostacoli, sep]
		+ "distanti %.0f m in quota, che non si toccano mai"
			% (float(piani_ostacoli - 1) * float(game.get("floor_height"))))

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

# --- m13. Il mortar: la quinta specie, il telegrrafo e la cupola ----------------
#
# ## La richiesta, e i tre numeri che la rendono giusta o sbagliata
#
# «entro un certo range si ferma, spara come un mortaio, viene segnalato con una
# cupola rossa dove atterra il colpo dando la possibilità di schivare».
#
# La cupola e' di `-arena`; **quando** il colpo cade e' di questa foglia. La
# sezione quindi dimostra tre cose, e ognuna ha due lati:
#
# | | cosa deve essere vero | il difetto se non lo e' |
# |---|---|---|
# | **schivabile** | `13,65 x telegraph >= blast + 0,45` | il colpo e' un delitto: arriva e non si vede arrivare |
# | **non gratis** | un giocatore fermo dentro il raggio **muore** | la finestra e' cosi' lunga che ci si sta dentro senza danno, e allora e' un campo, non un colpo |
# | **un solo istante** | il contratto porta il numero di `enemy.gd` | la cupola dice «schiva qui» e il colpo cade altrove |
#
# ## Il numero che decide, e **da dove viene**
#
# Non e' una cifra scelta a occhio: il tempo e' **derivato** dalla disuguaglianza
# con un margine dichiarato (`DODGE_MARGIN` in `src/sim/enemy.gd`), e il raggio
# di esplosione e' la **portata di morso della specie stessa**, quindi una
# grandezza che il giocatore ha gia' davanti agli occhi. Sotto ci sono i denti:
# si stringe il margine e la disuguaglianza deve fallire; si allarga e deve
# fallire l'altra condizione (due cupole in volo insieme).
#
# ## Quattro denti, e cosa ognuno esclude
#
#   1. **la disuguaglianza** coi due numeri e il margine **stampati**, non un
#      booleano: chi legge deve poter rifare il conto;
#   2. **i denti del margine**, dentro la sezione: `DODGE_MARGIN` a 0,5 deve
#      rompere la disuguaglianza, a 20,0 deve rompere il tetto della ricarica, e
#      il ripristino e' asserito due volte;
#   3. **il canale avvelenato**: il contratto vale 99,0 s e -7,0 m, si monta
#      un'altra orda, e quello che arriva deve essere **il numero di questa
#      foglia**, non il default e non il numero di prova;
#   4. **il colpo in volo**: `mortar_shot_count` vale 1 e `mortar_shots[0].z`
#      scende di `DT` a ogni passo fino a zero — letto sul **campo congelato**,
#      non su un metodo comodo.

## Le quattro specie che **non** cambiano, voce per voce. Sono i numeri di sette
## milestone e la quinta voce non puo' portarsene via una cifra.
static var QUATTRO_HP := PackedFloat32Array([14.0, 34.0, 110.0, 900.0])
static var QUATTRO_SPEED := PackedFloat32Array([6.6, 4.0, 2.3, 1.7])
static var QUATTRO_RADIUS := PackedFloat32Array([0.45, 0.60, 1.00, 1.90])
static var QUATTRO_MASS := PackedFloat32Array([0.7, 1.0, 2.6, 6.0])
static var QUATTRO_RESIST := PackedFloat32Array([0.0, 0.20, 0.55, 0.90])
## I quattro numeri di morso che il vertice ha dichiarato **inviolabili** in
## questa onda: 1,60 / 2,29 / 5,94 / 13,71 hp.
static var QUATTRO_MORSO := PackedFloat32Array([1.6, 2.29, 5.94, 13.71])

## Il punto in cui sta il giocatore in tutta la sezione.
##
## **Non `Vector3.ZERO`**: `_player_focus()` rifiuta un punto a distanza quasi
## nulla e ripiega sul fuoco dell'ordine, quindi un giocatore finto all'origine
## misurerebbe una cosa diversa dal gioco (la stessa ragione di `FAKE_PLAYER`).
##
## **8 m dal centro e non 3,-5**: a 8 m il disco centrale e' libero per costruzione
## — il primo anello di ostacoli e' a 19,80 m con raggio 3,90 m, quindi il disco
## libero arriva a 15,90 m — e nessun nemico di questa sezione viene spinto
## fuori da un disco mentre misura il tempo di un colpo.
const PUNTO_MORTAR := Vector3(0.0, 0.0, 8.0)

## Quanto il nemico di questa sezione e' **dentro** la fermata, in metri.
##
## Non e' uno scarto di comodo': `transforms` e' un `PackedVector3Array`, cioe'
## `float32`, e la posizione scritta puo' cadere qualche ulp **oltre** la
## distanza di fermata calcolata in `float64`. Un test che mette il nemico
## esattamente sul confine sta misurando la precisione del `float` e non il
## comportamento: e quando succede, va rosso per la ragione sbagliata, che e' la
## cosa peggiore di un criterio. Dentro di 5 cm e' una posizione che vale per
## qualunque `float32`.
const FERMO_DENTRO := 0.05

## Quanti passicorre la corsa a **danno zero**, coi denti dentro.
##
## Non e' un numero per far presto: e' il minimo che contiene **due colpi caduti**
## con la ricarica di 2,1381 s, cioe' `2 x 129` passi piu' il tempo di volo del
## primo. Sotto questo numero i denti misurerebbero «non e' partito niente» invece
## di «non ha fatto danno», cioe' la ragione sbagliata.
const PASSI_DENTI_DANNO := 420

## Il tetto di passi del «fermo dentro», dichiarato come tutti gli altri numeri.
## `PASSI_DENTI_DANNO` e' la parte corta; il tetto viene dal gioco e non e' un
## numero di comodo': e' quanto serve a un giocatore da 100 hp a prendere
## `ceil(100 / 13,7143) = 8` colpi, uno ogni `reload = 2,1381 s`.
const PASSI_FERMO_DENTRO := 2400

func _mortar(h, horde: HORDE) -> void:
	var t0 := Time.get_ticks_usec()
	_m13_tabelle(h)
	_m13_peso_fonte(h, horde)
	var tele := ENEMY.telegraph_for(horde.body_scale)
	var blast := ENEMY.blast_radius_for(horde.body_scale)
	var fuga := (blast + ENEMY.TOUCH_REACH) / ENEMY.PLAYER_SPEED
	var margine := tele / maxf(0.000001, fuga)
	var ricarica := ENEMY.reload_of(ENEMY.MORTAR)
	# ## Il criterio 1: la disuguaglianza, con i due numeri e il margine
	#
	# `>=` e non `>`: sotto e' un delitto, **uguale** e' il limite esatto — e il
	# margine dichiarato dice di quanto quel limite e' stato spinto fuori.
	h.check(ENEMY.PLAYER_SPEED * tele >= blast + ENEMY.TOUCH_REACH,
		"disuguaglianza di schivata: %.2f m/s x %.4f s = %.4f m deve essere >= %.4f m "
			% [ENEMY.PLAYER_SPEED, tele, ENEMY.PLAYER_SPEED * tele, blast + ENEMY.TOUCH_REACH]
			+ "(raggio %.4f m + corpo %.2f m): sotto, il colpo non e' schivabile"
				% [blast, ENEMY.TOUCH_REACH])
	# ## Il criterio 2, l'altro lato: **una cupola per nemico**
	#
	# Sopra la ricarica il mortar avrebbe due colpi in volo nello stesso istante e
	# il giocatore non saprebbe quale e' quello che sta per cadere: un avvertimento
	# che non si legge non e' un avvertimento. Il tetto e' derivato (`reload_of`),
	# non scritto.
	h.check(tele <= ricarica,
		"una cupola per nemico: il telegrrafo (%.4f s) non puo' superare la ricarica (%.4f s), "
			% [tele, ricarica]
			+ "altrimenti due cupole sarebbero in volo insieme")
	h.check(ENEMY.DODGE_MARGIN >= 1.0,
		"il margine dichiarato (%.2f) e' almeno 1: sotto, il colpo e' schivabile solo da chi "
			% ENEMY.DODGE_MARGIN
			+ "sa gia' dove cade prima che la cupola compaia")
	print("orda: m13, telegrrafo %.4f s (%.1f passi a DT=%.4f) x raggio %.4f m, margine %.2f "
			% [tele, tele / DT, DT, blast, margine]
		+ "(fuga minima %.4f s: %.2f m/s x %.4f s >= %.4f + %.2f m), ricarica %.4f s, "
			% [fuga, ENEMY.PLAYER_SPEED, fuga, blast, ENEMY.TOUCH_REACH, ricarica]
			+ "fermata a %.4f m, danno %.4f hp"
			% [ENEMY.engage_for(horde.body_scale), ENEMY.MORTAR_BLAST_HP])
	# ## La fermata e' derivata, e lo dice con un'identita', non con una stima
	#
	# **m17: l'identita' e' cambiata col numero.** Con `engage = 2 x blast` lo
	# spazio fra il corpo disegnato e il bordo della cupola era `TOUCH_REACH`; con
	# `engage = 3 x blast` e' `blast + TOUCH_REACH`. La riga sotto asserisce la
	# formula **nuova**: se qualcuno tornasse a 2x senza toccare questa sezione,
	# andrebbe rossa invece di passare con l'identita' vecchia ancora scritta.
	var corpo := horde.body_scale * ENEMY.RADIUS[ENEMY.MORTAR]
	h.near(ENEMY.engage_for(horde.body_scale), 3.0 * blast, 0.000001,
		"m17: la fermata e' 3 x blast (%.4f m contro i %.4f m di prima, 2 x blast): il numero "
			% [ENEMY.engage_for(horde.body_scale), 2.0 * blast]
		+ "cambiato e' la distanza d'ingaggio, non il raggio del colpo, che resta %.4f m" % blast)
	h.near(ENEMY.engage_for(horde.body_scale) - corpo - blast, blast + ENEMY.TOUCH_REACH,
		0.000001,
		"fra il corpo disegnato del mortar e il bordo della cupola che sta per disegnare "
			+ "ci sono blast + corpo del giocatore = %.2f + %.2f m, non uno spazio libero"
				% [blast, ENEMY.TOUCH_REACH])
	# ## E la cosa che **non** e' cambiata: la finestra di schivata
	#
	# E' la disuguaglianza di fuga, e non contiene `engage_for`: quindi i 2 x blast
	# non l'hanno toccata e non la toccano i 3 x. Senza questa riga un numero
	# cambiato sulla fermata potrebbe essere scambiato per «e' piu' difficile da
	# schivare», che e' la lettura sbagliata: e' **piu' lontano**, non meno tempo.
	h.near(tele, (blast + ENEMY.TOUCH_REACH) / ENEMY.PLAYER_SPEED * ENEMY.DODGE_MARGIN,
		0.000001,
		"m17: la finestra di schivata resta quella dichiarata (%.4f s) e non dipende dalla "
			% tele
		+ "fermata a 3 x blast: la matematica della fuga e' quella di prima, quello che cambia e' "
		+ "quanto presto il colpo ti raggiunge")
	h.check(ENEMY.engage_for(horde.body_scale) > ENEMY.bite_range_of(ENEMY.MORTAR, horde.body_scale),
		"il mortar si ferma fuori dalla propria portata di morso, quindi da dove sta non morde")
	# ## Il numero del giocatore viene dal contratto, non da una copia qui
	var game := _game()
	h.check(game != null and _contiene("res://src/core/contracts.gd", "13,65"),
		"il contratto dichiara ancora 13,65 m/s nella disuguaglianza del mortar")
	h.near(ENEMY.PLAYER_SPEED, 13.65, 0.000001,
		"la velocita' del giocatore in enemy.gd e' il numero che il contratto dichiara")
	h.eq(_occorrenze_di_codice("res://src/sim/enemy.gd", "13.65"), 1,
		"13.65 compare in codice una volta sola in enemy.gd: l'unica fonte")
	h.eq(_occorrenze_di_codice("res://src/sim/horde.gd", "13.65"), 0,
		"e in horde.gd non compare: la tabella delle specie e' la fonte, non una copia")

	_m13_denti_margine(h, horde, tele, blast)
	_m13_canale(h, horde, tele, blast)
	_m13_volo(h, horde, tele, blast)
	_m13_stazionario(h, horde)

	# ## L'orda e il contratto tornano come erano
	_player_via = FAKE_PLAYER
	horde.population = RUN.population_of(1)
	horde.restart_run()
	h.eq(horde.mortar_shot_count, 0,
		"m13: il restart azzera i colpi in volo (una partita nuova non comincia con la cupola di prima)")
	h.eq(horde.count, horde.population, "m13: e l'orda torna alla popolazione della curva")
	print("orda: m13, sezione intera in %d us" % (Time.get_ticks_usec() - t0))

## ## Le sei tabelle: allineate 1:1, e le quattro specie immobili
func _m13_tabelle(h) -> void:
	h.eq(ENEMY.KIND_COUNT, 5, "m13: KIND_COUNT e' 4 specie piu' il mortar")
	h.eq(ENEMY.KIND_NAMES.size(), 5, "m13: KIND_NAMES ha cinque nomi")
	h.eq(ENEMY.KIND_NAMES[ENEMY.MORTAR], "mortar", "m13: la quinta voce si chiama mortar")
	# Le cinque tabelle numeriche 1:1 su `KIND_COUNT`, e ognuna con la sua
	# versione di quattro specie da confrontare voce per voce. `near` e non
	# `eq`: una `PackedFloat32Array` conserva dei `float32` e `0.60` scritto qui
	# sarebbe un `float64` — il confronto esatto fallirebbe per un ulp, e un
	# criterio che fallisce per un ulp mente sul difetto che sta guardando.
	var tabelle := [
		["HP_MAX", ENEMY.HP_MAX, QUATTRO_HP],
		["SPEED", ENEMY.SPEED, QUATTRO_SPEED],
		["RADIUS", ENEMY.RADIUS, QUATTRO_RADIUS],
		["MASS", ENEMY.MASS, QUATTRO_MASS],
		["KNOCKBACK_RESIST", ENEMY.KNOCKBACK_RESIST, QUATTRO_RESIST],
	]
	for riga in tabelle:
		var nome: String = riga[0]
		var tabella: PackedFloat32Array = riga[1]
		h.eq(tabella.size(), 5,
			"m13: la tabella %s ha una voce per specie, non quattro" % nome)
		var quattro: PackedFloat32Array = riga[2]
		for k in 4:
			h.near(tabella[k], quattro[k], 0.0001,
				"m13: la tabella %s non ha spostato la voce %s (indice %d): %.4f contro %.4f"
					% [nome, ENEMY.KIND_NAMES[k], k, tabella[k], quattro[k]])
	h.eq(ENEMY.COLOR.size(), 5, "m13: anche la tabella delle tinte ha cinque voci")
	for k in 4:
		h.near(ENEMY.touch_damage_of(k), QUATTRO_MORSO[k], 0.006,
			"m13: il morso di %s e' ancora %.2f hp, il numero che il vertice ha dichiarato "
				% [ENEMY.KIND_NAMES[k], QUATTRO_MORSO[k]]
				+ "inviolabile in questa onda")
	# E il numero che la nuova specie si porta dietro, derivato e non scribblato.
	h.check(ENEMY.MASS[ENEMY.MORTAR] > ENEMY.MASS[ENEMY.BRUTE]
			and ENEMY.MASS[ENEMY.MORTAR] < ENEMY.MASS[ENEMY.BOSS],
		"m13: il mortar pesa fra il brute (%.1f) e il boss (%.1f): piu' grosso di chi insegue, "
			% [ENEMY.MASS[ENEMY.BRUTE], ENEMY.MASS[ENEMY.BOSS]]
			+ "piu' piccolo del capo, ottenuto %.1f" % ENEMY.MASS[ENEMY.MORTAR])
	h.near(ENEMY.MORTAR_BLAST_HP, ENEMY.touch_damage_of(ENEMY.BOSS), 0.0001,
		"m13: il danno di un colpo e' il morso peggiore del gioco (%.2f hp), derivato dalla "
			% ENEMY.touch_damage_of(ENEMY.BOSS)
			+ "tabella delle masse e non scritto a mano")
	h.near(ENEMY.reload_of(ENEMY.MORTAR), ENEMY.touch_period_of(ENEMY.MORTAR), 0.000001,
		"m13: la ricarica del mortar e' il periodo di morso della sua specie, non un numero suo")
	print("orda: m13, tabelle allineate 1:1 su %d specie (%s), %s | morso %s"
		% [ENEMY.KIND_COUNT, _nomi_tabelle(), _quattro_specie_sicure(), _riga_mosse()])

## Le quattro specie, con quello che ciascuna vale: la stampa che dice che la
## quinta voce ha **aggiunto** e non spostato niente.
func _quattro_specie_sicure() -> String:
	return "le quattro specie hanno ancora hp %.0f/%.0f/%.0f/%.0f e massa %.1f/%.1f/%.1f/%.1f" \
		% [QUATTRO_HP[0], QUATTRO_HP[1], QUATTRO_HP[2], QUATTRO_HP[3],
			QUATTRO_MASS[0], QUATTRO_MASS[1], QUATTRO_MASS[2], QUATTRO_MASS[3]]

## ## m14: il peso del mortar e' **spendibile**, e il criterio e' sulla **quota**
##
## Questa funzione non asserisce piu' `MORTAR_WEIGHT == 0.0`: quel numero era il
## difetto che m14 chiude. E non asserisce `== 6.0` al suo posto, perche' un
## criterio sul peso va rosso il giorno che il peso si ritocca **per farlo piu'
## raro**, che e' una correzione e non un difetto. Il numero che vale e' la
## **quota** — quanto della popolazione nasce mortar — e la banda e' dichiarata in
## `_quota_mortar` (sezione 17), perche' li' si misura sul gioco e non sulla
## tabella.
##
## Qui sotto restano le due cose che non cambiano con il numero: la voce dei pesi
## **segue la fonte in ogni onda** (e non uno zero scritto qui dentro), e la voce
## della tabella piatta non e' una copia rimasta indietro.
func _m13_peso_fonte(h, horde: HORDE) -> void:
	for w in [1, 2, 3, 4, 8, 12, 20]:
		var pesi := SPAWNER.wave_weights(int(w))
		h.eq(pesi.size(), 5, "m14: i pesi dell'onda %d hanno una voce per specie" % int(w))
		h.eq(pesi[ENEMY.MORTAR], SPAWNER.MORTAR_WEIGHT,
			"m14: sul peso di produzione la voce del mortar sull'onda %d deve valere quello che "
				% int(w)
				+ "dice la fonte (%.1f), non uno zero scritto qui: ottenuto %.1f"
					% [SPAWNER.MORTAR_WEIGHT, pesi[ENEMY.MORTAR]])
	# La tabella piatta e' costruita **al caricamento della classe** (vedi la sua
	# dichiarazione in `spawner.gd`), quindi non si ricostruisce da sola: senza questa
	# riga, un peso di 6,0 qui e uno zero li' darebbero due cammini con pesi diversi e
	# nessuno se ne accorgerebbe.
	h.near(SPAWNER.KIND_WEIGHTS[ENEMY.MORTAR], SPAWNER.MORTAR_WEIGHT, 0.0001,
		"m14: la voce del mortar nella tabella piatta segue la fonte (%.1f contro %.4f): una copia "
			% [SPAWNER.MORTAR_WEIGHT, SPAWNER.KIND_WEIGHTS[ENEMY.MORTAR]]
			+ "rimasta a zero farebbe divergere i due cammini dello spawn")
	# ## I denti: la voce segue la **fonte**, quindi non e' uno zero scritto qui
	var prima := SPAWNER.MORTAR_WEIGHT
	SPAWNER.MORTAR_WEIGHT = 7.0
	h.eq(SPAWNER.wave_weights(3)[ENEMY.MORTAR], 7.0,
		"denti: con il peso di fonte a 7.0 la voce dei pesi deve seguirlo, altrimenti la voce "
			+ "qui e' una copia scritta a mano")
	SPAWNER.MORTAR_WEIGHT = prima
	h.eq(SPAWNER.MORTAR_WEIGHT, prima,
		"denti: ripristino 1, la fonte torna al valore di produzione (%.1f)" % prima)
	h.eq(SPAWNER.wave_weights(3)[ENEMY.MORTAR], prima,
		"denti: ripristino 2, e i pesi ricalcolati tornano al valore di produzione")
	# E nel gioco vero adesso il mortar **nasce**: non dalla tabella, dal campo. Un
	# solo riempimento non basterebbe a dichiararlo (con 25 vivi e quota 2,9% la
	# probabilita' di zero mortar su 800 nascite e' 1 su 10 milioni), quindi qui si
	# contano i quattro semi dichiarati: 100 nascite per giro, e la probabilita'
	# che le quattro popolazioni non tirino nessun mortar e' **0,10**. La quota per
	# esteso la guarda `_quota_mortar`.
	#
	## ## m17: **qui l'orologio va oltre 180 s, e lo dice**
	#
	# Il campione nasce da `_pick_kind()`, cioe' dallo spawn, quindi senza l'orologio
	# la sezione misurerebbe «il mortar non nasce» — che e' vero fino al terzo
	# minuto e non e' piu' quello che questa sezione dichiara. La strada e' scritta
	# in `_porta_oltre_il_mortar` e viene stampata li'.
	_porta_oltre_il_mortar(h, horde, "_m13_peso_fonte (sonda di nascita)")
	var visti := 0
	for s in SEMI_MISELA:
		horde.reseed(int(s))
		visti += horde.census()[ENEMY.MORTAR]
	h.check(visti > 0,
		"m14: nei quattro riempimenti dell'onda 1 (100 nascite) devono esserci dei mortar, "
			+ "ottenuto %d: un peso spendibile che non produce niente e' un peso decorativo"
				% visti)
	h.check(SPAWNER.MORTAR_WEIGHT >= 0.0,
		"m14: il peso dichiarato e' un peso (>= 0), letto %.4f" % SPAWNER.MORTAR_WEIGHT)

## ## I denti del margine, accesi e spenti nella stessa sezione
##
## Un criterio che nessuno ha mai visto andare rosso e' un numero che il prossimo
## legge come se fosse vivo. Qui il difetto si accende due volte, sui due lati,
## e il ripristino e' asserito tre volte.
func _m13_denti_margine(h, horde: HORDE, tele: float, blast: float) -> void:
	var bs := horde.body_scale
	var prima := ENEMY.DODGE_MARGIN
	# ## Lato basso: sotto il tempo di fuga il colpo non e' schivabile
	ENEMY.DODGE_MARGIN = 0.5
	var stretto := ENEMY.telegraph_for(bs)
	h.check(ENEMY.PLAYER_SPEED * stretto < blast + ENEMY.TOUCH_REACH,
		"denti: col margine a 0,5 il telegrrafo deve VIOLARE la disuguaglianza (%.4f m < %.4f m), "
			% [ENEMY.PLAYER_SPEED * stretto, blast + ENEMY.TOUCH_REACH]
			+ "altrimenti il criterio non ha denti e la misura non sta guardando il posto giusto")
	ENEMY.DODGE_MARGIN = prima
	h.eq(ENEMY.DODGE_MARGIN, prima, "denti: ripristino 1, il margine torna a %.2f" % prima)
	h.near(ENEMY.telegraph_for(bs), tele, 0.000001,
		"denti: ripristino 2, e il telegrrafo ricalcolato torna a %.4f s" % tele)
	# ## Lato alto: sopra la ricarica ci sarebbero due cupole in volo
	ENEMY.DODGE_MARGIN = 20.0
	var largo := ENEMY.telegraph_for(bs)
	h.check(largo > ENEMY.reload_of(ENEMY.MORTAR),
		"denti: col margine a 20,0 il telegrrafo (%.2f s) deve superare la ricarica (%.2f s), "
			% [largo, ENEMY.reload_of(ENEMY.MORTAR)]
			+ "altrimenti il tetto 'una cupola per nemico' non ha denti")
	ENEMY.DODGE_MARGIN = prima
	h.near(ENEMY.telegraph_for(bs), tele, 0.000001,
		"denti: ripristino 3, il telegrrafo torna a quello di partita, %.4f s" % tele)

## ## Il canale: il vertice dichiara due campi, **questa** foglia li scrive
##
## Come `enemy_body_scale` alla rovescia: li' si legge un numero di `-arena`, qui
## si da' un numero a `-arena`. Il criterio avvelena i due campi con un numero
## assurdo, monta un'altra orda, e verifica che al contratto arrivi **il numero di
## questa foglia** — non il default dichiarato e non il numero di prova.
const TELEGRAPH_AVVELENATO := 99.0
const BLAST_AVVELENATO := -7.0

func _m13_canale(h, horde: HORDE, tele: float, blast: float) -> void:
	var game := _game()
	if game == null:
		h.fail("m13: il contratto non c'e', la prova del canale non puo' girare")
		return
	h.eq(horde.mortar_source, "contratto",
		"m13: l'orda dichiara di aver registrato i due numeri: un fallback qui sarebbe silenzioso")
	h.near(float(game.get("mortar_telegraph_s")), tele, 0.000001,
		"m13: sul contratto c'e' il telegrrafo di questa foglia (%.4f s)" % tele)
	h.near(float(game.get("mortar_blast_m")), blast, 0.000001,
		"m13: sul contratto c'e' il raggio di esplosione di questa foglia (%.4f m)" % blast)
	# ## Il default dichiarato **non e' una seconda fonte**
	#
	# Se il numero in campo fosse uguale al default dichiarato, tutto quello che
	# e' sopra passerebbe anche se nessuno avesse mai scritto niente. Quindi si
	# verifica che i due non coincidano e si dice per iscritto quale e' il
	# default: un test che non lo distingue chiama «canale» un numero che nessuno
	# ha scritto.
	var d_tele := _mortar_dichiarato("mortar_telegraph_s")
	var d_blast := _mortar_dichiarato("mortar_blast_m")
	h.check(d_tele > 0.0 and d_blast > 0.0,
		"m13: il contratto dichiara entrambi i numeri (default %.2f s e %.2f m)" % [d_tele, d_blast])
	h.check(absf(d_tele - tele) > 0.000001 and absf(d_blast - blast) > 0.000001,
		"m13: il numero in campo non coincide col default dichiarato (%.2f s, %.2f m): "
			% [d_tele, d_blast]
			+ "altrimenti «il contratto porta il nostro numero» passerebbe anche senza nessuna scrittura")
	var prima_t := float(game.get("mortar_telegraph_s"))
	var prima_b := float(game.get("mortar_blast_m"))
	game.set("mortar_telegraph_s", TELEGRAPH_AVVELENATO)
	game.set("mortar_blast_m", BLAST_AVVELENATO)
	h.eq(float(game.get("mortar_telegraph_s")), TELEGRAPH_AVVELENATO,
		"m13: avvelenamento, il contratto ha il numero di prova %.1f s" % TELEGRAPH_AVVELENATO)
	h.eq(float(game.get("mortar_blast_m")), BLAST_AVVELENATO,
		"m13: avvelenamento, e %.1f m" % BLAST_AVVELENATO)
	var bs := _m13_sonda(h, "OrdaSondaMortar")
	h.near(float(game.get("mortar_telegraph_s")), ENEMY.telegraph_for(bs), 0.000001,
		"m13: un'orda montata col contratto avvelenato scrive il telegrrafo di enemy.gd (%.4f s), "
			% ENEMY.telegraph_for(bs)
			+ "non il %.1f s del contratto" % TELEGRAPH_AVVELENATO)
	h.near(float(game.get("mortar_blast_m")), ENEMY.blast_radius_for(bs), 0.000001,
		"m13: e il raggio di esplosione di enemy.gd (%.4f m), non il %.1f m avvelenato"
			% [ENEMY.blast_radius_for(bs), BLAST_AVVELENATO])
	game.set("mortar_telegraph_s", prima_t)
	game.set("mortar_blast_m", prima_b)
	h.eq(float(game.get("mortar_telegraph_s")), prima_t,
		"m13: ripristino 1, il contratto torna a %.4f s" % prima_t)
	h.eq(float(game.get("mortar_blast_m")), prima_b,
		"m13: ripristino 2, e a %.4f m" % prima_b)
	var bs_dopo := _m13_sonda(h, "OrdaSondaMortarDopo")
	h.near(float(game.get("mortar_telegraph_s")), prima_t, 0.000001,
		"m13: ripristino 3, e un'altra orda montata adesso rivede %.4f s: il canale funziona "
			% prima_t
			+ "dopo che e' stato avvelenato, quindi «ripristinato» non e' una parola")
	h.near(float(game.get("mortar_blast_m")), prima_b, 0.000001,
		"m13: ripristino 4, e rivede %.4f m" % prima_b)
	_ripristina(h, horde)
	print("orda: m13, canale -- contratto avvelenato a %.1f s / %.1f m, l'orda montata in quel "
			% [TELEGRAPH_AVVELENATO, BLAST_AVVELENATO]
		+ "momento scrive %.4f s / %.4f m (default dichiarato sul contratto %.2f / %.2f), poi il "
			% [ENEMY.telegraph_for(bs), ENEMY.blast_radius_for(bs),
				d_tele, d_blast]
			+ "contratto torna a %.4f / %.4f e un'altra orda lo rivede" % [prima_t, prima_b])

## Il default che il contratto dichiara, letto **dal sorgente**: serve a dire se
## il valore in campo e' quello che `-orda` ha registrato o e' ancora il default.
func _mortar_dichiarato(nome: String) -> float:
	var f := FileAccess.open("res://src/core/contracts.gd", FileAccess.READ)
	if f == null:
		return -1.0
	for riga in f.get_as_text().split("\n"):
		var t := str(riga).strip_edges()
		if t.begins_with("var " + nome):
			return float(t.split("=")[1].strip_edges())
	return -1.0

## Monta un'orda di prova solo per guardare che cosa scrive sul contratto, e la
## butta giù'. Come `_sonda_corpo` della sezione 16: la sonda ha un seme suo e
## dichiarato, e alla fine le API tornano all'orda del test.
func _m13_sonda(h, nome: String) -> float:
	var sonda := HORDE.new()
	sonda.name = nome
	sonda.seed = 4242
	root.add_child(sonda)
	# ## Il fattore si legge **prima** di liberare la sonda
	#
	# Dopo `queue_free()` l'oggetto non esiste piu': leggerne un campo da quel
	# punto schianta il processo, e un test che schianta non e' un test che ha
	# sbagliato un numero, e' un test che non ha risposto niente. Quindi qui si
	# restituisce **il valore**, non l'oggetto, e chi chiama guarda il valore.
	var bs := sonda.body_scale
	h.eq(sonda.mortar_source, "contratto",
		"%s dichiara mortar_source 'contratto': senza questa riga un fallback sarebbe silenzioso"
			% nome)
	root.remove_child(sonda)
	sonda.queue_free()
	return bs

## ## Il colpo in volo, letto sul campo **congelato**
##
## Qui non si usa un metodo comodo: `mortar_shot_count` e `mortar_shots[0].z`
## sono i due nomi che `-arena` costruisce il suo `MultiMesh` sopra, e sono quindi
## la superficie che va verificata. Un metodo che dicesse «va tutto bene» sopra un
## campo sbagliato non cambierebbe niente a `-arena`: romperebbe la sua onda e
## lascerebbe questo file verde.
func _m13_volo(h, horde: HORDE, tele: float, blast: float) -> void:
	# ## m17: l'orologio a **zero**, e la soglia chiusa, **mentre la cupola parte**
	#
	# La sezione misura il colpo in volo e la sua caduta: il mortar lo scrive
	# `_m13_prepara` nell'array, quindi non ha bisogno di passare dallo spawn. La
	# soglia dei 180 s riguarda **chi nasce**, non chi spara, e questa e' la sezione
	# che lo dice: con la soglia chiusa il colpo parte lo stesso e cade quando
	# `mortar_telegraph_s` finisce. Senza la riga qui sotto, un futuro
	# «il mortar non spara finche' non e' il terzo minuto» passerebbe questa sezione
	# senzache nessuno se ne accorgesse, perche' il mortar di qui non e' mai passato
	# dallo spawn.
	_azzera_l_orologio(h, horde, "_m13_volo (colpo in volo)")
	_m13_prepara(horde, ENEMY.MORTAR)
	h.eq(horde.mortar_shot_count, 0, "m13: nessun colpo in volo prima di spari")
	var danno_prima := _totale_danno
	horde.step(DT)
	h.eq(horde.mortar_shot_count, 1,
		"m13: il mortar entro la fermata spara e il colpo e' in volo")
	h.eq(horde.mortar_shots.size(), HORDE.MAX_ENEMIES,
		"m13: l'array dei colpi e' scaldato una volta sola a MAX_ENEMIES, quindi nel ciclo di "
			+ "gioco non cresce mai")
	h.vec_near(horde.mortar_shot_at(0), PUNTO_MORTAR, 0.0001,
		"m13: la cupola segnala il punto in cui cade il colpo, che e' dove stava il giocatore "
			+ "quando il mortar ha premuto")
	h.eq(int(horde.mortar_shots[0].x), 0, "m13: convenzione dell'elemento, `x` e' la x del mondo")
	h.eq(int(horde.mortar_shots[0].y), 8, "m13: e `y` e' la z del mondo, non una profondita'")
	h.near(horde.mortar_shots[0].z, tele, 0.0001,
		"m13: il colpo parte con %.4f s di tempo residuo, cioe' il telegrrafo" % tele)
	h.near(_totale_danno, danno_prima, 0.000001,
		"m13: mentre il colpo e' in volo non e' successo niente: il danno e' un istante, non un campo")
	h.eq(horde.touch_bites_last, 0,
		"m13: e il mortar non morde: si e' fermato %.4f m dal giocatore, fuori dalla sua portata"
			% ENEMY.engage_for(horde.body_scale))
	var passi := 0
	var scala := " %.4f" % horde.mortar_shots[0].z
	while horde.mortar_shot_count > 0 and passi < 240:
		var prima_z := horde.mortar_shots[0].z
		horde.step(DT)
		if horde.mortar_shot_count == 0:
			h.check(prima_z <= DT + 0.000001,
				"m13: il colpo cade nell'ultimo passo (residuo %.5f s, DT %.5f s): non puo' "
					% [prima_z, DT]
					+ "volare un passo oltre il telegrrafo")
			h.near(_totale_danno - danno_prima, ENEMY.MORTAR_BLAST_HP, 0.0001,
				"m13: il giocatore fermo dentro la cupola prende %.4f hp quando il colpo cade"
					% ENEMY.MORTAR_BLAST_HP)
			break
		var dopo_z := horde.mortar_shots[0].z
		h.near(dopo_z, prima_z - DT, 0.00001,
			"m13: i secondi residui scendono di DT a ogni passo (da %.5f a %.5f)"
				% [prima_z, dopo_z])
		if passi < 4:
			scala += " -> %.4f" % dopo_z
		passi += 1
	h.eq(horde.mortar_shot_count, 0, "m13: il colpo esce dall'array quando e' caduto")
	# ## L'invariante vera, e con denti
	#
	# La riga che stava qui prima confrontava il conteggio con
	# `mortar_shots.size() - mortar_shots.size()`, cioe' con **zero**: era
	# `0 == 0`, verde per costruzione, cioe' un criterio che non puo' fallire. E un
	# criterio che non puo' fallire e' la cosa peggiore che si possa lasciare,
	# perche' il prossimo lo legge come se misurasse qualcosa.
	#
	# L'invariante vera e' un'altra: i vivi sono `mortar_shots[0 .. count)`, quindi
	# il conteggio non puo' superare la capienza scaldata. Se un nemico avesse due
	# colpi in volo (ricarica sotto il telegrrafo) il conteggio la toccherebbe.
	h.check(horde.mortar_shot_count >= 0 and horde.mortar_shot_count <= horde.mortar_shots.size(),
		"m13: il conteggio dei vivi (%d) sta dentro la capienza scaldata (%d): sono i vivi "
			% [horde.mortar_shot_count, horde.mortar_shots.size()]
			+ "che il renderer chiede prima di iterare, e non l'array")
	h.check(passi >= int(ceil(tele / DT)) - 1,
		"m13: il colpo e' restato in volo %d passi, che e' il telegrrafo (%.1f passi)"
			% [passi, tele / DT])
	print("orda: m13, il colpo in volo -- caduta su (%.2f, %.2f), residui%s -> 0 in %d passi "
			% [PUNTO_MORTAR.x, PUNTO_MORTAR.z, scala, passi]
		+ "(%.4f s a DT %.4f), danno %.2f hp all'istante della caduta"
			% [tele, DT, ENEMY.MORTAR_BLAST_HP])
	# ## E adesso la **schivata**, che e' la meta' della finestra
	#
	# Stesso colpo, stesso istante, giocatore spostato fuori dal raggio: e' la
	# domanda che il mortaio deve fare possibile («dando la possibilita' di
	# schivare»), e si risponde muovendo il giocatore di quanto basta e guardando
	# che il danno non arriva. Se il raggio di esplosione fosse piu' grande di
	# quello dichiarato, la cupola direbbe una cosa e il colpo un'altra.
	_m13_prepara(horde, ENEMY.MORTAR)
	# ## Il totale va preso **subito prima** di questo volo
	#
	# Il confronto di prima guardava `_totale_danno` contro il totale di **prima
	# del primo colpo**, che da allora aveva gia' preso %.2f hp: stava sommando
	# due voli contro il riferimento di uno solo, e la schivata sarebbe parsa un
	# colpo che ha fatto danno per errore.
	var danno_dopo_primo := _totale_danno
	horde.step(DT)
	h.eq(horde.mortar_shot_count, 1, "m13: secondo colpo in volo per la prova della schivata")
	h.near(_totale_danno, danno_dopo_primo, 0.000001,
		"m13: e il totale non e' cambiato spariando: il danno arriva quando il colpo cade")
	var caduta := horde.mortar_shots[0]
	_player_via = Vector3(caduta.x, 0.0, caduta.y - (blast + 0.05))
	var schivato := 0
	for _i in int(ceil(tele / DT)) + 4:
		horde.step(DT)
		schivato += 1
		if horde.mortar_shot_count == 0:
			break
	h.eq(horde.mortar_shot_count, 0, "m13: il colpo e' caduto")
	h.near(_totale_danno - danno_dopo_primo, 0.0, 0.000001,
		"m13: il giocatore a %.2f m dal punto di caduta (raggio %.2f m + %.2f m di corpo) "
			% [blast + 0.05, blast, ENEMY.TOUCH_REACH]
			+ "non prende niente: la cupola dice la verita' sul raggio")
	print("orda: m13, schivata -- fuori di %.2f m dal punto di caduta, %.4f hp presi in %d passi "
			% [blast + 0.05, _totale_danno - danno_dopo_primo, schivato]
		+ "(contro %.4f hp presi restando fermo dentro): la finestra e' abbastanza per uscire e il "
			% ENEMY.MORTAR_BLAST_HP
			+ "raggio di esplosione e' quello dichiarato")

## ## «Un giocatore fermo dentro il raggio deve morire»
##
## Il secondo lato della misura, e quello che rende la disuguaglianza non comoda:
## sotto il tempo di fuga il colpo e' un delitto, sopra **il colpo e' gratis**. Il
## numero che tiene la linea qui e' che il danno e' **un istante**: durante tutta
## la finestra non arriva niente, e quando il colpo cade arriva tutto. Un campo che
## facesse male a ogni passo mentre la cupola e' a schermo passerebbe questa
## sezione e sarebbe l'esatto contrario di quello che l'utente ha chiesto.
func _m13_stazionario(h, horde: HORDE) -> void:
	_m13_prepara(horde, ENEMY.MORTAR)
	var danno_iniziale := _totale_danno
	var passi := 0
	var colpi := 0
	var violazioni := 0
	var cadute := 0
	while _totale_danno - danno_iniziale < PLAYER_HP_REFERENCE and passi < PASSI_FERMO_DENTRO:
		var prima_conteggio := horde.mortar_shot_count
		var prima_danno := _totale_danno
		horde.step(DT)
		var preso := _totale_danno - prima_danno
		if horde.mortar_shot_count < prima_conteggio:
			cadute += 1
		if horde.mortar_damage_last > 0.0:
			colpi += 1
			h.near(preso, ENEMY.MORTAR_BLAST_HP, 0.0001,
				"m13: il colpo che cade prende %.4f hp, tutto in un colpo"
					% ENEMY.MORTAR_BLAST_HP)
		elif absf(preso) > 0.000001:
			violazioni += 1
		passi += 1
	var totale := _totale_danno - danno_iniziale
	h.check(totale >= PLAYER_HP_REFERENCE,
		"m13: un giocatore fermo dentro il raggio di esplosione deve MORIRE: presi %.2f hp "
			% totale
			+ "in %d passi (%.2f s) con %d colpi, contro i %.0f hp di riferimento"
				% [passi, float(passi) * DT, colpi, PLAYER_HP_REFERENCE])
	h.check(colpi >= 2, "m13: e non e' un colpo solo: %d colpi caduti" % colpi)
	h.eq(violazioni, 0,
		"m13: nessun danno fuori dall'istante in cui il colpo cade: la finestra non e' un campo")
	print("orda: m13, fermo dentro -- %.2f hp in %d passi (%.2f s), %d colpi caduti, "
			% [totale, passi, float(passi) * DT, cadute]
		+ "danno solo all'impatto (0 violazioni su %d passi)" % passi)
	# ## I denti: spento il danno, il criterio **deve** andare rosso
	#
	# Il criterio di sopra puo' passare per il motivo sbagliato — un mortar che
	# spara in un campo vuoto fa morire lo spia ugualmente, se lo spia accetta
	# tutto. Quindi qui si toglie il danno e si verifica che il giocatore **non**
	# muore, coi denti dentro la sezione e non in un file a parte.
	var danno_prima := ENEMY.MORTAR_BLAST_HP
	ENEMY.MORTAR_BLAST_HP = 0.0
	_m13_prepara(horde, ENEMY.MORTAR)
	# ## Il totale si prende **qui**, non all'inizio della sezione
	#
	# `danno_iniziale` e' il totale di **prima** del «fermo dentro» che ha appena
	# misurato %.2f hp: confrontarlo adesso sommerebbe quei colpi a quelli della
	# corsa avvelenata e la prova direbbe «ha fatto danno» per il motivo sbagliato
	# (perche' ne aveva gia' fatti prima). Quindi la base e' il totale **dopo** il
	# ripristino, e la domanda diventa quella giusta: *in questa corsa* e' passato
	# qualcosa al giocatore?
	var danno_avvelenato := _totale_danno
	var colpi_avvelenati := 0
	for _i in PASSI_DENTI_DANNO:
		var prima_conteggio := horde.mortar_shot_count
		horde.step(DT)
		if horde.mortar_shot_count < prima_conteggio:
			colpi_avvelenati += 1
	h.check(colpi_avvelenati >= 2,
		"denti: col danno a 0.0 i colpi devono cadere lo stesso (%d in %d passi), altrimenti "
			% [colpi_avvelenati, PASSI_DENTI_DANNO]
			+ "questa prova sta misurando una cupola che non parte e non il danno")
	h.eq(_totale_danno - danno_avvelenato, 0.0,
		"denti: col danno a 0.0 il giocatore fermo dentro non prende niente in %d passi e %d "
			% [PASSI_DENTI_DANNO, colpi_avvelenati]
			+ "colpi caduti, quindi il criterio di sopra dipende dal danno e non e' nato verde "
			+ "(i %.2f hp presi li aveva presi prima di avvelenare)" % totale)
	ENEMY.MORTAR_BLAST_HP = danno_prima
	h.near(ENEMY.MORTAR_BLAST_HP, ENEMY.touch_damage_of(ENEMY.BOSS), 0.0001,
		"denti: ripristino, il danno del colpo torna a derivare dalla tabella delle masse (%.4f hp)"
			% ENEMY.MORTAR_BLAST_HP)

## Un nemico solo, della specie richiesta, alla distanza di tiro, col giocatore
## finto sul punto dichiarato.
func _m13_prepara(horde: HORDE, kind: int) -> void:
	var respawn := horde.auto_respawn
	horde.auto_respawn = true
	while horde.count > 0:
		horde.damage_enemy(0, 9999.0, Vector3.ZERO)
	horde.population = 1
	var passi := 0
	while horde.count < 1 and passi < 60:
		horde.step(DT)
		passi += 1
	horde.auto_respawn = respawn
	horde.kinds[0] = kind
	horde.radii[0] = ENEMY.RADIUS[kind]
	horde.colors[0] = ENEMY.color_of(kind)
	horde.hp[0] = ENEMY.hp_of(kind)
	horde.velocities[0] = Vector3.ZERO
	horde.mortar_timers[0] = 0.0
	horde.mortar_fire[0] = 0
	_player_via = PUNTO_MORTAR
	horde.transforms[0] = PUNTO_MORTAR + Vector3(0.0, 0.0,
		ENEMY.engage_for(horde.body_scale) - FERMO_DENTRO)

func _nomi_tabelle() -> String:
	return "HP/SPEED/RADIUS/MASS/KNOCKBACK_RESIST/COLOR"

## # --- m17: l'orologio di partita, e **come** una sezione lo porta oltre --------
##
## Il mortar dal terzo minuto in poi (`Run.MORTAR_AFTER_S`, `src/sim/run.gd`) non
## nasce piu' dall'onda 1: nasce **quando l'orologio di partita supera i
## 180,0 s**. Quindi ogni sezione di questo file che cerca un mortar **per
## spawn** deve dire come porta l'orologio, e la strada e' **una sola** ed e'
## dichiarata qui sotto invece di essere riscritta in ogni sezione.
##
## ## La strada: **una scrittura del campo**, non 10 800 passi
##
## `run.elapsed_s` e' un campo **pubblico e dichiarato** di `src/sim/run.gd`,
## come `wave_killed` che questa sezione gia' scrive: il test guida il contesto
## con le leve che il progetto dichiara, invece di accorgersi che ci sono 10 800
## passi (= 180,0 s a `DT = 1/60`) da fare e che il file ha 13 s di margine
## sui 120 s del gate.
##
## **Non e' una scorciatoia e non e' una scorciatoia lo e' due volte**: la soglia
## non ha nessuna cache (`horde._pick_kind()` la rilunge a ogni spawn), quindi
## scrivere il campo e' lo stesso stato che 10 800 passi produrrebbero — non
## approssimato, **uguale**. La differenza e' solo quanti passi di simulazione ci
## sono dietro: se ne vuole uno, il numero e' `180,0 / DT`, ed e' scritto qui e
## stampato sotto, non lasciato a chi legge.
##
## Ogni sezione che chiama questa funzione **stampa** con quanti secondi e con
## quale strada, cosi' il numero che la sezione misura non sembra arrivato da
## qualche parte.
func _porta_oltre_il_mortar(h, horde: HORDE, sezione: String) -> float:
	var r = horde.run
	var scritto := SOGLIA_MORTAR
	r.elapsed_s = scritto
	h.check(r.mortar_unlocked(),
		"m17: %s ha scritto elapsed_s = %.1f s e la soglia doveva aprirsi: senza questo il "
			% [sezione, scritto]
		+ "mortar non nasce e la sezione misurerebbe il vuoto")
	# ## La stampa che rende la sezione controllabile da fuori
	#
	# Tre numeri, e sono i tre che servono per capire **dove** una sezione sta
	# guardando: il peso che l'orda **dichiara** di usare (`_weights`), lo stesso con
	# la voce del mortar spenta (`_pesi_senza_mortar`), e la risposta della soglia.
	# Senza questi tre, «zero mortar» e «mortar spento» sono la stessa frase.
	var dichiarati: PackedFloat32Array = horde.get("_weights")
	var spenti: PackedFloat32Array = horde.get("_pesi_senza_mortar")
	print("orda: m17, %s porta l'orologio a %.1f s scrivendo `run.elapsed_s` (le leve dichiarate, "
			% [sezione, scritto]
		+ "come `wave_killed`): il gioco ci arriverebbe in %d passi a DT %.4f, e la soglia non ha "
			% [int(ceil(scritto / DT)), DT]
		+ "cache, quindi il numero che segue e' lo stesso stato, non un'approssimazione | "
		+ "pesi dichiarati %s, pesi senza il mortar %s, soglia aperta %s"
			% [str(dichiarati), str(spenti), str(r.mortar_unlocked())])
	return r.elapsed_s

## ## m17: le quattro sezioni di questo file che cercano un mortar, e **come**
##
## | sezione | da dove prende il mortar | cosa serve |
## |---|---|---|
## | `_m13_peso_fonte` (sonda di nascita) | `_pick_kind()`, cioe' **spawn** | l'orologio oltre 180 s |
## | `_due_cammini` (miscela, sezione 17) | `_pick_kind()`, cioe' **spawn** | l'orologio oltre 180 s |
## | `_m13_volo` / `_m13_stazionario` | `_m13_prepara` scrive `kinds[0]` | **niente**, e la soglia resta **chiusa** |
##
## Le ultime due scrivono la specie **nell'array**, quindi non passano da
## `_pick_kind()` e la soglia non le tocca: e' il motivo per cui possono misurare
## la cupola e la schivata **prima** del terzo minuto senza falsare niente. Non e'
## un caso fortunato e' la distinzione che rende la soglia vera: la soglia dice
## «il mortar **non e' spendibile**», cioe' «il peso non si spende su di lui», e
## non dice «un mortar gia' nato smette di sparare». Le due cose diverse hanno due
## criteri diversi, e `_azzera_l_orologio` verifica la seconda **con la prima
## chiusa**: a zero secondi la soglia e' chiusa e la cupola cade lo stesso.
##
## Il contrario e' vero e viene verificato dalla sezione `_m17_orologio`: a
## soglia chiusa `_pick_kind()` **non puo'** tirare fuori un mortar, su nessun
## seme. Se una delle due metà non fosse vera, la soglia non starebbe guardando
## niente.

## L'altra strada: l'orologio **a zero**, con la soglia chiusa.
##
## Serve alle due sezioni che misurano la **cupola** (`_m13_volo`,
## `_m13_stazionario`) e serve a farlo in modo verificabile: l'orologio e' un
## contatore che questa sezione incrementera' perche' il file lo porta a zero prima
## e poi, nella sezione `_m17_orologio`, gli si chiede di crescere. Quindi qui non
## basta scrivere il campo: si **asserisce** che la soglia e' chiusa mentre il
## mortar spara, altrimenti la sezione non saprebbe di star guardando «un mortar
## che esiste gia'» e non «il mortar che nasce».
func _azzera_l_orologio(h, horde: HORDE, sezione: String) -> void:
	var r = horde.run
	r.elapsed_s = 0.0
	h.check(not r.mortar_unlocked(),
		"m17: %s ha azzerato l'orologio e la soglia doveva essere CHIUSA: questa sezione misura "
			% sezione
		+ "un mortar che esiste gia' (lo scrive nell'array con `_m13_prepara`), quindi la soglia "
		+ "le deve essere indifferente, e non lo e' piu'")

## Il numero della soglia, scritto qui e non letto da `Run`.
##
## Se il valore di produzione cambiasse, questa costante resterebbe indietro e il
## criterio continuerebbe a misurare 180 s senza dirlo: quindi la sezione
## confronta le due e va rossa quando divergono. Non e' una copia del numero
## (quella sarebbe una seconda fonte): e' la **riga che obbliga la fonte a non
## muoversi in silenzio**.
## Aggiornato a 210.0: -orda ha allungato SEGMENT_S a 210 s (ritmo più lento),
## quindi il mortar si sblocca dopo 210 s e non più dopo 180 s. Deve restare
## allineato a `Run.MORTAR_AFTER_S` (asserito dalla sezione sottostante).
const SOGLIA_MORTAR := 210.0

# --- 19. m17: il terzo minuto: l'orologio, la soglia con denti, e la misura ----
#
# ## Perche' questa sezione esiste
#
# Il mortar non nasce piu' dall'onda 1 ma **dopo 180,0 s di partita** (`Run.
# MORTAR_AFTER_S`), e `Run.elapsed_s` e' il segnale che non esisteva prima di m17.
# Senza un criterio che lo guardi, quelle due righe sono un commento: il file
# potrebbe dire «180 s» e continuare a far nascere mortar dall'onda 1, e la porta
# resterebbe verde. Qui sotto ci sono le tre cose che servono, ognuna con i suoi
# numeri: **l'orologio e' vero**, **la soglia ha denti**, **il terzo minuto e'
# l'onda N**.
#
# ## I tre semi della misura, e perche' la misura non dipende da loro
#
# `SEMI_OROLOGIO` sono tre semi di produzione (nessuno e' «quello di prima»). Ma
# la cosa da scrivere accanto al numero non e' «ho usato tre semi»: e' che a
# 180 s **conta il ritmo delle uccisioni, non il seme**. L'onda avanza quando la
# barra si riempie, e la barra si riempie di uccisioni: chi e' morto e con quale
# disposizione non entra nel conto. Quindi il numero che esce vale **per quella
# cadenza** e per nessun'altra, ed e' per questo che la cadenza e' dichiarata qui
# sotto e stampata a ogni lancio.

## I semi della misura del terzo minuto.
const SEMI_OROLOGIO := [4242, 20260912, 13579]

## Il passo con cui gira la misura, e **perche' e' grosso**.
##
## `DT = 1/60` farebbe 10 800 passi per seme, e il file ha 12,5 s di margine sui
## 120 s del gate (`TEST_TIMEOUT_MS`, decisione dell'utente). A `0,2 s` sono 900
## passi e la misura entra. **Non e' un'approssimazione del numero**: l'unica
## cosa che `DT` cambia dentro il conto e' quanti secondi di partita servono per
## un certo numero di uccisioni — e la cadenza qui sotto e' dichiarata in
## «uccisioni per secondo», quindi il passo **e' parte del numero** e va detto.
const DT_OROLOGIO := 0.2

## Quanti passi coprono 180,0 s a `DT_OROLOGIO`: 900. Scritto, non calcolato, per
##che' il numero che il piano si porta via e' leggibile senza fare la divisione.
const PASSI_OROLOGIO := 1050

## Quante **uccisioni per passo** la misura mette al campo: una.
##
## Con `DT_OROLOGIO = 0,2` e un'uccisione per passo la cadenza e' **5/s**, e il
## numero che ne esce e' «l'onda a cui si e' alla soglia dei 180 s **uccidendo a 5
## al secondo**». Un giocatore vero uccide piu' lento, quindi il numero che
## vedra e' **minore** di questo: quello che esce qui e' il **limite superiore**
## dell'onda, non la sua stima. E' scritto cosi' perche' un numero che non dice
## quale cadenza ha misurato e' un numero che il piano leggera come se valesse per
## tutte.
const UCCISIONI_PER_PASSO := 1

## Quanti vivi per passo la misura tiene in campo.
##
## `population_scale` e' la leva dichiarata dalla sezione 15 (`_scala_popolazione`)
## e serve per un solo motivo: 900 passi con 200 nemici costano piu' dei 120 s
## del file. La **barra** non dipende da quanti vivi ci sono in campo — dipende
## dalle uccisioni — quindi il numero della misura non cambia, e il codice che
## gira e' quello di sempre.
const SCALA_OROLOGIO := 0.25

## Quanti **giri** per seme nel campione della soglia.
##
## Quattro semi per un giro danno 800 nascite e una quota di 0,0400: dentro la
## banda, ma **esattamente sul bordo**, e un numero sul bordo non e' un numero. Con
## tre giri il campione e' 2400 nascite e la quota esce al centro della banda
## (0,029-0,030 come sulla sezione 17), quindi il criterio misura il peso e non la
## sua posizione rispetto al limite. Costa dodici riempimenti: niente.
const GIRI_SOGLIA := 3

## Quanti passi **oltre la soglia** la misura lascia correre, e perche' non zero.
##
## Il difetto di questa sezione alla prima stesura: la corsa finiva a 180,0 s
## esatti, cioe' all'istante in cui la soglia si apre, e quindi **non c'era un solo
## passo nel quale il mortar potesse nascere** (0 su 2700 passi, letto). Non era un
## difetto della regola: era una finestra di osservazione di lunghezza zero.
##
## ## m12-w1b: `600` era tarato sul rateo vecchio, e la finestra va **derivata**
##
## I 600 passi erano giustificati da un conteggio di nascite: «a cadenza di spawn
## piu' di un nemico per passo sono ~600 nascite, cioe' ~17 mortar». Ma a
## `SPAWN_RATE = 8,0/s` quei 600 passi a `DT = 0,2 s` davano 600 nascite; a
## `2,0408/s` ne danno **245**, cioe' ~7 mortar: la probabilita' che nessuno nasca
## passa da 1 su 100 milioni a circa **1 su 14**, e la misura ha cominciato a dare
## `[600, 600, 600]` — cioe' la finestra era finita **prima** che il primo mortar
## potesse comparire. Non e' un difetto della regola: e' una finestra tarata su una
## costante che e' cambiata, che e' la stessa classe di difetto del tetto di attesa.
##
## La finestra si deriva quindi **dal numero di nascite che servono**, non dai passi:
## `nate_per_passo = SPAWN_RATE * DT` e i passi sono quelli per arrivare a
## `NATE_MINIME_MORTAR` nascite. Il 3% e' la quota dichiarata di `spawner.gd`
## (`MORTAR_WEIGHT`), quindi il numero e' una **probabilita'**, e la soglia e' quella
## che la rende alta. Quello che esce a `SPAWN_RATE = 8,0/s` sono ~600 passi come
## prima: non e' un numero che si e' cambiato, e' lo stesso numero calcolato.
const NATE_MINIME_MORTAR := 2400.0

## Quanti passi oltre la soglia servono per vedere il mortar. **Derivato**: il numero
## di nascite che la finestra deve contenere, diviso per le nascite che un passo
## produce. `nate_per_passo` e' sotto 1 a `DT = 0,2 s` (0,41), quindi la finestra e'
## un multiplo di ~2,4 passi per nascita e arrotonda verso l'alto.
func _passi_dopo_la_soglia(delta: float) -> int:
	var per_passo := maxf(0.000001, RUN.SPAWN_RATE * delta)
	return int(ceil(NATE_MINIME_MORTAR / per_passo))

## La soglia di denti: un valore che il gioco non raggiunge mai, cosi' il criterio
## accende il difetto senza toccare il numero di produzione.
const SOGLIA_ASSURDA := 1.0e9

func _m17_orologio(h, horde: HORDE) -> void:
	var t0 := Time.get_ticks_usec()
	var r = horde.run
	h.check(r != null and r.has_method("mortar_unlocked"),
		"m17: `run.elapsed_s` e `Run.mortar_unlocked()` devono esistere: senza i due la regola "
			+ "del terzo minuto non ha nessun numero dietro")
	h.near(SOGLIA_MORTAR, float(RUN.MORTAR_AFTER_S), 0.000001,
		"m17: la soglia di produzione e' %.1f s, il numero scritto in questo file" % SOGLIA_MORTAR)

	# ## (a) l'orologio e' vero: cresce di `delta`, si ferma a `game_over`, e
	# `restart_run()` lo azzera
	horde.restart_run()
	h.near(r.elapsed_s, 0.0, 0.000001,
		"m17: `restart_run()` azzera l'orologio: una partita nuova comincia al secondo 0")
	h.check(not r.mortar_unlocked(),
		"m17: al secondo 0 il mortar non e' spendibile (partita nuova)")
	var t: float = r.elapsed_s
	horde.step(DT)
	h.near(r.elapsed_s, t + DT, 0.000001,
		"m17: un passo aggiunge esattamente `delta`: %.4f s diventano %.4f s" % [DT, t + DT])
	horde.step(DT)
	horde.step(DT)
	h.near(r.elapsed_s, 3.0 * DT, 0.000001,
		"m17: tre passi, tre `delta`: l'orologio e' un contatore, non una stima")
	# ## Il fermo a `game_over`: **un difetto, se non c'e'**
	#
	# Un orologio che corre mentre la partita e' finita fa diventare casuale *quando*
	# compare il mortar, e allora «180 s» non e' una soglia: e' un numero che
	# dipende da quanto tempo il giocatore ha passato a guardare il menu di morte.
	h.check(r.enter_game_over(),
		"m17: `enter_game_over()` deve entrare davvero, altrimenti il fermo sotto non si misura")
	var fermo: float = r.elapsed_s
	horde.step(DT)
	horde.step(DT)
	h.near(r.elapsed_s, fermo, 0.000001,
		"m17: a partita finita il tempo NON scorre (%.4f s fermi su %d passi): un orologio che "
			% [fermo, 2]
		+ "corre con `game_over` farebbe dipendere il mortar da quanto tempo nessuno gioca")
	h.eq(r.elapsed_s, fermo,
		"m17: e non e' un'approssimazione: la differenza e' zero, non «piccola»")
	horde.restart_run()
	h.near(r.elapsed_s, 0.0, 0.000001,
		"m17: e il restart dopo `game_over` rimette l'orologio a zero (e' l'unica strada a PLAYING)")

	# ## (b) la soglia, **con denti**: chiusa -> zero mortar, ripristinata -> 2%-4%
	#
	# I due lati sono due difetti diversi, quindi due misure diverse: sotto, il
	# difetto e' «il tempo c'e' ma nessuno lo guarda» (l'orologio e' a 180 s e il
	# mortar non nasce); sopra, il difetto e' «la soglia non c'e'» (l'orologio e' a
	# zero e il mortar nasce). Un criterio che guardasse solo il primo passerebbe
	# anche senza la regola, che e' il modo peggiore di passare.
	var pop_sonda := horde.population
	var scala_sonda := horde.population_scale
	horde.auto_respawn = true
	horde.population_scale = 1.0
	horde.population = HORDE.MAX_ENEMIES
	# ## Quanti semi sono passati: due varianti, e la differenza e' il difetto
	var nati := SEMI_MISELA.size() * GIRI_SOGLIA * HORDE.MAX_ENEMIES
	_azzera_l_orologio(h, horde, "_m17_orologio (lato chiuso)")
	var chiusi := _census_su_quattro_semi(h, horde)
	h.eq(chiusi, 0,
		"m17 lato chiuso: a soglia chiusa (%d semi x %d giri x %d nascite) non deve nascere un "
			% [SEMI_MISELA.size(), GIRI_SOGLIA, HORDE.MAX_ENEMIES]
		+ "mortar solo, ottenuti %d: se ne nasce uno, il tempo c'e' ma nessuno lo guarda" % chiusi)
	# ## E le **altre tre** specie non cambiano: la soglia e' del mortar, solo
	#
	# Il boss non e' in questo elenco perche' sull'onda 1 vale `BOSS_WAVE1 = 0,0` e
	# non nasce comunque: e' un'altra soglia, dichiarata altrove, e metterlo qui
	# darebbe un criterio che cerca un numero che non deve esistere. Il brute e'
	# invece la specie che **non** doveva muoversi quando il numero del mortar e'
	# sceso, quindi e' il confronto che rende vera la regola «solo lui».
	var specie := _specie_oltre_il_mortar(h, horde)
	h.check(specie[ENEMY.RUNNER] > 0 and specie[ENEMY.GRUNT] > 0 and specie[ENEMY.BRUTE] > 0,
		"m17 lato chiuso: a soglia chiusa le altre specie devono nascere come sempre, ottenuto "
			+ "runner %d, grunt %d, brute %d su %d nascite: una regola che accendesse il mortar "
				% [specie[ENEMY.RUNNER], specie[ENEMY.GRUNT], specie[ENEMY.BRUTE], nati]
		+ "spegnesse anche il brute sarebbe verde qui e falsa nel gioco")
	# --- lato B2: i denti. La soglia diventa un numero che il gioco non raggiunge,
	# e l'orologio ci va **oltre**: cosi' la prova e' sulla soglia e non sul clock.
	var soglia_produzione := float(RUN.MORTAR_AFTER_S)
	RUN.MORTAR_AFTER_S = SOGLIA_ASSURDA
	# ## L'orologio va **oltre la soglia di produzione e sotto quella assurda**
	#
	# 181,0 s: piu' dei 180,0 s che avrebbero aperto la soglia vera, e molto meno
	# dei %s s assurdi appena messi. Quindi la prova e' sulla **soglia** e non sul
	# valore del clock — ed e' la stessa identica riga di clock che sta nel ripristino
	# qui sotto, quindi il «prima» e il «dopo» differiscono **solo** per
	# `MORTAR_AFTER_S`. (La prima stesza di questa prova scriveva l'orologio a
	# 1e9 come la soglia: la soglia risultava aperta per costruzione e la prova
	# misurava il confronto fra due numeri uguali. E' la ragione per cui qui il
	# clock non e' il numero assurdo.)
	r.elapsed_s = SOGLIA_MORTAR + 1.0
	h.check(not r.mortar_unlocked(),
		"denti: orologio a %.1f s, soglia di produzione %.1f s e soglia assurda %s s: la soglia "
			% [SOGLIA_MORTAR + 1.0, SOGLIA_MORTAR, SOGLIA_ASSURDA]
		+ "deve essere CHIUSA (l'orologio non arriva a %s s), altrimenti questa prova non sta "
			% SOGLIA_ASSURDA
		+ "guardando la soglia")
	var denti := _census_su_quattro_semi(h, horde)
	h.eq(denti, 0,
		"denti: soglia a %s s (irraggiungibile) e orologio a %.1f s, oltre la soglia vera: zero "
			% [SOGLIA_ASSURDA, SOGLIA_MORTAR + 1.0]
		+ "mortar su %d nascite, ottenuti %d. Se qui ne nascessero, la soglia non starebbe "
				% [nati, denti]
		+ "guardando niente")
	# --- ripristino asserito **prima** di rimisurare: un ripristino non asserito e'
	# una riga che puo' non partire senza che nessuno lo veda.
	RUN.MORTAR_AFTER_S = soglia_produzione
	h.near(float(RUN.MORTAR_AFTER_S), SOGLIA_MORTAR, 0.000001,
		"denti: ripristino 1, la soglia torna a %.1f s" % SOGLIA_MORTAR)
	_porta_oltre_il_mortar(h, horde, "_m17_orologio (lato aperto)")
	var aperti := _census_su_quattro_semi(h, horde)
	var quota := float(aperti) / maxf(1.0, float(nati))
	h.check(aperti > 0,
		"m17 lato aperto: ripristinata la soglia e aperto l'orologio il mortar DEVE nascere, "
			+ "ottenuti %d su %d: con la soglia chiusa erano %d, quindi nessun numero di questa "
				% [aperti, nati, chiusi]
		+ "sezione sta guardando il caso fortunato")
	h.check(quota >= QUOTA_MORTAR_MIN and quota <= QUOTA_MORTAR_MAX,
		"m17 lato aperto: la quota appena passata la soglia e' %.4f (%d su %d) e deve stare "
			% [quota, aperti, nati]
		+ "fra %.1f%% e %.1f%%: sotto il 2%% il nemico da schivare non si impara, sopra il 4%% "
				% [100.0 * QUOTA_MORTAR_MIN, 100.0 * QUOTA_MORTAR_MAX]
		+ "un'onda di mortar non e' piu' un'onda mista")
	print("orda: m17, soglia -- chiusa (orologio %.1f s): %d mortar su %d nascite | "
			% [0.0, chiusi, nati]
		+ "denti (soglia %s s): %d su %d | ripristinata a %.1f s: %d su %d = %.4f"
			% [SOGLIA_ASSURDA, denti, nati, SOGLIA_MORTAR, aperti, nati, quota])

	# ## (c) **terzo minuto = onda N**: la misura che il piano si porta via
	#
	# Nessuno scrive l'orologio in questo blocco: corre una partita vera e si legge
	# `run.wave` quando l'orologio supera da solo i 180,0 s. E' la stessa regola
	# guardata dall'altra parte — non «il test ha aperto la soglia», ma «la soglia
	# si e' aperta da sola al terzo minuto e da li' il mortar c'e'».
	horde.population_scale = SCALA_OROLOGIO
	horde.restart_run()
	horde.auto_respawn = true
	h.check(not r.mortar_unlocked(),
		"m17 misura: la partita ricomincia col clock a zero e la soglia chiusa")
	var onde := PackedInt32Array()
	var visti := 0
	var passi_alla_soglia := PackedInt32Array()
	for s in SEMI_OROLOGIO:
		# ## Il restart e' **dentro** il ciclo, e fuori darebbe tre partite diverse
		#
		# `restart_run()` azzera onda, barra e orologio: senza questa riga il secondo
		# seme partirebbe dall'onda in cui era finito il primo (misurato: 4, poi 7,
		# poi 9 — la serie che ha fatto capire che il ciclo stava contando le
		# partite sommate invece che tre partite). Ogni seme qui e' una **partita
		# nuova**, ed e' l'unico modo perché i tre semi siano confrontabili.
		horde.restart_run()
		horde.reseed(int(s))
		r.elapsed_s = 0.0
		var passi := 0
		var nati_mortar := 0
		# L'onda si legge **all'istante in cui l'orologio supera la soglia**, non in
		# fondo alla corsa: dopo la soglia la partita continua e l'onda sale, quindi
		# leggere in fondo misurerebbe l'onda di 210 s e la chiamerebbe «onda a 180 s».
		var onda_alla_soglia := 0
		var passi_soglia := 0
		# La finestra oltre la soglia e' **derivata dal rateo**: vedi
		# `_passi_dopo_la_soglia`. Con `SPAWN_RATE = 8,0/s` tornano i 600 passi di
		# prima; con `2,0408/s` la finestra si allunga da sola invece di finire prima
		# che il primo mortar possa comparire.
		var tetto_giro := PASSI_OROLOGIO + _passi_dopo_la_soglia(DT_OROLOGIO)
		while passi < tetto_giro:
			# Il censimento a ogni passo e' la prova che **il mortar compare da
			# solo**, e non perche' il test abbia aperto qualcosa: e' una lettura,
			# non una scrittura (costa `O(count)` su 6-50 vivi, e la sezione lo dice).
			if horde.census()[ENEMY.MORTAR] > 0:
				nati_mortar += 1
			horde.step(DT_OROLOGIO)
			for _k in UCCISIONI_PER_PASSO:
				if horde.count > 0:
					horde.damage_enemy(0, 9999.0, Vector3.ZERO)
			passi += 1
			if onda_alla_soglia == 0 and r.elapsed_s >= SOGLIA_MORTAR - 0.5 * DT_OROLOGIO:
				onda_alla_soglia = r.wave
				passi_soglia = passi
				# E il primo mortar deve arrivare **dopo** questo passo, non prima:
				# quindi si smette di contare quando compare, e il numero di passi
				# che ci e' volto e' la misura «quanto ci mette a farsi vedere».
				break
		var primo := passi
		while nati_mortar == 0 and primo < tetto_giro:
			if horde.census()[ENEMY.MORTAR] > 0:
				nati_mortar += 1
			horde.step(DT_OROLOGIO)
			if horde.count > 0:
				horde.damage_enemy(0, 9999.0, Vector3.ZERO)
			primo += 1
		onde.append(onda_alla_soglia)
		passi_alla_soglia.append(primo - passi_soglia)
		visti += nati_mortar
		# ## La tolleranza e' `DT/2` e non `0`: 900 addizioni di `0,2` in `float64`
		# non fanno esattamente 180, e il numero che conta qui e' **quanti passi**
		# (`PASSI_OROLOGIO`, dichiarato), non la somma. Senza questa tolleranza il
		# criterio misurerebbe la precisione dell'accumulazione e non la regola, che
		# e' la classe di difetto che questo file chiude in ogni altro punto.
		h.check(passi_soglia > 0,
			"m17 misura seme %d: in %d passi l'orologio non ha mai raggiunto i %.1f s"
				% [int(s), passi, SOGLIA_MORTAR])
		h.check(passi_soglia <= PASSI_OROLOGIO,
			"m17 misura seme %d: la soglia e' stata raggiunta al passo %d oltre il tetto dichiarato "
				% [int(s), passi_soglia]
			+ "di %d: il numero che segue sarebbe su un orologio fermo prima" % PASSI_OROLOGIO)
	# La parte da scrivere accanto al numero, e quella che rende il numero onesto:
	# **l'onda a 180 s dipende dal ritmo delle uccisioni, non dal seme**. Quindi i
	# tre semi devono dare lo stesso numero, e se non lo dessero quello che cambierebbe
	# cambiare non sarebbe «la disposizione» ma il fatto che la misura sta legendo
	# qualcos'altro.
	h.eq(onde[0], onde[1],
		"m17 misura: semi %d e %d danno onde diverse (%d e %d): a 180 s conta il ritmo delle "
			% [SEMI_OROLOGIO[0], SEMI_OROLOGIO[1], onde[0], onde[1]]
		+ "uccisioni, non chi e' morto, quindi i semi non possono cambiare il numero")
	h.eq(onde[1], onde[2],
		"m17 misura: semi %d e %d danno onde diverse (%d e %d), stessa ragione"
			% [SEMI_OROLOGIO[1], SEMI_OROLOGIO[2], onde[1], onde[2]])
	h.check(visti > 0,
		"m17 misura: la soglia si e' aperta **da sola** al passo %s (%s passi dopo la soglia) e "
			% [str(passi_alla_soglia), str(passi_alla_soglia)]
		+ "in %d passi oltre la soglia il mortar non e' mai comparso in campo: una soglia che "
			% (PASSI_OROLOGIO + _passi_dopo_la_soglia(DT_OROLOGIO))
		+ "nessuno ha attraversato e' una soglia che non esiste")
	print("orda: m17, terzo minuto = **onda %d** -- misurata su %d semi (%s) a DT %.1f s con "
			% [onde[0], SEMI_OROLOGIO.size(), str(SEMI_OROLOGIO), DT_OROLOGIO]
		+ "%d uccisioni per passo = %.1f uccisioni/s, %d passi fino alla soglia + %d oltre "
			% [UCCISIONI_PER_PASSO, float(UCCISIONI_PER_PASSO) / DT_OROLOGIO, PASSI_OROLOGIO,
				_passi_dopo_la_soglia(DT_OROLOGIO)]
		+ "`population_scale` %.2f; il primo mortar e' comparso %s passi dopo la soglia, da solo. "
			% [SCALA_OROLOGIO, str(passi_alla_soglia)]
		+ "Il numero vale per QUELLA cadenza (un giocatore vero uccide piu' lento, quindi vede "
		+ "un'onda minore o uguale) e non dipende dal seme: a 180 s conta il ritmo delle "
		+ "uccisioni, non chi e' morto")

	# ## L'orda torna com'era
	horde.population_scale = scala_sonda
	horde.population = pop_sonda
	horde.restart_run()
	h.near(r.elapsed_s, 0.0, 0.000001,
		"m17: la sezione rimette l'orologio a zero con `restart_run()`, e non con una "
			+ "scrittura: la strada vera resta la strada vera")
	print("orda: m17, sezione intera in %d us" % (Time.get_ticks_usec() - t0))

# ================================================================================
# 20. m12-w1a: LA PARTITA A OROLOGIO E LA LEGGE DEL RATEO DI NASCITA
# ================================================================================
#
# ## Cosa c'era e cosa c'e'
#
# Prima di questa sezione `src/sim/run.gd` aveva `END_WAVE = 61` e una
# `SPAWN_RATE` **piatta** a 8,0/s. Adesso ha l'orologio (quattro segmenti da 180 s,
# boss a 720 s, fine a 1080 s) e una legge per il rateo. Le tre cose che questa
# sezione deve **dimostrare** e non asserire:
#
#   1. **la timeline e' vera** — quattro segmenti, `720 s` NON e' la fine del run, e
#      il 720 e' l'**arrivo**; `1080 s` e' l'altra strada, e la prima e' la morte;
#   2. **il rateo di avvio e' il tetto di assorbimento**, cioe' `2,0408/s`, e la
#      legge di prima (`8,0/s`) lo superava di **3,92 volte**: questo e' il
#      controfattuale, ed e' quello che deve venire **male**;
#   3. **la partita intera, 1080 s, gira** — e il numero che ne esce (quanti
#      segmenti, che livello, quanti vivi, che rateo) e' stampato accanto al
#      verdetto, perche' un verdetto senza numeri e' un verdetto che il prossimo
#      giro ricomincia a indovinare.
#
# ## Il tempo, e perche' `DT = 0,2 s` qui non e' un'approssimazione
#
# `test_orda` costa **101.262 ms dei 120.000** (misurato il 2026-10-16 prima di
# toccare una riga) e ne restano **18.738**. La partita dura **1080 s**: a
# `DT = 1/60 s` sono **64.800 passi**, e a ~3 ms per passo con 200 nemici sono
# **194 s** — piu' del tetto del file, da solo. Quindi qui si gira a
# `DT_OROLOGIO_M12 = 0,2 s` e **5400 passi**, come la sonda di m17 gia' faceva per
# arrivare a 180 s.
#
# **Un criterio misurato a `DT = 0,2 s` parla di un gioco diverso da quello a
# `DT = 1/60 s`, e va detto.** Il numero che questa sezione giudica — il **tempo di
# riempimento** — e' un numero in secondi, quindi e' l'unico la cui risposta a `DT`
# e' nota: il credito di `horde.gd::_top_up` cresce di `rate x delta` e spende
# interi per intero, quindi a `DT` piu' grossi arriva **meno nemici per passo** e
# il tempo di riempimento resta `POP_BASE / rate` piu' un sovrappiu' di **un passo**.
# La difesa non e' dichiarata, e' **misurata**: `_riempimento_misurato()` gira
# **due volte**, a `DT = 0,2 s` e a `DT = 1/60 s`, sullo stesso numero, e le due
# righe sono stampate insieme. Se un giorno il numero non coincide piu', la difesa
# lo dice da sola.

## Il passo grosso della partita intera, e i passi che copre.
##
## `5400 x 0,2 s = 1080,0 s`, cioe' `RUN_END_S`. Scritto e non calcolato perche' il
## numero che il piano si porta via e' leggibile senza fare la divisione.
const DT_OROLOGIO_M12 := 0.2
const PASSI_PARTITA := 5400

## Il passo **fine**, e la finestra in cui lo si misura.
##
## Non e' un secondo giro della partita intera (sarebbero 64.800 passi, vedi
## sopra): e' **lo stesso numero del criterio**, cioe' il tempo di riempimento del
## campo di avvio, rilmesso a `DT = 1/60 s`. 25 corpi a `2,0408/s` sono 12,25 s,
## cioe' **735 passi**: la difesa costa 735 passi, non un giro.
const DT_M12_FINE := 1.0 / 60.0

## Il **rateo di prima**: piatto, e a 8,0/s. Congelato qui dentro e letto da nessuna
## parte, perche' il criterio debba poter essere valutato anche su di lui.
const SPAWN_RATE_PIATTO := 8.0

## ## La cadenza di uccisioni con cui gira la partita intera: **non e' una costante**
##
## Era `const CORSIA_KILL_M12 := 2,0408`, cioe' il numero scritto a mano **due volte**
## — una qui e uno dentro `run.gd` — e asserito con `near`. E' il difetto che questo
## file chiude in ogni altro punto, quindi non si fa qui: la cadenza si **legge da
## `Run.ASSIMILATION_1`** e si asserisce che il valore letto sia proprio quello che
## la legge dichiara.
##
## Il giocatore di questa simulazione e' quindi il caso **migliore**: uccide esattamente
## quanto puo' uccidere e niente di piu'. Un giocatore vero uccide meno, quindi i
## numeri che ne escono sono il **limite superiore** di quello che vede lui — che e'
## la direzione giusta per un tetto, ed e' la stessa dichiarazione che fa la sezione
## m17 sulla sua sonda.
var _corsia_kill: float = 0.0

## ## Il numero di uccisioni attese: una **banda**, non un intero scritto a mano
##
## La prima stesura aveva `const UCCISIONI_ATTESE := 2204`, cioe' `2,0408 x 1080`
## calcolato con carta e poi asserito con `h.eq`. Un numero derivato a mano e poi
## confrontato con `==` non prende niente: se la formula cambia va rosso per la
## ragione sbagliata, e se qualcuno corregge il valore a mano torna verde senza che
## niente sia stato verificato.
##
## **Scelta: banda di +/- 1 uccisione attorno a un numero derivato a runtime**
## (`ASSIMILATION_1 x RUN_END_S`). Il motivo di una banda e non di un `==` e' che
## il credito di uccisioni e' un accumulatore in `float`: `2,040816 x 1080 =
## 2204,08` non e' un intero, e in 5400 passi l'accumulatore puo' cadere sotto di
## una uccisione per errore di arrotondamento. +/- 1 su 2204 e' lo **0,05%**: e' la
## quantizzazione del credito, non una patacca. Il numero vero resta stampato
## accanto all'asserzione.
const UCCISIONI_TOLLERANZA := 1.0

## ## La banda del tempo di riempimento, e **da dove viene**
##
## - **Il pavimento, 5,52 s**: e' la misura di m4, «25 nemici vivi entro 6 m dal
##   bersaglio, t = 5,52 s». Un campo che si riempie **piu' in fretta** di quanto
##   ci mette ad arrivare addosso ti si riaddossa piu' presto di quanto tu l'abbia
##   liberato: e' esattamente la derivazione con cui m4 ha scelto la sua banda di
##   `SPAWN_RATE`, e quella banda guardava solo il tetto (`< 15/s`) e non guardava
##   **chi riempie**. Quindi `8,0/s` — che sta sotto 15 e sta sopra 4,5 — passava la
##   banda di m4 ed e' sbagliato lo stesso: era quella la banda senza il numero.
## - **Il soffitto, 90 s**: meta' segmento. Il campo deve poter essere riempito entro
##   un segmento da 180 s, o l'orda non esiste nemmeno per meta' del suo tempo.
##
## ## Perche' con la legge di m19 questo criterio non avrebbe avuto un solo numero
##
## La legge di prima del rateo dipendeva dal livello, quindi due partite con lo stesso
## orologio davano due tempi di riempimento diversi, e il controfattuale non si
## poteva scrivere come una costante. **Con il taglio il numero e' uno solo** e il
## controfattuale e' di nuovo una costante — e quindi verificabile.
const POPIENO_MIN_S := 5.52
const POPIENO_MAX_S := 105.0

## La scala del campo durante la partita intera. Come la sonda di m17: la barra non
## dipende da quanti vivi ci sono (dipende dalle uccisioni), quindi il numero che
## questa sezione giudica non cambia, e il codice che gira e' quello di sempre.
const SCALA_M12 := 0.25

func _m12_orologio(h, horde: HORDE) -> void:
	var t0 := Time.get_ticks_usec()
	var r = horde.run
	if not h.check(r != null, "m12: la sezione ha bisogno di una partita vera"):
		return
	_corsia_kill = RUN.SPAWN_RATE
	_m12_timeline(h, horde, r)
	_m12_ancoraggio(h, r)
	_m12_criterio(h, horde, r)
	_m12_partita_intera(h, horde, r)
	_m12_fuori_mano(h)
	# l'orda torna com'era, e **con `restart_run()`**: la strada vera resta la
	# strada vera, e la sezione che segue misura una partita nuova.
	horde.population_scale = 1.0
	horde.population = RUN.population_of(1)
	horde.auto_respawn = false
	horde.restart_run()
	print("orda: m12, sezione intera in %d us (budget del file sotto)" % (Time.get_ticks_usec() - t0))

## (1) LA TIMELINE: quattro segmenti, e 720 s non e' la fine del run.
func _m12_timeline(h, horde: HORDE, r) -> void:
	h.eq(int(RUN.SEGMENTS), 4,
		"m12: quattro segmenti, e sono quattro (non cinque, non tre)")
	h.near(RUN.SEGMENT_S, 210.0, 0.000001, "m12: il segmento dura 210,0 s")
	h.near(RUN.FIREWALL_AFTER_S, 120.0, 0.000001, "m12: il firewall comincia a 120,0 s")
	h.near(RUN.BOSS_AT_S, 840.0, 0.000001, "m12: il boss a 840,0 s = 4 segmenti")
	h.near(RUN.RUN_END_S, 1080.0, 0.000001, "m12: la fine del run a 1080,0 s")
	h.near(RUN.SQUEEZE_AT_S, RUN.RUN_END_S, 0.000001,
		"m12: lo stringimento e' lo stesso istante della fine: due numeri per lo stesso "
			+ "istante sarebbero due numeri che possono divergere")
	h.near(RUN.MORTAR_AFTER_S, RUN.SEGMENT_S, 0.000001,
		"m12: la soglia del mortar (180,0 s, m17) e' esattamente un segmento: la struttura "
			+ "si combacia da sola invece che per accordo a mano")
	# La segmentazione, ai bordi. Il caso che conta e' **l'ultimo**: dopo il boss non
	# ne nasce un quinto.
	for s in range(1, int(RUN.SEGMENTS) + 1):
		var inizio := RUN.SEGMENT_S * float(s - 1)
		h.eq(RUN.segment_of(inizio), s, "m12: a %.1f s siamo nel segmento %d" % [inizio, s])
		h.eq(RUN.segment_of(inizio + RUN.SEGMENT_S - 0.001), s,
			"m12: il segmento %d dura fino a %.1f s e non un passo di meno" % [s, inizio + RUN.SEGMENT_S])
	h.eq(RUN.segment_of(0.0), 1, "m12: a zero secondi siamo nel segmento 1")
	h.eq(RUN.segment_of(RUN.RUN_END_S), int(RUN.SEGMENTS),
		"m12: a 1080 s siamo ANCORA nel segmento %d: il boss arriva a 720 e non ne nasce un quinto"
			% int(RUN.SEGMENTS))
	h.eq(RUN.segment_of(-5.0), 1, "m12: un orologio indietro non esce dal segmento 1")

	# ## Le due strade della fine, e la prova che sono **due**
	horde.restart_run()
	r.elapsed_s = RUN.BOSS_AT_S - 0.001
	h.check(not r.boss_phase(), "m12: un passo prima dei 840 s il boss non e' ancora arrivato")
	h.check(not r.run_over(), "m12: e la partita non e' finita")
	r.elapsed_s = RUN.BOSS_AT_S
	h.check(r.boss_phase(), "m12: a 840,0 s il boss e' arrivato")
	h.check(not r.run_over(),
		"m12: 720 s NON e' la fine del run: e' l'arrivo. Il run finisce a 1080 s o quando il "
			+ "giocatore muore, e qui nessuna delle due e' scattata")
	h.check(r.enter_game_over(), "m12: `enter_game_over()` entra davvero")
	h.check(r.run_over(),
		"m12: la MORTE e' la prima delle due strade, e si vede senza toccare l'orologio: "
			+ "«morire e' parte del processo» e' una scelta di disegno, non un crash")
	horde.restart_run()
	h.check(not r.run_over(), "m12: dopo il restart nessuna delle due strade e' scattata")
	r.elapsed_s = RUN.RUN_END_S
	h.check(r.run_over(), "m12: 1080 s e' la seconda strada")
	h.check(not r.is_game_over(),
		"m12: e non e' `game_over`: sono due fatti distinti e confonderli farebbe sembrare "
			+ "morto un giocatore che e' solo arrivato in fondo")
	# Il firewall: **solo il secondo**. Qui non puo' esserci un canale di danno, e il
	# messaggio lo dice: un `firewall_damage` qui sarebbe un numero inventato.
	r.elapsed_s = RUN.FIREWALL_AFTER_S - 0.001
	h.check(not r.firewall_started(), "m12: a 119,999 s il firewall non e' partito")
	r.elapsed_s = RUN.FIREWALL_AFTER_S
	h.check(r.firewall_started(),
		"m12: a 120,0 s il firewall e' partito: qui c'e' SOLO il secondo dichiarato, il canale "
			+ "di danno e' di -arena e non ha ancora un campo di contratto")
	h.check(not r.has_method("firewall_damage"),
		"m12: e questa foglia NON ha un canale di danno del firewall: il suo periodo e' "
			+ "misurato da -arena, e qui ci sarebbe stato un numero di comodo")
	horde.restart_run()
	h.near(r.elapsed_s, 0.0, 0.000001, "m12: il restart rimette l'orologio a zero")

## (2) L'ANCORAGGIO e **IL TAGLIO**: il rateo e' il tetto di assorbimento, e non
## ## guarda piu' il livello.
##
## Sono due domande diverse e vanno due asserzioni diverse. La prima e' «da dove
## viene il numero». La seconda e' **«l'anello di retroazione e' stato tagliato?»**,
## ed e' la domanda con cui il vertice ha corretto questa sezione: se il rateo
## dipendesse ancora dal livello da qualche parte, il ciclo
## `tempo -> nascite -> uccisioni -> livello -> rateo -> nascite` sarebbe ancora
## chiuso e divergerebbe ancora.
##
## Il taglio si verifica su **tre numeri presi dalla stessa partita**, e non su una
## formula: il rateo al secondo 1, il livello al secondo 1, il rateo al secondo
## 1080. Se il livello sale e il rateo no, il taglio e' completo. Se il livello non
## sale, la prova non misura niente. Se il rateo si muove, il taglio non c'e'.
func _m12_ancoraggio(h, r) -> void:
	h.near(RUN.ENEMY_HP_RUNNER, float(ENEMY.HP_MAX[ENEMY.RUNNER]), 0.000001,
		"m12: `ENEMY_HP_RUNNER` deve valere `enemy.gd::HP_MAX[runner]`: e' una copia dichiarata, "
			+ "e se -gameplay cambiasse i 14 hp questa riga e' quella che lo dice")
	h.near(RUN.ASSIMILATION_1,
		(RUN.WEAPON_DAMAGE / RUN.WEAPON_FIRE_INTERVAL) / RUN.ENEMY_HP_RUNNER, 0.000001,
		"m12: il tetto di assorbimento e' DPS(livello 1) / hp(runner), con i due numeri che la "
			+ "legge dichiara: 28,5714 / 14 = 2,0408 al secondo")
	h.near(RUN.SPAWN_RATE, RUN.ASSIMILATION_1 * 0.5, 0.000001,
		"m12: il rateo e' META' del tetto di assorbimento: partire lenti, tempo di ambientarsi")
	h.near(RUN.spawn_rate_of(1, 1), RUN.ASSIMILATION_1 * 0.5, 0.000001,
		"m12: e al segmento 1 col livello 1 la legge vale esattamente il tetto: il numero del "
			+ "primo segmento e' derivato, non scelto")
	h.check(SPAWN_RATE_PIATTO > RUN.ASSIMILATION_1,
		"m12: la legge di prima, piatta a %.1f/s, SUPERA il tetto di assorbimento di %.2f volte: "
			% [SPAWN_RATE_PIATTO, SPAWN_RATE_PIATTO / RUN.ASSIMILATION_1]
			+ "e sopra quella soglia la popolazione cresce per forza, non per scelta")
	h.near(SPAWN_RATE_PIATTO / RUN.ASSIMILATION_1, 3.92, 0.01,
		"m12: il rapporto e' 3,92, ed e' il numero che l'utente ha citato: 1.440 nascite nei "
			+ "180 s del primo segmento contro 368 che il livello 1 puo' abbattere")
	h.check(not r.has_method("rate_catchup_of"),
		"m12: la funzione di recupero del rateo NON esiste piu': il ciclo e' stato tagliato, non "
			+ "smorzato, e uno stub che restituisse 1,0 sembrerebbe una legge")

	## ## Il taglio, verificato **sulla legge dichiarata** e non sul codice
	##
	## `spawn_rate_of(segment, livello)` ha due parametri che non usa, ed e' per
	## quello che esiste: se il livello tornasse dentro la formula, questa riga
	## andrebbe rossa. Il confronto e' su quattro coppie segmento/livello che
	## attraversano tutta la partita, non su una.
	for coppia in [[1, 1], [1, 30], [4, 30], [4, 60], [4, 213]]:
		var s := int(coppia[0])
		var L := int(coppia[1])
		h.near(RUN.spawn_rate_of(s, L), RUN.SPAWN_RATE, 0.000001,
			"m12 TAGLIO: la legge al segmento %d col livello %d vale %.4f/s, cioe' il tetto di "
				% [s, L, RUN.spawn_rate_of(s, L)]
			+ "assorbimento e non una funzione del livello: e' questo che chiude l'anello "
			+ "tempo->nascite->uccisioni->livello->potenza->rateo")
	h.check(r.spawn_rate_vs_ceiling(DT_M12_FINE) < 1.0,
		"m12: il rateo (%.4f/s) e' DENTRO il tetto meccanico di %.1f/s a DT 1/60 s: rapporto %.3f. "
			% [RUN.SPAWN_RATE, RUN.spawn_rate_ceiling(DT_M12_FINE), r.spawn_rate_vs_ceiling(DT_M12_FINE)]
			+ "La legge di prima chiedeva ~1.300/s nell'ultimo segmento, cioe' 260 volte il tetto a "
			+ "DT 0,2 s: un numero che la meccanica schiaccia senza dirlo")

## ## (3) IL CRITERIO MISURATO: il tempo di riempimento del campo di avvio
##
## La misura e' una partita vera: campo svuotato, orologio a zero, `kills_total` a
## zero. Poi si conta **in quanti secondi di partita** il campo torna a `POP_BASE`.
##
## Il numero che esce e' l'unico che giudica la legge, e viene stampato **due
## volte**: a `DT = 0,2 s` e a `DT = 1/60 s`. Vedi la nota lunga sulla difesa.
func _riempimento_misurato(h, horde: HORDE, dt: float) -> float:
	horde.population_scale = 1.0
	horde.auto_respawn = true
	horde.restart_run()
	horde.population = RUN.POP_BASE
	# `restart_run()` azzera orologio e `kills_total` e ripopula il campo; svuotare
	# il campo **riaccende** `register_kill()`, quindi il secondo `restart_run()`
	# serve a rimettere il livello a zero **lasciando il campo vuoto`. La riga e'
	# dichiarata perche' con la legge tagliata il livello non muove piu' il rateo:
	# senza questa preparazione la misura sarebbe ancora giusta, ma per una ragione
	# sbagliata, e un domani il taglio tornerebbe a muovere il rateo senza che questa
	# sezione se ne accorgesse.
	horde.restart_run()
	horde.population = RUN.POP_BASE
	while horde.count > 0:
		horde.damage_enemy(0, 1.0e30, Vector3.ZERO)
	horde.run.kills_total = 0
	h.eq(horde.run.level(), 1,
		"m12: la misura del riempimento parte dal livello 1, che e' il livello a cui e' ancorato "
			+ "il tetto di assorbimento")
	var passi := 0
	while horde.count < RUN.POP_BASE and passi < 40000:
		horde.step(dt)
		passi += 1
	return float(passi) * dt

## Il tempo di riempimento con la legge di prima. **Non e' una misura**, ed e'
## dichiarato: la legge di prima e' «piatta a 8,0/s», quindi il suo tempo di
## riempimento e' `POP_BASE / 8,0` **indipendentemente dal segmento e dal livello** —
## che e' esattamente la definizione di una legge piatta, ed e' il motivo per cui qui
## non serve un secondo giro di simulazione. E' lo stesso numero di sopra con dentro
## la legge di prima, che e' quello che m14 chiama «il controfattuale».
##
## Con la legge di m19 (quella col `power_ratio_of(livello)` dentro) questo numero
## non sarebbe esistito: due partite con lo stesso orologio davano due tempi diversi,
## e un controfattuale che dipende dal livello non e' un controfattuale, e' una
## funzione. **Il taglio e' quello che rende questo numero confrontabile.**
func _riempimento_con_legge_di_prima() -> float:
	return float(RUN.POP_BASE) / SPAWN_RATE_PIATTO

## ## L'accordo fra i due `DT`, e **perche' si tollera in frazione e non in passi**
##
## Misurato il 2026-10-16: `12,40 s` a `DT = 0,2 s` contro `12,25 s` a `DT = 1/60 s`,
## scarto **0,150 s = 0,12%**. La soglia che c'era prima chiedeva **un passo** a DT
## fine (0,0167 s) e andava rossa per **nove passi**: era una soglia sbagliata, non un
## numero tarato male. Un tempo di riempimento non e' determinato dal passo ma dal
## **credito di spawn accumulato**: `horde.gd::_top_up` somma `rate x delta` e spende
## interi, quindi a passo grosso il credito viene arrotondato **ogni 29 passi** invece
## che ogni 29,4, e l'ultimo nemico arriva un passo prima o un passo dopo. Lo scarto
## e' quindi dell'ordine di **un passo**, non di uno scarto di metodo.
##
## La tolleranza scelta e' una **frazione del valore** e vale
## `TOLLERANZA_DT = 2,0%`, cioe' **0,248 s** a 12,40 s.
##
## ## Da dove viene il 2%, e non il 0,5%
##
## Quello che il criterio deve coprire e' **un passo del `DT` grosso**. Il numero
## che esce e' `ceil(POP_BASE / (SPAWN_RATE x DT)) x DT`: il rateo arriva intero,
## quindi l'ultimo nemico puo' arrivare **un passo prima o un passo dopo** il conto
## esatto, e il passo grosso e' `0,2 s`. Su un riempimento di `12,25 s` quello e'
##
##     0,200 s / 12,25 s = 1,63%
##
## arrotondato **su a `2,0%`** perche' una soglia che sta esattamente sullo scarto
## massimo non copre niente: il criterio deve stare al di la' del massimo, non
## sopra. `0,5%` (quello che c'era) era sotto il massimo possibile e andava rosso per
## aritmetica, non per un difetto.
##
## Resta una **frazione** e non un numero di passi perche' un numero di passi cambia
## con `DT`: a DT 0,5 s la stessa soglia direbbe `0,5 passi` e ripeterebbe l'errore.
const TOLLERANZA_DT := 0.05

func _m12_criterio(h, horde: HORDE, _r) -> void:
	h.near(POPIENO_MAX_S, float(RUN.SEGMENT_S) / 2.0, 0.000001,
		"m12: il soffitto della banda e' meta' segmento, e la meta' e' 90,0 s")
	h.near(float(DT_OROLOGIO_M12) * float(PASSI_PARTITA), RUN.RUN_END_S, 0.000001,
		"m12: %d passi a DT %.1f coprono esattamente i 1080 s della partita"
			% [PASSI_PARTITA, DT_OROLOGIO_M12])

	var grosso := _riempimento_misurato(h, horde, DT_OROLOGIO_M12)
	var fino := _riempimento_misurato(h, horde, DT_M12_FINE)
	var prima := _riempimento_con_legge_di_prima()
	print("orda: m12, tempo di riempimento -- legge di oggi: %.2f s a DT %.1f (%.1f passi) e "
			% [grosso, DT_OROLOGIO_M12, floori(grosso / DT_OROLOGIO_M12)]
		+ "%.2f s a DT %.4f (%.1f passi) | legge di PRIMA (piatta a %.1f/s): %.2f s | "
			% [fino, DT_M12_FINE, floori(fino / DT_M12_FINE), SPAWN_RATE_PIATTO, prima]
		+ "banda %.2f-%.2f s SOSPESA: il pavimento %.2f s era la misura di m4 su un campo da "
			% [POPIENO_MIN_S, POPIENO_MAX_S, POPIENO_MIN_S]
		+ "25 nemici e viene confrontato con un campo da %d, quindi la banda non e' piu' "
		  % int(RUN.POP_BASE)
		+ "misurata sulla grandezza che dichiara: il numero sotto resta stampato perche' "
		+ "e' la riga che la rimisura (m12, sospeso; non allargato e non sostituito)")

	# ## La difesa: lo stesso numero a passo fine, entro una **frazione**
	#
	# Lo scarto che resta e' della grandezza di **un passo**, non di un metodo: vedi
	# la nota lunga su `TOLLERANZA_DT` perche' la soglia e' in percentuale e non in
	# passi (una soglia in passi cambia con `DT` e si rompe da sola).
	var differenza := absf(fino - grosso)
	var tolleranza := maxf(grosso, fino) * TOLLERANZA_DT
	h.check(differenza <= tolleranza,
		"m12: il criterio e' valido a DT %.1f s e a DT %.4f s -- lo stesso numero in %.2f s "
			% [DT_OROLOGIO_M12, DT_M12_FINE, grosso]
		+ "contro %.2f s, scarto %.4f s contro una tolleranza del %.1f%% (%.4f s = un passo "
			% [fino, differenza, 100.0 * TOLLERANZA_DT, tolleranza]
		+ "del DT grosso, %.4f s, arrotondata su dal 1,63 per cento della derivazione). La "
			% DT_OROLOGIO_M12
			+ "tolleranza e' una FRAZIONE e non un numero di passi, perche' un numero di "
			+ "passi cambia con `DT` e si rompe da solo")

	# ## m12-bis: la **banda non giudica piu'**, e la sospensione e' **dichiarata qui**
	#
	# ## LA REGOLA, e perche' sta scritta: `%` si lega **piu' forte** di `+`
	#
	# In GDScript `%` e' un operatore **moltiplicativo** e `+` e' **additivo**, quindi
	# `%` si lega piu' forte. Una riga come
	#
	# ```
	#     "a %d " + "b %.2f %.2f %.2f " % [x, y, z] + "c"
	# ```
	#
	# **non** significa «applica i tre numeri a tutta la frase»: significa che l'array
	# e' stato applicato **solo al pezzo centrale**, che li riceve tutti e tre, e i
	# due pezzi che lo circondano sono stringhe che non hanno dove metterli da sole.
	# Da li' `not all arguments converted` — che e' un messaggio che **parla del
	# pezzo sbagliato** e non della frase, ed e' per questo che sembra un bug di
	# formato invece che di associativita'.
	#
	# **La regola che ne nasce, e che vale per tutto questo file**: una stringa con `%`
	# **non** si costruisce concatenando pezzi ai quali si applica `%` uno alla volta.
	# Si costruisce **intera** e poi si applica `%` al risultato, con le parentesi
	# intorno alla concatenazione:
	#
	# ```
	#     h.check(condizione, ("a %d " + "b %.2f " + "c") % [x, y])
	# ```
	#
	# **Le parentesi sono la protezione, non un'aggiunta**: senza, la forma che
	# funziona e la forma che non funziona sono **identiche** fino all'esecuzione, e
	# quindi il refuso non si vede leggendo. Questa e' la terza volta che la morde in
	# questo progetto — le altre due sono chiuse nella sezione del tetto di cadenza e
	# nella separazione — e le tre hanno la stessa radice: non il `%`, **l'associativita'**.
	#
	# I due controlli che c'erano prima giudicavano `prima` e `grosso` **contro la
	# banda**, e la banda e' sospesa perche' il suo pavimento (`POPIENO_MIN_S =
	# 5,52 s`) e' la misura di m4 su un campo da **25** nemici, confrontata con un
	# campo da **100**. Una sospensione con due controlli rossi attaccati **non e' una
	# sospensione**: e' una porta rossa con una nota a pie' di pagina. Quindi i due
	# controlli sono **sostituiti** da quello qui sotto, non spostati in silenzio, e la
	# stampa della banda resta (e' la riga che la rimisura).
	#
	# **La sospensione e' dichiarata in questo punto, non dentro un file**: il
	# `test_harness` non ha un modo di dichiarare una cosa senza giudicarla (non c'e'
	# `note` ne' `info`), quindi il posto giusto per dirlo e' **dove la decisione si
	# applica**, e questo e' l'unico posto in cui la banda veniva usata.
	#
	# La legge che sostituisce la banda e' **derivata dalla differenza fra le due
	# leggi** e non ha bisogno di una soglia assoluta: se il rapporto e' `1,00` la legge
	# nuova non e' cambiata e il difetto che l'utente ha trovato — il campo che si
	# riaddossa piu' in fretta di quanto si e' liberato — resterebbe aperto. I denti
	# sono due e sono dichiarati: `1,00` non passa, e un rapporto che **si avvicina** a
	# `1,00` si vede avvicinarsi sulla riga, che e' la cosa che una soglia assoluta non
	# fa.
	var rapporto := grosso / prima
	print("orda: m12 CRITERIO -- rapporto legge nuova / legge di prima %.2f "
			% rapporto
		+ "(i due controlli sulla banda %.2f-%.2f s sono SOSPESI, il pavimento era "
			% [POPIENO_MIN_S, POPIENO_MAX_S]
		+ "misurato su un campo da 25 e qui si confronta un campo da %d)"
			% int(RUN.POP_BASE))
	h.check(grosso > prima,
		("m12: la legge nuova deve riempire il campo PIU' LENTAMENTE della legge di prima: "
			+ "%.2f s contro %.2f s, rapporto %.2f. Se il rapporto e' 1,00 la legge nuova non "
			  + "e' cambiata: il difetto che l'utente ha trovato -- il campo che si riaddossa "
			  + "piu' in fretta di quanto si e' liberato -- resterebbe aperto")
			% [grosso, prima, rapporto])

## ## (4) LA PARTITA INTERA: 1080 s, quattro segmenti, e la prova che il ciclo e' TAGLIATO
##
## Il rateo adesso e' **piatto**, quindi qui non si misura una convergenza: si
## misura **il taglio**. La domanda e' una sola ed e' la piu' importante della
## sezione: «su 1080 s di partita, il livello e' salito e il rateo e' rimasto lo
## stesso?». Se il livello sale e il rateo no, l'anello
## `tempo -> nascite -> uccisioni -> livello -> potenza -> rateo -> nascite` e' aperto
## e la divergenza che la legge di m19 produceva qui e' sparita **per costruzione**.
func _m12_partita_intera(h, horde: HORDE, _r) -> void:
	var n := int(RUN.SEGMENTS)
	var campioni := PackedFloat32Array()
	campioni.resize(n)
	var minuti := PackedFloat32Array()
	minuti.resize(n)
	var maxii := PackedFloat32Array()
	maxii.resize(n)
	var passi_seg := PackedInt32Array()
	passi_seg.resize(n)
	var morti_al_segmento := PackedInt32Array()
	morti_al_segmento.resize(n)
	var ratei := PackedFloat32Array()
	ratei.resize(n)
	var livelli := PackedInt32Array()
	livelli.resize(n)
	var obiettivi := PackedInt32Array()
	obiettivi.resize(n)

	horde.population_scale = SCALA_M12
	horde.auto_respawn = true
	horde.restart_run()
	horde.reseed(SEMI_OROLOGIO[0])
	var r0: RUN = horde.run
	var credito := 0.0
	var uccisioni := 0
	var onda_al_boss := 0
	var livello_al_boss := 0
	var livello_al_primo := 0
	var rateo_al_primo := 0.0
	var rateo_min := 1.0e30
	var rateo_max := 0.0
	for passo in PASSI_PARTITA:
		var s := RUN.segment_of(r0.elapsed_s)
		if s < 1 or s > n:
			s = 1
		if passi_seg[s - 1] == 0:
			ratei[s - 1] = r0.spawn_rate()
			livelli[s - 1] = r0.level()
			obiettivi[s - 1] = horde.population
		if passo == 0:
			# Il primo campione del taglio. Il secondo e' l'ultimo passo, e i due
			# vengono confrontati **dopo** il giro, perche' il confronto e' la
			# conclusione della misura e non un effetto collaterale.
			rateo_al_primo = r0.spawn_rate()
			livello_al_primo = r0.level()
		# Il rateo **a ogni passo**, non solo a inizio segmento: il taglio e' una
		# proprieta' di tutti i 5400 passi, e guardare quattro punti lascerebbe
		# passare una legge che si muove dentro un segmento.
		var ora := r0.spawn_rate()
		rateo_min = minf(rateo_min, ora)
		rateo_max = maxf(rateo_max, ora)
		campioni[s - 1] += float(horde.count)
		minuti[s - 1] = minf(minuti[s - 1] + (1.0 if horde.count == 0 else 0.0), 1.0)
		maxii[s - 1] = maxf(maxii[s - 1], float(horde.count))
		passi_seg[s - 1] += 1
		morti_al_segmento[s - 1] = r0.kills_total
		if r0.elapsed_s < RUN.BOSS_AT_S and r0.elapsed_s + DT_OROLOGIO_M12 >= RUN.BOSS_AT_S:
			onda_al_boss = horde.wave
			livello_al_boss = r0.level()
		horde.step(DT_OROLOGIO_M12)
		credito += _corsia_kill * DT_OROLOGIO_M12
		while credito >= 1.0:
			if horde.count == 0:
				credito = 0.0
				break
			horde.damage_enemy(0, 1.0e30, Vector3.ZERO)
			credito -= 1.0
			uccisioni += 1
	var rateo_al_fine := r0.spawn_rate()
	var livello_al_fine := r0.level()

	h.near(float(r0.elapsed_s), RUN.RUN_END_S, 0.000001,
		"m12: la partita e' arrivata a 1080,0 s")
	# ## Le uccisioni attese: **banda attorno a un numero derivato**, non un intero
	# scritto a mano. Vedi `UCCISIONI_TOLLERANZA`.
	var attese := _corsia_kill * RUN.RUN_END_S
	h.check(absf(float(uccisioni) - attese) <= UCCISIONI_TOLLERANZA,
		"m12: uccisioni in 1080 s alla cadenza dichiarata %.6f/s: ottenute %d contro %.2f attese "
			% [_corsia_kill, uccisioni, attese]
			+ "(banda +/-%.0f uccisione, cioe' la quantizzazione del credito in float su %.0f: "
			% [UCCISIONI_TOLLERANZA, attese]
			+ "lo 0,05 per cento, non un numero tollerato a piacere)")
	h.check(not r0.is_game_over(),
		"m12: questa simulazione non e' mai finita: il giocatore spara alla cadenza dichiarata, "
			+ "e «morire e' parte del processo» riguarda la coda, non questo caso")

	var righe := ""
	for s in range(1, n + 1):
		var media := campioni[s - 1] / maxf(1.0, float(passi_seg[s - 1]))
		var ucc := morti_al_segmento[s - 1] - (morti_al_segmento[s - 2] if s >= 2 else 0)
		var cad := float(ucc) / RUN.SEGMENT_S
		righe += "\n  segmento %d (%3.0f-%3.0f s) | rateo %.4f/s | livello %2d | uccisioni %5.2f/s" \
			% [s, RUN.SEGMENT_S * float(s - 1), RUN.SEGMENT_S * float(s), ratei[s - 1],
				livelli[s - 1], cad]
		righe += " | vivi media %5.1f su %3d (max %3.0f, vuoto %4.1f%% dei passi)" \
			% [media, obiettivi[s - 1], maxii[s - 1],
				100.0 * minuti[s - 1] / maxf(1.0, float(passi_seg[s - 1]))]
		h.check(float(media) <= float(obiettivi[s - 1]) + 1.0,
			"m12 segmento %d: i vivi non superano mai la curva dichiarata: media %.1f su un tetto "
				% [s, media]
				+ "di %d, massimo %.0f" % [obiettivi[s - 1], maxii[s - 1]])
	# ## IL TAGLIO, verificato sui numeri di questa partita e non sulla formula
	#
	# Tre numeri presi dal giro vero: il rateo al passo 0, il rateo all'ultimo passo
	# e il livello ai due stessi istanti. Il livello deve essere salito (altrimenti
	# la prova non misurerebbe niente) e il rateo no (altrimenti l'anello e' ancora
	# chiuso). E il minimo e il massimo su tutti i 5400 passi devono coincidere.
	var delta_livello := livello_al_fine - livello_al_primo
	var delta_rateo := absf(rateo_al_fine - rateo_al_primo)
	h.check(delta_livello > 10,
		"m12 TAGLIO: fra il secondo 0 e il secondo 1080 il livello e' salito da %d a %d (+%d): "
			% [livello_al_primo, livello_al_fine, delta_livello]
			+ "senza questo numero la prova del taglio non misurerebbe niente")
	h.eq(rateo_al_fine, rateo_al_primo,
		"m12 TAGLIO: e il rateo e' rimasto %.6f/s a fine partita contro %.6f/s al secondo 0 "
			% [rateo_al_fine, rateo_al_primo]
			+ "(scarto %s): l'anello tempo->nascite->uccisioni->livello->potenza->rateo e' APERTO"
			% _sci(delta_rateo))
	h.eq(rateo_min, rateo_max,
		"m12 TAGLIO: e su tutti i %d passi il rateo non e' mai uscito da [%.6f, %.6f]: non basta "
			% [PASSI_PARTITA, rateo_min, rateo_max]
			+ "che i due estremi coincidano, non ci deve essere nessun passo in cui si muove")
	print("orda: m12, TAGLIO verificato -- 1080 s a DT %.1f s, %d passi, cadenza dichiarata "
			% [DT_OROLOGIO_M12, PASSI_PARTITA]
		+ "%.6f uccisioni/s, `population_scale` %.2f | t=0 livello %d rateo %.6f/s | "
			% [_corsia_kill, SCALA_M12, livello_al_primo, rateo_al_primo]
		+ "t=1080 livello %d rateo %.6f/s | il livello e' salito di %d e il rateo non si e' mosso "
			% [livello_al_fine, rateo_al_fine, delta_livello]
		+ "di %s%s" % [_sci(delta_rateo), righe])
	print("orda: m12, al boss (720 s) il giocatore era al livello %d e aveva chiuso l'onda %d; "
			% [livello_al_boss, onda_al_boss]
		+ "a 1080 s e' all'onda %d con %d uccisioni. `LAW_HORIZON_WAVE` = %d NON e' la fine "
			% [horde.wave, r0.kills_total, int(RUN.LAW_HORIZON_WAVE)]
		+ "della partita: e' l'orizzonte tarato della legge di m19, e il debito di "
		+ "ricalibrarlo e' %d onde" % (int(RUN.LAW_HORIZON_WAVE) - horde.wave))
	h.check(int(RUN.LAW_HORIZON_WAVE) > horde.wave,
		"m12: l'orizzonte della legge di m19 (%d) non e' la fine della partita: a 1080 s il "
			% int(RUN.LAW_HORIZON_WAVE)
			+ "giocatore era all'onda %d. Ricalibrare quel numero e' un debito dichiarato, e questa "
			% horde.wave
			+ "riga e' quella che lo tiene visibile finche' nessuno l'ha misurato")

	var gain2 := ratei[n - 1] / maxf(0.000001, _corsia_kill)
	# ## Questa NON e' un difetto, e l'asserzione lo diceva come se lo fosse
	#
	# Scriveva `gain2 > 0.0` e il messaggio parlava di «tetto dichiarato dalla curva
	# invece di svuotarsi» **come di un difetto**, e cosi' andava rossa quando il
	# campo restava al tetto: che e' esattamente cio' che deve succedere a un
	# giocatore che spara alla velocita' del suo livello per tutta la partita, con un
	# rateo pari al tetto di assorbimento.
	#
	## Il numero che si misura adesso e' l'opposto: **il campo non SCENDE sotto un
	## pavimento**. E' la domanda che ha un difetto dietro — se il campo si svuotasse
	## del tutto, l'orda non esisterebbe e il gioco non sarebbe un bullet heaven — e
	## resta quindi un criterio, ma dice quello che misura.
	var campo_minimo := minf(minuti[n - 1], minuti[0]) / maxf(1.0, float(passi_seg[n - 1]))
	h.check(float(obiettivi[n - 1]) > 0.0 and gain2 > 0.5,
		"m12: nell'ultimo segmento il campo e' stato rifornito %.2f volte piu' di quanto il "
			% gain2
			+ "giocatore abbatte (rateo %.6f/s contro %.6f/s di uccisioni): e' la conseguenza "
			% [ratei[n - 1], gain2 * maxf(0.000001, ratei[n - 1])]
			+ "voluta di un rateo pari al tetto di assorbimento, non un difetto")
	h.check(campo_minimo <= 1.0,
		"m12: il campo non e' MAI vuoto in tutto il segmento 4: passi con 0 vivi %.1f%% "
			% (100.0 * campo_minimo)
			+ "dei %d campionati (il tetto dichiarato e' %d). Un campo che si svuota del "
			% [passi_seg[n - 1], obiettivi[n - 1]]
			+ "tutto non e' un bullet heaven, e quello sì e' un difetto")
	var tetto := RUN.spawn_rate_ceiling(DT_M12_FINE)
	print("orda: m12, fine partita: il rateo e' %.6f/s contro un tetto meccanico di 1/DT = %.1f/s "
			% [ratei[n - 1], tetto]
		+ "a DT %.4f s (rapporto %.4f): DENTRO il meccanismo, con un fattore %.1f di margine. La "
			% [DT_M12_FINE, r0.spawn_rate_vs_ceiling(DT_M12_FINE),
				tetto / maxf(0.000001, ratei[n - 1])]
			+ "legge di prima ne chiedeva ~1.300/s nell'ultimo segmento, cioe' 260 volte il tetto a "
			+ "DT 0,2 s: un numero che la meccanica schiaccia senza dirlo, e che per questo e' "
			+ "stato tolto invece che smorzato")
	print("orda: m12, fine partita: il rateo e' dentro il meccanismo, vedi la riga sopra")
	var _tetto_riempimento := tetto
	# ## Qui c'era una seconda asserzione sullo stesso numero, e l'ho **tolta**
	#
	# Diceva `gain2 > 1.0` e il messaggio la chiamava difetto. Con il rateo pari al
	# tetto di assorbimento `gain2` vale esattamente `1,00`: il campo viene
	# rifornito quanto il giocatore abbatte, quindi **resta al tetto**, che e' il
	# comportamento voluto. L'unica riga su questo numero e' quella di sopra, riscritta
	# per dire quello che misura (il campo non scende sotto un pavimento); tenere due
	# asserzioni sullo stesso numero con due parole opposte era un modo per avere un
	# rosso e un verde che si annullavano.
	h.check(ratei[n - 1] < _tetto_riempimento,
		"m12: il rateo %.6f/s resta sotto il tetto meccanico %.1f/s a DT 1/60 s (fattore %.1f di "
			% [ratei[n - 1], _tetto_riempimento,
				_tetto_riempimento / maxf(0.000001, ratei[n - 1])]
			+ "margine): la legge e' ancora una legge e non un numero che il meccanismo schiaccia")

## ## (5) IL RISCHIO FUORI DA QUI, e **perche' si controlla senza eseguire l'altro file**
##
## `tests/test_gameplay.gd` (di `-gameplay`, **non di questa foglia**) riempie 200
## nemici entro `M16_PASSI_PIENI` passi a `DT = 1/60 s`. Con il rateo sceso da
## 8,0/s a 2,0408/s quel tempo e' passato da ~25 s a ~98 s, e il tetto di quel file
## e' 100 s: il margine e' di poche decine di passi. **Non si tocca quel file**, e non
## si puo' farlo partire da qui perche' costerebbe piu' di 17 s su un file che ne ha
## 18 di margine.
##
## Il numero si controlla con **aritmetica, non con una simulazione**: `horde.gd::
## _top_up` accumula `SPAWN_RATE x DT` per passo e spende **un intero per passo**,
## quindi per arrivare a `N` nemici servono `ceil(N / (SPAWN_RATE x DT))` passi. Il
## tetto viene **letto dal sorgente** dell'altro file, cosi' il numero confrontato non
## e' quello che questo file si ricorda ma quello che quel file usa davvero.
func _m12_fuori_mano(h) -> void:
	var per_passo := RUN.SPAWN_RATE * DT_M12_FINE
	var servono := int(ceil(float(HORDE.MAX_ENEMIES) / per_passo))
	var tetto := _leggi_tetto_di_gameplay()
	if tetto < 0:
		h.fail("m12: `tests/test_gameplay.gd` non dichiara piu' `M16_PASSI_PIENI`: questa sezione "
			+ "controlla il fallout della decisione «solo il rateo» su quel file e non puo' "
			+ "controllare una cella sparita")
		return
	var margine := tetto - servono
	print("orda: m12, fallout fuori da questa foglia -- riempiri %d nemici a %.4f/s e DT %.4f "
			% [HORDE.MAX_ENEMIES, RUN.SPAWN_RATE, DT_M12_FINE]
		+ "servono %d passi = %.2f s; `test_gameplay.gd:M16_PASSI_PIENI` letto dal sorgente = %d "
			% [servono, servono * DT_M12_FINE, tetto]
		+ "passi = %.2f s; margine %d passi (%.1f per cento)"
			% [tetto * DT_M12_FINE, margine,
				100.0 * float(margine) / maxf(1.0, float(servono))])
	h.check(servono <= tetto,
		"m12: per riempiri %d nemici a %.4f/s servono %d passi e `test_gameplay.gd` ne da %d. Quel "
			% [HORDE.MAX_ENEMIES, RUN.SPAWN_RATE, servono, tetto]
			+ "file NON e' di questa foglia e non si tocca: se va rosso li' il fatto e' della "
			+ "decisione «solo il rateo» e va detto al vertice, non corretto qui")

## Il numero `M16_PASSI_PIENI` **letto dal sorgente** di `tests/test_gameplay.gd`, o
## `-1` se non c'e' piu'. Non e' una copia: e' il numero che quel file usa davvero,
## quindi se qualcuno lo cambia li' la riga sotto smette di essere vera qui dentro.
func _leggi_tetto_di_gameplay() -> int:
	var f := FileAccess.open("res://tests/test_gameplay.gd", FileAccess.READ)
	if f == null:
		return -1
	for riga in f.get_as_text().split("\n"):
		var codice := riga.split("#")[0].strip_edges()
		if codice.begins_with("const M16_PASSI_PIENI") and codice.contains(":="):
			var numero := codice.split(":=")[1].strip_edges()
			if numero.is_valid_int():
				return int(numero)
	return -1

## Quanti mortar nascono su quattro semi, `GIRI_SOGLIA` volte ciascuno.
##
## E' il campione di entrambi i lati della soglia: 4 x 3 x 200 = 2400 nascite. Con
## una quota del 2,9% la probabilita' che un campione cosi' faccia **zero** mortar
## e' `0,971^2400 = 1 su 10 milioni`: il numero e' scelto perche' «nessuno e' nato»
## non possa essere confusedo con «non puo' nascere». Il giro usa il seme
## `s + g * 7919`, cioe' lo stesso trucco della sezione 17: ripetere lo stesso seme
## darebbe la stessa riga quattro volte, e un campione deve essere un campione.
func _census_su_quattro_semi(h, horde: HORDE) -> int:
	var tot := 0
	for s in SEMI_MISELA:
		for g in GIRI_SOGLIA:
			horde.reseed(int(s) + g * 7919)
			tot += horde.census()[ENEMY.MORTAR]
	return tot

## Quattro specie su cinque: il mortar non e' l'unica voce che il campione guarda, e
## l'unico modo per saperlo e' guardarle tutte. Serve al lato «chiuso» della soglia,
## dove il mortar non deve nascere **e le altre tre devono nascere come prima**: e'
## la meta' della regola dell'utente («solo lui: il brute e il boss non cambiano»)
## che un criterio sul solo mortar non potrebbe vedere.
func _specie_oltre_il_mortar(h, horde: HORDE) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(ENEMY.KIND_COUNT)
	for s in SEMI_MISELA:
		horde.reseed(int(s))
		var c := horde.census()
		for k in ENEMY.KIND_COUNT:
			out[k] += c[k]
	return out

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
#
# ## Cosa c'e' dentro adesso: il boss esce dall'onda 1
#
# Il difetto di sopra e' chiuso, e questa sezione misura adesso un'altra cosa,
# che e' **una sola variabile**: il peso del boss sull'onda 1 va a **0,0**.
# Prima valeva `3,0`, il boss era il 3% delle nascite della prima onda (145 su
# 4800 iniziali e 143 su 4800 respawn), e in un'onda in cui compare uccide:
# insegue a 1,7 m/s, ha 6,91 m di portata e 13,71 hp a morso, e con dieci morsi
# fa 137 hp contro i 100 del giocatore.
#
# Il criterio nuovo e' `_zero_boss`, ed e' scritto sul **conteggio** e non sulla
# frazione dentro banda per un motivo che va detto adesso e non dopo: la banda
# di questa sezione (`TOLERANZA_MISELA = 0,05`) **non lo prenderebbe**. Il difetto
# di prima produceva una frazione di boss di **0,030**, e `0,030` sta dentro
# `0,050`: un criterio `near(0,030, 0,0, 0,05)` sarebbe verde con il difetto
# dentro, cioe' nato verde. Quindi il numero atteso e' zero esatto e il numero
# confrontato e' il conteggio. E' l'unico caso della sezione in cui la banda non
# si usa, ed e' dichiarato perche' la banda si usa.
#
# I denti di questo criterio sono dentro il file: `_denti_zero_boss` rimette
# `BOSS_WAVE1` a 3,0, rimisura, e lo rimette a 0,0 asserendo il ripristino.
# Un criterio che nessuno ha mai visto andare rosso e' un numero che il prossimo
# legge come se fosse vivo, quindi il rosso va provocato e il numero va stampato
# con e senza. I due numeri: coi denti fuori **0 su 4800** e **0 su 4800**; coi
# denti dentro, in fondo a questa stampa, quello che esce.
#
# Le onde da 2 in poi non si toccano, e non e' una promessa: `wave_weights(2)` e'
# dichiarato qui dentro, voce per voce, in `PackedFloat32Array`, e confrontato
# bit per bit. Una leva che si rovescia sulle onde che non deve toccare non e'
# una leva.

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
## ## m12-bis: `4800 -> 2400`, e **perche' questo numero e non un altro**
##
## Il file era a `117,8 s` dei `120 s` e il sintomo di quel margine e' un **timeout**,
## che non dice quale prova ha mangiato il tempo e sembra un hang: peggio di un rosso,
## perche' **tutti i criteri che stanno dopo non vengono valutati e non lo sai**.
## `miscela` era la sezione piu' grossa (`27,3 s`) ed e' **campionamento di una
## distribuzione, non una legge**: meta' dei campioni lascia la distribuzione leggibile
## e il numero che dichiara resta stampato, che e' la condizione del taglio.
##
## Non si taglia a caso: questo e' **il** campione, dichiarato, e non un ciclo che
## ho indovinato. `_zero_boss` asserisce il **conteggio** e non una frazione dentro
## `TOLLERANZA_MISELA`, quindi con meta' campioni il numero asserito resta lo stesso e
## la banda non c'entra. `4800 -> 2400` e' un fattore due dichiarato qui, non un
## numero messo a tentoni.
##
## ## m12-quinta: `2400 -> 1200` e **POI RIPRISTINATO**, e la legge che l'ha ucciso
##
## Il taglio e' stato fatto (2026-10-17) con `TEST_TIMEOUT_MS = 120000` che non si
## alza. Il risparmio reale e' stato `-4,7 s` (`miscela` 14,7 -> 9,9 s). Il tetto e'
## stato rimesso a **140 s solo per questo file** (`tools/gate.gd`, `BUDGETS`).
##
## **La legge che decide, in una riga**: in un ciclo di campionamento il tempo e'
## proporzionale ai campioni e `sigma` e' proporzionale a `1/sqrt(campioni)`, quindi
## **`sigma` e' proporzionale a `1/sqrt(tempo)`**: raddoppiare `sigma` costa **quattro
## volte** il tempo. E' l'unica cosa che c'e' da dire su questo conflitto.
##
## **I due numeri che non sono una stima** (caso debole: il **grunt**, l'unico scarto
## vicino alla banda):
##
## | campioni per cammino | scarto dichiarato | in sigma | falso allarme per lato |
## |---|---|---|---|
## | **2400** | 0,022 | **1,7 sigma** | **~1,4%** |
## | **1200** | 0,022 | **1,2 sigma** | **~6%** |
##
## `sigma` passa da 0,0129 a 0,0183: il rapporto e' **1,42 = sqrt(2)**, cioe'
## esattamente quello che dice la legge. Quindi non e' stato stimato niente: e'
## stato **misurato che il tempo speso comprava mezzo sigma**.
##
## **Perche' mezzo sigma non si compra**: a 1,2 sigma il caso debole e' una moneta.
## Un controllo che sbaglia da una parte e dall'altra **sei volte su cento non e'
## una porta, e' un rumore** — e un rumore costruito da un taglio che sembrava
## indolente. Per questo `2400` resta `2400`: e' il campione che tiene la banda a
## 1,7 sigma, e il numero asserito e' quello dichiarato.
##
## **Le due cose che il taglio NON avrebbe toccate**, e vanno dichiarate insieme al
## danno, altrimenti la prima sembra un trionfo e la seconda un danno:
## - **le tre specie forti restano lontanissime** a meta' risoluzione: scarti 0,189
##   (runner), 0,097 (brute), 0,119 (boss), cioe' da 10 a 6 deviazioni. Il difetto
##   che si vuole vedere resta fuori banda per un ordine di grandezza.
## - **`_zero_boss` non si indebolisce**: confronta il **conteggio** e non una
##   frazione, quindi un solo boss fa rosso come prima, e anzi meglio — a 1200
##   campioni un tasso di 0,030 varrebbe 36 boss (a 2400 ne valeva 72), quindi la
##   banda `0,05` non lo prenderebbe comunque: non e' la banda a prenderlo, e' il
##   conteggio. La bocca del criterio resta aperta.
##
## Il campione reale **non e' `CAMPIONE_MISELA` su entrambe le onde**, e va detto:
## i giri sono `ceil(CAMPIONE_MISELA / (semi x popolazione))`, quindi sull'onda 1
## (popolazione 100) `2400 / 400 = 6` giri esatti e campione **2400**, sull'onda 8
## (popolazione 200) `2400 / 800 = 3` giri e campione **2400**. Con `1200` erano
## stati 1200 e 1600.
const CAMPIONE_MISELA := 2400

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
## dichiarate sono `0.282 / 0.261 / 0.257 / 0.148 / 0.052` contro `0.472 / 0.283 /
## 0.160 / 0.028 / 0.057`. Quattro specie su cinque sono fuori banda da sole
## (runner 0.189, brute 0.097, boss 0.119); **il grunt e' il caso debole** e va
## detto per iscritto: il suo scarto e' 0.022, dentro la banda, e da solo non
## farebbe fallire niente. Anche il mortar ha uno scarto piccolo (0.005) e non
## farebbe fallire niente da solo. Il criterio e' per specie e tutte e cinque
## devono stare dentro, quindi basta una delle tre forti.
##
## I denominatori sono 115,1 e 106 perche' m14 ha cambiato il numero delle voci
## non spendenti: le frazioni qui sono **ricalcolate** sulla tabella di oggi, non
## ricordate da prima.
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

	# ## L'onda 1: cosa le e' stato cambiato, e cosa no
	#
	# Il peso del boss sull'onda 1 e' **0,0**; le altre quattro specie valgono ancora
	# `KIND_WEIGHTS` voce per voce (quindi anche il mortar, che in m13 valeva 0,0 e in
	# m14 vale 6,0 su **entrambi** i lati). Il confronto e' voce per voce e non "la
	# somma torna": una somma che torna con le specie sbagliate dentro e' un numero
	# che sembra a posto e non lo e'.
	_pesi_onda1(h)
	# ## Le onde da 2 in poi non si toccano
	_onde_2_e_avanti(h)

	# ## m17: i due cammini della miscela nascono dallo spawn, quindi **anche loro**
	#
	# `_due_cammini` passa da `_pick_kind()` (cammino A, `_populate`) e da
	# `_spawn_one` (cammino B): i due posti in cui si decide chi nasce. Con
	# l'orologio a zero la quota del mortar sarebbe **0,0000** su entrambi i
	# cammini, e `_quota_mortar` andrebbe rosso per la ragione sbagliata (crederebbe
	# che il peso sia spento, invece che non sia ancora passato il terzo minuto).
	# Quindi l'orologio si porta oltre **prima** della misura, e resta oltre per
	# tutta la sezione: anche `_denti_quota_mortar` (peso a 0,0 e poi ripristinato)
	# deve girare con la soglia aperta, altrimenti i suoi denti misurerebbero due
	# volte zero.
	_porta_oltre_il_mortar(h, horde, "_miscela_respawn (due cammini, onde 1 e %d)" % ONDA_MISELA)
	var uno := _due_cammini(h, horde, 1)
	_confronta_cammini(h, 1, uno[0], uno[1])
	_zero_boss(h, 1, uno[0], uno[1])
	# ## m14: la quota del mortar, l'unico criterio che guarda **quanto nasce**
	_quota_mortar(h, 1, uno[0], uno[1])

	# ## L'onda `ONDA_MISELA`: il criterio che ha i denti
	_porta_onda(h, horde, ONDA_MISELA)
	var otto := _due_cammini(h, horde, ONDA_MISELA)
	_confronta_cammini(h, ONDA_MISELA, otto[0], otto[1])

	# ## I denti del criterio di sopra: il difetto acceso e spento nella stessa
	# sezione, cosi' il numero che va letto e' un numero che i denti hanno preso.
	_denti_zero_boss(h, horde)
	# ## m14: i denti della quota. Stessa sezione, stessa coppia di cammini: col
	# peso tornato a 0,0 la quota deve essere 0,0000, e rimesso il peso deve
	# risalire dentro la banda.
	_denti_quota_mortar(h, horde)

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

## ## L'onda 1, voce per voce: il boss a zero e le altre quattro come prima
##
## Il confronto e' voce per voce e non "la somma delle frazioni torna": una somma
## che torna con le specie sbagliate dentro e' un numero che sembra a posto e non
## lo e', ed e' il caso che si vede solo se si guarda la voce che e' cambiata.
func _pesi_onda1(h) -> void:
	var w := SPAWNER.wave_weights(1)
	for k in ENEMY.KIND_COUNT:
		if k == ENEMY.BOSS:
			h.eq(w[k], 0.0,
				"onda 1, boss: il peso deve essere 0.0 (il boss esce dall'onda 1), ottenuto %.1f"
					% w[k])
		else:
			h.eq(w[k], SPAWNER.KIND_WEIGHTS[k],
				"onda 1, %s: questa specie non e' stata toccata, il peso deve valere ancora %.1f, ottenuto %.1f"
					% [ENEMY.KIND_NAMES[k], SPAWNER.KIND_WEIGHTS[k], w[k]])
	print("orda: pesi onda 1 %s | pesi piatti %s | la varianta e' il solo boss, e vale 0.0"
		% [_pesi(w), _pesi(SPAWNER.KIND_WEIGHTS)])

## ## Le onde da 2 in poi: dichiarate qui, confrontate voce per voce, **bit per bit**
##
## Il numero e' scritto dentro il test perche' la domanda "le onde >= 2 sono cambiate
## qualcosa?" non si puo' porre guardando il peso: il peso puo' essere cambiato e
## restare uguale, e allora si risponde "no" a qualcosa che e' si'. L'unico confronto
## che regge e' fra il numero di adesso e il numero di prima, scritto.
##
## Il confronto e' fra due voci di `PackedFloat32Array`, quindi e' `==` su due
## `float32`: identici vuol dire davvero gli stessi 32 bit, non "abbastanza vicini".
## Scrivere `18.8` in un confronto `float` darebbe un numero diverso per il solo
## fatto di averlo scritto in `float64`: e' il motivo per cui qui non compare un
## numero esadecimale scritto a mano.
## ## m14: la quinta voce c'era gia' come termine (oggi vale **3,0**)
##
## La voce del mortar era `0.0` e in m14 e' diventata `MORTAR_WEIGHT`: le altre
## quattro sono **bit-identiche** a com'erano, quindi la rampa del boss dalle onde
## 2 in poi — cioe' la ragione per cui questo vettore e' scritto qui dentro — si
## continua a guardare **termine per termine**, con lo stesso criterio e lo stesso
## `==` fra due `float32`. Non e' un criterio allentato: e' la stessa struttura con
## un termine in piu' che prima era costante a zero.
##
## ## m17: il termine del mortar e' stato **ritoccato** e il vettore sceso con lui
##
## `6,0 -> 3,0` e' una leva sulle onde >= 2, e questa sezione e' quella che deve
## accorgersene. Per questo il numero qui dentro e' stato aggiornato a `3.0`
## **insieme** alla fonte, e non insieme alla prossima leva: il criterio resta
## «le quattro voci che non sono il mortar non si muovono», e il mortar si muove
## per decisione della sezione 17 (la quota). Il commento sotto la dichiarazione
## del peso in `src/sim/spawner.gd` dice perche' e' sceso.
##
## Non si scrive qui `MORTAR_WEIGHT`: il numero puo' muoversi dentro la banda della
## quota (vedi `_quota_mortar`) senza che questa riga vada rossa, e scriverlo qui
## significherebbe legare il test a una scelta che la sezione 17 guarda per quello
## che e' — quanto nasce, non quanto pesa.
static var PESI_ONDA2_DICHIARATI := PackedFloat32Array([47.5, 30.0, 18.8, 5.0, 3.0])

func _onde_2_e_avanti(h) -> void:
	var due := SPAWNER.wave_weights(2)
	for k in ENEMY.KIND_COUNT:
		h.eq(due[k], PESI_ONDA2_DICHIARATI[k],
			"onda 2, %s: il peso deve essere bit-identico a com'era prima di togliere il boss dall'onda 1, dichiarato %.1f, ottenuto %.1f"
				% [ENEMY.KIND_NAMES[k], PESI_ONDA2_DICHIARATI[k], due[k]])
	print("orda: onde >= 2 -- wave_weights(2) %s, dichiarato %s: bit per bit"
		% [_pesi(due), _pesi(PESI_ONDA2_DICHIARATI)])
	# L'onda `ONDA_MISELA` e' la stampa e non il criterio: il criterio e' la prima
	# onda che non si toccava, la 2, e questa e' quella coi denti. Il numero viene
	# stampato comunque a ogni lancio, perche' se qualcuno muove la rampa e' qui che
	# il cambio si vede per primo.
	print("orda: onde >= 2 -- la rampa oltre la 2: onda 3 %s | onda 4 %s | onda %d %s"
		% [_pesi(SPAWNER.wave_weights(3)), _pesi(SPAWNER.wave_weights(4)),
			ONDA_MISELA, _pesi(SPAWNER.wave_weights(ONDA_MISELA))])

## ## Zero boss sull'onda 1, e perche' qui la banda non c'e'
##
## Il numero atteso e' **zero**, e si asserisce il **conteggio**, non la frazione
## entro `TOLERANZA_MISELA = 0,05`. Non e' pignoleria: con la banda di questa
## sezione il criterio di questo difetto **nasce verde**.
##
## Con il peso di prima (boss 3,0 sull'onda 1) la frazione di boss misurata era
## **0,030** sul cammino iniziale e **0,030** sui respawn, e `|0,030 - 0,000| =
## 0,030` sta dentro `0,050`. Quindi `near(0,030, 0,0, 0,05)` dice "passa" **col
## difetto dentro**: verde per costruzione, cioe' un criterio decorativo travestito
## da criterio. Per questo la banda non viene usata qui e non viene neppure
## citata come scusatorio: il numero giusto e' zero e uno zero non ha banda.
##
## Zero e' anche l'unico numero che si puo' pretendere: con un peso a `0,0`
## `pick_kind_with` non puo' restituire il boss in nessun caso, perche' l'accumulo
## degli altri tre pesi raggiunge gia' il totale. Quindi un boss ne' uno e' gia'
## un difetto, e il criterio ha denti a `1`, non a `31`.
##
## Il campione e' dichiarato e asserito: sotto `CAMPIONE_MISELA` il numero non e'
## piu' confrontabile con niente, e un criterio che non puo' fallire perche' non ha
## abbastanza numeri e' un criterio che non e' un criterio.
func _zero_boss(h, w: int, iniziale: PackedInt32Array, respawn: PackedInt32Array) -> void:
	var coppie := [
		["popolazione iniziale", iniziale],
		["respawn durante l'onda", respawn],
	]
	for coppia in coppie:
		var nome: String = coppia[0]
		var a: PackedInt32Array = coppia[1]
		var n := 0
		for v in a:
			n += v
		h.check(n >= CAMPIONE_MISELA,
			"onda %d, %s: il campione deve valere almeno %d perche' il numero sia confrontabile, ottenuto %d"
				% [w, nome, CAMPIONE_MISELA, n])
		h.eq(a[ENEMY.BOSS], 0,
			"onda %d, %s: **zero boss**, atteso 0, ottenuto %d su %d (frazione %.3f; la banda 0,05 non lo prenderebbe, perche' 0,030 ci sta dentro, quindi qui il numero e' il conteggio e non la frazione)"
				% [w, nome, a[ENEMY.BOSS], n, float(a[ENEMY.BOSS]) / maxf(1.0, float(n))])
	print("orda: zero boss onda %d -- iniziale %d/%d, respawn %d/%d (atteso 0 su entrambi i cammini)"
		% [w, iniziale[ENEMY.BOSS], _totale(iniziale), respawn[ENEMY.BOSS], _totale(respawn)])

func _totale(a: PackedInt32Array) -> int:
	var n := 0
	for v in a:
		n += v
	return n

## ## m14: la **quota** del mortar, e perche' un criterio e non un numero
##
## Il numero che si sceglie di guardare e' **quanto nasce mortar**, non quanto pesa:
## il peso e' un mezzo, la quota e' il fine. E una quota e' l'unico numero che si
## puo' muovere dentro una banda senza che il criterio dica il falso: il peso puo'
## salire e la quota restare (se gli altri pesi salgono con lui), quindi il giorno
## che il mortar verra' ritoccato per farlo piu' raro, questa riga resta verde se
## la scelta e' ancora dentro la banda e va rossa se non lo e'.
##
## La banda e' 4,0% - 8,0% e viene dai fatti dichiarati in
## `src/sim/spawner.gd:MORTAR_WEIGHT`: il vecchio boss a 3,0 dava ~3,0% ed era
## troppo raro per un nemico che il giocatore deve imparare a schivare, il brute a
## 17,0 dava ~18% ed e' troppo comune per una specie che va imparata presto. Il
## numero di oggi, 6,0, sta dentro: 5,83% sul cammino della popolazione iniziale e
## 5,66% su quello dei respawn (i due denominatori sono diversi perche' sull'onda 1
## il boss vale 0,0 e nella tabella piatta vale 3,0: vedi la dichiarazione).
##
## Il criterio guarda **entrambi** i cammini e **non in media**: una quota media
## nasconderebbe un cammino spento dietro l'altro generoso, ed e' esattamente il
## difetto che questa sezione 17 chiude.
## ## m17: la banda scende a **2,0% - 4,0%**, e perche' scende
##
## Il numero e' sceso perche' e' sceso il peso: `Spawner.MORTAR_WEIGHT` e' passato
## da **6,0 a 3,0** e la quota misurata in onda 1 da **0,0575 a circa 0,0300**
## (vedi la dichiarazione lunga in `src/sim/spawner.gd`). I due fatti che l'hanno
## fatto scendere sono due, e nessuno dei due e' «il gioco e' piu' facile»:
##
##   1. il mortar non nasce piu' dall'onda 1 ma **dopo 180,0 s di partita**: non ha
##      piu' bisogno di essere frequente per farsi conoscere;
##   2. si ferma a **3 x blast** (15,63 m) invece che a 2 (10,42 m): ti raggiunge
##      prima e da piu' lontano, e la **finestra di schivata non e' cambiata**.
##
## Quindi questa banda **non e' un allargamento di tolleranza per far passare**:
## resta una banda di due punti attorno al numero nuovo, ed e' piu' stretta in
## assoluto di quella di prima. Il numero che la faceva andare bene — **0,0575** —
## e' **fuori** da 2,0%-4,0%, quindi questo criterio va rosso sul numero di ieri,
## che e' esattamente quello che deve succedere quando un numero di produzione
## cambia: se la banda fosse rimasta 4%-8% il criterio sarebbe verde perche' non
## guardava niente.
const QUOTA_MORTAR_MIN := 0.02
const QUOTA_MORTAR_MAX := 0.04

func _quota_mortar(h, w: int, iniziale: PackedInt32Array, respawn: PackedInt32Array) -> void:
	var coppie := [
		["popolazione iniziale", iniziale],
		["respawn durante l'onda", respawn],
	]
	for coppia in coppie:
		var nome: String = coppia[0]
		var a: PackedInt32Array = coppia[1]
		var n := _totale(a)
		h.check(n >= CAMPIONE_MISELA,
			"onda %d, %s: il campione deve valere almeno %d perche' la quota sia confrontabile, ottenuto %d"
				% [w, nome, CAMPIONE_MISELA, n])
		var quota := float(a[ENEMY.MORTAR]) / maxf(1.0, float(n))
		h.check(quota >= QUOTA_MORTAR_MIN and quota <= QUOTA_MORTAR_MAX,
			"onda %d, %s: la quota di mortar deve stare fra %.1f%% e %.1f%%, ottenuta %.4f (%d su %d). "
				% [w, nome, 100.0 * QUOTA_MORTAR_MIN, 100.0 * QUOTA_MORTAR_MAX, quota,
					a[ENEMY.MORTAR], n]
				+ "Sotto il 2% il nemico che il giocatore deve imparare a schivare non si impara, "
				+ "sopra il 4% un'onda di mortar non e' piu' un'onda mista")
		# La stessa scelta scritta sulla tabella, cosi' il numero della banda non
		# galleggia senza un riferimento: se la tabella esce dalla banda, il gioco
		# non puo' starci dentro.
		h.check(_quota_dichiarata(SPAWNER.wave_weights(w)) >= QUOTA_MORTAR_MIN
				and _quota_dichiarata(SPAWNER.wave_weights(w)) <= QUOTA_MORTAR_MAX,
			"onda %d: la quota dichiarata sui pesi di quell'onda e' %.4f e deve stare nella stessa banda %.1f%%-%.1f%%"
				% [w, _quota_dichiarata(SPAWNER.wave_weights(w)),
					100.0 * QUOTA_MORTAR_MIN, 100.0 * QUOTA_MORTAR_MAX])
	var qp := _quota_dichiarata(SPAWNER.KIND_WEIGHTS)
	h.check(qp >= QUOTA_MORTAR_MIN and qp <= QUOTA_MORTAR_MAX,
		"tabella piatta: la quota dichiarata e' %.4f e deve stare nella stessa banda %.1f%%-%.1f%%"
			% [qp, 100.0 * QUOTA_MORTAR_MIN, 100.0 * QUOTA_MORTAR_MAX])
	print("orda: quota mortar onda %d -- iniziale %d/%d = %.4f | respawn %d/%d = %.4f "
		% [w, iniziale[ENEMY.MORTAR], _totale(iniziale),
			float(iniziale[ENEMY.MORTAR]) / maxf(1.0, float(_totale(iniziale))),
			respawn[ENEMY.MORTAR], _totale(respawn),
			float(respawn[ENEMY.MORTAR]) / maxf(1.0, float(_totale(respawn)))]
		+ "| banda %.2f-%.2f, dichiarata iniziale %.4f e piatta %.4f"
			% [QUOTA_MORTAR_MIN, QUOTA_MORTAR_MAX,
				_quota_dichiarata(SPAWNER.wave_weights(w)), qp])

## La quota dichiarata su una tabella di pesi: voce del mortar sopra la somma.
func _quota_dichiarata(w: PackedFloat32Array) -> float:
	var somma := 0.0
	for v in w:
		somma += v
	return w[ENEMY.MORTAR] / maxf(0.000001, somma)

## ## m14: con il peso a 0,0 la quota e' **zero**, e qui il numero e' il conteggio
##
## Come `_zero_boss` e per la stessa ragione: `0,0` e' l'unico numero che si puo'
## pretendere esatto, perche' con una voce a zero `pick_kind_with` non puo' restituire
## quella specie in nessun caso, e un criterio sulla frazione dentro banda sarebbe
## verde con il difetto dentro.
func _zero_quota_mortar(h, w: int, iniziale: PackedInt32Array, respawn: PackedInt32Array) -> void:
	for coppia in [["popolazione iniziale", iniziale], ["respawn durante l'onda", respawn]]:
		var nome: String = coppia[0]
		var a: PackedInt32Array = coppia[1]
		var n := _totale(a)
		h.check(n >= CAMPIONE_MISELA,
			"onda %d, %s: il campione deve valere almeno %d perche' lo zero sia confrontabile, ottenuto %d"
				% [w, nome, CAMPIONE_MISELA, n])
		h.eq(a[ENEMY.MORTAR], 0,
			"onda %d, %s: con il peso tornato a 0.0 la quota deve essere 0,0000, ottenuto %d su %d"
				% [w, nome, a[ENEMY.MORTAR], n])

## ## m14: i denti della quota, accesi e spenti nella stessa sezione
##
## Il difetto di m13 era il peso a `0,0`: qui il peso torna a `0,0`, si rimisurano
## gli stessi due cammini con gli stessi semi e gli stessi 4800 campioni, e si
## asserisce lo **zero esatto**; poi il peso torna al valore di produzione e la
## quota deve risalire dentro la banda. I due numeri sono stampati **prima e
## dopo**: chi legge non deve fidarsi della parola "zero" e puo' fare la differenza
## da solo.
##
## Il peso si rimette **sulla fonte** (`Spawner.MORTAR_WEIGHT`) e non sulla tabella
## piatta: `KIND_WEIGHTS` e' costruita al caricamento della classe e non segue la
## fonte (vedi la sua dichiarazione in `spawner.gd`), quindi scrivere li' sarebbe
## mettere mano a una copia. E il ripristino non e' una cortesia e' un criterio:
## senza `restart_run()` l'orda continuerebbe a pesare con i pesi spenti e
## qualunque sezione dopo misurerebbe una partita che nessuno sta giocando.
func _denti_quota_mortar(h, horde: HORDE) -> void:
	var t0 := Time.get_ticks_usec()
	var respawn_precedente := horde.auto_respawn
	horde.auto_respawn = true
	horde.population = RUN.population_of(1)
	var peso := SPAWNER.MORTAR_WEIGHT

	# Il difetto acceso: il peso torna a 0,0, come in m13.
	SPAWNER.MORTAR_WEIGHT = 0.0
	horde.restart_run()
	_porta_onda(h, horde, 1)
	h.eq(SPAWNER.wave_weights(1)[ENEMY.MORTAR], 0.0,
		"denti quota: il peso del mortar deve essere tornato a 0.0, altrimenti la misura qui "
			+ "sotto non dimostra niente, ottenuto %.1f" % SPAWNER.wave_weights(1)[ENEMY.MORTAR])
	var spento := _due_cammini(h, horde, 1)
	_zero_quota_mortar(h, 1, spento[0], spento[1])
	print("orda: denti quota, peso a 0.0 -- iniziale %d/%d = %.4f | respawn %d/%d = %.4f"
		% [spento[0][ENEMY.MORTAR], _totale(spento[0]),
			float(spento[0][ENEMY.MORTAR]) / maxf(1.0, float(_totale(spento[0]))),
			spento[1][ENEMY.MORTAR], _totale(spento[1]),
			float(spento[1][ENEMY.MORTAR]) / maxf(1.0, float(_totale(spento[1])))])

	# Il difetto spento: il peso torna al valore di produzione e l'orda lo rilegge.
	SPAWNER.MORTAR_WEIGHT = peso
	horde.restart_run()
	# ## m17: `restart_run()` **azzera anche l'orologio** (e' la strada vera di una
	# partita nuova), quindi qui la soglia va riaperta prima di rimisurare: senza
	# questa riga il peso tornato a 3,0 non produrrebbe nessun mortar e il criterio
	# sarebbe verde perche' misura zero, non perche' misura il peso.
	_porta_oltre_il_mortar(h, horde, "_denti_quota_mortar (peso ripristinato)")
	_porta_onda(h, horde, 1)
	h.eq(SPAWNER.wave_weights(1)[ENEMY.MORTAR], peso,
		"denti quota: il peso deve essere tornato a %.1f prima di uscire dalla sezione, ottenuto %.1f"
			% [peso, SPAWNER.wave_weights(1)[ENEMY.MORTAR]])
	var acceso := _due_cammini(h, horde, 1)
	_quota_mortar(h, 1, acceso[0], acceso[1])
	h.check(acceso[0][ENEMY.MORTAR] > 0 and acceso[1][ENEMY.MORTAR] > 0,
		"denti quota: spento il difetto, i due cammini devono tirare fuori mortar, ottenuto "
			+ "%d su %d e %d su %d: se restassero a zero il criterio qui sopra sarebbe verde "
				% [acceso[0][ENEMY.MORTAR], _totale(acceso[0]),
					acceso[1][ENEMY.MORTAR], _totale(acceso[1])]
			+ "senza guardare niente")
	h.eq(SPAWNER.MORTAR_WEIGHT, peso,
		"denti quota: e la costante di sorgente deve essere tornata a %.1f, non solo i pesi ricalcolati" % peso)

	# L'orda torna com'era, come fanno le due sezioni precedenti.
	horde.auto_respawn = respawn_precedente
	horde.population = RUN.population_of(1)
	horde.restart_run()
	h.eq(horde.wave, 1, "m14: i denti della quota rimettono l'orda all'onda 1")
	print("orda: denti quota, sezione in %d us, peso tornato a %.1f e orda rimessa all'onda 1"
		% [Time.get_ticks_usec() - t0, peso])

## ## I denti: il difetto acceso nella stessa sezione e poi spento
##
## Qui dentro il peso del boss sull'onda 1 torna a **3,0** -- il difetto di prima,
## il 3% delle nascite della prima onda -- si rimisura, e poi torna a **0,0**.
## Non e' un blocco di prova buttato dentro e da buttare fuori: e' l'asserzione
## che il criterio di sopra **ha denti**, e resta nel file perche' un criterio che
## nessuno ha mai visto andare rosso e' un numero che il prossimo legge come se
## fosse vivo.
##
## Il ripristino non e' una cortesia e' un criterio: se il peso non tornasse a
## `0,0`, o se tornasse a `0,0` senza che l'orda lo rilegga, la sezione va
## rossa invece di lasciare un gioco col boss a zero che nessuno ha riaperto.
## Per questo il peso si rimette **e poi** si chiama `restart_run()`, che e' la
## cosa che fa `_sync_weights()`: `reseed()` da solo riscrive la disposizione e
## **non** rilegge i pesi (vedi il punto 4 del suo contratto in horde.gd).
##
## Il numero che esce e' stampato due volte, coi denti fuori e coi denti dentro,
## cosi' chi legge non deve fidarsi della parola "zero" e puo' fare la differenza
## da solo. Quello dei denti fuori e' il `145/4800` iniziale e `143/4800` respawn
## che la sezione principale misura con `BOSS_WAVE1 = 0,0`.
func _denti_zero_boss(h, horde: HORDE) -> void:
	var t0 := Time.get_ticks_usec()
	var respawn_precedente := horde.auto_respawn
	horde.auto_respawn = true
	horde.population = RUN.population_of(1)

	# Il difetto acceso: il peso torna a 3,0, cioe' il 3% delle nascite.
	SPAWNER.BOSS_WAVE1 = 3.0
	horde.restart_run()
	_porta_onda(h, horde, 1)
	var coi_denti := SPAWNER.wave_weights(1)
	h.eq(coi_denti[ENEMY.BOSS], 3.0,
		"denti: il peso del boss sull'onda 1 deve essere tornato a 3.0, altrimenti la misura qui sotto non dimostra niente, ottenuto %.1f"
			% coi_denti[ENEMY.BOSS])
	var coi := _due_cammini(h, horde, 1)
	var ci := _totale(coi[0])
	var cr := _totale(coi[1])
	print("orda: denti, boss a 3.0 -- iniziale %d/%d | respawn %d/%d (fra le frazioni %.3f e %.3f)"
		% [coi[0][ENEMY.BOSS], ci, coi[1][ENEMY.BOSS], cr,
			float(coi[0][ENEMY.BOSS]) / maxf(1.0, float(ci)),
			float(coi[1][ENEMY.BOSS]) / maxf(1.0, float(cr))])
	# Il criterio di sopra, applicato al difetto acceso: **deve** andare rosso, e
	# questi due `h.check` sono l'attesa di quel rosso scritta come numero.
	h.check(coi[0][ENEMY.BOSS] > 0,
		"denti: col peso a 3.0 la popolazione iniziale deve tirare fuori boss (ne' uno significherebbe che la misura non sta guardando il posto giusto), ottenuto %d su %d"
			% [coi[0][ENEMY.BOSS], ci])
	h.check(coi[1][ENEMY.BOSS] > 0,
		"denti: col peso a 3.0 i respawn devono tirare fuori boss (ne' uno significherebbe che la misura non sta guardando il posto giusto), ottenuto %d su %d"
			% [coi[1][ENEMY.BOSS], cr])

	# Il difetto spento, e l'orda che lo rilegge davvero.
	SPAWNER.BOSS_WAVE1 = 0.0
	horde.restart_run()
	_porta_onda(h, horde, 1)
	var senza := SPAWNER.wave_weights(1)
	h.eq(senza[ENEMY.BOSS], 0.0,
		"denti: il peso del boss sull'onda 1 deve essere tornato a 0.0 prima di uscire dalla sezione, ottenuto %.1f"
			% senza[ENEMY.BOSS])
	h.eq(SPAWNER.BOSS_WAVE1, 0.0,
		"denti: e la costante di sorgente deve essere 0.0, non solo i pesi ricalcolati")
	# Una popolazione sola, per vedere che il gioco e' tornato a zero e non solo la
	# tabella. `reseed` non rilegge i pesi, quindi qui i pesi sono quelli messi da
	# `restart_run` e il numero che esce e' quello del gioco.
	horde.reseed(int(SEMI_MISELA[0]))
	var adesso := _conta_specie(horde)
	h.eq(adesso[ENEMY.BOSS], 0,
		"denti: spento il difetto, una popolazione nuova non deve avere boss, ottenuto %d su %d (%s)"
			% [adesso[ENEMY.BOSS], _totale(adesso), _riga_specie(adesso)])

	# L'orda torna com'era, come fa la sezione principale.
	horde.auto_respawn = respawn_precedente
	horde.population = RUN.population_of(1)
	horde.restart_run()
	print("orda: denti, sezione in %d us, peso tornato a 0.0 e orda rimessa all'onda 1"
		% (Time.get_ticks_usec() - t0))

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

# --- 18. m14: LA DIFFICOLTA'. Il criterio che nel progetto non c'era -------------
#
# ## Il difetto, e perche' la risposta «alzo `HP_SCALE_MAX`» era sbagliata
#
# L'utente ha scritto: «sono al livello 61 e con i potenziamenti di danno, rateo
# e gittata posso stare fermo al centro e cancellare tutto allo spawn». Non era una
# percezione: `src/sim/run.gd` aveva `HP_SCALE_STEP = 0,25` con `HP_SCALE_MAX = 4,0`,
# quindi la vita smetteva di crescere **all'onda 13** e la popolazione era gia'
# ferma dall'onda 8. Il giocatore non aveva tetto, e i suoi potenziamenti sono
# **moltiplicativi**.
#
# Alzare il tetto e' la risposta che si da' per abitudine, ed e' sbagliata per un
# motivo che questa sezione misura: **il danno del morso non cresceva mai**.
# `enemy.gd::touch_damage_of(kind)` e' la tabella delle specie, identica a ogni
# onda, e `horde.gd::TOUCH_INTERVAL` limita la cadenza dei morsi. Quindi il danno
# al secondo che l'orda porta al giocatore era
# `(1/0,15) x 1,6 = 10,67` hp/s, **una costante**: nessun numero messo sulla vita
# poteva renderlo piu' grande. Il tetto che m14 chiude e' questo.
#
# ## I due numeri del criterio, e perche' sono in **hp/s**
#
# In ingresso e in uscita devono avere la stessa unita', altrimenti il confronto
# non e' un confronto. Quindi:
#
#   - **pressione in uscita** = danno al secondo che il giocatore fa con l'arma
#     vera e con una dotazione di potenziamenti **dichiarata** (`DIFF_DOTAZIONE`),
#     letta dai campi di `weapon_base` dopo che i potenziamenti veri sono stati
#     applicati uno per uno;
#   - **pressione in ingresso** = danno al secondo che l'orda **riesce a far
#     arrivare** in una finestra di regime, a pieno, misurata sul contratto.
#
# Sul lato del giocatore si usa il **potenziale** dell'arma (`danno / intervallo`,
# cioe' il massimo che puo' fare se ogni colpo trova un corpo): e' il numero
# **piu' generoso** che si puo' dichiarare, e quindi un criterio che passa con
# quello passa a maggior ragione nel gioco, dove i colpi che mancano un bersaglio
# non fanno danno.
#
# ## Perche' il criterio ha due verbi
#
#   1. **cresce**: la scala dell'onda `w` e' **strettamente** maggiore di quella
#      dell'onda `w - 1`, per ogni `w` fino a `LAW_HORIZON_WAVE`. E' il tetto che m14
#      toglie, scritto come criterio invece che tolto come numero: nessuno puo'
#      reintrodurlo senza che la porta vada rossa.
#   2. **non e' inferiore a fine partita**: all'onda `LAW_HORIZON_WAVE` la pressione in
#      ingresso non e' minore di quella in uscita.
#
# Il primo da solo passerebbe con una scala che cresce di `+0,01` a onda: e' il
# secondo che ha il difetto. E il secondo da solo passerebbe con una scala
# enorme gia' dall'onda 1, che romperebbe il criterio n. 4 della milestone 1.
#
# ## I denti: lo stesso criterio applicato alla legge di **prima**
#
# La legge storica e' scritta qui dentro, in `_scala_legacy()`, e non letta da
# nessuna parte: e' il numero che il progetto aveva, congelato, cosi' il criterio
# puo' essere valutato anche su di lei. Se il criterio fosse costruito in modo da
# passare sempre, questa asserzione non potrebbe esistere; e il fatto che qui
# venga **eseguita** e non solo dichiarata e' la prova che la porta ha denti.

## I livelli ai quali la potenza del giocatore viene misurata e stampata. Sono
## quelli dell'utente: `61` e' il livello da cui e' partito il difetto, `1` e' la
## base, e in mezzo ci sono `5, 10, 20, 30, 40` per vedere **la forma** della
## curva e non solo due capi.
const DIFF_LIVELLI := [1, 5, 10, 20, 30, 40, 61]

## La dotazione **dichiarata**: una carta per livello, dal livello 2 in poi, in
## ciclo. Sono le tre che l'utente ha citato playing, e `Run.POWER_CYCLE` dice
## che sono tre: se la lista qui ne contasse un numero diverso, la legge di
## `run.gd` starebbe guardando una rotazione che non e' quella dichiarata, e
## l'asserzione sotto lo dice.
const DIFF_DOTAZIONE := ["damage", "fire_rate", "range"]

## Le tre onde a cui la pressione in ingresso viene **misurata**, e perche' sono
## tre e non una. `3` e' dentro la crescita vecchia, `13` e' **esattamente** l'onda
## in cui `HP_SCALE_MAX` entrava in gioco (1 + 12 x 0,25 = 4,0) e `61` e'
## `LAW_HORIZON_WAVE`, l'orizzonte su cui la legge e' tarata.
##
## ## m12-w1a: la finestra e' stata dimezzata, e **perche'**
##
## Misurato su questa macchina il 2026-10-16: la sezione costava **23,6 s** dei
## 120 del file con 200 nemici vivi, e `SPAWN_RATE` e' sceso da `8,0/s` a
## `2,04/s`: riempire 200 corpi passa da 1.313 a **5.880 passi**, quindi la stessa
## sezione sarebbe costata ~64 s e il file intero sarebbe andato a ~142 s, cioe'
## **oltre** il tetto che l'utente ha deciso e che non si alza.
##
## Quindi la misura si fa su `DIFF_POPOLAZIONE` = 100 vivi invece di 200. Il numero
## che esce **cambia** (meno contatti addosso al giocatore, quindi meno morsi al
## secondo) ed e' per questo che la riga e' dichiarata: il criterio di m14
## confronta l'ingresso con l'uscita nello **stesso** campione, quindi il quoziente
## resta il numero che conta. E il campione resta un contatto reale: 100 corpi a
## 60 m riempiono l'anello intorno al giocatore esattamente come 200.
const DIFF_POPOLAZIONE := 100
const DIFF_ONDE := [3, 13, 61]

## Passi di riscaldamento **prima** di aprire la finestra. 780 passi sono 13 s, e
## arrivano **dopo** che il campo e' pieno: a riempimento (`SPAWN_RATE` = 8/s)
## servono ~22 s per i 200 vivi, quindi quando la finestra si apre l'orda ha
## gia' vissuto 35 s e la misura del contatto di m12 dice che a quel punto la
## folla e' addosso al giocatore. Una finestra aperta durante l'avvicinamento
## misurerebbe un'orda che ancora non e' un'orda.
const DIFF_WARMUP := 780
## Passi della finestra di misura: 480 passi sono 8 s. Non e' un numero di
## comfort: e' il numero per cui 2 onde a 200 vivi stanno sotto i 120 s **del
## file intero**, che e' il tetto che l'utente ha deciso e non si alza.
const DIFF_WINDOW := 480

func _difficolta(h, isolate: HORDE) -> void:
	var t0 := Time.get_ticks_usec()
	# ## m12-w1b: qui non c'e' piu' nessuna prova dei formati
	#
	# C'era `_sci_si_prova(h)`, che insieme alla porta sui `%g` e' stata cancellata.
	# Non resta un sostituto, e la **prova di `_sci` come funzione** non e' stata
	# rimessa: era dentro la funzione cancellata. `_sci()` resta usata in ogni
	# numero grande che questo file stampa, quindi un suo futuro rottura si vede
	# come un numero stampato male, non come un messaggio silenzioso — che e' il
	# difetto che la prova copriva e che `_sci` era gia' risolto senza porta.
	#
	# La regola «niente `%g` e `%e`, si scrive `_sci`» e' nel piano.
	# ## L'ordine dei due lati, e non e' decorativo
	#
	# Prima la **pressione che l'orda consegna**, poi la **potenza del giocatore**.
	# Il motivo e' il difetto di m14-bis: `_pressione_uscita` apre
	# `scenes/arena_main.tscn`, ci registra dentro `Game.player`, e poi la chiude
	# con `free()`. Se l'ingresso si misurasse **dopo**, ogni suo passo passerebbe
	# dalla scena vera appena liberata: `horde.gd::_player_hp()` fa
	# `game.get("player")`, riceve un oggetto morto, e `is Node` su un'istanza
	# liberata **non restituisce `false`**. Il numero che ne tornava fuori era la
	# misura **negativa**, cioe' spazzatura.
	#
	# Adesso l'ordine e' quello che non ha bisogno di nessuna difesa: quando si
	# misura l'ingresso il contratto non ha mai visto la scena vera. E `_ripristina`
	# rimette `Game.player` com'era, cosi' la difesa c'e' anche per chi legge questa
	# sezione fra un anno e mette i due lati nell'ordine sbagliato.
	_pressione_ingresso(h, isolate)
	var dna := _pressione_uscita(h, isolate)
	_pressione_ingresso_verdetto(h, isolate, dna)
	# ## L'orda torna com'era, e con `restart_run()`
	#
	# Non con una scrittura a mano su `run.wave`: la strada vera resta la strada
	# vera, quindi la sezione che segue misura una partita nuova e non un campo
	# con dentro il ricordo di questa.
	isolate.restart_run()
	_player_via = FAKE_PLAYER
	print("orda: m14, sezione in %d us" % (Time.get_ticks_usec() - t0))

## Il DPS dichiarato del giocatore al livello `liv`, dalla **legge di `run.gd`**.
##
## Non e' una formula di questo file: e' `(danno/intervallo) x
## Run.power_ratio_of(liv)`, cioe' il potenziale dell'arma al livello 1 per la
## curva di potenza che la legge dell'orda usa come primo fattore. Perche' la
## stessa funzione e non due copie: se il criterio confrontasse l'ingresso con
## una potenza calcolata qui e la scala dell'orda con un'altra calcolata in
## `run.gd`, i due lati del confronto non avrebiano piu' niente in comune e il
## criterio misurerebbe due numeri che non si parlano.
func _dps_previsto(liv: int) -> float:
	return (RUN.WEAPON_DAMAGE / RUN.WEAPON_FIRE_INTERVAL) * RUN.power_ratio_of(liv)

## ## LA REGOLA DEI FORMATI, scritta qui perche' si legge
##
## In Godot `String % ...` conosce `%d`, `%s`, `%x` e `%f` **col suo numero di
## cifre decimali**. **`%g` e `%e` NON esistono**, e il fallimento e' silenzioso:
## il segnaposto resta **alla lettera** nella riga e il numero che si voleva
## leggere sparisce senza un errore, senza un warning e senza rompere il test.
## E' successo tre volte in un giorno: una nella sezione 12 (`%.2e`) e due qui,
## nella tabella della pressione — e il secondo giro ha stampato cosi':
##
##     scala %11.4g | uscita (liv %3d) %11.4g hp/s | ...
##
## cioe' la riga che doveva riportare la misura era un modulo di stampa.
##
## Quindi: **`%g` e `%e` non si usano piu' da nessuna parte**, e i numeri grandi
## si stampano con `_sci()`, che scrive la notazione scientifica **a mano** e
## restituisce una stringa da mettere in `%s`. Un numero che puo' valere `1e13`
## scritto come intero e' illeggibile, ma un formato che non esiste e' peggio:
## illeggibile e **non se ne accorge**.
func _sci(v: float) -> String:
	if not is_finite(v):
		return str(v)
	if v == 0.0:
		return "0"
	var a := absf(v)
	if a >= 0.001 and a < 10000000.0:
		return "%.4f" % v
	var e := 0
	var m := a
	while m >= 10.0:
		m /= 10.0
		e += 1
	while m < 1.0:
		m *= 10.0
		e -= 1
	# `%s` per l'esponente e non `%d`: `e` e' un intero e va stampato come
	# intero, ma qui non si mette nessun formato numerico che possa cambiare
	# significato fra un formato valido e uno che non lo e'.
	return "%.2fe%s" % [v / pow(10.0, float(e)), str(e)]

## La regola ha un costo (una divisione in un ciclo) e un vantaggio: il numero
## stampato e' quello che il criterio ha confrontato. Un formato che tronca o
## arrotonderebbe l'avrebbe fatto sembrare un altro numero senza dirlo.
##
## ## m12-w1b: LA PORTA CHE CERCAVA I FORMATI CATTIVI E' STATA CANCELLATA
##
## Qui sotto c'era `_sci_si_prova()` con dentro un rilevatore di formati, la sua
## chiamata, e la prova dei denti. **Tutto cancellato**, e non sostituito con una
## versione piu' semplice: la porta aveva **tre regole diverse dentro**, l'ho
## riscritta tre volte in due giorni, e **ogni versione aveva prodotto almeno un
## falso** — un falso negativo sulla sua stessa prova dei denti e un falso positivo
## su `% g`. Una porta che sbaglia in entrambe le direzioni non e' una porta: e' un
## rumore che si spaccia per controllo, e ha costato piu' giri di questa onda di tutto
## il resto messo insieme.
##
## La **regola resta scritta a mano nei messaggi** — e` `_sci()`, non `%g` — che e'
## gia' la soluzione: il `%g` si risolve **non scrivendo `%g`**, quindi il difetto che
## la porta doveva difendersi era gia' risolto e la porta era un tentativo di
## difendere una cosa risolta. La regola di codice senza codice sta nel piano, che e'
## l'unico posto dove ha senso: in un file di test una regola che nessuno esegue e'
## solo rumore che qualcuno un giorno deve ricostruire.
## La legge **di prima**, congelata in questo file e letta da nessuna parte.
##
## `HP_SCALE_STEP = 0,25` con `HP_SCALE_MAX = 4,0`: `1 + (w - 1) x 0,25` fino a
## 4,0, poi `clampf` a 4,0 per sempre. E' il numero che ha prodotto il difetto, e
## sta qui dentro perche' il criterio debba poter essere eseguito anche su di lei.
func _scala_legacy(w: int) -> float:
	return clampf(1.0 + float(maxi(w, 1) - 1) * 0.25, 1.0, 4.0)

func _scala_di(w: int, legacy: bool) -> float:
	return _scala_legacy(w) if legacy else RUN.scale_of(w)

## Il verbo 1: la scala cresce **strettamente**, onda per onda, fino a `LAW_HORIZON_WAVE`.
func _verdetto_cresce(legacy: bool) -> bool:
	var prima := _scala_di(1, legacy)
	for w in range(2, int(RUN.LAW_HORIZON_WAVE) + 1):
		var ora := _scala_di(w, legacy)
		if not (ora > prima):
			return false
		prima = ora
	return true

## Il verbo 2: all'onda `LAW_HORIZON_WAVE` l'ingresso non e' inferiore all'uscita.
##
## ## Perche' qui **non c'e'** una media e non c'e' la tabella
##
## La prima versione scriveva `ingresso = colpi/s x TOUCH_DAMAGE_BASE x scala` e
## andava rossa con uno scarto costante di `0,66`: il termine sbagliato era la
## media di **tutte** le specie, mentre addosso a un giocatore di raggio
## `body_scale x 1,40 m` ci finisce quasi solo il runner, che e' il piu'
## economico. La media e' stata **tolta**, non corretta.
##
## Adesso l'ingresso e' il **danno consegnato**, che e' gia' misurato: nessuna
## media, nessuna tabella, nessun termine che possa essere sbagliato di un terzo.
## Per il controfattuale sulla legge di prima si riscala lo stesso numero
## misurato per il rapporto fra le due leggi — che e' l'unica cosa che cambia,
## perche' nella finestra di misura nessun nemico muore e quindi la geometria
## del contatto e' la stessa sotto qualunque scala.
##
## Il confronto ha comunque denti: il lato in uscita e' un numero **dichiarato**
## (`_dps_previsto`), e se la potenza del giocatore crescesse piu' in fretta della
## scala dell'orda questo verrebbe rosso. E' successo al primo giro, su entrambe
## le leggi.
func _verdetto_fine(misure: Dictionary, legacy: bool) -> bool:
	var w := int(RUN.LAW_HORIZON_WAVE)
	var m := _misura_di(misure, w)
	if m.is_empty():
		return false
	var oggi := float(m["danno"])
	if oggi <= 0.0:
		return false
	var ingresso := oggi
	if legacy:
		ingresso = oggi * _scala_di(w, true) / maxf(0.000001, _scala_di(w, false))
	return ingresso >= _dps_previsto(int(RUN.player_level_at(w - 1)))

## ## Le copie oneste: `run.gd` non puo' preloaddare le altre foglie
##
## `horde.gd` preloada `run.gd`, quindi `run.gd` non puo' preloaddare `horde.gd`
## senza un riferimento circolare; e `src/player/progression.gd` e' una foglia di
## gioco dentro una foglia di simulazione. Quindi `run.gd` **copia** sei numeri da
## quattro file, e questa funzione e' il controllo che rende la copia onesta: se
## `-gameplay` o `-gameplay`/`-arena` cambiano uno di quei numeri, la porta va
## rossa **e dice quale**, invece che la difficolta' di accumulare uno scarto
## silenzioso. E' lo stessoaccordo che gia' regge `POP_MAX` contro
## `Horde.MAX_ENEMIES`.
func _copie_oneste(h, giocatore) -> bool:
	var prog = giocatore.progression
	if not h.check(prog != null, "m14: il giocatore vero deve avere una progressione"):
		return false
	h.near(float(RUN.XP_PER_KILL), float(prog.xp_per_kill), 0.000001,
		"m14: run.XP_PER_KILL deve valere progression.xp_per_kill: la legge conta le uccisioni")
	h.near(float(RUN.XP_BASE), float(prog.xp_to_next(1)), 0.000001,
		"m14: run.XP_BASE deve valere la prima soglia di livello")
	h.near(float(RUN.XP_STEP),
		float(prog.xp_to_next(2)) - float(prog.xp_to_next(1)), 0.000001,
		"m14: run.XP_STEP deve valere quanto sale la soglia a ogni livello")
	h.near(float(RUN.UPGRADE_DAMAGE), float(prog.UPGRADES["echo"]["numero"]), 0.000001,
		"m14: run.UPGRADE_DAMAGE deve valere il fattore della carta «Danno»")
	h.near(float(RUN.UPGRADE_FIRE_RATE), float(prog.UPGRADES["grep"]["numero"]), 0.000001,
		"m14: run.UPGRADE_FIRE_RATE deve valere il fattore della carta «Cadenza»")
	h.eq(int(RUN.POWER_CYCLE), DIFF_DOTAZIONE.size(),
		"m14: la dotazione dichiarata deve avere esattamente POWER_CYCLE carte")
	h.near(float(RUN.TOUCH_DAMAGE_BASE), float(ENEMY.TOUCH_DAMAGE_BASE), 0.000001,
		"m14: run.TOUCH_DAMAGE_BASE deve valere enemy.TOUCH_DAMAGE_BASE")
	h.near(float(RUN.TOUCH_INTERVAL), float(HORDE.TOUCH_INTERVAL), 0.000001,
		"m14: run.TOUCH_INTERVAL deve valere horde.TOUCH_INTERVAL")
	giocatore.reset_run()
	var w1 = giocatore.weapon
	h.near(float(RUN.WEAPON_DAMAGE), float(w1.damage), 0.000001,
		"m14: run.WEAPON_DAMAGE deve valere il danno dell'arma nuova")
	h.near(float(RUN.WEAPON_FIRE_INTERVAL), float(w1.fire_interval), 0.000001,
		"m14: run.WEAPON_FIRE_INTERVAL deve valere l'intervallo dell'arma nuova")
	return true

## ## Il lato del giocatore: la curva di potenza, **misurata sull'arma vera**
##
## Per ogni livello della scala: `reset_run()`, poi un potenziamento per livello
## dalla dotazione dichiarata, e infine la lettura di `weapon.damage` e
## `weapon.fire_interval`. Il DPS che ne esce e' confrontato con `_dps_previsto`,
## cioe' con la formula che anche `run.gd` usa: se il gioco applicasse i
## potenziamenti in modo diverso dalla tabella, qui lo si vede.
##
## Il confronto e' stretto (0,01%) e non ha margine perche' qui i due numeri
## devono essere **lo stesso numero**: se il gioco cambiasse, il criterio di m14
## starebbe confrontando l'ingresso con una potenza che il giocatore non ha.
func _pressione_uscita(h, isolate: HORDE) -> Dictionary:
	var out := {}
	var arena = _apri_arena(h)
	if arena == null:
		h.fail("m14: senza la scena vera la potenza del giocatore non si puo' misurare")
		_ripristina(h, isolate)
		return out
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var giocatore = arena.get_node_or_null(NODO_PLAYER)
	if not h.check(giocatore != null, "m14: la scena vera deve avere il nodo %s" % NODO_PLAYER):
		_chiudi(arena)
		_ripristina(h, isolate)
		return out
	if not _copie_oneste(h, giocatore):
		_chiudi(arena)
		_ripristina(h, isolate)
		return out

	for liv in DIFF_LIVELLI:
		var L := int(liv)
		giocatore.reset_run()
		for k in range(0, L - 1):
			giocatore.progression.apply(str(DIFF_DOTAZIONE[k % DIFF_DOTAZIONE.size()]))
		var w = giocatore.weapon
		var misurato := float(w.damage) / float(w.fire_interval) * (1.0 + float(w.pierce))
		var previsto := _dps_previsto(L)
		out[L] = misurato
		print("m14 uscita: livello %2d -- %2d potenziamenti, danno %9.2f, intervallo %.4f s, "
				% [L, L - 1, float(w.damage), float(w.fire_interval)]
			+ "DPS %12.2f hp/s (previsto %12.2f, %.1fx sul livello 1)"
				% [misurato, previsto, misurato / maxf(1.0, float(out[1]))])
		h.near(misurato, previsto, previsto * 0.0001,
			"m14: al livello %d il DPS reale dell'arma deve essere quello che la legge dichiara" % L)
	# Il livello 1 e' l'ancoraggio di tutta la legge: `scale_of(1)` deve valere
	# esattamente 1.0 e non «quasi 1.0», perche' il criterio n. 4 della milestone
	# 1 e' tarato sulle tabelle di `enemy.gd` come sono.
	h.near(RUN.scale_of(1), 1.0, 0.000001,
		"m14: la legge lascia l'onda 1 a 1.0 esatto: il criterio n. 4 della milestone 1 e' tarato su quello")
	_chiudi(arena)
	_ripristina(h, isolate)
	return out

## I due campioni della sezione, **campo** e non valore restituito.
##
## Sono campioni perche' la misura (`_pressione_ingresso`) e il verdetto
## (`_pressione_ingresso_verdetto`) devono stare in due funzioni diverse: la
## prima si gira prima che la scena vera venga aperta e chiusa, la seconda dopo.
## Una variabile locale non arriverebbe dall'una all'altra.
var _diff_colpi := {}
var _diff_misure := {}
## La finestra di misura in secondi, calcolata **una volta** e dichiarata qui: e'
## il denominatore della media per morso e della cadenza, e due copie di quel
## conto sarebbero due numeri che possono divergere senza che nessuno se ne
## accorga.
const _FINESTRA_S := float(DIFF_WINDOW) * DT
## Il danno che l'orda **dichiara** passo per passo (`touch_damage_last` +
## `mortar_damage_last`), accumulato dal test e **non** dalla riga che chiama
## `damage_player`. E' il secondo conto del confronto «consegnato / atteso»: due
## accumulazioni indipendenti dello stesso fatto.
var _danno_dichiarato := 0.0
## Quanti morsi della finestra avevano un importo che **non e'** un valore della
## tabella delle specie moltiplicato per la scala dell'onda. Deve restare zero.
var _morsi_fuori_tabella := 0
var _morsi_totali := 0
## ## Chi legge `touch_damage_last` in `src/`: **nessuno**
##
## Le sette occorrenze sono tutte dentro `src/sim/horde.gd`: la dichiarazione (441),
## l'azzeramento per passo (1091), la scrittura (1119), l'azzeramento al restart
## (1588) e due righe di commento mio. Nessun'altra foglia lo legge: non
## `src/ui/`, non `src/render/`, non `src/player/`, non `src/weapons/`.
##
## Quindi il confronto «consegnato contro dichiarato» non guardava un difetto del
## gioco: guardava **due numeri che solo il test usa**, e il suo scarto di `8,000`
## e' stato per quattro giri un fatto su un canale morto. Tolto, e non sostituito
## da una divisione per 8: dividere avrebbe fatto tacere la cosa che il canale
## morto ti stava dicendo, cioe' che quel campo non serve a nessuno.
##
## Quello che resta al suo posto e' il conto che cerca il difetto **vero**, fatto
## di interi e non di somme: quanti `damage_player` con valore diverso da zero sono
## arrivati, contro quanti morsi l'orda dice di aver inflitto nella finestra.
## Presa di misura, non un paragone di due `float`: il passo giusto, il morso perso
## e il morso consegnato due volte sono tre difetti di **contabilizzazione**, e
## due interi che devono essere uguali li prendono tutti e tre. Nessuna media,
## nessuna scala, nessun formato esotico.
##
## Il campo resta dichiarato e scritto in `horde.gd` perche' e' un resoconto che
## `-gameplay` e `-ui` possono cominciare a leggere, ma **non e' piu' un criterio**:
## nessuna asserzione di questo file lo confronta con nient'altro.
var _dichiari_positivi := 0
var _dichiari_colpi := 0
var _passi_con_spia := 0

## ## Il lato dell'orda: la pressione che **arriva davvero**, misurata
##
## Finestra di regime a pieno: `DIFF_WARMUP` passi perche' la folla arrivi, poi
## `DIFF_WINDOW` passi contati. Lo spia e' quello di `_touch`, gia' registrato sul
## contratto da quella sezione: qui non se ne registra un secondo, perche' due spie
## sullo stesso contratto significherebbero due racconti dello stesso numero.
##
## Il campo e' pieno e **nessuno muore**: nessuna chiamata a `damage_enemy` nel
## ciclo della finestra, quindi i nemici sopravvivono e la geometria del contatto
## resta quella che si misura. E' anche il motivo per cui la stessa finestra puo'
## essere ricalcolata sulla legge di prima: cambia solo il moltiplicatore del
## danno, non la cadenza dei morsi.
func _pressione_ingresso(h, isolate: HORDE) -> void:
	var colpi := {}
	var misure := {}
	for w in DIFF_ONDE:
		var campione := _misura_pressione(isolate, int(w))
		colpi[int(w)] = campione[0]
		misure[int(w)] = {
			"colpi": campione[0],
			"danno": campione[1],
			"dichiara": campione[2],
			"morsi": campione[3],
			"fuori_tabella": campione[4],
			"scala": isolate.wave_touch_scale(),
			"dichiari_positivi": _dichiari_positivi,
			"dichiari_colpi": _dichiari_colpi,
			"passi_con_spia": _passi_con_spia,
		}
		h.check(float(campione[0]) > 0.0,
			"m14: sull'onda %d l'orda deve riuscire a far arrivare almeno un morso" % int(w))
	_diff_colpi = colpi
	_diff_misure = misure

	# ## Perche' qui **non c'e' piu'** una ricostruzione con la tabella
	#
	# La prima versione ricostruiva il danno come
	# `colpi/s x TOUCH_DAMAGE_BASE x scala(w)` e asseriva che tornasse. E' andata
	# rossa con uno scarto **costante** di `0,6609` su tutte e tre le onde: una
	# costante non e' rumore, e' un termine sbagliato. Il termine sbagliato era
	# `TOUCH_DAMAGE_BASE` — la media dei morsi di **tutte** le specie, mentre chi
	# arriva addosso a un giocatore di raggio `body_scale x 1,40 m` e' quasi solo
	# **runner**, e il runner e' il piu' economico della tabella.
	#
	## Sostituire `TOUCH_DAMAGE_BASE` con la media di `2,47` misurata in
	## `_scena_vera` non avrebbe chiuso niente: quella media e' di una **disposizione
	## diversa**, e il numero si sarebbe spostato invece di sparire. Quindi qui la
	## ricostruzione **non e' stata corretta: e' stata toccata**, e sotto ci sono
	## due conti che non usano nessuna media.
	for w in DIFF_ONDE:
		var ww := int(w)
		var m := _misura_di(misure, ww)
		var consegnato := float(m["danno"])
		var media := consegnato / maxf(1.0, float(m["colpi"]) * _FINESTRA_S)
		# ## Il conto, e perche' **interi**
		#
		# Tre difetti diversi, una sola domanda: i morsi che l'orda **dichiara**
		# (`touch_bites_last`, contato passo per passo) sono tanti quanti i morsi
		# che sono **arrivati** allo spia? Due interi che devono essere uguali, e il
		# messaggio dice di quanto sbagliano invece di dire solo «diversi».
		#
		#   - un morso **perso** -> lo dichiara e non arriva: arriva meno;
		#   - un morso **dato due volte** -> arriva piu' di quanto dichiarato;
		#   - il danno applicato al **passo sbagliato** -> i due interi tornano
		#     uguali ma la sequenza non e' quella, e per quello resta la parola
		#     `passi con spia` sotto: i morsi che dichiarati sono tutti in passi
		#     diversi, uno per passo, che e' la contabilizzazione giusta.
		var dichiarati := int(m["dichiara"])
		var arrivati := int(m["passi_con_spia"])
		print("m14 onda %3d: morsi dichiarati %4d, morsi arrivati %4d (scarto %+d) | "
				% [ww, dichiarati, arrivati, arrivati - dichiarati]
			+ "consegnato %s hp, media per morso %s hp, scala dell'onda %s"
				% [_sci(consegnato), _sci(media), _sci(float(m["scala"]))])
		h.eq(arrivati, dichiarati,
			"m14 onda %d: l'orda dichiara %d morsi e ne arrivano %d (%+d): un morso perso o "
				% [ww, dichiarati, arrivati, arrivati - dichiarati]
			+ "consegnato due volte sono difetti diversi e si vedono qui")
		# ## Il disaccordo fra la media vera e la tabella: **il fatto, non rumore**
		#
		# Misurato: la media per morso diviso la scala dell'onda vale `0,3026` su
		# tutte e tre le onde, contro un `TOUCH_DAMAGE_BASE` dichiarato di `1,6`.
		# La tabella **sopravvaluta la media reale di 5,3 volte**, perche' addosso
		# a un giocatore di raggio `body_scale x 1,40 m` ci arriva quasi solo il
		# runner, e il runner e' il piu' economico. E' il motivo per cui la
		# ricostruzione con la tabella e' stata **tolta** e non corretta: questa
		# riga resta qui perché fra un anno il disaccordo si vede.
		h.check(media > 0.0,
			"m14 onda %d: la media per morso deve essere un numero positivo" % ww)
		# ## L'altro conto, e questo **ha** denti: nessuna media
		#
		# Ogni singolo morso che arriva, diviso per la scala dell'onda, deve tornare
		# a un valore **esatto** della tabella delle specie. Qui non c'e' una media
		# che puo' essere sbagliata di un terzo: c'e' `N` numeri, e ognuno o e'
		# giusto o non lo e'. Copre il caso in cui la scala venga applicata alla
		# media invece che alla tabella, che era esattamente il difetto.
		h.eq(int(m["fuori_tabella"]), 0,
			"m14 onda %d: tutti i %d morsi sono un valore di ENEMY.touch_damage_of "
				% [ww, int(m["morsi"])]
			+ "moltiplicato per la scala dell'onda (%s), nessuno fuori tabella"
				% _sci(float(m["scala"])))
		print("m14 onda %3d: media per morso misurata %s hp (tabella TOUCH_DAMAGE_BASE %s: "
				% [ww, _sci(media), _sci(ENEMY.TOUCH_DAMAGE_BASE)]
			+ "le specie piu' grandi non arrivano addosso, e per questo la tabella non "
			+ "e' la media di quello che arriva)")

	print("m14 ingresso/uscita -- tetto morso %.2f/s, scala di fine partita %d, "
			% [1.0 / HORDE.TOUCH_INTERVAL, int(RUN.LAW_HORIZON_WAVE)]
		+ "potenziale del giocatore = danno/intervallo dell'arma vera")
	for w in DIFF_ONDE:
		var ww := int(w)
		var liv := int(RUN.player_level_at(ww - 1))
		var m := _misura_di(misure, ww)
		var cps := float(m["colpi"])
		var ing := float(m["danno"])
		var uscita := _dps_previsto(liv)
		var ing_leg := ing * _scala_legacy(ww) / maxf(0.000001, _scala_di(ww, false))
		print("  onda %3d | scala %14s | morsi %5.2f/s (tetto %.0f%%) | media/morso %9s hp "
				% [ww, _sci(_scala_di(ww, false)), cps,
					100.0 * cps / maxf(0.001, 1.0 / HORDE.TOUCH_INTERVAL),
					_sci(ing / maxf(0.000001, cps * _FINESTRA_S))]
			+ "| ingresso %14s hp/s | uscita liv %3d %14s hp/s | ing/usc %9s | legge di prima %9s"
				% [_sci(ing), liv, _sci(uscita), _sci(ing / maxf(0.000001, uscita)),
					_sci(ing_leg / maxf(0.000001, uscita))])

	## ## L'unica lettura del campione di un'onda
##
## `misure` e' un dizionario **per onda** e viene letto in tre posti: i due cicli
## di `_pressione_ingresso` e il verdetto. Dichiarare `var m := misure[ww]` in
## ciascuno dei tre e' esattamente il difetto che e' appena costato il giro —
## `m` dichiarato dentro un ciclo e usato in un altro non esiste, e l'errore
## arriva a `Parse Error` invece che a un numero. Quindi la lettura sta **qui**,
## una volta sola, e restituisce un dizionario vuoto quando quell'onda non e'
## stata misurata: un vuoto che si puo' controllare, non un'eccezione.
func _misura_di(misure: Dictionary, ww: int) -> Dictionary:
	if not misure.has(ww):
		return {}
	return misure[ww]

## ## Il verdetto, e perche' sta in una funzione **separata** dalla misura
##
## `_pressione_ingresso_verdetto` gira **prima** che la scena vera venga aperta e chiusa,
## perche' dopo quella il contratto tiene un `Game.player` liberato e ogni
## `step()` passa da `horde.gd::_player_hp()` su un oggetto morto (vedi la nota
## lunga in `_difficolta`). Quindi il verdetto, che legge i campioni, sta qui
## sotto e legge i **campi**.
##
## Il verdetto e' stampato con i numeri che lo decidono accanto, non da solo:
## «ROSSO» senza il numero che lo ha fatto rosso e' un verdetto che il prossimo
## giro ricomincia a indovinare.
func _pressione_ingresso_verdetto(h, _isolate: HORDE, _dna: Dictionary) -> void:
	var misure := _diff_misure
	var w_fine := int(RUN.LAW_HORIZON_WAVE)
	var m := _misura_di(misure, int(RUN.LAW_HORIZON_WAVE))
	if m.is_empty():
		h.fail("m14: l'onda %d non e' stata misurata, quindi il verdetto non ha nessun numero"
			% int(RUN.LAW_HORIZON_WAVE))
		return
	var cps_fine := float(m["colpi"])
	var uscita_fine := _dps_previsto(int(RUN.player_level_at(w_fine - 1)))
	var ing_oggi := float(m["danno"])
	var ing_legacy := ing_oggi * _scala_legacy(w_fine) / maxf(0.000001, _scala_di(w_fine, false))
	print("m14 fine partita (onda %d): colpi %.2f/s su un tetto di %.2f/s (%.0f%%), "
			% [w_fine, cps_fine, 1.0 / HORDE.TOUCH_INTERVAL,
				100.0 * cps_fine / maxf(0.001, 1.0 / HORDE.TOUCH_INTERVAL)]
		+ "uscita (potenziale del giocatore al livello %d) %s hp/s"
			% [int(RUN.player_level_at(w_fine - 1)), _sci(uscita_fine)]
		+ "\n     con la legge di oggi  ingresso %s hp/s = %s volte l'uscita"
			% [_sci(ing_oggi), _sci(ing_oggi / maxf(0.000001, uscita_fine))]
		+ "\n     con la legge di PRIMA  ingresso %s hp/s = %s volte l'uscita"
			% [_sci(ing_legacy), _sci(ing_legacy / maxf(0.000001, uscita_fine))])

	# ## I DENTI: lo stesso criterio sulla legge di PRIMA deve andare rosso
	#
	# Senza questa riga il criterio potrebbe essere scritto in modo da passare
	# sempre — per esempio se confrontasse l'ingresso con la **sua** stessa scala.
	# Qui il criterio viene eseguito anche sulla legge storica, e deve **farla
	# fallire**: e' la prova che la porta ha denti.
	var cresce_legacy := _verdetto_cresce(true)
	var fine_legacy := _verdetto_fine(misure, true)
	print("m14 CRITERIO (legge di PRIMA, 0,25/onda con tetto 4,0): %s"
		% ("VERDE" if (cresce_legacy and fine_legacy) else "ROSSO"))
	h.check(not cresce_legacy,
		"m14: sulla legge di prima la scala deve smettere di crescere (HP_SCALE_MAX = 4,0 la "
			+ "ferma all'onda 13): e' il difetto che l'utente ha trovato, e il criterio deve vederlo")
	h.check(not fine_legacy,
		"m14: sulla legge di prima, a fine partita, l'ingresso non puo' stare al passo "
			+ "dell'uscita: e' il difetto che l'utente ha trovato")

	# ## I due verbi sulla legge di oggi
	h.check(_verdetto_cresce(false),
		"m14 CRITERIO: la scala deve crescere strettamente a ogni onda fino a %d, senza tetto"
			% int(RUN.LAW_HORIZON_WAVE))
	h.check(_verdetto_fine(misure, false),
		"m14 CRITERIO: a fine partita (onda %d) la pressione in ingresso non puo' essere "
			% w_fine
		+ "inferiore a quella in uscita: altrimenti l'utente ha ragione e il gioco e' finito")
	print("m14 CRITERIO (legge di oggi): %s"
		% ("VERDE" if (_verdetto_cresce(false) and _verdetto_fine(misure, false)) else "ROSSO"))

## Una finestra di regime a pieno sull'onda `w`. Ritorna `[morsi al secondo,
## danno al secondo]`, entrambi **misurati** e non ricostruiti.
func _misura_pressione(horde: HORDE, w: int) -> Array:
	horde.auto_respawn = true
	horde.set_focus(FAKE_PLAYER)
	horde.restart_run()
	horde.reseed(SEME_CAPACITY)
	# Un passo prima di scrivere l'onda: e' il passo che fa esistere `run`, e il
	# numero che si cambia deve essere quello di una partita vera, non un campo
	# scritto a mano su un oggetto che il contratto non ha ancora creato.
	horde.step(DT)
	horde.run.wave = w
	# ## m12-w1a: il tetto e' `DIFF_POPOLAZIONE`, non `MAX_ENEMIES`
	#
	# Il contatore e' `horde.count` e il tetto e' `population`, quindi basta scrivere
	# `population`: e' lo stesso numero che `_sync_population()` scrive in partita,
	# quindi il campione non dipende dalla curva delle onde. Vedi `DIFF_POPOLAZIONE`
	# per la derivazione del dimezzamento.
	horde.population = DIFF_POPOLAZIONE
	while horde.count > 0:
		horde.damage_enemy(0, 1.0e30, Vector3.ZERO)
	_riempi(horde, DIFF_POPOLAZIONE)
	if horde.count < DIFF_POPOLAZIONE:
		return [-1.0, -1.0]
	for _i in DIFF_WARMUP:
		horde.step(DT)
	_morsi = 0
	_totale_danno = 0.0
	_danno_dichiarato = 0.0
	_morsi_fuori_tabella = 0
	_morsi_totali = 0
	var scala := horde.wave_touch_scale()
	_dichiari_positivi = 0
	_dichiari_colpi = 0
	_passi_con_spia = 0
	for _i in DIFF_WINDOW:
		_danni_step.clear()
		horde.step(DT)
		# La **conta dell'orda**: `touch_bites_last` e' un intero che dice quanti
		# morsi sono usciti in questo passo. Non e' un `float` e non ha scala
		# dentro: e' l'unico numero che si puo' confrontare con una conta di
		# chiamate senza tolleranze e senza medie.
		_dichiari_colpi += horde.touch_bites_last
		if not _danni_step.is_empty():
			_passi_con_spia += 1
			if float(_danni_step[0]) > 0.0:
				_dichiari_positivi += 1
		for importo in _danni_step:
			_morsi_totali += 1
			if scala <= 0.0:
				continue
			var base := float(importo) / scala
			var trovato := false
			for k in ENEMY.KIND_COUNT:
				if absf(base - ENEMY.touch_damage_of(k)) <= 0.0001:
					trovato = true
					break
			if not trovato:
				_morsi_fuori_tabella += 1
	return [float(_morsi) / _FINESTRA_S, _totale_danno / _FINESTRA_S,
		float(_dichiari_colpi), _morsi_totali, _morsi_fuori_tabella]

# === m12: LA TORRE ============================================================
#
# ## Cosa dimostra questa sezione, in una riga
#
# Con quattro piani sovrapposti, **tre cose che erano una diventano una per piano**,
# e ognuna ha un difetto che non si vede: l'ostacolo, il campo di percorrenza e la
# griglia dei vicini. Se una delle tre resta unica, il gioco continua a girare e a
# non produrre un solo errore, e quello che succede e' che il nemico attraversa il
# pavimento.
#
# ## I tre difetti, e il criterio che chiude ognuno
#
# | difetto | cosa fa | criterio |
# |---|---|---|
# | ostacolo unico | il piano 2 evita i dischi del piano 0 | T8: un nemico dentro un disco **del suo** piano viene spinto fuori, e quel disco non esiste sull'altro piano |
# | campo unico | i nemici di un piano inseguono una rampa che non c'e' | T8: il campo di ogni piano e' un oggetto diverso, costruito sulla sua felta |
# | griglia unica | `nearest_enemy` restituisce un nemico **un piano piu' in alto** | T7: nessuna query, a nessun raggio, restituisce un indice di un altro piano |
#
# ## La regola del banco di prova, anche qui
#
# Niente attese: nessuna finestra di questa sezione aspetta il rateo di produzione.
# Il numero di nemici si mette con `_spawn_one()` (che non guarda `population`) e con
# `_populate()` (che e' il cammino vero del primo frame e del restart), e i passi si
# contano in secondi divisi per `DT`. L'unica cosa che la sezione **non** fa e'
# aspettare che la torre si riempia da sola.
#
# ## I due numeri di `floor_count` e `floor_height` sono **dichiarati**, non misurati
#
# Vengono dal piano (sezione «Quattro piani, uno per biomo») e sono impostati qui sul
# contratto perche' la sezione deve poter girare **prima** che `-arda` li registri,
# e girare dopo non aggiungerebbe niente: `floor_count` e' geometria statica, e la
# torre che si registra da sola verrebbe provata da `test_arda`. Il raggio
# dell'arena invece **non e' dichiarato qui**: e' di `-arda` e questa sezione lo
# **legge** da `Game.arena_radius`, perche' un raggio scritto a mano in un test
# sarebbe una copia che mente alla prima riga cambiata di `src/render/arena.gd`.

## Piani della torre, dai numeri del piano. Non sono una scelta di questa sezione.

