defmodule Ecto.Adapters.DynamoDB.Integration.Test do
  @moduledoc """
  Integration tests.
  """
  use ExUnit.Case
  alias ExAws.Dynamo

  @ex_aws_dynamo_test_table_name "ex_aws_dynamo_test_table"

  setup_all do
    TestHelper.setup_all()
  end

  describe "Integration tests for ExAws.Dynamo" do
    test "create_table" do
      Dynamo.create_table(@ex_aws_dynamo_test_table_name, [email: :hash, age: :range], [email: :string, age: :number], 1, 1) |> ExAws.request!
      {:ok, table_info} = ExAws.Dynamo.describe_table(@ex_aws_dynamo_test_table_name) |> ExAws.request()

      assert table_info["Table"]["TableName"] == @ex_aws_dynamo_test_table_name
      assert table_info["Table"]["BillingModeSummary"]["BillingMode"] == "PROVISIONED"
    end

    test "update_table" do
      Dynamo.update_table(@ex_aws_dynamo_test_table_name, [billing_mode: :pay_per_request]) |> ExAws.request!
      {:ok, table_info} = ExAws.Dynamo.describe_table(@ex_aws_dynamo_test_table_name) |> ExAws.request()

      assert table_info["Table"]["BillingModeSummary"]["BillingMode"] == "PAY_PER_REQUEST"
    end

    test "delete_table" do
      result = Dynamo.delete_table(@ex_aws_dynamo_test_table_name) |> ExAws.request!

      assert result["TableDescription"]["TableName"] == @ex_aws_dynamo_test_table_name
    end
  end
  
end
