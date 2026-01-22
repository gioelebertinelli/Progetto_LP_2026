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

;;; Helper per creare una transizione, se l'input è NIL, rappresenta una epsilon-transizione.
(defun make-transition (from input to) ;;;prende 3 parametri e li restituisce come lista
  (list from input to))
;;;------------------------------------------------------------------------------------------

;;; Funzione  che compila ricorsivamente la regex.
;;; Ritorna una lista di tre elementi: (stato-inizio stato-fine lista-transizioni)
(defun compile-recursive (re)
  (cond
    ;; CASO 1: Atomo
    ((or (atom re)
         (and (listp re) 
              (not (member (first re) '(c a z o)))))
     (let ((start (gensym "Q")) 
           (end (gensym "Q")))
       (list start 
             end 
             (list (make-transition start re end)))))

    ;; CASO 2: Concatenazione ('c')
    ((eq (first re) 'c)
     (reduce (lambda (automa-prima automa-dopo)
               (list (first automa-prima)                          ; Start del primo
                     (second automa-dopo)                          ; End dell'ultimo
                     (append (third automa-prima)                  ; Transizioni accumulate
                             (third automa-dopo)                   ; Transizioni nuove
                             ;; Ponte
                             (list (make-transition (second automa-prima) nil (first automa-dopo))))))
             (mapcar #'compile-recursive (rest re))))

    ;; CASO 3: Alternativa ('a')
    ((eq (first re) 'a)
     (let ((start (gensym))
           (end (gensym)))
       (list start
             end
             (apply #'append 
                    (mapcar (lambda (sotto-regex)
                              (let* ((automa-figlio (compile-recursive sotto-regex))
                                     (inizio-figlio (first automa-figlio))
                                     (fine-figlio   (second automa-figlio))
                                     (transizioni-figlio (third automa-figlio)))
                                ;; Collega Start->Figlio->End
                                (append (list (make-transition start nil inizio-figlio)
                                              (make-transition fine-figlio nil end))
                                        transizioni-figlio)))
                            (rest re))))))

    ;; CASO 4: Stella di Kleene ('z')
    ((eq (first re) 'z)
     (let* ((automa-interno      (compile-recursive (second re)))
            (inizio-interno      (first automa-interno))
            (fine-interna        (second automa-interno))
            (transizioni-interne (third automa-interno))
            (start (gensym))
            (end   (gensym)))
       (list start
             end
             (append (list (make-transition start nil inizio-interno)        ; Entrata
                           (make-transition fine-interna nil end)            ; Uscita
                           (make-transition fine-interna nil inizio-interno) ; Loop
                           (make-transition start nil end))                  ; Skip
                     transizioni-interne))))

    ;; CASO 5: Uno o più ('o')
    ;; CORRETTO QUI: Era ((eq (first re) 'z), deve essere 'o
    ((eq (first re) 'o)
     (let* ((automa-interno      (compile-recursive (second re)))
            (inizio-interno      (first automa-interno))
            (fine-interna        (second automa-interno))
            (transizioni-interne (third automa-interno))
            (start (gensym))
            (end   (gensym)))
       (list start
             end
             (append (list (make-transition start nil inizio-interno)        ; Entrata
                           (make-transition fine-interna nil end)            ; Uscita
                           (make-transition fine-interna nil inizio-interno)); Loop
                     transizioni-interne))))))


;;; ----------------------------------------------------------------------------
;;; FUNZIONE PRINCIPALE
;;; ----------------------------------------------------------------------------
(defun nfsa-compile-regex (RE)
  (if (is-regex RE)
      (let ((result (compile-recursive RE)))
        (make-nfsa :initial (first result)
                   :finals (list (second result))
                   :delta (third result)))
      nil))