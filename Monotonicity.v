Require Export RelDefinitions.
Require Export RelOperators.
Require Export Relators.
Require Import Delay.

(** ** The [monotonicity] tactic *)

(** The purpose of the [monotonicity] tactic is to automatically
  select and apply a theorem of the form [Proper ?R ?m] in order to
  make progress when the goal is an applied relation. Compared with
  setoid rewriting, [monotonicity] is less powerful, but more direct
  and simple. This means it is easier to debug, and it can seamlessly
  handle dependent types and heterogenous relations. *)

(** *** Truncating applications *)

(** The search is guided by the left-hand side term, so that if the
  goal has the form [?R (?f ?x1 ?x2 ?x3 ... ?xn) ?y], we will seek a
  [Proper] instance for some prefix [f x1 ... xk]. This allows both
  [R] and [y] to be existential variables, which is required in
  particular by the [transport] tactic.

  However, since peeling off the [xi]s one by one and conducting a
  full-blown search at every step is very time-consuming, we narrow
  down the search to only one option whenever a [Params] instance has
  been declared. The [get_params] tactic queries the declared number
  of parameters for a given head term [h] and passes it to the
  continuation [sk]. The [remove_params] tactic drops applied
  arguments from its argument [m] so that the result expects the
  declared number of parameters. We are careful to skip an appropriate
  number of parameters when the type of term indicates that it is
  already a partial application. *)

Ltac get_params h sk fk :=
  let nv := fresh "nparams" in evar (nv : nat);
  let n := eval red in nv in clear nv;
  let H := fresh in
  first
    [ assert (H: Params h n) by typeclasses eauto;
      clear H;
      let n := eval compute in n in first [ sk n | fail 2 ]
    | unify n O; (* make sure [n] is instantciated *)
      (* idtac "Warning: no Params instance for" h; *)
      fk ].

Ltac remove_params m sk fk :=
  let rec remove m n :=
    lazymatch n with
      | S ?n' =>
        lazymatch m with
          | ?m' _ => remove m' n'
        end
      | O => sk m
    end in
  let rec remove_from_partial m t n :=
    lazymatch t with
      | forall x, ?t' =>
        lazymatch n with
          | S ?n' => remove_from_partial m t' n'
        end
      | _ =>
        remove m n
    end in
  let rec head m :=
    lazymatch m with
      | ?m' _ => head m'
      | _ => constr:m
    end in
  let h := head m in
  let t := type of m in
  get_params h ltac:(remove_from_partial m t) fk.

(** When [get_params] fails, we need to enumerate all possible
  prefixes for a given application. This typeclass provides
  corresponding instances. When conducting a query, the first argument
  should be the application, the second argument should be an
  existential variable to be filled in. *)

Class IsPrefixOf {A B} (m: B) (f: A).

Global Instance is_prefix_of_self {A} (f: A):
  IsPrefixOf f f.

