%% SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0
%% Copyright (C) 2026 SNAPKITTYWEST / Sovereign Kernel Project
%% CLONE_GATE: icp-dag-crystallizer::prolog::kernels::cycle_rejector
%%
%% K2: Cycle rejector — detects and rejects cyclic kernels
%% Domain: dag-validation | Purity: pure

:- module(cycle_rejector, [
    cycle_through/1,
    has_cycle/0,
    rejection/2,
    rejected_kernel/1
]).

:- use_module(reachability_closure).
:- use_module('../icp_dag').

cycle_through(Node) :-
    edge2(Node, Next),
    (   Next = Node
    ;   reach_(Next, Node, edge2, [Next])
    ).

has_cycle :-
    node(Node, _, _),
    cycle_through(Node).

rejection(Node, dependency_cycle) :-
    node(Node, _, _),
    cycle_through(Node).

rejected_kernel(K) :-
    kernel(K, _, _),
    cycle_through(K).
