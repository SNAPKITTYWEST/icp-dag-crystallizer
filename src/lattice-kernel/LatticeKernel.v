(* LatticeKernel.v — Coq production specification of the relational kernel.
   Inductive relations are the source of truth (search/proof).
   Fixpoints are the executable shadow (extraction / compute).
   Load: coqtop -l LatticeKernel.v   or  coqc LatticeKernel.v
   No extra libraries beyond Coq.Init. *)

From Coq Require Import Arith.PeanoNat.
From Coq Require Import Bool.Bool.
From Coq Require Import Lists.List.
From Coq Require Import Strings.String.
From Coq Require Import Lia.
Import ListNotations.

Module LatticeKernel.

(* ---------- lists as relations ---------- *)

Inductive appendo {A : Type} : list A -> list A -> list A -> Prop :=
| appendo_nil : forall s, appendo [] s s
| appendo_cons : forall a d s res,
    appendo d s res ->
    appendo (a :: d) s (a :: res).

Inductive membero {A : Type} : A -> list A -> Prop :=
| membero_here : forall x d, membero x (x :: d)
| membero_there : forall x a d, membero x d -> membero x (a :: d).

Inductive rembero {A : Type} : A -> list A -> list A -> Prop :=
| rembero_here : forall x d, rembero x (x :: d) d
| rembero_there : forall x a d res,
    x <> a -> rembero x d res -> rembero x (a :: d) (a :: res).

Inductive reverseo_acc {A : Type} : list A -> list A -> list A -> Prop :=
| rev_nil : forall acc, reverseo_acc [] acc acc
| rev_cons : forall a d acc o,
    reverseo_acc d (a :: acc) o ->
    reverseo_acc (a :: d) acc o.

Definition reverseo {A} (l o : list A) : Prop := reverseo_acc l [] o.

Inductive lengtho {A : Type} : list A -> nat -> Prop :=
| lengtho_nil : lengtho [] 0
| lengtho_cons : forall a d n, lengtho d n -> lengtho (a :: d) (S n).

Inductive distincto {A : Type} : list A -> Prop :=
| distincto_nil : distincto []
| distincto_cons : forall a d,
    ~ membero a d -> distincto d -> distincto (a :: d).

Fixpoint append_f {A} (l s : list A) : list A :=
  match l with
  | [] => s
  | a :: d => a :: append_f d s
  end.

Lemma appendo_correct : forall A (l s : list A),
  appendo l s (append_f l s).
Proof.
  induction l; intros; simpl; constructor; auto.
Qed.

Lemma appendo_fun : forall A (l s o : list A),
  appendo l s o -> o = append_f l s.
Proof.
  intros A l s o H; induction H; simpl; congruence.
Qed.

