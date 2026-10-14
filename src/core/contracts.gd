extends Node
## Contratto di interfecce di terminal-gun. Autoload `Game`.
##
## REGOLA AUREA: il contratto **dichiara**, le implementazioni **si registrano**.
##
## DATI — nel proprio `_ready()`, una volta sola:
##     Game.player = self
##     Game.horde = self
##     Game.arena_radius = 60.0
##
## Quell'ultima riga e' un **esempio di forma**, non un valore da copiare: il raggio
## dell'arena ha una sola fonte, `src/render/arena.gd:ARENA_RADIUS`, che la registra lei
## stessa nel proprio `_enter_tree()` prima di qualunque `_ready()` (§5.1). Il default qui
## sotto deve **coincidere** con quello, ed e' il criterio n. 2 di m9 a dirlo.
##
## **Il numero e' cambiato dal 46,0 al 60,0 il 2026-10-14**, e questa riga e' rimasta a
## 46,0 fino a che `-scheletro` me l'ha segnalata leggendo il gate. Il motivo e' la
## lezione di m9: il raggio era in **sei copie**, io ne ho cambiata la fonte e non ho
## **avvisato**, e due foglie hanno scoperto il numero vecchio dalla porta. La sequenza
## che funziona e' **vertice cambia la fonte -> vertice avvisa -> foglie rispecchiano**,
## e il vertice non puo' saltare il passo di mezzo.
##
## METODI — nel proprio `_ready()`, una volta sola:
##     Game.register_impl("nearest_enemy", self._nearest_enemy)
##     Game.register_impl("damage_enemy", self._damage_enemy)
##     Game.register_impl("spawn_projectile", self._spawn_projectile)
##     Game.register_impl("random_spawn_point", self._random_spawn_point)
##     Game.register_impl("player_position", self._player_position)
##
## ⚠ Perché non `Game.nearest_enemy = self._nearest_enemy`: GDScript lo RIFIUTA.
## Un nome che è già un `func` dello script non è assegnabile ("Invalid assignment
## of property or key ... with value of type 'Callable'"). Quindi la registrazione
## dei metodi passa da `register_impl`, che è la sola forma che funziona.
## Chiamare invece i metodi col nome normale: `Game.nearest_enemy(pos, 12.0)`,
## non `Game.nearest_enemy.call(pos, 12.0)`.
##
## Nessuna foglia modifica questo file. Se serve un campo o un metodo nuovo,
## non si anticipa qui: si chiede al vertice, che decide e aggiorna questo file.
##
## Sotto il contratto valgono tre regole (piano §5):
##   1. nessun nodo per nemico: l'orda tiene `count`/`transforms`/`colors`;
##   2. nessuna allocazione nel ciclo di gioco: capacità fissa assegnata all'avvio;
##   3. nessuna dipendenza circolare tra foglie: ciò che l'API non espone si chiede al vertice.
##
## Le stringhe che finiscono a schermo sono solo ASCII, accenti compresi. Non è
## pignoleria: la console di Windows e il pipe di `OS.execute` rimangono in
## codepage e un accento diventa spazzatura illeggibile proprio nel messaggio che
## serve a capire un fallimento. I commenti invece possono tenerli.

## I metodi che il contratto dichiara. Serve a `register_impl` per rifiutare un
## nome che non esiste: una foglia che registra una API inesistente deve
## fallire subito e rumorosamente, non diventare una chiamata che non porta da
## nessuna parte fra tre settimane.
const API := [
	"nearest_enemy",
	"damage_enemy",
	"spawn_projectile",
	"random_spawn_point",
	"player_position",
	# --- m7, 2026-10-13: la via che il danno prende. Vedi `damage_player` sotto.
	"damage_player",
]

# --- Dati esposti dalle foglie -------------------------------------------------

## -gameplay. Il nodo del giocatore. Non nodo per nemico: il giocatore è uno solo.
var player: Node3D

## -orda (src/sim/horde.gd). I nemici vivi sono **record in array**, non nodi:
## horde.count / horde.transforms / horde.colors.
var horde: Node

