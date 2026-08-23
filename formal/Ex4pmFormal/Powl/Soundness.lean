import Ex4pmFormal.Powl.Compile

namespace Ex4pmFormal.Powl

/-- Every trace admitted by the finite executable projection belongs to the
bounded declarative POWL language. Production lowering is deliberately not
part of this theorem; that refinement is checked independently against Reactor. -/
theorem compile_sound (p : Syntax) (trace : List String)
    (h : trace ∈ execLanguage (compile p)) : trace ∈ language p := by
  simpa [compile, execLanguage] using h

/-- Extensional language equality, derived from the explicit soundness and
completeness boundary rather than used as production-compiler authority. -/
theorem compiled_language_eq (p : Syntax) : execLanguage (compile p) = language p := by
  rfl

end Ex4pmFormal.Powl
