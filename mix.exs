defmodule Mongo.EctoOne.Mixfile do
  use Mix.Project

  @version "0.1.3"

  def project do
    [app: :mongodb_ecto_one,
     version: @version,
     elixir: "~> 1.0",
     deps: deps(),
     test_coverage: [tool: ExCoveralls],
     description: description(),
     package: package(),
     docs: docs()]
  end

  def application do
    [applications: [:ecto_one, :mongodb]]
  end

  defp deps do
    [
      {:mongodb, "~> 0.1"},
      {:ecto_one, github: "mkaszubowski/ecto", branch: "ecto_one"},
      {:dialyze, "~> 0.2.0", only: :dev},
      {:excoveralls, "~> 0.3.11", only: :test},
      {:inch_ex, ">= 0.0.0", only: :docs},
      {:earmark, "~> 0.1", only: :docs},
      {:ex_doc, "~> 0.8", only: :docs}
    ]
  end

  defp description do
    """
    MongoDB adapter for EctoOne
    """
  end

  defp package do
    [maintainers: ["Michał Muskała"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/michalmuskala/mongodb_ecto_one"},
     files: ~w(mix.exs README.md CHANGELOG.md lib)]
  end

  defp docs do
    [source_url: "https://github.com/michalmuskala/mongodb_ecto_one",
     source_ref: "v#{@version}",
     main: "extra-readme",
     extras: ["README.md"]]
  end
end
