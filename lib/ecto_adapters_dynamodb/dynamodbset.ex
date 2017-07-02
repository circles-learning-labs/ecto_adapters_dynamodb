defmodule Ecto.Adapters.DynamoDB.DynamoDBSet do
  @behaviour Ecto.Type
  def type, do: MapSet

  def cast(mapset) do
    case mapset do
      %MapSet{} -> if valid?(mapset), do: {:ok, mapset}, else: :error
      _         -> :error
    end
  end

  def load(mapset), do: {:ok, mapset}
  def dump(mapset), do: {:ok, mapset}

  defp valid?(mapset) do
    Enum.all?(mapset, fn x -> is_number(x) end) or
    Enum.all?(mapset, fn x -> is_binary(x) end)
  end

end
