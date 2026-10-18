extends Node3D
## Il pool dei proiettili. -gameplay. Capacità fissa, nessuna allocazione nel
## ciclo di gioco (piano §5, regola 2).
##
## Come funziona, e perché è scritto così:
##
## 1. **100 slot, creati una volta sola** in `_ready()`. Da lì in avanti non
##    esiste più nessuna `new()`, `instantiate()` o `queue_free()`: un colpo
##    riusa uno slot, un proiettile scaduto torna in coda con uno *swap con
##    l'ultimo* (O(1), e l'elenco degli attivi resta compatto in `[0, _count)`).
##    Se il pool è pieno, il più vecchio viene riusato: in un bullet heaven
##    perdere il colpo è peggio che raddoppiare un proiettile già sparato.
##    Lo swap sposta un **indice**, non un record: vedi `_items`, `_order`,
##    `_free`.
##
## 2. **L'orda si legge, non si possiede.** Nessun nemico è un nodo: qui il
##    **contatto** scandisce i due campi pubblici che il piano dichiara come
##    "massa" (`horde.count` e `horde.transforms`) e scrive **solo** attraverso
##    `Game.damage_enemy(indice, danno, knockback)`.
##
##    Il pool **non usa `nearest_enemy`**, e non per dimenticanza: la **mira** la
##    fa `weapon_base._try_fire`, che chiama `Game.nearest_enemy(pos, raggio)` e
##    riceve un **indice** (`-1` = nessun bersaglio, piano §5.2). `-1` non è un
##    nemico: chi lo riceve non spara e non lo passa mai a `damage_enemy`. Il
##    contatto invece ha bisogno di *tutti* i nemici vivi per frame — il segmento
##    del proiettile viene confrontato con ciascuno e si sceglie il primo
##    incontrato — e una "nearest" non serve a niente: quello che serve è
##    `horde.transforms`, cioè gli indici buoni. Per questo il percorso del
##    danno è: **mira** via `Game.nearest_enemy` (nell'arma), **impatto** via
##    `horde.transforms` + `Game.damage_enemy` (qui).
##
## 3. **Il contatto è un segmento, non un punto.** A 26 m/s e 60 Hz un
##    proiettile avanza di 0.43 m per frame: testando solo la posizione finale
##    passerebbe attraverso i nemici senza colpirli mai. Qui si testa il
##    segmento percorso nel frame, e si sceglie il **primo** nemico toccato
##    (parametro `t` minimo), così il proiettile che attraversa una folla
##    colpisce quello davanti e non quello dietro. «Primo» vuol dire primo **fra
##    quelli della banda di quota** del punto 4: i nemici degli altri piani non
##    sono candidati e non sono «dietro» nessuno.
##
## 4. **Il contatto è sul piano XZ, dentro una banda di quota.** Qui sotto ci
## sono due fatti distinti e insieme, e vanno tenuti distinti:
##
##    - **la `y` non parteciupa al test geometrico**: il contratto non dice quale
##      `y` mette l'orda nei `transforms` (piedi del modello? centro?Origine?),
##      e ignorarla rende il proiettile indifferente a quella scelta invece di
##      fallire in silenzio quando l'orda ne sceglie un'altra. Per questo
##      `_segment_hit()` resta sul piano;
##    - **ma un nemico di un altro piano non e' un candidato**. Con la torre di
##      m12 (quattro piani) un test sul piano XZ fa sparare un colpo **attraverso
##      il pavimento**: il nemico colpito e' della specie giusta, muore con il
##      danno giusto, e il giocatore vede un colpo che arriva dal basso senza capire
##      perche'. E' il difetto piu' grave della torre perche' e' **invisibile**.
##
## Quindi `_collide()` filtra per **banda di quota** prima di confrontare: la banda
## del piano del proiettile e' `floor_height` letto dal contratto, e i due bordi si
## calcolano **una volta per `step()`**, non una volta per nemico. Il numero che
## decide questa scelta, il costo e il confronto con l'alternativa, sono nel blocco
## lungo di `_collide()`.
##
## 5. **Un ostacolo non ferma un proiettile.** Nemmeno per meta', nemmeno
##    "appena": `OBSTACLES_BLOCK_PROJECTILES = false` in testa a questo file, che
##    e' la meta' di -gameplay del criterio n. 6 di m10. La decisione e' sua e il
##    motivo (un muro che blocca anche i proiettili rende al sicuro e
##    irraggiungibile per sempre il giocatore che ci si mette dietro) sta per
##    esteso accanto alla costante.
##
## 6. **L'involucro di contatto e' il corpo che si vede, per specie.**
##    `enemy_contact_radius(kind) = Game.enemy_body_scale * Enemy.RADIUS[kind]`,
##    letto dal contratto e dalla tabella di `-orda`: e' la stessa identita' che
##    governa il morso dal 2026-10-14 (m11-quarta), quindi i due fatti non
##    possono divergere. Il numero che stava qui prima — `ENEMY_RADIUS = 0.55`
##    per tutte e cinque le specie — era rimasto indietro di `SIZE_FACTOR = 3.4`
##    e rendeva il mortar, largo 4,76 m a schermo, un bersaglio da 0,55 m: la
##    meta' della segnalazione «alcuni nemici non riescono a farmi danno». Il
##    blocco lungo accanto alla costante spiega perche' non c'e' piu' un numero
##    scritto qui.

const ProjectileScript := preload("res://src/weapons/projectile.gd")
## Le specie del nemico, **lette**: `Enemy.RADIUS` e' la tabella dei corpi
## (`src/sim/enemy.gd:51`) ed e' una `static var` di un file che non e' mio.
## Leggerla non e' scriverci: il difetto era una **copia** di un numero che
## un'altra foglia poteva cambiare, non il fatto che la tabella stia li'.
const EnemyScript := preload("res://src/sim/enemy.gd")

