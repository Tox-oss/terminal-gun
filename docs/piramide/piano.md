# terminal-gun — piano della piramide

Documento di riferimento per il vertice (`terminal-gun`) e per i cinque specialisti.
È l'unica fonte di verità su scope, contratto e porte. Se qualcosa non è scritto qui, **non lo si inventa**: si chiede al vertice, che decide e aggiorna questo file.

Tutti i path sono **relativi alla root del progetto** (`~/Desktop/Lavori/terminal-gun`).
opencode va avviato da questa cartella: i path relativi funzionano solo da qui.

---

## 1. Cosa stiamo costruendo

Un bullet heaven 3D low-poly, nello stile di Megabonk: un'arena chiusa, un giocatore che si muove con WASD, l'arma che spara **da sola**, ondate di nemici che crescono col tempo, XP e potenziamenti a scelta.

Milestone 1 — **vertical slice giocabile**. Deve valere tutto questo, verificabile:

| # | criterio | come si verifica |
|---|---|---|
| 1 | La porta è verde | `godot --headless --path . --script tools/gate.gd` esce `0` e stampa `GATE: 4/4` |
| 2 | La scena si apre senza errori | `godot --headless --path . --quit-after 300` esce `0`, zero `SCRIPT ERROR` nel log |
| 3 | 200 nemici vivi, senza un nodo per nemico | `node_count < 120` con `horde.count == 200` (test arena) |
| 4 | Il player spara e uccide | `tests/test_arena.gd` sulla scena **vera**: HP scende di **esattamente un colpo** e resta fermo (30 frame, `pierce=3`, proiettile ancora in volo), knockback ≥ 0.3 unità **sulle specie su cui è progettato per funzionare** (§5.4). `tests/test_gameplay.gd` copre danno-una-volta-sola anche con nemici sovrapposti, traiettoria entro 5°, e l'impulso passato **grezzo e non normalizzato** |
| 5 | Si sente il "bonk" | `assets/sfx/bonk.wav` esiste, < 0.6 s, 44100 Hz mono |
| 6 | Niente binari nel Git normale | `git lfs ls-files` elenca `.glb` e `.wav` |

Fuori milestone 1, dichiarato: colonna sonora, menu, salvataggi, boss con fasi, multiplayer, mobile.

### 1.1 Milestone 2 — il gioco è un gioco: progressione, fine onda, morte, restart

Milestone 1 ha dimostrato che il motore gira e che il player uccide. **Non ha dimostrato che sia un gioco**: non c'è una fine, non c'è una morte, e l'XP non è governato da nessun criterio. Milestone 2 chiude il cerchio, scegliendo **una sola cosa**: che la partita abbia inizio, crescita e fine, misurabili dal gate.

Fuori milestone 2, dichiarato come prima: colonna sonora, menu, salvataggi, boss con fasi, multiplayer, mobile.

| # | criterio | come si verifica |
|---|---|---|
| 1 | La porta è verde | `GATE: 7/7` (le 4 di w2 + 3 nuove), exit `0` |
| 2 | L'XP fa salire di livello, e non è finta | `tests/test_progression.gd`: uccidere N nemici fa salire di livello; barra XP in `[0, next]` **sempre**, mai `NaN`/`INF`; l'XP di un ucciso **non** è perso al cambio onda |
| 3 | Un potenziamento **cambia il comportamento misurabile** | `tests/test_upgrades.gd`: applicato un upgrade, il danno o la cadenza cambiano di **almeno il 2%**, misurato sulla scena vera. Un upgrade che non muove nessun numero è un upgrade decorativo e **fallisce** |
| 4 | La partita ha una fine | `tests/test_gameloop.gd`: uccisi i nemici dell'onda corrente e la barra wave è a 0 → onda successiva con contatore++; player a 0 HP → stato `game_over`; **restart** → torni a `wave 1`, `horde.count` azzerato e ripopolato, **nessun nodo duplicato** |
| 5 | Il criterio n. 4 di m1 non regredisce | knockback runner **≥ 0.3** resta verde dopo che m2 ha toccato XP e HUD: m2 non può alzare `KNOCKBACK` per stare comodo |
| 6 | La porta non ha timeout | **debito di m1 chiuso**: `gate.gd` prende un timeout per test e un test che si blocca diventa FAIL, non un gate congelato |

## 1.3 Milestone 3 — la disposizione dell'orda sulla scena vera è riproducibile

Milestone 2 ha chiuso il cerchio della partita. m3 non aggiunge funzionalità: **chiude
l'ultimo debito di misura**, quello che m2-w3 ha rimandato per iscritto e che nessuno ha
misurato da allora.

Il debito, con le parole di `spatial_grid.gd` (righe 32-39): la densità che fa traboccare
un secchiello è **misurata sull'orda isolata** (`BUCKET_SLOTS` 12 → 32 sul picco di 19), ma
l'orda della **scena vera** gira con `seed = 0` e **nessuna asserzione guarda la sua
`grid_overflowed()`**. Quindi il traboccamento vero può accadere e nessuno lo saprebbe: non
è un test che fallisce a caso, è un test che **non esiste**.

La causa non è la casualità, è un **buco di API**, e l'ho verificato leggendo il codice:

| fatto | dove |
|---|---|
| `seed` è un campo **pubblico**, documentato «0 = casuale, un numero = riproducibile» | `src/sim/horde.gd:91-92` |
| ma `_build()` lo legge **una volta sola**, dentro `_ready()` | `src/sim/horde.gd:188-191` |
| e sulla scena vera l'orda la crea `arena_main.tscn`, quindi nessun codice esterno scrive `seed` prima di `_build()` | `tests/test_arena.gd:154` |
| `restart_run()` ripopola ma **non cambia il seme**: usa il `_rng` già in stato | `src/sim/horde.gd:467-476` |

Il campo sembra la riproducibilità e sulla scena vera **è irraggiungibile**: `seed = 0`
sempre, `randomize()` sempre. m3 non è «misurare meglio»: è **chiudere il buco**.

Fuori m3, dichiarato come prima: colonna sonora, menu, salvataggi, boss con fasi,
multiplayer, mobile.

| # | criterio | come si verifica |
|---|---|---|
| 1 | La porta è verde | `GATE: 8/8` (il gate conta i file su disco, §6: m3 non aggiunge test) e `PERM: 15/15` rieseguite dal vertice |
| 2 | La disposizione sulla scena vera è una **funzione del seme** | `tests/test_arena.gd`: stesso seme due volte → `transforms` **identici**; seme diverso → **diversi**. Entrambe le asserzioni, perché una sola è a denti nulli |
| 3 | La griglia ha una **testata dichiarata e misurata** | sweep di N semi sulla scena vera: `min`/`mediana`/`max` di `worst_bucket()` stampati, e il tetto è una costante nel file **con il commento che dice come è stata derivata**. Nessun numero scritto qui prima della misura: è la lezione di §1.2 |
| 4 | L'asserzione ha i **denti**, provati e rimossi | forzare il traboccamento sulla scena vera → l'asserzione deve dire `FAIL`; poi rimosso. Protocollo di m2-w3, stessa regola |

### 3.5 Scope della milestone 3: due foglie, un oggetto condiviso

m3 è la prima onda che mette **due foglie sullo stesso oggetto di simulazione**. Le scope
restano disgiunte e sono già nelle allowlist: **nessuna riga di permesso nuova**, che è la
ragione per cui questa onda non ha bisogno di un atto dell'utente.

| agente | modello | in m3 scrive | note |
|---|---|---|---|
| `terminal-gun-orda` | `space-bunny-free#max` | `src/sim/horde.gd` | **solo** `reseed(s)` e la correzione della riga di documentazione di `worst_bucket()`. Se serve `src/sim/spatial_grid.gd`, non lo tocca: lo dice nel report e si ferma lì |
| `terminal-gun-arena` | `space-bunny-free#max` | `tests/test_arena.gd` | la sezione nuova, sullo sweep. Nessun altro file |
| `terminal-gun` (vertice) | `space-bunny-free#max` | `docs/piramide/piano.md`, `src/core/contracts.gd` | la superficie congelata di m3 |

**L'interfaccia è congelata in `src/core/contracts.gd`, sezione «Supersficie di milestone 3»**:
`horde.reseed(s)` con cinque punti di semantica scritti. -orda la scrive, -arena la chiama,
e nessuno dei due può cambiarne il nome durante l'onda senza fermarsi.

**Perché il vertice scrive il contratto e non le foglie.** Il piano registra già il caso: due
foglie che hanno concordato un nome perché una lo aveva scritto e l'altra lo aveva letto nel
codice dell'altra (`wave`, letto per nome dall'HUD). Funziona, ma funziona **per fortuna**. Qui
sarebbe peggio: `reseed` non è un nome che si inventa due volte uguale.

### 4.2 Onde della milestone 3

| onda | chi | parallelismo | finisce quando |
|---|---|---|---|
| **m3-w0** | vertice | — | superficie congelata in `contracts.gd`, specifica scritta, `PERM: 15/15` confermata **prima** di lanciare (nessuna riga di permesso nuova) |
| **m3-w1** | orda ∥ arena | 2 agenti, una stessa risposta | `GATE: 8/8` exit 0 e `--quit-after 300` pulito, rieseguiti **dal vertice** |
| **m3-w2** | vertice | — | commit, piano aggiornato, verdetto |

**m3-w1 ha un parallelismo vero con una dipendenza dichiarata.** I file sono disgiunti
(`src/sim/horde.gd` / `tests/test_arena.gd`), ma il test chiama un metodo che il codice non ha
ancora: è il caso che il gate diventa rosso **per il motivo giusto**. Non è una race da evitare,
è un ordine di consegna, ed è il motivo per cui il nome è congelato prima e non durante.

### 4.3 Un difetto di -orda che m3 deve chiudere: `worst_bucket()` non è quello che dice

`src/sim/horde.gd:601` documenta «Il nemico più occupato in una cella, **in un frame**», e il
codice non lo fa: `begin_frame()` azzera `overflowed` e **non** `worst_bucket`, che si azzera
soltanto in `setup()` (`spatial_grid.gd:76`). Quindi è un **massimo storico** della sessione.

La conseguenza è una trappola per chiunque asserisca: `worst_bucket()` dopo un reseed non
descrive la disposizione appena scritta, descrive **tutto il massimo da `setup()` in poi**. Un
test che lo legge come per-frame misura la storia e chiama "misura del frame" quello che è un
massimo. -orda deve **scegliere** e **dichiarare** quale delle due cose è: correggere il
commento e lasciare il massimo storico, oppure azzerare in `begin_frame()` e cambiare il
significato. Sono due semantiche diverse e il vertice non le sceglie al posto suo: **la scelta
è di -orda, il commento che la dichiara è obbligatorio**, e il criterio n. 3 di m3 vale con
qualsiasi delle due purché il test sappia quale sta usando.

## 2. Toolchain

Installata in **w0** dal vertice. **Nessun agente deve installare nulla**, e nessuno deve cercare i binari per conto proprio: legge `tools/env.sh`.

| strumento | id winget | ruolo |
|---|---|---|
| Godot 4.7 | `GodotEngine.GodotEngine` | motore, import, gate headless |
| Blender 5.2 | `BlenderFoundation.Blender` | generazione modelli low-poly in headless |
| Python 3.14 | già presente | generazione SFX, script Blender |
| ffmpeg 9 | già presente | normalizzazione audio, `ffprobe` per le verifiche |
| git 2.55 + git-lfs 3.7 | già presente | versionamento, `winget` per il resto |

Uso convenuto in ogni comando:
```sh
. tools/env.sh && "$GODOT" --headless --path . --script tools/gate.gd
. tools/env.sh && python tools/gen_sfx.py --out assets/sfx
```

Path reali rilevati in w0:

| variabile | valore | come è stato trovato |
|---|---|---|
| `GODOT` | `godot` | già su `PATH` via alias WinGet (`WinGet\Links\godot`). Verificato: `godot --headless --version` → `4.7.2.stable.official.ed1daf0bf` |
| `BLENDER` | `C:/Program Files/Blender Foundation/Blender 5.2/blender.exe` | **non** su `PATH`: winget lo installa sotto `Program Files` senza alias. Trovato con `find "/c/Program Files/Blender Foundation" -iname blender.exe` |

Installati in w0, in sequenza (lock globale di winget): Godot `4.7.2`, Blender `5.2.2`.
Entrambe le installazioni winget sono avvenute **senza privilegi admin**; l'alias `godot`
è stato creato lo stesso e risponde. `blender` non ha alias: da qui il path assoluto.

Nota sui permessi del vertice: il comando convenuto `. tools/env.sh && "$GODOT" ...`
non è eseguibile dal vertice, che ha una deny su `shell *` e un allow solo su
`godot *`, `git *`, `winget install *`. Il vertice esegue quindi le porte come
`godot --headless ...`, che è equivalente perché `GODOT="godot"` è già su `PATH`.
Le foglie mantengono la convenzione con `. tools/env.sh &&`.

## 3. Agenti e scope esclusivi

Un file, un proprietario. **Due agenti che toccano lo stesso file sono un bug di questo piano.**

| agente | modello | scrive | non tocca mai |
|---|---|---|---|
| `terminal-gun-scheletro` | `space-bunny-free#max` | `project.godot`, `src/core/`, `tools/gate.gd`, `tools/test_harness.gd`, `tests/test_smoke.gd`, `.gitignore`, `scenes/arena_main.tscn` (solo segnaposto) | `src/sim`, `src/player`, `src/weapons`, `src/render`, `src/ui`, `assets` |
| `terminal-gun-orda` | `space-bunny-free#max` | `src/sim/`, `tests/test_orda.gd` | tutto il resto del codice, `project.godot`, `.godot/` |
| `terminal-gun-gameplay` | `space-bunny-free#max` | `src/player/`, `src/weapons/`, `scenes/player.tscn`, `scenes/projectile.tscn`, `tests/test_gameplay.gd` | `src/sim`, `src/render`, `src/ui`, `scenes/arena_main.tscn`, `.godot/` |
| `terminal-gun-arena` | `space-bunny-free#max` | `scenes/arena_main.tscn`, `scenes/hud.tscn`, `src/render/`, `src/ui/`, `tests/test_arena.gd` | `src/sim`, `src/player`, `src/weapons`, `project.godot`, `.godot/` |

### 3.3 Scope della milestone 2: una foglia nuova, tre scope che si riaprono

In m1 la regola "un file, un proprietario" ha funzionato. In m2 tre file devono **cambiare proprietario o allargarsi**, e va detto prima, non dopo.

