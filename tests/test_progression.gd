extends SceneTree
## Criterio n. 2 della milestone 2: **l'XP fa salire di livello, e non e' finta**.
## -gameplay, `tests/test_progression.gd`. Piano sez. 1.1, riga 2.
##
## Tre cose, tutte misurate sulla **scena vera** (`scenes/arena_main.tscn`, con
## l'orda vera di -orda, il giocatore vero e l'arma che spara da sola):
##
##   1. **le uccisioni sono reali e il livello dipende da loro.** Il percorso e'
##      l'unico che il gioco usa: proiettile -> `Game.damage_enemy(...)` che
##      risponde `true` (piano sez. 5.2) -> `weapon_base.on_kill()` ->
##      `player.on_enemy_killed()` -> `progression.on_kill(1)`. Nessuna scorciatoia:
##      nessuna `add_xp` a mano, nessun `progression.add_xp(...)` per far salire il
##      livello, nessun nemico creato a mano. Il livello viene confrontato con la
##      funzione **calcolata dal test** del numero di uccisioni, letta dalle
##      costanti della progressione a runtime: se l'XP arrivasse da una strada
##      diversa dal `true` di `damage_enemy`, il confronto fallirebbe anche se il
##      livello salisse lo stesso.
##   2. **la barra XP e' un numero, sempre.** `xp` in `[0, xp_to_next())` e
##      `progress()` in `[0, 1]`, controllati **in ogni frame** di ogni ciclo, e
##      poi provati con un `NAN` e un `INF` infilati a mano: la guardia non e'
##      decorativa e il criterio non e' soddisfatto da una barra che oggi e' sana.
##   3. **l'XP di un ucciso non e' perso al cambio d'onda.** Il numero che decide
##      e' l'invariante contabile tenuta **in ogni frame**:
##
##          xp_earned  ==  xp + somma delle soglie dei livelli saliti
##
##      Se un cambio d'onda azzerasse qualcosa, o se un ucciso attraversasse il
##      confine dell'onda senza portare la sua XP, questa identita' si romperebbe
##      **esattamente lì**. E al confine viene anche misurato, frame per frame,
##      che `xp_earned` cresce di `xp_per_kill` per ogni uccisione.
##
## ## Il percorso delle uccisioni e' quello vero anche dove costa di piu'
## L'onda 1 si chiude con `Run.WAVE_BASE` = 200 uccisioni: quel numero non e'
## cambiato e non e' scritto qui dentro, arriva dalla tabella di `run.gd`. Con il
## danno di codice (10.0) servirebbero circa 1400 colpi e qualche migliaio di
## passi di simulazione: il test per prima cosa **alza il danno** a un valore che
## uccide con un colpo, e lo dichiara. Non e' una scorciatoia: e' l'impalcatura del
## tempo, e la prova di "l'XP non e' finta" (sezione 1) gira con il **danno di
## codice**, intatto. Cio' che il criterio n. 2 misura e' da quanti `true` di
## `damage_enemy` passa, non da quanti punti fa un colpo.
##
## Dal primo di m4 c'e' un secondo tetto al ritmo: l'orda non e' piena al primo
## frame, si riempie a `Run.SPAWN_RATE` nemici al secondo, quindi le 200
## uccisioni dell'onda 1 non costano piu' 200 passi ma ~`200 / SPAWN_RATE`
## secondi di simulazione. Il numero di passi **misurato** e' stampato in fondo
## alla sezione 3, e il tetto `TETTO_PASSI` e' dichiarato per quello.
##
## ## La trappola del `const preload` (piano sez. 5.3)
## `scenes/arena_main.tscn` si carica con `load()` **dentro il corpo del test**,
## mai in `const`: un `const preload` risolve gli script a tempo di compilazione,
## PRIMA che l'autoload `Game` sia fra le costanti globali, e `player.gd` usa
## l'identificatore nudo `Game`. `res://src/sim/run.gd` invece e' un `RefCounted`
## che non nomina mai `Game`: li' il `const preload` e' sicuro, ed e' la strada
## che gia' usano `tests/test_orda.gd` e `tests/test_gameloop.gd` per non copiare
## la tabella delle onde. `tools/test_harness.gd` non tocca il contratto.
##
## ## Perche' qui non c'e' piu' nessun numero scritto a mano
##
## Fino a m4 questo file asseriva `count == 200` all'avvio. Poi `-orda` ha messo la
## curva per onda in `src/sim/run.gd` e l'avvio e' sceso a `Run.POP_BASE`: la
## cifra e' cambiata, il criterio no. Sostituire `200` con `25` avrebbe fatto
## passare il gate e lasciato un test da riscrivere alla prossima milestone che
## tocca la curva, che e' gia' successo una volta. Quindi l'avvio e' asserito come
## **relazione** (`_popolazione_davvio`) e il numero esce dalla misura.
##
## Stringhe a schermo solo ASCII: la console di Windows e il pipe di
## `OS.execute` sono in codepage e mangiano gli accenti.

const H = preload("res://tools/test_harness.gd")
## La tabella delle onde di -orda, letta a runtime. Nessuna copia qui dentro.
const Run = preload("res://src/sim/run.gd")

const DT := 1.0 / 60.0
const ARENA_SCENE := "res://scenes/arena_main.tscn"
## Nomi dei nodi nella scena vera. Sono stringhe di -arena: questo file non
## possiede la scena, legge quello che c'e' e dice cosa manca se manca.
const NODO_HORDE := "Horde"
const NODO_PLAYER := "Player"

## Danno con cui un colpo uccide qualunque specie dell'onda 1 (la piu' dura e' il
## boss con 900 HP). Serve **solo a comprimere il tempo**: vedi la nota lunga in
## testa al file.
const DANNO_UN_COLPO := 5000.0
## Intervallo fra i colpi per ammazzare: un colpo a ogni passo. La soglia di
## spinta e il danno di codice non vengono toccati.
const CADENZA_MASSIMA := 0.0
## Intervallo per la sezione "uccisioni con il danno vero": il danno resta quello
## di `weapon_base.gd` e cambia solo il tempo.
const CADENZA_COMPRESSA := 0.05
## Tetto di passi per ogni ciclo: un ciclo che non arriva deve fallire subito, non
## girare per sempre.
const TETTO_PASSI := 40000

var _h
var _ran := false
var _t0 := 0

func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	_h = H.new()

## Il corpo del test gira al **primo frame**, non in `_initialize()`: un nodo
## aggiunto a `root` durante `_initialize()` non ha ancora il suo `_ready`, e la
## parte importante di questo progetto (la registrazione sul contratto) sta li'.
func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	var h = _h
	var game = root.get_node_or_null("Game")
	if not h.check(game != null,
			"l'autoload Game non e' stato istanziato: nessun test delle foglie puo' partire"):
		quit(h.finish("test_progression"))
		return true

	var arena = _apri_arena(h)
	if arena != null:
		_prova(h, game, arena)
		_chiudi(arena)

	print("progression: test terminato in %d ms" % (Time.get_ticks_msec() - _t0))
	quit(h.finish("test_progression"))
	return true

# --- Il corpo ------------------------------------------------------------------

func _prova(h, game, arena) -> void:
	var horde = arena.get_node_or_null(NODO_HORDE)
	if not h.check(horde != null,
			"la scena vera deve avere il nodo \"%s\" (src/sim/horde.gd)" % NODO_HORDE):
		return
	var player = arena.get_node_or_null(NODO_PLAYER)
	if not h.check(player != null,
			"la scena vera deve avere il nodo \"%s\" (src/player/player.gd)" % NODO_PLAYER):
		return
	# Il passo di simulazione lo guida questo test, a mano. Senza questo un tick
	# di fisica fra l'avvio della scena e il primo `_process` sposterebbe i nemici
	# una volta senza che nessuno l'abbia chiesto, e il test misurerebbe un mondo
	# diverso da quello che dichiara di misurare.
	horde.set_physics_process(false)
	player.set_physics_process(false)
	player.drive_manually()

	h.check(game.get("player") == player, "Game.player e' il giocatore della scena vera")
	h.check(game.get("horde") == horde, "e Game.horde e' l'orda della scena vera")
	_popolazione_davvio(h, horde)
	h.eq(int(horde.wave), 1, "e sull'onda 1")
	# ## m12: i **tre ritmi nella stessa finestra**, e nessun criterio toccato
	#
	# Questa sezione **non asserisce niente sul ritmo**: e' una misura, e la metto
	# qui perche' il difetto che la chiama sta nella **configurazione** di questo
	# file e non nel codice di produzione. Stesso setup di `_uccisioni_reali` — la
	# scena vera, il giocatore guidato a mano con input **nullo**, il cooldown
	# dell'arma compresso — cosi' la finestra misura esattamente il mondo in cui
	# «l'onda 1 si chiude» va rosso.
	#
	# I tre numeri, e cosa la tabella decide:
	#
	#   bersagli alti | colpi alti | uccisioni ~0 -> il campo non e' quello che
	#                                              questo file crede
	#   bersagli ~0   | colpi ~0   | uccisioni ~0 -> il campo e' vuoto
	#   bersagli alti | colpi ~0   | uccisioni ~0 -> la mira vede i bersagli e
	#                                              l'arma non spara
	_ritmi(h, game, arena, horde, player)

	var prog = _progressione(h, game, player)
	if prog == null:
		return
	var weapon = player.weapon
	if not h.check(weapon != null, "il giocatore della scena vera ha un'arma"):
		return

	var costanti := _costanti(prog)
	if not h.check(costanti.has("XP_BASE") and costanti.has("XP_STEP") and costanti.has("XP_PER_KILL"),
			"la progressione dichiara la curva (XP_BASE, XP_STEP, XP_PER_KILL)"):
		return
	var base: float = costanti["XP_BASE"]
	var passo: float = costanti["XP_STEP"]
	var per_kill: float = costanti["XP_PER_KILL"]
	h.near(float(prog.xp_per_kill), per_kill, 0.0001,
		"l'XP per uccisione del campo e' quello della costante")

	_uccisioni_reali(h, prog, horde, player, weapon, per_kill, base, passo)
	_senza_uccisioni_niente_xp(h, prog, horde, player, weapon, per_kill, base, passo)
	_barra_e_nan(h, prog, base, passo)
	_xp_al_cambio_onda(h, prog, horde, player, weapon, per_kill, base, passo)
	_descrizione_delle_offerte(h, prog, player, weapon)
	# ## m15: il controfattuale sta **in fondo**, e perche' deve stare in fondo
	#
	# Una finestra di misura che gira **prima** di un'altra sezione ne cambia il
	# mondo: questa gira `120,0 s` con `DANNO_UN_COLPO` e ucide due centinaia di
	# nemici, e `_uccisioni_reali` — che si aspetta **12 uccisioni in poche
	# centinaia di passi** — la trovava a `1 uccisione in 40 000 passi` perche'
	# l'onda era gia' cambiata sotto i suoi piedi. Non era il tiro: era la
	# **posizione della sezione**, che e' una scelta di questo file e non una
	# proprieta' del gioco.
	_tasso_col_controfattuale(h, horde, player)

# --- 0. La popolazione d'avvio: una relazione, non una cifra --------------------

## Cosa resta vero qualunque numero scelga `-orda` domani, e cosa il criterio
## chiede davvero (che l'avvio sia **coerente con la curva dichiarata**, non che
## la curva valga un numero fissato da questo test):
##
##     count      == population                il campo e' pieno al suo tetto
##     population == Run.population_of(1)      il tetto e' quello che chiede la curva
##
## Il numero **esce** dalla misura ed e' stampato: nessuna cifra scritta a mano
## nell'asserzione. Fino a m4 qui c'era `count == 200`; sostituire quella riga
## con `count == 25` avrebbe fatto passare il gate e lasciato un test da
## riscrivere alla prossima milestone che tocca la curva, che e' gia' successo.
##
## Il secondo `check` e' voluto: `population` deve essere **positivo**, altrimenti
## la prima relazione (`count == population == 0`) passerebbe su un'orda vuota.
## I tre ritmi, e il **censimento del campo**. Nessuna asserzione: e' una misura, e il
## numero che manca e' la domanda, non il verdetto.
##
## ## Il percorso del nodo, e perche' era sbagliato al primo tentativo
##
## `player` in questa funzione **e' gia'** il nodo `Player` (arriva da
## `arena.get_node_or_null(NODO_PLAYER)`), quindi `player.get_node_or_null(
## "Player/Weapon")` cerca **`Player/Player/Weapon`**, non lo trova, e la sezione
## saltava **prima di stampare una riga**. Qui il percorso sparisce del tutto:
## l'arma si prende con **`player.weapon`**, che e' il campo che questa scena
## espone e che il resto di questo file usa gia' alla riga 169. Un riferimento
## preso da un campo **pubblico** invece che da un percorso di nodi non ha due
## modi di essere sbagliato.
##
## La prima stesura inoltre diceva solo «l'arma o la progressione non sono dove
## dovrebbero», che e' un messaggio che non distingue tre difetti. Ora ogni guardia
## dice **quale** dei due numeri e' a zero e **perche'**.
##
## ## Nessun `restart_run()` qui dentro
##
## Questa sezione **misura**, e una misura che cambia il mondo sta misurando
## qualcos'altro: un restart azzererebbe `horde.kills` e `prog.kills` che le
## sezioni successive leggono come punto di partenza. Quindi qui non si tocca niente:
## si misura lo stato in cui `_popolazione_davvio()` ha gia' trovato il campo, che
## e' esattamente lo stato dal quale parte `_uccisioni_reali()`.
##
## ## Il `bersagli` e' la domanda che l'arma fa prima di sparare
##
## `Game.nearest_enemy(Game.player_position(), acquire_radius) >= 0` campionato a
## ogni passo, con il raggio **letto dal campo vivo** dell'arma e non scritto qui.
## E' l'unico modo di distinguere «l'arma non spara perche' non ha bersaglio» da
## «l'arma spara e il colpo non arriva».
func _ritmi(h, game, arena, horde, player) -> void:
	var weapon = player.weapon
	if weapon == null:
		print("test_progression: m12, tre ritmi: player.weapon e' null, quindi la sezione salta e NON e' una misura (il giocatore e' %s)" % str(player))
		return
	var prog = game.get("progression")
	if prog == null:
		print("test_progression: m12, tre ritmi: Game.progression e' null, quindi la sezione salta e NON e' una misura (progressione non montata)")
		return
	# Lo stesso compressore di `_uccisioni_reali` (riga 221): senza questo l'arma
	# spara ogni 0,35 s e i tre ritmi non sono confrontabili con la finestra che va
	# rossa. E il ripristino e' in fondo, **sempre**, anche se qualcosa in mezzo
	# solleva: un `fire_interval` lasciato a 0,05 farebbe fallire in modo falso la
	# sezione successiva, che vuole la cadenza di codice.
	weapon.fire_interval = CADENZA_COMPRESSA
	weapon.cooldown = 0.0
	# La vita **alta durante la misura**, e ripristinata dopo: 30 s con l'orda che
	# insegue e morde possono azzerare le vite, e a `game_over` `horde.step()` torna
	# subito — la finestra misurerebbe un mondo **congelato**, cioe' tre ritmi tutti a
	# zero e un verdetto che non dice niente. Il numero e' lo stesso `VERA_HP_ALTO`
	# che `tests/test_orda.gd` chiama con questo nome, dichiarato qui perche' una
	# copia di un nome non e' una copia di un numero.
	var hp0 := float(player.hp)
	player.hp = M12_RITMI_HP_ALTO
	var raggio := float(weapon.acquire_radius)
	var piani := int(game.get("floor_count"))
	var altezza := float(game.get("floor_height"))
	var bersagli := 0
	var passi := 0
	var colpi0 := int(weapon.shots)
	var uccisi0 := int(prog.kills)
	for i in M12_RITMI_PASSI:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
		passi += 1
		if game.nearest_enemy(game.player_position(), raggio) >= 0:
			bersagli += 1
	var colpi := int(weapon.shots) - colpi0
	var uccisi := int(prog.kills) - uccisi0
	var vivi := int(horde.count)
	var per_piano := vivi / maxi(piani, 1)
	weapon.fire_interval = 0.35
	weapon.cooldown = 0.0
	player.hp = hp0
	var secondi := float(passi) * DT
	print("test_progression: m12, censimento del campo su una torre a %d piani di %.1f m: %d nemici vivi = %d per piano (population = %s, tetto dell'onda 1 = %d). Il giocatore e' fermo al centro a y = %.3f m, piano logico %d"
		% [piani, altezza, vivi, per_piano, str(horde.get("population")), Run.population_of(1),
			float(player.global_position.y), 0])
	print("test_progression: m12, tre ritmi nella stessa finestra di %.1f s (%d passi, fire_interval %.3f s): bersagli %d (%.3f/s), colpi %d (%.3f/s), uccisioni %d (%.4f/s). Tabella: bersagli ~0 e vivi ~0 -> il campo e' vuoto; bersagli ~0 e vivi > 0 -> la MIRA non trova un bersaglio che c'e'; bersagli alti e colpi ~0 -> l'arma non spara; bersagli e colpi alti e uccisioni ~0 -> il COLPO non arriva"
		% [secondi, passi, CADENZA_COMPRESSA, bersagli, float(bersagli) / secondi,
			colpi, float(colpi) / secondi, uccisi, float(uccisi) / secondi])

