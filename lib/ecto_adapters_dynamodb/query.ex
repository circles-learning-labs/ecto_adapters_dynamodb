defmodule Ecto.Adapters.DynamoDB.Query do
  @moduledoc """
  Some query wrapper functions for helping us query dynamo db. Selects indexes to use, etc.
  Not to be confused with Ecto.Query (Should wec rename this module?)

  """

	import Ecto.Adapters.DynamoDB.Info


  # examples:
  #   Ecto.Adapters.DynamoDB.Query.get_item("person", %{ "id" => "person-franko"})
  # 

  def get_item(table, search) do
	
    results = case get_best_index!(table, search) do
      # primary key based lookup  uses the efficient 'get_item' operation
      {:primary, _} = index->
        #https://hexdocs.pm/ex_aws/ExAws.Dynamo.html#get_item/3
        query = construct_search(index, search)
        ExAws.Dynamo.get_item(table, query) |> ExAws.request!

      # secondary index based lookups need the query functionality. 
      index ->
        # https://hexdocs.pm/ex_aws/ExAws.Dynamo.html#query/2
        query = construct_search(index, search)
        ExAws.Dynamo.query(table, query) |> ExAws.request!

    end

    filter(results, search)  # index may have had more fields than the index did, thus results need to be trimmed.
  end



  # we've a list of fields from an index that matches the (some of) the search fields,
  # so construct a dynamo db search criteria map with only the given fields and their
  # search objects!
  def construct_search({:primary, index_fields}, search),  do: construct_search(%{}, index_fields, search)
  def construct_search({index_name, index_fields}, search) do
    criteria = [index_name: index_name]
    criteria ++ case index_fields do
      [hash, range] ->
        [
		  # We need ExpressionAttributeNames when field-names are reserved, for example "name" or "role"
		  expression_attribute_names: %{"##{hash}" => hash, "##{range}" => range},
          expression_attribute_values: [hash_key: search[hash], range: search[range]],
          key_condition_expression: "##{hash} = :hash_key AND ##{range} = :range_key"
        ]

      [hash] ->
        [
		  expression_attribute_names: %{"##{hash}" => hash},
          expression_attribute_values: [hash_key: search[hash]],
          key_condition_expression: "##{hash} = :hash_key"
        ]
      
    end
  end


  defp construct_search(criteria, [], _), do: criteria
  defp construct_search(criteria, [index_field|index_fields], search) do
    Map.put(criteria, index_field, search[index_field]) |> construct_search(index_fields, search)
  end


  # TODO: Given the search criteria, filter out other results that were caught in the
  # index read. TODO: Can we do this on the server side dynamo query instead?
  # see: http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Query.html#DDB-Query-request-FilterExpression
  # note, this doesn't save us read capacity, but DOES reduce the result set and parsing over the wire.
  def filter(results, _search), do: results



  @doc """
  Given a map with a search criteria, finds the best index to search against it.
  Returns a tuple indicating whether it's a primary key index, or a secondary index.
  To query against a secondary index in Dynamo, we NEED to have it's index name,
  so secondary indexes are returned as a tuple with the field name, whilst
  the primary key uses the atom :primary to distinguish it.

    {:primary, [indexed_fields_list]} | {"index_name", [indexed_fields_list]}

  Exception if the index doesn't exist.
  """
  def get_best_index(tablename, search) do
    case get_matching_primary_index(tablename, search) do
      # if we found a primary index with hash+range match, it's probably the best index.
      {:primary, [_hash, _range]} = index -> index

      # we've found a primary hash index, but lets check if there's a more specific
      # secondary index with hash+sort available...
      {:primary, _primary_hash} = index ->
        case get_matching_secondary_index(tablename, search) do
          {_, [_, _]} = sec_index -> sec_index  # we've found a better, more specific index.
          _                       -> index      # :not_found, or any other hash? default back to the primary.
        end

      # no primary found, so try for a secondary.
      :not_found -> get_matching_secondary_index(tablename, search)
    end
  end


  @doc """
  Same as get_best_index, but raises an exception if the index isn't found.
  """
  def get_best_index!(tablename, search) do
    case get_best_index(tablename, search) do
      :not_found -> raise "index_not_found"
      index -> index
    end

  end


  @doc """
  Given a search criteria of 1 or more fields, we try find out if the primary key is a
  good match and can be used to forfill this search. Returns the tuple 
    {:primary, [hash] | [hash, range]}
  or 
    :not_found
  """
  def get_matching_primary_index(tablename, search), do: match_index(primary_key!(tablename), search)


  @doc """
  Given a map containing key values representing a search field and value to search for
  (eg %{id => "franko"}, or %{circle_id => "123", person_id =>"abc"}), will return the
  dynamo db index description that will help us match this search. return :not_found if
  no index is found.

  Returns a tuple of {"index_name", [ hash_key or hash,range_key]]} or :not_found
  TODO: Does not help with range queries. 
  """
  def get_matching_secondary_index(tablename, search) do
    # For each index, see how well it matches the search criteria.
    indexes = secondary_indexes(tablename)
    find_best_match(indexes, search, :not_found)
  end



  defp find_best_match([], _search, best), do: best
  defp find_best_match([index|indexes], search, best) do
    case match_index(index, search) do
      {_, [_,_]} -> index   # Matching on both hash + sort makes this the best index (as well as we can tell)
      {_, [_]}   -> find_best_match(indexes, search, index)   # we have a candidate for best match, though it's a hash key only. Look for better.
      :not_found -> find_best_match(indexes, search, best)    # haven't found anything good, keep looking, retain our previous best match.
    end
  end


  defp match_index(index, search) do
    case index do
      {_, [hash, range]}  ->
        if Map.has_key?(search, hash) and Map.has_key?(search, range), do: index, else: :not_found

      {_, [hash]} ->
        if Map.has_key?(search, hash), do: index, else: :not_found
    end
  end

end
