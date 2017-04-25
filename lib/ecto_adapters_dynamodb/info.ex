defmodule Ecto.Adapters.DynamoDB.Info do
  @moduledoc """
  Get information on dynamo tables and schema 
  """


  @doc """
  Returns the raw amazon dynamo DB table schema information. The raw json is presented as
  and elixir map.

  Here is an example of what it may look like
  %{"Table" => %{"AttributeDefinitions" => [%{"AttributeName" => "id",
       "AttributeType" => "S"},
     %{"AttributeName" => "person_id", "AttributeType" => "S"}],
    "CreationDateTime" => 1489615412.651,
    "GlobalSecondaryIndexes" => [%{"IndexArn" => "arn:aws:dynamodb:ddblocal:000000000000:table/circle_members/index/person_id",
       "IndexName" => "person_id", "IndexSizeBytes" => 7109,
       "IndexStatus" => "ACTIVE", "ItemCount" => 146,
       "KeySchema" => [%{"AttributeName" => "person_id", "KeyType" => "HASH"}],
       "Projection" => %{"ProjectionType" => "ALL"},
       "ProvisionedThroughput" => %{"ReadCapacityUnits" => 100,
         "WriteCapacityUnits" => 50}}], "ItemCount" => 146,
    "KeySchema" => [%{"AttributeName" => "id", "KeyType" => "HASH"},
     %{"AttributeName" => "person_id", "KeyType" => "RANGE"}],
    "ProvisionedThroughput" => %{"LastDecreaseDateTime" => 0.0,
      "LastIncreaseDateTime" => 0.0, "NumberOfDecreasesToday" => 0,
      "ReadCapacityUnits" => 100, "WriteCapacityUnits" => 50},
    "TableArn" => "arn:aws:dynamodb:ddblocal:000000000000:table/circle_members",
    "TableName" => "circle_members", "TableSizeBytes" => 7109,
    "TableStatus" => "ACTIVE"}}  
  """
  def table_info(tablename) do
    # Fetch the raw schema definition from DynamoDB - We should cache this...
    %{"Table" => schema} = ExAws.Dynamo.describe_table(tablename) |> ExAws.request!
    schema
  end


  @doc "Get all the raw information on indexes for a given table, returning as a map."
  def index_details(tablename) do
    # Extract the primary key data (required) and the optional secondary global or local indexes
    %{"KeySchema" => primary_key} = schema = table_info(tablename)
    indexes = Map.get(schema, "GlobalSecondaryIndexes", []) ++ Map.get(schema, "LocalSecondaryIndexes", [])

    # return only the relevant index/key data
    %{:primary => primary_key, :secondary => indexes}
  end


  @doc """
  Get a list of the available indexes on a table. The format of this list is described in 
  """
  def indexes(tablename) do
    [primary_key!(tablename) | secondary_indexes(tablename)]
  end


  @doc """
  Returns the primary key/ID for a table. It may be a single field that is a HASH, OR
  it may be the dynamoDB {HASH, SORT} type of index. we return
  {:primary, [index]}
  in a format described in normalise_dynamo_index
  """
  def primary_key!(tablename) do
    indexes = index_details(tablename)
    {:primary, normalise_dynamo_index!(indexes[:primary])}
  end


  #@doc "return true if this HASH key/{HASH/SORT} key is the table primary key"
  #def primary_key?(tablename, key) do
  #  case primary_key!(tablename) do
  #    {:primary, ^key} -> true
  #    _ -> false
  #  end
  #end


  #@doc "return true is this is a secondary key (HASH/{HASH,SORT}) for the table"
  #def secondary_key?(tablename, key) do
  #  indexes = secondary_indexes(tablename)
  #  Enum.member?(indexes, key)
  #end


  @doc """
  returns a simple list of the secondary indexes (global and local) for the table. Uses same format
  for each member of the list as 'primary_key!'.
  """
  def secondary_indexes(tablename) do
    %{:secondary => indexes} = index_details(tablename)   # Extract the secondary index value from the index_details map
    for index <- indexes, do: {index["IndexName"], normalise_dynamo_index!( index["KeySchema"] )}
  end



  # dynamo raw index data is complex, and can contain either one or two fields along with their type (hash or range)
  # This parses it and returns a simple list format. The first element of the list is the HASH key, the second
  # (optional) is the range/sort key. eg:
  # [hash_field_name, sort_field_name] or [hash_field_name]
  defp normalise_dynamo_index!(index_fields) do
    # The data structure can look a little like these examples:
    #   [%{"AttributeName" => "person_id", "KeyType" => "HASH"}]
    # [%{"AttributeName" => "id", "KeyType" => "HASH"}, %{"AttributeName" => "person_id", "KeyType" => "RANGE"}]
    case index_fields do
      # Just one entry in the fields list; it must be a simple hash.
      [%{"AttributeName" => fieldname}] ->
        [fieldname]

      # Two entries, it's a HASH + SORT - but they might not be returned in order - So figure out 
      # which is the hash and which is the sort by matching for the "HASH" attribute in the first,
      # then second element of the list. Match explicitly as we want a crash if we get anything else.
      [%{"AttributeName" => fieldname_hash, "KeyType" => "HASH"}, %{"AttributeName" => fieldname_sort}] ->
        [fieldname_hash, fieldname_sort]
      [%{"AttributeName" => fieldname_sort}, %{"AttributeName" => fieldname_hash, "KeyType" => "HASH"}] ->
        [fieldname_hash, fieldname_sort]
    end
  end


end
