defmodule AdapterStateEqcTest do
  use ExUnit.Case
  use EQC.ExUnit  
  use EQC.StateM

  import Ecto.Query
  import TestGenerators

  alias Ecto.Adapters.DynamoDB.TestRepo
  alias Ecto.Adapters.DynamoDB.TestSchema.Person

  @keys [:a, :b, :c, :d, :e]

  setup_all do
    TestHelper.setup_all("test_person")
  end

  defmodule State do
    defstruct db: %{}
  end

  # Generators
  def key, do: oneof(@keys)
  def value, do: person_with_id(key())

  def key_list, do: @keys |> Enum.shuffle |> sublist
  def value_list do
    # Generates a list of people, all with different keys:
    let keys <- key_list() do
      for k <- keys, do: person_with_id(k)
    end
  end

  # Properties
  property "stateful adapter test" do
    forall cmds <- commands(__MODULE__) do
      for k <- @keys, do: delete_row(k)

      #results = run_commands(cmds)
      #pretty_commands(cmds, results, results.result)
      true
    end
  end

  # Helper functions

  def delete_row(key) do
    id = Atom.to_string(key)
    TestRepo.delete_all((from p in Person, where: p.id == ^id))
  end

  # StateM callbacks

  # We'll keep a simple map as our state which represents
  # the expected contents of the database
  def initial_state, do: %State{}

  # INSERT

  def insert_args(_s) do
    [value()]
  end

  def insert(value) do
    TestRepo.insert! Person.changeset(value)
  end

  def insert_post(_s, [value], result) do
    ensure value == result
  end

  def insert_next(s, _result, [value]) do
    new_db = Map.put(s.db, value.id, value)
    %State{s | db: new_db}
  end

  # INSERT_ALL

  # GET

  def get_args(_s) do
    [key()]
  end

  def get(key) do
    TestRepo.get(Person, key)
  end

  def get_post(s, [key], result) do
    case Map.get(s.db, key) do
      nil ->
        ensure result == nil
      value ->
        ensure result == value
    end
  end
end
