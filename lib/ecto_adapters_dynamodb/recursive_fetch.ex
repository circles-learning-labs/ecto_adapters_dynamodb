defmodule Ecto.Adapters.DynamoDB.RecursiveFetch do
  alias Ecto.Adapters.DynamoDB
  alias Ecto.Adapters.DynamoDB.Query

  @typep fetch_func :: (Query.table_name(), keyword -> ExAws.Operation.JSON.t())

  def fetch_query(repo, query, table, opts) do
    fetch(
      repo,
      &ExAws.Dynamo.query/2,
      table,
      query,
      Query.parse_recursive_option(:query, opts),
      %{}
    )
  end

  @spec fetch(Repo.t(), fetch_func, Query.table_name(), keyword, boolean | number, map) ::
          Query.dynamo_response()
  def fetch(repo, func, table, expressions, recursive, result) do
    updated_expressions =
      if recursive == true, do: Keyword.delete(expressions, :limit), else: expressions

    fetch_result =
      func.(table, updated_expressions) |> ExAws.request!(DynamoDB.ex_aws_config(repo))

    # recursive can be a boolean or a page limit
    updated_recursive = update_recursive_option(recursive)

    if fetch_result["LastEvaluatedKey"] != nil and updated_recursive.continue do
      fetch(
        repo,
        func,
        table,
        updated_expressions ++ [exclusive_start_key: fetch_result["LastEvaluatedKey"]],
        updated_recursive.new_value,
        combine_results(result, fetch_result)
      )
    else
      combine_results(result, fetch_result)
    end
  end

  @doc """
  Updates the recursive option during a recursive fetch, according to whether the option is a
  boolean or an integer (as in the case of page_limit)
  """
  def update_recursive_option(r) when is_boolean(r), do: %{continue: r, new_value: r}
  def update_recursive_option(r) when is_integer(r), do: %{continue: r > 1, new_value: r - 1}

  @spec combine_results(map, map) :: map
  defp combine_results(result, scan_result) do
    if result == %{} do
      scan_result
    else
      %{"Count" => result_count, "Items" => result_items, "ScannedCount" => result_scanned_count} =
        result

      %{
        "Count" => scanned_count,
        "Items" => scanned_items,
        "ScannedCount" => scanned_scanned_count
      } = scan_result

      %{
        "Count" => result_count + scanned_count,
        "Items" => result_items ++ scanned_items,
        "ScannedCount" => result_scanned_count + scanned_scanned_count
      }
    end
  end
end
