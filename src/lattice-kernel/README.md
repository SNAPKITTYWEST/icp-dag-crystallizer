# src/lattice-kernel — 8-Language Relational Lattice Kernel

**License**: GPL-3.0-or-later OR Apache-2.0

A coherent multi-language implementation of a relational lattice kernel.
Every file implements the same set of relations across a different host language.
The Lean 4 and Coq files are the formal specifications; the others are executable.

---

## Relation Set

Every language implements (a subset of) these relations:

| Relation | Domain |
|----------|--------|
| `appendo`, `membero`, `rembero`, `reverseo`, `lengtho`, `distincto`, `permuteo` | Lists |
| `addo`, `mulo`, `zeroo`, `succo`, `nato` | Peano arithmetic |
| `bit-xoro`, `bit-ando`, `half-addero`, `full-addero`, `ripple-addero` | Bit / full adder |
| `lookupo`, `eval-expro`, `applyo`, `evalo` | Relational interpreter |
| `smt-sat?` / `smt_sato` / `satStub` | SMT satisfiability stub |
| `edgeo`, `patho`, `reacho` | Parameterized path / reachability |
| `fsmo`, `fsm-traceo` | FSM transitions + traces |
| `refineo` | Interval / abstract value refinement |

---

## Files

### Scheme — `mu_kanren.scm`
**Toolchain**: Chez Scheme, Guile, Racket (`#lang scheme`), or any R5RS/R7RS host.

Pure μKanren kernel with the canonical `(subst . counter)` state representation.
Implements the full `fresh`/`conde`/`run`/`run*` macro surface, `=/=`, `symbolo`,
`numbero`, `absento`, `call/fresh`. All list, Peano, bit, evalo, SMT, path, FSM,
and refinement relations are relational (work in all modes).

```scheme
(run 3 (q) (appendo '(1 2) '(3) q))
; => ((1 2 3))
(run* (q) (full-addero 0 1 1 q 1))
; => (0)
(run 1 (q) (evalo '(quote hello) q))
; => (hello)
```

```bash
chez --script src/lattice-kernel/mu_kanren.scm
guile src/lattice-kernel/mu_kanren.scm
```

---

### ISO Prolog — `lattice_kernel.pl`
**Toolchain**: SWI-Prolog 8+, GNU Prolog, SICStus.

Portable ISO Prolog port. Optionally loads `library(clpfd)` for the
`full_addo_clp/5` constraint-based adder. All relations work via standard
Prolog backtracking.

```prolog
?- appendo([1,2],[3],Q).
Q = [1, 2, 3].
?- full_addo(1,1,0,S,C).
S = 0, C = 1.
?- evalo(app(lambda(x,x),quote(hello)),V).
V = hello.
```

```bash
swipl src/lattice-kernel/lattice_kernel.pl -g "demo, halt."
```

---

