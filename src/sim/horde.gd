extends Node3D
## L'orda: 200 nemici vivi **senza un nodo per nemico**.
##
## Un nemico e' un record in `transforms` (dove sta) piu' cinque array paralleli
## (velocita', hp, specie, timer, raggio), non un `Node3D`. Il criterio della
## milestone e' `node_count < 120` con `horde.count == 200`: un nodo per nemico,
## da solo, farebbe fallire il criterio.
##
## ## L'API "massa" non passa da funzioni
##
## Disegnare 200 nemici non e' una query, e' un `MultiMeshInstance3D` che legge
## quattro campi. Per questo sono campi pubblici e non metodi:
##
##     horde.count        # quanti nemici vivi
##     horde.transforms   # PackedVector3Array, posizione mondo di ciascuno
##     horde.colors       # PackedColorArray, tinta per specie
##     horde.radii        # PackedFloat32Array, raggio del CORPO, in metri (m8)
##
## `transforms.size() == colors.size() == radii.size() == count`, sempre:
## l'invariante e' quello che permette all'arena di non controllare nulla.
##
## ## m8: `radii`, e perche' un array parallelo e non una strada nuova
##
## Il difetto che m8 chiude e' che **due numeri che dovrebbero essere uno solo
## erano due**: il nemico ha un raggio (`RADIUS[kind]`, in `src/sim/enemy.gd`)
## e un margine di morso (`TOUCH_REACH`), e il renderer ne disegnava **uno solo**,
## uguale per tutte e quattro le specie. Il giocatore leggeva quindi una taglia
## che non e' quella che morde, e `RADIUS` stava in un posto solo che nessuna
## altra foglia poteva raggiungere senza copiarlo.
##
## `radii` e' la strada dichiarata dal vertice in `src/core/contracts.gd`
## ("Supersficie di milestone 8", congelata il 2026-10-13): `-orda` la scrive,
## `-arena` la legge, e il nome non si inventa due volte.
##
## **Perche' un array parallelo e non un metodo.** Perche' `radii[i]` e' un dato
## grezzo al pari di `transforms[i]`: il renderer lo legge una volta per nemico
## dentro il ciclo di disegno, e un metodo che calcolasse `RADIUS[kinds[i]]`
## dentro quel ciclo sarebbe una ricerca per nemico per un numero che cambia
## solo quando cambia la specie.
##
## **Perche' non una strada nuova.** `radii` cresce, si svuota e si ricompone
## **negli stessi quattro punti** degli altri array paralleli: `_resize_arrays`,
## `_apply_spawn`, `_kill`, e da li' transitano `_populate` (quindi `restart_run`
## e `reseed`) e `_spawn_one`. Un array parallelo con una strada sua e' il
## modo in cui si stacca dagli altri, ed e' gia' successo in questo progetto
## con `transforms`. Il test asserisce `radii.size() == count` perche' un
## disallineamento qui e' un nemico disegnato con il raggio di un altro.
##
## ## La partita non e' fra i tre campi
##
## Onda, barra e `game_over` stanno in `src/sim/run.gd`, un oggetto che questa
## foglia tiene in un campo. Si leggono cosi':
##
##     horde.wave               # campo: numero dell'onda (lo legge anche l'HUD)
##     horde.wave_total()       # uccisioni che chiudono l'onda
##     horde.wave_remaining()   # la barra wave, in interi
##     horde.wave_bar_ratio()   # la stessa barra, da 0 a 1
##     horde.run_state()        # "playing" oppure "game_over"
##     horde.is_game_over()     # la stessa domanda in booleano
##     horde.restart_run()      # nuova partita: onda 1, orda ripopolata
##
## `wave` e' un campo e gli altri sono metodi perche' non sono la stessa cosa:
## `wave` e' un numero che un'altra foglia legge gia' per nome
## (`src/ui/hud.gd`), gli altri sono numeri **derivati** — la barra e'
## `wave_total - wave_killed`, e se fossero campi pubblici qualcuno potrebbe
## leggerne due in due momenti diversi e vedere una combinazione che non e' mai
## vera. I tre campi di sopra sono dati grezzi e il lettore ne fa quello che
## vuole; questi no.
##
## `population` resta il significato che aveva in m1: quanti nemici vivi
## **contemporaneamente**. Quanti ne vanno ammazzati in tutto lo dice la barra,
## e sono due numeri diversi (vedi `src/sim/run.gd`).
##
## ## m4: `population` non e' piu' una costante
##
## Prima di m4 questo campo valeva `MAX_ENEMIES` e `_build()` riempiva a quel
## numero: 200 nemici vivi al primo frame, e `_top_up()` li riportava a 200 a
## ogni passo. Nessun colpo svuotava l'arena. La **curva per onda** sta in
## `src/sim/run.gd` (`Run.population_of`), con la misura da cui e' uscita scritta
## li'; qui dentro ci sono solo il meccanismo e il credito di spawn.
##
## ## Le tre API del contratto (registrate in `_ready`)
##
##     Game.horde = self
##     Game.register_impl("nearest_enemy", self.nearest_enemy_index)
##     Game.register_impl("damage_enemy", self.damage_enemy)
##     Game.register_impl("random_spawn_point", self.random_spawn_point)
##
## Forma lunga (`register_impl` con la Callable), non `Game.nearest_enemy = ...`:
## GDScript rifiuta l'assegnazione a un nome che e' gia' un `func` e l'errore
## interromperebbe il `_ready()` (piano 5.1).
##
## `player_position` NON e' registrata qui: e' di -gameplay, e registrarne due
## impl per lo stesso nome e' una doppia registrazione.
##
## ## m7: l'orda ferisce il giocatore, e lo chiama dal ciclo di gioco
##
## Il chiamante di `Game.damage_player(x)` e' **questa foglia**: e' `_apply_bites`,
## dentro `step()`, e non un test. Il criterio n. 1 della milestone 7 e' una
## `grep` su `src/` e non un'asserzione, proprio perche' un test che chiama
## `damage_player` a mano dimostrerebbe che la funzione funziona e non che
## qualcuno la chiami.
##
## La strada e' il contratto e non `Game.player.take_damage(x)`: la seconda
## funzionerebbe e obbligherebbe questa foglia a leggere `src/player/player.gd`,
## cioe' il codice di un'altra (piano sez. 5, regola 3). I numeri del morso
## stanno in `src/sim/enemy.gd` e sono tre costanti, non una tabella: vedi la
## sezione "il morso" di quel file, che porta la misura da cui sono usciti.
##
## ## Perche' qui il contratto si prende con `get_node_or_null` e non con `Game.`
##
## Questo file viene compilato anche dai processi di test lanciati con
## `--script`, e in quel contesto l'autoload `Game` non e' ancora fra le
## costanti globali di GDScript: l'identificatore nudo `Game` non risolve e la
## compilazione si ferma con `Compile Error: Identifier not found: Game`,
## **prima** che una riga di questo file venga eseguita. Il nodo che si ottiene
## e' lo stesso identico singleton: si aggira la compilazione, non il
## contratto. Vedi `_contract()` e piano 5.3.

const E = preload("res://src/sim/enemy.gd")
const Grid = preload("res://src/sim/spatial_grid.gd")
const Spawner = preload("res://src/sim/spawner.gd")
const Run = preload("res://src/sim/run.gd")
const Flow = preload("res://src/sim/flow_field.gd")
const Obst = preload("res://src/sim/obstacles.gd")

## Capienza massima: decisa qui, una volta sola, e mai piu' cambiata.
const MAX_ENEMIES := 200
## Quanti colpi recenti si ricordano per sfx e flash, in un anello di capienza fissa.
const HITS_KEPT := 64
## Raggio entro cui due nemici si spingono, e quanti vicini si controllano per
## ciascuno. Il tetto e' quello che tiene il costo costante.
const SEPARATION_RADIUS := 1.6
const SEPARATION_CHECKS := 6
const SEPARATION_FORCE := 11.0
## Dalla zona dei colpi dello sparo, un nemico non deve arrivare addosso.
const MIN_SPAWN_GAP := 12.0
## Popolazione viva **contemporaneamente** dell'onda corrente. **Non e' una
## costante**: e' uno specchio di `Run.population_of(run.wave)`, tenuto allineato
## da `_sync_population()` negli stessi punti in cui cambia `wave` (vedi il
## commento di quel metodo). Il valore di partenza non e' 200 ma
## `Run.POP_BASE` = 25: la curva e la sua misura sono in `src/sim/run.gd`.
var population: int = 0

## ## m11-ter: `population_scale`, la cucitura di misura dell'apertura
##
## **Un moltiplicatore, dichiarato, che il gioco non tocca mai.** Esiste per una
## ragione sola, e la ragione e' scritta qui perche' un campo senza ragione
## dichiarata e' un numero che qualcuno puo' alzare per far passare un test.
##
## La sonda `docs/piramide/probe_survive.gd` (del vertice) ha misurato che al
## raggio consegnato di 60,0 m **tutte le morti cadono sull'onda 1 con 25 nemici
## vivi**, mai sulla 2 (piano §1.14-seque): quindi la leva e' **l'apertura**, non
## il fondo. Per sapere quanto deve scendere `Run.POP_BASE` serve poter variare
## la popolazione dell'onda 1 **a runtime**. Prima di questo campo non si poteva:
## `Run.POP_BASE` e' una `const`, e una `const` non e' un punto da sonda — si
## cambiava il sorgente a ogni tentativo, che e' il modo piu' lento di misurare e
## il piu' facile di sbagliare.
##
## **Il default e' 1.0 esatto, quindi i numeri di oggi non si muovono.**
## `roundi(intero * 1.0)` restituisce quell'intero, quindi l'onda 1 parte da
## `Run.POP_BASE` = 25 come prima e i quattro numeri delle milestone restano
## quelli che sono.
##
## **Chi lo tocca: solo una sonda, e solo per la durata della misura.** Il
## percorso di gioco non lo tocca, e questo non e' una promessa ma un criterio:
## `tests/test_orda.gd` sezione 15 conta le occorrenze **di codice** del nome in
## tutto `res://src` e in `res://scenes`, e va rossa se compare un terzo punto,
## se un `restart_run()` la tocca, o se una scena ne scrive una seconda copia del
## default. La riga che mette la scala dentro la popolazione e' `_sync_population`,
## ed e' l'unica.
var population_scale: float = 1.0

## Se falsa, l'orda non si riempie da sola: serve al test per vedere il
## conteggio scendere davvero.
var auto_respawn: bool = true
## ## `seed`: il seme **della disposizione che e' in campo**, non un default
## ##
## Tre cose, e sono tre cose diverse:
##   - **`0`** = la disposizione in campo e' casuale: non la si puo' riprodurre.
##   - **un numero** = la disposizione in campo e' quella di quel seme, e si puo'
##     rifare: e' il contratto di m3 (`reseed(s)`), verificato da
##     `tests/test_arena.gd` e da `tests/test_orda.gd`.
##   - **il default dell'avvio** e' un'altra cosa ancora, e non sta qui: e' la
##     proprieta' `seed` con cui `scenes/arena_main.tscn` monta il nodo `Horde`,
##     che e' di `-arena`. Quel numero rende **la prima partita** riproducibile
##     (senza di lui ogni montaggio della scena e' una partita diversa, e ogni
##     durata misurata sul gioco e' un campione: piano §1.14-ter).
##
## `_build()` lo legge **una volta sola**, nel `_ready()`: dopo l'avvio il campo
## si cambia solo da `reseed(s)` e da `restart_run()`, e le due scrivono qui il
## valore che descrive **la disposizione che stanno scrivendo**.
var seed: int = 0

# --- API massa (piano 5) -------------------------------------------------------

## Nemici vivi. Vale sempre `transforms.size() == colors.size() == count`.
var count: int = 0
## Posizione mondo di ogni nemico vivo. Cio' che arena legge per il MultiMesh.
var transforms: PackedVector3Array = PackedVector3Array()
## Tinta per nemico (per specie).
var colors: PackedColorArray = PackedColorArray()
## Raggio del **corpo** di ogni nemico vivo, in metri: `radii[i] ==
## RADIUS[kinds[i]]`. Non e' la distanza a cui morde (quella e' `radii[i] +
## TOUCH_REACH`, e la condizione sta in `src/sim/enemy.gd`), e non e' un raggio
## di collisione generico: e' **la taglia che devi vedere**. Superficie
## congelata in `src/core/contracts.gd`, punto 4: e' il numero che il renderer
## deve disegnare, e la proporzione `disegnato_i / disegnato_j == radii[i] /
## radii[j]` e' l'invariante, non la taglia assoluta.
var radii: PackedFloat32Array = PackedFloat32Array()

