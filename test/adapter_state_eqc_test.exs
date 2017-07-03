defmodule AdapterStateEqcTest do
  use ExUnit.Case
  use EQC.ExUnit  
  use EQC.StateM

  import Ecto.Query

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
  def value, do: TestGenerators.person_generator()

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
    [key(), value()]
  end

  def insert(key, value) do
    value = %{value | id: Atom.to_string(key)}
    TestRepo.insert! Person.changeset(value)
    value
  end

  def insert_post(_s, [key, value], result) do
    ensure key == result.id
  end

  def insert_next(s, result, [key, _value]) do
    new_db = Map.put(s.db, key, result)
    %State{s | db: new_db}
  end

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
