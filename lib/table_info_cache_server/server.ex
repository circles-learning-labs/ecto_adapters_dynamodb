defmodule TableInfoCacheServer.Server do
  use GenServer

  alias ExAws.Dynamo

  #####
  # External API

  def start_link(table_info_cache_pid) do
    {:ok, _pid} = GenServer.start_link(__MODULE__, table_info_cache_pid, name: __MODULE__)
  end

  def describe_table(table_name) do
    GenServer.call __MODULE__, {:describe_table, table_name}
  end

  def get_cache do
    GenServer.call __MODULE__, :get_cache
  end


  #####
  # GenServer implementation

  def init(table_info_cache_pid) do
    current_table_info_cache = TableInfoCacheServer.TableInfoCache.get_table_info_cache(table_info_cache_pid)
    { :ok, {current_table_info_cache, table_info_cache_pid} }
  end

  def handle_call({:describe_table, table_name}, _from, {current_table_info_cache, table_info_cache_pid}) do
    case current_table_info_cache[table_name] do
      nil ->
        %{"Table" => schema} = Dynamo.describe_table(table_name) |> ExAws.request!
        updated_table_info_cache = Map.merge(current_table_info_cache, %{table_name => schema})
        { :reply, schema, {updated_table_info_cache, table_info_cache_pid} }
      schema -> 
        { :reply, schema, {current_table_info_cache, table_info_cache_pid} }
    end
  end

  def handle_call(:get_cache, _from, {current_table_info_cache, table_info_cache_pid}) do
    { :reply, current_table_info_cache, {current_table_info_cache, table_info_cache_pid} }
  end

  def terminate(_reason, {current_table_info_cache, table_info_cache_pid}) do
    TableInfoCacheServer.TableInfoCache.save_table_info_cache(table_info_cache_pid, current_table_info_cache)
  end
end
