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
   
   ; Lista vuota non e' una regex valida
   ((null RE) nil)
   
   ;; Caso base: un atomo (simbolo o numero) e' sempre una regex valida
   ;; Questo include anche 'a, 'c, 'z, 'o quando sono usati come simboli
   ((atom RE) t)
   
   ;; Caso lista: dobbiamo controllare se e' un operatore valido
   ((listp RE)
    (cond
     
     ;; Operatore 'c' (sequenza): deve avere almeno un argomento
     ;; e tutti gli argomenti devono essere regex valide
     ((eq (first RE) 'c)
      (and (>= (length (rest RE)) 1)  ; almeno un argomento
           (every #'is-regex (rest RE))))  ; controllo ricorsivo
     
     ;; Operatore 'a' (alternativa): deve avere almeno un argomento
     ;; e tutti gli argomenti devono essere regex valide
     ((eq (first RE) 'a)
      (and (>= (length (rest RE)) 1)
           (every #'is-regex (rest RE))))
     
     ;; Operatore 'z' (stella di Kleene): deve avere esattamente un argomento
     ;; che deve essere una regex valida
     ((eq (first RE) 'z)
      (and (= (length (rest RE)) 1)  ; esattamente un argomento
           (is-regex (second RE))))  ; controllo ricorsivo
     
     ;; Operatore 'o' (uno-o-piu'): deve avere esattamente un argomento
     ;; che deve essere una regex valida
     ((eq (first RE) 'o)
      (and (= (length (rest RE)) 1)
           (is-regex (second RE))))
     
     ;; Se il primo elemento NON e' uno degli operatori riservati (c, a, z, o),
     ;; allora questa e' una S-expression che rappresenta un simbolo dell'alfabeto
     ;; e quindi e' una regex valida
     ;; Esempio: (foo bar) e' un simbolo valido dell'alfabeto
     (t t)))
   
   ;; Altri casi (per evitare bug)
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