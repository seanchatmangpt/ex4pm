defmodule Mix.Tasks.Ex4pm.Gen.Blueprint do
  @moduledoc """
  Generates a mathematically sound Ash Resource process blueprint with 1-Safe Workflow Net guarantees.

  Usage:
      mix ex4pm.gen.blueprint ResourceName action1 action2 action3
  """

  use Mix.Task

  @shortdoc "Generates an Ash process resource blueprint"

  @impl Mix.Task
  def run(args) do
    case args do
      [name | [_ | _] = actions] ->
        generate_blueprint(name, actions)

      _ ->
        Mix.shell().error(
          "Usage: mix ex4pm.gen.blueprint ResourceName action1 action2 action3 ..."
        )
    end
  end

  def generate_blueprint(name, actions) do
    module_name = "Ex4pmDomain.#{Macro.camelize(name)}"
    file_name = "apps/ex4pm_domain/lib/ex4pm_domain/#{Macro.underscore(name)}.ex"

    states = Enum.map(actions, &Macro.underscore/1) ++ ["completed"]
    initial_state = List.first(states)

    content = """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      Generated 1-Safe Sound Process Blueprint for #{name}.
      \"\"\"
      use Ash.Resource,
        domain: Ex4pmDomain,
        data_layer: Ash.DataLayer.Ets

      actions do
        defaults [:read, :destroy]

        create :create do
          primary? true
          accept [:title]
          change set_attribute(:state, :#{initial_state})
        end
    #{generate_action_defs(states)}
      end

      attributes do
        uuid_primary_key :id
        attribute :title, :string, allow_nil?: false, public?: true
        attribute :state, :atom, default: :#{initial_state}, public?: true
      end

      def to_workflow_net do
        %{
          places: #{inspect(Enum.map(states, &"p_#{&1}"))},
          transitions: %{
    #{generate_wf_transitions(states)}
          },
          initial_marking: ["p_#{initial_state}"],
          final_marking: ["p_completed"]
        }
      end
    end
    """

    Mix.shell().info("Generated process blueprint: #{file_name}")
    content
  end

  defp generate_action_defs(states) do
    Enum.chunk_every(states, 2, 1, :discard)
    |> Enum.map(fn [from, to] ->
      """
          update :transition_to_#{to} do
            validate attribute_equals(:state, :#{from})
            change set_attribute(:state, :#{to})
          end
      """
    end)
    |> Enum.join("\n")
  end

  defp generate_wf_transitions(states) do
    Enum.chunk_every(states, 2, 1, :discard)
    |> Enum.map(fn [from, to] ->
      "        t_#{from}_to_#{to}: %{inputs: [\"p_#{from}\"], outputs: [\"p_#{to}\"], label: \"#{from}_to_#{to}\"}"
    end)
    |> Enum.join(",\n")
  end
end
