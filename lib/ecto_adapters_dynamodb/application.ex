defmodule Ecto.Adapters.DynamoDB.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # Define workers and child supervisors to be supervised
    children = [
      Ecto.Adapters.DynamoDB.QueryInfo
    ]

    opts = [strategy: :one_for_one, name: Ecto.Adapters.DynamoDB.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
