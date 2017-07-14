defmodule Ecto.Adapters.DynamoDB.Migration do
  import Ecto.Adapters.DynamoDB, only: [ecto_dynamo_log: 2]

  alias ExAws.Dynamo

  def execute_ddl(repo, command, options) do
    ecto_dynamo_log(:debug, "EXECUTE_DDL:::")
    ecto_dynamo_log(:debug, "repo: #{inspect repo}")
    ecto_dynamo_log(:debug, "command: #{inspect command}")
    ecto_dynamo_log(:debug, "options: #{inspect options}")

    execute_ddl(command, options)
  end

  # {:create_if_not_exists, %Ecto.Migration.Table{comment: nil, engine: nil, name: :schema_migrations, options: nil, prefix: nil, primary_key: true}, [{:add, :version, :bigint, [primary_key: true]}, {:add, :inserted_at, :naive_datetime, []}]}

  def execute_ddl({:create_if_not_exists, %Ecto.Migration.Table{} = table, field_clauses}, _opts) do
    table_name = Atom.to_string(table.name)
    %{"TableNames" => table_list} = Dynamo.list_tables |> ExAws.request!
    
    if not Enum.member?(table_list, table_name),
    do: create_table(table_name, field_clauses)

    :ok
  end

  # {:create, %Ecto.Migration.Table{comment: nil, engine: nil, name: :post, options: nil, prefix: nil, primary_key: true}, [{:add, :id, :serial, [primary_key: true]}, {:add, :title, :string, []}, {:add, :content, :string, []}, {:add, :inserted_at, :naive_datetime, [null: false]}, {:add, :updated_at, :naive_datetime, [null: false]}]}, [timeout: :infinity, log: false])

  def execute_ddl({:create, %Ecto.Migration.Table{} = table, field_clauses}, _opts) do
    table_name = Atom.to_string(table.name)
    %{"TableNames" => table_list} = Dynamo.list_tables |> ExAws.request!
    
    if not Enum.member?(table_list, table_name) do
      create_table(table_name, field_clauses)
      :ok
    else
      raise "table, #{inspect table_name}, already exists"
    end
  end

  # {:drop, %Ecto.Migration.Table{comment: nil, engine: nil, name: :post, options: nil, prefix: nil, primary_key: true}}, [timeout: :infinity, log: false]

  def execute_ddl({:drop, %Ecto.Migration.Table{} = table}, _opts) do
    table_name = Atom.to_string(table.name)
    Dynamo.delete_table(table_name) |> ExAws.request!
    :ok
  end


  defp create_table(table_name, field_clauses) do
    # support hash only for now (take the first in the list)
    {primary_key_field, primary_key_type} = hd Enum.reduce(field_clauses, [], fn({cmd, field, type, opts}, acc) ->
      if cmd == :add and opts[:primary_key] == true, do: [{field, type} | acc], else: acc
    end)

    key_definitions = %{primary_key_field => convert_type(primary_key_type)}

    Dynamo.create_table(table_name, [{primary_key_field, :hash}], key_definitions, 1, 1) |> ExAws.request!
  end

  defp convert_type(type) do
    case type do
      :bigint -> :number
      :serial -> :number
      _       -> type
    end
  end
end
