defmodule Ecto.Adapters.DynamoDB.Config do
  alias Confex.Resolver

  def get(repo) do
    config = Resolver.resolve!(repo.config())

    case config[:ex_aws_config] do
      nil -> basic_config(config)
      :ex_aws -> common_config(config)
      full_config when is_list(config) -> full_config
    end
    |> Keyword.merge(Keyword.get(config, :dynamodb, []))
  end

  defp basic_config(config) do
    Keyword.take(config, [:debug_requests, :access_key_id, :secret_access_key, :region])
  end

  defp common_config(config) do
    Application.get_env(config, :ex_aws)
  end
end
