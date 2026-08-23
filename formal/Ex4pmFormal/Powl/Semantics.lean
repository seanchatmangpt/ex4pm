import Ex4pmFormal.Powl.Syntax

namespace Ex4pmFormal.Powl

private def concatLang (left right : List (List String)) : List (List String) :=
  left.flatMap (fun l => right.map (fun r => l ++ r))

private def seqLang : List (List (List String)) → List (List String)
  | [] => [[]]
  | h :: t => concatLang h (seqLang t)

private def repeatLang : Nat → List (List String) → List (List String) → List (List String)
  | 0, body, _redo => body
  | Nat.succ n, body, redo => concatLang (concatLang body redo) (repeatLang n body redo)

mutual
  def language : Syntax → List (List String)
    | .atom a => [[a]]
    | .silent => [[]]
    | .seq xs => seqLang (xs.map language)
    | .choice xs => xs.flatMap language
    | .repeat n body redo => repeatLang n (language body) (language redo)
    | .admittedPartial traces => traces

  def execLanguage : Exec → List (List String)
    | .finiteFragments traces => traces
end

end Ex4pmFormal.Powl
