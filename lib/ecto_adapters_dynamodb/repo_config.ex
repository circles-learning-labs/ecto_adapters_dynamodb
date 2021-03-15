defmodule Ecto.Adapters.DynamoDB.RepoConfig do
  alias Confex.Resolver

  def table_in_list?(repo, table, list) do
    repo.config()
    |> Resolver.resolve!()
    |> Keyword.get(list, [])
    |> Enum.member?(table)
  end

  def config_val(repo, key, default \\ nil) do
    repo.config()
    |> Resolver.resolve!()
    |> Keyword.get(key, default)
  end
end
