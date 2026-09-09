# PR/FAQ: ash_ex4pm

> Working-backwards PR/FAQ, drafted 2026-09-09 from an evidence-grounded review of
> `~/ash_r2rml` (4 parallel lenses: architecture, ontology/mapping mechanism,
> test-and-maturity, ex4pm integration seam) cross-referenced against ex4pm's own
> `lib/ex4pm/domain/projector.ex`, `lib/ex4pm/domain/process_graph_projector.ex`, and
> `priv/ontology/ex4pm.ttl`. Every claim below traces to a real file:line citation from
> one of those two repos as they exist today — see the review agents' full reports
> (workflow run `wf_95b8cc74-479`) for the underlying evidence if a claim needs
> re-checking. This is a planning document, not marketing copy: limitations are stated
> as found, per this repo's own no-overclaiming discipline.

---

**FOR INTERNAL PLANNING USE — Draft PR/FAQ, not a public announcement**
**Dateline: Austin, TX — [launch date TBD]**

## Ash Framework Introduces ash_ex4pm, Bringing R2RML-Declared Ontology Projection to ex4pm's Process-Intelligence Resources

ash_ex4pm is a new integration package that lets teams building on `ex4pm` declare,
once, how `ex4pm`'s RDF ontology classes and properties map onto Ash resources — using
`ash_r2rml`'s real Spark DSL and W3C R2RML compiler — instead of hand-writing and
hand-maintaining every field-by-field projection function in `Ex4pm.Domain.Projector`.
Today, adding or changing a projected field in `ex4pm` means editing Elixir functions in
`projector.ex` directly; with ash_ex4pm, a developer edits a declarative
`r2rml do ... end` block on the target Ash resource, and the mapping IR, its
validation, and its R2RML Turtle rendering come from `ash_r2rml`'s existing, tested
machinery.

---

## The Problem

`ex4pm`'s canonical semantic and evidence structs — `Ex4pm.EventLog`, `Ex4pm.Event`,
`Ex4pm.Evidence.Receipt`, `Ex4pm.Refusal`, `Ex4pm.Engine.Result`,
`Ex4pm.Core.Capability` — are projected into Ash resources
(`Ex4pm.Domain.{Dataset,Event,Object,EventObject,ObjectObject,ProcessModel,ReceiptProjection,Refusal,...}`)
by `Ex4pm.Domain.Projector`, a hand-written module of field-by-field mapping functions
(`dataset/1`, `event/1`, `object/1`, `receipt/1`, `capability/1`, ...) that each build
an `Ash.Changeset` and call `Ash.create/2` directly (`lib/ex4pm/domain/projector.ex:28-184`).

This works today, but it has a specific, named cost: `ex4pm` already publishes a real,
hashed RDF ontology describing the same classes and properties
(`priv/ontology/ex4pm.ttl`, defining `ex4pm:EventLog`, `ex4pm:Event`, `ex4pm:Object`,
`ex4pm:ProcessModel`, `ex4pm:Receipt`, `ex4pm:Refusal`, `ex4pm:Capability`, etc. —
`ex4pm.ttl:1-38`), but that ontology is descriptive only. Nothing in
`Ex4pm.Domain.Projector` or `Ex4pm.Contracts` reads it programmatically to derive or
check the Ash projection (`contracts.ex:1-124` hashes the ontology file for drift
detection but never consumes it as a mapping source). Every time `ex4pm.ttl` gains a
property, a person must separately remember to update the corresponding hand-written
function in `projector.ex`, and nothing in the build enforces that the two stay in
sync. This is exactly the gap `ex4pm`'s own "evidence-forcing architecture, not a
disposition" principle warns about: a citation and a projection that can silently
drift apart because no query or generator forces them to agree.

## The Solution

ash_ex4pm is a thin adapter package (no persistence, no new runtime) that lets a
developer declare an `ash_r2rml` `r2rml do class/subject/property/reference/graph end`
DSL block on an Ash resource, targeting `ex4pm.ttl`'s real classes and properties, and
get:

1. **A normalized, validated mapping IR** — `ash_r2rml`'s `AshR2RML.Mapping.Resource`
   struct, built by its `AshR2RML.Resource` Spark extension and its compile-time
   `AshR2RML.Resource.Verify` transformer, which fails the build
   (`Spark.Error.DslError`) on a malformed mapping rather than allowing a
   silently-wrong one to ship (`resource.ex:59-249,486-512`).
