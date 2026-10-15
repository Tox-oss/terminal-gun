# Progetto: come armi e potenziamenti coesistono

Sei un revisore di design. Ti do lo stato reale di un videogioco e tre domande
concrete. Ragiona sul merito, contraddicimi quando hai ragione, e non propose
numeri senza dirci su cosa sono misurati.

---

## 1. Che cos'è il gioco

Arena circolare, camera fissa inclinata, il giocatore spara da solo e si muove
con WASD/frecce, dash con SPACE o SHIFT. Non c'è alcun input di mouse. Si
combatte per sopravvivere a ondate crescenti.

## 2. La baseline, misurata

Non inventare questi numeri, vengono tutti da misure su codice reale:

- Giocatore: `10` danno, `111` colpi/min (`1,85/s`), gittata `84 m`, `1` perforante
- Rinculo `18,0 m/s`, attenuato per specie
- Onda 1: `25` nemici, si chiude in `45,85 s` con `200` uccisioni
- `livello 16` a `250` uccisioni
- Il massimo contemporaneo è `200` nemici, con `8` nascite al secondo
- Morso per specie: runner `1,60` / grunt `2,29` / brute `5,94` / mortar `7,31` / boss `13,71` hp
- Giocatore fermo al centro con `200` nemici: **morto dopo `14,10 s`**
- Finestra di invulnerabilità dopo un colpo: `0,25 s`. Con `200` nemici vengono
  offerti `144` morsi e accettati `79`, cioè `2,67/s`
- Ventisette ostacoli solidi di raggio `3,90 m`

**Il bug che ha fatto scrivere tutto questo:** un giocatore con potenziamenti
raggiunge il livello `61` e può **stare fermo al centro e cancellare tutto**.
La causa è stata trovata: la scala degli HP dei nemici era `+25%` a ondata con
**tetto `4,0x` raggiunto alla ondata 13**, e la popolazione era già ferma a `200`
dalla ondata 7. Il giocatore non ha tetto. Quindi dall'onda 13 la difficoltà era
costante per costruzione. Quel tetto è ora in rimozione.

## 3. Il sistema di armi che si vuole costruire

Pipeline a comandi, stile Noita. **Sostituisce** l'arma attuale.

Comandi: `echo` (base), `grep` (cono d'area), `ping` (rimbalzo), `curl`
(inseguimento), `rm` (esplosione ravvicinata).

Modificatori: `-r` ricorsione/divisione, `-f` forza/perforazione/rinculo,
`sudo` overclock e danno doppio.

Operatori: `|` e `&&` per concatenare effetti (esempio `ping | kill -9`).

Un limite di memoria: superata la lunghezza della stringa si subisce
**autodanno** e l'arma va in sovraccarico.

## 4. Il sistema di potenziamenti

Esistono già, funzionano, e hanno misurato i loro effetti:

- `Danno +25%`
- `Cadenza -18%` (tempo di ricarica)
- `Corsa +10%`
- `Velocità proiettile +20%`
- `Spinta +30%`
- `Perforante +1 nemico`
- `Vita massima +20`
- `Gittata +25%`

Si ottengono così: l'XP fa salire di livello, a ogni livello il gioco offre
**tre carte** e ne scegli una. La scelta è permanente per la run.

Una decisione già presa: **quattro carte riguardano l'arma** (danno, cadenza,
spinta, perforante) **e quattro riguardano il giocatore** (vita massima, corsa,
velocità proiettile, e la nuova rigenerazione).

## 5. Il sistema delle casse, che è nuovo

I `27` ostacoli solidi diventano **casse apribili con il tasto E**.

- Il drop esce dalla cassa con una breve traiettoria, cade accanto al
  giocatore e **resta lì finché non viene raccolto**
- Aprendo la cassa il gioco offre **tre potenziamenti fra cui scegliere**,
  mostrati come carte
- Se il contenuto è un comando o un pezzo, la carta mostra un tooltip che
  spiega come equipaggiarlo
- Il reroll delle carte costa **un drop già raccolto**, che viene consumato
- Tipi di drop: **XP, medikit, comando, potenziamento**
- Decisione già presa: **un comando non entra mai nella scelta dei tre**, perché
  un comando è roba che possiedi, non un effetto fra cui scegliere

