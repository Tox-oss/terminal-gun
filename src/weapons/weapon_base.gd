extends Node3D
## L'arma: spara **da sola**, verso il nemico più vicino. -gameplay.
##
## Il giocatore non preme il grilletto, in un bullet heaven non c'è un pulsante:
## il divertimento è correre per restare vivo mentre l'arma lavora. Quindi qui
## non ci sono input di sparo, solo un cooldown.
##
## La regola di ritmo che conta: **il colpo parte nello stesso frame in cui
## l'arma è pronta**. Il cooldown parte a `0.0` e viene contato a mano, non con
## un `Timer` e non con `await`: un `Timer` aspetta il frame di fisica
## successivo, e un frame di ritardo sul primo colpo è un frame di ritardo su
## tutti. Per la stessa ragione `step()` è pubblico e si può chiamare a mano:
## è così che il test guida il gioco, frame per frame, senza dipendere dalla
## velocità con cui gira il `SceneTree`.
##
## Nessuna dipendenza circolare: l'arma conosce il giocatore solo attraverso
## `Game.player_position()` (il contratto), e conosce il pool attraverso
## `preload`. Del giocatore non sa nemmeno il tipo.

const PoolScript := preload("res://src/weapons/projectile_pool.gd")
## Le tabelle delle specie, **lette**: `SPEED` e' la tabella delle velocita' dei
## cinque nemici e il suo massimo e' il `|v|` che la legge sotto usa. Leggerla
## non e' scriverci — il difetto sarebbe una **copia** di un numero che `-orda`
## puo' cambiare, non il fatto che la tabella stia li'.
const EnemyScript := preload("res://src/sim/enemy.gd")

## Il suono dell'impatto. Se il file non c'è nessun rumore e nessun errore:
## un test non deve fallire perché manca un asset.
const SFX_IMPACT := "res://assets/sfx/bonk.wav"

# --- Regolazione del gioco. Sono numeri, non segreti. --------------------------

## Secondi fra due colpi. 0.35 = quasi 3 colpi al secondo.
const FIRE_INTERVAL := 0.35
## Danno per proiettile.
const DAMAGE := 10.0
## ## m18: la velocita' del proiettile **non e' un numero**, e' una legge
##
## Il valore di prima era `const PROJECTILE_SPEED := 26.0`, scritto a mano. La
## legge del vertice (2026-10-18) e':
##
## > **durante il volo del proiettile il bersaglio non deve spostarsi piu' di una
## > finestra di centro.**
##
## Il tempo di volo e' `d / v_proiettile` e lo spostamento del bersaglio e'
## `|v| * d / v_proiettile`, quindi:
##
##     |v| * d / v_proiettile  <=  reach      <=>      v_proiettile  >=  |v| * d / reach
##
## e la velocita' **minima** che rispetta la legge e' quella che e' uguale al
## limite. Con i tre numeri **gia' dichiarati** — il `|v|` massimo della tabella
## delle specie (`6,6 m/s`, il runner), la gittata `ACQUIRE_RADIUS` (`26,0000 m`)
## e la finestra di centro `pool.reach_minimo()` (`1,6900 m`) — la velocita'
## richiesta e':
##
##     6,6 * 26,0000 / 1,6900  =  **101,538 m/s**
##
## cioe' **15,4 volte** il runner, contro le `26,0 m/s` di prima che ne erano
## `3,9`. I due errori che quei `26,0 m/s` producevano sono entrambi **derivati**
## da quello: con `26 m/s` il bersaglio medio si sposta `4,6263 * 17,0818 / 26 =
## 3,0394 m` durante il volo, cioe' **una volta e mezzo la finestra di centro**, e
## con un tempo di volo cosi' lungo l'anticipo da solo non puo' essere vero.
##
## ## Perche' **derivata** e non scritta
##
## Perche' i tre numeri da cui dipende sono gia' dichiarati e **nessuno dei tre
## verra' scritto diversamente per caso**: se `-orda` cambia una velocita', se un
## potenziamento allarga la gittata o se `-arda` cambia il fattore di corpo, la
## velocita' richiesta cambia **da sola**. Una velocita' scritta a mano e' un
## numero che aspetta di divergere dalle tre cose da cui dipende — ed e' esattamente
## quello che e' successo con i `26,0 m/s`.
##
## Quindi qui sotto **non c'e' nessun numero**: il campo parte da
## `PROIETTILE_NON_DERIVATA` come «non ancora derivata» e la derivazione sta in
## `_deriva_velocita()`, chiamata da `_ready()` (il posto in cui il pool esiste) e
## da `reset()` (il posto in cui tutta la regolazione torna alla sua regolazione di
## partenza, e quindi anche questa). Un potenziamento che moltiplica
## `projectile_speed` continua a funzionare: la derivazione e' la **regolazione di
## partenza**, non il valore corrente.
##
## ## Il caso peggiore dichiarato, e perche' non e' quello usato
##
## Qui si usa il massimo di `Enemy.SPEED` (`6,6 m/s`, il runner). Esiste un
## numero piu' grande e dichiarato: `Enemy.SPEED_MAX = 18,0 m/s`, che e' il
## **tetto della velocita' combinata** (inseguimento + spinta + separazione). Se la
## legge volesse davvero il caso peggiore di un nemico spinto, la velocita'
## richiesta sarebbe `18,0 * 26,0 / 1,6900 = 276,9 m/s`. Chi legge sappia che il
## numero qui e' il **massimo delle velocita' dichiarate per specie**, non il tetto
## della velocita' effettiva.
const PROIETTILE_NON_DERIVATA := 0.0
## Vita del proiettile, in secondi: con la velocita' **derivata** copre tutta
## l'arena e anche piu' (`101,5 m/s * 1,4 s = 142 m`), quindi la vita non e' il
## limite di nessuna legge — e il numero resta dichiarato perche' i proiettili
## vivi sono `vite * 60` e il pool ne tiene `100`.
const PROJECTILE_LIFE := 1.4
## Spinta data al nemico colpito, **in m/s**, non un vettore normalizzato.
## `Game.damage_enemy` deve sommarla alla velocita' del nemico e non
## normalizzarla.
##
## Il numero e' tarato sul **criterio n. 4** ("knockback >= 0.3 unita' entro 5
## frame"), misurato come delta di posizione e non come modulo dell'impulso: a
## 14 m/s il nemico che insegue a 3 m/s si sposta di 0.31 unita' in 5 frame,
## cioe' di misura. Il modulo dell'impulso non c'entra niente (e' uno scatto di
## velocita', non uno spostamento), ma la sensazione che il numero produce sì:
## 18 dà al colpo la spinta di un calcio e non di un dito, e al nemico resta
## qualche decimo di secondo di deriva prima che l'inseguimento lo riprenda.
const KNOCKBACK := 18.0
## Quanti nemici extra attraversa un proiettile prima di sparire. 0 = un colpo
## e via, come in un bullet heaven.
const PIERCE := 0
## Fin dove l'arma si mette in cerca di un bersaglio, in metri dal giocatore.
const ACQUIRE_RADIUS := 26.0
## Altezza della canna sopra il giocatore: il proiettile esce da qui e non dal
## centro del modello, altrimenti si vede uscire dai piedi.
const MUZZLE_HEIGHT := 0.9
## Due impatti nello stesso frame non suonano due volte: 0.05 s di attesa tra
## un "bonk" e l'altro, il tempo di un'orecchia.
const IMPACT_SFX_GAP := 0.05