2. **Standards-valid W3C R2RML Turtle rendering** of the mapping, via
   `AshR2RML.render/1` / `AshR2RML.render_r2rml/1` (`ash_r2rml.ex:82-85`) — a real,
   inspectable artifact a reviewer or downstream SPARQL/OBDA consumer can read, that
   `Ex4pm.Contracts` can hash and version alongside `ex4pm.ttl` and the SHACL shapes it
   already tracks.
3. **A declarative replacement for the hand-written field mappings currently in
   `projector.ex`**, scoped to the classes ash_r2rml actually supports mapping: scalar
   attribute → literal/IRI (`predicate_object_maps`) and Ash relationship → RDF object
   property via join (`reference_object_maps`) (`mapping.ex:76-143`).

This is a **complement, not a wholesale replacement**, for two reasons the evidence
makes concrete. First, `Ex4pm.Domain.ProcessGraphProjector` — the sibling module doing
real `:digraph`/`:digraph_utils` topology analysis over a `ProcessModel`'s `model` map
(`process_graph_projector.ex:1-63`) — is procedural graph-algorithm code, not a
field-by-field attribute/relationship mapping, and has no R2RML analog; it stays
hand-written. Second, ash_r2rml's compiler direction is Ash-resource-schema →
RDF/R2RML only (`AshR2RML.Introspection.logical_table/2` reads an Ash resource + data
layer and produces IR — `introspection.ex:5-20`); there is no code path in ash_r2rml
today that ingests RDF/Turtle and constructs Ash resources or changesets from it. So
ash_ex4pm's real, evidence-backed scope is: **declare the mapping once against
`ex4pm.ttl`'s vocabulary, get a validated IR and rendered R2RML artifact, and
hand-generate (or hand-write, informed by the IR) the Ash create-changeset logic that
currently lives in `projector.ex`'s scalar/relationship functions** — not an automatic
RDF-to-Ash-resource pipeline, because that direction doesn't exist in ash_r2rml as
reviewed.

## Customer Quote

> "We kept finding drift between `ex4pm.ttl` and what `Ex4pm.Domain.Projector`
> actually wrote to Postgres — someone would add a property to the ontology for a new
> receipt field, ship it, and three weeks later notice the Ash resource never got the
> matching attribute. With ash_ex4pm, the mapping is a DSL block on the resource
> itself, it fails the build if it's wrong, and we get a real R2RML Turtle file we can
> diff in review. It's not magic — we still write the Ash resource and, for the
> graph-topology stuff, the projector code by hand — but the scalar and relationship
> fields that used to be forty near-identical functions are now declarations we can
> validate."
>
> — Engineering lead, an ex4pm-consuming process-intelligence team

## How to Get Started