# --- m10: gli ostacoli e il campo di percorrenza ------------------------------
#
# ## Cosa c'e' qui e cosa non c'e'
#
#     horde.obstacles      # i dischi, gia' nella forma del contratto
#     horde.flow_field     # il campo di percorrenza, o null
#     horde.flow_problem   # il motivo per cui il campo non c'e', "" se c'e'
#
# Il campo e' **dati**, non nodi: un `RefCounted` che l'orda tiene in un campo e
# che muore con lei. `node_count` non si muove di una unita' e l'ordine resta in
# tre nodi (criterio n. 7).
#
# ## Perche' `flow_problem` e' un campo e non uno `if` silenzioso
#
# Il punto 5 della semantica di m10 e' la trappola dell'onda: «un insieme vuoto
# e' un errore, non un mondo senza muri». Un campo costruito su un insieme vuoto
# passerebbe **tutti** i criteri di m10 — «nessun ostacolo blocca nessuno» e'
# vero anche quando non ce n'e' — e non avrebbe mai aggirato niente: e' la
# classe di difetto di §1.6, una macchina verificata che il gioco non chiama.
#
# Quindi qui non esiste il fallback «se non ci sono ostacoli, agisci come se non
# ci fossero»: esiste **un campo che dice che mancano**. Chi legge
# `flow_problem` sa perche' l'evitamento e' spento, e `tests/test_orda.gd` lo
# asserisce: la piramide non montata porta la porta rossa invece di un verde
# costruito sul nulla.
#
# La simulazione intanto **prosegue senza evitamenti**: e' cio' che le rende
# indispensabili le altre foglie che chiamano `step()` su un'orda senza ostacoli,
# e non e' un silenzio: `_load_obstacles()` avvisa una volta sola per processo.
var obstacles: PackedVector3Array = PackedVector3Array()
var flow_field = null
var flow_problem: String = ""
## Quante volte il campo e' stato ricostruito in questo processo. La telemetria
## che rende verificabile «da fermo il campo non costa niente».
var flow_rebuilds: int = 0

# --- Dati per nemico: array paralleli, tutti lunghi `count` --------------------

var velocities: PackedVector3Array = PackedVector3Array()
var hp: PackedFloat32Array = PackedFloat32Array()
var kinds: PackedInt32Array = PackedInt32Array()
## Secondi di pausa dopo un colpo. Colpisce solo l'animazione, non la fisica.
var timers: PackedFloat32Array = PackedFloat32Array()

# --- Il morso (milestone 7) ---------------------------------------------------
#
# Due array paralleli, e sono loro che portano la meta' di questa foglia in m7:
# il nemico che chiama `Game.damage_player(x)` dal ciclo di gioco.
#
# `bite_timers[i]` e' da quanto tempo il nemico i e' addosso al giocatore,
# `bites[i]` vale 1 **solo nel passo in cui quel nemico morde**. La decisione
# ("sono abbastanza vicino, e il periodo e' passato") sta in
# `src/sim/enemy.gd`, dove stanno le specie; qui si applica solo il tetto dei
# morderci contemporanei e si chiama il contratto.

var bite_timers: PackedFloat32Array = PackedFloat32Array()
## ## m12: `bite_latch`, i due bit del **rientro**, e perche' un array parallelo
##
## `bite_latch[i]` e' un intero con due soli bit possibili:
##
##   - `E.BITE_IN_PORTATA` — **il passo scorso** questo nemico era a portata di
##     morso. E' il bordo in salita della portata, cioe' il contatto come causa.
##   - `E.BITE_SPENT` — ha gia' morso e **non puo' ripetere finche' non esce
##     dalla portata**. E' l'unico limite sul morso di un singolo nemico.
##
## **Perche' serve e non basta `bites`.** `bites[i]` dice «morde in questo
## passo» e viene azzerato ogni passo: da solo non distingue *sta morendo per la
## prima volta* da *sta morendo di nuovo*, che e' esattamente la distinzione che
## il rientro deve fare. E non puo' derivarsi dalla posizione, perche' «era a
## portata al passo scorso» e' un fatto **del nemico**, non della sua distanza di
## adesso: uno che entra ed esce dalla portata a ogni passo ha la stessa distanza
## di uno che ci sta fermo, e i due devono comportarsi in modo opposto.
##
## Vive e muore negli stessi quattro punti degli altri array paralleli
## (`_resize_arrays`, `_apply_spawn`, `_kill`, e da li' `_populate`,
## `restart_run` e `reseed`), e `tests/test_orda.gd` asserisce
## `bite_latch.size() == count` per la stessa ragione per cui lo fa su
## `bite_timers`: un array parallelo disallineato e' un nemico che morde con lo
## stato di un altro.
var bite_latch: PackedInt32Array = PackedInt32Array()
var bites: PackedInt32Array = PackedInt32Array()

# --- m13: il mortar, e i colpi in volo -----------------------------------------
#
# ## Perche' un array e non un nodo per colpo
#
# Un colpo in volo e' un dato, non un oggetto di scena: se ogni colpo fosse un
# `Node3D` il `node_count` salirebbe con il fuoco dell'orda, che e' esattamente
# il tetto che questa foglia non puo' toccare (e che il gia' successo con
# l'audio). Quindi `mortar_shots` e' un `PackedVector3Array` di capienza fissa,
# riscaldato una volta sola in `_build()` come `hit_positions`: nel ciclo di gioco
# non si alloca niente e `resize` non viene chiamato.
#
# ## La convenzione dell'elemento, detta una volta sola
#
#     elemento = Vector3(x_atterraggio, z_atterraggio, secondi_residui)
#
# cioe' **il punto in cui il colpo cade sta in `x` e `y`, e i secondi che mancano
# stanno in `z`**. E' la trappia di m10 (il raggio nel disco sta in `y`) ripetuta
# su un altro array, e per questo `mortar_shot_at(i)` esiste: ritorna il punto
# **del mondo** con la convenzione gia' disfatta, cosi' `-arena` non deve sapere
# che `y` e' una `z`.
var mortar_shots: PackedVector3Array = PackedVector3Array()
## Quanti colpi sono **in volo**. E' il numero che il renderer chiede prima di
## iterare: i vivi sono `mortar_shots[0 .. mortar_shot_count)`. Vale sempre
## `mortar_shot_count <= mortar_shots.size()`, e la capienza e' quella scaldata
## all'avvio, quindi nel ciclo di gioco non cresce mai.
##
## Superficie **congelata dal vertice**: `-orda` la scrive, `-arena` la legge, e
## il nome non si inventa due volte.
var mortar_shot_count: int = 0
## Danni di esplosione consegnati nell'ultimo passo. Telemetria, come
## `touch_damage_last`: serve a un test per guardare l'economia del colpo e non
## e' un secondo posto dove il danno e' scritto.
var mortar_damage_last: float = 0.0
## **Quanti** colpi sono caduti sul giocatore nell'ultimo passo, non solo quanto
## danno. `mortar_damage_last` dice il valore: due colpi che cadono nello stesso
## passo danno lo stesso numero e il campo non distingue l'uno dall'altro, quindi
## un test che volesse contare gli eventi ricevuti dal giocatore avrebbe un numero
## che non torna.
##
## Serve a `tests/test_orda.gd` per il criterio delle due fonti di danno (morso e
## colpo): e' l'unico posto dove "quanti eventi sono arrivati" e' un numero
## dichiarato e non una ricostruzione del test.
var mortar_impacts_last: int = 0
## Secondi alla prossima ricarica per nemico. Parallelo come gli altri: entra
## negli stessi quattro punti (`_resize_arrays`, `_apply_spawn`, `_kill`,
## `restart_run`).
var mortar_timers: PackedFloat32Array = PackedFloat32Array()
## Richiesta di colpo del passo, 1 = spara adesso. Come `bites[i]`: la decisione
## e' in `src/sim/enemy.gd`, qui si applica.
var mortar_fire: PackedInt32Array = PackedInt32Array()
## Da dove viene il numero del telegrrafo che sta sul contratto: `contratto` se
## e' stato registrato, `fallback` altrimenti. Come `body_scale_source`: distingue
## «canale scritto» da «canale che nessuno ha scritto», che sembrano uguali.
var mortar_source: String = "fallback"

## ## m12: `bite_mode`, e perche' e' un campo **pubblico e dichiarato**
##
## Il gioco gira su `E.BITE_CONTACT`: **il contatto e' la causa del morso**. Un
## nemico che entra nella sua portata e il passo prima non c'era morde, e non puo'
## ripetere finche' non ne esce.
##
## L'altro valore, `E.BITE_TIMER`, e' il morso **schedulato a timer** di prima:
## entra solo se il nemico e' a portata da un periodo intero (1,00 s sul runner).
## **Non e' mai quello di partita.** Vive perche' `tests/test_orda.gd` deve poter
## rimetterlo, girare il gioco vecchio e riportare i numeri di prima accanto a
## quelli di adesso: un rimedio che si puo' solo descrivere e non misurare non
## e' un rimedio verificato.
##
## Perche' un campo e non un `static var` dentro `enemy.gd`: un `static var` e'
## una superficie che qualunque file puo' cambiare in qualunque momento, e
## quindi una superficie che il gioco non controlla. Qui il valore vive nell'ordine
## ed e' dichiarato qui sotto, e `tests/test_orda.gd` conta le occorrenze **di
## codice** di questo nome in `res://src` e va rossa se compare in un terzo punto.
var bite_mode: int = E.BITE_CONTACT

## Quanti secondi devono passare fra due morsi **che arrivano addosso**, di
## qualunque specie. E' il tetto che tiene insieme la m7, ed e' nato da una
## prima idea **sbagliata** che la misura ha smentita (vedi sotto).
##
## ## La prima idea, e perche' la misura l'ha buttata
##
## Il primo tentativo era un tetto di **3 nemici che mordono nello stesso passo**,
## col nome `TOUCH_BITERS`. La misura su 30 s a regime (in `tests/test_orda.gd`)
## dice: nell'onda 1 il passo peggiore ha **1** morso e sull'onda 8 ne ha **1**.
## Il tetto non mordeva mai: e' un tetto per passo, e un passo dura 1/60 s, quindi
## tollera 180 morsi al secondo. Non era un tetto, era una decorazione.
##
## ## Il tetto vero, e il numero che l'ha prodotto
##
## Quello che cresce con la folla non e' il danno di un morso, e' la **cadenza**:
## 2.20 morsi al secondo con 25 vivi e **6.50** con 200, misurati senza nessun
## tetto. Un tetto sulla cadenza e' quindi quello che serve. `TOUCH_INTERVAL =
## 0.40 s` fissa il massimo teorico a 2.5 morsi/s; la cadenza **misurata** con
## il tetto dentro e' 1.07-1.57 morsi/s, sotto quel massimo perche' un morso
## respinto non e' rimesso in coda: chi perde aspetta un periodo intero.
##
## Il risultato e' che l'orda da 200 vivi fa **2.56 volte** il danno al secondo
## dell'orda da 25, contro una crescita di circa 5.7 che senza il tetto avrebbe
## misurato lo stesso campione (contatto 3.3 volte x morso medio 1.7 volte, perche'
## a 200 vivi l'anello intorno al giocatore e' fatto di nemici piu' grossi). In
## secondi da fermo al centro: **6.5 s** con 200 vivi, **16.5 s** con 25.
## ## m12: il tetto e' passato da **0,40 s a 0,15 s**, e perche' e' un vincolo
##
## Il tetto **non** e' un numero di difficolta' scelto a occhio: e' una condizione
## che il gioco **non puo' violare**, e il numero che la impone e' il **tempo di
## contatto misurato** (`tests/test_orda.gd`, sezione 11-z: il giocatore che
## attraversa l'orda a 13,65 m/s e quanto resta dentro la portata di morso di
## ciascuna specie).
##
##     TOUCH_INTERVAL  <  contatto peggiore del runner   =  0,233 s (14 passi)
##
## **Se il tetto fosse piu' lungo del contatto, il difetto di oggi tornerebbe con
## un tetto nuovo**: il nemico entra in portata mentre il tetto e' ancora
## scarico, il morso verrebbe rimandato di qualche decimo di secondo, e il
## nemico uscirebbe dalla portata senza aver mai morso. E' esattamente la
## segnalazione dell'utente del 2026-10-15 («se i nemici mi toccano mi
## danneggiano»), riprodotta da un tetto invece che da un periodo.
##
## **Il prima e il dopo, nella stessa frase.**
##
## | | prima (m7) | dopo (m12) |
## |---|---|---|
## | `TOUCH_INTERVAL` | **0,40 s** (massimo 2,50 morsi/s) | **0,15 s** (massimo **6,67 morsi/s**) |
## | contatto misurato del runner | non misurato | **0,233 s** (14 passi), caso peggiore su 3 geometrie |
##
## **Il tetto piu' corto non vuol dire piu' danni: vuol dire che il tetto
## smettere di essere la cosa che decide se un morso arriva addosso.** Con 0,40 s
## il tetto era 1,7 volte il contatto del runner e la **speranza** di morso del
## nemico attraversato era zero; con 0,15 s il tetto e' 0,64 volte il contatto e
## **un morso che arriva al passo giusto arriva davvero**, perche' il tetto si
## scarica dentro la finestra. Il massimo teorico sale da 2,50 a 6,67 morsi/s, ma
## e' un tetto che il contatto **raggiunge** solo con l'orda addosso: la cadenza
## **misurata** resta quella che la sezione 11 stampa a ogni lancio, e quei
## numeri sono la realta' del gioco, non questo massimo.
##
## **Perche' 0,15 e non 0,20, che basterebbe.** 0,20 s e' sotto lo 0,233 s misurato
## di appena 0,033 s: il numero che lo giustifica e' il **minimo su tre
## geometrie**, non il minimo vero, e con un margine del 14% la finestra puo'
## chiudersi per una disposizione che non e' stata campionata. 0,15 s lascia il
## 36% di margine e resta sotto il tetto del giocatore vero, che scarta i morsi
## per `INVULN_AFTER_HIT = 0,7 s`: sotto 0,7 s il tetto dell'ordine non e' mai
## quello che limita il giocatore, quindi questo numero **non e' un tetto sul
## giocatore** e non sposta la difficolta' per meta'.
const TOUCH_INTERVAL := 0.15
## Danno consegnato al giocatore nell'ultimo passo. Telemetria: serve a un
## test per guardare l'economia del morso e a un eventuale HUD per il lampo,
## e non e' un secondo posto dove il danno e' scritto (criterio n. 6 di m7).
var touch_damage_last: float = 0.0
## Quanti nemici hanno morso davvero nell'ultimo passo (non quanti potevano).
var touch_bites_last: int = 0