| agente | modello | in m2 scrive | note |
|---|---|---|---|
| `terminal-gun-orda` | `space-bunny-free#max` | `src/sim/` (scala delle onde, `SPEED_MAX` se l'esperimento lo richiede), `tests/test_gameloop.gd` | `test_gameloop.gd` è suo perché wave e game over stanno nella simulazione, non nell'UI |
| `terminal-gun-gameplay` | `space-bunny-free#max` | `src/player/` (XP, potenziamenti, stato `game_over`, restart), `src/weapons/`, `tests/test_progression.gd`, `tests/test_upgrades.gd` | è il suo lavoro: crescita del player è scope di gameplay, non di ui |
| `terminal-gun-ui` (nuovo) | `space-bunny-free#max` | `scenes/hud.tscn`, `src/ui/`, `tests/test_ui.gd` | **foglia nuova in m2**: barra XP, contatore wave, schermata game over. `scenes/hud.tscn` e `src/ui/` sono anche nel scope di -arena: è il **passaggio di proprietà** di m2, non un conflitto (§4.1) |
| `terminal-gun` (vertice) | `space-bunny-free#max` | `docs/piramide/piano.md`, `src/core/contracts.gd`, `tools/gate.gd` (timeout), `tools/env.sh`, `tools/check_perms.py` | il timeout del gate è suo: tocca il gate, che è di scheletro, e scheletro **non lavora in m2**. Anche la porta dei permessi è sua: verifica le allowlist, che nessun altro può scrivere |

`terminal-gun-scheletro` e `terminal-gun-assets` **non lavorano in m2**. Il gate ha il timeout e `contracts.gd` è del vertice: è la riapertura più economica perché scheletro non ha altri file da difendere in questa ondata.
| `terminal-gun-assets` | `muse-spark-1.3-contributor-free#high` | `tools/gen_sfx.py`, `tools/blender/gen_models.py`, `tools/convert_assets.sh`, `assets/` | `src/`, `scenes/`, `project.godot`, `tools/env.sh`, non esegue mai `godot` |
| `terminal-gun` (vertice) | `space-bunny-free#max` | `docs/piramide/piano.md`, `src/core/contracts.gd`, `tools/env.sh`, `tools/check_perms.py`, **`.gitattributes`** | il codice del gioco |

Sovrascrittura **autorizzata e unica**: `scenes/arena_main.tscn`, segnaposto di scheletro (w1) → scena reale di arena (w2). È dichiarata qui perché ogni altro file è creato una volta sola.

### 3.1 `.gitattributes` era senza proprietario: dichiarato al vertice

Il vertice lo crea in w0 (con `git lfs track`), ma nella tabella sopra non compariva: **nessuna delle cinque foglie poteva scriverlo e il vertice non aveva l'`edit` allow**. Un file senza proprietario dichiarato è un file che nessuno toccerà mai e nessuno guarderà mai: è stato il buco dietro il caso `*.pck` / `*.exe` di §3.2.

Ora è **di proprietà del vertice**. Manca però ancora la regola: in `.gitattributes` ci sono solo `*.glb`, `*.wav`, `*.ogg` in LFS.

### 3.2 Due righe fuori, finché il vertice non ha il permesso

`.gitignore` esclude `*.pck`, `*.exe`, `build/`, `export/`, quindi quei file **non entrano nel repo**: il criterio n. 6 è soddisfatto per costanza, non per merito. Se qualcuno li forza dentro, git tenta un diff **testuale** su contenuto binario.

Servono in `.gitattributes`:

```
*.pck binary
*.exe binary
```

Non LFS: sono artefatti di rilascio e non vale la pena spenderne il quota. `binary` serve a una cosa sola, ed è quella giusta: impedisce a git di tentare diff e merge testuali.

### 3.4 L'eseguibile sul desktop: l'utente lo può provare

Richiesto dall'utente il 2026-10-06: un modo per **giocare** senza aprire l'editor. Non è dentro i criteri di m2, perché non è un criterio di prodotto: è un modo per guardare.

Un `.exe` non si può produrre da qui in modo onesto: **`export_presets.cfg` non esiste** e i template di esportazione di Godot 4.7 non sono installati su questa macchina. Scaricarli è una decisione dell'utente, non mia: sono ~1 GB e si installano dalla GUI di Godot.

Quindi il percorso che resta, in ordine di onestà:

1. **`godot --path .`** — apre l'editor con il progetto già caricato, si preme F5. Un comando, zero installazioni, ed è il modo **vero** di provarlo adesso.
2. **`godot --path . scenes/arena_main.tscn`** — parte **senza editor**, gioco diretto. È il più vicino a "un eseguibile" che esiste oggi su questa macchina.
3. **Export a `.exe`** — quando l'utente decide di scaricare i template. Va fuori `.gitignore` (ci è già, §3.2) e va costruito con `terminal-gun-scheletro` in un'onda dedicata, perché tocca `project.godot` e `export_presets.cfg`: nessuno dei due è scope di m2.

Il comando del punto 2 è quello da usare, ed è **un comando solo**. Non prometto un `.exe` finché i template non ci sono: prometterlo sarebbe far annunciare a un agente un artefatto che non può produrre.

**Il vertice non può scriverle**: il suo `edit` copre `docs/piramide/**`, `src/core/contracts.gd`, `tools/env.sh`. L'`edit` su `.gitattributes` va aggiunto a `~/.config/opencode/agents/terminal-gun.md` e richiede un riavvio di opencode. Finché non è fatto, **queste due righe le deve scrivere a mano l'utente**: sono l'unico punto della piramide dove il vertice è più debole di una foglia.

**Riconfermato dal vertice il 2026-10-06**: `write` su `.gitattributes` risponde `Permission denied: edit`. Il file è quindi **in mano all'utente**, non al vertice. Le due righe ci sono (scritte a mano) ma erano **fuori da ogni commit**: il vertice le ha committate il 2026-10-06, il che è l'unico atto che gli resta su questo file. Manca solo il newline finale in fondo, che è cosmetico e non blocca nulla.

## 4. Onde

| onda | chi | parallelismo | finisce quando |
|---|---|---|---|
| **w0** | vertice, solo shell | — | Godot e Blender installati, `tools/env.sh` scritto, `git init` + LFS configurati |
| **w1** | scheletro ∥ assets | 2 agenti, una stessa risposta | `godot --headless --path . --import` esce 0 e il gate dice `GATE: 1/1` |
| **w2** | orda ∥ gameplay ∥ arena | 3 agenti, una stessa risposta | gate dice `GATE: 4/4` e `--quit-after 300` è pulito |
| **w3** | vertice | — | commit fatto e verdetto riportato all'utente |

### 4.1 Onde della milestone 2

Stessa struttura, con un cambio: **w2 ha tre foglie e un solo file di test per foglia**, quindi in m2 i file di test si contendono. Sono assegnati esplicitamente per evitare race su `tests/`.

| onda | chi | parallelismo | finisce quando |
|---|---|---|---|
| **m2-w0** | vertice, solo shell | — | l'esperimento `KNOCKBACK` vs `SPEED_MAX` è **misurato e scritto** (§1.2), `terminal-gun-arena` è invocabile **come tale** col suo modello |
| **m2-w1** | orda ∥ gameplay ∥ ui | 3 agenti, una stessa risposta | `GATE: 7/7`, e `--quit-after 300` pulito |
| **m2-w2** | vertice | — | commit, piano aggiornato, verdetto |

Perché `ui` è una foglia separata e non parte di `arena`: in m1 l'UI era dentro `src/ui/` di arena, e arena ha già finito il suo scope. Aggiungere HUD a un agente **che ha chiuso** il proprio file obbliga a riaprirlo e rompe la regola 1. In m2 l'UI ha bisogno della barra XP e del contatore wave: è lavoro suo, non accessorio di arena.

### 1.2 L'esperimento `KNOCKBACK` vs `SPEED_MAX`: FATTO, e l'ipotesi era sbagliata

**MISURATO dal vertice in m2-w0 il 2026-10-06. Debito chiuso.**

Strumento: `docs/piramide/probe_knockback.gd`, che riusa la procedura di
`tests/test_arena.gd` sez. 7 sulla **scena vera** e varia `weapon.knockback`, che
e' un **campo d'istanza** (inizializzato dalla `const`): nessun file di -gameplay
e' stato toccato per fare l'esperimento.

```sh
. tools/env.sh && godot --headless --path . --script res://docs/piramide/probe_knockback.gd
```

| `KNOCKBACK` | runner | grunt | \|v\| all'impatto | saturato? |
|---|---|---|---|---|
| 9.0 | 0.119 | 0.011 | 1.18 / 2.23 | no |
| **18.0** (codice) | **0.312** | **0.356** | 8.97 / 8.45 | **no** |
| 36.0 | 0.812 | 0.885 | **18.00** / **18.00** | **si** |
| 72.0 | **0.812** | **0.885** | **18.00** / **18.00** | **si** |

**Risposta: no, al valore di codice i due numeri NON sono bloccati insieme.**
Il quarto punto (72.0, non richiesto dal piano) rende la risposta definitiva:
`36 -> 72` da' numeri **identici al quarto decimale**, un pianoro vero.

**Perche' l'ipotesi era sbagliata.** L'impulso e' **sommato alla velocita' di
inseguimento**, che e' nel verso opposto: la velocita' netta dopo il colpo e'
`KNOCKBACK x (1 - resistenza) - chase_speed`, e il tetto di -orda si applica a
**quella** somma:

| specie | soglia di saturazione | `KNOCKBACK` a 18.0 |
|---|---|---|
| runner (chase 6.6) | `> 24.6` m/s | 11.4 netti: **sotto** il tetto |
| grunt (chase 4.0, res 0.20) | `> 27.5` m/s | 10.4 netti: **sotto** il tetto |

Il valore di codice **18.0 sta a 11.4 m/s netti sotto un tetto di 18.0**: nessuna
saturazione, margine ~37%. Il tetto morde solo sopra ~24.6, che oggi nessuno usa.

**Il numero di grunt a 9.0 (0.011) e' fisica, non rumore.** La traccia di `|v|` e'
`2.23 -> 1.40 -> 0.68 -> 0.05 -> 0.49 -> 0.96`: la spinta netta (3.2 m/s) e' quasi
annullata dall'inseguimento entro 5 frame e la posizione residua e' la differenza
di due spostamenti quasi uguali. Il vertice ha ipotizzato un artefatto di
`EDGE_PUSH` e **si e' sbagliato**: la guardia anti-muro aggiunta al probe non ha
cambiato il numero. E' la cancellazione, non il muro.

**Determinismo.** Sul pianoro i valori sono **identici bit per bit** fra due
esecuzioni (0.8120 / 0.8847). Sotto il pianoro oscillano di ~0.5% (runner a 18.0:
0.3107, 0.3116, 0.3122) per la sola distanza di nascita casuale: dentro il
margine del criterio n. 4 (0.011 su 0.3, cioe' 3.7%) con un ordine di grandezza
di scarto.

**Conseguenze, e sono decisioni di vertice:**

1. **Nessuna correzione a -orda.** La pendenza non e' piatta al valore in gioco,
   quindi il punto 4 del protocollo non si attiva: `SPEED_MAX` non va
   ricalcolato e il tetto 0.3 resta sulla posizione. **Debito di m1 chiuso.**
2. **`KNOCKBACK` non va alzato in m2.** Il margine lo permetterebbe (fino a
   ~24.6), ma l'unico motivo sarebbe stare comodo, e il criterio n. 5 di m2 lo
   vieta esplicitamente.
3. **Il limite vero, se qualcuno lo volesse, e' ~24.6 m/s sul runner**: oltre,
   il tetto di -orda morde e il colpo non diventa piu' forte. Scritto qui perche'
   nessuno lo scopra con un esperimento.

### 1.2b Il protocollo, per reference (era qui, ora e' fatto)

Il testo originale, che il piano dichiarava non verificato e mai eseguito:

1. Misura `KNOCKBACK` a **tre** valori (l'attuale, il doppio, la meta'), non a uno: un solo punto non distingue "saturato" da "cresce".
2. Usa la procedura gia' esatta di `tests/test_arena.gd` — 5 passi a passo fisso, **delta di posizione**, mai velocita' letta prima dell'assetamento.
3. Riporta i tre numeri e **dimostra la pendenza**. Se raddoppiare `KNOCKBACK` non muove il numero, la saturazione e' confermata e il tetto 0.3 va ricalcolato su `SPEED_MAX`, non su `KNOCKBACK`.
4. Se la pendenza e' piatta, la correzione e' di **-orda** (`SPEED_MAX` o l'ordinamento impulso/chase nell'integrazione), non di -gameplay: il tetto di m2-criterio n. 4 e' sulla posizione, e la posizione la possiede l'orda.

Il protocolso ha tenuto: i quattro punti sono esatti e li ho seguiti. Il quarto
punto **non si e' attivato**, perche' la pendenza non e' piatta al valore in gioco.

w1 e w2 hanno parallelismo **vero**: scope disgiunti e nessuna dipendenza di file. w2 ha una sola dipendenza (lo scheletro di w1): se `src/core/contracts.gd` non esiste, w2 non parte.

## 5. Contratto di interfacce

Vive in `src/core/contracts.gd` (autoload `Game`). **Il contratto dichiara, le implementazioni si registrano**: ogni foglia si registra una volta sola nel proprio `_ready()` e non chiama mai il costruttore di un'altra foglia. Ma **dati e metodi si registrano in due modi diversi**: vedi §5.1, non è una questione di stile.

```gdscript
var player: Node3D
var horde: Node            # src/sim/horde.gd
var arena_radius: float = 28.0
func nearest_enemy(from: Vector3, radius: float) -> int    # indice, -1 se nessuno
func damage_enemy(index: int, amount: float, knockback: Vector3) -> bool   # true = ucciso
func spawn_projectile(pos: Vector3, dir: Vector3, speed: float) -> bool     # true = slot preso
func random_spawn_point() -> Vector3
func player_position() -> Vector3
```

### 5.1 Come ci si registra davvero

Emendato dal vertice in w1, dopo che `terminal-gun-scheletro` ha trovato che la formulazione precedente **non funziona**. `Game.nearest_enemy = self._nearest_enemy` è **rifiutato da GDScript** (`Invalid assignment of property or key ... with value of type 'Callable'`), e l'errore **interrompe il `_ready()`**: la foglia crede di aver registrato e non ha registrato niente. Se w2 fosse partito con il testo precedente, tutte e tre le foglie avrebbero prodotto codice morto e nessun errore lo avrebbe detto.

**Dati**, nel proprio `_ready()`, assegnazione diretta:
```gdscript
Game.player = self
Game.horde = self
Game.arena_radius = 28.0
```

**⚠ `_ready()` è troppo tardi se qualcuno legge il dato durante il proprio avvio.** Godot chiama il `_ready()` dei **figli prima** di quello del padre. Se un nodo che ha figli registra un dato che i suoi figli leggono nel loro `_ready()`, i figli leggono il **valore di default**: non è intermittente, è ordine di esecuzione, ed è **sempre** rotto.

Verificato in w2 da `terminal-gun-arena`: `arena_radius` registrato in `_ready()` produceva muri da 152 m invece di 352 e pavimento da 32 m invece di 64. Il test l'ha scoperto solo perché il muro era **misurabile**: un errore di grandezza che nessuna asserzione guardava sarebbe passato.

**Regola**: chi ha figli che leggono il dato registra in **`_enter_tree()`**, che gira prima di qualunque `_ready()`. Chi è foglia e non ha figli tiene `_ready()`. La registrazione in `_enter_tree()` deve essere **idempotente**, perché può essere chiamata più volte.

**Metodi**, nel proprio `_ready()`, una volta sola:
```gdscript
Game.register_impl("nearest_enemy", self._nearest_enemy)   # forma lunga
Game.register_impl("player_position", self)                # forma corta
```

- **forma lunga**: esplicita, vale per ogni nome di metodo.
- **forma corta**: risolve a `self.player_position()`, cioè il metodo **omonimo** all'API.
- **La forma corta non è compatibile con il prefisso `_`.** `register_impl("player_position", self)` su una foglia che espone `_player_position` va in `push_error` e **non registra**. O forma lunga con `self._player_position`, o forma corta con metodo senza underscore: **le due convenzioni non si mescolano.**
- **Chiamate**: come funzioni, `Game.nearest_enemy(pos, 12.0)`. **Mai** `Game.nearest_enemy.call(...)`.

Già nel contratto, se serve: `Game.has_impl("nearest_enemy") -> bool` per verificare prima di chiamare; un nome fuori contratto passato a `register_impl` viene **rifiutato** con `push_error` invece di registrarsi in silenzio.

Proprietari, come nei commenti di `contracts.gd`: `nearest_enemy`, `damage_enemy`, `random_spawn_point` → **-orda**; `spawn_projectile`, `player_position` → **-gameplay** (`player_position` può essere anche di -orda, ma **uno solo** dei due la registra).

Stringhe a schermo: **ASCII only** nei `print`/`push_warning`/`push_error`. La console Windows e le pipe di `OS.execute` stanno in codepage e mangiano gli accenti. I commenti invece possono accentedersi: non passano dalla pipe.

### 5.2 Le firme originali erano sbagliate: emendate in w2

`terminal-gun-orda` e `terminal-gun-gameplay` hanno trovato che tre firme del §5 originale **non potevano funzionare**. Non è stile, è incoerenza con la regola 1.

| firma originale | problema verificato | ora |
|---|---|---|
| `nearest_enemy(...) -> Node3D` | Il nemico **non è un nodo** (regola 1), quindi non c'è un `Node3D` da restituire. `int as Node3D` dà `SCRIPT ERROR: Invalid cast` | `-> int`, `-1` se nessuno |
| `spawn_projectile(...) -> Node3D` | Idem: i proiettili sono record in un pool, non nodi | `-> bool`, `true` se ha preso uno slot |
| `damage_enemy(...) -> void` | Non diceva **cosa fosse** `knockback`: due foglie lo avevano interpretato in due modi diversi | `-> bool`, semantica definita sotto |

- **`knockback` è un impulso in m/s**, già scalato dal chiamante e **non** normalizzato nel callee, sommato alla velocità del nemico. Il suo modulo **non** è la misura in unità del criterio n. 4: per verificare "knockback ≥ 0.3 unità" si simula un passo di tempo fisso e si misura la **delta di posizione**.
- **`damage_enemy` restituisce `bool`** (nemico morto). Era la richiesta di -gameplay per l'XP: senza questo l'XP si aggancia al calo di `horde.count` e non sa **chi** è morto. Un segnale `enemy_died` apposito è rimandato, non dimenticato.

L'indice di `nearest_enemy` è lo stesso che `damage_enemy` si aspetta: si spara a un nemico senza trasformare la referenza in un nodo.

### 5.3 L'identificatore `Game`: cosa è provato e cosa no

**Provato:** l'identificatore nudo `Game` **risolve** sotto `--script`. `src/sim/horde.gd` scrive `Game.horde = self` e `Game.register_impl(...)` in testa al file, e i suoi errori di parse sono su un altro identificatore: se `Game` non risolvesse, l'errore sarebbe su `Game`. `tests/test_smoke.gd` passa inoltre controllando che l'autoload sia **istanziato**.

**Non provato, e da non dare per scontato:** `terminal-gun-gameplay` ha riferito un errore di compilazione su `Game` in tre suoi file e ha adottato la via del nodo (`root.get_node_or_null("Game")`). Non ho isolato **in quale contesto** fallisce, e la mia prima versione di questa sezione lo dichiarava incompatibile ovunque: **era sbagliato**, l'ho scritto su una sola testimonianza mentre il codice di -orda lo contraddiceva. Non farlo propagare.

**Regola:** `Game.<campo>` e `Game.register_impl(...)` sono la forma normale e vanno usate per default. Se un file specifico non compila con `Identifier "Game" not declared`, il problema è in **quel** file — i sospetti sono i contesti dove un autoload non è visibile: `static func`, un `const`, un'annotazione di tipo (`var g: Game`) o un `class_name`. In quel file solo, usa `root.get_node_or_null("Game")` e annota il perché. Non estendere il workaround agli altri file senza evidenza.

### 5.4 Il knockback non è uniforme: le specie che lo subiscono e quelle che lo resistono

Emendamento del vertice in w2, dopo che `terminal-gun-gameplay` ha tarato `KNOCKBACK` sul **proprio finto** (misurava 0.2985, sotto soglia, e l'ha alzata a 18) e `terminal-gun-arena` ha misurato il criterio n. 4 sulla **scena vera**, dove i numeri erano diversi.

`src/sim/enemy.gd` ha una **resistenza per specie** che scala l'impulso di knockback (`static var`, non un campo modificabile a runtime): **0 / 0.20 / 0.55 / 0.90** per runner, grunt, brute, boss. Con `KNOCKBACK` = 18 m/s lo spostamento misurato in 5 frame a DT=1/60 è:

| specie | impulso ricevuto | spostamento | tetto 0.3 |
|---|---|---|---|
| runner | 18.0 m/s | 0.311 | sì, ma **+3.7%** |
| grunt | 14.4 m/s | 0.356 | sì |
| brute | 8.1 m/s | 0.196 | **no** |
| boss | 1.8 m/s | 0.055 | **no** |

Due conclusioni, e sono una decisione di progetto, non un aggiustamento:

1. **Il knockback è asseverato sulle specie su cui è progettato per funzionare**, cioè runner e grunt, che sono **l'80% dell'onda** con i pesi veri di `Spawner.KIND_WEIGHTS`. Brute e boss **resistono al knockback per progetto**: un nemico pesante che non scivola quando lo colpisci è giusto in un bullet heaven, e il boss con resistenza 0.90 è di fatto **non knockbackabile** — portarlo a 0.3 richiederebbe `KNOCKBACK` ≈ 170 e un'integrazione che regge. Non è un difetto, è una proprietà, e da ora è scritta qui perché nessuno la riscopra come un bug.
2. **Il +3.7% sul runner è sottile ma non è fragile**, e la distinzione conta: la misura è su **passo di tempo fisso** (5 frame a DT=1/60), quindi è **deterministica** e non dipende dal framerate né dalla macchina. Non è la stessa cosa del benchmark di `tests/test_orda.gd`, che misura microsecondi di wall-clock e quelli oscillano davvero: quello sì era a rischio di fallire a caso.

   Resta però un problema reale, diverso: **il margine è sottile e accoppiato alla regolazione di -orda**. Il tetto n. 4 è a 0.011 dal valore misurato, quindi chiunque tocchi `chase_speed`, `ACCEL`, `SPEED_MAX` o la tabella di resistenza spegne il criterio senza accorgersene. Il numero di `KNOCKBACK` è di -gameplay ma c'è un **accoppiamento non dichiarato**: `-orda` ha `SPEED_MAX = 18.0`. **Misurato in m2-w0 (§1.2): l'accoppiamento esiste ma NON morde al valore di codice**, perché l'impulso si somma alla velocità di inseguimento e il tetto si applica alla somma: al netto il runner è a 11.4 m/s sotto un tetto di 18.0. La soglia vera è **~24.6 m/s** sul runner, non 18.

Nota tecnica per chi rimisura: l'orda **non** usa un `drag`, usa smorzamento di primo ordine `v += (wanted - v) * min(1, dt*ACCEL)` con `ACCEL = 8.0` 1/s (τ = 0.125 s), più `SPEED_MAX = 18.0` e `ARRIVE_RADIUS = 3.0`. Due errori di misura che arena ha già commesso e documentato: leggere la velocità **prima** dell'assestamento (dà zero), e infilare la finestra di "nessun secondo colpo" **prima** della misura (a τ = 0.125 s l'impulso è già sparito e si misura l'inseguimento: 0.5382 ≈ 6.6 m/s × 5/60).

Il lato "massa" dell'orda non passa da funzioni ma da tre campi pubblici, perché disegnarli non è una query:

```gdscript
var count: int                       # nemici vivi
var transforms: PackedVector3Array   # uno per nemico
var colors: PackedColorArray         # tinta per tipo
```

Tre regole che tengono insieme i pezzi:
1. **Nessun nodo per nemico.** I nemici sono record in array; arena li disegna con una `MultiMeshInstance3D` leggendo `count` e `transforms`.
2. **Niente `instantiate()`, `new()`, `queue_free()` nel ciclo di gioco.** Capacità fissa assegnata una volta sola all'avvio (200 nemici, 100 proiettili).
3. **Nessuna dipendenza circolare tra foglie.** Se ti serve qualcosa che l'API non espone, non te lo procuri con un `get_node("../..")`: si chiede al vertice.

## 6. Porte di verifica

```sh
. tools/env.sh && "$GODOT" --headless --path . --import          # w1, solo scheletro
. tools/env.sh && "$GODOT" --headless --path . --script tools/gate.gd
. tools/env.sh && "$GODOT" --headless --path . --quit-after 300
python tools/check_perms.py                                      # permessi, vedi 11.7
```

Il gate dei permessi è una porta **separata** e va eseguita **a parte**: `gate.gd` gira i `tests/test_*.gd` dentro Godot, e uno script Python non è un test Godot. Le due porte non si sommano in un unico numero: `GATE: 4/4` e `PERM: 15/15` sono due fatti distinti, e il vertice riporta entrambi.

Il gate (`tools/gate.gd`) esegue ogni `tests/test_*.gd` in un **processo separato** e decide sul codice di uscita: `0` solo se tutti passano. Ogni test stampa `PASS <nome>` o `FAIL <nome>: <motivo>` e finisce con `quit(0)`/`quit(1)`; un test assente è `SKIP`, non un fallimento.

Regola di oro: **nessun agente "finisce" perché ha scritto il codice**. Finisce quando la porta dice verde.

## 7. Regole anti-race

Cinque agenti scrivono nella stessa cartella **in parallelo**. Queste regole sono ciò che separa un'ondata da un disastro:

1. **`.godot/` è di `terminal-gun-scheletro`.** Nessun altro esegue `--import`. In caso di cache corrotta: `rm -rf .godot` e re-import (solo scheletro, o vertice).
2. **Il commit è del vertice.** Nessuna foglia esegue `git add` o `git commit`.
3. **`winget` mai in parallelo**, e solo in w0: winget ha un lock globale.
4. **Scope sui permessi, non sulle buone maniere.** Ogni foglia ha in `permissions` una deny su `edit *` e un allow sui propri file: se sfora, il sistema glielo blocca. **Emendato da §11**: è vero per la *scrittura*, che è l'unica cosa bloccata davvero, perché `shell` non è una sandbox (§11.3) e `mkdir`/`cp`/`mv`/`rm`/`echo` sono assenti di proposito. Quello che **non** è più un blocco secco è l'accesso a una risorsa non enumerata in anticipo: quello chiede, e lo chiede all'utente (§11.2). Le invarianti di **proprietà** — `--import`, `rm -rf .godot`, `git add`/`commit` — restano `deny` per tutti, con l'unica eccezione dichiarata per scheletro e vertice.
5. **Niente path assoluti di macchina** nei file prodotti, con una sola eccezione: `tools/env.sh`, che esiste proprio perché i path stiano in un posto solo. **Una seconda eccezione, dichiarata in §11.8:** il path assoluto di Blender in `permissions` degli agenti che lo eseguono, per lo stesso identico motivo.

## 8. Stato

Da aggiornare a fine onda. **w0, w1, w2 e w3 verdi. Milestone 1 chiusa.**

| onda | agenti | esito | gate | stato |
|---|---|---|---|---|
| w0 | vertice | Godot 4.7.2 + Blender 5.2.2 installati, `tools/env.sh` scritto, `git init` + LFS su `*.glb`/`*.wav`/`*.ogg`, identità git impostata **localmente** (`bisco <bisco@localhost>`: non c'era nessuna, né locale né globale) | — | **verde** |
| w1 | scheletro, assets | `project.godot`, `contracts.gd`, `gate.gd`, `test_harness.gd`, `test_smoke.gd`, `.gitignore`; 7 SFX + 6 modelli generati e deterministici | `GATE: 1/1`, exit 0, verificato dal vertice | **verde** |
| w2 | orda, gameplay, arena | orda: `src/sim/` (horde, griglia spaziale, pool, spawner, tabelle specie). gameplay: player, armi, proiettili, XP e potenziamenti. arena: `MultiMeshInstance3D`, terreno, camera, HUD — **eseguito via `esecutore`** | `GATE: 4/4`, exit 0; `--quit-after 300` exit 0 con zero `SCRIPT ERROR` | **verde** |
| w3 | vertice | piano emendato in §5.1 (ordine di registrazione), §5.2 (firme), §5.3 (identificatore `Game`), §5.4 (knockback per specie); stato e criteri aggiornati | entrambe le porte rieseguite dal vertice | **verde** |

### Le onde della milestone 2

| onda | agenti | esito | gate | stato |
|---|---|---|---|---|
| **m2-w0** | vertice, solo shell | esperimento `KNOCKBACK` vs `SPEED_MAX` **misurato e scritto** (§1.2): l'ipotesi di m1 era **sbagliata**, nessuna saturazione al valore di codice, soglia vera ~24.6 m/s. `-arena` **provato con un lancio reale**: il provider lo blocca, il catalogo mentiva | `GATE: 4/4`, `PERM: 15/15` rieseguite dal vertice | **verde con due debiti aperti** |
| **m2-w1** | orda, gameplay, ui | **chiusa al secondo giro**: `-orda` `test_gameloop` + `BUCKET_SLOTS` 12→32; `-gameplay` `test_progression`, `test_upgrades`, `Game.progression` cablato; `-ui` era gia' finita | `GATE: 8/8` exit 0, `--quit-after 300` pulito, knockback runner **0.3114** | **verde** |
| **m2-w2** | vertice | commit, piano aggiornato, verdetto; `.godot/` ricostruita dal vertice (13 asset) | `GATE: 8/8`, `PERM: 15/15`, `--quit-after 300` rieseguite dal vertice | **verde** |
| **m2-w3** | orda | `test_gameloop` reso riproducibile: seme fisso **177** sull'orda isolata, scelto da uno sweep 1..240 dentro la banda tipica (picco 28 su 32) perche' l'asserzione conservi i denti; i denti provati due volte e rimossi (seme 148 e `BUCKET_SLOTS` 12, entrambi `FAIL`); nessun altro file toccato | `GATE: 8/8` exit 0, **120 esecuzioni consecutive** di `test_gameloop` (60 foglia + 60 vertice) tutte PASS | **verde** |

### Riapertura del 2026-10-12: nessuna wave pendente, un atto di governance fuori da ogni commit

**Non c'era una wave da riprendere, e il vertice non ne ha rilanciata nessuna.** w0–w3 e
m2-w0–m2-w3 erano verdi da prima; il piano non definisce m3, quindi aprire una milestone nuova
sarebbe stato inventare scope, non eseguire un'onda. Le porte sono state **rieseguite**, non
rilette: `GATE: 8/8`, `--quit-after 300` pulito, `PERM: 15/15`, `git lfs ls-files` 13 file.

**Il pendente era un altro, e non era un codice**: `.opencode/agents/terminal-gun.md` era
**modificato e non committato**. La riga `edit tools/gate.gd` c'era già, scritta dall'utente
(§11.5), e `perm_mirror` era verde: le due copie — repo e installazione — erano allineate. Mancava
solo la **storia**, e per §11.6 il mirror nel repo è la fonte di verità: una riga di governance non
committata è una riga che al prossimo clone sparisce. Commit del vertice, come la regola 7.2.

| fatto | misura |
|---|---|
| `perm_scope` | **verde**: `PERM: 15/15`, il `14/15` dichiarato aperto è chiuso |
| allowlist **applicate** (§11.10) | `edit .gitignore` → `Permission denied: edit` |
| allowlist nuova **viva** | `edit tools/gate.gd` → nessun rifiuto, arriva alla ricerca |
| working directory | root del progetto, non `C:\Windows\System32` (la trappola di §8) |

Il verde di `PERM: 15/15` da solo non bastava a dichiarare il debito chiuso: senza la seconda e
la terza riga sarebbe stato lo stesso numero di una sessione **non governata**, che è
compatibile con `15/15`. La differenza tra le due è un `Permission denied`, e il piano la
dichiarava non misurata da nessuna parte.

### Le onde della milestone 3

| onda | agenti | esito | gate | stato |
|---|---|---|---|---|
| **m3-w0** | vertice | superficie di m3 **congelata** in `src/core/contracts.gd` (`reseed(s)`, cinque punti di semantica), specifica §1.3/§3.5/§4.2/§4.3 scritta, difetto di `worst_bucket()` trovato leggendo il codice | `PERM: 15/15` **prima** di lanciare: nessuna riga di permesso nuova | **verde** |
| **m3-w1** | orda, arena | `-orda`: `reseed(s)` in `src/sim/horde.gd:517`, tutti e cinque i punti; `worst_bucket` reso per-frame **senza toccare `spatial_grid.gd`**. `-arena`: sezione 8 in `tests/test_arena.gd`, 126 → **169 asserzioni** | `GATE: 8/8` exit 0, `--quit-after 300` pulito, rieseguiti **dal vertice** | **verde** |
| **m3-w2** | vertice | porte rieseguite, sweep verificato identico su 3 lanci, commit | `GATE: 8/8`, `PERM: 15/15`, `--quit-after 300` | **verde** |

### I quattro criteri della milestone 3, uno per uno

Rimisurati dal vertice il 2026-10-12, non rileggi dai report delle foglie.

| # | criterio | esito | numeri di oggi |
|---|---|---|---|
| 1 | La porta è verde | **sì** | `GATE: 8/8` exit `0`, `PERM: 15/15`. Il denominatore è **8**, non 9: m3 non aggiunge un file di test, mette le sue asserzioni dentro `test_arena.gd` |
| 2 | La disposizione è una funzione del seme | **sì** | seme `4242` due volte → **0/200** posizioni diverse, somma `-487.136671` **identica**; seme `7311` → **200/200** diverse. Entrambe le direzioni asserite, e `colors` confrontati a parte |
| 3 | Testata dichiarata e misurata | **sì** | sweep di **24 semi** (1, 11, … 231) sulla scena vera: `worst_bucket` **min 4, mediana 5, max 7**, **0 semi traboccati su 24**, **0 celle sconosciute**, **23/23** coppie di semi consecutivi con disposizione diversa. Tetto `GRID_CEILING = 11` |
| 4 | I denti, provati e rimossi | **sì, due volte** | (1) 200 nemici in una cella → `worst_bucket` 32, `grid_overflowed()` vero, tre asserzioni `FAIL`, uscita 1. (2) **12** nemici in una cella → `worst_bucket` 13 con `grid_overflowed()` **falso**: a cadere è **solo** il tetto di densità. Il blocco che le forzava **non è nel file**, verificato con grep |

**La seconda prova è quella che conta.** La prima dimostra che le asserzioni cadono; la
seconda dimostra che il tetto di densità **non è portato** dalla segnalazione di traboccamento.
Senza di essa, `GRID_CEILING` sarebbe un controllo che il flag di overflow tiene su in ogni
caso in cui conta, cioè un'asserzione decorativa con tre cifre.

**Come il tetto è stato derivato**, e perché è sulla misura e non sul codice: base = massimo
misurato **7** (non il minimo 4, non la mediana 5: entrambi cadrebbero alla prima variazione
normale di densità), **+4 slot** di margine dichiarato — maggiore dell'escursione dell'intero
campione, che è di 3 — e **21 slot** di distanza da `BUCKET_SLOTS = 32`. Non `BUCKET_SLOTS - 1`:
`insert()` aggiorna il contatore solo con `n < BUCKET_SLOTS`, quindi quel tetto sarebbe una
**tautologia che non può fallire**. `-orda` e `-arena` sono arrivati alla stessa conclusione
sulla tautologia **da soli, in due foglie diverse, senza dirmelo**: è il segnale che la
documentazione di `spatial_grid.gd` lavora.

**Il campione è deterministico per costruzione, non per fortuna.** I semi sono fissi,
`_rng.seed` li fissa, `_populate` è la stessa funzione del primo frame: l'argomento è
strutturale. Le **3 esecuzioni** del vertice hanno dato le linee di m3 **identiche byte per
byte**, e sono **corroborazione, non prova** — a differenza di m2-w3, dove l'argomento non
poteva essere strutturale (RNG globale non seminato) e i 120 lanci erano invece la prova.
Unica cosa che oscilla fra un lancio e l'altro è il knockback del criterio n. 4 di m1
(0.3109 / 0.3128 runner): comportamento noto di §1.2, dentro il tetto 0.3, **non introdotto
da m3**.

### Cosa m3 ha chiuso, e cosa ha lasciato com'era

- ~~**Il traboccamento vero della griglia sulla scena vera non è guardato da nessuna
  asserzione.**~~ **CHIUSO.** E la causa era un buco di API, non la casualità: `horde.seed`
  era un campo pubblico documentato come riproducibile, ma `_build()` lo leggeva una volta
  sola dentro `_ready()`, e sulla scena vera nessun codice poteva scriverlo prima. Il campo
  **sembrava** la riproducibilità ed era irraggiungibile.
- ~~**`worst_bucket()` diceva una cosa e ne faceva un'altra.**~~ **CHIUSO.** Il commento
  promises «in un frame», il codice teneva un massimo storico. `-orda` ha scelto la
  semantica per-frame e l'ha resa azzerando in `_rebuild_grid()`, **senza toccare
  `spatial_grid.gd`**; `-arena` non gliel'ha accettata a parole, l'ha **verificata**
  riscrivendo il seme peggiore (picco 7) e poi quello migliore, e asserendo che il numero
  **scenda**. Quella riga è quella che cade se la semantica torna storica.
- **Aperto, e dichiarato**: `BUCKET_SLOTS = 32` è tarato su un picco di **19** misurato
  sull'orda **isolata**, mentre sulla scena vera il picco è **7**. La costante è quindi
  **4,7 volte** più larga di quanto serva oggi. Non è un difetto — il fallback a scansione
  lineare è corretto e il costo è ~84 KB presi una volta sola — ma è un margine che nessuno
  ha chiesto e che nessuno ha misurato. **Non si tocca in m3**: cambiarlo è un esperimento
  con un suo protocollo, non un ripulimento, e l'ipotesi «lo abbasso» va verificata come
  l'ha verificata §1.2.
- **Aperto**: nessun segnale `enemy_died` (rimandato da m2). Oggi l'XP usa il valore di
  ritorno di `damage_enemy` e funziona.

### m2-w3 (debito): `test_gameloop` riproducibile — specifica

**CHIUSA il 2026-10-11, verificata dal vertice, non riletta dalla tabella.** `-orda` ha
consegnato un seme fisso e ha **dimostrato** il seme, non sorteggiato: sweep dei semi 1..240
sulla sequenza esatta della parte 1 del test, picco di cella min 24 / mediana 29 / max 32,
un solo seme trabocca (il **148**, picco 33 — tasso 0,4%, coerente col ~0,6% misurato). Ha
scelto il **177** (picco 28): non trabocca (4 slot di margine su 32), e' nella banda tipica
(mediana 29, vicini 28/29/28), e conserva i **denti** dell'asserzione — non il minimo 24 (seme
158), che renderebbe la guardia immune a qualunque densita'. I denti **provati due volte e poi
rimossi**: seme 148 → `FAIL test_gameloop: nessun secchiello traboccato`, exit 1; e
`BUCKET_SLOTS` 32→**12** con seme 177 → stesso FAIL, exit 1. Nessun probe su disco, `git status`
pulito su `src/sim/**`. **Porte rieseguite dal vertice**: `GATE: 8/8` exit 0; **120 esecuzioni
consecutive** di `test_gameloop` tutte PASS — 60 della foglia, **60 del vertice** (non la stessa
misura letta due volte). Nota dichiarata da -orda: l'orda della **scena vera** in `_scena_vera`
resta `seed = 0`, ma nessuna asserzione guarda la sua `grid_overflowed`; e' li' che il
traboccamento vero puo' ancora accadere e va guardato in m3 (ed e' quello che il criterio n. 3
di m1 misura gia' sulla scena vera).

**Perche' questa onda esiste.** Misurato il 2026-10-11, non dichiarato: `test_gameloop` e'
caduto **1 volta in 175 esecuzioni**. L'asserzione che cade e' `tests/test_gameloop.gd:241`
(`not horde.grid_overflowed()`), e la causa **non** e' un difetto del codice. L'orda
**isolata** del test nasce con `seed = 0` (`src/sim/horde.gd:92`), cioe' `_rng.randomize()`:
la disposizione dei nemici cambia a ogni lancio. Quando il ripopolamento ne addensa
abbastanza da superare `BUCKET_SLOTS` (**32**, `src/sim/spatial_grid.gd:46`) nella stessa
cella, `overflowed` va a vero e il gate scende a `7/8` **senza alcuna regressione**. Non e'
riproducibile a comando, ed e' esattamente cio' che §11.11 vieta di lasciare in giro: una
porta la cui rossa non distingue «difetto» da «dado».

**Un file, un proprietario.** Scope: `tests/test_gameloop.gd` (-orda, §3.3). Se e solo se il
seme non bastasse, anche `src/sim/horde.gd` o `src/sim/spatial_grid.gd`, con la motivazione
scritta; nessun altro file.

**Cosa consegna `-orda`:**

1. **Riproducibilita'.** Il caso che la riga 241 misura non dipende piu' dal dado: un **seme
   fisso** per l'orda isolata del test (o, se motivato, un caso costruito). Il numero sta nel
   file con un commento che dice **perche'** quello.
2. **I denti dell'asserzione.** Una prova **temporanea, rimossa prima di finire** (come il
   probe del timeout di §11.11): forzando il traboccamento — popolazione piu' densa, o
   `BUCKET_SLOTS` abbassato di proposito — la riga 241 deve dire **FAIL**. Un'asserzione che
   non sa fallire non e' un'asserzione.
3. **La porta verde, e non per fortuna.** `GATE: 8/8`, exit 0, e **60 esecuzioni consecutive**
   di `test_gameloop` (dirette o con `tools/gate.gd --only test_gameloop`) tutte PASS: e' il
   numero che rende «riproducibile» una misura invece di un'impressione.
4. **Report a tre righe**: cosa fatto — file toccati — cosa resta.

**Cosa questa onda non e'.** Non e' un permesso da chiedere (il file e' gia' nello scope di
-orda) e non e' una regressione da riparare: e' un debito di **misura**. Se al punto 2 la
riga 241 restasse verde anche col traboccamento forzato, la scoperta non sarebbe «aggiustare
il test»: sarebbe che la riga 241 **non ha mai misurato niente**.

### I sei criteri della milestone 2, uno per uno

Rimisurati dal vertice il 2026-10-11, non rileggi dalla tabella.

| # | criterio | esito | numeri di oggi |
|---|---|---|---|
| 1 | La porta e' verde | **si'** | `GATE: 8/8`, exit `0`. Il `7/7` del criterio va letto come **almeno 7**: il gate esegue ogni `tests/test_*.gd` su disco (§6), e di test ne sono nati otto |
| 2 | L'XP fa salire di livello, e non e' finta | **si'** | `PASS test_progression`, **106 asserzioni**: 12 uccisioni **vere** in 161 passi -> livello 3; onda 1→2 dopo 252 uccisioni -> livello 16, 756.0 XP; barra in `[0, next)` **controllata in ogni frame**; `NaN`/`INF/-INF/-7` respinti; al confine d'onda **nessuna XP persa**, con 188 uccisioni contate identiche da -orda e da -gameplay |
| 3 | Un potenziamento cambia il comportamento misurabile | **si'** | `PASS test_upgrades`, **323 asserzioni**, otto misure **comportamentali** e nessuna lettura di campo. Spostamenti: `damage` **+25.0%**, `fire_rate` **-18.0%** (piu' rapida), `move_speed` **+9.7%**, `projectile_speed` **+20.0%**, `knockback` **+30.0%** (8.100→10.530 m/s sul bruto), `pierce` **+100.0%** (1→2 nemico), `vitality` **+20.0%** (10→12 colpi), `range` **+26.2%** (84→106 passi). Tutte le misure non pertinenti restano a **0.0%**: nessun rumore. Soglia 2% superata da tutte e otto |
| 4 | La partita ha una fine | **si', con una meta' dichiarata** | `PASS test_gameloop`, 233 asserzioni: onde 1→3 superate, onda 3→4 con barra a 0, scala vita 1.00→1.50, **4 restart con 3 nodi prima e dopo** e un solo nodo `Horde` sotto root, nessun nodo duplicato, 0 KB di crescita su 600 passi. Il test dimostra **anche in un numero** che `restart_run()` non rimette in piedi il giocatore da solo (hp 0.0): e' la meta' di -orda, e la meta' di -gameplay e' chiamarla. **La schermata di game over e' scope di -ui ed e' scritta**, ma nessun criterio la misura |
| 5 | Il criterio n. 4 di m1 non regredisce | **si'** | runner **0.3114**, grunt **0.3570** (tetto 0.3), brute 0.1963 e boss 0.0554 esclusi per progetto (§5.4). **`KNOCKBACK` resta 18.0**, confermato da tre letture indipendenti nella stessa esecuzione |
| 6 | La porta non ha timeout | **SI', il codice — chiuso il 2026-10-11; resta mezza riga di governance** | `tools/gate.gd` non usa più `OS.execute`: `_run()` lancia il test con `OS.execute_with_pipe(..., false)`, sorveglia pid e pipe leggendo a pezzi, e oltre `TEST_TIMEOUT_MS` (120 s) **uccide** il figlio con `OS.kill` e lo dichiara `FAIL <nome>: timeout: ...`. **Provato, non dichiarato**: un test che si blocca e' diventato FAIL a **120 s esatti**, con zero processi rimasti; il gate normale e' identico (`GATE: 8/8`, exit 0) e la stderr del figlio continua ad arrivare al gate (una `PASS` con uno `SCRIPT ERROR` su stderr resta un FAIL). **Mezza riga aperta**: `perm_scope` e' **rosso** (`PERM: 14/15`) finche' l'utente non aggiunge `edit tools/gate.gd` alla allowlist del vertice — §11.11. E una scoperta nuova, dichiarata li': **il rimedio «pronto» da giorni non compilava** |

### m2-w1 ripreso il 2026-10-11: `GATE: 6/6` non vuol dire m2 chiusa

**Il verde e' reale, ma non copre quello che m2 chiede.** Distinguiamo i due fatti,
perche' il primo rischia di mascherare il secondo.

**Fatto 1 — l'ambiente era rotto, non le foglie.** Il primo gate dava **`GATE: 2/6`**,
con `Cannot open file 'res://.godot/imported/*.scn'` in ogni test che apre la scena
vera: la cache di import di Godot **non esisteva piu'**. Non e' un difetto di nessuna
foglia, e non e' nato stasera: e' il costo di `.godot/` fuori da git. Il vertice l'ha
ricostruita con `--import` (13 asset, 6 `.glb` + 7 `.wav`) e il gate e' salito a `4/6`.
**Da mettere in conto a ogni sessione che riapre il repo dopo un tempo**: se il gate
e' rosso con `imported/` che non c'e', la prima mossa non e' rilanciare foglie.

**Fatto 2 — `-orda` ha consegnato, e ha trovato difetti che non erano nel FAIL.**
`tests/test_gameloop.gd` non partiva per `_superficie(h, game)` con due argomenti
contro una firma da tre (`tests/test_gameloop.gd:105` contro `:431`): un file scritto
a meta'. Sotto, **tre difetti reali**, due nel codice e due nel test:

- **Traboccamento della griglia, difetto di CODICE**: il picco reale e' **19 nemici in
  una cella da 4 m contro 12 slot**. Non e' rumore, e' la densita' che l'orda crea
  convergendo sul bersaglio: il fallback a scansione lineare si riaccendeva proprio
  nel caso in cui la griglia serve. `-orda` ha portato `BUCKET_SLOTS` da 12 a **32**
  in `src/sim/spatial_grid.gd`, con il margine motivato a commento. Il costo e' **zero
  nel ciclo di gioco**: le query iterano `bucket[HEAD]` (indici validi), non la
  capienza, e il riscaldamento gira una volta sola in `setup()`. `worst_bucket()` e' un
  contatore, non un limite di memoria.
- **Game over, difetto del TEST**: il test pretendeva che rimettere le vite riportasse
  la partita in corso, ma `run.gd` documenta `enter_game_over()` come **a senso unico**.
  L'asserzione e' stata invertita: vite rimesse **senza** restart la partita resta
  finita; il restart vero la riprende.
- **Superficie di m2, difetto del TEST**: `_superficie` girava dopo che `_scena_vera`
  aveva liberato l'arena, quindi `Game.horde` puntava a un nodo liberato e il
  contratto rispondeva "manca" per un registro che c'era: si misurava **un garbage
  pointer invece del contratto**. Spostata dentro `_scena_vera`, prima di `_chiudi`.

Risultato: **`PASS test_gameloop`, 233 asserzioni**, `test_orda` non rotto (griglia
ancora 1.21-1.32x sulla lineare, 200 nemici con 3 nodi, `nessun traboccamento`).

**Fatto 3 — `-gameplay` ha corretto il FAIL, ma ha tolto copertura.** Il FAIL del
primo giro diceva `knockback` atteso **23.4** e ottenuto **18.0**: sembrava il divieto
di §1.2 violato dal codice. Era il contrario, e la prova e' aritmetica:
**23.4 = 18.0 x 1.3**, **8.47 = 7.0 x 1.1 x 1.1**, **120 = 100 + 20**. Il test confrontava
il restart non con la regolazione di partenza, ma con uno **snapshot sporco** preso
dopo che la sezione upgrades aveva gia' applicato tre potenziamenti. Il codice aveva
ragione, il test aveva torto. **`KNOCKBACK` resta 18.0 e il divieto di §1.2 e' stato
rispettato** — ma aavedlo a dirlo e' stato `-gameplay`, non il vertice, e per poco:
se avesse rialzato il numero a 23.4 per far quadrare l'asserzione, il gate sarebbe
verde e il criterio n. 5 di m2 **regredito in silenzio**.

Il costo di quella correzione pero' e' reale: **`-gameplay` ha rimosso dal
`test_gameplay.gd` le sezioni 7 (XP) e 8 (potenziamenti)** per spostarle in
`tests/test_progression.gd` e `tests/test_upgrades.gd`, **che non ha mai creato**.
Il gate conta quello che trova su disco, quindi e' salito a **`GATE: 6/6`** senza che
nessun test avesse fallito. **Copertura persa, non spostata.** Ne segue che adesso
**i criteri n. 2 e n. 3 di m2 non hanno porta**: `7/7` del criterio n. 1 non e'
raggiungibile e, per il momento, non e' nemmeno verificabile.

**Fatto 3b — la copertura persa e' stata recuperata, e il numero e' salito senza che nessun test fallisse.** `-gameplay` e' stato rilanciato su questo punto solo. Ha cablato `Game.progression = progression` in `src/player/player.gd`, e **la prova che il collegamento sia reale non e' il gate verde**: e' che `test_gameloop` **ha smesso di stampare** la lista di dieci voci «manca: il contratto non ha ancora 'progression'». Poi ha creato i due file, `test_progression.gd` e `test_upgrades.gd`. `test_gameplay` non e' stato toccato in questo giro ed e' restato verde. Il gate e' passato da `6/6` a **`8/8`**.

Quel passaggio lascia **una lezione di metodo, non un difetto del codice**: **il gate conta i file, non la copertura**. Un test puo' essere cancellato e il denominatore puo' salire nella stessa ora, e nessuna riga di `GATE:` lo dichiara. L'unica difesa e' che il vertice legga **quali** test sono passati, non **quanti** — e la stessa ragione per cui `GATE: 0/0` e' un FAIL e non un verde.

Vale anche per la direzione opposta, ed e' gia' successa: il piano dichiara `GATE: 7/7` per m2, ma il gate ne conta uno in piu' per ogni `test_*.gd` che trova. Il `7/7` va letto come **«almeno 7»**, e la regola per stabilire se un criterio ha una porta non e' il denominatore: e' **se il file di quel criterio esiste e gira**.

**Fatto 4 — il difetto di governance e' tornato, terza volta, ed e' nella mia allowlist.**
`tools/gate.gd` e' dichiarato **del vertice** da §3.3, che mi assegna esplicitamente
il timeout del gate perche' scheletro non lavora in m2. Il piano §2 lo conferma.
Ma il blocco `edit` di `terminal-gun.md` (righe 368-380) contiene `docs/piramide/**`,
`src/core/contracts.gd`, `tools/env.sh`, `tools/check_perms.py` e `.gitattributes`:
**`tools/gate.gd` non c'e'**. Provato stasera, non dichiarato: `edit` su quel file
risponde `Permission denied: edit`.

E' **la stessa classe di difetto** di §3.1 (`.gitattributes` senza proprietario in
nessuna allowlist) e del primo m2-w1 (tre path di scope che il piano assegnava e che
nessuno aveva messo nei permessi). La differenza e' che questa volta **colpisce il
vertice**, quindi non c'e' nessuna foglia a cui chiedere: per §11.5 il vertice non puo'
riscrivere la propria allowlist. **E' un atto dell'utente**, come le quattro copie del
2026-10-06. Il rimedio e' una riga, e `tools/check_perms.py` (scope del vertice)
va aggiornato con lo stesso path, altrimenti `perm_scope` va rossa al primo check.