## -arena. Raggio utile dell'arena, in metri. Dato, non calcolato: nessuno lo
## deve derivare dalla geometria della scena per evitare dipendenze circolari.
##
## **m9, 2026-10-13: 28.0 -> 46.0, perche' e come.** Il numero non e' stato scelto: e'
## uscito dalla sonda `docs/piramide/probe_arena_density.gd` del vertice, che misura lo
## **spazio che l'orda concede** al variare del raggio invece di indovinarlo (§1.4b).
## Sulla scena vera a regime, 200 nemici, seme 4242, DT 1/60:
##
##     R=28  area 2463 m2  libera 85,2%  disco libero max  9,5 m  tempo till il muro 1,4 s
##     R=40  area 5027 m2  libera 92,8%  disco libero max 15,6 m  tempo till il muro 2,2 s
##     R=46  area 6648 m2  libera 94,6%  disco libero max 19,1 m  tempo till il muro 2,7 s
##
## Il tempo till il muro e' `(R - 9,4) / 13,65 m/s`: l'orda forma un anello di ~9,4 m
## intorno al giocatore, e R compare nel numeratore mentre quel 9,4 no. Percio' ingrandire
## **raddoppia i due numeri che descrivono «non riesco a muovermi»** (la bolla sicura e i
## secondi per scappare) e muove poco la percentuale di area libera, che era gia' 85,2%.
##
## **Quello che questo numero NON risolve**, dichiarato perche' il piano non vende numeri:
## lo spazio libero resta **frammentato in tasche** e l'anello di ~9,4 m intorno al
## giocatore **non si assottiglia**, perche' e' un numero di simulazione (popolazione e
## separazione) e non di mappa.
##
## ## m11, 2026-10-14: **46,0 -> 60,0 m**, e il raggio non e' piu' una scelta a occhio.
##
## La sonda `docs/piramide/probe_survive.gd` (piano sez. 1.14-quinque) ha misurato la
## sopravvivenza di uno schivatore al variare del raggio, su **tre semi** e con **due casi a
## risposta nota**:
##
## | R | caso peggiore | fattore sul passo precedente |
## |---|---|---|
## | 12 m (riferimento: li' non si puo' schivare, e lo strumento **deve** morire) | 61,20 s | — |
## | **46 m (questo valore)** | **55,33 s** | — |
## | **60 m** | **146,72 s** | **2,65** |
## | 75 m | 156,33 s | 1,07 |
##
## Il **ginocchio e' a circa 60 m**: da 46 a 60 il caso peggiore guadagna 2,65 volte, da 60 a 75
## solo 1,07. Percio' il raggio va portato a 60 e **non** piu' in la', e allargarlo oltre sarebbe
## pagare area libera che il gioco non usa (vedi la nota sopra sullo spazio frammentato).
##
## **Quello che 60 m NON risolve, dichiarato perche' il piano non vende numeri:** al raggio 75,
## che e' 1,63 volte questo valore, il caso peggiore muore lo stesso a 156,33 s, e i 600 s
## dell'utente sono **3,8 volte** tanto. Quindi **la mappa non basta da sola** e il resto del
## lavoro di m11 e' sulla rampa delle onde.
##
## **Perche' il default e' qui e cosa significa.** `src/render/arena.gd:ARENA_RADIUS` e' la
## **fonte unica** e la registra nel proprio `_enter_tree()`: questo valore e' cioe' quello
## che c'e' **prima** che l'arena si registri, e per m9 deve essere **uguale** a quello. Non
## e' una seconda fonte e non deve essere cambiato per ottenere un verde: e' il valore che
## `tests/test_smoke.gd` e `tests/test_gameplay.gd` asseriscono, e il criterio n. 2 di m9
## verifica che tutte le copie **esistenti** dicano lo stesso numero.
var arena_radius: float = 60.0

## ## m11, 2026-10-14: il fattore di calibrazione del corpo entra nel contratto.
##
## **Il problema, e la sua forma esatta.** La banda di sovrapposizione a vuoto non e' un numero
## che sfugge: e' esattamente `(SIZE_FACTOR - 1) * RADIUS[kind]`, cioe' **2,4 volte `RADIUS[kind]`**
## — 1,08 m sul runner, 1,44 sul grunt, 2,40 sul brute, **4,56 sul boss**, e cresce con la specie.
## Quindi **chiuderla non richiede nessun numero nuovo**: richiede che la simulazione applichi **lo
## stesso** fattore che il renderer usa per disegnare. E il coefficiente **non e' libero**:
## `corpo_giocatore` e' gia' `TOUCH_REACH = 0.45`, perche' il criterio n. 2 di m8 asserisce che la
## taglia misurata sulla scena vera e' **uguale** a `TOUCH_REACH`. Quindi
## `morse_entro(k) = SIZE_FACTOR * RADIUS[k] + TOUCH_REACH` e basta, e la banda diventa **zero per
## costruzione**, non per taratura.
##
## **Perche' allora questo numero entra qui.** `SIZE_FACTOR` e' dichiarato in
## `src/render/horde_renderer.gd`, che e' di `-arena`, e il punto 4 sopra lo autorizza
## esplicitamente. Ma **senza questo canale non si puo' derivare niente**: la simulazione non sa
## quanto e' grande il corpo che si vede, quindi per morre alla distanza giusta dovrebbe
## **copiare** il numero di un'altra foglia, e una copia mente — che e' il difetto delle sei copie
## di m9, gia' pagato una volta.
##
## **La forma segue il precedente di `arena_radius`**, che e' gia' in questo file: la **fonte** e'
## `src/render/arena.gd`, che la registra nel proprio `_enter_tree()`; il contratto ne espone il
## valore; **`-orda` e `-ui` lo leggono** e non lo possiedono. Nessuna copia, nessun fallback
## silenzioso, e chi lo registra e' `-arena`.
var enemy_body_scale: float = 3.4

## **Terzo raggio scritto a mano, e va chiuso con gli altri due.** `-orda` mi ha segnalato
## `src/weapons/projectile_pool.gd:89`, `const ENEMY_RADIUS := 0.55`: un raggio nemico in un file
## di `-gameplay`, cioe' un **terzo** proprietario dello stesso concetto. Il difetto che l'utente ha
## segnalato non e' solo dei morsi: e' che **un proiettile colpisce un corpo 1,53-6,46 m con un
## raggio di 0,55 m**, quindi anche dall'altra parte il colpo arriva da lontano. La richiesta
## dell'utente e' *«le dimensioni dell'hitbox combacino con le grandezze mie e dei nemici»*, e
## quella comprende **entrambi** i lati. Finche' quel `0.55` non deriva dalla stessa taglia, il
## difetto e' spostato e non chiuso.

