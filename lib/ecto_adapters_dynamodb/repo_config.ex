defmodule Ecto.Adapters.DynamoDB.RepoConfig do
  def table_in_list?(repo, table, list) do
    :ecto_adapters_dynamodb
    |> Confex.get_env(repo)
    |> Keyword.get(list, [])
    |> Enum.member?(table)
  end

  def config_val(repo, key, default \\ nil) do
    :ecto_adapters_dynamodb
    |> Confex.get_env(repo)
    |> Keyword.get(key, default)
  end
end
