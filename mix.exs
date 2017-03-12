defmodule Pgjob.Mixfile do
  use Mix.Project

  def project do
    [app: :pgjob,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger],
     mod: {Pgjob.Application, []}]
  end

  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:ecto, "~> 2.1"},
      {:poison, "~> 3.0"},
      {:postgrex, ">= 0.0.0"}
    ]
  end
end