## Quanti secondi uno slot del pool resta occupato **oltre** la lunghezza del
## suono: la rete per il giorno in cui `finished` non arrivasse. Stesso numero
## di `player.gd`, dichiarato qui e non letto da li': i due file non si
## preloaded a vicenda e nessuno dei due deve il tipo dell'altro, quindi
## nessuno dei due deve nemmeno una costante dell'altro.
const SFX_SICUREZZA := 0.35

## ## `SFX_POOL = 1`, e la capienza viene da una **misura**, non da un paragone
##
## Sul giocatore `SFX_POOL = 1` è motivato da due numeri del gioco: `hurt` non
## si sovrappone (`INVULN_AFTER_HIT = 0.7 s` contro 0.25 s di suono) e `levelup`
## non si sovrappone (otto uccisioni fra una soglia e l'altra contro 0.50 s).
## **Qui quel ragionamento non si può copiare**: `bonk` dura **0.18 s** e parte
## a ogni impatto, e l'arma spara da sola.
##
## Quindi la capienza è **misurata**, in `tests/test_gameplay.gd`, sezione
## `_audio_bonk`: tre montaggi della scena vera, 900 passi ciascuno, e il
## **massimo di suoni dentro una finestra di `bonk.wav`**, cioè 11 passi a
## DT = 1/60 s (0.1833 s, il primo multiplo di DT che supera 0.18 s).
##
##   - 117 suoni in 2700 passi, ~39 per montaggio;
##   - **massimo per passo: 1**;
##   - **massimo in 11 passi (0.1833 s): 1**, uguale in tutti e tre i montaggi;
##   - concorrenza massima fra suoni in uso: **1**.
##
## Il massimo è 1, quindi un nodo basta, e `45` resta `45`.
##
## ## Il tetto strutturale è 4, e va detto perché non è 1
##
## `IMPACT_SFX_GAP = 0.05 s` è il throttle di `on_impact()`: un suono ogni
## 0.05 s, cioè al più `ceil(0.1833 / 0.05) = 4` dentro la finestra. Quindi **1
## non è un teorema**: è il massimo osservato. Due impatti ravvicinati sono
## possibili per costruzione — l'arma spara ogni `FIRE_INTERVAL = 0.35 s` e mira
## al nemico più vicino in quel momento, quindi se fra due colpi il nemico più
## vicino è cambiato e il nuovo è più vicino di 4.3 m, il secondo proiettile
## arriva entro 0.1833 s dal primo.
##
## E va detto anche **cosa succede** in quel caso, perché è la parte buona: con
## `SFX_POOL = 1` lo slot è occupato, il pool **riprende lo slot che sta per
## finire** (`_prendi_slot`) e `play()` ricomincia il suono. Questa è
## **esattamente** la semantica del nodo unico di prima del pool: un `play()`
## su un nodo che suona ricomincia. Quindi nel caso raro il suono viene
## su un nodo che suona ricomincia. Quindi nel caso raro il suono viene
## troncato, ma veniva troncato anche prima: **non è una perdita, è il
## comportamento che il gioco aveva**. Alzare la capienza a 2 aggiungerebbe un
## nodo alla scena vera e romperebbe i tre criteri di `test_arena.gd`,
## `test_gameloop.gd` e `test_ui.gd`, che sono giusti: per quello la decisione è
## del vertice, non di questo file.
const SFX_POOL := 1

