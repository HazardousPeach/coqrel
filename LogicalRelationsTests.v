Require Import LogicalRelations.
Require Import Coq.Lists.List.
Require Import OptionRel.
Local Open Scope rel_scope.

(** * Tests *)

(** ** Reflexivity *)

Goal
  forall A (a: A), a = a.
Proof.
  intros.
  rauto.
Qed.

Goal
  forall A (a: A), exists b, b = a.
Proof.
  intros; eexists.
  monotonicity.
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

(** There is an issue with the following. *)

Goal
  forall A (a b: A) (R: rel A A) (f: A -> A) (p: A -> Prop),
    Monotonic f (R ++> R) ->
    Monotonic p (R --> impl) ->
    R a b ->
    p (f b) ->
    p (f a).
Proof.
  intros A a b R f p Hf Hp Hab H.
  Fail rewrite <- Hab in H.
Abort.

(** ** Monotonicity tactics *)

(** Basic sanity check. This has actually failed in the past due to
  [context_candidate] being too liberal and selecting the [RB]
  property instead of [RA], then going nowhere with that with no
  backtracking implemented yet. *)

Goal
  forall A B (RA: rel A A) (x y: A) (RB: rel B B) (z t: B),
    RA x y ->
    RB z t ->
    RA x y.
Proof.
  intros.
  rauto.
Qed.

Goal
  forall A (a b: A) (R: rel A A) (H: R a b),
    let f (x y: A * A) := (@pair (A+A) (A+A) (inr (fst x)) (inl (snd y))) in
    Monotonic f (R * ⊤ ++> ⊤ * R ++> (⊥ + R) * (R + ⊥))%rel.
Proof.
  intros; unfold f.
  rauto.
Qed.

Goal
  forall {A1 A2 B1 B2} (R1 R1': rel A1 A2) (R2 R2': rel B1 B2),
    subrel R1' R1 ->
    subrel R2 R2' ->
    subrel (R1 ++> R2) (R1' ++> R2').
Proof.
  do 10 intro.
  rauto.
Qed.

(** Check that we can use relational hypotheses from the context as
  well as [Monotonic]/[Related] instances. *)

Goal
  forall
    {A B} (R: rel A A)
    (op: A -> B) (Hop: (R ++> eq) op op)
    (x y: A) (Hxy: R x y),
    op x = op y.
Proof.
  intros.
  rauto.
Qed.

