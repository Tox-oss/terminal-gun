extends RefCounted
## Un nemico di terminal-gun: **i dati e il comportamento di un singolo nemico,
## ma non un nodo**.
##
## E' un record in un array parallelo di array compattati, non un oggetto di
## scena. Nessun `Node3D`, nessun `queue_free()`, nessun nodo per nemico: il
## criterio della milestone e' `node_count < 120` con `horde.count == 200`, e un
## nodo per nemico lo renderebbe impossibile da solo.
##
## Perche' `static var` e non `const`: in Godot 4.7 un `PackedFloat32Array([...])`
## NON e' un'espressione costante, quindi `const` su una tabella di questo tipo
## non compila ("Assigned value for constant ... isn't a constant expression").
## Le tabelle sono lette solo, quindi `static var` e' la forma giusta.
##
## `step()` scrive dentro gli array passati e non restituisce nulla: nel ciclo di
## gioco non viene allocato niente, perche' non viene creato niente.

## Le cinque specie. L'indice nel record e' questo intero (`kinds[i]`).
const RUNNER := 0
const GRUNT := 1
const BRUTE := 2
const BOSS := 3
## m13: la quinta specie, l'unica che **non insegue**: entro una certa distanza
## si ferma e spara un colpo che cade dove stava il giocatore. Le quattro di
## sopra non cambiano di una virgola: questa aggiunge una voce a ogni tabella e
## non ne modifica una (vedi il blocco "m13: il mortar" piu' in basso).
const MORTAR := 4
const KIND_COUNT := 5
const KIND_NAMES := ["runner", "grunt", "brute", "boss", "mortar"]

# Tabelle per specie, allineate 1:1 con KIND_NAMES. Indexate da `kind`.
##
## ## Perche' una quinta voce e non un tavolo nuovo
##
## Una tabella allineata 1:1 che cresce di una voce **tocca tutto quello che la
## legge**, e il progetto l'ha gia' scritto (m9: sei copie del raggio). Quindi
## qui si sceglie la forma che tocca il meno posto possibile: la quinta voce
## entra nelle sei tabelle che gia' esistono, `KIND_COUNT` passa da 4 a 5, e
## ogni funzione che le legge le legge gia' con `clamp_kind(kind)`: nessuna
## tabella nuova da tenere allineata e nessun `switch` da aggiornare.
##
## ## Perche' le quattro specie non si muovono
##
## I numeri di `runner`, `grunt`, `brute` e `boss` sono **quelli di prima**,
## voce per voce, e la sezione `m13` di `tests/test_orda.gd` li asserisce uno per
## uno contro i numeri scritti qui sotto. Un quinto tipo che si fosse portato
## via una cifra delle altre quattro avrebbe spostato le misure di sette
## milestone senza dirlo, e la cosa piu' vicina a un numero che mente.
static var HP_MAX := PackedFloat32Array([14.0, 34.0, 110.0, 900.0, 65.0])
static var SPEED := PackedFloat32Array([6.6, 4.0, 2.3, 1.7, 2.9])
static var RADIUS := PackedFloat32Array([0.45, 0.60, 1.00, 1.90, 1.40])
static var MASS := PackedFloat32Array([0.7, 1.0, 2.6, 6.0, 3.2])
## Quanto knockback il nemico si mangia: 0 = tutto, 0.9 = quasi immobile.
static var KNOCKBACK_RESIST := PackedFloat32Array([0.0, 0.20, 0.55, 0.90, 0.70])
## Tinta per specie: e' quello che arena passa al MultiMesh, cosi' l'arena non
## deve sapere cosa sia un nemico.
##
## La quinta tinta e' **ciano** e non un rosso: il rosso e' della cupola che
## segnala dove cade il colpo (`mortar_renderer` di `-arena`), e una specie
## colorata come il proprio avvertimento renderebbe il segnale illeggibile.
static var COLOR := PackedColorArray([
	Color(0.98, 0.35, 0.30),
	Color(0.86, 0.20, 0.55),
	Color(0.55, 0.25, 0.88),
	Color(1.00, 0.76, 0.15),
	Color(0.16, 0.74, 0.80),
])

## Oltre' questa distanza dal bersaglio il nemico rallenta (arrivo).
const ARRIVE_RADIUS := 3.0
## Costante di tempo dell'accelerazione: 1/ACCEL secondi per cambiare direzione.
const ACCEL := 8.0
## Tetto di velocita', cosi' un knockback non lancia un nemico fuori dal mondo.
const SPEED_MAX := 18.0
## Spinta verso il centro quando il nemico sborda l'arena.
const EDGE_PUSH := 3.0

