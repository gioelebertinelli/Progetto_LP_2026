================================================================================
                    COMPILATORE REGEX -> NFSA IN COMMON LISP
================================================================================

DESCRIZIONE:
------------
Implementazione in Common Lisp di un compilatore da espressioni regolari a
NFSA. Il programma permette di compilare regex e riconoscere se una stringa 
appartiene al linguaggio definito.

REQUISITI:
----------
- Interprete Common Lisp (LispWorks,..)

ESECUZIONE:
-----------
(load "nfsa.lisp")

FUNZIONI PRINCIPALI:
--------------------

1. is-regex (RE)
   Controlla se un'espressione regolare (RE) è valida.
   Ritorna T se valida, NIL altrimenti.

2. nfsa-compile-regex (RE)
   Compila un'espressione regolare in un automa NFSA. 
   Ritorna la struct nfsa se RE è valida, NIL altrimenti.

3. nfsa-recognize (FA Input)
   Verifica se Input appartiene al linguaggio riconosciuto dall'automa FA.
   Ritorna T se accettato, NIL altrimenti.

================================================================================

LOGICA DI IMPLEMENTAZIONE is-regex (RE)
---------------------------------------
La funzione controlla ricorsivamente se un'espressione regolare è ben formata 
controllando la struttura e gli operatori.

1. Casi Base
   - Lista vuota: non rappresenta nessuna regex quindi ritorna NIL.

   - Atomo: rappresenta un simbolo dell'alfabeto quindi è sempre valido, 
     anche se è 'a, 'c, 'z, 'o usati come simboli quindi ritorna T.

2. Operatori
   - Operatore 'c' (sequenza): è valida se ha almeno 2 argomenti e tutti gli 
     argomenti sono regex valide.
     Il controllo viene fatto con 'every' che è una funzione che ritorna T se
     e solo se tutti gli argomenti soddisfano la condizione (regex valida).

   - Operatore 'a' (alternativa): è valida se ha almeno 2 argomenti e tutti gli 
     argomenti sono regex valide.
     Il controllo viene fatto con 'every' che è una funzione che ritorna T se
     e solo se tutti gli argomenti soddisfano la condizione (regex valida).

   - Operatore 'z' (chiusura di Kleene): è valida se ha esattamente 1 argomento 
     che è una regex valida.
     L'argomento viene controllato chiamando is-regex su di esso.

   - Operatore 'o' (uno o più): è valida se ha esattamente 1 argomento che è 
     una regex valida. 
     L'argomento viene controllato chiamando is-regex su di esso.

   Nota: per gli operatori 'c' e 'a', è stato considerato un numero minimo di
         argomenti >= 2 e non >=1 perchè la concatenazione o l'alternativa di 
         un simbolo sarebbero il simbolo stesso.

3. S-expression 
   - Se la lista non inizia con operatori riservati significa che è una 
     S-expression che rappresenta un simbolo composto dell'alfabeto. 
     È sempre valida quindi ritorna T.


LOGICA DI IMPLEMENTAZIONE nfsa-compile-regex (RE)
-------------------------------------------------
Questo modulo permette di trasformare un'espressione regolare (in formato S-expression)
in un Automa a Stati Finiti Non Deterministico (NFSA) utilizzando la Costruzione di Thompson.

1. Strutture Dati
L'automa è costruito combinando tre elementi fondamentali:

Stati: Etichette univoche generate con gensym (es. Q1234).
Transizioni: Triplette (da-stato input a-stato).
Epsilon-mosse: Transizioni con input NIL che permettono di cambiare stato senza consumare caratteri della stringa.

L'automa finale viene restituito come una struttura nfsa contenente lo stato iniziale, la lista degli stati finali e
l'insieme di tutte le transizioni (delta).

