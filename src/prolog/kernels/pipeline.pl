%% SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0
%% Copyright (C) 2026 SNAPKITTYWEST / Sovereign Kernel Project
%% CLONE_GATE: icp-dag-crystallizer::prolog::kernels::pipeline
%%
%% SGMT Crystallization Pipeline — ties all 6 kernels together
%% Pipeline: XSLT normalize → Prolog resolve → constraints → proofs → digest → dedup → EGG

:- module(pipeline, [
    crystallize_kernel/3,
    crystallize_all/3,
    pipeline_status/1
]).

:- use_module(reachability_closure).
:- use_module(cycle_rejector).
:- use_module(fail_closed_gate).
:- use_module(structural_digest).
:- use_module(semantic_dedup).
:- use_module(egg_packer).

%% ── Single kernel crystallization ────────────────────────────────────────────

crystallize_kernel(K, Generation, Result) :-
    decide(K, Decision),
    (   Decision = admit(K)
    ->  pack_egg(K, Generation, Egg),
        Result = crystallized(K, Egg)
    ;   Decision = reject(K, Reason),
        Result = rejected(K, Reason)
    ).

%% ── Batch crystallization with dedup ─────────────────────────────────────────

crystallize_all(Kernels, Generation, Results) :-
    dedup(Kernels, Admitted, DupRejections),
    maplist(crystallize_single(Generation), Admitted, CrystResults),
    append(CrystResults, DupRejections, Results).

crystallize_single(Generation, K, Result) :-
    crystallize_kernel(K, Generation, Result).

%% ── Pipeline status ──────────────────────────────────────────────────────────

pipeline_status(Status) :-
    (   has_cycle
    ->  Status = blocked(cycles_detected)
    ;   Status = ready
    ).
