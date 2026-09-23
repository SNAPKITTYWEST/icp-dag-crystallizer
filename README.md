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
├── xslt/              # XSLT 3.0 normalizer
│   └── sgmt_normalize.xsl  # agent-submission → sgmt:submission canonical form
├── prolog/            # SWI-Prolog reference implementation
│   ├── icp_dag.pl     # Base module with all invariants + kernels
│   └── kernels/       # compiler-00: 6 crystallization kernels + pipeline
│       ├── reachability_closure.pl  # K1: graph traversal with seen list
│       ├── cycle_rejector.pl        # K2: cycle detection + rejection
│       ├── fail_closed_gate.pl      # K3: 12-condition admission gate
│       ├── structural_digest.pl     # K4: SHA-256 content addressing
│       ├── semantic_dedup.pl        # K5: digest-based deduplication
│       ├── egg_packer.pl            # K6: immutable EGG packaging
│       └── pipeline.pl              # Orchestrates K1-K6
```

## SGMT Crystallization Pipeline (compiler-00)

```
XML submission → XSLT normalize → Prolog/Datalog resolve → constraint discharge
→ proof obligations → structural digest → semantic dedup → EGG pack → SEALED
```

### 6 Prolog Kernels

| Kernel | Domain | Description |
|--------|--------|-------------|
| K1: reachability_closure | graph-reachability | Transitive closure with cycle-safe seen list |
| K2: cycle_rejector | dag-validation | Detects cycles, emits rejection nodes |
| K3: fail_closed_gate | admission-control | 12-condition gate (schema, deps, cycles, proofs, determinism...) |
| K4: structural_digest | content-addressing | Canonical form → SHA-256 digest |
| K5: semantic_dedup | deduplication | Same digest = one canonical node |
| K6: egg_packer | packaging | Immutable terminal form with provenance |

### 12 Fail-Closed Conditions

1. schema_invalid
2. unknown_dependency
3. dependency_cycle
4. missing_symbol
5. unresolved_constraint
6. failed_proof
7. ambiguous_binding
8. nondeterministic_output
9. digest_mismatch
10. undeclared_side_effect
11. duplicate_semantics
12. broken_provenance

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

Agent submissions preserved in `spec/submissions/`:
- `agent-submission.xml` — ICP-DAG crystallizer (Datalog, 10 invariants)
- `compiler-00-gen1.xml` — compiler-00 (SWI-Prolog, 6 kernels, 12-condition gate)
