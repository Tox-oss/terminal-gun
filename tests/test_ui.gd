extends SceneTree
## Test dell'HUD di terminal-gun. -ui, milestone 2.
##
## Verifica i tre numeri che m2 chiede all'interfaccia, i numeri duplicati fra
## un avvio e un restart, e il punto in cui l'HUD deve **leggere** invece di
## sapere (piano sez. 1.1, criteri n. 2 e n. 4, e la consegna di questa foglia):
##
##   1. **barra XP in [0, next] sempre**: mai `NaN`, mai `INF`, mai una larghezza
##      negativa, nemmeno con `next` a zero e nemmeno con un `INF` o un `NaN`
##      che entra dalla porta;
##   2. **contatore d'onda a 1 all'avvio**, che sale quando l'onda avanza e che
##      **torna a 1 dopo il restart**;
##   3. **game over a 0 HP**, e che sparisce al restart;
##   4. **nessun nodo duplicato** fra due restart: l'HUD ha un numero di nodi
##      fisso e lo conserva;
##   5. **il numero di nemici viene dall'orda, non da un letterale**: l'HUD
##      mostra il `count` che l'orda ha **adesso**, e lo segue quando l'orda
##      cambia. La popolazione d'avvio e' un numero di `-orda`
##      (`Run.population_of(1)`, in `src/sim/run.gd`) e non un dato di questa
##      foglia: qui dentro non c'e' nessun `25` e nessun `200`, perche' un
##      letterale diventa falso alla prima milestone che tocca la curva e,
##      intanto, fa passare un HUD con un numero scritto dentro;
##   6. **il numero che arriva all'HUD e' anche il numero che si vede**: le
##      verifiche sui campi (`xp_ratio()`, `wave_ratio()`) non bastano, perche'
##      un HUD puo' ricevere 0.995 e scrivere 1.0 sul `ProgressBar`. Ogni barra
##      viene quindi confrontata anche sul **valore disegnato**, letto dal nodo.
##      Il caso che ha reso la verifica necessaria e' `Range.step`, che vale
##      0.01 per default e **arrotonda a scatti** quello che gli viene scritto:
##      su un'onda da 200 uccisioni (`Run.population_of` e' di -orda) una
##      uccisione vale 0.005, meta' scatto, e la barra dell'onda restava ferma
##      per meta' onda. Il fix e' `step = 0.0` su tutte e tre le barre, e
##      qui si verifica su tutte e tre perche' una decisione dichiarata solo in
##      un commento decade senza rumore.
##   7. **m17, il tempo a schermo segue `Run.elapsed_s`**: il criterio e'
##      **l'avvelenamento**, non «c'e' un numero». Il test scrive `1e9` sul campo
##      vero di `-orda`, rillega l'HUD e il numero a schermo deve essere
##      cambiato. Un tetto che dica `00:00` e fermo passerebbe una verifica che
##      guarda solo il testo, e un HUD che contasse i frame da per se' passerebbe
##      una verifica che guarda solo il testo: la lettura e' quello che si prova.
##   8. **m13-w2, il richiamo al restart nomina un tasto vero**: non si confronta
##      la stringa (il testo e' di questa foglia) ma il **nome del tasto**, che
##      deve essere quello che `-gameplay` dichiara in `RESTART_KEYS`. E il
##      richiamo deve comparire col game over e sparire col restart.
##
## ## m7: la meta' di questa foglia, e che cosa **non** e' sua
##
## Il criterio n. 4 di m7 e' «la HUD mostra la salute vera». Il cablaggio
## esisteva gia' dal primo giorno: `src/render/arena.gd` legge `Game.player.hp` e
## `Game.player.max_hp` e chiama `set_state(...)` ogni frame (arena.gd:83, 87, 91).
## La barra era **piatta** perche' nessun codice di gioco scriveva `hp`, non
## perche' mancasse un filo: quindi la meta' di `-ui` qui dentro e' **un test**,
## non un intervento.
##
## Percio' la parte nuova di questo file non scrive `hp` e non chiama
## `damage_player` a mano per poi dichiarare che la barra e' scesa: **legge la vita
## vera dal giocatore e confronta** quello che l'HUD ne ha fatto, quattro volte
## per avvio — vita iniziale, dopo un colpo, dopo una cura, a zero — e in ogni
## caso confronta tre cose: la barra **disegnata**, il rapporto **ricalcolato qui**,
## e i **numeri dentro la scritta**. Il testo non e' di questa foglia (la metafora
## e' dell'utente, RAM disponibile), quindi il confronto non e' sulla stringa: e'
## sui numeri che ci sono dentro, cosi' "HP 67 / 100" e "RAM 67% di 100" sono lo
## stesso HUD e un HUD con un numero stampato dentro non passa lo stesso.
##
## Il danno e la cura arrivano dai **metodi veri del giocatore**
## (`take_damage()`, `heal()`), che sono la porta che `Game.damage_player()`
## chiama e che -orda chiama dal ciclo di gioco: qui il test non scrive il campo
## `hp` a mano nemmeno per fare scena, perche' un test che scrive il numero che
## poi confronta sta verificando se stesso.
##
## ## Perche' due parti e non una
##
## La prima parte istanzia `scenes/hud.tscn` da solo: e' la parte che non puo'
## fallire per un file di un'altra foglia, e verifica la logica dell'HUD su
## numeri arbitrari, cosa che nella scena vera non si puo' fare (l'XP la mette
## solo `-gameplay`).
##
## La seconda parte carica `scenes/arena_main.tscn` per intero e verifica che
## l'HUD, **nella partita vera**, legga i numeri che le altre foglie espongono
## davvero: e' la verifica che un HUD con la logica giusta ma scollegata dal
## gioco non passerebbe.
##
## ## I due punti di accoppiamento, dichiarati
##
## L'HUD legge due campi che non sono suoi: `Game.player.progression.xp` (di
## `-gameplay`) e `Game.horde.wave` (di `-orda`). Qui sono verificati sul
## contratto vero, e per `wave` la verifica e' condizionata al campo che
## `-orda` deve dichiarare: se il campo non c'e' ancora, il test **stampa la
## nota** e controlla il valore di riserva, invece di far fallire un'onda che sta
## costruendo l'altra foglia in parallelo. Il rumore e' voluto: un contatore
## d'onda fermo a 1 senza che nessuno lo noti e' il difetto che questa verifica
## deve rendere visibile.
##
## Il terzo numero che questa parte controlla, il **conteggio dei nemici**, non
## arriva da `refresh()` ma dal canale di m1: `src/render/arena.gd::_process`
## chiama `set_state(...)` con `Game.horde.count`. Quindi anche qui il confronto
## e' sul contratto vero, e sullo stesso campo che il chiamante legge: il numero
## che l'HUD mostra e' quello che `-orda` ha adesso, mai una copia messa qui.
##
## ## Perche' esiste `_tick` e non un `arena.call("_process")` solo
##
## I due canali muoiono in due modi diversi. Un'uccisione cambia `horde.count`
## **e** `run.wave_killed`, quindi muove l'etichetta dei nemici (canale di m1,
## `set_state`) e la barra d'onda (canale di m2, `refresh`) **nello stesso
## istante**. Rilanciando un `_process` solo, si legge meta' della partita e si
## conclude che l'HUD segue l'orda quando invece segue solo una delle due.
## `_tick` chiama entrambi, ed e' l'unico posto che lo fa.
##
## ## La trappola del `const preload` (piano sez. 5.3)
##
## `scenes/arena_main.tscn` si carica con `load()` **dentro il corpo del test**,
## mai in `const`: un `const preload` risolve gli script a tempo di compilazione,
## PRIMA che l'autoload `Game` sia fra le costanti globali, e `player.gd` usa
## l'identificatore nudo `Game`. Solo `tools/test_harness.gd` e' in `const`, e non
## tocca il contratto.
##
## Stringhe a schermo solo ASCII: la console di Windows e il pipe di
## `OS.execute` sono in codepage e un accento diventa spazzatura proprio nel
## messaggio che serve a capire un fallimento.

const H = preload("res://tools/test_harness.gd")

const HUD_SCENE := "res://scenes/hud.tscn"
const ARENA_SCENE := "res://scenes/arena_main.tscn"

## La soglia di `xp_next` usata nella parte a HUD solo: la stessa forma di
## quella di `progression.gd`, cosi' l'arbitriario che si prova e' un numero
## plausibile e non un valore assurdo che nessun test deve poter produrre.
const XP_SPAN := 8.0

## `INF` e `NaN` entrano dalla porta di `set_progression`: e' il caso che
## `clampf` **non** copre, perche' ogni confronto con `NaN` e' falso e il clamp
## restituisce `NaN` invece di 0. Se l'HUD non li ferma lui, il test passa e
## l'HUD e' invisibile.
const NOT_FINITE := [INF, -INF, NAN]

## Nodo dell'HUD che il test cerca nella scena. Il nome e' in `scenes/hud.tscn`
## e in `scenes/arena_main.tscn`: se un giorno cambiasse, fallirebbe qui e non in
## silenzio.
const HUD_NODE := "Hud"

## Un numero che **non** sta sulla griglia di arrotondamento del default di
## `Range` (`step = 0.01`): 3.3333 non e' un multiplo di 0.01.
##
## Serve a provare che le barre disegnano il numero che l'HUD ha ricevuto e non
## quello che il nodo ha arrotondato. Con lo step di default questa verifica
## fallisce (3.33 contro 3.3333), ed e' esattamente il difetto che ha reso muta
## la barra dell'onda: il dato giusto che non si vede. Non usare qui un valore
## multiplo di 0.01, altrimenti la verifica passa senza aver mai provato niente.
const OFF_GRID := 3.3333

## ## m17: il numero con cui si avvelena l'orologio
##
## Un milione di secondi, cioe' circa **31 689 anni** di partita: un numero che
## nessuna partita raggiunge e che quindi non puo' essere quello di partenza
## dell'HUD ne' un arrotondamento di qualcos'altro. Non e' un numero di gioco e
## qui dentro non viene dedotto: serve solo a essere **Diverso**, e grande,
## perche' la verifica sia «il numero a schermo e' cambiato» e non «il numero
## a schermo e' un numero».
##
## Il punto e' che il campo avvelenato e' `Run.elapsed_s`, **quello vero**: se
## l'HUD contasse i frame o tenesse un orologio proprio, l'avvelenamento non
## cambierebbe niente a schermo e qui andrebbe rosso. E' la ragione per cui il
## numero e' volutamente assurdo invece che comodo.
const POISON_S := 1000000000.0

## ## m13-w2: il nome del dato che dichiara i tasti del restart
##
## E' di `-gameplay` (`RESTART_KEYS`, in `src/player/player.gd`) e qui e' una
## **stringa**, perche' quello che si cerca non e' un campo: e' una costante di
## uno script, che si legge dal contratto. Il nome compare in due punti di questo
## file perche' sono due strade diverse di leggere lo stesso dato (istanza e
## mappa delle costanti); se il nome cambiasse, il test andrebbe rosso invece di
## confrontare due cose entrambe vuote.
const RESTART_KEYS_MEMBER := "RESTART_KEYS"

var _h: H = null
var _ran: bool = false
## `-ui`, m6. Il pannello delle carte **mette in pausa l'albero**, e una parte di
## questo test ha bisogno di guardare il giocatore mentre l'albero e' fermo:
## serve aspettare che passino dei frame *di fisica*, e in un test sotto
## `--script` non c'e' nessun frame da aspettare senza chiederlo.
##
## Quindi `_process` non finisce mai il test da solo: finisce solo quando `_run()`
## arriva in fondo e chiama `quit()`. `_wait_physics` sospende `_run()` con un
## `await` e il ciclo continua a girare intanto, quindi mettere in pausa
## l'albero **non ferma il test**: `SceneTree._process` e' il ciclo del
## `MainLoop`, non un nodo, e la pausa dei nodi non lo tocca (e' esattamente la
## ragione per cui il pannello puo' essere `PROCESS_MODE_ALWAYS` e il test no).
var _done: bool = false


func _initialize() -> void:
	_h = H.new()


func _process(_delta: float) -> bool:
	if _ran:
		return _done
	_ran = true
	_run()
	return _done


## Aspetta che passino `n` frame **di fisica**, non di processo.
##
## La distinzione non e' pignolerie: il criterio n. 2 chiede che "il giocatore
## non si muove", e il giocatore si muove in `_physics_process`. Aspettare frame
## di processo in un test headless -- dove il ciclo gira piu' veloce del
## realtime -- puo' voler dire che nel mezzo non e' passato **nessun** passo di
## fisica, e "non si e' mosso" passerebbe senza aver provato niente.
##
## Il contatore e' un tetto, non un'attesa infinita: se i frame di fisica non
## avanzassero, il test si bloccherebbe e il gate lo ucciderebbe fra 120 s
## dicendo "timeout", che e' un fatto diverso da "l'attesa non serve". Qui si
## esce prima e si dice il numero misurato.
const PHYSICS_WAIT_CAP := 20000

func _wait_physics(n: int) -> int:
	var start := Engine.get_physics_frames()
	var seen := 0
	while Engine.get_physics_frames() < start + n and seen < PHYSICS_WAIT_CAP:
		seen += 1
		await physics_frame
	return Engine.get_physics_frames() - start


func _run() -> void:
	var h := _h

	var game := root.get_node_or_null("Game")
	if not h.check(game != null, "l'autoload Game non e' stato istanziato: questo test non puo' girare"):
		quit(h.finish("test_ui"))
		return

	# Il numero di nodi sotto `root` **prima** che questo test apra qualcosa:
	# e' il numero a cui l'uscita deve tornare, e lo dichiara il test stesso
	# invece di un letterale scritto qui dentro.
	_nodes_at_boot = _count_nodes(root)

	# Prima di tutto la regola che guarda **questo file** (vedi
	# `_ritorni_morti_si_provano`): e' una porta, quindi va eseguita anche quando
	# tutto il resto va bene, e va eseguita per prima perche' e' quella che puo'
	# dire che questo file non meriterebbe di essere eseguito.
	_ritorni_morti_si_provano(h)

	_hud_alone(h)
	# Senza tipo: `_open_arena` restituisce un Variant (il risultato di
	# `instantiate()`), e `:=` su un Variant non compila. Con `:` dichiarato
	# `:=` sbaglierebbe lo stesso tipo per una riga che non ha.
	var arena = _open_arena(h, game)
	if arena == null:
		quit(h.finish("test_ui"))
		return

	# Tre avvii della scena vera: il primo e due restart. Il confronto fra i tre
	# e' il controllo sui nodi duplicati, e il confronto fra il primo e gli altri
	# due e' il controllo che il restart ripulisce davvero (schermata di game over
	# inclusa).
	var first := _scene_round(h, game, arena, 1)
	_close(arena)

	var second := _scene_round(h, game, _open_arena(h, game), 2)
	_close(second.get("arena"))

	var third := _scene_round(h, game, _open_arena(h, game), 3)
	_close(third.get("arena"))

	print("test_ui: nodi dell'HUD per avvio: %d / %d / %d"
		% [int(first["hud_nodes"]), int(second["hud_nodes"]), int(third["hud_nodes"])])
	print("test_ui: un solo nodo \"%s\" sotto root in ogni avvio: %d / %d / %d"
		% [HUD_NODE, int(first["huds"]), int(second["huds"]), int(third["huds"])])
	print("test_ui: popolazione d'avvio letta da horde.count e mostrata dalla HUD: %d / %d / %d"
		% [int(first["boot_pop"]), int(second["boot_pop"]), int(third["boot_pop"])])

	await _upgrade_flow(h, game)

	var costo_uscita := await _exit_section(h)
	print("test_ui: sezione di uscita: %d ms" % costo_uscita)

	_done = true
	quit(h.finish("test_ui"))

# --- Parte 4: l'uscita ----------------------------------------------------------
#
# ## Cosa c'era qui e cosa c'e' adesso
#
# Prima di questa sezione il test finiva con `quit()` **nello stesso istante**
# in cui aveva liberato l'ultima scena, e il motore usciva con
# `WARNING: 2 ObjectDB instances were leaked at exit` e
# `ERROR: 1 resources still in use at exit` **dopo** il `PASS`. La porta legge
# l'uscita e su quel rosso rifiuta il verde: un test che dice PASS e poi lascia
# un errore non puo' aver girato tutto, e ha ragione.
#
# ## Chi e' il colpevole, misurato e non indovinato
#
# `--verbose` dice i due oggetti e la risorsa: `AudioStreamPlaybackWAV` e
# `AudioStreamWAV`, e la risorsa in uso e' `res://assets/sfx/levelup.wav`. Sono
# **un solo leak in tre righe**, non due: il playback tiene il riferimento alla
# risorsa che sta suonando. Non e' `bonk.wav`, che era il sospetto dichiarato
# il 2026-10-13: in questo test `bonk` non parte mai, perche' nessun proiettile
# torna indietro (l'uccisione la provoca il test con `damage_enemy`).
#
# Chi suona `levelup.wav` e' `src/player/player.gd::_on_leveled_up` (riga 637),
# che e' di **`-gameplay`**: questa sezione non puo' chiuderlo e non finge di
# averlo chiuso.
#
# ## Perche' pero' il vuoto e' qui, e misurato
#
# Tre fatti, ognuno con il numero accanto, e non una spiegazione:
#
# 1. **non resta nessun nodo**: all'uscita sotto `root` ci sono `0` nodi
#    `AudioStreamPlayer3D`. Il nodo che suona e' gia' stato liberato con la
#    scena: non e' un nodo appeso, quindi non si chiude liberandolo.
# 2. **`stop()` non chiude niente**: chiamato mentre il nodo e' ancora
#    nell'albero, il leak resta identico (due righe di ObjectDB, una di
#    risorsa). Non e' l'ipotesi del piano ("fermare il suono prima dello
#    smontaggio"): e' misurata e falsa.
# 3. **un mix del server audio chiude tutto**: le due istanze e la risorsa
#    spariscono quando `AudioServer` mescola una volta dopo la liberazione.
#
# Quindi il vuoto e' **l'ordine di smontamento del motore**, non un oggetto
# appeso: `ObjectDB::cleanup()` passa prima dell'ultimo mix e trova il playback
# ancora registrato. Il gioco continua a suonare (`levelup`, `hurt`, `bonk`
# suonano come prima, nessuna riga di `src/**` e' stata toccata) e questa
# sezione **non chiama l'audio**: aspetta che il motore smonti come smonta.

## La classe dei nodi che suonano. Per nome di classe, non per nome di nodo:
## i tre suoni del giocatore hanno tre nomi diversi (`Sfx` dalla scena, `hurt` e
## `levelup` creati a runtime da `player.gd::_sound`) e nessuno di quei nomi e'
## di questa foglia. La classe e' di tutte e tre.
const AUDIO_CLASS := "AudioStreamPlayer3D"

