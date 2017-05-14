defmodule Ecto.Adapters.DynamoDB.Cache do
  def start_link do
    cached_table_list = Application.get_env(:ecto_adapters_dynamodb, :cached_tables) || []
    Agent.start_link(fn -> %{
                       schemas: %{}, 
                       tables: (for table_name <- cached_table_list, into: %{}, do: {table_name, nil})
                     } end, name: __MODULE__)
  end

  def describe_table(table_name),
  do: Agent.get_and_update(__MODULE__, &do_describe_table(&1, table_name))

  def scan(table_name),
  do: Agent.get_and_update(__MODULE__, &do_scan(&1, table_name))

  def get_cache,
  do: Agent.get(__MODULE__, &(&1))

  defp do_describe_table(cache, table_name) do
    case cache.schemas[table_name] do
      nil ->
        %{"Table" => schema} = ExAws.Dynamo.describe_table(table_name) |> ExAws.request!
        updated_cache = put_in(cache.schemas[table_name], schema)
        { schema, updated_cache }
      schema ->
        { schema, cache }
    end 
  end

  defp do_scan(cache, table_name) do
    table_name_in_config = Map.has_key?(cache.tables, table_name)

    case cache.tables[table_name] do
      nil when table_name_in_config ->
        scan_result = ExAws.Dynamo.scan(table_name) |> ExAws.request!
        updated_cache = put_in(cache.tables[table_name], scan_result)
        { scan_result, updated_cache }
      scan_result ->
        { scan_result, cache }
    end 
  end
end
