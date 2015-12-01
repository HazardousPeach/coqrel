(** This file implements a tactical [delaying tac] and a tactic
  [delay], which function in the following way: [tac] is able to
  invoke [delay] to solve any subgoal. Assuming the subgoal can be
  typed in the context in which [delaying tac] was invoked, the
  [delay] tactic will succeed, and the subgoal will instead become a
  subgoal of the encolosing invocation of [delaying tac].

  To see why this is useful, consider the way [eauto] works. Applying
  an [eauto] hint is only considered successful when the generated
  subgoal can themselves be solved by [eauto]. Otherwise, [eauto]
  backtracks and another hint is used. If no hint can be used to solve
  the goal completely, then no progress is made.

  While this behavior is usually appropriate, this means [eauto]
  cannot be used as a base for tactics which make as much progress as
  possible, then let the user (or another tactic in a sequence) solve
  the remaining subgoals. With the tactics defined below, this can be
  accomplished by registering an external hint making use of [delay]
  for strategic subgoals, and invoking [delaying eauto].

  Additionally, the variant [delaying_conjunction] bundles all of the
  subgoals solved by [delay] in a single conjunction of the form
  [P1 /\ ... /\ Pn /\ True]. This is useful as it provides a uniform
  interface when reifying the effect of a tactic. *)


(** * The [delayed]/[delay] tactics *)

Module Delay.
  (** The [delaying] tactical and the [delay] tactic communicate
    through the use of existential variables. Specifically, [delaying]
    introduces a so-called "open conjunction" to the context. The open
    conjunction starts as a hypothesis of type [?P], and remains of
    the form [P1 /\ ... /\ Pn /\ ?Q] throughout. Each invocation of
    [delay] unifies [?Q] with a new node [Pi /\ ?Q']. *)

  Ltac use_conjunction H :=
    first [ use_conjunction (proj2 H) | eapply (proj1 H) ].

  (** Once we're done, we've packaged all of the goals we solved using
    [use_conjunction] into a single hypothesis. We can use the
    following tactic to split up that conjunction into individual
    subgoals again. *)

  Ltac split_conjunction :=
    match goal with
      | |- _ /\ _ => split; [ | split_conjunction]
      | |- _ => exact I
      | |- ?Q => fail 1 "split_conjunction: improper terminator" Q
    end.

  (** As much as possible, our open conjunction should remain hidden
    from the user's point of view. To avoid interfering with random
    tactics such as [eassumption], we wrap it in the following record
    type. *)

  Record open_conjunction (P: Prop) :=
    {
      open_conjunction_proj: P
    }.

  (** Now we can defined [delayed], [delayed_conjunction] and [delay]. *)

  Ltac delay :=
    idtac;
    lazymatch goal with
      | Hdelayed: open_conjunction _ |- _ =>
        use_conjunction (open_conjunction_proj _ Hdelayed)
      | _ =>
        fail "delay can only be used under the 'delayed' tactical"
    end.

  Ltac delayed_conjunction tac :=
    let Pv := fresh in evar (Pv: Prop);
    let P := eval red in Pv in clear Pv;
    let Hdelayed := fresh "Hdelayed" in
    cut (open_conjunction P);
    [ intro Hdelayed; tac; clear Hdelayed |
      eapply Build_open_conjunction ].

  Ltac delayed tac :=
    delayed_conjunction tac;
    [ | split_conjunction ].
End Delay.

Tactic Notation "delayed" tactic1(tac) :=
  Delay.delayed tac.

Tactic Notation "delayed_conjunction" tactic1(tac) :=
  Delay.delayed_conjunction tac.

Ltac delay := Delay.delay.


(** * Hints *)

(** We hook [delay] into [eauto] in two different ways: subgoals
  intended to be delayed can be marked with the wrapper below.
  Alternately, one can use the [delay] hint database, which provides a
  low-priority delay rule. *)

Definition delay (P: Prop) := P.

Hint Extern 0 (delay _) => delay.

Hint Extern 100 => delay : delay.


(** * Example: reifying [eapply] *)

(** To demonstrate how [delayed_conjunction] can be used to reify a
  tactic into a typeclass, we define the [EApply] typeclass. An
  instance of [EApply HT P Q] expresses that if [H] is a hypothesis of
  type [HT], then invoking [eapply H] on a goal of type [Q] will
  generate the subgoal conjunction [P]. *)

Class EApply (HT P Q: Prop) :=
  eapply : HT -> P -> Q.

Hint Extern 1 (EApply ?HT _ _) =>
  let H := fresh in
  let HP := fresh "HP" in
    intros H HP;
    delayed_conjunction solve [eapply H; delay];
    eexact HP :
  typeclass_instances.
