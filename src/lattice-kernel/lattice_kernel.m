%-----------------------------------------------------------------------------%
% SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0
% CLONE_GATE: lattice_kernel_mercury
%
% lattice_kernel.m — Mercury production library
% Deterministic functions + multi-moded relations for the LATTICE kernel:
% lists, Peano, bit full-adder, SMT-stub SAT, path, FSM, interval refine.
% Build: mmc --make lattice_kernel   (needs a main module to link)
%   or compile as a library: mmc --make liblattice_kernel
%-----------------------------------------------------------------------------%

:- module lattice_kernel.
:- interface.

:- import_module bool.
:- import_module list.

% ---- types ----
:- type peano
    --->    z
    ;       s(peano).

:- type bit
    --->    b0
    ;       b1.

:- type smt
    --->    atom(string)
    ;       smt_not(smt)
    ;       smt_and(smt, smt).

:- type node == int.

:- type fsm_state
    --->    s0
    ;       s1.

:- type abs_val
    --->    conc(int)
    ;       top
    ;       interval(int, int).

% ---- lists (relational, reversible) ----
:- pred appendo(list(T), list(T), list(T)).
:- mode appendo(in, in, out) is det.
:- mode appendo(out, out, in) is multi.
:- mode appendo(in, out, in) is semidet.
:- mode appendo(out, in, in) is semidet.

:- pred membero(T, list(T)).
:- mode membero(in, in) is semidet.
:- mode membero(out, in) is nondet.

:- pred rembero(T, list(T), list(T)).
:- mode rembero(in, in, out) is semidet.
:- mode rembero(in, out, in) is nondet.

:- pred reverseo(list(T), list(T)).
:- mode reverseo(in, out) is det.
:- mode reverseo(out, in) is det.

:- pred lengtho(list(T), peano).
:- mode lengtho(in, out) is det.

:- pred distincto(list(T)).
:- mode distincto(in) is semidet.

% ---- Peano ----
:- pred nato(peano).
:- mode nato(in) is det.

:- pred addo(peano, peano, peano).
:- mode addo(in, in, out) is det.
:- mode addo(in, out, in) is semidet.
:- mode addo(out, in, in) is semidet.
:- mode addo(out, out, in) is multi.

:- pred mulo(peano, peano, peano).
:- mode mulo(in, in, out) is det.

:- func add_f(peano, peano) = peano.
:- func mul_f(peano, peano) = peano.

% ---- bits / adder ----
:- pred bit_xoro(bit, bit, bit).
:- mode bit_xoro(in, in, out) is det.
:- mode bit_xoro(in, out, in) is semidet.
:- mode bit_xoro(out, in, in) is semidet.
:- mode bit_xoro(in, in, in) is semidet.
:- mode bit_xoro(out, out, in) is multi.

:- pred bit_ando(bit, bit, bit).
:- mode bit_ando(in, in, out) is det.
:- mode bit_ando(in, in, in) is semidet.

:- pred half_addero(bit, bit, bit, bit).
:- mode half_addero(in, in, out, out) is det.

:- pred full_addero(bit, bit, bit, bit, bit).
:- mode full_addero(in, in, in, out, out) is det.
:- mode full_addero(in, in, in, in, in) is semidet.

:- pred ripple_addero(list(bit), list(bit), bit, list(bit), bit).
:- mode ripple_addero(in, in, in, out, out) is semidet.

% ---- SMT stub + path ----
:- pred smt_sato(smt, bool).
:- mode smt_sato(in, out) is det.
:- mode smt_sato(in, in) is semidet.

:- pred edgeo(node, node, smt).
:- mode edgeo(in, in, out) is nondet.
:- mode edgeo(out, out, out) is multi.
:- mode edgeo(in, out, out) is nondet.

:- pred patho(node, node, list(node), smt).
:- mode patho(in, in, out, out) is nondet.
:- mode patho(out, out, out, out) is nondet.

% ---- FSM / refine ----
:- pred fsmo(fsm_state, bit, fsm_state, bit).
:- mode fsmo(in, in, out, out) is det.
:- mode fsmo(in, in, in, in) is semidet.
:- mode fsmo(out, out, out, out) is multi.

:- pred refineo(abs_val, int).
:- mode refineo(in, in) is semidet.
:- mode refineo(in, out) is nondet.