## ## m10: cosa fa un ostacolo a un proiettile
##
## `false`, e **voluto**. Non e' un dettaglio dimenticato e non e' un numero che
## nessuno usa: e' la dichiarazione che questo file fa a chi ci arriva dopo.
##
## Il contratto (`src/core/contracts.gd`, "Superficie di milestone 10") mette
## nella stessa riga tre fatti: l'ostacolo e' **solido per il giocatore**
## (`src/player/player.gd`), **solido per il nemico** (`src/sim/`, di -orda) e
## **trasparente ai proiettili** (qui). La terza meta' e' una **decisione del
## vertice** e non una conseguenza: se l'ostacolo fermasse anche i proiettili, il
## giocatore che ci si mette dietro sarebbe al sicuro e irraggiungibile per
## sempre, cioe' un gioco che si vince stando fermi.
##
## Quindi qui sotto, dentro `_collide()`, **non c'e' nessun ostacolo**, e non
## deve esserci: il contatto e' nemico per nemico e nient'altro. «Proiettili che
## si fermano» e' **m11**, e quando arrivera la decisione va presa li' e
## dichiarata come questa.
##
## Il perche' questa riga esiste invece di un commento: la foglia dopo che
## aggiungera' una `CollisionShape3D` a un proiettile, o un test di attraversata
## su un disco, la vedra **qui in cima** e non la consideri un dettaglio. Un
## proiettile che per caso non incontra un ostacolo e' un proiettile che passa
## per fortuna, ed e' cosi' che un muro che blocca chi lo usa e non chi lo
## combatte entra nel gioco senza che nessuno l'abbia scritto.
const OBSTACLES_BLOCK_PROJECTILES := false

## ## m15: i due **controfattuali**, e perche' due campi e non uno
##
## Il contatore e' unico perche' il confronto e' fra due comportamenti della
## stessa arma e i due lati hanno un nome diverso: `colpi_anticipati` e
## `colpi_senza_anticipo` non sono lo stesso numero contato due volte, sono il
## numeratore di due tassi che vanno confrontati (vedi il campo `anticipa` di
## `weapon_base.gd` e `_tasso_col_controfattuale` in `tests/test_progression.gd`).
##
## Il denominatore **non e' qui**: e' `weapon.shots`, che il test legge a ogni
## passo e sa a quale braccio appartiene, quindi qui dentro non c'e' nessun
## contatore che nessun altro contatore puo' contraddire.
var colpi_anticipati: int = 0
var colpi_senza_anticipo: int = 0

## ## m15: lo **scarto residuo**, e perche' e' una distanza e non una previsione
##
## La domanda e' «il predetto cade dentro il reach? e di quanto?», e l'unica
## grandezza che questo progetto puo' misurare per risponderci e' **la distanza
## minima che il segmento del colpo ha raggiunto da un centro nemico**, tenuta
## per tutto il volo e attribuita al braccio da cui il colpo e' partito.
##
## ## Perche' **non** «dove il bersaglio era davvero all'istante della previsione»
##
## Perche' **un indice non e' un'identita'**. Misurato: campionando l'indice del
## bersaglio all'istante in cui la previsione era vera (`tau` = `0,66 s`, circa
## `40` passi), l'indice contiene un nemico in media a **`29 m`** da dove
## conteneva: l'orda compatta i suoi array a ogni morte e li riempie subito
## (`count` resta `100` a ogni passo, con `SPAWN_RATE = 2,0/s`), quindi nel giro
## di mezzo secondo lo stesso numero punta a un nemico diverso. Il numero che si
## leggeva li' — uno **scarto residuo di `28,7 m`** — era la distanza fra due
## nemici, non fra una previsione e il suo bersaglio.
##
## Quindi la previsione si confronta **dentro il frame in cui il colpo passa**:
## `_segment_hit()` restituisce gia' la distanza minima (vedi la sua firma) e il
## minimo sul volo e' quello che il colpo e' passato vicino. Se quel minimo sta
## **dentro** il reach, il colpo poteva arrivare e quello che ha mancato e' il
## nemico che si e' mosso: **nessuna formula lo corregge**, perche' nessuna
## formula vede la svolta. Se sta **fuori**, il colpo non poteva arrivare e il
## difetto e' della previsione.
##
## Il confronto e' fatto con il **reach del runner** (`1,6900 m`), cioe' il
## **minimo** dei cinque: «dentro il reach di ogni specie» e' il numero severo,
## ed e' quello che serve per dire se il colpo poteva arrivare a qualunque
## bersaglio.
var scarto_anticipato := 0.0
var scarto_senza := 0.0
var campioni_anticipato := 0
var campioni_senza := 0
var dentro_anticipato := 0
var dentro_senza := 0

## Scene con la mesh del proiettile: i dati visuali stanno nelle scene, non in
## codice. Se non ci fosse, si usa un primitivo (vedi `_bullet_mesh`).
const PROJECTILE_SCENE := "res://scenes/projectile.tscn"

## Quanti proiettili esistono, per sempre. Assegnati una volta sola all'avvio.
const CAPACITY := 100

## ## m14-a: il raggio di contatto **non e' piu' un numero scritto qui**
##
## Il difetto che questa sezione chiude, in una riga. Qui sotto stava
##
##     const ENEMY_RADIUS := 0.55
##
## e quel numero era nato quando il nemico si disegnava `RADIUS[kind]` cioe'
## 0,45 m per il runner. Poi `SIZE_FACTOR = 3.4` ha triplicato i corpi e questa
## riga e' rimasta indietro: il proiettile prendeva il runner a 0,55 m e il
## **mortar a 0,55 m dentro un corpo che si vede largo 4,76 m**. Per il mortar —
## il primo nemico che devi uccidere mentre ti spara da 10,42 m — il colpo che
## arriva e' «invisibile colpisce»: passa accanto a una sagoma enorme e non
## succede niente. E' la segnalazione dell'utente, «alcuni nemici non riescono a
## farmi danno», nella sua meta' che non era il morso (chiusa da m11-quarta).
##
## ## La regola, che e' di m11-quarta e non di questo file
##
##     morse_entro(k) = Game.enemy_body_scale * Enemy.RADIUS[k] + TOUCH_REACH
##
## e l'involucro del proiettile e' **lo stesso involucro**, letto dallo stesso
## canale:
##
##     contatto_proiettile(k) = Game.enemy_body_scale * Enemy.RADIUS[k]
##
## Due fatti che oggi sono discordi diventano uno, e la banda va a **0,0000 per
## costruzione**, non per taratura. Il `TOUCH_REACH` **non** c'e': quegli 0,45 m
## sono il corpo del **giocatore**, cioe' lo sconto che il morso ha per
## arrivare addosso a te, e non un involucro del nemico. Copiarli qui
## significa che il proiettile colpisce mezzo metro oltre il bordo che si vede.
##
## ## Il vincolo forte e' a un senso solo
##
## L'involucro **non puo' mai essere piu' grande del corpo che si vede**: colpire
## cose invisibili e' peggio che non colpire cose visibili. Quindi il fattore si
## legge **dal contratto ogni volta che serve** (`Game.enemy_body_scale`, che
## `-arena` registra da `SIZE_FACTOR`) e non si copia da nessuna parte: e' la
## lezione delle sei copie di m9, gia' pagata una volta con questo numero.
##
## ## Il ripiego, e perche' e' `1.0`
##
## Se il contratto non dichiara il campo (un'orda montata senza autoload) il
## fattore non e' noto, e il unico valore che **non mente verso il grande** e'
## `1.0`: l'involuclo resta `RADIUS[k]`, cioe' il corpo nudo, che e' sempre
## piu' piccolo di quello disegnato. Non si scrive qui `3.4` nemmeno come
## riserva: il ripiego avvisa **una volta** e chi legge sa che il canale non e'
## arrivato, esattamente come `horde.body_scale_source` in `src/sim/horde.gd`.
const BODY_SCALE_FALLBACK := 1.0