## Il nome che `scenes/player.tscn` da' allo slot 0. Lo slot 0 riusa quel nodo,
## quindi il totale dei nodi della scena non cambia; gli slot 1 e oltre, se mai
## ce ne fossero, prendono `Sfx1`, `Sfx2`...
const NOME_SFX := "Sfx"

# --- Stato. Tutto qui è un campo perché sono cose che i potenziamenti cambiano.
var damage := DAMAGE
var fire_interval := FIRE_INTERVAL
## La velocita' del proiettile, **in m/s, DERIVATA** dalla legge sopra: qui parte
## da `PROIETTILE_NON_DERIVATA` e `_ready()` la calcola. Vedi il blocco lungo e
## `_deriva_velocita()`.
var projectile_speed := PROIETTILE_NON_DERIVATA
var projectile_life := PROJECTILE_LIFE
var knockback := KNOCKBACK
var pierce := PIERCE
var acquire_radius := ACQUIRE_RADIUS
## ## m15: l'arma **anticipa** il bersaglio, e questo campo e' l'interruttore
##
## La legge e' del vertice (2026-10-18) e non una scelta di gusto: e' aritmetica,
## e i numeri che la impongono sono gia' scritti in questo file.
##
## Il tempo di volo di un colpo, alla gittata dell'arma:
##
##     tempo_di_volo = distanza / PROJECTILE_SPEED = 26,0 m / 26,0 m/s = 1,00 s
##
## e in quei `1,00 s` il nemico piu' veloce (runner, `6,6 m/s`) si sposta di
## `6,6 m`, mentre il reach del colpo e' `1,6900 m`: il bersaglio **e' uscito dal
## reach 3,9 volte prima** che il proiettile arrivi. Percio' un proiettile che
## guarda dove il nemico **e'** invece che dove **sara'** puo' colpire solo a
## contatto, e la misura lo conferma: `t = 1,0000` in tutte le candidate
## campionate, cioe' il punto d'impatto considerato e' **la fine del segmento**,
## il colpo arriva dove il bersaglio non c'e' piu'.
##
## ## La formula, e **la correzione che il controfattuale ha imposto**
##
## La prima stesura era `v * d / PROJECTILE_SPEED`, cioe' la velocita' del
## bersaglio per il **tempo di volo**. Il controfattuale di
## `tests/test_progression.gd::_tasso_col_controfattuale` l'ha falsificata in
## cinque esecuzioni su cinque: tasso di centro **0,0477 - 0,0531** con
## anticipo contro **0,0592 - 0,0725** senza, differenza **negativa in 5 su 5**,
## `sigma` fino a **3,77**. Il termine sbagliato e' `d / PROJECTILE_SPEED`:
## quello e' il tempo di **volo**, non il tempo di **intercettazione**, e sono
## due numeri diversi perche' il bersaglio **insegue e chiude** invece di starsi
## fermo. Quindi:
##
##     tempo_di_intercettazione = distanza / (velocita' del proiettile + |velocita' del bersaglio|)
##     anticipo = velocita' del bersaglio * tempo_di_intercettazione
##
## ## La correzione e' vera, e **non basta**: i numeri che lo dicono
##
## Misurati sugli stessi colpi della finestra del controfattuale, dentro
## `_try_fire()` (sonda poi tolta, numeri dichiarati in `tests/test_progression.gd`):
##
##     tempo di volo           `v * d / 26`          ->  **3,2192 m**
##     tempo di intercettazione `v * d / (26 + |v|)`  ->  **2,6798 m**
##
## La correzione toglie **`0,5394 m`** ed e' la differenza giusta. **Ma il
## predetto non cade dentro il reach**: `2,6798 m` contro `1,6900 m` di finestra
## di centro, fuori di **`0,9898 m`**, cioe' del **`58,6%`** della finestra. E il
## controfattuale, riletto con la formula corretta, e' **ancora rosso e ancora
## negativo**: `0,0476 - 0,0531` contro `0,0634 - 0,0684`, sigma **2,12 - 3,26**
## in cinque esecuzioni su cinque.
##
## Il numero che dice **perche'** e' lo **scarto residuo** stampato dal test: i
## colpi passano in media a **`6,5 m`** da un centro nemico contro i `1,6900 m`
## del reach, e solo **`2,9%`** dei campioni passa dentro la finestra. Cioe' lo
## scarto residuo e' **quattro volte la finestra di centro**, e **non e' un
## difetto di formula**: dentro quei `0,6104 s` di volo il nemico cambia
## direzione, e nessuna formula vede la svolta.
##
## Nota su un numero che e' stato preso e buttato: `1,4319 m` era la stima
## dell'anticipo corretto ricavata come `|v|` medio per `d` medio. **La media di
## un prodotto non e' il prodotto delle medie** e `|v|` e `d` sono anticorrelati
## (i bersagli lontani sono i piu' lenti, quelli addosso i piu' veloci), quindi
## quel numero era **derivato e sbagliato** — due volte la differenza dal
## misurato. E' scritto qui perche' la lezione e' gia' stata pagata una volta.
##
## La velocita' del bersaglio **non e' copiata qui**: e' `horde.velocities`,
## array parallelo a `horde.transforms` e letto dal contratto come gli altri due
## (vedi `_velocita()`).
##
## ## Perche' un campo e non una costante
##
## Perche' il **controfattuale** e' una misura, e una misura che non puo'
## spegnere la cosa che misura non e' una misura: `tests/test_progression.gd`
## spara a ogni passo alternando questo campo e mette i due bracci a confronto
## **sullo stesso passo, alla stessa distanza** (vedi `_tasso_col_controfattuale`).
## Il numero che verifica il rimedio e' `tasso di centro con l'anticipo contro
## tasso senza`, e quel numero non si sposta: una disuguaglianza fra due
## comportamenti della stessa arma resta quella che e' anche se una soglia
## assoluta si abbassa.
var anticipa := true
## Countdown del proiettile successivo. Parte a `0.0`: il primo colpo esce al
## primo `step()`.
var cooldown := 0.0
## Quanti colpi sono partiti dal caricamento. Il test ci fa caso.
var shots := 0
## Il pool: 100 proiettili, nessun nodo per proiettile. Senza tipo di classe,
## così questo file non deve niente a `projectile_pool.gd` e viceversa.
var pool

