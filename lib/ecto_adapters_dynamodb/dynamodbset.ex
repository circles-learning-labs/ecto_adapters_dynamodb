defmodule Ecto.Adapters.DynamoDB.DynamoDBSet do
  @moduledoc """
  An Ecto type for handling MapSet, corresponding with DynamoDB's **set** type. Since ExAws already encodes and decodes MapSet, we only handle casting and validation here.
  """

  @behaviour Ecto.Type

  @doc """
  This type is actually a MapSet
  """
  def type, do: MapSet


  @doc """
  Confirm the type is a MapSet and its elements are of one type, number or binary
  """
  def cast(mapset) do
    case mapset do
      %MapSet{} -> if valid?(mapset), do: {:ok, mapset}, else: :error
      _         -> :error
    end
  end

  @doc """
  Load as is
  """
  def load(mapset), do: {:ok, mapset}

  @doc """
  Dump as is
  """
  def dump(mapset), do: {:ok, mapset}

  defp valid?(mapset) do
    Enum.all?(mapset, fn x -> is_number(x) end) or
    Enum.all?(mapset, fn x -> is_binary(x) end)
  end

end
