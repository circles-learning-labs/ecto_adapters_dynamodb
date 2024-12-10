defmodule Ecto.Adapters.DynamoDB.ConcurrentBatch do
  alias Ecto.Adapters.DynamoDB.RecursiveFetch

  def fetch(repo, query, table, hash_values, opts) do
    items =
      if Confex.get_env(:ecto_adapters_dynamodb, :concurrent_batch, false) do
        concurrent_fetch(repo, query, table, hash_values, opts)
      else
        do_fetch_recursive(repo, query, table, hash_values, opts)
      end

    %{"Responses" => %{table => items}}
  end

  def concurrent_fetch(repo, query, table, hash_values, opts) do
    max_fetch_concurrency = Confex.get_env(:ecto_adapters_dynamodb, :max_fetch_concurrency, 100)

    min_concurrent_fetch_batch =
      Confex.get_env(:ecto_adapters_dynamodb, :min_concurrent_fetch_batch, 10)

    item_count = length(hash_values)

    processes = min(max_fetch_concurrency, ceil(item_count / min_concurrent_fetch_batch))

    if processes < 2 do
      do_fetch_recursive(repo, query, table, hash_values, opts)
    else
      do_concurrent_fetch(repo, query, table, hash_values, opts, processes)
    end
  end

  defp do_concurrent_fetch(repo, query, table, hash_values, opts, processes) do
    hash_values
    |> Enum.chunk_every(ceil(length(hash_values) / processes))
    |> Enum.map(fn chunk ->
      Task.async(fn -> do_fetch_recursive(repo, query, table, chunk, opts) end)
    end)
    |> Enum.map(&Task.await/1)
    |> List.flatten()
  end

  defp do_fetch_recursive(repo, query, table, hash_values, opts) do
    Enum.reduce(hash_values, [], fn hash_value, acc ->
      # When receiving a list of values to query on, construct a custom query for each
      # of those values to pass into fetch_recursive_query/1.
      new_query =
        Kernel.put_in(query, [:expression_attribute_values, :hash_key], hash_value)

      %{"Items" => items} = RecursiveFetch.fetch_query(repo, new_query, table, opts)
      acc ++ items
    end)
  end
end
