# `tools/gate.gd`: timeout per test — applicato il 2026-10-11

**Stato: applicato e verificato, con tre correzioni al diff originale.** Il vertice ha
applicato la modifica al gate il 2026-10-11. Il **diff che questo file conteneva dal
2026-10-06 non compilava**: tre righe sbagliate, tutte descritte sotto. Le correzioni sono
in `tools/gate.gd` (vedi git), non in questo file.

Questo documento chiude il **criterio n. 6 di m2** e il debito di m1 «il gate non ha
timeout». Resta **una mezza riga di governance**, in fondo: la allowlist del vertice.

## Il diff originale, e perché non compilava

Il diff del 2026-10-06 partiva da un'API che **non è quella di Godot 4.7.2**. Applicato
così com'era, `tools/gate.gd` non si caricava: **`Parse error`**, gate assente, non un
timeout mancato. Tre errori, tutti nella stessa chiamata:

| com'era scritto | com'è davvero (Godot 4.7.2) |
|---|---|
| `OS.execute_with_pipe(exe, args, false, true)` | la firma ha **tre** argomenti: `execute_with_pipe(path, args, blocking = true)`. **Nessun** `read_stderr` |
| `var pid = handle[0]`, `var pipe = handle[1]` | il ritorno è un **Dictionary**: `{ "pid": int, "stdio": FileAccess, "stderr": FileAccess }` |
| si leggeva solo la pipe di stdout | **stdout e stderr sono due pipe separate.** Leggerne una sola rende `_engine_errors` cieca: il gate smette di vedere gli `SCRIPT ERROR` e crede `PASS` a test che non hanno girato |

Le prime due sono parse error (si vedono subito). La terza è **silenziosa**: sarebbe passata
le prove di un gate verde, togliendo di nascosto il controllo più importante che il gate ha.
Per questo qui sotto la stderr si legge **dalla sua pipe** ed è provata con un test che
emette un errore.

La lezione è registrata nel piano, §11.11: **un rimedio «pronto» che non è mai stato
compilato è una bozza.** Questo lo era.

## Cosa fa il codice applicato

`tools/gate.gd`, funzione `_run()` (`return OS.execute(...)` non c'è più):

- lancia il test con `OS.execute_with_pipe(exe, args, false)` — **non bloccante**;
- dal `Dictionary` prende `pid`, `stdio` (stdout) e `stderr`, e **legge entrambe**, ogni
  `POLL_MS = 5 ms`, mentre `OS.is_process_running(pid)` dice se il figlio è vivo;
- oltre `TEST_TIMEOUT_MS = 120000` (120 s): `OS.kill(pid)` e il test diventa
  `FAIL <nome>: timeout: il test non e' terminato entro 120.0 s, processo ucciso`;
- il verdetto resta il **codice di uscita** del figlio, il motivo resta la sua **stdout +
  stderr**;
- i byte delle due pipe si accumulano e si decodificano **una volta sola** alla fine:
  decodificare pezzo per pezzo spezzerebbe a metà un carattere multibyte sull'ultima riga,
  che è quella che decide PASS o FAIL;
- se `execute_with_pipe` non è disponibile (handle vuoto), si esegue con `OS.execute` e si
  **dichiara** di aver rinunciato al timeout — non si finge.

## Cosa è stato verificato, e con che numeri

I tre controlli che il piano esigeva, tutti eseguiti il 2026-10-11:

1. **Il gate normale è identico.** `GATE: 8/8`, exit `0`: gli stessi otto test, gli stessi
   verdetti, gli stessi motivi di FAIL di prima della modifica.
2. **Il timeout scatta.** Un test finto che si blocca (`tests/test_zz_probe_timeout.gd`,
   scritto, eseguito una volta con `--only`, e **rimosso**: non è nel repo) è diventato
   `FAIL test_zz_probe_timeout: timeout: il test non e' terminato entro 120.0 s, processo
   ucciso`. Durata misurata: **120 s esatti**. `GATE: 0/1`, exit 1.
3. **`OS.kill` uccide davvero.** Subito dopo il timeout, `tasklist` non mostra **nessun**
   processo `godot` rimasto: il figlio è morto, non abbandonato. Senza questa prova il gate
   avrebbe potuto dichiarare un timeout che non c'era.

E una quarta prova, che è la correzione al diff originale — **la stderr arriva al gate**: un
test finto che stampa `PASS`, esce `0` e **prima** emette uno `SCRIPT ERROR` su stderr
(`tests/test_zz_probe_stderr.gd`, anche questo rimosso) è stato riportato come
`FAIL test_zz_probe_stderr: SCRIPT ERROR durante il test: ...`, con
`anche: il test diceva PASS ma non puo' aver girato tutto`. La pipe `"stderr"` è letta.

## La mezza riga che manca, ed è dell'utente

La modifica al codice è di §3.3 (il timeout del gate è del vertice). Perché il vertice possa
**anche** dichiarare quel file nel proprio scope, la allowlist deve contenerlo: **finché non
lo contiene, `perm_scope` è rosso** (`PERM: 14/15`) e lo **deve** essere — è il piano §3.3 che
assegna il file al vertice, non la allowlist. Quel rosso è la porta che dice la verità su un
drift che c'era già.

Nel blocco `edit` di **`terminal-gun.md`**, accanto agli altri allow di scrittura del vertice:

```yaml
  - action: edit
    resource: "tools/gate.gd"
```

Poi **gli stessi due passi del 2026-10-06**, perché `perm_mirror` confronta byte e non testo
normalizzato:

```sh
# nel repo (.opencode/agents/terminal-gun.md, mirror: fonte di verità)
# poi in ~/.config/opencode/agents/terminal-gun.md (installazione)
# poi: riavviare opencode, i permessi si caricano all'avvio
```

`SCOPE` in `tools/check_perms.py` **è già aggiornato** (con la sovrapposizione dichiarata in
`DECLARED_OVERLAP`, perché il file resta anche di `-scheletro`): appena la riga qui sopra è a
terra, `PERM: 15/15`. Fino a quel momento il rosso è **corretto**, non un difetto da
nascondere.

## Un debito trovato per strada, e non è questo

Applicando la modifica è emerso che **`test_gameloop` è raramente instabile**: l'asserzione
`not horde.grid_overflowed()` dipende dal ripopolamento casuale dell'orda, e ogni tanto
fallisce da sola. Misura: **1 fallimento in 175 esecuzioni** (52 dirette, 60 `--only` col gate
nuovo, 60 col gate vecchio — questi 120 a 0), quindi **non è un effetto del timeout**. È in
§8 del piano, tra i debiti dichiarati.