## -arena (m10). Gli ostacoli del mondo: **dischi sul piano XZ**.
##
##     un elemento = Vector3(centro_x, RAGGIO, centro_z)
##
## Il raggio sta in **`y`**, che e' l'unica cosa controintuitiva di questa superficie: `y`
## **non** e' un'altezza e `z` **non** e' una profondita'. Semantica completa e congelata in
## «Superficie di milestone 10» piu' in basso; qui la dichiarazione, che mancava ed e' stata
## aggiunta **dopo** che tre foglie l'hanno segnalata.
##
## **Statici**: li registra `src/render/arena.gd` nel proprio `_enter_tree()`, e `-orda` li
## legge una volta sola quando costruisce il campo di percorrenza. Registrati in `_ready()`
## sarebbero sempre fuori tempo, per la regola di §5.1.
##
## **Non e' un semplice contenitore.** `-arena` lo riempie, `-orda` lo evita e `-gameplay` ci
## scontra, e nessuno dei tre legge i numeri dagli altri due: il punto per cui questa riga e'
## dichiarata qui e non concordata fra tre file.
var obstacles: PackedVector3Array = PackedVector3Array()

# --- Superficie di milestone 2 ----------------------------------------------------
#
# In m1 il contratto dichiarava i cinque metodi che le foglie si passavano. In m2
# la partita ha un inizio, una crescita e una fine, quindi **tre** foglie hanno da
# guardarsi negli occhi: -orda conta le uccisioni, -gameplay fa salire di livello
# il giocatore, -ui mostra entrambe.
#
# Quei nomi, fino a m2, se li erano concordati **leggendo il codice dell'altra**:
# -ui fa `Game.horde.wave` perche' -orda espone `wave` come campo e non come
# metodo `wave()`, perche' a un certo punto l'HUD lo leggeva gia'. Funziona, ma
# funziona per fortuna. Qui sotto e' **dichiarato**, con nomi e firme esatti: chi
# lo cambia non sta piu' implementando un contratto, sta cambiando il contratto,
# e il vertice deve saperlo.
#
# Queste voci **non** passano da `register_impl`: sono campi e metodi pubblici
# gia' esposti da un oggetto che il contratto contiene gia' (`Game.horde`,
# `Game.player`). Il contratto le dichiara, nessuno le registra.

## Superficie di m2, per proprietario. I valori sono i **nomi esatti** dei membri:
## `prop` e' il campo dati del contratto che contiene l'oggetto, `member` e' il
## membro su quell'oggetto, `kind` dice se e' un campo o un metodo.
const M2_SURFACE := [
	{"owner": "terminal-gun-orda", "prop": "horde", "member": "wave", "kind": "field"},
	{"owner": "terminal-gun-orda", "prop": "horde", "member": "wave_total", "kind": "method"},
	{"owner": "terminal-gun-orda", "prop": "horde", "member": "wave_remaining", "kind": "method"},
	{"owner": "terminal-gun-orda", "prop": "horde", "member": "wave_killed", "kind": "method"},
	{"owner": "terminal-gun-orda", "prop": "horde", "member": "wave_bar_ratio", "kind": "method"},
	{"owner": "terminal-gun-orda", "prop": "horde", "member": "wave_hp_scale", "kind": "method"},
	{"owner": "terminal-gun-orda", "prop": "horde", "member": "run_state", "kind": "method"},
	{"owner": "terminal-gun-orda", "prop": "horde", "member": "is_game_over", "kind": "method"},
	{"owner": "terminal-gun-orda", "prop": "horde", "member": "restart_run", "kind": "method"},
	{"owner": "terminal-gun-gameplay", "prop": "player", "member": "hp", "kind": "field"},
	{"owner": "terminal-gun-gameplay", "prop": "player", "member": "max_hp", "kind": "field"},
	{"owner": "terminal-gun-gameplay", "prop": "player", "member": "progression", "kind": "field"},
	{"owner": "terminal-gun-gameplay", "prop": "player", "member": "health_ratio", "kind": "method"},
	# --- m7, 2026-10-13: il giocatore e' feribile, e si vede. `hp` e `max_hp`
	# erano gia' dichiarati sopra ma erano **piatti**: nessun codice di gioco li
	# scriveva. Questi due non aggiungono una superficie, rendono verificabile
	# quella che c'era: `damage_player` e' il chiamante che il criterio cerca.
	{"owner": "terminal-gun-gameplay", "prop": "player", "member": "is_dead", "kind": "method"},
	{"owner": "terminal-gun-gameplay", "prop": "player", "member": "grant_xp", "kind": "method"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "level", "kind": "field"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "xp", "kind": "field"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "kills", "kind": "field"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "offers", "kind": "field"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "progress", "kind": "method"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "xp_to_next", "kind": "method"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "pending", "kind": "method"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "choose", "kind": "method"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "apply", "kind": "method"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "on_kill", "kind": "method"},
	# --- m6, 2026-10-13: la descrizione di un'offerta. ---
	#
	# La prima volta che -ui costruisce il pannello dei potenziamenti, il problema
	# non e' che cosa mostra ma **chi sa che cosa mostra**. Il numero del
	# potenziamento e' dentro `progression.gd`, che e' di -gameplay: se -ui
	# scrive "danno +25%" a mano, sta copiando una conoscenza che non e' sua, e
	# la copia mente alla prima riga cambiata in `apply()`.
	#
	# Questi due metodi sono la strada dichiarata. `progression.offers` dice
	# **quali** id ci sono; questi due dicono **come si chiamano** e **quanto
	# fanno**, e li espone chi possiede i numeri.
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "offer_label", "kind": "method"},
	{"owner": "terminal-gun-gameplay", "prop": "progression", "member": "offer_effect", "kind": "method"},
	# --- m11, la superficie del boss finale: **ancora non dichiarata, e perche'**. ---
	#
	# Il boss finale e' una cosa nuova: oggi `BOSS` e' una specie con 900 hp e
	# resistenza 0,90 al knockback, e `Spawner.wave_weights(wave)` cambia i pesi per
	# onda, ma **nessun codice sa che "al minuto 10 c'e' il boss"**. Non c'e' un'onda
	# designata, non c'e' un trigger, non c'e' una vittoria: quindi serve uno **stato**,
	# e uno stato nuovo e' superficie di contratto da congelare **prima** dell'onda che
	# lo usa, come in m3, m6 e m10.
	#
	# **Perche' pero' non la dichiaro adesso.** L'ho scritta, e poi l'ho tolta, perche'
	# dichiararla renderebbe `test_smoke` **rosso** con cinque membri mancanti senza che
	# nessuno li implementi, e soprattutto la renderebbe **inraggiungibile**: la misura
	# dice che al raggio 60 m lo schivatore peggiore muore a **146,72 s**, quindi nessuno
	# arriva a 600 s e il boss non potrebbe mai sparare. Codice che non puo' partire e'
	# la classe di difetto che questo progetto ha gia' chiuso piu' volte: la sonda
	# rimossa e mai eseguita, l'asserzione decorativa, il criterio che nasce verde.
	#
	# **La congelo all'inizio dell'onda del boss**, cioe' dopo che l'apertura e' stata
	# sistemata e il trigger a 600 s e' misurato. E il numero di *quando* parte l'ultima
	# onda sara' di `-orda` e vivera' in `run.gd`: il contratto dichiarera' la
	# **regola**, non copiera' il numero. Copiarlo qui creerebbe esattamente la copia
	# che m9 ha imparato a contare.
]

