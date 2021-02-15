defmodule Ecto.Adapters.DynamoDB.Cache do
  @moduledoc """
  An Elixir agent to cache DynamoDB table schemas and the first page of results for selected tables
  """

  @typep table_name_t :: String.t()
  @typep dynamo_response_t :: %{required(String.t()) => term}

  alias Ecto.Adapters.DynamoDB
  alias Ecto.Repo

  defstruct [
    :schemas,
    :tables,
    :ex_aws_config
  ]

  @type t :: %__MODULE__{
          schemas: Map.t(),
          tables: [CachedTable.t()]
        }

  def child_spec([repo]) do
    %{
      id: repo,
      start: {__MODULE__, :start_link, [repo]}
    }
  end

  @spec start_link(Repo.t()) :: Agent.on_start()
  def start_link(repo) do
    cached_table_list =
      :ecto_adapters_dynamodb
      |> Confex.get_env(repo)
      |> Keyword.get(:cached_tables, [])

    Agent.start_link(
      fn ->
        %__MODULE__{
          schemas: %{},
          tables: for(table_name <- cached_table_list, into: %{}, do: {table_name, nil}),
          ex_aws_config: DynamoDB.ex_aws_config(repo)
        }
      end,
      name: agent(repo)
    )
  end

  @doc """
  Returns the cached value for a call to DynamoDB, describe-table. Performs a DynamoDB scan if not yet cached and raises any errors as a result of the request. The raw json is presented as an elixir map.
  """
  @spec describe_table!(Repo.t(), table_name_t) :: dynamo_response_t | no_return
  def describe_table!(repo, table_name) do
    case describe_table(repo, table_name) do
      {:ok, schema} -> schema
      {:error, error} -> raise error.type, message: error.message
    end
  end

  @spec describe_table(Repo.t(), table_name_t) :: {:ok, dynamo_response_t} | {:error, term}
  def describe_table(repo, table_name),
    do: Agent.get_and_update(agent(repo), &do_describe_table(&1, table_name))

  @doc """
  Performs a DynamoDB, describe-table, and caches (without returning) the result. Raises any errors as a result of the request
  """
  @spec update_table_info!(Repo.t(), table_name_t) :: :ok | no_return
  def update_table_info!(repo, table_name) do
    case update_table_info(repo, table_name) do
      :ok -> :ok
      {:error, error} -> raise error.type, message: error.message
    end
  end

  @spec update_table_info(Repo.t(), table_name_t) :: :ok | {:error, term}
  def update_table_info(repo, table_name),
    do: Agent.get_and_update(agent(repo), &do_update_table_info(&1, table_name))

  @doc """
  Returns the cached first page of results for a table. Performs a DynamoDB scan if not yet cached and raises any errors as a result of the request
  """
  @spec scan!(Repo.t(), table_name_t) :: dynamo_response_t | no_return
  def scan!(repo, table_name) do
    case scan(repo, table_name) do
      {:ok, scan_result} -> scan_result
      {:error, error} -> raise error.type, message: error.message
    end
  end

  @spec scan(Repo.t(), table_name_t) :: {:ok, dynamo_response_t} | {:error, term}
  def scan(repo, table_name),
    do: Agent.get_and_update(agent(repo), &do_scan(&1, table_name))

  @doc """
  Performs a DynamoDB scan and caches (without returning) the first page of results. Raises any errors as a result of the request
  """
  @spec update_cached_table!(Repo.t(), table_name_t) :: :ok | no_return
  def update_cached_table!(repo, table_name) do
    case update_cached_table(repo, table_name) do
      :ok -> :ok
      {:error, error} -> raise error.type, message: error.message
    end
  end

  @spec update_cached_table(Repo.t(), table_name_t) :: :ok | {:error, term}
  def update_cached_table(repo, table_name),
    do: Agent.get_and_update(agent(repo), &do_update_cached_table(&1, table_name))

  @doc """
  Returns the current cache of table schemas, and cache of first page of results for selected tables, as an Elixir map
  """
  # For testing and debugging use only:
  def get_cache(repo),
    do: Agent.get(agent(repo), & &1)

  defp do_describe_table(cache, table_name) do
    case cache.schemas[table_name] do
      nil ->
        result = ExAws.Dynamo.describe_table(table_name) |> ExAws.request(cache.ex_aws_config)

        case result do
          {:ok, %{"Table" => schema}} ->
            updated_cache = put_in(cache.schemas[table_name], schema)
            {{:ok, schema}, updated_cache}

          {:error, error} ->
            {{:error, %{type: ExAws.Error, message: "ExAws Request Error! #{inspect(error)}"}},
             cache}
        end

      schema ->
        {{:ok, schema}, cache}
    end
  end

  defp do_update_table_info(cache, table_name) do
    result = ExAws.Dynamo.describe_table(table_name) |> ExAws.request(cache.ex_aws_config)

    case result do
      {:ok, %{"Table" => schema}} ->
        updated_cache = put_in(cache.schemas[table_name], schema)
        {:ok, updated_cache}

      {:error, error} ->
        {{:error, %{type: ExAws.Error, message: "ExAws Request Error! #{inspect(error)}"}}, cache}
    end
  end

  defp do_scan(cache, table_name) do
    table_name_in_config = Map.has_key?(cache.tables, table_name)

    case cache.tables[table_name] do
      nil when table_name_in_config ->
        result = ExAws.Dynamo.scan(table_name) |> ExAws.request(cache.ex_aws_config)

        case result do
          {:ok, scan_result} ->
            updated_cache = put_in(cache.tables[table_name], scan_result)
            {{:ok, scan_result}, updated_cache}

          {:error, error} ->
            {{:error, %{type: ExAws.Error, message: "ExAws Request Error! #{inspect(error)}"}},
             cache}
        end

      nil ->
        {{:error,
          %{
            type: ArgumentError,
            message:
              "Could not confirm the table, #{inspect(table_name)}, as listed for caching in the application's configuration. Please see README file for details."
          }}, cache}

      cached_scan ->
        {{:ok, cached_scan}, cache}
    end
  end

  defp do_update_cached_table(cache, table_name) do
    table_name_in_config = Map.has_key?(cache.tables, table_name)

    case cache.tables[table_name] do
      nil when not table_name_in_config ->
        {{:error,
          %{
            type: ArgumentError,
            message:
              "Could not confirm the table, #{inspect(table_name)}, as listed for caching in the application's configuration. Please see README file for details."
          }}, cache}

      _ ->
        result = ExAws.Dynamo.scan(table_name) |> ExAws.request(cache.ex_aws_config)

        case result do
          {:ok, scan_result} ->
            updated_cache = put_in(cache.tables[table_name], scan_result)
            {:ok, updated_cache}

          {:error, error} ->
            {{:error, %{type: ExAws.Error, message: "ExAws Request Error! #{inspect(error)}"}},
             cache}
        end
    end
  end

  defp agent(repo), do: Module.concat(repo, Cache)
end
