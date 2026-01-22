% Bertinelli	Gioele	923893
% Gianoli	Matteo	924072
% Martinalli	Marco	924003

:- use_module(library(gensym)).


% Qui metto i funtori riservati della sintassi delle regex.
% Cioè quelli che NON possono comparire come simboli normali (compound).
% (epsilon lo usiamo solo per epsilon-transizioni dell'automa)
reserved(c).
reserved(a).
reserved(z).
reserved(o).
reserved(epsilon).

% I predicati dell'automa (li salviamo nella base di conoscenza a runtime)
% nfsa_init(Id, StatoIniziale)
% nfsa_final(Id, StatoFinale)
% nfsa_delta(Id, DaStato, Simbolo, AStato)
:- dynamic nfsa_init/2.
:- dynamic nfsa_final/2.
:- dynamic nfsa_delta/4.


% predicato is_regex\1

% Caso base: se viene passata una variabile, fallisco subito.
is_regex(Re) :-
    var(Re),
    !,
    fail.

% Caso base: tutti gli atomi/numeri sono regex (simboli dell'alfabeto)
% tranne epsilon che ci serve come etichetta speciale di transizione.
is_regex(Re) :-
    atomic(Re),
    Re \= epsilon.

% Operatori unari: z ed o
% (controllo solo che dentro sia regex)
is_regex(z(Re)) :-
    is_regex(Re).

is_regex(o(Re)) :-
    is_regex(Re).

% Concatenazione: c
% Noi la accettiamo solo se ha almeno 2 argomenti
is_regex(Expr) :-
    compound(Expr),
    compound_name_arity(Expr, c, N),
    N >= 2,
    % trasformo in lista degli argomenti e controllo ricorsivamente
    Expr =.. [c | Args],
    maplist(is_regex, Args).

% Alternativa: a
% Anche qui almeno 2 argomenti
is_regex(Expr) :-
    compound(Expr),
    compound_name_arity(Expr, a, N),
    N >= 2,
    Expr =.. [a | Args],
    maplist(is_regex, Args).

% Se è un termine composto tipo foo(bar) o zio_di(achille) ecc...
% allora lo considero simbolo valido solo se il funtore non è riservato.
% (foo(bar) ok, ma c(a,b) qui no perché c è riservato, anche foo() ok)
is_regex(Re) :-
    compound(Re),
    compound_name_arity(Re, F, _),
    \+ reserved(F).


% nfsa_compile_regex(FA_Id, Re)
% compila la regex in un NFSA e lo salva nel DB dinamico.
% Se esiste già un automa con lo stesso Id, lo riscriviamo.

nfsa_compile_regex(FA_Id, Re) :-
    % Id non deve contenere alcuna variabile
    ground(FA_Id),
    % regex deve essere valida
    is_regex(Re),

    % se esiste già un automa con questo id, lo tolgo prima
    nfsa_delete(FA_Id),

    % creo stato iniziale e finale (unici per questo automa)
    gensym(q, Start),
    gensym(q, End),

    % li salvo nel DB
    assertz(nfsa_init(FA_Id, Start)),
    assertz(nfsa_final(FA_Id, End)),

    % compilo effettivamente (se per qualche motivo fallisce, pulisco tutto)
    (   compile(FA_Id, Re, Start, End)
    ->  true
    ;   nfsa_delete(FA_Id), fail
    ).


% compile(Id, Regex, Start, End)
% aggiunge transizioni nfsa_delta/4 che collegano Start -> End
% in modo che riconosca Regex.

% A) Sequenza: c
compile(Id, Term, Start, End) :-
    compound(Term),
    compound_name_arity(Term, c, N),
    N >= 2,
    Term =.. [c | Args],
    % funzione helper
    compile_seq(Id, Args, Start, End).

% B) Alternativa: a
compile(Id, Term, Start, End) :-
    compound(Term),
    compound_name_arity(Term, a, N),
    N >= 2,
    Term =.. [a | Args],
    % helper
    compile_alt(Id, Args, Start, End).

