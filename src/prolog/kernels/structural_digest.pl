%% SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0
%% Copyright (C) 2026 SNAPKITTYWEST / Sovereign Kernel Project
%% CLONE_GATE: icp-dag-crystallizer::prolog::kernels::structural_digest
%%
%% K4: Structural digest — content-addressed canonical form
%% Domain: content-addressing | Purity: pure

:- module(structural_digest, [
    canonical_kernel/2,
    structural_digest/2
]).

:- use_module(library(crypto)).

canonical_kernel(K, canonical(K, SigSet, DepSet)) :-
    findall(S, semantic_signature(K, S), Sigs),
    sort(Sigs, SigSet),
    findall(D, dependency_signature(K, D), Deps),
    sort(Deps, DepSet).

structural_digest(K, Digest) :-
    canonical_kernel(K, Canonical),
    term_string(Canonical, String),
    crypto_data_hash(String, Digest, [algorithm(sha256), encoding(hex)]).

%% ── Stub predicates ──────────────────────────────────────────────────────────

:- discontiguous semantic_signature/2, dependency_signature/2.
