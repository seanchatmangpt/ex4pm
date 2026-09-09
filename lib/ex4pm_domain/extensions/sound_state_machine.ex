defmodule Ex4pmDomain.Extensions.SoundStateMachine do
  @moduledoc """
  Spark DSL Extension enforcing mathematical 1-Safe Soundness on Ash State Machine Resources.
  """
  use Spark.Dsl.Extension,
    verifiers: [Ex4pmDomain.Verifiers.VerifySoundness]
end
