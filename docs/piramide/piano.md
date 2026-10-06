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
| 4 | Il player spara e uccide | test gameplay: danno applicato una volta sola, knockback ≥ 0.3 unità |
| 5 | Si sente il "bonk" | `assets/sfx/bonk.wav` esiste, < 0.6 s, 44100 Hz mono |
| 6 | Niente binari nel Git normale | `git lfs ls-files` elenca `.glb` e `.wav` |

Fuori milestone 1, dichiarato: colonna sonora, menu, salvataggi, boss con fasi, multiplayer, mobile.

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
| `terminal-gun-arena` | `fledge-alpha-free#max` | `scenes/arena_main.tscn`, `scenes/hud.tscn`, `src/render/`, `src/ui/`, `tests/test_arena.gd` | `src/sim`, `src/player`, `src/weapons`, `project.godot`, `.godot/` |
| `terminal-gun-assets` | `muse-spark-1.3-contributor-free#high` | `tools/gen_sfx.py`, `tools/blender/gen_models.py`, `tools/convert_assets.sh`, `assets/` | `src/`, `scenes/`, `project.godot`, `tools/env.sh`, non esegue mai `godot` |
| `terminal-gun` (vertice) | `space-bunny-free#max` | `docs/piramide/piano.md`, `src/core/contracts.gd`, `tools/env.sh` | il codice del gioco |

Sovrascrittura **autorizzata e unica**: `scenes/arena_main.tscn`, segnaposto di scheletro (w1) → scena reale di arena (w2). È dichiarata qui perché ogni altro file è creato una volta sola.

## 4. Onde

| onda | chi | parallelismo | finisce quando |
|---|---|---|---|
| **w0** | vertice, solo shell | — | Godot e Blender installati, `tools/env.sh` scritto, `git init` + LFS configurati |
| **w1** | scheletro ∥ assets | 2 agenti, una stessa risposta | `godot --headless --path . --import` esce 0 e il gate dice `GATE: 1/1` |
| **w2** | orda ∥ gameplay ∥ arena | 3 agenti, una stessa risposta | gate dice `GATE: 4/4` e `--quit-after 300` è pulito |
| **w3** | vertice | — | commit fatto e verdetto riportato all'utente |

w1 e w2 hanno parallelismo **vero**: scope disgiunti e nessuna dipendenza di file. w2 ha una sola dipendenza (lo scheletro di w1): se `src/core/contracts.gd` non esiste, w2 non parte.

## 5. Contratto di interfacce

Vive in `src/core/contracts.gd` (autoload `Game`). **Il contratto dichiara, le implementazioni si registrano**: ogni foglia scrive `Game.<campo> = self` una volta sola nel proprio `_ready()`, e non chiama mai il costruttore di un'altra foglia.

```gdscript
var player: Node3D
var horde: Node            # src/sim/horde.gd
var arena_radius: float = 28.0
func nearest_enemy(from: Vector3, radius: float) -> Node3D
func damage_enemy(index: int, amount: float, knockback: Vector3) -> void
func spawn_projectile(pos: Vector3, dir: Vector3, speed: float) -> Node3D
func random_spawn_point() -> Vector3
func player_position() -> Vector3
```

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
```

Il gate (`tools/gate.gd`) esegue ogni `tests/test_*.gd` in un **processo separato** e decide sul codice di uscita: `0` solo se tutti passano. Ogni test stampa `PASS <nome>` o `FAIL <nome>: <motivo>` e finisce con `quit(0)`/`quit(1)`; un test assente è `SKIP`, non un fallimento.

Regola di oro: **nessun agente "finisce" perché ha scritto il codice**. Finisce quando la porta dice verde.

## 7. Regole anti-race

Cinque agenti scrivono nella stessa cartella **in parallelo**. Queste regole sono ciò che separa un'ondata da un disastro:

1. **`.godot/` è di `terminal-gun-scheletro`.** Nessun altro esegue `--import`. In caso di cache corrotta: `rm -rf .godot` e re-import (solo scheletro, o vertice).
2. **Il commit è del vertice.** Nessuna foglia esegue `git add` o `git commit`.
3. **`winget` mai in parallelo**, e solo in w0: winget ha un lock globale.
4. **Scope sui permessi, non sulle buone maniere.** Ogni foglia ha in `permissions` una deny su `edit *` e un allow sui propri file: se sfora, il sistema glielo blocca.
5. **Niente path assoluti di macchina** nei file prodotti, con una sola eccezione: `tools/env.sh`, che esiste proprio perché i path stiano in un posto solo.

## 8. Stato

Da aggiornare a fine onda. **w0 fatta. w1 in attesa.**

| onda | agenti | esito | gate | stato |
|---|---|---|---|---|
| w0 | vertice | Godot 4.7.2 + Blender 5.2.2 installati, `tools/env.sh` scritto, `git init` + LFS su `*.glb`/`*.wav`/`*.ogg`, identità git impostata **localmente** (`bisco <bisco@localhost>`: non c'era nessuna, né locale né globale) | — | **verde** |
| w1 | scheletro, assets | — | — | da fare |
| w2 | orda, gameplay, arena | — | — | da fare |
| w3 | vertice | — | — | da fare |

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

1. Riavvia opencode dalla root del progetto: gli agenti generati diventano invocabili solo dopo.
2. `/terminal-gun` apre il vertice. In alternativa Tab fino a `terminal-gun`.
3. Il vertice esegue w0 da solo e poi ti chiederà il nulla prima di ogni ondata.

Riferimenti: `~/.config/opencode/agents/terminal-gun*.md` e `~/.config/opencode/commands/terminal-gun.md`.
Questi file **non** sono copiati dentro `.opencode/agents/` perché il progetto non specchia i propri agenti: se un giorno lo farà, vanno copiati lì identici per la portabilità.