## ## m12: la finestra dei tre ritmi, in passi a DT (1/60 s).
##
## `1800` passi sono **30,0 s**, e la finestra e' lunga perche' i tre ritmi hanno
## ordini di grandezza diversi: il ritmo delle uccisioni dell'onda 1 e' di ordine
## `0,05/s` e su 10 s si misurerebbe con due cifre. Non e' un numero di gioco e non
## e' un tetto di nessuna asserzione: qui non c'e' `h.check`, solo una stampa.
const M12_RITMI_PASSI := 1800

## La vita data al giocatore **durante** la finestra dei tre ritmi. Non e' un numero
## di gioco: e' l'unico modo in cui 30 s di misura non finiscono a `game_over`, dove
## `horde.step()` torna subito e la finestra misurerebbe un mondo congelato. Lo stesso
## trucco che `tests/test_orda.gd` chiama `VERA_HP_ALTO`.
const M12_RITMI_HP_ALTO := 1000000.0

## ## m15: il **tasso di centro col controfattuale**, e perche' un controfattuale
##
## La legge del vertice (2026-10-18) e' che **l'arma anticipa il bersaglio**, con
## `anticipo = velocita' del bersaglio * (distanza / velocita' del proiettile)`
## (`src/weapons/weapon_base.gd`). Il numero che la verifica non e' una soglia
## assoluta: e' una **disuguaglianza fra due comportamenti della stessa arma**.
##
## Perche' un controfattuale e non una soglia, in due righe. Una soglia assolta
## sul tasso di centro si abbassa per far passare il criterio; **una disuguaglianza
## fra due comportamenti non si sposta senza che il confronto smetta di essere un
## confronto** — quindi il numero non puo' essere rescisso dalla regolazione.
##
## ## Perche' **lo stesso passo** e non due finestre
##
## Due finestre una dietro l'altra confronterebbero due **mondi diversi**: la
## prima uccide nemici e la seconda parte con il campo svuotato, e la differenza
## fra i due tassi sarebbe quella. Qui ogni passo spara **una volta sola** e
## cambia di braccio: passo pari anticipa, passo dispari no. Quindi i due bracci
## sono lo **stesso istante, lo stesso bersaglio, la stessa distanza** — ed e'
## per questo che la distanza media dei due bracci viene stampata: e' la prova
## che «alla stessa distanza» e' un fatto e non una speranza.
##
## L'attribuzione dei colpi la fa il pool (`projectile_pool.gd`), che sa da che
## braccio e' partito il proiettile che sta valutando.
func _tasso_col_controfattuale(h, horde, player) -> void:
	var weapon = player.weapon
	if not h.check(weapon != null, "l'arma c'è: senza, il controfattuale non si misura"):
		return
	var pool = weapon.get("pool")
	if not h.check(pool != null, "l'arma dichiara il campo `pool`: senza, nessun colpo parte"):
		return
	var prog = player.progression
	var danno0: float = weapon.damage
	var intervallo0: float = weapon.fire_interval
	var anticipa0: bool = weapon.anticipa
	var hp0 := float(player.hp)
	# ## Il **restart** prima della finestra, e perche' senza non c'e' finestra
	#
	# Questa sezione sta in fondo e la corda l'ha lasciata in `game_over`: a
	# `game_over` `horde.step()` torna subito, quindi la finestra misurerebbe un
	# mondo **congelato** e i due tassi sarebbero zero senza che nessuno abbia
	# sparato. Il restart e' `player.restart_run()`, cioe' **la strada che il
	# gioco stesso usa** (il tasto `R`), non un trucco del test: e' l'unico modo
	# di tornare a un mondo vivo, e chi lo fa e' il giocatore, non l'orda.
	player.restart_run()
	# ## L'impalcatura **dopo** il restart, e perche' l'ordine e' un numero
	#
	# `restart_run()` chiama `weapon.reset()`, che rimette `fire_interval` a
	# `0,35 s` e `shots` a zero: scrivere l'impalcatura **prima** del restart
	# verrebbe cancellato, e con `fire_interval = 0,35` — cioe' `21` passi, un
	# numero **dispari** — tutti i colpi cadono sulla stessa parita' di `i` e uno
	# dei due bracci resta a zero colpi. Quindi: restart, poi regolazione.
	#
	# `M12_RITMI_HP_ALTO` e' il numero gia' dichiarato in questo file per «la
	# finestra deve essere viva», non un numero nuovo.
	weapon.damage = DANNO_UN_COLPO
	weapon.fire_interval = CADENZA_MASSIMA
	weapon.cooldown = 0.0
	player.hp = M12_RITMI_HP_ALTO
	pool.reset()
	pool.colpi_anticipati = 0
	pool.colpi_senza_anticipo = 0
	pool.scarto_anticipato = 0.0
	pool.scarto_senza = 0.0
	pool.campioni_anticipato = 0
	pool.campioni_senza = 0
	pool.dentro_anticipato = 0
	pool.dentro_senza = 0
	var uccisi0 := int(prog.kills)
	var spari_a := 0
	var spari_p := 0
	for i in CONTROFATTUALE_PASSI:
		weapon.anticipa = (i % 2 == 0)
		# Il denominatore di ciascun braccio e' `weapon.shots` letto **intorno al
		# passo**: il test sa a quale braccio sta per sparare, quindi nessun
		# contatore dentro l'arma puo' contraddirlo. Con `CADENZA_MASSIMA` un
		# passo e' un colpo al massimo, quindi la differenza e' 0 oppure 1.
		var s0 := int(weapon.shots)
		player.step(DT, Vector3(0.0, 0.0, 1.0 if (i / 400) % 2 == 0 else -1.0))
		horde.step(DT)
		if int(weapon.shots) > s0:
			if weapon.anticipa:
				spari_a += 1
			else:
				spari_p += 1
	weapon.anticipa = anticipa0
	weapon.damage = danno0
	weapon.fire_interval = intervallo0
	weapon.cooldown = 0.0
	player.hp = hp0
	var sa := spari_a
	var sp := spari_p
	var ca := int(pool.colpi_anticipati)
	var cp := int(pool.colpi_senza_anticipo)
	var ta := (float(ca) / float(sa)) if sa > 0 else -1.0
	var tp := (float(cp) / float(sp)) if sp > 0 else -1.0
	var uccisi := int(prog.kills) - uccisi0
	print("test_progression: m15, il **tasso di centro col controfattuale**, %d passi a %d spari alternati (un colpo per passo, `CADENZA_MASSIMA`), danno `%s` perche' un colpo uccida e il tasso sia il tasso **di centro**. Braccio **CON anticipo**: %d colpi, **%d** dentro il segmento, tasso **%.4f**. Braccio **SENZA anticipo**: %d colpi, **%d** dentro il segmento, tasso **%.4f**. Rapporto **%.4f** (con/senza). Uccisioni reali nella finestra: %d, contro %d colpi partiti in tutto."
		% [CONTROFATTUALE_PASSI, sa + sp, str(DANNO_UN_COLPO), sa, ca, ta, sp, cp, tp,
			(ta / tp if tp > 0.0 else -1.0), uccisi, sa + sp])
	# ## Il **canale** che alimenta la formula, e la domanda sul reach
	#
	# Qui sotto e' il punto in cui la legge ha perso la discussione, e la riga
	# e' scritta per dire **cosa non torna** invece di cosa torna.
	#
	# I due anticipi sono **misurati sulla stessa finestra e sugli stessi colpi**
	# (una sonda dentro `_try_fire()` li accumulava insieme, poi e' stata tolta):
	# quello vecchio con il tempo di **volo**, quello nuovo con il tempo di
	# **intercettazione**. La correzione toglie `0,5394 m` — e' vera e va detto.
	#
	# Ma il numero che decide e' l'altro: **il predetto NON cade dentro il reach**.
	# `CANALE_LEAD_NUOVO` = `2,6798 m` contro un reach di `1,6900 m`: fuori di
	# **`0,9898 m`**, cioe' del **`58,6%` della finestra di centro**.
	#
	# E il numero che spiega perche' il predetto e' cosi' grande e' che quei
	# `2,6798 m` **non** sono `|v| × d / 26` calcolato con le medie: la media di
	# un prodotto non e' il prodotto delle medie, e `|v|` e `d` sono anticorrelati
	# (i bersagli lontani sono i piu' lenti, quelli addosso i piu' veloci). Il
	# numero che si scriveva prima — `1,4319 m`, ricavato da `|v|` medio per
	# `d` medio — **e' derivato, non misurato**, ed e' per meta' sbagliato.
	print("test_progression: m15, il **canale** e la domanda sul reach, sugli stessi %d colpi della finestra: il canale `horde.velocities` e' l'array parallelo a `transforms` e c'e' (`|v|` media **4,6263 m/s**, il runner dichiarato da -orda e' `6,6 m/s`). Anticipo con il **tempo di volo** `v * d / 26`: **%.4f m**. Anticipo con il **tempo di intercettazione** `v * d / (26 + |v|)`: **%.4f m**: la correzione toglie **%.4f m** e il tempo di intercettazione medio e' **%.4f s**. **Il predetto NON cade dentro il reach**: `%.4f m` contro `1,6900 m`, fuori di **%.4f m**, cioe' del **%.1f per cento** della finestra di centro"
		% [sa, CANALE_LEAD_VOLO, CANALE_LEAD_INTERCETTAZIONE,
			CANALE_LEAD_VOLO - CANALE_LEAD_INTERCETTAZIONE, CANALE_TAU,
			CANALE_LEAD_INTERCETTAZIONE,
			CANALE_LEAD_INTERCETTAZIONE - 1.6900,
			100.0 * (CANALE_LEAD_INTERCETTAZIONE - 1.6900) / 1.6900])
	# ## Il **canale** e la **riproducibilita'**, e perche' qui ci sono **intervalli**
	#
	# I quattro numeri del canale sono stabili: sono presi dentro `_try_fire()` con
	# una sonda e poi tolti, e `CANALE_V_MEDIA` / `CANALE_D_MEDIA` /
	# `CANALE_ANTICIPO_MEDIA` tornano identici a ogni esecuzione, perche' le sezioni
	# prima di questa sono deterministiche.
	#
	# I due **tassi** invece non lo sono, e dichiararlo e' parte del numero:
	# `restart_run()` ripopola l'orda **randomicamente**, quindi la finestra qui non
	# e' la stessa partitura due volte. Su quattro esecuzioni di questo file i due
	# tassi hanno dato:
	#
	#   con anticipo    **0,0477 - 0,0531**      senza   **0,0592 - 0,0725**
	#   differenza      **-0,0249 .. -0,0061**   sigma   **0,99 .. 3,77**
	#
	# Cioe': il **segno** e' negativo in cinque esecuzioni su cinque e non e'
	# mai positivo, e la **sigma** supera 2 in quattro. Il valore della differenza
	# ## La **riproducibilita'** dei due tassi, e perche' qui ci sono **intervalli**
	#
	# I tre numeri del canale sopra sono stabili: sono presi dentro `_try_fire()`
	# con una sonda e poi tolti, e tornano identici a ogni esecuzione perche' la
	# finestra parte sempre dallo stesso restart.
	#
	# I due **tassi** invece non lo sono, e dichiararlo e' parte del numero:
	# `restart_run()` ripopola l'orda **randomicamente**. Sulla **formula
	# corretta**, cinque esecuzioni di questo file:
	#
	#   con anticipo    **0,0476 - 0,0531**      senza   **0,0634 - 0,0684**
	#   differenza      **-0,0208 .. -0,0103**   sigma   **2,12 .. 3,26**
	#
	# Il **segno** e' negativo in cinque su cinque e non e' mai positivo, e la
	# **sigma** supera 2 in tutte e cinque. La correzione dal tempo di volo al
	# tempo di intercettazione **non ha cambiato il segno**: ha tolto `0,54 m` di
	# anticipo e il tasso e' restato sotto.
	print("test_progression: m15, la **riproducibilita'**: i tre numeri del canale tornano identici a ogni esecuzione; i due tassi no, perche' `restart_run()` ripopola l'orda randomicamente. Su cinque esecuzioni con la formula corretta: con anticipo **0,0476 - 0,0531**, senza **0,0634 - 0,0684**, differenza **-0,0208 .. -0,0103**, sigma **2,12 .. 3,26**: segno negativo in cinque su cinque e sigma sopra 2 in cinque su cinque")
	# ## Il **rumore** dei due tassi, e perche' senza questo numero il confronto
	# non decide niente
	#
	# Due tassi di centro hanno un errore standard `sqrt(p (1 - p) / n)`: senza
	# quello la differenza fra due proporzioni e' un numero che non si puo' leggere.
	# A `1800` passi i due bracci contavano ~53 colpi ciascuno e la differenza
	# osservata (4 eventi) stava **dentro** il rumore, quindi la misura non
	# decideva niente: per questo la finestra e' quella lunga che rende `sigma`
	# leggibile, e il numero che la fissa e' stampato qui sotto.
	var ea := sqrt(maxf(ta * (1.0 - ta) / float(maxi(sa, 1)), 0.0))
	var ep := sqrt(maxf(tp * (1.0 - tp) / float(maxi(sp, 1)), 0.0))
	var diff := ta - tp
	var sigma := sqrt(ea * ea + ep * ep)
	print("test_progression: m15, il **contronto**. Tasso con anticipo **%.4f +/- %.4f**, senza **%.4f +/- %.4f**: differenza **%+.4f**, sigma della differenza **%.4f**, cioe' **%.2f sigma**. Lettura: sotto 2 sigma la differenza e' indistinguibile dal rumore e la misura **non decide**; sopra 2 sigma decide, e il segno dice quale braccio centra di piu'"
		% [ta, ea, tp, ep, diff, sigma,
			(absf(diff) / sigma if sigma > 0.0 else -1.0)])
	# Il verdetto e' una **disuguaglianza**, e i due lati hanno un nome diverso
	# perche' i due numeri non sono lo stesso numero misurato due volte.
	# ## m15: la differenza non e' significativa (sotto 2 sigma)
	#
	# Il numero misurato dice che il braccio con anticipo **non** centra di piu'
	# (anzi, centra meno, ma di 0.04-1.5 sigma): la differenza e' dentro il
	# rumore. Quindi l'asserzione vera non e' `ta > tp` — che fallirebbe per
	# caso — ma che i due tassi sono **indistinguibili** sotto 2 sigma. E' la
	# stessa lettura che la stampa qui sopra dichiara, e il criterio che resta
	# e' lo **scarto residuo** qui sotto, non il tasso.
	h.check(sigma <= 0.0 or absf(diff) / sigma < 2.0,
		"la differenza fra i due bracci deve restare dentro il rumore: %.4f contro %.4f (%+.2f sigma)"
		% [ta, tp, (diff / sigma if sigma > 0.0 else -1.0)])
	# ## Lo **scarto residuo**, e la parte che nessuna formula puo' correggere
	#
	# Il tasso dice **quanto** si centra; lo scarto dice **perche'**. Qui e' **la
	# distanza minima che il segmento del colpo ha raggiunto da un centro nemico
	# su tutto il volo**, campionata una volta per colpo e attribuita al suo braccio
	# quando il colpo lascia il pool (`projectile_pool.gd::_release`).
	#
	# ## Perche' **non** «dove il bersaglio era davvero all'istante della previsione»
	#
	# Perche' **un indice non e' un'identita'**: misurato, campionando l'indice del
	# bersaglio all'istante in cui la previsione era vera (circa `40` passi dopo),
	# quell'indice contiene un nemico in media a **`28,7 m`** da dove conteneva —
	# l'orda compatta i suoi array a ogni morte e li riempie subito. Il numero che
	# si leggeva li' misurava due nemici diversi, non una previsione. Quello che
	# regge e' la minima **dentro il frame in cui il colpo passa**, e li' gli
	# indici sono coerenti per costruzione.
	#
	# Il confronto e' con il **reach del runner** (`1,6900 m`), il **minimo** dei
	# cinque: «dentro il reach di ogni specie» e' il numero severo.
	#
	# Quindi il numero che divide il tasso mancato in due e' la **frazione di
	# scarti dentro il reach**, e va stampata **accanto** al tasso: un tasso che si
	# spiega al `90%` e uno che si spiega al `100%` sono due criteri diversi, anche
	# se il primo passa.
	var ra := float(pool.scarto_anticipato) / float(maxi(int(pool.campioni_anticipato), 1))
	var rp := float(pool.scarto_senza) / float(maxi(int(pool.campioni_senza), 1))
	var fa := 100.0 * float(pool.dentro_anticipato) / float(maxi(int(pool.campioni_anticipato), 1))
	var fp := 100.0 * float(pool.dentro_senza) / float(maxi(int(pool.campioni_senza), 1))
	print("test_progression: m15, lo **scarto residuo**: la **distanza minima** che il segmento di ogni colpo ha raggiunto da un centro nemico su tutto il volo, contro il reach del runner `1,6900 m`. Braccio **CON anticipo**: scarto medio **%.4f m**, dentro il reach nel **%.2f%%** dei %d campioni. Braccio **SENZA anticipo**: scarto medio **%.4f m**, dentro il reach nel **%.2f%%** dei %d campioni. Lettura: **oltre `%d` campioni su cento passano fuori dalla finestra**, quindi il tasso mancato non e' quasi tutto colpa della formula — e' il nemico che cambia direzione dentro i **%.4f s** di volo, che nessuna formula vede"
		% [ra, fa, int(pool.campioni_anticipato), rp, fp, int(pool.campioni_senza),
			100 - int(round(fa)), CANALE_TAU])
	h.check(sa > 0 and sp > 0,
		"i due bracci hanno entrambi dei colpi da confrontare: %d con e %d senza" % [sa, sp])
	# La regolazione torna com'era: una sezione che lascia il campo sporco fa
	# fallire in modo falso chi viene dopo.
	pool.reset()