## Il **pool** dei nodi che suonano l'impatto, e le scadenze dei suoi slot.
## Stessa forma del pool di `player.gd`: un `Array` di nodi e una
## `PackedFloat32Array` di scadenze, capienza `SFX_POOL`. La scadenza di uno
## slot e' `0.0` quando lo slot e' libero. Suonare **prende** uno slot: nessun
## nodo nasce durante la partita, e i nodi sono gia' nel totale `20` di
## `-gameplay` perche' `scenes/player.tscn` li porta gia'.
var _sfx: Array[AudioStreamPlayer3D] = []
var _sfx_scadenza := PackedFloat32Array()
var _sfx_gap := 0.0
## Quanti suoni ha fatto partire quest'arma, in tutto. E' il numero con cui il
## test misura **quanti bonk arrivano ravvicinati**, che e' la domanda che
## decide quanti nodi deve tenere il pool di `bonk`: e' anche la prova che il
## suono e' uscito e non e' stato solo contato.
var sfx_emessi := 0
## Quanti impatti ha visto l'arma, **compresi quelli che il throttle
## `IMPACT_SFX_GAP` lascia passare senza suono**. E' il denominatore del
## confronto con `sfx_emessi`: senza questo numero un criterio che chiede
## «il suono esce» passerebbe anche con metà dei bonk persi, ed è esattamente
## quello che è successo quando il ramo di riuso dello slot è stato tolto per
## misura: i suoni sono scesi da 39 a 20 per montaggio e il criterio era verde.
var impatti := 0
## Chi ha creato l'arma. Senza tipo di classe: `player.gd` conosce
## `weapon_base.gd` solo per crearla, e nessuno dei due deve il tipo dell'altro.
var player

func _ready() -> void:
	pool = PoolScript.new()
	pool.name = "Pool"
	add_child(pool)
	pool.weapon = self
	# ## m18: la velocita' si deriva **qui**, e non in `_ready()` per caso
	#
	# `_deriva_velocita()` ha bisogno del pool per `reach_minimo()`, e il pool
	# esiste solo da questo momento. Quindi questo e' l'unico posto dove la
	# derivazione puo' girare prima del primo colpo, ed e' il posto giusto: dopo
	# questa riga `projectile_speed` e' un numero per tutte le ragioni.
	projectile_speed = _deriva_velocita()
	_sfx = _costruisci_pool()
	_sfx_scadenza.resize(_sfx.size())
	# Piano §5.1: i metodi si registrano con `register_impl`, mai con
	# `Game.spawn_projectile = self._spawn_projectile` (GDScript lo rifiuta e
	# interrompe il `_ready`, e la foglia crede di aver registrato).
	Game.register_impl("spawn_projectile", self._spawn_projectile)

## ## Nuova partita: l'arma torna alla regolazione di partenza
##
## ## Perche' questo metodo esiste, e non e' una formalita'
##
## `player.reset_run()` lo chiama, ed e' stato scritto **dopo** che il restart
## e' diventato un criterio (n. 4 di m2). Senza di questo, `reset_run()` lancerebbe
## `Invalid call. Nonexistent function 'reset'` a meta' della sua propria esecuzione:
## le vite tornerebbero a 100 e la progressione a livello 1, ma **qui dentro
## resterebbero i numeri dei potenziamenti scelti nella partita precedente** (il
## danno prende il +25% a ogni livello, quindi una partita nuova comincerebbe gia'
## con il danno di un livello 7). E' il difetto che `progression.reset()`
## documenta e non risolve da solo: la progressione non puo' scrivere sui campi
## dell'arma, e l'arma non puo' scrivere sulla progressione.
##
## Sono **numeri in campi che esistono gia'**: nessun nodo creato, nessuno liberato,
## nessuna allocazione, quindi il criterio n. 4 ("nessun nodo duplicato") non
## dipende da una scelta di questo file. Il pool viene svuotato con il **suo**
## `reset()`, che riusa gli stessi 100 record: `ever_created()` resta 100 anche
## dopo un restart.
##
## Il cooldown torna a `0.0` e non a `fire_interval`: come all'avvio, il primo
## colpo deve partire **al primo `step()`** e non un `fire_interval` dopo. Un
## restart che lasciasse l'arma in attesa e' una partita nuova che comincia senza
## sparare, che e' il difetto peggiore di tutti quelli che poteva avere.
func reset() -> void:
	damage = DAMAGE
	fire_interval = FIRE_INTERVAL
	projectile_life = PROJECTILE_LIFE
	knockback = KNOCKBACK
	pierce = PIERCE
	acquire_radius = ACQUIRE_RADIUS
	anticipa = true
	cooldown = 0.0
	shots = 0
	# ## m18: la velocita' torna alla **derivazione**, non a un numero scritto
	#
	# `reset()` e' «la regolazione di partenza», e la regolazione di partenza della
	# velocita' **e' la legge**: quindi qui si rideriva, e non si rimette un
	# letterale. Il vantaggio si vede subito: se un potenziamento aveva alzato
	# `acquire_radius`, qui torna a `ACQUIRE_RADIUS` e la velocita' si ricalcola di
	# conseguenza — una velocita' scritta a mano sarebbe restata al valore vecchio.
	projectile_speed = _deriva_velocita()
	_sfx_gap = 0.0
	# Gli slot del pool di `bonk` tornano a zero come gli altri numeri della
	# partita: uno slot occupato da un suono della partita che è finita
	# ripartirebbe occupato, e su un solo slot la partita nuova comincerebbe
	# con il suono che le occupa lo slot.
	chiudi_suoni()
	if pool != null:
		pool.reset()

