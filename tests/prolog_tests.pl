%% SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0
%% Copyright (C) 2026 SNAPKITTYWEST / Sovereign Kernel Project
%% CLONE_GATE: icp-dag-crystallizer::tests::prolog_tests
%%
%% SWI-Prolog test suite for ICP-DAG

:- use_module('../src/prolog/icp_dag').

:- begin_tests(icp_dag).

%% ── Valid DAG ────────────────────────────────────────────────────────────────

test(valid_dag_no_violations) :-
    retractall(node(_, _, _)),
    retractall(edge(_, _, _)),
    assert(node(ev1, evidence, observed)),
    assert(node(c1, claim, verified)),
    assert(node(p1, proof, proven)),
    assert(node(d1, decision, authorized)),
    assert(node(e1, execution, pending)),
    assert(edge(ev1, c1, supports)),
    assert(edge(c1, p1, 'proven-by')),
    assert(edge(p1, d1, decides)),
    assert(edge(d1, e1, executes)),
    check_all_invariants(Violations),
    length(Violations, 0).

%% ── Proven derivation ────────────────────────────────────────────────────────

test(proven_claim) :-
    retractall(node(_, _, _)),
    retractall(edge(_, _, _)),
    assert(node(c1, claim, verified)),
    assert(node(p1, proof, proven)),
    assert(edge(c1, p1, 'proven-by')),
    proven(c1).

%% ── Self-edge violation ──────────────────────────────────────────────────────

test(i2_self_edge, [true(Len > 0)]) :-
    retractall(node(_, _, _)),
    retractall(edge(_, _, _)),
    assert(node(n1, claim, verified)),
    assert(edge(n1, n1, supports)),
    check_all_invariants(Violations),
    length(Violations, Len).

%% ── Unknown authorizes violation ─────────────────────────────────────────────

test(i3_unknown_authorizes, [true(Len > 0)]) :-
    retractall(node(_, _, _)),
    retractall(edge(_, _, _)),
    assert(node(c1, claim, unknown)),
    assert(node(d1, decision, proposed)),
    assert(edge(c1, d1, decides)),
    check_all_invariants(Violations),
    length(Violations, Len).

%% ── Cycle detection ──────────────────────────────────────────────────────────

test(i10_cycle, [true(HasCycle)]) :-
    retractall(node(_, _, _)),
    retractall(edge(_, _, _)),
    assert(node(a, claim, verified)),
    assert(node(b, proof, proven)),
    assert(node(c, decision, proposed)),
    assert(edge(a, b, 'proven-by')),
    assert(edge(b, c, decides)),
    assert(edge(c, a, supports)),
    ( cycle(_) -> HasCycle = true ; HasCycle = false ).

%% ── Can execute derivation ───────────────────────────────────────────────────

test(can_execute_derivation) :-
    retractall(node(_, _, _)),
    retractall(edge(_, _, _)),
    assert(node(c1, claim, verified)),
    assert(node(p1, proof, proven)),
    assert(node(d1, decision, authorized)),
    assert(node(e1, execution, pending)),
    assert(edge(c1, p1, 'proven-by')),
    assert(edge(c1, d1, decides)),
    assert(edge(d1, e1, executes)),
    can_execute(e1).

%% ── Edge creation validation ─────────────────────────────────────────────────

test(edge_create_blocks_cycle) :-
    retractall(node(_, _, _)),
    retractall(edge(_, _, _)),
    assert(node(a, claim, verified)),
    assert(node(b, proof, proven)),
    assert(edge(a, b, 'proven-by')),
    \+ edge_create_valid(b, a, 'supports').

:- end_tests(icp_dag).

:- run_tests.