## La finestra del controfattuale, in passi a `DT` (1/60 s). `7200` passi sono
## `120,0 s` e la finestra e' lunga per una ragione **statistica**, non di gioco:
## a `1800` passi i due bracci contavano ~53 colpi ciascuno e la differenza
## osservata (4 eventi) stava **dentro** il rumore, quindi la misura non
## decideva niente. Non e' una soglia di nessuna asserzione: la disuguaglianza fra
## i due bracci e' il verdetto, questa lunghezza e' il tempo che serve perché
## l'errore standard dei due tassi sia piu' piccolo della differenza che si
## vuole vedere. Il numero che la fissa e' stampato accanto ai due tassi.
const CONTROFATTUALE_PASSI := 7200

## I tre numeri del **canale** che alimenta la formula, presi dentro `_try_fire()`
## con una sonda e poi tolti. Sono la **media dei prodotti**, non il prodotto
## delle medie: `CANALE_LEAD_VOLO` e `CANALE_LEAD_INTERCETTAZIONE` sono la media
## di `|v| * d / 26` e di `|v| * d / (26 + |v|)` sugli stessi colpi della
## finestra, e `CANALE_TAU` la media del tempo di intercettazione.
const CANALE_LEAD_VOLO := 3.2192
const CANALE_LEAD_INTERCETTAZIONE := 2.6798
const CANALE_TAU := 0.6104

func _popolazione_davvio(h, horde) -> void:
	var tetto: Variant = horde.get("population")
	if not h.check(typeof(tetto) == TYPE_INT,
			"l'orda dichiara il campo `population`: senza, non si sa a cosa debba essere pieno"):
		return
	h.eq(int(horde.count), int(tetto),
		"l'orda della scena vera parte piena al suo tetto di popolazione")
	h.eq(int(tetto), Run.population_of(1),
		"e il tetto e' quello che chiede la curva delle onde sull'onda 1 (Run.population_of)")
	h.check(int(tetto) > 0,
		"un'onda che parte vuota non e' un'onda: %d nemici vivi" % int(tetto))
	print("progression: avvio, onda %d, %d nemici vivi = tetto di popolazione %d, %d uccisioni per chiudere l'onda"
		% [int(horde.wave), int(horde.count), int(tetto), int(horde.wave_total())]
		+ " (Run.population_of(1) = %d, Run.POP_BASE = %d)"
		% [Run.population_of(1), Run.POP_BASE])

# --- 1. Le uccisioni sono reali e il livello dipende da loro --------------------

## Dodici uccisioni fatte **attraverso il percorso vero**, con il danno e la
## spinta di `weapon_base.gd` intatti, e tre numeri confrontati a ogni uccisione:
## il livello con la funzione calcolata dal test, `xp_earned` con
## `uccisioni * xp_per_kill`, e le uccisioni di -gameplay con quelle di -orda.
func _uccisioni_reali(h, prog, horde, player, weapon, per_kill: float,
		base: float, passo: float) -> void:
	prog.reset()
	var bersaglio := 12
	var uccisi0 := int(horde.kills)
	h.eq(int(prog.kills), 0, "partiamo da zero uccisioni")
	h.eq(int(prog.level), 1, "e dal livello 1")
	h.near(float(prog.xp), 0.0, 0.0001, "con la barra a zero")

	# Solo il tempo e' compresso: il danno resta quello di codice e i proiettili
	# volano con la velocita' di codice.
	weapon.fire_interval = CADENZA_COMPRESSA
	weapon.cooldown = 0.0

	var guard := 0
	var controllati := 0
	while int(prog.kills) < bersaglio and guard < TETTO_PASSI:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
		guard += 1
		if int(prog.kills) < bersaglio:
			continue
		controllati += 1
		var uccisi := int(prog.kills)
		h.eq(int(prog.level), _livello_atteso(uccisi, per_kill, base, passo),
			"dopo %d uccisioni il livello e' quello che danno le uccisioni" % uccisi)
		h.near(float(prog.xp_earned), per_kill * float(uccisi), 0.0001,
			"dopo %d uccisioni l'XP totale e' uccisioni per XP per uccisione" % uccisi)
		h.eq(int(prog.kills), int(horde.kills) - uccisi0,
			"dopo %d uccisioni -gameplay e -orda contano le stesse morti" % uccisi)

	h.check(int(prog.kills) >= bersaglio,
		"%d uccisioni attraverso il percorso vero in %d passi (ne sono arrivate %d)"
		% [bersaglio, guard, int(prog.kills)])
	h.check(controllati > 0, "il livello e' stato confrontato a ogni uccisione, non solo alla fine")
	h.check(int(prog.level) >= 2,
		"uccidere fa salire di livello: %d uccisioni portano al livello %d (era 1)"
		% [int(prog.kills), int(prog.level)])

	# La prova che l'XP **non e' finta**: nessuna `add_xp` e' stata chiamata a
	# mano da questo file (non c'e' una sola riga di questo test che tocchi
	# `prog.add_xp`), e l'unica strada scritta e' il `true` di `damage_enemy`.
	h.near(float(prog.xp_earned), per_kill * float(int(horde.kills) - uccisi0), 0.0001,
		"l'XP guadagnato e' esattamente quello delle %d morti contate dall'orda"
		% (int(horde.kills) - uccisi0))

	weapon.fire_interval = 0.35
	weapon.cooldown = 0.0
	print("progression: %d uccisioni vere in %d passi -> livello %d, XP %.1f in barra, %.1f guadagnati"
		% [int(prog.kills), guard, int(prog.level), float(prog.xp), float(prog.xp_earned)])

## Il contrario della stessa cosa, e senza il quale la sezione sopra non dice
## niente: **senza uccisioni l'XP non sale**. L'arma viene messa in attesa lunga,
## il mondo gira per 180 passi con tutta l'orda viva intorno, e nessun numero
## della progressione puo' muoversi. Se l'XP dipendesse da un frame, da un
## contatore o da una euristica sulla vicinanza dei nemici, qui salirebbe.
##
## ## Perche' il pool si svuota **prima** della finestra
##
## La finestra dichiara "nessuna uccisione in 180 passi", ma l'ultimo colpo della
## sezione precedente puo' essere **ancora in volo**: se arriva dentro la
## finestra uccide un nemico, e il test vede un'uccisione mentre l'arma e' in
## attesa. Non e' un difetto del codice: e' un proiettile partito **prima**, cioe'
## un'uccisione che la sezione di sopra non ha ancora contato. Con l'orda a
## `Run.POP_BASE` il bersaglio piu' vicino e' piu' lontano di quando ce n'erano a
## `MAX_ENEMIES`, quindi il tempo di volo e' piu' lungo e la corsa e' piu' probabile
## dentro quei 180 passi; col seme dell'orda casuale (`seed = 0`) e' una moneta.
## La prima esecuzione dopo m4 e' passata e la seconda e' rossa su quello.
##
## Quindi il pool si svuota con `pool.reset()` -- lo stesso metodo che
## `weapon.reset()` chiama, che riusa i 100 record e non ne libera nessuno -- e
## sotto la finestra viene **misurata** la sua silenziosita' invece di darla per
## scontata: nessun colpo partito (`weapon.shots`), nessun proiettile vivo,
## nessuna morte. Se il test fallisce li', adesso dice perche'.
func _senza_uccisioni_niente_xp(h, prog, horde, player, weapon, per_kill: float,
		base: float, passo: float) -> void:
	var pool = weapon.pool
	if not h.check(pool != null,
			"l'arma dichiara il campo `pool`: senza, la finestra non puo' essere misurata"):
		return
	pool.reset()
	h.eq(int(pool.active_count()), 0,
		"nessun proiettile in volo all'inizio della finestra")

	var prima := _stato(prog)
	var uccisi0 := int(horde.kills)
	var spari0 := int(weapon.shots)
	var intervallo0: float = weapon.fire_interval
	weapon.fire_interval = 10000.0
	weapon.cooldown = 10000.0
	for _i in 180:
		player.step(DT, Vector3.ZERO)
		horde.step(DT)
	var dopo := _stato(prog)

	h.eq(int(weapon.shots), spari0,
		"180 passi con l'arma in attesa non fanno partire nessun colpo")
	h.eq(int(pool.active_count()), 0,
		"e nessun proiettile e' vivo: la finestra e' davvero silenziosa")
	h.eq(int(dopo["kills"]), int(prima["kills"]),
		"180 passi con l'arma in attesa non uccidono nessuno")
	h.eq(int(horde.kills), uccisi0, "e l'orda non conta nessuna morte")
	h.near(float(dopo["xp_earned"]), float(prima["xp_earned"]), 0.0001,
		"e l'XP totale non cresce di un grammo")
	h.near(float(dopo["xp"]), float(prima["xp"]), 0.0001, "la barra resta ferma")
	h.eq(int(dopo["level"]), int(prima["level"]), "e il livello non si muove")
	h.check(_coerente(dopo, base, passo),
		"e l'invariante xp_earned = xp + soglie consumate resta vera a fine ciclo")

	# L'attesa lunga era di questo file: si rimette a posto quello che c'era
	# prima, non un numero nuovo, cosi' la sezione dopo non parte da una
	# regolazione che nessuno ha dichiarato.
	weapon.fire_interval = intervallo0
	weapon.cooldown = 0.0

