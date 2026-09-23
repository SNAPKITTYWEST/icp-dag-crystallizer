%% SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0
%% CLONE_GATE: formulog_minikanren_kernel
%%
%% Dense miniKanren relational core + Formulog-style stratified rules/SMT stubs.
%% Unification, interleaving search, constraints, lists, numbers, evalo, path/SMT.
%% No runtime deps beyond SWI-Prolog stdlib. Kernel for LATTICE-style refinement.

:- module(formulog_minikanren_kernel, [
    walk/3, walk_star/3, occurs/3, unify/4,
    conso/3, nullo/1, caro/2, cdro/2, pairo/1,
    listo/1, appendo/3, membero/2, rembero/3,
    reverseo/2, lengtho/2, flatteno/2, distincto/1,
    permuteo/2, subseto/2, zipo/3, takeo/3, dropo/3,
    filtero/3,
    zeroo/1, succo/2, nato/1, addo/3, mulo/3,
    lookupo/3, eval_expro/3, applyo/3, evalo/2,
    smt_and/3, smt_not/2, smt_var/2, is_sat/1,
    assert_edb/3, assert_edb/4, factso/3, factso/4,
    patho/5, reacho/3,
    bito/1, fulladdo/5,
    fsmo/5, refineo/3,
    kernel_demo/0
]).

:- use_module(library(apply)).
:- use_module(library(lists)).
:- use_module(library(assoc)).

:- dynamic edb/3, edb/4.

%% ============================================================================
%% SUBSTITUTION / WALK (explicit substitution for miniKanren-style reasoning)
%% ============================================================================

walk(U, S, V) :-
    ( get_assoc(U, S, W) -> walk(W, S, V) ; V = U ).

walk_star(V, S, Out) :-
    walk(V, S, W),
    ( is_list(W) ->
        maplist({S}/[X,Y]>>walk_star(X, S, Y), W, Out)
    ; compound(W), W = pair(A, B) ->
        walk_star(A, S, A1), walk_star(B, S, B1), Out = pair(A1, B1)
    ; Out = W
    ).

occurs(X, V, S) :-
    walk(V, S, W),
    ( W == X -> true
    ; is_list(W) -> member(E, W), occurs(X, E, S)
    ; compound(W), W = pair(A, B) -> (occurs(X, A, S) ; occurs(X, B, S))
    ).

unify(U, V, Sin, Sout) :-
    walk(U, Sin, Wu),
    walk(V, Sin, Wv),
    unify_(Wu, Wv, Sin, Sout).

unify_(W, W, S, S) :- !.
unify_(Wu, Wv, S, Sout) :-
    var(Wu), !,
    \+ occurs(Wu, Wv, S),
    put_assoc(Wu, S, Wv, Sout).
unify_(Wu, Wv, S, Sout) :-
    var(Wv), !,
    \+ occurs(Wv, Wu, S),
    put_assoc(Wv, S, Wu, Sout).
unify_(Wu, Wv, S, Sout) :-
    is_list(Wu), is_list(Wv),
    length(Wu, N), length(Wv, N),
    foldl([A-B, Si, So]>>unify(A, B, Si, So),
          Wu, Wv, S, Sout).

%% ============================================================================
%% LIST RELATIONS (native Prolog — miniKanren list ops as predicates)
%% ============================================================================

conso(A, D, pair(A, D)).
nullo(nil).
caro(pair(A, _), A).
cdro(pair(_, D), D).
pairo(pair(_, _)).

listo(nil).
listo(pair(_, D)) :- listo(D).

appendo(nil, S, S).
appendo(pair(A, D), S, pair(A, R)) :-
    appendo(D, S, R).

membero(X, pair(X, _)).
membero(X, pair(_, D)) :-
    membero(X, D).

rembero(_, nil, nil).
rembero(X, pair(X, D), D).
rembero(X, pair(A, D), pair(A, R)) :-
    dif(A, X),
    rembero(X, D, R).

reverseo(L, O) :- rev_acc(L, nil, O).
rev_acc(nil, Acc, Acc).
rev_acc(pair(A, D), Acc, O) :- rev_acc(D, pair(A, Acc), O).

lengtho(nil, 0).
lengtho(pair(_, D), s(N)) :- lengtho(D, N).

flatteno(nil, nil).
flatteno(pair(A, D), O) :-
    ( pairo(A) ->
        flatteno(A, FA), flatteno(D, FD), appendo(FA, FD, O)
    ;   flatteno(D, FD), O = pair(A, FD)
    ).

distincto(nil).
distincto(pair(A, D)) :-
    \+ membero(A, D),
    distincto(D).

