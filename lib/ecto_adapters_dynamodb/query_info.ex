defmodule Ecto.Adapters.DynamoDB.QueryInfo do
  def start_link, do: Agent.start_link(fn -> %{} end, name: __MODULE__)

  def get_key, do: :crypto.strong_rand_bytes(32) |> Base.url_encode64

  def put(key, val), do: Agent.update(__MODULE__, fn map -> Map.put(map, key, val) end)

  def get(key), do: Agent.get_and_update(__MODULE__, fn map -> {map[key], Map.delete(map, key)} end)

  def get_map, do: Agent.get(__MODULE__, fn map -> map end)

end
