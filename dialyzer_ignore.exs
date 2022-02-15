[
  # See https://github.com/elixir-lang/elixir/pull/8480 - this is an issue with the way dialyzer
  # and MapSet interact
  {"lib/ecto_adapters_dynamodb.ex", :call_without_opaque},
  {"lib/ecto_adapters_dynamodb/dynamodbset.ex", :call_without_opaque},

  # Type mismatch on newer Ecto versions - only exists for support of older ones
  {"lib/ecto_adapters_dynamodb.ex", :call}
]
