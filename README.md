# ICP-DAG Crystallizer — Integrity Constraint Protocol as Deterministic Logic

**License**: GPL-3.0-or-later OR Apache-2.0 (dual-licensed)

Formalizes the ICP-DAG v1.0 governance protocol across four logic languages:
Soufflé Datalog, SWI-Prolog, Clingo ASP, and MUMPS.

## 10 Governance Invariants

| ID | Invariant | Severity |
|----|-----------|----------|
| I1 | Every edge has existing endpoints | FATAL |
| I2 | No self-edges | FATAL |
| I3 | Unknown claims cannot authorize decisions | FATAL |
| I4 | Contradicted claims cannot authorize decisions | FATAL |
| I5 | Execution needs authorized decision with proven claim | FATAL |
| I6 | Every proof references a claim | FATAL |
| I7 | Every policy references a constraint | FATAL |
| I8 | Constraint failure propagates to proofs | FATAL |
| I9 | No simultaneous unknown + verified state | FATAL |
| I10 | DAG must be acyclic (cycle = halt) | FATAL |

## 6 Kernel Candidates

| Kernel | Domain | Purity |
|--------|--------|--------|
| K1: node_create | Node management | Pure |
| K2: edge_validate | DAG integrity | Pure |
| K3: constraint_check | Constraint enforcement | Pure |
| K4: dag_integrity_check | Governance verification | Pure |
| K5: governance_enforce | Policy execution | Side-effect |
| K6: seal_dag | Finalization | Side-effect |

## DAG Dependency Chain

```
EVIDENCE ──supports──→ CLAIM ──proven-by──→ PROOF ──decides──→ DECISION ──executes──→ EXECUTION
                                              ↑
POLICY ──enforces──→ CONSTRAINT ──satisfies──┘
```

## Architecture

```
src/
├── datalog/           # Soufflé Datalog (primary formalization)
│   ├── facts.dl       # Base relations, type/state/edge declarations
│   ├── rules.dl       # Derivation rules (proven, authorized, reachable)
│   ├── invariants.dl  # 10 invariants as violation-emitting rules
│   └── kernels.dl     # 6 kernel candidates (node create → seal)
├── prolog/            # SWI-Prolog reference implementation
│   └── icp_dag.pl     # Full module with all invariants + kernels
├── asp/               # Clingo ASP constraints
│   └── icp_dag.lp     # Integrity constraints (unsat = invalid DAG)
└── mumps/             # MUMPS governance kernel
    └── ICP_DAG.m      # Hierarchical globals, BFS reachability
```

## Run

```bash
# Soufflé Datalog (valid DAG — expect VALID + SEALED)
souffle tests/valid_dag.dl

# Soufflé Datalog (invalid — expect violations)
souffle tests/invalid_cycle.dl
souffle tests/invalid_self_edge.dl
souffle tests/invalid_unknown_decides.dl
souffle tests/invalid_unauthorized_exec.dl

# SWI-Prolog
swipl tests/prolog_tests.pl

# Clingo ASP
clingo src/asp/icp_dag.lp tests/valid_dag_facts.lp
```

## Agent Submission

The original SGMT agent submission is preserved in `spec/agent-submission.xml`.