# --- Il morso: cosa fa il nemico al giocatore (milestone 7) -------------------
#
# ## Tre costanti e nessuna tabella
#
# Il criterio n. 6 della milestone 7 chiede che un numero di danno non viva in
# due posti: quindi qui sotto ci sono **tre costanti e nessuna tabella**. Il
# danno e la cadenza di ogni specie escono da `MASS`, che e' gia' la tabella
# del progetto e gia' governa la separazione (`SEPARATION_FORCE / mass_of(kind)`
# in `horde.gd::_separation`). Una cosa sola dice "quanto e' pesante", e quella
# cosa governa sia quanto il nemico ti scarta dal tuo vicino, sia quanto ti
# morde: e' la stessa fisica, scritta una volta sola.
#
#     morso(specie)   = TOUCH_DAMAGE_BASE * massa / massa(runner)
#     periodo(specie) = TOUCH_PERIOD      * sqrt(massa / massa(runner))
#     dps(specie)     = morso / periodo   = base/periodo * sqrt(massa/runner)
#
# Il `sqrt` sul periodo e' quello che tiene il capo in gioco: senza, il boss
# (massa 6.0, otto volte e mezzo il runner) morderebbe 8,6 volte tanto e 8,6
# volte spesso, cioe' 74 volte la dps di un runner. Con il `sqrt` il capo
# mordere forte e piano, che e' quello che ci si aspetta da una cosa pesante.
#
# ## La portata del morso: rimisurata sulla scena vera (milestone 8)
#
# Il numero di prima era **1.2**, dichiarato «misurato» qui sotto — ma
# misurato **sull'orda isolata**, con uno **spia** al posto del giocatore
# (`tests/test_orda.gd`, sezione 11). Uno spia accetta ogni morso. Il giocatore
# vero no: `player.gd::take_damage` scarta il danno durante l'invulnerabilita'
# dopo un colpo (`INVULN_AFTER_HIT = 0.7 s`). La misura di prima era quindi la
# **produzione dell'orda**, non **l'ingestione del giocatore**, ed e' su quella
# che il numero era stato scelto.
#
# ### La misura, sulla scena vera (`tests/test_orda.gd`, sezione 12)
#
# `scenes/arena_main.tscn` per intero, orda a 200 vivi, giocatore vero fermo al
# centro, passo fisso 1/60 s, 30 s di riscaldamento e 30 s di finestra.
#
# **La scena vera allora non aveva seme**: `horde.seed = 0` vuol dire `randomize()`,
# quindi la disposizione era diversa a ogni avvio — e questa frase, insieme al
# rimedio, e' il difetto di m11-bis-b (piano §1.14-ter): `_arena` ha messo sulla
# scena un `seed` **fisso** dichiarato, e `horde.gd::restart_run()` **rimescola** a
# ogni nuova partita. Quindi la riga qui sotto vale per la misura **come era**,
# presa su una disposizione casuale: le righe successive hanno dispersione e si
# leggono come **bande**, non come valori; sono stampate a ogni lanzo dalla
# sezione 12, che e' il posto dove si rileggono. L'unica riga senza dispersione
# e' la prima, e non per caso: e' l'unica che **sceglie** il numero.
#
# Dopo il rimedio la sezione 12 e' di nuovo **una funzione del seme** finche'
# non chiama `restart_run()`: e' per questo che la sezione 14 di
# `tests/test_orda.gd` verifica il reroll **sull'orda isolata** e non dentro la
# sezione 12 — un restart li riaprirebbe proprio il numero che il criterio n. 1
# confronta fra montaggi.
#
# | grandezza misurata | prima (`TOUCH_REACH` = 1.2) | dopo (0.45) |
# |---|---|---|
# | **raggio del corpo che il giocatore VEDE** | **0.4500 m** | 0.4500 m |
# | corpi entro `RADIUS + TOUCH_REACH` | 21 su 200 | 8 su 200 |
# | corpi entro `RADIUS + 0.00` (nessun margine) | 6 su 200 | 8 su 200 |
# | morsi offerti / accettati in 30 s | 56 / 29 | 22 / 16 |
# | **hp al secondo sentiti dal giocatore** | **5.97** | **5.24** |
# | **sopravvivenza, 100 hp, fermo al centro, 200 vivi** | **19.77 s** | **11.57 s** |
#
# Le ultime due righe vanno lette insieme: **i morsi sono quasi dimezzati ma sono
# piu' pesanti**, perche' a portata corta arrivano solo le specie grosse. Il danno
# al secondo che il giocatore sente scende del 12%, non del 50%: meta' dei morsi
# offerti non entrava comunque, perche' il giocatore era gia' invulnerabile.
#
# La tabella qui sopra e' la misura di m8, e riguarda la portata di **allora**,
# `RADIUS[kind] + TOUCH_REACH`. Dal 2026-10-14 (m11-quarta, vedi `bite_range_of`
# piu' in basso) la portata e' `body_scale * RADIUS[kind] + TOUCH_REACH`, quindi
# **quelle righe non descrivono piu' il gioco**: sono la derivazione del numero
# `TOUCH_REACH`, non la sua fotografia di oggi. Le due righe che contano il
# numero di oggi sono la sezione 16 di `tests/test_orda.gd` (banda per specie) e la
# sezione 12 (ingestione sulla scena vera), e vengono ristampate a ogni lancio.
#
# ### Perche' questo numero e' quello
#
# La condizione del morso e' `dist <= bite_range_of(kind, body_scale)`: la somma
# di due raggi deve essere una distanza, e i due raggi che ci sono sono **il corpo
# del nemico** e **il corpo del giocatore**. Il secondo non era un numero: era
# un punto. Ed e' il punto che l'utente ha scritto di essere troppo piccolo.
#
# Quindi `TOUCH_REACH` non e' una portata e' **il raggio del corpo del
# giocatore**, letto dalla scena vera: 0.4500 m. Con questo numero la frontiera
# del morso e' letteralmente **il bordo del nemico che tocca il bordo del
# giocatore**, per tutte e quattro le specie, e non un margine che non si vede.
# E' la risposta a «due numeri che dovrebbero essere uno solo erano due»: il
# secondo dei due non e' sparito, e' diventato **la taglia del giocatore**.
#
# ### Il numero e' un vincolo, non una costante scolpita
#
# Se il modello del giocatore cambia, questo numero deve cambiare con lui: non
# e' una convenzione, e' una lettura. Per questo la sezione 12 di
# `tests/test_orda.gd` asserisce che `TOUCH_REACH` **uguale** il raggio misurato
# sulla scena vera, e non che sia vicino a 0.45. Quel test e' la difesa: senza
# di lui questo numero diventerebbe un magico 0.45 che mente alla prima riga
# cambiata del modello, che e' la lezione di `offer_label` scritta in
# `src/core/contracts.gd`.
#
# ### La difficolta' che cambia, e non e' una regressione
#
# Accorciare la portata vuol dire meno corpi a portata e quindi morsi meno
# frequenti. Ma il giocatore **vero** era gia' protetto da `INVULN_AFTER_HIT`:
# su 56 morsi offerti ne accettava 29 e meta' del danno offerto non entrava.
# Percio' i numeri di sezione 11 (l'orda isolata con uno spia che accetta
# tutto) restano la **produzione** dell'orda e continuano a servire al tetto
# `TOUCH_INTERVAL`, ma **non** descrivono la difficolta': sulla scena vera quei
# due numeri sono circa il doppio di quelli che il giocatore sente.
const TOUCH_REACH := 0.45

