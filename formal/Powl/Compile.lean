import Ex4pmFormal.Powl.Semantics

namespace Ex4pmFormal.Powl

/-- Formal executable projection. The executable Elixir court separately binds
this finite language to observed Reactor plans, preventing the formal model from
self-certifying production compilation. -/
def compile (p : Syntax) : Exec := .finiteFragments (language p)

end Ex4pmFormal.Powl
