defmodule TableInfoCacheServer.TableInfoCache do
  use GenServer

  #####
  # External API

  def start_link(current_table_info_cache) do
    {:ok, _pid} = GenServer.start_link( __MODULE__, current_table_info_cache)
  end

  def save_table_info_cache(pid, new_table_info_cache) do
    GenServer.cast pid, {:save_table_info_cache, new_table_info_cache}
  end

  def get_table_info_cache(pid) do
    GenServer.call pid, :get_table_info_cache
  end

  #####
  # GenServer implementation

  def handle_call(:get_table_info_cache, _from, current_table_info_cache) do 
    { :reply, current_table_info_cache, current_table_info_cache }
  end

  def handle_cast({:save_table_info_cache, new_table_info_cache}, _current_table_info_cache) do
    { :noreply, new_table_info_cache}
  end
end