2. Logica di Compilazione (Casi)
La funzione compile-recursive smonta la regex e la ricostruisce seguendo questi schemi logici:

	a. Caso Base (Simbolo singolo)
	Crea un'unità minima con due stati e una transizione diretta.

	Inizio --(carattere)--> Fine

	b. Concatenazione ('c')
       	Unisce gli automi in serie (uno dopo l'altro).

	Logica: Collega la fine del primo automa all'inizio del secondo tramite una epsilon-mossa.

	Accumulatore: Usa reduce per unire un numero infinito di simboli in una catena continua.

	c. Alternativa ('a')
	Implementa l'operatore OR (bivio).

	Logica: Crea un nuovo inizio che punta a tutti i rami possibili e una nuova fine dove tutti i rami convergono.

	Struttura: È una configurazione "a diamante" che permette di scegliere un percorso tra i tanti.

	d. Stella di Kleene ('z') e "Uno o più" ('o')
	Gestiscono la ripetizione.

	Loop: Una epsilon-mossa torna dalla fine all'inizio del simbolo per ripeterlo.

	Skip (Solo Caso 'z'): Una epsilon-mossa permette di saltare il simbolo se presente 0 volte.

	Entrata/Uscita: Due stati extra racchiudono il simbolo per mantenere l'automa modulare.


LOGICA DI IMPLEMENTAZIONE nfsa-recognize
----------------------------------------
La funzione verifica se una stringa in input  appartiene al linguaggio 
riconosciuto dall'automa.
Prima controlla che l'automa sia valido, in caso contrario genera un errore.
Controlla che l'input sia una lista, altrimenti ritorna NIL.
Se tutto è valido, estrae i componenti dell'automa (stato iniziale, stati 
finali, transizioni) e avvia il riconoscimento chiamando la funzione 
recognize-from-state partendo dallo stato iniziale.

Il riconoscimento avviene tramite backtracking esplorando tutti i percorsi 
possibili nell'automa. In un NFSA da uno stato possono partire più transizioni
diverse sia che consumano un simbolo della stringa sia epsilon transizioni. 
Il backtracking prova tutte queste possibilità per vedere se almeno una porta
all'accettazione della stringa. In quel caso ritorna T.

1. Funzione Helper: recognize-from-state
   Esplora ricorsivamente l'automa partendo dallo stato attuale.
   
   Logica:
   - Input esaurito: verifica se mi trovo in uno stato finale, in quel 
     caso ritorna T, altrimenti prova a vedere se si può raggiungere uno stato
     finale con epsilon transizioni.

   - Input rimanente: prova prima le transizioni che consumano un simbolo
     poi prova le epsilon-transizioni. Se almeno una di queste possibilità 
     porta all'accettazione, ritorna T.

2. Gestione Transizioni Simbolo: try-symbol-transitions
   Le transizioni simbolo consumano il primo elemento dell'input. Per ogni
   transizione dallo stato in cui ci troviamo, si controlla se il simbolo della
   transizione corrisponde al primo simbolo dell'input rimanente. Se
   corrisponde, si fa la transizione passando allo stato successivo e
   avanzando nell'input.

3. Gestione Epsilon-Transizioni: try-epsilon-transitions
   Le epsilon-transizioni permettono di cambiare stato senza consumare
   input. Per ogni transizione dallo stato in cui ci troviamo, si controlla
   se è una epsilon-transizione guardando se il simbolo è NIL. 
   Se lo è, si può eseguire la transizione passando allo stato successivo.
   Per evitare cicli infiniti, c'è una lista visited-epsilon degli stati
   visitati tramite epsilon-transizioni. Se uno stato è già in visited-epsilon,
   si ferma quel ramo per evitare di entrare in un ciclo. Ogni volta che viene
   fatta una transizione consumando un simbolo si resetta visited-epsilon
   siccome dopo aver consumato un simbolo non c'è più il rischio di loop dovuti
   a epsilon transizioni.

   Nota: Per il backtracking si usa la funzione 'some' che prende una funzione e 
         una lista e applica la funzione a ogni elemento della lista, ritornando
         T appena un elemento della lista torna T. In questo modo si provano 
         tutte le transizioni possibili e non appena una ritorna T e quindi
         accetta la stringa, ritorna T e l'automa accetta.

4. Simbolo di confronto utilizzato
   Si usa 'equal' che confronta il contenuto delle liste per supportare le 
   S-expressions di simboli composti.
