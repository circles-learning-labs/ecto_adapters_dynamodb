defmodule Ecto.Adapters.DynamoDB.TableInfoCacheAgent do
  def start_link(initial_cache),
  do: Agent.start_link(fn -> initial_cache end, name: __MODULE__)

  def describe_table(table_name),
  do: Agent.get_and_update(__MODULE__, &do_describe_table(&1, table_name))

  def get_cache,
  do: Agent.get(__MODULE__, &(&1))


  defp do_describe_table(cache, table_name) do
    case cache[table_name] do
      nil ->
        %{"Table" => schema} = ExAws.Dynamo.describe_table(table_name) |> ExAws.request!
        updated_cache = Map.merge(cache, %{table_name => schema})
        { schema, updated_cache }
      schema ->
        { schema, cache }
    end 
  end
end
