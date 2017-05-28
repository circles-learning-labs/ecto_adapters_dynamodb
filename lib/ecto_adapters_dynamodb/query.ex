defmodule Ecto.Adapters.DynamoDB.Query do
  @moduledoc """
  Some query wrapper functions for helping us query dynamo db. Selects indexes to use, etc.
  Not to be confused with Ecto.Query (Should wec rename this module?)

  """

  import Ecto.Adapters.DynamoDB.Info


  # parameters for get_item: TABLE_NAME::string, %{ATTRIBUTE::string => {VALUE::string, OPERATOR::atom}}
  # examples:
  #   Ecto.Adapters.DynamoDB.Query.get_item("person", %{ "id" => {"person-franko", :==}})
  # 

  # Repo.all(model), provide cached results for tables designated in :cached_tables
  def get_item(table, search) when search == %{} do
    Ecto.Adapters.DynamoDB.Cache.scan!(table)
  end

  # Regular queries
  def get_item(table, search) do

    results = case get_best_index!(table, search) do
      # primary key based lookup  uses the efficient 'get_item' operation
      {:primary, _} = index->
        #https://hexdocs.pm/ex_aws/ExAws.Dynamo.html#get_item/3
        query = construct_search(index, table, search)
        ExAws.Dynamo.get_item(table, query) |> ExAws.request!

      # secondary index based lookups need the query functionality. 
      index ->
        # https://hexdocs.pm/ex_aws/ExAws.Dynamo.html#query/2
        query = construct_search(index, table, search)
        ExAws.Dynamo.query(table, query) |> ExAws.request!

    end

    filter(results, search)  # index may have had more fields than the index did, thus results need to be trimmed.
  end



  # we've a list of fields from an index that matches the (some of) the search fields,
  # so construct a dynamo db search criteria map with only the given fields and their
  # search objects!
  def construct_search({:primary, index_fields}, table, search),  do: construct_search(%{}, index_fields, table, search)
  def construct_search({:primary_partial, _index_fields}, _table, _search),  do: raise ":primary_partial index search not yet implemented"
  def construct_search({index_name, index_fields}, table, search) do
    # Construct a DynamoDB FilterExpression (since it cannot be provided blank but may be,
    # we merge it with the full query)
    {filter_expression_tuple, expression_attribute_names, expression_attribute_values} = construct_filter_expression(table, search)

    criteria = [index_name: index_name]
    criteria ++ case index_fields do
      [hash, range] ->
        {hash_val, _op} = search[hash]
        {range_val, _op} = search[range]
        [
          # We need ExpressionAttributeNames when field-names are reserved, for example "name" or "role"
          key_condition_expression: "##{hash} = :hash_key AND ##{range} = :range_key",
          expression_attribute_names: Map.merge(%{"##{hash}" => hash, "##{range}" => range}, expression_attribute_names),
          expression_attribute_values: [hash_key: hash_val, range_key: range_val] ++ expression_attribute_values,
          select: :all_attributes
        ] ++ filter_expression_tuple

      [hash] ->
        {hash_val, _op} = search[hash]
        [
          key_condition_expression: "##{hash} = :hash_key",
          expression_attribute_names: Map.merge(%{"##{hash}" => hash}, expression_attribute_names),
          expression_attribute_values: [hash_key: hash_val] ++ expression_attribute_values,
          select: :all_attributes
        ] ++ filter_expression_tuple
      
    end
  end

  # TODO: would there be a difference, constructing this as an explicit range query > "0"?
  def construct_search({:secondary_partial, index_name , index_fields}, table, search) do
    construct_search({index_name, index_fields}, table, search)
  end

  defp construct_search(criteria, [], _, _), do: criteria
  defp construct_search(criteria, [index_field|index_fields], table, search) do
    Map.put(criteria, index_field, elem(search[index_field], 0)) |> construct_search(index_fields, table, search)
  end


  # returns a tuple: {filter_expression_tuple, expression_attribute_names, expression_attribute_values}
  defp construct_filter_expression(table, search) do
    # We can only construct a FilterExpression on a non-indexed field.
    indexed_fields = Ecto.Adapters.DynamoDB.Info.indexed_attributes(table)
    non_indexed_filters = Enum.filter(search, fn {field, {_val, _op}} -> not Enum.member?(indexed_fields, field) end)

    case non_indexed_filters do
      [] -> {[], %{}, []}
      _  ->
        # For now, we'll just handle the 'and' logical operator
        filter_expression = Enum.map(non_indexed_filters, &construct_conditional_statement/1) |> Enum.join(" and ")
        expression_attribute_names = for {field, {_val, _op}} <- non_indexed_filters, into: %{}, do: {"##{field}" , field}
        expression_attribute_values = for {_field, {val, op}} <- non_indexed_filters, do: format_expression_attribute_value(val, op)
        {[filter_expression: filter_expression], expression_attribute_names, expression_attribute_values}
    end
  end

  defp format_expression_attribute_value(val, :is_nil), do: {String.to_atom(val), nil}
  defp format_expression_attribute_value(val, _op), do: {String.to_atom(val), val}

  defp construct_conditional_statement({field, {val, :is_nil}}) do
    "(##{field} = :#{val} or attribute_not_exists(##{field}))"
  end
  defp construct_conditional_statement({field, {val, :==}}) do
    "##{field} = :#{val}"
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
      {:primary, _} = index -> index

      # we've found a primary hash index, but lets check if there's a more specific
      # secondary index with hash+sort available...
      {:primary_partial, _primary_hash} = index ->
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
  def get_matching_primary_index(tablename, search) do
    primary_key = primary_key!(tablename)

    case match_index(primary_key, search) do
      # We found a full primary index
      {:primary, _} = index -> index

      # We might be able to use a range query for all results with
      # the hash part, such as all circle_member with a specific person_id (all a user's circles).
      :not_found             -> match_index_hash_part(primary_key, search)
    end
  end


  @doc """
  Given a map containing key values representing a search field and value to search for
  (eg %{id => "franko"}, or %{circle_id => "123", person_id =>"abc"}), will return the
  dynamo db index description that will help us match this search. return :not_found if
  no index is found.

  Returns a tuple of {"index_name", [ hash_key or hash,range_key]]} or :not_found
  TODO: Does not help with range queries. -> The match_index_hash_part function is
    beginning to address this.
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
      :not_found ->
        case match_index_hash_part(index, search) do
          :not_found    -> find_best_match(indexes, search, best)    # haven't found anything good, keep looking, retain our previous best match.
          index_partial -> find_best_match(indexes, search, index_partial) 
        end
    end
  end


  # The parameter, 'search', is a map: %{field_name::string => {value::string, operator::atom}}
  defp match_index(index, search) do
    case index do
      {_, [hash, range]} ->
        # Part of the query could be a nil filter on an indexed attribute;
        # in that case, we need a check in addition to has_key?, so we check the operator.
        if Map.has_key?(search, hash) and elem(search[hash], 1) != :is_nil
        and Map.has_key?(search, range) and elem(search[range], 1) != :is_nil,
        do: index, else: :not_found

      {_, [hash]} ->
        if Map.has_key?(search, hash) and elem(search[hash], 1) != :is_nil, do: index, else: :not_found
    end
  end

  defp match_index_hash_part(index, search) do
    case index do
      {:primary, [hash, _range]} ->
        if Map.has_key?(search, hash) and elem(search[hash], 1) != :is_nil,
        do: {:primary_partial, [hash]}, else: :not_found

      {index_name, [hash, _range]} ->
        if Map.has_key?(search, hash) and elem(search[hash], 1) != :is_nil,
        do: {:secondary_partial, index_name, [hash]}, else: :not_found

      _ -> :not_found
    end
  end

end
