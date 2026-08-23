import Ex4pmFormal.Powl.Soundness

namespace Ex4pmFormal.Powl
theorem compile_complete (p : Syntax) : language p = execLanguage (compile p) := by
  simpa using (compile_sound p).symm
end Ex4pmFormal.Powl
