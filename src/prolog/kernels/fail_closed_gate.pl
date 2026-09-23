%% SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0
%% Copyright (C) 2026 SNAPKITTYWEST / Sovereign Kernel Project
%% CLONE_GATE: icp-dag-crystallizer::prolog::kernels::fail_closed_gate
%%
%% K3: Fail-closed admission gate — 12-condition kernel validation
%% Domain: admission-control | Purity: pure
%%
%% Every kernel must pass all 12 conditions or be rejected with the
%% first failure reason. The cut ordering ensures determinism.

:- module(fail_closed_gate, [
    admissible/1,
    decide/2,
    first_failure/2
]).

:- use_module(reachability_closure).
:- use_module(cycle_rejector).
:- use_module('../icp_dag').

%% ── Admission ────────────────────────────────────────────────────────────────

admissible(K) :-
    kernel_candidate(_, K, Domain, _),
    domain_constraints(Domain, Constraints),
    maplist(satisfied(K), Constraints),
    required_proofs(K, Proofs),
    maplist(discharged, Proofs),
    \+ cyclic(K),
    deterministic(K).

cyclic(K) :- cycle_through(K).

%% ── Decision (deterministic via cut) ─────────────────────────────────────────

decide(K, admit(K)) :-
    admissible(K), !.
decide(K, reject(K, Reason)) :-
    first_failure(K, Reason).

%% ── 12 fail-closed conditions ────────────────────────────────────────────────

first_failure(K, schema_invalid) :-
    \+ schema_valid(K), !.
first_failure(K, unknown_dependency) :-
    undeclared_dependency(K, _), !.
first_failure(K, dependency_cycle) :-
    cyclic(K), !.
first_failure(K, missing_symbol) :-
    missing_symbol(K, _), !.
first_failure(K, unresolved_constraint) :-
    kernel_candidate(_, K, Domain, _),
    domain_constraints(Domain, Constraints),
    member(C, Constraints),
    \+ satisfied(K, C), !.
first_failure(K, failed_proof) :-
    required_proofs(K, Proofs),
    member(P, Proofs),
    \+ discharged(P), !.
first_failure(K, ambiguous_binding) :-
    ambiguous_binding(K, _), !.
first_failure(K, nondeterministic_output) :-
    \+ deterministic(K), !.
first_failure(K, digest_mismatch) :-
    \+ digest_consistent(K), !.
first_failure(K, undeclared_side_effect) :-
    undeclared_side_effect(K, _), !.
first_failure(K, duplicate_semantics) :-
    semantic_duplicate(K, _), !.
first_failure(K, broken_provenance) :-
    broken_provenance(K), !.

%% ── Stub predicates (to be provided by external modules) ─────────────────────

:- discontiguous schema_valid/1, undeclared_dependency/2, missing_symbol/2.
:- discontiguous satisfied/2, discharged/1, deterministic/1.
:- discontiguous ambiguous_binding/2, digest_consistent/1.
:- discontiguous undeclared_side_effect/2, semantic_duplicate/2.
:- discontiguous broken_provenance/1, domain_constraints/2, required_proofs/2.