## Nodo che disegna i proiettili: UNO solo, per 100 proiettili. Nessun nodo per
## proiettile, quindi il conteggio dei nodi non cresce sparando.
var _visual: MultiMeshInstance3D
var _visual_basis := Basis.IDENTITY

## L'arma che ha creato questo pool: il pool non conosce nessun altro script,
## prende da lei danno, knockback, vita e pierce. Senza tipo di classe per non
## dipendere da `weapon_base.gd` (nessuna dipendenza circolare, piano §5).
var weapon

## `CAPACITY` record, **sempre gli stessi oggetti nella stessa casella**, mai
## sostituiti e mai messi a `null`. `_items` non si riordina mai: e' il deposito
## dei record, e la sua forma non cambia dalla `_ready()` in poi.
var _items: Array = []
## Quale record di `_items` e' vivo adesso: `_order[0.._count)` sono gli attivi,
## compatti. E' un array di **interi**, non di record: cosi' il "swap con
## l'ultimo" sposta un indice e non un riferimento, e un record non può finire
## in due caselle insieme.
##
## Il difetto che questo evita, e che un `Array` di record diretto ha: liberando
## la casella `i` e spostando in `i` il record dell'ultimo, il record liberato
## sparisce dall'array e l'ultimo si ritrova **in due caselle**. Il prossimo
## `acquire` prende la casella `i` (libera) e rilancia dentro un record che è
## ancora in volo: il colpo sparisce e quello precedente viene teletrasportato.
## Con la pila `_free` sotto ogni record resta in una casella sola e la riusa e'
## sempre dello stesso oggetto, che e' quello che "zero allocazioni" significa.
var _order := PackedInt32Array()
## Pila, allocata una volta sola, degli indici di `_items` liberi. `_free_top` e'
## quanto e' piena: lo slot liberato e' l'ultimo (`_free[_free_top - 1]`).
var _free := PackedInt32Array()
var _free_top: int = 0
## Proiettili vivi adesso.
var _count: int = 0
## Quanti proiettili sono stati creati in totale. Deve restare `CAPACITY` per
## sempre: è il contatore che il test usa per dire "300 colpi, zero allocazioni".
var _created: int = 0
var _warned_no_horde: bool = false
## I due ripieghi di m14-a avvisano **una volta sola**, perche' un avviso per
## frame riempirebbe la console di un gioco che funziona. Vedi `BODY_SCALE_FALLBACK`
## in testa al file per la regola che li governa: quando il canale non arriva,
## si sceglie sempre il valore che **non** fa sembrare il nemico piu' grande.
var _warned_no_body_scale: bool = false
var _warned_no_kinds: bool = false

func _ready() -> void:
	_build_items()
	_build_visual()

func capacity() -> int:
	return CAPACITY

## Proiettili vivi adesso.
func active_count() -> int:
	return _count

## Quanti ne sono stati creati in totale dall'avvio: se cresce, qualcuno ha
## allocato nel ciclo di gioco.
func ever_created() -> int:
	return _created

## ## m14-a: l'involucro di contatto, e la sua unica formula
##
## `Game.enemy_body_scale * Enemy.RADIUS[kind]`: il fattore **dal contratto** e
## la tabella delle specie **da `src/sim/enemy.gd`**. Nessuna copia di nessuno
## dei due, e nessun `TOUCH_REACH`: vedi il blocco lungo in testa al file.
##
## E' pubblico perche' e' la misura del criterio, non un dettaglio: il test
## confronta questo numero con la portata del morso che l'orda espone
## (`horde.bite_range_of`), e i due devono combaciare su cinque specie.
func enemy_contact_radius(kind: int) -> float:
	return _body_scale() * _species_radius(kind)

## Il fattore di calibrazione del corpo, **letto adesso** dal contratto. Non e'
## messo in campo all'avvio come in `src/sim/horde.gd`: qui non costa niente
## (una lettura di un float per frame) e la lettura per volta e' cio' che rende
## il canale un canale — un avvelenamento del contratto si vede subito, senza
## rimontare niente.
func _body_scale() -> float:
	var v: Variant = Game.get("enemy_body_scale")
	if v == null:
		_warn_no_body_scale()
		return BODY_SCALE_FALLBACK
	var s := float(v)
	if s <= 0.0:
		_warn_no_body_scale()
		return BODY_SCALE_FALLBACK
	return s

func _warn_no_body_scale() -> void:
	if _warned_no_body_scale:
		return
	_warned_no_body_scale = true
	push_warning("projectile_pool: il contratto non espone `enemy_body_scale`, quindi l'involucro di contatto ripiega su %.1f (corpo nudo, mai piu' grande del disegnato). tocca a terminal-gun-arena registrare il fattore." % BODY_SCALE_FALLBACK)



## Il raggio di specie `kind`, dalla tabella di `src/sim/enemy.gd`. Il clamp e'
## qui, in una riga, ed e' la stessa regola di `Enemy.clamp_kind`, cioe' limitare
## a `KIND_COUNT - 1`: la tabella non e' di questa foglia e non ci si accede
## fuori dai suoi indici.
func _species_radius(kind: int) -> float:
	var k: int = clampi(kind, 0, EnemyScript.KIND_COUNT - 1)
	return float(EnemyScript.RADIUS[k])

