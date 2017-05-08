defmodule TableInfoCacheServer.SubSupervisor do
  use Supervisor

  def start_link(table_info_cache_pid) do
    {:ok, _pid} = Supervisor.start_link(__MODULE__, table_info_cache_pid)
  end

  def init(table_info_cache_pid) do
    child_processes = [ worker(TableInfoCacheServer.Server, [table_info_cache_pid]) ]
    supervise child_processes, strategy: :one_for_one
  end
end
