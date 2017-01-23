defmodule Simple.Mixfile do
  use Mix.Project

  def project do
    [app: :simple,
     version: "0.0.1",
     deps: deps]
  end

  def application do
    [mod: {Simple.App, []},
     applications: [:mongodb_ecto_one, :ecto_one]]
  end

  defp deps do
    [{:mongodb_ecto_one, path: "../.."},
     {:ecto_one, path: "../../deps/ecto_one", override: true},
     {:mongodb, path: "../../deps/mongodb", override: true}]
  end
end