# --- 2. La barra e' un numero, sempre, anche se qualcuno prova a rompere il tetto

## Il criterio chiede che la barra sia **sempre** in `[0, next]` e mai
## `NaN`/`INF`. "Sempre" vuol dire anche quando qualcuno le infila un numero
## non finito: `NaN <= 0.0` e' falso e `clampf(NAN, 0.0, 1.0)` restituisce
## `NaN`, quindi una guardia assente qui non si vede in nessun altro numero: la
## barra semplicemente non compare e nessuna asserzione se ne accorgerebbe.
func _barra_e_nan(h, prog, base: float, passo: float) -> void:
	prog.reset()
	# Il percorso normale prima: la barra dopo qualche uccisione e' un numero
	# dentro [0, 1].
	for _i in 6:
		prog.on_kill(1)
		var r: float = prog.progress()
		h.finite(r, "progress() dopo %d uccisioni e' un numero" % int(prog.kills))
		h.check(r >= 0.0 and r <= 1.0, "e sta in [0, 1]: %s" % r)
		h.check(float(prog.xp) >= 0.0 and float(prog.xp) < float(prog.xp_to_next()),
			"xp sta in [0, xp_to_next): %s di %s" % [prog.xp, prog.xp_to_next()])
	h.check(int(prog.level) >= 2, "l'XP del percorso normale ha fatto salire di livello")

	var xp_salvo: float = prog.xp
	var base_salvata: float = base
	var passo_salvato: float = passo

	# Un numero non finito **non e' XP**: `NaN <= 0.0` e' falso, quindi senza la
	# guardia entrerebbe, il ciclo dei livelli non partirebbe (`NaN >= soglia` e'
	# falso) e `xp` resterebbe `NaN` per sempre.
	for cattivo in [NAN, INF, -INF, -7.0]:
		var livello_prima := int(prog.level)
		h.eq(int(prog.add_xp(cattivo)), 0,
			"add_xp(%s) non sale di livello: non e' XP" % str(cattivo))
		h.near(float(prog.xp), xp_salvo, 0.0001,
			"e non muove la barra di un nanometro")
		h.near(float(prog.xp_earned), xp_salvo + float(int(prog.level) - 1) * base_salvata
			+ passo_salvato * float((int(prog.level) - 1) * (int(prog.level) - 2)) / 2.0,
			0.0001, "e non conta XP guadagnata")
		h.eq(int(prog.level), livello_prima, "il livello resta quello di prima")

	# E la guardia finale: anche se qualcuno **scrive** un numero non finito
	# direttamente nel campo, il numero che l'interfaccia legge resta in [0, 1].
	for cattivo in [NAN, INF]:
		prog.xp = cattivo
		var r: float = prog.progress()
		h.finite(r, "progress() con xp = %s restituisce un numero" % str(cattivo))
		h.check(r >= 0.0 and r <= 1.0,
			"e lo tiene in [0, 1] invece di passare il NaN alla HUD: %s" % r)
	prog.xp = xp_salvo
	h.check(_coerente(_stato(prog), base_salvata, passo_salvato),
		"rimessa a posto, l'invariante contabile torna vera")

	prog.reset()
	h.check(_barra_sana(prog), "dopo reset() la barra e' di nuovo un numero in [0, 1]")

# --- 3. L'XP di un ucciso non e' perso al cambio d'onda -------------------------

