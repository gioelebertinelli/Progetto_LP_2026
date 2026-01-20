% Bertinelli	Gioele	923893
% Gianoli	Matteo	924072
% Martinalli	Marco	924003

:- use_module(library(gensym)).



% --- 1. GESTIONE DELLA BASE DI DATI DINAMICA ---
:- dynamic nfsa_initial/2.
:- dynamic nfsa_final/2.
:- dynamic nfsa_delta/4.

% --- 2. PREDICATI AUSILIARI ---

% Parole chiave riservate agli operatori
reserved(c).
reserved(a).
reserved(z).
reserved(o).
reserved(epsilon).

% --- 3. VALIDATORE (is_regex/1) ---

% Caso base: simboli atomici (es. a, b, 42)
% epsilon è riservato come metasimbolo per ε-transizioni
is_regex(Re) :-
    atomic(Re),
    Re \= epsilon,
    !.

% Simbolo composto trattato come atomico (es. foo(bar))
% purché il funtore non sia riservato
is_regex(Re) :-
    compound(Re),
    functor(Re, F, _),
    \+ reserved(F),
    !.

% Operatori unari: Kleene Star
is_regex(z(Re)) :- 
    is_regex(Re).

% Operatori unari: Plus
is_regex(o(Re)) :- 
    is_regex(Re).

% Operatori n-ari: Sequenza
is_regex(Expr) :-
    compound(Expr),
    functor(Expr, c, N),
    N > 0,
    !,
    Expr =.. [c | Args],
    maplist(is_regex, Args).

% Operatori n-ari: Alternativa
is_regex(Expr) :-
    compound(Expr),
    functor(Expr, a, N),
    N > 0,
    !,
    Expr =.. [a | Args],
    maplist(is_regex, Args).

% --- 4. COMPILATORE (nfsa_compile_regex/2) ---

% nfsa_compile_regex(FA_Id, RE) è vero quando RE è compilabile
% in un automa identificato da FA_Id
nfsa_compile_regex(Id, Re) :-
    nfsa_delete(Id),        % Pulisce eventuali versioni precedenti
    gensym(q, Start),       % Genera stato iniziale
    gensym(q, End),         % Genera stato finale
    assertz(nfsa_initial(Id, Start)),
    assertz(nfsa_final(Id, End)),
    compile(Id, Re, Start, End).

% --- 5. MOTORE DI COMPILAZIONE (Costruzione di Thompson) ---

% A. Sequenza c(re1, re2, ..., ren)
compile(Id, Term, Start, End) :-
    compound(Term),
    functor(Term, c, N),
    N > 0,
    !,
    Term =.. [c | Args],
    compile_seq(Id, Args, Start, End).

% B. Alternativa a(re1, re2, ..., ren)
compile(Id, Term, Start, End) :-
    compound(Term),
    functor(Term, a, N),
    N > 0,
    !,
    Term =.. [a | Args],
    compile_alt(Id, Args, Start, End).

% C. Kleene Star z(re)
compile(Id, z(Re), Start, End) :-
    !,
    gensym(q, S1),
    gensym(q, E1),
    % Percorso zero: epsilon da Start a End
    assertz(nfsa_delta(Id, Start, epsilon, End)),
    % Ingresso nel loop
    assertz(nfsa_delta(Id, Start, epsilon, S1)),
    % Corpo del loop
    compile(Id, Re, S1, E1),
    % Uscita dal loop
    assertz(nfsa_delta(Id, E1, epsilon, End)),
    % Back-edge per ripetizione
    assertz(nfsa_delta(Id, E1, epsilon, S1)).

% D. Plus o(re) = re seguito da z(re)
compile(Id, o(Re), Start, End) :-
    !,
    gensym(q, Mid),
    compile(Id, Re, Start, Mid),
    compile(Id, z(Re), Mid, End).

% E. Simbolo atomico
compile(Id, Sym, Start, End) :-
    atomic(Sym),
    Sym \= epsilon,
    !,
    assertz(nfsa_delta(Id, Start, Sym, End)).

% F. Simbolo compound (es. foo(bar))
compile(Id, Sym, Start, End) :-
    compound(Sym),
    functor(Sym, F, _),
    \+ reserved(F),
    !,
    assertz(nfsa_delta(Id, Start, Sym, End)).

% --- 6. PREDICATI DI SUPPORTO PER COMPILAZIONE ---

% Compilazione di sequenza: caso base (ultimo elemento)
compile_seq(Id, [Last], Start, End) :-
    !,
    compile(Id, Last, Start, End).

% Compilazione di sequenza: caso ricorsivo
compile_seq(Id, [H | T], Start, End) :-
    gensym(q, Mid),
    compile(Id, H, Start, Mid),
    compile_seq(Id, T, Mid, End).

% Compilazione di alternativa: caso base (ultimo elemento)
compile_alt(Id, [H], Start, End) :-
    !,
    gensym(q, S1),
    gensym(q, E1),
    assertz(nfsa_delta(Id, Start, epsilon, S1)),
    compile(Id, H, S1, E1),
    assertz(nfsa_delta(Id, E1, epsilon, End)).

% Compilazione di alternativa: caso ricorsivo
compile_alt(Id, [H | T], Start, End) :-
    gensym(q, S1),
    gensym(q, E1),
    % Branch per opzione corrente
    assertz(nfsa_delta(Id, Start, epsilon, S1)),
    compile(Id, H, S1, E1),
    assertz(nfsa_delta(Id, E1, epsilon, End)),
    % Ricorsione sulle altre alternative
    compile_alt(Id, T, Start, End).

% --- 7. RICONOSCITORE (nfsa_recognize/2) ---

% nfsa_recognize(FA_Id, Input) è vero quando l'input è completamente
% consumato e l'automa si trova in uno stato finale
nfsa_recognize(Id, Input) :-
    is_list(Input),
    nfsa_initial(Id, Start),
    nfsa_final(Id, Final),
    recognize(Id, Start, Final, Input, []).

% Caso base: input finito, nello stato finale
recognize(_, Current, Final, [], _) :-
    Current = Final,
    !.

% Caso base: input finito, non nello stato finale
% Prova epsilon-transizioni verso il finale
recognize(Id, Current, Final, [], Visited) :-
    nfsa_delta(Id, Current, epsilon, Next),
    \+ memberchk(Next-[], Visited),
    recognize(Id, Next, Final, [], [Next-[] | Visited]).

% Consumo di un simbolo
recognize(Id, Current, Final, [Sym | Rest], _) :-
    nfsa_delta(Id, Current, Sym, Next),
    Sym \= epsilon,
    recognize(Id, Next, Final, Rest, []).

% Epsilon-transizione senza consumare input
% (solo quando c'è ancora input da processare)
recognize(Id, Current, Final, Input, Visited) :-
    Input \= [],
    nfsa_delta(Id, Current, epsilon, Next),
    \+ memberchk(Next-Input, Visited),
    recognize(Id, Next, Final, Input, [Next-Input | Visited]).

% --- 8. GESTIONE DELLA BASE DI DATI ---

% Cancella tutti gli automi dalla base di dati
nfsa_delete_all :-
    retractall(nfsa_initial(_, _)),
    retractall(nfsa_final(_, _)),
    retractall(nfsa_delta(_, _, _, _)).

% Cancella un automa specifico dalla base di dati
nfsa_delete(Id) :-
    retractall(nfsa_initial(Id, _)),
    retractall(nfsa_final(Id, _)),
    retractall(nfsa_delta(Id, _, _, _)).
