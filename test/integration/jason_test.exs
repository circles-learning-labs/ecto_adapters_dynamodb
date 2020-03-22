defmodule Ecto.Adapters.DynamoDB.Integration.Jason.Test do
  @moduledoc """
  Integration tests for Jason.
  """

  use ExUnit.Case

  test "encode" do
    assert Jason.encode(%{foo: "bar"}) == {:ok, "{\"foo\":\"bar\"}"}
  end
end