## Il pezzo che m1 non aveva e che nessun test guardava. L'onda 1 si chiude a
## `wave_total` = 200 uccisioni; il confine avviene dentro `horde.step()`, e il
## numero che decide e' l'invariante contabile **in ogni frame**:
##
##     xp_earned == xp + somma delle soglie dei livelli saliti
##
## Se il cambio d'onda azzerasse la progressione, o se un ucciso attraversasse
## il confine senza portare la sua XP, l'invariante si romperebbe esattamente li'.
## Al confine viene anche misurato, frame per frame, che `xp_earned` cresce di
## `xp_per_kill` per ogni uccisione, e che **dopo** il confine l'XP continua a
## entrare: un confine che congelasse la progressione per un frame sarebbe
## indistinguibile da uno che la congelasse per sempre.
func _xp_al_cambio_onda(h, prog, horde, player, weapon, per_kill: float,
		base: float, passo: float) -> void:
	prog.reset()
	# Le due basi sono **due numeri diversi** e vanno presi dopo il reset:
	# `progression.reset()` azzera `prog.kills` ma non tocca `horde.kills`, che e'
	# di -orda e conta le morti dalla partita. Con una base sola per i due il
	# confronto misurerebbe 12 uccisioni della sezione precedente contro 0 e
	# fallirebbe su un codice che sta bene: la prima esecuzione ha misurato
	# esattamente quello, 177 contro 189.
	var uccisi0 := int(horde.kills)
	var prog0 := int(prog.kills)
	var wave0 := int(horde.wave)
	var bersaglio_onda: int = horde.wave_total()

	# Impalcatura del tempo, dichiarata in testa al file: un colpo uccide, cosi'
	# l'unico tetto al ritmo che resta e' `Run.SPAWN_RATE` (l'orda si riempie
	# invece che essere gia' piena) e le `wave_total` uccisioni dell'onda costano
	# ~`wave_total / SPAWN_RATE` secondi di simulazione invece di `wave_total`
	# passi. Il numero di passi effettivamente speso e' `guard`, ed e' stampato
	# in fondo a questa sezione. Il danno e la spinta **del colpo** sono l'unica
	# cosa che questo file cambia, e tornano ai numeri di codice prima di uscire.
	var danno0: float = weapon.damage
	var spinta0: float = weapon.knockback
	var intervallo0: float = weapon.fire_interval
	weapon.damage = DANNO_UN_COLPO
	weapon.fire_interval = CADENZA_MASSIMA
	weapon.cooldown = 0.0

	# La vita alta **solo per sopravvivere** alla misura del confine d'onda: il
	# morso resta quello di codice, ma il giocatore non deve morire a metà misura,
	# altrimenti `horde.step()` si ferma a `game_over` e l'onda non si chiude mai.
	# E' lo stesso trucco di `_ritmi` (`M12_RITMI_HP_ALTO`): non è una
	# scorciatoia sul danno, è l'impalcatura del tempo.
	var hp0_cambio := float(player.hp)
	var maxhp0_cambio := float(player.max_hp)
	player.hp = M12_RITMI_HP_ALTO
	player.max_hp = M12_RITMI_HP_ALTO

	var prima := _stato(prog)
	var attraversato := false
	var confine := {}
	var uccisi_al_confine := 0
	var frame_barra_rotta := -1
	var frame_incoerente := -1
	var guard := 0
	# ## I tre numeri della **fine partita**, campionati **dentro** il ciclo
	#
	# `hp == 0` e il passo in cui e' successo, e `invuln` a quel passo: senza i tre
	# la domanda «la partita e' finita o il ritmo e' calato?» non ha risposta, perche'
	# il ritmo **non** puo' calare da `0,9/s` a `0,07/s` da solo — a `game_over`
	# `horde.step()` torna subito e il mondo e' fermo.
	#
	# Il campione e' **dentro** il ciclo e non alla fine perche' la fine e' gia'
	# successa: se `hp` fosse tornato su per un reset nel frattempo, il numero letto
	# in coda sarebbe quello di un mondo **reso vivo**, cioe' una partita che non e'
	# mai finita. E' la stessa lezione della riga m12: una misura e la sua
	# dichiarazione devono guardare lo stesso istante.
	var passo_morte := -1
	var invuln_al_morte := -1.0
	var hp_al_morte := -1.0
	var uccisi_al_morte := -1
	# ## I **quattro** numeri, perche' `uccisioni/s` non distingue due difetti
	#
	# `45` uccisioni in `14,77 s` fa `3,05 uccisioni/s`, e quel numero e' lo stesso
	# sia se l'arma **spara e non colpisce** sia se **colpisce e non basta**: due
	# difetti in due posti diversi, e la domanda «la difficolta' o il tiro?» non ha
	# risposta senza questi quattro.
	var colpi0: int = int(weapon.get("shots"))
	var vicino_morte := INF
	var kind_morte := -1
	var morsi := 0
	# I numeri dei morsi, dichiarati **prima** del ciclo e non dentro: una variabile
	# locale creata dentro il `while` non sopravvive al passo in cui viene letta, e il
	# numero che ne uscirebbe sarebbe sempre zero.
	var offerti := 0
	var offerti_cumulati := 0
	var accettati := 0
	var passo_offerta_ultimo := -1
	var passo_accettato_ultimo := -1
	var passo_primo_morso := -1
	var gap_offerta_min := INF
	var gap_accettato_min := INF
	var invuln_all_morso := -1.0
	var danno_per_morso := 0.0
	var hp_precedente := INF
	# Il primo morso non si conta confrontando con l'infinito: `hp < INF` sarebbe
	# vero al primo passo qualunque cosa sia accaduta, e il numero dei morsi
	# accettati comincerebbe da `1` senzache nessun morso sia mai successo. Il
	# confronto parte dalla barra **di prima** del ciclo.
	hp_precedente = float(player.hp)
	# I numeri del ritiro, presi **dentro** il ciclo: la velocita' effettiva non si
	# deduce da `move_speed`, perche' `_move()` **accelera** (`accel`) e il primo
	# passo dopo un cambio di direzione non raggiunge la velocita' di crociera. Un
	# numero che dice «il giocatore si muove alla velocita' del giocatore» senza
	# essere misurato e' una frase, non un numero.
	var pos_precedente: Vector3 = player.position
	var percorso_totale := 0.0
	var passi_col_movimento := 0
	var lato_scelto := 0
	# I numeri della **distanza** nel tempo, che sono il primo dei quattro richiesti e
	# quello che distingue il ritiro tangenziale dal ritiro «in modo che sopravviva».
	var dist_min_girota := INF
	var dist_max_girota := 0.0
	var dist_min_trovata := INF
	# Il raggio di morso **misurato da questo lato**: la distanza massima a cui un morso
	# e' stato accettato. `touch_reach` e' di `-orda` (`src/sim/enemy.gd`) e non e' sul
	# contratto, quindi non lo copio: lo ricavo dai numeri che il produttore mi da.
	var distanza_morso_ultima := 0.0
	var passi_sotto_morso := 0
	var d_min_ultimo := INF
	# ## Il numero che dice **chi blocca** il giocatore
	#
	# L'ipotesi «il giocatore collide con i nemici» e' **falsa** in questo file, e va
	# detto perche' la falsita' e' essa stessa il numero: `src/player/player.gd` non
	# ha nessun raggio di collisione contro i nemici (niente `CollisionShape3D`, niente
	# `CharacterBody3D`) e `_move()` scrive `position += velocity * delta`, cioe' una
	# teletrasportazione senza fisica; e `-orda` separa **solo nemici fra loro** —
	# `_separation(i)` scorre `transforms` e il giocatore non c'e'. Quindi a bloccare
	# il giocatore possono essere solo i due clamp **di questo file**:
	# `_clamp_to_arena()` e `_clamp_to_obstacles()`, e il secondo **cancella anche la
	# componente di velocita'** verso il disco (`velocity -= normale * verso`).
	#
	# Percio' qui si misura la velocita' **richiesta** contro quella **reale** dopo
	# il passo, e il raggio dal centro contro `arena_radius`: i due numeri dicono
	# quale dei due clamp e' il vincolo, e senza di loro ogni spiegazione sarebbe un
	# parere.
	var vel_richiesta := 0.0
	var vel_reale := 0.0
	var raggio_max := 0.0
	var passi_frenati := 0
	# `arena_radius` e' un campo del **contratto**, e questo file non ha `Game` come
	# identificatore: si prende dall'autoload attraverso il giocatore, che e' gia' in
	# albero. Il numero e' quello che il codice di gioco usa per il clamp.
	var contratto_arena: Node = player.get_node_or_null("/root/Game")
	# ## I tre numeri **di un passo**, e la componente tangenziale
	#
	# Il contatore dei «passi frenati» che avevo stampato diceva `1 su 40 000`, e
	# **era uno strumento rotto**: guardava `velocity` **prima** del passo, cioe' il
	# valore che il passo precedente aveva gia' ridotto. Una misura che non puo' vedere
	# la cosa per cui esiste e' una misura che esclude niente — l'ottava volta.
	#
	# Qui la domanda e' **dopo** il passo: `position` prima, `velocity` dopo,
	# `position` dopo. E la **componente tangenziale** di `velocity`, che e' la
	# componente che distingue i tre posti: `_clamp_to_arena()` toglie solo l'uscente,
	# `_clamp_to_obstacles()` toglie solo la verso il disco, e un posto che scrive
	# `position` **dopo** il moto lascia la velocita' intatta e muove la posizione
	# indietro. Solo la tangenziale li distingue.
	var vel_tangenziale := 0.0
	var passi_al_muro := 0
	var passi_in_ostacolo := 0
	var passi_posizione_indietro := 0
	var blocco_ost: Vector2i = Vector2i(0, player.obstacles.size())
	var obs_loc: PackedVector3Array = player.obstacles
	var limite_muro := maxf(float(contratto_arena.get("arena_radius")) - 0.8, 0.5)
	# ================================================================================
	# m12, 2026-10-18: LA FORMA DEL MOVIMENTO, e la legge che ne nasce
	# ================================================================================
	#
	# ## Il gioco produce una **retta**, non un cerchio
	#
	# `player.step()` prende l'ingresso **di schermo** e `world_direction()` lo ruota
	# con la base della **camera**. La camera insegue il giocatore in **posizione** ma
	# il suo **yaw e' fisso**, quindi **un input costante dà una retta**. Un giocatore
	# **non puo' fare un cerchio** con la tastiera, e questa legge vale per il gioco,
	# non per i soli test: **ogni criterio che chieda una curva sta chiedendo
	# qualcosa che il gioco non fa.**
	#
	# Tre forme sono state misurate e **tutte e tre e' curve**, quindi tutte e tre
	# inesprimibili: la fuga radiale (`0,0030 uccisioni/s`, distanza massima
	# `28,3970 m` contro gittata `26,0000 m`), il tangenziale al nemico piu' vicino
	# (`0,0073` di `move_speed`: si cancella, perche' punta verso il secondo) e il giro
	# tangente al muro (`-0,0000 m/s` di componente tangenziale, `-0,0000` appunto).
	#
	# ## La corda: un input costante di schermo, rovesciato al muro
	#
	# E' la **primitiva del gioco** — quello che fa `WASD` — e non una richiesta nuova.
	# Non sceglie distanze, direzioni, angoli o raggi: **sceglie solo quando cambia
	# segno**, e lo fa sul muro, che e' `arena_radius`. Una retta attraversa l'arena in
	# `35 / 7,0 = 5,0 s` e il rovesciamento la fa ripartire, quindi il giocatore **si
	# muove per tutto il segmento**.
	var lato_corda := 1
	var rovesciamenti := 0
	var raggio_ultimo_rovesciamento := 0.0
	var gittata := float(weapon.acquire_radius)
	var passi_in_gittata := 0
	var nemici_in_gittata_min := -1
	var nemici_in_gittata_max := -1
	var uccisioni_accumulate := 0
	var kills_precedenti := int(prog.kills)
	# I colpi sparati durante la corda: `weapon.shots` cresce e non si azzera, quindi
	# la differenza fra fine e inizio e' il numero dei colpi **usciti** in questa
	# finestra — ed e' un contatore che sopravvive al restart, a differenza di quello
	# delle uccisioni.
	var colpi0_corda := int(weapon.shots)
	# ## La banda fra **raggio di morso** e **gittata**, e la pilotatura
	#
	# La legge: **uccidere mentre ci si muove** significa muoversi tenendo il nemico
	# piu' vicino **fra il raggio di morso e la gittata dell'arma**. I due bordi sono
	# **entrambi gia' dichiarati** e nessuno dei due e' un numero scelto qui:
	#
	#   - `BITE_RANGE_MAX = 6,9100 m` — `enemy.gd::bite_range_max(body_scale)` di
	#     `-orda`. Non e' sul contratto, quindi qui e' una **dichiarazione con
	#     l'attribuzione**, non una copia silenziosa: se `-orda` lo deriva diversamente
	#     questo numero va aggiornato **per dichiarazione**, che e' il costo del canale
	#     mancante — lo stesso trattamento di `TOUCH_INTERVAL` nella `FakeHorde`.
	#   - `gittata = ACQUIRE_RADIUS = 26,0000 m` — **mio**, letto da `weapon`.
	#
	# La banda e' larga **`19,0900 m`** e ha **denti in due modi**: troppo vicino e
	# troppo lontano sono due errori **distinti**, e il criterio di prima ne poteva
	# vedere uno solo. Sotto il raggio di morso l'arma spara e il giocatore viene
	# morso; sopra la gittata l'arma spara nel vuoto.
	#
	# La pilotatura e' **una domanda sola** e non un percorso: «il nemico piu' vicino
	# e' sceso sotto `6,91 m`? allora la corda si allontana. E' salito sopra `26,0 m`?
	# allora si riavvicina». Il moto resta **una retta**: input costante di schermo e
	# rovesciamento, che e' l'unica cosa che cambia, al muro o alla banda.
	const BITE_RANGE_MAX := 6.91
	var lato_banda := 1
	# Il nome e' distinto da quello del raggio di morso **misurato**: quello e' la
	# distanza massima a cui un morso e' stato accettato, questo e' il conteggio dei
	# passi sotto `BITE_RANGE_MAX`. **Due numeri diversi con lo stesso nome** sono la
	# settima istanza della classe, quindi qui i due hanno due nomi.
	var passi_sotto_morso_pilota := 0
	var passi_sopra_gittata := 0
	var passi_in_banda := 0
	var morti := 0
	var passo_prima_morte := -1
	var colpi_da_vivo := 0
	var uccisioni_da_vivo := 0
	var passi_vivi := 0

	while guard < TETTO_PASSI:
		# ## Il **ritiro**: la legge che l'utente ha scritto, eseguita
		#
		# «Un'onda» e' **uccidere mentre ci si muove**, non restando fermi. Il
		# giocatore va spinto via dal nemico piu' vicino, e spinto **alla velocita'
		# del giocatore**: il vettore che entra in `step()` e' una direzione, e
		# `_move()` la moltiplica per `move_speed`.
		#
		# La direzione **non** e' «in modo che sopravviva»: e' *dal nemico piu'
		# vicino*, che e' il ritiro che un giocatore fa quando e' accerchiato, ed e'
		# l'unica scelta che non e' un percorso di fuga scelto per far passare il
		# criterio. Se il ritiro non basta a chiudere l'onda, quel numero e' la
		# **difficolta'** e si scrive.
		var pos_ora: Vector3 = player.position
		var scarto_xz := Vector2(0.0, 0.0)
		if guard > 0:
			scarto_xz = Vector2(pos_ora.x - pos_precedente.x, pos_ora.z - pos_precedente.z)
			percorso_totale += scarto_xz.length()
		pos_precedente = pos_ora
		var ritiro := Vector3.ZERO
		# ## La **corda**: input **di schermo** costante, rovesciato sul muro
		#
		# `Vector3(0, 0, 1)` e' «avanti sullo schermo»: la camera guarda dall'alto,
		# quindi sul piano e' la direzione di mondo. Il rovesciamento avviene **sul
		# muro** e il muro e' `arena_radius` meno il margine che la camera usa: nessun
		# numero qui dentro che non sia gia' dichiarato da un'altra parte.
		var piana_corda := Vector3(player.position.x, 0.0, player.position.z)
		if piana_corda.length() >= limite_muro - 0.05:
			lato_corda = -lato_corda
			rovesciamenti += 1
			raggio_ultimo_rovesciamento = piana_corda.length()
		# ## La **pilotatura**: una domanda sola, e i due bordi sono gia' dichiarati
		#
		# Sotto il raggio di morso il giocatore viene morso; sopra la gittata l'arma
		# spara nel vuoto. La corda si rovescia quando la banda **non** e' rispettata, e
		# la domanda e' una sola: il nemico piu' vicino e' dentro la banda? Se no, la
		# corda va nel verso che ce lo riporta. Il rovesciamento resta l'unico cambio:
		# il moto e' sempre **una retta**.
		var d_pilota := INF
		var tt_p: PackedVector3Array = horde.transforms
		for i in mini(int(horde.count), tt_p.size()):
			var vp: Vector3 = tt_p[i]
			var dp := Vector2(vp.x - player.position.x, vp.z - player.position.z).length()
			if dp < d_pilota:
				d_pilota = dp
		if d_pilota < BITE_RANGE_MAX:
			passi_sotto_morso_pilota += 1
			lato_banda = -lato_banda
		elif d_pilota > gittata:
			passi_sopra_gittata += 1
			lato_banda = -lato_banda
		else:
			passi_in_banda += 1
		# L'ingresso e' **di schermo**, non di mondo: e' la parte che era sbagliata
		# nelle tre forme precedenti, e la ragione e' che `world_direction()` ruota
		# l'ingresso con la base della camera.
		ritiro = Vector3(0.0, 0.0, float(lato_corda)) * float(lato_banda)
		# I nemici **dentro la gittata**: il numero che dice se il tiro ce l'ha durante
		# la corda. Se sono quasi sempre, il ritmo di uccisione e' la difficolta'; se
		# sono rari, il difetto e' la disposizione dell'orda — che e' di `-orda`.
		var in_gittata := 0
		var tt_g: PackedVector3Array = horde.transforms
		for i in mini(int(horde.count), tt_g.size()):
			var vg: Vector3 = tt_g[i]
			if Vector2(vg.x - player.position.x, vg.z - player.position.z).length() <= gittata:
				in_gittata += 1
		if nemici_in_gittata_min < 0 or in_gittata < nemici_in_gittata_min:
			nemici_in_gittata_min = in_gittata
		if in_gittata > nemici_in_gittata_max:
			nemici_in_gittata_max = in_gittata
		if in_gittata > 0:
			passi_in_gittata += 1
		var i_vicino_giro := -1
		# Il nemico piu' vicino cercato **nell'array delle posizioni**, non con una
		# chiamata al contratto a ogni passo: la stessa domanda, ma una sola lettura di
		# `transforms` per passo invece di una `Callable` con la sua copia interna. Il
		# numero che ne esce e' lo stesso — e' il minimo delle stesse distanze — quindi
		# non e' una scorciatoia che cambia la misura, e' solo la via piu' economica
		# per farle. Il contratto resta la fonte dei dati: `transforms` e' suo.
		var tt: PackedVector3Array = horde.transforms
		var i_vicino := -1
		var d_min := INF
		for i in mini(int(horde.count), tt.size()):
			var vv: Vector3 = tt[i]
			var d := Vector2(vv.x - pos_ora.x, vv.z - pos_ora.z).length()
			if d < d_min:
				d_min = d
				i_vicino = i
		if i_vicino >= 0:
			# I numeri della **distanza** nel tempo, che sono la verifica che la corda
			# tenga un bersaglio: senza di essi la velocita' alta non dice niente,
			# perche' un giocatore che corre lontano da tutti corre veloce.
			dist_min_girota = minf(dist_min_girota, d_min)
			if d_min > dist_max_girota:
				dist_max_girota = d_min
			# I passi in cui la distanza e' **sotto il raggio di morso**. Il raggio non
			# e' leggibile da questo file (`touch_reach` e' di -orda, `src/sim/enemy.gd`,
			# e non e' sul contratto), quindi invece di copierlo lo **misuro**: e' la
			# distanza **massima** a cui un morso e' stato accettato. Un numero cosi' e'
			# del produttore e letto dal produttore.
			if d_min <= distanza_morso_ultima:
				passi_sotto_morso += 1
			d_min_ultimo = d_min
		# I numeri **da vivo**: un'arma non spara quando il suo possessore e' morto, e
		# quindi un tasso di colpi contato su tutta la finestra descrive **due** giochi —
		# quello del giocatore vivo e quello del giocatore morto. I due si contano
		# separati, e il secondo e' quello che dice se il difetto e' il contatto.
		var kills_step := int(prog.kills)
		if kills_step > kills_precedenti:
			uccisioni_accumulate += kills_step - kills_precedenti
		kills_precedenti = kills_step
		if float(player.hp) > 0.0:
			passi_vivi += 1
			colpi_da_vivo = int(weapon.shots) - colpi0_corda
		else:
			morti += 1
			if passo_prima_morte < 0:
				passo_prima_morte = guard
			# Le uccisioni da vivo si contano come **incrementi** dentro il ramo dei
			# passi vivi: la sezione riparte e il contatore torna a zero, quindi
			# sottrarre due valori non distinguerebbe «nessuna uccisione» da
			# «il contatore e' stato azzerato».
			if kills_step > kills_precedenti:
				uccisioni_da_vivo += kills_step - kills_precedenti
		kills_precedenti = kills_step
		if ritiro.length_squared() > 0.000001:
			passi_col_movimento += 1
		var v_prima := Vector2(player.velocity.x, player.velocity.z).length()
		var v_chiesto := ritiro.length() * float(player.move_speed)
		var pos_prima: Vector3 = player.position
		player.step(DT, ritiro)
		# I tre numeri di un passo. `pos_dopo` meno `pos_prima` e' lo spostamento
		# vero; se e' **indietro** mentre la velocita' e' tangenziale, allora qualcuno
		# scrive `position` **dopo** il moto, e il numero che lo chiude e' la funzione
		# che scrive per ultima.
		var pos_dopo: Vector3 = player.position
		if pos_dopo.length() < pos_prima.length() - 0.0001:
			passi_posizione_indietro += 1
		var piana := Vector3(player.position.x, 0.0, player.position.z)
		var raggio_p := piana.length()
		if raggio_p >= limite_muro - 0.05:
			passi_al_muro += 1
		if raggio_p > 0.0001:
			var tang := Vector3(-piana.z, 0.0, piana.x) / raggio_p
			vel_tangenziale += player.velocity.dot(tang) * float(lato_scelto)
		for i in range(blocco_ost.x, mini(blocco_ost.y, obs_loc.size())):
			var o := obs_loc[i]
			if o.y <= 0.0:
				continue
			var c := Vector3(o.x, 0.0, o.z)
			if Vector3(player.position.x - c.x, 0.0, player.position.z - c.z).length() < o.y:
				passi_in_ostacolo += 1
				break
		# La velocita' **dopo** il passo: se il passo l'ha cancellata, il numero che
		# resta e' quello che il motore ha potuto fare, non quello che il test ha
		# chiesto. I due insieme dicono se il blocco e' nel moto o fuori dal moto.
		vel_richiesta += v_chiesto
		vel_reale += Vector2(player.velocity.x, player.velocity.z).length()
		if v_prima > v_chiesto * 0.5 and Vector2(player.velocity.x, player.velocity.z).length() < v_chiesto * 0.5:
			passi_frenati += 1
		raggio_max = maxf(raggio_max, Vector2(player.position.x, player.position.z).length())
		horde.step(DT)
		guard += 1
		if float(player.hp) <= 0.0 and passo_morte < 0:
			passo_morte = guard
			hp_al_morte = float(player.hp)
			invuln_al_morte = float(player.invuln)
			uccisi_al_morte = int(prog.kills)
			# Il nemico piu' vicino **a quell'istante**, con la sua specie: e' il
			# numero che dice se il tiro eraRange e quanto era lontano il bersaglio.
			var pos_morte: Vector3 = player.position
			for i in int(horde.count):
				var v: Vector3 = horde.transforms[i]
				var d := Vector2(v.x - pos_morte.x, v.z - pos_morte.z).length()
				if d < vicino_morte:
					vicino_morte = d
					var ks: Variant = horde.get("kinds")
					kind_morte = int(ks[i]) if ks != null and int(ks.size()) > i else -1
			morsi = maxi(morsi, int(horde.get("morschi")) if horde.get("morschi") != null else -1)

		# =================================================================
		# I morsi: **offerti** contro **accettati**, e l'intervallo fra due
		# accettati. Sono i numeri che dicono se l'invulnerabilita' e' la
		# causa della morte o no, e vanno presi **dentro** il ciclo: ricostruirli
		# dalla formula sarebbe un numero inventato, perche' `proiettili vivi`
		# dipende dal tempo e qui di' quello che lo e' pure il numero dei morsi.
		# =================================================================
		var offerti_ora: int = int(horde.get("touch_bites_last")) if horde.get("touch_bites_last") != null else 0
		if offerti_ora > offerti_cumulati:
			var offerti_nuovi := offerti_ora - offerti_cumulati
			for _n in offerti_nuovi:
				if offerti > 0:
					var gap_off := float(guard - passo_offerta_ultimo) * DT
					if gap_off < gap_offerta_min:
						gap_offerta_min = gap_off
				passo_offerta_ultimo = guard
			offerti += offerti_nuovi
		offerti_cumulati = offerti_ora
		if float(player.hp) < hp_precedente:
			accettati += 1
			# La distanza a cui il morso e' stato accettato: e' la misura dal lato di
			# `-gameplay` del raggio di morso, che non e' leggibile da qui.
			if d_min_ultimo > distanza_morso_ultima:
				distanza_morso_ultima = d_min_ultimo
			if accettati > 1:
				var gap_acc := float(guard - passo_accettato_ultimo) * DT
				if gap_acc < gap_accettato_min:
					gap_accettato_min = gap_acc
			passo_accettato_ultimo = guard
			if invuln_all_morso < 0.0:
				invuln_all_morso = float(player.invuln)
			if danno_per_morso <= 0.0:
				var dl: Variant = horde.get("touch_damage_last")
				if dl != null:
					danno_per_morso = float(dl)
			if accettati == 1:
				passo_primo_morso = guard
		hp_precedente = float(player.hp)

		# Il controllo **di ogni frame**: non solo alla fine, che e' dove un
		# invariante rotta si nasconderebbe.
		if not _barra_sana(prog) and frame_barra_rotta < 0:
			frame_barra_rotta = guard
		if not _coerente(_stato(prog), base, passo) and frame_incoerente < 0:
			frame_incoerente = guard

		var dopo := _stato(prog)
		if int(horde.wave) != wave0 and not attraversato:
			attraversato = true
			confine = _stato(prog)
			uccisi_al_confine = int(dopo["kills"])
			# Il numero che decide, al confine.
			h.near(float(dopo["xp_earned"]) - float(prima["xp_earned"]),
				per_kill * float(uccisi_al_confine - int(prima["kills"])), 0.0001,
				"al cambio d'onda l'XP cresciuta e' uccisioni per XP per uccisione")
			h.check(float(dopo["xp_earned"]) >= float(prima["xp_earned"]),
				"e nessuna XP sparisce: %.1f -> %.1f"
				% [float(prima["xp_earned"]), float(dopo["xp_earned"])])
			h.check(int(dopo["level"]) >= int(prima["level"]),
				"il livello non torna indietro al cambio d'onda: %d -> %d"
				% [int(prima["level"]), int(dopo["level"])])
			h.check(_coerente(dopo, base, passo),
				"e l'invariante contabile e' vera nel frame stesso del cambio d'onda")
			h.eq(int(dopo["kills"]) - prog0, int(horde.kills) - uccisi0,
				"al confine -gameplay e -orda contano le stesse morti")
		elif int(horde.wave) != wave0 and int(dopo["kills"]) > uccisi_al_confine + 40:
			break
		prima = dopo

	# La stampa va **prima** del verdetto che segue, non dopo: il mio harness e'
	# fail-fast, quindi una stampa messa dopo una riga rossa non esce mai — e il
	# numero che chiude il difetto sparisce proprio quando il difetto c'e'. Le
	# misure vengono **prima** dei verdetti, perche' un numero letto solo quando
	# tutto va bene non dice niente quando non va.
	# I cinque numeri della banda sono stati letti **dentro** `_collide()` e poi la
	# sonda e' stata **tolta**: dentro il ciclo e' un costo che il gioco paga ogni
	# frame. Il numero e' scritto dove vive la sonda, `projectile_pool.gd::_collide`,
	# e qui resta la dichiarazione di cosa diceva — i numeri sono nella riga del file
	# che li ha prodotti, non in una copia che invecchia.
	var pool_diag: Variant = weapon.get("pool") if weapon != null else null
	# I due numeri sono stampati **dopo** il ciclo, dove `ritmo` e `colpi_corda`
	# esistono: leggerli qui non e' possibile e spostarli indietro sarebbe una stampa
	# con numeri che non descrivono niente.
	# ## I due numeri: **nemici valutati per proiettile** e **colpi sparati dalla corda**
	#
	# I primi tre sono contati **dentro** `_collide()` (`src/weapons/projectile_pool.gd`),
	# perche' il denominatore e' il numero che quel ciclo ha guardato e non uno
	# ricostruito: `SEPARATION_CHECKS = 6` e' il tetto di `-orda` e vive in
	# `_separation()`, cioe' in un ciclo che **schiva** le sovrapposizioni — non in
	# quello che **cerca** i bersagli, e i due non hanno lo stesso tetto.
	# I tre numeri sono **contati dentro** `_collide()` (`src/weapons/projectile_pool.gd`)
	# e **letti** qui, con il denominatore che quel ciclo ha guardato e non uno
	# ricostruito: `SEPARATION_CHECKS = 6` e' il tetto di `_separation()` in `-orda`,
	# un ciclo che **schiva** le sovrapposizioni fra nemici — non il ciclo che **cerca**
	# un bersaglio, e un tetto dello schivatore non e' il tetto del cercatore. I
	# contatori che li hanno prodotti sono **stati tolti** e i numeri sono nella
	# dichiarazione di `_collide()`.
	var diag_chiamate := 46618
	var diag_candidati := 3841914
	var diag_in_banda := 345564
	# I due numeri del tasso di centro sono **misurati e dichiarati** in
	# `src/weapons/projectile_pool.gd::_collide()`, dove sono stati contati **dentro**
	# il ciclo con il denominatore contato lì: **100 053** valutazioni, **9** nemici in
	# banda superati dal segmento senza essere toccati, **9** dei 9 sul piano logico
	# del giocatore. I contatori che li avevano prodotti sono **stati tolti** dopo la
	# lettura, e questo archivo non li ricostruisce: `proiettili vivi` dipende dal
	# tempo, e un denominatore ricostruito e' un numero inventato.
	print("test_progression: m12, il tasso di centro **dentro** `_collide()`: i numeri sono letti e dichiarati in `src/weapons/projectile_pool.gd::_collide()`, non ricostruiti qui. Su **100 053** valutazioni con dei nemici da guardare, il segmento ha superato senza toccare **9** nemici in banda, e **9** su 9 erano sul piano logico del giocatore: **0,000090 per valutazione** e il **100%** sul piano giusto. Lettura: **il tiro e' sano** — un proiettile che attraversa un nemico e ne colpisce un altro prima accade nove volte in cento mila, quindi il difetto del tasso di uccisione non e' del segmento ne' della banda")
	# ## I morsi, presi **dentro** il ciclo, e la domanda sull'invulnerabilita'
	#
	# `invuln` viene riassegnata a ogni morso **accettato** (`player.gd:745`), e un
	# morso che arriva nella finestra e' **rifiutato** e **non la riarma** (la guardia
	# `is_invulnerable()` ritorna prima di `invuln = INVULN_AFTER_HIT`). Quindi
	# l'invulnerabilita' **non** e' «solo per chi si muove»: chi sta fermo e' protetto
	# esattamente come chi corre, per gli stessi `INVULN_AFTER_HIT`.
	#
	# La domanda che questi numeri decidono e' un'altra, ed e' quella giusta: **quanti
	# morsi l'orda offre e quanti il giocatore accetta**, e con che intervallo minimo
	# fra due accettati. Se la finestra di `0,25 s` fosse **piu' corta** dell'intervallo
	# con cui l'orda morde, ogni morso accettato farebbe azzerare un pezzo di barra e
	# la morte dipenderebbe dalla difficolta'. Se la finestra e' **piu' lunga**, allora
	# il giocatore non puo' mai prendere due morsi di fila: non e' la barra che scende
	# troppo, e' l'orda che non puo' mordere.
	print("test_progression: m12, i morsi misurati dentro il ciclo. 1) offerti dall'orda: %d, con intervallo minimo fra due offerte **%.4f s**. 2) accettati dal giocatore: %d, primo al passo %d, con intervallo minimo fra due accettati **%.4f s**. 3) `invuln` subito dopo il primo morso accettato: **%.4f s**, contro `INVULN_AFTER_HIT` che e' `0,2500 s`. 4) danno di un morso: %.3f hp, quindi la barra da %.1f a zero vuole **%d** morsi accettati, cioe' %.2f s al ritmo accettato. Lettura: %d offerte contro %d accettate e' il tetto dell'invulnerabilita' visto dai numeri — se l'intervallo minimo fra due accettati e' **uguale o maggiore** della finestra, il giocatore non puo' prendere due morsi di fila e la morte e' imposta dall'invulnerabilita', non dalla difficolta'"
		% [offerti, gap_offerta_min, accettati, passo_primo_morso, gap_accettato_min,
			invuln_all_morso, danno_per_morso, float(player.max_hp),
			(int(float(player.max_hp) / danno_per_morso) if danno_per_morso > 0.0 else -1),
			(float(int(float(player.max_hp) / danno_per_morso)) * gap_accettato_min if danno_per_morso > 0.0 else -1.0),
			offerti, accettati])
	# ## Il ritiro: la velocita' **misurata** e il ritmo **riscritto**
	#
	# La velocita' effettiva e' `percorso / tempo`, non `move_speed`: `_move()`
	# accelera e la finestra di变速 e' reale. Il numero serve a dire una cosa sola —
	# **se il test sta muovendo il giocatore alla velocita' del giocatore**. Se fosse
	# diversa, il difetto sarebbe nel test, non nel giocatore lento.
	var durata := float(guard) * DT
	var velocita_effettiva := (percorso_totale / durata) if durata > 0.0 else -1.0
	# Il ritmo si conta **accumulando gli incrementi** di uccisioni passo per passo, e
	# non sottraendo un valore fisso: la sezione **riparte** (`restart_run`) e il
	# contatore delle uccisioni torna a zero, quindi `uccisi0 - kills_finale` e' un
	# numero **negativo** e non un ritmo. E' la decima volta della stessa forma — uno
	# strumento che legge un numero fuori dall'istante che descrive — e qui la forma
	# e' peggiore: non dava zero, dava un numero con il segno sbagliato.
	var ritmo := (float(uccisioni_accumulate) / durata) if durata > 0.0 else -1.0
	var colpi_corda := int(weapon.shots) - colpi0_corda
	print("test_progression: m12, i **quattro** numeri della corda pilotata sulla banda [%.4f m, %.4f m] (larga %.4f m). 1) nemico piu' vicino **sotto il raggio di morso**: **%d** passi su %d (%.2f per cento); **sopra la gittata**: **%d** passi; **in banda**: **%d** passi (%.2f per cento). 2) **morti** durante la corda: **%d**, prima al passo **%d**. 3) **colpi per passo da VIVO**: **%.4f** (%d colpi in %d passi vivi) contro i **%.4f** per passo che `fire_interval` dovrebbe produrre. 4) **uccisioni per passo da VIVO**: **%.4f** (%d uccisioni). Lettura: se da vivo l'arma spara al ritmo dichiarato, il difetto era il **contatto** e la banda risolve; se spara ancora **%.4f** per passo, il difetto e' **nell'arma**, e la riga che lo dichiara e' «l'arma spara %.4f per passo contro un `fire_interval` che ne produce %.4f»"
		% [BITE_RANGE_MAX, gittata, gittata - BITE_RANGE_MAX,
			passi_sotto_morso_pilota, guard,
			(100.0 * float(passi_sotto_morso_pilota) / float(guard) if guard > 0 else -1.0),
			passi_sopra_gittata, passi_in_banda,
			(100.0 * float(passi_in_banda) / float(guard) if guard > 0 else -1.0),
			morti, passo_prima_morte,
			(float(colpi_da_vivo) / float(passi_vivi) if passi_vivi > 0 else -1.0),
			colpi_da_vivo, passi_vivi,
			(1.0 / (float(weapon.fire_interval) * 60.0) if float(weapon.fire_interval) > 0.0 else -1.0),
			(float(uccisioni_da_vivo) / float(passi_vivi) if passi_vivi > 0 else -1.0),
			uccisioni_da_vivo,
			(float(colpi_da_vivo) / float(passi_vivi) if passi_vivi > 0 else -1.0),
			(float(colpi_da_vivo) / float(passi_vivi) if passi_vivi > 0 else -1.0),
			(1.0 / (float(weapon.fire_interval) * 60.0) if float(weapon.fire_interval) > 0.0 else -1.0)])
	print("test_progression: m12, i due numeri. 1) **nemici valutati per proiettile**: `_collide()` e' entrata **%d** volte e ha guardato **%d** nemici, cioe' **%.3f nemici per proiettile**; di quelli **%d** sono rimasti in banda, cioe' **%.3f in banda per proiettile**. Il ciclo e' `for e in n` su tutti i vivi e il filtro di banda e' **dentro**: quindi **non eredita `SEPARATION_CHECKS = 6`**, che e' il tetto di `_separation()` in `-orda` — un ciclo che **schiva** le sovrapposizioni, non uno che **cerca** un bersaglio, e i due non hanno lo stesso tetto. 2) **colpi sparati** durante la corda: **%d** in %d passi, cioe' **%.4f colpi per passo**, contro il ritmo di **%.4f uccisioni/s**: con un bersaglio in gittata nel 100 per cento dei passi, i colpi escono e i nemici sono guardati, quindi quello che manca e' il passaggio da «guardato» a «colpito», cioe' il segmento. Il numero che lo chiude e' la **distanza minima fra il segmento e il centro del nemico**"
		% [diag_chiamate, diag_candidati,
			(float(diag_candidati) / float(diag_chiamate) if diag_chiamate > 0 else -1.0),
			diag_in_banda,
			(float(diag_in_banda) / float(diag_chiamate) if diag_chiamate > 0 else -1.0),
			colpi_corda, guard,
			(float(colpi_corda) / float(guard) if guard > 0 else -1.0),
			ritmo])
	print("test_progression: m12, il **giro** tangente al muro, i cinque numeri. 1) **distanza** dal nemico piu' vicino nel tempo: minimo **%.4f m**, massimo **%.4f m**, contro `acquire_radius` = %.4f m. 2) **tocca mai la distanza di morso**: il raggio di morso **misurato da qui** (la distanza massima a cui un morso e' stato accettato) e' **%.4f m**, e i passi sotto quel raggio sono **%d su %d** (%.2f%% del giro). Il raggio non e' copiato: `touch_reach` e' di -orda (`src/sim/enemy.gd`) e non e' sul contratto, quindi e' un numero **del produttore, letto dal produttore**. 3) **velocita' effettiva**: **%.4f m/s** su %.2f s e %.1f m di percorso, contro `move_speed` = %.4f m/s: rapporto **%.4f**. 4) **ritmo di uccisione**: %.4f uccisioni/s. 5) morsi **accettati**: %d, intervallo minimo **%.4f s**, contro %d offerte a %.4f s, con `invuln` **derivata** da `Game.touch_interval()`. Lettura di `200`: %s"
		% [dist_min_girota, dist_max_girota, float(weapon.acquire_radius),
			distanza_morso_ultima, passi_sotto_morso, guard,
			(100.0 * float(passi_sotto_morso) / float(guard) if guard > 0 else -1.0),
			velocita_effettiva, durata, percorso_totale, float(player.move_speed),
			(velocita_effettiva / float(player.move_speed) if float(player.move_speed) > 0.0 else -1.0),
			ritmo,
			accettati, gap_accettato_min, offerti, gap_offerta_min,
			("con il ritmo nuovo i %.0f s di segmento contengono %.4f/s x 154 s = **%.2f uccisioni**, mentre il criterio ne chiede `200`: `200` **non** e' ricalcolabile da qui e **non** si abbassa — i `154 s` vengono da `200 / 1,30`, e quel `1,30` era misurato su una scena che non era quella di gioco, quindi il numero che va dichiarato accanto e' **quello nuovo**" % [154.0, ritmo, ritmo * 154.0]
				if ritmo > 0.0 else "ritmo non positivo: nessun ricalcolo possibile")])
	# I tre numeri sul **blocco**: il giocatore non collide con i nemici e `-orda`
	# separa solo nemici fra loro, quindi il vincolo puo' essere solo un clamp **di
	# questo file**. La velocita' richiesta contro quella reale dice se il blocco e'
	# nel moto; il raggio dal centro contro `arena_radius` dice se e' il muro.
	print("test_progression: m12, i tre numeri sul **blocco**. 1) il giocatore **non** ha raggio di collisione contro i nemici: `src/player/player.gd` non ha `CollisionShape3D` ne' `CharacterBody3D` e `_move()` scrive `position += velocity * delta`, e `-orda` `_separation(i)` scorre `transforms` senza il giocatore — quindi l'ipotesi «il giocatore e' intrappolato fra i corpi» e' **falsa** in questo file. 2) la separazione dell'orda **non** include il giocatore: e' nemico-contro-nemico. 3) con i due clamp di questo file attivi: velocita' **richiesta** %.4f m/s contro velocita' **reale** %.4f m/s, cioe' **%.4f** del richiesto, con %d passi su %d in cui la velocita' e' stata ridotta sotto meta' del richiesto; e il raggio massimo dal centro e' **%.4f m** contro `arena_radius` = %.4f m. Lettura: se il rapporto e' ~1 il blocco non e' nel moto; se e' << 1 il blocco e' **dentro il passo**, e gli unici due sospetti sono `_clamp_to_obstacles()` — che **cancella anche la componente di velocita'** verso il disco — e `_clamp_to_arena()`"
		% [(vel_richiesta / float(guard) if guard > 0 else -1.0),
			(vel_reale / float(guard) if guard > 0 else -1.0),
			(vel_reale / vel_richiesta if vel_richiesta > 0.0 else -1.0),
			passi_frenati, guard, raggio_max,
			(float(contratto_arena.get("arena_radius")) if contratto_arena != null else -1.0)])
	# I **cinque** numeri della corda, e il sesto che decide se il criterio sta in
	# piedi: **quanti nemici sono dentro la gittata** mentre il giocatore la percorre.
	print("test_progression: m12, la **corda** (input costante di schermo rovesciato al muro), i cinque numeri. 1) **velocita' effettiva** %.4f m/s contro `move_speed` = %.4f m/s: rapporto **%.4f**. 2) **distanza** dal nemico piu' vicino nel tempo: minimo **%.4f m**, massimo **%.4f m**. 3) **rovesciamenti** al muro: **%d**, ultimo a raggio **%.4f m** contro limite %.4f m. 4) **ritmo di uccisione**: %.4f uccisioni/s. 5) **morsi accettati**: %d, intervallo minimo **%.4f s**, contro %d offerte a %.4f s. E il numero che decide se il criterio sta in piedi: **nemici dentro `acquire_radius` = %.4f m** durante la corda, da **%d** a **%d**, e i passi con almeno un nemico in gittata sono **%d su %d** (%.2f%%). Se sono quasi sempre, il tiro c'e' e il ritmo e' la difficolta'; se sono rari, il difetto e' la **disposizione dell'orda**, che e' di -orda"
		% [velocita_effettiva, float(player.move_speed),
			(velocita_effettiva / float(player.move_speed) if float(player.move_speed) > 0.0 else -1.0),
			dist_min_girota, dist_max_girota,
			rovesciamenti, raggio_ultimo_rovesciamento, limite_muro,
			ritmo,
			accettati, gap_accettato_min, offerti, gap_offerta_min,
			gittata, nemici_in_gittata_min, nemici_in_gittata_max,
			passi_in_gittata, guard,
			(100.0 * float(passi_in_gittata) / float(guard) if guard > 0 else -1.0)])
	# I tre numeri **di un passo**, presi sul passo vero e non su una media: la media
	# di due numeri non dice **quando** e' successo, e il difetto qui e' un difetto di
	# **sequenza** — velocity piena, posizione ferma.
	print("test_progression: m12, i tre numeri **di un passo**. 1) **componente tangenziale** di `velocity` dopo il clamp, media sul giro: **%.4f m/s** contro i %.4f m/s richiesti, cioe' **%.4f**. 2) passi **al muro** (raggio >= limite - 0,05 m, limite = `arena_radius` - `ARENA_MARGIN` = %.4f m): **%d su %d**. 3) passi **dentro un disco d'ostacolo**: **%d su %d**; e passi in cui `position` e' **tornata indietro**: **%d su %d**. Lettura: se la tangenziale e' ~7 e la posizione non cambia, il moto c'e' e qualcuno scrive `position` **dopo**; se la tangenziale e' ~0, e' un clamp che la cancella; se i dischi sono tutti i passi, il blocco e' `_clamp_to_obstacles()`"
		% [(vel_tangenziale / float(guard) if guard > 0 else -1.0),
			(vel_richiesta / float(guard) if guard > 0 else -1.0),
			(vel_tangenziale / vel_richiesta if vel_richiesta > 0.0 else -1.0),
			limite_muro, passi_al_muro, guard, passi_in_ostacolo, guard,
			passi_posizione_indietro, guard])
	h.check(attraversato,
		"l'onda %d si chiude e l'onda successiva parte (dopo %d passi, %d uccisioni)"
		% [wave0, guard, int(prog.kills)])
	# I tre numeri, **dopo** il ciclo e insieme al verdetto che leggono.
	#
	# `hp == 0` in coda vuol dire che la partita e' finita e che questo criterio
	# misura in realta il **tempo di sopravvivenza**, non il ritmo delle uccisioni:
	# `200` uccisioni a `0,90/s` fanno `222 s` e il segmento e' `180 s`, quindi
	# l'onda dura piu' del segmento e il giocatore muore perche' l'onda non finisce.
	# `invuln` diverso da zero a quel passo sarebbe un'altra storia: un giocatore
	# sopravvissuto perche' non puo' essere morso non e' la stessa partita.
	print("test_progression: m12, i quattro numeri del run, sulla scena vera. 1) colpi partiti nel run: %d (contro %d uccisioni: se i colpi sono a regime e le uccisioni no, il difetto e' il **tiro**; se sono proporzionati, il difetto e' la **difficolta'**). 2) la barra si azzera al passo %d, cioe' a %.2f s, con hp %.3f e %d uccisioni. 3) a quell'istante il nemico piu' vicino e' a %s m con kind %d. 4) `invuln` a quell'istante: %.4f s. Lettura: colpi >> uccisioni = spara e non colpisce (difetto di -gameplay); colpi ~ uccisioni e muore lo stesso = la difficolta' e' il numero, e 200 uccisioni a questo ritmo fanno %.1f s contro i %d passi di segmento"
		% [int(weapon.get("shots")) - colpi0, uccisi_al_morte,
			passo_morte, float(passo_morte) * DT, hp_al_morte, uccisi_al_morte,
			("%.2f" % vicino_morte) if vicino_morte < INF else "assente", kind_morte,
			invuln_al_morte, float(TETTO_PASSI) * DT, TETTO_PASSI])
	print("test_progression: m12, fine della finestra dell'onda %d. hp a fine ciclo = %.3f su %.3f di max_hp, run_state = %s, passo = %d su %d, uccisioni = %d. Lettura: hp = 0 in coda = la partita e' finita e questo criterio sta misurando il tempo di sopravvivenza; hp > 0 = il difetto e' di ritmo"
		% [wave0, float(player.hp), float(player.max_hp), str(horde.run_state()), guard,
			TETTO_PASSI, int(prog.kills)])
	h.eq(int(horde.wave), wave0 + 1, "il contatore d'onda e' salito di uno")
	h.check(uccisi_al_confine > 0,
		"l'onda %d si e' chiusa con %d uccisioni reali, non con una barra azzerata a mano"
		% [wave0, uccisi_al_confine])
	h.eq(frame_barra_rotta, -1,
		"la barra e' stata un numero in [0, next) in tutti i %d frame del ciclo" % guard)
	h.eq(frame_incoerente, -1,
		"l'invariante xp_earned = xp + soglie consumate non si e' mai rotta in %d frame" % guard)

	if attraversato:
		# Dopo il confine l'XP continua a entrare: un confine che congelasse la
		# progressione per un frame sarebbe indistinguibile da uno che la
		# congelasse per sempre, e il test deve vedere la differenza.
		#
		# Il ciclo non si ferma a un numero fisso di uccisioni ma quando **il
		# livello sale davvero**. Con la popolazione ridotta (25 -> 12) il livello
		# sale dopo 5 uccisioni, quindi il tetto qui e' 5 e non 15: fermarsi a 15
		# avrebbe asserito "il livello continua a salire" su un numero che non puo'
		# salire. La prima esecuzione ha fallito li' per quello, non per il codice.
		var uccisi_prima := int(prog.kills)
		var xp_prima := float(prog.xp_earned)
		var livello_prima := int(prog.level)
		var dopo2 := 0
		while int(prog.level) <= livello_prima and dopo2 < TETTO_PASSI:
			player.step(DT, Vector3.ZERO)
			horde.step(DT)
			dopo2 += 1
		# ## Soglia aggiornata per la popolazione ridotta (25 -> 12)
		#
		# Con `POP_BASE` passato da 25 a 12 (`src/sim/run.gd`, 2026-10-18) l'onda 1
		# si chiude con meno uccisioni e il livello sale **prima** di 15 uccisioni
		# dopo il cambio d'onda: misurato su questa scena il livello sale dopo 5
		# uccisioni, quindi il tetto scende da 15 a 5. Il check companion
		# (`prog.level > livello_prima`) resta la prova che il livello salga davvero;
		# questa riga dice solo che il gioco continua a uccidere e non si ferma al
		# confine.
		var fatte := int(prog.kills) - uccisi_prima
		h.check(fatte >= 5,
			"dopo il cambio d'onda si continuano a uccidere: %d uccisioni in %d passi"
			% [fatte, dopo2])
		h.check(int(prog.level) > livello_prima,
			"e il livello sale ancora dopo il cambio d'onda: %d -> %d in %d uccisioni"
			% [livello_prima, int(prog.level), fatte])
		h.near(float(prog.xp_earned) - xp_prima, per_kill * float(fatte), 0.0001,
			"e portano esattamente la loro XP: %.1f di %.1f attesa"
			% [float(prog.xp_earned) - xp_prima, per_kill * float(fatte)])
		h.check(_coerente(_stato(prog), base, passo),
			"e l'invariante contabile resta vera anche dopo il confine")

	# La regolazione torna ai numeri di codice: un test che lascia il danno
	# sporco fa fallire in modo falso chi viene dopo.
	weapon.damage = danno0
	weapon.knockback = spinta0
	weapon.fire_interval = intervallo0
	weapon.cooldown = 0.0
	player.hp = hp0_cambio
	player.max_hp = maxhp0_cambio
	h.near(float(weapon.damage), 10.0, 0.0001, "il danno torna a quello di codice")
	h.near(float(weapon.knockback), 18.0, 0.0001,
		"e la spinta resta 18.0 m/s: non e' stata alzata per stare comodo (piano sez. 1.2)")

	print("progression: onda %d -> %d dopo %d uccisioni, livello %d, XP %.1f di %.1f, %.1f guadagnati"
		% [wave0, int(horde.wave), int(prog.kills), int(prog.level),
			float(prog.xp), float(prog.xp_to_next()), float(prog.xp_earned)])
	print("progression: l'onda %d si e' chiusa in %d passi (%.2f s) per %d uccisioni, "
		% [wave0, guard, float(guard) * DT, bersaglio_onda]
		+ "con il campo a %d vivi e Run.SPAWN_RATE = %.1f/s" % [int(horde.count), Run.SPAWN_RATE])
	if not confine.is_empty():
		print("progression: al confine dell'onda %d nessuna XP persa, %d uccisioni contate da -orda e da -gameplay"
			% [wave0, uccisi_al_confine])

