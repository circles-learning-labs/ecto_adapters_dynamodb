defmodule Ecto.Adapters.DynamoDB.Cache do
  def start_link do
    cached_table_list = Application.get_env(:ecto_adapters_dynamodb, :cached_tables)
    Agent.start_link(fn -> %{
                       schemas: %{}, 
                       tables: (for table_name <- cached_table_list, into: %{}, do: {table_name, nil})
                     } end, name: __MODULE__)
  end

  def describe_table!(table_name) do
    case describe_table(table_name) do
      {:ok, schema}   -> schema
      {:error, error} -> raise error.type, message: error.message
    end
  end

  def describe_table(table_name),
  do: Agent.get_and_update(__MODULE__, &do_describe_table(&1, table_name))

  def update_table_info!(table_name) do
    case update_table_info(table_name) do
      :ok             -> :ok
      {:error, error} -> raise error.type, message: error.message
    end
  end

  def update_table_info(table_name),
  do: Agent.get_and_update(__MODULE__, &do_update_table_info(&1, table_name))

  def scan!(table_name) do
    case scan(table_name) do
      {:ok, scan_result} -> scan_result
      {:error, error}    -> raise error.type, message: error.message
    end
  end

  def scan(table_name),
  do: Agent.get_and_update(__MODULE__, &do_scan(&1, table_name))

  def update_cached_table!(table_name) do
    case update_cached_table(table_name) do
      :ok             -> :ok
      {:error, error} -> raise error.type, message: error.message
    end
  end

  def update_cached_table(table_name),
  do: Agent.get_and_update(__MODULE__, &do_update_cached_table(&1, table_name))

  def get_cache,
  do: Agent.get(__MODULE__, &(&1))

  defp do_describe_table(cache, table_name) do
    case cache.schemas[table_name] do
      nil ->
        result = ExAws.Dynamo.describe_table(table_name) |> ExAws.request
        case result do 
          {:ok, %{"Table" => schema}} ->
            updated_cache = put_in(cache.schemas[table_name], schema)
            {{:ok, schema}, updated_cache}
          {:error, error} ->
            {{:error, %{type: ExAws.Error, message: "ExAws Request Error! #{inspect error}"}}, cache}
        end
      schema ->
        {{:ok, schema}, cache}
    end 
  end

  defp do_update_table_info(cache, table_name) do
    result = ExAws.Dynamo.describe_table(table_name) |> ExAws.request
    case result do 
      {:ok, %{"Table" => schema}} ->
        updated_cache = put_in(cache.schemas[table_name], schema)
        {:ok, updated_cache}
      {:error, error} ->
        {{:error, %{type: ExAws.Error, message: "ExAws Request Error! #{inspect error}"}}, cache}
    end
  end

  defp do_scan(cache, table_name) do
    table_name_in_config = Map.has_key?(cache.tables, table_name)

    case cache.tables[table_name] do
      nil when table_name_in_config ->
        result = ExAws.Dynamo.scan(table_name) |> ExAws.request
        case result do
          {:ok, scan_result} ->
            updated_cache = put_in(cache.tables[table_name], scan_result)
            {{:ok, scan_result}, updated_cache}
          {:error, error} ->
            {{:error, %{type: ExAws.Error, message: "ExAws Request Error! #{inspect error}"}}, cache}
        end
      nil ->
        {{:error, %{type: ArgumentError, message: "Could not confirm the table, #{inspect table_name}, as listed for caching in the application's configuration. Please see README file for details."}}, cache}
      cached_scan ->
        {{:ok, cached_scan}, cache}
    end 
  end

  defp do_update_cached_table(cache, table_name) do
    table_name_in_config = Map.has_key?(cache.tables, table_name)

    case cache.tables[table_name] do
      nil when not table_name_in_config ->
        {{:error, %{type: ArgumentError, message: "Could not confirm the table, #{inspect table_name}, as listed for caching in the application's configuration. Please see README file for details."}}, cache}
      _ ->
        result = ExAws.Dynamo.scan(table_name) |> ExAws.request
        case result do
          {:ok, scan_result} ->
            updated_cache = put_in(cache.tables[table_name], scan_result)
            {:ok, updated_cache}
          {:error, error} ->
            {{:error, %{type: ExAws.Error, message: "ExAws Request Error! #{inspect error}"}}, cache}
        end
    end 
  end

end
