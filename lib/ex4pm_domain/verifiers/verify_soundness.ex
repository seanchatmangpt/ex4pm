defmodule Ex4pmDomain.Verifiers.VerifySoundness do
  @moduledoc """
  Spark DSL Verifier enforcing mathematical 1-Safe Soundness on Ash state machine resources at compile-time.

  If an Ash resource defines `to_workflow_net/0`, this verifier compiles the reachability graph
  and proves:
  1. Option to complete (liveness)
  2. Proper completion (no lingering tokens in sink place)
  3. No dead transitions (fireability)
  4. 1-Safety (no place contains > 1 token)

  If any invariant fails, compilation immediately halts with a `Spark.Error.DslError`.
  """

  use Spark.Dsl.Verifier

  alias Ex4pmEngine.SoundnessProver

  @impl Spark.Dsl.Verifier
  def verify(dsl_state) do
    module = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)

    if function_exported?(module, :to_workflow_net, 0) do
      net = apply(module, :to_workflow_net, [])
      report = SoundnessProver.verify_soundness(net)

      if report.sound? do
        :ok
      else
        {:error,
         Spark.Error.DslError.exception(
           module: module,
           path: [:actions],
           message:
             "State machine is mathematically unsound! Counterexamples: #{inspect(report.counterexamples)}"
         )}
      end
    else
      :ok
    end
  end
end