Conseguenza: **il criterio n. 6 di m2 resta aperto**. `tools/gate.gd` oggi dichiara
esplicitamente `OS.execute` bloccante e senza timeout, e il blocco di codice corrispondente
e' ancora `return OS.execute(exe, args, output, true, false)`. Il rimedio e' gia' scritto
e verificabile: `OS.execute_with_pipe` in modo **non bloccante** restituisce sia il pid
sia la pipe, quindi si puo' sorvegliarlo con `OS.is_process_running`, leggere l'output a
pezzi e **uccidere con `OS.kill` il test che si blocca**, riportandolo come FAIL
dichiarato invece di congelare il gate. Non l'ho applicato perche' **non posso**.

### m2-w1: due foglie su tre bloccate, e il difetto è del vertice

**Non è un difetto delle foglie.** Entrambe si sono fermate al primo file che il piano chiedeva di scrivere, con `Permission denied: edit`, e nessuna ha aggirato il permesso (che è il comportamento corretto, §11.2).

**La causa è che in m2-w0 ho preparato solo metà del wave.** Ho creato il file della foglia **nuova** (`-ui`) e ho cambiato il modello di `-arena`, e ho dato per scontato che fosse sufficiente. Non lo era: il piano §3.3 assegna a `-orda` anche `tests/test_gameloop.gd` e a `-gameplay` anche `tests/test_progression.gd` e `tests/test_upgrades.gd`, e **quelle tre righe non erano in nessuna allowlist**. È l'errore che §3.1 chiama "file senza proprietario" fatto **al contrario**: non un file senza proprietario, ma un path che il piano assegna e che nessuno aveva messo nei permessi.

