%% SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0
%% Copyright (C) 2026 SNAPKITTYWEST / Sovereign Kernel Project
%% CLONE_GATE: icp-dag-crystallizer::prolog::kernels::egg_packer
%%
%% K6: EGG packer — immutable crystallized kernel package
%% Domain: packaging | Purity: pure
%%
%% An EGG is the terminal form: ground, content-addressed, immutable.
%% Once packed, digest(Egg) is fixed — any mutation yields a new digest.

:- module(egg_packer, [
    pack_egg/3,
    egg_digest/2,
    egg_valid/1
]).

:- use_module(structural_digest).

pack_egg(K, Generation, Egg) :-
    structural_digest(K, Digest),
    atom_concat('egg:', Digest, Id),
    provenance(K, Provenance),
    kernel_body(K, Body),
    egg_dependencies(K, Dependencies),
    kernel_constraints(K, Constraints),
    required_proofs(K, Proofs),
    kernel_exports(K, Exports),
    Egg = egg(Id, Digest, Generation, Provenance,
              Body, Dependencies, Constraints, Proofs, Exports).

egg_digest(egg(_, Digest, _, _, _, _, _, _, _), Digest).

egg_valid(Egg) :-
    Egg = egg(Id, Digest, _Gen, _Prov, Body, _Deps, _Cons, _Proofs, _Exports),
    ground(Egg),
    atom_concat('egg:', Digest, Id),
    ground(Body).

%% ── Stub predicates ──────────────────────────────────────────────────────────

:- discontiguous provenance/2, kernel_body/2, egg_dependencies/2.
:- discontiguous kernel_constraints/2, kernel_exports/2.