## ## m11-quarta: la portata del morso **deriva dalla taglia disegnata**
##
## ## Il difetto, in una riga
##
## Il corpo che si vede e' `SIZE_FACTOR * RADIUS[kind]` (`SIZE_FACTOR` lo
## registra `-arena` e il contratto lo espone come `Game.enemy_body_scale`), e
## la portata del morso era `RADIUS[kind] + TOUCH_REACH`. La banda di
## sovrapposizione a vuoto era quindi `(SIZE_FACTOR - 1) * RADIUS[kind]`, cioe'
## 1,08 m sul runner, 1,44 sul grunt, 2,40 sul brute e **4,56 m sul boss**: per
## quella lunghezza il nemico e' letteralmente dentro il giocatore e non fa
## niente, e la banda **cresceva con la specie**, che e' l'opposto di quello che
## serve. E' la segnalazione dell'utente del 2026-10-14 (piano §1.14-nona).
##
## ## La regola, che e' del contratto (m8 punto 1b, emendato lo stesso giorno)
##
##     morse_entro(k) >= taglia_disegnata(k) + taglia_disegnata_giocatore
##
## e la banda deve essere **zero per ogni specie**. Non e' una soglia da tarare:
## e' un'identita', e si ottiene **derivando** la portata dalla taglia che si
## vede, cosi' il numero che si vede e quello che morde non possono divergere.
##
## ## Perche' il coefficiente NON e' libero
##
## `corpo_giocatore` **e' gia'** `TOUCH_REACH = 0.45`: il criterio n. 2 di m8,
## verificato nella sezione 12 di `tests/test_orda.gd`, asserisce che il raggio
## **misurato** sulla scena vera del giocatore e' uguale a `TOUCH_REACH`. Quindi
## basta una riga:
##
##     morse_entro(k) = body_scale * RADIUS[k] + TOUCH_REACH
##
## e la banda va a **0,0000 per costruzione**, non per taratura. Non c'e' un
## fattore «in attesa di misura»: metterne uno sarebbe mettere un numero a caso,
## che e' la cosa che questo progetto vieta.
##
## ## Perche' `body_scale` arriva come **parametro** e non come costante
##
## Il fattore e' di `-arena`. Copiarlo qui dentro (o scrivere `3.4`) sarebbe una
## copia che mente alla prima riga cambiata di quel file — la lezione delle sei
## copie di m9, gia' pagata una volta. Quindi il fattore arriva dal contratto,
## passa per un campo di `horde.gd` letto **una volta sola** all'avvio (come gli
## ostacoli di m10) e viene passato qui a ogni passo: nessuna copia, nessun
## fallback silenzioso in questo file, e chi lo registra e' `-arena`.
##
## ## Il numero che cambia, e il numero che non cambia
##
## La portata del boss passa da **2,35 m a 6,91 m** e i morsi offerti salgono:
## il gioco diventa piu' difficile. Il danno per morso e la cadenza **non** sono
## stati toccati: sono le due cose che m7 ha misurato e continuano a valere.
static func bite_range_of(kind: int, body_scale: float) -> float:
	return bite_range_for(RADIUS[clamp_kind(kind)], body_scale)

## Idem per un raggio che non viene dalla tabella: serve al dente «`RADIUS x 7`
## non cambia il verdetto» di `tests/test_orda.gd`, che vuole la banda a zero
## anche per un raggio che nessuna specie ha. Non e' una seconda formula: e' la
## stessa, con il ragchio in mano.
static func bite_range_for(radius: float, body_scale: float) -> float:
	return body_scale * radius + TOUCH_REACH

