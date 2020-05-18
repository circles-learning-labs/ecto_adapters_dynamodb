defmodule Ecto.Adapters.DynamoDB.Info.Test do
  @moduledoc """
  Unit tests for Ecto.Adapters.DynamoDB.Info
  """

  use ExUnit.Case

  import import Ecto.Adapters.DynamoDB.Info

  test "table_info" do
    assert %{
             "AttributeDefinitions" => [
               %{"AttributeName" => "id", "AttributeType" => "S"},
               %{"AttributeName" => "mass", "AttributeType" => "N"},
               %{"AttributeName" => "name", "AttributeType" => "S"}
             ],
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
             "TableStatus" => "ACTIVE"
           } = table_info("test_planet")
  end

  test "index_details" do
    assert %{
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
           } = index_details("test_person")
  end

  test "indexes" do
    assert indexes("test_person") == [
             {:primary, ["id"]},
             {"first_name_age", ["first_name", "age"]},
             {"age_first_name", ["age", "first_name"]},
             {"first_name", ["first_name"]},
             {"first_name_email", ["first_name", "email"]},
             {"email", ["email"]}
           ]
  end

  test "primary_key!" do
    assert primary_key!("test_planet") == {:primary, ["id", "name"]}
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
    assert secondary_indexes("test_person") == [
             {"first_name_age", ["first_name", "age"]},
             {"age_first_name", ["age", "first_name"]},
             {"first_name", ["first_name"]},
             {"first_name_email", ["first_name", "email"]},
             {"email", ["email"]}
           ]
  end

  test "indexed_attributes" do
    assert indexed_attributes("test_planet") == ["id", "name", "mass"]
  end
end