# --- Telemetria ---------------------------------------------------------------

## Nemici ammazzati dall'inizio della partita.
var kills: int = 0
## Raggio utile dell'arena, ripreso dal contratto a ogni passo.
##
## ## Questo numero e' un FALLBACK DICHIARATO, non una fonte (m9)
##
## Il numero che vale davvero e' quello del contratto, e la sua fonte e'
## `src/render/arena.gd:ARENA_RADIUS` (**60.0**), che la registra sul contratto in
## `_enter_tree()`; da li' `_contract_radius()` la rilegge a ogni passo, quindi in
## partita questa riga **non viene mai usata**. Vive per il caso in cui il
## contratto non c'e' ancora (i processi di test lanciati con `--script`, e
## l'ordine di ingresso in cui l'orda e' costruita prima dell'arena).
##
## ## m11: **46.0 -> 60.0**, e da dove viene il numero
##
## Il **prima** e il **dopo** nella stessa frase, perche' il raggio non e' una
## costante di stile: e' la misura su cui poggia tutto il resto di questa foglia.
##
##   - **46.0** (m9): il valore era uscito dalla sonda
##     `docs/piramide/probe_arena_density.gd` (piano 1.12): a 200 nemici lo
##     spazio libero passava dall'85,2% al 94,6% e la bolla sicura piu' grande da
##     9,5 a 19,1 m. Era il massimo che quella sonda guardava;
##   - **60.0** (m11): il valore e' uscito dalla sonda
##     `docs/piramide/probe_survive.gd` (piano 1.14-quinque), che misura la
##     **sopravvivenza** di uno schivatore al variare del raggio, tre semi per
##     raggio e con due casi a risposta nota (a R = 12 m, dove non si puo'
##     schivare, lo strumento **deve** morire: e' morto a 61,20 s). Caso peggiore:
##     **55,33 s a 46 m**, **146,72 s a 60 m**, fattore **2,65**; da 60 a 75 m il
##     fattore e' **1,07**, quindi il ginocchio e' a circa 60 m e oltre non si
##     compra niente.
##
## Nessuna riga di `src/sim/` e' cambiata per questo passaggio: e' cambiata **la
## geometria su cui la simulazione converge**, che e' esattamente la forma del
## 28 -> 46 di m9. Quello che ne deriva e' dichiarato dove viene misurato, cioe'
## in `tests/test_orda.gd` (la sezione sul raggio): la griglia del campo passa
## da 55x55 a 69x69 celle, i dischi da 2,99 a 3,90 m di raggio, e il costo per
## passo e' rimisurato con lo stesso codice a 46 m e a 60 m.
##
## Un fallback che dicesse 46.0 mentirebbe proprio nel caso in cui nessuno lo
## guarda, cioe' quando l'arena non si e' ancora registrata: e in quel caso
## nessuna delle misure qui sopra sarebbe quella che vale in partita.
##
## Il criterio n. 2 di m9 e' sulla **deriva**, non sull'assenza: se qualcuno
## cambiasse una delle copie senza cambiare le altre, la porta va rossa. Di questa
## copia si occupa `tests/test_orda.gd` (legge questa riga dal sorgente e la
## confronta col default del contratto); delle altre si occupa
## `tests/test_arena.gd`.
var arena_radius: float = 60.0
## Ultimi colpi ricevuti, in un anello di capienza fissa: `hit_count` quanti
## sono validi. Serve a sfx/flash senza toccare gli array e senza allocare.
var hit_count: int = 0
var hit_positions: PackedVector3Array = PackedVector3Array()
var hit_kinds: PackedInt32Array = PackedInt32Array()
## Numero di celle mai viste dalla griglia: dopo il riscaldamento deve restare 0.
var grid_unknown_cells: int = 0

# --- La partita ---------------------------------------------------------------
#
# Senza tipo dichiarato, come `_grid`: l'oggetto lo crea `_build()`, e in GDScript
# `:=` su una variabile senza tipo non compila. Si indica il tipo dove si legge.
# `run` non e' nullo dopo `_build()`, che e' l'unico posto in cui si costruisce.

## Stato della partita e scala delle onde. Oggetto, non nodo: un restart non
## crea e non libera niente nell'albero.
var run = null

## Pesi delle specie dell'onda corrente. Ricalcolati **solo** al cambio d'onda e
## in `_build()`: ogni spawn legge questo array e non ne costruisce uno, quindi lo
## spawn non alloca nel ciclo di gioco.
var _weights: PackedFloat32Array = PackedFloat32Array()
## ## m17: gli stessi pesi **con la voce del mortar a zero**, gia' costruiti
##
## Il mortar non e' spendibile prima di `Run.MORTAR_AFTER_S` (180,0 s: il terzo
## minuto, vedi la dichiarazione di `elapsed_s` in `src/sim/run.gd`), quindi lo
## spawn ha bisogno di due tabelle e non di una. Sono **due array gia' scaldati**,
## non due calcoli: `_sync_weights()` scrive entrambi e `_pick_kind()` sceglie
## l'uno o l'altro con un `if`, quindi il cammino di spawn non alloca e non
## ricostruisce niente (8 spawn al secondo, ma la regola vale comunque: nel ciclo
## di gioco non si costruisce un array).
##
## **Perche' `_weights` resta la tabella dichiarata e non quella col mortar a
## zero**: `_weights` e' quello che l'orda *dichiara* di usare, e un test che lo
## legge (`horde.get("_weights")`, `-arena` in `tests/test_arena.gd`) lo confronta
## voce per voce con `Spawner.wave_weights(onda)`. La soglia e' una condizione
## sul **tempo**, quindi vive nel ramo che sceglie, e non dentro la tabella.
var _pesi_senza_mortar: PackedFloat32Array = PackedFloat32Array()

# --- Interno ------------------------------------------------------------------

var _grid = null
var _grid_extent: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Bersaglio dei nemici. Se -gameplay ha registrato `player_position` e' la sua
## posizione, altrimenti il centro dell'arena.
var _focus: Vector3 = Vector3.ZERO
var _sep_buf: PackedInt32Array = PackedInt32Array()
## Credito di spawn accumulato, in nemici. `_top_up()` lo riempie di
## `run.spawn_rate() * delta` e ne spende solo interi: e' il posto dove vive il
## "non tutti insieme" di m4. Il tetto a 1 (in `_top_up`) vuol dire che un passo
## lento non accumula un raffica e la scarica tutta al passo dopo.
var _budget: float = 0.0
var _built: bool = false
var _registered: bool = false
var _grid_dirty: bool = true
var _contract_node: Node = null
## Il giocatore, tenuto dal dato `Game.player`. Si rivede solo se non e' piu'
## valido: nel ciclo di gioco non si fa una ricerca per nome ogni frame.
var _player_cache: Node = null
## Quanto manca al **prossimo** morso che puo' arrivare addosso, in secondi.
## E' il tetto di cadenza di `TOUCH_INTERVAL`, ed e' l'unico stato che serve:
## nessun cursore, nessun conteggio di morderci per passo (vedi la sezione
## "il morso" in testa al file: quel tetto li' e' stato provato e non mordeva).
var _bite_interval_left: float = 0.0

func _ready() -> void:
	_build()
	_register()

## Il contratto, come nodo. Vedi la nota in testa al file: `Game.` non compila
## sotto `--script`, `get_node_or_null("Game")` si'. Va risolto una volta sola:
## nel ciclo di gioco una ricerca per nome a ogni frame sarebbe sprecata.
func _contract() -> Node:
	if _contract_node == null and is_inside_tree():
		_contract_node = get_tree().root.get_node_or_null("Game")
	return _contract_node

## Raggio utile dell'arena, letto dal contratto. Se il contratto non c'e' ancora
## si tiene il valore gia' in campo: meglio un raggio che uno zero.
func _contract_radius() -> float:
	var game := _contract()
	if game != null:
		var r: float = game.arena_radius
		return maxf(r, 6.0)
	return maxf(arena_radius, 6.0)

## ## m11-quarta: il fattore di calibrazione del corpo, **letto e non copiato**
##
## `SIZE_FACTOR` e' di `-arena` (`src/render/horde_renderer.gd`) e il contratto
## lo espone come `Game.enemy_body_scale`. Qui viene **letto una volta sola**,
## all'avvio, come gli ostacoli di m10: `-arena` lo registra in `_enter_tree()`,
## che gira prima del `_ready()` di questo nodo, quindi non e' una corsa.
##
## **Perche' non una `const` e non un `3.4` scritto qui**: un numero copiato
## mente alla prima riga cambiata di `-arena`, che e' il difetto delle sei copie
## di m9 e la ragione per cui il vertice ha aperto questo canale.
##
## ## Il fallback, e perche' e' `1.0` e non il numero del renderer
##
## `BODY_SCALE_FALLBACK = 1.0` vuol dire **nessuna calibrazione**: e' il caso in
## cui il contratto non c'e' (l'orda montata da sola, sotto `--script` senza
## autoload) e quindi la simulazione non sa quanto e' grande il corpo che si
## vede. Non si scrive qui il numero di un'altra foglia nemmeno come riserva:
## quando il canale e' chiuso `body_scale_source` dice `fallback`, e chi legge
## sa che la banda non e' verificabile finche' `-arena` non registra.
var body_scale: float = BODY_SCALE_FALLBACK
## Da dove viene il numero in campo: `contratto` oppure `fallback`. Non e' un
## campo per il gusto di averlo: e' la riga che distingue «canale usato» da
## «canale mai scritto da nessuno», che sono due cose diverse e sembrano uguali.
var body_scale_source: String = "fallback"

const BODY_SCALE_FALLBACK := 1.0

func _load_body_scale() -> void:
	body_scale = BODY_SCALE_FALLBACK
	body_scale_source = "fallback"
	var game := _contract()
	if game == null:
		return
	var v = game.get("enemy_body_scale")
	if v == null:
		return
	var s := float(v)
	if s <= 0.0:
		return
	body_scale = s
	body_scale_source = "contratto"