Lemma switch_to_prefix_of {A A' B} {m: A} (m': A') (f: B):
  IsPrefixOf m' f ->
  IsPrefixOf m f.
Proof.
  constructor.
Qed.

Hint Extern 1 (IsPrefixOf (?m ?n) ?f) =>
  eapply (switch_to_prefix_of m) : typeclass_instances.

(** Next, we reify [remove_params] as the [RemoveParams] class.
  An instance of [RemoveParams m f] indicates that [f] is a possible
  prefix of the application [m], as constrained by any declared
  [Params] instance. *)

Class RemoveParams {A B} (m: A) (f: B).

(** To resolve [RemoveParams m f], we attempt to use [remove_params]
  on [m]. If that succeeds, we unify the result with [f]. *)

Lemma remove_params_direct {A B} {m: A} (f: B):
  RemoveParams m f.
Proof.
  constructor.
Qed.

(* Otherwise, we allow any prefix of [m] to be used. *)

Lemma remove_params_anyprefix {A B} (m: A) (f: B):
  IsPrefixOf m f ->
  RemoveParams m f.
Proof.
  constructor.
Qed.

Hint Extern 1 (RemoveParams ?m _) =>
  remove_params m
    ltac:(fun f => eapply (remove_params_direct f))
    ltac:(eapply remove_params_anyprefix) : typeclass_instances.

(** *** Selecting a relational property *)

Class CandidateProperty {A B} (R: rel A B) m n (Q: Prop) :=
  candidate_related: Related R m n.

Lemma candidate_l {A B GA GB} (R: rel A B) f g (QR: rel GA GB) m n:
  RemoveParams m f ->
  Related R f g ->
  CandidateProperty R f g (QR m n).
Proof.
  firstorder.
Qed.

Hint Extern 2 (CandidateProperty _ _ _ (?QR ?m ?n)) =>
  not_evar m; eapply candidate_l : typeclass_instances.

Lemma candidate_r {A B QA QB} (R: rel A B) f g (QR: rel QA QB) m n:
  RemoveParams n g ->
  Related R f g ->
  CandidateProperty R f g (QR m n).
Proof.
  firstorder.
Qed.

Hint Extern 3 (CandidateProperty _ _ _ (?QR ?m ?n)) =>
  not_evar n; eapply candidate_r : typeclass_instances.

(** *** Using [subrel] *)

(** It is not obvious at what point in the process [subrel] should be
  hooked in. One thing we crucially want to avoid is an open-ended
  [subrel] search enumerating all possibilities to be filtered later,
  with a high potential for exponential blow-up should the user be a
  little too liberal with the [subrel] instances they declare.

  Here I choose to have it kick in after a candidate property has been
  selected, and we know how to apply it to a goal. Then we use
  [subrel] to bridge any gap between that goal and the actual one,
  through the [RImpl] class below.

  This is a conservative solution which precludes many interesting
  usages of [subrel]. For instance, suppose we have a relational
  property alogn the lines of [Proper ((R1 ++> R1) ∩ (R2 ++> R2)) f].
  We would want to be able to use it to show that [f] preserve [R1] or
  [R2] individually (because [subrel (R1 ++> R1) ((R1 ++> R1) ∩ (R2
  ++> R2))], but also together (because [subrel (R1 ∩ R2 ++> R1 ∩ R2)
  ((R1 ++> R1) ∩ (R2 ++> R2))]). This cannot be done using this
  approach, which does not act on the relational property itself but
  only the goal we're attempting to prove.

  Perhaps in the future we can extend this by acting at the level of
  [RElim]. In any case, we should provide explicit guidelines for when
  to declare [subrel] instances, and how. *)

Class RImpl (P Q: Prop): Prop :=
  rimpl: P -> Q.

Global Instance rimpl_refl P:
  RImpl P P.
Proof.
  firstorder.
Qed.

Global Instance rimpl_subrel {A B} (R R': rel A B) m n:
  subrel R R' ->
  Unconvertible _ R R' -> (* should be by convention on instances of [subrel]? *)
  RImpl (R m n) (R' m n).
Proof.
  firstorder.
Qed.

(** *** Main tactic *)

(** With these components, defining the [monotonicity] tactic is
  straightforward: identify a candidate property, then figure out a
  way to apply it to the goal [Q] using the [RElim] class. We first
  define a [Monotonicity] typeclass that captures this behavior with
  full backtracking ability. *)

Class Monotonicity (P Q: Prop): Prop :=
  monotonicity: P -> Q.

Global Instance apply_candidate {A B} (R: rel A B) m n P Q Q':
  CandidateProperty R m n Q ->
  RElim R m n P Q' ->
  RImpl Q' Q ->
  Monotonicity P Q.
Proof.
  firstorder.
Qed.

(** We also exploit [Reflexive] instances. A reflexive relation is one
  for which all elements are proper elements. Then reflexivity is a
  kind of general, nullary monotonicity property. In fact, in
  principle we should use [Reflexive] to declare a generic [Proper] or
  [Related] instance, and the instance below would follow. However,
  such instances end up polluting the resolution process and causing
  premature instanciations of existential variables.

  Instead, we only use the following instance as a last resort, and
  only to satisfy the goal directly (not in the search for relational
  properties). This allows us to insist the related terms be exactly
  identical, not just unifiable. *)

Global Instance reflexive_monotonicity {A} (R: rel A A) (m: A):
  NotEvar R ->
  Reflexive R ->
  Monotonicity True (R m m) | 10.
Proof.
  firstorder.
Qed.

(** The Ltac tactic simply applies [monotonicity]; typeclass
  resolution will do the rest. Note that using [apply] naively is too
  lenient because in a goal of type [A -> B], it will end up unifying
  [A] with [P] and [B] with [Q] instead of setting [Q := A -> B] and
  generating a new subgoal for [P] as expected. On the other hand,
  using [refine] directly is too restrictive because it will not unify
  the type of [monotonicity] against the goal if existential variables
  are present in one or the other. Hence we constrain apply just
  enough, so as to handle both of these cases. *)

Ltac monotonicity :=
  lazymatch goal with |- ?Q => apply (monotonicity (Q:=Q)) end;
  Delay.split_conjunction.

(** Another way to use [Monotonicity] is to hook it as an [RStep]
  instance. *)

Global Instance monotonicity_rstep {A B} (P: Prop) (R: rel A B) m n:
  Monotonicity P (R m n) ->
  RStep P R m n | 50.
Proof.
  firstorder.
Qed.

(** Convert goals of the form [P -> Q] to use the [impl] relation. *)

Global Instance impl_monotonicity P Q1 Q2:
  Monotonicity P (impl Q1 Q2) ->
  Monotonicity P (Q1 -> Q2).
Proof.
  firstorder.
Qed.

(** Our version of [Morphisms.f_equiv]. *)

Ltac f_equiv :=
  repeat monotonicity.

(** Our version of [Morphisms.solve_proper]. Note that we are somewhat
  parcimonious with introductions because we don't want to cause undue
  unfoldings. For instance, if we define the relation [R1] from [R2]
  as [R1 x y := forall i, R2 (get i x) (get i y)], we may create a
  situation where applying the monotonicity theorem for [get] on a
  goal of the form [R2 (get i x) (get i y)] produces a subgoal of the
  form [R1 x y], but then an introduction would get us back to where
  we started. So we limit them to well-defined cases.

  Most cases are straightforward. In the [match]/[if] case, we need to
  first show that the terms being destructed are related. Then if the
  relation has been defined in a typical way (akin to [sum_rel] or
  [list_rel] below), destructing that hypothesis will cause the goal
  to reduce and we can go on with the process. Note that for [prod],
  and for record types, we usually prefer to define associated
  relations as conjunctions of statements that the projections are
  related, in which case the terms would need to be destructed on
  their own as well. At the moment we only have a special case for
  [prod_rel]. *)

Ltac solve_monotonic_tac t :=
  let conclusion_progress t :=
    lazymatch goal with
      | |- ?G =>
        t;
        lazymatch goal with
          | |- G => fail "No progress in conclusion"
          | |- _ => idtac
        end
    end in
  let destruct_rel H :=
    idtac;
    match type of H with
      | prod_rel _ _ ?x ?y =>
        let H1 := fresh in
        let H2 := fresh in
        destruct x, y;
        destruct H as [H1 H2];
        simpl fst in H1, H2;
        simpl snd in H1, H2
      | _ =>
        destruct H
    end in
  let destruct_both m1 m2 :=
    let t1 := type of m1 in
    let t2 := type of m2 in
    let Rv := fresh "R" in evar (Rv: rel t1 t2);
    let Rm := eval red in Rv in clear Rv;
    let H := fresh in
    assert (H: Rm m1 m2) by solve_monotonic_tac t;
    conclusion_progress ltac:(destruct_rel H) in
  let step :=
    lazymatch goal with
      | |- Proper _ _ => red
      | |- Related _ _ _ => red
      | |- ?P -> ?Q => change (impl P Q)
      | |- _ (match ?m with _ => _ end) (match ?m with _ => _ end) =>
        destruct m
      | |- _ (if ?m then _ else _) (if ?m then _ else _) =>
        destruct m
      | |- _ (match ?m1 with _ => _ end) (match ?m2 with _ => _ end) =>
        destruct_both m1 m2
      | |- _ (if ?m1 then _ else _) (if ?m2 then _ else _) =>
        destruct_both m1 m2
      | |- _ =>
        rstep
    end in
  first [ step; solve_monotonic_tac t | t ].

Tactic Notation "solve_monotonic" :=
  solve_monotonic_tac ltac:(eassumption || congruence || (now econstructor)).

Tactic Notation "solve_monotonic" tactic(t) :=
  solve_monotonic_tac ltac:(eassumption || congruence || (now econstructor)|| t).

(** ** Exploiting [foo_subrel] instances *)

(** Although we declared [Proper] instances for the relation
  constructors we defined, so far the usefulness of these instances
  has been limited. But now we can use them in conjunction with our
  [monotonicity] tactic to break up [subrel] goals along the structure
  of the relations being considered. *)

Hint Extern 5 (subrel _ _) =>
  monotonicity; unfold flip : typeclass_instances.

(** Furthermore, the following instance of [subrel] enables the use of
  [foo_subrel] instances for rewriting along within applied relations.
  So that for instance, a hypothesis [H: subrel R1 R2] can be used for
  rewriting in a goal of the form [(R1 * R1' ++> R) x y]. *)

Instance subrel_pointwise_subrel {A B}:
  subrel (@subrel A B) (eq ==> eq ==> impl).
Proof.
  intros R1 R2 HR x1 x2 Hx y1 y2 Hy H; subst.
  eauto.
Qed.