## L'oggetto di m2 che -gameplay registra. Non e' un nodo: e' il
## `RefCounted` di `src/player/progression.gd`, che sta dietro il giocatore.
## -ui lo raggiunge per contratto e non con `get_node("../..")`.
var progression = null

## La superficie di m2 che non e' ancora li'. Lista **vuota** = contratto rispettato.
##
## Non e' un controllo di stile: senza questo, un membro rinominato da una foglia
## fa fallire le altre tre con un `Invalid get index` che non dice quale delle
## quattro foglie ha rotto il contratto, e il messaggio arriva a un'onda di
## distanza dal rename. Con questo arriva subito e con il nome del membro.
func verify_m2_surface() -> Array[String]:
	var missing: Array[String] = []
	for row in M2_SURFACE:
		var holder = self.get(row["prop"])
		if holder == null or not is_instance_valid(holder):
			missing.append("%s.%s manca: il contratto non ha ancora '%s'" % [row["owner"], row["member"], row["prop"]])
			continue
		var v: Variant = holder.get(row["member"])
		if v == null:
			missing.append("%s.%s non c'e'" % [row["owner"], row["member"]])
		elif row["kind"] == "method" and not (holder.get(row["member"]) is Callable):
			missing.append("%s.%s non e' un metodo" % [row["owner"], row["member"]])
	return missing

# --- Superficie di milestone 3 ---------------------------------------------------
#
# **Non e' una API registrata.** `reseed` e `worst_bucket`/`grid_overflowed` sono
# metodi pubblici di `src/sim/horde.gd`, che -arena raggiunge attraverso il nodo
# `Horde` della scena vera, come gia' fa con `step()`, `damage_enemy()` e i tre
# campi di massa. Non passano da `register_impl` perche' nessuna delle due
# foglie li registra: sono la superficie **della simulazione**, non del contratto.
#
# Sono qui perche' m3 e' la prima onda che mette **due foglie sullo stesso
# oggetto**: `horde.gd` e' di -orda e `tests/test_arena.gd` e' di -arena, e il
# piano registra gia' il caso in cui due foglie hanno concordato un nome senza
# che nessuno lo decidesse (il campo `wave` letto per nome dall'HUD). Il rimedio
# non e' fidarsi, e' una riga scritta qui **prima** che le foglie lavorino.

