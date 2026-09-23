# ICP-DAG Crystallizer — Integrity Constraint Protocol as Deterministic Logic

**License**: GPL-3.0-or-later OR Apache-2.0 (dual-licensed)

Formalizes the ICP-DAG v1.0 governance protocol across multiple logic languages
and provides a multi-language relational lattice kernel for constraint-based
reasoning, path refinement, and FSM verification.

---

## Repository Map

```
icp-dag-crystallizer/
├── src/
│   ├── datalog/           # Soufflé Datalog — primary ICP-DAG formalization
│   ├── prolog/            # SWI-Prolog reference + miniKanren kernel
│   │   └── kernels/       # compiler-00: 6 crystallization kernels
│   ├── asp/               # Clingo ASP integrity constraints
│   ├── mumps/             # MUMPS governance kernel
│   ├── xslt/              # XSLT 3.0 submission normalizer
│   ├── lattice-kernel/    # 8-language relational lattice kernel (NEW)
│   └── validators/        # Rust + Go governance protocol enforcement
├── spec/                  # Agent submissions + ICP-DAG analysis JSON
├── tests/                 # Soufflé test cases + Prolog tests
├── CLONE_GATE.md
└── README.md
```

---

## ICP-DAG Governance Protocol

### 10 Invariants (all FATAL)

| ID | Invariant |
|----|-----------|
| I1 | Every edge has existing endpoints |
| I2 | No self-edges |
| I3 | Unknown claims cannot authorize decisions |
| I4 | Contradicted claims cannot authorize decisions |
| I5 | Execution needs authorized decision with proven claim |
| I6 | Every proof references a claim |
| I7 | Every policy references a constraint |
| I8 | Constraint failure propagates to proofs |
| I9 | No simultaneous unknown + verified state |
| I10 | DAG must be acyclic (cycle = halt) |

### DAG Dependency Chain

```
EVIDENCE ──supports──→ CLAIM ──proven-by──→ PROOF ──decides──→ DECISION ──executes──→ EXECUTION
                                              ↑
POLICY ──enforces──→ CONSTRAINT ──satisfies──┘
```

---

## ICP-DAG Implementation Stack

```
src/
├── datalog/
│   ├── facts.dl       # Base relations, type/state/edge declarations
│   ├── rules.dl       # Derivation rules (proven, authorized, reachable)
│   ├── invariants.dl  # 10 invariants as violation-emitting rules
│   ├── kernels.dl     # 6 kernel candidates (node_create → seal_dag)
│   └── sgmt_model.dl  # SGMT semantic model
├── asp/
│   └── icp_dag.lp     # Clingo integrity constraints (unsat = invalid DAG)
├── mumps/
│   └── ICP_DAG.m      # Hierarchical globals, BFS reachability
├── xslt/
│   └── sgmt_normalize.xsl   # agent-submission → canonical sgmt:submission
└── prolog/
    ├── icp_dag.pl           # Full ICP-DAG module (all invariants + kernels)
    ├── formulog_minikanren_kernel.pl   # miniKanren relational kernel (Prolog)
    └── kernels/             # compiler-00 crystallization pipeline
        ├── reachability_closure.pl  # K1: transitive closure, cycle-safe
        ├── cycle_rejector.pl        # K2: cycle detection + rejection nodes
        ├── fail_closed_gate.pl      # K3: 12-condition admission gate
        ├── structural_digest.pl     # K4: SHA-256 content addressing
        ├── semantic_dedup.pl        # K5: digest-based deduplication
        ├── egg_packer.pl            # K6: immutable EGG packaging
        └── pipeline.pl              # Orchestrates K1–K6
```

### 6 Kernel Candidates

| Kernel | Domain | Purity |
|--------|--------|--------|
| K1: reachability_closure | graph-reachability | Pure |
| K2: cycle_rejector | dag-validation | Pure |
| K3: fail_closed_gate | admission-control (12 conditions) | Pure |
| K4: structural_digest | content-addressing | Pure |
| K5: semantic_dedup | deduplication | Pure |
| K6: egg_packer | packaging | Side-effect |

### SGMT Crystallization Pipeline (compiler-00)

```
XML submission → XSLT normalize → Prolog/Datalog resolve → constraint discharge
→ proof obligations → structural digest → semantic dedup → EGG pack → SEALED
```

---

## Lattice Kernel — 8-Language Relational Batch

`src/lattice-kernel/` is a coherent multi-language implementation of a
relational lattice kernel covering: unification, list relations, Peano
arithmetic, full-adder, relational interpreter (evalo), SMT stub,
parameterized path/reachability, FSM relations, and interval refinement.

See [`src/lattice-kernel/README.md`](src/lattice-kernel/README.md) for full details.

| File | Language | Toolchain |
|------|----------|-----------|
| `mu_kanren.scm` | Scheme μKanren | Chez / Guile / Racket |
| `lattice_kernel.pl` | ISO Prolog | SWI-Prolog / GNU Prolog |
| `path_refine.flg` | Formulog | HarvardPL Formulog |
| `path_refine.dl` | Soufflé Datalog | Soufflé |
| `lattice_kernel.pi` | Picat | Picat |
| `LatticeKernel.lean` | Lean 4 | `lake` / `lean` |
| `lattice_kernel.m` | Mercury | `mmc` |
| `LatticeKernel.v` | Coq | `coqc` / `coqtop` |

---

## Formulog miniKanren Kernel

`src/prolog/formulog_minikanren_kernel.pl` — a dense miniKanren relational core
ported to pure SWI-Prolog, collapsing 40+ copy-pasted numbered functions from
the Python original into single parameterized predicates.

Covers: walk/unify, list relations (appendo/membero/rembero/…), Peano arithmetic,
evalo relational interpreter, SMT stub, 50-relation parameterized EDB, 12 FSM
instances, refinement lattice.

```bash
swipl src/prolog/formulog_minikanren_kernel.pl
?- kernel_demo.
```

---

## Governance Validators

`src/validators/` contains Rust and Go implementations of the ICP-DAG governance
protocol enforcement layer.

| File | Language | Role |
|------|----------|------|
| `governance-validator.rs` | Rust | Compile-time invariant enforcement (714 LOC) |
| `governance-validator.go` | Go | Runtime governance protocol enforcement (726 LOC) |

---

## Run

```bash
# Soufflé Datalog
souffle tests/valid_dag.dl
souffle tests/invalid_cycle.dl
souffle tests/invalid_self_edge.dl
souffle tests/invalid_unknown_decides.dl
souffle tests/invalid_unauthorized_exec.dl

# SWI-Prolog
swipl tests/prolog_tests.pl
swipl src/prolog/formulog_minikanren_kernel.pl -g "kernel_demo, halt."

# Clingo ASP
clingo src/asp/icp_dag.lp tests/valid_dag_facts.lp

# Lattice kernel
chez --script src/lattice-kernel/mu_kanren.scm
swipl src/lattice-kernel/lattice_kernel.pl -g "demo, halt."
souffle src/lattice-kernel/path_refine.dl -D.
picat src/lattice-kernel/lattice_kernel.pi
lean src/lattice-kernel/LatticeKernel.lean
mmc --make src/lattice-kernel/lattice_kernel
coqc src/lattice-kernel/LatticeKernel.v
```

---

## Agent Submissions

`spec/submissions/`:
- `icp-dag-gen1.xml` — ICP-DAG crystallizer (Datalog, 10 invariants)
- `compiler-00-gen1.xml` — compiler-00 (SWI-Prolog, 6 kernels, 12-condition gate)
