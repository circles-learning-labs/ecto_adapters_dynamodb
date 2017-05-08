defmodule TableInfoCacheServer do
  use Application

  def start(_type, _args) do
    {:ok, _pid} = TableInfoCacheServer.Supervisor.start_link(Map.new)
  end
end
