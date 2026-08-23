namespace Ex4pmFormal.Powl

inductive Syntax where
  | atom : String → Syntax
  | silent : Syntax
  | seq : List Syntax → Syntax
  | choice : List Syntax → Syntax
  | repeat : Nat → Syntax → Syntax → Syntax
  | admittedPartial : List (List String) → Syntax
  deriving Repr, DecidableEq

inductive Exec where
  | atom : String → Exec
  | silent : Exec
  | seq : List Exec → Exec
  | choice : List Exec → Exec
  | repeat : Nat → Exec → Exec → Exec
  | finiteFragments : List (List String) → Exec
  deriving Repr, DecidableEq

end Ex4pmFormal.Powl
