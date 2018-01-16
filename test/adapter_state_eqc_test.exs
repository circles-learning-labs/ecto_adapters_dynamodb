# Skip EQC testing if we don't have it installed:
if Code.ensure_compiled?(:eqc) do
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
    TestHelper.setup_all()
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
  def gen_field_val({:embed, %Ecto.Embedded{cardinality: :many}}), do: []

  def insert_opts do
    oneof([[on_conflict: :nothing],
           [on_conflict: :replace_all],
           [on_conflict: :raise],
           [] # Should have same behavior as :raise, per Ecto docs
    ])
  end

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

  def cmp_people(a, b) do
    a = Map.delete(a, :__meta__)
    b = Map.delete(b, :__meta__)
    a == b
  end

  # StateM callbacks

  # We'll keep a simple map as our state which represents
  # the expected contents of the database
  def initial_state, do: %State{}

  # INSERT

  def insert_args(_s) do
    [value(), insert_opts()]
  end

  def insert(value, opts) do
    value |> Person.changeset |> TestRepo.insert(opts)
  end

  def insert_post(s, [value, opts], result) do
    on_conflict = Keyword.get(opts, :on_conflict, :raise)
    value_exists = Map.has_key?(s.db, value.id)

    case {on_conflict, value_exists, result} do
      {:raise, true, {:error, %Ecto.Changeset{errors: [id: {"has already been taken", []}]}}} ->
        true
      {:nothing, true, {:ok, result_value}} ->
        # The result should be the value we passed in with the primary key set to nil
        cmp_people(%{value | id: nil}, result_value)
      {_, _, {:ok, result_value}} ->
        cmp_people(value, result_value)
    end
  end

  def insert_next(s, _result, [value, opts]) do
    on_conflict = Keyword.get(opts, :on_conflict, :raise)
    new_db = case on_conflict do
      :replace_all ->
        Map.put(s.db, value.id, value)
      _ ->
        Map.put_new(s.db, value.id, value)
    end
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
      state_val ->
        next_val = Map.merge(state_val, change_list)
        cmp_people(next_val, result)
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

  # DELETE

  def delete_args(_s) do
    [key()]
  end

  def delete(key) do
    try do
      TestRepo.delete(%Person{id: key})
    rescue
      # Raising a "StaleEntryError" sure seems like a weird, unintuitive way
      # to signal that we tried to delete a non-existent value, but this is
      # also the way it works for other adapters so I'm assuming this is
      # normal...🤔
      Ecto.StaleEntryError -> :not_found
    end
  end

  def delete_post(s, [key], {:ok, _}) do
    Map.has_key?(s.db, key)
  end
  def delete_post(s, [key], :not_found) do
    !Map.has_key?(s.db, key)
  end

  def delete_next(s, _result, [key]) do
    new_db = Map.delete(s.db, key)
    %State{s | db: new_db}
  end
end
end
