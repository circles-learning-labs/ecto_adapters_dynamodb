defmodule Ecto.Adapters.DynamoDB.Migration do
  import Ecto.Adapters.DynamoDB, only: [ecto_dynamo_log: 2, ecto_dynamo_log: 3, ex_aws_config: 1]

  alias ExAws.Dynamo
  alias Ecto.Adapters.DynamoDB.RepoConfig

  @moduledoc """
  Implements Ecto migrations for `create table` and `alter table`.

  The functions, `add`, `remove` and `modify` correspond to indexes on the DynamoDB table. Using `add`, the second parameter, field type (which corresponds with the DynamoDB attribute) must be specified. Use the third parameter to specify a primary key not already specified. For a HASH-only primary key, use `primary_key: true` as the third parameter. For a composite primary key (HASH and RANGE), in addition to the `primary_key` specification, set the third parameter on the range key attribute to `range_key: true`. There should be only one primary key (hash or composite) specified per table.

  To specify index details, such as provisioned throughput, create_if_not_exists/drop_if_exists, billing_mode, and global and local indexes, use the `options` keyword in `create table` and `alter table`, please see the examples below for greater detail.

  *Please note that `change` may not work as expected on rollback. We recommend specifying `up` and `down` instead.*

  ```
  Example:

  # Migration file 1:

    def change do
      create table(:post,
        primary_key: false,
        options: [
          global_indexes: [
            [index_name: "email_content",
             keys: [:email, :content],
             provisioned_throughput: [100, 100]] # [read_capacity, write_capacity]
            ],
          provisioned_throughput: [20,20]
        ]) do

        add :email,   :string, primary_key: true  # primary composite key
        add :title,   :string, range_key: true    # primary composite key
        add :content, :string
      end
    end


  # Migration file 2:

    def up do
      create_if_not_exists table(:rabbit,
        primary_key: false,
        options: [
          billing_mode: :pay_per_request,
          global_indexes: [
            [index_name: "name",
              keys: [:name]]
          ]
        ]) do

        add :id, :string, primary_key: true
        add :name, :string, hash_key: true
      end
    end

    def down do
      drop_if_exists table(:rabbit)
    end


  # Migration file 3:

    def up do
      alter table(:post,
        options: [
          global_indexes: [
            [index_name: "content",
             keys: [:content],
             create_if_not_exists: true,
             provisioned_throughput: [1,1],
             projection: [projection_type: :include, non_key_attributes: [:email]]]
          ]
        ]) do

        add :content, string
      end
    end

    def down do
      alter table(:post,
        options: [
          global_indexes: [
            [index_name: "content",
              drop_if_exists: true]]
        ]
      ) do
        remove :content
      end
    end


  # Migration file 4:

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

  # DynamoDB has restrictions on what can be done while tables are being created or
  # updated so we allow for a custom wait between requests if certain resource-access
  # errors are returned
  defp initial_wait(repo), do: RepoConfig.config_val(repo, :migration_initial_wait, 1000)
  defp wait_exponent(repo), do: RepoConfig.config_val(repo, :migration_wait_exponent, 1.05)
  # 10 minutes
  defp max_wait(repo), do: RepoConfig.config_val(repo, :migration_max_wait, 10 * 60 * 1000)

  # Adapted from line 620, https://github.com/michalmuskala/mongodb_ecto/blob/master/lib/mongo_ecto.ex
  def execute_ddl(_repo_meta, string, _opts) when is_binary(string) do
    raise ArgumentError,
      message: "Ecto.Adapters.Dynamodb does not support SQL statements in `execute`"
  end

  def execute_ddl(%{repo: repo, migration_source: migration_source}, command, options) do
    ecto_dynamo_log(:debug, "#{inspect(__MODULE__)}.execute_ddl", %{
      "#{inspect(__MODULE__)}.execute_ddl-params" => %{
        repo: repo,
        command: command,
        options: options
      }
    })

    # We provide a configuration option for migration_table_capacity
    updated_command = maybe_add_schema_migration_table_capacity(repo, migration_source, command)
    execute_ddl(repo, updated_command)
  end

  defp execute_ddl(repo, {:create_if_not_exists, %Ecto.Migration.Table{} = table, field_clauses}) do
    # :schema_migrations might be provided as an atom, while 'table.name' is now usually a binary
    table_name = if is_atom(table.name), do: Atom.to_string(table.name), else: table.name
    %{"TableNames" => table_list} = Dynamo.list_tables() |> ExAws.request!(ex_aws_config(repo))

    ecto_dynamo_log(:info, "#{inspect(__MODULE__)}.execute_ddl: :create_if_not_exists (table)")

    if not Enum.member?(table_list, table_name) do
      ecto_dynamo_log(
        :info,
        "#{inspect(__MODULE__)}.execute_ddl: create_if_not_exist: creating table",
        %{table_name: table.name}
      )

      create_table(repo, table_name, field_clauses, table.options)
    else
      ecto_dynamo_log(
        :info,
        "#{inspect(__MODULE__)}.execute_ddl: create_if_not_exists: table already exists.",
        %{table_name: table.name}
      )
    end

    {:ok, []}
  end

  defp execute_ddl(repo, {:create, %Ecto.Migration.Table{} = table, field_clauses}) do
    ecto_dynamo_log(:info, "#{inspect(__MODULE__)}.execute_ddl: create table: creating table", %{
      table_name: table.name
    })

    create_table(repo, table.name, field_clauses, table.options)

    {:ok, []}
  end

  defp execute_ddl(_repo, {command, %Ecto.Migration.Index{}}) do
    raise ArgumentError,
      message:
        "Ecto.Adapters.Dynamodb migration does not support '" <>
          to_string(command) <> " index', please use 'alter table' instead, see README.md"
  end

  defp execute_ddl(repo, {:drop, %Ecto.Migration.Table{} = table}) do
    ecto_dynamo_log(:info, "#{inspect(__MODULE__)}.execute_ddl: drop: removing table", %{
      table_name: table.name
    })

    Dynamo.delete_table(table.name) |> ExAws.request!(ex_aws_config(repo))

    {:ok, []}
  end

  defp execute_ddl(repo, {:drop_if_exists, %Ecto.Migration.Table{} = table}) do
    %{"TableNames" => table_list} = Dynamo.list_tables() |> ExAws.request!(ex_aws_config(repo))

    ecto_dynamo_log(:info, "#{inspect(__MODULE__)}.execute_ddl: drop_if_exists (table)")

    if Enum.member?(table_list, table.name) do
      ecto_dynamo_log(
        :info,
        "#{inspect(__MODULE__)}.execute_ddl: drop_if_exists: removing table",
        %{table_name: table.name}
      )

      Dynamo.delete_table(table.name) |> ExAws.request!(ex_aws_config(repo))
    else
      ecto_dynamo_log(
        :info,
        "#{inspect(__MODULE__)}.execute_ddl: drop_if_exists (table): table does not exist.",
        %{table_name: table.name}
      )
    end

    {:ok, []}
  end

  defp execute_ddl(repo, {:alter, %Ecto.Migration.Table{} = table, field_clauses}) do
    ecto_dynamo_log(:info, "#{inspect(__MODULE__)}.execute_ddl: :alter (table)")

    {delete, update, key_list} = build_delete_and_update(field_clauses)

    attribute_definitions =
      for {field, type} <- key_list do
        %{
          attribute_name: field,
          attribute_type: Dynamo.Encoder.atom_to_dynamo_type(convert_type(type))
        }
      end

    to_create =
      case table.options[:global_indexes] do
        nil ->
          nil

        global_indexes ->
          Enum.filter(global_indexes, fn index ->
            if index[:keys],
              do: index[:keys] |> Enum.all?(fn key -> Keyword.has_key?(key_list, key) end)
          end)
      end

    create = build_secondary_indexes(to_create) |> Enum.map(fn index -> %{create: index} end)

    data =
      %{global_secondary_index_updates: create ++ delete ++ update}
      |> Map.merge(
        if create == [], do: %{}, else: %{attribute_definitions: attribute_definitions}
      )

    result = update_table_recursive(repo, table, data, initial_wait(repo), 0)
    set_ttl(repo, table.name, table.options)
    result
  end

  defp execute_ddl(_repo, {command, struct, _}),
    do:
      raise(ArgumentError,
        message:
          "#{inspect(__MODULE__)}.execute_ddl error: '" <>
            to_string(command) <>
            " #{extract_ecto_migration_type(inspect(struct.__struct__))}' is not supported"
      )

  defp execute_ddl(_repo, {command, struct}),
    do:
      raise(ArgumentError,
        message:
          "#{inspect(__MODULE__)}.execute_ddl error: '" <>
            to_string(command) <>
            " #{extract_ecto_migration_type(inspect(struct.__struct__))}' is not supported"
      )

  # We provide a configuration option for migration_table_capacity
  defp maybe_add_schema_migration_table_capacity(
         repo,
         migration_source,
         {:create_if_not_exists, %Ecto.Migration.Table{} = table, field_clauses} = command
       ) do
    if to_string(table.name) == migration_source do
      migration_table_capacity = RepoConfig.config_val(repo, :migration_table_capacity, [1, 1])

      updated_table_options =
        case table.options do
          nil -> [provisioned_throughput: migration_table_capacity]
          opts -> Keyword.put(opts, :provisioned_throughput, migration_table_capacity)
        end

      {:create_if_not_exists, Map.put(table, :options, updated_table_options), field_clauses}
    else
      command
    end
  end

  defp maybe_add_schema_migration_table_capacity(_repo, _migration_source, command), do: command

  defp poll_table(repo, table_name) do
    table_info = Dynamo.describe_table(table_name) |> ExAws.request(ex_aws_config(repo))

    case table_info do
      {:ok, %{"Table" => table}} ->
        ecto_dynamo_log(:info, "#{inspect(__MODULE__)}.poll_table: table", %{
          "#{inspect(__MODULE__)}.poll_table-table" => %{table_name: table_name, table: table}
        })

        table

      {:error, error_tuple} ->
        ecto_dynamo_log(
          :info,
          "#{inspect(__MODULE__)}.poll_table: error attempting to poll table. Stopping...",
          %{
            "#{inspect(__MODULE__)}.poll_table-error" => %{
              table_name: table_name,
              error_tuple: error_tuple
            }
          }
        )

        raise ExAws.Error, message: "ExAws Request Error! #{inspect(error_tuple)}"
    end
  end

  defp list_non_active_statuses(table_info) do
    secondary_index_statuses =
      (table_info["GlobalSecondaryIndexes"] || [])
      |> Enum.map(fn index -> {index["IndexName"], index["IndexStatus"]} end)

    ([{"TableStatus", table_info["TableStatus"]}] ++ secondary_index_statuses)
    |> Enum.filter(fn {_, y} -> y != "ACTIVE" end)
  end

  defp update_table_recursive(repo, table, data, wait_interval, time_waited) do
    ecto_dynamo_log(:info, "#{inspect(__MODULE__)}.update_table_recursive: polling table", %{
      table_name: table.name
    })

    table_info = poll_table(repo, table.name)
    non_active_statuses = list_non_active_statuses(table_info)

    if non_active_statuses != [] do
      ecto_dynamo_log(
        :info,
        "#{inspect(__MODULE__)}.update_table_recursive: non-active status found in table",
        %{
          "#{inspect(__MODULE__)}.update_table_recursive-non_active_status" => %{
            table_name: table.name,
            non_active_statuses: non_active_statuses
          }
        }
      )

      to_wait =
        if time_waited == 0,
          do: wait_interval,
          else: round(:math.pow(wait_interval, wait_exponent(repo)))

      if time_waited + to_wait <= max_wait(repo) do
        ecto_dynamo_log(
          :info,
          "#{inspect(__MODULE__)}.update_table_recursive: waiting #{inspect(to_wait)} milliseconds (waited so far: #{
            inspect(time_waited)
          } ms)"
        )

        :timer.sleep(to_wait)
        update_table_recursive(repo, table, data, to_wait, time_waited + to_wait)
      else
        raise "Wait exceeding configured max wait time, stopping migration at update table #{
                inspect(table.name)
              }...\nData: #{inspect(data)}"
      end
    else
      # Before passinng the index data to Dynamo, do a little extra preparation:
      # - filter the data based on the presence of :create_if_not_exists or :drop_if_exists_options
      # - if the user is running against Dynamo's local development version (in config, dynamodb_local: true),
      #   we may need to add provisioned_throughput to indexes to handle situations where the local table is provisioned
      #   but the index will be added to a production table that is on-demand.
      requests = make_safe_index_requests(repo, data, table)
      prepared_data = maybe_default_throughput_local(repo, requests, table_info)

      case prepared_data[:global_secondary_index_updates] do
        [] ->
          {:ok, []}

        _ ->
          result =
            Dynamo.update_table(table.name, prepared_data) |> ExAws.request(ex_aws_config(repo))

          ecto_dynamo_log(
            :info,
            "#{inspect(__MODULE__)}.update_table_recursive: DynamoDB/ExAws response",
            %{"#{inspect(__MODULE__)}.update_table_recursive-result" => inspect(result)}
          )

          case result do
            {:ok, _} ->
              ecto_dynamo_log(
                :info,
                "#{inspect(__MODULE__)}.update_table_recursive: table altered successfully.",
                %{table_name: table.name}
              )

              {:ok, []}

            {:error, {error, _message}}
            when error in [
                   "LimitExceededException",
                   "ProvisionedThroughputExceededException",
                   "ThrottlingException"
                 ] ->
              to_wait =
                if time_waited == 0,
                  do: wait_interval,
                  else: round(:math.pow(wait_interval, wait_exponent(repo)))

              if time_waited + to_wait <= max_wait(repo) do
                ecto_dynamo_log(
                  :info,
                  "#{inspect(__MODULE__)}.update_table_recursive: #{inspect(error)} ... waiting #{
                    inspect(to_wait)
                  } milliseconds (waited so far: #{inspect(time_waited)} ms)"
                )

                :timer.sleep(to_wait)
                update_table_recursive(repo, table, data, to_wait, time_waited + to_wait)
              else
                raise "#{inspect(error)} ... wait exceeding configured max wait time, stopping migration at update table #{
                        inspect(table.name)
                      }...\nData: #{inspect(data)}"
              end

            {:error, error_tuple} ->
              ecto_dynamo_log(
                :info,
                "#{inspect(__MODULE__)}.update_table_recursive: error attempting to update table. Stopping...",
                %{
                  "#{inspect(__MODULE__)}.update_table_recursive-error" => %{
                    table_name: table.name,
                    error_tuple: error_tuple,
                    data: inspect(data)
                  }
                }
              )

              raise ExAws.Error, message: "ExAws Request Error! #{inspect(error_tuple)}"
          end
      end
    end
  end

  # When running against local Dynamo, we may need to perform some additional special handling for indexes.
  defp maybe_default_throughput_local(repo, data, table_info),
    do:
      do_maybe_default_throughput_local(
        RepoConfig.config_val(repo, :dynamodb_local),
        data,
        table_info
      )

  # When running against production Dynamo, don't alter the index data. Production DDB will reject the migration if there's
  # disagreement between the table's billing mode and the options specified in the index migration.
  defp do_maybe_default_throughput_local(false, data, _table_info), do: data

  # However, when runnning against the local dev version of Dynamo, it will hang on index migrations
  # that attempt to add an index to a provisioned table without specifying throughput. The problem doesn't exist
  # the other way around; local Dynamo will ignore throughput specified for indexes where the table is on-demand.
  defp do_maybe_default_throughput_local(_using_ddb_local, data, table_info) do
    # As of spring 2020, production and local DDB (version 1.11.478) no longer return a "BillingModeSummary" key
    # for provisioned tables. In order to allow for backwards compatibility, we've retained the original condition
    # following the or in the if statement below, but that can probably be removed in the future.
    if not Map.has_key?(table_info, "BillingModeSummary") or
         table_info["BillingModeSummary"]["BillingMode"] == "PROVISIONED" do
      updated_global_secondary_index_updates =
        for index_update <- data.global_secondary_index_updates,
            {action, index_info} <- index_update do
          if action in [:create, :update] do
            # If the table is provisioned but the index_info lacks :provisioned_throughput, add a map of "default" values.
            %{
              action =>
                Map.put_new(index_info, :provisioned_throughput, %{
                  read_capacity_units: 1,
                  write_capacity_units: 1
                })
            }
          else
            index_update
          end
        end

      Map.replace!(data, :global_secondary_index_updates, updated_global_secondary_index_updates)
    else
      data
    end
  end

  defp create_table(repo, table_name, field_clauses, options) do
    {key_schema, key_definitions} =
      build_key_schema_and_definitions(table_name, field_clauses, options)

    [read_capacity, write_capacity] = options[:provisioned_throughput] || [nil, nil]
    global_indexes = build_secondary_indexes(options[:global_indexes])
    local_indexes = build_secondary_indexes(options[:local_indexes])
    billing_mode = options[:billing_mode] || :provisioned

    create_table_recursive(
      repo,
      table_name,
      key_schema,
      key_definitions,
      read_capacity,
      write_capacity,
      global_indexes,
      local_indexes,
      billing_mode,
      initial_wait(repo),
      0
    )

    set_ttl(repo, table_name, options)
  end

  defp create_table_recursive(
         repo,
         table_name,
         key_schema,
         key_definitions,
         read_capacity,
         write_capacity,
         global_indexes,
         local_indexes,
         billing_mode,
         wait_interval,
         time_waited
       ) do
    result =
      Dynamo.create_table(
        table_name,
        key_schema,
        key_definitions,
        read_capacity,
        write_capacity,
        global_indexes,
        local_indexes,
        billing_mode
      )
      |> ExAws.request(ex_aws_config(repo))

    ecto_dynamo_log(
      :info,
      "#{inspect(__MODULE__)}.create_table_recursive: DynamoDB/ExAws response",
      %{"#{inspect(__MODULE__)}.create_table_recursive-result" => inspect(result)}
    )

    case result do
      {:ok, _} ->
        ecto_dynamo_log(
          :info,
          "#{inspect(__MODULE__)}.create_table_recursive: table created successfully.",
          %{table_name: table_name}
        )

        :ok

      {:error, {error, _message}}
      when error in [
             "LimitExceededException",
             "ProvisionedThroughputExceededException",
             "ThrottlingException"
           ] ->
        to_wait =
          if time_waited == 0,
            do: wait_interval,
            else: round(:math.pow(wait_interval, wait_exponent(repo)))

        if time_waited + to_wait <= max_wait(repo) do
          ecto_dynamo_log(
            :info,
            "#{inspect(__MODULE__)}.create_table_recursive: #{inspect(error)} ... waiting #{
              inspect(to_wait)
            } milliseconds (waited so far: #{inspect(time_waited)} ms)"
          )

          :timer.sleep(to_wait)

          create_table_recursive(
            repo,
            table_name,
            key_schema,
            key_definitions,
            read_capacity,
            write_capacity,
            global_indexes,
            local_indexes,
            billing_mode,
            to_wait,
            time_waited + to_wait
          )
        else
          raise "#{inspect(error)} ... wait exceeding configured max wait time, stopping migration at create table #{
                  inspect(table_name)
                }..."
        end

      {:error, error_tuple} ->
        ecto_dynamo_log(
          :info,
          "#{inspect(__MODULE__)}.create_table_recursive: error attempting to create table. Stopping...",
          %{
            "#{inspect(__MODULE__)}.create_table_recursive-error" => %{
              table_name: table_name,
              error_tuple: error_tuple
            }
          }
        )

        raise ExAws.Error, message: "ExAws Request Error! #{inspect(error_tuple)}"
    end
  end

  defp set_ttl(_repo, _table_name, nil), do: :ok

  defp set_ttl(repo, table_name, table_options) do
    if Keyword.has_key?(table_options, :ttl_attribute) do
      do_set_ttl(repo, table_name, table_options[:ttl_attribute])
    end
  end

  defp do_set_ttl(repo, table_name, nil), do: do_set_ttl(repo, table_name, "ttl", false)

  defp do_set_ttl(repo, table_name, attribute, enabled? \\ true) do
    result =
      table_name
      |> Dynamo.update_time_to_live(attribute, enabled?)
      |> ExAws.request(ex_aws_config(repo))

    case result do
      {:error, {"ValidationException", "TimeToLive is already disabled"}} when not enabled? -> :ok
      {:ok, _} -> :ok
    end
  end

  defp build_key_schema_and_definitions(table_name, field_clauses, options) do
    secondary_index_atoms =
      ((options[:global_indexes] || []) ++ (options[:local_indexes] || []))
      |> Enum.flat_map(fn indexes -> indexes[:keys] || [] end)

    {hash_key, range_key, key_list} =
      Enum.reduce(field_clauses, {nil, nil, []}, fn {cmd, field, type, opts},
                                                    {hash, range, key_list} ->
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

    if is_nil(hash_key),
      do:
        raise(
          "#{inspect(__MODULE__)}.build_key_schema error: no primary key was found for table #{
            inspect(table_name)
          }. Please specify one primary key in migration."
        )

    key_definitions = for {field, type} <- key_list, do: {field, convert_type(type)}

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
      %{
        index_name: index[:index_name],
        key_schema: build_secondary_key_schema(index[:keys]),
        projection: build_secondary_projection(index[:projection])
      }
      |> maybe_add_throughput(index[:provisioned_throughput])
    end)
  end

  defp build_secondary_key_schema(keys) do
    case keys do
      [hash] ->
        [%{attribute_name: Atom.to_string(hash), key_type: "HASH"}]

      [hash, range] ->
        [
          %{attribute_name: Atom.to_string(hash), key_type: "HASH"},
          %{attribute_name: Atom.to_string(range), key_type: "RANGE"}
        ]
    end
  end

  defp build_secondary_projection(nil), do: %{projection_type: "ALL"}

  defp build_secondary_projection(projection) do
    case projection[:projection_type] do
      :include ->
        %{projection_type: "INCLUDE", non_key_attributes: projection[:non_key_attributes]}

      type when type in [:all, :keys_only] ->
        %{projection_type: ExAws.Utils.upcase(type)}
    end
  end

  defp build_delete_and_update(field_clauses) do
    Enum.reduce(proper_list(field_clauses), {[], [], []}, fn field_clause,
                                                             {delete, update, key_list} ->
      case field_clause do
        {:remove, field} ->
          {[%{delete: %{index_name: field}} | delete], update, key_list}

        {:modify, field, _type, opts} ->
          {delete,
           [
             %{
               update: %{index_name: field} |> maybe_add_throughput(opts[:provisioned_throughput])
             }
             | update
           ], key_list}

        {:add, field, type, _opts} ->
          {delete, update, [{field, type} | key_list]}

        _ ->
          {delete, update, key_list}
      end
    end)
  end

  # Include provisioned_throughput only when it has been explicitly provided.
  defp maybe_add_throughput(index_map, nil), do: Map.merge(index_map, %{})

  defp maybe_add_throughput(index_map, [read_capacity, write_capacity]),
    do:
      Map.merge(index_map, %{
        provisioned_throughput: %{
          read_capacity_units: read_capacity,
          write_capacity_units: write_capacity
        }
      })

  defp convert_type(type) do
    case type do
      :bigint -> :number
      :serial -> :number
      :binary -> :blob
      :binary_id -> :blob
      _ -> type
    end
  end

  # Compare the list of existing global secondary indexes with the indexes flagged with
  # :create_if_not_exists and/or :drop_if_exists options and filter them accordingly -
  # skipping any that already exist or do not exist, respectively.
  defp make_safe_index_requests(repo, data, table) do
    existing_index_names = list_existing_global_secondary_index_names(repo, table.name)
    {create_if_not_exist_indexes, drop_if_exists_indexes} = get_existence_options(table.options)

    filter_fun =
      &assess_conditional_index_operations(
        &1,
        existing_index_names,
        create_if_not_exist_indexes,
        drop_if_exists_indexes
      )

    filtered_global_secondary_index_updates =
      Enum.filter(data[:global_secondary_index_updates], filter_fun)

    # In the case of creating an index, the data will have an :attribute_definitions key,
    # which has additional info about the index being created. If that index has been removed
    # in this filtering process, remove its :attribute_definitions as well.
    # Note that this is not technically necessary and does not affect the behavior of the adapter.
    # If the index is missing from filtered_global_secondary_index_updates, unmatched data[:attribute_definitions]
    # will be overlooked in the call to Dynamo.update_table(). However, to avoid passing around unused data,
    # we have opted to filter the attribute_definitions to match the global_secondary_index_updates.
    filtered_attribute_definitions =
      case data[:attribute_definitions] do
        nil ->
          nil

        _ ->
          Enum.filter(data[:attribute_definitions], fn attribute_definition ->
            attribute_name = Atom.to_string(attribute_definition.attribute_name)

            if attribute_name not in create_if_not_exist_indexes,
              do: true,
              else: attribute_name not in existing_index_names
          end)
      end

    %{global_secondary_index_updates: filtered_global_secondary_index_updates}
    |> Map.merge(
      if is_nil(filtered_attribute_definitions),
        do: %{},
        else: %{attribute_definitions: filtered_attribute_definitions}
    )
  end

  # Check for the presence/absence of the option and assess its relationship to the list of existing indexes
  defp assess_conditional_index_operations(
         global_secondary_index_update,
         existing_index_names,
         create_if_not_exist_indexes,
         drop_if_exists_indexes
       ) do
    [{operation, index_info}] = Map.to_list(global_secondary_index_update)

    index_name =
      if Kernel.is_atom(index_info.index_name),
        do: Atom.to_string(index_info.index_name),
        else: index_info.index_name

    assess_index_operation(
      operation,
      index_name,
      index_name in create_if_not_exist_indexes,
      index_name in drop_if_exists_indexes,
      existing_index_names
    )
  end

  # If an existence option has not been provided, or if the action is an update, return 'true' so
  # the index is included in the results of Enum.filter(). Otherwise, compare :create_if_not_exists
  # and :drop_if_exists with the list of existing indexes and decide how to proceed.
  defp assess_index_operation(
         :create,
         index_name,
         in_create_if_not_exist_indexes,
         _in_drop_if_exists_indexes,
         existing_index_names
       )
       when in_create_if_not_exist_indexes do
    if index_name not in existing_index_names do
      true
    else
      ecto_dynamo_log(
        :info,
        "#{inspect(__MODULE__)}.assess_index_operation: index already exists. Skipping create...",
        %{"#{inspect(__MODULE__)}.assess_index_operation_skip-create-index" => index_name}
      )

      false
    end
  end

  defp assess_index_operation(
         :delete,
         index_name,
         _in_create_if_not_exist_indexes,
         in_drop_if_exists_indexes,
         existing_index_names
       )
       when in_drop_if_exists_indexes do
    if index_name in existing_index_names do
      true
    else
      ecto_dynamo_log(
        :info,
        "#{inspect(__MODULE__)}.assess_index_operation: index does not exist. Skipping drop...",
        %{"#{inspect(__MODULE__)}.assess_index_operation_skip-drop-index" => index_name}
      )

      false
    end
  end

  defp assess_index_operation(
         _operation,
         _index_name,
         _in_create_if_not_exist_indexes,
         _in_drop_if_exists_indexes,
         _existing_index_names
       ),
       do: true

  defp list_existing_global_secondary_index_names(repo, table_name) do
    case poll_table(repo, table_name)["GlobalSecondaryIndexes"] do
      nil ->
        []

      existing_indexes ->
        Enum.map(existing_indexes, fn existing_index -> existing_index["IndexName"] end)
    end
  end

  # Return a tuple with all of the indexes flagged with :create_if_not_exists or :drop_if_exists options
  defp get_existence_options(table_options) do
    case table_options do
      nil ->
        {[], []}

      _ ->
        global_index_options = Keyword.get(table_options, :global_indexes, [])

        {parse_existence_options(global_index_options, :create_if_not_exists),
         parse_existence_options(global_index_options, :drop_if_exists)}
    end
  end

  # Sort the existence options based on the option provided
  defp parse_existence_options(global_index_options, option) do
    for global_index_option <- global_index_options,
        Keyword.has_key?(global_index_option, option),
        do: global_index_option[:index_name]
  end

  defp proper_list(l), do: proper_list(l, [])
  defp proper_list([], res), do: Enum.reverse(res)
  defp proper_list([a | b], res) when not is_list(b), do: Enum.reverse([a | res])
  defp proper_list([a | b], res), do: proper_list(b, [a | res])

  defp extract_ecto_migration_type(str),
    do: str |> String.split(".") |> List.last() |> String.downcase()
end
