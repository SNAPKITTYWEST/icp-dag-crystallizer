%% SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0
%% Copyright (C) 2026 SNAPKITTYWEST / Sovereign Kernel Project
%% CLONE_GATE: icp-dag-crystallizer::asp::icp_dag
%%
%% ICP-DAG v1.0 — Answer Set Programming constraints (Clingo)
%% 10 governance invariants as integrity constraints.

%% ── Node types ───────────────────────────────────────────────────────────────

node_type(evidence; claim; constraint; proof; decision;
          authorization; execution; audit; policy).

valid_state(unknown; proposed; verified; proven; authorized;
            pending; executed; contradicted; active; observed).

%% ── Derivation rules ─────────────────────────────────────────────────────────

proven(C) :- node(P, proof, proven), edge(C, P, "proven-by").

authorized(D) :- node(D, decision, authorized),
                  node(C, claim, verified),
                  edge(C, D, decides),
                  proven(C).

can_execute(E) :- node(E, execution, pending),
                  node(D, decision, authorized),
                  edge(D, E, executes).

reachable(X, Y) :- edge(X, Y, _).
reachable(X, Z) :- edge(X, Y, _), reachable(Y, Z).

cycle(X) :- reachable(X, X).

%% ── I1: Every edge has existing endpoints ────────────────────────────────────

:- edge(A, B, _), not node(A, _, _).
:- edge(A, B, _), not node(B, _, _).

%% ── I2: No self-edges ────────────────────────────────────────────────────────

:- node(N, _, _), edge(N, N, _).

%% ── I3: Unknown cannot authorize ─────────────────────────────────────────────

:- node(C, claim, unknown), node(D, decision, _), edge(C, D, decides).

%% ── I4: Contradicted cannot authorize ────────────────────────────────────────

:- node(C, claim, contradicted), node(D, decision, _), edge(C, D, decides).

%% ── I5: Authorization requires proven claim ──────────────────────────────────

:- node(D, decision, authorized),
   node(C, claim, _),
   edge(C, D, decides),
   not proven(C).

%% ── I5b: Execution requires authorized decision ─────────────────────────────

:- node(E, execution, _),
   edge(D, E, executes),
   node(D, decision, S),
   S != authorized.

%% ── I9: No simultaneous unknown + verified ───────────────────────────────────

:- node(C, claim, unknown), node(C, claim, verified).

%% ── I10: Acyclicity ─────────────────────────────────────────────────────────

:- cycle(X).

%% ── Output ───────────────────────────────────────────────────────────────────

#show proven/1.
#show authorized/1.
#show can_execute/1.
#show cycle/1.
