defmodule Ex4pm.Qualification.ReferenceRailCourt do
  @moduledoc "Executes the five canonical reference rails against exact artifacts."

  alias Ex4pm.Engine.{Beam, Ex4pmPlan, Nif, Remote, Wasm}
  alias Ex4pm.Qualification.Rails

  def run(output_dir) do
    File.mkdir_p!(output_dir)
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    with {:ok, beam} <- beam_result(),
         {:ok, planner} <- planner_result(),
         {:ok, wasm} <- wasm_result(),
         {:ok, nif} <- nif_result(),
         {:ok, remote} <- remote_result(),
         results = [beam, planner, wasm, nif, remote],
         {:ok, verified} <- Rails.verify(results) do
      files = Map.new(results, &write_result(output_dir, &1))
      artifacts = artifact_manifests()

      manifest = %{
        standing: "ALIVE",
        source_sha: subject_sha(),
        rails: jsonify(verified.rails),
        result_files: files,
        artifacts: artifacts,
        differential_groups: [%{operation: "plan", rails: ["ex4pm_plan", "remote"]}]
      }

      File.write!(Path.join(output_dir, "rail-court.json"), Jason.encode!(manifest, pretty: true) <> "\n")
      {:ok, manifest}
    end
  end

  defp beam_result do
    model = %{
      type: :dfg,
      edges: %{{"a", "b"} => %{count: 1, average_duration_ms: 1}},
      starts: %{"a" => 1},
      ends: %{"b" => 1}
    }

    Beam.execute(:simulate, model, max_depth: 4)
  end

  defp planner_result do
    request = json_file!("EX4PM_PLAN_REQUEST")
    response = json_file!("EX4PM_PLAN_RESULT")
    problem = Map.fetch!(request, "problem")
    image_digest = System.fetch_env!("EX4PM_PLAN_IMAGE_DIGEST")

    transport = fn generated_request, _opts ->
      if generated_request != request do
        raise "planner request correspondence mismatch"
      end

      {:ok, response,
       %{
         observed: true,
         source_sha: Ex4pmPlan.source_sha(),
         image_digest: image_digest
       }}
    end

    Ex4pmPlan.execute(:plan, problem, ex4pm_plan_fun: transport)
  end

  defp wasm_result do
    path = System.fetch_env!("EX4PM_REFERENCE_WASM")
    digest = artifact_digest!(path)

    Wasm.execute(:wasm_probe, 21,
      wasm_path: path,
      wasm_digest: "sha256:" <> digest,
      wasm_runtime_identity: System.get_env("EX4PM_WASM_RUNTIME", "wasmex-wasmtime"),
      wasm_contract: %{
        wasm_probe: %{
          export: "qualification_probe",
          params: [21],
          algorithm: :reference_wasm,
          timeout: 5_000
        }
      }
    )
  end

  defp nif_result do
    path = System.fetch_env!("EX4PM_REFERENCE_NIF")
    digest = artifact_digest!(path)
    toolchain = System.get_env("EX4PM_RUST_TOOLCHAIN", "observed-rustc")

    identity = %{
      observed: true,
      source_sha: subject_sha(),
      library_digest: "sha256:" <> digest,
      toolchain: toolchain
    }

    with :ok <- Ex4pm.Qualification.ReferenceNif.load_nif() do
      Nif.execute(:qualification_probe, 21,
        nif_module: Ex4pm.Qualification.ReferenceNif,
        nif_identity: identity,
        nif_digest: "sha256:" <> digest
      )
    end
  end

  defp remote_result do
    request = json_file!("EX4PM_PLAN_REQUEST")
    problem = Map.fetch!(request, "problem")
    url = System.fetch_env!("EX4PM_REMOTE_URL")
    ca = System.fetch_env!("EX4PM_REMOTE_CA")
    artifact_digest = System.fetch_env!("EX4PM_REMOTE_ARTIFACT_DIGEST")

    remote_fun = fn :plan, subject, _opts ->
      with {:ok, payload} <- https_json(url, ca, %{operation: "plan", subject: subject}),
           true <- payload["receipt_verified"] == true,
           result when is_map(result) <- payload["result"] do
        {:ok, result,
         %{
           observed: true,
           transport: :tls,
           source_sha: subject_sha(),
           image_digest: artifact_digest,
           receipt_verified: true
         }}
      else
        other -> {:error, {:invalid_remote_probe, other}}
      end
    end

    Remote.execute(:plan, problem,
      remote_fun: remote_fun,
      remote_image_digest: artifact_digest
    )
  end

  defp https_json(url, ca, payload) do
    body = Jason.encode!(payload)

    ssl = [
      verify: :verify_peer,
      cacertfile: String.to_charlist(ca),
      server_name_indication: ~c"localhost",
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]

    request = {String.to_charlist(url), [], ~c"application/json", body}

    case :httpc.request(:post, request, [ssl: ssl], body_format: :binary) do
      {:ok, {{_version, 200, _reason}, _headers, response}} -> Jason.decode(response)
      {:ok, {{_version, status, _reason}, _headers, response}} -> {:error, {status, response}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp write_result(output_dir, result) do
    engine = to_string(result.engine)
    path = Path.join(output_dir, engine <> ".json")
    File.write!(path, Jason.encode!(serialize_result(result), pretty: true) <> "\n")
    {engine, %{path: path, sha256: artifact_digest!(path)}}
  end

  defp serialize_result(result) do
    %{
      engine: to_string(result.engine),
      operation: to_string(result.operation),
      standing: result.standing |> to_string() |> String.upcase(),
      subject_hash: result.subject_hash,
      value: jsonify(result.value),
      evidence: jsonify(result.evidence)
    }
  end

  defp artifact_manifests do
    %{
      beam: artifact_manifest(beam_artifact()),
      ex4pm_plan: artifact_manifest(System.fetch_env!("EX4PM_PLAN_ARTIFACT")),
      wasm: artifact_manifest(System.fetch_env!("EX4PM_REFERENCE_WASM")),
      nif: artifact_manifest(System.fetch_env!("EX4PM_REFERENCE_NIF")),
      remote: artifact_manifest(System.fetch_env!("EX4PM_REMOTE_ARTIFACT"))
    }
  end

  defp artifact_manifest(path), do: %{path: path, sha256: artifact_digest!(path)}

  defp beam_artifact do
    Ex4pm.Engine.Beam
    |> :code.which()
    |> List.to_string()
  end

  defp artifact_digest!(path) do
    path
    |> File.read!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp json_file!(name) do
    name
    |> System.fetch_env!()
    |> File.read!()
    |> Jason.decode!()
  end

  defp subject_sha, do: System.fetch_env!("EX4PM_SUBJECT_SHA")

  defp jsonify(value) when is_map(value),
    do: Map.new(value, fn {key, nested} -> {to_string(key), jsonify(nested)} end)

  defp jsonify(value) when is_list(value), do: Enum.map(value, &jsonify/1)
  defp jsonify(value) when is_tuple(value), do: value |> Tuple.to_list() |> jsonify()
  defp jsonify(value) when is_atom(value), do: Atom.to_string(value)
  defp jsonify(value), do: value
end
