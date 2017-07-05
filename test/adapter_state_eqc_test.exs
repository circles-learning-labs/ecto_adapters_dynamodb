defmodule AdapterStateEqcTest do
  use ExUnit.Case
  use EQC.ExUnit  
  use EQC.StateM

  import Ecto.Query
  import TestGenerators

  alias Ecto.Adapters.DynamoDB.TestRepo
  alias Ecto.Adapters.DynamoDB.TestSchema.Person

  @keys ~w[a b c d e]

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

  def change_list do
    let fs <- fields() do
      for {name, type} <- fs, into: %{}, do: {name, gen_field_val(type)}
    end
  end

  def fields do
    Person.get_fields()
    |> Enum.filter(&(elem(&1, 1) != :binary_id))
    |> Enum.shuffle # order probably doesn't matter here, but can't hurt to mix it up!
    |> sublist
  end

  def gen_field_val(:string), do: nonempty_str()
  def gen_field_val(:integer), do: int()
  def gen_field_val({:array, type}), do: type |> gen_field_val |> list |> non_empty

  # Properties
  property "stateful adapter test" do
    forall cmds <- commands(__MODULE__) do
      for k <- @keys, do: delete_row(k)

      results = run_commands(cmds)
      pretty_commands(cmds, results, results[:result] == :ok)
    end
  end

  # Helper functions

  def delete_row(id) do
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
    value |> Person.changeset |> TestRepo.insert
  end

  def insert_post(s, [value], {:ok, result}) do
    if !Map.has_key?(s.db, value.id) do
      value = Map.delete(value, :__meta__)
      result = Map.delete(result, :__meta__)
      value == result
    else
      # If we already have this key in our db, we
      # shouldn't have gotten back a successful result
      false
    end
  end
  def insert_post(s, [value], {:error,
                               %Ecto.Changeset{errors: [id: {"has already been taken", []}]}}) do
    Map.has_key?(s.db, value.id)
  end
  def insert_post(_s, _args, _res) do
    false
  end

  def insert_next(s, _result, [value]) do
    new_db = Map.put_new(s.db, value.id, value)
    %State{s | db: new_db}
  end

  # INSERT_ALL

  def insert_all_args(_s) do
    [value_list()]
  end

  def insert_all(values) do
    map_values = for v <- values, do: Map.drop(v, [:__meta__, :__struct__])
    TestRepo.insert_all(Person, map_values)
  end

  def insert_all_post(_s, [values], result) do
    result == {length(values), nil}
  end

  def insert_all_next(s, _result, [values]) do
    new_db = for v <- values, into: s.db, do: {v.id, v}
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
        result == nil
      value ->
        result == value
    end
  end

  # UPDATE

  def update_args(_s) do
    [key(), change_list()]
  end

  def update(key, change_list) do
    case TestRepo.get(Person, key) do
      nil ->
        :not_found
      res ->
        res
        |> Person.changeset(change_list)
        |> TestRepo.update!
    end
  end

  def update_post(s, [key, change_list], result) do
    case Map.get(s.db, key) do
      nil ->
        result == :not_found
      _ ->
        # TODO check return value of update! here?
        true
    end
  end

  def update_next(s, _result, [key, change_list]) do
    case Map.get(s.db, key) do
      nil ->
        s
      val ->
        new_val = Map.merge(val, change_list)
        new_db = %{s.db | key => new_val}
        %State{s | db: new_db}
    end
  end
end