## ## m13: i due numeri del mortar **scritti** sul contratto, non letti
##
## Qui la direzione e' opposta a `enemy_body_scale`: non siamo noi a leggere un
## numero di `-arena`, siamo noi a **dargli** il nostro. Il vertice ha dichiarato
## i due campi (`mortar_telegraph_s`, `mortar_blast_m`) dicendo che la fonte e'
## `src/sim/enemy.gd`, e `-arena` li legge senza possederli.
##
## **Perche' non si copia il default del contratto.** Quel default (1,0 s e 4,0 m)
## e' un valore di partenza, non una fonte: se `-arena` leggesse quel numero,
## la cupola mostrerebbe un tempo che la simulazione non usa, e cioe' direbbe
## «schiva qui» mentre il colpo cade altrove — la classe di difetto delle sei
## copie di m9, che questo progetto ha gia' pagata una volta.
##
## ## Perche' si scrive con `set()` e non con `game.campo = x`
##
## `_contract()` e' un `Node`: il contratto e' il nodo che si ottiene a runtime,
## non un tipo noto al compilatore, quindi `get`/`set` sono la strada che questo
## file usa gia' per `obstacles` ed `enemy_body_scale` (piano 5.1, 5.3).
func _load_mortar() -> void:
	mortar_source = "fallback"
	var game := _contract()
	if game == null:
		return
	game.set("mortar_telegraph_s", E.telegraph_for(body_scale))
	game.set("mortar_blast_m", E.blast_radius_for(body_scale))
	mortar_source = "contratto"

## La portata del morso di una specie, **come la calcola la simulazione**. Non e'
## una copia della formula di `enemy.gd`: e' la stessa funzione, e il test di
## m11-quarta confronta le due cose perche' una copia, qui, mentirebbe.
func bite_range_of(kind: int) -> float:
	return E.bite_range_of(kind, body_scale)

func _physics_process(delta: float) -> void:
	step(delta)

# --- Costruzione --------------------------------------------------------------

func _build() -> void:
	if _built:
		return
	_built = true
	arena_radius = _contract_radius()
	# Gli ostacoli prima di **qualsiasi** spawn: la disposizione iniziale deve
	# gia' sapere dove sono i muri, altrimenti il primo nemico della partita
	# nasce dentro uno e il criterio n. 2 ha gia' un nemico da segnalare al
	# primo frame.
	_load_obstacles()
	# Il seme si legge **una volta sola**, qui: `seed` e' il default che la scena
	# consegna, e da questo momento in poi lo cambiano solo `reseed(s)` e
	# `restart_run()`. Il ramo «casuale» non e' una riga qui dentro: e'
	# `_reroll()`, lo stesso che chiama il restart, cosi' «casuale» e' scritto in
	# un posto solo e non in tre (`_build`, `reseed`, `restart_run`).
	if seed != 0:
		_rng.seed = seed
	else:
		_reroll()
	# La griglia si riscalda su un quadrato piu' largo dell'arena: i nemici non
	# escono mai, ma il knockback puo' spingerli oltre il raggio utile.
	# `_sync_grid()` fa `setup()` solo quando l'estensione cambia davvero:
	# `setup()` ricrea tutti i secchielli, quindi rifarlo ogni frame sarebbe
	# esattamente l'allocazione nel ciclo di gioco che questo file evita.
	_grid = Grid.new()
	_sync_grid()
	_sep_buf.resize(SEPARATION_CHECKS)
	hit_positions.resize(HITS_KEPT)
	hit_kinds.resize(HITS_KEPT)
	# ## m13: la capienza dei colpi in volo, **una volta sola**
	#
	# `MAX_ENEMIES` e' la capienza giusta perche' un nemico non puo' avere due
	# colpi in volo: la ricarica parte quando il colpo **spara** e il criterio di
	# `tests/test_orda.gd` asserisce che il telegrrafo e' piu' corto della
	# ricarica. Quindi un nemico, non un colpo, e' l'unita' che conta — e come
	# per `hit_positions` il ciclo di gioco non chiama mai `resize`.
	mortar_shots.resize(MAX_ENEMIES)

	# La partita esiste **prima** di qualunque spawn: `_apply_spawn` legge da
	# `run` il moltiplicatore di vita dell'onda, quindi costruirlo dopo sarebbe
	# un ordine in cui la prima generazione di nemici nasce con regole diverse
	# dalla seconda.
	run = Run.new()
	_sync_wave()
	_sync_weights()
	# La curva decide quanti nemici ci sono **al primo frame**: 25, non 200. Il
	# numero e la misura da cui e' uscito stanno in `src/sim/run.gd`.
	_sync_population()
	# Il fattore di calibrazione del corpo, **prima** di qualunque spawn: come
	# gli ostacoli, e per la stessa ragione — la simulazione deve sapere quanto e'
	# grande il corpo che si vede dal primo passo, non dal secondo.
	_load_body_scale()
	# I due numeri del mortar sul contratto, **subito dopo** il fattore del corpo:
	# il raggio di esplosione e' la portata di morso della specie, quindi dipende
	# dalla taglia che il renderer ha appena dichiarato. Registrarlo prima
	# lascerebbe il contratto con un numero che dipende da un fattore non ancora
	# letto, cioe' da una seconda fonte.
	_load_mortar()
	_budget = 0.0
	# Disposizione iniziale **a `population`**, non a `MAX_ENEMIES`.
	_populate(population)
	_rebuild_grid()

# --- m10: gli ostacoli e il campo ---------------------------------------------

## Legge `Game.obstacles` **una volta sola**, all'avvio, e costruisce il campo.
##
## ## La forma dichiarata, punto per punto (contratto di m10)
##
##   1. **statici**: letti qui, una volta sola. Non tornano piu' a leggersi nel
##      ciclo di gioco;
##   2. **dischi sul piano XZ**: `y` e' il raggio e non un'altezza. Qui sotto si
##      legge `elemento.y` come raggio e non come quota, e non e' un caso: e' la
##      convenzione che evita due array paralleli da allineare;
##   3. **raggio positivo**: un raggio zero e' un ostacolo che non esiste e si
##      distingue dal raggio negativo solo per il crash, quindi e' un invariante
##      e viene controllato qui, non affidato alla buona fede di chi lo scrive;
##   4. **registrato in `_enter_tree()`**: percio' quando questa funzione gira il
##      dato e' gia' dentro, e l'ordine delle due foglie non e' una corsa;
##   5. **un insieme vuoto e' un errore**: se il campo non c'e', `flow_problem`
##      dice perche'. Non si costruisce un campo su un insieme vuoto, perche'
##      passerebbe tutti i criteri di m10 senza aver aggirato niente.
##
## La lettura passa da `get("obstacles")` e non da `game.obstacles`: sotto
## `--script` l'identificatore nudo `Game` non compila (vedi la nota in testa al
## file) e `Object.get()` su un nome assente restituisce `null` senza schiantare
## il processo. Quel `null` e' pero' **il caso da urlare**, non un valore di
## riserva: e la riga sotto.
func _load_obstacles() -> void:
	obstacles = PackedVector3Array()
	flow_field = null
	flow_problem = ""
	flow_rebuilds = 0
	var game := _contract()
	if game == null:
		flow_problem = "nessun contratto: gli ostacoli di m10 non possono essere letti"
		_avvisa_ostacoli(flow_problem)
		return
	var raw = game.get("obstacles")
	if raw == null:
		flow_problem = "Game.obstacles non e' dichiarato in src/core/contracts.gd: " \
			+ "la piramide non e' montata, nessun ostacolo blocca nessuno"
		_avvisa_ostacoli(flow_problem)
		return
	if not (raw is PackedVector3Array):
		flow_problem = "Game.obstacles non e' un PackedVector3Array (e' %s)" \
			% type_string(typeof(raw))
		_avvisa_ostacoli(flow_problem)
		return
	var letti: PackedVector3Array = raw
	if letti.is_empty():
		flow_problem = "Game.obstacles e' vuoto: un insieme vuoto e' un errore, " \
			+ "non un mondo senza muri (contratto di m10, punto 5)"
		_avvisa_ostacoli(flow_problem)
		return
	for ob in letti:
		if ob.y <= 0.0:
			flow_problem = "un ostacolo ha raggio %.3f: il raggio e' in `y` ed e' " \
				+ "positivo, punto 3 del contratto di m10" % ob.y
			_avvisa_ostacoli(flow_problem)
			return
	# Copia: l'array del contratto e' di un'altra foglia e non e' nostro.
	obstacles = letti.duplicate()
	flow_field = Flow.new()
	# `E.RADIUS[BOSS]` e non un numero scritto qui: il raggio del nemico piu'
	# grosso sta nella tabella delle specie e non ha una seconda copia (criterio
	# n. 6 di m7).
	flow_field.build(obstacles, arena_radius, E.radius_of(E.BOSS))
	flow_field.rebuild(_player_focus())

## Il margine con cui un punto di nascita viene tenuto fuori dagli ostacoli: il
## **corpo del nemico piu' grosso**, non quello della specie che capita di
## nascere. Il criterio n. 5 e' scritto su nessun nemico dentro un disco, e con
## il margine del runner un boss ci nascerebbe dentro regolarmente.
func _spawn_skin() -> float:
	return E.radius_of(E.BOSS)

## Un avviso per processo, non uno per frame: `flow_problem` resta comunque
## leggibile e il test e' la porta rossa vera.
func _avvisa_ostacoli(motivo: String) -> void:
	push_warning("Horde: ostacoli assenti, l'inseguimento resta in linea retta -- %s" % motivo)

## Quanti ostacoli ci sono. `0` quando la piramide non e' montata: e' il numero
## che rende leggibile `flow_problem` senza doverlo interpretare.
func obstacle_count() -> int:
	return obstacles.size()

## L'evitamento e' attivo? Se `false`, `flow_problem` dice perche'.
func flow_active() -> bool:
	return flow_field != null and flow_field.built

## Quanti nemici vivi sono **dentro** un ostacolo, corpo compreso. E' il numero
## del criterio n. 2, e viene contato dal test sul **numero di nemici dentro un
## ostacolo durante una partita vera**, non sul valore che una funzione ritorna.
func inside_obstacles() -> int:
	if obstacles.is_empty():
		return 0
	var dentro := 0
	for i in count:
		if flow_field != null and flow_field.contains(transforms[i], radii[i]):
			dentro += 1
	return dentro

## Ricostruisce il campo se il bersaglio si e' mosso abbastanza. Chiamata una
## volta per passo, prima di muovere chiunque: da fermo non costa niente, che e'
## il caso in cui il gioco si vorrebbe vincere stando fermi.
func _sync_flow(target: Vector3) -> void:
	if flow_field == null:
		return
	if flow_field.needs_rebuild(target):
		flow_field.rebuild(target)
		flow_rebuilds = int(flow_field.rebuilds)

func _register() -> void:
	if _registered:
		return
	var game := _contract()
	if game == null:
		push_error("Horde: l'autoload Game non c'e': nessuna API registrata sul contratto")
		return
	_registered = true
	# Dato (piano 5.1): assegnazione diretta del campo.
	game.horde = self
	# Metodi (piano 5.1): forma lunga, perche' GDScript rifiuta l'assegnazione
	# a un nome che e' gia' un `func` del contratto.
	game.register_impl("nearest_enemy", self.nearest_enemy_index)
	game.register_impl("damage_enemy", self.damage_enemy)
	game.register_impl("random_spawn_point", self.random_spawn_point)

func _resize_arrays(n: int) -> void:
	transforms.resize(n)
	colors.resize(n)
	radii.resize(n)
	velocities.resize(n)
	hp.resize(n)
	kinds.resize(n)
	timers.resize(n)
	bite_timers.resize(n)
	bite_latch.resize(n)
	bites.resize(n)
	mortar_timers.resize(n)
	mortar_fire.resize(n)

## Mette `n` nemici nell'orda, disposti ad anelli come all'avvio, **senza creare
## nessun nodo**: si riscrivono array che hanno gia' la capienza.
##
## E' la stessa operazione del primo frame e quella del restart, ed e' voluto
## che sia una sola: due versioni della stessa disposizione sarebbero due numeri
## che possono divergere, e il primo frame e il restart devono essere la stessa
## cosa vista due volte.
func _populate(n: int) -> void:
	var target := clampi(n, 0, MAX_ENEMIES)
	count = target
	_resize_arrays(count)
	for i in count:
		_apply_spawn(i, Spawner.layout_point(arena_radius, i, count, _rng,
			obstacles, _spawn_skin()), _pick_kind())
	_grid_dirty = true