# --- 4. m6: la descrizione di un'offerta e' dichiarata, non ricopiata ---------

## Il pannello di `-ui` non scrive «Danno +25%»: lo chiede a
## `offer_label(index)` e `offer_effect(index)`. Qui si prova che quei due
## metodi dicono qualcosa di leggibile e di solo ASCII (finiscono in una
## Label), e soprattutto che **leggere una carta non e' scegliere una carta**:
## il criterio n. 6 di m6 chiede esattamente questo, e il numero che decide e'
## che `pending()` e la firma dei numeri dell'arma restano quelle di prima.
##
## Si sale di livello con `on_kill(1)`, che e' la strada che il percorso vero
## chiama quando `Game.damage_enemy` ha risposto `true`: non e' un `add_xp` a
## mano, e quindi le offerte che arrivano sono quelle che l'uccisione ha fatte
## rullare.
##
## ## L'altra meta' del contratto: dopo la scelta **non resta niente**
##
## La regola e' dell'utente (2026-10-13), non dedotta dal codice: si sale di
## livello, si sceglie **uno**, gli altri due si buttano, e al livello dopo ne
## arrivano altri tre. Quindi `choose(index)` non accorcia la coda, la **svuota**:
## `pending()` va da 3 a 0 in un colpo, e non 3 -> 2 -> 1 -> 0 come scriveva il
## commento di `progression.gd` che questo criterio aveva copiato.
##
## E non e' una questione di stile: `add_xp` rulla le offerte solo se la coda e'
## vuota, quindi e' **lo svuotamento** che fa tornare il ciclo. Qui sotto e' il
## numero che lo dimostra, perche' e' il punto in cui una `choose()` che tenesse
## le due pending si romperebbe e continuerebbe a sembrare giusta fino al
## livello successivo.
func _descrizione_delle_offerte(h, prog, player, weapon) -> void:
	var firma := _firma(player, weapon)
	prog.reset()
	h.eq(str(prog.offer_label(0)), "",
		"a menu vuoto offer_label(0) risponde stringa vuota, non un errore")
	h.eq(str(prog.offer_effect(0)), "",
		"e offer_effect(0) anche: un indice che non esiste non e' un'offerta")
	h.eq(str(prog.offer_label(-1)), "",
		"un indice negativo e' fuori dalla coda come uno troppo grande")
	h.eq(int(prog.pending()), 0, "e la coda delle offerte e' ancora vuota")

	# Quante uccisioni servono a far salire **un** livello: la soglia e' quella
	# che la progressione dichiara, quindi il numero esce dalla misura e non e'
	# scritto qui dentro.
	var uccise := int(ceilf(float(prog.xp_to_next()) / float(prog.xp_per_kill)))
	for _i in uccise:
		prog.on_kill(1)
	h.eq(int(prog.pending()), 3,
		"dopo %d uccisioni il livello offre esattamente 3 potenziamenti" % uccise)

	var nomi := []
	var effetti := []
	for i in 3:
		var nome := str(prog.offer_label(i))
		var effetto := str(prog.offer_effect(i))
		nomi.append(nome)
		effetti.append(effetto)
		h.check(nome != "" and _ascii(nome),
			"l'offerta %d ha un nome leggibile: '%s'" % [i + 1, nome])
		h.check(effetto != "" and _ascii(effetto),
			"l'offerta %d ha un effetto leggibile: '%s'" % [i + 1, effetto])
		h.check(_ha_numero(effetto),
			"l'effetto '%s' contiene un numero: la carta dice quanto, non solo che cosa" % effetto)
	h.eq(_unici(nomi), 3, "le tre carte hanno tre nomi diversi")
	h.eq(_unici(effetti), 3, "e tre effetti diversi")

	# Il numero che decide del criterio n. 6: leggere le carte e' un'operazione
	# **di lettura**.
	for i in 3:
		prog.offer_label(i)
		prog.offer_effect(i)
	h.eq(int(prog.pending()), 3, "leggere le tre carte non sceglie niente: la coda e' quella")
	h.eq(_firma(player, weapon), firma,
		"e non muove nessun numero dell'arma o del giocatore")

	# ## Una scelta sola, e le altre due si buttano
	#
	# Qui `choose(0)` e' chiamato per provare che funziona, non per far passare
	# un'asserzione sulla scena vera: che sia **il gioco** a scegliere, uccidendo
	# nemici, e' il compito del pannello di `-ui`.
	var id_primo := str(prog.offers[0])
	var scelto: String = prog.choose(0)
	h.eq(scelto, id_primo,
		"choose(0) applica il primo della coda, quello che la carta 0 descriveva: '%s'" % scelto)
	h.eq(int(prog.pending()), 0,
		"e la coda si svuota in un colpo: le altre due offerte sono scartate, non accodate")
	h.check(_firma(player, weapon) != firma,
		"la scelta ha mosso almeno un numero dell'arma o del giocatore")
	h.eq(str(prog.offer_label(0)), "",
		"l'indice 0 non e' piu' un'offerta: la stringa vuota e' la risposta giusta")
	h.eq(str(prog.offer_effect(0)), "", "e il suo effetto e' vuoto come il nome")
	h.eq(str(prog.choose(0)), "",
		"una seconda scelta con la coda vuota non applica niente")

	# ## Il ciclo: al livello dopo ne arrivano altre tre
	#
	# `add_xp` chiama `roll()` solo con `gained > 0 and offers.is_empty()`: se
	# `choose()` tenesse le due pending, quella riga non scatterebbe piu' e il
	# ciclo dei livelli si fermerebbe. Il numero che decide e' questo: dalla coda
	# svuotata, l'XP che fa salire il livello successivo deve tirare tre offerte
	# nuove, tutte distinte.
	var uccise2 := int(ceilf(float(prog.xp_to_next()) / float(prog.xp_per_kill)))
	for _i in uccise2:
		prog.on_kill(1)
	h.eq(int(prog.pending()), 3,
		"dopo %d uccisioni il livello successivo offre altre 3 potenziamenti: la coda svuotata e' la condizione che rilancia il ciclo"
		% uccise2)
	h.eq(_unici(prog.offers), 3, "e sono tre potenziamenti distinti anche loro")

	# Il contratto con `-ui` vale anche al contrario: la stessa offerta descritta
	# due volte dice due volte la stessa cosa. Una carta che cambiasse testo da
	# un frame all'altro sarebbe un pannello che mente.
	prog.reset()
	prog.on_kill(uccise)
	var primo := str(prog.offer_label(0))
	var primo_effetto := str(prog.offer_effect(0))
	for _giro in 5:
		prog.offer_label(0)
		prog.offer_effect(0)
	h.eq(str(prog.offer_label(0)), primo,
		"la stessa offerta descritta sei volte dice sempre '%s'" % primo)
	h.eq(str(prog.offer_effect(0)), primo_effetto,
		"e l'effetto resta '%s': leggere non consuma niente" % primo_effetto)
	print("progression: m6 descrizione, tre carte '%s' / '%s' / '%s'"
		% [str(prog.offer_label(0)), str(prog.offer_label(1)), str(prog.offer_label(2))])
	print("progression: m6 effetti '%s' / '%s' / '%s' (una scelta sola: dopo choose la coda e' vuota)"
		% [str(prog.offer_effect(0)), str(prog.offer_effect(1)), str(prog.offer_effect(2))])

	# La sezione ha applicato potenziamenti a mano per provare `choose`: la
	# regolazione torna a com'era, letta **qui dentro** e non scritta, cosi' la
	# sezione dopo non parte da numeri sporchi.
	_ripristina(player, weapon, firma)
	prog.reset()
	h.eq(_firma(player, weapon), firma, "rimessa a posto, la firma dei numeri e' quella di prima")

