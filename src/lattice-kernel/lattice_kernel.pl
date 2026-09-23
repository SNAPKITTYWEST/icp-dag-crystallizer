%% SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0
%% CLONE_GATE: lattice_kernel_pl
%%
%% lattice_kernel.pl — Relational Lattice Kernel (ISO Prolog)
%%
%% Same relations as mu_kanren.scm as portable ISO predicates.
%% Optional CLP(FD) adder via use_module(library(clpfd)).
%% Compatible with SWI-Prolog, GNU Prolog, SICStus.
%%
%% Run: swipl -s lattice_kernel.pl
%%      ?- demo.

:- use_module(library(lists)).

%% ============================================================
%% 1. LIST RELATIONS
%% ============================================================

conso(A, D, [A|D]).
nullo([]).
caro([A|_], A).
cdro([_|D], D).
pairo([_|_]).

listo([]).
listo([_|D]) :- listo(D).

appendo([], S, S).
appendo([A|D], S, [A|R]) :- appendo(D, S, R).

membero(X, [X|_]).
membero(X, [_|T]) :- membero(X, T).

rembero(_, [], []).
rembero(X, [X|D], D) :- !.
rembero(X, [A|D], [A|R]) :- X \= A, rembero(X, D, R).

reverseo(L, O) :- rev_acco(L, [], O).
rev_acco([], Acc, Acc).
rev_acco([A|D], Acc, O) :- rev_acco(D, [A|Acc], O).

lengtho([], z).
lengtho([_|D], s(N)) :- lengtho(D, N).

distincto([]).
distincto([A|D]) :- \+ member(A, D), distincto(D).

permuteo([], []).
permuteo([A|D], O) :-
    permuteo(D, R),
    inserto(A, R, O).

inserto(X, L, [X|L]).
inserto(X, [A|D], [A|R]) :- inserto(X, D, R).

zipo([], [], []).
zipo([A|DA], [B|DB], [[A,B]|R]) :- zipo(DA, DB, R).

takeo(0, _, []) :- !.
takeo(s(N), [A|D], [A|R]) :- takeo(N, D, R).

dropo(0, L, L) :- !.
dropo(s(N), [_|D], O) :- dropo(N, D, O).

filtero(_, [], []).
filtero(P, [A|D], Out) :-
    ( call(P, A) ->
        filtero(P, D, R), Out = [A|R]
    ; filtero(P, D, Out)
    ).

%% ============================================================
%% 2. PEANO ARITHMETIC
%% ============================================================

zeroo(z).
succo(N, s(N)).
nato(z).
nato(s(N)) :- nato(N).

addo(z, Y, Y).
addo(s(X), Y, s(Z)) :- addo(X, Y, Z).

mulo(z, _, z).
mulo(s(X), Y, Z) :-
    mulo(X, Y, Z1),
    addo(Y, Z1, Z).

leq_nato(z, _).
leq_nato(s(X), s(Y)) :- leq_nato(X, Y).

%% ============================================================
%% 3. BIT ARITHMETIC — FULL ADDER
%% ============================================================

bito(0).
bito(1).

half_addo(0, 0, 0, 0).
half_addo(0, 1, 1, 0).
half_addo(1, 0, 1, 0).
half_addo(1, 1, 0, 1).

full_addo(A, B, Cin, S, Cout) :-
    bito(A), bito(B), bito(Cin),
    half_addo(A, B, W, C1),
    half_addo(W, Cin, S, C2),
    ( C1 =:= 1 ; C2 =:= 1 -> Cout = 1 ; Cout = 0 ).

%% CLP(FD) adder (loaded conditionally)
:- ( catch(use_module(library(clpfd)), _, true) ->
       assert(clpfd_available)
   ; true
   ).

full_addo_clp(A, B, Cin, S, Cout) :-
    clpfd_available, !,
    [A, B, Cin, S, Cout] ins 0..1,
    S #= (A + B + Cin) mod 2,
    Cout #= (A + B + Cin) // 2.
