defmodule Simple.App do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    tree = [worker(Simple.Repo, [])]

    opts = [name: Simple.Sup, strategy: :one_for_one]
    Supervisor.start_link(tree, opts)
  end
end

defmodule Simple.Repo do
  use EctoOne.Repo, otp_app: :simple
end

defmodule Weather do
  use EctoOne.Model

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "weather" do
    field :city, :string
    field :temp_lo, :integer
    field :temp_hi, :integer
    field :prcp, :float, default: 0.0
    timestamps
  end
end

defmodule Simple do
  import EctoOne.Query

  def sample_query do
    query = from w in Weather,
          where: w.prcp > 0.0 or is_nil(w.prcp),
         select: w
    Simple.Repo.all(query)
  end
end
