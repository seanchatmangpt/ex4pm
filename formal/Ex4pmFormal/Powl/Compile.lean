import Ex4pmFormal.Powl.Semantics

namespace Ex4pmFormal.Powl

/-- The formal executable projection is the finite bounded trace fragment set.
The independent Elixir court separately checks each fragment against the actual
Reactor compiler, so this theorem cannot self-certify production lowering. -/
def compile (p : Syntax) : Exec := .finiteFragments (language p)

end Ex4pmFormal.Powl
