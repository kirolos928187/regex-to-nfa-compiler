# Da espressioni regolari ad automi NFSA

Questo è un progetto che ho fatto per il corso di Linguaggi di Programmazione (2026). Il programma prende un'espressione regolare, la trasforma in un automa a stati finiti non deterministico (con ε-transizioni) e poi permette di controllare se una lista di simboli viene accettata dall'automa.

L'ho scritto due volte, una in **Prolog** e una in **Julia**, con la stessa interfaccia. Così ho potuto vedere bene le differenze tra i due modi di ragionare.

## Cosa si può scrivere nelle espressioni

- un simbolo semplice (un atomo o un numero), per esempio `a` o `1`
- `c(R1, ..., Rn)`: concatenazione
- `a(R1, ..., Rn)`: alternativa, cioè R1 oppure R2 e così via
- `z(R)`: chiusura di Kleene, R ripetuta zero o più volte
- `o(R)`: R ripetuta una o più volte
- qualsiasi altro termine composto viene trattato come un unico simbolo

`c`, `a`, `z`, `o` sono nomi riservati e `epsilon` non è una regex valida, perché lo uso internamente per le ε-transizioni.

## Funzioni

- `nfsa_compile_regex(Id, RE)` controlla la regex, cancella l'automa che aveva già lo stesso `Id` e ne costruisce uno nuovo
- `nfsa_recognize(Id, Input)` dice se l'input è accettato dall'automa
- `nfsa_delete(Id)` elimina un automa
- `nfsa_delete_all` elimina tutti gli automi (solo in Prolog)

## Esempi

Prolog:

```prolog
?- consult('prolog/nfsa.pl').
?- nfsa_compile_regex(a1, c(a, z(b))).
?- nfsa_recognize(a1, [a, b, b]).
true.
?- nfsa_recognize(a1, [b, a]).
false.
```

Julia:

```julia
include("julia/nfsa.jl")
nfsa_compile_regex(:a1, :(c(a, z(b))))
nfsa_recognize(:a1, [:a, :b, :b])   # true
nfsa_recognize(:a1, [:b, :a])       # false
```

## Come l'ho fatto

Ogni parte della regex viene compilata tra uno stato di partenza e uno di arrivo, creando stati nuovi quando servono. Un simbolo diventa una transizione diretta. La concatenazione collega le parti con stati intermedi. L'alternativa mette tutti i rami in parallelo tra gli stessi due stati. Per `z` e `o` ho aggiunto due stati interni e delle ε-transizioni per entrare, uscire e ripetere (in `o` manca quella che permette di saltare tutto, perché l'espressione va eseguita almeno una volta).

In Prolog gli automi sono salvati come fatti dinamici (`nfsa_init`, `nfsa_final`, `nfsa_delta`). In Julia ho usato due struct, `Transition` e `Automaton`, e un dizionario globale che le contiene.

Il riconoscimento parte dallo stato iniziale e prova le transizioni una alla volta: con un simbolo normale consuma un elemento dell'input, con `epsilon` non ne consuma. Se alla fine l'input è finito e siamo nello stato finale, l'input è accettato. In Prolog il lavoro di provare le alternative lo fa il backtracking, in Julia ho dovuto scrivere io il ciclo sulle transizioni.

## Limiti

Con chiusure annidate come `z(z(a))` si formano cicli di ε-transizioni e il riconoscitore può andare in loop, perché non tengo traccia degli stati già visitati. In Julia le espressioni vanno scritte con `:( ... )`.

## Struttura

```
prolog/nfsa.pl
julia/nfsa.jl
```
