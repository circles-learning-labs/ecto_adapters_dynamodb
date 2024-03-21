defmodule Ecto.Adapters.DynamoDB.Info.Test do
  @moduledoc """
  Unit tests for Ecto.Adapters.DynamoDB.Info
  """

  use ExUnit.Case

  import Ecto.Adapters.DynamoDB.Info

  alias Ecto.Adapters.DynamoDB.TestRepo

  setup_all do
    TestHelper.setup_all()

    on_exit(fn ->
      TestHelper.on_exit()
    end)
  end

  test "table_info" do
    info = normalise_info(table_info(TestRepo, "test_planet"))

    assert normalise_info(%{
             "AttributeDefinitions" => [
               %{"AttributeName" => "id", "AttributeType" => "S"},
               %{"AttributeName" => "mass", "AttributeType" => "N"},
               %{"AttributeName" => "name", "AttributeType" => "S"}
             ],
             "CreationDateTime" => info["CreationDateTime"],
             "DeletionProtectionEnabled" => false,
             "GlobalSecondaryIndexes" => [
               %{
                 "IndexArn" =>
                   "arn:aws:dynamodb:ddblocal:000000000000:table/test_planet/index/name_mass",
                 "IndexName" => "name_mass",
                 "IndexSizeBytes" => 0,
                 "IndexStatus" => "ACTIVE",
                 "ItemCount" => 0,
                 "KeySchema" => [
                   %{"AttributeName" => "name", "KeyType" => "HASH"},
                   %{"AttributeName" => "mass", "KeyType" => "RANGE"}
                 ],
                 "Projection" => %{"ProjectionType" => "ALL"},
                 "ProvisionedThroughput" => %{
                   "ReadCapacityUnits" => 100,
                   "WriteCapacityUnits" => 100
                 }
               }
             ],
             "ItemCount" => 0,
             "KeySchema" => [
               %{"AttributeName" => "id", "KeyType" => "HASH"},
               %{"AttributeName" => "name", "KeyType" => "RANGE"}
             ],
             "ProvisionedThroughput" => %{
               "LastDecreaseDateTime" => 0.0,
               "LastIncreaseDateTime" => 0.0,
               "NumberOfDecreasesToday" => 0,
               "ReadCapacityUnits" => 100,
               "WriteCapacityUnits" => 100
             },
             "TableArn" => "arn:aws:dynamodb:ddblocal:000000000000:table/test_planet",
             "TableName" => "test_planet",
             "TableSizeBytes" => 0,
             "TableStatus" => "ACTIVE"
           }) == info
  end

  test "index_details" do
    info = normalise_info(index_details(TestRepo, "test_person"))

    assert normalise_info(%{
             primary: [%{"AttributeName" => "id", "KeyType" => "HASH"}],
             secondary: [
               %{
                 "IndexArn" =>
                   "arn:aws:dynamodb:ddblocal:000000000000:table/test_person/index/first_name_age",
                 "IndexName" => "first_name_age",
                 "IndexSizeBytes" => 0,
                 "IndexStatus" => "ACTIVE",
                 "ItemCount" => 0,
                 "KeySchema" => [
                   %{"AttributeName" => "first_name", "KeyType" => "HASH"},
                   %{"AttributeName" => "age", "KeyType" => "RANGE"}
                 ],
                 "Projection" => %{"ProjectionType" => "ALL"},
                 "ProvisionedThroughput" => %{
                   "ReadCapacityUnits" => 100,
                   "WriteCapacityUnits" => 100
                 }
               },
               %{
                 "IndexArn" =>
                   "arn:aws:dynamodb:ddblocal:000000000000:table/test_person/index/age_first_name",
                 "IndexName" => "age_first_name",
                 "IndexSizeBytes" => 0,
                 "IndexStatus" => "ACTIVE",
                 "ItemCount" => 0,
                 "KeySchema" => [
                   %{"AttributeName" => "age", "KeyType" => "HASH"},
                   %{"AttributeName" => "first_name", "KeyType" => "RANGE"}
                 ],
                 "Projection" => %{"ProjectionType" => "ALL"},
                 "ProvisionedThroughput" => %{
                   "ReadCapacityUnits" => 100,
                   "WriteCapacityUnits" => 100
                 }
               },
               %{
                 "IndexArn" =>
                   "arn:aws:dynamodb:ddblocal:000000000000:table/test_person/index/first_name",
                 "IndexName" => "first_name",
                 "IndexSizeBytes" => 0,
                 "IndexStatus" => "ACTIVE",
                 "ItemCount" => 0,
                 "KeySchema" => [%{"AttributeName" => "first_name", "KeyType" => "HASH"}],
                 "Projection" => %{"ProjectionType" => "ALL"},
                 "ProvisionedThroughput" => %{
                   "ReadCapacityUnits" => 100,
                   "WriteCapacityUnits" => 100
                 }
               },
               %{
                 "IndexArn" =>
                   "arn:aws:dynamodb:ddblocal:000000000000:table/test_person/index/first_name_email",
                 "IndexName" => "first_name_email",
                 "IndexSizeBytes" => 0,
                 "IndexStatus" => "ACTIVE",
                 "ItemCount" => 0,
                 "KeySchema" => [
                   %{"AttributeName" => "first_name", "KeyType" => "HASH"},
                   %{"AttributeName" => "email", "KeyType" => "RANGE"}
                 ],
                 "Projection" => %{"ProjectionType" => "ALL"},
                 "ProvisionedThroughput" => %{
                   "ReadCapacityUnits" => 100,
                   "WriteCapacityUnits" => 100
                 }
               },
               %{
                 "IndexArn" =>
                   "arn:aws:dynamodb:ddblocal:000000000000:table/test_person/index/email",
                 "IndexName" => "email",
                 "IndexSizeBytes" => 0,
                 "IndexStatus" => "ACTIVE",
                 "ItemCount" => 0,
                 "KeySchema" => [%{"AttributeName" => "email", "KeyType" => "HASH"}],
                 "Projection" => %{"ProjectionType" => "ALL"},
                 "ProvisionedThroughput" => %{
                   "ReadCapacityUnits" => 100,
                   "WriteCapacityUnits" => 100
                 }
               }
             ]
           }) == info
  end

  test "indexes" do
    assert indexes(TestRepo, "test_person") == [
             {:primary, ["id"]},
             {"first_name_age", ["first_name", "age"]},
             {"age_first_name", ["age", "first_name"]},
             {"first_name", ["first_name"]},
             {"first_name_email", ["first_name", "email"]},
             {"email", ["email"]}
           ]
  end

  test "primary_key!" do
    assert primary_key!(TestRepo, "test_planet") == {:primary, ["id", "name"]}
  end

  test "repo_primary_key" do
    assert repo_primary_key(Ecto.Adapters.DynamoDB.TestSchema.Person) == "id"

    assert_raise ArgumentError,
                 "DynamoDB repos must have a single primary key, but repo Elixir.Ecto.Adapters.DynamoDB.TestSchema.BookPage has more than one",
                 fn ->
                   repo_primary_key(Ecto.Adapters.DynamoDB.TestSchema.BookPage)
                 end
  end

  test "secondary_indexes" do
    assert secondary_indexes(TestRepo, "test_person") == [
             {"first_name_age", ["first_name", "age"]},
             {"age_first_name", ["age", "first_name"]},
             {"first_name", ["first_name"]},
             {"first_name_email", ["first_name", "email"]},
             {"email", ["email"]}
           ]
  end

  test "indexed_attributes" do
    assert indexed_attributes(TestRepo, "test_planet") == ["id", "name", "mass"]
  end

  defp normalise_info(info) when is_map(info) do
    info
    |> Enum.map(fn {k, v} -> {k, normalise_info(v)} end)
    |> Map.new()
  end

  defp normalise_info(info) when is_list(info) do
    info
    |> Enum.map(&normalise_info/1)
    |> Enum.sort()
  end

  defp normalise_info(info), do: info
end