## Dichiarato dal vertice il 2026-10-12, **congelato**: i due nomi qui sotto sono
## le uniche due firme che -orda scrive e -arena chiama. Cambiarne una durante
## l'onda significa fermare l'onda e tornare dal vertice.
##
##     horde.reseed(s)              # -orda la scrive, -arena la chiama
##     horde.worst_bucket()         # gia' esiste: il contratto ne dichiara il significato
##     horde.grid_overflowed()      # gia' esiste
##
## `reseed(s)` e' l'API che manca e che rende questa onda possibile:
##
##   - `horde.seed` (campo pubblico, `src/sim/horde.gd:92`) e' letto **una volta
##     sola**, dentro `_build()`, che gira nel `_ready()`. Sulla scena vera
##     l'orda la crea `arena_main.tscn`: nessun codice esterno puo' scrivere
##     `seed` prima che `_build()` giri. Il campo sembra la riproducibilita' e
##     sulla scena vera e' **irraggiungibile**: `seed = 0` sempre, `_rng.randomize()`
##     sempre. Il difetto di m3 e' questo, non la casualita'.
##   - `reseed(s)` rende la disposizione una **funzione del seme** anche quando
##     l'orda e' nata dentro una scena.
##
## Semantica congelata, in cinque punti. Ogni altro comportamento e' di -orda:
##
##   1. scrive il campo pubblico `seed` con `s`;
##   2. `s == 0` mantiene il significato dichiarato del campo: `randomize()`, cioe'
##      casuale a ogni avvio (non "seme zero");
##   3. con `s != 0` fissa `_rng` sul seme e **ripopola a `population`** con
##      **lo stesso percorso del primo frame** (`_populate`), non con un mestiere
##      diverso: due versioni della stessa disposizione sarebbero due numeri che
##      possono divergere, ed e' la lezione gia' scritta in `_populate`;
##   4. **non tocca** `run`, `wave`, `kills` ne `population`. E' un'operazione di
##      **disposizione**, non di stato di partita: `restart_run()` resta l'unica
##      cosa che rimette a posto la partita, e le due non vanno confuse;
##   5. ricostruisce la griglia, cosi' `worst_bucket()` e `grid_overflowed()`
##      parlano della disposizione appena scritta e non di quella precedente.
##
## Perche' il punto 5 e' nel contratto e non un dettaglio: senza, il chiamante
## misura la griglia della disposizione **precedente** e il numero che ne ricava
## e' vero ma non risponde alla domanda che ha fatto.

# --- Superficie di milestone 8 ---------------------------------------------------
#
# ## Il difetto, e perché è una superficie e non un dettagolo di disegno
#
# Il 2026-10-13 un utente che ha giocato scrive: «il mio hitbox è troppo piccolo
# o i nemici troppo grandi». Misurato, il difetto è preciso e non è quello che
# sembra: **le quattro specie sono disegnate con la stessa mesh alla stessa
# scala** (`BASE_SCALE = 1.5`, `src/render/horde_renderer.gd:32`) e cambiano
# solo di tinta (`colors`). Quindi un runner e un boss sono indistinguibili alla
# vista, mentre il boss morde da ben piu' lontano:
#
#     specie  RADIUS    morde fino a (RADIUS + TOUCH_REACH)
#     runner    0.45     1.65 m
#     grunt     0.60     1.80 m
#     brute     1.00     2.20 m
#     boss      1.90     3.10 m
#
# `RADIUS` vive in `src/sim/enemy.gd`, che è di -orda. `-arena` non può leggerlo
# da sola: sarebbe prendere un numero di un'altra foglia, cioè la copia che mente
# alla prima riga cambiata (la lezione di `offer_label`, sopra). Quindi il numero
# attraversa una **superficie dichiarata**, e la stessa forma di m3: due foglie
# sullo stesso oggetto, nomi congelati **prima** dell'onda.
#
# ## Congelato dal vertice il 2026-10-13
#
#     horde.radii          # -orda la scrive, -arena la legge. PackedFloat32Array
#
# Semantica, in cinque punti. Ogni altro comportamento resta di -orda e di -arena:
#
#   1. `radii[i]` e' il **raggio del corpo** del nemico `i`, in metri, preso da
#      `RADIUS[kind]`. Non e' un raggio di collisione generico: e' la taglia che
#      devi **vedere**;
#   1b. **EMENDATO 2026-10-14, per la segnalazione dell'utente.** La versione
#      precedente di questo punto diceva anche *«non e' la distanza di morso»*, e
#      **quella clausola e' la causa del difetto segnalato**: separando la
#      taglia che si vede dalla taglia che morde, un nemico puo' stare **dentro
#      il giocatore** senza mordere. Misurato: col `SIZE_FACTOR = 3.4` la banda di
#      sovrapposizione a vuoto e' **1,08 m** sul runner, **1,44** sul grunt, **2,40**
#      sul brute e **4,56 m sul boss**, e la banda **cresce con la specie**, che e'
#      l'opposto di quello che serve. Il piano e' in sez. 1.14-nona.
#      **Ora la regola e' l'inverso, ed e' strutturale:** il morso deve cadere
#      **non piu' tardi** del contatto visibile, quindi
#          morse_entro(k) >= taglia_disegnata(k) + taglia_disegnata_giocatore
#      e la banda di sovrapposizione a vuoto deve essere **zero per ogni
#      specie**. Non e' una soglia da tarare: e' un'identita' che si ottiene
#      **derivando la portata del morso dalla taglia disegnata**, cosi' il numero
#      che si vede e quello che morde non possono divergere per costruzione.
#   2. `radii.size() == horde.count`, allineata a `transforms`, `colors` e
#      `kinds`: l'indice `i` e' lo stesso nemico in tutti e quattro gli array.
#      Un array parallelo che non allinea e' il difetto che `tests/test_orda.gd`
#      gia' asserisce su `transforms`, e vale anche per questo;
#   3. cresce, si svuota e si ricompone **negli stessi punti** degli altri array
#      paralleli (`_resize_arrays`, `_apply_spawn`, `_kill`, `restart_run`): non
#      una strada nuova, che e' il modo in cui un array parallelo si stacca;
#   4. **e' il numero che il renderer deve disegnare.** La taglia disegnata di un
#      nemico e' proporzionale a `radii[i]`. Se il renderer ne usa una costante,
#      i due divergono, ed e' esattamente il difetto che m8 esiste per chiudere:
#      l'invariante e' la **proporzionalita'**
#      `disegnato_i / disegnato_j == radii[i] / radii[j]`, non la taglia assoluta,
#      cosi' il fattore di calibrazione puo' cambiare senza falsare l'invariante
#      e senza che l'onda debba ricominciare;
#   5. il raggio di una specie si cambia in **un posto solo**, `RADIUS` in
#      `src/sim/enemy.gd`. Non esiste una seconda copia del raggio da nessuna
#      parte, ne' nel renderer ne' in un test: e' il criterio n. 6 di m7, che era
#      stato scritto per i numeri di danno e che vale per tutti i numeri.