permuteo(nil, nil).
permuteo(pair(A, D), O) :-
    rembero(A, O, R),
    permuteo(D, R).

subseto(nil, _).
subseto(pair(X, R), B) :-
    membero(X, B),
    subseto(R, B).

filtero(_, nil, nil).
filtero(Tag, pair(A, D), Out) :-
    ( A == Tag ->
        filtero(Tag, D, R), Out = pair(A, R)
    ;   filtero(Tag, D, Out)
    ).

zipo(nil, nil, nil).
zipo(pair(A, DA), pair(B, DB), pair(pair(A, B), R)) :-
    zipo(DA, DB, R).

takeo(0, _, nil).
takeo(s(N), pair(A, D), pair(A, R)) :-
    takeo(N, D, R).

dropo(0, L, L).
dropo(s(N), pair(_, D), O) :-
    dropo(N, D, O).

%% ============================================================================
%% PEANO ARITHMETIC
%% ============================================================================

zeroo(0).
succo(N, s(N)).

nato(0).
nato(s(N)) :- nato(N).

addo(0, Y, Y).
addo(s(X), Y, s(Z)) :- addo(X, Y, Z).

mulo(0, _, 0).
mulo(s(X), Y, Z) :-
    mulo(X, Y, Z1),
    addo(Y, Z1, Z).

%% ============================================================================
%% RELATIONAL INTERPRETER (evalo — miniKanren classic)
%% ============================================================================

lookupo(X, pair(pair(X, V), _), V).
lookupo(X, pair(pair(Y, _), Rest), V) :-
    dif(X, Y),
    lookupo(X, Rest, V).

eval_expro(quote(Q), _, Q).
eval_expro(X, Env, V) :-
    atom(X),
    lookupo(X, Env, V).
eval_expro(lambda(P, B), Env, closure(P, B, Env)).
eval_expro(app(Rator, Rand), Env, V) :-
    eval_expro(Rator, Env, Clo),
    eval_expro(Rand, Env, Arg),
    applyo(Clo, Arg, V).
eval_expro(cons(A, D), Env, pair(VA, VD)) :-
    eval_expro(A, Env, VA),
    eval_expro(D, Env, VD).
eval_expro(if(C, T, E), Env, V) :-
    eval_expro(C, Env, CV),
    ( CV == true -> eval_expro(T, Env, V)
    ; CV == false -> eval_expro(E, Env, V)
    ).

applyo(closure(P, B, Env), Arg, V) :-
    eval_expro(B, pair(pair(P, Arg), Env), V).

evalo(Expr, Val) :- eval_expro(Expr, nil, Val).

%% ============================================================================
%% FORMULOG SMT STUB
%% ============================================================================

smt_and(A, B, and(A, B)).
smt_not(A, not(A)).
smt_var(N, var(N)).

is_sat(Phi) :-
    flatten_and(Phi, Atoms),
    \+ contradicted(Atoms).

flatten_and(and(A, B), Out) :-
    !, flatten_and(A, LA), flatten_and(B, LB), append(LA, LB, Out).
flatten_and(X, [X]).

contradicted(Atoms) :-
    member(not(P), Atoms),
    member(P, Atoms), !.

%% ============================================================================
%% EDB / FACT STORE (Formulog-style extensional database)
%% ============================================================================

assert_edb(Rel, A, B) :-
    assertz(edb(Rel, A, B)).
assert_edb(Rel, A, B, C) :-
    assertz(edb(Rel, A, B, C)).

factso(Rel, A, B) :- edb(Rel, A, B).
factso(Rel, A, B, C) :- edb(Rel, A, B, C).

%% ============================================================================
%% PARAMETERIZED PATH / REACHABILITY (single predicate, not N copies)
%% ============================================================================

patho(Rel, X, Y, path(Y), Phi) :-
    factso(Rel, X, Y, Phi),
    is_sat(Phi).
patho(Rel, X, Y, path(Z, P), and(E, Phi2)) :-
    factso(Rel, X, Z, E),
    patho(Rel, Z, Y, P, Phi2),
    is_sat(and(E, Phi2)).

reacho(Rel, S, S).
reacho(Rel, S, T) :-
    edb(Rel, S, M),
    reacho(Rel, M, T).

%% ============================================================================
%% BIT ARITHMETIC (CLP-style full adder)
%% ============================================================================

bito(0).
bito(1).

fulladdo(A, B, Cin, S, Cout) :-
    bito(A), bito(B), bito(Cin), bito(S), bito(Cout),
    Sum is A + B + Cin,
    S is Sum mod 2,
    Cout is Sum // 2.

