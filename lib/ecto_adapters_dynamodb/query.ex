defmodule Ecto.Adapters.DynamoDB.Query do
  @moduledoc """
  Some query wrapper functions for helping us query dynamo db. Selects indexes to use, etc.
  Not to be confused with Ecto.Query (Should wec rename this module?)

  """

  import Ecto.Adapters.DynamoDB.Info


  # parameters for get_item: 
  # TABLE_NAME::string,
  # %{LOGICAL_OP::atom => [{ATTRIBUTE::string => {VALUE::string, OPERATOR::atom}}]} | %{ATTRIBUTE::string => {VALUE::string, OPERATOR::atom}}
  #

  # Repo.all(model), provide cached results for tables designated in :cached_tables
  def get_item(table, search) when search == [] do
    Ecto.Adapters.DynamoDB.Cache.scan!(table)
  end

  # Regular queries
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
  def construct_search({:primary, index_fields}, search), do: construct_search(%{}, index_fields, search)
  def construct_search({:primary_partial, _index_fields}, _search), do: raise ":primary_partial index search not yet implemented"
  def construct_search({index_name, index_fields}, search) do
    # Construct a DynamoDB FilterExpression (since it cannot be provided blank but may be,
    # we merge it with the full query)
    {filter_expression_tuple, expression_attribute_names, expression_attribute_values} = construct_filter_expression(search, index_fields)

    criteria = [index_name: index_name]
    criteria ++ case index_fields do
      [hash, range] ->
        {hash_val, _op} = deep_find_key(search, hash)
        {range_expression, range_attribute_names, range_attribute_values} = construct_range_params(range, deep_find_key(search, range))
        [
          # We need ExpressionAttributeNames when field-names are reserved, for example "name" or "role"
          key_condition_expression: "##{hash} = :hash_key AND #{range_expression}",
          expression_attribute_names: Enum.reduce([%{"##{hash}" => hash}, range_attribute_names, expression_attribute_names], &Map.merge/2),
          expression_attribute_values: [hash_key: hash_val] ++ range_attribute_values ++ expression_attribute_values,
          select: :all_attributes
        ] ++ filter_expression_tuple

      [hash] ->
        {hash_val, _op} = deep_find_key(search, hash)
        [
          key_condition_expression: "##{hash} = :hash_key",
          expression_attribute_names: Map.merge(%{"##{hash}" => hash}, expression_attribute_names),
          expression_attribute_values: [hash_key: hash_val] ++ expression_attribute_values,
          select: :all_attributes
        ] ++ filter_expression_tuple
      
    end
  end

  def construct_search({:secondary_partial, index_name , index_fields}, search) do
    construct_search({index_name, index_fields}, search)
  end

  defp construct_search(criteria, [], _), do: criteria
  defp construct_search(criteria, [index_field|index_fields], search) do
    Map.put(criteria, index_field, elem(deep_find_key(search, index_field), 0)) |> construct_search(index_fields, search)
  end

  defp construct_range_params(range, {[range_start, range_end], :between}) do
    {"##{range} between :range_start and :range_end", %{"##{range}" => range}, [range_start: range_start, range_end: range_end]} 
  end
  defp construct_range_params(range, {range_val, :==}) do
    {"##{range} = :range_key", %{"##{range}" => range}, [range_key: range_val]}
  end
  defp construct_range_params(range, {range_val, op}) when op in [:<, :>, :<=, :>=] do
    {"##{range} #{to_string(op)} :range_key", %{"##{range}" => range}, [range_key: range_val]}
  end

  # returns a tuple: {filter_expression_tuple, expression_attribute_names, expression_attribute_values}
  defp construct_filter_expression(search, index_fields) do
    # We can only construct a FilterExpression on attributes not in key-conditions.
    non_indexed_filters = collect_non_indexed_search(search, index_fields, [])

    case non_indexed_filters do
      [] -> {[], %{}, []}
      _  ->
        {filter_expression_list, expression_attribute_names, expression_attribute_values} = 
          build_filter_expression_data(non_indexed_filters, {[], %{}, %{}})

        {[filter_expression: Enum.join(filter_expression_list, " and ")],
         expression_attribute_names,
         Enum.into(expression_attribute_values, [])}
    end
  end


  # Recursively strip out the fields for key-conditions; they could be mixed with non key-conditions.
  # TODO: this may be redundant - the indexed fields can just be skipped during the expression construction
  defp collect_non_indexed_search([], _index_fields, acc), do: acc
  defp collect_non_indexed_search([search_clause | search_clauses], index_fields, acc) do
    case search_clause do
      {field, {_val, _op}} = complete_tuple when not field in [:and, :or] ->
        if Enum.member?(index_fields, field),
        do: collect_non_indexed_search(search_clauses, index_fields, acc),
        else: collect_non_indexed_search(search_clauses, index_fields, [complete_tuple | acc])

      {logical_op, deeper_clauses} when logical_op in [:and, :or] ->
        filtered_clauses = collect_non_indexed_search(deeper_clauses, index_fields, [])
        # don't keep empty logical_op groups
        if filtered_clauses == [],
        do: collect_non_indexed_search(search_clauses, index_fields, acc),
        else: collect_non_indexed_search(search_clauses, index_fields, [{logical_op, filtered_clauses} | acc])
    end
  end

  # Recursively reconstruct parentheticals
  defp build_filter_expression_data([], acc), do: acc
  defp build_filter_expression_data([expr | exprs], {filter_exprs, attr_names, attr_values}) do
    case expr do
      # a list of lookup fields; iterate.
      {field, {val, op} = val_op_tuple} = complete_tuple when is_tuple(val_op_tuple) ->
        updated_filter_exprs = [construct_conditional_statement(complete_tuple) | filter_exprs]
        updated_attr_names = Map.merge(%{"##{field}" => field}, attr_names)
        updated_attr_values = Map.merge(format_expression_attribute_value(field, val, op), attr_values) 

        build_filter_expression_data(exprs, {updated_filter_exprs, updated_attr_names, updated_attr_values})

      {logical_op, exprs_list} when is_list(exprs_list) ->
        {deeper_filter_exprs, deeper_attr_names, deeper_attr_values} = build_filter_expression_data(exprs_list, {[], %{}, %{}})
        updated_filter_exprs = ["(" <> Enum.join(deeper_filter_exprs, " #{to_string(logical_op)} ") <> ")" | filter_exprs]
        updated_attr_names = Map.merge(deeper_attr_names, attr_names)
        updated_attr_values = Map.merge(deeper_attr_values, attr_values)

        build_filter_expression_data(exprs, {updated_filter_exprs, updated_attr_names, updated_attr_values})
    end
  end

  # We use a version of the field-name for the value's key to guarantee uniqueness
  defp format_expression_attribute_value(field, _val, :is_nil), do: %{String.to_atom(field <> "_val") => nil}
  # double op
  defp format_expression_attribute_value(field, [val1, val2], [_op1, _op2]) do
    %{String.to_atom(field <> "_val1") => val1, String.to_atom(field <> "_val2") => val2}
  end
   defp format_expression_attribute_value(field, [start_val, end_val], :between) do
    %{String.to_atom(field <> "_start_val") => start_val, String.to_atom(field <> "_end_val") => end_val}
  end
  defp format_expression_attribute_value(field, val, _op), do: %{String.to_atom(field <> "_val") => val}


  # double op (neither of them ought be :==)
  defp construct_conditional_statement({field, {[_val1, _val2], [op1, op2]}}) do
    "##{field} #{to_string(op1)} :#{field <> "_val1"} and ##{field} #{to_string(op2)} :#{field <> "_val2"}"
  end  
  defp construct_conditional_statement({field, {_val, :is_nil}}) do
    "(##{field} = :#{field <> "_val"} or attribute_not_exists(##{field}))"
  end
  defp construct_conditional_statement({field, {_val, :==}}) do
    "##{field} = :#{field <> "_val"}"
  end
  defp construct_conditional_statement({field, {_val, op}}) when op in [:<, :>, :<=, :>=] do
    "##{field} #{to_string(op)} :#{field <> "_val"}"
  end
  defp construct_conditional_statement({field, {[_start_val, _end_val], :between}}) do
    "##{field} between :#{field <> "_start_val"} and :#{field <> "_end_val"}"
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
        # in that case, we need a check in addition to the key, so we check the operator.
        # Also, the hash part can only accept an :== operator.
        hash_key = deep_find_key(search, hash)
        range_key = deep_find_key(search, range)
        if hash_key != nil and elem(hash_key, 1) == :==
        and range_key != nil and elem(range_key, 1) != :is_nil,
        do: index, else: :not_found

      {_, [hash]} ->
        hash_key = deep_find_key(search, hash)
        if hash_key != nil and elem(hash_key, 1) == :==, 
        do: index, else: :not_found
    end
  end

  defp match_index_hash_part(index, search) do
    case index do
      {:primary, [hash, _range]} ->
        hash_key = deep_find_key(search, hash)
        if hash_key != nil and elem(hash_key, 1) == :==,
        do: {:primary_partial, [hash]}, else: :not_found

      {index_name, [hash, _range]} ->
        hash_key = deep_find_key(search, hash)
        if hash_key != nil and elem(hash_key, 1) == :==,
        do: {:secondary_partial, index_name, [hash]}, else: :not_found

      _ -> :not_found
    end
  end

  # TODO: multiple use of deep_find_key could be avoided by using the recursion in the main module to provide a set of indexed attributes in addition to the nested logical clauses.
  defp deep_find_key([], _), do: nil
  defp deep_find_key([clause | clauses], key) do
    case clause do
      {field, {val, op}} when not field in [:and, :or] ->
        if field == key, do: {val, op}, else: deep_find_key(clauses, key)
      {logical_op, deeper_clauses} when logical_op in [:and, :or] ->
        found = deep_find_key(deeper_clauses, key)
        if found != nil, do: found, else: deep_find_key(clauses, key)
    end
  end

end