## Un passo di gioco: cooldown, eventuale colpo, e il volo dei proiettili.
##
## ## m13-w3: il fuoco finisce con il giocatore
##
## Qui c'era `if cooldown <= 0.0: _try_fire()` e nient'altro, cioe' il difetto che
## l'utente ha visto giocando: a `game_over` la pausa la mette `-orda`
## (`horde.step` ritorna subito), ma il **cooldown e' un numero del
## giocatore** e l'albero continua a girare — quindi l'arma spara per sempre
## sopra una partita finita, e ogni colpo fa un "bonk" su un nemico immobile.
##
## Il clock gira **sempre**, anche da morto: e' quello che fa partire il primo
## colpo **subito** quando la condizione di morte torna falsa, e non un
## `fire_interval` dopo. E il pool gira **sempre**, quindi i proiettili gia' in
## volo finiscono il loro percorso invece di restare fermi a meta' aria per
## sempre: quello che si ferma e' il fuoco, non il mondo.
func step(delta: float) -> void:
	cooldown -= delta
	_sfx_gap -= delta
	if cooldown <= 0.0 and not _morto():
		_try_fire()
	_chiudi_bonk_scaduti(delta)
	if pool != null:
		pool.step(delta)

## Il giocatore e' morto? La domanda e' **`player.is_dead()`, riletta a ogni
## passo**, e non un flag memorizzato al momento della morte.
##
## La differenza e' un difetto intero: un flag latchato («una volta morto, non
## sparo piu'») passa la stessa finestra di 600 passi di un test che guarda solo
## il contatore, e resta spento **per sempre** anche quando la condizione di
## morte non e' piu' vera — cioe' al restart, e al primo colpo di una partita
## nuova che non spara. `tests/test_gameplay.gd::_fuoco_dopo_morte` avvola la
## condizione di morte e pretende che il contatore torni a crescere: e' il dente.
##
## `has_method` invece di un tipo: `player.gd` e questo file non si preloaded a
## vicenda e nessuno dei due deve il tipo dell'altro (piano §5, regola 3). Un
## giocatore finto — o un'arma usata da sola — non ha `is_dead()`, e allora non
## e' morto: il portatore del difetto e' il giocatore vero, che ce l'ha.
func _morto() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if not player.has_method("is_dead"):
		return false
	return bool(player.call("is_dead"))

## La spinta auto: mira al nemico più vicino entro `acquire_radius`. Se non
## c'è nessuno nel raggio non spara: meglio una pausa che spazzare il vuoto.
## Il bersaglio si chiede al contratto con `nearest_enemy(from, radius) -> int`
## (piano §5.2: un indice, non un nodo) e l'indice e' lo stesso che
## `damage_enemy` accetta.
##
## ## m15: il punto che si mira e' **dove il bersaglio sara'**, non dove e'
##
## `pool.enemy_position(target)` dice dove il nemico **e' adesso**; il colpo arriva
## dopo `tempo_di_volo`, e a quel punto quel nemico si e' spostato. Quindi il
## vettore `to_target` qui sotto e' la posizione **di partenza** del tiro, non la
## sua direzione: la direzione e' quella di `mira - origin`, e `mira` passa da
## `_anticipo()`. Senza quel passaggio il colpo e' una retta e il bersaglio una
## curva: e' il difetto che i numeri del campo `anticipa` descrivono.
## ## Diagnostica di `_try_fire()`: **tolta dopo che il suo numero e' stato scritto**
##
## Un passo che «non spara» ha tre `return` e un solo contatore, `shots`, che conta
## **soli** i casi in cui il pool ha ceduto lo slot: `shots` fermo non dice quale dei
## tre abbia fermato, dice che qualcosa ha fermato. Per un'onda sono stati messi sei
## contatori, incrementati nei quattro punti **senza cambiare alcun ramo**, e letti una
## volta sola. I numeri, sulla scena vera di `tests/test_gameplay.gd` dopo la finestra
## di `600` passi:
##
##   raggiunta **96** | pool mancante 0 | senza bersaglio 51 | a distanza zero 0
##   **arrivata alla riga che chiama `Game.spawn_projectile` 45** | risposta `false` **0**
##
## `96 = 51 + 45`: gli altri due `return` non sparano mai e il contratto non risponde
## mai `false`. Quindi su quella scena la catena e' sana, e il numero che chiude un
## difetto di sparo e' **`player.weapon == null`**: `step()` (riga 542) ha **un solo**
## `return`, `if delta <= 0.0` — non c'e' guardia su `is_dead()` ne' su `invuln` — e
## `weapon.step(delta)` e' protetto **solo** da `if weapon != null` (riga 560).
##
## I contatori sono **togliati**: un contatore che nessun criterio guarda, dentro un
## file di gioco, e' un costo che il gioco paga ogni frame. Una sonda si toglie
## **dopo** che il suo numero e' stato scritto, non prima.
func _try_fire() -> void:
	if pool == null:
		return
	var from: Vector3 = Game.player_position()
	var target := Game.nearest_enemy(from, acquire_radius)
	# -1 e' "nessuno", e non e' un indice: da non passare mai a `damage_enemy`.
	if target < 0:
		return
	var origin := muzzle_position()
	var dove_ora: Vector3 = pool.enemy_position(target)
	var to_target: Vector3 = dove_ora - origin
	var dist := to_target.length()
	if dist <= 0.001:
		return
	# Il tempo di intercettazione e' la distanza **di adesso** divisa per la
	# velocita' di chiusura: vedi `_tempo_intercettazione`.
	var mira := dove_ora + _anticipo(target, dist)
	# Si passa per il contratto e non per una chiamata diretta al pool: il
	# percorso che il gioco usa è lo stesso che il test e le altre foglie
	# verificano con `Game.spawn_projectile`.
	if Game.spawn_projectile(origin, (mira - origin).normalized(), projectile_speed):
		shots += 1
	cooldown = fire_interval