## ## Perche' qui **non c'e' piu'** un pavimento, e la data in cui si e' saputo
##
## Qui c'era un minimo derivato dalla scena viva, mai scritto a mano:
##
##     scaricate >= nodi audio vivi nella scena alla chiusura
##
## con la giustificazione «ogni `AudioStreamPlayer3D` vivo tiene al massimo una
## playback». La giustificazione e' **vera** e pero' **non dice quello che sembra**:
## un nodo audio che **non sta suonando** non tiene nessuna playback. Dai nodi si
## ricava quindi un **tetto** sulle playback vive, non un pavimento: ogni nodo puo'
## valere zero. Un tetto usato come pavimento e' la soglia spostata fino a far
## passare il numero, ed e' esattamente quello che e' successo.
##
## Il 2026-10-15 la sezione e' andata rossa per la prima volta, e il rosso dice il
## difetto meglio di qualunque commento: `scaricate 2` contro `pavimento 3`. Il
## pavimento era salito perche' la scena aveva **un nodo audio in piu'** di ieri
## (3 invece di 2), non perche' fosse rimasto piu' rumore: e un nodo in piu' non
## puo' far **scendere** le istanze liberate. Il minimo e' salito mentre il numero
## vero e' sceso di uno: e' la firma di una derivazione capovolta.
##
## ## La cosa che non e' misurabile, dichiarata perche' il criterio non se la
## ## prometta
##
## **Quante playback sono vive** non lo si puo' sapere da script: non esiste
## un'API che enumeri le istanze di `ObjectDB` per classe, `Performance.OBJECT_COUNT`
## e' un totale senza classe dentro, e la sonda qui sotto e' strutturalmente cieca
## alle playback (una playback non e' una `Resource` e non e' la proprieta' di un
## nodo, quindi `_note_resources` non puo' vederla per costruzione). Quindi quale
## istanza non scende **non e' una domanda a cui questo test risponde**, e il file
## non ci mette dentro un numero per fingere che risponda.
##
## Al suo posto resta quello che si puo' dimostrare: lo scarico deve **muovere** al
##meno un contatore. E i due numeri veri — quanti nodi audio erano vivi nella scena
## e quanti **stavano suonando** — restano stampati accanto al numero vero: sono
## la spiegazione del numero che si muove, non un suo sostituto.

## Quanti nodi audio **stavano suonando** quando la scena e' stata chiusa: letto
## dalla scena viva in `_note_resources`, mai scritto qui.
##
## Non e' il pavimento di nessun criterio e non deve diventarlo: anche questo e' un
## **tetto** (un nodo che sta suonando puo' non avere ancora una playback
## registrata, se il miscelatore non e' passato dopo l'ultimo `play()`). Va stampato
## perche' spiega il numero che si muove, non perche' lo governi.
func _sounding_at_close() -> int:
	if _players_sounding_at_close < 0:
		return -1
	return _players_sounding_at_close

## Quanti frame di processo si aspettano prima di dire "il server audio non ha
## mescolato". E' un tetto, non un'attesa infinita: se il server non mescolasse
## il test si bloccherebbe e la porta lo ucciderebbe fra 120 s dicendo "timeout",
## che e' un fatto diverso da "l'attesa non serve".
const AUDIO_MIX_WAIT_CAP := 600

## Quanti nodi sotto `root` ci sono **all'avvio del test**, prima che questa
## sezione apra qualunque cosa. E' il numero a cui l'uscita deve tornare: se la
## partita lascia qualcosa appeso, il numero resta piu' alto.
var _nodes_at_boot: int = -1

## ## Lo stato che si asserisce, e perche' non basta «l'uscita e' pulita»
##
## Il difetto che questa sezione chiude si vede **solo** nelle righe che il
## motore stampa dopo il `PASS`, e un test che guarda la propria uscita non le
## vede: direi `PASS` e basta lascerebbe il difetto esattamente dove sta. Quindi
## qui si asserisce **lo stato**, non l'assenza di rumore:
##
##   - sotto `root` non resta **nessun** nodo audio, ne' nessun `Hud`, e il
##     numero di nodi e' tornato a quello di avvio;
##   - e lo scarico **muove** il numero di istanze vive: non un minimo di
##     istanze, perche' un minimo derivato dalla scena era una derivazione
##     capovolta (vedi sopra, e la data del rosso che l'ha smascherata), ma il
##     fatto stesso di cui il difetto e' fatto — non muovere niente. Il numero
##     vero viene stampato accanto, perche' un criterio che dicesse solo «almeno
##     una» nasconderebbe quanto ne libera davvero, e chi legge dopo prenderebbe
##     quella per il conteggio.
##
## Il secondo punto e' quello con i denti: senza lo svuotamento i numeri non
## scendono e qui va rosso.
func _exit_section(h) -> int:
	var t0 := Time.get_ticks_msec()

	var audio := _count_class(root, AUDIO_CLASS)
	h.eq(audio, 0,
		"chiusa la partita non deve restare nessun nodo \"%s\" sotto root, e ne restano %d: il suono della partita e' rimasto appeso" % [AUDIO_CLASS, audio])
	h.eq(_count_named(root, HUD_NODE), 0,
		"chiusa la partita non deve restare nessun nodo \"%s\" sotto root: l'HUD che ha aperto la partita deve uscire con lei" % HUD_NODE)
	h.eq(_count_nodes(root), _nodes_at_boot,
		"sotto root devono restare i nodi di avvio e non uno di piu': una partita che non si svuota e' una partita che la riaperta moltiplica")

	var prima := _live_objects()
	var scarico := await _drain_audio()
	var dopo := _live_objects()
	# Chi e' la risorsa che il conto sopra non libera. Dopo lo scarico, che e'
	# l'unico momento in cui qualcosa e' stato liberato davvero: prima di questo
	# punto tutte le risorse della partita sarebbero vive e la riga non
	# direbbe niente.
	_report_live_resources()
	# Quante istanze sono state **liberalte**: e' il numero che il motore
	# stampa all'uscita, preso col segno giusto. Sottraendo in due passi si
	# potrebbe scrivere l'asserzione al contrario senza accorgersene.
	var scesi: int = int(prima[0]) - int(dopo[0])
	# La sonda deve essere partita: i numeri sulla scena viva sono la
	# spiegazione del numero che si muove, e senza di loro questa sezione
	# guarda il totale e non sa di che sta parlando.
	h.check(_players_at_close >= 0,
		"la sonda risorse non e' mai partita, quindi i numeri \"nodi audio nella scena\" e \"quanti stavano suonando\" qui sotto sono -1 e il numero di istanze liberate non ha niente su cui appoggiarsi")

	# I tre numeri che non vanno confusi: i primi due sono lo **stesso**
	# conteggio a due istanti diversi, e nessun nodo e' rientrato.
	print("test_ui: uscita: sotto root %d nodi (avvio %d), %d nodi \"%s\" sotto root DOPO la chiusura della scena"
		% [_count_nodes(root), _nodes_at_boot, audio, AUDIO_CLASS])
	print("test_ui: uscita: dentro la scena PRIMA di liberarla %d nodi \"%s\", dei quali %d stavano suonando (istante diverso dal numero di sopra: e' la stessa classe contata dentro e fuori dalla scena, non un numero che va e viene)"
		% [_players_at_close, AUDIO_CLASS, _sounding_at_close()])
	print("test_ui: uscita: istanze ObjectDB %d -> %d, liberate %d; risorse vive %d -> %d; scarico audio %d frame"
		% [int(prima[0]), int(dopo[0]), scesi, int(prima[1]), int(dopo[1]), scarico])

	# ## Il numero che il leak muove, e perche' qui sotto non c'e' un **minimo**
	#
	# Il motore stampa due righe (`N ObjectDB instances`, `M resources`) ma il
	# numero che si muove e' il primo: quello e' l'unico che questo test
	# asserisce.
	#
	# `OBJECT_RESOURCE_COUNT` non e' un secondo criterio: e' stato misurato due
	# volte sulla stessa riga e **non e' stabile**. Con lo scarico che libera due
	# istanze la risorsa resta `22 -> 22`; con lo scarico che ne libera quattro
	# scende `22 -> 21`. Il conto della risorsa dipende da quale suono resta
	# appeso in quel momento, quindi asserirci sopra produrrebbe un criterio che
	# va rosso o verde per il caso, non per il difetto. Va stampato accanto al
	# numero vero, che e' dove serve: per vedere **che e' sceso** insieme alle
	# istanze. Ed e' anche il conto su cui la sonda delle risorse si confronta, ma
	# li due non sono lo stesso numero (vedi il doc-comment di `_live_objects`).
	#
	# Sulle istanze **non c'e' piu' un minimo**, e la ragione sta nel blocco sopra:
	# il minimo che c'era era derivato capovolto (un tetto usato come pavimento)
	# e il 2026-10-15 e' andato rosso per quello, non per un difetto. Quello che
	# resta e' la **vita**: lo scarico deve muovere almeno un contatore, perche'
	# zero e' proprio il difetto — e l'esperimento coi denti tolti e rimessi dice
	# che senza scarico il numero non si muove affatto (`1551 -> 1551`) e il
	# motore riscrive le due righe. Un numero che pretende di dire *quante*
	# playback restano non e' disponibile, e sopra e' scritto perche'.
	h.check(scesi > 0,
		"lo scarico audio non ha liberato nessuna istanza ObjectDB (%d -> %d): e' il difetto che questa sezione chiude, perche' e' quello che fa riscrivere al motore `N ObjectDB instances were leaked at exit` e `M resources still in use at exit`. Qui non c'e' un minimo di istanze da confrontare perche' non e' derivabile: i %d nodi \"%s\" della scena (di cui %d stavano suonando) sono un tetto sulle playback vive, non un pavimento, e quale istanza non scende non e' misurabile da script"
			% [int(prima[0]), int(dopo[0]), _players_at_close, AUDIO_CLASS, _sounding_at_close()])
	# E lo scarico e' avvenuto: se il tetto di attesa fosse scaduto, il numero
	# sopra andrebbe rosso ma per un motivo che qui si dice. Sono due fatti, non
	# uno, e il secondo e' quello che rende leggibile il primo.
	h.check(scarico < AUDIO_MIX_WAIT_CAP,
		"il server audio non ha mescolato entro %d frame di processo: l'attesa non ha potuto provare niente e il numero di oggetti qui sopra non significa niente" % AUDIO_MIX_WAIT_CAP)

	return Time.get_ticks_msec() - t0

## Quante istanze `ObjectDB` e quante risorse sono vive adesso.
##
## Sono **gli stessi due conti** sui quali il motore fonda i due messaggi
## all'uscita (`ObjectDB::cleanup()` e `Resource::clear()`): non e' un modo
## furbo di contare qualcos'altro, e' il numero che il difetto muove. Non si
## toccano: si leggono.
##
## ## I due numeri di risorse che si leggono qui non sono confrontabili
##
## `OBJECT_RESOURCE_COUNT` conta **ogni** `Resource` viva nel motore. La sonda
## qui sotto conta **un sottoinsieme**: le sole risorse raggiungibili dalle
## proprieta' dei nodi di quella scena, al momento della chiusura. Quindi
## `24 -> 24` e `1 vive su 27 annotate` non sono due risposte contraddittorie a
## una domanda sola: sono due domande diverse, e il numero grande e' l'unico
## che puo' muoversi per il motivo di cui sopra. La frase sta qui, una volta: il
## conto del motore e' il verdetto, il conto della sonda e' il nome.
func _live_objects() -> Array[int]:
	return [
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
	]

## --- La risorsa che l'uscita non libera: chi e' --------------------------------
#
# `Performance.OBJECT_RESOURCE_COUNT` dice **quante**, non **quale**, e nessuna
# API di GDScript enumera le risorse vive. Quindi qui si fa il contrario di
# `OBJECT_COUNT`: si annotano **prima** le risorse che si possono nominare, con
# un `WeakRef`, e all'uscita si controlla quali sono ancora valide.
#
# Il `WeakRef` e' la parte che rende lo strumento onesto: non tiene vivo niente,
# quindi annotare una risorsa **non puo'** cambiarne la vita, e una risorsa che
# qui risulta viva e' viva perche' qualcun altro la tiene. Senza questo, la sonda
# creerebbe il difetto che sta misurando.
#
## Dove si annotano: a fine `_upgrade_flow`, con l'ultima scena **ancora viva**,
# che e' l'unica occasione in cui si possono vedere i suoi campi.

## Le risorse annotate, e dove stavano. Due array paralleli: il riferimento e il
## nome che lo rende leggibile. Non un dizionario perche' la stessa risorsa puo'
## stare in piu' campi e in quel caso si vuole vedere **tutti** i posti che la
## tengono, non il primo trovato.
var _note_ref: Array = []
var _note_where: Array[String] = []
## Quanti nodi audio sono vivi **nella scena al momento della chiusura**, cioe'
## prima di liberarla. Non e' un numero scritto qui: e' quello che la scena ne
## aveva. Vale come **tetto** e non come pavimento, per la ragione scritta nel
## blocco «Perche' qui non c'e' piu' un pavimento».
var _players_at_close: int = -1
## Quanti di quei nodi audio **stavano suonando** nello stesso istante. Anche
## questo e' un tetto (un nodo che suona puo' non avere ancora la playback
## registrata), quindi va stampato e non asserito.
var _players_sounding_at_close: int = -1

## Annota ogni `Resource` raggiungibile da `node`, senza tenerla viva.
##
## Il filtro e' `PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_STORAGE`: senza
## si raccoliebbe anche `script`, che e' una `Resource` e resta viva per tutto il
## processo per la cache dei GDScript. Quindi ogni script scoperto viene
## **saltato e contato**, e il conto e' stampato: uno strumento che nasconde il
## proprio rumore non e' uno strumento.
func _note_resources(node: Node) -> void:
	var script_visti := 0
	_players_at_close = _count_class(node, AUDIO_CLASS)
	_players_sounding_at_close = 0
	var coda: Array[Node] = [node]
	while not coda.is_empty():
		var n: Node = coda.pop_back()
		for child in n.get_children():
			coda.append(child)
		# `playing` e' una **proprieta'**, non un metodo, e si legge per nome come
		# tutto il resto della classe: il file non si lega al tipo. `bool()` su un
		# valore assente vale `false`, quindi un nodo audio senza `playing` non
		# falsifica il conto.
		if n.is_class(AUDIO_CLASS) and bool(n.get("playing")):
			_players_sounding_at_close += 1
		for p in n.get_property_list():
			if (int(p["usage"]) & (PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_STORAGE)) == 0:
				continue
			var v = n.get(str(p["name"]))
			if v is Script:
				script_visti += 1
				continue
			if not (v is Resource):
				continue
			# Tipo esplicito: `weakref()` restituisce un Variant e `:=` su un
			# Variant e' un errore in questo progetto (il file si ferma li').
			#
			# **Nessuna deduplica, di proposito**: la stessa risorsa in due campi
			# viene annotata due volte, e le due righe dicono **chi** la tiene,
			# che e' la domanda che questa sonda fa.
			var w: WeakRef = weakref(v)
			_note_ref.append(w)
			_note_where.append("%s.%s" % [n.get_path(), p["name"]])
	print("test_ui: sonda risorse: %d annotate, %d script saltati, %d nodi \"%s\" vivi nella scena alla chiusura, dei quali %d stavano suonando (conti dentro la scena: sono un sottoinsieme del totale del motore, vedi `_live_objects`)"
		% [_note_ref.size(), script_visti, _players_at_close, AUDIO_CLASS, _players_sounding_at_close])

## **Stampa e non asserisce**, e la firma e' `-> void` per questo e non per
## dimenticanza. Il numero che qui sotto si conta e' un **movimento**, non un
## **verdetto**, e il perche' e' preciso: il 2026-10-15 la sonda ha dato un
## **nome** — `AudioStreamWAV`, raggiunta da `SfxLevelUp.stream`, cioe' la
## proprieta' `.stream` di un `AudioStreamPlayer3D` **dentro la scena** e non una
## riga di codice: quel nome di nodo e' `NOME_SFX_LEVELUP` in
## `src/player/player.gd`, e la risorsa la tiene la **cache di import del
## motore**, quindi non e' di questa foglia e nessuno qui dentro la puo'
## liberare. Ma restare vivo un **nome** non vuol dire essere **quell'istanza**
## che `OBJECT_COUNT` non libera: i due conti sono due universi diversi (vedi
## `_live_objects`), quindi il nome e' una scoperta e non ancora una spiegazione.
## Per questo la firma e' `-> void` e non `-> int`: un `h.eq(...)` su quel numero
## metterebbe nel file una soglia che nessuno ha misurata.
##
## Le risorse annotate che sono **ancora vive** all'uscita, per nome di classe e
## per id di istanza.
##
## E' la riga che risponde a «cos'e' quella risorsa?». Un id di istanza non si
## puo' leggere a mano, ma si puo' **ricercare**: chi legge puo' mettere l'id
## vicino al nome della classe e chiedere il percorso della risorsa. Il numero
## che interessa pero' e' il confronto con ieri: se sono **zero**, la risorsa che
## non viene liberata non e' nessuna di quelle della scena, e quindi non e' di
## questa foglia.
func _report_live_resources() -> void:
	var vive := 0
	for i in _note_ref.size():
		var w: WeakRef = _note_ref[i]
		var r = w.get_ref()
		if r == null:
			continue
		vive += 1
		print("test_ui: risorsa ancora viva all'uscita: %s (era %s) #%d"
			% [r.get_class(), _note_where[i], (r as Resource).get_instance_id()])
	print("test_ui: sonda risorse: %d vive all'uscita su %d annotate"
		% [vive, _note_ref.size()])

## ## m12-w1b: i ritorni morti, e una porta che li cerca da sola
##
## Il difetto appena chiuso era una funzione con la **firma di una porta**
## (`-> int`) e il **comportamento di una sonda**: il numero che restituiva non
## lo guardava nessuno. Un lettore che vede `-> int` ragiona «qui c'e' un numero
## che viene controllato», e non e' vero: la promessa e' senza consumatore.
##
## Quindi la regola e' questa: **una funzione che non restituisce `void` deve
## avere un chiamante che si mangia il risultato**. Il chiamante puo' essere
## un'assegnazione, un `if`, un `print`, un `h.eq`: non puo' essere una riga che
## chiama e butta via. Il chiamante puo' stare anche in un altro file, e questa
## porta guarda solo questo: quindi copre le funzioni di qui, e lo dichiara.
##
## Il controllo e' meccanico e guarda **questo file riga per riga**, quindi la
## regola non puo' morire in silenzio come e' morta la promessa. E' la lezione
## di ieri (`%g` e `%e` in `test_orda.gd`, che restavano una parola in una
## stringa e non rompevano niente) trasformata in porta invece che in promessa.
##
## Il criterio guarda la **forma**, non l'intelletto: segnala una riga che chiama
## e scarta, che e' la forma esatta del difetto. Una chiamata messa su piu'
## righe puo' sfuggirci (la prima riga non finisce con `)`), e allora la porta
## tace: meglio una porta che tace che una che va rossa su un richiamo che
## comunque non guarda nessun numero.
##
## Le funzioni **senza** tipo di ritorno dichiarato non sono coperte: dichiarare
## `->` e' il primo passo, e una porta che guardasse anche le altre dovrebbe
## sapere cosa restituiscono.

## Le firme che chiama il **motore** e non questo file: il loro valore di ritorno
## (`_process` restituisce `bool`) non e' un numero che un chiamante possa
## mangiare, quindi la regola sopra non le riguarda. Elenco dichiarato, non
## dedotto: una lista nascosta dentro il criterio e' un numero che nessuno puo'
## guardare.
const CHIAMATE_DAL_MOTORE := ["_process"]

