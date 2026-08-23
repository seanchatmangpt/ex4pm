import Ex4pmFormal.Powl.Soundness

namespace Ex4pmFormal.Powl

/-- Every bounded declarative POWL trace is represented by the finite
executable projection. -/
theorem compile_complete (p : Syntax) (trace : List String)
    (h : trace ∈ language p) : trace ∈ execLanguage (compile p) := by
  simpa [compile, execLanguage] using h

/-- The two one-way obligations close the finite bounded language court. -/
theorem compile_iff (p : Syntax) (trace : List String) :
    trace ∈ execLanguage (compile p) ↔ trace ∈ language p := by
  constructor
  · exact compile_sound p trace
  · exact compile_complete p trace

end Ex4pmFormal.Powl
