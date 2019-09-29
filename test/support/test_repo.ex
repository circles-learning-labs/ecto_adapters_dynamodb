defmodule Ecto.Adapters.DynamoDB.TestRepo do
  use Ecto.Repo,
    otp_app: :ecto_adapters_dynamodb,
    adapter: Ecto.Adapters.DynamoDB
end