## ## m15: il tempo di **intercettazione**, e la sua formula scritta una volta sola
##
##     tempo_di_intercettazione = distanza / (velocita' del proiettile + |velocita' del bersaglio|)
##
## Il denominatore e' la **velocita' di chiusura**: il proiettile corre verso il
## bersaglio e il bersaglio corre verso il proiettile, quindi i due si avvicinano
## **sommando** e non sottraendo. E' la correzione che il controfattuale ha
## imposto: col denominatore a `velocita' di chiusura` il predetto scende da
## **`3,2192 m`** a **`2,6798 m`** misurati sugli stessi colpi (vedi il campo
## `anticipa`).
##
## La distanza e' quella **di adesso**, non quella anticipata: la forma e' chiusa
## e non un'iterazione, e il numero che dice se basta e' lo **scarto residuo**
## stampato dal test — cioe' quanto il colpo e' passato lontano da un centro
## nemico, `6,5 m` contro i `1,6900 m` della finestra di centro. Quello scarto
## **nessuna formula puo' correggerlo**, perche' dentro quei `0,6104 s` di volo il
## nemico cambia direzione e non lo dichiara.
##
## `anticipa == false` dà `dist / PROJECTILE_SPEED`: e' il **controfattuale**,
## cioe' il comportamento di prima della legge, ed e' l'unico modo di misurare
## che il rimedio cambi qualcosa (vedi il campo `anticipa`).
func _tempo_intercettazione(indice: int, dist: float) -> float:
	var den := projectile_speed
	if anticipa:
		den += _velocita(indice).length()
	return dist / maxf(den, 0.001)

## L'anticipo: **dove il bersaglio sara'** quando il colpo arriva. Il secondo
## fattore e' il tempo di intercettazione (vedi sopra); il primo e' quanto il
## bersaglio si sposta in quel tempo.
##
## `anticipa == false` dà `Vector3.ZERO`: e' il controfattuale.
func _anticipo(indice: int, dist: float) -> Vector3:
	if not anticipa:
		return Vector3.ZERO
	return _velocita(indice) * _tempo_intercettazione(indice, dist)

## La velocita' del nemico `indice`, **letta dal contratto** e non copiata: e'
## `horde.velocities`, array parallelo a `horde.transforms`, cioe' lo stesso canale
## che `_try_fire` legge gia' per la posizione e che `projectile_pool.gd` legge per
## le specie.
##
## ## Il ripiego e' `ZERO`, e perche' questo e' il ripiego che **non mente**
##
## Se il contratto non espone `velocities` (un'orda montata senza autoload) il
## canale non e' arrivato, e `ZERO` significa **«nessun anticipo»**: il
## comportamento di prima della legge. E' l'unico ripiego che non dichiara un
## numero che nessuno ha misurato — un ripiego che stimasse «quanto corre un
## nemico» scriverebbe qui una velocita' inventata, e i numeri che se ne
## ricavassero sarebbero inventati con lei. Avvisa **una volta sola**.
func _velocita(indice: int) -> Vector3:
	var horde: Node = Game.horde
	if horde == null:
		_avis_velocita()
		return Vector3.ZERO
	var v: Variant = horde.get("velocities")
	if not (v is PackedVector3Array):
		_avis_velocita()
		return Vector3.ZERO
	var vv: PackedVector3Array = v
	if indice < 0 or indice >= vv.size():
		return Vector3.ZERO
	return vv[indice]

var _warned_no_velocities := false

func _avis_velocita() -> void:
	if _warned_no_velocities:
		return
	_warned_no_velocities = true
	push_warning("weapon_base: l'orda non espone `velocities`, quindi l'arma **non anticipa** e spara dove il bersaglio e' adesso, non dove sara'. tocca a terminal-gun-orda esporre l'array parallelo a `transforms`.")