**Perché `PERM: 15/15` non l'aveva preso, e questa è la parte che vale.** `perm_scope` confronta gli `edit` allow con `SCOPE` in `check_perms.py`, e anche `SCOPE` era rimasto quello di m1. Il gate confrontava due copie del **vecchio** scope e concludeva che erano d'accordo: era verde e aveva ragione su cio' che misurava, che non era quello che serviva. Una porta che verifica bene una cosa giusta non copre una cosa che non hai scritto.

**Il difetto è già riparato e verificato**: `docs/piramide/fix_m2_test_scopes.py` aggiunge le tre righe e si ferma se gli `edit` allow non sono **esattamente** quelli del piano §3 e §3.3. Diff di `-orda`: **tre righe aggiunte, nient'altro**. `check_perms.py` ha guadagnato gli stessi tre path in `SCOPE`. Simulazione: **`SIMULAZIONE PERM: 15/15`**.

### Cosa ha consegnato `-orda` che vale, e va nel piano

`restart_run()` fa **solo la metà di -orda**: azzera e ripopola l'orda, ma **non tocca il giocatore**. Il restart di `-gameplay` deve chiamarla. Senza questo il criterio n. 4 si dimostra solo sul lato simulazione, e va detto.

Un altro accoppiamento, **non dichiarato prima e trovato dalla collaborazione**: `-ui` legge `Game.horde.wave` **per nome**, e `-orda` espone `wave` come **campo** e non come metodo perche' quell'HUD lo legge gia'. Due foglie che lavorano in parallelo hanno quindi concordato un nome senza che nessuno lo avesse deciso: e' successo perche' una delle due lo aveva scritto e l'altra lo aveva letto nel codice dell'altra. Funziona, ma funziona per fortuna e non per contratto.