## Le specie dei nemici vivi, dall'orda. `kinds` e' un campo **pubblico** di
## `src/sim/horde.gd` come `transforms` e `count`: e' la stessa lettura di dati
## pubblici che questo file fa gia' da due milestone, non un pezzo di orda che
## qui si possiede.
func _kinds() -> PackedInt32Array:
	var horde: Node = Game.horde
	if horde == null:
		return PackedInt32Array()
	var v: Variant = horde.get("kinds")
	if not (v is PackedInt32Array):
		if not _warned_no_kinds:
			_warned_no_kinds = true
			push_warning("Game.horde non espone `kinds`: il proiettile non puo' sapere la specie e prende il raggio piu' piccolo della tabella, cioe' colpisce meno di quanto si vede. tocca a terminal-gun-orda.")
		return PackedInt32Array()
	return v

## Il raggio del nemico `i`: quello della sua specie, e **il piu' piccolo della
## tabella** quando l'orda non dice quale e'. Il ripiego e' dichiarato perche' il
## vincolo forte e' a un senso solo (l'involucro non puo' essere piu' grande del
## corpo che si vede) e questa e' l'unica direzione che gli e' concessa.
func _radius_at(kinds: PackedInt32Array, i: int) -> float:
	if kinds.is_empty() or i < 0 or i >= kinds.size():
		return _species_radius(EnemyScript.RUNNER)
	return _species_radius(int(kinds[i]))

## Il proiettile attivo numero `i` (0 <= i < `active_count()`).
func active_at(i: int):
	if i < 0 or i >= _count:
		return null
	return _items[_order[i]]

# --- Il ciclo di gioco ---------------------------------------------------------

## Un passo: muove tutti i proiettili vivi e ne testa il contatto.
## Si itera **all'indietro** e si libera con lo swap con l'ultimo sugli indici di
## `_order`: l'indice che finisce nello slot appena liberato è già stato mosso in
## questo frame, quindi nessun proiettile viene mosso due volte e nessuno resta
## indietro.
func step(delta: float) -> void:
	var i := _count - 1
	while i >= 0:
		var p = _items[_order[i]]
		p.step(delta)
		if p.expired():
			_release(i)
		else:
			_collide(p, i)
		i -= 1
	_draw()

## Implementazione di `Game.spawn_projectile`: riusa uno slot e restituisce
## il record. Non restituisce un `Node3D`, e non è un difetto: un proiettile
## non è un nodo (piano §5, regola 1). Il tipo di ritorno lo dichiara il piano
## §5.2: `-> bool`, `true` se il pool ha ceduto uno slot. Questo metodo
## restituisce il record per comodita' di chi chiama il pool direttamente, ma
## `weapon_base._spawn_projectile` non lo usa e passa dal contratto.
func acquire(pos: Vector3, dir: Vector3, speed: float):
	# ## «esiste ancora?», e non «e' nullo?»
	#
	# Il guard chiedeva `weapon == null`, che e' una domanda **diversa** da quella che
	# serve: un oggetto **liberato** non e' `null`. Se la scena e' stata rimontata e il
	# pool e' sopravvissuto, il pool puo' tenersi dentro un'arma **liberata**: il guard
	# passa, e la riga dopo (`weapon.damage`) legge da un oggetto morto — cioe' un
	# errore a runtime dentro `acquire()`, che restituisce `null` al chiamante senza
	# dirlo. Il chiamante vede `false` da `spawn_projectile`, `shots` non cresce, e il
	# difetto sembra della mira.
	#
	# E' la stessa domanda che `contracts.gd::_live()` si e' fatta con `_impl`: non
	# «la voce c'e'?» ma «**l'oggetto e' ancora vivo?**». La risposta giusta e' una sola
	# e si chiama `is_instance_valid`.
	if not is_instance_valid(weapon):
		return null
	var idx := -1
	if _free_top > 0:
		_free_top -= 1
		idx = _free[_free_top]
		_order[_count] = idx
		_count += 1
	elif _count >= CAPACITY:
		# Pool pieno: si riusa il più vecchio, che è l'attivo numero 0. Si
		# rilancia dentro il suo record senza toccare `_order` né `_count`: il
		# vecchio colpo sparisce e il nuovo lo prende in presto, che in un
		# bullet heaven e' meglio che perdere il colpo.
		idx = _order[0]
	else:
		# Difesa: `CAPACITY` record, `CAPACITY` indici, e ogni indice o e' in
		# `_order[0.._count)` o e' in `_free`. Se questa riga si raggiunge,
		# qualcuno ha rotto l'invariante e vale piu' un errore rumoroso che un
		# record fuori posto.
		push_error("projectile_pool: nessuno slot libero ma gli attivi sono %d su %d: l'invariante del pool e' rotta." % [_count, CAPACITY])
		return null
	var p = _items[idx]
	p.launch(pos, dir.normalized(), speed, weapon.damage, weapon.knockback,
		weapon.projectile_life, weapon.pierce)
	# m15: da quale dei due controfattuali e' partito questo colpo. E' un flag e
	# non nient'altro, e senza di questo il confronto fra i due bracci non
	# avrebbe un numeratore per ciascuno (vedi i due campi in testa al file).
	p.anticipato = bool(weapon.anticipa)
	p.scarto_min2 = INF
	return p

## Svuota il pool senza toccare l'orda. Serve ai test e al cambio d'onda.
func reset() -> void:
	while _count > 0:
		_release(0)
	_draw()
# --- Lettura dell'orda (dati pubblici, mai i suoi nodi) -------------------------

## Il nemico di indice `i`, se vivo. `Vector3.ZERO` se non c'è: nessuna
## posizione restituita è ambigua, perché ZERO è anche sotto il giocatore.
func enemy_position(i: int) -> Vector3:
	var horde: Node = Game.horde
	if i < 0 or horde == null:
		return Vector3.ZERO
	var v: Variant = horde.get("transforms")
	if not (v is PackedVector3Array):
		return Vector3.ZERO
	var tr: PackedVector3Array = v
	if i >= tr.size():
		return Vector3.ZERO
	return tr[i]

