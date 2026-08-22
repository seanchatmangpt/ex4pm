defmodule Ex4pmWeb.OcelController do
  use Ex4pmWeb, :controller

  alias Ex4pm.Domain.Projector
  alias Ex4pm.Refusal
  alias Ex4pm.Stream.Ingest

  def ingest(conn, params) do
    broadcaster = fn %{log: log, envelope: envelope} ->
      # Project into domain
      Projector.project_log(log)

      # Broadcast over PubSub for real-time LiveView listeners
      Phoenix.PubSub.broadcast(
        Ex4pmWeb.PubSub,
        "process_intelligence:live",
        {:ocel_ingested, envelope}
      )
    end

    case Ingest.ingest_envelope(params, broadcaster: broadcaster) do
      {:ok, result} ->
        conn
        |> put_status(:created)
        |> json(%{
          status: "success",
          data: result
        })

      {:error, %Refusal{} = refusal} ->
        # Project refusal into domain
        Projector.refusal(refusal)

        # Broadcast refusal to LiveView
        Phoenix.PubSub.broadcast(
          Ex4pmWeb.PubSub,
          "process_intelligence:live",
          {:refusal_emitted, refusal}
        )

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          status: "refused",
          standing: :refused,
          error: %{
            code: refusal.code,
            message: refusal.message,
            details: refusal.details
          }
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          status: "error",
          error: inspect(reason)
        })
    end
  end
end