## La portata di morso **peggiore** fra le specie: il numero con cui una legge di
## nascita puo' promettere che nessuno nasce addosso al giocatore.
##
## ## Perche' serve, e perche' il massimo e non uno medio
##
## Una legge di nascita e' **anteriore** alla scelta della specie: il punto e'
## deciso prima di sapere chi ci nascera'. Quindi l'unico numero che rende la
## clausola **dimostrabile** su ogni onda e' il peggiore dei casi, non quello
## dell'onda 1 (`brute`, 3,85 m a `body_scale = 3,4`) e non una media.
##
## Con `body_scale = 3,4` il numero e' **6,91 m** (boss), e viene da
## `RADIUS` e da `TOUCH_REACH` per costruzione: nessun numero scritto qui dentro.
static func bite_range_max(body_scale: float) -> float:
	var peggiore := 0.0
	for r in RADIUS:
		peggiore = maxf(peggiore, bite_range_for(r, body_scale))
	return peggiore

## Danno di un morso di runner, e da dove viene questo numero.
##
## Il primo tentativo era **2.0** ed era **troppo forte**: misurava 6.40 s da fermo
## al centro dell'onda 1, cioe' un giocatore che sbaglia un attimo muore prima
## di capire cosa e' successo. Il numero e' stato abbassato a 1.6 e rimisurato.
## Il tetto alla cadenza (`TOUCH_INTERVAL` in `horde.gd`) e' stato messo **prima**
## di questo ritocco ed e' quello che tiene la curva: vedi la sezione "il morso"
## di `horde.gd`, che dichiara anche il primo tentativo sbagliato.
const TOUCH_DAMAGE_BASE := 1.6

## Secondi fra due morsi della stessa specie, per il runner. Il resto lo
## ricava da `MASS` con la radice quadrata (vedi sopra).
const TOUCH_PERIOD := 1.0

# --- m12: COME nasce un morso, e perche' il contatto e' la causa ----------------
#
# ## Il difetto che questo blocco chiude, in numeri
#
# Il morso era **schedulato a timer**: entrava solo se `bite_timers[i]`, che
# contava i secondi di contatto, aveva raggiunto `TOUCH_PERIOD` (1,00 s sul
# runner, 3,16 s sul boss). Ma il tempo che il giocatore resta dentro la portata
# di morso **attraversando l'orda** e' molto piu' corto di un periodo: misurato
# in `tests/test_orda.gd` sezione 11-z, treno a 13,65 m/s, caso peggiore
#
# | specie | portata | contatto misurato | periodo di prima | morsi per attraversamento, prima |
# |---|---|---|---|---|
# | runner | 1,98 m | **0,233 s** (14 passi) | 1,000 s | **0** |
# | grunt | 2,49 m | **0,333 s** (20 passi) | 1,198 s | **0** |
# | brute | 3,85 m | **0,533 s** (32 passi) | 1,969 s | **0** |
# | boss | 6,91 m | **1,000 s** (60 passi) | 3,162 s | **0** |
#
# Il contatto non era la causa del morso, era solo il permesso: il nemico ti
# arrivava addosso e non mordeva, e la ragione non era ne' la distanza ne' il
# danno. Era il timer.
#
# ## Il rimedio, e il **solo** limite che si tiene
#
#     entra in portata e il passo prima non c'era  ->  morde
#
# e poi **un** limite, che serve per non uccidere a 60 Hz: **lo stesso nemico non
# può mordere due volte senza che il contatto si sia interrotto**. Il modo più
# semplice è il **rientro**: morde una volta, e non ripete finché non è uscito
# dalla portata. Un passo solo fuori è sufficiente, e questo è il numero che
## rende possibile il criterio «ogni nemico attraversato morde almeno una volta»:
## un nemico che il giocatore attraversa esce sempre dalla portata, quindi è
## sempre riarmaato al prossimo attraversamento.
#
# ## Perche' questo e' un **flag**, e non un periodo
#
# Un periodo e' un tempo che passa **anche senza contatto**: e' esattamente il
# difetto di prima, riscritto. Il rientro è invece legato al contatto, quindi
# sta in due bit e non in un float. `TOUCH_PERIOD` resta dichiarato e resta
# assertato perche' è la tabella della cadenza di m7: non e' piu' il gate del
# morso (lo è `TOUCH_INTERVAL` in `horde.gd`, tarato sul contatto **misurato**),
# ma resta la derivazione della tabella che questa sezione stampa.

## Il morso è causato dal **contatto**, cioè dal bordo in salita della portata.
const BITE_CONTACT := 0
## Il morso è schedulato a timer: la forma di **prima**. Vive solo per il dente di
## `tests/test_orda.gd` (che deve poter girare il gioco vecchio e misurarne i
## numeri) e non è mai quello di partita: `horde.bite_mode` vale `BITE_CONTACT`
## dal primo passo e nessuna riga di `src/` lo cambia.
const BITE_TIMER := 1

## `bite_latch` — due bit per nemico, e nulla altro.
const BITE_IN_PORTATA := 1  ## il passo scorso era a portata: il contatto è **vecchio**
const BITE_SPENT := 2  ## ha morso: non ripete finché non esce dalla portata (rientro)

