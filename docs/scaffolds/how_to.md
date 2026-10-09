# How to: Using crate

## Prerequisites


- BasicPredicate::t (type)

- BindingBox::BindingBox (struct)

- Data::Data (struct)

- Ex4pm.Claim::Ex4pm.Claim (struct)

- Ex4pm.Claim::t (type)

- Ex4pm.Core.Capability::Ex4pm.Core.Capability (struct)

- Ex4pm.Core.Capability::t (type)

- Ex4pm.Core.Hash::digest (function)

- Ex4pm.Core.Hash::digest (type)

- Ex4pm.Engine.Discovery.Incremental::Ex4pm.Engine.Discovery.Incremental (struct)

- Ex4pm.Engine.Discovery.Incremental::dfg (function)

- Ex4pm.Engine.Discovery.Incremental::edge (type)

- Ex4pm.Engine.Discovery.Incremental::finalize (function)

- Ex4pm.Engine.Discovery.Incremental::from_events (function)

- Ex4pm.Engine.Discovery.Incremental::new (function)

- Ex4pm.Engine.Discovery.Incremental::t (type)

- Ex4pm.Engine.Discovery.Incremental::update (function)

- Ex4pm.Engine.Discovery.InductiveMiner::activity (type)

- Ex4pm.Engine.Discovery.InductiveMiner::alphabet (function)

- Ex4pm.Engine.Discovery.InductiveMiner::detect_exclusive_choice_cut (function)

- Ex4pm.Engine.Discovery.InductiveMiner::detect_sequence_cut (function)

- Ex4pm.Engine.Discovery.InductiveMiner::directly_follows_graph (function)

- Ex4pm.Engine.Discovery.InductiveMiner::event_log (type)

- Ex4pm.Engine.Discovery.InductiveMiner::mine (function)

- Ex4pm.Engine.Discovery.InductiveMiner::trace (type)

- Ex4pm.Engine.Ferroplan.Host::fetch (function)

- Ex4pm.Engine.Ferroplan.Host::handle_call (function)

- Ex4pm.Engine.Ferroplan.Host::init (function)

- Ex4pm.Engine.Ferroplan.Host::stop_all (function)

- Ex4pm.Engine.Ferroplan::artifact_path (function)

- Ex4pm.Engine.Ferroplan::available? (function)

- Ex4pm.Engine.Ferroplan::execute (function)

- Ex4pm.Engine.Ferroplan::explain (function)

- Ex4pm.Engine.Ferroplan::fond_policy (function)

- Ex4pm.Engine.Ferroplan::fond_policy_validate (function)

- Ex4pm.Engine.Ferroplan::fond_validate (function)

- Ex4pm.Engine.Ferroplan::hddl_solve (function)

- Ex4pm.Engine.Ferroplan::hierarchical_plan (function)

- Ex4pm.Engine.Ferroplan::id (function)

- Ex4pm.Engine.Ferroplan::opts (type)


## Steps


1. Use `t` from `BasicPredicate`.

2. Use `BindingBox` from `BindingBox`.

3. Use `Data` from `Data`.

4. Use `capabilities` from `Ex4pm`.

5. Use `cmca` from `Ex4pm`.

6. Use `conform` from `Ex4pm`.

7. Use `contracts` from `Ex4pm`.

8. Use `differential` from `Ex4pm`.

9. Use `discover` from `Ex4pm`.

10. Use `ferroplan` from `Ex4pm`.

11. Use `forecast` from `Ex4pm`.

12. Use `health` from `Ex4pm`.


## Verified snippet

<!-- The snippet slot carries code copied from the extracted code surface -->
<!-- (doc:Claim rows whose doc:attribute is "snippet"), never agent prose. -->

```rust
// Ex4pm :: capabilities
capabilities/2
```

<!-- AGENT-COMMENTARY-BEGIN -->
<!-- The ONLY region an agent may write into. Bounds: <= 12 lines,    -->
<!-- <= 100 chars/line, no new code facts (any new symbol mentioned   -->
<!-- must exist in queries/ast_extract.rq output; the doc_quality     -->
<!-- court fails Phi_halluc > 0.001 otherwise). No tables, no         -->
<!-- signatures, no parameters, no error lists — AGENT-FORBIDDEN      -->
<!-- everywhere.                                                      -->
<!-- AGENT-COMMENTARY-END -->