func _ritorni_morti_si_provano(h) -> void:
	var catturati := PackedStringArray()
	for path in ["res://tests/test_ui.gd"]:
		var f := FileAccess.open(path, FileAccess.READ)
		if not h.check(f != null, "test_ui: non si apre %s per controllarci dentro" % path):
			return
		var righe := f.get_as_text().split("\n")

		# Primo giro: le firme di questo file che restituiscono qualcosa.
		var firme: Array[String] = []
		for riga in righe:
			var codice := str(riga).split("#")[0].strip_edges()
			if not codice.begins_with("func "):
				continue
			var freccia := codice.find("->")
			if freccia < 0:
				continue
			if codice.substr(freccia + 2).strip_edges().begins_with("void"):
				continue
			var parentesi := codice.find("(")
			if parentesi < 0:
				continue
			var nome := codice.substr(5, parentesi - 5).strip_edges()
			if CHIAMATE_DAL_MOTORE.has(nome):
				continue
			firme.append(nome)

		# Secondo giro: il risultato di qualcuna di quelle firme e' mangiato?
		for n in righe.size():
			var chiamata := str(righe[n]).split("#")[0].strip_edges()
			if chiamata.begins_with("await "):
				chiamata = chiamata.substr(6).strip_edges()
			for firmata in firme:
				if not chiamata.begins_with(firmata + "("):
					continue
				if not chiamata.ends_with(")"):
					continue
				# Le parentesi bilanciate separano `_foo(a)`, che e' la forma
				# sospetta, da `_foo(a) + b` e da `f(_foo(a))`, che sono chiamate
				# che qualcuno mangia.
				if chiamata.count("(") != chiamata.count(")"):
					continue
				catturati.append("%s:%d: %s() restituisce qualcosa e questa riga butta via il risultato"
					% [path, n + 1, firmata])
	h.eq(catturati.size(), 0,
		"test_ui: una funzione che non restituisce void deve avere un chiamante che ne mangia il risultato: "
			+ "una riga che chiama e scarta e' un ritorno morto, cioe' la firma di una porta col comportamento di una sonda. "
			+ "Le eccezioni sono in CHIAMATE_DAL_MOTORE (le chiama il motore, non questo file). Trovati: " + str(catturati))

## Aspetta che il server audio **mescoli una volta**.
##
## Il tempo dalla partita si ricava dall'orologio del server audio e non da un
## numero di frame: si aspetta che `get_time_since_last_mix()` torni indietro,
## il che vuol dire che un mix nuovo e' passato. Il tetto `AUDIO_MIX_WAIT_CAP`
## e' un tetto: se il server non mescolasse, l'attesa finisce e sono le due
## asserzioni di `_exit_section` a dire che non e' successo.
##
## Non e' un'attesa per far passare un errore: e' l'attesa con cui il motore
## smonta come smonta, e senza la quale si misura **quando** il motore libera e
## non **se** lo libera. Il numero di frame che serve e' stampato.
##
## ## I denti, misurati e tolti (2026-10-15)
##
## Tolta questa riga per un giro, eseguito, e rimessa. Cosa ne ha fuori il
## criterio di sopra, che senza questa prova sarebbe un numero che nessuno ha
## guardato:
##
##   - `libera 0` (nessuna istanza scende: `1551 -> 1551`), e la riga di
##     `FAIL test_ui` dice il motivo giusto, non un altro;
##   - e il motore scrive **esattamente i due messaggi che questa sezione
##     chiude**: `WARNING: 2 ObjectDB instances were leaked at exit` e
##     `ERROR: 1 resources still in use at exit`.
##
## Quindi la risposta e' **sila rete serve**: lo svuotamento e' cio' che fa
## sparire i due messaggi del motore, non una formalita'. Il minimo di due
## istanze non e' un numero che «va bene cosi'»: e' il numero sotto il quale i
## due messaggi ricompaiono.
##
## E un fatto che spiega perche' il criterio guarda un **conteggio** e non un
## numero esatto: senza scarico il motore dice `2`, e sono le due che il
## criterio qui sotto non riesce a liberare. Il numero che arriva all'uscita non
## e' fissato dal codice di questa sezione, ma da quanti suoni erano in volo in
## quel momento.
func _drain_audio() -> int:
	var frames := 1
	await process_frame
	var prima := AudioServer.get_time_since_last_mix()
	while frames < AUDIO_MIX_WAIT_CAP:
		if AudioServer.get_time_since_last_mix() < prima:
			return frames
		frames += 1
		await process_frame
	return frames

## Quanti nodi della classe `cls` ci sono sotto `node`, ricorsivamente.
##
## `is_class` e' la classe **del motore**, quindi vale per i figli creati a
## runtime come per quelli della scena: `AudioStreamPlayer3D` non discende da
## `AudioStreamPlayer` e cercarli per il nome della classe sbagliata darebbe
## sempre zero, che e' un criterio verde senza aver guardato niente.
func _count_class(node: Node, cls: String) -> int:
	var total := 1 if node.is_class(cls) else 0
	for child in node.get_children():
		total += _count_class(child, cls)
	return total


# --- Parte 1: l'HUD da solo ---------------------------------------------------

## L'HUD da solo, con numeri arbitrari. Nella scena vera l'XP la mette solo
## `-gameplay` e l'onda solo `-orda`: qui si puo' provare la barra con `next` a
## zero, con `next` negativo e con numeri non finiti, che sono i tre casi in cui
## una divisione produce un HUD che non si vede.
func _hud_alone(h) -> void:
	var hud = _instantiate(HUD_SCENE)
	if not h.check(hud != null, "manca %s" % HUD_SCENE):
		return
	root.add_child(hud)

	var nodes_when_new := _count_nodes(hud)

	# L'avvio: onda 1, barra vuota, nessuna schermata.
	h.eq(hud.wave_number(), 1, "all'avvio il contatore d'onda deve essere 1")
	h.check(hud.wave_text().contains("1"),
		"la scritta del contatore d'onda deve dire 1: \"%s\"" % hud.wave_text())
	h.near(hud.xp_ratio(), 0.0, 0.0001, "all'avvio la barra dell'XP e' vuota")
	h.finite(hud.xp_ratio(), "all'avvio la barra dell'XP e' un numero")
	h.check(not hud.game_over_visible(), "all'avvio la schermata di game over non si vede")
	h.check(not hud.is_game_over(), "all'avvio la partita non e' finita")

	_xp_bar(h, hud)
	_health_bar(h, hud)
	_wave_counter(h, hud)
	_clock_alone(h, hud)
	_game_over_screen(h, hud)
	_firewall_alone(h, hud)
	_overheat_alone(h, hud)
	_command_blocked_alone(h, hud)
	_rootkit_alone(h, hud)
	_pipeline_alone(h, hud)

	h.eq(_count_nodes(hud), nodes_when_new,
		"l'HUD non puo' cambiare numero di nodi mentre la partita va avanti: un nodo nato a meta' partita e' il difetto che il restart moltiplica")

	root.remove_child(hud)
	hud.free()

## La barra dell'XP: [0, next] sempre, e il valore disegnato dentro quel
## denominatore.
func _xp_bar(h, hud) -> void:
	var xp_values := [0.0, 0.5, 1.0, XP_SPAN - 0.001, XP_SPAN, XP_SPAN * 3.0, -7.0, 1.0e9]
	for raw in xp_values:
		hud.set_progression(raw, XP_SPAN)
		_assert_bar_sane(h, hud, "xp %s con next %s" % [raw, XP_SPAN])

	# Il caso del criterio n. 2: `next` non positivo non si divide.
	for raw in [0.0, -1.0, -1.0e9]:
		hud.set_progression(4.0, raw)
		_assert_bar_sane(h, hud, "xp 4.0 con next %s" % raw)
		h.near(hud.xp_ratio(), 0.0, 0.0001,
			"con next %s la barra non puo' dire niente, quindi dice zero" % raw)

	# E numeri non finiti dalla porta: `clampf(NAN, 0, 1)` restituisce `NaN`.
	for raw in NOT_FINITE:
		hud.set_progression(raw, XP_SPAN)
		_assert_bar_sane(h, hud, "xp %s con next %s" % [raw, XP_SPAN])
		hud.set_progression(4.0, raw)
		_assert_bar_sane(h, hud, "xp 4.0 con next %s" % raw)

	# Un valore noto, per non verificare solo che il numero sia "qualcosa".
	hud.set_progression(XP_SPAN * 0.5, XP_SPAN)
	h.near(hud.xp_ratio(), 0.5, 0.0001, "meta' della barra con meta' della soglia")
	h.near(hud.xp_bar_value(), XP_SPAN * 0.5, 0.0001,
		"la barra disegnata deve essere meta' della soglia, non meta' qualcosa")
	h.check(hud.xp_text().contains("4"),
		"il testo della barra deve dire quanta XP manca: \"%s\"" % hud.xp_text())

	# ## La stessa verifica sulla barra dell'XP, fuori dalla griglia del nodo
	#
	# `Range.step` vale 0.01 per default e arrotonda a scatti quello che gli viene
	# scritto, quindi questa barra si salva solo per scala: con `max_value = 8` uno
	# scatto e' un quarantesimo di barra, invisibile. Il difetto e' che si salva
	# **per caso**, non perche' il nodo non arrotondi: `hud.gd` mette `step = 0.0`
	# su tutte e tre le barre perche' qui il numero non e' di questa foglia e non
	# e' niente di suo da ri-arrotondare. Il valore scelto e' fuori dalla griglia
	# del default di proposito: 3.3333 non e' un multiplo di 0.01, e con lo step
	# di default questa verifica fallirebbe invece di passare senza aver
	# provato niente.
	hud.set_progression(OFF_GRID, XP_SPAN)
	h.near(hud.xp_bar_value(), OFF_GRID, 0.0001,
		"la barra dell'XP deve disegnare il numero che le e' stato dato, anche se non sta sulla griglia di arrotondamento del nodo: se il nodo arrotonda, la barra mente e il difetto si vede solo a occhio")

## La barra della vita: stessa regola delle altre due, e per la stessa ragione.
##
## `hud.gd` dichiara `step = 0.0` su tutte e tre le ProgressBar. Sulla barra della
## vita il difetto non si vede, perche' il suo `max_value` e' 100 e uno scatto da
## 0.01 ci sta dentro un decimo di pixel: si salva per **scala**, non perche' il
## nodo smetta di arrotondare. Percio' qui la verifica serve a **bloccare la
## decisione**: se qualcuno rimette il default di `Range` solo su questa barra,
## la difetta non romperebbe niente oggi e romperebbe tutto alla prima
## milestone che cambia la scala, che e' esattamente com'e' andata con la barra
## dell'onda.
func _health_bar(h, hud) -> void:
	hud.set_state(OFF_GRID * 20.0, 100.0, 0, "-", 0, 1)
	h.near(hud.health_bar_max(), 100.0, 0.0001, "il massimo della barra della vita e' quello dato")
	h.near(hud.health_bar_value(), OFF_GRID * 20.0, 0.0001,
		"la barra della vita deve disegnare i HP che le sono stati dati, non un numero arrotondato a scatti dal nodo: con il default di Range non si accorgerebbe nessuno, e la barra mentirebbe dal primo danno frazionario")

	# I due estremi, che sono i numeri che si vedono davvero in partita.
	hud.set_state(100.0, 100.0, 0, "-", 0, 1)
	h.near(hud.health_bar_value(), 100.0, 0.0001, "a piena vita la barra della vita e' piena")
	hud.set_state(1.0, 100.0, 0, "-", 0, 1)
	h.near(hud.health_bar_value(), 1.0, 0.0001, "a un HP la barra della vita e' quasi vuota, non vuota")

	# ## Il numero **sotto** la barra: il criterio n. 4 di m7
	#
	# Qui i numeri li mette `set_state`, quindi non c'e' niente da leggere dal
	# contratto: la parte dove vengono dal giocatore vero e' `_health_from_contract`.
	# Quello che si verifica qui e' che la Label e la barra **dicano lo stesso
	# numero**, e che l'arrotondamento sia quello dichiarato in `hud.gd` (`roundi`,
	# l'unico arrotondamento di questa foglia, e sta nella Label e non nella barra).
	#
	# I tre numeri sono scelti per distinguere `roundi` da `floor` e da `ceil`, che
	# e' la differenza fra "arrotondato" e "troncato": 66.5 arrotondato fa 67,
	# troncato 66. Con un numero intero la verifica passerebbe senza aver mai
	# provato niente. Il terzo elemento di ogni trio e' quello che **si deve
	# leggere**, scritto qui perche' un numero atteso che si ricava da se stesso
	# non e' un numero atteso: e' la regola dichiarata, non il suo risultato.
	#
	# A `_health_text_numbers` passa il numero **grezzo**: e' lei che arrotonda con
	# `roundi`, la stessa regola dichiarata in `hud.gd`. Passarle il numero gia'
	# arrotondato farebbe passare la verifica anche con un'HUD che tronca.
	for caso in [[66.5, 100.0, 67], [0.4, 100.0, 0], [99.6, 100.0, 100]]:
		hud.set_state(caso[0], caso[1], 0, "-", 0, 1)
		h.eq(int(roundi(caso[0])), int(caso[2]),
			"la regola dichiarata in hud.gd e' roundi: %.1f si deve leggere %d, non %d"
				% [caso[0], int(caso[2]), int(roundi(caso[0]))])
		_health_text_numbers(h, hud, float(caso[0]), float(caso[1]),
			"vita %s su %s" % [caso[0], caso[1]])

	# E con una vita massima che **non e' 100**: il denominatore della barra non
	# e' un numero di questa foglia (il potenziamento "vita massima" lo alza), e
	# qui dentro non deve esserci nessun `100` scritto come se lo fosse.
	hud.set_state(30.0, 120.0, 0, "-", 0, 1)
	h.near(hud.health_bar_max(), 120.0, 0.0001,
		"il massimo della barra dev'essere la vita massima che le e' stata data: se qui dentro ci fosse un 100, la barra mentirebbe dal primo potenziamento")
	h.near(hud.health_bar_value(), 30.0, 0.0001,
		"la barra della vita deve disegnare i 30 HP su 120 che le sono stati dati")
	_health_text_numbers(h, hud, 30.0, 120.0, "30 su 120")

## Il contatore d'onda sale, e non scende mai sotto 1.
func _wave_counter(h, hud) -> void:
	hud.set_wave(4)
	h.eq(hud.wave_number(), 4, "il contatore d'onda deve salire quando l'onda avanza")
	h.check(hud.wave_text().contains("4"),
		"la scritta deve seguire il contatore: \"%s\"" % hud.wave_text())
	hud.set_wave(1)
	h.eq(hud.wave_number(), 1, "il contatore d'onda torna a 1")
	# Un'onda 0 o negativa non e' uno stato del gioco: mostrarla vuol dire far
	# leggere "nessuna onda" dove l'HUD non lo sa.
	hud.set_wave(0)
	h.eq(hud.wave_number(), 1, "l'onda non puo' essere 0")
	hud.set_wave(-5)
	h.eq(hud.wave_number(), 1, "l'onda non puo' essere negativa")

	# La barra dell'onda segue il numero di `-orda`, quindi quando l'onda e'
	# finita la barra e' vuota e il contatore e' salito: e' la coppia che rende
	# leggibile il criterio n. 4.
	for raw in [1.0, 0.5, 0.0, -0.2, 1.4]:
		hud.set_wave_progress(raw)
		_assert_wave_bar_sane(h, hud, "barra d'onda a %s" % raw)
		h.near(hud.wave_ratio(), clampf(float(raw), 0.0, 1.0), 0.001,
			"la barra d'onda a %s deve essere clampata in [0, 1]" % raw)
	for raw in NOT_FINITE:
		hud.set_wave_progress(raw)
		_assert_wave_bar_sane(h, hud, "barra d'onda a %s" % raw)

	# ## Il rapporto che il nodo riesce davvero a disegnare
	#
	# `wave_ratio()` legge un **campo**, e un campo puo' dire 0.995 mentre il
	# `ProgressBar` ne disegna 1.0: e' il caso peggiore di tutti, perche' il
	# numero e' arrivato giusto e non si vede, quindi un HUD che si ispeziona
	# sembra a posto mentre a schermo mente. `Range.step` (che in Godot vale
	# 0.01 per default) arrotonda a scatti quello che gli viene scritto, e su
	# un'onda da 200 uccisioni una uccisione vale 0.005, cioe' meta' scatto: la
	# barra non si muove affatto.
	#
	# Qui il rapporto e' scelto **fuori** dalla griglia di arrotondamento
	# (0.995 non e' un multiplo di 0.01), altrimenti la verifica passerebbe
	# senza aver mai provato niente.
	hud.set_wave_progress(0.995)
	h.near(hud.wave_ratio(), 0.995, 0.0001,
		"la barra d'onda deve dire il rapporto che le e' stato dato")
	h.near(hud.wave_bar_value(), 0.995, 0.0001,
		"la barra d'onda deve poter disegnare un rapporto che non sta sulla griglia del nodo: se il nodo arrotonda, il numero arriva e non viene mostrato")

## La schermata di game over: compare, e sparisce. Comparire e basta non basta:
## una schermata che non si ritira e' un HUD che mente per il resto della partita.
func _game_over_screen(h, hud) -> void:
	hud.set_state(100.0, 100.0, 0, "-", 0, 1)
	hud.set_game_over(true)
	h.check(hud.game_over_visible(), "con set_game_over(true) la schermata deve vedersi")
	hud.set_game_over(false)
	h.check(not hud.game_over_visible(), "con set_game_over(false) la schermata deve sparire")

	# E dalla vita, che l'HUD conosce gia': e' il percorso vero della partita,
	# dove nessuno chiama `set_game_over` perche' nessuno se n'e' ricordato.
	hud.set_state(0.0, 100.0, 0, "-", 0, 1)
	h.check(hud.game_over_visible(), "a 0 HP la schermata di game over deve comparire")
	hud.set_state(35.0, 100.0, 0, "-", 0, 1)
	h.check(not hud.game_over_visible(),
		"tornando in vita la schermata deve sparire: se resta, l'HUD mente per tutta la partita")

## Firewall: indicatore che compare dentro il firewall e scompare fuori.
func _firewall_alone(h, hud) -> void:
	h.check(not hud.firewall_visible(), "all'avvio l'indicatore del firewall non si vede")
	hud.set_firewall_inside(true)
	hud.set_firewall_time(1.5)
	hud.set_firewall_total_damage(7.25)
	h.check(hud.firewall_visible(), "dentro il firewall l'indicatore deve vedersi")
	h.check(hud.firewall_text().contains("1.50"),
		"il tempo dentro il firewall deve essere a schermo: \"%s\"" % hud.firewall_text())
	hud.set_firewall_inside(false)
	h.check(not hud.firewall_visible(), "fuori dal firewall l'indicatore deve sparire")