(* ---------- Peano arithmetic (nat is Coq's Peano) ---------- *)

Inductive addo : nat -> nat -> nat -> Prop :=
| addo_z : forall y, addo 0 y y
| addo_s : forall x y z, addo x y z -> addo (S x) y (S z).

Inductive mulo : nat -> nat -> nat -> Prop :=
| mulo_z : forall y, mulo 0 y 0
| mulo_s : forall x y z1 z,
    mulo x y z1 -> addo y z1 z -> mulo (S x) y z.

Lemma addo_plus : forall x y z, addo x y z <-> z = x + y.
Proof.
  split.
  - intros H; induction H; simpl; lia.
  - revert y z; induction x; intros y z ->; simpl; constructor; auto.
Qed.

Lemma mulo_mult : forall x y z, mulo x y z -> z = x * y.
Proof.
  intros x y z H; induction H.
  - reflexivity.
  - apply addo_plus in H0. subst. lia.
Qed.

(* ---------- bits / full adder ---------- *)

Inductive bit : Type := B0 | B1.

Definition bit_to_nat (b : bit) : nat :=
  match b with B0 => 0 | B1 => 1 end.

Inductive bit_xoro : bit -> bit -> bit -> Prop :=
| xor00 : bit_xoro B0 B0 B0
| xor01 : bit_xoro B0 B1 B1
| xor10 : bit_xoro B1 B0 B1
| xor11 : bit_xoro B1 B1 B0.

Inductive bit_ando : bit -> bit -> bit -> Prop :=
| and00 : bit_ando B0 B0 B0
| and01 : bit_ando B0 B1 B0
| and10 : bit_ando B1 B0 B0
| and11 : bit_ando B1 B1 B1.

Inductive half_addero : bit -> bit -> bit -> bit -> Prop :=
| half_add : forall x y r c,
    bit_xoro x y r -> bit_ando x y c -> half_addero x y r c.

Inductive full_addero : bit -> bit -> bit -> bit -> bit -> Prop :=
| full_add : forall cin x y r cout w c1 c2,
    half_addero x y w c1 ->
    half_addero w cin r c2 ->
    bit_xoro c1 c2 cout ->
    full_addero cin x y r cout.

Definition xor_f (x y : bit) : bit :=
  match x, y with
  | B0, B0 => B0 | B0, B1 => B1 | B1, B0 => B1 | B1, B1 => B0
  end.

Definition and_f (x y : bit) : bit :=
  match x, y with
  | B1, B1 => B1 | _, _ => B0
  end.

Definition full_add_f (cin x y : bit) : bit * bit :=
  let w := xor_f x y in
  let c1 := and_f x y in
  let r := xor_f w cin in
  let c2 := and_f w cin in
  (r, xor_f c1 c2).

Lemma xor_rel_fun : forall x y r, bit_xoro x y r <-> r = xor_f x y.
Proof.
  split; intros H.
  - inversion H; reflexivity.
  - subst; destruct x, y; constructor.
Qed.

Lemma and_rel_fun : forall x y r, bit_ando x y r <-> r = and_f x y.
Proof.
  split; intros H.
  - inversion H; reflexivity.
  - subst; destruct x, y; constructor.
Qed.

Lemma half_add_sound : forall x y r c,
  r = xor_f x y -> c = and_f x y -> half_addero x y r c.
Proof.
  intros; apply half_add; [apply xor_rel_fun | apply and_rel_fun]; auto.
Qed.

Lemma full_add_sound : forall cin x y r cout,
  full_add_f cin x y = (r, cout) ->
  full_addero cin x y r cout.
Proof.
  intros cin x y r cout H.
  unfold full_add_f in H. inversion H; subst.
  eapply full_add.
  - apply half_add_sound; reflexivity.
  - apply half_add_sound; reflexivity.
  - apply xor_rel_fun; reflexivity.
Qed.

(* numeric contract: sum bits + carry-in = result + 2*carry-out *)
Lemma full_add_value : forall cin x y r cout,
  full_addero cin x y r cout ->
  bit_to_nat x + bit_to_nat y + bit_to_nat cin
    = bit_to_nat r + 2 * bit_to_nat cout.
Proof.
  intros cin x y r cout H.
  inversion H; subst.
  inversion H0; subst. inversion H1; subst.
  inversion H4; inversion H5; inversion H2; inversion H3; inversion H6;
    subst; simpl; reflexivity.
Qed.

(* ---------- SMT stub ---------- *)

Inductive smt : Type :=
| SatAtom : string -> smt
| SatNot  : smt -> smt
| SatAnd  : smt -> smt -> smt.

Fixpoint atoms (p : smt) : list smt :=
  match p with
  | SatAnd a b => atoms a ++ atoms b
  | other => [other]
  end.

Definition smt_sat (p : smt) : bool :=
  let as_ := atoms p in
  negb (existsb (fun q =>
          match q with
          | SatNot r => existsb (fun z =>
              match z, r with
              | SatAtom s1, SatAtom s2 => String.eqb s1 s2
              | _, _ => false
              end) as_
          | SatAtom s => existsb (fun z =>
              match z with
              | SatNot (SatAtom s2) => String.eqb s s2
              | _ => false
              end) as_
          | _ => false
          end) as_).

(* ---------- graph / path ---------- *)

Definition node := nat.

Inductive edgeo : node -> node -> smt -> Prop :=
| e01 : edgeo 0 1 (SatAtom "bv_slt_x_y")
| e12 : edgeo 1 2 (SatAtom "bv_slt_y_z")
| e23 : edgeo 2 3 (SatAtom "bv_sgt_z_x")
| e31 : edgeo 3 1 (SatAnd (SatAtom "p") (SatNot (SatAtom "q"))).

Inductive patho : node -> node -> list node -> smt -> Prop :=
| path_base : forall x y phi,
    edgeo x y phi ->
    smt_sat phi = true ->
    patho x y [y] phi
| path_step : forall x y z p2 e phi2,
    edgeo x z e ->
    patho z y p2 phi2 ->
    ~ membero z p2 ->
    smt_sat (SatAnd e phi2) = true ->
    patho x y (z :: p2) (SatAnd e phi2).

Lemma edge_01_sat : smt_sat (SatAtom "bv_slt_x_y") = true.
Proof. reflexivity. Qed.

Lemma path_0_1 : patho 0 1 [1] (SatAtom "bv_slt_x_y").
Proof. apply path_base; [constructor | reflexivity]. Qed.

(* ---------- FSM ---------- *)

Inductive fsm_state : Type := S0 | S1.

Inductive fsmo : fsm_state -> bit -> fsm_state -> bit -> Prop :=
| fsm_s0_0 : fsmo S0 B0 S0 B0
| fsm_s0_1 : fsmo S0 B1 S1 B0
| fsm_s1_0 : fsmo S1 B0 S0 B1
| fsm_s1_1 : fsmo S1 B1 S1 B1.

Definition fsm_f (st : fsm_state) (inp : bit) : fsm_state * bit :=
  match st, inp with
  | S0, B0 => (S0, B0)
  | S0, B1 => (S1, B0)
  | S1, B0 => (S0, B1)
  | S1, B1 => (S1, B1)
  end.

Lemma fsmo_fun : forall st inp nst out,
  fsmo st inp nst out <-> fsm_f st inp = (nst, out).
Proof.
  split; intros H.
  - inversion H; reflexivity.
  - destruct st, inp; inversion H; constructor.
Qed.

Inductive fsm_trace : fsm_state -> list bit -> fsm_state -> list bit -> Prop :=
| trace_nil : forall s, fsm_trace s [] s []
| trace_cons : forall s0 inp ins sn out outs s1,
    fsmo s0 inp s1 out ->
    fsm_trace s1 ins sn outs ->
    fsm_trace s0 (inp :: ins) sn (out :: outs).

(* ---------- abstract refinement ---------- *)

Inductive abs_val : Type :=
| Conc : nat -> abs_val
| Top
| Interval : nat -> nat -> abs_val.

Inductive refineo : abs_val -> nat -> Prop :=
| ref_conc : forall n, refineo (Conc n) n
| ref_top  : forall n, refineo Top n
| ref_ivl  : forall lo hi n, lo <= n -> n <= hi -> refineo (Interval lo hi) n.

Lemma refine_interval_3 : refineo (Interval 0 7) 3.
Proof. apply ref_ivl; lia. Qed.

(* ---------- evalo subset (quote / var / lambda / app) ---------- *)

Inductive expr : Type :=
| EQuote : nat -> expr
| EVar   : string -> expr
| ELam   : string -> expr -> expr
| EApp   : expr -> expr -> expr
| ECons  : expr -> expr -> expr
| EIf    : expr -> expr -> expr -> expr.

Inductive value : Type :=
| VNat : nat -> value
| VClos : string -> expr -> list (string * value) -> value
| VPair : value -> value -> value
| VBool : bool -> value.

Inductive lookupo : string -> list (string * value) -> value -> Prop :=
| look_here : forall x v rest, lookupo x ((x, v) :: rest) v
| look_there : forall x y v rest r,
    x <> y -> lookupo x rest r -> lookupo x ((y, v) :: rest) r.

Inductive evalo : expr -> list (string * value) -> value -> Prop :=
| ev_quote : forall n env, evalo (EQuote n) env (VNat n)
| ev_var   : forall x env v, lookupo x env v -> evalo (EVar x) env v
| ev_lam   : forall p b env, evalo (ELam p b) env (VClos p b env)
| ev_app   : forall rator rand env p b env' arg val,
    evalo rator env (VClos p b env') ->
    evalo rand env arg ->
    evalo b ((p, arg) :: env') val ->
    evalo (EApp rator rand) env val
| ev_cons  : forall a d env va vd,
    evalo a env va -> evalo d env vd ->
    evalo (ECons a d) env (VPair va vd)
| ev_if_t  : forall c t e env val,
    evalo c env (VBool true) -> evalo t env val ->
    evalo (EIf c t e) env val
| ev_if_f  : forall c t e env val,
    evalo c env (VBool false) -> evalo e env val ->
    evalo (EIf c t e) env val.

Lemma eval_quote : evalo (EQuote 42) [] (VNat 42).
Proof. constructor. Qed.

Lemma eval_id :
  evalo (EApp (ELam "x" (EVar "x")) (EQuote 7)) [] (VNat 7).
Proof.
  eapply ev_app.
  - apply ev_lam.
  - apply ev_quote.
  - apply ev_var. apply look_here.
Qed.

End LatticeKernel.