In più si vuole una carta di **difficoltà**: il gioco diventa più duro, i drop
diventano migliori. Serve a trasformare il surplus di potenza in una scelta
invece che in uno stato già risolto.

## 6. Modificatori in arrivo

- **Armatura**, in percentuale fissa (decisione presa)
- **Rigenerazione passiva** di HP al posto della fortuna, con valori bassi.
  Proposta non ancora confermata: che parta **solo dopo un tempo senza subire
  danno**, così non si può guarire mentre si viene massacrati e la scelta
  diventa "sai uscire dal mucchio"
- Reroll col costo di un drop

## 7. La mappa, che cambia tutto

- Almeno **4 volte più grande**, quindi raggio da `60 m` a `120 m`
- **Generata proceduralmente**, deterministica rispetto al seme
- **Quattro biomi** sparsi; per biomio cambiano densità, terreno e potenziamenti
  disponibili
- I nemici non nascono in un'area ma **a un raggio dal giocatore, fuori dallo
  schermo, già ingaggiati**
- Il **boss finale è una porta**: non si può combattere senza aver attraversato
  i biomi

---

# Le tre domande

### A. Come coesistono i due sistemi, senza che uno cannibalizzi l'altro?

Oggi c'è una fonte sola di potenza (i livelli) e ne arriva una seconda (le
casse). Sono la stessa moneta o due valute? Se sono la stessa, le casse
diventano una scorciatoia e i biomi smettono di avere una ragione per essere
attraversati. Se sono due valute diverse, quale scambio ha? Il reroll che costa
un drop crea già un passaggio fra le due: quanto è profondo?

### B. La collisione che vedo io, e che ti chiedo di reggere o di smentire

Tre delle cinque bandiere della pipeline e tre delle quattro carte sull'arma
**comprano la stessa idea in due vocabolari**:

- `-r` ricorsione/divisione  ↔  carta `Perforante +1`
- `-f` forza/rinculo        ↔  carta `Spinta +30%`
- `sudo` danno doppio       ↔  carta `Danno +25%`

Se esistono entrambe, il giocatore compra lo stesso effetto in due modi e non
sa quale sia il migliore. Le tre uscite possibili che vedo sono:

1. **Le carte sono bandiere.** La linea di comando è il foglio di personaggio:
   la carta `Perforante` non è un numero già applicato, è un token che devi
   mettere da qualche parte. Una sola vocabolario, e la carta acquista una
   scelta di secondo ordine ("dove lo metto?"), che è quello che rende
   interessante una build.
2. **Le bandiere sono fisse ai comandi.** Ogni comando ha un comportamento
   intrinseco, le carte cambiano solo i numeri. Due vocabolari separati, ma
   l'ordine in cui scrivi la linea non conta.
3. **Le bandiere sono un asse a parte.** Le carte danno numeri, le bandiere
   vengono da un'altra fonte (per esempio i drop di comando), e la linea di
   comando le compone.

Quale funziona meglio **per un giocatore che deve anche imparare a scrivere una
stringa**? E il costo di scrittura cambia la risposta?

### C. Il sovraccarico è una terza fonte di difficoltà, e oggi ce ne sono due

L'autodanno da overflow è **difficoltà che il giocatore si autoinflige**, e si
somma alla difficoltà che dà l'orda. Con l'orda che ora cresce per sempre, un
giocatore che scrive bene e un giocatore che scrive male divergono sempre di
più.

Tre domande dentro questa: l'autodanno è una **tassa sulla disattenzione** o una
**parte del gioco**? Se è una tassa, l'errore fa perdere una run e in un gioco
di questo genere è molto forte. E con armatura e rigenerazione, un giocatore
che scrive male può comunque sopravvivere: **il sovraccarico punisce chi gioca
male, che è esattamente chi non dovrebbe punire di più?**

---

Rispondi in ordine, A poi B poi C. Su ogni punto, dimmi **perché la scelta
regge** e **che cosa la romperebbe**. Se un numero serve per sostenere una
tesi, dimmi su cosa lo stai misurando e da cosa dipende: le regole del progetto
dicono che nessun numero entra senza essere misurato, e quelle curve le sto
ancora misurando.