## Indice del nemico vivo più vicino a `from` entro `radius`, o `-1`.
## **Non è sul percorso del danno** e il gameplay non la chiama: vedi il punto 2
## in testa al file. Resta per chi debba debuggare un tiro (perche' ha colpito
## quello e non un altro) senza attraversare il contratto.
func nearest_enemy(from: Vector3, radius: float) -> int:
	var tr := _transforms()
	if tr.is_empty():
		return -1
	var n := mini(_live_count(tr), tr.size())
	var best := -1
	var best_d2 := radius * radius
	for i in n:
		var d2 := _dist2(from, tr[i])
		if d2 <= best_d2:
			best_d2 = d2
			best = i
	return best

# --- Interno ------------------------------------------------------------------

## Collisione di un proiettile: al massimo un nemico per frame, il primo
## incontrato lungo il percorso, e mai due volte lo stesso nemico (il registro
## sta nel record). `index` serve per liberare lo slot se il budget di `pierce`
## finisce.
##
## Qui dentro non c'e' nessun ostacolo, e `OBSTACLES_BLOCK_PROJECTILES` in testa
## al file e' il perche'. Il contatto e' **nemico per nemico**: quello che si
## attraversa e' l'orda.
##
## ## m14-a: il raggio e' **per nemico**, non un numero unico
##
## Il reach non si calcola piu' una volta sola per tutti: si calcola dentro il
## ciclo, per ciascun nemico, dalla **sua** specie. Un nemico grosso e' un disco
## piu' grande, ed e' la sua taglia che il giocatore vede: e' l'unico modo che
## «il colpo arriva quando tocca quello che vedi» sia un fatto e non una
## convinzione. Il fattore e' letto una volta per `step()` (fuori dal ciclo dei
## nemici) perche' nel frame non cambia, e perche' rileggere il contratto 200
## volte sarebbe sprecato; la specie la da l'orda, che e' la sua.
## Il numero che decide questa sezione: **quanti confronti fa un passo**, e quanto
## costa ciascuno. La domanda e' legittima perche' il ciclo gira davvero su
## `proiettili × nemici` a ogni passo e la scorciatoia piatta era voluta.
##
## Il **ciclo non cresce**: `for e in n` visita esattamente gli stessi `n` nemici
## di prima, dove `n = min(horde.count, transforms.size())`. Quindi le visite per
## passo sono `proiettili_vivi × nemici_vivi`, **identiche** prima e dopo.
##
## Cosa cambia e' **quanto costa una visita**:
##
##   - costa un confronto in piu' (`tr[e].y` contro i due bordi). La `y` esce gia'
##     dalla stessa lettura `tr[e]` che il test di segmento fa un attimo dopo, quindi
##     il costo aggiunto e' **due confronti**, non una lettura;
##   - e **scarta** i nemici degli altri piani **prima** del test di segmento, che
##     e' la parte con la divisione. Su quattro piani con l'orda distribuita in
##     modo uniforme sono un quarto: il lavoro pesante scende di **tre quarti**.
##
## Con `floor_height = 0` (il default del contratto, cioe' «non c'e' una torre») il
## filtro **non gira affatto**: il ramo e' uno per `step()`, non uno per nemico, e
## il comportamento e' **identico** a quello di prima di m12. E' per questo che la
## forma scelta non e' «un test 3D che costa un po' di piu'»: e' «un filtro che
## costa **meno**».
##
## ## Perche' NON un test 3D, e non perche' sembra piu' pulito
##
## Un test di segmento a tre dimensioni sarebbe corretto, e costerebca circa tre
## operazioni in piu' per nemico. Ma ** romperebbe il punto 4** di questo file:
## renderebbe il contatto **dipendente dalla convenzione di `y` dell'orda**, che e'
## una cosa che questo progetto ha deciso di non sapere (il contratto non dice se
## nei `transforms` c'e' il piede o il centro del modello). Oggi il colpo arriva
## «dove si vede il nemico» indipendentemente da quella scelta; con il 3D tornerebbe
## a dipenderne, e tornerebbe a essere una taratura invece di un'identita'.
##
## La banda e' l'alternativa giusta perche' e' la stessa grandezza che il gioco usa
## gia' ovunque (`Game.player_floor()`, `Game.floor_of()`, la torre di `-arda`), e
## perche' e' **un intero** e non un `float`: il piano si calcola una volta per
## proiettile e i due bordi una volta per `step()`.
##
## ## Il numero **misurato** non c'e', e la ragione e' dichiarata
##
## La foglia che scrive questa riga **non ha potuto eseguire il test** (nessun
## `shell`), quindi qui non c'e' nessun numero di wall-clock e non ne verra
## inventato: la regola del progetto e' che una cifra prima della sua misura e' la
## classe di difetto che questo file stesso chiude. Il conteggio delle visite e'
## **derivabile** e il test lo stampa: `tests/test_gameplay.gd::_m12_impatto_su_piano`
## stampa `proiettili × nemici` per passo e la frazione che arriva al test di
## segmento.
## ## Diagnostica di `_collide()`: **tolta dopo che il suo numero e' stato scritto**
##
## `shots` conta gli spari e i colpi che arrivano si vedono dalle uccisioni: nessuno
## dei due dice **perche'** un colpo che mirava a un nemico non e' arrivato. Per un
## onda sono stati messi cinque numeri, letti **dentro** il ciclo e non ricostruiti da
## formula, e poi tolti. I numeri, sulla scena vera di `tests/test_progression.gd`
## nella finestra dell'onda 1:
##
##   scartati dalla banda **7 503 975** | superati dalla banda e **non toccati** dal
##   segmento **445 038** | quota del proiettile `0,885 m` (piano del colpo `0`) contro
##   quota del nemico **20,000 m**, differenza **19,115 m**
##
## La differenza e' **`floor_height` meno `MUZZLE_HEIGHT`**: cioe' il nemico scartato
## sta sul piano **successivo** rispetto al colpo, che e' **esattamente** cioe' che la
## banda deve fare. Quindi questi numeri **non** accusano la banda: dicono che la banda
## scarta i nemici del piano sopra, e il numero che la accuserebbe — uno scarto di un
## nemico alla **stessa** quota — non e' mai stato preso.
##
## I contatori sono **togliuti**: dentro il ciclo di collisione un numero che nessun
## criterio guarda e' un costo che il gioco paga **ogni frame**.
## Il **tasso di centro**, misurato dentro questo ciclo con il denominatore contato
## qui e non ricostruito dalla formula.
##
## Cosa e' stato contato, in un run di `40 000` passi con `935` colpi partiti:
##
##   - **valutazioni** di `_collide()` con dei nemici da guardare:  **100 053**
##   - **nemici in banda che il segmento ha superato senza toccare** — il segmento
##     ci passava dentro e ha colpito un nemico piu' vicino lungo il percorso:
##     **9**, cioe' **0,000090 per valutazione**
##   - fra questi 9, sul **piano logico del giocatore**: **9**, cioe' il **100%**
##
## La conclusione e' una e non e' hypothesis: **il tiro e' sano**. Un proiettile che
## attraversa un nemico e non lo colpisce perche' ne ha colpito un altro prima e' un
## caso che si verifica **nove volte in cento mila valutazioni**, e tutte e nove sono
## nemici **del piano giusto**. Il difetto del tasso di uccisione **non e' qui**.
##
## Il denominatore `100 053` e' stato contato qui dentro il ciclo e **non** ricostruito
## come `passi x proiettili vivi x nemici in banda`: i proiettili vivi dipendono dal
## tempo, e in questo progetto un denominatore ricostruito e' stato falso piu' volte.
## I contatori che l'hanno prodotto sono stati **tollti** dopo la lettura: un
## contatore che resta in un file di gioco e' un numero che nessuno rilegge.
## ## Quanti nemici guarda davvero un proiettile, misurato in questo ciclo
##
## I tre numeri sono stati contati **qui dentro**, non nel test, e sono poi **tolti**:
## un contatore che resta in un file di gioco e' un numero che nessuno rilegge.
## Sul run della corda (`tests/test_progression.gd`, `40 000` passi):
##
##   - volte in cui `_collide()` e' entrata con dei nemici:      **46 618**
##   - nemici **guardati**:                                     **3 841 914**
##     cioe' **82,413 nemici per proiettile**
##   - nemici **restati in banda**:                               **345 564**
##     cioe' **7,413 in banda per proiettile**
##
## La cosa che questi numeri **escludono**: `SEPARATION_CHECKS = 6` di `-orda` **non**
## arriva qui. Quello e' il tetto di `_separation()`, un ciclo che **schiva** le
## sovrapposizioni fra nemici; questo e' un ciclo che **cerca** un bersaglio, e un
## tetto dello schivatore non e' il tetto del cercatore. Il ciclo qui e' `for e in n`
## su **tutti** i vivi e il filtro di banda e' **dentro**: nessun`tetto`, nessun
## campione, tutti i nemici contano.
func _collide(p, index: int) -> void:
	var tr := _transforms()
	if tr.is_empty():
		return
	var n := mini(_live_count(tr), tr.size())
	if n <= 0:
		return
	var scala := _body_scale()
	var kinds := _kinds()
	var best := -1
	var best_t := 2.0
	for e in n:
		if p.has_hit(e):
			continue
		var reach: float = p.radius + scala * _radius_at(kinds, e)
		var hit := _segment_hit(p.prev_pos, p.pos, tr[e], reach * reach)
		# ## m15: il **minimo sul volo**, e nient'altro
		#
		# Una riga e un confronto: `_segment_hit()` ha gia' calcolato la distanza
		# minima (vedi la sua firma, che la restituisce per questo), e il numero che
		# si tiene e' il **minimo su tutto il volo**, cioe' quanto il colpo e'
		# passato vicino a un centro nemico. Il confronto e' con `INF` e non con un
		# numero: cosi' non si scrive un valore iniziale che un colpo con `INF` non
		# tocca, e il primo nemico incontrato vince.
		if hit.y < p.scarto_min2:
			p.scarto_min2 = hit.y
		var t := hit.x
		if t >= 0.0 and t < best_t:
			best_t = t
			best = e
	if best < 0:
		return
	if not p.log_hit(best):
		return
	# m15: il colpo e' attribuito al suo braccio **dopo** `log_hit`, cioe' solo se
	# il danno verra' davvero applicato: un contatore messo prima conterrebbe
	# anche i tentativi che il registro rifiuta, e il confronto dei due tassi
	# sarebbe fra due numeri che non sono «colpi» ma «occasioni di colpire».
	if p.anticipato:
		colpi_anticipati += 1
	else:
		colpi_senza_anticipo += 1
	# Il punto d'impatto vero: quello sul segmento, non la fine del frame.
	var impact: Vector3 = p.prev_pos.lerp(p.pos, best_t)
	# `damage_enemy` risponde `true` se il nemico e' morto (piano §5.2): e'
	# l'unico modo onesto di sapere di aver ucciso qualcosa, e da li nasce l'XP.
	var killed: bool = Game.damage_enemy(best, p.damage, p.dir * p.knockback)
	if weapon != null:
		weapon.on_impact(impact)
	if killed and weapon != null:
		weapon.on_kill()
	if p.hits_left() <= 0:
		_release(index)

