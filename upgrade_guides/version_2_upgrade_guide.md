# Upgrading from version 1.X.X -> 2.X.X

## `adapter` definition

Upgrading to the latest version of this adapter should be relatively painless, since you'd really just be following Ecto's instructions for setting the adapter (albeit with some of our specific configuration details, specified in the README).

Probably the most notable change is that you no longer define the adapter in your application's `config/` file(s), but rather in the `Repo` file itself. For example:

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.DynamoDB
end
```

## Local DynamoDB version

In order to make sure your local version of DynamoDB is up to date with the current production features, please use the latest release of DynamoDB local. As of spring 2019, the latest version is `1.11.477`, released on February 6, 2019.