# --- m13: il mortar -------------------------------------------------------------
#
# ## La richiesta dell'utente, 2026-10-15, e cosa c'e' qui dentro
#
# «in caso riusciamo a dare un attacco ranged ad uno dei mostri? entro un certo
# range si ferma, spara come un mortaio, viene segnalato con una cupola rossa dove
# atterra il colpo dando la possibilità di schivare al giocatore».
#
# Tre pezzi, e sono in tre posti diversi perche' sono di due foglie:
#
# | pezzo | dove sta | chi lo fa |
# |---|---|---|
# | il colpo cade **dopo** `mortar_telegraph_s` secondi | qui, `telegraph_for()` | `-orda` |
# | la cupola rossa che disegna quegli stessi secondi | `horde.mortar_shots` | `-arena` |
# | che il colpo sia **schivabile** e che **non sia gratis** | qui sotto | `-orda` |
#
# I due numeri attraversano il contratto (`Game.mortar_telegraph_s`,
# `Game.mortar_blast_m`) perche' sono **due foglie e un solo istante**: se ognuna
# avesse il suo, la cupola direbbe «schiva qui» e il colpo arriverebbe altrove,
# che e' la classe di difetto delle sei copie di m9.
#
# ## I TRE numeri nuovi, e da dove viene ognuno
#
# ### 1. `PLAYER_SPEED`, la velocita' che rende la disuguaglianza possibile
#
# E' la velocita' del giocatore, e la fonte **non e' qui**: e' il numero con cui
# il vertice ha scritto la disuguaglianza stessa in `src/core/contracts.gd` (13,65
# m/s). Copiarlo e' una copia che mente, quindi il criterio di `tests/test_orda.gd`
# verifica che il contratto dichiari ancora `13,65` e che questa costante sia
# l'unica occorrenza in codice di quel numero.
const PLAYER_SPEED := 13.65

# ### 2. Il raggio di esplosione: **l'area che la specie stessa minaccia**
#
#     blast = bite_range_of(MORTAR, body_scale) = corpo_disegnato + TOUCH_REACH
#
# Perche' questa e non una cifra: e' la **portata di morso del mortar**, cioe' la
# grandezza che il giocatore ha gia' davanti agli occhi sotto forma di «quando e'
# cosi' vicino mi morde». Il colpo e' pericoloso esattamente quanto e' pericoloso
# il mostro che lo spara: piu' piccolo e il mortar sarebbe una species che vale
# meno del suo corpo, piu' grande e servirebbe un numero nuovo che nessuno saprebbe
# controllare. E deriva da `RADIUS[MORTAR]` e da `body_scale`, quindi si muove da
# solo se il renderer cambia la taglia, come `radii`.
static func blast_radius_for(body_scale: float) -> float:
	return bite_range_of(MORTAR, body_scale)

# ### 3. Il tempo del telegrrafo: **derivato**, e non scelto a occhio
#
# La condizione che decidere se la cosa e' giusta ha due lati, e sono entrambi
# sbagliati agli estremi:
#
#     PLAYER_SPEED x telegraph >= blast + TOUCH_REACH
#
# sotto, il colpo **non e' schivabile** ed e' un delitto; sopra, **non costa
# niente** ed e' un regalo. Quindi il tempo non e' una cifra: e' il tempo minimo
# di fuga **per un metro che il giocatore deve davvero percorrere** — uscire dal
# raggio di esplosione piu' il suo corpo, che e' `TOUCH_REACH` — moltiplicato per
# il margine dichiarato qui sotto.
static func telegraph_for(body_scale: float) -> float:
	return (blast_radius_for(body_scale) + TOUCH_REACH) / PLAYER_SPEED * DODGE_MARGIN

# ## Il margine, e perche' e' 2,0 e non 1,0
#
# A `1,0` il tempo del telegrrafo e' **esattamente** il tempo di fuga: si puo'
# schivare solo se si sa gia' dove va a cadere il colpo prima che la cupola
# compaia, e cioe' se non lo si schiva. Quello non e' una finestra, e' una
# frase sulla geometria.
#
# A `2,0` la finestra e' **due volte** il minimo: la cupola sta a schermo per un
# tempo di fuga intero *dopo* che il giocatore l'ha vista. E il criterio e' sui
# due lati, perche' i due lati sono due difetti diversi:
#
#   - **sotto** `DODGE_MARGIN = 1,0`: il colpo non e' schivabile (delitto);
#   - **sopra** il tempo di ricarica (`touch_period_of(MORTAR)`): un nemico puo'
#     avere **due cupole in volo** nello stesso istante e non si sa piu' quale e'
#     quella pericolosa, cioe' il mortaio diventa un'arma che non si legge.
#
# Il secondo tetto e' derivato (`reload_of(MORTAR)`) e non e' un numero scritto:
# e' la cadenza con cui quella massa puo' colpire, e cioe' la stessa tabella che
# gia' decide quanto spesso un morso arriva addosso.
static var DODGE_MARGIN := 2.0

