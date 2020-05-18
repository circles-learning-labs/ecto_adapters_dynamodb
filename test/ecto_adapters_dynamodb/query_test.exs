defmodule Ecto.Adapters.DynamoDB.Query.Test do
  @moduledoc """
  Unit tests for the query module.
  """
  use ExUnit.Case
  import Ecto.Adapters.DynamoDB.Query, only: [get_matching_secondary_index: 3]

  setup_all do
    on_exit(fn ->
      TestHelper.on_exit()
    end)
  end

  # When we have a hash-only key that also appears as the hash part of a composite key,
  # query on the key that best matches the situation. In the example below, we have two indexes
  # on the test_person table, first_name and first_name_email. If we just query on a hash indexed field
  # (either on its own, or with additional conditions), use the hash-only key rather than the composite key;
  # otherwise, querying with the composite key would fail to return records where a first_name was provided but email was nil.
  test "get_matching_secondary_index/3" do
    tablename = "test_person"

    hash_idx_result =
      get_matching_secondary_index(tablename, [{"first_name", {"Jerry", :==}}], [])

    composite_idx_result =
      get_matching_secondary_index(
        tablename,
        [and: [{"first_name", {"Jerry", :==}}, {"email", {"jerry@test.com", :==}}]],
        []
      )

    multi_cond_hash_idx_result =
      get_matching_secondary_index(
        tablename,
        [and: [{"first_name", {"Jerry", :==}}, {"last_name", {"Garcia", :==}}]],
        []
      )

    # If a user provides an explicit :index option, select that index if it is available.
    string_idx_option_result =
      get_matching_secondary_index(
        tablename,
        [and: [{"first_name", {"Jerry", :==}}, {"last_name", {"Garcia", :==}}]],
        index: "email"
      )

    atom_idx_option_result =
      get_matching_secondary_index(
        tablename,
        [and: [{"first_name", {"Jerry", :==}}, {"last_name", {"Garcia", :==}}]],
        index: :email
      )

    assert hash_idx_result == {"first_name", ["first_name"]}
    assert composite_idx_result == {"first_name_email", ["first_name", "email"]}
    assert multi_cond_hash_idx_result == {"first_name", ["first_name"]}
    assert string_idx_option_result == {"email", ["email"]}
    assert atom_idx_option_result == {"email", ["email"]}

    assert_raise(
      ArgumentError,
      "Ecto.Adapters.DynamoDB.Query.get_matching_secondary_index/3 error: :index option does not match existing secondary index names. Did you mean email?",
      fn ->
        get_matching_secondary_index(tablename, [{"first_name", {"Jerry", :==}}], index: "emai")
      end
    )

    assert_raise(
      ArgumentError,
      "Ecto.Adapters.DynamoDB.Query.get_matching_secondary_index/3 error: :index option does not match existing secondary index names.",
      fn ->
        get_matching_secondary_index(tablename, [{"first_name", {"Jerry", :==}}], index: :foobar)
      end
    )
  end
end
