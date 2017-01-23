# System.at_exit fn _ -> Logger.flush end
Logger.configure(level: :info)
ExUnit.start exclude: [:uses_usec, :id_type, :read_after_writes, :sql_fragments, :decimal_type, :invalid_prefix, :transaction, :foreign_key_constraint]

Application.put_env(:ecto_one, :primary_key_type, :binary_id)

Code.require_file "../deps/ecto_one/integration_test/support/repo.exs", __DIR__
Code.require_file "../deps/ecto_one/integration_test/support/models.exs", __DIR__
Code.require_file "../deps/ecto_one/integration_test/support/migration.exs", __DIR__

# Basic test repo
alias EctoOne.Integration.TestRepo

Application.put_env(:ecto_one, TestRepo,
                    adapter: Mongo.EctoOne,
                    url: "ecto_one://localhost:27017/ecto_one_test",
                    pool_size: 1)

defmodule EctoOne.Integration.TestRepo do
  use EctoOne.Integration.Repo, otp_app: :ecto_one
end

defmodule EctoOne.Integration.Case do
  use ExUnit.CaseTemplate

  alias EctoOne.Integration.TestRepo

  setup_all do
    :ok
  end

  setup do
    Mongo.EctoOne.truncate(TestRepo)
    :ok
  end
end

_   = EctoOne.Storage.down(TestRepo)
:ok = EctoOne.Storage.up(TestRepo)

{:ok, pid} = TestRepo.start_link
:ok = TestRepo.stop(pid, :infinity)
{:ok, _pid} = TestRepo.start_link

# We capture_io, because of warnings on references
ExUnit.CaptureIO.capture_io fn ->
  :ok = EctoOne.Migrator.up(TestRepo, 0, EctoOne.Integration.Migration, log: false)
end
