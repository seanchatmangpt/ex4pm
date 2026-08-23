namespace Ex4pmFormal.Powl

inductive Syntax where
  | atom : String → Syntax
  | silent : Syntax
  | seq : List Syntax → Syntax
  | choice : List Syntax → Syntax
  | repeat : Nat → Syntax → Syntax → Syntax
  | admittedPartial : List (List String) → Syntax
  deriving Repr

inductive Exec where
  | finiteFragments : List (List String) → Exec
  deriving Repr

end Ex4pmFormal.Powl
