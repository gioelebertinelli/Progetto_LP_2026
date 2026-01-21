; Bertinelli	Gioele	923893
; Gianoli	Matteo	924072
; Martinalli	Marco	924003

;;; ----------------------------------------------------------------------------
;;; FUNZIONE: is-regex
;;; Controlla se l'espressione RE è una regex valida
;;; Ritorna T se RE e' una regex valida, NIL altrimenti
;;; ----------------------------------------------------------------------------

(defun is-regex (RE)
  
  (cond
   
   ; Caso lista vuota: non e' una regex valida
   ((null RE) nil)
   
   ;; Caso atomo: e' sempre una regex valida 
   ;; (anche 'a, 'c, 'z, 'o quando sono usati come simboli)
   ((atom RE) t)
   
   ;; Caso lista: controllo se l'operatore è valido
   ((listp RE)
    (cond
     
     ;; Caso operatore 'c' (sequenza): deve avere almeno un argomento
     ;; e tutti gli argomenti devono essere regex valide
     ((eq (first RE) 'c)
      (and (>= (length (rest RE)) 1)  
           (every #'is-regex (rest RE))))
     
     ;; Caso operatore 'a' (alternativa): deve avere almeno un argomento
     ;; e tutti gli argomenti devono essere regex valide
     ((eq (first RE) 'a)
      (and (>= (length (rest RE)) 1)
           (every #'is-regex (rest RE))))
     
     ;; Caso operatore 'z' (chiusura di Kleene):
     ;; deve avere esattamente un argomento che deve essere una regex valida
     ((eq (first RE) 'z)
      (and (= (length (rest RE)) 1)  
           (is-regex (second RE))))
     
     ;; Caso operatore 'o' (ripetizione uno-o-piu'):
     ;; deve avere esattamente un argomento che deve essere una regex valida
     ((eq (first RE) 'o)
      (and (= (length (rest RE)) 1)
           (is-regex (second RE))))
     
     ;; Se il primo elemento NON e' uno degli operatori riservati (c, a, z, o),
     ;; allora questa e' una S-expression che rappresenta un simbolo
     ;; dell'alfabeto e quindi e' una regex valida. Esempio: (foo bar) 
     (t t)))
   
   ;; Altri casi: catch-all per tipi non previsti
   (t nil)))


;;; ----------------------------------------------------------------------------
;;; FUNZIONE: nfsa-compile-regex
;;; ritorna l’automa ottenuto dalla compilazione di RE, se è un’espressione regolare, 
;;; altrimenti ritorna NIL.
;;; ----------------------------------------------------------------------------

;;; Definizione della struttura dell'automa (NFSA)

(defstruct nfsa
  initial   ; Stato iniziale
  finals    ; Lista degli stati finali
  delta)    ; Lista delle transizioni (stato-da input stato-a)

;;; Variabile globale per contare gli stati e generare ID univoci.
(defparameter *state-counter* 0)

;;; Helper per generare un nuovo stato (semplicemente un numero intero)
(defun new-state ()
  (incf *state-counter*))

;;; Helper per creare una transizione.
;;; Se l'input è NIL, rappresenta una epsilon-transizione.
(defun make-transition (from input to)
  (list from input to))

;;; Funzione  che compila ricorsivamente la regex.
;;; Ritorna una lista di tre elementi: (stato-inizio stato-fine lista-transizioni)
;;; serve per collegare "i pezzi"
(defun compile-recursive (re)
  (cond
    ;; CASO 1: Atomo (Simbolo base o lista che non è un operatore)
    ((or (atom re)
         (and (listp re) 
              (not (member (first re) '(c a z o)))))
     (let ((start (new-state))
           (end (new-state)))
       (list start 
             end 
             (list (make-transition start re end)))))

    ;; CASO 2: Concatenazione ('c')
    ((eq (first re) 'c)
     (let* ((args (rest re))
            (first-res (compile-recursive (first args)))
            (current-start (first first-res))
            (current-end (second first-res))
            (current-trans (third first-res)))
       
     
       (dolist (next-re (rest args))
         (let* ((next-res (compile-recursive next-re))
                (next-start (first next-res))
                (next-end (second next-res))
                (next-trans (third next-res)))

           ;; Colleghiamo la fine del precedente all'inizio del successivo
           (push (make-transition current-end nil next-start) current-trans)
           ;; Uniamo le transizioni
           (setf current-trans (append current-trans next-trans))
           ;; Aggiorniamo la fine corrente
           (setf current-end next-end)))
       
       (list current-start current-end current-trans)))

    ;; CASO 3: Alternativa ('a' - OR)

    ((eq (first re) 'a)
     (let ((global-start (new-state))
           (global-end (new-state))
           (all-trans '()))
       
       (dolist (sub-re (rest re))
         (let* ((res (compile-recursive sub-re))
                (s (first res))
                (e (second res))
                (t-list (third res)))
           ;; Start globale -> Start sotto-regex
           (push (make-transition global-start nil s) all-trans)
           ;; End sotto-regex -> End globale
           (push (make-transition e nil global-end) all-trans)
           ;; Accumuliamo le transizioni interne
           (setf all-trans (append all-trans t-list))))
       
       (list global-start global-end all-trans)))

    ;; CASO 4: Stella di Kleene ('z' - Zero o più)
    ((eq (first re) 'z)
     (let* ((res (compile-recursive (second re))) ; L'argomento è il secondo elemento
            (s (first res))
            (e (second res))
            (t-list (third res))
            (new-s (new-state))
            (new-e (new-state)))
       
       ;; Aggiungiamo le 4 transizioni tipiche
       (push (make-transition new-s nil s) t-list)     ; Entrata
       (push (make-transition e nil new-e) t-list)     ; Uscita
       (push (make-transition e nil s) t-list)         ; Loop indietro
       (push (make-transition new-s nil new-e) t-list) ; Skip (caso zero volte)
       
       (list new-s new-e t-list)))

    ;; CASO 5: Uno o più ('o')
    ;; Simile alla stella, ma senza lo skip iniziale diretto
    ((eq (first re) 'o)
     (let* ((res (compile-recursive (second re)))
            (s (first res))
            (e (second res))
            (t-list (third res))
            (new-s (new-state))
            (new-e (new-state)))
       
       (push (make-transition new-s nil s) t-list)     ; Entrata
       (push (make-transition e nil new-e) t-list)     ; Uscita
       (push (make-transition e nil s) t-list)         ; Loop indietro
       ;; NON c'è la transizione new-s -> new-e perché deve farne almeno uno
       
       (list new-s new-e t-list)))))

;;; FUNZIONE PRINCIPALE RICHIESTA
(defun nfsa-compile-regex (RE)
  ;; Controllo preliminare usando la tua funzione is-regex
  (if (is-regex RE)
      (progn
        ;; Resettiamo il contatore per avere stati puliti partendo da 1 o 0
        (setf *state-counter* 0)
        ;; Compiliamo ottenendo i 3 pezzi (start end transitions)
        (let ((result (compile-recursive RE)))
          ;; Costruiamo e ritorniamo la struct finale
          (make-nfsa :initial (first result)
                     :finals (list (second result))
                     :delta (third result))))
      nil))

;; Dichiarazione funzioni per evitare warning 
;; (nel caso venga chiamata prima di essere letta)
(declaim (ftype (function (t t t t t) t) recognize-from-state))
(declaim (ftype (function (t t t t t) t) try-epsilon-transitions))
(declaim (ftype (function (t t t t) t) try-symbol-transitions))

;;; ----------------------------------------------------------------------------
;;; FUNZIONE HELPER: try-epsilon-transitions
;;; Prova tutte le epsilon-transizioni (quelle con simbolo NIL)
;;; Non consumano input, quindi passiamo lo stesso remaining-input
;;; Ritorna T se almeno una porta al successo, NIL altrimenti
;;; ----------------------------------------------------------------------------


(defun try-epsilon-transitions (current-state remaining-input final-states 
                                transitions visited-epsilon)
  
  ;; CONTROLLO ANTI-LOOP: Se questo stato è già in visited-epsilon, FERMATI!
  (when (member current-state visited-epsilon)
    (return-from try-epsilon-transitions nil))
  
  ;; Aggiungi current-state ai visitati PRIMA di esplorare
  (let ((new-visited (cons current-state visited-epsilon)))
    (some #'(lambda (trans)
              (let ((from-state (first trans))
                    (symbol (second trans))
                    (to-state (third trans)))
                (when (and (eql from-state current-state)
                          (null symbol))
                  ;; Passa new-visited alla chiamata ricorsiva
                  (recognize-from-state to-state remaining-input final-states 
                                      transitions new-visited))))
          transitions)))


;;; ----------------------------------------------------------------------------
;;; FUNZIONE HELPER: try-symbol-transitions
;;; Prova tutte le transizioni che consumano il prossimo simbolo dell'input
;;; Ritorna T se almeno una porta al successo, NIL altrimenti
;;; ----------------------------------------------------------------------------

(defun try-symbol-transitions (current-state remaining-input final-states 
                               transitions)
  (when remaining-input  ; Controllo di sicurezza
    (let ((next-symbol (first remaining-input))
          (rest-input (rest remaining-input)))
      
      ;; Troviamo tutte le transizioni applicabili dallo stato corrente
      ;; che consumano esattamente il prossimo simbolo
      (some #'(lambda (trans)
                (let ((from-state (first trans))
                      (symbol (second trans))
                      (to-state (third trans)))
                  
                  ;; Controlliamo se questa transizione e' applicabile:
                  ;; 1. Parte dallo stato corrente
                  ;; 2. Il simbolo corrisponde (NON e' epsilon)
                  ;; 3. Il simbolo matcha con next-symbol
                  (when (and (eql from-state current-state)
                            (not (null symbol))  ; NON epsilon
                            (equal symbol next-symbol))
                    
                    ;; Proviamo a continuare da questo nuovo stato
                    ;; consumando il resto dell'input
                    ;; IMPORTANTE: resettiamo visited-epsilon 
                    (recognize-from-state to-state rest-input final-states 
                                         transitions '()))))
            transitions))))


;;; ----------------------------------------------------------------------------
;;; FUNZIONE HELPER: recognize-from-state
;;; Funzione ricorsiva che esplora l'automa con backtracking
;;; 
;;; Parametri:
;;;   current-state: lo stato in cui ci troviamo ora
;;;   remaining-input: la lista di simboli ancora da consumare
;;;   final-states: lista degli stati finali
;;;   transitions: lista di tutte le transizioni dell'automa
;;;
;;; Logica:
;;;   1. Se l'input e' finito E siamo in uno stato finale -> successo (T)
;;;   2. Altrimenti proviamo tutte le transizioni possibili
;;;   3. Se almeno UN percorso porta al successo -> T, altrimenti NIL
;;; ----------------------------------------------------------------------------

(defun recognize-from-state (current-state remaining-input final-states 
                             transitions visited-epsilon)
  (cond
   ;; CASO BASE: Input esaurito
   ;; Controlliamo se siamo in uno stato finale
   ((null remaining-input)
    (if (member current-state final-states)
        t  ; Successo! Abbiamo riconosciuto l'input
        ;; Anche se l'input e' finito, potremmo raggiungere uno stato finale
        ;; tramite epsilon-transizioni, quindi le proviamo
        (try-epsilon-transitions current-state remaining-input final-states 
                                transitions visited-epsilon)))
   
   ;; CASO RICORSIVO: Abbiamo ancora simboli da consumare
   (t
    ;; Proviamo prima le transizioni che consumano il prossimo simbolo
    ;; e poi le epsilon-transizioni (per esplorarle tutte)
    (or (try-symbol-transitions current-state remaining-input final-states 
                               transitions)
        (try-epsilon-transitions current-state remaining-input final-states 
                                transitions visited-epsilon)))))


;;; ----------------------------------------------------------------------------
;;; FUNZIONE: nfsa-recognize
;;; Riconosce se l'input appartiene al linguaggio dell'automa FA
;;; Ritorna T se l'input viene accettato, NIL altrimenti
;;; Genera un errore se FA non e' un automa valido
;;; ----------------------------------------------------------------------------

(defun nfsa-recognize (FA Input)
  ;; Controllo che FA e' un automa valido
  (unless (nfsa-p FA)
    (error "~A non è un automa." FA))
  
  ;; Se input non e' una lista, ritorna NIL 
  ;; (come esempio (nfsa-recognize basic-nfsa-1 'a) -> NIL)
  (if (listp Input)
      ;; Estrazione componenti dell'automa
      (let ((start (nfsa-initial FA))        ; Stato iniziale
            (final-states (nfsa-finals FA))  ; Stati finali
            (transitions (nfsa-delta FA)))   ; Transizioni
        
        ;; Chiamata alla funzione helper
        (recognize-from-state start Input final-states transitions '()))
      nil))

