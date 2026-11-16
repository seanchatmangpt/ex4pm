# TODO-FIX-AND-FINISH (ex4pm)

Standing: UNVERIFIED

Source: PROJECT-REVIEWS.md R4; re-read where marked confirmed.

## Fix

- MED `lib/ex4pm/engine/adapters.ex:184-185` `admit_identity(identity, nil) when is_map` returns
  `:ok` with no expected digest (confirmed read); degrade to `:partial_alive` and downstream
  enforcement UNVERIFIED. Check: court that missing digest cannot reach ALIVE.
- MED atom minting from input: `priv/ggen/templates/standing_coded.ex.eex:59-62` (`new/2`
  guards `is_atom`; mint site UNVERIFIED), `soundness_prover.ex:55`, `cognition/prolog.ex:163`.
  Fix in template then regenerate. Check: no `String.to_atom` on input in generated output.
- MED unguarded `apply` on `task.intent` (`runtime/intent.ex:15-19`); local executor origin
  UNVERIFIED. Check: allow-list court.
- LOW `brce_gate.ex:85-95` no fallback clause; `cli.ex:134` `to_existing_atom` raises
  (UNVERIFIED).

## Finish

- Generated `standing_coded.ex` must be fixed via template, not hand edit (ggen law).
- Version sync with ash_ex4pm pin (see ash_ex4pm TODO).

## Commit hygiene

- Modified `docs/thesis/chapters/generated_ocel_benchmark_tables.tex` uncommitted (confirmed;
  generated file, verify generator before staging).

## Decide

- Whether missing expected NIF digest is refused outright or remains `:partial_alive`.

## Reuse

- Engine adapters admission pattern (`engine/adapters.ex:184`) for identity-bound admission.

## See Also

`ash_ex4pm/docs/jira/v26.11.12/TODO-FIX-AND-FINISH.md`