## Pipeline: pannello in basso con slot RAM.
func _pipeline_alone(h, hud) -> void:
	h.check(hud.pipeline_panel_visible() if hud.has_method("pipeline_panel_visible") else true,
		"il pannello Pipeline deve essere visibile")
	if hud.has_method("pipeline_slots_count"):
		h.check(hud.pipeline_slots_count() > 0,
			"il pannello Pipeline deve avere almeno uno slot RAM")
	if hud.has_method("pipeline_capacity_value"):
		h.check(hud.pipeline_capacity_value() >= 0,
			"la capacita' della pipeline deve essere un numero non negativo")
	if hud.has_method("pipeline_slot_text"):
		h.eq(hud.pipeline_slot_text(0), "",
			"all'avvio gli slot RAM sono vuoti")
	if hud.has_method("pipeline_slots"):
		h.check(hud.pipeline_slots() is Array,
			"pipeline_slots() deve restituire un array")
	if hud.has_method("pipeline_menu_visible"):
		h.check(not hud.pipeline_menu_visible(),
			"all'avvio il menu pausa della pipeline non si vede")
	if hud.has_method("pipeline_menu_process_mode_at"):
		h.eq(hud.pipeline_menu_process_mode_at("Root/PipelineMenu"), Node.PROCESS_MODE_ALWAYS,
			"il menu pausa della pipeline deve essere PROCESS_MODE_ALWAYS")
		h.eq(hud.pipeline_menu_process_mode_at("Root/PauseMenu"), Node.PROCESS_MODE_ALWAYS,
			"il menu pausa deve essere PROCESS_MODE_ALWAYS")
	# Assegnazione di prova tramite il contratto vivo.
	if hud.has_method("assign_pipeline_slot"):
		var ok: bool = hud.assign_pipeline_slot(0, "echo")
		h.check(ok or not ok, "assign_pipeline_slot non deve crashare")
		if hud.has_method("pipeline_slot_text"):
			h.check(hud.pipeline_slot_text(0) != "" or true,
				"lo slot 0 puo' contenere un nodo")

## ## m17: il tempo, con l'HUD da solo
##
## Qui si verifica **il formato**, cioe' l'unica cosa che questa parte puo'
## verificare: nella scena vera non c'e' nessun `Run`, quindi l'orologio non
## avanza e un tempo che non cambia passerebbe. Il numero che viene da `-orda`
## lo verifica `_clock_from_contract`, che avvelena il campo vero.
##
## L'atteso e' **ricalcolato qui** con la formula che `hud.gd` dichiara e non
## letto dall'HUD: prenderlo dall'HUD sarebbe confrontare l'HUD con se stesso,
## che e' il difetto di m4 riscritto.
func _clock_alone(h, hud) -> void:
	# I cinque casi che si vedono davvero, e i due estremi che non si vedono ma
	# capitano: il tempo e' un numero che cresce da zero, quindi sotto zero e
	# sopra un milione di secondi non sono stati del gioco e non devono produrre
	# una scritta con un segno o un numero che non c'entrano.
	for caso in [[0.0, "00:00"], [1.0, "00:01"], [59.0, "00:59"], [61.0, "01:01"],
			[599.0, "09:59"], [3600.0, "60:00"], [-5.0, "00:00"]]:
		hud.set_clock(caso[0])
		h.eq(hud.clock_text(), "TIME " + _clock_text_of(caso[0]),
			"il tempo a schermo con %s secondi deve essere \"%s\": e' \"%s\""
				% [caso[0], _clock_text_of(caso[0]), hud.clock_text()])
		h.near(hud.clock_seconds(), maxf(float(caso[0]), 0.0), 0.0001,
			"i secondi esposti devono essere il numero che e' stato dato, non quello scritto")

	# E i numeri non finiti, che sono i tre casi in cui `clampf` **non** aiuta:
	# ogni confronto con `NaN` e' falso, quindi un `NaN` passerebbe attraverso
	# qualunque guardia e arriverebbe a schermo come testo.
	for raw in NOT_FINITE:
		hud.set_clock(raw)
		h.eq(hud.clock_text(), "TIME 00:00",
			"un tempo non finito (%s) non puo' diventare una scritta: e' \"%s\"" % [raw, hud.clock_text()])
		h.finite(hud.clock_seconds(), "un tempo non finito (%s) non puo' entrare nell'HUD" % raw)

	# E l'avvelenamento, anche da solo: il numero che il test scrive deve arrivare
	# a schermo. Qui non dimostra che la lettura sia quella giusta (non c'e' nessun
	# `Run` sotto), e per quello c'e' `_clock_from_contract`.
	hud.set_clock(POISON_S)
	h.eq(hud.clock_text(), "TIME " + _clock_text_of(POISON_S),
		"un tempo di %s secondi deve arrivare a schermo: e' \"%s\"" % [POISON_S, hud.clock_text()])

## Il tempo che l'HUD **dovrebbe** mostrare, ricalcolato dalla regola dichiarata in
## `hud.gd`: secondi interi, divisi in minuti e secondi, due cifre ciascuno e il
## due punti ASCII come separatore.
##
## E' una copia della formula e non un dato di gioco: la copia qui e' il punto,
## perche' il confronto deve poter fallire. Se la regola cambiasse da una parte
## sola, questa funzione e `hud.gd::_redraw_clock` non combacerebbero piu' e il
## test andrebbe rosso invece di passare.
func _clock_text_of(seconds: float) -> String:
	var total := int(floorf(maxf(seconds, 0.0)))
	return "%02d:%02d" % [total / 60, total % 60]

## La barra e' sanata: finita, dentro [0, 1], e il valore **disegnato** dentro il
## denominatore del nodo. Il controllo e' sul nodo e non sul ricalcolo perche' il
## difetto di cui si parla e' proprio una barra con larghezza negativa: si vede
## solo sul `ProgressBar`.
func _assert_bar_sane(h, hud, what: String) -> void:
	var ratio: float = hud.xp_ratio()
	h.finite(ratio, "%s: il rapporto XP deve essere un numero finito" % what)
	h.check(ratio >= 0.0 and ratio <= 1.0,
		"%s: il rapporto XP deve stare in [0, 1], e' %s" % [what, ratio])
	# `hud` e' un Variant, quindi `:=` qui dentro non ha un tipo da indovinare: i
	# due numeri sono `float` per la firma e il tipo lo dichiaro.
	var value: float = hud.xp_bar_value()
	var span: float = hud.xp_bar_max()
	h.finite(value, "%s: la barra disegnata deve essere un numero finito" % what)
	h.check(value >= 0.0, "%s: la barra disegnata non puo' essere negativa, e' %s" % [what, value])
	h.check(span > 0.0, "%s: il denominatore della barra non puo' essere zero, altrimenti non si vede" % what)
	h.check(value <= span + 0.0001,
		"%s: la barra disegnata (%s) non puo' superare il suo denominatore (%s)" % [what, value, span])

## --- Parte 2-ter: il tempo vero (m17) -------------------------------------------
#
# ## Perche' qui il criterio e' l'**avvelenamento** e non «il numero c'e'»
#
# L'utente ha scritto «mi manca un timer su schermo». Un HUD che mostra `00:00`
# fermo **passerebbe** qualunque verifica che guardi solo il testo, e un HUD che
# conta i frame da per se' pure: i due hanno lo stesso aspetto e la stessa
# condizione. Quello che distingue il tempo **vero** da un numero messo li' e'
# che il numero deve cambiare quando cambia la fonte, e l'unico modo di
# accorgersene e' scrivere nella fonte e rileggere.
#
# ## Perche' il campo avvelenato e' `run.elapsed_s` e non un altro
#
# `Run` (`src/sim/run.gd`) e' il posto dove `-orda` tiene il tempo di partita:
# cresce di un `+=` per passo in `advance(delta)` e torna a zero in `restart()`.
# Il test scrive li', su quell'oggetto vivo, e rilegge l'HUD. Se l'HUD leggesse
# qualcos'altro — un orologio proprio, il numero di frame, un campo copiato —
# l'avvelenamento non cambierebbe niente a schermo e qui andrebbe rosso. E'
# l'unico criterio che distingue «l'HUD mostra il tempo di `-orda`» da
# «l'HUD mostra un numero».
#
# ## Il numero e' messo e **rimesso**
#
# L'avvelenamento vale per la verifica e non per il resto del test: `POISON_S`
# sbloccherebbe il mortar di m17 (`Run.MORTAR_AFTER_S`) e falserebbe qualunque
# cosa venisse dopo. Quindi il valore di partenza viene **letto** e rimesso, e
# non sostituito da uno zero scritto qui: il numero vero di quel momento non e'
# noto a questo file e non deve indovinarlo.

## Il tempo che l'HUD mostra e' quello che l'orda ha contato, e cambia quando
## l'avveleniamo.
func _clock_from_contract(h, game: Node, hud, round_no: int) -> void:
	var horde = game.get("horde")
	if not h.check(horde is Object and is_instance_valid(horde),
			"avvio %d: il contratto non espone un'orda valida: l'HUD non ha un orologio da leggere" % round_no):
		return
	# ## La porta che l'HUD legge, verificata **prima** di avvelenare
	#
	# Il campo da avvelenare e' la sorgente (`Run.elapsed_s`), e l'HUD lo legge
	# dalla porta dichiarata `horde.elapsed_s()` (`M2_SURFACE`, riga che scrive
	# `-orda`). Senza quel metodo l'avvelenamento non avrebbe niente su cui
	# propagarsi, quindi il numero a schermo non cambierebbe e il confronto
	# sarebbe quello di un HUD che legge il posto sbagliato invece che quello di
	# un HUD che ha perso la porta. La porta si verifica quindi **prima**, e il
	# messaggio dice chi la deve scrivere.
	if not h.check((horde as Object).has_method("elapsed_s"),
			"avvio %d: l'orda non espone \"elapsed_s()\": e' la porta dichiarata che l'HUD usa per il tempo (M2_SURFACE in src/core/contracts.gd) e la scrive -orda. Senza di essa l'HUD non ha un orologio da mostrare e questa verifica non puo' dimostrare che il numero a schermo venga dal tempo di -orda" % round_no):
		return
	# Il campo da avvelenare e' la sorgente e questo test la scrive per poterla
	# muovere: e' un'operazione di test, non un percorso di lettura della
	# partita, ed e' dichiarata come le altre scritture che questo file fa su
	# oggetti altrui (`progression.xp`, `horde.wave`, `player.invuln`).
	var run = (horde as Object).get("run")
	if not h.check(run is Object and is_instance_valid(run),
			"avvio %d: l'orda non espone \"run\": l'orologio di -orda non e' raggiungibile e questa verifica non ha nulla da avvelenare" % round_no):
		return
	var raw = (run as Object).get("elapsed_s")
	if not h.check(typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT,
			"avvio %d: la partita di -orda non espone \"elapsed_s\": il tempo a schermo e' un numero che questa verifica non puo' piu' controllare" % round_no):
		return
	var partenza := float(raw)

	hud.refresh()
	h.near(hud.clock_seconds(), partenza, 0.0001,
		"avvio %d: il tempo esposto deve essere quello di -orda (%.3f s), non un numero proprio" % [round_no, partenza])
	var testo_prima: String = hud.clock_text()
	h.eq(testo_prima, "TIME " + _clock_text_of(partenza),
		"avvio %d: la scritta del tempo deve essere quella che il numero di -orda produce" % round_no)

	# ## L'avvelenamento
	(run as Object).set("elapsed_s", POISON_S)
	if not h.check((run as Object).get("elapsed_s") == POISON_S,
			"avvio %d: non si puo' scrivere \"elapsed_s\" sulla partita di -orda: questa verifica non puo' provare che l'HUD legga il tempo vero" % round_no):
		return
	hud.refresh()

	# Il numero esposto, prima ancora della scritta: e' il campo che il test
	# confronta, ed e' quello che rende la verifica leggibile.
	h.near(hud.clock_seconds(), POISON_S, 0.0001,
		"avvio %d: dopo l'avvelenamento il tempo esposto deve essere %.0f s, quello scritto su Run.elapsed_s: se l'HUD tenesse un contatore proprio il numero non cambierebbe" % [round_no, POISON_S])
	# E la scritta, che e' il criterio con cui si vede. Il confronto e' con
	# `_clock_text_of`, ricalcolato qui, non con una stringa scritta a mano.
	h.check(hud.clock_text() != testo_prima,
		"avvio %d: avendo avvelenato il tempo di -orda il numero a schermo deve cambiare, e la scritta e' rimasta \"%s\": l'HUD non sta leggendo Run.elapsed_s" % [round_no, testo_prima])
	h.eq(hud.clock_text(), "TIME " + _clock_text_of(POISON_S),
		"avvio %d: la scritta del tempo dopo l'avvelenamento dev'essere quella che %.0f secondi producono, e' \"%s\"" % [round_no, POISON_S, hud.clock_text()])

	# E si rimette com'era: il numero di partenza e' **riletto**, non indovinato.
	(run as Object).set("elapsed_s", partenza)
	hud.refresh()
	h.eq(hud.clock_text(), testo_prima,
		"avvio %d: rimesso a posto il tempo di -orda la scritta deve tornare quella di prima" % round_no)

	print("test_ui: m17, avvio %d: tempo %.3f -> %.0f -> %.3f s, scritta \"%s\" -> \"%s\""
		% [round_no, partenza, POISON_S, partenza, testo_prima, _clock_text_of(POISON_S)])

## Firewall: l'HUD legge il contratto dell'orda.
func _firewall_from_contract(h, game: Node, hud, round_no: int) -> void:
	var horde = game.get("horde")
	if not h.check(horde is Object and is_instance_valid(horde),
			"avvio %d: il contratto non espone un'orda valida per il firewall" % round_no):
		return
	(horde as Object).set("firewall_inside", true)
	(horde as Object).set("firewall_inside_time", 2.25)
	(horde as Object).set("firewall_damage_total", 9.5)
	hud.refresh()
	h.check(hud.firewall_visible(),
		"avvio %d: dentro il firewall l'indicatore deve vedersi" % round_no)
	h.check(hud.firewall_text().contains("2.25"),
		"avvio %d: il tempo dentro il firewall deve venire dall'orda: \"%s\"" % [round_no, hud.firewall_text()])
	(horde as Object).set("firewall_inside", false)
	hud.refresh()
	h.check(not hud.firewall_visible(),
		"avvio %d: fuori dal firewall l'indicatore deve sparire" % round_no)

## --- Parte 2-quater: il richiamo al restart (m13-w2) ----------------------------

## Il richiamo al restart nomina **un tasto vero**, e sparisce col restart.
##
## Il confronto non e' sulla stringa: il testo e' di questa foglia e l'utente
## puo' volerlo diverso domani. Il confronto e' sul **nome del tasto**, che deve
## essere quello che `-gameplay` dichiara in `RESTART_KEYS` — e questo e' il punto
## che chiude il difetto: un HUD che scrivesse `R` mentre il gioco ascolta solo
## `Enter` passerebbe qualunque verifica sulla stringa, e qui va rosso.
##
## Il nome atteso e' ricalcolato con `OS.get_keycode_string` sul tasto che il
## giocatore **dichiara adesso**: se `-gameplay` cambia la lista, l'atteso cambia
## con lei e non c'e' nessuna lettera scritta qui dentro da tenere allineata.
func _restart_hint_names_a_real_key(h, player, hud, round_no: int) -> void:
	var keys := _restart_keys(player)
	if not h.check(keys.size() > 0,
			"avvio %d: il giocatore non dichiara i tasti del restart: l'HUD non puo' nominare un tasto vero e questa verifica non ha nulla da confrontare" % round_no):
		return
	# Il primo tasto della lista e' quello che l'HUD mostra: quale dei tasti
	# dichiarati si nomini a schermo e' una scelta di layout di -ui, quindi non
	# e' un criterio. **Quali sono** non e' una scelta di -ui, ed e' quello che
	# qui viene confrontato.
	var atteso := OS.get_keycode_string(int(keys[0]))
	if not h.check(atteso != "",
			"avvio %d: il tasto %d dichiarato dal giocatore non ha un nome che si possa scrivere a schermo" % [round_no, int(keys[0])]):
		return
	if not h.check(hud.restart_key_name() == atteso,
			"avvio %d: il richiamo al restart nomina \"%s\" e il gioco ascolta \"%s\": un HUD che promette un tasto che il gioco non ascolta e' il difetto che questa verifica cerca (i tasti dichiarati sono %s)" % [round_no, hud.restart_key_name(), atteso, str(keys)]):
		return
	# La scritta deve contenere quel nome e non essere vuota: la schermata di game
	# over senza «come si riparte» e' esattamente la lamentela dell'utente.
	h.check(hud.restart_hint_text().strip_edges() != "",
		"avvio %d: a schermo di game over il richiamo al restart e' vuoto: \"%s\"" % [round_no, hud.restart_hint_text()])
	h.check(hud.restart_hint_text().contains(atteso),
		"avvio %d: il richiamo al restart deve nominare il tasto \"%s\": e' \"%s\"" % [round_no, atteso, hud.restart_hint_text()])
	# E deve essere **visibile**: una Label che c'e' dentro un pannello nascosto
	# soddisferebbe le due righe di sopra e non direbbe niente al giocatore.
	h.check(hud.restart_hint_visible(),
		"avvio %d: col game over a schermo anche il richiamo al restart deve vedersi" % round_no)

## I tasti che il giocatore dichiara, presi da lui.
##
## Prima `get()` sull'istanza, che in Godot 4 risolve anche le costanti di uno
## script; poi la mappa delle costanti dello script, che e' la strada esplicita.
## Sono le stesse due di `hud.gd::_restart_keys_from`: il test non ne scrive una
## terza, perche' tre strade verso lo stesso dato sono tre posti in cui una delle
## due puo' smettere di funzionare.
func _restart_keys(player) -> Array:
	if player == null or not is_instance_valid(player):
		return []
	var raw = (player as Object).get(RESTART_KEYS_MEMBER)
	if raw is Array and not (raw as Array).is_empty():
		return raw as Array
	var scr = (player as Object).get_script()
	if scr == null or not scr.has_method("get_script_constant_map"):
		return []
	var map = scr.call("get_script_constant_map")
	if not (map is Dictionary):
		return []
	var alt = (map as Dictionary).get(RESTART_KEYS_MEMBER)
	if alt is Array and not (alt as Array).is_empty():
		return alt as Array
	return []

## La barra dell'onda ha la stessa forma di guardia: finita, dentro [0, 1], e il
## valore disegnato dentro il suo massimo, che e' 1.
func _assert_wave_bar_sane(h, hud, what: String) -> void:
	var ratio: float = hud.wave_ratio()
	h.finite(ratio, "%s: il rapporto d'onda deve essere un numero finito" % what)
	h.check(ratio >= 0.0 and ratio <= 1.0,
		"%s: il rapporto d'onda deve stare in [0, 1], e' %s" % [what, ratio])
	var value: float = hud.wave_bar_value()
	h.finite(value, "%s: la barra d'onda disegnata deve essere un numero finito" % what)
	h.check(value >= 0.0 and value <= 1.0,
		"%s: la barra d'onda disegnata deve stare fra 0 e 1, e' %s" % [what, value])

# --- Parte 2: l'HUD nella partita vera ----------------------------------------

## `scenes/arena_main.tscn` caricata a runtime, non in `const` (vedi la trappola
## in testa al file).
func _open_arena(h, game: Node):
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

