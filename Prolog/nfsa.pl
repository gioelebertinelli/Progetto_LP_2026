% Bertinelli	Gioele	923893
% Gianoli	Matteo	924072
% Martinalli	Marco	924003


:- use_module(library(gensym)).

% ============================================================
% 0) FUNZIONI DI SUPPORTO
% ============================================================

reserved(c).
reserved(a).
reserved(z).
reserved(o).

% ============================================================
% 1) BASE DI DATI DINAMICA
% ============================================================

:- dynamic nfsa_init/2.
:- dynamic nfsa_final/2.
:- dynamic nfsa_delta/4.

% ============================================================
% 3) VALIDATORE: is_regex/1
% ============================================================

% Variabili non ammesse
is_regex(Re) :-
    var(Re),
    !,
    fail.

% Caso base: simboli atomici (a, b, 42, epsilon, ...)
is_regex(Re) :-
    atomic(Re).

% Operatori unari
is_regex(z(Re)) :-
    is_regex(Re).

is_regex(o(Re)) :-
    is_regex(Re).

% Operatori n-ari: sequenza c(...)
is_regex(Expr) :-
    compound(Expr),
    functor(Expr, c, N),
    N >= 2,
    Expr =.. [c | Args],
    maplist(is_regex, Args).

% Operatori n-ari: alternativa a(...)
is_regex(Expr) :-
    compound(Expr),
    functor(Expr, a, N),
    N >= 2,
    Expr =.. [a | Args],
    maplist(is_regex, Args).

% Simboli compound come foo(bar), zio_di(Achille), ... sono simboli validi
% purché il funtore non sia riservato come operatore regex
is_regex(Re) :-
    compound(Re),
    functor(Re, F, _),
    \+ reserved(F).

% ============================================================
% 4) COMPILAZIONE REGEX -> NFSA (Thompson)
% ============================================================

nfsa_compile_regex(FA_Id, Re) :-
    ground(FA_Id),
    is_regex(Re),
    nfsa_delete(FA_Id),
    gensym(q, Start),
    gensym(q, End),
    assertz(nfsa_init(FA_Id, Start)),
    assertz(nfsa_final(FA_Id, End)),
    (   compile(FA_Id, Re, Start, End)
    ->  true
    ;   nfsa_delete(FA_Id), fail
    ).

% ============================================================
% 5) MOTORE DI COMPILAZIONE (Thompson)
%
% Convenzioni:
% - epsilon-transition: etichetta eps (NON consuma input)
% - transizione che consuma un simbolo X: etichetta sym(X)
% ============================================================

% A. Sequenza c(re1, re2, ..., ren)
compile(Id, Term, Start, End) :-
    compound(Term),
    functor(Term, c, N),
    N >= 2,
    Term =.. [c | Args],
    compile_seq(Id, Args, Start, End).

% B. Alternativa a(re1, re2, ..., ren)
compile(Id, Term, Start, End) :-
    compound(Term),
    functor(Term, a, N),
    N >= 2,
    Term =.. [a | Args],
    compile_alt(Id, Args, Start, End).

% C. Kleene Star z(re)
compile(Id, z(Re), Start, End) :-
    gensym(q, S1),
    gensym(q, E1),

    % 0 ripetizioni: Start -> End
    assertz(nfsa_delta(Id, Start, eps, End)),

    % entra nel loop: Start -> S1
    assertz(nfsa_delta(Id, Start, eps, S1)),

    % corpo loop
    compile(Id, Re, S1, E1),

    % esci dal loop: E1 -> End
    assertz(nfsa_delta(Id, E1, eps, End)),

    % ripeti: E1 -> S1
    assertz(nfsa_delta(Id, E1, eps, S1)).

% D. Plus o(re) = re seguito da z(re)
compile(Id, o(Re), Start, End) :-
    gensym(q, Mid),
    compile(Id, Re, Start, Mid),
    compile(Id, z(Re), Mid, End).

% E. Simbolo atomico (consuma input)
compile(Id, Sym, Start, End) :-
    atomic(Sym),
    assertz(nfsa_delta(Id, Start, sym(Sym), End)).

% F. Simbolo compound non riservato (consuma input)
compile(Id, Sym, Start, End) :-
    compound(Sym),
    functor(Sym, F, _),
    \+ reserved(F),
    assertz(nfsa_delta(Id, Start, sym(Sym), End)).

% ============================================================
% 6) SUPPORTO COMPILAZIONE: sequenza e alternativa
% ============================================================

% Sequenza: caso base (un solo elemento)
compile_seq(Id, [Last], Start, End) :-
    compile(Id, Last, Start, End).

% Sequenza: caso ricorsivo
compile_seq(Id, [H | T], Start, End) :-
    gensym(q, Mid),
    compile(Id, H, Start, Mid),
    compile_seq(Id, T, Mid, End).

% Alternativa: caso base (una sola alternativa)
compile_alt(Id, [H], Start, End) :-
<<<<<<< HEAD
    compile(Id, H, Start, End).
=======
    gensym(q, S1),
    gensym(q, E1),
    assertz(nfsa_delta(Id, Start, eps, S1)),
    compile(Id, H, S1, E1),
    assertz(nfsa_delta(Id, E1, eps, End)).
>>>>>>> ef677049d1622ccda5709eac2ede4edb4565b257

% Alternativa: caso ricorsivo
compile_alt(Id, [H | T], Start, End) :-
    gensym(q, S1),
    gensym(q, E1),
    assertz(nfsa_delta(Id, Start, eps, S1)),
    compile(Id, H, S1, E1),
    assertz(nfsa_delta(Id, E1, eps, End)),
    compile_alt(Id, T, Start, End).

% ============================================================
% 7) RICONOSCITORE: nfsa_recognize/2
% ============================================================

% nfsa_recognize(FA_Id, Input) è vero quando l'input è completamente
% consumato e l'automa può arrivare in UNO stato finale
nfsa_recognize(FA_Id, Input) :-
    is_list(Input),
    nfsa_init(FA_Id, Start),
    recognize(FA_Id, Start, Input, []).

% Se input è finito: accetta se Current è finale
recognize(Id, Current, [], _) :-
    nfsa_final(Id, Current).

% Se input è finito: prova ancora epsilon-transizioni (senza cicli)
recognize(Id, Current, [], Visited) :-
    \+ memberchk(Current-[], Visited),
    nfsa_delta(Id, Current, eps, Next),
    recognize(Id, Next, [], [Current-[] | Visited]).

% Consumo di un simbolo (transizione etichettata sym(Sym))
recognize(Id, Current, [Sym | Rest], _) :-
    nfsa_delta(Id, Current, sym(Sym), Next),
    recognize(Id, Next, Rest, []).

% Epsilon-transizione senza consumare input (senza cicli)
recognize(Id, Current, Input, Visited) :-
    \+ memberchk(Current-Input, Visited),
    nfsa_delta(Id, Current, eps, Next),
    recognize(Id, Next, Input, [Current-Input | Visited]).


nfsa_delete_all :-
    retractall(nfsa_init(_, _)),
    retractall(nfsa_final(_, _)),
    retractall(nfsa_delta(_, _, _, _)).

% Cancella un automa specifico dalla base di dati
nfsa_delete(FA_Id) :-
    retractall(nfsa_init(FA_Id, _)),
    retractall(nfsa_final(FA_Id, _)),
    retractall(nfsa_delta(FA_Id, _, _, _)).
