use Mix.Config

config :simple, Simple.Repo,
  adapter: Mongo.EctoOne,
  database: "ecto_one_simple",
  hostname: "localhost"
