defmodule Ecto.Adapters.DynamoDB.DynamoDBSet do
  @moduledoc """
  An Ecto type for handling MapSet, corresponding with DynamoDB's **set** type. Since ExAws already encodes and decodes MapSet, we only handle casting and validation here.
  """

  @behaviour Ecto.Type

  @doc """
  This type is actually a MapSet
  """
  @impl Ecto.Type
  def type, do: MapSet

  @doc """
  Confirm the type is a MapSet and its elements are of one type, number or binary
  """
  @impl Ecto.Type
  def cast(mapset) do
    case mapset do
      %MapSet{} -> if valid?(mapset), do: {:ok, mapset}, else: :error
      _         -> :error
    end
  end

  @doc """
  Load as is
  """
  @impl Ecto.Type
  def load(mapset), do: {:ok, mapset}

  @doc """
  Dump as is
  """
  @impl Ecto.Type
  def dump(mapset), do: {:ok, mapset}

  @doc """
  Check if two terms are semantically equal
  """
  @impl Ecto.Type
  def equal?(term_a, term_b), do: MapSet.equal?(term_a, term_b)

  @doc """
  Dictates how the type should be treated inside embeds
  """
  @impl Ecto.Type
  def embed_as(MapSet), do: :self
  def embed_as(_), do: :dump

  defp valid?(mapset) do
    Enum.all?(mapset, fn x -> is_number(x) end) or
    Enum.all?(mapset, fn x -> is_binary(x) end)
  end

end