## Dichiarato dal vertice il 2026-10-13, **congelato**: il nome qui sotto e' l'unico
## che -orda scrive e -arena legge. Cambiarlo durante l'onda significa fermare
## l'onda e tornare dal vertice.

# --- Superficie di milestone 10 --------------------------------------------------
#
# ## Il difetto, e perché è una superficie
#
# L'utente ha deciso il 2026-10-13: «il nemico li **aggira davvero**». E' la prima volta che
# questo progetto introduce **geometria statica del mondo**, e la prima volta che una foglia
# deve costruire qualcosa che l'altra deve *evitare*: con un inseguimento in linea retta un
# ostacolo non è un ostacolo, è un muro, e il gioco si vince stando fermi dietro.
#
# `-orda` possiede la simulazione e il campo di percorrenza; `-arena` possiede la scena e
# costruisce gli ostacoli. `-orda` ha bisogno della loro forma e `-arena` ha bisogno di sapere
# che il dato è pubblico. Due foglie, due file, e **nessun contratto**: le due inventano il
# nome diverse e non si vedono mai. È la terza volta della stessa classe (§8, `wave` letto
# per nome dall'HUD; m8, `radii`).
#
# ## Congelato dal vertice il 2026-10-13
#
#     Game.obstacles : PackedVector3Array
#
# Un elemento per ostacolo, con la convenzione **dichiarata e non negoziabile**:
#
#     elemento = Vector3(centro_x, RAGGIO, centro_z)
#
# cioè **il raggio sta in `y`**, che è la sola cosa controintuitiva di questa superficie, e
# quindi l'unica che va detta tre volte. Motivo della scelta di *un solo array*: questo progetto
# ha già sofferto l'allineamento di array paralleli (`transforms`/`colors`/`kinds`/`radii`), e
# due array che possono staccarsi sono due array che si staccheranno. Con uno, non c'è nulla da
# allineare.
#
# ## Semantica, in cinque punti
#
#   1. **statici**: letti una volta sola da `-orda` quando costruisce il campo di percorrenza.
#      Non si muovono durante la partita. Se in futuro si muovono, è un'altra milestone e
#      questo contratto va emendato per primo;
#   2. **dischi sul piano XZ**: `y` è il raggio e **non** un'altezza. `-orda` non deve mai
#      leggere `elemento.y` come una quota, e `z` è la seconda coordinata del centro, non la
#      profondità. Un ostacolo che volasse sarebbe un'altra milestone;
#   3. **il raggio e' in metri ed e' positivo**: `elemento.y > 0.0` e' un invariante, non una
#      convenzione, e va asserito: un raggio zero è un ostacolo che non esiste e si distingue
#      dal raggio negativo solo per il crash;
#   4. **registrato in `_enter_tree()`, non in `_ready()`** (§5.1): l'orda costruisce il campo
#      di percorrenza al proprio avvio, quindi il dato dev'essere già dentro quando i figli
#      leggono. Registrazione in `_enter_tree()` **idempotente**;
#   5. **un insieme vuoto e' un errore, non un mondo senza muri.** Se `-orda` chiede gli
#      ostacoli e non sono registrati, il contratto **non** restituisce un array vuoto in
#      silenzio: dice che la piramide non è montata. Un array vuoto passerebbe **tutti** i
#      test di m10 perché «nessun ostacolo blocca nessuno» è vero anche quando non ce n'è:
#      è la classe di difetto di §1.6, cioè una macchina verificata che il gioco non chiama.
#
# ## Chi è solido e chi no, e perché è scritto qui perché non torni indietro
#
#   - **solido per il giocatore** (`src/player/player.gd`, di `-gameplay`): ci si scontra.
#   - **solido per il nemico** (`src/sim/`, di `-orda`): ci si scontra e **aggira**.
#   - **trasparente ai proiettili** (`src/weapons/`, di `-gameplay`): l'arma spara da sola e
#     i proiettili passano sopra.
#
# Il terzo punto è una **decisione del vertice**, non una conseguenza, e il motivo è la
# combinazione degenerata: se l'ostacolo blocca anche i proiettili, il giocatore che ci si
# mette dietro è **al sicuro e irraggiungibile** per sempre. Il gioco si vince stando fermi.
# Facendo l'ostacolo solido solo a chi cammina, l'ostacolo diventa un ostacolo e resta un
# ostacolo. «Proiettili che si fermano» è m11 e va detto come milestone.