### Formulog — `path_refine.flg`
**Toolchain**: [HarvardPL Formulog](https://github.com/HarvardPL/formulog).

Stratified Datalog + ML-style types + first-class SMT formulas. The `smt_formula`
algebraic type carries SMT terms through derivation rules. `sat_stub` is a
pure Formulog function; the full SMT solver is a drop-in replacement.

Strata:
1. Base reachability (no SMT)
2. Guarded reachability (`sat_stub` check)
3. Path with accumulated formula (conjunction of guards)
4. FSM trace derivation
5. Refinement + full-adder truth table

```bash
formulog src/lattice-kernel/path_refine.flg
```

---

### Soufflé Datalog — `path_refine.dl`
**Toolchain**: [Soufflé](https://souffle-lang.github.io/) ≥ 2.0.

Executable IDB with propositional tags replacing SMT (no external solver
required). Covers: guarded reachability, path tag accumulation, FSM
`fsm_reach`/`fsm_accepts`, full-adder truth table, list prefix sum,
3-color graph coloring, interval refinement, edge/sat statistics.

```bash
souffle src/lattice-kernel/path_refine.dl -D.
```

EDB input files: `edge.facts`, `fsm_trans.facts`, `abs_val.facts`, `list_elem.facts`
(tab-separated, one tuple per line).

---

### Picat — `lattice_kernel.pi`
**Toolchain**: [Picat](http://picat-lang.org/) ≥ 3.0.

Functional-logic port. Uses Picat's `cp` module for `full_addo_cp/5`
(constraint-based adder with `#=/2`). Peano relations are `tabled` for
termination guarantees. Includes `widen/3` for abstract domain joining.

```bash
picat src/lattice-kernel/lattice_kernel.pi
```

---

### Lean 4 — `LatticeKernel.lean`
**Toolchain**: `lake` or `lean src/lattice-kernel/LatticeKernel.lean`. No Mathlib required.

Formal specification only — theorems are the contracts; search stays in the
other languages. Covers:
- `Peano` inductive type + `add`/`mul` with `add_z`/`add_s` lemmas
- `Bit` type + `bitXor`/`bitAnd`/`fullAdd`
- `Smt` type + `satStub` (contradiction check)
- `FsmState` + `fsm` step function
- `Abs` type + `refines : Abs → Nat → Prop`

```bash
lean src/lattice-kernel/LatticeKernel.lean
```

---

### Mercury — `lattice_kernel.m`
**Toolchain**: Melbourne Mercury Compiler (`mmc`).

Production library with full mode declarations. Mercury's mode system
statically verifies that each predicate is deterministic in its declared modes.
Multi-mode predicates (e.g., `appendo(out,out,in) is multi`) are reversible.

Key modes:
- `addo(in,in,out) is det` / `addo(out,out,in) is multi`
- `full_addero(in,in,in,out,out) is det` / `(in,in,in,in,in) is semidet`
- `patho(in,in,out,out) is nondet`
- `fsmo(out,out,out,out) is multi`

```bash
mmc --make src/lattice-kernel/lattice_kernel   # link into an executable
# or as a library:
mmc --make liblattice_kernel
```

---

### Coq — `LatticeKernel.v`
**Toolchain**: `coqc` / `coqtop -l`. No extra libraries beyond `Coq.Init`.

Full inductive specification with correctness proofs:
- `appendo_correct`: `appendo l s (append_f l s)` — relation matches fixpoint
- `addo_plus`: `addo x y z ↔ z = x + y`
- `mulo_mult`: `mulo x y z → z = x * y`
- `full_add_value`: numeric contract `x + y + cin = r + 2 * cout`
- `xor_rel_fun` / `and_rel_fun`: bit relations match boolean functions
- `fsmo_fun`: `fsmo st inp nst out ↔ fsm_f st inp = (nst, out)`
- `path_0_1`: concrete path proof `patho 0 1 [1] (SatAtom "bv_slt_x_y")`
- `refine_interval_3`: `refineo (Interval 0 7) 3`
- `eval_quote` / `eval_id`: evalo sanity lemmas

```bash
coqc src/lattice-kernel/LatticeKernel.v
# or interactively:
coqtop -l src/lattice-kernel/LatticeKernel.v
```

---

## Cross-Language Correspondence

| Concept | Scheme | Prolog | Formulog | Soufflé | Picat | Lean 4 | Mercury | Coq |
|---------|--------|--------|----------|---------|-------|--------|---------|-----|
| Unification | `unify` | built-in | built-in | — | built-in | — | built-in | `unify` |
| Streams | `mplus`/`bind` | backtracking | semi-naïve | bottom-up | backtracking | — | backtracking | `Prop` |
| Full adder | `full-addero` | `full_addo` | `full_add_result` | `full_add` | `full_addero` | `fullAdd` | `full_addero` | `full_addero` |
| FSM step | `fsmo` | `fsmo` | `fsm_trans` (EDB) | `fsm_trans` (EDB) | `fsmo` | `fsm` | `fsmo` | `fsmo` |
| SAT stub | `smt-sat?` | `is_sat` | `sat_stub` | `sat_tag` | `is_sat` | `satStub` | `smt_sato` | `smt_sat` |
| Refinement | `refineo` | `refineo` | `refines` | `refines` | `refineo` | `refines` | `refineo` | `refineo` |

---

## Language Stack Policy

This batch is **Python-free**. Python kernel retired for new logic/symbolic work.
Allowed host languages for new additions: Mercury, Curry, Oz, Agda, Isabelle,
HOL, ACL2, Smalltalk, Ruby/Crystal.
