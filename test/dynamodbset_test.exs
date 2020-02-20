defmodule Ecto.Adapters.DynamoDBSet.Test do
  @moduledoc """
  Unit tests for Ecto.Adapters.DynamoDB.DynamoDBSet
  """

  use ExUnit.Case

  import Ecto.Adapters.DynamoDB.DynamoDBSet

  test "type/0" do
    assert type() == MapSet
  end

  test "cast/1" do
    valid_mapset = MapSet.new([1, 2, 3])
    invalid_mapset = MapSet.new([1, 2, :foo])

    assert cast(valid_mapset) == {:ok, valid_mapset}
    assert cast(invalid_mapset) == :error
    assert cast(%{foo: :bar}) == :error
  end

  test "load/1" do
    mapset = MapSet.new([1, 2, 3])

    assert load(mapset) == {:ok, mapset}
  end

  test "dump/1" do
    mapset = MapSet.new([1, 2, 3])

    assert dump(mapset) == {:ok, mapset}
  end

  test "equal?/2" do
    mapset_a = MapSet.new([1, 2, 3])
    mapset_b = MapSet.new([1, 2, 3])
    mapset_c = MapSet.new([:a, :b, :c])

    assert equal?(mapset_a, mapset_b)
    refute equal?(mapset_b, mapset_c)
  end

  test "embed_as/1" do
    assert embed_as(MapSet) == :self
    assert embed_as(List) == :dump
  end
end