full_addo_clp(A, B, Cin, S, Cout) :-
    full_addo(A, B, Cin, S, Cout).

%% n-bit ripple-carry adder
addero([], [], [], Cin, Cin).
addero([A|As], [B|Bs], [S|Ss], Cin, Cout) :-
    full_addo(A, B, Cin, S, Cmid),
    addero(As, Bs, Ss, Cmid, Cout).

%% ============================================================
%% 4. RELATIONAL INTERPRETER (evalo)
%% ============================================================

:- dynamic edb/3, edb/4, fsm_transition/5.

lookupo(X, [[X,V]|_], V) :- !.
lookupo(X, [[Y,_]|Rest], V) :-
    X \= Y,
    lookupo(X, Rest, V).

eval_expro(quote(Q), _, Q).
eval_expro(X, Env, V) :-
    atom(X), \+ X = quote, \+ X = lambda, \+ X = cons,
    \+ X = car, \+ X = cdr, \+ X = if, \+ X = 'null?',
    lookupo(X, Env, V).
eval_expro(lambda(P, B), Env, closure(P, B, Env)).
eval_expro(app(Rator, Rand), Env, V) :-
    eval_expro(Rator, Env, Clo),
    eval_expro(Rand, Env, Arg),
    applyo(Clo, Arg, V).
eval_expro(cons(A, D), Env, [VA|VD]) :-
    eval_expro(A, Env, VA),
    eval_expro(D, Env, VD).
eval_expro(car(E), Env, V) :-
    eval_expro(E, Env, [V|_]).
eval_expro(cdr(E), Env, V) :-
    eval_expro(E, Env, [_|V]).
eval_expro(if(C, T, El), Env, V) :-
    eval_expro(C, Env, CV),
    ( CV \= false -> eval_expro(T, Env, V)
    ; eval_expro(El, Env, V)
    ).

applyo(closure(P, B, Env), Arg, V) :-
    eval_expro(B, [[P,Arg]|Env], V).

evalo(Exp, Val) :- eval_expro(Exp, [], Val).

%% ============================================================
%% 5. SMT STUB
%% ============================================================

smt_and(A, B, and(A, B)).
smt_not(A, not(A)).
smt_var(N, var(N)).

is_sat(Phi) :-
    collect_atoms(Phi, [], Atoms),
    \+ contradiction(Atoms).

collect_atoms(and(A, B), Acc, Out) :- !,
    collect_atoms(A, Acc, Acc1),
    collect_atoms(B, Acc1, Out).
collect_atoms(X, Acc, [X|Acc]).

contradiction(Atoms) :-
    member(not(P), Atoms),
    member(P, Atoms).

%% ============================================================
%% 6. EDB FACT STORE
%% ============================================================

assert_edb(Rel, A, B) :- assertz(edb(Rel, A, B)).
assert_edb(Rel, A, B, C) :- assertz(edb(Rel, A, B, C)).

factso(Rel, A, B) :- edb(Rel, A, B).
factso(Rel, A, B, C) :- edb(Rel, A, B, C).

%% ============================================================
%% 7. PARAMETERIZED PATH / REACHABILITY
%% ============================================================

%% patho(+Rel, +X, ?Y, -Path, -Phi)
patho(Rel, X, Y, path(Y), Phi) :-
    factso(Rel, X, Y, Phi),
    is_sat(Phi).
patho(Rel, X, Y, path(Z, P), and(E, Phi2)) :-
    factso(Rel, X, Z, E),
    is_sat(E),
    patho(Rel, Z, Y, P, Phi2).

reacho(_, S, S).
reacho(Rel, S, T) :-
    edb(Rel, S, M),
    reacho(Rel, M, T).

%% ============================================================
%% 8. FSM RELATIONS
%% ============================================================