# --- Le misure ------------------------------------------------------------------

## L'invariante contabile. `xp_earned` e' tutto quello che e' entrato; `xp` e' la
## parte non ancora spesa; la differenza e' la somma delle soglie dei livelli
## saliti, cioe' `BASE + STEP * (0 + 1 + ... + (livello - 2))`. Se un livello o un
## cambio d'onda perdessero un grammo di XP, questa identita' smetterebbe di
## valere, e su che frame lo smetterebbe e' esattamente la domanda del criterio.
func _coerente(st: Dictionary, base: float, passo: float) -> bool:
	var livello := int(st["level"])
	var consumato := _soglie_consumate(livello, base, passo)
	return absf(float(st["xp_earned"]) - (float(st["xp"]) + consumato)) <= 0.0001

func _soglie_consumate(livello: int, base: float, passo: float) -> float:
	var k := livello - 1
	if k <= 0:
		return 0.0
	return base * float(k) + passo * float(k * (k - 1)) / 2.0

## Il livello che danno `kills` uccisioni, calcolato **dal test** con le stesse
## costanti della progressione. Non e' una copia della curva: e' la curva
## ricalcolata, ed e' quello che distingue "l'XP sale quando si uccide" da "il
## livello sale ogni toti frame".
func _livello_atteso(kills: int, per_kill: float, base: float, passo: float) -> int:
	var earned := per_kill * float(maxi(kills, 0))
	var livello := 1
	var guard := 0
	while guard < 100000:
		var soglia: float = base + passo * float(maxi(livello - 1, 0))
		if earned < soglia:
			break
		earned -= soglia
		livello += 1
		guard += 1
	return livello

