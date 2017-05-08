defmodule TableInfoCacheServer.Supervisor do
  use Supervisor

  def start_link(initial_table_info_cache) do
    result = {:ok, sup } = Supervisor.start_link(__MODULE__, [initial_table_info_cache])
    start_workers(sup, initial_table_info_cache)
    result
  end

  def start_workers(sup, initial_table_info_cache) do
    # Start the cache worker
    {:ok, table_info_cache_pid} =
      Supervisor.start_child(sup, worker(TableInfoCacheServer.TableInfoCache, [initial_table_info_cache]))
    # and then the subsupervisor for the actual cache server
    Supervisor.start_child(sup, supervisor(TableInfoCacheServer.SubSupervisor, [table_info_cache_pid]))
  end

  def init(_) do
    supervise [], strategy: :one_for_one
  end
end