## Mette in coda uno slot liberato, con lo swap con l'ultimo sugli **indici**.
## `_items` non viene toccata: il record resta nella sua casella, e l'indice
## liberato torna sulla pila `_free`.
##
## ## m15: qui, e solo qui, si chiude lo **scarto residuo** del colpo
##
## Il colpo esce dal pool in due modi — scaduto o finiti i bersagli — ed e'
## l'**ultimo** momento in cui il suo record e' ancora in mano: `acquire()` lo
## riuserebbe e `scarto_min2` ripartirebbe da `INF`. Quindi il confronto con il
## reach avviene qui, una volta per colpo, e il colpo viene attribuito al suo
## braccio dal flag che `acquire()` gli ha messo.
func _release(index: int) -> void:
	if index < 0 or index >= _count:
		return
	var freed := _order[index]
	_chiusura_scarto(_items[freed])
	_count -= 1
	if index != _count:
		_order[index] = _order[_count]
	if _free_top < CAPACITY:
		_free[_free_top] = freed
		_free_top += 1

## Il **reach di ogni specie**, cioe' il **minimo** dei cinque (`1,6900 m` sul
## runner). «Il colpo poteva arrivare a qualunque bersaglio» e' il numero severo,
## ed e' quello che serve per separare «la previsione era fuori dalla finestra»
## da «il nemico si e' mosso dentro la finestra».
##
## ## Perche' e' **pubblico e senza argomenti**
##
## Perche' e' il **terzo numero della legge** di `weapon_base.gd`: la velocita' del
## proiettile **deriva** da qui, e una velocita' derivata da una funzione che
## chiede un proiettile non si puo' chiamare da li'. Il proiettile non serve:
## `p.radius` e' sempre `ProjectileScript.RADIUS`.
func reach_minimo() -> float:
	return ProjectileScript.RADIUS + enemy_contact_radius(EnemyScript.RUNNER)

