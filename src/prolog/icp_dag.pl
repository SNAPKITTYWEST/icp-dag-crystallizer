%% SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0
%% Copyright (C) 2026 SNAPKITTYWEST / Sovereign Kernel Project
%% CLONE_GATE: icp-dag-crystallizer::prolog::icp_dag
%%
%% ICP-DAG v1.0 — Prolog reference implementation
%% 10 invariants + 6 kernel candidates

:- module(icp_dag, [
    node/3, edge/3,
    proven/1, authorized/1, can_execute/1,
    reachable/2, cycle/1,
    dag_valid/0, governance_enforce/0, seal_dag/0,
    violation/4, check_all_invariants/1
]).

:- dynamic node/3, edge/3.

%% ── Derivation rules ────────────────────────────────────────────────────────

proven(C) :-
    node(P, proof, proven),
    edge(C, P, 'proven-by').

authorized(D) :-
    node(D, decision, authorized),
    node(C, claim, verified),
    edge(C, D, decides),
    proven(C).

can_execute(E) :-
    node(E, execution, pending),
    node(D, decision, authorized),
    edge(D, E, executes).

reachable(X, Y) :- edge(X, Y, _).
reachable(X, Z) :- edge(X, Y, _), reachable(Y, Z).

cycle(X) :- reachable(X, X).

%% ── Invariant checks ────────────────────────────────────────────────────────

violation(i1, A, B, 'dangling source') :-
    edge(A, B, _), \+ node(A, _, _).
violation(i1, A, B, 'dangling target') :-
    edge(A, B, _), \+ node(B, _, _).

violation(i2, N, N, 'self edge') :-
    node(N, _, _), edge(N, N, _).

violation(i3, C, D, 'unknown authorizes') :-
    node(C, claim, unknown),
    node(D, decision, _),
    edge(C, D, decides).

violation(i4, C, D, 'contradicted authorizes') :-
    node(C, claim, contradicted),
    node(D, decision, _),
    edge(C, D, decides).

violation(i5, D, C, 'unproven authorization') :-
    node(D, decision, authorized),
    node(C, claim, _),
    edge(C, D, decides),
    \+ proven(C).

violation(i5b, E, D, 'unauthorized execution') :-
    node(E, execution, _),
    edge(D, E, executes),
    node(D, decision, S),
    S \= authorized.

violation(i6, P, P, 'orphan proof') :-
    node(P, proof, _),
    \+ edge(_, P, 'proven-by').

violation(i7, PO, PO, 'orphan policy') :-
    node(PO, policy, _),
    \+ edge(PO, _, enforces).

violation(i9, C, C, 'state contradiction') :-
    node(C, claim, unknown),
    node(C, claim, verified).

violation(i10, X, X, 'cycle detected') :-
    cycle(X).

%% ── Aggregate checks ────────────────────────────────────────────────────────

check_all_invariants(Violations) :-
    findall(violation(Inv, A, B, Msg), violation(Inv, A, B, Msg), Violations).

dag_valid :-
    \+ violation(_, _, _, _).

%% ── Kernel candidates ───────────────────────────────────────────────────────

%% K1: Node creation
valid_state(S) :- member(S, [unknown, proposed, verified, proven, authorized,
                              pending, executed, contradicted, active, observed]).
valid_type(T) :- member(T, [evidence, claim, constraint, proof, decision,
                             authorization, execution, audit, policy]).

node_create_valid(ID, Type, State) :-
    atom(ID), valid_type(Type), valid_state(State).

%% K2: Edge validation
edge_create_valid(From, To, Type) :-
    node(From, _, _),
    node(To, _, _),
    From \= To,
    \+ reachable(To, From),
    atom(Type).

%% K3: Constraint check
all_constraints_satisfied :-
    \+ (constraint(CID, _, _), \+ constraint_satisfied(CID)).

constraint_satisfied(CID) :-
    constraint(CID, _, _),
    \+ constraint_violated(CID).

:- dynamic constraint/3, constraint_violated/1.

%% K4: DAG integrity
dag_integrity_check(pass) :- dag_valid, !.
dag_integrity_check(fail).

%% K5: Governance enforcement
governance_enforce :-
    dag_valid,
    all_constraints_satisfied.

%% K6: Seal
seal_dag :-
    governance_enforce,
    aggregate_all(count, node(_, _, _), NodeCount),
    aggregate_all(count, edge(_, _, _), EdgeCount),
    format('SEALED: ~w nodes, ~w edges~n', [NodeCount, EdgeCount]).
