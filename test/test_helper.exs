# Load all our support files first, since we need some of them to define our helper modules

files = File.ls!("./test/support") |> Enum.filter(&String.ends_with?(&1, [".ex", ".exs"]))

Enum.each(files, fn file ->
  Code.require_file("support/#{file}", __DIR__)
end)

defmodule TestHelper do
  alias ExAws.Dynamo
  alias Ecto.Adapters.DynamoDB
  alias Ecto.Adapters.DynamoDB.TestRepo

  def setup_all() do
    IO.puts("========== main test suite ==========")

    IO.puts("starting test repo")
    TestRepo.start_link()

    IO.puts("deleting any leftover test tables that may exist")
    Dynamo.delete_table("test_person") |> request()
    Dynamo.delete_table("test_book_page") |> request()
    Dynamo.delete_table("test_planet") |> request()
    Dynamo.delete_table("test_fruit") |> request()

    IO.puts("creating test_person table")
    # Only need to define types for indexed fields:
    key_definitions = %{id: :string, email: :string, first_name: :string, age: :number}

    indexes = [
      %{
        index_name: "email",
        key_schema: [
          %{
            attribute_name: "email",
            key_type: "HASH"
          }
        ],
        provisioned_throughput: %{
          read_capacity_units: 100,
          write_capacity_units: 100
        },
        projection: %{projection_type: "ALL"}
      },
      %{
        index_name: "first_name",
        key_schema: [
          %{
            attribute_name: "first_name",
            key_type: "HASH"
          }
        ],
        provisioned_throughput: %{
          read_capacity_units: 100,
          write_capacity_units: 100
        },
        projection: %{projection_type: "ALL"}
      },
      %{
        index_name: "first_name_email",
        key_schema: [
          %{
            attribute_name: "first_name",
            key_type: "HASH"
          },
          %{
            attribute_name: "email",
            key_type: "RANGE"
          }
        ],
        provisioned_throughput: %{
          read_capacity_units: 100,
          write_capacity_units: 100
        },
        projection: %{projection_type: "ALL"}
      },
      %{
        index_name: "first_name_age",
        key_schema: [
          %{
            attribute_name: "first_name",
            key_type: "HASH"
          },
          %{
            attribute_name: "age",
            key_type: "RANGE"
          }
        ],
        provisioned_throughput: %{
          read_capacity_units: 100,
          write_capacity_units: 100
        },
        projection: %{projection_type: "ALL"}
      },
      %{
        index_name: "age_first_name",
        key_schema: [
          %{
            attribute_name: "age",
            key_type: "HASH"
          },
          %{
            attribute_name: "first_name",
            key_type: "RANGE"
          }
        ],
        provisioned_throughput: %{
          read_capacity_units: 100,
          write_capacity_units: 100
        },
        projection: %{projection_type: "ALL"}
      }
    ]

    Dynamo.create_table("test_person", [id: :hash], key_definitions, 100, 100, indexes, [])
    |> request()

    IO.puts("creating test_book_page table")
    key_definitions = %{id: :string, page_num: :number}

    Dynamo.create_table(
      "test_book_page",
      [id: :hash, page_num: :range],
      key_definitions,
      100,
      100,
      [],
      []
    )
    |> request()

    IO.puts("creating test_planet table")
    key_definitions = %{id: :string, name: :string, mass: :number}

    indexes = [
      %{
        index_name: "name_mass",
        key_schema: [
          %{
            attribute_name: "name",
            key_type: "HASH"
          },
          %{
            attribute_name: "mass",
            key_type: "RANGE"
          }
        ],
        provisioned_throughput: %{
          read_capacity_units: 100,
          write_capacity_units: 100
        },
        projection: %{projection_type: "ALL"}
      }
    ]

    Dynamo.create_table(
      "test_planet",
      [id: :hash, name: :range],
      key_definitions,
      100,
      100,
      indexes,
      []
    )
    |> request()

    IO.puts("creating test_fruit table")

    Dynamo.create_table("test_fruit", [id: :hash], %{id: :string}, 100, 100, [], [])
    |> request()

    IO.puts("creating keyword table")

    Dynamo.create_table("test_keyword", [key: :hash], %{key: :string}, 100, 100, [], [])
    |> request()

    :ok
  end

  def setup_all(:migration) do
    IO.puts("========== migration test suite ==========")
    Dynamo.delete_table("test_schema_migrations") |> request()

    IO.puts("starting test repo")
    TestRepo.start_link()
  end

  def on_exit() do
    IO.puts("deleting main test tables")
    Dynamo.delete_table("test_person") |> request()
    Dynamo.delete_table("test_book_page") |> request()
    Dynamo.delete_table("test_planet") |> request()
    Dynamo.delete_table("test_fruit") |> request()
    Dynamo.delete_table("test_fruit") |> request()
    Dynamo.delete_table("test_keyword") |> request()
  end

  def on_exit(:migration) do
    IO.puts("deleting migration test tables")

    # Except for test_schema_migrations, these tables should be deleted during the "down" migration test.
    # Just to make sure, we'll clean up here anyway.
    Dynamo.delete_table("dog") |> request()
    Dynamo.delete_table("cat") |> request()
    Dynamo.delete_table("stream") |> request()
    Dynamo.delete_table("rabbit") |> request()
    Dynamo.delete_table("billing_mode_test") |> request()
    Dynamo.delete_table("test_schema_migrations") |> request()
  end

  defp request(operation), do: ExAws.request(operation, DynamoDB.ex_aws_config(TestRepo))
end

# Skip EQC testing if we don't have it installed:
if Code.ensure_compiled(:eqc) == {:module, :eqc} do
  defmodule TestGenerators do
    use EQC

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
      person_with_id(nonempty_str())
    end

    def person_with_id(key_gen) do
      let {id, first, last, age, email, pass, circles} <-
            {key_gen, nonempty_str(), nonempty_str(), int(), nonempty_str(), nonempty_str(),
             circle_list()} do
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
else
  IO.puts("Could not find eqc module - skipping property based testing!")
end

# Set seed: 0 so that tests are run in order - critical for our migration tests.
ExUnit.start(seed: 0)