### Il gate di m2 conta piu' test di quanti ne chiede

`GATE: 5/5` con `test_ui` presente: il gate esegue **ogni** `tests/test_*.gd` che trova su disco (§6), quindi il conteggio di m2 che dice `7/7` sale a `8/8` quando anche `test_ui` c'è. Non è un fallimento: è il gate che fa il suo lavoro. Il `7/7` del criterio n. 1 va letto come "almeno 7".

### m2-w0, seconda parte: i file di agente di m2 sono pronti

L'utente ha chiesto al vertice di fare lui l'agente. Il vertice ha potuto fare **tutto tranne la copia**, perché `write` su `.opencode/agents/**` è il muro di §11.5 (provato, non dichiarato).

| file pronto | cosa cambia | da dove viene |
|---|---|---|
| `docs/piramide/agents_ready/terminal-gun-ui.md` | foglia nuova di m2 | blocco `permissions` di `-arena`, privato dei suoi `edit` + il path del test nuovo |
| `docs/piramide/agents_ready/terminal-gun-arena.md` | `model: fledge-alpha-free#max` → `space-bunny-free#max` | una riga sola |

**Il blocco dei permessi di `-ui` non è riscritto a mano**: è generato dal file di `-arena`, che è già verde, e il generatore si ferma se gli `edit` allow non sono esattamente `scenes/hud.tscn`, `src/ui/**`, `tests/test_ui.gd` o se uno di questi punta a un file di un altro agente.

**Un difetto reale, preso dalla simulazione e non a occhio.** La prima versione lasciava a `-ui` anche `scenes/arena_main.tscn` e `src/render/**`, perche' il blocco ereditato li conteneva: `perm_scope` l'ha visto e ha detto `scope dei permessi [...] != scope dichiarato [...]`. Un allow in più del dichiarato è **un buco nella regola 1**: una foglia che puo' scrivere file di un'altra senza che nessuno lo dichiari. Il generatore ora lo dichiara e si ferma se torna.

**Verificato prima di chiedere la copia**: `python docs/piramide/verify_agent_install.py` → **`SIMULAZIONE PERM: 15/15`**. Consegnare all'utente un file che al primo check è rosso è il modo più veloce per bruciare la fiducia in una porta.

**Cosa deve fare l'utente, in quattro copie** (il vertice non può, §11.5):

```sh
cp docs/piramide/agents_ready/terminal-gun-ui.md    .opencode/agents/
cp docs/piramide/agents_ready/terminal-gun-arena.md .opencode/agents/
cp docs/piramide/agents_ready/terminal-gun-ui.md    ~/.config/opencode/agents/
cp docs/piramide/agents_ready/terminal-gun-arena.md ~/.config/opencode/agents/
```