## I pesi delle specie dell'onda in corso.
##
## ## m17: qui si costruiscono **due** tabelle, non una
##
## `_weights` e' la tabella dichiarata dell'onda (quella che `Spawner.wave_weights`
## restituisce) e `_pesi_senza_mortar` e' la stessa con la voce del mortar a
## zero. La seconda si costruisce **qui** e non nel ramo di spawn perche' qui
## cambia una volta per onda, e li' cambierebbe otto volte al secondo.
func _sync_weights() -> void:
	_weights = Spawner.wave_weights(1 if run == null else run.wave)
	# ## Il `.duplicate()` **non e' un dettaglio**: e' il difetto che questa riga
	# aveva senza, e la sua firma e' stata vista.
	#
	# `var b = a` su un `PackedFloat32Array` **condivide il buffer**: scrivere
	# `b[4] = 0.0` scriveva anche `a[4]`, quindi `_pesi_senza_mortar` e `_weights`
	# erano lo stesso array e la soglia aveva spento il mortar **per sempre**, non
	# solo a soglia chiusa. Il sintomo era la quota a 0,0000 su tutti e due i
	# cammini con l'orologio a 180 s e la soglia dichiarata aperta: la tabella che
	# l'orda «dichiara di usare» aveva il mortar a zero, e la stampa di
	# `tests/test_orda.gd::_porta_oltre_il_mortar` la mostrava voce per voce accanto
	# a `soglia aperta true`. Una `duplicate()` su cinque float, una volta per
	# cambio d'onda: e' il prezzo di due tabelle, e il prezzo e' dichiarato.
	_pesi_senza_mortar = _weights.duplicate()
	_pesi_senza_mortar[E.MORTAR] = 0.0

## Una specie per lo spawn di adesso: un peso solo, non uno studio di insieme.
##
## ## m17: **il mortar ha una soglia di tempo, e la domanda e' qui**
##
## «Siamo oltre 180,0 s?» e' `Run.mortar_unlocked()`, e nessun'altra species fa
## questa domanda: il brute e il boss nascono dall'onda 1 come prima. La soglia si
## legge **per spawn**, non una volta per frame: cosi' il cambio di soglia non ha
## bisogno di nessun cache e non puo' desincronizzarsi da un array che qualcuno ha
## dimenticato di ricalcolare — il difetto che aveva `BOSS_WAVE1` quando la
## soglia era per onda e i pesi si ricalcolavano solo al cambio d'onda.
func _pick_kind() -> int:
	var pesi := _pesi_effettivi()
	if pesi.is_empty():
		return Spawner.pick_kind(_rng)
	return Spawner.pick_kind_with(_rng, pesi)

## La tabella che questo spawn usa davvero: quella dell'onda, o la stessa senza
## la voce del mortar se l'orologio non e' ancora oltre `Run.MORTAR_AFTER_S`.
##
## `run == null` (l'orda montata senza partita, il caso dei test che misurano la
## tabella delle specie) non ha orologio, quindi **non ha soglia**: legge la
## tabella piena. E' la scelta dichiarata perche' la soglia e' una domanda sul
## tempo di partita, e un'orda senza partita non ha un tempo.
func _pesi_effettivi() -> PackedFloat32Array:
	if run == null or run.mortar_unlocked():
		return _weights
	return _pesi_senza_mortar

## La vita di un nemico appena nato: la tabella della specie per il
## moltiplicatore dell'onda. Sull'onda 1 il moltiplicatore e' 1.0 esatto, quindi
## i numeri di `src/sim/enemy.gd` sono quelli di sempre e il criterio n. 4 della
## milestone 1 resta tarato su di loro.
func _hp_scale() -> float:
	return 1.0 if run == null else run.hp_scale()

func _apply_spawn(i: int, pos: Vector3, kind: int) -> void:
	transforms[i] = pos
	velocities[i] = Vector3.ZERO
	kinds[i] = kind
	hp[i] = E.hp_of(kind) * _hp_scale()
	timers[i] = 0.0
	bite_timers[i] = 0.0
	bite_latch[i] = 0
	bites[i] = 0
	# Carico: un nemico appena nato spara subito se e' gia' in portata di tiro.
	mortar_timers[i] = 0.0
	mortar_fire[i] = 0
	colors[i] = E.color_of(kind)
	# Il raggio del corpo, dalla tabella delle specie: un posto solo (criterio
	# n. 4 di m8). `radii` non e' derivato da `transforms` ne' dalla tinta: e'
	# l'unico posto in cui la taglia attraversa la foglia.
	radii[i] = E.radius_of(kind)

# --- Simulazione --------------------------------------------------------------

## Un passo. Chiamato da `_physics_process`; il test lo chiama direttamente
## per non dipendere dal ciclo di frame.
##
## Nel corpo di questa funzione non c'e' `new()`, `instantiate()` o `queue_free()`:
## si scrive dentro array gia' di capienza e dentro la griglia gia' riscaldata.
## ## Lo stato della partita si guarda PRIMA di muovere chiunque
##
## Non e' solo un ordine: a `game_over` la simulazione e' ferma, quindi un passo
## non sposta nessuno e non riempie nessuno. E' la differenza fra "la partita e'
## finita" e "la partita continua ma non si vede piu' niente", che e' la
## confusione peggiore che un gioco possa fare a chi ci sta giocando.
func step(delta: float) -> void:
	if not _built or delta <= 0.0:
		return
	arena_radius = _contract_radius()
	# Se l'arena e' cambiata, la griglia va riscaldata di nuovo, altrimenti le
	# celle nuove costerebbero un'allocazione per frame.
	_sync_grid()

	_poll_run()
	if run != null and run.is_game_over():
		return
	# ## m17: **l'orologio avanza qui**, e in nessun altro posto
	#
	# Dopo il controllo di `game_over` e prima di qualunque spawn: a partita
	# finita il tempo non scorre (nessuno sta giocando), e quando scorre e' gia'
	# dentro questo passo, quindi la soglia dei 180 s del mortar non ha un passo
	# di ritardo rispetto al resto della simulazione. Un `+=` e una domanda: non
	# c'e' `new()`, non c'e' `instantiate()`, non c'e' `queue_free()`.
	if run != null:
		run.advance(delta)

	_rebuild_grid()
	hit_count = 0
	var focus := _player_focus()
	# Il campo prima di muovere chiunque: l'inseguimento di questo passo legge
	# il campo che e' stato costruito **per questo bersaglio**, non quello del
	# passo precedente. Costa una passeggiata sulle celle quando e' il caso, e
	# niente quando il giocatore sta fermo.
	_sync_flow(focus)
	# Il giocatore c'e' davvero? E' la domanda che accende il morso: senza un
	# giocatore non c'e' nessuno da ferire, e nessun nemico deve "mordere" il
	# centro vuoto dell'arena. Si calcola una volta per passo, non per nemico.
	var ha_giocatore := _has_player()
	for i in count:
		E.step(i, delta, focus, _separation(i), transforms, velocities, timers,
			kinds, arena_radius, bite_timers, bite_latch, bites, ha_giocatore,
			body_scale, bite_mode, mortar_timers, mortar_fire, flow_field)
	# ## m13: i colpi in volo scendono **nello stesso passo** in cui nascono
	#
	# Prima i morsi e poi il mortar, o viceversa: sono due azioni diverse e
	# l'ordine non le cambia. Quello che conta e' che `_mortar_step` stia qui,
	# dopo il ciclo dei nemici (perche' e' lui che chiede i colpi) e prima di
	# `_sweep_dead` (che puo' togliere un nemico e spostare indici con lo
	# scambio-ultimo: la richiesta di un nemico appena ucciso e' gia' stata
	# consegnata, e la decisione di m12 — una richiesta consegnata non e' un
	# colpo perso — vale anche per il mortar).
	_mortar_step(delta, focus, ha_giocatore)
	_apply_bites(delta)
	_sweep_dead()
	_wave_tick(delta)

## Applica i morsi che `src/sim/enemy.gd` ha deciso in questo passo e chiama
## `Game.damage_player(x)`.
##
## ## Qui, e non altrove, sta la meta' di -orda in m7
##
## Il chiamante che il criterio n. 1 cerca con la `grep` e' questa riga: e l'unica
## in tutto `src/`, e il suo numero non e' scritto qui ma esce da
## `E.touch_damage_of(kind)`, cioe' dalla tabella delle specie (criterio n. 6: un
## numero di danno in un posto solo).
##
## ## Perche' si passa dal contratto e non da `Game.player`
##
## `Game.player.take_damage(x)` funzionerebbe e sarebbe una trappola: obbligherebbe
## questa foglia a **leggere `src/player/player.gd`**, cioe' il codice di un'altra,
## che e' l'antipattern che la sezione 5 del piano esiste per impedire. Qui si sa
## solo che il contratto espone `damage_player(amount) -> bool` e nient'altro.
##
## ## Il tetto e' un intervallo, non un numero di morderci
##
## `TOUCH_INTERVAL` e' il tetto dichiarato in testa al file. Il giro parte dal
## primo nemico che morde in ordine d'indice: con un tetto a intervallo il
## nemico che vince e' quello con l'indice piu' basso fra quelli pronti, e gli
## indici cambiano a ogni morte (scambio-ultimo), quindi non e' sempre lo stesso.
##
## ## m12: **una richiesta rimandata NON e' una richiesta persa**
##
## `bites[i]` e' la richiesta del passo e resta accesa finche' non e' consegnata
## (vedi `enemy.gd`). Prima di m12 chi perde la gara vedeva il proprio segnale
## azzerato al passo dopo e aspettava un **periodo intero** di timer: in una
## folla di venti nemici che entrano in portata nello stesso passo, diciannove
## non avrebbero morso mai, e il difetto che l'utente ha segnalato sarebbe
## sopravvissuto al rimedio. Quindi qui:
##
##   - tetto **scarico**: si consegna e si arma il tetto;
##   - tetto **carico**: si **lascia il segnale acceso** e si va avanti.
##
## Il tetto cosi' **limita la cadenza** e non **sceglie chi sopravvive**: il primo
## segnale in ordine d'indice vince, e gli altri riprovano al passo seguente,
## dentro la stessa finestra di contatto.
##
## ## m12: il rientro si arma **qui**, e non in `enemy.gd`
##
## `BITE_SPENT` lo mette la **consegna**, non la richiesta. La differenza non e'
## una sfumatura: se lo mettesse `enemy.gd`, un nemico che chiede il morso al
## passo 40 e lo riceve al passo 42 risulterebbe "speso" dal passo 40, cioe'
## consumerebbe il rientro **senza aver morso**, e un rientro consumato per niente
## e' un nemico che non morde. Chi ha mordo e' `horde.gd`, quindi il rientro si
## arma dove il morso e' avvenuto.
##
## Nessuna allocazione: si scrive dentro array gia' di capienza e si chiama un
## metodo del contratto. Niente `new()`, niente `instantiate()`, niente
## `queue_free()`.
func _apply_bites(delta: float) -> void:
	touch_damage_last = 0.0
	touch_bites_last = 0
	# L'intervallo si scarica **prima** del controllo: cosi' un morso non puo'
	# costare un passo extra di attesa a ogni fine intervallo.
	_bite_interval_left = maxf(0.0, _bite_interval_left - delta)
	if count == 0:
		return
	var game := _contract()
	if game == null:
		return
	for i in count:
		if bites[i] == 0:
			continue
		if _bite_interval_left > 0.0:
			# tetto scarico: la richiesta **resta accesa** e il nemico riprova
			# al passo dopo, dentro la stessa finestra di contatto
			continue
		bites[i] = 0
		# il rientro comincia qui: questo nemico non ripete fino a che non
		# esce dalla portata (`enemy.gd` lo riarma in un passo)
		bite_latch[i] |= E.BITE_SPENT
		var danno := E.touch_damage_of(kinds[i])
		game.damage_player(danno)
		touch_damage_last = danno
		touch_bites_last += 1
		_bite_interval_left = TOUCH_INTERVAL
		return

