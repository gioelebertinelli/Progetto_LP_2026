=============================================================================
                    COMPILATORE REGEX -> NFSA IN PROLOG
=============================================================================

DESCRIZIONE:

Implementazione in Prolog di un compilatore da espressioni regolari a
NFSA.

Il programma permette:
- di verificare se un termine Prolog rappresenta una regex valida
- di compilare una regex in un automa NFSA salvato nel database dinamico
- di riconoscere se una stringa (lista di simboli) appartiene al linguaggio
  definito dalla regex

L’implementazione segue l’algoritmo di Thompson ed è pensata per lavorare
direttamente con termini Prolog (atomici e composti).

REQUISITI:
- Interprete Prolog (SWI-Prolog consigliato)
- Libreria gensym


ESECUZIONE:
?- consult('nfsa.pl').


PREDICATI PRINCIPALI:

1. is_regex(RE)
   Verifica se RE è un’espressione regolare valida.
   Ritorna true se RE è una regex, fallisce altrimenti.

2. nfsa_compile_regex(FA_Id, RE)
   Compila la regex RE in un automa NFSA identificato da FA_Id.
   L’automa viene salvato nel database dinamico tramite fatti nfsa_init/2,
   nfsa_final/2 e nfsa_delta/4.

3. nfsa_recognize(FA_Id, Input)
   Verifica se Input (lista) viene accettato dall’automa FA_Id.


LOGICA DI IMPLEMENTAZIONE is_regex/1

Il predicato is_regex/1 controlla ricorsivamente se un termine Prolog
rappresenta una regex ben formata, secondo le specifiche del progetto.

SCELTE PROGETTUALI IMPORTANTI

- L’alfabeto delle regex è costituito da termini Prolog:
  - tutti gli atomi
  - tutti i termini composti,a patto che il funtore non sia riservato
- Alcuni funtori sono riservati e non possono essere usati come simboli:
  c, a, z, o, epsilon
- epsilon NON è considerato un simbolo dell’alfabeto, ma viene riservato
  esclusivamente per rappresentare le epsilon-transizioni dell’automa.
  Questo evita ambiguità nel riconoscimento dell’input.

1. Gestione delle variabili
Se RE è una variabile, is_regex fallisce immediatamente.
Motivo:
In Prolog una variabile potrebbe unificarsi con qualunque termine,
portando a comportamenti non desiderati e a risposte non deterministiche.
Inoltre il predicato is_regex deve essere un puro controllo, non un
generatore di regex.

2. Caso base: simboli atomici
Tutti i termini che soddisfano atomic/1 sono considerati regex valide,
tranne epsilon.

Esempi validi:
- a
- foo
- 42
- hello

Esempio NON valido:
- epsilon

3. Operatori unari: z e o
- z(RE): chiusura di Kleene
- o(RE): uno o più

Sono validi solo se:
- hanno esattamente un argomento
- l’argomento è a sua volta una regex valida

Il controllo è fatto richiamando is_regex/1 in modo ricorsivo.

4. Operatori n-ari: c e a
- c(RE1, RE2, ..., REn): concatenazione
- a(RE1, RE2, ..., REn): alternativa

Scelta progettuale:
Questi operatori sono accettati solo se hanno almeno 2 argomenti (N >= 2).
Motivo:
Una concatenazione o alternativa con un solo elemento non ha senso logico,
perché sarebbe equivalente all’elemento stesso.

Il controllo avviene così:
- si verifica che il termine sia compound
- si controlla che il funtore sia c o a
- si controlla l’arietà (>= 2)
- si applica is_regex/1 ricorsivamente a tutti gli argomenti tramite maplist

5. Termini composti non riservati
Un termine composto con funtore NON riservato (es. foo(bar), test())
è considerato un simbolo valido dell’alfabeto,
abbiamo deciso di accettare anche termini composti con zero parametri,
a patto che il funtore non sia ovviamente riservato 
(per esempio foo() viene accettato)

Questo permette di usare simboli complessi come elementi dell’input,
non solo atomi semplici.

Nota aggiuntiva:
Uso di compound_name_arity/3

Per l’analisi dei termini composti viene utilizzato il predicato built-in
compound_name_arity/3, che permette di estrarre in modo diretto il funtore
e l’arità di un termine Prolog.

Questo predicato è particolarmente utile perché consente di:
distinguere in modo chiaro i funtori riservati (c, a, z, o)
dai simboli normali dell’alfabeto;

inoltre permette di controllare esplicitamente l’arità degli operatori c e a,
imponendo il vincolo di almeno due argomenti;

gestisce correttamente anche termini composti con arità zero
(come foo()), che in SWI-Prolog sono considerati termini compound
con arità 0.


LOGICA DI IMPLEMENTAZIONE nfsa_compile_regex/2


Questo predicato compila una regex in un NFSA seguendo la costruzione di
Thompson e salva l’automa nel database dinamico.

