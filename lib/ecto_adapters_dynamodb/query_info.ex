defmodule Ecto.Adapters.DynamoDB.QueryInfo do
  @moduledoc """
  An Elixir agent to optionally record DynamoDB query information (like LastEvaluatedKey) that's not part of expected Ecto return values.
  """

  def start_link, do: Agent.start_link(fn -> %{} end, name: __MODULE__)

  @doc """
  Provides a random 32 character, base 64 encoded string.
  """
  def get_key, do: :crypto.strong_rand_bytes(32) |> Base.url_encode64

  @doc """
  Updates the value of a given key in the Agent map.
  """
  def put(key, val), do: Agent.update(__MODULE__, fn map -> Map.put(map, key, val) end)

  @doc """
  Updates the value of a given key in the Agent map by appending values to an accumulating list.
  """
  def put_in_list(key, val) do
    current_val = get(key)

    if current_val do
      Agent.update(__MODULE__, fn map -> Map.put(map, key, current_val ++ [val]) end)
    else
      put(key, [val])
    end
  end

  @doc """
  Returns the value (query info) in the QueryInfo agent associated with the provided key.
  """
  def get(key), do: Agent.get_and_update(__MODULE__, fn map -> {map[key], Map.delete(map, key)} end)

  @doc """
  Returns the complete current map recorded by the agent.
  """
  def get_map, do: Agent.get(__MODULE__, fn map -> map end)

end
