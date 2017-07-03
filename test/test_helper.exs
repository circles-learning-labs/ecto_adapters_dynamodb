# Load all our support files first, since we need some of them to define our helper modules

files = File.ls!("./test/support") |> Enum.filter(&(String.ends_with?(&1, [".ex", ".exs"])))

Enum.each files, fn(file) ->
  Code.require_file "support/#{file}", __DIR__
end

defmodule TestHelper do
  alias ExAws.Dynamo
  alias Ecto.Adapters.DynamoDB.TestRepo

  def setup_all(table_name) do
    IO.puts "starting test repo"
    TestRepo.start_link()

    IO.puts "deleting any leftover test table that may exist"
    Dynamo.delete_table(table_name) |> ExAws.request

    IO.puts "creating test table"
    # Only need to define types for indexed fields:
    key_definitions = %{id: :string, email: :string}
    indexes = [%{
               index_name: "email",
               key_schema: [%{
                            attribute_name: "email",
                            key_type: "HASH",
               }],
               provisioned_throughput: %{
                 read_capacity_units: 100,
                 write_capacity_units: 100,
               },
               projection: %{projection_type: "ALL"}
    }]
    Dynamo.create_table(table_name, [id: :hash], key_definitions, 100, 100, indexes, []) |> ExAws.request!

    :ok
  end
end

defmodule TestGenerators do
  use EQC

  alias Ecto.Adapters.DynamoDB.TestRepo
  alias Ecto.Adapters.DynamoDB.TestSchema.Person

  def nonempty_str() do
    such_that s <- utf8() do
      # Ecto.Changeset.validate_required checks for all-whitespace
      # strings in addition to empty ones, hence the trimming:
      String.trim_leading(s) != ""
    end
  end

  def circle_list() do
    non_empty(list(nonempty_str()))
  end

  def person_generator() do
    let {id, first, last, age, email, pass, circles} <-
        {nonempty_str(), nonempty_str(), nonempty_str(), int(),
          nonempty_str(), nonempty_str(), circle_list()} do
      %Person{
        id: id,
        first_name: first,
        last_name: last,
        age: age,
        email: email,
        password: pass,
        circles: circles
      }
    end
  end
end

ExUnit.start()
