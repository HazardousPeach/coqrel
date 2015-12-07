Require Import LogicalRelations.
Require Import Coq.Lists.List.

(** * Tests *)

(** ** Partial applications *)

Goal forall A (a1 a2: A) B (b1 b2: B) (RA: rel A A), True.
Proof.
  intros.

  evar (T: Type); evar (R: rel T T); subst T;
  assert (H1: ProperQuery (proper_partial_app::nil) R (@pair A A a1)); subst R.
  typeclasses eauto.
  instantiate (1 := RA) in H1.

  evar (T: Type); evar (R: rel T T); subst T;
  assert (H2: ProperQuery (proper_partial_app::nil) R (@pair A)); subst R.
  typeclasses eauto.
  instantiate (1 := RA) in H2.

  evar (T: Type); evar (R: rel T T); subst T;
  assert (H3: ProperQuery (proper_partial_app::nil) R (@inl A B a2)); subst R.
  typeclasses eauto.
  instantiate (1 := eq) in H3.

  exact I.
Qed.

(** ** Setoid rewriting *)

Goal
  forall A (a b: A) `(HR: Equivalence A) (H: R a b),
    sum_rel R R (inl a) (inl b).
Proof.
  intros.
  rewrite H.
  rewrite <- H.
  reflexivity.
Qed.

(** This test checks that [transitive_proper] is used as expected. *)

Goal
  forall A (op: A -> A -> A) (R: rel A A) (x y z: A),
    Proper (R ++> R ++> R) op ->
    PreOrder R ->
    R (op y x) (op x y) ->
    R (op (op z y) x) (op z (op x y)).
Proof.
  intros A op R x y z Hop HR H.
  rewrite <- H.

  (** For your debugging convenience, here are the goals generated by
    the [rewrite] above. *)
  evar (RE: rel A A);
  assert (Morphisms.Proper (RE ==> flip impl) (R (op (op z y) x))
       /\ Morphisms.Proper (flip R ==> RE) (op z)); subst RE.
  {
    split.
    * convert_proper.
      proper_orientation_flip.
      eapply do_proper_subrel.
      proper_partial_app_arg.
      eapply proper_partial_app_bail.
      eapply transitive_proper.
      typeclasses eauto.
      proper_applies.
      typeclasses eauto.
      reflexivity.
    * convert_proper.
      typeclasses eauto.
  }
Abort.

(** ** Monotonicity tactics *)

Goal
  forall A (a b: A) (R: rel A A) (H: R a b),
    let f (x y: A * A) := (@pair (A+A) (A+A) (inr (fst x)) (inl (snd y))) in
    Proper (R * ⊤ ++> ⊤ * R ++> (⊥ + R) * (R + ⊥)) f.
Proof.
  intros; unfold f.
  solve_monotonic.
Qed.

Goal
  forall {A1 A2 B1 B2} (R1 R1': rel A1 A2) (R2 R2': rel B1 B2),
    subrel R1' R1 ->
    subrel R2 R2' ->
    subrel (R1 ++> R2) (R1' ++> R2').
Proof.
  do 10 intro.
  solve_monotonic.
Qed.

Goal
  forall P Q R,
    impl Q R ->
    (impl P Q) -> (impl P R).
Proof.
  intros P Q R HPQ.
  solve_monotonic.
Qed.

(** Check that we can use relational hypotheses from the context as
  well as [Proper] and [Related] instances. *)

Goal
  forall
    {A B} (R: rel A A)
    (op: A -> B) (Hop: (R ++> eq) op op)
    (x y: A) (Hxy: R x y),
    op x = op y.
Proof.
  intros.
  solve_monotonic.
Qed.

(** Bug with relational parametricity: you can't [RElim] a relation
  you don't know yet. *)

Goal
  forall {A B} (RA: rel A A) (RB: rel B B) (m n: (A -> B) * B) (x y: A),
    ((- ==> RB) * RB)%rel m n ->
    RB (fst m x) (fst n x).
Proof.
  intros A B RA RB m n x y Hmn.
  try monotonicity.
  try solve_monotonic.
Abort.

(** ** Using [foo_subrel] instances *)

Goal
  forall A1 A2 B1 B2 C1 C2 (R1 R2: rel A1 A2) (R1': rel B1 B2) (R: rel C1 C2),
    subrel R1 R2 ->
    forall x y,
      (R2 ++> R) x y ->
      (R1 ++> R) x y.
Proof.
  intros A1 A2 B1 B2 C1 C2 R1 R2 R1' R HR12 x y H.
  rewrite HR12.
  assumption.
Qed.

Goal
  forall A B (xa1 xa2 ya1 ya2 : A) (xb1 xb2 yb1 yb2 : B)
         (opA: A -> A -> A) (opB: B -> B -> B)
         (RA: rel A A) (RB: rel B B)
         (HopA: Proper (RA ++> RA ++> RA) opA)
         (HopB: Proper (RB ++> RB ++> RB) opB)
         (Hxa: RA xa1 xa2)
         (Hxb: RB xb1 xb2)
         (Hya: RA ya1 ya2)
         (Hyb: RB yb1 yb2),
    (RA * RB)%rel
      (opA xa1 ya1, opB xb1 yb1)
      (opA xa2 ya2, opB xb2 yb2).
Proof.
  intros.
  solve_monotonic.
Qed.

(** FIXME: this should work as well. *)

Goal
  forall A1 A2 B1 B2 C1 C2 (R1 R2: rel A1 A2) (R1': rel B1 B2) (R: rel C1 C2),
    subrel R1 R2 ->
    forall x y,
      (R2 * R1' ++> R) x y ->
      (R1 * R1' ++> R) x y.
Proof.
  intros A1 A2 B1 B2 C1 C2 R1 R2 R1' R HR12 x y H.
  try rewrite HR12.
Abort.
