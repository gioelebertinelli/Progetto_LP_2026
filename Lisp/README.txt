================================================================================
                    COMPILATORE REGEX -> NFSA IN COMMON LISP
================================================================================

DESCRIZIONE:
------------
Implementazione in Common Lisp di un compilatore da espressioni regolari a
automi finiti non deterministici (NFSA). Il programma permette di compilare
regex e riconoscere se una stringa appartiene al linguaggio definito.

REQUISITI:
----------
- Interprete Common Lisp (Lispworks Personal Edition)

ESECUZIONE:
-----------
(load "nfsa.lisp")

FUNZIONI PRINCIPALI:
--------------------

1. is-regex (RE)
   Valida se RE è una regex ben formata. Ritorna T se valida, NIL altrimenti.

2. nfsa-compile-regex (RE)
   Compila una regex in un automa NFSA. Ritorna la struct nfsa se RE è valida,
   NIL altrimenti.

3. nfsa-recognize (FA Input)
   Verifica se Input appartiene al linguaggio dell'automa FA.
   Ritorna T se accettato, NIL altrimenti. Input deve essere una lista.


================================================================================

LOGICA DI IMPLEMENTAZIONE is-regex (RE)
---------------------------------------
La funzione valida ricorsivamente la struttura di una regex seguendo le regole
sintattiche degli operatori.

1. Casi Base
   - Lista vuota: NIL (non valida)
   - Atomo: T (sempre valido, anche 'a, 'c, 'z, 'o quando usati come simboli)

2. Operatori Binari/N-ari
   - Operatore 'c' (sequenza): valida se ha almeno 2 argomenti e tutti gli
     argomenti sono regex valide
   - Operatore 'a' (alternativa): valida se ha almeno 2 argomenti e tutti gli
     argomenti sono regex valide

3. Operatori Unari
   - Operatore 'z' (chiusura di Kleene): valida se ha esattamente 1 argomento
     che è una regex valida
   - Operatore 'o' (uno o più): valida se ha esattamente 1 argomento che è
     una regex valida

4. S-expression
   - Lista che non inizia con operatori riservati (c, a, z, o): T
     Rappresenta un simbolo dell'alfabeto (es: (foo bar))


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
Il riconoscimento avviene tramite backtracking esplorando tutti i percorsi possibili
nell'automa.

1. Funzione Principale: recognize-from-state
   Esplora ricorsivamente l'automa partendo da uno stato corrente.
   
   Logica:
   - Input esaurito: verifica se stato finale o raggiungibile via epsilon
   - Input rimanente: prova prima transizioni simbolo, poi epsilon-transizioni
   - Ritorna T se almeno un percorso porta all'accettazione

2. Gestione Epsilon-Transizioni
   Le epsilon-transizioni (input NIL) permettono di cambiare stato senza consumare
   input. Per prevenire loop infiniti, si mantiene una lista visited-epsilon degli
   stati visitati tramite epsilon. Se uno stato è già in visited-epsilon, si ferma
   l'esplorazione da quello stato.

3. Gestione Transizioni Simbolo
   Le transizioni simbolo consumano il primo elemento dell'input. Dopo una
   transizione simbolo, visited-epsilon viene resettato, permettendo di
   ri-entrare in stati già visitati.

4. Confronto Simboli
   Si usa 'equal' invece di 'eql' per supportare S-expressions come simboli
   (es: (foo bar) matcha con (foo bar)).