defmodule Ecto.Adapters.DynamoDB.Query.Test do
  @moduledoc """
  Unit tests for the query module.
  """
  use ExUnit.Case
  import Ecto.Adapters.DynamoDB.Query, only: [ get_matching_secondary_index: 2 ]

  setup_all do
    on_exit fn ->
      TestHelper.on_exit()
    end
  end

  # When we have a hash-only key that also appears as the hash part of a composite key,
  # query on the key that best matches the situation. In the example below, we have two indexes
  # on the test_person table, first_name and first_name_email. If we just query on first_name,
  # use the hash-only key rather than the composite key; otherwise, querying with the composite key would
  # fail to return records where a first name was provided but email was nil.
  test "get_matching_secondary_index/2" do
    tablename = "test_person"
    hash_idx_result = get_matching_secondary_index(tablename, [{"first_name", {"Jerry", :==}}])
    composite_idx_result = get_matching_secondary_index(tablename, [and: [{"first_name", {"Jerry", :==}}, {"email", {"jerry@test.com", :==}}]])

    assert hash_idx_result == {"first_name", ["first_name"]}
    assert composite_idx_result == {"first_name_email", ["first_name", "email"]}
  end
  
end