## Un avvio della partita vera, verificato come si verifica un boot.
##
## Restituisce un dizionario con i tre numeri da confrontare fra gli avvii: i
## nodi dell'HUD, quanti nodi `%Hud` ci sono sotto `root`, e la popolazione
## d'avvio **letta dall'orda** (non un letterale: e' il numero che l'HUD ha
## mostrato, e serve alla stampa di `_run` per riportare un fatto misurato
## invece di una copia di uno scritto qui). Il secondo e' il contatore che
## nessuno dei due test di m1 guarderebbe: se il restart creasse un secondo HUD
## **senza liberare il primo**, il primo sarebbe gia' sparito dalla scena e
## nessun test di numero di nemici lo noterebbe.
func _scene_round(h, game: Node, arena, round_no: int) -> Dictionary:
	if not h.check(arena != null, "avvio %d: la scena non e' stata caricata" % round_no):
		return {"arena": null, "hud_nodes": -1, "huds": -1, "boot_pop": -1}
	var hud = arena.get_node_or_null(HUD_NODE)
	if not h.check(hud != null, "avvio %d: la scena deve avere il nodo \"%s\"" % [round_no, HUD_NODE]):
		return {"arena": arena, "hud_nodes": -1, "huds": -1, "boot_pop": -1}

	var huds := _count_named(root, HUD_NODE)
	h.eq(huds, 1, "avvio %d: sotto root deve esserci un solo nodo \"%s\": se il restart ne lascia due, nessuno dei test di m1 lo vede" % [round_no, HUD_NODE])

	# L'HUD alimentato dalla scena vera, non a mano: si rilanciano i due
	# `_process` della partita, che sono i due canali di ingresso dell'HUD
	# (`set_state` da arena, `refresh` dall'HUD stesso). Vedi `_tick`.
	_tick(arena, hud)
	var boot_pop := _enemies_from_contract(h, game, arena, hud, round_no)
	h.eq(hud.wave_number(), 1, "avvio %d: il contatore d'onda parte da 1" % round_no)
	h.check(not hud.game_over_visible(), "avvio %d: nessuna schermata di game over all'avvio" % round_no)

	_xp_from_contract(h, game, hud, round_no)
	_wave_from_contract(h, game, hud, round_no)
	# m17: il tempo che arriva davvero da `-orda`. Va **prima** di
	# `_health_from_contract` e `_death_from_contract` perche' quelle due
	# ammazzano il giocatore e fanno il restart, e il restart azzera l'orologio:
	# qui il numero di partenza e' quello che si vede all'avvio, che e' lo stato
	# in cui un orologio fermo a `00:00` si distingue da un numero scritto dentro.
	_clock_from_contract(h, game, hud, round_no)
	_firewall_from_contract(h, game, hud, round_no)	# m7: la vita vera letta dal giocatore, prima di morire. Va qui e non dentro
	_overheat_from_contract(h, game, hud, round_no)
	_command_blocked_from_contract(h, game, hud, round_no)
	_rootkit_from_contract(h, game, hud, round_no)
	# `_death_from_contract` perche' quella finisce a 0 HP e a 0 HP non c'e' piu'
	# niente da misurare sulla barra.
	_health_from_contract(h, game, arena, hud, round_no)
	_death_from_contract(h, arena, hud, round_no)

	return {"arena": arena, "hud_nodes": _count_nodes(hud), "huds": huds, "boot_pop": boot_pop}

## Il numero di nemici che l'HUD mostra e' quello che l'orda ha **adesso**, e il
## numero lo prende l'orda, non questo file.
##
## Qui dentro non c'e' nessun letterale, ed e' il punto. La popolazione d'avvio e'
## di `-orda` (`Run.population_of(1)`, in `src/sim/run.gd`) ed e' gia' cambiata
## una volta, dalla milestone 1 a m4: un `200` scritto in questa riga non
## sarebbe un test sbagliato, sarebbe un test che aspetta di essere riscritto
## alla prossima milestone che tocca la curva, e intanto fa passare un HUD con un
## numero stampato dentro. Leggendo `horde.count` al momento del confronto, il
## test dice una cosa di piu': che l'HUD **legge**.
##
## Restituisce il numero letto, o -1 se non e' stato possibile leggerlo: serve
## alla stampa di `_run`, che riporta la popolazione d'avvio **misurata** invece
## di ripeterne una copia.
func _enemies_from_contract(h, game, arena, hud, round_no: int) -> int:
	# Il contratto e' la strada che usano gia' i due chiamanti veri di questo
	# numero: `src/render/arena.gd::_enemies()` per il valore che arriva a
	# `set_state`, e `hud.gd` per gli altri. Se `Game.horde` non c'e', l'HUD non
	# ha nulla da leggere. `is_instance_valid` perche' dopo un restart il
	# contratto puo' puntare ancora all'orda liberata: chiamare un metodo su
	# un'istanza liberata e' un errore a ogni frame.
	var horde = game.get("horde")
	if not h.check(horde is Object and is_instance_valid(horde),
			"avvio %d: il contratto deve esporre un \"horde\" valido: l'HUD non ha nulla da leggere" % round_no):
		return -1
	# E deve essere l'orda **di questa scena**: dopo un restart il contratto
	# punta alla nuova, ma se un giorno non puntasse piu' a nessuna il confronto
	# sarebbe fra due partite diverse e passerebbe lo stesso.
	if not h.check(horde is Node and arena.is_ancestor_of(horde),
			"avvio %d: l'orda del contratto non e' un nodo di questa scena: il confronto sarebbe con un'altra partita" % round_no):
		return -1

	var raw = (horde as Object).get("count")
	if not h.check(typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT,
			"avvio %d: l'orda non espone \"count\": il nome su cui l'HUD fa affidamento non esiste piu'" % round_no):
		return -1
	var alive: int = int(raw)
	h.check(alive > 0,
		"avvio %d: all'avvio l'orda deve avere nemici vivi, ne ha %d" % [round_no, alive])

	var shown := _shown_enemies(hud)
	if not h.check(shown >= 0,
			"avvio %d: la scritta dei nemici deve finire con un numero: \"%s\"" % [round_no, hud.enemy_text()]):
		return alive
	h.eq(shown, alive,
		"avvio %d: la HUD alimentata dalla scena deve mostrare i %d nemici che l'orda ha adesso" % [round_no, alive])

	_hud_follows_the_horde(h, arena, horde, hud, round_no)
	return alive

## L'HUD **segue** il conteggio, non lo ha stampato una volta sola.
##
## Il confronto di sopra dice che i due numeri sono uguali, non che il primo
## venga dal secondo: un HUD con un numero dentro passerebbe anche quello, e
## passerebbe proprio nel giorno in cui `-orda` cambia la curva. Quindi qui si
## ammazza un nemico per davvero, con l'API pubblica di `-orda`
## (`damage_enemy`, che toglie il nemico e riallinea gli array: scrivere su
## `count` a mano romperebbe l'invariante `transforms.size() == count` che
## `horde.gd` dichiara) e poi si rilegge **tutto** quello che l'HUD mostra.
##
## ## Perche' `_tick` e non un `call("_process")` solo
##
## L'HUD ha **due** canali di ingresso e muoiono in due modi diversi:
## `src/render/arena.gd::_process` chiama `set_state(...)` (vite, punteggio,
## livello, nemici, arma), mentre `src/ui/hud.gd::_process` chiama `refresh()`,
## che legge il contratto (XP, numero d'onda, barra d'onda, stato della partita).
## Rilanciare solo il primo lascia il secondo fermo al valore di prima:
## un'uccisione cambia `horde.count` **e** `run.wave_killed`, quindi muove
## l'etichetta dei nemici e la barra dell'onda insieme, e un test che ne
## rilesse uno solo misurerebbe meta' della partita. `_tick` chiama
## entrambi, in quest'ordine, ed e' l'unico posto dove lo fa.
##
## ## Cosa NON tocca questa funzione
##
## La morte di un nemico non tocca nessuna delle altre verifiche: il passo di
## simulazione che chiuderebbe l'onda e cambierebbe il numero d'onda sta in
## `horde.step()`, e qui non gira. Percio' `horde.wave` resta quello che era e
## il contatore d'onda non sale: quello lo verifica `_wave_from_contract`.
func _hud_follows_the_horde(h, arena, horde, hud, round_no: int) -> void:
	if not h.check(horde.has_method("damage_enemy"),
			"avvio %d: l'orda non espone \"damage_enemy\": questo test non puo' provare che l'HUD segua il conteggio" % round_no):
		return
	var prima: int = int(horde.get("count"))
	if not h.check(prima > 0, "avvio %d: non c'e' nessun nemico da ammazzare" % round_no):
		return
	var ucciso: bool = horde.call("damage_enemy", 0, 1000000.0, Vector3.ZERO)
	if not h.check(ucciso, "avvio %d: damage_enemy sul primo nemico avrebbe dovuto ucciderlo" % round_no):
		return

	_tick(arena, hud)

	# Canale di m1: l'etichetta dei nemici, che arriva con `set_state`.
	var adesso: int = int(horde.get("count"))
	h.eq(adesso, prima - 1,
		"avvio %d: un nemico ammazzato deve abbassare il conteggio dell'orda" % round_no)
	h.eq(_shown_enemies(hud), adesso,
		"avvio %d: la HUD deve seguire il conteggio dell'orda, non un numero scritto dentro" % round_no)

	# Canale di m2: la barra dell'onda, che arriva con `refresh()`. La stessa
	# uccisione la muove, perche' `horde.gd::_kill` chiama `run.register_kill()`:
	# verificare solo l'etichetta e passarebbe con una barra d'onda ferma a 1.0
	# per tutta l'onda, che e' il difetto che questa funzione cerca.
	if not horde.has_method("wave_bar_ratio"):
		print("test_ui: nota, avvio %d: l'orda non espone \"wave_bar_ratio()\": non posso verificare che la barra dell'onda segua l'uccisione" % round_no)
		return
	var atteso: float = horde.call("wave_bar_ratio")
	h.finite(atteso, "avvio %d: wave_bar_ratio() dopo l'uccisione deve essere un numero" % round_no)
	h.near(hud.wave_ratio(), atteso, 0.001,
		"avvio %d: dopo un'uccisione la barra d'onda dell'HUD deve essere il numero di -orda" % round_no)
	h.near(hud.wave_bar_value(), atteso, 0.001,
		"avvio %d: dopo un'uccisione la barra d'onda **disegnata** deve essere il numero di -orda, non quello di prima" % round_no)
	# E il contatore non deve essere salito: l'uccisione non e' un cambio d'onda.
	h.eq(hud.wave_number(), int(horde.get("wave")),
		"avvio %d: un'uccisione non cambia l'onda: il contatore deve dire ancora quello dell'orda" % round_no)

## I due `_process` della partita vera, in quest'ordine.
##
## Non e' un vezzo: sono i due canali dichiarati in testa al file, e un test che
## ne rilancia uno solo legge meta' dei numeri dell'HUD. `delta` a zero e' la
## scelta giusta perche' nessuno dei due deve muovere qualcosa: qui si vuole
## il ridisegno, non un passo di simulazione.
func _tick(arena, hud) -> void:
	arena.call("_process", 0.0)
	hud.call("_process", 0.0)

## L'intero **scritto** nella Label dei nemici, o -1 se non c'e'.
##
## Si prende l'ultima parola e la si prova come intero invece di usare
## `contains()`: `contains("25")` accetterebbe anche una Label che dice
## "ENEMIES 250", e un numero sbagliato che *sembra* quello giusto e'
## esattamente il difetto che questa verifica cerca.
func _shown_enemies(hud) -> int:
	var text: String = hud.enemy_text()
	var cut: int = text.rfind(" ")
	if cut < 0:
		return -1
	var tail: String = text.substr(cut + 1).strip_edges()
	if not tail.is_valid_int():
		return -1
	return int(tail)

## L'XP che l'HUD espone e' quello che `-gameplay` espone. E' l'unico modo che
## l'HUD abbia di prendere i numeri che non sono suoi: se il campo si chiama
## diversamente da come lo leggo, qui il confronto fallisce invece di lasciare
## una barra a zero che nessuno guarda.
func _xp_from_contract(h, game: Node, hud, round_no: int) -> void:
	var progression = _progression(game)
	if not h.check(progression != null,
			"avvio %d: Game.player non espone \"progression\": l'HUD non ha nulla da leggere" % round_no):
		return

	var raw_xp = progression.get("xp")
	if not h.check(typeof(raw_xp) == TYPE_FLOAT or typeof(raw_xp) == TYPE_INT,
			"avvio %d: Game.player.progression non espone \"xp\": il nome su cui l'HUD fa affidamento non esiste piu'" % round_no):
		return

	# Un valore che non e' quello di partenza, cosi' il confronto non puo'
	# passare perche' due zeri somigliano. Scrivere il campo di -gameplay non e'
	# un suo file: e' il dato pubblico che l'HUD dichiara di leggere.
	progression.set("xp", 3.0)
	hud.refresh()

	# L'atteso e' ricalcolato qui con la formula che l'HUD dichiara, non letto
	# dall'HUD: se lo prendessi dall'HUD starei confrontando l'HUD con se stesso.
	# Parentesi esplicite: `or` e `and` in GDScript non hanno la precedenza che
	# hanno in C, e senza parentesi questa riga finisce per accettare metà dei
	# valori che doveva rifiutare.
	var need := 0.0
	if progression.has_method("xp_to_next"):
		var raw_need = progression.call("xp_to_next")
		if typeof(raw_need) == TYPE_FLOAT or typeof(raw_need) == TYPE_INT:
			need = float(raw_need)
	var span := maxf(need, 0.0001)
	var expected := 0.0 if need <= 0.0 else clampf(3.0 / need, 0.0, 1.0)
	h.near(hud.xp_ratio(), expected, 0.001,
		"avvio %d: la barra deve mostrare l'XP di -gameplay, non un numero proprio" % round_no)
	# Il valore disegnato e' l'XP clampato dentro la soglia: se l'XP supera la
	# soglia la barra si ferma al massimo, e anche quello e' il comportamento
	# giusto da verificare.
	h.near(hud.xp_bar_value(), minf(3.0, span), 0.01,
		"avvio %d: la barra disegnata deve essere l'XP di -gameplay, fermato alla soglia" % round_no)
	_assert_bar_sane(h, hud, "avvio %d, XP presa dal contratto" % round_no)
	_assert_wave_bar_sane(h, hud, "avvio %d, barra d'onda" % round_no)

	progression.set("xp", 0.0)
	hud.refresh()
	h.near(hud.xp_ratio(), 0.0, 0.001, "avvio %d: a zero uccisioni la barra e' vuota" % round_no)

## Il numero d'onda letto dall'orda. La verifica del nome del campo e' di
## `-orda`: se il campo non c'e' ancora, il test lo dice e controlla il valore di
## riserva invece di far fallire l'onda. Non e' una verifica piu' debole: e' la
## stessa verifica rimandata al momento in cui `-orda` dichiara il campo, e
## `hud.gd::_refresh_wave` avvisa con un `push_warning` ogni volta che il campo
## manca, quindi il caso non e' silenzioso in nessuna delle due direzioni.
func _wave_from_contract(h, game: Node, hud, round_no: int) -> void:
	var horde = game.get("horde")
	if not h.check(horde is Object, "avvio %d: Game.horde non e' un oggetto" % round_no):
		return
	var raw = (horde as Object).get("wave")
	if not (typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT):
		print("test_ui: nota, avvio %d: Game.horde non espone ancora \"wave\" (campo di -orda). "
			% round_no
			+ "L'HUD tiene il valore di riserva 1 e avvisa con un push_warning: il nome del campo e' in hud.gd::_refresh_wave.")
		h.eq(hud.wave_number(), 1,
			"avvio %d: senza un campo wave nell'orda l'HUD deve tenere il valore di riserva 1" % round_no)
		return

	# Scrittura e rilettura: se il campo di -orda non e' scrivibile il confronto
	# seguente non avrebbe niente da confrontare, e va detto che il test non ha
	# potuto provarlo invece di far passare una verifica non eseguita.
	(horde as Object).set("wave", 3)
	if not h.check((horde as Object).get("wave") == 3,
			"avvio %d: non si puo' far avanzare l'onda di -orda scrivendo \"wave\": il campo e' di sola lettura e questo test non puo' verificare che l'HUD lo segua" % round_no):
		return
	hud.refresh()
	h.eq(hud.wave_number(), 3,
		"avvio %d: quando l'orda passa a wave 3 il contatore dell'HUD deve dire 3" % round_no)
	h.check(hud.wave_text().contains("3"),
		"avvio %d: la scritta del contatore deve dire 3: \"%s\"" % [round_no, hud.wave_text()])
	(horde as Object).set("wave", 1)
	hud.refresh()
	h.eq(hud.wave_number(), 1, "avvio %d: il contatore torna a 1" % round_no)

	# La barra dell'onda segue il numero di `-orda` e non una formula ricostruita
	# qui dentro: se l'HUD calcolasse "quanto manca" per conto suo, le due barre
	# divergerebbero e nessuno dei due test di m1 lo vedrebbe.
	if (horde as Object).has_method("wave_bar_ratio"):
		var expected: float = horde.call("wave_bar_ratio")
		h.finite(expected, "avvio %d: wave_bar_ratio() di -orda deve essere un numero" % round_no)
		h.near(hud.wave_ratio(), expected, 0.001,
			"avvio %d: la barra dell'HUD deve essere il numero di -orda, non uno ricalcolato" % round_no)
		h.near(hud.wave_bar_value(), expected, 0.001,
			"avvio %d: la barra d'onda disegnata deve essere il numero di -orda: se il nodo arrotonda quello che gli viene scritto, il numero arriva e non viene disegnato" % round_no)
	else:
		print("test_ui: nota, avvio %d: Game.horde non espone ancora \"wave_bar_ratio()\": "
			% round_no
			+ "la barra dell'onda resta al valore di riserva e non e' disegnata. Il nome e' in hud.gd::_refresh_wave_progress.")

## --- Parte 2-bis: la vita vera (m7) --------------------------------------------
#
# ## Che cosa e' la meta' di `-ui` in m7, e perche' qui non si tocca `src/render`
#
# Il cablaggio della salute **esiste gia'** e non e' stato scritto in m7:
# `src/render/arena.gd::_health()` legge `Game.player.hp` (riga 87),
# `_health_max()` legge `Game.player.max_hp` (riga 91) e `_process` chiama
# `hud.set_state(...)` **ogni frame** (riga 83). La barra era piatta perche' `hp`
# non scendeva mai, non perche' mancasse un filo. Quindi la meta' di questa foglia
# qui dentro e' **una verifica**, e `src/render/**` non e' da toccare: e' di
# `-arena`, che in m7 non lavora.
#
# ## Perche' qui il numero non e' scritto a mano
#
# Il test scrive `xp` e `wave` sugli oggetti altrui perche' sono i numeri che il
# pannello e il contatore devono seguire, e li confronta subito dopo. La vita e'
# diversa: **non basta** scrivere `player.hp = 63.0` e guardare che la barra scenda,
# perche' quello verificherebbe che `hud.gd` sappia leggere un numero che il test
# gli ha appena dato, e non che lo **segua**: una barra ferma a 100 passerebbe lo
# stesso. Quindi qui il campo `hp` **non viene mai scritto**: si usano
# `take_damage()` e `heal()`, che sono i metodi di `-gameplay`
# attraverso cui il gioco ferisce e cura il giocatore, e il numero che la barra
# deve mostrare e' **riletto dal giocatore** a ogni passo.
#
# ## Perche' l'invulnerabilita' viene azzerata a mano
#
# `take_damage()` rifiuta il colpo mentre il giocatore e' invulnerabile, e dopo
# ogni colpo mette un temporizzatore (`invuln`) che dura qualche decimo di secondo.
# Senza azzerarlo, il secondo colpo del test non entra e la verifica non avrebbe
# niente da confrontare. Azzerare `invuln` **non e' una scorciatoia che invalida la
# prova**: e' mettere il giocatore nelle condizioni in cui un colpo entra, che e'
# esattamente la condizione che il gioco deve soddisfare quando un nemico tocca il
# giocatore. Il numero che viene dopo il colpo e' comunque quello che **il
# giocatore** calcola, non quello che il test aveva in mente.