1. Controllo su FA_Id

FA_Id non deve contenere variabili.

Motivo:
FA_Id è usato come identificatore dell’automa nel database.
Se fosse una variabile, siccome andiamo a chiamare nfsa_delete(FA_Id),
questo porterebbe all'unificazione con ogni Id dell'automa e la conseguente
cancellazione di ognuno di essi

2. Validazione della regex

Prima di compilare, si controlla che RE sia una regex valida con is_regex/1.
Se non lo è, la compilazione fallisce.

3. Gestione del database
Se esiste già automa con lo stesso FA_Id,viene cancellato con nfsa_delete/1.
Questo permette di “ricompilare” lo stesso automa senza creare duplicati.

4. Creazione degli stati

Gli stati iniziale e finale vengono creati con gensym/2 per garantire
unicità globale.

Vengono poi salvati con:
- nfsa_init(FA_Id, Start)
- nfsa_final(FA_Id, End)
per tali salvataggio nel database dinamico si usa assertz\1.

5. Compilazione vera e propria
La compilazione è delegata al predicato helper compile/4 che costruisce
le transizioni nfsa_delta/4 seguendo Thompson.

Se la compilazione fallisce a metà, l’automa viene cancellato per evitare
di lasciare dati inconsistenti nel database.

6. Costruzione secondo Thompson

- Simbolo base:
  Start --(simbolo)--> End

- Concatenazione (c):
  Gli automi vengono collegati in serie usando stati intermedi.

- Alternativa (a):
  Viene creata una struttura a diamante con epsilon-transizioni
  dall’inizio verso ogni ramo e da ogni ramo verso la fine.

- Kleene star (z):
  Si permettono:
  - 0 ripetizioni (epsilon Start -> End)
  - ripetizioni multiple tramite loop epsilon

- Plus (o):
  È implementato come RE seguito da z(RE), quindi almeno una occorrenza.

Le epsilon-transizioni usano il simbolo speciale epsilon, che è stato
riservato appositamente in fase di progettazione.


LOGICA DI IMPLEMENTAZIONE nfsa_recognize/2

Questo predicato verifica se una lista di simboli Input viene accettata
dall’automa identificato da FA_Id.

1. Controllo sull’input

Input deve essere una lista. Se non lo è, il predicato fallisce subito.

2. Recupero dello stato iniziale

Si recupera lo stato iniziale tramite nfsa_init/2.
Se non esiste, significa che l’automa non è stato compilato.

3. Riconoscimento tramite backtracking

Il riconoscimento è implementato dal predicato helper recognize/4, che
simula l’esecuzione di un NFSA esplorando tutti i cammini possibili.

4. Gestione dei casi

- Input vuoto:
  Se lo stato corrente è finale, l’input è accettato.
  Altrimenti si prova a raggiungere uno stato finale tramite
  epsilon-transizioni.

- Input non vuoto:
  Si prova prima a consumare il simbolo corrente con una transizione
  normale, poi si provano eventuali epsilon-transizioni.

5. Prevenzione dei cicli infiniti

Le epsilon-transizioni possono creare cicli.
Per evitarli, viene mantenuta una lista Visited che tiene traccia delle
coppie (Stato, Input) già visitate.

Se una configurazione è già stata esplorata, quel ramo viene scartato.

Ogni volta che si consuma un simbolo, Visited viene azzerata perché
il rischio di loop su epsilon sparisce.

GESTIONE DEL DATABASE

I predicati nfsa_delete/1 e nfsa_delete_all/0 utilizzano il predicato
built-in retractall/1 per rimuovere fatti dal database dinamico.

nfsa_delete(FA_Id) rimuove tutti i fatti relativi all’automa
identificato da FA_Id, ovvero:

nfsa_init(FA_Id, _)

nfsa_final(FA_Id, _)

nfsa_delta(FA_Id, _, _, _)

nfsa_delete_all/0 rimuove tutti gli automi, indipendentemente
dall’identificatore.

Il predicato retractall/1 ha la caratteristica di avere sempre successo,
anche nel caso in cui non esistano fatti da rimuovere.

Per questo motivo, sia nfsa_delete/1 sia nfsa_delete_all/0
ritornano sempre true e possono essere utilizzati in modo sicuro
per ripulire il database senza dover controllare preventivamente
l’esistenza dell’automa.

Questa scelta semplifica la gestione della ricompilazione degli automi,
evitando stati inconsistenti o duplicazioni nel database dinamico.

NOTE FINALI

Il progetto sfrutta le caratteristiche di Prolog (pattern matching,
backtracking, database dinamico) per implementare in modo naturale
un NFSA.

Le scelte progettuali (uso di ground/1, riservare epsilon, gestione
esplicita delle variabili, controllo sui funtori riservati) sono state
fatte per evitare comportamenti non deterministici e bug difficili
da individuare, mantenendo il codice il più possibile aderente alle
specifiche del progetto.
