defmodule Ecto.Adapters.DynamoDB.Integration.ExAws.Dynamo.Test do
  @moduledoc """
  Integration tests for ExAws.Dynamo.
  """

  use ExUnit.Case

  alias Ecto.Adapters.DynamoDB
  alias Ecto.Adapters.DynamoDB.TestRepo
  alias ExAws.Dynamo

  @ex_aws_dynamo_test_table_name "ex_aws_dynamo_test_table"

  test "create_table" do
    Dynamo.create_table(
      @ex_aws_dynamo_test_table_name,
      [email: :hash, age: :range],
      [email: :string, age: :number],
      1,
      1
    )
    |> request!()

    {:ok, table_info} = ExAws.Dynamo.describe_table(@ex_aws_dynamo_test_table_name) |> request()

    assert table_info["Table"]["TableName"] == @ex_aws_dynamo_test_table_name
  end

  test "update_table" do
    Dynamo.update_table(@ex_aws_dynamo_test_table_name, billing_mode: :pay_per_request)
    |> request!()

    {:ok, table_info} = ExAws.Dynamo.describe_table(@ex_aws_dynamo_test_table_name) |> request()

    assert table_info["Table"]["BillingModeSummary"]["BillingMode"] == "PAY_PER_REQUEST"
  end

  test "delete_table" do
    result = Dynamo.delete_table(@ex_aws_dynamo_test_table_name) |> request!()

    assert result["TableDescription"]["TableName"] == @ex_aws_dynamo_test_table_name
  end

  test "Decoder.decode()" do
    assert Dynamo.Decoder.decode(%{"BOOL" => true}) == true
    assert Dynamo.Decoder.decode(%{"BOOL" => false}) == false
    assert Dynamo.Decoder.decode(%{"BOOL" => "true"}) == true
    assert Dynamo.Decoder.decode(%{"BOOL" => "false"}) == false
    assert Dynamo.Decoder.decode(%{"NULL" => true}) == nil
    assert Dynamo.Decoder.decode(%{"NULL" => "true"}) == nil
    assert Dynamo.Decoder.decode(%{"B" => "Zm9vYmFy"}) == "foobar"
    assert Dynamo.Decoder.decode(%{"S" => "foo"}) == "foo"
    assert Dynamo.Decoder.decode(%{"M" => %{"M" => %{foo: %{"S" => "bar"}}}}) == %{foo: "bar"}

    assert Dynamo.Decoder.decode(%{"BS" => ["U3Vubnk=", "UmFpbnk=", "U25vd3k="]}) ==
             MapSet.new(["U3Vubnk=", "UmFpbnk=", "U25vd3k="])

    assert Dynamo.Decoder.decode(%{"SS" => ["foo", "bar", "baz"]}) ==
             MapSet.new(["foo", "bar", "baz"])

    assert Dynamo.Decoder.decode(%{"NS" => [1, 2, 3]}) == MapSet.new([1, 2, 3])
    assert Dynamo.Decoder.decode(%{"NS" => ["1", "2", "3"]}) == MapSet.new([1, 2, 3])
    assert Dynamo.Decoder.decode(%{"L" => [%{"S" => "asdf"}, %{"N" => "1"}]}) == ["asdf", 1]
  end

  defp request(request), do: ExAws.request(request, DynamoDB.ex_aws_config(TestRepo))
  defp request!(request), do: ExAws.request!(request, DynamoDB.ex_aws_config(TestRepo))
end