## ## m18: la velocita' richiesta dalla legge, e la formula per intero
##
##     v_proiettile  =  |v|_massimo  x  gittata  /  finestra_di_centro
##
## I tre numeri vengono **letti**, non scritti:
##
##   - `|v|_massimo` = massimo di `Enemy.SPEED`, la tabella delle velocita' delle
##     cinque specie (`6,6 m/s`, il runner). Il caso peggiore dichiarato e' un
##     altro e non e' questo: `Enemy.SPEED_MAX = 18,0 m/s`, il tetto della
##     velocita' combinata; con quello la velocita' richiesta sarebbe `276,9 m/s`.
##   - `gittata` = `acquire_radius`, il **campo** e non la costante, perche' un
##     potenziamento puo' allargarla e la legge deve accorgersene.
##   - `finestra_di_centro` = `pool.reach_minimo()`, cioe'
##     `RADIUS del proiettile + Game.enemy_body_scale * Enemy.RADIUS[runner]`: la
##     **minima** delle cinque finestre, perche' la legge vale per qualunque
##     bersaglio e non solo per il piu' grosso.
##
## ## Il ripiego, e perche' e' **il massimo dei tre** e non una costante
##
## Se un numero non e' leggibile il risultato sarebbe `0,0` — e `0,0` e' una
## velocita' che non esiste, cioe' un'arma che non spara mai. Quindi il ripiego
## prende **il massimo dei tre ingressi che sono arrivati**: e' l'unico valore che
## non dichiara un numero che nessuno ha misurato, e resta comunque una velocita'
## che il gioco puo' usare.
func _deriva_velocita() -> float:
	var v_max := velocita_massima_nemico()
	var gittata := acquire_radius
	var finestra := finestra_di_centro()
	if v_max <= 0.0 or gittata <= 0.0 or finestra <= 0.0:
		return maxf(v_max, maxf(gittata, finestra))
	return v_max * gittata / finestra

## Il massimo della tabella delle velocita' delle specie, **letto**. `-1,0` =
## la tabella non e' leggibile: e' il sentinel del canale, non una velocita'.
##
## ## Perche' e' pubblico
##
## Perche' e' uno dei **tre numeri della legge** e il test deve poterli leggere
## senza ricalcolarli da un'altra parte: un numero della legge che il test
## ricopia e' una copia che invecchia. Stessa ragione di `gittata()`.
func velocita_massima_nemico() -> float:
	var tabella: Variant = EnemyScript.SPEED
	if not (tabella is PackedFloat32Array):
		return -1.0
	var sp: PackedFloat32Array = tabella
	if sp.is_empty():
		return -1.0
	var massimo := 0.0
	for v in sp:
		massimo = maxf(massimo, float(v))
	return massimo

## La **finestra di centro**, cioe' il reach del nemico piu' piccolo: la chiede al
## pool, che e' l'unico che sa la meta' del proiettile e quella del nemico, e che la
## legge `Game.enemy_body_scale`. `-1,0` = il pool non c'e' ancora. Pubblica per lo
## stesso motivo di `velocita_massima_nemico()`.
func finestra_di_centro() -> float:
	if pool == null or not is_instance_valid(pool):
		return -1.0
	return float(pool.call("reach_minimo"))

## Implementazione di `Game.spawn_projectile` (piano §5.1, forma lunga).
## Restituisce `bool` dal §5.2: `true` se il pool ha ceduto uno slot. Non
## restituisce il record, perché nessuno nel progetto ha bisogno di un handle:
## tutto quello che serve del proiettile sta gia' nel pool.
func _spawn_projectile(pos: Vector3, dir: Vector3, speed: float) -> bool:
	if pool == null:
		return false
	return pool.acquire(pos, dir, speed) != null

## Da dove esce il colpo.
func muzzle_position() -> Vector3:
	return global_position + Vector3(0.0, MUZZLE_HEIGHT, 0.0)

## ## m12: la **gittata** come numero pubblico, e perche' `-orda` ne ha bisogno
##
## `ACQUIRE_RADIUS` (26,0 m) e' la gittata dell'arma, e **il punto di nascita dei
## nemici sul piano logico del giocatore deve stare dentro quel raggio**: altrimenti
## il giocatore spara verso il vuoto e la partita finisce a `14,77 s` invece che a
## `154 s`. Misurato sulla torre vera: `31,39 - 31,90 m` il nemico piu' vicino sul
## piano che l'arma interroga, `0` nemici entro `26,00 m`, `3,05 uccisioni/s` a
## regime, e `45` uccisioni in `886` passi prima che `hp` arrivi a `0`.
##
## Il numero **non** era leggibile da `-orda`: questo file usa l'identificatore
## globale `Game` (riga 168), che esiste solo con `--path .`, quindi
## `preload("res://src/weapons/weapon_base.gd")` da un test gira **senza progetto** e
## non compila. Per lo stesso motivo **non** c'e' un accessor `static`: se lo script
## non si carica, nessuna sua funzione si chiama. L'unica strada che resta e'
## l'**istanza viva**, ed e' la strada giusta per un'altra ragione: quello che serve
## a `-orda` e' la gittata **con cui l'arma spara davvero**, cioe' il campo
## `acquire_radius`, che un potenziamento puo' cambiare — la costante no.
##
## ## Perche' il nome non e' `acquire_radius()`
##
## Il campo `acquire_radius` (riga 123) occupa gia' quel nome, e in GDScript una
## funzione e un campo non possono omonimi: il nome che il vertice aveva ipotizzato
## non compila. Questo e' il nome da usare: **`gittata()`**.
func gittata() -> float:
	return acquire_radius

## Chiamato dal pool su ogni impatto: qui è il momento del "bonk".
func on_impact(_where: Vector3) -> void:
	impatti += 1
	if _sfx.is_empty() or _sfx_gap > 0.0:
		return
	_sfx_gap = IMPACT_SFX_GAP
	_suona_bonk()