# ## La distanza a cui il mortar si ferma: **derivata**, da 2x a **3x** il raggio
#
#     engage = 3 x blast = 3 x bite
#
# Non e' una distanza scelta: e' un multiplo della somma delle due cose che il
# mortar puo' fare — il suo corpo e la cupola che sta per disegnare — e la sua
# proprieta' resta un'identita', non una taratura. Sostituendo
# `bite = corpo_disegnato + TOUCH_REACH`:
#
#     engage - corpo_disegnato - blast  ==  blast + TOUCH_REACH
#
# cioe' **fra il corpo disegnato del mortar e il bordo della cupola che sta per
# disegnare ci sono esattamente `blast + TOUCH_REACH` metri**: il raggio
# d'esplosione piu' il raggio del corpo del giocatore. Con il multiplo di prima
# (`2 x blast`) quel numero era `TOUCH_REACH` e il criterio lo asseriva cosi';
# adesso e' piu' grande, quindi **l'identita' e' cambiata e va detta**, non
# lasciata com'era con la formula nuova sotto.
#
# Il colpo non tocca mai il nemico che l'ha sparato, e il mortar non puo'
# morderti da dove sta (la fermata e' fuori dalla sua stessa portata di morso,
# per costruzione: `engage > bite`).
#
# ## Perche' **3x** e non 2x, e cosa cambia davvero per il giocatore
#
# | | prima (m13) | adesso (m17) |
# |---|---|---|
# | raggio del colpo | 5,21 m | 5,21 m (**invariato**) |
# | fermata | 10,42 m | **15,63 m** |
# | finestra di schivata | 0,8293 s | 0,8293 s (**invariata**) |
# | margine di fuga | 2,00 | 2,00 (**invariato**) |
#
# **La finestra non si muove di un secondo e non si muove di un metro**: e' la
# stessa disuguaglianza di prima, `telegraph_for()`, che di questa distanza non sa
# niente. Quindi **la matematica della fuga e' identica**: chi schivava schiva
# ancora, con lo stesso margine. Quello che cambia e' **quanto presto ti
# raggiunge**: prima il mortar ti colpiva quando eri gia' vicino — la fermata a
# 10,42 m metteva la cupola addosso a chi era gia' dentro il cerchio dei nemici —
# adesso ti colpisce mentre sei **ancora lontano**, a 15,63 m. Non e' «piu'
# danno»: il danno e' lo stesso identico numero (13,71 hp, il morso del boss).
# E' un colpo che arriva **prima nella partita**, e quindi che ti costringe a
# leggere la cupola da piu' lontano, con piu' nemici fra te e quella.
static func engage_for(body_scale: float) -> float:
	return 3.0 * blast_radius_for(body_scale)

# ## Il danno di un colpo: **il morso peggiore del gioco**
#
#     MORTAR_BLAST_HP = TOUCH_DAMAGE_BASE x MASS[BOSS] / MASS[RUNNER] = 13,71 hp
#
# Perche' il morso del boss e non un numero nuovo: se un colpo costasse meno del
# morso peggiore che il gioco ha, un giocatore che punta contro un boss starebbe
# fermo invece di schivare — cioe' la cupola smetterebbe di essere una scelta e
# diventerebbe un avvertimento inutile. Il numero **deriva** dalla tabella delle
# masse, quindi non e' scritto due volte: la tabella delle specie resta l'unica
# fonte di quanto un colpo costa.
static var MORTAR_BLAST_HP := TOUCH_DAMAGE_BASE * MASS[BOSS] / MASS[RUNNER]

## Il tempo di ricarica del mortar: **il periodo di morso della sua stessa
## specie**, `touch_period_of(kind)`. Non e' una tabella nuova: e' la cadenza con
## cui quella massa puo' colpire, ed e' gia' dichiarata e verificata. E perche'
## non un numero suo: se il mortar ricaricasse piu' in fretta del suo telegrrafo
## avrebbe due cupole in volo, che e' il secondo difetto del margine sopra.
static func reload_of(kind: int) -> float:
	return touch_period_of(kind)

static func clamp_kind(kind: int) -> int:
	return clampi(kind, 0, KIND_COUNT - 1)

static func hp_of(kind: int) -> float:
	return HP_MAX[clamp_kind(kind)]

static func speed_of(kind: int) -> float:
	return SPEED[clamp_kind(kind)]

static func radius_of(kind: int) -> float:
	return RADIUS[clamp_kind(kind)]

static func mass_of(kind: int) -> float:
	return MASS[clamp_kind(kind)]

static func color_of(kind: int) -> Color:
	return COLOR[clamp_kind(kind)]

static func knockback_resist_of(kind: int) -> float:
	return KNOCKBACK_RESIST[clamp_kind(kind)]

## Quanto toglie hp un morso di questa specie. Vedi la sezione "il morso" in
## testa al file: una sola formula sulla tabella `MASS`, nessun numero scritto
## due volte.
static func touch_damage_of(kind: int) -> float:
	var k := clamp_kind(kind)
	return TOUCH_DAMAGE_BASE * MASS[k] / MASS[RUNNER]

## Quanti secondi devono passare fra due morsi della stessa specie. Stessa
## tabella, radice quadrata: piu' pesante significa piu' lento a mordere.
static func touch_period_of(kind: int) -> float:
	var k := clamp_kind(kind)
	return TOUCH_PERIOD * sqrt(MASS[k] / MASS[RUNNER])