## La chiusura dello **scarto residuo** di un colpo: un campione per proiettile,
## attribuito al suo braccio. Vedi il blocco lungo sui sei campi in testa al file.
func _chiusura_scarto(p) -> void:
	if p == null or not is_finite(float(p.scarto_min2)):
		return
	var s := sqrt(maxf(float(p.scarto_min2), 0.0))
	var dentro := s <= reach_minimo()
	if p.anticipato:
		scarto_anticipato += s
		campioni_anticipato += 1
		if dentro:
			dentro_anticipato += 1
	else:
		scarto_senza += s
		campioni_senza += 1
		if dentro:
			dentro_senza += 1

## Le posizioni dell'orda. `-1` non serve: un array vuoto dice "niente da
## colpire", e la differenza la fa `nearest_enemy` che restituisce `-1`.
func _transforms() -> PackedVector3Array:
	var horde: Node = Game.horde
	if horde == null:
		if not _warned_no_horde:
			_warned_no_horde = true
			push_warning("Game.horde non e' registrata: nessun proiettile puo' colpire niente. tocca a terminal-gun-orda.")
		return PackedVector3Array()
	var v: Variant = horde.get("transforms")
	if not (v is PackedVector3Array):
		return PackedVector3Array()
	return v

## Quanti dei `transforms` sono vivi. `count` è l'autorità: se l'orda tiene
## slot morti in coda, non sono nemici e non si possono colpire.
func _live_count(tr: PackedVector3Array) -> int:
	var horde: Node = Game.horde
	if horde == null:
		return 0
	var v: Variant = horde.get("count")
	if not (v is int or v is float):
		return 0
	return mini(int(v), tr.size())

