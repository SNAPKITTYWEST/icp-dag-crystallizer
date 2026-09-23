%% SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0
%% Copyright (C) 2026 SNAPKITTYWEST / Sovereign Kernel Project
%% CLONE_GATE: icp-dag-crystallizer::prolog::kernels::semantic_dedup
%%
%% K5: Semantic deduplication — identical digest = one canonical node
%% Domain: deduplication | Purity: pure

:- module(semantic_dedup, [
    signature_pair/2,
    dedup/3
]).

:- use_module(structural_digest).

signature_pair(K, Signature-K) :-
    structural_digest(K, Signature).

dedup(Kernels, Admitted, Rejected) :-
    maplist(signature_pair, Kernels, Pairs),
    keysort(Pairs, Sorted),
    group_pairs_by_key(Sorted, Groups),
    findall(First, member(_Sig-[First|_], Groups), Admitted),
    findall(reject(K, duplicate_semantics),
            ( member(_Sig-[_|Rest], Groups),
              member(K, Rest) ),
            Rejected).