(** Bug with relational parametricity: you can't [RElim] a relation
  you don't know yet. *)

Goal
  forall {A B} (RA: rel A A) (RB: rel B B) (m n: (A -> B) * B) (x: A),
    ((- ==> RB) * RB)%rel m n ->
    RB (fst m x) (fst n x).
Proof.
  intros A B RA RB m n x Hmn.
  try monotonicity.
  try rauto.
Abort.

(** Pattern matching *)

Goal
  forall {A B} (RA: rel A A) (RB: rel B B) (x y: A) (f: A -> A + B),
    RA x y ->
    (RA ++> RA + RB) f f ->
    RA (match f x with inl a => a | inr b => x end)
       (match f y with inl a => a | inr b => y end).
Proof.
  intros.
  rauto.
Qed.

Goal
  forall {A B} (RA: rel A A) (RB: rel B B) (x y: A * B) (z: A),
    RA z z ->
    prod_rel RA RB x y ->
    RA (let (a, b) := x in z)
       (let (a, b) := y in z).
Proof.
  intros.
  rauto.
Qed.

Goal
  forall {A} (R: rel A A),
    Monotonic
      (fun (b: bool) x y => if b then x else y)
      (- ==> R ++> R ++> R).
Proof.
  intros.
  rauto.
Qed.

Goal
  forall {A} (R : rel A A) (b : bool) (x y : A),
    b = b ->
    R x x ->
    R y y ->
    R (if b then x else y)
      (if b then x else y).
Proof.
  intros.
  rauto.
Qed.

(** [rel_curry] *)

Goal
  forall {A B C} R R' S (f: A -> B -> B -> C) (x1 y1: A) (x2 y2: B),
    Monotonic f (rel_curry (R ++> R' ++> S)) ->
    S (f x1 x2 x2) (f y1 y2 y2).
Proof.
  intros A B C R R' S f x1 y1 x2 y2 Hf.
  monotonicity.
Abort.

(** If we can deduce some terms are equal, we should be able to
  rewrite them under any context. However right now this can only be
  done by declaring the [f_equal_relim] hint.

  Maybe a good solution for this might even go further: abstract the
  common context and use [eq_rect] if it's possible to prove equality
  between the variant parts. *)

Goal
  forall {A} (R: rel A A) (f: A -> A) (C: A -> Prop) x y,
    Monotonic f (R ++> eq) ->
    R x y ->
    C (f x) ->
    C (f y).
Proof.
  intros A R f C x y Hf Hxy.
  Fail rauto.
  pose proof @f_equal_relim.
  rauto.
Qed.

(** *** Hypotheses from the context *)

(* This used to fail because [Hyy] would
  shadow [Hxy] (the hypothesis we want). *)

Goal
  forall {A} (R: rel A A) (x y: A),
    R x y -> eq y y -> R x y.
Proof.
  intros A R x y Hxy Hyy.
  monotonicity.
Qed.

(* This still fail with Coq 8.5, but Coq 8.6 is able to backtrack and
  try hypothesis from the context beyond the first one it finds. *)

Goal
  forall {A} (R: rel A A) (x y: A),
    R x y -> eq x y -> R x y.
Proof.
  intros A R x y Hxy Hyy.
  try monotonicity.
Abort.

(** This used to fail because the flipped hypothesis would not be
  identified as a candidate. This is important because the constraints
  generated by the setoid rewriting system often have this form. *)

Goal
  forall {A} (R: rel A A) (f : A -> A),
    Monotonic f (R ++> R) ->
    (flip R ++> flip R) f f.
Proof.
  intros A R f Hf.
  rauto.
Qed.

(** Then *this* used to fail because the [flip] was hidden until after
  we exploit the [subrel] property. This is important in particular
  when using the equivalences for a given partial order, as in [eqrel]
  vs. [subrel], where we want to be able to use equivalences in both
  directions. *)

Goal
  forall {A} (R R': rel A A) (f: A -> A),
    Monotonic f (R ++> R) ->
    Related R' (flip R) subrel ->
    (R' ++> flip R) f f.
Proof.
  intros A R R' f Hf HR.
  rauto.
Qed.

(** As an example where proper handling of [flip] is important,
  this is a goal generated by [setoid_rewrite] when we try to rewrite
  using [eqrel] under [option_le]. Here, both [R1] and [R2] have to be
  instantiated as [flip eq] (so that the associated hypotheses can be
  used to solve goals of the form [yi = xi]), and similarly we need to
  use the super-relation [flip subrel] of [eqrel]. *)

Goal
  forall A, exists R1 R2: relation (option A),
    (eqrel ==> R1 ==> R2 ==> flip impl)%signature option_le option_le.
Proof.
  intros A. eexists. eexists.
  rauto.
Qed.

(** *** [impl] vs. [subrel] *)

(** This checks that a relational property written in terms of
  [subrel] can be used to solve a goal stated in terms of [impl].
  This is made possible by [subrel_impl_relim]. *)

Goal
  forall A B C (R: rel A A) (f: A -> rel B C) a1 a2 b c,
    Monotonic f (R ++> subrel) ->
    R a1 a2 ->
    impl (f a1 b c) (f a2 b c).
Proof.
  intros A B C R f a1 a2 b c Hf Ha.
  monotonicity; rauto.
Qed.

Goal
  forall A1 A2 B1 B2 (R1 R2: rel A1 A2) (R: rel B1 B2),
    subrel R1 R2 ->
    forall x y,
      (R2 ++> R) x y ->
      (R1 ++> R) x y.
Proof.
  intros A1 A2 B1 B2 R1 R2 R HR12 x y.
  rauto.
Qed.

(** *** Generic rules *)

(** The [coreflexivity] of [rel_prod] and [eq] makes it possible for
  [pair_rel] to behave in the same way as [f_equal] below, since they
  allow us to deduce that [eq * eq] is a [subrel] of [eq]. *)

Goal
  forall A B (x1 x2 : A) (y1 y2 : B),
    x1 = x2 -> y1 = y2 -> (x1, y1) = (x2, y2).
Proof.
  intros.
  rauto.
Qed.

(** ** Using [foo_subrel] instances *)

(** Still broken because of the interaction between [subrel] and
  [- ==> - ==> impl] (or lack thereof) *)

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
         (HopA: Monotonic opA (RA ++> RA ++> RA))
         (HopB: Monotonic opB (RB ++> RB ++> RB))
         (Hxa: RA xa1 xa2)
         (Hxb: RB xb1 xb2)
         (Hya: RA ya1 ya2)
         (Hyb: RB yb1 yb2),
    (RA * RB)%rel
      (opA xa1 ya1, opB xb1 yb1)
      (opA xa2 ya2, opB xb2 yb2).
Proof.
  intros.
  rauto.
Qed.

Goal
  forall A1 A2 B1 B2 C1 C2 (R1 R2: rel A1 A2) (R1': rel B1 B2) (R: rel C1 C2),
    subrel R1 R2 ->
    forall x y,
      (R2 * R1' ++> R) x y ->
      (R1 * R1' ++> R) x y.
Proof.
  intros A1 A2 B1 B2 C1 C2 R1 R2 R1' R HR12 x y H.
  rewrite HR12.
  assumption.
Qed.

(** ** The [rgraph] tactic *)

Goal
  forall {A} (R S T: rel A A),
    subrel R S ->
    subrel S R ->
    subrel S T ->
    subrel R T.
Proof.
  intros.
  rstep.
Qed.

Goal
  forall `(PER) (x y z t : A),
    R x y ->
    R z y ->
    R z t ->
    R t x.
Proof.
  intros.
  rstep.
Qed.

(** ** The [transport] tactic *)

Goal
  forall W acc A B C (R1: W -> rel A A) (R2: W -> rel B B) (R3: W -> rel C C) f g a b x w,
    Monotonic f (rforall w, R1 w ++> R2 w) ->
    Monotonic g (rforall w, R2 w ++> option_rel (rel_incr acc R3 w)) ->
    R1 w a b ->
    g (f a) = Some x ->
    exists y, rel_incr acc R3 w x y.
Proof.
  intros.
  transport H2.
  eexists.
  rauto.
Qed.

(** ** Tests for specific relators *)

(** *** [list_rel] *)

(** [list_subrel] use to not work because of a missing [Params] declaration. *)

Goal
  forall A B (R R': rel A B) l1 l2 x y,
    subrel R R' ->
    list_rel R l1 l2 ->
    R' x y ->
    list_rel R' (x :: l1) (y :: l2).
Proof.
  intros.
  rauto.
Qed.

(** *** [rel_pull] *)

(** The [RIntro] instance for [rel_pull] used to be less general. *)

Goal
  forall A B (f: A -> B) (R: rel B B) x y,
    R (f x) (f y) ->
    (R @@ f) x y.
Proof.
  intros.
  rauto.
Qed.

(** We don't want the introduction rule for [rel_pull] to shadow
  relational properties. *)

Lemma rel_pull_2:
  forall A B (f: A -> B) (R: rel B B) (g: A -> A) x y,
    Monotonic g (⊤ ==> R @@ f) ->
    (R @@ f) (g x) (g y).
Proof.
  intros.
  rauto.
Qed.

(** *** [rel_all] *)

Lemma rel_all_1:
  forall {A} (x: A),
    (rforall a, req a) x x -> forall a, req a x x.
Proof.
  intros.
  rauto.
Qed.

(** *** [rel_ex] *)

Lemma rel_ex_1:
  forall {A} (x: A),
    (rexists a, req a) x x.
Proof.
  intros.
  rauto.
Qed.

(** *** [rel_top] *)

(** We used to only have an [RIntro] instance for [⊤%rel], which is
  enough for proving all goals of the form [⊤%rel x y] but not enough
  to derive properties of relations in which [⊤%rel] is a component. *)

Lemma rel_top_component_refl:
  forall {A} (x: list A),
    list_rel ⊤ x x.
Proof.
  intros.
  rauto.
Qed.

Lemma rel_top_component_trsym:
  forall {A} (x y z: list A),
    list_rel ⊤ x y -> list_rel ⊤ z y -> list_rel ⊤ x z.
Proof.
  intros.
  rauto.
Qed.