# --- m13: i colpi del mortar, e le tre cose che devono essere vere --------------
#
# ## L'ordine dentro `_mortar_step`, e perche' e' quello
#
#   1. **scendono** i colpi gia' in volo, e quelli che arrivano a zero
#      **esplodono** e escono dall'array;
#   2. poi si leggono le **richieste** dei nemici di questo passo e i colpi
#      nuovi entrano con `telegraph_for()` secondi.
#
# Il punto 2 viene dopo il 1 e non prima perche' un colpo appena sparato deve
# partire dal suo tempo pieno: accodarlo prima di aver fatto scendere gli altri
# gli toglierebbe un `DT` a ogni passo, e `mortar_shots[i].z` deve scendere di
# esattamente `DT` a ogni passo — e' il numero su cui `-arena` disegna la cupola.
#
# Nessuna allocazione: si scrive dentro un array gia' scaldato e si rimuove per
# **scambio con l'ultimo**, come `_kill`. Nessun `resize`, nessun `new()`.

## Un passo del mortar: i colpi in volo scendono e le richieste diventano colpi.
func _mortar_step(delta: float, focus: Vector3, ha_giocatore: bool) -> void:
	mortar_damage_last = 0.0
	mortar_impacts_last = 0
	var i := 0
	while i < mortar_shot_count:
		var s := mortar_shots[i]
		if s.z - delta > 0.0:
			mortar_shots[i] = Vector3(s.x, s.y, s.z - delta)
			i += 1
			continue
		_mortar_impact(i, focus, ha_giocatore)
		# niente `i += 1`: lo slot `i` e' stato riempito con l'ultimo colpo,
		# quindi e' **quello** che va guardato al passo dopo (scambio-ultimo).
	for j in count:
		if mortar_fire[j] == 0:
			continue
		mortar_fire[j] = 0
		_mortar_spara(focus)

## Il colpo e' sparato: entra in `mortar_shots` con il tempo del telegrrafo e il
## punto in cui cade, che e' **dove stava il giocatore quando ha premuto**.
##
## Il punto di cadere non e' il nemico: e' il bersaglio al momento dello sparo,
## e non un punto davanti a lui. La cupola quindi segnala il pericolo **vero**,
## cioe' quello che il giocatore deve abbandonare adesso.
func _mortar_spara(focus: Vector3) -> void:
	if mortar_shot_count >= mortar_shots.size():
		# Difensivo, e dichiarato: non ci arriva mai, perche' un nemico non puo'
		# avere due colpi in volo (ricarica > telegrrafo) e i nemici non sono
		# piu' di `MAX_ENEMIES`. Un tetto che non puo' scattare e' una difesa, non
		# un criterio, ed e' dichiarato come tale.
		return
	# `(x, z, secondi)`: i secondi stanno in `z`, come dice il contratto.
	mortar_shots[mortar_shot_count] = Vector3(focus.x, focus.z,
		E.telegraph_for(body_scale))
	mortar_shot_count += 1

## Il colpo e' caduto: se il giocatore e' dentro il raggio di esplosione prende
## il danno, e il colpo esce comunque.
##
## ## Il danno e' un **istante**, non un campo
##
## Qui e' il secondo criterio del mortar, e quello che rende la misura non
## comoda: mentre la cupola e' a schermo il giocatore **non prende niente**, e
## prende tutto **quando il colpo cade**. Una finestra nella quale ci si puo'
## stare dentro senza danno non e' una finestra per schivare, e' un campo che
## si puo' attraversare: quello e' il difetto che il criterio deve chiudere, e
## per questo qui non c'e' nessun danno per passo e nessun `if` dentro la
## finestra.
func _mortar_impact(i: int, focus: Vector3, ha_giocatore: bool) -> void:
	var s := mortar_shots[i]
	var blast := E.blast_radius_for(body_scale)
	# `s.y` e' la **z** del mondo: la convenzione dell'elemento e' `(x, z, s)` e
	# disfarla qui e' il motivo per cui esiste `mortar_shot_at`.
	var punto := Vector2(s.x, s.y)
	if ha_giocatore and Vector2(focus.x, focus.z).distance_squared_to(punto) <= blast * blast:
		var game := _contract()
		if game != null:
			game.damage_player(E.MORTAR_BLAST_HP)
			mortar_damage_last = E.MORTAR_BLAST_HP
			mortar_impacts_last += 1
	# scambio con l'ultimo: niente cancellazione dal vettore, niente `resize`.
	var last := mortar_shot_count - 1
	if i != last:
		mortar_shots[i] = mortar_shots[last]
	mortar_shot_count = last

## Il punto **del mondo** dove cade il colpo `i`, con la convenzione disfatta.
##
## Esiste perche' l'elemento di `mortar_shots` tiene `(x, z, secondi)`: chi
## disegna la cupola ha bisogno di un `Vector3` con la `y` a zero, e rileggere
## `shot.y` come profondita' e' l'errore che la convenzione di m10 (il raggio
## del disco in `y`) ha gia' fatto perdere un'onda a qualcun altro.
func mortar_shot_at(i: int) -> Vector3:
	if i < 0 or i >= mortar_shot_count:
		return Vector3.ZERO
	var s := mortar_shots[i]
	return Vector3(s.x, 0.0, s.y)

## Quanto manca, in secondi, alla caduta del colpo `i`. `-1.0` se non c'e'.
func mortar_shot_left(i: int) -> float:
	return -1.0 if i < 0 or i >= mortar_shot_count else mortar_shots[i].z

## C'e' un giocatore in scena? `player_position` e' l'API che -gameplay registra:
## se non c'e', non c'e' nessun giocatore, e nessun morso. Non e' una ipotesi sul
## contratto, e' la strada che `nearest_enemy` e `random_spawn_point` gia' usano
## per lo stesso motivo (piano 5.1).
func _has_player() -> bool:
	var game := _contract()
	return game != null and game.has_impl("player_position")

## Fine dell'onda e riempimento, in un passo solo.
func _wave_tick(delta: float) -> void:
	# La barra a zero e' l'unica condizione che chiude un'onda. Non si guarda
	# anche che il campo sia vuoto: col riempimento continuo un'onda da 230
	# uccisioni con 200 vivi non ha mai il campo vuoto al momento giusto, e
	# l'onda non finirebbe mai.
	if run != null and run.wave_cleared():
		run.next_wave()
		# I pesi delle specie cambiano con l'onda. Adesso, e non dentro
		# `next_wave`: le specie sono di questa foglia, `run.gd` non sa cosa sia
		# un runner.
		_sync_wave()
		_sync_weights()
		# E con l'onda cambia anche **quanti** ne devono essere vivi: la curva
		# di `run.gd`. Rialineata qui e non dentro `next_wave()` per lo stesso
		# motivo dei pesi, e non in `_top_up()` perche' li' il numero deve
		# arrivare gia' giusto: uno specchio allineato in due posti e' una
		# combinazione che non e' mai vera.
		_sync_population()
	_top_up(delta)

## Rende il campo pubblico `wave` uguale a quello di `run`. Chiamata dagli
## **tre** punti in cui l'onda cambia, e da nessun altro: uno specchio
## allineato in tre punti si puo' controllare a occhio, uno allineato "quando
## capita" no.
func _sync_wave() -> void:
	if run != null:
		wave = run.wave

## Rende il campo pubblico `population` uguale a quello che `run` chiede per
## l'onda corrente. Chiamata dagli stessi **tre** punti di `_sync_wave()`
## (`_build()`, cambio d'onda, restart) e da nessun altro.
##
## Non e' una copia per comodita': e' l'unico posto in cui la curva di
## `src/sim/run.gd` entra nell'orda. `_top_up()` legge **solo** il campo, quindi
## un test che pilota `population` a mano (il test di capacita') ottiene un'orda
## di 200 senza dipendere dalla curva, ed e' esattamente il motivo per cui i due
## numeri sono separati.
##
## **Qui dentro entra anche `population_scale`** (vedi la dichiarazione del campo):
## e' l'unico punto di tutto `src/` in cui la cucitura di misura dell'apertura
## viene letta. Il `roundi` serve perche' il campo e' un `float` e `population`
## e' un `int`; a 1.0 — il default, e l'unico valore che il gioco usa — il
## `roundi` restituisce l'intero di prima, quindi la riga e' un no-op sul
## comportamento e una leva per chi misura.
func _sync_population() -> void:
	if run != null:
		population = clampi(roundi(run.population_of(run.wave) * population_scale), 0, MAX_ENEMIES)

## Rimette a posto i nemici rimasti senza vita. `damage_enemy` li toglie subito,
## quindi di norma non trova niente: e' la rete di sicurezza, non il caso normale.
func _sweep_dead() -> void:
	var i := 0
	while i < count:
		if hp[i] <= 0.0:
			_kill(i)
			continue
		i += 1

## Riporta l'orda verso `population`, ma **al ritmo di `run.spawn_rate()`**.
##
## ## Perche' non "finche' `count < population`" come prima
##
## La versione di m1 e di m3 era un `while` che riempiva tutto in un passo:
## misurato, da 0 a 200 in **0.0167 s**, cioe' un passo. E' il sintomo «arrivano
## tutti insieme addosso», ed e' un fatto sul **tempo**, non sul conteggio: una
## curva per onda che si riempisse comunque in un frame avrebbe risolto il
## numero e lasciato il sintomo.
##
## Quindi qui il numero di spawn per passo e' il **credito** meno uno, e il
## credito cresce di `spawn_rate() * delta`. Intero per intero: con 8/s e un
## passo a 1/60 lo spawn arriva ogni 7.5 passi, mai piu' di uno per passo.
##
## Il credito non puo' accumularsi oltre **1**: un passo lento (o un `delta`
## enorme) non deve poter scaricare una raffica tutta insieme al passo dopo,
## altrimenti il tetto esisterebbe solo nella media e il sintomo tornerebbe
## proprio nei momenti in cui il gioco e' andato a scatti.
func _top_up(delta: float) -> void:
	if not auto_respawn or count >= population:
		return
	if delta <= 0.0:
		return
	_budget += (SPAWN_RATE_FALLBACK if run == null else run.spawn_rate()) * delta
	var n := int(_budget)
	if n <= 0:
		return
	# mai piu' di quanti ne servono, e mai piu' della capienza fisica
	n = mini(n, population - count)
	n = mini(n, MAX_ENEMIES - count)
	_budget = minf(_budget - float(n), 1.0)
	for _i in n:
		_spawn_one()

## Usato solo se `run` non c'e' ancora, cioe' mai: sta qui perche' `population`
## si puo' pilotare a mano anche su un'orda senza partita.
const SPAWN_RATE_FALLBACK := 8.0

## Un nemico che entra a meta' partita, e **la sua specie viene dalla stessa
## tabella dei pesi dell'onda** con cui e' nato il primo nemico dell'onda: la
## funzione e' `_pick_kind()`, cioe' il cammino di `_populate`.
##
## ## Il difetto che questa riga chiude, in numeri
##
## Qui sotto c'era `Spawner.pick_kind(_rng)`, cioe' `Spawner.KIND_WEIGHTS`
## **piatto**: il respawn ignorava l'onda. Due cammini, due miscele per la stessa
## onda, e quindi metà regola metà tabella in campo.
##
## I numeri, sull'onda 8 (`Spawner.wave_weights(8)` = `[32.5, 30, 29.6, 17]`,
## runner che scende e boss che sale, contro `KIND_WEIGHTS` = `[50, 30, 17, 3]`):
## il respawn tirava **3.0% di boss** dove l'onda ne chiede **15.6%**, e **50.0%
## di runner** dove ne chiede **29.8%** — il campo si riempiva di corpi fragili
## proprio sulle onde in cui la scala vuole corpi grossi.
##
## **Sull'onda 1 la riga non sposta niente**, e va detto perche': `wave_weights(1)`
## e' `KIND_WEIGHTS` voce per voce, quindi li' i due cammini erano gia' lo stesso
## numero e questa correzione e' invisibile. Anche l'impronta `m11-bis`, che e'
## un numero di onda 1, non si muove. Il difetto era vivo dalle onde 2 in giu'.
func _spawn_one() -> void:
	if count >= MAX_ENEMIES:
		return
	var kind := _pick_kind()
	var pos := Spawner.spawn_point(arena_radius, _player_focus(), _rng, MIN_SPAWN_GAP,
		obstacles, _spawn_skin())
	count += 1
	_resize_arrays(count)
	_apply_spawn(count - 1, pos, kind)
	_grid_dirty = true