%% ============================================================================
%% FSM RELATIONS (parameterized by FSM id)
%% ============================================================================

:- dynamic fsm_transition/5.

fsmo(FsmId, St, Inp, Nst, Out) :-
    fsm_transition(FsmId, St, Inp, Nst, Out).

register_fsm(Id) :-
    assertz(fsm_transition(Id, s0, 0, s0, 0)),
    assertz(fsm_transition(Id, s0, 1, s1, 0)),
    assertz(fsm_transition(Id, s1, 0, s0, 1)),
    assertz(fsm_transition(Id, s1, 1, s1, 1)).

%% ============================================================================
%% REFINEMENT / LATTICE
%% ============================================================================

refineo(Abs, Conc, refined) :-
    ( Abs == Conc -> true
    ; Abs = top -> true
    ; Abs = interval(Lo, Hi), number(Conc), Conc >= Lo, Conc =< Hi
    ).

%% ============================================================================
%% GRAPH COLORING (single predicate, parameterized)
%% ============================================================================

coloro(Rel, N, C) :-
    member(C, [red, green, blue]),
    \+ (edb(Rel, N, M), coloro(Rel, M, C)).

%% ============================================================================
%% HIGHER-ORDER LIST OPERATIONS
%% ============================================================================

mapo(_, nil, nil).
mapo(Goal, pair(A, D), pair(B, R)) :-
    call(Goal, A, B),
    mapo(Goal, D, R).

foldo(_, nil, Acc, Acc).
foldo(Goal, pair(A, D), Acc, Out) :-
    call(Goal, A, Acc, NAcc),
    foldo(Goal, D, NAcc, Out).

%% ============================================================================
%% EDB SEED DATA (50 edge sets, parameterized)
%% ============================================================================

seed_edges :-
    retractall(edb(_, _, _)),
    retractall(edb(_, _, _, _)),
    numlist(0, 49, Ids),
    maplist(seed_edge_set, Ids).

seed_edge_set(N) :-
    atom_concat(edge, N, Rel),
    atom_concat(e, N, ERel),
    smt_var(x, VX), smt_var(y, VY), smt_var(z, VZ),
    smt_var(p, VP), smt_not(smt_var(q), NQ),
    assert_edb(Rel, 0, 1, bv_slt(VX, VY)),
    assert_edb(Rel, 1, 2, bv_slt(VY, VZ)),
    smt_and(VP, NQ, Phi),
    assert_edb(Rel, 2, 3, Phi),
    N0 is N mod 7,
    N1 is (N + 1) mod 7,
    assert_edb(ERel, N, N0),
    assert_edb(ERel, N0, N1).

%% ============================================================================
%% REGISTER DEFAULT FSMs
%% ============================================================================

seed_fsms :-
    retractall(fsm_transition(_, _, _, _, _)),
    numlist(0, 11, Ids),
    maplist(register_fsm, Ids).

%% ============================================================================
%% KERNEL DEMO / SMOKE TEST
%% ============================================================================

kernel_demo :-
    seed_edges,
    seed_fsms,
    format('=== Formulog miniKanren Kernel (Prolog) ===~n'),

    % appendo test
    format('~nappendo test:~n'),
    findall(Q, (appendo(pair(1, pair(2, nil)), pair(3, nil), Q)), R1),
    forall(member(X, R1), format('  ~w~n', [X])),

    % evalo test
    format('~nevalo test:~n'),
    findall(V, evalo(quote(pair(a, b)), V), R2),
    forall(member(X, R2), format('  ~w~n', [X])),

    % addo test
    format('~naddo test:~n'),
    findall(Z, addo(s(0), s(s(0)), Z), R3),
    forall(member(X, R3), format('  ~w~n', [X])),

    % edge facts test
    format('~nedge facts test:~n'),
    findall(X-Y, factso(edge0, X, Y, _), R4),
    forall(member(X, R4), format('  ~w~n', [X])),

    % full adder test
    format('~nfull adder test:~n'),
    findall(S-Cout, fulladdo(1, 1, 0, S, Cout), R5),
    forall(member(X, R5), format('  ~w~n', [X])),

    % FSM test
    format('~nFSM test:~n'),
    findall(Nst-Out, fsmo(0, s0, 1, Nst, Out), R6),
    forall(member(X, R6), format('  ~w~n', [X])),

    % reachability test
    format('~nreachability test:~n'),
    findall(T, reacho(e0, 0, T), R7),
    length(R7, N7),
    format('  ~w reachable nodes from 0~n', [N7]),

    format('~n=== KERNEL COMPLETE ===~n').

:- initialization(kernel_demo, main).
