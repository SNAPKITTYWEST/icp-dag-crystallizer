%% SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0
%% Copyright (C) 2026 SNAPKITTYWEST / Sovereign Kernel Project
%% CLONE_GATE: icp-dag-crystallizer::prolog::kernels::reachability_closure
%%
%% K1: Reachability closure — graph traversal with cycle-safe seen list
%% Domain: graph-reachability | Purity: pure

:- module(reachability_closure, [
    edge2/2,
    reachable/2,
    reachable/3,
    reach_/4
]).

:- use_module('../icp_dag').

edge2(X, Y) :- edge(X, Y, _).

reachable(Start, Goal, Edge) :-
    reach_(Start, Goal, Edge, [Start]).

reach_(Current, Current, _Edge, _Seen).
reach_(Current, Goal, Edge, Seen) :-
    call(Edge, Current, Next),
    \+ memberchk(Next, Seen),
    reach_(Next, Goal, Edge, [Next|Seen]).

reachable(Start, Goal) :-
    reachable(Start, Goal, edge2).