## ## La strada dei dati, dichiarata dal vertice il 2026-10-13 dopo che l'onda l'ha chiesto
##
## Il vertice aveva scritto «i numeri sono di `-orda`, la costruzione è di `-arena`» **senza
## dire come i numeri arrivano**, e la conseguenza fu che `-arena` aspettava un valore che nessuno
## gli passava, con `OBSTACLE_LAYOUT` vuota e tutti i criteri di m10 rossi per «insieme vuoto».
## È la terza volta in questo progetto che due foglie hanno bisogno di un dato e il vertice ha
## dichiarato la superficie **senza il canale**: `wave` letto per nome, `radii`, e questa.
##
## Il canale è questo, ed è **una riga**:
##
##     -orda possiede i NUMERI:  src/sim/obstacles.gd -> layout(arena_radius)
##     -arena possiede la FORMA e LEGGE quei numeri, non li ricopia
##
## Quindi `-arena` fa `preload("res://src/sim/obstacles.gd")`, chiama `layout(arena_radius)` e
## registra **quel** risultato in `Game.obstacles` nel proprio `_enter_tree()`.
##
## **Perché un `preload` del file di un'altra foglia è lecito qui e non altrove**: la regola di §5
## vieta di prendere con `get_node("../..")` un dato che l'API non espone, perché copia una
## conoscenza e la copia mente alla prima riga cambiata. Qui il **proprietario del dato è
## dichiarato** (`src/sim/obstacles.gd` è di `-orda`), il dato ha **un solo produttore**, e la
## cosa che `-arena` ci mette dentro — il cilindro, l'altezza, i 12 segmenti, il colore — è sua.
## Se `-orda` cambia un raggio, l'ostacolo disegnato cambia **senza che `-arena` lo sappia**, ed è
## esattamente il comportamento voluto: due copie del numero non esistono.

# --- Registrazione -------------------------------------------------------------

## Implementazioni dei metodi, per nome di API. Stringhe perché GDScript non
## permette di riassegnare un `func` (vedi avvertenza in testa al file).
var _impl: Dictionary = {}

## Registra l'implementazione di un metodo del contratto.
##
##     Game.register_impl("nearest_enemy", self._nearest_enemy)   # Callable
##     Game.register_impl("nearest_enemy", self)                   # metodo omonimo
##
## La seconda forma è più corta: se `impl` è un oggetto, si assume il metodo
## con lo stesso nome della API.
func register_impl(api: String, impl: Variant) -> void:
	if not API.has(api):
		push_error("Game.register_impl: \"%s\" non e' un'API del contratto (le note: %s). Si chiede al vertice." % [api, ", ".join(API)])
		return
	var callable: Callable
	if impl is Callable:
		callable = impl
	elif impl is Object:
		callable = Callable(impl, api)
	else:
		push_error("Game.register_impl(\"%s\"): ci si aspetta una Callable o un oggetto, ricevuto %s" % [api, type_string(typeof(impl))])
		return
	if not callable.is_valid():
		push_error("Game.register_impl(\"%s\"): l'oggetto non ha il metodo %s" % [api, api])
		return
	_impl[api] = callable
	print("Game: %s implementato da %s" % [api, callable.get_object().get_class()])

## Un'API è registrata? Per i test e per il debug. Le foglie non ne hanno bisogno.
##
## **m10, 2026-10-13: `has_impl` non basta più, e la ragione è un difetto vero.**
## `_impl` tiene una `Callable`, e una `Callable` con l'oggetto **liberato** resta nel
## dizionario per sempre: `_impl.has(api)` dice vero, e la chiamata **crasha** con
## `Attempt to call function 'null::_player_position (Callable)' on a null instance`.
## Lo ha scoperto `tests/test_ui.gd`, che **riapre l'arena tre volte**: alla seconda, il
## giocatore precedente è stato liberato e la sua registrazione è rimasta. Un contratto che
## dichiara presente un membro che non esiste è un contratto rotto, ed è la stessa classe
## di difetto che `verify_m2_surface` era nato per evitare: un chiamante che riceve un
## errore che non dice quale delle foglie ha rotto il contratto, e lo riceve **a un'onda di
## distanza** dal momento in cui è successo.
func has_impl(api: String) -> bool:
	return _live(api).is_valid()

## L'unica strada con cui si legge `_impl`. Tutti e sei le API e `has_impl` passano di
## qui, quindi la regola «una registrazione il cui oggetto non esiste **non esiste**» è
## scritta **una volta sola**.
##
## La voce morta viene **cancellata**: lasciarla dentro significa che `has_impl` continuerebbe
## a dire vero, che `_warned` non riporterebbe il fatto, e che il prossimo registro finirebbe
## sopra una voce che nessuno guarda. Un contratto che mente in silenzio è peggio di uno che
## non è montato, perché il secondo è rumoroso e il primo no.
func _live(api: String) -> Callable:
	if not _impl.has(api):
		return Callable()
	var c: Callable = _impl[api]
	if c.is_valid():
		return c
	_impl.erase(api)
	return Callable()