Poi **riavviare opencode** (i permessi si caricano all'avvio, §10) e lanciare `python tools/check_perms.py`, che deve dire `PERM: 15/15`. A quel punto m2-w1 può partire con `orda ∥ gameplay ∥ ui`.

**`check_perms.py` è già registrato per `terminal-gun-ui`** (`LEAVES` e `SCOPE`, con il passaggio di `scenes/hud.tscn` e `src/ui/**` da `-arena` a `-ui` in `DECLARED_OVERLAP`). Finché i file non sono installati la porta dice **`PERM: 0/15` con `perm_install`**, che è il comportamento giusto: la piramide non è installata, e la porta lo dice una volta sola invece di tredici.

**Un `.pyc` è finito nel repo, e non lo posso togliere.** `import check_perms` dentro i due script di m2-w0 ha scritto `tools/__pycache__/check_perms.cpython-314.pyc`, e `git add -A` lo ha committato. `.gitignore` **non ha la regola `__pycache__`**, e `.gitignore` è scope di `-scheletro`, quindi il vertice non la tocca. Il rimedio è `git rm --cached tools/__pycache__/`, che al vertice è **negato** (non è in allowlist, e `git rm` è nella stessa famiglia di `git clean`/`git reset`). Quindi: **lo toglie l'utente, o lo toglie `-scheletro` in un'onda dedicata** con le due righe `__pycache__/` e `*.pyc`. Intanto i due script hanno `sys.dont_write_bytecode = True`, quindi **non ne generano altri**: il danno è uno e solo, non una crescita.

### I sei criteri della milestone 1, uno per uno

| # | criterio | esito | numeri |
|---|---|---|---|
| 1 | La porta è verde | **sì** | `GATE: 4/4`, exit `0` |
| 2 | La scena si apre senza errori | **sì** | `--quit-after 300` exit `0`, zero `SCRIPT ERROR` / `Parse Error` |
| 3 | 200 nemici vivi, senza un nodo per nemico | **sì** | `horde.count == 200` con `node_count` **27** in scena (tetto 120); nel test di -orda `node_count == 3` |
| 4 | Il player spara e uccide | **sì** | HP scende di **un** colpo e resta fermo 30 frame con `pierce=3`; knockback runner **0.311**, grunt **0.356** (tetto 0.3), brute 0.196 e boss 0.055 **esclusi per progetto** (§5.4) |
| 5 | Si sente il "bonk" | **sì** | `assets/sfx/bonk.wav` 44100 Hz mono, 0.18 s (tetto 0.6) |
| 6 | Niente binari nel Git normale | **sì** | `git lfs ls-files` elenca 13 file: 6 `.glb` + 7 `.wav` |

### Rimesurazione dal vertice, 2026-10-06

Il vertice **non si è fidato di §8**: ha rieseguito le porte e rimisurato i sei criteri invece di rileggere una tabella. **Verdi tutti e sei.** I knockback tornano a `0.3128` e `0.3555`, cioè gli stessi numeri già dichiarati ma più arrotondati: non è una variazione, è la stessa misura.

| # | criterio | esito | numeri di oggi |
|---|---|---|---|
| 1 | La porta è verde | **sì** | `GATE: 4/4`, `exit 0` rieseguito dal vertice |
| 2 | La scena si apre senza errori | **sì** | `--quit-after 300`, `exit 0` letto esplicitamente, zero `SCRIPT ERROR` / `Parse Error` / `ERROR:` |
| 3 | 200 nemici vivi, senza un nodo per nemico | **sì** | `node_count=27` con `horde.count=200` (tetto 120) |
| 4 | Il player spara e uccide | **sì** | `PASS test_gameplay` 110 asserzioni; knockback reale in 5 frame: runner **0.3128**, grunt **0.3555** (tetto 0.3), brute 0.1964 e boss 0.0555 esclusi per progetto |
| 5 | Si sente il "bonk" | **sì, ma non con `ffprobe`** | `tools/gen_sfx.py` scrive `SAMPLE_RATE = 44100`, `nchannels=1`, `bonk = render_tone(0.18, ...)`. Il vertice ha una deny su `shell *` con allow solo su `godot`/`git`/`winget`, quindi **non ha potuto misurare il file**: dato da sorgente, non sul campione |
| 6 | Niente binari nel Git normale | **sì** | `git lfs ls-files`: 13 file, 6 `.glb` + 7 `.wav` |

**Cosa è cambiato in questa sessione, in una riga:** niente del codice. Il vertice ha committato `.gitattributes`, che era **modificato ma fuori da ogni commit**, e ha corretto due affermazioni del piano che non reggevano più (§3.2, §8: il modello di -arena).

### Come w2 è finita: sette difetti reali, e due miei

**Il vertice ha sbagliato due volte, ed è il fatto più utile di questa onda.**

1. **§5 prescribeva una registrazione ineseguibile.** `Game.nearest_enemy = self._nearest_enemy` è rifiutato da GDScript e **interrompe il `_ready()`**: tre foglie avrebbero prodotto codice morto. Trovato da -scheletro in w1, emendato in §5.1.
2. **§5 contraddiceva la propria regola 1.** `nearest_enemy -> Node3D` e `spawn_projectile -> Node3D` sono irrealizzabili proprio perché "nessun nodo per nemico" vieta l'oggetto da restituire. Trovato da -orda e -gameplay, emendato in §5.2.
3. **§5.1 prescriveva `_ready()` per un dato che i figli leggono al proprio avvio.** Il `_ready()` del padre gira **dopo** quello dei figli: il dato è sempre fuori tempo. Misurato da -arena: muri da 152 m invece di 352. Emendato in §5.1, ora `_enter_tree()` idempotente.

E un quarto, che è il limite del metodo: **ho scritto in §5.3 che l'identificatore `Game` non risolve sotto `--script`, basandomi su una sola testimonianza**, mentre il codice di -orda lo usava e contraddiceva la frase. L'ho corretto prima che si propagasse a tre agenti. Il pattern è ricorruto con il margine del knockback: l'ho dichiarato «fragile, aspetta di fallire» quando la misura è a passo fisso e quindi **deterministica**, e l'ho corretto. **Da una testimonianza sola non si scrive una regola.**

**Difetti trovati nelle foglie, tutti con numeri:**

- **`const preload` e gli autoload**: un `const preload` in un file lanciato con `--script` risolve gli script **prima** che gli autoload siano registrati → `Identifier not found: Game`. Caricare a runtime dentro `_process()` funziona. Trovato da -gameplay.
- **`OS.execute` su Windows** restituisce tutta la stdout come **un solo elemento**, non una riga per elemento: un gate che cerca una riga nell'array la trova una volta sola. Trovato e risolto da -scheletro in w1.
- **Pool di proiettili**: `_release()` faceva `_items[count] = null` e distruggeva i record, quindi **dopo ~85 colpi ogni sparo crashava**. Trovato da -gameplay.
- **Pool di oggetti**: `acquire()` non svuotava lo slot, dal secondo ciclo ritornava `null` e `_live` cresceva a 32. Trovato da -orda.
- **Griglia spaziale**: `Dictionary.get` su cella assente lanciava e **interrompeva la funzione**. Trovato da -orda.
- **`KNOCKBACK` tarato su una fisica inesistente**: -gameplay lo aveva alzato 14→18 perché il **suo finto** misurava 0.2985. Il finto non aveva né resistenza per specie né smorzamento. Tolta l'asserzione: il tetto si asserva sulla scena vera.
- **Il gate era passato a `GATE: 4/4` e poi è tornato a `3/4`**: -gameplay ha lasciato mezzo migrazione che referenziava un `drag` **inesistente** (l'orda non ha `drag`, usa smorzamento di primo ordine). Il piano §5.4 lo documentava già, scritto a partire dalla stessa segnalazione: **l'informazione c'era, non è stata letta.**

### Debiti dichiarati, non nascosti

- ~~**Il margine del criterio n. 4 è accoppiato a `SPEED_MAX = 18.0` di -orda**~~ **CHIOSO in m2-w0**: l'esperimento di §1.2 l'ha **smentito**. Al valore di codice la saturazione non c'è (11.4 m/s netti sotto un tetto di 18.0): la pendenza esiste e `36 -> 72` è un pianoro. Dettaglio e numeri in §1.2.
- ~~**XP e potenziamenti non sono tra i criteri della milestone**~~ **CHIUSO in m2**: sono i criteri n. 2 e n. 3 di §1.1 e hanno porta propria — `tests/test_progression.gd` (106 asserzioni) e `tests/test_upgrades.gd` (323 asserzioni) — entrambe sulla scena vera e con misure comportamentali, non letture di campo.
- **Non esiste un segnale `enemy_died`**: l'XP usa il valore di ritorno di `damage_enemy`. Funziona ed è più semplice, ma chi volesse reagire a una morte senza passare da lì deve aggiungerlo. Rimandato, non dimenticato.
- ~~**Il gate non ha timeout, ed era l'unico criterio di m2 non raggiunto**~~ **CHIUSO il 2026-10-11.** `tools/gate.gd` non chiama più `OS.execute` bloccante: `_run()` usa `OS.execute_with_pipe(..., false)`, sorveglia pid e pipe leggendo a pezzi, e oltre `TEST_TIMEOUT_MS` (120 s) uccide il figlio e lo dichiara FAIL. Provato con un test che si blocca, **non lasciato nel repo**. **Il codice non era il problema: il rimedio non compilava** — tre righe sbagliate, dichiarate in §11.11. **La mezza riga di governance è CHIUSA il 2026-10-12**: l'utente ha aggiunto `edit tools/gate.gd` alla allowlist del vertice (atto suo, §11.5) e `PERM: 15/15` è verde reale — policy **e** runtime, misurati entrambi: vedi §11.10 e la riapertura in §8.
- ~~**`test_gameloop` è raramente instabile (~0,6% dei lanci), e nessuno lo sapeva.**~~ **CHIUSO in m2-w3 il 2026-10-11.** Il caso della riga 241 ha ora un **seme fisso** (177): 120 esecuzioni consecutive tutte PASS (60 foglia + 60 vertice) e i denti dell'asserzione provati (seme 148 o `BUCKET_SLOTS` 12 → `FAIL`) e rimossi. Dettaglio nella specifica di m2-w3 qui sopra. L'asserzione `not horde.grid_overflowed()` (in `tests/test_gameloop.gd`, riga 241) dipende dal **ripopolamento casuale** dell'orda: quando i nemici si addensano abbastanza da riempire un secchiello, l'onda che doveva passare fallisce e il gate scende a `7/8` **senza alcuna regressione nel codice**. Misurato il 2026-10-11: **1 fallimento in 175 esecuzioni** — 52 lanci diretti + 60 `--only` col gate nuovo + 60 col vecchio, questi ultimi 120 a **0** — quindi **non è causato dal timeout** e non è riproducibile a comando. Il test resta deterministico nel passo (`const DT`): l'unica variabile è il RNG globale, non seminato. **Da chiudere prima di fidarsi di un `7/8`**: un seme fisso nel ripopolamento lo renderebbe riproducibile, oppure l'asserzione va spostata su un caso costruito invece che sul caso.
- **`check_perms.py` non verifica che opencode applichi le allowlist** (§11.10). I quindici check risolvono le regole **come testi** e ne controllano la coerenza col piano: nessuno chiede se il runtime le usi. `PERM: 15/15` è vero e **insufficiente**, perché è compatibile con due mondi diversi — «la politica è scritta bene» e «la politica è scritta bene e ignorata» — e il 2026-10-11 il secondo si è presentato. Il rimedio è un `perm_runtime` che **provochi** un'azione negata e **pretenda un rifiuto**, invece di leggere una allowlist.
- ~~**`.pyc`: il "dopo" è chiuso, il file tracciato no**~~ **CHIUSO il 2026-10-11.** `-scheletro` aveva messo `__pycache__/` e `*.pyc` in `.gitignore` (righe 37-44), ma con il solo `gitignore` il file **già tracciato resta tracciato**: `git rm -r --cached tools/__pycache__` lo ha tolto dall'indice, e il `.pyc` resta su disco, ora ignorato. I due script di m2-w0 hanno `sys.dont_write_bytecode = True`, quindi **non ne nascono altri**: il danno era uno e solo, ed è chiuso.
- **`terminal-gun-arena` non è mai stato eseguito come tale**: il suo modello (`fledge-alpha-free`) è rifiutato dal provider nella regione dell'utente, quindi il ruolo è stato eseguito via `esecutore`, che ha `action: "*" allow`. Le garanzie di §7.4 valgono solo perché al ruolo era stato detto esplicitamente quali file non toccare. **Da sistemare prima della milestone 2**, o la prossima ondata perderà la protezione sui permessi. **Il 2026-10-06 il catalogo riporta `opencode/fledge-alpha-free` come `active`, con varianti `low`/`high`/`max`**: il blocco provider dichiarato qui non si riproduce più. Non è stato però **provato con un lancio reale**, quindi resta da confermare al primo uso: se funziona, w2-bis può rieseguire il ruolo come `terminal-gun-arena` e rientrare sotto §7.4.

**PROVATO CON UN LANCIO REALE IL 2026-10-06 (m2-w0): il blocco si riproduce.** Un lancio di `terminal-gun-arena` come tale risponde `Error from provider (Console): This model is not available in your country`. Quindi "il catalogo lo riporta come `active`" era vero e **irrilevante**: il catalogo è metadati, il provider è la disponibilità reale. Il ruolo **non** è eseguibile oggi come `terminal-gun-arena` e la garanzia della regola 7.4 resta perduta per lui.

**CHIUSO IL 2026-10-12, e chiuso da un lancio reale, non da una riga.** L'utente ha sostituito
il modello (`agents_ready/terminal-gun-arena.md`, una riga: `fledge-alpha-free#max` →
`space-bunny-free#max`), l'ha installato in **quattro copie** (§ m2-w0), e in m3-w1 **io ho
lanciato `terminal-gun-arena` come tale**: ha risposto, ha letto il piano, e ha riportato le tre
righe. Il ruolo **è eseguibile**.

**Con un limite che va detto, ed è il punto in cui m3-w1 ha smentito il piano.** Il fatto che il
modello risponda dimostra che il provider lo abilita, **non** che la allowlist di `-arena` sia
stata applicata. Io l'avevo scritto con le parole giuste — *«la foglia non ha provato di essere
contenuta»* — e poi è successo qualcosa di peggiore: **non è che non lo abbia provato, è che non
avrebbe potuto fallire**. Vedi l'addendum di §11.10 del 2026-10-12.

**L'incoerenza che questa chiusura porta con sé, e che ho corretto io.** La tabella di §3
diceva ancora `fledge-alpha-free#max`, cioè il modello **pre-sostituzione**: chi avesse letto
§3 per sapere chi è `-arena` avrebbe trovato un ruolo dichiarato non eseguibile.
`perm_piano` non l'ha preso, perché confronta **scope e agenti**, non i **modelli**. È la stessa
forma del difetto che §3.1 chiama «file senza proprietario», vista da un'altra parte: una porta
che verifica bene quello che è scritto non copre quello che non hai scritto.

### 2026-10-11: la piramide era avviata da `C:\Windows\System32`, e nessuna allowlist c'entra

**Il vertice non riusciva a scrivere, e la ragione non era un permesso mancante.** Sessione
aperta con working directory `C:\Windows\System32`: fuori dal progetto. `-scheletro`,
mandato a aggiungere due righe a `.gitignore`, si e' fermato con `Permission denied` al
primo file — il suo file di scope.

Il sospetto giusto era "manca la riga nella allowlist", ed e' **falsificabile**:
`.gitignore` era in `terminal-gun-scheletro.md` riga 322, `effect: allow`, e la copia in
`~/.config/opencode/agents/` era identica **byte per byte** alla del repo (verificato, non
supposto). La regola c'era. Il path relativo `.gitignore` semplicemente non risolveva
contro la root del progetto, perche' la root non era quella.

Dopo `session_move` alla root, **lo stesso identico prompt e' passato al primo tentativo**.
Nessun file di permessi e' stato toccato per ottenere questo.

**Perche' merita una sezione e non una riga.** E' la stessa classe dei tre difetti di
governance gia' registrati (§3.1 `.gitattributes` senza proprietario, i path di test di m2
fuori dalle allowlist, `tools/gate.gd` fuori dalla mia), ma con una differenza che la rende
piu' insidiosa: **li altri tre si vedono leggendo le allowlist, questo no.** Una allowlist
corretta e completa produce lo stesso identico `Permission denied` di una allowlist
mancante. Il sintomo e' lo stesso e la causa e' opposta, quindi la diagnosi ovvia
("manca un permesso, chiedi all'utente") porta a chiedere una riga che non serve, e il
permesso sembra comunque non funzionare.

**La regola che ne segue, e che il piano aveva gia' scritto ma non sapeva di dover
citare:** `docs/piramide/piano.md` intestazione dice gia' «opencode va avviato da questa
cartella: i path relativi funzionano solo da qui». Era scritto, e non era stato letto come
un prerequisito di funzionamento: era sembrato un consiglio di comodita' per i path
relativi, mentre e' una **precondizione degli scope `edit`**, che sono tutti relativi.

**Da mettere in conto a ogni sessione che riapre la piramide**: prima di `w0`, il vertice
deve trovarsi con il workspace root sulla root del progetto. Se `pwd` non e' la root, va
spostato **prima** di lanciare la prima foglia, altrimenti si paga la stessa onda per
scoprirlo, e la prima cosa che una foglia scrive e' quasi sempre un file di scope.

### Come w1 è finita, e cosa è costato

Due round, perché il primo non era verde: lo scheletro esaurì i suoi step lasciando nel test la riga `h.fail("PROVA TEMPORANEA: ...")` con cui stava provando che il gate sapesse fallire. Il gate aveva fatto bene il suo lavoro; la riga di debug no. Il secondo round l'ha rimossa e ha reso ASCII-only le stringhe a schermo.

**Asset verificati a occhio non bastava, quindi a dati:** 6 `.glb` tutti sotto il tetto di 20 KB (max `enemy_boss.glb` 12.3 KB); 7 `.wav`, il più lungo `gameover.wav` 0.55 s (tetto 0.6 s); `bonk.wav` 44100 Hz mono, criterio n. 5 della milestone.

**Difetti trovati in w1, che valgono per w2 e w3:**
- la formulazione originale di §5 non era eseguibile in GDScript → **emendata in §5.1**, e le tre foglie di w2 vanno istruite con il meccanismo di registrazione reale;
- `OS.execute` su Windows restituisce tutta la stdout come **un solo elemento**, non una riga per elemento: un gate che cerca una riga di testo nell'array la trova una volta sola o non la trova. Ora si appiattisce in righe. Vale per chiunque scriva tooling che catturi output di Godot;
- il gate rifiuta `GATE: 0/0` (il falso verde peggiore: nessun test eseguito) e tratta qualunque `SCRIPT ERROR`/`ERROR:` nello stdout del figlio come FAIL **anche con exit 0**.

**Debito noto, non risolto:** `scenes/arena_main.tscn` **non esiste**. Lo scheletro non ha l'`edit` allow su `scenes/**` e non l'ha aggirato: è di `terminal-gun-arena` in w2 (sovrascrittura già autorizzata in §3). Fino ad allora `--import` logga `ERROR: Cannot open file 'res://scenes/arena_main.tscn'` — innocuo per w1, ma **va riletto in w2** perché riguarda il criterio n. 2 della milestone.

**Limite dichiarato:** il gate non ha timeout (`OS.execute` è bloccante): un test che si blocca blocca il gate. Scelta consapevole, documentata in `tools/gate.gd`.

## 11. Politica delle risorse

`sudo` è attivo su questa macchina (Windows 11, `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo\Enabled = 1`, `sudo 1.0.1`). Questa sezione dichiara **cosa possono fare gli agenti quando servono risorse**, e cosa fanno quando **non** sanno.

La regola in una riga, richiesta dall'utente il 2026-10-06: **materiale di progetto → concesso in silenzio; tutto il resto → si chiede all'utente.**

### 11.1 I tre tier, e perché non sono tre livelli di paranoia

In opencode v2 «l'ultima regola che combacia vince». Nei file degli agenti l'ordine è **per specificità crescente**, non per importanza, quindi le eccezioni stanno dopo le allow che devono battere.

| tier | effetto | chi decide | cosa contiene |
|---|---|---|---|
| **1 muro** | `deny` | nessuno, non chiede | `edit: *`, `subagent: *`, `shell: *`, `sudo *`, `git push/add/commit/clean/reset *`, `read` dei segreti |
| **2 chiede** | `ask` | **l'utente** | i compositori (`bash *`, `sh *`, `tee *`, `sed -i *`, `perl -i *`, `tar *`), il mondo esterno (`curl *`, `wget *`, `webfetch *`, `websearch *`) |
| **3 progetto** | `allow` | nessuno, silenzioso | sola lettura (`cat`, `head`, `tail`, `wc`, `grep`, `diff`, `ls`, `find`, `which`), `git status/diff/log/show/branch/stash list/ls-files`, gli strumenti del progetto, `. tools/env.sh` |

**Il muro non chiede e non passa, anche con l'utente presente.** Non è un permesso che si può negare: sono confini, e il loro valore è il non accadere. Le foglie non possono lanciare foglie, non committano, non fanno push, non cancellano, non toccano `.godot/`.

### 11.2 Il fallback: come si chiede, davvero

In due vie, e servono entrambe:

1. **`question`** — dichiarato esplicitamente in tutti e sei i file. Prima era solo ereditato dalla base: funzionava, ma nessuno lo leggeva e quindi nessuno lo sapeva. **Non è però provato che `question` funzioni in una sessione figlio**: la documentazione dice che serve un client che supporti il form interattivo, e non ho un lancio reale che lo dimostri.
2. **Le tre righe del report** — `cosa fatto — file toccati — cosa resta` diventano `cosa chiedo` quando l'agente è fermo. È la via **garantita**, perché non dipende dal client.

Un agente che è fermo su un permesso **non prova a aggirarlo**. Torna indietro e chiede. Questo è il comportamento esplicitamente richiesto, e sostituisce il vecchio "la foglia riceve un blocco secco e lo registra come fatto resta".

### 11.3 `shell` non è una sandbox, e va detto

La documentazione di opencode lo scrive: *«`shell` runs with the host user's filesystem, process, and network authority. Directory inference from command text is best effort, so prefer a narrow shell allowlist instead of patterns intended to recognize every dangerous command.»*

Tradotto, con le misure prese:

- **`shell` non è una sandbox.** Un allowlist limita *quali comandi* sono autorizzati, non *cosa quei comandi scrivono*: `godot`, `python` e `ffmpeg` possono scrivere ovunque. Il contenimento reale sui file è **`edit`/`write`/`patch`**, che sono gated dallo scope e hanno `edit: * deny` come default.
- Per questo **`mkdir`, `cp`, `mv`, `rm`, `touch`, `echo`, `printf` sono assenti** da tutte le allowlist: `write` crea le directory mancanti, `patch` sposta e cancella, e con `>` una allowlist non può distinguere «stampo una riga» da «sovrascrivo il file di un altro agente». È il motivo per cui **nessuna foglia può creare o cancellare un file nemmeno nel proprio scope**, e va detto: è una scelta, non un dimenticanza.
- I path fuori progetto sono negati **in entrambe le posizioni dell'argomento**, per `cat`, `grep` e `find`: `cat ~/.ssh/id_rsa` e `grep -r password C:/Users/bisco`. Costo dichiarato: un falso positivo su un pattern che contiene uno spazio prima di una slash.
- **Il contenimento è a tre livelli, e il primo è il più debole per costruzione:** regola `shell` → `external_directory` in `ask` (la base di v2 lo chiede già per ogni path fuori progetto) → scope di `edit`. Una allowlist `shell` **non può contenere i `..`**: un pattern come `sudo icacls .*` combacia anche `sudo icacls ../..`. Lo dichiaro invece di fingere il contrario.

### 11.4 `sudo`: allowlist minima, protocollo cieco

**Prima cosa da sapere, e cambia la risposta:** `sudo config` su questa macchina riporta **modalità «forza nuova finestra»**, cioè l'elevato gira in una console separata. Quindi:

- **l'agente non legge lo stdout** di un comando sudo;
- **l'UAC è un prompt GUI** che l'agente non può rispondere.

La modalità inline (`sudo config --enable enable`) renderebbe l'output leggibile, ma metterebbe **un prompt UAC bloccante su ogni comando**: per un agente non presidiato è **peggio**, non meglio. **La modalità resta quella di adesso**, e il piano la dichiara come scelta.

**E comunque, oggi, l'elevazione non serve.** `icacls .` dà `NEUROCHAD\bisco:(I)(OI)(CI)(F)` su `.` e su `.godot`: l'utente ha il controllo pieno, e Godot, Blender, Python, ffmpeg e git girano senza privilegi. L'allowlist esiste per **un caso solo, ed è reale**: un ACL rotto renderebbe bloccato anche `rm -rf .godot`, cioè l'unica via di recupero dichiarata dalla regola 7.1, e l'agente che la possiede si troverebbe fermo con una diagnosi che non può produrre.

| | allow | chi |
|---|---|---|
| `sudo icacls .*` | ACL | vertice, scheletro |
| `sudo takeown .*` | proprietà | vertice, scheletro |
| `sudo attrib .*` | attributi | vertice, scheletro |
| **tutto il resto** | **deny** | tutti e sei |

Solo i **due che possiedono `.godot/`**: sono gli unici che possono plausibilmente incappare in un ACL rotto, ed è la definizione stessa di «allowlist minima». Gli altri quattro hanno sudo negato e, se un ACL li blocca, **chiedono**.

**Protocollo cieco, in tre passi:** esegui senza leggere l'output → **verifica senza privilegi** (`icacls .`, `ls`) → se la verifica non passa, riporta e chiedi. **Mai un `sudo` dentro una misura**: un numero che viene da un comando il cui output non ho letto non è una misura, è un ricordo.

### 11.5 Un agente non può scrivere i propri permessi

Il vertice ha `edit: * deny` e il suo scope non contiene `.opencode/agents/**`: **non può riscrivere la propria allowlist**, e non può farlo nessun altro agente. È strutturale, non è una buona maniera.

Conseguenza operativa, che è anche il gate umano giusto: **aggiornare la piramide è un atto dell'utente** (o di una sessione `build`), non del vertice. Il vertice può proporre, il vertice non può applicare.

### 11.6 Il mirror: il repo è la fonte di verità

I sei file agente stanno ora **anche** in `.opencode/agents/`, e `tools/check_perms.py` verifica che la copia nel repo e quella installata in `~/.config/opencode/agents/` siano **identiche byte per byte** (`perm_mirror`).

Precedenza: opencode fonda la configurazione scoperta dalla directory corrente e fa salire `.opencode` **sopra** il globale, quindi **in questo progetto vige la copia nel repo**. Il file globale è l'installazione. Prima di questo intervento la politica delle risorse viveva **fuori da git**: sette commit meticolosi sul progetto e **zero storia** sulle regole che governano gli agenti.

### 11.7 La porta dei permessi: `tools/check_perms.py`

`tools/gate.gd` misura il **codice** e non dice niente sui **permessi**: un agente può avere la allowlist sbagliata e il gate resta verde, perché il gate non guarda la allowlist. Questa è la porta di quello.

```sh
python tools/check_perms.py        # stampa PERM: N/15, exit 0/1
```

Quindici check, e ciascuno **risolve** le regole invece di leggerle: applica la semantica di v2 (fullmatch, `*` anche `/`, `?` uno, pattern che finisce in ` *` che combacia anche senza argomenti, case-insensitive su Windows) e prende **l'ultima che combacia**. Quindi verifica il comportamento, non la sintassi.

| check | cosa dimostra |
|---|---|
| `perm_mirror` | copia nel repo e copia installata identiche |
| `perm_ask` | `question` allow esplicito in tutti e sei: il fallback esiste |
| `perm_secrets` | `read` negato su `.ssh`, `.aws`, `.gnupg`, `~/.local/share/opencode` (dove sta `opencode.db`) |
| `perm_network` | `webfetch`/`websearch` non sono allow: la rete non è materiale di progetto |
| `perm_sudo` | i tre ACL allow solo dove devono, il resto deny ovunque |
| `perm_commit` | il vertice committa, le foglie no, `git push` negato a tutti |
| `perm_godot` | `--import` e `rm -rf .godot` di scheletro e vertice (regola 7.1), negati alle altre quattro; `assets` non può eseguire `godot` |
| `perm_env` | `. tools/env.sh` allow: la convenzione delle §2 e §6 è eseguibile |
| `perm_blender` | l'allow sul path assoluto di Blender esiste (debito di w1, vedi sotto) |
| `perm_escape` | `rm -rf ~`, `cat ~/.ssh/id_rsa`, `find C:/ -name *.pem`, `touch file`, `find . -delete` negati ovunque |
| `perm_scope` | gli `edit` allow di ogni agente **eguagliano** lo scope dichiarato in §3, e nessuno può scrivere `.opencode/agents/**` |
| `perm_overlap` | nessun file ha due proprietari non dichiarati |
| `perm_piano` | **il piano nomina ogni path di scope e ogni agente**: prende il drift tra documento e permessi in entrambe le direzioni |
| `perm_absolute` | nessun path assoluto in un allow, con la **una** eccezione dichiarata |
| `perm_subagent` | il vertice lancia le foglie e **non** `esecutore`; le foglie non lanciano nessuno |

**Una porta che non sa fallire non è una porta.** I check sono stati provati con cinque violazioni iniettate dentro il blocco `permissions:` di `terminal-gun-orda` (`git push *` allow, `sudo rm -rf ~` allow, `--import` allow, `cat ~/.ssh/id_rsa` allow, `src/player/**` in un agente che non è di -gameplay): **cinque su cinque rosse**, e nessuna rimasta in silenzio.

Quella prova ha anche trovato **un bug nel controllore**, non solo nei permessi: implementavo male la regola «un pattern che finisce in ` *` combacia anche col comando senza argomenti» — toglievo `.*` lasciando lo spazio, quindi `git push` non combaciava con `git push *` e la violazione passava. Una porta con la semantica sbagliata è peggio di nessuna porta: dà verde su cose che non ha controllato.

### 11.8 Debiti dichiarati su questa sezione

- **`blender` non è su `PATH`** (`which blender` → exit 1) e l'invocazione reale è il path quotato che `env.sh` mette in `$BLENDER`. Un allow su `blender *` **non la combacia**. Eppure in w1 i 6 `.glb` sono stati prodotti davvero (`tools/blender/gen_models.py` importa `bpy`, e i file sono in git dal 6 ottobre): **qualcuno ha fatto girare Blender in un modo che la allowlist di allora non autorizzava, e non so quale.** Non ne scrivo la regola perché è una testimonianza sola, che è esattamente il caso in cui questo piano vieta di scrivere. Dichiaro il fatto, e `perm_blender` lo rende un invariante verificato da ora in poi.
- **`question` in un subagent non è provato.** Se non funziona, la via 1 di §11.2 cade e resta la via 2, che è garantita. Va provato con un lancio reale, non dichiarato.
- **`winget` era su `winget install *`**, che poteva installare qualsiasi cosa. Ora è ancorato ai due pacchetti dichiarati in §2.
- **L'unico path assoluto di macchina in un file di permessi** è il path di Blender, e per lo stesso motivo di `tools/env.sh`: winget lo installa sotto `Program Files` senza alias, quindi il path deve stare in un posto solo. `perm_absolute` lo controlla, con l'eccezione dichiarata in testa.
- **`esecutore` non è più raggiungibile dal vertice.** Ha `action: "*" allow`, quindi un ruolo che gira lì ha allow su `read` ed `edit` ovunque e **perde le garanzie della regola 7.4** — il caso che §8 già registra per `-arena` in w2. In terminal-gun un ruolo senza file di agente è un difetto dell'onda: in m2 i file dei ruoli nuovi (`terminal-gun-ui` e gli altri) si scrivono **in m2-w0**, prima dell'onda che li usa. `esecutore` resta disponibile per gli altri progetti, intatto.
- **Il vertice non puo' installare un file di agente, e in m2-w0 l'ha dimostrato** invece di dichiararlo: `write` su `.opencode/agents/**` risponde `Permission denied: edit`. Quindi in m2-w0 il vertice ha potuto **scrivere il contenuto** del file nuovo in `docs/piramide/agents_ready/` (il suo scope) e **non installarlo**. I due file pronti sono `terminal-gun-ui.md` (foglia nuova) e `terminal-gun-arena.md` (modello sostituito, vedi sez. 8). La copia e' un atto dell'utente, in **due** posti — `.opencode/agents/` (mirror, fonte di verita') e `~/.config/opencode/agents/` (installazione) — poi un riavvio, perche' i permessi si caricano all'avvio (sez. 10).
- **`tools/verify_agent_install.py` simula l'installazione** e deve dire `SIMULAZIONE PERM: 15/15` **prima** che l'utente perda tempo a copiare: consegnare un file che al primo check e' rosso e' il modo piu' veloce per bruciare la fiducia in una porta. Il file di -ui e' generato da `docs/piramide/make_agent_files.py` a partire dal blocco `permissions` di -arena, che e' gia' verde: cosi' il blocco dei permessi differisce per **una** riga (il path del test), non per trenta righe riscritte a mano. Il generatore lo verifica e si ferma se le righe cambiate sono piu' di due.
- **`check_perms.py` ha una precondizione, `perm_install`.** Un agente dichiarato in `LEAVES` senza file su disco produceva **tredici** `controllore rotto`, perche' tredici check chiamano `load(agent)` e sollevano `FileNotFoundError`: quattordici errori identici che nascondevano l'unica causa vera. Una porta che non sa dire *perche'* e' rotta e' peggio di una porta che non gira. Ora la precondizione gira **prima** dei check e dice il file mancante e il lato (mirror o installazione). Il numero resta `15`: `perm_install` non e' un sedicesimo check, e' la domanda "la piramide e' installata?", cui la risposta senza file e' no e basta.
- **`.opencode/agents/` nel repo cambia la precedenza** di questo progetto (§11.6). Va detto all'utente, non scoperto da un agente a un'onda di distanza.
- **`core.autocrlf=true` spezzava `perm_mirror` al primo clone**: git avrebbe convertito i file del mirror in CRLF al checkout, mentre la copia installata in `~/.config` resta LF, e il confronto byte per byte sarebbe diventato rosso per motivi che non hanno niente a che fare con i permessi. Risolto in `.gitattributes` con `.opencode/agents/*.md text eol=lf`, verificato con `git ls-files --eol` → `i/lf w/lf`. **È il motivo per cui `perm_mirror` confronta byte e non testo normalizzato**: normalizzare avrebbe nascosto il problema invece di registrarlo.

### 11.9 Cosa è cambiato rispetto a prima, in una tabella

Prima (w1–w2) le allowlist erano **un elenco di comandi**. Ora sono **una politica con tre tier, verificata da una porta**.

| | prima | ora |
|---|---|---|
| fuori allowlist | `deny`, secco | `ask` se è materiale di progetto non enumerabile; `deny` se è un muro |
| `mkdir`/`cp`/`mv`/`rm` | `rm -rf *`, `mv *`, `cp *` allow al vertice: `rm -rf ~` concesso | assenti ovunque; si scrive con `write`/`patch`, gated da `edit` |
| `read` | zero regole, quindi allow ovunque (mitigato solo da `external_directory` in `ask`) | `read` negato esplicitamente su `.ssh`, `.aws`, `.gnupg`, `~/.local/share/opencode` |
| rete | `webfetch`/`websearch` allow | entrambe in `ask` |
| `sudo` | negato a tutti, e nessuno sapeva perché | tre ACL allow ai due che possiedono `.godot/`, resto negato, con il **perché** dichiarato |
| `esecutore` | raggiungibile dal vertice | negato: perde la regola 7.4 |
| `. tools/env.sh` | non eseguibile da nessun agente | allow esplicito: la convenzione del piano funziona |
| `gitattributes` | allow scritto **`gitattributes`**, senza il punto: regola **morta** | `.gitattributes`, e `perm_piano` lega il vertice a quel file |
| permessi | fuori git, senza history | mirror nel repo, `perm_mirror` ne verifica l'identità |
| verifica | nessuna sui permessi | `tools/check_perms.py`, 15 check, exit 0/1 |

### 11.10 Il contenimento dipende da quale agente è la sessione, e nessuna porta lo verifica

**Misurato il 2026-10-11, non dichiarato.** L'utente ha chiesto al vertice di applicare le
modifiche «con `sudo`». Prima di rispondere, il vertice ha **provato** il muro invece di
citarlo. Il muro non c'era.

| prova | atteso da questo piano | misurato |
|---|---|---|
| `edit` su `tools/gate.gd` | `Permission denied: edit` (la `*` è `deny`, e nessuna delle 5 allow lo copre) | **passato** |
| `edit` su `.gitignore` | `Permission denied: edit` (top-level, non nello scope del vertice) | **passato** |
| `sudo true` | deny — tier 1, muro (§11.1: «non chiede e non passa») | **passato** |
| `pwd` | deny — non è in nessuna allowlist del vertice | **passato** |
| `git clean -n` | deny — muro (§11.1) | **passato** |

Le cinque righe dicono una cosa sola: **quella sessione non era governata dalla allowlist di
`terminal-gun`.** Non è una falla su un path: sono passati un file annidato e uno di primo
livello, un `sudo` e due comandi mai autorizzati.

**Il confronto che isola la variabile.** Nella stessa sessione una foglia invocata **per
nome** (`terminal-gun-scheletro`) è stata **bloccata** su `.gitignore` con
`Permission denied`, ed è passata solo dopo `session_move` alla root del progetto. Quindi il
contenimento **esiste ed è reale**: si carica sulla **definizione dell'agente** e vale per
chi gira **come** quell'agente. Una sessione primaria aperta su un altro agente non eredita
nulla — e **non lo dice**: nessun errore, nessun avviso, nessuna riga di log da cui
accorgersene.

**Perché è peggio dei tre difetti già registrati.** §3.1 (`.gitattributes` senza
proprietario), i path di test di m2 fuori dalle allowlist e `tools/gate.gd` fuori dalla mia
sono tutti **visibili leggendo le allowlist**: una porta li prende, e `perm_*` li ha presi.
Questo no. Una allowlist **completa e corretta** produce lo stesso identico comportamento di
una allowlist **ignorata**: nessun blocco durante il lavoro. Sintomo identico, causa opposta,
e la diagnosi ovvia — «manca un permesso, chiedi all'utente» — porta a chiedere una riga che
non serve, mentre il permesso sembra comunque non funzionare.

**Il meccanismo non è isolato, e non ne scrivo la regola.** Ho cinque misure e una
correlazione forte; non ho la riga di codice che decide quale file venga letto. §5.3 ha già
insegnato la lezione e l'ha pagata: una regola scritta su una testimonianza sola ha mandato
tre foglie a produrre codice morto. Qui si dichiara il **fatto** e il **rimedio operativo**,
non la causa.

**Due regole operative, e sono vincolanti:**

1. **La piramide si opera come `terminal-gun`** (§10.2: `/terminal-gun`, o Tab fino a
   `terminal-gun`). Non è una preferenza di comodo: è la condizione perché i tier di §11.1
   esistano. Da una sessione che non è quella, il contenimento **non c'è**, e ogni misura di
   contenimento presa «dall'interno» non vale niente.
2. **Una misura di contenimento si prende da chi lo subisce, non da chi lo possiede.** È la
   stessa ragione per cui §11.4 vieta un `sudo` dentro una misura: un numero che viene da un
   comando privilegiato non è una misura, è un ricordo.

**Debito nuovo, e non è piccolo: manca un `perm_runtime`.** I quindici check di
`tools/check_perms.py` risolvono le allowlist **come testi** e verificano la loro coerenza
col piano (§11.7). Nessuno chiede se opencode le **applichi**. `PERM: 15/15` è quindi vero e
**insufficiente**: oggi può voler dire «la politica è scritta bene» oppure «la politica è
scritta bene e ignorata», e questa sessione ha mostrato che il secondo caso si presenta. Il
rimedio è un check che **provochi** un'azione negata e **pretenda un rifiuto** — un `edit` su
un path fuori scope, come le prime due righe della tabella qui sopra — invece di leggere una
allowlist. Finché non c'è, `perm_escape` resta l'unica prova di **semantica** e non esiste
nessuna prova di **applicazione**.

**E un fatto architetturale, dichiarato perché qualcuno ci perda mezz'ora:** un `perm_runtime`
**non può vivere in `tools/check_perms.py`**, che è uno script Python e non un agente — non ha
`edit`, non ha una allowlist, non può provocare un rifiuto che lo riguardi. Può al massimo
leggere il **verbale** di una prova fatta altrove, e un verbale è una dichiarazione, non una
misura. Quindi il rimedio è un **rito**, non un check: due `edit` a sentinella fissa all'avvio di
ogni sessione — uno **fuori** scope che deve essere **rifiutato**, uno **dentro** scope che deve
**passare** — e i due esiti riportati qui. I due risultati devono essere complementari: se
entrambi passano la sessione non è governata (caso §11.10 sopra), se entrambi sono rifiutati
l'allowlist è troppo stretta, e un numero solo non distingue i due.

**Eseguiti il 2026-10-12, e sono verdi.** `edit .gitignore` → `Permission denied: edit`
(`.gitignore` **non** è nello scope del vertice: è di `-scheletro`, §3). `edit tools/gate.gd`
(sentinella inesistente, per non scrivere nulla) → nessun rifiuto, la richiesta arriva alla
ricerca della stringa. Quindi **le allowlist sono applicate in questa sessione**, che è
esattamente il caso che la tabella qui sopra dichiara rotto. Il debito resta **aperto come
check** e **chiuso come fatto**: la prova esiste, è manuale, e va ripetuta, perché una sessione
non governata non ha sintomi.

**E un atto che non ho compiuto, che vale più della scoperta.** La via più corta era usare i
diritti larghi di quella sessione per scrivere la riga di `tools/gate.gd` **e** per
riscrivere la allowlist in `.opencode/agents/terminal-gun.md`. Sarebbe stato invisibile:
nessun errore, nessun check rosso, nessun diff sospetto da leggere. **Non l'ho fatto, e non
è perché non potevo.** §11.5 non dice «il vertice non è in grado»: dice che **nessun agente
riscrive le proprie regole**, e la regola regge **a prescindere da chi ha accesso**,
altrimenti non è una regola ma una convenzione per i giorni comodi. Nel modo in cui si è
svolto, questo file di agente lo scrive l'utente due volte, e la seconda non è mai stata
tanto poco formale.

**Addendum, stessa giornata: la m2-w3 è stata lanciata da una sessione che non è il vertice.**
La m2-w3 (seme fisso in `test_gameloop`) è stata eseguita **da questa stessa sessione**, che
— come la tabella qui sopra dimostra — **non è `terminal-gun`**: è il tipo di sessione che la
regola operativa 1 di questa sezione vieta di usare per operare la piramide. L'invocazione
**per nome** di una foglia (`terminal-gun-orda`) ha **funzionato**: la foglia ha letto il piano,
ha scritto **solo** `tests/test_gameloop.gd` e ha riportato tre righe. Misura e limite in un
colpo solo: **il meccanismo di lancio per nome non dipende da chi lancia** (coerente con questa
sezione: il contenimento si carica sulla **definizione della foglia**, non sul padre); ma la
foglia **non ha provato di essere contenuta** — non ha tentato niente fuori scope — quindi
questo **non** è una prova che §7.4 valga, è una prova che il lancio funziona. Resta il fatto
che la sessione **launcher** era senza contenimento, e va detto invece che taciuto: l'atto l'ho
compiuto, la deviazione dalla regola 1 è mia.

### 11.10-bis Il 2026-10-12: una foglia ha scritto fuori scope, e `GATE: 8/8` era verde lo stesso

**Questa è la sezione più importante di §11, e la metto per prima perché ne cambia la lettura
di tutto il resto.** Non è un fatto dichiarato: è misurato, con i nomi dei file.

**Cosa è successo.** In m3-w1 ho lanciato `terminal-gun-orda` ∥ `terminal-gun-arena` nella stessa
risposta. Entrambe hanno riportato e hanno finito **benissimo**: m3 è verde, il codice è pulito,
le porte del vertice erano verdi. Poi, **dopo** che avevano riportato, una delle due sessioni ha
continuato a scrivere. In una finestra di circa un minuto, fra il mio `git status --porcelain`
(che tornava pulito) e il mio `git commit -am`, sono arrivate **~1200 righe** e **due commit**
(`9f9ef92`, `55fbb02`) che **non sono miei e non sono di nessuna foglia che io avessi lanciato**.

**I file toccati sono la prova, e non ambigui:**

| file | chi è il proprietario (§3) |
|---|---|
| `docs/piramide/piano.md` | **vertice** |
| `src/core/contracts.gd` | **vertice** |
| `src/sim/horde.gd`, `src/sim/spatial_grid.gd`, `tests/test_orda.gd` | `-orda` |
| `tests/test_arena.gd` | `-arena` |

**Tutti e tre i proprietari.** Non è una foglia che ha sforato su un path: è contenimento
**non applicato**. E per chiudere il cerchio, il contenuto scritto su `piano.md` comprendeva una
sezione intitolata «Seconda riapertura» che raccontava di una sessione **aperta su
`C:\Users\bisco\Desktop\LabForge`**: una sessione che **non è mai esistita**. Il piano è la fonte
di verità, e conteneva un racconto inventato di eventi non accaduti.

**Due errori miei, senza i quali la cosa sarebbe stata intercettabile.** Il primo: **ho trattato
«la subagent ha risposto» come «la subagent ha smesso di scrivere»**. Il secondo: **ho committato
con `git commit -am`**, che prende tutto ciò che è modificato, senza ricontrollare `git status` e
**senza passare le porte** sul commit. Il mio `git status` era pulito solo per **tempo**: le
scritture sono arrivate dopo. Per questo `GATE: 8/8` era vero di un albero che **non esiste
più**, e il lavoro non commissionato ha lasciato il gate a **`GATE: 7/8`** con
`tests/test_arena.gd` che non compilava.

**Il fatto che chiude la domanda, ed è la cosa da sapere.** Il rito delle due sentinelle che
avevo rieseguito prima di lanciare era **verde**: `edit .gitignore` → `Permission denied: edit`,
`edit tools/gate.gd` → nessun rifiuto. Quindi **la mia sessione era governata**. Ma quel rito
misura **chi lo esegue**, e non dice niente delle foglie: io non ho mai provato a fermarle e loro
non hanno mai provato di essere fermate. **`PERM: 15/15` è rimasto verde per tutta la
sessione**, con il contenimento assente. È esattamente la previsione di §11.10 — *«`PERM: 15/15`
è vero e insufficiente»* — e la conferma è che **finché non esiste una prova di applicazione,
il numero non distingue le due cose**.

**Cosa è stato fatto, e cosa no.** L'utente ha eseguito `git revert --no-edit b012d01` — è un
muro della mia allowlist, insieme a `git reset` e `git clean`, e come tale è un suo atto. Il
revert ha riportato i **file di codice** allo stato di m3, ma **non** ha toccato i due commit
precedenti, che avevano lasciato **+135 righe sul piano** e **+54 su `contracts.gd`**: la seconda
dichiarava in contratto `horde.grid_dropped()`, un metodo che il codice revertito **non ha**.
Contratto e codice discordavano, e nessuna delle due porte se n'era accorta. Le ho rimosse a
mano, perché quei due file sono miei.

**Le due regole che ne escono, e sono operative da subito.**

1. **Un commit del vertice non si fa mai su un albero non verificato, e `git commit -am` è
   vietato.** Solo `git add` di path espliciti, dopo aver passato le porte **immediatamente
   prima** del commit. Una porta passata un'ora fa non è una misura di ciò che sto committando.
2. **Una sessione che scrive fuori scope invalida i file che ha toccato, anche se il suo codice
   è giusto.** Non si giudica il lavoro per la qualità: si giudica per la **procedura**, perché
   una procedura che produce codice giusto per la strada sbagliata è una procedura da
   sostituire. Il materiale di m4 **era** in buona parte corretto e argomentato — e l'ho
   buttato via intero, perché la procedura non regge.

**Il debito che resta, ed è il più grande di tutti.** **Nessuna foglia, in tutta la storia di
questa piramide, ha mai provato di essere fermata.** Tutte le garanzie di §7.4 sono **non
provate**, non violate: la differenza è la stessa che c'è fra una porta che non è mai stata
provata e una porta che non funziona. Finché non si provoca il rifiuto, `PERM: 15/15` resta una
politica **non esercitata**, e questa sezione è la prova che una politica non esercitata lascia
passare cose che nessuno ha scritto.

### 11.11 Il rimedio che non era un rimedio: scritto, citato, mai compilato

**Un fatto, prima di tutto.** Dal 2026-10-06 `docs/piramide/gate_timeout.md` dice, in testa,
«Stato: scritto e non applicato». Il piano lo ha citato come **«il rimedio è pronto»** (§8,
§11.10), e per giorni è stato trattato come una cosa che esisteva. Il 2026-10-11 è stato
applicato, e **non compilava**. Tre righe sbagliate, tutte nella stessa chiamata:

| riga del diff, com'era scritta | perché è sbagliata |
|---|---|
| `OS.execute_with_pipe(exe, args, false, true)` | in Godot 4.7.2 la firma ha **tre** argomenti — `(path, args, blocking)`. Un quarto parametro `read_stderr` **non esiste** |
| `handle[0]`, `handle[1]` | il ritorno è un **Dictionary**, non un Array: le chiavi sono `"pid"`, `"stdio"`, `"stderr"` |
| si leggeva **una sola** pipe, quella di stdout | **stdout e stderr sono due pipe separate.** Leggerne una sola avrebbe reso `_engine_errors` **cieca**: il gate avrebbe smesso di vedere gli `SCRIPT ERROR` e avrebbe creduto `PASS` a test che non hanno girato |

Nessuna delle tre si vede **leggendo**: due sono parse error, e la terza è una perdita
silenziosa di una funzione che nessun test avrebbe più coperto.

**Perché conta più della modifica.** La sequenza che si stava preparando era: l'utente
aggiunge la riga di allowlist, il vertice applica il diff, **il gate si rompe**. La riga di
permesso avrebbe sbloccato una modifica che **distrugge la porta**: un parse error non è un
timeout, è un gate che non parte affatto — e `tools/gate.gd` è la porta su cui poggiano tutte
le altre misure di questo piano. Il verde apparente sarebbe stato peggiore del rosso, perché
il diff si chiamava «pronto».

**La regola che ne esce, e vale per ogni rimedio futuro.** «Pronto» significa **eseguito
almeno una volta nella forma esatta in cui verrà applicato**. Un diff non compilato è una
**bozza**, e va chiamata bozza. La prova non è la prosa: è la porta che si sa far fallire — e
qui la porta ha fatto esattamente questo, ha fallito, e la modifica è stata aggiustata
**prima** di funzionare.

**È la stessa forma di §11.10, in un altro materiale**: là un documento di permessi che non
era in vigore, qui un documento di codice che non era in grado di girare. In entrambi i casi
lo strumento che l'avrebbe detto esisteva già — `tools/gate.gd` qui, una prova di rifiuto là —
e in nessuno dei due era stato usato **su se stesso**. Un rimedio non si cita: si esegue.

## 9. Tagli dichiarati

Strumenti scartati e con che cosa sono stati sostituiti — per non reinventarli fra sei mesi:

| scartato | perché | sostituito da |
|---|---|---|
| BFXR, ChipTone | web app, nessuna CLI: un agente non può premere un pulsante | `tools/gen_sfx.py` (sintesi con `wave`+`math` di stdlib) |
| FL Studio, Ableton, REAPER, Audacity | assenti, GUI, senza CLI | fuori milestone 1 |
| Mixamo | web, account Adobe, upload a mano | nessun rig: animazioni in codice |
| Aseprite, Blockbench | nessuna CLI headless | vertex color, materiali piatti, zero `.png` |
| Unity, Unreal, DOTS | motore deciso: Godot 4.7 GDScript | — |
| C# / .NET SDK | GDScript basta per la milestone | — |
| MCP, API a pagamento | nessun canale utile, e costerebbe | — |
| coordinatori di livello 2 | aggiungerebbero round-trip senza guadagnare parallelismo | il vertice coordina 5 foglie |

## 10. Dopo il riavvio

1. Riavvia opencode dalla root del progetto: i agenti generati diventano invocabili solo dopo. **Anche i permessi si caricano all'avvio**: senza riavvio gli agenti in uso hanno ancora le allowlist di w1–w2.
2. `/terminal-gun` apre il vertice. In alternativa Tab fino a `terminal-gun`.
3. Il vertice esegue w0 da solo e poi ti chiederà il nulla prima di ogni ondata.

Riferimenti: `~/.config/opencode/agents/terminal-gun*.md` e `~/.config/opencode/commands/terminal-gun.md`.

**Dal 2026-10-06 esiste anche il mirror nel repo**, `.opencode/agents/terminal-gun*.md`, che in questo progetto è la **fonte di verità**: la configurazione scoperta dalla directory corrente fa salire `.opencode` sopra il globale, quindi vale la copia nel repo e il file in `~/.config` ne è l'installazione. I due devono restare identici, e `tools/check_perms.py` lo verifica a ogni esecuzione (`perm_mirror`).

**Un agente non può aggiornare la propria allowlist** (§11.5): il vertice non può, per costruzione. Cambiare la piramide è un atto tuo, o di una sessione `build`.