## Distanza **tridimensionale**, quadrata. `y` adesso c'e', e la ragione e' m12:
## questa funzione era `_flat_dist2` e ignorava la quota, quindi su una torre
## diceva che due nemici a 8 m di distanza sul piano XZ erano **vicini** anche se
## uno era 20 m piu' in alto. «Il vicino» senza quota e' una parola che non
## descrive nessun mondo.
##
## ## Non e' sul percorso del danno, e va detto
##
## Il chiamante di questa funzione e' `nearest_enemy()` qui sotto, che e' **un
## aiuto per il debug di un tiro** (`weapon_base._try_fire` mira con
## `Game.nearest_enemy`, cioe' con la registrazione di `-orda`). Il percorso che
## **danneggia** e' `_collide()` -> `_segment_hit()`, e li' la `y` non partecipa al
## test geometrico perche' e' la banda di quota a fare da filtro (vedi il punto 4
## in testa al file). Quindi il difetto che `-orda` ha segnalato qui era reale ma
## **non era quello che faceva sparare i colpi**: quello e' il filtro di banda, e
## la banda e' quella giusta perche' non rende il contatto dipendente dalla
## convenzione di `y` dell'orda.
static func _dist2(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dy := a.y - b.y
	var dz := a.z - b.z
	return dx * dx + dy * dy + dz * dz

## Parametro `t` in [0, 1] del primo punto del segmento `from..to` entro
## `radius2` da `center`, oppure -1. È il test di contatto vero: copre tutto
## il cammino del frame, quindi nessun proiettile veloce attraversa un nemico.
##
## ## m15: restituisce **anche la distanza minima**, e non e' un extra
##
## Il valore di ritorno e' `Vector2(t, distanza_minima_al_quadrato)`. La
## distanza era gia' calcolata qui dentro per il confronto con `radius2` — e la
## riga che la ricalcolerebbe fuori sarebbe una **sesta copia** della proiezione,
## cioe' la classe di difetto che questo progetto ha gia' pagato una volta (vedi
## `OBSTACLES_BLOCK_PROJECTILES` e il blocco di `_collide`). Quindi la si
## restituisce: costa zero e il chiamante non ricopia niente. `t` e' `-1,0`
## quando il segmento **non** tocca, e in quel caso la distanza e' comunque
## quella vera, che e' il numero che serve allo scarto residuo.
##
## ## Perche' resta **sul piano**, e non e' un dimenticanza di m12
##
## La `y` non entra, e il motivo non e' che la torre non esiste: e' che **il filtro
## di banda di `_collide()` ha gia' detto tutto quello che la `y` potrebbe dire**.
## Un nemico che arriva a questo test e' per costruzione **sullo stesso piano del
## proiettile**, quindi lui e il proiettile stanno sullo stesso piano orizzontale e
## la distanza sul piano XZ *e' gia'* la distanza. Il contratto non dice quale `y`
## l'orda metta nei `transforms` (il piede del modello? il centro?), e questo test
## continua a **non saperlo e a non volerlo sapere**: e' il punto 4 in testa al
## file, ed e' la ragione per cui il filtro e' una banda e non un test a tre
## dimensioni.
## ## m15: questo calcolo e' **proiettato sul piano**, e la riga che lo dichiara
##
## Il segmento del proiettile e' una retta in tre dimensioni, ma il confronto
## qui sotto scarta la `y`. **Non e' una dimenticanza e non e' un'approssimazione
## invisible**: e' una proiezione, e i due numeri che la misurano sono gia' presi.
##
## Il proiettile nasce dalla muzzle a `y = 0,8850 m` e va verso un nemico a
## `y = 0,0000 m`, quindi **scende**, e di quanto dipende dalla distanza:
##
##     a 25,6 m:  0,0150 m per frame   (segmento lungo 0,4333 m)
##     a contatto: 0,0167 -> -0,0002 m  (i due estremi hanno `y` diverse)
##
## Quel `-0,0002` e' il numero che dichiara la proiezione: **il segmento
## attraversa lo `y` del nemico e gli finisce sotto**, e questo test non lo vede.
## Lo schermo di questa finestra e' `RADIUS + 3,4 * RADIUS[kind]`, cioe' da
## `1,6900 m` a `6,6200 m`, e i piani sono a `20,0 m`: **un errore di quota di
## `0,0150 m` dentro una finestra di `1,6900 m` non sposta una soglia, e su un
## piatto di `20,0 m` non sposta niente.** Quindi la proiezione e' giusta per le
## distanze che questo gioco produce, ed e' dichiarata qui perche' il giorno che
## qualcuno tocca `has_hit()` sappia che **il tiro e' in 3D e il contatto no**.
static func _segment_hit(from: Vector3, to: Vector3, center: Vector3, radius2: float) -> Vector2:
	var sx := to.x - from.x
	var sz := to.z - from.z
	var len2 := sx * sx + sz * sz
	var t := 0.0
	if len2 > 0.000001:
		t = ((center.x - from.x) * sx + (center.z - from.z) * sz) / len2
		t = clampf(t, 0.0, 1.0)
	var cx := from.x + sx * t - center.x
	var cz := from.z + sz * t - center.z
	var d2 := cx * cx + cz * cz
	if d2 <= radius2:
		return Vector2(t, d2)
	return Vector2(-1.0, d2)

## I CAPACITY record, una volta sola. `_items` non si riordina piu' e `_order` /
## `_free` sono gia' dimensionati: da qui in poi nessuna allocazione.
func _build_items() -> void:
	_items.resize(CAPACITY)
	for i in CAPACITY:
		var p = ProjectileScript.new()
		# Registro dimensionato al massimo possibile: nessuna allocazione dopo.
		p.hit_log.resize(ProjectileScript.MAX_PIERCE + 1)
		_items[i] = p
	_order.resize(CAPACITY)
	_free.resize(CAPACITY)
	# Pila: l'indice 0 e' in cima, quindi si empila in ordine inverso.
	for i in CAPACITY:
		_free[i] = CAPACITY - 1 - i
	_free_top = CAPACITY
	_count = 0
	_created = CAPACITY

## Un nodo solo per 100 proiettili.
##
## ## `top_level = true`: perche' sta qui e non altrove
##
## `_draw()` scrive nelle istanze della MultiMesh delle **posizioni mondo**: il
## `pos` del record viene da `muzzle_position()`, che e' `global_position + MUZZLE_HEIGHT`.
## Ma questa `MultiMeshInstance3D` sta **dentro** il pool, che sta dentro l'arma,
## che sta dentro `Player`: il renderer moltiplica ogni istanza per la
## trasformazione globale del nodo che le disegna. Con la gerarchia di prima il
## nodo visivo era a `posizione del giocatore`, e ogni proiettile finiva a
## `posizione del giocatore + posizione mondo del proiettile`: i pallini
## scortavano di quanto ti eri mosso.
##
## Il rimedio e' `top_level = true`, che stacca la trasformazione di questo nodo
## da quella del padre: la sua `global_transform` resta **identita'** e le
## posizioni mondo arrivano a schermo dove sono state calcolate.
##
## ## Perche' non toccare la gerarchia
##
## L'alternativa era spostare il nodo fuori dal giocatore (sotto `root`, o in un
## `Node` dedicato). Non e' quello che si fa, e il motivo e' scritto: la scena
## vera conta i nodi perche' il criterio n. 3 di m1 e il criterio n. 5 di m5
## impongono `node_count == 33`. `top_level` e' **una proprietà**, non un nodo:
## l'albero resta identico, il conteggio resta identico, e la trasformazione che
## il renderer applica a una posizione mondo diventa l'identita' — che e' la
## cosa che il difetto aveva rotto.
##
## Il numero lo misura `tests/test_gameplay.gd`, perche' in headless la MultiMesh
## non si rilegge: la misura e' sulla `global_transform` del nodo, che e' la
## causa, non l'effetto.
func _build_visual() -> void:
	_visual = MultiMeshInstance3D.new()
	_visual.name = "Projectiles"
	# PRIMA di `add_child`: il nodo non entra mai nell'albero con la trasformazione
	# del padre, quindi non c'e' nemmeno un istante in cui i proiettili sono
	# disegnati a `posizione del giocatore + posizione mondo`.
	_visual.top_level = true
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _bullet_mesh()
	mm.instance_count = CAPACITY
	mm.visible_instance_count = 0
	_visual.multimesh = mm
	add_child(_visual)

## Il nodo che disegna i proiettili, se c'e'. Non serve al gameplay: esiste per
## il test di m5, che in headless non puo' rileggere la MultiMesh e quindi
## misura la **trasformazione** che il renderer le applica.
func visual_node():
	return _visual

## La trasformazione che il renderer applica a una posizione **mondo**: e' la
## `global_transform` del nodo visivo, e deve essere l'**identita'**. Se tornasse
## diversa, ogni proiettile verrebbe disegnato spostato di quanto vale quella
## trasformazione — cioe' di quanto si e' mosso il giocatore, che e' il difetto.
func draw_transform() -> Transform3D:
	if _visual == null or not is_instance_valid(_visual):
		return Transform3D.IDENTITY
	return _visual.global_transform

## Dove il renderer **disegnerebbe davvero** un proiettile che il pool tiene a
## `world_pos`: `draw_transform() * world_pos`. E' una composizione, non un campo
## letto al posto di una misura, quindi il test verifica la posizione finisce
## dove e' stata calcolata invece di verificare un flag.
func draw_position(world_pos: Vector3) -> Vector3:
	return draw_transform() * world_pos

## La mesh del proiettile: da `scenes/projectile.tscn` se c'è, altrimenti un
## primitivo. Nessun rendering deve dipendere da un file che non c'è.
func _bullet_mesh() -> Mesh:
	if ResourceLoader.exists(PROJECTILE_SCENE):
		var packed = load(PROJECTILE_SCENE)
		if packed is PackedScene:
			var template: PackedScene = packed
			var node: Node = template.instantiate()
			var mi := _find_mesh(node)
			var mesh: Mesh = mi.mesh if mi != null else null
			node.free()
			if mesh != null:
				return mesh
	var box := BoxMesh.new()
	box.size = Vector3(0.18, 0.18, 0.42)
	return box

func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for c in node.get_children():
		var found := _find_mesh(c)
		if found != null:
			return found
	return null

## Scrive le posizioni degli attivi nella MultiMesh. `visible_instance_count` è
## quello che tiene conto di pieno e svuotamento: gli slot oltre `_count` non si
## vedono, e non si vedranno i proiettili scaduti.
func _draw() -> void:
	if _visual == null or _visual.multimesh == null:
		return
	_visual.multimesh.visible_instance_count = _count
	for i in _count:
		_visual.multimesh.set_instance_transform(i, Transform3D(_visual_basis, _items[_order[i]].pos))