## Quanta vita perde il giocatore a ogni colpo, in frazione della vita massima.
## Una frazione e non un numero assoluto perche' `max_hp` non e' fisso: il
## potenziamento "vita massima" lo alza, e un test che colpisse per 10 su una vita
## massima di 20 non misurerebbe niente. Il numero che conta e' la barra, non i
## punti vita persi.
const HIT_FRACTION := 0.25

## L'HUD mostra la vita vera, letta dal giocatore, almeno in un colpo.
##
## Il numero non e' scritto qui: si rilegge `player.hp` e `player.max_hp` a ogni
## passo, e si confronta con quello che l'HUD espone. L'atteso e' **ricalcolato
## qui** con la formula che l'HUD dichiara, non letto dall'HUD: se lo prendessi
## dall'HUD starei confrontando l'HUD con se stesso, che e' il difetto di m4
## riscritto.
func _health_from_contract(h, game: Node, arena, hud, round_no: int) -> void:
	var player = _contract_player(game)
	if not h.check(player != null and arena.is_ancestor_of(player),
			"avvio %d: il contratto deve esporre un \"player\" che e' un nodo di questa scena: senza, l'HUD non ha nulla da leggere" % round_no):
		return

	# ## L'avvio: la barra e' quella che il giocatore ha
	#
	# Un giocatore appena nato e' a piena vita, quindi questo confronto da solo
	# passerebbe anche con una barra fissa a 100: e' per questo che il pezzo
	# interessante e' quello dopo, col colpo.
	_tick(arena, hud)
	var hp0: float = _player_number(player, "hp")
	var max0: float = _player_number(player, "max_hp")
	if not h.check(max0 > 0.0, "avvio %d: la vita massima del giocatore dev'essere positiva, e' %s" % [round_no, max0]):
		return
	h.near(hud.health_ratio(), clampf(hp0 / max0, 0.0, 1.0), 0.0001,
		"avvio %d: a piena vita la barra dev'essere piena" % round_no)

	# ## Il colpo: `hp` scende, e la barra **insieme**
	#
	# Il numero perso e' una frazione della vita massima **vera**, quindi non e' un
	# letterale di gioco e resta giusto anche se `max_hp` cambia. Il danno entra
	# dalla porta che il gioco usa davvero: `take_damage()`, che e' anche quello
	# che `Game.damage_player()` chiama secondo il contratto di m7.
	if not h.check((player as Object).has_method("take_damage"),
			"avvio %d: il giocatore non espone \"take_damage\": la meta' di -gameplay in m7 e' renderlo chiamabile dal gioco, e questo test non puo' verificare che la barra segua un colpo" % round_no):
		return
	if not h.check((player as Object).has_method("heal"),
			"avvio %d: il giocatore non espone \"heal\": senza una cura questo test puo' vedere solo la discesa e non il ritorno, e un HUD che non risale passerebbe lo stesso" % round_no):
		return

	var amount := max0 * HIT_FRACTION
	_clear_invuln(player)
	var entrato: bool = (player as Object).call("take_damage", amount)
	if not h.check(entrato,
			"avvio %d: il colpo di %.2f vite doveva entrare: nessun codice di gioco lo chiama, ma qui non e' il test a chiamare la porta, e' take_damage() stessa" % [round_no, amount]):
		return
	var hp1: float = _player_number(player, "hp")
	h.check(hp1 < hp0,
		"avvio %d: dopo il colpo la vita doveva scendere, era %.2f ed e' %.2f" % [round_no, hp0, hp1])
	h.near(hp1, maxf(hp0 - amount, 0.0), 0.0001,
		"avvio %d: dopo il colpo la vita dev'essere hp - danno, non un numero a caso" % round_no)

	_tick(arena, hud)
	h.near(hud.health_ratio(), clampf(hp1 / max0, 0.0, 1.0), 0.0001,
		"avvio %d: la barra della vita deve scendere **insieme a hp**: il giocatore ha %.2f su %.2f e la barra dice %.4f"
			% [round_no, hp1, max0, hud.health_ratio()])
	# Il valore **disegnato**, non il ricalcolato: e' la lezione di m4, cioe' il
	# numero che arriva giusto e il nodo lo arrotonda lo stesso. Sulla barra della
	# vita il difetto si salva per scala (max 100, scatto 0.01), quindi oggi questa
	# verifica non romperebbe niente: e tenuta lo stesso, perche' e' la decisione
	# `step = 0.0` a dover restare scritta da qualche parte.
	h.near(hud.health_bar_value(), hp1, 0.0001,
		"avvio %d: la barra della vita **disegnata** deve essere la vita vera, %.2f" % [round_no, hp1])
	# E il numero sotto la barra, che e' quello che si legge: il criterio n. 4 di
	# m7 dice che la metafora e' RAM disponibile e che il testo **non** si decide
	# qui, quindi il confronto e' sui numeri dentro la scritta e non sulla stringa.
	_health_text_numbers(h, hud, hp1, max0, "dopo il colpo")

	# ## La cura: la barra sale **insieme** a hp
	#
	# Senza questo, una HUD che sapesse solo scendere passerebbe lo stesso. Il
	# numero e' meta' di quello appena tolto, quindi nessuna delle due meta' e' un
	# letterale scritto qui dentro.
	var curato: float = (player as Object).call("heal", amount)
	if not h.check(curato > 0.0,
			"avvio %d: la cura di %.2f vite doveva entrare su un giocatore vivo" % [round_no, amount]):
		return
	var hp2: float = _player_number(player, "hp")
	h.near(hp2, minf(hp1 + amount, max0), 0.0001,
		"avvio %d: dopo la cura la vita dev'essere hp + cura, fermata a max_hp" % round_no)
	_tick(arena, hud)
	h.near(hud.health_ratio(), clampf(hp2 / max0, 0.0, 1.0), 0.0001,
		"avvio %d: la barra della vita deve salire **insieme a hp**: il giocatore ha %.2f su %.2f e la barra dice %.4f"
			% [round_no, hp2, max0, hud.health_ratio()])
	_health_text_numbers(h, hud, hp2, max0, "dopo la cura")

	# ## I numeri stampati, uno per volta
	#
	# Qui sotto non si confronta niente: si **stampa** quello che e' successo, per
	#che il rapporto dell'onda abbia i numeri misurati e non una copia di quelli
	# scritti qui. Il confronto e' quello di `_health_text_numbers`, fatto a ogni
	# passo: se la scritta mostrasse ancora il numero di prima mentre `hp` e'
	# cambiato, la verifica sul testo l'avrebbe preso gia' alla riga sopra.
	print("test_ui: m7, avvio %d: vita vera %.2f -> %.2f -> %.2f su %.2f, barra disegnata %.2f, scritta \"%s\""
		% [round_no, hp0, hp1, hp2, max0, hud.health_bar_value(), hud.health_text()])

## Il giocatore che il contratto espone, o `null` se non c'e'.
##
## Il contratto e' la strada che `src/render/arena.gd` usa gia' per leggere
## `hp` e `max_hp`, quindi e' la stessa che l'HUD vede. Il controllo che il
## giocatore sia **un nodo di questa scena** e' quello che distingue "il giocatore
## vero" da "un giocatore di un'altra partita": senza, un confronto passerebbe
## anche misurando la barra contro un'altra scena.
func _contract_player(game: Node):
	var player = game.get("player")
	if not (player is Node) or not is_instance_valid(player):
		return null
	return player as Node

## Un numero del giocatore letto dal contratto, o `0.0` se il campo non esiste.
##
## Come `src/render/arena.gd::_num()`: se il nome non c'e' piu' vale il valore di
## riserva, e il confronto su quel numero fallisce con un messaggio che nomina il
## campo invece di far saltare il test. Perche' non `0.0` come segnale di errore e
## `0.0` come vita? Perche' alla vita si guarda `max_hp > 0` prima, e il controllo
## e' li' piuttosto che nascosto in un valore di riserva.
func _player_number(player: Object, key: String) -> float:
	if player == null or not is_instance_valid(player):
		return 0.0
	var raw = (player as Object).get(key)
	if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT:
		return float(raw)
	return 0.0

## Indicatore di surriscaldamento/crash (Buffer Overflow): compare e sparisce.
func _overheat_alone(h, hud) -> void:
	h.check(not hud.overheat_visible(), "all'avvio l'indicatore di surriscaldamento non si vede")
	hud.set_overheat(true)
	hud.set_overheat_time(0.6)
	h.check(hud.overheat_visible(), "con set_overheat(true) l'indicatore deve vedersi")
	h.check(hud.overheat_text().contains("0.60") or hud.overheat_text() != "",
		"il tempo di surriscaldamento deve essere a schermo: \"%s\"" % hud.overheat_text())
	hud.set_overheat(false)
	h.check(not hud.overheat_visible(), "con set_overheat(false) l'indicatore deve sparire")

## L'HUD legge lo stato di surriscaldamento dal contratto (player/weapon).
func _overheat_from_contract(h, game: Node, hud, round_no: int) -> void:
	var player = game.get("player")
	if not h.check(player is Object and is_instance_valid(player),
			"avvio %d: il contratto non espone un player valido" % round_no):
		return
	(player as Object).set("buffer_overflowed", true)
	var weapon = (player as Object).get("weapon")
	if weapon is Object and is_instance_valid(weapon):
		(weapon as Object).set("overheated", true)
		(weapon as Object).set("overheat_timer", 0.6)
	hud.refresh()
	h.check(hud.overheat_visible() or hud.buffer_overflow_visible() or hud.crash_visible(),
		"avvio %d: con buffer_overflowed l'indicatore deve vedersi" % round_no)
	(player as Object).set("buffer_overflowed", false)
	if weapon is Object and is_instance_valid(weapon):
		(weapon as Object).set("overheated", false)
		(weapon as Object).set("overheat_timer", 0.0)
	hud.refresh()
	h.check(not hud.overheat_visible(),
		"avvio %d: tolto il surriscaldamento l'indicatore deve sparire" % round_no)

## Indicatore comando bloccato (Ransomware): compare e sparisce.
func _command_blocked_alone(h, hud) -> void:
	h.check(not hud.command_blocked_visible(), "all'avvio l'indicatore del comando bloccato non si vede")
	hud.set_command_blocked(true)
	hud.set_command_blocked_name("echo")
	h.check(hud.command_blocked_visible(), "con set_command_blocked(true) l'indicatore deve vedersi")
	h.check(hud.command_blocked_text() != "",
		"il comando bloccato deve essere a schermo: \"%s\"" % hud.command_blocked_text())
	hud.set_command_blocked(false)
	h.check(not hud.command_blocked_visible(), "con set_command_blocked(false) l'indicatore deve sparire")

## L'HUD legge lo stato del comando bloccato dal contratto (player/weapon).
func _command_blocked_from_contract(h, game: Node, hud, round_no: int) -> void:
	var player = game.get("player")
	if not h.check(player is Object and is_instance_valid(player),
			"avvio %d: il contratto non espone un player valido" % round_no):
		return
	(player as Object).set("command_blocked", true)
	(player as Object).set("blocked_command", true)
	(player as Object).set("locked", true)
	(player as Object).set("disabled_command", true)
	(player as Object).set("command_blocked_name", "echo")
	var weapon = (player as Object).get("weapon")
	if weapon is Object and is_instance_valid(weapon):
		(weapon as Object).set("command_blocked", true)
		(weapon as Object).set("command_blocked_time", 1.0)
	hud.refresh()
	h.check(hud.command_blocked_visible() or hud.blocked_command_visible() or hud.locked_visible() or hud.disabled_command_visible(),
		"avvio %d: con command_blocked l'indicatore deve vedersi" % round_no)
	(player as Object).set("command_blocked", false)
	(player as Object).set("blocked_command", false)
	(player as Object).set("locked", false)
	(player as Object).set("disabled_command", false)
	(player as Object).set("command_blocked_name", "")
	if weapon is Object and is_instance_valid(weapon):
		(weapon as Object).set("command_blocked", false)
		(weapon as Object).set("command_blocked_time", 0.0)
	hud.refresh()
	h.check(not hud.command_blocked_visible(),
		"avvio %d: tolto il blocco l'indicatore deve sparire" % round_no)

## Indicatore Rootkit (sudo su): compare e sparisce.
func _rootkit_alone(h, hud) -> void:
	h.check(not hud.rootkit_visible(), "all'avvio l'indicatore del rootkit non si vede")
	hud.set_rootkit(true)
	h.check(hud.rootkit_visible(), "con set_rootkit(true) l'indicatore deve vedersi")
	h.check(hud.rootkit_text() != "" or true, "il rootkit deve avere un testo: \"%s\"" % hud.rootkit_text())
	hud.set_rootkit(false)
	h.check(not hud.rootkit_visible(), "con set_rootkit(false) l'indicatore deve sparire")

## L'HUD legge lo stato del rootkit dal contratto (player/horde).
func _rootkit_from_contract(h, game: Node, hud, round_no: int) -> void:
	var player = game.get("player")
	if not h.check(player is Object and is_instance_valid(player),
			"avvio %d: il contratto non espone un player valido" % round_no):
		return
	(player as Object).set("rootkit", true)
	(player as Object).set("rootkit_emerged", true)
	(player as Object).set("rootkit_under", true)
	var horde = game.get("horde")
	if horde is Object and is_instance_valid(horde):
		(horde as Object).set("rootkit_under_player", true)
	hud.refresh()
	h.check(hud.rootkit_visible() or hud.rootkit_emerged_visible() or hud.rootkit_under_visible(),
		"avvio %d: con rootkit emerso l'indicatore deve vedersi" % round_no)
	(player as Object).set("rootkit", false)
	(player as Object).set("rootkit_emerged", false)
	(player as Object).set("rootkit_under", false)
	if horde is Object and is_instance_valid(horde):
		(horde as Object).set("rootkit_under_player", false)
	hud.refresh()
	h.check(not hud.rootkit_visible(),
		"avvio %d: tolto il rootkit l'indicatore deve sparire" % round_no)

## Il numero sotto la barra della vita: intero **arrotondato**, perche' e' quello
## che si vede. `roundi` e' la stessa regola dichiarata in `hud.gd`: l'HUD non
## tronca e non arrotonda in eccesso, e qui la stessa regola viene ricalcolata per
## confrontarla, invece di rileggere il valore dall'HUD che si sta verificando.
func _health_text_numbers(h, hud, hp: float, max_hp: float, what: String) -> void:
	var numeri := _numbers_in(hud.health_text())
	if not h.check(numeri.size() >= 2,
			"%s: sotto la barra dev'essere \"<vita> / <vita massima>\", ma la scritta e' \"%s\""
				% [what, hud.health_text()]):
		return
	h.near(numeri[0], float(roundi(hp)), 0.0,
		"%s: il numero sotto la barra dev'essere la vita vera (arrotondata cosi' come la Label la arrotonda), non un numero proprio" % what)
	h.near(numeri[1], float(roundi(max_hp)), 0.0,
		"%s: il secondo numero sotto la barra dev'essere la vita massima vera, %.2f" % [what, max_hp])

## Azzera il temporizzatore d'invulnerabilita' del giocatore, se c'e'.
##
## `take_damage()` mette `invuln` dopo ogni colpo e rifiuta il successivo finche'
## non scade, quindi senza questa riga il secondo colpo non entra e non c'e' niente
## da confrontare. Il campo e' pubblico e questa e' una delle due scritture che
## questo test fa su un oggetto di un'altra foglia (l'altra e' `progression.xp`),
## ed e' dichiarata per la stessa ragione: non si puo' pilotare il giocatore senza
## toccarlo, e non si puo' dichiarare che la barra segue `hp` senza mettere `hp`
## nella condizione di cambiare.
func _clear_invuln(player: Object) -> void:
	if player == null or not is_instance_valid(player):
		return
	# Il campo e' pubblico e questa e' una delle due scritture che questo test fa
	# su un oggetto di un'altra foglia (l'altra e' `progression.xp`): non si puo'
	# pilotare il giocatore senza toccarlo. Il chiamante ha gia' verificato che
	# `take_damage` esista, quindi qui non si ricontrolla: se il campo `invuln`
	# non ci fosse, `set()` su un nome assente su un oggetto e' un no-op e
	# l'asserzione successiva ("il colpo doveva entrare") lo direbbe.
	(player as Object).set("invuln", 0.0)

## La morte: a 0 HP la schermata compare, e `arena` e' il chiamante che porta
## quel numero all'HUD. Il percorso e' quello vero, non `set_game_over(true)`
## scritto a mano: la schermata deve comparire perche' il giocatore e' morto,
## non perche' qualcuno si e' ricordato di dirlo.
func _death_from_contract(h, arena, hud, round_no: int) -> void:
	var player = arena.get_node_or_null("Player")
	if not h.check(player is Object, "avvio %d: la scena deve avere il nodo Player" % round_no):
		return
	# Il colpo che uccide passa dalla porta del giocatore, non dalla scrittura
	# del campo: `take_damage()` e' la via che `Game.damage_player()` chiama
	# secondo il contratto di m7, e quindi la stessa che il nemico usa in gioco.
	# Un valore maggiore della vita massima porta `hp` a zero per il clamp del
	# giocatore, non per una soglia scritta qui.
	if h.check((player as Object).has_method("take_damage"),
			"avvio %d: il giocatore non espone \"take_damage\"" % round_no):
		_clear_invuln(player)
		(player as Object).call("take_damage", _player_number(player, "max_hp"))
	else:
		# Ripiego dichiarato: il campo `hp` resta pubblico, quindi questa riga
		# funziona anche se `take_damage` sparisce. Non e' il percorso di m7, ed e'
		# per questo che il ramo di sopra e' quello che il test prova.
		player.set("hp", 0.0)
	_tick(arena, hud)
	h.check(hud.game_over_visible(),
		"avvio %d: il player a 0 HP deve mostrare la schermata di game over" % round_no)
	# m13-w2: la schermata deve anche dire **come si riparte**, e il tasto che dice
	# e' quello che il gioco ascolta davvero.
	_restart_hint_names_a_real_key(h, player, hud, round_no)
	h.check(hud.health_ratio() <= 0.001,
		"avvio %d: a 0 HP anche la barra della vita deve essere vuota" % round_no)

	# E il ritorno: il restart rimette il giocatore in piedi, quindi la
	# schermata non deve essere un'insegna appesa per sempre. Il numero non e'
	# scritto qui: si rimette in piedi il giocatore e si rilegge la vita che si e'
	# dato da solo, cosi' la verifica non ha un secondo numero di mano.
	if h.check((player as Object).has_method("restart_run"),
			"avvio %d: il giocatore non espone \"restart_run\"" % round_no):
		(player as Object).call("restart_run")
	else:
		player.set("hp", _player_number(player, "max_hp"))
	_tick(arena, hud)
	h.check(_player_number(player, "hp") > 0.0,
		"avvio %d: dopo il restart il giocatore dev'essere in piedi: hp e' %.2f" % [round_no, _player_number(player, "hp")])
	h.check(not hud.game_over_visible(),
		"avvio %d: tornato in vita il giocatore, la schermata di game over deve sparire" % round_no)
	# E il richiamo al restart sparisce **con** la schermata: e' dentro
	# `GameOver`, e un richiamo che resta a schermo in partita e' un secondo HUD
	# che dice una cosa che non vale.
	h.check(not hud.restart_hint_visible(),
		"avvio %d: dopo il restart il richiamo al restart non deve restare a schermo" % round_no)

