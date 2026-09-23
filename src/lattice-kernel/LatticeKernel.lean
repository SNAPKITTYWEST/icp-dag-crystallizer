/- LatticeKernel.lean — Lean 4 specification of the relational kernel.
   Theorems are the contracts; execution stays in miniKanren/Prolog/Formulog.
   lake / lean LatticeKernel.lean  (mathlib not required)
-/

namespace LatticeKernel

inductive Peano where
  | z
  | s : Peano → Peano
deriving Repr, DecidableEq

def add : Peano → Peano → Peano
  | .z, y => y
  | .s x, y => .s (add x y)

def mul : Peano → Peano → Peano
  | .z, _ => .z
  | .s x, y => add y (mul x y)

theorem add_z (y : Peano) : add .z y = y := rfl
theorem add_s (x y : Peano) : add (.s x) y = .s (add x y) := rfl

inductive Bit where
  | b0 | b1
deriving Repr, DecidableEq

def bitXor : Bit → Bit → Bit
  | .b0, .b0 => .b0
  | .b0, .b1 => .b1
  | .b1, .b0 => .b1
  | .b1, .b1 => .b0

def bitAnd : Bit → Bit → Bit
  | .b1, .b1 => .b1
  | _, _ => .b0

def fullAdd (cin x y : Bit) : Bit × Bit :=
  let w := bitXor x y
  let c1 := bitAnd x y
  let r := bitXor w cin
  let c2 := bitAnd w cin
  (r, bitXor c1 c2)

inductive Smt where
  | atom : String → Smt
  | not  : Smt → Smt
  | and  : Smt → Smt → Smt
deriving Repr

partial def atoms : Smt → List Smt
  | .and a b => atoms a ++ atoms b
  | p => [p]

def satStub (φ : Smt) : Bool :=
  let as := atoms φ
  ¬ as.any (fun p =>
    match p with
    | .not q => as.contains q
    | q => as.contains (.not q))

inductive FsmState where
  | s0 | s1
deriving Repr, DecidableEq

def fsm (st : FsmState) (inp : Bit) : FsmState × Bit :=
  match st, inp with
  | .s0, .b0 => (.s0, .b0)
  | .s0, .b1 => (.s1, .b0)
  | .s1, .b0 => (.s0, .b1)
  | .s1, .b1 => (.s1, .b1)

inductive Abs where
  | conc : Nat → Abs
  | top
  | interval : Nat → Nat → Abs
deriving Repr

def refines : Abs → Nat → Prop
  | .conc c, n => c = n
  | .top, _ => True
  | .interval lo hi, n => lo ≤ n ∧ n ≤ hi

end LatticeKernel