# --- API dichiarate ------------------------------------------------------------
#
# Finché una foglia non registra la propria implementazione, il metodo resta
# uno stub: restituisce un valore neutro e avvisa una volta sola. Non è un
# fallback deliberato, è un rumore esplicito: un test che lo chiama deve
# fallire con un messaggio che dice chi deve registrarla.

## -orda. **Indice** del nemico vivo piu vicino a `from` entro `radius`, oppure
## -1 se non c'e' nessuno. Restituisce l'indice, NON un nodo: la regola "nessun
## nodo per nemico" (piano sez. 5, regola 1) rende un Node3D qualcosa che non
## esiste da restituire. E l'indice e' esattamente quello che `damage_enemy` si
## aspetta, cosi si spara a un nemico senza trasformare la referenza in un nodo.
func nearest_enemy(from: Vector3, radius: float) -> int:
	var c := _live("nearest_enemy")
	if c.is_valid():
		return c.call(from, radius) as int
	_missing("nearest_enemy", "terminal-gun-orda")
	return -1

## -orda. Applica `amount` di danno al nemico di indice `index` e gli somma
## `knockback` alla velocita'. Restituisce `true` se il nemico e' morto: e' l'unico
## modo per sapere di aver ucciso qualcosa senza aggiungere un segnale, e serve a
## -gameplay per l'XP.
##
## `knockback` e' un **impulso in m/s, gia' scalato dal chiamante, non
## normalizzato qui**: sommato cosi' alla velocita' del nemico, il suo modulo non
## dice gli metri spostati. Per verificare il criterio n. 4 ("knockback >= 0.3
## unita'") si simula un passo di tempo fisso e si misura la delta di posizione.
func damage_enemy(index: int, amount: float, knockback: Vector3) -> bool:
	var c := _live("damage_enemy")
	if c.is_valid():
		return c.call(index, amount, knockback) as bool
	_missing("damage_enemy", "terminal-gun-orda")
	return false

## -gameplay. Applica `amount` di danno al **giocatore**. Restituisce `true` se la
## mossa ha fatto scendere `hp`, `false` altrimenti.
##
## Questa firma e' l'inverso esatto di `damage_enemy`, ed esiste per la stessa
## ragione: fin qui il giocatore era **invulnerabile**, perche' `take_damage()`
## aveva **zero chiamanti** in tutto `src/` (misurato il 2026-10-13, un solo
## `grep`, una riga: la definizione). Scriverlo cosi' invece che
## `Game.player.take_damage(x)` non e' pignoleria: il secondo scopo obbliga
## -orda a **leggere `player.gd`**, cioe' il codice di un'altra foglia, che e'
## esattamente l'antipattern che la sezione 5 esiste per impedire. Qui -orda
## scrive `Game.damage_player(x)` e non sa cosa sia il giocatore.
##
## **Nota per chi impara dai numeri**: questa firma dichiara *che* il giocatore
## puo' perdere hp. Non dichiara che perda. Il criterio di m7 non e' "questa
## riga esiste" (esiste gia' ora, e non ha cambiato niente in un anno): e' che
## un `grep` trovi il chiamante **in `src/`** e non solo nei test. E' la
## settima volta della stessa classe di difetto, vedi il piano sez. 1.6.
func damage_player(amount: float) -> bool:
	var c := _live("damage_player")
	if c.is_valid():
		return c.call(amount) as bool
	_missing("damage_player", "terminal-gun-gameplay")
	return false

## -gameplay. Tira un proiettile da `pos` verso `dir` alla velocita' `speed`.
## Restituisce `true` se ha ottenuto uno slot dal pool, `false` se il pool era
## pieno. Come `nearest_enemy`, non restituisce un nodo: i proiettili non sono
## nodi, sono record come i nemici.
func spawn_projectile(pos: Vector3, dir: Vector3, speed: float) -> bool:
	var c := _live("spawn_projectile")
	if c.is_valid():
		return c.call(pos, dir, speed) as bool
	_missing("spawn_projectile", "terminal-gun-gameplay")
	return false

## -orda. Punto di arrivo casuale dentro l'arena, a una distanza comoda dal
## giocatore. Non va mai restituito come origine: Vector3.ZERO è ambiguo, è
## anche sotto il giocatore, quindi è un segnale di "non implementato".
func random_spawn_point() -> Vector3:
	var c := _live("random_spawn_point")
	if c.is_valid():
		return c.call() as Vector3
	_missing("random_spawn_point", "terminal-gun-orda")
	return Vector3.ZERO

## -orda/-gameplay. Posizione corrente del giocatore.
func player_position() -> Vector3:
	var c := _live("player_position")
	if c.is_valid():
		return c.call() as Vector3
	_missing("player_position", "terminal-gun-gameplay")
	return Vector3.ZERO

# --- Interno -------------------------------------------------------------------

## Avvisa una volta sola per metodo, dicendo chi deve registrarlo. Lo spam di
## warning ogni frame nasconderebbe il rumore utile.
var _warned: Dictionary = {}

func _missing(api: String, owner_agent: String) -> void:
	if _warned.has(api):
		return
	_warned[api] = true
	push_warning("Game.%s() non e' ancora registrata: tocca a %s farlo con Game.register_impl(\"%s\", self) nel proprio _ready()." % [api, owner_agent, api])