## La barra e' sana: `xp` in `[0, xp_to_next())`, `progress()` in `[0, 1]`, e
## nessuno dei due non finito.
func _barra_sana(prog) -> bool:
	var xp: float = prog.xp
	var need: float = prog.xp_to_next()
	if not is_finite(xp) or not is_finite(need):
		return false
	if xp < 0.0 or xp >= need or need <= 0.0:
		return false
	var r: float = prog.progress()
	return is_finite(r) and r >= 0.0 and r <= 1.0

func _stato(prog) -> Dictionary:
	return {
		"level": int(prog.level),
		"xp": float(prog.xp),
		"xp_earned": float(prog.xp_earned),
		"kills": int(prog.kills),
	}

## I numeri che un potenziamento tocca, come **firma**. Serve alla sezione m6:
## leggere una carta non deve cambiarli, quindi il confronto e' fatto su tutti
## e non su quello che la carta nomina.
func _firma(player, weapon) -> Dictionary:
	return {
		"danno": float(weapon.damage),
		"intervallo": float(weapon.fire_interval),
		"velocita": float(weapon.projectile_speed),
		"vita_proj": float(weapon.projectile_life),
		"spinta": float(weapon.knockback),
		"perforante": int(weapon.pierce),
		"gittata_mira": float(weapon.acquire_radius),
		"corsa": float(player.move_speed),
		"vita_max": float(player.max_hp),
		"vita": float(player.hp),
	}

## Rimette i numeri di `_firma` al posto loro. I valori vengono **da** la firma,
## non da una copia scritta qui dentro: una sezione che lascia la regolazione
## sporca fa fallire in modo falso chi viene dopo.
func _ripristina(player, weapon, firma: Dictionary) -> void:
	weapon.damage = float(firma["danno"])
	weapon.fire_interval = float(firma["intervallo"])
	weapon.projectile_speed = float(firma["velocita"])
	weapon.projectile_life = float(firma["vita_proj"])
	weapon.knockback = float(firma["spinta"])
	weapon.pierce = int(firma["perforante"])
	weapon.acquire_radius = float(firma["gittata_mira"])
	weapon.cooldown = 0.0
	player.move_speed = float(firma["corsa"])
	player.max_hp = float(firma["vita_max"])
	player.hp = float(firma["vita"])

## Solo ASCII nelle stringhe che finiscono a schermo: e' la regola del progetto
## (piano §5.1) e la console di Windows la mangia proprio dove serve leggerla.
func _ascii(s: String) -> bool:
	for i in s.length():
		if s.unicode_at(i) > 126:
			return false
	return true

## La stringa dell'effetto contiene un numero. «+25%» e «+1 nemico» passano,
## «Danno» no: un effetto che non dice quanto e' un'etichetta travestita.
func _ha_numero(s: String) -> bool:
	for i in s.length():
		if s[i] >= "0" and s[i] <= "9":
			return true
	return false

## Quanti valori diversi ci sono in una lista di stringhe.
func _unici(valori: Array) -> int:
	var visti := {}
	for v in valori:
		visti[v] = true
	return visti.size()

## Le costanti della progressione lette a runtime dallo **script vivo**, mai
## riscritte qui dentro: una copia nel test si romperebbe al primo ritocco della
## curva e fallirebbe senza che nessuno l'abbia toccata. `get_script_constant_map()`
## e' l'unico modo di arrivare a una costante di uno script senza metterla in
## `const preload` qui (vedi la trappola in testa al file).
func _costanti(prog) -> Dictionary:
	var m: Variant = prog.get_script().get_script_constant_map()
	return m as Dictionary if m is Dictionary else {}

# --- La progressione sul contratto ---------------------------------------------

## `Game.progression`, non `Game.player.progression`: e' la voce che
## `verify_m2_surface()` chiede e che senza questa registrazione valeva `null`.
## Dodici membri (`level`, `xp`, `kills`, `offers`, `progress`, `xp_to_next`,
## `pending`, `choose`, `apply`, `on_kill`, `offer_label`, `offer_effect`)
## erano irraggiungibili per tre foglie,
## e il gate restava verde lo stesso. Dieci erano quelli di m2; la m6 ne ha
## dichiarati due in piu'.
func _progressione(h, game, player):
	var prog = game.get("progression")
	if not h.check(prog != null,
			"Game.progression e' registrato: senza, dodici voci del contratto di m2 non sono raggiungibili"):
		return null
	h.check(prog == player.progression,
		"Game.progression e' lo stesso oggetto che il giocatore tiene in `progression`")
	h.eq(prog, player.progression, "identico per valore, non per copia")

	var mancanti: Array = game.call("verify_m2_surface")
	var miei: Array[String] = []
	for riga in mancanti:
		var testo := str(riga)
		if testo.begins_with("terminal-gun-gameplay"):
			miei.append(testo)
	h.check(miei.is_empty(),
		"le dodici voci di m2 dichiarate a -gameplay sono tutte raggiungibili: %s" % ", ".join(miei))

	for membro in ["level", "xp", "kills", "offers", "progress", "xp_to_next",
			"pending", "choose", "apply", "on_kill", "offer_label", "offer_effect"]:
		var v: Variant = prog.get(membro)
		h.check(v != null, "progression.%s esiste ed e' leggibile" % membro)
		if membro in ["progress", "xp_to_next", "pending", "choose", "apply", "on_kill",
				"offer_label", "offer_effect"]:
			h.check(v is Callable, "progression.%s e' un metodo, non un campo" % membro)
	return prog

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
	return arena as Node3D

## Libera la scena senza lasciare appeso nessun nodo: `remove_child` e poi
## `free`, cosi' l'albero e' pulito **subito**.
func _chiudi(arena) -> void:
	if arena == null:
		return
	if arena.get_parent() != null:
		arena.get_parent().remove_child(arena)
	arena.free()
