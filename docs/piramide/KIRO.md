# Contratto di consegna per `kiro-cli`

Regola che vale per **qualsiasi** agente lanciato fuori da opencode, cioè con
`kiro-cli --no-interactive --trust-all-tools`. Vedi piano §1.14-undicesima per il fatto che
l'ha resa necessaria.

## Perché questo file esiste

`kiro-cli --trust-all-tools` **non ha allowlist**: può scrivere ovunque. E
`tools/check_perms.py` confronta i file di agente **opencode** contro `LEAVES` e `SCOPE`, quindi
**non vede un agente kiro**. Senza questo contratto, `PERM: 15/15` continuerebbe a significare
«i quindici permessi dei quindici agenti che conosco» e non «niente sta scrivendo fuori scope»:
una porta che mente per definizione, che è la classe di difetto che questo progetto ha già chiuso
tre volte (sonda mai eseguita, asserzione decorativa, criterio che nasce verde).

**Quindi: due canali, un solo verdetto.** Il commit è del vertice. `GATE` è l'unico che dichiara
verde. Un agente esterno produce file e numeri; **non dichiara niente**.

## Le quattro regole, in ordine di importanza

### 1. Se non puoi eseguire il test, non scrivere codice

`shell` è stato negato a un agente per tutta una sessione, e quello ha lasciato
`tests/test_orda.gd` **non compilante** con sei parse error. Quello è successo **quattro volte**
oggi. Un file non compilante è la cosa peggiore che si possa lasciare.

Se il comando di test non parte, il turno finisce lì con **«non eseguito»** e niente scritto.
Mezzo lavoro verificato batte tutto non eseguito.

### 2. Esegui il test dopo ogni edit, non alla fine

Il costo di ogni sezione va stampato. `TEST_TIMEOUT_MS` è **120 s** e l'utente ha deciso che **non
si alza**: se il tuo lavoro non ci sta, **la sezione si fa piccola**.

### 3. Non spostare un tetto per far entrare il numero

Se una banda cede, un tetto si allarga o una soglia si alza, quello è un **risultato**, non un
ostacolo: si scrive accanto al numero di prima e si dice che è successo. Spostare un tetto perché
il codice non ci arriva è il difetto che questo progetto vieta più spesso.

### 4. I denti si provano e si tolti

Se per far cadere un criterio metti un blocco di prova, **tiralo fuori dal file** prima di
finire. Una prova lasciata dentro è un numero che il prossimo leggerà come se fosse vivo.

## Il muro è meccanico, non dichiarato (2026-10-18)

La sezione «il primo canale» diceva «muro di vetro: dice che c'è, ma non impedisce niente».
**Era sbagliato, e in un modo che contava.** Il muro **esiste ed è meccanico**, e non è la
disciplina di kiro:

> **Il vertice fa `git add` con percorsi espliciti, mai `-A`.** Quindi **qualsiasi scrittura
> fuori dai percorsi che dichiara resta sporca e non entra mai in un commit.**

Una scrittura di kiro in `src/**` o in `tests/**` **non viene pubblicata**: resta modificata
e visibile nel `git status` del vertice, che la vede prima di ogni commit. **La contenzione non
richiede che kiro obbedisca: richiede solo che il vertice non faccia `git add -A`.** È la stessa
forma del resto del progetto — **una porta che non si puo' aggirare vale piu' di una regola che
si puo' dimenticare.**

## Dove puo' scrivere, e dove no

```
PUO'   docs/piramide/diagnosi/*.md          file nuovi, mai toccati da altri
NON    src/**        il codice ha un proprietario per file, e tu non sei un file di agente
NON    tests/**      idem: i test sono scope di una foglia
NON    tools/**      la porta e' del vertice
NON    docs/piramide/piano.md        il piano e' l'unica fonte di verita' ed e' del vertice
NON    docs/piramide/KIRO.md         questo contratto non si modifica da solo
NON    .opencode/**                   allowlist, fuori per costruzione
```

**Il motivo della riga su `src/**` e' di governance, non dicapacita'.** La garanzia su cui
regge tutta la piramide e' **un proprietario per file**: `tools/check_perms.py` confronta i
file di agente opencode contro `LEAVES` e `SCOPE`. **Un agente che non e' un file di agente non
e' coperto da nessuna di quelle porte**, quindi **qualsiasi cosa che scrive non ha un
proprietario** — e un file senza proprietario non e' una versione, e' un artefatto. **Questo
canale fa diagnosi e non produce artefatti.**

## Cosa gli si affida, e perche' e' la classe giusta

Il costo di un'onda non e' scrivere codice: e' **il ping-pong seriale**. Il difetto di
`test_arena` ha attraversato **undici passaggi** fra `-arena` e `-gameplay`, e in undici di
quelli le due foglie si sono passati **un numero alla volta** — perche' **nessuna foglia puo'
leggere lo scope dell'altra**.

Una diagnosi che deve leggere `src/**` e `tests/**` insieme e' **impossibile per una foglia e
banale per un agente senza allowlist**. E il canale esiste per quello: **quota separata**, quindi
il lavoro non compete con le foglie.

I tre incarichi, in ordine di ritorno misurato:

1. **Localizzazione cross-scope, sola lettura.** Per ogni riga `FAIL` che la porta stampa:
   `file:line` del guard che la produce, il valore della sua condizione in quell'istante, e
   **lo scope che lo possiede**.
2. **`SCRIPT ERROR` → riga e perche'.** Il formato `at: GDScript::reload (res://X.gd:541)`
   contiene gia' tutto; in questa sessione ne sono successi quattro e ognuno ha costato un giro.
3. **Censimento delle copie.** Il difetto della **quarta copia di un numero** e' ricorso almeno
   quattro volte in due settimane: due funzioni con lo stesso nome per lo stesso numero, un
   raggio in tre file, un ripiego `-1`. **Un agente che legge tutto lo trova in un passata.**

## Cosa deve contenere il rapporto finale

Cinque righe, e ognuna con il numero o con la parola che la rende inutile:

1. `cosa fatto` — una frase
2. `file toccati` — i percorsi esatti, e `nessuno` se nessuno
3. **`PASS` + il numero di asserzioni, oppure il numero dell'errore** e il costo in ms
4. il numero che il lavoro cambia, **prima e dopo nella stessa frase**
5. che cosa **non** è stato fatto e resta aperto

Se una riga non la puoi riempire, **quella riga è il rapporto**: «non eseguito» è una risposta
valida, inventare un numero non lo è.

## Le due cose che non sono negoziabili

- **Il commit è del vertice.** Mai `git add`, mai `git commit`, mai `git checkout`, mai `git clean`.
- **La porta è del vertice.** Mai `godot --headless --path . --script tools/gate.gd`, mai
  `python tools/check_perms.py`, mai `--import`. Tu esegui **solo il test del tuo file**.

E se un turno finisce e l'albero è sporco, **dillo**: il vertice ripristina, e dirlo vale più che
lasciare mezza cosa e sperare.

## Il primo canale, che è anche il più pericoloso

`kiro-cli` **può scrivere in qualunque file** perché non ha allowlist. Questo contratto è quindi
**l'unico** confine che ha. Trattalo come un muro di vetro: dice che c'è, ma non impedisce niente,
e se lo ignori la porta non se ne accorge.

## Stato del canale

`kiro-cli-chat 2.31.0`, verificato il 2026-10-14 con
`kiro-cli chat --no-interactive --trust-all-tools`, che ha risposto `PRONTO`.
Quindi il binario c'è, l'account risponde, e la **quota è diversa** da quella di opencode: è il
motivo per cui il canale esiste.
