% Mina Kirolos

% -Mode: Prolog-
% nfsa.pl

:- dynamic nfsa_init/2.
:- dynamic nfsa_final/2.
:- dynamic nfsa_delta/4.

%Caso Base 
%Caso epsilon diverso da RE:
is_regex(epsilon) :- 
    !,
    fail.

%Caso 1: Atomi e numeri sono regex
is_regex(RE) :-
    atomic(RE).

%caso 2: simboli complessi, controllo se tra i simboli 
%che sono presenti termini composti, che riservano pero c,a,z,o
is_regex(RE) :-
    compound(RE),   %built in
    compound_name_arguments(RE, Functor, _), %built in
    \+ member(Functor, [c, a, z, o]). %il + sarebbe un NOT


%se RE è un comando regex, avviene un controllo completo
is_regex(RE) :-
    compound(RE),   %deve essere composto
    compound_name_arguments(RE, Functor, Args),     %smonta le parti composte
    member(Functor, [c, a, z, o]),  %controlla se il funtore è uno tra c,a,z,o
    maplist(is_regex, Args).   %applica is_regex a ogni elemento di Args

nfsa_compile_regex(FA_Id, RE) :-
    % -1: controllo se è una regex valida
    is_regex(RE),

    % -2: se esiste gia un automa con questo id, lo elimina
    nfsa_delete(FA_Id),

    % -3: gensym crea l'inizio e la fine dell'automa
    gensym(state, Start),
    gensym(state, End),

    % -4: imponiamo l'inizio e la fine dell'automa FA_Id
    assert(nfsa_init(FA_Id, Start)),   % l'automa FA_Id parte da start
    assert(nfsa_final(FA_Id, End)),    % l'automa FA_Id finisce a end

    % -5: la predicato compile definita si occupa di creare il percorso
    % tra l'inizio e la fine dell'automa 
    compile(FA_Id, RE, Start, End).

% caso 1: definizione predicato compile "c" (concatenazione)

compile(FA_Id, Term, Start, End) :-
    compound(Term),          % controllo se il termine composto
    Term =.. [c | Args],        % scomposizione del termine composto in una lista
    !,
    compile_seq(FA_Id, Args, Start, End).       % applichiamo l'helper compile "c"


% caso 2: definizione predicato compile "a"

compile(FA_Id, Term, Start, End) :-
    compound(Term),          % controllo se il termine composto
    Term =.. [a | Args],        % scomposizione del termine composto in una lista
    !,
    compile_alt(FA_Id, Args, Start, End).       % applichiamo l'helper compile "a"

% caso 3: definizione predicato compile "z" (chiusura di KLEENE)

compile(FA_Id, Term, Start, End) :-
    compound(Term),
    Term =.. [z, Args],
    !,                                  % cut per evitare il backtracking sulle regole successive
    gensym(state, S1),
    gensym(state, S2),
    assert(nfsa_delta(FA_Id, Start, epsilon, S1)),  % Entra nel circuito
    assert(nfsa_delta(FA_Id, S2, epsilon, End)),    % Esce dal circuito
    assert(nfsa_delta(FA_Id, Start, epsilon, End)), % Salta tutto (caso "zero volte")
    assert(nfsa_delta(FA_Id, S2, epsilon, S1)),     % Torna indietro (loop)
    % Compiliamo il contenuto Args dentro il circuito
    compile(FA_Id, Args, S1, S2).

% caso 4: definizione predicato compile "o" (simile alla chiusura di KLEENE)

compile(FA_Id, Term, Start, End) :-
    compound(Term),
    Term =.. [o, Args],
    !,                                  % cut per evitare il backtracking sulle regole successive
    gensym(state, S1),
    gensym(state, S2),
    assert(nfsa_delta(FA_Id, Start, epsilon, S1)),  % Entra nel circuito
    assert(nfsa_delta(FA_Id, S2, epsilon, End)),    % Esce dal circuito
    assert(nfsa_delta(FA_Id, S2, epsilon, S1)),     % Torna indietro (loop)
    compile(FA_Id, Args, S1, S2).

% caso 5: compile simbolo semplice (atomo o numero)

compile(FA_Id, Simbolo, Start, End) :-
    atomic(Simbolo),
    !,                  % cut inserito per evitare duplicazione del percorso nel caso 6
    assert(nfsa_delta(FA_Id, Start, Simbolo, End)).  % crea il collegamento diretto

% caso 6: compile simbolo complesso

compile(FA_Id, Simbolo, Start, End) :-
    assert(nfsa_delta(FA_Id, Start, Simbolo, End)).

%----------------------------
% helper compile
% helper compile "c": crea collegamento tra gli elementi
% caso base: rimane solo un elemento tra gli argomenti
compile_seq(FA_Id, [Ultimo], Start, End) :-
    !,
    compile(FA_Id, Ultimo, Start, End).     % concatena l'elemento rimasto

% caso ricorsivo: caso con più argomenti rimanenti
compile_seq(FA_Id, [H | Args], Start, End) :-
    gensym(state, Mid),                         % crea stato mid
    compile(FA_Id, H, Start, Mid),              % concatena la testa della lista
    compile_seq(FA_Id, Args, Mid, End).         %chiamata ricorsiva con gli argomenti rimanenti

% helper compile "a": collega gli elementi in parallelo
% caso base
compile_alt( _, [], _, _). % lista vuota finisce subito

% caso ricorsivo
compile_alt(FA_Id, [H | Args], Start, End) :-
    compile(FA_Id, H, Start, End),              % direttamente da Start a End
    compile_alt(FA_Id, Args, Start, End).       % esegue lo stesso con gli argomenti rimanenti

% nfsa_recognize

nfsa_recognize(FA_Id, Input) :-
    nfsa_init(FA_Id, Start),
    recognize(FA_Id, Start, Input).

% caso 1: la lista è vuota quindi siamo nello stato finale
recognize(FA_Id, Stato, []) :-
    nfsa_final(FA_Id, Stato). 

% caso 2: transizione standard (utilizzando il "simbolo" cerchiamo se esiste almeno una transizione)
recognize(FA_Id, Stato, [Simbolo | Resto]) :-
    nfsa_delta(FA_Id, Stato, Simbolo, StatoSucc),   % cerca la transizione
    recognize(FA_Id, StatoSucc, Resto).             % passa allo stato successivo con il resto

% caso 3: transizione con Epsilon (senza modificare la lista input)
recognize(FA_Id, Stato, Input) :-
    nfsa_delta(FA_Id, Stato, epsilon, StatoSucc),
    recognize(FA_Id, StatoSucc, Input).

% definizione nfsa_delete (per pulizia)
nfsa_delete(FA_Id) :-
    retractall(nfsa_init(FA_Id, _)),            % cancella lo stato iniziale
    retractall(nfsa_final(FA_Id, _)),           % cancella lo stato finale
    retractall(nfsa_delta(FA_Id, _, _, _)).     % cancella tutti i percorsi intermedi

nfsa_delete_all :-
   retractall(nfsa_init(_, _)),            % cancella lo stato iniziale di tutti gli automi creati
    retractall(nfsa_final(_, _)),           % cancella lo stato finale di tutti gli automi creati
    retractall(nfsa_delta(_, _, _, _)).     % cancella tutti i percorsi intermedi di tutti gli automi creati
    