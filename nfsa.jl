# Mina Kirolos

# -Mode: Julia-
#nfsa.jl
 
# Definiamo cos'è una "Transizione"
struct Transition
    start_state::Any
    symbol::Any
    end_state::Any
end

# Definiamo cos'è un "Automa"
struct Automaton
    init_state::Any
    final_state::Any
    delta::Vector{Transition}
end

# Creiamo il "Database" globale (NFSA_DB) che contiene tutti gli automi
const NFSA_DB = Dict{Any, Automaton}()

# Contatore globale per generare stati nuovi (s_1, s_2...)
const STATE_COUNTER = Ref(0)

# Funzione per generare nomi di stati univoci
function generate_state()
    STATE_COUNTER[] += 1
    return Symbol("s_", STATE_COUNTER[])
end

#funzione is regex
function is_regex(RE)
    if(RE == :epsilon)      #controllo lettera epsilon
        return false
    end

    if(RE isa Symbol || RE isa Number)          #controllo se RE è un atomo
        return true

    elseif(RE isa Expr)                  #controllo se RE è un simbolo complesso
        if((RE.args[1]) in (:c, :a, :z, :o))        #controlla l'operatore per lettere riservate
           return all(is_regex, RE.args[2:end])     #controllo argomenti ricorsivamente
        else
            return true
        end
    end 
    return false
end
#funzione nfsa_compile_regex
function nfsa_compile_regex(FA_Id, RE)
    if(is_regex(RE) == false)              #controllo se i_regex è valida
        error("Regex non valida")
    end
    nfsa_delete(FA_Id)                      #elimina automi pre esistenti con lo stesso FA_Id
    start = generate_state()                #crea lo stato iniziale
    final = generate_state()                #crea lo stato finale
    transitions = Transition[]              #array che contiene i passaggi di stato

    compile!(transitions, RE, start, final)             

    automa = Automaton(start, final, transitions)           #unisce tutti gli stati creando l'automa completo
    NFSA_DB[FA_Id] = automa                                 #Database (archivio) dove vengono memorizzati gli automi
end

function compile!(transitions, RE, start, final)
    if(RE isa Symbol || RE isa Number)                              #controllo se RE è un atomo
        push!(transitions, Transition(start, RE, final))            #collegamento diretto tra lo stato iniziale e finale
        return
    end

    if(RE isa Expr)                                                         #controllo se RE è un simbolo complesso
        if(RE.args[1] in (:c, :a, :z, :o))                                  #controlla se l'operatore è una lettera tra c,a,z,o che sono riservate
            #caso "c" (concatenazione)
            if(RE.args[1] == :c)                                                
                compile_seq!(transitions, RE.args[2:end], start, final)         #richiamo dell'helper di compile_seq
            end
            #caso "a" (Alternato)
            if(RE.args[1] == :a)
                compile_alt!(transitions, RE.args[2:end], start, final)         #richiamo dell'helper di compile_alt
            end
            #caso "z" (chiusura di KLEENE)
            if(RE.args[1] == :z)
                S1 = generate_state()                                           #crea stati iniziale S1
                S2 = generate_state()                                           #crea stati finale S2
                #4 possibili percorsi
                push!(transitions, Transition(start, :epsilon, S1))             #1. INGRESSO: Collega lo stato iniziale all'inizio dell'espressione
                push!(transitions, Transition(S2, :epsilon, final))             #2. USCITA: Collega la fine dell'espressione allo stato finale
                push!(transitions, Transition(start, :epsilon, final))          #3. SALTO (0 volte): Permette di andare subito alla fine senza mai eseguire l'espressione interna
                push!(transitions, Transition(S2, :epsilon, S1))                #4. LOOP (N volte): Dalla fine dell'espressione torna all'inizio per ripeterla
                compile!(transitions, RE.args[2], S1, S2)                       #Compila il contenuto  tra i due stati interni
            end
            #caso "o" (uno o più)
            #stesso funzionamento della chiusura di KLEENE, senza il caso 3. del salto perchè viene eseguito almeno una volta
            if(RE.args[1] == :o)                                        
                S1 = generate_state()
                S2 = generate_state()
                push!(transitions, Transition(start, :epsilon, S1))
                push!(transitions, Transition(S2, :epsilon, final))
                push!(transitions, Transition(S2, :epsilon, S1))
                compile!(transitions, RE.args[2], S1, S2)
            end
        else
            push!(transitions, Transition(start, RE, final))                    #se il funtore non è una lettera riservata crea un collegamento diretto
        end
    end 
end

#nfsa_recognize
function nfsa_recognize(FA_Id, input)                                           #funzione che prende l'automa e avvia la funzione recognize dallo stato iniziale
    
    if(!haskey(NFSA_DB, FA_Id))                                                 #controlla se esiste l'automa nel Database
        error("l'automa non esiste")
    end
    automa = NFSA_DB[FA_Id]
    return recognize(automa, automa.init_state, input)                          #richiamo funzione ricorsiva
end

#funzione recognize
function recognize(automa, stato, input)                                        #funzione ricorsiva
    #caso base                                              
    if(isempty(input) && stato == automa.final_state)                           #controllo se la lista degli input si è svuotata e lo stato corrente è quello finale
        return true
    else
        for t in automa.delta                                                       #esplora tutte le transizioni dell'automa
            if(t.start_state == stato && !isempty(input) && t.symbol == input[1])   #se le condizione sono verificate si procede all'esplorazione ricorsiva dell'automa
                if(recognize(automa, t.end_state, input[2:end]))                    #chiamata ricorsiva di recognize
                    return true
                end
            end
            if(t.start_state == stato && t.symbol == :epsilon)                      #stesso funzionamento con la differenza che non viene consumato un'input al cambio di stato
                if(recognize(automa, t.end_state, input))                           #chiamata ricorsiva di recognize
                    return true
                end
            end
        end
    end
    return false
end

#helper compile
#compile seq
function compile_seq!(transitions, RE, start, final)                     #helper compile caso "c"
    #caso base: se rimane un elemento fa il collegamento finale 
    if(length(RE) == 1)
        elemento = RE[1]
        compile!(transitions, elemento, start, final)                   #chiamata ricorsiva di compile
        return
    end

    mid = generate_state()                                              #creazione stato intermedio
    compile!(transitions, RE[1], start, mid)                            #chiamata ricorsiva per il collegamento iniziale e quelli intermedi
    compile_seq!(transitions, RE[2:end], mid, final)                    #chiamata ricorsiva dei collegamenti intermedi a quello finale
end
#compile alt 
function compile_alt!(transitions, RE, start, final)                    #helper compile caso "a"
    for elemento in RE                                                  #esplorazione di tutti gli elementi di RE
        compile!(transitions, elemento, start, final)                   #collegamento di tutti gli stati tra inizio e la fine in parallelo
    end
end
#funzione nfsa_delete
function nfsa_delete(FA_Id)                                            
    if haskey(NFSA_DB, FA_Id)                                           #controllo se l'automa è nel Database
        delete!(NFSA_DB, FA_Id)                                         #elimina dal Database l'automa
    end
end