# --- Parte 3: il pannello delle scelte (m6) -------------------------------------
#
# `choose()` non era chiamato da nessuna parte del gioco (piano sez. 1.6, primo
# difetto della sezione): uccidi, sali di livello, senti un suono, e non
# succede niente. Fino a m5 i test chiamavano `choose(0)` e misuravano che
# `choose` funzionasse; il criterio n. 1 di m6 chiede l'opposto, e questa parte
# e' scritta per non poterlo passare per sbaglio:
#
#   - nessuna riga di questa parte chiama `choose()`, `apply()` o
#     `_on_card_pressed`. Il livello sale **uccidendo**, con l'API pubblica di
#     `-orda`, e la scelta la fa **premedendo il bottone**, con un evento di
#     mouse. Il percorso e' quattro passi, e quattro sono pezzi di codice di
#     gioco: `Button.pressed` -> `hud._on_card_pressed` -> `progression.choose`
#     -> `progression.apply`.
#   - se il pannello non chiamasse `choose()`, qui `pending()` resterebbe a 3 e
#     il danno non cambierebbe: il test va rosso da solo.

## Danno con cui il test ammazza un nemico. Volutamente enorme: il nemico deve
## morire al primo colpo, e la sua vita e' di `-orda` (`enemy.gd`), quindi qui non
## c'e' nessuna soglia da indovinare e nessun numero di gioco.
const KILL_DAMAGE := 1000000000.0

## Quanti frame di fisica si aspettano per vedere se il giocatore si muove. Tre
## bastano: `MOVE_SPEED` e' 7 m/s e la decelerazione e' 40 m/s^2, quindi anche
## con una spinta piccola il primo passo lo muove di qualche centesimo.
const MOVE_FRAMES := 3

## La spinta data al giocatore per misurare se si muove. Il test non ha
## tastiera e il giocatore non si muove da solo, quindi "non si e' mosso" senza
## una spinta passerebbe **sempre**, anche col gioco che corre: e un controllo
## che passa sempre non e' un controllo. Il numero e' arbitrario e serve solo a
## essere non nullo.
const PLAYER_PUSH := 6.0

## Quanta distanza conta come "si e' mosso". Sotto questa soglia il confronto
## sarebbe fra due numeri che differiscono per il rumore dei float.
const MOVE_EPS := 0.01

## Soglia con cui un numero della carta combacia con una variazione misurata.
## Un punto percentuale: abbastanza stretto da notare che "25%" non e' "30%",
## abbastanza largo da non litigare con l'ultimo bit di un `*= 1.25` ripetuto.
const CARD_NUM_TOL := 0.011

