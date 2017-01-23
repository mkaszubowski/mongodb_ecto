ExUnit.start
Logger.configure(level: :info)

defmodule Simple.Case do
  use ExUnit.CaseTemplate

  setup do
    Mongo.EctoOne.truncate(Simple.Repo)
    :ok
  end
end