:- implementation.

:- import_module int.
:- import_module string.

% ---- lists ----
appendo([], S, S).
appendo([A | D], S, [A | Res]) :-
    appendo(D, S, Res).

membero(X, [X | _]).
membero(X, [_ | D]) :-
    membero(X, D).

rembero(X, [X | D], D).
rembero(X, [A | D], [A | Res]) :-
    A \= X,
    rembero(X, D, Res).

reverseo(L, O) :-
    reverseo_acc(L, [], O).

:- pred reverseo_acc(list(T), list(T), list(T)).
:- mode reverseo_acc(in, in, out) is det.
:- mode reverseo_acc(out, in, in) is det.
reverseo_acc([], Acc, Acc).
reverseo_acc([A | D], Acc, O) :-
    reverseo_acc(D, [A | Acc], O).

lengtho([], z).
lengtho([_ | D], s(N)) :-
    lengtho(D, N).

distincto([]).
distincto([A | D]) :-
    not membero(A, D),
    distincto(D).

% ---- Peano ----
nato(z).
nato(s(P)) :-
    nato(P).

addo(z, Y, Y).
addo(s(X), Y, s(Z)) :-
    addo(X, Y, Z).

mulo(z, _, z).
mulo(s(X), Y, Z) :-
    mulo(X, Y, Z1),
    addo(Y, Z1, Z).

add_f(z, Y) = Y.
add_f(s(X), Y) = s(add_f(X, Y)).

mul_f(z, _) = z.
mul_f(s(X), Y) = add_f(Y, mul_f(X, Y)).

% ---- bits ----
bit_xoro(b0, b0, b0).
bit_xoro(b0, b1, b1).
bit_xoro(b1, b0, b1).
bit_xoro(b1, b1, b0).

bit_ando(b0, b0, b0).
bit_ando(b0, b1, b0).
bit_ando(b1, b0, b0).
bit_ando(b1, b1, b1).

half_addero(X, Y, R, C) :-
    bit_xoro(X, Y, R),
    bit_ando(X, Y, C).

full_addero(Cin, X, Y, R, Cout) :-
    half_addero(X, Y, W, C1),
    half_addero(W, Cin, R, C2),
    bit_xoro(C1, C2, Cout).

ripple_addero([], [], Cin, [], Cin).
ripple_addero([X | Xs], [Y | Ys], Cin, [R | Rs], Cout) :-
    full_addero(Cin, X, Y, R, C1),
    ripple_addero(Xs, Ys, C1, Rs, Cout).

% ---- SMT stub: reject phi /\ ~phi at top-level flatten ----
smt_sato(Phi, Sat) :-
    atoms(Phi, As),
    ( unsat_pair(As) -> Sat = no ; Sat = yes ).

:- pred atoms(smt::in, list(smt)::out) is det.
atoms(smt_and(A, B), Xs) :-
    atoms(A, Xs1),
    atoms(B, Xs2),
    appendo(Xs1, Xs2, Xs).
atoms(smt_not(P), [smt_not(P)]).
atoms(atom(S), [atom(S)]).

:- pred unsat_pair(list(smt)::in) is semidet.
unsat_pair(As) :-
    membero(P, As),
    membero(smt_not(P), As).

edgeo(0, 1, atom("bv_slt_x_y")).
edgeo(1, 2, atom("bv_slt_y_z")).
edgeo(2, 3, atom("bv_sgt_z_x")).
edgeo(3, 1, smt_and(atom("p"), smt_not(atom("q")))).

patho(X, Y, [Y], Phi) :-
    edgeo(X, Y, Phi),
    smt_sato(Phi, yes).
patho(X, Y, [Z | P2], smt_and(E, Phi2)) :-
    edgeo(X, Z, E),
    patho(Z, Y, P2, Phi2),
    not membero(Z, P2),
    smt_sato(smt_and(E, Phi2), yes).

% ---- FSM / refine ----
fsmo(s0, b0, s0, b0).
fsmo(s0, b1, s1, b0).
fsmo(s1, b0, s0, b1).
fsmo(s1, b1, s1, b1).

refineo(conc(C), C).
refineo(top, _).
refineo(interval(Lo, Hi), N) :-
    N >= Lo,
    N =< Hi.

:- end_module lattice_kernel.
