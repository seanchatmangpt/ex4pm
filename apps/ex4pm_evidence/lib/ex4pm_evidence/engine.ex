defmodule Ex4pmEvidence.Engine do
  @moduledoc """
  Multi-Standard Semantic Evidence & Provenance Engine.

  Generates standards-compliant RDF evidence and IEEE OCEL 2.0 process multigraphs:
  1. W3C EARL 1.0 test assertions (`earl:Assertion`, `earl:TestResult`, `earl:passed`, `earl:failed`, `earl:cantTell`, etc.)
  2. W3C SOSA / SSN observations with QUDT units (`sosa:Observation`, `qudt:QuantityValue`, `qudt:numericValue`, `qudt:unit`)
  3. W3C PROV-O execution lineage (`prov:Entity`, `prov:Activity`, `prov:Agent`, `prov:wasDerivedFrom`, `prov:wasGeneratedBy`)
  4. W3C DCAT 3 enterprise catalog records (`dcat:Catalog`, `dcat:Dataset`, `dcat:Distribution`, `dcat:DataService`)
  5. SPDX 3.0 package manifests with cryptographic SHA-256 state hashes.
  """

  # Standard Prefixes
  @earl_ns "http://www.w3.org/ns/earl#"
  @sosa_ns "http://www.w3.org/ns/sosa/"
  @qudt_ns "http://qudt.org/schema/qudt/"
  @unit_ns "http://qudt.org/vocab/unit/"
  @prov_ns "http://www.w3.org/ns/prov#"
  @dcat_ns "http://www.w3.org/ns/dcat#"
  @dcterms_ns "http://purl.org/dc/terms/"
  @spdx_ns "https://spdx.org/rdf/3.0.0/terms/"
  @f5_ns "https://enterprise.fortune5.com/ontology/"
  @f5_evidence_ns "https://enterprise.fortune5.com/evidence/"

  # ---------------------------------------------------------------------------
  # 1. W3C EARL 1.0 Test Assertion Generator
  # ---------------------------------------------------------------------------

  @doc "Builds a W3C EARL 1.0 test assertion map and Turtle representation."
  def build_earl_assertion(opts \\ []) do
    id_suffix = Keyword.get(opts, :id, "assertion-" <> random_id())
    assertion_iri = "#{@f5_evidence_ns}earl/#{id_suffix}"
    result_iri = "#{@f5_evidence_ns}earl/result/#{id_suffix}"

    asserted_by = Keyword.get(opts, :asserted_by, "#{@f5_ns}agent/ex4pm-verifier")
    subject = Keyword.get(opts, :subject, "#{@f5_ns}system/ex4pm-core")
    test_criterion = Keyword.get(opts, :test_criterion, "#{@f5_ns}test/conformance/soundness")
    outcome_atom = Keyword.get(opts, :outcome, :passed)
    mode_atom = Keyword.get(opts, :mode, :automatic)

    info =
      Keyword.get(
        opts,
        :info,
        "Formal process verification assertion passed with 100% operational closure."
      )

    pointer =
      Keyword.get(
        opts,
        :pointer,
        "urn:sha256:" <> (:crypto.hash(:sha256, info) |> Base.encode16(case: :lower))
      )

    timestamp = Keyword.get(opts, :timestamp, DateTime.utc_now() |> DateTime.to_iso8601())

    outcome_prefix = "earl:#{outcome_atom}"
    mode_prefix = "earl:#{mode_atom}"

    turtle = """
    @prefix earl: <#{@earl_ns}> .
    @prefix dcterms: <#{@dcterms_ns}> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

    <#{assertion_iri}> a earl:Assertion ;
        earl:assertedBy <#{asserted_by}> ;
        earl:subject <#{subject}> ;
        earl:test <#{test_criterion}> ;
        earl:result <#{result_iri}> ;
        earl:mode #{mode_prefix} .

    <#{result_iri}> a earl:TestResult ;
        earl:outcome #{outcome_prefix} ;
        earl:info "#{info}" ;
        earl:pointer "#{pointer}" ;
        dcterms:date "#{timestamp}"^^xsd:dateTime .
    """

    {:ok,
     %{
       id: assertion_iri,
       result_id: result_iri,
       outcome: outcome_atom,
       turtle: turtle,
       details: %{
         asserted_by: asserted_by,
         subject: subject,
         test_criterion: test_criterion,
         timestamp: timestamp
       }
     }}
  end

  # ---------------------------------------------------------------------------
  # 2. W3C SOSA / SSN + QUDT Observation Generator
  # ---------------------------------------------------------------------------

  @doc "Builds a SOSA/SSN telemetry observation with QUDT units."
  def build_sosa_observation(opts \\ []) do
    id_suffix = Keyword.get(opts, :id, "obs-" <> random_id())
    obs_iri = "#{@f5_evidence_ns}sosa/#{id_suffix}"
    value_iri = "#{@f5_evidence_ns}qudt/val/#{id_suffix}"

    observed_property = Keyword.get(opts, :observed_property, "#{@f5_ns}P99Latency")

    feature_of_interest =
      Keyword.get(opts, :feature_of_interest, "#{@f5_ns}service/order-ingress")

    numeric_value = Keyword.get(opts, :numeric_value, 24.5)
    unit_iri = Keyword.get(opts, :unit, "#{@unit_ns}MilliSEC")
    made_by_sensor = Keyword.get(opts, :made_by_sensor, "#{@f5_ns}sensor/open-telemetry-probe-1")
    timestamp = Keyword.get(opts, :result_time, DateTime.utc_now() |> DateTime.to_iso8601())

    turtle = """
    @prefix sosa: <#{@sosa_ns}> .
    @prefix qudt: <#{@qudt_ns}> .
    @prefix unit: <#{@unit_ns}> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

    <#{obs_iri}> a sosa:Observation ;
        sosa:observedProperty <#{observed_property}> ;
        sosa:hasFeatureOfInterest <#{feature_of_interest}> ;
        sosa:madeBySensor <#{made_by_sensor}> ;
        sosa:resultTime "#{timestamp}"^^xsd:dateTime ;
        sosa:hasResult <#{value_iri}> .

    <#{value_iri}> a qudt:QuantityValue ;
        qudt:numericValue "#{numeric_value}"^^xsd:decimal ;
        qudt:unit <#{unit_iri}> .
    """

    {:ok,
     %{
       id: obs_iri,
       value_id: value_iri,
       numeric_value: numeric_value,
       unit: unit_iri,
       turtle: turtle
     }}
  end

  # ---------------------------------------------------------------------------
  # 3. W3C PROV-O Lineage Generator
  # ---------------------------------------------------------------------------

  @doc "Builds a PROV-O execution lineage graph."
  def build_prov_lineage(opts \\ []) do
    id_suffix = Keyword.get(opts, :id, "act-" <> random_id())
    activity_iri = "#{@f5_evidence_ns}prov/activity/#{id_suffix}"
    agent_iri = Keyword.get(opts, :agent, "#{@f5_ns}agent/autonomous-worker-42")

    input_entity =
      Keyword.get(opts, :input_entity, "#{@f5_evidence_ns}entity/raw-event-stream-batch-1")

    output_entity =
      Keyword.get(
        opts,
        :output_entity,
        "#{@f5_evidence_ns}entity/conformance-report-#{id_suffix}"
      )

    start_time = Keyword.get(opts, :started_at_time, DateTime.utc_now() |> DateTime.to_iso8601())
    end_time = Keyword.get(opts, :ended_at_time, DateTime.utc_now() |> DateTime.to_iso8601())

    turtle = """
    @prefix prov: <#{@prov_ns}> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

    <#{activity_iri}> a prov:Activity ;
        prov:wasAssociatedWith <#{agent_iri}> ;
        prov:used <#{input_entity}> ;
        prov:startedAtTime "#{start_time}"^^xsd:dateTime ;
        prov:endedAtTime "#{end_time}"^^xsd:dateTime .

    <#{output_entity}> a prov:Entity ;
        prov:wasGeneratedBy <#{activity_iri}> ;
        prov:wasDerivedFrom <#{input_entity}> .
    """

    {:ok,
     %{
       activity_id: activity_iri,
       agent_id: agent_iri,
       input_entity: input_entity,
       output_entity: output_entity,
       turtle: turtle
     }}
  end

  # ---------------------------------------------------------------------------
  # 4. W3C DCAT 3 Catalog Record Generator
  # ---------------------------------------------------------------------------

  @doc "Builds a DCAT 3 dataset catalog entry."
  def build_dcat_catalog_record(opts \\ []) do
    id_suffix = Keyword.get(opts, :id, "dataset-" <> random_id())
    catalog_iri = "#{@f5_evidence_ns}dcat/catalog/main"
    dataset_iri = "#{@f5_evidence_ns}dcat/dataset/#{id_suffix}"
    distribution_iri = "#{@f5_evidence_ns}dcat/dist/#{id_suffix}"

    title = Keyword.get(opts, :title, "IEEE OCEL 2.0 Production Process Audit Stream")

    description =
      Keyword.get(opts, :description, "Immutable IEEE OCEL 2.0 object-centric event stream.")

    publisher = Keyword.get(opts, :publisher, "#{@f5_ns}org/process-intelligence-division")
    issued = Keyword.get(opts, :issued, DateTime.utc_now() |> DateTime.to_iso8601())

    download_url =
      Keyword.get(opts, :download_url, "https://controlplane.fly.dev/api/v1/ocel/stream")

    turtle = """
    @prefix dcat: <#{@dcat_ns}> .
    @prefix dcterms: <#{@dcterms_ns}> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

    <#{catalog_iri}> a dcat:Catalog ;
        dcterms:title "Enterprise Process Intelligence Catalog" ;
        dcat:dataset <#{dataset_iri}> .

    <#{dataset_iri}> a dcat:Dataset ;
        dcterms:title "#{title}" ;
        dcterms:description "#{description}" ;
        dcterms:publisher <#{publisher}> ;
        dcterms:issued "#{issued}"^^xsd:dateTime ;
        dcat:distribution <#{distribution_iri}> .

    <#{distribution_iri}> a dcat:Distribution ;
        dcat:accessURL <#{download_url}> ;
        dcat:mediaType "application/json" ;
        dcterms:format "IEEE-OCEL-2.0" .
    """

    {:ok,
     %{
       catalog_id: catalog_iri,
       dataset_id: dataset_iri,
       distribution_id: distribution_iri,
       turtle: turtle
     }}
  end

  # ---------------------------------------------------------------------------
  # 5. SPDX 3.0 SBOM Package Manifest Generator
  # ---------------------------------------------------------------------------

  @doc "Builds an SPDX 3.0 cryptographic package integrity manifest."
  def build_spdx_manifest(opts \\ []) do
    package_name = Keyword.get(opts, :name, "ex4pm-process-engine")
    version = Keyword.get(opts, :version, "0.1.0")

    files =
      Keyword.get(opts, :files, ["lib/ex4pm_engine/powl.ex", "lib/ex4pm_evidence/conformance.ex"])

    file_entries =
      Enum.map(files, fn file ->
        content = if File.exists?(file), do: File.read!(file), else: file
        hash = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
        %{file: file, hash: hash}
      end)

    batch_content = Enum.map_join(file_entries, "", & &1.hash)
    package_digest = :crypto.hash(:sha256, batch_content) |> Base.encode16(case: :lower)

    turtle = """
    @prefix spdx: <#{@spdx_ns}> .
    @prefix dcterms: <#{@dcterms_ns}> .

    <#{@f5_evidence_ns}spdx/pkg/#{package_name}> a spdx:Package ;
        spdx:name "#{package_name}" ;
        spdx:versionInfo "#{version}" ;
        spdx:checksum [
            a spdx:Checksum ;
            spdx:algorithm spdx:checksumAlgorithm_sha256 ;
            spdx:checksumValue "#{package_digest}"
        ] .
    """

    {:ok,
     %{
       package: package_name,
       version: version,
       digest: package_digest,
       files: file_entries,
       turtle: turtle
     }}
  end

  defp random_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
