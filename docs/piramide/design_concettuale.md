# terminal-gun — mappa concettuale di design (fornita dall'utente)

## Stile visivo
ASCII Retro / Terminale CRT, movimento fluido a 360° e fisica real-time.

## Durata della run
12 minuti suddivisi in 4 cicli da 3 minuti.

## 1. Struttura della run & fasi (12 minuti)
- 00:00 - 03:00 (Boot / Fase 1): infezione lieve. Spawn di Bug Minori e Adware.
- 03:00 - 06:00 (Infiltration / Fase 2): arrivano i Trojan (movimento erratico) e i Wurm (catene segmentate).
- 06:00 - 09:00 (System Compromised / Fase 3): compaiono i Ransomware (bloccano comandi/armi) e i Rootkit (spuntano da sotto la griglia).
- 09:00 - 12:00 (Kernel Panic / Fase 4): sovraccarico dell'arena, ondate miste e spawn del Boss Finale (Kernel Panic).

## 2. Bestiario dei nemici (minacce di sistema)
- Bug Minore (x_x): mob base di sciame; si muovono dritti verso il player per logorare la RAM.
- Wurm ([--]--[--]): catena segmentata di nemici collegati che serpeggia e attraversa la mappa. Richiede di essere spezzata nei punti giusti.
- Trojan (pezzo degli scacchi / cavallo con base tonda): si muove con pattern irregolari ed erratici (a scatti imprevedibili).
- Ransomware (.locked): carri armati lenti e pesanti; se si avvicinano troppo, bloccano temporaneamente un comando/arma casuale.
- Rootkit (sudo su): si muovono "sotto" la griglia di gioco e emergono all'improvviso sotto i piedi del player.
- Adware / Pop-up Storm: piccole entità caotiche che, se circondano il giocatore, riempiono lo schermo di finestre di testo finte ([CLICK HERE]).
- Kernel Panic (Boss): 900 HP, alta resistenza al knockback, distorce l'estetica del terminale e spara raffiche a 360°.

## 3. Sistema di combattimento e armi (stile Noita)
Il giocatore parte con un'arma base (echo) e costruisce la propria "stringa di esecuzione" raccogliendo nodi di codice durante la run.

### A. I comandi (attacchi attivi)
- echo: spara proiettili lineari base (arma di partenza).
- grep: cono di scansione ad area (DoT ed evidenziazione).
- ping: proiettili veloci che rimbalzano tra i nemici.
- curl: flusso di minion/pacchetti a ricerca automatica.
- rm: esplosione a corto raggio che cancella i bersagli.

### B. I modificatori (flag e parametri)
- -r (Recursive): divide il proiettile all'impatto.
- -f (Force): aumenta velocità, knockback e penetrazione (piercing).
- sudo (Overclock): raddoppia i danni ma aumenta i tempi di ricarica.

### C. Operatori logici e pipe (| e &&)
Permettono di concatenare i comandi (es. ping + | + kill -9 per giustiziare i nemici colpiti dai rimbalzi).

### Gestione della RAM (limiti & crash)
La stringa ha un limite di slot di memoria. Superarlo o creare combinazioni troppo instabili provoca un Buffer Overflow (autodanno e surriscaldamento temporaneo dell'arma).

## 4. Passi di implementazione suggeriti
1. Trasformare il level-up (dalle stat passive ai nodi/comandi): sostituire le opzioni stat con nodi di codice (Comando: grep, ping, curl; Modificatore: -r, -f, sudo; Operatore: |, &&). Aggiungere un'interfaccia "Pipeline" in basso con slot RAM dove assegnare i nodi trovati nell'ordine desiderato (es. [echo] -> [-f] -> [|] -> [grep]).
2. Implementare la prima specie di nemico speciale: Trojan (cavallo) con movimento a scatti a "L"; Wurm con nodo padre che segue il player e figli che seguono a cascata.
3. Gestire lo stack delle armi nel codice (`weapon_pipeline.gd`).

## Nota
Documento fornito dall'utente come mappa concettuale. Il vertice non ha ancora definito scope per le foglie: le ondate future si registrano su richiesta dell'utente.