## Un passo di simulazione del nemico `i`.
##
## `push` e' la spinta di separazione calcolata dalla griglia (l'horda la passa
## gia' pronta: qui dentro non si sa niente di griglie ne' di query).
##
## `has_target` dice se il bersaglio e' un **giocatore** e non un punto vuoto.
## Senza di esso nessun nemico morde: il morso e' l'unica azione che questa
## simulazione fa sul giocatore, e contro un bersaglio che non c'e' non ha
## senso accenderla. E' anche il motivo per cui nessun test che mette l'orda da
## sola si trova un morso senza avergli dato un giocatore.
##
## `flow` e' il **campo di percorrenza** di `src/sim/flow_field.gd` e puo' essere
## `null`. E' `null` quando gli ostacoli non sono registrati sul contratto, e in
## quel caso questo passo e' **identico** a quello di prima della milestone 10:
## l'evitamento non e' un interruttore della fisica, e' una direzione in piu'
## quando c'e' qualcosa da evitare.
##
## `body_scale` e' il fattore di calibrazione del corpo che arriva dal contratto
## (`Game.enemy_body_scale`), letto una volta sola da `horde.gd` e passato qui a
## ogni passo: la portata del morso e' derivata dalla taglia **disegnata**, quindi
## il numero che si vede e quello che morde non possono divergere (vedi
## `bite_range_of` piu' in alto).
##
## `bite_timers`, `bite_latch` e `bites` sono tre array paralleli in scrittura:
## il primo tiene da quanti secondi il nemico e' in contatto, il secondo porta i
## due bit del **rientro** (`BITE_IN_PORTATA`, `BITE_SPENT`) e il terzo dice se
## il nemico chiede di mordere in questo passo (1) o no (0). **La decisione del
## morso e' qui dentro**, dove stanno le specie; a chi tocca applicarlo
## (`horde.gd`) spetta solo il tetto di cadenza e la chiamata al contratto.
##
## Tutti gli array sono paralleli e lunghi `count`: scrive solo `positions[i]`,
## `velocities[i]`, `timers[i]`, `bite_timers[i]`, `bite_latch[i]`, `bites[i]`,
## `mortar_timers[i]` e `mortar_fire[i]`. Nessuna allocazione.
##
## `bite_latch` serve perche' **senza di lui il contatto non puo' essere la
## causa del morso**: per morso all'ingresso occorre sapere se il passo scorso il
## nemico era gia' a portata, e quello e' un fatto del nemico (il suo stato), non
## della sua posizione.
##
## `bite_mode` e' `BITE_CONTACT` (il contatto e' la causa) oppure `BITE_TIMER`
## (la forma di prima, che vive solo per il dente di `tests/test_orda.gd`). Lo
## passa `horde.gd` dal suo campo pubblico, che vale `BITE_CONTACT` dal primo
## passo: un `static var` qui dentro sarebbe una superficie che `src/` puo'
## cambiare senza passare dall'ordine, che e' la strada che questo progetto vieta
## di continuo.
## ## m13: due array in piu', e perche' sono due e non uno
##
## Il mortar ha bisogno di **due** fatti: quanto manca alla ricarica
## (`mortar_timers`, un `float`) e se questo passo ha chiesto il colpo
## (`mortar_fire`, un intero). Non si puo' fare con uno solo perche' i due tempi
## sono diversi — il primo arriva a zero e aspetta, il secondo e' un istante —
## e misurarli nello stesso numero sarebbe la stessa ricetta dell'array parallelo
## che si disallinea: un nemico che spara con lo stato di un altro.
static func step(i: int, delta: float, target: Vector3, push: Vector3,
		positions: PackedVector3Array, velocities: PackedVector3Array,
		timers: PackedFloat32Array, kinds: PackedInt32Array,
		arena_radius: float, bite_timers: PackedFloat32Array,
		bite_latch: PackedInt32Array, bites: PackedInt32Array, has_target: bool,
		body_scale: float, bite_mode: int, mortar_timers: PackedFloat32Array,
		mortar_fire: PackedInt32Array, flow = null) -> void:
	var kind := clamp_kind(kinds[i])
	var pos := positions[i]
	var to_target := target - pos
	to_target.y = 0.0
	var dist := to_target.length()
	var dir := Vector3.ZERO
	if dist > 0.001:
		dir = to_target / dist
	# ## Il campo di percorrenza, e perche' sta qui e non dentro l'orda
	#
	# La **direzione** e' l'unica cosa che il campo cambia: se la linea diretta
	# non e' interrotta, `steer` restituisce la stessa direzione di due righe
	# sopra, quindi un nemico che non ha ostacoli addosso si muove esattamente
	# come prima di m10 e i numeri di m7/m8/m9 restano quelli che erano. Se la
	# linea e' interrotta, restituisce il verso del campo mescolato con la
	# trazione diretta sul bersaglio, e il campo da solo farebbe girare il
	# nemico attorno all'ostacolo per sempre.
	if flow != null:
		dir = flow.steer(pos, target)

	# Arrivo: rallenta vicino al bersaglio, altrimenti gli si infila addosso e
	# i 200 nemici diventano un solo punto.
	var arrive := clampf(dist / ARRIVE_RADIUS, 0.0, 1.0)
	# ## m13: il mortar **si ferma**, e non e' una velocita' diversa
	#
	# Il mortar non «va piu' piano»: a `engage_for()` si **ferma**, cioe' la
	# spinta verso il bersaglio sparisce e rimane solo quella di separazione.
	# E' la differenza fra un nemico che rallenta e uno che ha deciso di
	# tirare: rallentare e' una velocita', fermarsi e' una scelta, e la scelta
	# e' quello che il giocatore impara a schivare.
	#
	# `has_target` e' nella condizione per la stessa ragione del morso: senza
	# un giocatore non c'e' nessuno a cui mirare e nessuna cupola da disegnare,
	# e un mortar che spara al vuoto sarebbe un nemico che spara.
	var fermo := kind == MORTAR and has_target and dist <= engage_for(body_scale)
	var wanted := push if fermo else dir * SPEED[kind] * arrive + push

	var vel := velocities[i]
	vel += (wanted - vel) * minf(1.0, delta * ACCEL)
	vel.y = 0.0
	vel = vel.limit_length(SPEED_MAX)

	# Banda elastica sul bordo dell'arena: il nemico puo' sbordare di qualche
	# decina (knockback), non deve poter sparire.
	var flat := Vector2(pos.x, pos.z)
	var r := flat.length()
	var limit := maxf(1.0, arena_radius - RADIUS[kind])
	if r > limit:
		# `flat` e' un Vector2 perche' la distanza dal centro si calcola sul piano:
		# la spinta pero' va su `vel`, che e' un Vector3, quindi il verso va
		# rimontato con y = 0 invece che promuoverlo (promuovere aggiungerebbe
		# anche una componente verticale, che qui non esiste).
		vel -= Vector3(flat.x, 0.0, flat.y) / maxf(r, 0.001) * (r - limit) * EDGE_PUSH

	timers[i] = maxf(0.0, timers[i] - delta)
	# ## m13: il mortar, e perche' la decisione e' qui e non dentro l'ordine
	#
	# `mortar_timers[i]` e' un semplice conto alla rovescia della ricarica e
	# `mortar_fire[i]` e' la **richiesta** del passo, esattamente come `bites[i]`
	# per il morso: la **decisione** (sono in portata? sono carico?) sta qui,
	# dove stanno le specie, e a chi tocca applicarla spetta solo la strada
	# dichiarata — cioe' scrivere **dove** e **quando** cade, che e' il numero
	# che `-arena` deve disegnare nello stesso istante.
	#
	# Il timer **non e' un flag**: quando il giocatore esce dalla portata il
	# conto si ferma a meta' e il mortar resta carico per quello che manca,
	# quindi entra ed esce e spara appena entra. Il nemico che si scarica e
	# aspetta un periodo intero e' il difetto che m12 ha chiuso per il morso, e
	# non si ripete qui.
	mortar_fire[i] = 0
	if fermo:
		mortar_timers[i] -= delta
		if mortar_timers[i] <= 0.0:
			# Il colpo e' gia' sparso: la ricarica parte **adesso**, non quando
			# il colpo cade. Sono due istanti diversi e l'ordine e' quello che
			# tiene sotto `telegraph_for()` il tetto «una cupola per nemico».
			mortar_timers[i] = reload_of(kind)
			mortar_fire[i] = 1
	# ## Il morso: il contatto e' la causa (m12)
	#
	# `bite_latch` e' di due bit: `BITE_IN_PORTATA` dice che **il passo scorso**
	# il nemico era a portata, e `BITE_SPENT` che ha gia' morso e non puo'
	# ripetere finche' non esce. `bites[i]` e' la **richiesta**: resta 1 fino a
	# che `horde.gd` la consegna, e per questo un morso trattenuto dal tetto di
	# cadenza non e' un morso perso (vedi `_apply_bites`).
	bites[i] = 0
	if not (has_target and dist <= bite_range_of(kind, body_scale)):
		# **Uscito**: il rientro e' automatico e costa un passo solo. E' qui che
		# il nemico attraversato diventa capace di mordere di nuovo, ed e'
		# l'unico posto del file in cui il rientro si arma.
		bite_latch[i] = 0
		bite_timers[i] = 0.0
	elif bite_mode == BITE_TIMER:
		# La forma di prima, tenuta **fuori dal percorso di partita**: serve al
		# dente di `tests/test_orda.gd`, che la riattiva per una corsa e
		# rimostra i numeri di prima. Se questa riga sparisse, il dente
		# misurerebbe il rimedio e chiamerebbe "prima" un numero che non e' mai
		# esistito.
		var atteso := bite_timers[i] + delta
		if atteso >= touch_period_of(kind):
			bites[i] = 1
			bite_timers[i] = 0.0
		else:
			bite_timers[i] = atteso
		bite_latch[i] = BITE_IN_PORTATA
	else:
		var f: int = bite_latch[i]
		if (f & BITE_IN_PORTATA) == 0 and (f & BITE_SPENT) == 0:
			# Bordo in salita della portata, e rientro armato: **morde**.
			bites[i] = 1
		bite_latch[i] = f | BITE_IN_PORTATA
		# `bite_timers` resta il contatore di secondi di contatto, ed e' il
		# numero che la sezione 11-z stampa: e' la telemetria di questa riga.
		bite_timers[i] += delta
	velocities[i] = vel
	if flow == null:
		positions[i] = pos + vel * delta
		return
	# ## Il vincolo esatto, e perche' e' qui e non nella griglia
	#
	# `push_out` e' un test di distanza disco-corpo, non una griglia: e' lui che
	# rende vero il criterio n. 2 al centesimo di millimetro. La spinta sposta
	# la posizione sul bordo e **cancella la componente di velocita' che entra
	# nell'ostacolo**: e' quello che fa scivolare il nemico lungo il disco
	# invece di piantarlo sul bordo, ed e' la differenza fra aggirare e
	# incastrarsi (criterio n. 4).
	var dopo := pos + vel * delta
	var spinta: Vector3 = flow.push_out(dopo, RADIUS[kind])
	if spinta.length_squared() > 0.000001:
		dopo += spinta
		var fuori: Vector3 = spinta.normalized()
		var dentro := vel.dot(fuori)
		if dentro < 0.0:
			vel -= fuori * dentro
			velocities[i] = vel
	positions[i] = dopo