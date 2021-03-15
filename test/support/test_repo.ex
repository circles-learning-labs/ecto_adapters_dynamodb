defmodule Ecto.Adapters.DynamoDB.TestRepo do
  use Ecto.Repo,
    otp_app: :test_app,
    adapter: Ecto.Adapters.DynamoDB
end