## Uccisione per **scambio con l'ultimo**: `transforms[i] = transforms[last]` e
## `resize(count - 1)`. Non si cancella dal vettore: spostare 200 elementi per
## ogni nemico ammazzato costerebbe piu' della query che l'ha ucciso.
func _kill(i: int) -> void:
	var last := count - 1
	if i != last:
		transforms[i] = transforms[last]
		colors[i] = colors[last]
		radii[i] = radii[last]
		velocities[i] = velocities[last]
		kinds[i] = kinds[last]
		hp[i] = hp[last]
		timers[i] = timers[last]
		bite_timers[i] = bite_timers[last]
		bite_latch[i] = bite_latch[last]
		bites[i] = bites[last]
		mortar_timers[i] = mortar_timers[last]
		mortar_fire[i] = mortar_fire[last]
	count = last
	_resize_arrays(count)
	kills += 1
	# Ogni morte e' un passo in avanti sulla barra dell'onda. Si conta qui e non
	# in `damage_enemy`: `_kill` e' l'unico posto in cui un nemico sparisce davvero,
	# e cosi' la barra non dipende da **come** e' morto.
	if run != null:
		run.register_kill()
	_grid_dirty = true

# --- La partita e le onde ------------------------------------------------------
#
# Superficie che l'interfaccia e i test usano. Tre campi pubblici (`count`,
# `transforms`, `colors`) restano dati grezzi perche' sono la massa da disegnare;
# qui sotto sono numeri **derivati**, quindi metodi: se fossero campi, una barra
# letta a metà fra due aggiornamenti mostrerebbe una combinazione che non è mai
# vera.

## La partita e' in corso.
const RUN_PLAYING := "playing"
## La partita e' finita: il giocatore non ha piu' vite.
const RUN_GAME_OVER := "game_over"

## Numero dell'onda. **Campo**, e non metodo, perche' un altro file lo legge gia'
## per nome: `src/ui/hud.gd`::_refresh_wave fa `Game.horde.get("wave")` e si
## aspetta un intero, con un valore di riserva e un `push_warning` se non lo
## trova. Un metodo `wave()` avrebbe fatto dire all'HUD che il campo non esiste,
## e il contatore delle onde sarebbe rimasto fermo a 1 senza che nessuno lo
## notasse.
##
## E' uno **specchio** di `run.wave`, tenuto allineato da `_sync_wave()`: un solo
## punto in cui cambia, chiamato da `_build()`, dal cambio d'onda e dal restart.
## `tests/test_gameloop.gd` confronta il campo con `run.wave` in ogni stato
## raggiungibile, quindi uno specchio rotto diventa un test rosso e non un
## contatore fermo.
var wave: int = 1

## Numero dell'onda corrente. 1 all'avvio e dopo un restart.
func wave_total() -> int:
	return 0 if run == null else run.wave_total

## Quante uccisioni restano all'onda corrente: **la barra wave**. A zero l'onda
## è finita. Non scende mai sotto zero: quando le uccisioni sorpassano il
## bersaglio, l'onda è già finita e non "da un meno".
func wave_remaining() -> int:
	return 0 if run == null else run.wave_remaining()

## Quante uccisioni sono cadute nell'onda corrente.
func wave_killed() -> int:
	return 0 if run == null else run.wave_killed

## La barra wave come rapporto da 0 a 1, per l'interfaccia: 1.0 all'inizio
## dell'onda, 0.0 quando è finita. Sono gli stessi due numeri di
## `wave_remaining()`, quindi l'HUD non può mostrare una barra diversa da quella
## che la simulazione conta.
func wave_bar_ratio() -> float:
	return 0.0 if run == null else run.bar_ratio()

## `Run.PLAYING` o `Run.GAME_OVER`. Le due stringhe sono anche qui, perche' un
## metodo che restituisce una costante di un altro file e' una costante che si
## rompe da sola quando l'altro file la cambia: meglio due righe che una
## dipendenza per un nome.
func run_state() -> String:
	return RUN_PLAYING if run == null else run.state

## La partita è finita: il giocatore non ha più vite. Da solo non si torna
## indietro, l'unica strada è `restart_run()`.
func is_game_over() -> bool:
	return run != null and run.is_game_over()

## La vita relativa dei nemici di questa onda: 1.0 sull'onda 1, e cresce con le
## onde. Le tabelle di `src/sim/enemy.gd` non si toccano mai, quindi il criterio
## n. 4 della milestone 1 resta tarato su quei numeri: è la scala delle onde a
## essere nuova, non la fisica.
func wave_hp_scale() -> float:
	return 1.0 if run == null else run.hp_scale()

## Ricomincia la partita: **onda 1**, barra piena, niente `game_over`, e l'orda
## di nuovo piena **di `population`**, che sull'onda 1 e' `Run.POP_BASE` = 25 e
## non `MAX_ENEMIES`. Prima di m4 il restart ripartiva da 200 nemici vivi; era
## la stessa scelta di design sbagliata dell'avvio, ripetuta al secondo posto.
##
## Nessun nodo viene creato e nessuno viene liberato: si riscrivono gli array che
## già esistono. Il criterio n. 4 chiede che un restart non lasci nodi
## duplicati, e con questa forma il numero di nodi non *può* cambiare invece di
## dover essere controllato.
##
## **Anche `radii` viene ricomposta qui**, per la via che il contratto di m8
## dichiara: il restart chiama `_populate`, che chiama `_apply_spawn` per ogni
## nemico, ed e' li' che `radii[i]` prende il raggio della specie. Non c'e' una
## strada per `radii` diversa da quella degli altri array paralleli: e' il punto
## 3 del contratto, ed e' quello che un array parallelo deve rispettare per non
## staccarsi dagli altri.
##
## Il giocatore **non** è toccato: è di -gameplay, e rimetterlo in piedi (vite,
## potenziamenti, arma) è la sua metà del restart. Chi chiama questo metodo deve
## rimettere in piedi anche il giocatore: se le vite restano a zero, il passo di
## simulazione successivo rilegge `game_over` e la partita si ferma di nuovo,
## che è la cosa giusta da fare ma non è un restart riuscito.
##
## ## m11-bis-b: il restart **rimescola** (piano §1.14-ter)
##
## Una riga nuova in cima a tutto, `_reroll()`, ed è la riga che tiene insieme il
## progetto: **`restart_run()` randomizza esplicitamente**, e non «per caso».
##
## Il fatto che l'ha resa necessaria è verificato e scritto nel piano. `scenes/
## arena_main.tscn` non montava la proprietà `seed`, quindi `_build()` faceva
## `_rng.randomize()` a ogni montaggio: **ogni montaggio della scena vera era una
## partita diversa**, e ogni durata misurata sul gioco — «morto dopo 8,40 s» o
## «dopo 28,20 s» sullo stesso comando — era un campione di un dado.
##
## Il rimedio è diviso in due, e i due pezzi appartengono a due foglie:
##
## | chi | cosa possiede | cosa dichiara |
## |---|---|---|
## | `-arena`, `scenes/arena_main.tscn` | il **default** della scena | un `seed` **fisso**, dichiarato, sulla scena |
## | `-orda`, questo file | il **reroll** di partita | `restart_run()` **randomizza esplicitamente** |
## | `-arena`, `src/render/arena_ground.gd` | le casse | lo stesso seme, dichiarato |
##
## **Il secondo rigo è quello che chiude il difetto invece di scambiarlo con
## un altro.** Con la scena a seme fisso e senza il reroll, il gioco sarebbe
## **sempre identico**: da «ogni misura è un campione» a «ogni partita è la
## stessa», che per un bullet heaven è peggio. Sono un invariante e la sua faccia
## rossa, e si verificano insieme: la riproducibilità è il criterio 1
## (`tests/test_gameplay.gd`, `-arena`), il reroll è il criterio 2
## (`tests/test_orda.gd`, qui).
##
## Il reroll è **esplicito** e non implicito in tre motivi, e sono i tre che lo
## rendono verificabile invece che Lucky:
##   1. **`restart_run()` è l'unico posto** in cui una partita ricomincia, quindi
##      e' l'unico posto in cui il seme va rimescolato: metterlo dentro `_populate`
##      o dentro `_spawn_one` lo farebbe succedere **anche** a `reseed(s)`, e un
##      `reseed` che rimescola non riproduce piu' niente;
##   2. **`seed` viene scritto a `0`**, cioè al suo significato dichiarato di
##      «casuale»: dopo il restart il campo dice la verità sulla disposizione
##      che è in campo. Lasciarci il seme fisso della scena sarebbe un campo che
##      mente — direbbe «questa disposizione è riproducibile da 4242» per una
##      disposizione che 4242 non produce;
##   3. **nessun nodo e nessuna allocazione**: `_reroll()` è una riga su un
##      `RandomNumberGenerator` che esiste già, e il ripopolamento è lo stesso
##      `_populate` del primo frame e di `reseed`.
func restart_run() -> void:
	if not _built:
		return
	run.restart()
	kills = 0
	hit_count = 0
	_bite_interval_left = 0.0
	touch_damage_last = 0.0
	touch_bites_last = 0
	# ## m13: i colpi in volo **non sopravvivono al restart**
	#
	# Un colpo e' gia' partito e il suo istante di caduta e' gia' deciso: senza
	# questa riga una partita nuova comincerebbe con la cupola di un colpo
	# sparato nella partita di prima, cioe' un avvertimento che punta a una zona
	# che non ha niente a che fare. Il conto si azzera e basta: l'array di
	# capienza resta scaldato, quindi non si alloca niente.
	mortar_shot_count = 0
	mortar_damage_last = 0.0
	mortar_impacts_last = 0
	# **Prima** di `_populate`: il ripopolamento legge `_rng`, quindi il seme va
	# rimescolato prima e non dopo (dopo sarebbe un no-op silenzioso, e un
	# no-op silenzioso è un difetto che la porta non vede).
	_reroll()
	_sync_wave()
	_sync_weights()
	_sync_population()
	_budget = 0.0
	_populate(population)

## Il **reroll**: «da qui in poi la disposizione è casuale».
##
## Sono due righe, e sono le uniche due che rendono casuale una disposizione in
## tutto `src/sim/`: `_build()` e `reseed(0)` ci passano quando non c'è un seme
## da seguire, `restart_run()` ci passa **sempre**. Scriverlo qui e non nei tre
## chiamanti è la differenza fra «una decisione» e «tre copie di una decisione»:
## il giorno che «casuale» volesse dire qualcos'altro (un seme derivato dal
## numero della partita, un `state` del motore) si cambia **una** riga.
##
## `seed = 0` non è un dettaglio: è il significato dichiarato del campo pubblico
## (`seed.gd`, testa del file), e dopo questa chiamata il campo **descrive** la
## disposizione che verrà scritta. `reseed(s != 0)` continua a scriverci `s`, e
## quindi il campo non è mai un numero che mente su quello che è in campo.
func _reroll() -> void:
	seed = 0
	_rng.randomize()

