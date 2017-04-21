defmodule Ecto.Adapters.DynamoDB.Info do
  @moduledoc """
  Get information on dynamo tables and schema 
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
  Get a list containing the names of the fields that have an index on them. In dynamo DB, some of these
  indexes may be made up of two fields: HASH + SORT(range) keys. In this case, a tuple is returned
  describing the index - {HASH_KEY, RANGE_KEY}. Primary key is always the first element in this
  """
  def indexes(tablename) do
    raw_indexes = index_details(tablename)
    indexes = []

    # Prepand the primary index to the secondary, and return it.
    #[ raw_indexes[:primary]: primary| indexes]
  end


  @doc """
  Returns the primary key/ID for a table. It may be a single field that is a HASH, OR
  it may be the dynamoDB {HASH, SORT} type of index. A single field name is returned if it's
  a single HASH value, or a tuple is returned if it's HASH + INDEX
  """
  def primary_key!(tablename) do
    indexes = index_details(tablename)
    normalise_dynamo_index!(indexes[:primary])
  end


  @doc "return true if this HASH key/{HASH/SORT} key is the table primary key"
  def primary_key?(tablename, key) do
    case primary_key!(tablename) do
      ^key -> true
      _ -> false
    end
  end


  @doc "return true is this is a secondary key (HASH/{HASH,SORT}) for the table"
  def secondary_key?(tablename, key) do
    indexes = secondary_indexes(tablename)
    Enum.member?(indexes, key)
  end


  @doc """
  returns a simple list of the secondary indexes (global and local) for the table. Uses same format
  for each member of the list as 'primary_key!'.
  """
  def secondary_indexes(tablename) do
    %{:secondary => indexes} = index_details(tablename)
    for index <- indexes, do: normalise_dynamo_index!( index["KeySchema"] )
  end


  @doc """
  Given a map with a search criteria, finds the best index to search against it.
  Returns a tuple indicating whether it's a primary key index, or a secondaray index.
  (Since we need to know for dynamo DB searches.)

  {:primary, index} | {:secondary, index}

  Exception if the index doesn't exist.
  """
  def get_best_index!(tablename, search) do
    case get_matching_primary_index(tablename, search) do
      [hash, range] ->
        # if we found a primary index with hash+range match, it's probably the best index.
        {:primary, [hash, range]}

      [] ->
        # no primary found, so try for a secondary.
        # no case match exception will be triggered if none is found.
        case get_matching_secondary_index(tablename, search) do
          [hash, range] -> {:secondary, [hash, range]}
          [hash]      -> {:secondary, [hash]}
        end

      primary_hash ->
        # we've found a primary hash index, but lets check if there's a more specific
        # secondary index with hash+sort available...
        case get_matching_secondary_index(tablename, search) do
          [hash, range] -> {:secondary, [hash, range]}
          _           -> {:primary, [primary_hash]}
        end
    end
  end


  def get_matching_primary_index(tablename, search) do
    case primary_key!(tablename) do
      [hash, range] ->
        if Map.has_key?(search, hash) and Map.has_key(search, range), do: [hash, range], else: []

      [hash] ->
        if Map.has_key?(search, hash), do: [hash], else: []
    end

  end

  @doc """
  Given a map containing key values representing a search field and value to search for
  (eg %{id => "franko"}, or %{circle_id => "123", person_id =>"abc"}), will return the
  dynamo db index description that will help us match this search. Fire exception
  if there is no matching index we can use.
  Does not help with range queries.
  """
  def get_matching_secondary_index(tablename, search) do
    for {k, v} <- search do

    end
  end

  # dynamo raw index data is complex, and can contain either one or two fields. This just takes that
  # list of one or two fields and turns it in to a proplist. if index has just a hash key, it's {field, true}.
  # if it's a hash + range, it's {HASH_field, RANGE_field}
  defp normalise_dynamo_index!(index_fields) do
    # The data structure can look a little like these examples:
    #   [%{"AttributeName" => "person_id", "KeyType" => "HASH"}]
    # [%{"AttributeName" => "id", "KeyType" => "HASH"}, %{"AttributeName" => "person_id", "KeyType" => "RANGE"}]
    case index_fields do
      # Just one entry in the fields list; it must be a simple range.
      [%{"AttributeName" => fieldname}] ->
        fieldname

      # Two entries, it's a HASH + SORT - but they might not be returned in order - So figure out 
      # which is the hash and which is the sort by matching for the "HASH" attribute in the first,
      # then second element of the list. Match explicitly as we want a crash if we get anything else.
      [%{"AttributeName" => fieldname_hash, "KeyType" => "HASH"}, %{"AttributeName" => fieldname_sort}] ->
        {fieldname_hash, fieldname_sort}
      [%{"AttributeName" => fieldname_sort}, %{"AttributeName" => fieldname_hash, "KeyType" => "HASH"}] ->
        {fieldname_hash, fieldname_sort}
    end
  end


end
