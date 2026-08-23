import Ex4pmFormal.Powl.Compile

namespace Ex4pmFormal.Powl

theorem compile_sound (p : Syntax) : execLanguage (compile p) = language p := by
  rfl
end Ex4pmFormal.Powl