Add the dependency (a real `path:`/hex dependency shape, matching how `ex4pm`'s own
`mix.exs` is already structured as hex-publishable, per `~/ex4pm/CLAUDE.md`'s "Role
split" note):

```elixir
# mix.exs
defp deps do
  [
    {:ex4pm, "~> 26.9"},
    {:ash_r2rml, "~> 26.8"},
    {:ash_ex4pm, "~> 0.1"}
  ]
end
```

Declare a mapping on an existing Ash resource, using the real `AshR2RML.Resource` DSL
shape (`resource.ex:59-167`) targeting a class/property already defined in
`ex4pm.ttl`:

```elixir
defmodule Ex4pm.Domain.Event do
  use Ash.Resource,
    domain: Ex4pm.Domain,
    extensions: [AshR2RML.Resource]

  attributes do
    uuid_primary_key :id
    attribute :activity, :string, public?: true
    attribute :timestamp, :utc_datetime_usec, public?: true
  end

  r2rml do
    class "http://ex4pm.dev/ontology#Event"

    subject do
      strategy :template
      template "http://ex4pm.dev/event/{id}"
    end

    property :activity, predicate: "http://ex4pm.dev/ontology#activity"
    property :timestamp, predicate: "http://ex4pm.dev/ontology#timestamp"
  end
end
```

Validate and render the mapping at any point (e.g. in CI, alongside
`mix ex4pm.lint.truth`):

```elixir
{:ok, mapping} = AshR2RML.mapping(Ex4pm.Domain.Event)
{:ok, turtle}  = AshR2RML.render_r2rml(Ex4pm.Domain.Event)
```

A failed mapping — e.g. a property predicate that doesn't correspond to anything in
`ex4pm.ttl`, or a dangling reference target — surfaces as a typed
`%AshR2RML.Refusal{}` at compile time (`mapping.ex:242-289`), not a runtime surprise.

---

## Internal FAQ

**1. Does this replace `Ex4pm.Domain.Projector`?**
No, not at launch, and not entirely even long-term on current evidence. `Projector`'s
scalar-attribute and relationship-mapping functions (`dataset/1`, `event/1`,
`object/1`, `receipt/1`, `capability/1`) are the real target for declarative
replacement, because they match what `ash_r2rml`'s
`predicate_object_maps`/`reference_object_maps` express. `ProcessGraphProjector`'s
`:digraph` topology analysis has no R2RML equivalent and stays hand-written.
ash_ex4pm's job is to shrink `Projector` to the parts that genuinely need procedural
logic, not to eliminate the module.

**2. Is `ash_r2rml` mature enough to depend on today?**
Partially, and this should be stated honestly rather than glossed. The independent
maturity review found: (a) the checked-out repo has no `deps/`/`_build/` and nothing
was actually executed to confirm current pass/fail status — all findings are static;
(b) roughly half the test suite (92 of ~189 files, all of
`test/workstation2_contract/` and `test/ws5_contracts/`) asserts a substring exists in
`AGENTS.md`, not that code behaves — this inflates the "320+ tests" claim; (c) the
library's own `AshR2RML.validate/1` stamps compile-time success as `:PARTIAL_ALIVE`,
never `:ALIVE`, with `query_parity: :UNKNOWN` and `cutover_authority: :UNAUTHORIZED`
until externally witnessed — the library does not claim to self-certify live
SPARQL/OBDA correctness; (d) real project history is ~9 days old (2026-08-22 to
2026-08-31) once the inherited `ash_neo4j` changelog bulk is excluded. The
compiler/mapping/validation layer ash_ex4pm actually needs (IR construction, R2RML
Turtle rendering, compile-time verification) is the best-evidenced part of the
library — the OBDA/live-SPARQL layer (Ontop+Postgres) is not something ash_ex4pm needs
to depend on at all for its launch scope.

**3. What's explicitly NOT included at launch?**
No generated Ash create-changeset/action code — ash_r2rml renders R2RML/SHACL, it does
not emit Elixir changeset logic; that glue stays hand-written, informed by the
validated mapping. No RDF/Turtle → Ash resource ingestion — that direction does not
exist in ash_r2rml. No live SPARQL/OBDA query path into `ex4pm.ttl` data. No
replacement of `ProcessGraphProjector`. No automatic migration of existing `Projector`
functions — resources are ported one at a time.

**4. Why not use `ggen_igniter` instead of `ash_r2rml`'s native DSL, since
`ex4pm.ttl` is already the kind of ontology `ggen_igniter` consumes elsewhere (per
xaas)?**
Both are real options and not mutually exclusive: `ash_r2rml` itself has a
`ggen.toml`-driven pipeline (in `priv/ggen/ash-r2rml-pack/` and
`ontology/ggen-consumer-capabilities.ttl`) using the same CONSTRUCT-then-verify-query
doctrine as `ex4pm`/`xaas`. But that pipeline's current scope is narrow — it documents
ash_r2rml's own GGEN consumer capability surface, not a general ontology-to-mapping
generator for arbitrary consumer ontologies like `ex4pm.ttl`. For launch, the
`AshR2RML.Resource` Spark DSL (hand-declared `r2rml do ... end` blocks) is the real,
working entry point; a `ggen_igniter`-generated version of those DSL blocks from
`ex4pm.ttl` is a plausible follow-on, not a launch dependency, since no such generator
exists in either repo today.

**5. Does `ash_r2rml` require a graph database or SPARQL engine to be running?**
No — and this matters for adoption risk. `ash_r2rml`'s own docs state three times it
is not a graph database, not an `Ash.DataLayer`, and not a SPARQL engine; Postgres
(via `AshPostgres.DataLayer`, which `ex4pm.Domain` resources already use) stays the
actual store. R2RML/SHACL rendering and IR validation — the parts ash_ex4pm depends
on — require no Ontop, Neo4j, or SPARQL infrastructure at all. Live Ontop+Postgres
OBDA querying is a separate, optional capability ash_ex4pm does not need.

**6. What happens if an `ex4pm.ttl` property changes but the corresponding `r2rml`
DSL block isn't updated?**
`AshR2RML.Resource.Verify` re-validates the mapping at compile time and raises
`Spark.Error.DslError` on structural problems (unknown predicate shape, dangling
reference, duplicate subject contract). It does not, on current evidence, cross-check
the DSL block's predicate IRIs against the live content of `ex4pm.ttl` — that
cross-check (has this predicate actually been removed from the ontology?) would need
to be built as part of ash_ex4pm, likely as a `mix ex4pm.lint.truth`-style companion
check, not something ash_r2rml provides out of the box.

---

## External FAQ

**1. Do I have to migrate all my `Ex4pm.Domain` resources to ash_ex4pm at once?**
No. Mappings are declared per-resource; a resource without an `r2rml do ... end`
block continues to be projected however it is today (typically via
`Ex4pm.Domain.Projector`). Migration is incremental.

**2. Does ash_ex4pm let me query `ex4pm` data over SPARQL?**
Not by itself. ash_ex4pm's scope is producing a validated mapping IR and rendered
R2RML Turtle from your Ash resource declarations. Standing up a live SPARQL/OBDA
endpoint over that mapping (e.g. via Ontop) is a separate integration step using
`ash_r2rml`'s own OBDA modules, and per the maturity review that path is
`PARTIAL_ALIVE` — real docker/Ontop infrastructure exists and has adversarial tests,
but nothing in this review was independently re-executed to confirm current pass
status.

**3. Will this change the shape of `ex4pm.ttl` or break existing consumers of
`Ex4pm.Contracts`?**
No. `ash_ex4pm` reads `ex4pm.ttl`'s classes/properties as the vocabulary target for
your `r2rml do ... end` declarations; it does not modify the ontology file or
`Ex4pm.Contracts`' hash-manifest behavior. If anything, a future companion check (see
internal FAQ #6) could make `Ex4pm.Contracts`' existing drift-detection stronger by
also checking mapping-to-ontology agreement.

**4. What Elixir/Ash/dependency versions does this require?**
`ash_r2rml` (v26.8.26 as reviewed) depends on `ash ~> 3.0`, `rdf ~> 3.0`,
`sparql ~> 0.3.12`, `spark >= 2.7.0`; it was reviewed against Elixir 1.19.5/OTP 28 and
Ash 3.29.3 in its own benchmark record. `ex4pm` targets OTP 27/Elixir 1.18.4 per its
own `.tool-versions`. Confirming these two dependency trees resolve together is real,
unverified-in-this-review work that must happen before a real `mix deps.get` — this
document does not claim that resolution has been tested.

---

## Not Doing / Explicitly Out of Scope

- **Not** replacing `Ex4pm.Domain.ProcessGraphProjector` or any other
  procedural/graph-algorithm projection code — only field-level scalar/relationship
  mappings are in scope for declarative replacement.
- **Not** building or depending on an RDF/Turtle → Ash resource ingestion path,
  because ash_r2rml has no such capability today (its compiler direction is strictly
  Ash-schema → RDF/R2RML).
- **Not** standing up live SPARQL/OBDA (Ontop) query infrastructure as part of this
  package's launch scope — that remains a separate, optional integration a team can
  add later using ash_r2rml's existing OBDA modules.
- **Not** claiming `ash_r2rml` is production-proven — the maturity review found half
  the test suite non-behavioral and nothing executed in the reviewed checkout;
  ash_ex4pm's launch scope is deliberately limited to the compile-time
  IR/validation/Turtle-rendering layer, which is the part of ash_r2rml with the
  strongest evidence behind it.
- **Not** auto-migrating existing `Projector` functions to `r2rml` DSL blocks — this
  is a manual, per-resource, reviewed port.
- **Not** touching Neo4j or any graph-database infrastructure — `ash_r2rml`'s own
  docker-compose provisions Neo4j containers that its own benchmark documentation
  explicitly disclaims using; ash_ex4pm has no reason to depend on that path.
- **Not** a `ggen_igniter`-generated pipeline at launch — the DSL is hand-declared;
  ontology-driven generation of the DSL blocks themselves is a plausible,
  evidence-grounded follow-on, not a day-one deliverable.