## Suona l'impatto **prendendo uno slot** dal pool. Nessun nodo nasce qui: e' il
## punto intero del pool, ed e' la differenza rispetto alla forma che creava il
## nodo al momento del suono.
func _suona_bonk() -> void:
	var slot := _prendi_slot()
	# La guardia non e' paranoia: e' il buco che un `-1` di `_prendi_slot()`
	# aprirebbe. `_prendi_slot()` restituisce `-1` solo se il vettore delle
	# scadenze e' vuoto (nessuno slot costruito), e quel `-1`, usato come
	# indice, in Godot non e' «l'ultimo» ne' «nessuno»: e' un accesso fuori dal
	# vettore. Il valore e' possibile, quindi va fermato **qui**, dove si usa.
	if slot < 0:
		return
	if _sfx[slot].stream == null:
		# L'asset manca: nessun suono, e nessuno slot occupato da un silenzio.
		_sfx_scadenza[slot] = 0.0
		return
	_sfx[slot].play()
	_sfx_scadenza[slot] = _vita(_sfx[slot])
	sfx_emessi += 1

## Quale slot prendere: il primo libero, e se non ce n'è uno quello **che sta
## per finire prima** (la scadenza più piccola). Il ramo «nessuno libero» non
## cresce: non c'è un `while` e non c'è un nodo creato per farne uno libero.
func _prendi_slot() -> int:
	var vicino := -1
	for i in _sfx_scadenza.size():
		if _sfx_scadenza[i] <= 0.0:
			return i
		if vicino < 0 or _sfx_scadenza[i] < _sfx_scadenza[vicino]:
			vicino = i
	return maxi(vicino, 0)

## Quanto vive uno slot occupato: la lunghezza vera del suono più `SFX_SICUREZZA`.
## Un asset assente dà solo il margine.
func _vita(node: AudioStreamPlayer3D) -> float:
	if node.stream == null:
		return SFX_SICUREZZA
	return node.stream.get_length() + SFX_SICUREZZA

## `finished`: lo slot torna libero. `queue_free()` non c'è e non serve: il nodo
## del pool **non muore mai**, quindi qui non c'è niente da liberare e niente
## che possa lasciare un playback registrato nell'`AudioServer` — che è il
## difetto che questo pool chiude.
func _bonk_finito(slot: int) -> void:
	if slot < 0 or slot >= _sfx_scadenza.size():
		return
	_sfx_scadenza[slot] = 0.0

## La rete per `finished` che non arriva. Gira da `step()`, e non da
## `_exit_tree()`: a `_exit_tree()` il nodo è già fuori dall'albero e `stop()`
## fa un return anticipato.
func _chiudi_bonk_scaduti(delta: float) -> void:
	for i in _sfx_scadenza.size():
		if _sfx_scadenza[i] <= 0.0:
			continue
		_sfx_scadenza[i] -= delta
		if _sfx_scadenza[i] <= 0.0:
			_sfx_scadenza[i] = 0.0

## Libera subito **tutti** gli slot del pool. Non è un suono che si ferma: è il
## tempo che il suono occupa lo slot che si rimette a zero, quindi il suono
## **finisce di suonare** e lo slot torna libero come dopo `finished`.
func chiudi_suoni() -> void:
	for i in _sfx_scadenza.size():
		_sfx_scadenza[i] = 0.0

## Il pool di `bonk`: `SFX_POOL` nodi, presi dalla scena se ci sono.
##
## Un nodo che la scena non porta viene creato qui, in `_ready()`, e solo qui:
## durante la partita nessun nodo nasce. Lo slot 0 è il nodo `Sfx` che
## `scenes/player.tscn` porta già, quindi nella scena vera il pool lo riusa e
## **il totale dei nodi non cambia**.
func _costruisci_pool() -> Array[AudioStreamPlayer3D]:
	var slots: Array[AudioStreamPlayer3D] = []
	for i in SFX_POOL:
		var nome := NOME_SFX if i == 0 else NOME_SFX + str(i)
		var node := get_node_or_null(nome) as AudioStreamPlayer3D
		if node == null:
			node = AudioStreamPlayer3D.new()
			node.name = nome
			add_child(node)
		if node.stream == null:
			node.stream = _stream(SFX_IMPACT)
		node.finished.connect(_bonk_finito.bind(i))
		slots.append(node)
	return slots

## Chiamato dal pool quando `Game.damage_enemy` ha risposto che il nemico è
## morto. È l'unica strada dell'XP: nessuna euristica sul conteggio dell'orda.
func on_kill() -> void:
	if player != null:
		player.on_enemy_killed()

static func _stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var res = load(path)
	return res as AudioStream

## NOTA PER IL VERTICE (piano §5.3): l'identificatore nudo `Game` qui funziona,
## e il sospetto "non risolve sotto `--script`" va riformulato. Non è il
## **contesto** a decidere (nessuno dei miei usi è in `static func`, `const`,
## annotazione di tipo o `class_name`): è **quando** lo script viene compilato.
## Un `const preload` in testa al test risolve i suoi script a tempo di
## compilazione, PRIMA che `Main` aggiunga gli autoload al nome globale, e a quel
## punto l'identificatore non è ancora registrato. Caricando gli stessi script a
## runtime (`load()` dentro `_process`, dopo il primo frame) l'identificatore c'è
## e i miei file compilano senza nessun `_contract()`.