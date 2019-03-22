defmodule Ecto.Adapters.DynamoDB.Mixfile do
  use Mix.Project

  def project do
    [app: :ecto_adapters_dynamodb,
     version: "1.0.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     dialyzer: [plt_add_apps: [:ecto]],
     docs: [main: "readme", extras: ["README.md"]],
     description: "A DynamoDB adapter for Ecto supporting basic queries. See https://github.com/circles-learning-labs/ecto_adapters_dynamodb for detailed instructions.",
     package: package(),
     source_url: "https://github.com/circles-learning-labs/ecto_adapters_dynamodb"
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger],
     mod: {Ecto.Adapters.DynamoDB.Application, []},
     env: [
       cached_tables: [],
       insert_nil_fields: true,
       log_levels: [:info],
       log_colours: %{info: :green, debug: :normal},
       log_in_colour: System.get_env("MIX_ENV") == "dev",
       log_path: "",
       remove_nil_fields_on_update: false,
       scan_all: false,
       scan_limit: 100,
       scan_tables: []
     ],
     applications: [:ex_aws, :hackney, :poison]
   ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:ecto, "~> 2.2"},
      # {:ex_aws_dynamo, "~> 2.0"},
      # For the moment, using a fork (of a fork) of ex_aws_dynamo, which adds support for billing modes.
      {:ex_aws_dynamo, git: "git@github.com:circles-learning-labs/ex_aws_dynamo.git", branch: "master"},
      {:poison, "~> 3.0"},
      {:hackney, "~> 1.6"},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:eqc_ex, "~> 1.4.2", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.19.3", only: :dev, runtime: false},
    ]
  end

  defp package do
    [
      # files: ["lib", "priv", "mix.exs", "README*", "readme*", "LICENSE*", "license*"],
      maintainers: ["Franko Franicevich", "Darren Klein", "Gilad Barkan", "Nick Marino"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/circles-learning-labs/ecto_adapters_dynamodb"}
    ]
  end
end