register_fsm(Id) :-
    assertz(fsm_transition(Id, s0, 0, s0, 0)),
    assertz(fsm_transition(Id, s0, 1, s1, 0)),
    assertz(fsm_transition(Id, s1, 0, s0, 1)),
    assertz(fsm_transition(Id, s1, 1, s1, 1)).

fsmo(Id, St, Inp, Nst, Out) :-
    fsm_transition(Id, St, Inp, Nst, Out).

%% fsm_traceo(+Id, +S0, +Inputs, -Outputs)
fsm_traceo(_, _, [], []).
fsm_traceo(Id, S, [I|Rest], [O|RestO]) :-
    fsmo(Id, S, I, S1, O),
    fsm_traceo(Id, S1, Rest, RestO).

%% ============================================================
%% 9. REFINEMENT LATTICE
%% ============================================================

refineo(conc(C), C, refined).
refineo(top, _, refined).
refineo(interval(Lo, Hi), N, refined) :-
    leq_nato(Lo, N),
    leq_nato(N, Hi).

refineo_nat(conc(C), C).
refineo_nat(top, _).
refineo_nat(interval(Lo, Hi), N) :-
    integer(Lo), integer(Hi), integer(N),
    Lo =< N, N =< Hi.

%% ============================================================
%% 10. HIGHER-ORDER LIST OPERATIONS
%% ============================================================

mapo(_, [], []).
mapo(Goal, [A|D], [B|R]) :-
    call(Goal, A, B),
    mapo(Goal, D, R).

foldo(_, [], Acc, Acc).
foldo(Goal, [A|D], Acc, Out) :-
    call(Goal, A, Acc, NAcc),
    foldo(Goal, D, NAcc, Out).

%% ============================================================
%% 11. SEED DATA
%% ============================================================

seed_db :-
    retractall(edb(_, _, _)),
    retractall(edb(_, _, _, _)),
    retractall(fsm_transition(_, _, _, _, _)),
    assert_edb(edge, 0, 1, bv_slt(var(x), var(y))),
    assert_edb(edge, 1, 2, bv_slt(var(y), var(z))),
    assert_edb(edge, 2, 3, and(var(p), not(var(q)))),
    assert_edb(edge, 0, 2),
    assert_edb(edge, 1, 3),
    register_fsm(fsm0).

%% ============================================================
%% 12. DEMO / SMOKE TEST
%% ============================================================

demo :-
    seed_db,
    format('=== lattice_kernel.pl ===~n'),

    format('~nappendo([1,2],[3],?): '),
    findall(Q, appendo([1,2],[3],Q), R1),
    format('~w~n', [R1]),

    format('addo(s(z),s(s(z)),?): '),
    findall(Q, addo(s(z),s(s(z)),Q), R2),
    format('~w~n', [R2]),

    format('full_addo(1,1,0,S,C): '),
    findall(S-C, full_addo(1,1,0,S,C), R3),
    format('~w~n', [R3]),

    format('evalo: '),
    findall(V, evalo(app(lambda(x,x),quote(hello)),V), R4),
    format('~w~n', [R4]),

    format('reacho from 0: '),
    findall(T, reacho(edge,0,T), R5),
    sort(R5, R5s),
    format('~w~n', [R5s]),

    format('fsm_traceo [0,1,0]: '),
    findall(O, fsm_traceo(fsm0,s0,[0,1,0],O), R6),
    format('~w~n', [R6]),

    format('refineo interval: '),
    findall(R, refineo(interval(s(z),s(s(s(z)))),s(s(z)),R), R7),
    format('~w~n', [R7]),

    format('is_sat true: '),
    ( is_sat(and(var(p), not(var(q)))) -> format('sat~n') ; format('unsat~n') ),
    format('is_sat contradiction: '),
    ( is_sat(and(var(p), not(var(p)))) -> format('sat~n') ; format('unsat~n') ),

    format('~n=== COMPLETE ===~n').

:- initialization(demo, main).