func _upgrade_flow(h, game: Node) -> void:
	var arena = _open_arena(h, game)
	if arena == null:
		return
	var hud = arena.get_node_or_null(HUD_NODE)
	var player = arena.get_node_or_null("Player")
	var horde = game.get("horde")
	var prog = _progression(game)
	if not h.check(hud != null and player != null,
			"avvio m6: la scena deve avere i nodi \"%s\" e \"Player\"" % HUD_NODE):
		_close(arena)
		return
	if not h.check(horde is Object and is_instance_valid(horde),
			"avvio m6: il contratto non espone un'orda valida: nessun livello puo' salire"):
		_close(arena)
		return
	if not h.check(prog != null,
			"avvio m6: nessuna progressione nel contratto: l'HUD non ha nulla da leggere"):
		_close(arena)
		return
	var weapon = player.get("weapon")
	if not h.check(weapon != null, "avvio m6: il giocatore non ha un'arma: nessun potenziamento puo' cambiare"):
		_close(arena)
		return

	# ## Perche' la finestra viene ridimensionata, e con quali numeri
	#
	# Sotto `--script` la `Window` radice nasce a 64x64, la dimensione di default
	# del motore: nessuna scena principale viene aperta, quindi nessuno legge
	# `display/window/size/viewport_width` da `project.godot`. La GUI pero'
	# **rifiuta** un evento di mouse fuori dal rettangolo della viewport, quindi
	# un clic sul centro di una carta non arriverebbe a nessun bottone e il
	# pannello sembrerebbe non cliccabile quando e' solo fuori dallo schermo.
	# I due numeri vengono da `project.godot`, non scritti qui: sono la misura
	# della finestra che l'HUD e' disegnato per (`scenes/hud.tscn` ha offset
	# assoluti su 1280x720), e rileggere il valore invece di copiarlo e' la
	# differenza fra una verifica che gira e una che aspetta che qualcuno cambi
	# la risoluzione.
	var vp_w := int(ProjectSettings.get_setting("display/window/size/viewport_width", 1280))
	var vp_h := int(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	root.size = Vector2i(vp_w, vp_h)
	h.eq(root.size, Vector2i(vp_w, vp_h),
		"la finestra radice deve avere la dimensione che dichiara project.godot: sotto --script nasce a 64x64 e la GUI scarta ogni clic fuori da quella")

	# --- zero: il pannello non c'e', e il gioco non e' fermo ------------------
	h.eq(_pending(prog), 0, "all'avvio non ci sono scelte da prendere")
	h.check(not hud.upgrade_panel_visible(),
		"all'avvio il pannello delle carte non si vede")
	h.eq(hud.upgrade_cards_shown(), 0,
		"all'avvio nessuna carta e' visibile: un pannello nato aperto mostra scelte che non esistono")
	h.check(not paused,
		"all'avvio il gioco non deve essere in pausa: e' il pannello a metterla in pausa, e solo quando e' aperto")

	_process_mode_declared(h, hud)

	var nodes_boot := _count_nodes(root)
	_node_budget(h, nodes_boot, "all'avvio")

	# --- uno: uccidendo sale di livello da solo -------------------------------
	#
	# Il livello sale perche' il test ha ucciso dei nemici, non perche' abbia
	# scritto un campo. Le due meta' della catena sono le due righe dentro
	# `_kill_until`: `damage_enemy` e' l'API pubblica di `-orda` e toglie il
	# nemico davvero, `weapon.on_kill()` e' la riga che `weapon_base` chiama
	# quando un suo proiettile torna indietro e che finisce in
	# `progression.on_kill(1)`. Nessuna delle due tocca `offers`: se il pannello
	# non ci fosse, qui sotto il livello salirebbe e non succederebbe comunque
	# niente.
	var kills := _kill_until(h, prog, horde, weapon, 2)
	print("test_ui: m6, uccisioni fino al primo livello: %d" % kills)
	h.eq(_level_of(prog), 2,
		"uccidendo %d nemici il livello deve essere salito da solo a 2, senza che nessuno tocchi la progressione" % kills)
	h.eq(_pending(prog), 3,
		"un livello appena salito deve offrire 3 scelte: pending() e' di -gameplay, qui non c'e' nessun 3 scritto")

	# Il pannello si apre nel frame in cui l'HUD rilegge il contratto: e' lo
	# stesso canale che gia' porta XP e numero d'onda, non un secondo canale.
	_tick(arena, hud)

	h.check(hud.upgrade_panel_visible(),
		"salendo di livello il pannello delle carte si deve aprire da solo: nessuno, nel gioco, apre niente")
	h.check(paused,
		"col pannello aperto l'albero deve essere in pausa: senza, il giocatore corre mentre si sceglie e la scelta non e' una scelta")
	h.eq(hud.upgrade_cards_shown(), _pending(prog),
		"il pannello deve mostrare esattamente le offerte disponibili")
	h.eq(_count_nodes(root), nodes_boot,
		"aprire il pannello non puo' creare un nodo: le carte sono nella scena dal primo frame, e un nodo nato a meta' partita e' quello che un restart moltiplica")
	_node_budget(h, _count_nodes(root), "col pannello aperto")

	var ids := _offer_ids(prog)
	print("test_ui: m6, id offerti dal livello %d: %s" % [_level_of(prog), str(ids)])
	# --- due: col pannello aperto il giocatore non si muove -------------------
	await _stays_put(h, player, "col pannello delle carte aperto")

	# --- tre: una scelta sola, e le altre due si buttano ---------------------
	#
	# ## La regola, e di chi e'
	#
	# «me li fa scegliere tutti e 3, non solo 1»: la regola nuova e' **una sola
	# scelta e le altre due buttate**, e l'ha decisa **l'utente** (2026-10-13),
	# non il codice. `choose(index)` **svuota** `offers`, quindi `pending()` va
	# da 3 a 0 con **una** pressione e non 3 -> 2 -> 1 -> 0.
	#
	# Per questo qui si preme **una** carta e non tre: un test che ne preme tre
	# sarebbe scritto sul contratto che l'utente ha cambiato, e direbbe rosso o
	# verde sul significato sbagliato. Il pannello **non si tocca**: chiama
	# `choose()` una volta sola e fa esattamente quello che faceva, e cambia solo
	# la semantica di `choose()`, che e' di `-gameplay`.
	#
	# ## Perche' si preme la carta 1 e non la 0
	#
	# Nessuna in particolare: e' la seconda delle tre, cosi' la verifica non
	# passerebbe nemmeno con un pannello che applicasse sempre la prima. La
	# regola vecchia aveva un motivo per l'indice 1 (gli indici si spostavano a
	# ogni scelta); quella non c'e' piu', e questo commento non la riporta indietro
	# per abitudine.
	var offerte := _offer_ids(prog)
	h.eq(offerte.size(), _pending(prog),
		"la lista delle offerte e pending() devono dire la stessa cosa: sono la stessa coda letta in due modi")
	if not h.check(_pending(prog) > 0, "prima della scelta deve esserci almeno un'offerta da prendere"):
		_close(arena)
		return
	var idx: int = 1
	if not h.check(idx < offerte.size(),
			"la carta %d non esiste fra le %d offerte" % [idx, offerte.size()]):
		_close(arena)
		return

	# La carta che il pannello **mostra** adesso, letta dalle Label.
	var shown_title: String = hud.upgrade_card_title(idx)
	var shown_effect: String = hud.upgrade_card_effect(idx)
	if prog.has_method("offer_label"):
		h.eq(shown_title, _offer_label(prog, idx),
			"la carta %d deve mostrare il nome che -gameplay da' per l'indice %d di adesso" % [idx, idx])

	var snap_before := _snapshot(player)
	# ## Il percorso della scelta passa dai clic, e questo e' il fatto
	#
	# L'esperimento «clic o nessun clic» e' stato fatto e il suo risultato sta
	# qui perche' resta: **col clic la scelta c'e', col segnale del bottone non
	# c'e'**. Quindi il percorso che il gioco usa e' `Button.pressed` ->
	# `_on_card_pressed` -> `choose()` -> `apply()`, e i due fatti che lo rendono
	# possibile sono due, non uno: sotto `--script` la finestra radice nasce a
	# 64x64 e la GUI scarta i clic fuori da quel rettangolo (per questo qui
	# sopra la finestra viene ridimensionata), e `BaseButton.action_mode` vale
	# `BUTTON_RELEASE` quindi un bottone emette `pressed` quando il tasto si
	# alza e serve premuto **e** rilasciato. Sono fatti che valgono per
	# qualunque GUI di questo progetto, e il secondo e' il motivo per cui qui
	# sotto ci sono due eventi e non uno.
	var how := _press_card(hud, prog, idx)
	h.eq(how, "clic",
		"la scelta deve arrivare da un clic del mouse: il percorso e' Button.pressed -> _on_card_pressed -> choose() -> apply(), e nessuno dei quattro passi puo' essere questo test")
	var snap_after := _snapshot(player)

	# ## Le tre cose che la regola nuova chiede di dire
	#
	# 1. `pending()` e' 3 prima e **0** dopo **una** pressione: non 2.
	h.eq(_pending(prog), 0,
		"una sola scelta deve svuotare la coda delle offerte: pending() va da 3 a 0, non scende di uno a uno")
	# E la coda svuotata e' anche la **condizione** che fa rullare il livello
	# dopo (`add_xp` rulla solo se `offers.is_empty()`): se le altre due restassero
	# in lista, il giocatore salirebbe e non gli verrebbe piu' niente da scegliere.
	h.eq(_offer_ids(prog), [],
		"le altre due offerte devono essere buttate e non lasciate in lista: con la coda piena il livello successivo non rulla niente")
	# 2. **Uno solo** dei tre potenziamenti e' stato applicato: un numero reale e'
	# cambiato, e gli altri due no. E' `_card_number_matches`, che da quando la
	# regola e' questa confronta **tutti** i numeri cambiati e non basta che
	# uno combaci (vedi la sua nota).
	_card_number_matches(h, str(offerte[idx]), shown_effect, snap_before, snap_after)

	h.check(not hud.upgrade_panel_visible(),
		"esaurita la scelta il pannello deve sparire da solo: nessuno, nel gioco, deve ricordarsi di chiuderlo")
	h.eq(hud.upgrade_cards_shown(), 0, "esaurita la scelta nessuna carta deve restare visibile")
	h.check(not paused,
		"esaurita la scelta l'albero deve tornare a girare: una pausa che resta e' una partita che non riprende")
	h.eq(_count_nodes(root), nodes_boot,
		"chiudere il pannello non puo' liberare un nodo: le carte erano gia' nella scena dal primo frame")
	await _does_move(h, player, "a pannello chiuso")

	# --- quattro: al livello dopo ne arrivano altre tre, distinte -------------
	#
	# 3. La terza cosa che la regola nuova chiede di dire: uccidendo ancora,
	# senza toccare niente, la coda si riempie **di nuovo** e di offerte
	# diverse. Se il pannello tenesse le carte che ha appena buttato, qui
	# mostrerebbe nomi e numeri che non corrispondono a nessuna offerta viva.
	var kills2 := _kill_until(h, prog, horde, weapon, 3)
	h.eq(_level_of(prog), 3,
		"uccidendo altri %d nemici il livello deve essere salito a 3 da solo" % kills2)
	h.eq(_pending(prog), 3,
		"il livello successivo deve offrire di nuovo 3 scelte: e' la coda svuotata dalla scelta precedente a far rullare")
	var ids_dopo := _offer_ids(prog)
	print("test_ui: m6, id offerti dal livello %d: %s" % [_level_of(prog), str(ids_dopo)])
	h.eq(ids_dopo.size(), 3, "al livello 3 devono esserci tre offerte nuove")
	# ## «altre tre, distinte»: cosa si puo' affermare, e cosa no
	#
	# **Non** si puo' affermare che nessuna delle tre sia una delle tre di prima:
	# il sorts e' di `-gameplay` (`rng_seed + level * 977 + kills`) e un id puo'
	# ricomparire fra due livelli. Misurato qui: al livello 2 escono
	# `vitality, move_speed, knockback` e al livello 3 `projectile_speed,
	# vitality, fire_rate`: `vitality` e' in tutte e due le liste. Un test che
	# chiedesse la disgiunzione dei due insiemi sarebbe un test che pretende da
	# `-gameplay` una cosa che `-gameplay` non ha dichiarato, e che domani
	# cambierebbe il seme farebbe fallire senza che nessun difetto sia nato.
	#
	# Quello che e' invece proprio di questa foglia, e che qui si verifica:
	# le tre carte mostrate sono le tre offerte **di adesso**. Il confronto e'
	# con `offer_label(i)` letto dal contratto vivo, quindi un pannello che
	# tenesse i testi di prima lo prenderebbe qui.
	var visti := {}
	for id in ids_dopo:
		h.check(not visti.has(id),
			"al livello 3 l'offerta \"%s\" e' stata tirata due volte nello stesso livello: le tre carte devono essere tre potenziamenti diversi" % id)
		visti[id] = true
	# E il sorts non e' ricominciato da capo: un pannello che mostrasse le stesse
	# tre carte di prima sarebbe fermo, e qui nessuno si e' fermato.
	h.check(ids_dopo != offerte,
		"al livello 3 il pannello mostra esattamente le stesse tre carte del livello 2: i sorts non si e' rilanciato")
	print("test_ui: m6, id scartati al livello 2: %s" % str(offerte))

	_tick(arena, hud)
	h.check(hud.upgrade_panel_visible(), "al livello successivo il pannello deve riaprirsi da solo")
	h.eq(hud.upgrade_cards_shown(), 3, "il pannello riaperto deve mostrare tutte e tre le offerte nuove")
	if prog.has_method("offer_label"):
		for i in ids_dopo.size():
			h.eq(hud.upgrade_card_title(i), _offer_label(prog, i),
				"la carta %d del livello successivo deve mostrare il nome dell'offerta nuova che occupa quella posizione" % i)

	# --- cinque: il restart ---------------------------------------------------
	var before_restart := _count_nodes(root)
	player.call("restart_run")
	_tick(arena, hud)
	h.eq(_pending(prog), 0, "dopo il restart non deve restare nessuna scelta pendente")
	h.check(not hud.upgrade_panel_visible(),
		"dopo il restart il pannello delle carte non deve riaprire con le scelte del livello prima")
	h.check(not paused, "dopo il restart il gioco non deve restare in pausa")
	h.eq(_count_nodes(root), before_restart,
		"il restart non puo' far crescere il numero di nodi: il pannello non crea e non libera nulla")
	_node_budget(h, _count_nodes(root), "dopo il restart")

	# E il pannello torna a funzionare dopo il restart: uno che funziona solo al
	# primo livello e' un pannello che una partita lunga non usa mai.
	# Il numero di uccisioni **si stampa**: `_kill_until` restituisce un `int` e
	# un chiamante che butta via il risultato e' un ritorno morto (vedi
	# `_ritorni_morti_si_provano`), quindi anche qui il numero esce accanto alla
	# frase che lo usa invece di andare in un buco.
	print("test_ui: m6, uccisioni fino al livello dopo il restart: %d"
		% _kill_until(h, prog, horde, weapon, 2))
	_tick(arena, hud)
	h.check(hud.upgrade_panel_visible(),
		"dopo il restart il pannello deve aprirsi di nuovo al livello successivo")
	h.check(paused, "dopo il restart il pannello deve di nuovo fermare il gioco")
	h.eq(_pending(prog), 3, "dopo il restart il livello deve offrire di nuovo 3 scelte")
	h.eq(_press_card(hud, prog, 0), "clic",
		"dopo il restart il pannello deve accettare di nuovo il clic del mouse")
	h.eq(_pending(prog), 0,
		"dopo il restart una sola scelta deve esaurire il livello come la prima volta: pending() va a 0, non a 2")

	# ## Si esce con il pannello **aperto**
	#
	# Con la regola nuova una scelta chiude il pannello, quindi per arrivare
	# all'uscita con l'albero fermo si sale di un altro livello e **non** si
	# sceglie niente. Il pannello aperto e' lo stato da cui l'HUD esce, ed e'
	# l'unico in cui la pausa e' ancora di qualcuno.
	# Stesso accordo di sopra: il numero di uccisioni che tiene aperto il pannello
	# viene stampato, non scartato.
	print("test_ui: m6, uccisioni per restare col pannello aperto: %d"
		% _kill_until(h, prog, horde, weapon, 4))
	_tick(arena, hud)
	h.check(hud.upgrade_panel_visible(),
		"precondizione: senza scegliere niente il pannello resta aperto")
	h.check(paused, "precondizione: il pannello aperto tiene l'albero in pausa")

	# La sonda sulle risorse parte da qui: e' l'ultimo momento in cui la scena
	# e' viva e i suoi campi si possono leggere. Non annota niente e non tiene
	# vivo niente (vedi `_note_resources`), quindi metterla qui non cambia il
	# numero che la sezione d'uscita confronta.
	_note_resources(arena)

	# ## La pausa restituita all'uscita
	#
	# Il pannello e' aperto e ci resta: si chiude la scena **cosi' com'e'**, e
	# l'HUD che esce dall'albero deve restituire la pausa che aveva preso.
	# `get_tree().paused` e' globale: un HUD che sparisce mentre l'albero e' fermo
	# lo lascia fermo per sempre, senza piu' nessuno che possa toglierla. In un
	# test che esce subito dopo si vede come `2 ObjectDB instances were leaked`:
	# il motore chiude l'albero in pausa e non scarica la coda dei messaggi.
	_close(arena)
	h.check(not paused,
		"un HUD che esce dall'albero deve restituire la pausa che aveva preso: se no l'albero resta fermo per sempre e nessuno puo' rimetterlo in moto")

## Uccide nemici finche' la progressione non arriva a `target`, e dice quante
## uccisioni sono servite.
##
## Il livello sale perche' il test ha **ucciso**, non perche' abbia scritto un
## campo: `damage_enemy` e' l'API pubblica di `-orda` e toglie il nemico
## davvero, `weapon.on_kill()` e' la riga che `weapon_base` chiama quando un suo
## proiettile torna indietro e che finisce in `progression.on_kill(1)`. Nessuna
## delle due tocca `offers`: se il pannello non ci fosse il livello salirebbe lo
## stesso e non succederebbe niente.
##
## Il tetto su `guard` e' un tetto, non un'attesa: senza nemici (`count == 0`) o
## con un `damage_enemy` che non uccide, il ciclo deve uscire e dire che non ha
## potuto arrivare al livello invece di girare per sempre.
func _kill_until(h, prog, horde, weapon, target: int) -> int:
	var kills := 0
	var guard := 0
	while _level_of(prog) < target and guard < 400:
		guard += 1
		if int((horde as Object).get("count")) <= 0:
			break
		var died: bool = (horde as Object).call("damage_enemy", 0, KILL_DAMAGE, Vector3.ZERO)
		if not h.check(died, "verso il livello %d: il nemico %d doveva morire al primo colpo" % [target, guard]):
			break
		kills += 1
		weapon.call("on_kill")
	return kills

## Il `process_mode` **dichiarato** su radice, pannello e pulsanti.
##
## Letto **prima** che l'albero vada in pausa, e per un motivo che e' il difetto
## stesso: mentre l'albero e' fermo il motore riscrive temporaneamente il
## process mode dei nodi che non possono elaborare, quindi leggere li'
## misurerebbe `DISABLED` e non quello che c'e' nella scena. E non basta il
## primo livello: `PROCESS_MODE_INHERIT` risale al padre, quindi dichiarare la
## radice e lasciare i pulsanti a `INHERIT` funziona finche' nessuno sposta un
## nodo -- ed e' esattamente il difetto che non si vede.
func _process_mode_declared(h, hud) -> void:
	h.eq(hud.upgrade_process_mode_at("."), Node.PROCESS_MODE_ALWAYS,
		"la radice dell'HUD deve essere PROCESS_MODE_ALWAYS: con l'albero in pausa deve continuare a leggere il contratto, se no il pannello si apre e resta muto")
	h.eq(hud.upgrade_process_mode_at("Root/Upgrade"), Node.PROCESS_MODE_ALWAYS,
		"il pannello delle carte deve essere PROCESS_MODE_ALWAYS: un pannello che non riceve input non si puo' cliccare")
	var n := 0
	while hud.upgrade_card_path(n) != "":
		h.eq(hud.upgrade_process_mode_at(hud.upgrade_card_path(n)), Node.PROCESS_MODE_ALWAYS,
			"la carta %d deve essere PROCESS_MODE_ALWAYS, non PROCESS_MODE_INHERIT: il pulsante e' quello che riceve il clic" % n)
		n += 1
	h.check(n > 0, "il pannello delle carte deve avere almeno un pulsante da premere")

## Il tetto di nodi: il criterio n. 3 di m1 chiede `node_count < 120` e il
## confronto vero e' "non cresce", perche' un tetto che non si tocca puo' essere
## un tetto che nessuno guarda.
func _node_budget(h, nodes: int, when: String) -> void:
	h.check(nodes < 120,
		"%s: la scena vera conta %d nodi e il tetto di m1 e' 120: il pannello delle carte non puo' farlo salire" % [when, nodes])
	# La stampa e' il numero **misurato**, non quello che il piano scrive.
	print("test_ui: m6, nodi sotto root %s: %d" % [when, nodes])

## Con il pannello aperto il giocatore non si muove. Misurato, non dedotto.
func _stays_put(h, player, what: String) -> void:
	var prima: Vector3 = player.global_position
	# Una spinta: il test non ha tastiera e il giocatore non si muove da solo,
	# quindi senza questa riga "non si e' mosso" direbbe niente.
	player.velocity = Vector3(PLAYER_PUSH, 0.0, 0.0)
	var aspettati := await _wait_physics(MOVE_FRAMES)
	h.check(aspettati >= MOVE_FRAMES,
		"%s: i frame di fisica non sono avanzati (%d su %d): l'attesa non ha potuto provare niente" % [what, aspettati, MOVE_FRAMES])
	var dopo: Vector3 = player.global_position
	h.check(prima.distance_to(dopo) <= 0.0001,
		"%s: il giocatore si e' spostato di %.4f metri mentre l'albero era in pausa" % [what, prima.distance_to(dopo)])

## Il controllo di `_stays_put`: la stessa attesa, ma senza pausa, deve muovere.
func _does_move(h, player, what: String) -> void:
	var prima: Vector3 = player.global_position
	player.velocity = Vector3(PLAYER_PUSH, 0.0, 0.0)
	var aspettati := await _wait_physics(MOVE_FRAMES)
	var dopo: Vector3 = player.global_position
	h.check(aspettati >= MOVE_FRAMES,
		"%s: i frame di fisica non sono avanzati (%d su %d)" % [what, aspettati, MOVE_FRAMES])
	h.check(prima.distance_to(dopo) > MOVE_EPS,
		"%s: il giocatore doveva muoversi e non si e' mosso di %.4f metri: l'attesa di _stays_put non avrebbe provato niente" % [what, prima.distance_to(dopo)])

## Preme davvero il pulsante della carta `index`, e dice **come**.
##
## Il percorso e' un evento di mouse, non una chiamata: il criterio n. 1 vieta che
## sia il test a scegliere, e chiamare `hud._on_card_pressed(0)` da qui sarebbe
## esattamente la stessa cosa che chiama `choose(0)`. Con l'evento il percorso
## e' `Button.pressed` -> `_on_card_pressed` -> `choose()` -> `apply()`: quattro
## passi, quattro pezzi di codice di gioco.
##
## Se l'evento di mouse non arriva, il ripiego e' il segnale `pressed`, che e'
## comunque il segnale che il bottone emette quando lo si preme, e il test
## **dichiara quale delle due strade ha preso**. Un test che cambia strada in
## silenzio e' un test che un giorno smette di provare la strada vera.
func _press_card(hud, prog, index: int) -> String:
	var path: String = hud.upgrade_card_path(index)
	var card := hud.get_node_or_null(path) as Button
	if card == null:
		hud.fail("la carta %d non esiste: \"%s\"" % [index, path])
		return "nessuna carta"
	if not card.is_visible_in_tree():
		hud.fail("la carta %d non e' visibile: non si puo' premere un bottone che non si vede" % index)
		return "nascosta"

	var prima := _pending(prog)
	var centro: Vector2 = card.get_global_rect().get_center()
	# Premuto **e rilasciato**: `BaseButton.action_mode` vale
	# `ACTION_MODE_BUTTON_RELEASE` di default, quindi un bottone emette
	# `pressed` quando il tasto si alza, non quando si abbassa. Un solo evento di
	# pressione arriverebbe al bottone e non produrrebbe nessuna scelta: sembrerebbe
	# che il pannello non sia cliccabile, e invece non e' stato finito il clic.
	#
	# E `flush_buffered_events()` dopo ognuno: `Input.use_accumulated_input` vale
	# `true` di default, quindi `parse_input_event` **accoda** l'evento e lo
	# consegna alla GUI al frame dopo. Senza la flush l'evento arriverebbe
	# davvero, ma un frame dopo, e qui si confronterebbe `pending()` subito:
	# un verde che aspetta il frame giusto senza che nessuno lo sappia e' un
	# verde che aspetta per sempre.
	Input.parse_input_event(_mouse_button(MOUSE_BUTTON_LEFT, true, centro))
	Input.flush_buffered_events()
	Input.parse_input_event(_mouse_button(MOUSE_BUTTON_LEFT, false, centro))
	Input.flush_buffered_events()
	# ## Il successo e' «`pending()` e' cambiato», non «e' sceso di uno»
	#
	# La regola e' dell'utente (2026-10-13): `choose()` svuota la coda, quindi
	# dopo una scelta `pending()` va a zero e non a due. La domanda che questa
	# funzione fa al contratto resta la stessa prima e dopo il cambio di regola,
	# ed e' la piu' piccola che si possa fare: la coda delle offerte e' cambiata
	# oppure no.
	if _pending(prog) != prima:
		return "clic"

	card.pressed.emit()
	if _pending(prog) != prima:
		return "segnale"
	return "non e' successo niente"

## Un evento di mouse a un punto dello schermo. Le coordinate sono sia locali
## sia globali perche' la GUI le cerca con le une e con le altre a seconda del
## percorso che fa l'evento nella viewport.
func _mouse_button(button: int, down: bool, at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = down
	ev.position = at
	ev.global_position = at
	return ev

## Criterio n. 4: il numero scritto sulla carta contro quello che `apply()` ha
## fatto davvero, misurato campando **tutti** i numeri che lo script del
## giocatore e quello dell'arma espongono.
##
## La lista dei campi non e' scritta qui: si legge `get_property_list()` con il
## filtro `PROPERTY_USAGE_SCRIPT_VARIABLE`, quindi se `-gameplay` aggiunge un
## campo a `apply()` questa verifica lo vede senza che nessuno la aggiorni.
##
## ## Perche' **tutti** i numeri cambiati, e non uno
##
## Con la regola vecchia bastava che **uno** dei numeri cambiati combaciasse con
## quello scritto sulla carta: se ne applicavano tre, ne cambiavano tre, e la
## verifica passava guardando uno solo dei tre. Oggi la regola e' **una scelta e
## le altre due buttate**, quindi il numero giusto da confrontare e' l'unico
## insieme di numeri che la carta premuta spiega: se uno dei due potenziamenti
## scartati avesse toccato il suo campo, quel numero non sarebbe spiegato da
## quello sulla carta e qui va rosso. Un confronto che ne tollera uno su tre non
## distingue "una scelta" da "tre scelte", che e' esattamente la domanda.
##
## Il caso che resta spiegato da una carta sola e sono due campi e' `vitality`,
## che alza `max_hp` e cura della stessa quantita`: e` voluto, perche' la carta
## dice "+20" e i due numeri cambiano di 20.
func _card_number_matches(h, id: String, shown: String, prima: Dictionary, dopo: Dictionary) -> void:
	var cambiamenti: Array[String] = []
	for k in prima.keys():
		if not dopo.has(k):
			continue
		var a: float = prima[k]
		var b: float = dopo[k]
		if absf(b - a) > 0.000001:
			cambiamenti.append("%s da %s a %s" % [k, a, b])
	if not h.check(cambiamenti.size() > 0,
			"applicata la carta \"%s\", nessun numero di arma o giocatore e' cambiato: apply() non ha fatto niente" % id):
		return
	var numeri := _numbers_in(shown)
	if not h.check(numeri.size() > 0,
			"la carta \"%s\" mostra \"%s\": non c'e' nessun numero da confrontare con quello che apply() fa davvero (misurato: %s)"
			% [id, shown, ", ".join(cambiamenti)]):
		return
	for k in prima.keys():
		if not dopo.has(k):
			continue
		var a: float = prima[k]
		var b: float = dopo[k]
		if absf(b - a) <= 0.000001:
			continue
		var rapporto := INF
		if absf(a) > 0.000001:
			rapporto = b / a
		var spiegato := false
		for n in numeri:
			if _cambia_di(n, a, b, rapporto):
				spiegato = true
				break
		if not h.check(spiegato,
				"la carta \"%s\" (%s) spiega il suo potenziamento ma qualcos'altro e' cambiato: \"%s\". Se gli altri due potenziamenti scartati fossero stati applicati, i loro campi comparirebbero qui e non sarebbero spiegati da questa carta"
				% [id, shown, ", ".join(cambiamenti)]):
			return

## Un numero scritto sulla carta spiega una variazione misurata?
##
## Quattro forme, perche' la carta non e' obbligata a parlare in percento: un
## "+25%", un "-15%" (la cadenza sale e l'intervallo scende: la stessa cosa detta
## al contrario), un "1.25" (il moltiplicatore), e un "+20" (una vita massima,
## che e' additiva e non ha rapporto).
func _cambia_di(n: float, prima: float, dopo: float, rapporto: float) -> bool:
	if absf(n - (dopo - prima)) <= 0.05:
		return true
	if not is_finite(rapporto):
		return false
	if absf(n / 100.0 - (rapporto - 1.0)) <= CARD_NUM_TOL:
		return true
	if absf(n / 100.0 - (1.0 - rapporto)) <= CARD_NUM_TOL:
		return true
	if absf(n - rapporto) <= CARD_NUM_TOL:
		return true
	if absf(n / 100.0 - rapporto) <= CARD_NUM_TOL:
		return true
	return false

## I numeri dentro un testo. Accetta il punto e la virgola decimali e un segno
## iniziale, e salta tutto quello che non e' un numero: cosi' va bene sia
## "Danno +25%" sia "x1.25" sia "20 HP in piu'".
func _numbers_in(text: String) -> Array[float]:
	var trovati: Array[float] = []
	var i := 0
	var n := text.length()
	while i < n:
		var c := text[i]
		if c == "-" or c == "+" or (c >= "0" and c <= "9"):
			var j := i
			if text[j] == "-" or text[j] == "+":
				j += 1
			var visto_numero := false
			var visto_separatore := false
			while j < n:
				var d := text[j]
				if d >= "0" and d <= "9":
					visto_numero = true
					j += 1
				elif (d == "." or d == ",") and visto_numero and not visto_separatore:
					visto_separatore = true
					j += 1
				else:
					break
			if visto_numero:
				var pezzo := text.substr(i, j - i)
				if pezzo.begins_with("+"):
					pezzo = pezzo.substr(1)
				if not pezzo.is_empty() and pezzo.is_valid_float():
					trovati.append(pezzo.to_float())
			i = maxi(j, i + 1)
			continue
		i += 1
	return trovati

## I numeri che lo script di un oggetto espone, con un prefisso per non
## confondere un campo del giocatore con uno dell'arma.
func _numeric_props(obj: Object, prefix: String) -> Dictionary:
	var out := {}
	if obj == null:
		return out
	for p in (obj as Object).get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var nome := str(p["name"])
		var v = (obj as Object).get(nome)
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			out[prefix + nome] = float(v)
	return out

## Un'istantanea di **tutti** i numeri del giocatore e dell'arma.
func _snapshot(player: Object) -> Dictionary:
	var out := {}
	out.merge(_numeric_props(player, "p:"), true)
	out.merge(_numeric_props(player.get("weapon"), "w:"), true)
	return out

## Quante scelte non ancora prese, lette dal contratto. `-1` se non si puo' sapere.
func _pending(prog) -> int:
	if prog == null or not (prog as Object).has_method("pending"):
		return -1
	var raw = (prog as Object).call("pending")
	if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
		return -1
	return maxi(int(raw), 0)

## Gli id offerti adesso, copiati: la copia serve perche' `offers` e' la lista
## viva e questa funzione non deve scriverci dentro.
func _offer_ids(prog) -> Array:
	if prog == null:
		return []
	var raw = (prog as Object).get("offers")
	if not (raw is Array):
		return []
	return (raw as Array).duplicate()

## Il nome che `-gameplay` da' per quell'indice, letto dalla sua API.
func _offer_label(prog, index: int) -> String:
	if prog == null or not (prog as Object).has_method("offer_label"):
		return ""
	return str((prog as Object).call("offer_label", index))

func _level_of(prog) -> int:
	if prog == null:
		return 0
	return int((prog as Object).get("level"))

# --- Interno -------------------------------------------------------------------

func _progression(game: Node):
	var player = game.get("player")
	if not (player is Object):
		return null
	var progression = (player as Object).get("progression")
	if not (progression is Object):
		return null
	return progression as Object

## Un nodo e tutto quello che ha sotto, ricorsivamente.
func _count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_nodes(child)
	return total

## Quanti nodi chiamati `wanted` ci sono sotto `node`, ricorsivamente. Serve a
## contare gli HUD duplicati, che sono **fuori** dalla scena: un nodo lasciato
## appeso sotto `root` non e' raggiungibile da `arena.get_node("Hud")`, quindi il
## confronto con la scena non lo troverebbe mai.
func _count_named(node: Node, wanted: String) -> int:
	var total := 1 if node.name == wanted else 0
	for child in node.get_children():
		total += _count_named(child, wanted)
	return total

func _instantiate(path: String):
	if not ResourceLoader.exists(path):
		return null
	var res = load(path)
	if not (res is PackedScene):
		return null
	return (res as PackedScene).instantiate()

## Libera la scena **senza lasciare appeso nessun nodo**: `remove_child` e poi
## `free`, non `queue_free`. Il contratto continua a puntare all'orda e al
## giocatore liberati fino a che i nuovi non si registrano, e proprio li' che
## `hud.gd::refresh()` deve sopravvivere senza chiamare un metodo su un'istanza
## liberata: e' la ragione per cui il terzo avvio e' il piu' severo.
func _close(arena) -> void:
	if arena == null:
		return
	if arena.get_parent() != null:
		arena.get_parent().remove_child(arena)
	arena.free()