## Ridispone l'orda su un altro seme: il **semplice** e' la disposizione, non
## la partita. Chiamata dal contratto di m3 (`contracts.gd`, "Supersficie di
## milestone 3"), che ne dichiara la semantica in cinque punti; qui la si
## implementa senza aggiungere nomi nuovi.
##
## Serve perche' `seed` e' un campo pubblico ma lo leggeva **una volta sola**,
## dentro `_build()`, che gira nel `_ready()`: sulla scena vera l'orda la crea
## `arena_main.tscn`, quindi nessun codice esterno poteva scriverlo prima, e il
## campo sembrava la riproducibilita' mentre era irraggiungibile (`seed = 0`
## sempre, `_rng.randomize()` sempre).
##
## ## I cinque punti, e come sono resi qui
##
## 1. scrive il campo pubblico `seed` con `s` — nei due rami sotto, `_reroll()`
##    per `s == 0` e la coppia `seed = s` / `_rng.seed = s` per `s != 0`.
## 2. `s == 0` **mantiene il significato dichiarato del campo**: `randomize()`,
##    cioe' casuale, e non "seme zero" (che Godot tratterebbe come seme fisso).
## 3. con `s != 0` fissa `_rng` sul seme e ripopola **a `population`** con lo
##    **stesso percorso del primo frame**: la funzione chiamata e' `_populate`,
##    la stessa che chiama `_build()`, non un mestiere separato. Due versioni
##    della stessa disposizione sarebbero due numeri che possono divergere, ed e'
##    la lezione gia' scritta in `_populate`.
## 4. **non tocca** `run`, `wave`, `kills` ne `population`: si leggono, non si
##    scrivono. E' un'operazione di disposizione, non di stato di partita;
##    `restart_run()` resta l'unica cosa che rimette a posto la partita. In
##    particolare `_sync_wave()` e `_sync_weights()` **non** vengono chiamate:
##    l'onda non e' cambiata, quindi pesi e scala della vita sono gia' quelli
##    giusti e risincronizzarli sarebbe scrivere lo stato di partita.
## 5. ricostruisce la griglia, cosi' `worst_bucket()` e `grid_overflowed()`
##    parlano della disposizione **appena scritta** e non di quella precedente.
##
## Sia con `s == 0` sia con `s != 0` la disposizione viene riscritta: il nome e'
## "ridisporre su un altro seme", e lasciare il campo com'e' a `s == 0` lascerebbe
## al chiamante una disposizione vecchia travestita da casuale. La differenza fra
## i due rami e' **solo** come `_rng` viene seminato.
##
## Nessun nodo viene creato e nessuno viene liberato, e nessuna allocazione
## nuova: `_populate` riscrive array che hanno gia' la capienza e `_rebuild_grid`
## riusa la griglia gia' riscaldata. Se `_built` e' falso e' un no-op, come
## `restart_run()`: l'orda non e' nata, quindi non c'e' niente da disporre.
func reseed(s: int) -> void:
	if not _built:
		return
	# `s == 0` e' il ramo «casuale», ed e' `_reroll()`: la stessa funzione che
	# chiama `restart_run()`. Il punto 1 del contratto di m3 («scrive il campo
	# pubblico `seed` con `s`») resta valido perche' `_reroll()` scrive `0`, che
	# e' `s` in quel ramo; il punto 2 («`s == 0` mantiene il significato
	# dichiarato del campo: `randomize()`») e' quello che la funzione contiene.
	if s == 0:
		_reroll()
	else:
		seed = s
		_rng.seed = s
	_populate(population)
	_rebuild_grid()

# --- Griglia ------------------------------------------------------------------

## Riscalda la griglia solo quando l'estensione cambia. `setup()` ricrea tutti i
## secchielli: chiamarlo ogni frame sarebbe l'allocazione nel ciclo di gioco che
## questo file evita, quindi la soglia e' volutamente grossolana.
func _sync_grid() -> void:
	var extent := arena_radius * 1.5
	if absf(extent - _grid_extent) < 0.5:
		return
	_grid_extent = extent
	_grid.setup(Grid.CELL, extent)
	_grid_dirty = true

func _rebuild_grid() -> void:
	_grid.begin_frame()
	# `worst_bucket` e' un **massimo storico** dentro `spatial_grid.gd`: si azzera
	# in `setup()` e non in `begin_frame()`, quindi dopo questo punto direbbe ancora
	# il picco della disposizione **precedente**. Il contratto di m3 pretende il
	# contrario: dopo `reseed` il numero deve parlare della disposizione appena
	# scritta (punto 5). Lo si azzera qui, dall'unico posto che ricostruisce la
	# griglia: il campo e' pubblico e non serve toccare `spatial_grid.gd`. Dopo il
	# ciclo di `insert` sotto, vale "picco del frame appena ricostruito".
	_grid.worst_bucket = 0
	for i in count:
		_grid.insert(i, transforms[i])
	grid_unknown_cells = _grid.unknown_cells
	_grid_dirty = false

## Una morte o uno spawn rendono la griglia vecchia. La query la sistema da
## sola invece di ricostruirla 30 volte per frame solo perche' un nemico e'
## morto.
func _ensure_grid() -> void:
	if _grid_dirty:
		_rebuild_grid()

func _separation(i: int) -> Vector3:
	if count < 2:
		return Vector3.ZERO
	var p := transforms[i]
	# `found` con tipo esplicito: `_grid` e' una variabile senza tipo (perche' la
	# griglia si crea in `_build()`), e `:=` su un chiamata che non ha tipo
	# dichiarato non compila.
	var found: int = _grid.collect_into(_sep_buf, p, SEPARATION_RADIUS, transforms,
		SEPARATION_CHECKS)
	var acc := Vector3.ZERO
	for k in found:
		var j: int = _sep_buf[k]
		if j == i:
			continue
		var away := p - transforms[j]
		var l2 := away.length_squared()
		if l2 > 0.0001 and l2 < SEPARATION_RADIUS * SEPARATION_RADIUS:
			acc += away / l2
	if acc.length_squared() <= 0.000001:
		return Vector3.ZERO
	return acc.normalized() * (SEPARATION_FORCE / E.mass_of(kinds[i]))

# --- API del contratto --------------------------------------------------------

## Indice del nemico vivo piu' vicino a `from` entro `radius`, oppure -1.
##
## Restituisce un **indice**, non un nodo: un nemico non e' un nodo (regola 1).
## L'indice e' esattamente quello che `damage_enemy(index, ...)` si aspetta, e il
## contratto fa `as int` su questo valore: si puo' chiamare
## `Game.nearest_enemy(pos, 12.0)` senza errori di cast (piano 5.2).
func nearest_enemy_index(from: Vector3, radius: float) -> int:
	if not _built or count == 0 or radius <= 0.0:
		return -1
	_ensure_grid()
	return _grid.nearest_index(from, radius, transforms)

## Applica `amount` di danno al nemico `index` e gli impartisce `knockback`.
## Se il nemico muore, viene tolto **subito**: dopo questa chiamata `count` e'
## gia' giusto, senza aspettare il frame dopo. Restituisce `true` se e' morto:
## e' l'unico modo per -gameplay di sapere **chi** e' morto senza aggiungere un
## segnale (piano 5.2).
##
## `knockback` e' un **impulso in m/s, gia' scalato dal chiamante**: qui non si
## normalizza e non si somma alla posizione, si somma alla velocita'.
func damage_enemy(index: int, amount: float, knockback: Vector3) -> bool:
	if not _built or index < 0 or index >= count:
		return false
	hp[index] -= amount
	if knockback.length_squared() > 0.000001:
		velocities[index] += knockback * (1.0 - E.knockback_resist_of(kinds[index]))
		timers[index] = 0.12
	_record_hit(transforms[index], kinds[index])
	if hp[index] <= 0.0:
		_kill(index)
		return true
	return false

## Punto di arrivo casuale dentro l'arena. Non puo' restituire `Vector3.ZERO`:
## il contratto usa ZERO come segnale di "non implementato".
func random_spawn_point() -> Vector3:
	if not _built:
		return Vector3(0.0, 0.0, _contract_radius() * 0.5)
	return Spawner.spawn_point(arena_radius, _player_focus(), _rng, MIN_SPAWN_GAP,
		obstacles, _spawn_skin())

# --- Lettura per arena e ui ---------------------------------------------------

## Nome della specie, per un HUD o un log.
func kind_name(index: int) -> String:
	if index < 0 or index >= count:
		return "-"
	return E.KIND_NAMES[E.clamp_kind(kinds[index])]

## Velocita' massima di un tipo di nemico, per il render che deve animarli.
func speed_of_kind(kind: int) -> float:
	return E.speed_of(kind)

## Popolazione viva per specie.
func census() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(E.KIND_COUNT)
	for i in count:
		out[E.clamp_kind(kinds[i])] += 1
	return out

## Celle occupate dalla griglia, per diagnostica.
func occupied_cells() -> int:
	if _grid == null:
		return 0
	return _grid.occupied_cells()

## Qualche secchiello e' traboccato e le query stanno cadendo a scansione
## lineare? Non deve succedere, e il test lo controlla.
func grid_overflowed() -> bool:
	return _grid != null and _grid.overflowed

## Il nemico piu' occupato in una cella, **nel frame (griglia) appena
## ricostruito**: il picco delle celle dell'ultima disposizione scritta nella
## griglia, non un massimo storico.
##
## ## Perche' questo numero e' per-frame e non storico (scelta dichiarata)
##
## Dentro `spatial_grid.gd` il contatore e' un **massimo storico**: si azzera in
## `setup()` e non in `begin_frame()`. Lasciandolo com'e', dopo un `reseed`
## continuerebbe a dire il picco della disposizione **precedente**, e il
## chiamante misurerebbe una griglia vera che pero' non risponde alla domanda
## che ha fatto. Il contratto di m3 (punto 5) pretende esattamente il contrario:
## dopo `reseed` il numero parla della disposizione appena scritta.
##
## Percio' `_rebuild_grid()` azzera il campo pubblico del contatore a ogni
## ricostruzione: **non** serve modificare `spatial_grid.gd`. Il numero che
## esce da qui e' quindi il picco **dell'ultimo frame ricostruito**, ed e' quello
## che un test che asserisce deve sapere che sta usando.
##
## Nota per chi asserisce: non e' un massimo "da sempre". Un test che volesse il
## picco di tutta una sequenza deve ricordare il massimo osservato frame per
## frame, perche' questo numero torna giu' a ogni ricostruzione.
##
## ## Il numero e' limitato a `BUCKET_SLOTS`: non usarlo come guardia
##
## `spatial_grid.gd::insert` aggiorna il contatore solo con `n < BUCKET_SLOTS`,
## quindi questo valore **non puo' superare 32**: `worst_bucket() <= BUCKET_SLOTS`
## e' una tautologia che non puo' fallire, e un test che ci mette sopra una soglia
## cosi' non sta misurando niente. Il segnale che il traboccamento e' avvenuto e'
## `grid_overflowed()`. Per una **misura di densita'** questo numero va confrontato
## con un tetto **proprio, sotto 32** (e quel tetto va derivato da una misura, non
## scelto a piacere), che e' esattamente il tetto dichiarato che m3 chiede.
func worst_bucket() -> int:
	return 0 if _grid == null else _grid.worst_bucket

# --- Interno ------------------------------------------------------------------

func _record_hit(pos: Vector3, kind: int) -> void:
	var slot := hit_count % HITS_KEPT
	hit_positions[slot] = pos
	hit_kinds[slot] = kind
	hit_count = mini(hit_count + 1, HITS_KEPT)

## Lo stato della partita si aggiorna leggendo le vite del giocatore, e il
## giocatore si raggiunge per il **contratto**: `Game.player` è un dato pubblico
## che -gameplay registra, non un nodo che questa simulazione va a cercare
## nell'albero con `get_node("../..")`. È la strada che usa già
## `src/render/arena.gd` per la barra delle vite, e vale per la stessa ragione:
## una foglia che si cerca fra le altre foglie è una dipendenza circolare.
##
## Un campo assente, o di un tipo diverso, vale "non lo so": niente errore e
## niente `push_warning` ogni frame. Se un domani il giocatore smettesse di
## esporre `hp`, il test che azzera le vite e poi chiede `is_game_over()` lo
## direbbe subito — il che è meglio di un `game_over` che scatta da solo per un
## motivo sbagliato.
func _poll_run() -> void:
	if run == null:
		return
	var hp := _player_hp()
	if hp >= 0.0 and hp <= 0.0:
		run.enter_game_over()

## Le vite del giocatore, o -1.0 se il contratto non ha ancora un giocatore con
## quel campo. -1.0 e non 0.0 perché "non lo so" e "è morto" sono due fatti
## diversi e metterli nello stesso numero fa finire la partita a chi non lo sa.
func _player_hp() -> float:
	var game := _contract()
	if game == null:
		return -1.0
	if _player_cache == null or not is_instance_valid(_player_cache):
		_player_cache = null
		var found = game.get("player")
		if not (found is Node):
			return -1.0
		_player_cache = found
	var v: Variant = _player_cache.get("hp")
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return float(v)
	return -1.0

## Il bersaglio dei nemici. Se -gameplay ha registrato `player_position` si usa
## quella, altrimenti il centro dell'arena: nessuna dipendenza circolare, e
## nessun `push_warning` se il contratto non e' ancora popolato. E' anche la
## domanda che accende il morso: vedi `_has_player()`.
func _player_focus() -> Vector3:
	var game := _contract()
	if game != null and game.has_impl("player_position"):
		var p: Vector3 = game.player_position()
		if p.length_squared() > 0.000001:
			return p
	return _focus

## Se arena ha il giocatore ma non ha registrato `player_position`, puo' dirlo
## qui. Non e' un `get_node("../..")`: e' un dato, non una dipendenza.
func set_focus(pos: Vector3) -> void:
	_focus = pos