% C) Kleene: z
% Schema classico:
% Start --eps--> End (0 ripetizioni)
% Start --eps--> S1  (entro nel loop)
% ...compilo Re da S1 a E1...
% E1 --eps--> End (esco)
% E1 --eps--> S1  (ripeto)
compile(Id, z(Re), Start, End) :-
    gensym(q, S1),
    gensym(q, E1),
    assertz(nfsa_delta(Id, Start, epsilon, End)), % 0 volte
    assertz(nfsa_delta(Id, Start, epsilon, S1)),  % entro
    compile(Id, Re, S1, E1),
    assertz(nfsa_delta(Id, E1, epsilon, End)),    % esco
    assertz(nfsa_delta(Id, E1, epsilon, S1)).     % ripeto

% D) Plus: o(re) = re seguito da z(re)
% cioè almeno 1 occorrenza, quindi faccio un Re e poi lo star
compile(Id, o(Re), Start, End) :-
    gensym(q, Mid),
    compile(Id, Re, Start, Mid),
    compile(Id, z(Re), Mid, End).

% E) Simbolo atomico: transizione etichettata dal simbolo
% consuma un elemento della lista input
compile(Id, Sym, Start, End) :-
    atomic(Sym),
    Sym \= epsilon, % epsilon lo teniamo solo per mosse speciali
    assertz(nfsa_delta(Id, Start, Sym, End)).

% F) Simbolo compound non riservato: tipo foo(bar)
% Anche questo consuma un elemento input, ma come simbolo intero.
compile(Id, Sym, Start, End) :-
    compound(Sym),
    compound_name_arity(Sym, F, _),
    \+ reserved(F),
    assertz(nfsa_delta(Id, Start, Sym, End)).


% Sequenza: caso finale
compile_seq(Id, [Last], Start, End) :-
    compile(Id, Last, Start, End).

% Sequenza: creo uno stato intermedio e collego a catena
compile_seq(Id, [H | T], Start, End) :-
    gensym(q, Mid),
    compile(Id, H, Start, Mid),
    compile_seq(Id, T, Mid, End).

% Alternativa: caso finale (ultima alternativa)
compile_alt(Id, [H], Start, End) :-
    compile(Id, H, Start, End).

% Alternativa: per ogni ramo:
% Start --eps--> S1
% (compilo H) S1 ... E1
% E1 --eps--> End
% poi passo al resto della lista T
compile_alt(Id, [H | T], Start, End) :-
    gensym(q, S1),
    gensym(q, E1),
    assertz(nfsa_delta(Id, Start, epsilon, S1)),
    compile(Id, H, S1, E1),
    assertz(nfsa_delta(Id, E1, epsilon, End)),
    compile_alt(Id, T, Start, End).


% nfsa_recognize(FA_Id, Input)
% vero se l'input viene consumato tutto e si può arrivare a uno stato finale.
% Input deve essere lista

nfsa_recognize(FA_Id, Input) :-
    is_list(Input),              % se non è lista fallisco 
    nfsa_init(FA_Id, Start),
    recognize(FA_Id, Start, Input, []).

% Caso 1: input finito e stato finale -> accetto
recognize(Id, Current, [], _) :-
    nfsa_final(Id, Current).

% Caso 2: input finito ma posso ancora muovermi con epsilon fino a un finale.
% Uso Visited per evitare cicli su epsilon 
recognize(Id, Current, [], Visited) :-
    \+ memberchk(Current-[], Visited),
    nfsa_delta(Id, Current, epsilon, Next),
    recognize(Id, Next, [], [Current-[] | Visited]).

% Caso 3: consumo simbolo normale (non epsilon)
% Dopo aver consumato resetto Visited (così riparto pulito sul nuovo input)
recognize(Id, Current, [Sym | Rest], _) :-
    Sym \= epsilon,
    nfsa_delta(Id, Current, Sym, Next),
    recognize(Id, Next, Rest, []).

% Caso 4: epsilon move senza consumare input (qui Visited serve davvero)
recognize(Id, Current, Input, Visited) :-
    \+ memberchk(Current-Input, Visited),
    nfsa_delta(Id, Current, epsilon, Next),
    recognize(Id, Next, Input, [Current-Input | Visited]).



% Cancello un automa specifico (tutti i fatti con quell'Id)
nfsa_delete(FA_Id) :-
    retractall(nfsa_init(FA_Id, _)),
    retractall(nfsa_final(FA_Id, _)),
    retractall(nfsa_delta(FA_Id, _, _, _)).

% Cancello tutti gli automi salvati (pulizia totale)
nfsa_delete_all :-
    retractall(nfsa_init(_, _)),
    retractall(nfsa_final(_, _)),
    retractall(nfsa_delta(_, _, _, _)).
