defmodule Ecto.Adapters.DynamoDB.Migration do
  import Ecto.Adapters.DynamoDB, only: [ecto_dynamo_log: 2]

  alias ExAws.Dynamo

  @moduledoc"""
  Implements some Ecto migrations.

  ```
  Example:

  #Migration file 1:

    def change do
      create table(:post, primary_key: false,
        options: [
          global_indexes: [
            [index_name: "email_content",
             keys: [:email, :content],
             provisioned_throughput: [100, 100]] # [read_capacity, write_capacity]
            ],
          provisioned_throughput: [20,20]
        ]) do

        add :email,   :string, primary_key: true
        add :title,   :string, range_key: true
        add :content, :string

        timestamps()
      end
    end


  # Migration file 2:

    def up do
      alter table(:post,
        options: [
          global_indexes: [
            [index_name: "content",
             keys: [:content],
             projection: [projection_type: :include, non_key_attributes: [:email]]]
          ]
        ]) do

        add :content, string
      end
    end

    def down do
      alter table(:post) do
        remove :content
      end
    end


  # Migration file 3:
    def up do
      alter table(:post) do
        # modify will not be processed in a rollback if 'change' is used
        modify :"email_content", :string, provisioned_throughput: [2,2]
        remove :content
      end
    end

    def down do
      alter table(:post,
        options: [
          global_indexes: [
            [index_name: "content",
             keys: [:content],
             projection: [projection_type: :include, non_key_attributes: [:email]]]
          ]
        ]) do

        modify :"email_content", :string, provisioned_throughput: [100,100]
        add :content, :string
      end
    end
 ```
  """

  # Adapted from line 620, https://github.com/michalmuskala/mongodb_ecto/blob/master/lib/mongo_ecto.ex
  def execute_ddl(_repo, string, _opts) when is_binary(string) do
    raise ArgumentError, message: "Ecto.Adapters.Dynamodb does not support SQL statements in `execute`"
  end

  def execute_ddl(repo, command, options) do
    ecto_dynamo_log(:debug, "EXECUTE_DDL:::")
    ecto_dynamo_log(:debug, "repo: #{inspect repo}")
    ecto_dynamo_log(:debug, "command: #{inspect command}")
    ecto_dynamo_log(:debug, "options: #{inspect options}")

    execute_ddl(command, options)
  end

  def execute_ddl({:create_if_not_exists, %Ecto.Migration.Table{} = table, field_clauses}, _opts) do
    table_name = Atom.to_string(table.name)
    %{"TableNames" => table_list} = Dynamo.list_tables |> ExAws.request!

    ecto_dynamo_log(:info, "#{inspect __MODULE__}.execute_ddl: create_if_not_exists (table)")
    
    if not Enum.member?(table_list, table_name) do
      ecto_dynamo_log(:info, "Creating table #{inspect table.name}")
      create_table(table_name, field_clauses, table.options)
    else
      ecto_dynamo_log(:info, "Table #{inspect table.name} already exists, skipping...")
    end

    :ok
  end

  def execute_ddl({:create, %Ecto.Migration.Table{} = table, field_clauses}, _opts) do
    ecto_dynamo_log(:info, "#{inspect __MODULE__}.execute_ddl: create table")
    ecto_dynamo_log(:info, "Creating table #{inspect table.name}")

    create_table(table.name, field_clauses, table.options)
    :ok
  end

  def execute_ddl({:create, %Ecto.Migration.Index{}}, _opts) do
    raise ArgumentError, message: "Ecto.Adapters.Dynamodb migration does not support 'create index()', please use 'alter table()' instead, see README.md"
  end

  def execute_ddl({:drop, %Ecto.Migration.Table{} = table}, _opts) do
    ecto_dynamo_log(:info, "#{inspect __MODULE__}.execute_ddl: drop")
    ecto_dynamo_log(:info, "Removing table #{inspect table.name}")

    Dynamo.delete_table(table.name) |> ExAws.request!
    :ok
  end

  def execute_ddl({:alter, %Ecto.Migration.Table{} = table, field_clauses}, _opts) do
    ecto_dynamo_log(:info, "#{inspect __MODULE__}.execute_ddl: alter table")

    {delete, update, key_list} = build_delete_and_update(field_clauses)

    attribute_definitions = for {field, type} <- key_list do
      %{attribute_name: field, attribute_type: Dynamo.Encoder.atom_to_dynamo_type(convert_type(type))}
    end

    to_create = case table.options[:global_indexes] do
      nil -> nil
      global_indexes ->
        Enum.filter(global_indexes, fn index -> index[:keys] |> Enum.all?(fn key -> Keyword.has_key?(key_list, key) end) end)
    end

    create = build_secondary_indexes(to_create) |> Enum.map(fn index -> %{create: index} end)

    data = %{global_secondary_index_updates: create ++ delete ++ update}
           |> Map.merge(if create == [], do: %{}, else: %{attribute_definitions: attribute_definitions})

    Dynamo.update_table(table.name, data) |> ExAws.request!
    :ok
  end

  def execute_ddl({command, _, _}, _opts), do:
  raise ArgumentError, message: "#{inspect __MODULE__}.execute_ddl error: #{inspect command} is not supported"


  defp create_table(table_name, field_clauses, options) do
    {key_schema, key_definitions} = build_key_schema_and_definitions(table_name, field_clauses, options)
    [read_capacity, write_capacity] = options[:provisioned_throughput] || [1,1]
    global_indexes = build_secondary_indexes(options[:global_indexes])
    local_indexes = build_secondary_indexes(options[:local_indexes])

    Dynamo.create_table(table_name, key_schema, key_definitions, read_capacity, write_capacity, global_indexes, local_indexes) |> ExAws.request!
  end

  defp build_key_schema_and_definitions(table_name, field_clauses, options) do
    secondary_index_atoms =
      (options[:global_indexes] || []) ++ (options[:local_indexes] || [])
      |> Enum.flat_map(fn indexes -> indexes[:keys] || [] end)

    {hash_key, range_key, key_list} = Enum.reduce(field_clauses, {nil, nil, []}, fn({cmd, field, type, opts}, {hash, range, key_list}) ->
      cond do      
        cmd == :add and opts[:primary_key] == true ->
          {field, range, [{field, type} | key_list]}
        cmd == :add and opts[:range_key] == true ->
          {hash, field, [{field, type} | key_list]}
        cmd == :add and Enum.member?(secondary_index_atoms, field) ->
          {hash, range, [{field, type} | key_list]}
        true ->
          {hash, range, key_list}
      end
    end)

    if is_nil(hash_key), do: raise "#{inspect __MODULE__}.build_key_schema error: no primary key was found for table #{inspect table_name}. Please specify one primary key in migration."

    key_definitions = for {field, type} <- key_list, into: %{}, do: {field, convert_type(type)}

    case range_key do
      nil ->
        {[{hash_key, :hash}], key_definitions}

      range_key ->
        {[{hash_key, :hash}, {range_key, :range}], key_definitions}
    end
  end

  defp build_secondary_indexes(nil), do: []
  defp build_secondary_indexes(global_indexes) do
    Enum.map(global_indexes, fn index ->
      [read_capacity, write_capacity] = index[:provisioned_throughput] || [1,1]

      %{index_name: index[:index_name],
        key_schema: build_secondary_key_schema(index[:keys]),
        provisioned_throughput: %{read_capacity_units: read_capacity,
                                  write_capacity_units: write_capacity},
        projection: build_secondary_projection(index[:projection])}
    end)
  end

  defp build_secondary_key_schema(keys) do
    case keys do
      [hash]        -> [%{attribute_name: Atom.to_string(hash), key_type: "HASH"}]
      [hash, range] -> [%{attribute_name: Atom.to_string(hash), key_type: "HASH"},
                        %{attribute_name: Atom.to_string(range), key_type: "RANGE"}]
    end
  end

  defp build_secondary_projection(nil), do: %{projection_type: "ALL"}
  defp build_secondary_projection(projection) do
    case projection[:projection_type] do
      :include ->
        %{projection_type: "INCLUDE",
          non_key_attributes: projection[:non_key_attributes]}

      type when type in [:all, :keys_only] ->
        %{projection_type: ExAws.Utils.upcase(type)}
    end
  end

  defp build_delete_and_update(field_clauses) do
    Enum.reduce(proper_list(field_clauses), {[],[],[]}, fn (field_clause, {delete, update, key_list}) ->
      case field_clause do
        {:remove, field} ->
          {[%{delete: %{index_name: field}} | delete], update, key_list}
        {:modify, field, _type, opts} ->
          [read_capacity, write_capacity] = opts[:provisioned_throughput] || [1,1]
          provisioned_throughput =  %{read_capacity_units: read_capacity, write_capacity_units: write_capacity}
          {delete, [%{update: %{index_name: field, provisioned_throughput: provisioned_throughput}} | update], key_list}
        {:add, field, type, _opts} ->
          {delete, update, [{field, type} | key_list]}
        _ ->
          {delete, update, key_list}
      end
    end)
  end

  defp convert_type(type) do
    case type do
      :bigint    -> :number
      :serial    -> :number
      :binary    -> :blob
      :binary_id -> :blob
      _          -> type
    end
  end

  defp proper_list(l), do: proper_list(l, [])
  defp proper_list([], res), do: Enum.reverse(res)
  defp proper_list([a | b], res) when not (is_list b), do: Enum.reverse([a | res])
  defp proper_list([a | b], res), do: proper_list(b, [a | res])

end
