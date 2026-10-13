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

## Le quattro specie. L'indice nel record e' questo intero (`kinds[i]`).
const RUNNER := 0
const GRUNT := 1
const BRUTE := 2
const BOSS := 3
const KIND_COUNT := 4
const KIND_NAMES := ["runner", "grunt", "brute", "boss"]

# Tabelle per specie, allineate 1:1 con KIND_NAMES. Indexate da `kind`.
static var HP_MAX := PackedFloat32Array([14.0, 34.0, 110.0, 900.0])
static var SPEED := PackedFloat32Array([6.6, 4.0, 2.3, 1.7])
static var RADIUS := PackedFloat32Array([0.45, 0.60, 1.00, 1.90])
static var MASS := PackedFloat32Array([0.7, 1.0, 2.6, 6.0])
## Quanto knockback il nemico si mangia: 0 = tutto, 0.9 = quasi immobile.
static var KNOCKBACK_RESIST := PackedFloat32Array([0.0, 0.20, 0.55, 0.90])
## Tinta per specie: e' quello che arena passa al MultiMesh, cosi' l'arena non
## deve sapere cosa sia un nemico.
static var COLOR := PackedColorArray([
	Color(0.98, 0.35, 0.30),
	Color(0.86, 0.20, 0.55),
	Color(0.55, 0.25, 0.88),
	Color(1.00, 0.76, 0.15),
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
# **La scena vera non ha seme**: `horde.seed = 0` vuol dire `randomize()`, quindi
# la disposizione e' diversa a ogni avvio. Le righe sotto hanno dispersione e si
# leggono come **bande**, non come valori; sono stampate a ogni lanzo dalla
# sezione 12, che e' il posto dove si rileggono. L'unica riga senza dispersione
# e' la prima, e non per caso: e' l'unica che **sceglie** il numero.
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
# ### Perche' questo numero e' quello
#
# La condizione del morso e' `dist <= RADIUS[kind] + TOUCH_REACH`: la somma di
# due raggi deve essere una distanza, e i due raggi che ci sono sono **il corpo
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
## `bite_timers` e `bites` sono due array paralleli in scrittura: il primo
## tiene da quanto tempo questa specie e' in contatto, il secondo dice "questo
## passo morde" (1) o no (0). **La decisione del morso e' qui dentro**, dove
## stanno le specie; a chi tocca applicarlo (`horde.gd`) spetta solo il tetto
## dei morderci contemporanei e la chiamata al contratto.
##
## Tutti gli array sono paralleli e lunghi `count`: scrive solo `positions[i]`,
## `velocities[i]`, `timers[i]`, `bite_timers[i]` e `bites[i]`. Nessuna
## allocazione.
static func step(i: int, delta: float, target: Vector3, push: Vector3,
		positions: PackedVector3Array, velocities: PackedVector3Array,
		timers: PackedFloat32Array, kinds: PackedInt32Array,
		arena_radius: float, bite_timers: PackedFloat32Array,
		bites: PackedInt32Array, has_target: bool, flow = null) -> void:
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
	var wanted := dir * SPEED[kind] * arrive + push

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
	# Il morso riparte da zero quando il contatto si perde: una specie deve
	# restare addosso per un periodo **intero** prima di mordere, altrimenti un
	# nemico che sbatte sul bordo del contatto azzererebbe il timer ogni passo e
	# non morderebbe mai. E il prezzo e' dichiarato: chi entra ed esce spesso
	# non morde affatto.
	bites[i] = 0
	if has_target and dist <= RADIUS[kind] + TOUCH_REACH:
		var atteso := bite_timers[i] + delta
		if atteso >= touch_period_of(kind):
			bites[i] = 1
			bite_timers[i] = 0.0
		else:
			bite_timers[i] = atteso
	else:
		bite_timers[i] = 0.0
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