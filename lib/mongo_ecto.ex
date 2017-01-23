defmodule Mongo.EctoOne do
  @moduledoc """
  EctoOne integration with MongoDB.

  This document will present a general overview of using MongoDB with EctoOne,
  including common pitfalls and extra functionalities.

  Check the [EctoOne documentation](http://hexdocs.pm/ecto_one) for an introduction
  or [examples/simple](https://github.com/michalmuskala/mongodb_ecto_one/tree/master/examples/simple)
  for a sample application using EctoOne and MongoDB.

  ## Repositories

  The first step to use MongoDB with EctoOne is to define a repository
  with `Mongo.EctoOne` as an adapter. First define a module:

      defmodule Repo do
        use EctoOne.Repo, otp_app: :my_app
      end

  Then configure it your application environment, usually in your
  `config/config.exs`:

      config :my_app, Repo,
        adapter: Mongo.EctoOne,
        database: "ecto_one_simple",
        username: "mongodb",
        password: "mongodb",
        hostname: "localhost"

  Each repository in EctoOne defines a `start_link/0` function that needs to
  be invoked before using the repository. This function is generally from
  your supervision tree:

      def start(_type, _args) do
        import Supervisor.Spec

        children = [
          worker(Repo, [])
        ]

        opts = [strategy: :one_for_one, name: MyApp.Supervisor]
        Supervisor.start_link(children, opts)
      end

  ## Models

  With the repository defined, we can define our models:

      defmodule Weather do
        use EctoOne.Model

        # see the note below for explanation of that line
        @primary_key {:id, :binary_id, autogenerate: true}

        # weather is the MongoDB collection name
        schema "weather" do
          field :city,    :string
          field :temp_lo, :integer
          field :temp_hi, :integer
          field :prcp,    :float, default: 0.0
        end
      end

  EctoOne defaults to using `:id` type for primary keys, that is translated to
  `:integer` for SQL databases, and is not handled by MongoDB. You need to
  specify the primary key to use the `:binary_id` type, that the adapter will
  translate to ObjectID. Remember to place this declaration before the
  `schema` call.

  The name of the primary key is just a convenience, as MongoDB forces us to
  use `_id`. Every other name will be recursively changed to `_id` in all calls
  to the adapter. We propose to use `id` or `_id` as your primary key name
  to limit eventual confusion, but you are free to use whatever you like.
  Using the `autogenerate: true` option will tell the adapter to take care of
  generating new ObjectIDs. Otherwise you need to do this yourself.

  Since setting `@primary_key` for every model can be too repetitive, we
  recommend you to define your own module that properly configures it:

      defmodule MyApp.Model do
        defmacro __using__(_) do
          quote do
            use EctoOne.Model
            @primary_key {:id, :binary_id, autogenerate: true}
            @foreign_key_type :binary_id # For associations
          end
        end
      end

  Now, instead of `use EctoOne.Model`, you can `use MyApp.Model` in your
  modules. All EctoOne types, except `:decimal`, are supported by `Mongo.EctoOne`.

  By defining a schema, EctoOne automatically defines a struct with
  the schema fields:

      iex> weather = %Weather{temp_lo: 30}
      iex> weather.temp_lo
      30

  The schema also allows the model to interact with a repository:

      iex> weather = %Weather{temp_lo: 0, temp_hi: 23}
      iex> Repo.insert!(weather)
      %Weather{...}

  After persisting `weather` to the database, it will return a new copy of
  `%Weather{}` with the primary key (the `id`) set. We can use this value
  to read a struct back from the repository:

      # Get the struct back
      iex> weather = Repo.get Weather, "507f191e810c19729de860ea"
      %Weather{id: "507f191e810c19729de860ea", ...}

      # Update it
      iex> weather = %{weather | temp_lo: 10}
      iex> Repo.update!(weather)
      %Weather{...}

      # Delete it
      iex> Repo.delete!(weather)
      %Weather{...}

  ## Queries

  `Mongo.EctoOne` also supports writing queries in Elixir to interact with
  your MongoDB. Let's see an example:

      import EctoOne.Query, only: [from: 2]

      query = from w in Weather,
            where: w.prcp > 0 or is_nil(w.prcp),
           select: w

      # Returns %Weather{} structs matching the query
      Repo.all(query)

  Queries are defined and extended with the `from` macro. The supported
  keywords in MongoDB are:

    * `:where`
    * `:order_by`
    * `:offset`
    * `:limit`
    * `:select`
    * `:preload`

  When writing a query, you are inside EctoOne's query syntax. In order to
  access params values or invoke functions, you need to use the `^`
  operator, which is overloaded by EctoOne:

      def min_prcp(min) do
        from w in Weather, where: w.prcp > ^min or is_nil(w.prcp)
      end

  Besides `Repo.all/1`, which returns all entries, repositories also
  provide `Repo.one/1`, which returns one entry or nil, and `Repo.one!/1`
  which returns one entry or raises.

  There is also support for count function in queries that uses `MongoDB`'s
  `count` command. Please not that unlike in SQL databases you can only select
  a count - there is no support for querying using a count, there is also no
  support for counting documents and selecting them at the same time.

  Please note that not all EctoOne queries are valid MongoDB queries. The adapter
  will raise `EctoOne.QueryError` if it encounters one, and will try to be as
  specific as possible as to what exactly is causing the problem.

  For things that are not possible to express with Elixir's syntax in queries,
  you can use keyword fragments:

      from p in Post, where: fragment("$exists": "name"), select: p

  To ease of using in more advanced queries, there is `Mongo.EctoOne.Helpers` module
  you could import into modules dealing with queries.
  Please see the documentation of the `Mongo.EctoOne.Helpers` module for more
  information and supported options.

  ### Options for reader functions (`Repo.all/2`, `Repo.one/2`, etc)

  Such functions also accept options when invoked which allow
  you to use parameters specific to MongoDB `find` function:

    * `:slave_ok` - the read operation may run on secondary replica set member
    * `:partial` - partial data from a query against a sharded cluster in which
      some shards do not respond will be returned in stead of raising error

  ## Commands

  MongoDB has many administrative commands you can use to manage your database.
  We support them thourgh `Mongo.EctoOne.command/2` function.

      Mongo.EctoOne.command(MyRepo, createUser: "ecto_one", ...)

  We also support one higher level command - `Mongo.EctoOne.truncate/1` that is
  used to clear the database, i.e. during testing.

      Mongo.EctoOne.truncate(MyRepo)

  You can use it in your `setup` call for cleaning the database before every
  test. You can define your own module to use instead of `ExUnit.Case`, so you
  don't have to define this each time.

      defmodule MyApp.Case do
        use ExUnit.CaseTemplate

        setup do
          Mongo.EctoOne.truncate(MyRepo)
          :ok
        end
      end

  Please see documentation for those functions for more information.

  ## Associations

  EctoOne supports defining associations on schemas:

      defmodule Post do
        use EctoOne.Model

        @primary_key {:id, :binary_id, autogenerate: true}
        @foreign_key_type :binary_id

        schema "posts" do
          has_many :comments, Comment
        end
      end

  Keep in mind that EctoOne associations are stored in different Mongo
  collections and multiple queries may be required for retriving them.

  While `Mongo.EctoOne` supports almost all association features in EctoOne,
  keep in mind that MongoDB does not support joins as used in SQL - it's
  not possible to query your associations together with the main model.

  Some more elaborate association schemas may force EctoOne to use joins in
  some queries, that are not supported by MongoDB as well. One such call
  is `EctoOne.Model.assoc/2` function with a `has_many :through` association.

  You can find more information about defining associations and each respective
  association module in `EctoOne.Schema` docs.

  ## Embedded models

  EctoOne supports defining relations using embedding models directly inside the
  parent model, and that fits MongoDB's design perfectly.

      defmodule Post do
        #...

        schema "posts" do
          embeds_many :comments, Comment
        end
      end

      defmodule Comment do
        embedded_schema do
          field :body, :string
        end
      end

  You can find more information about defining embedded models in the
  `EctoOne.Schema` docs.

  ## Indexes and Migrations

  Although schema migrations make no sense for databases such as MongoDB
  there is one field where they can be very benefitial - indexes. Because of
  this Mongodb.EctoOne supports EctoOne's database migrations. You can generate a
  migration with:

      $ mix ecto_one.gen.migration create_posts

  This will create a new file inside `priv/repo/migrations` with the `up` and
  `down` functions. Check `EctoOne.Migration` for more information.

  Because MongoDB does not support (or need) database schemas majority of the
  functionality provided by `EctoOne.Migration` is not useful when working with
  MongoDB. As we've already noted the most useful part is indexing, but there
  are others - creating capped collections, executing administrative commands,
  or migrating data, e.g.:

      defmodule SampleMigration do
        use EctoOne.Migration

        def up do
          create table(:my_table, options: [capped: true, size: 1024])
          create index(:my_table, [:value])
          create unique_index(:my_table, [:unique_value])
          execute touch: "my_table", data: true, index: true
        end

        def down do
          # ...
        end
      end

  MongoDB adapter does not support `create_if_not_exists` or `drop_if_exists`
  migration functions.

  ## MongoDB adapter features

  The adapter uses `mongodb` for communicating with the database and a pooling
  library such as `poolboy` for managing connections.

  The adapter has support for:

    * documents with ObjectID as their primary key
    * insert, find, update, remove and count mongo functions
    * management commands with `command/2`
    * embedded documents either with `:map` type, or embedded models
    * partial updates using `change_map/2` and `change_array/2` from the
      `Mongo.EctoOne.Helpers` module
    * queries using javascript expresssion and regexes using respectively
      `javascript/2` and `regex/2` functions from `Mongo.EctoOne.Helpers` module.

  ### MongoDB adapter options

  Options passed to the adapter are split into different categories decscribed
  below. All options should be given via the repository configuration.

  ### Compile time options

  Those options should be set in the config file and require
  recompilation in order to make an effect.

    * `:adapter` - The adapter name, in this case, `Mongo.EctoOne`
    * `:pool` - The connection pool module, defaults to `Mongo.Pool.Poolboy`
    * `:log_level` - The level to use when logging queries (default: `:debug`)

  ### Connection options

    * `:hostname` - Server hostname (default: `localhost`)
    * `:port` - Server port (default: `27017`)
    * `:username` - Username
    * `:password` - User password
    * `:connect_timeout` - The timeout for establishing new connections (default: 5000)
    * `:w` - MongoDB's write convern (default: 1). If set to 0, some of the
      EctoOne's functions may not work properely
    * `:j`, `:fsync`, `:wtimeout` - Other MongoDB's write concern options. Please
      consult MongoDB's documentation

  ### Pool options

  `Mongo.EctoOne` does not use EctoOne pools, instead pools provided by the MongoDB
  driver are used. The default poolboy adapter accepts following options:

    * `:pool_size` - The number of connections to keep in the pool (default: 10)
    * `:max_overflow` - The maximum overflow of connections (default: 0)

  For other adapters, please see their documentation.
  """

  @behaviour EctoOne.Adapter
  @behaviour EctoOne.Adapter.Storage
  @behaviour EctoOne.Adapter.Migration

  alias Mongo.EctoOne.NormalizedQuery
  alias Mongo.EctoOne.NormalizedQuery.ReadQuery
  alias Mongo.EctoOne.NormalizedQuery.WriteQuery
  alias Mongo.EctoOne.NormalizedQuery.CountQuery
  alias Mongo.EctoOne.NormalizedQuery.AggregateQuery
  alias Mongo.EctoOne.ObjectID
  alias Mongo.EctoOne.Connection
  alias Mongo.EctoOne.Conversions

  ## Adapter

  @doc false
  defmacro __before_compile__(env) do
    module = env.module
    config = Module.get_attribute(module, :config)
    adapter = Keyword.get(config, :pool, Mongo.Pool.Poolboy)

    quote do
      defmodule Pool do
        use Mongo.Pool, name: __MODULE__, adapter: unquote(adapter)

        def log(return, queue_time, query_time, fun, args) do
          Mongo.EctoOne.log(unquote(module), return, queue_time, query_time, fun, args)
        end
      end

      def __mongo_pool__, do: unquote(module).Pool
    end
  end

  @doc false
  def start_link(repo, opts) do
    {:ok, _} = Application.ensure_all_started(:mongodb_ecto_one)

    repo.__mongo_pool__.start_link(opts)
  end

  @doc false
  def stop(_module, pid, timeout) do
    ref = Process.monitor(pid)
    Process.exit(pid, :normal)
    receive do
      {:DOWN, ^ref, _, _, _} -> :ok
    after
      timeout -> exit(:timeout)
    end
    Application.stop(:mongodb_ecto_one)
    :ok
  end

  @doc false
  def load(_type, nil),
    do: {:ok, nil}
  # wat
  def load(:binary_id, %BSON.ObjectId{value: value}),
    do: ObjectID.load(value)
  def load(:binary, %BSON.Binary{binary: value}),
    do: {:ok, value}
  def load(EctoOne.UUID, %BSON.Binary{binary: value}),
    do: {:ok, value}
  def load(:map, keyword),
    do: {:ok, Enum.into(keyword, %{})}
  def load(EctoOne.Date, %BSON.DateTime{} = datetime) do
    {date, _time} = BSON.DateTime.to_datetime(datetime)
    EctoOne.Date.load(date)
  end
  def load(EctoOne.Time, %BSON.DateTime{} = datetime) do
    {_date, time} = BSON.DateTime.to_datetime(datetime)
    EctoOne.Time.load(time)
  end
  def load(EctoOne.DateTime, %BSON.DateTime{} = datetime),
    do: datetime |> BSON.DateTime.to_datetime |> EctoOne.DateTime.load
  def load(module, %BSON.DateTime{} = datetime),
    do: datetime |> BSON.DateTime.to_datetime |> module.load
  def load(type, data),
    do: EctoOne.Type.load(type, data, &load/2)

  @doc false
  def dump(_type, nil),
    do: {:ok, nil}
  def dump(:binary_id, data),
    do: ObjectID.dump(data)
  def dump(:binary, value),
    do: {:ok, %BSON.Binary{binary: value}}
  def dump(EctoOne.UUID, value),
    do: {:ok, %BSON.Binary{binary: value, subtype: :uuid}}
  def dump(EctoOne.Date, datetime),
    do: from_datetime(datetime)
  def dump(EctoOne.Time, datetime),
    do: from_datetime(datetime)
  def dump(EctoOne.DateTime, datetime),
    do: from_datetime(datetime)
  def dump(type, data),
    do: EctoOne.Type.dump(type, data, &dump/2)

  @epoch :calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})

  def from_datetime(%EctoOne.Date{year: year, month: month, day: day}),
    do: from_datetime({{year, month, day}, {0, 0, 0, 0}})
  def from_datetime(%EctoOne.Time{hour: hour, min: min, sec: sec, usec: usec}),
    do: from_datetime({{1970, 1, 1}, {hour, min, sec, usec}})
  def from_datetime(%EctoOne.DateTime{year: year, month: month, day: day, hour: hour, min: min, sec: sec, usec: usec}),
    do: from_datetime({{year, month, day}, {hour, min, sec, usec}})
  def from_datetime({_, _, _, _} = time),
    do: from_datetime({{1970, 1, 1}, time})
  def from_datetime({date, {hour, min, sec, usec}}) do
    greg_secs = :calendar.datetime_to_gregorian_seconds({date, {hour, min, sec}})
    epoch_secs = greg_secs - @epoch
    {:ok, %BSON.DateTime{utc: epoch_secs * 1000 + div(usec, 1000)}}
  end

  @doc false
  def embed_id(_), do: ObjectID.generate

  @doc false
  def prepare(function, query) do
    {:nocache, {function, query}}
  end

  @read_queries [ReadQuery, CountQuery, AggregateQuery]

  @doc false
  def execute(repo, _meta, {function, query}, params, preprocess, opts) do
    case apply(NormalizedQuery, function, [query, params]) do
      %{__struct__: read} = query when read in @read_queries ->
        {rows, count} =
          Connection.read(repo.__mongo_pool__, query, opts)
          |> Enum.map_reduce(0, &{process_document(&1, query, preprocess), &2 + 1})
        {count, rows}
      %WriteQuery{} = write ->
        result = apply(Connection, function, [repo.__mongo_pool__, write, opts])
        {result, nil}
    end
  end

  @doc false
  def insert(_repo, meta, _params, {key, :id, _}, _returning, _opts) do
    raise ArgumentError,
      "MongoDB adapter does not support :id field type in models. " <>
      "The #{inspect key} field in #{inspect meta.model} is tagged as such."
  end

  def insert(_repo, meta, _params, _autogen, [_] = returning, _opts) do
    raise ArgumentError,
      "MongoDB adapter does not support :read_after_writes in models. " <>
      "The following fields in #{inspect meta.model} are tagged as such: #{inspect returning}"
  end

  def insert(repo, meta, params, nil, [], opts) do
    normalized = NormalizedQuery.insert(meta, params, nil)

    case Connection.insert(repo.__mongo_pool__, normalized, opts) do
      {:ok, _} ->
        {:ok, []}
      other ->
        other
    end
  end

  def insert(repo, meta, params, {pk, :binary_id, nil}, [], opts) do
    normalized = NormalizedQuery.insert(meta, params, pk)

    case Connection.insert(repo.__mongo_pool__, normalized, opts) do
      {:ok, %{inserted_id: objid}} ->
        {:ok, [{pk, objid}]}
      other ->
        other
    end
  end

  def insert(repo, meta, params, {pk, :binary_id, _value}, [], opts) do
    normalized = NormalizedQuery.insert(meta, params, pk)

    case Connection.insert(repo.__mongo_pool__, normalized, opts) do
      {:ok, _} ->
        {:ok, []}
      other ->
        other
    end
  end

  @doc false
  def update(_repo, meta, _fields, _filter, {key, :id, _}, _returning, _opts) do
    raise ArgumentError,
      "MongoDB adapter does not support :id field type in models. " <>
      "The #{inspect key} field in #{inspect meta.model} is tagged as such."
  end

  def update(_repo, meta, _fields, _filter, _autogen, [_|_] = returning, _opts) do
    raise ArgumentError,
      "MongoDB adapter does not support :read_after_writes in models. " <>
      "The following fields in #{inspect meta.model} are tagged as such: #{inspect returning}"
  end

  def update(repo, meta, fields, filter, {pk, :binary_id, _value}, [], opts) do
    normalized = NormalizedQuery.update(meta, fields, filter, pk)

    Connection.update(repo.__mongo_pool__, normalized, opts)
  end

  def update(repo, meta, fields, filter, nil, [], opts) do
    normalized = NormalizedQuery.update(meta, fields, filter, nil)

    Connection.update(repo.__mongo_pool__, normalized, opts)
  end

  @doc false
  def delete(_repo, meta, _filter, {key, :id, _}, _opts) do
    raise ArgumentError,
      "MongoDB adapter does not support :id field type in models. " <>
      "The #{inspect key} field in #{inspect meta.model} is tagged as such."
  end

  def delete(repo, meta, filter, {pk, :binary_id, _value}, opts) do
    normalized = NormalizedQuery.delete(meta, filter, pk)

    Connection.delete(repo.__mongo_pool__, normalized, opts)
  end

  def delete(repo, meta, fields, filter, nil, [], opts) do
    normalized = NormalizedQuery.update(meta, fields, filter, nil)

    Connection.update(repo.__mongo_pool__, normalized, opts)
  end

  defp process_document(document, %{fields: fields, pk: pk}, preprocess) do
    document = Conversions.to_ecto_one_pk(document, pk)

    Enum.map(fields, fn
      {:field, name, field} ->
        preprocess.(field, Map.get(document, Atom.to_string(name)), nil)
      {:value, value, field} ->
        preprocess.(field, Conversions.to_ecto_one_pk(value, pk), nil)
      field ->
        preprocess.(field, document, nil)
    end)
  end

  ## Storage

  # Noop for MongoDB, as any databases and collections are created as needed.
  @doc false
  def storage_up(_opts) do
    :ok
  end

  @doc false
  def storage_down(opts) do
    Connection.storage_down(opts)
  end

  ## Migration

  alias EctoOne.Migration.Table
  alias EctoOne.Migration.Index

  @doc false
  def supports_ddl_transaction?, do: false

  @doc false
  def execute_ddl(_repo, string, _opts) when is_binary(string) do
    raise ArgumentError, "MongoDB adapter does not support SQL statements in `execute`"
  end

  def execute_ddl(repo, command, opts) when is_list(command) do
    command(repo, command, opts)
    :ok
  end

  def execute_ddl(repo, {:create, %Table{options: nil, name: coll}, columns}, opts) do
    warn_on_references!(columns)
    command(repo, [create: coll], opts)
    :ok
  end

  def execute_ddl(repo, {:create, %Table{options: options, name: coll}, columns}, opts)
      when is_list(options) do
    warn_on_references!(columns)
    command(repo, [create: coll] ++ options, opts)
    :ok
  end

  def execute_ddl(_repo, {:create, %Table{options: string}, _columns}, _opts)
      when is_binary(string) do
    raise ArgumentError, "MongoDB adapter does not support SQL statements as collection options"
  end

  def execute_ddl(repo, {:create, %Index{} = command}, opts) do
    index = [name: to_string(command.name),
             unique: command.unique,
             background: command.concurrently,
             key: Enum.map(command.columns, &{&1, 1}),
             ns: namespace(repo, command.table)]

    query = %WriteQuery{coll: "system.indexes", command: index}

    {:ok, _} = Connection.insert(repo.__mongo_pool__, query, opts)
    :ok
  end

  def execute_ddl(repo, {:drop, %Index{name: name, table: coll}}, opts) do
    command(repo, [dropIndexes: coll, index: to_string(name)], opts)
    :ok
  end

  def execute_ddl(repo, {:drop, %Table{name: coll}}, opts) do
    command(repo, [drop: coll], opts)
    :ok
  end

  def execute_ddl(repo, {:rename, %Table{name: old}, %Table{name: new}}, opts) do
    command = [renameCollection: namespace(repo, old), to: namespace(repo, new)]
    command(repo, command, [database: "admin"] ++ opts)
    :ok
  end

  def execute_ddl(repo, {:rename, %Table{name: coll}, old, new}, opts) do
    query = %WriteQuery{coll: to_string(coll),
                        command: ["$rename": [{to_string(old), to_string(new)}]],
                        opts: [multi: true]}

    {:ok, _} = Connection.update(repo.__mongo_pool__, query, opts)
    :ok
  end

  def execute_ddl(_repo, {:create_if_not_exists, %Table{options: nil}, columns}, _opts) do
    # We treat this as a noop as the collection will be created by mongo
    warn_on_references!(columns)
    :ok
  end

  def execute_ddl(_repo, {:create_if_not_exists, %Table{}, _columns}, _opts) do
    raise ArgumentError, "MongoDB adapter supports options for collection only in the `create` function"
  end

  def execute_ddl(_repo, {:create_if_not_exists, %Index{}}, _opts) do
    raise ArgumentError, "MongoDB adapter does not support `create_if_not_exists` for indexes"
  end

  def execute_ddl(_repo, {:drop_if_exists, _}, _opts) do
    raise ArgumentError, "MongoDB adapter does not support `drop_if_exists`"
  end

  defp warn_on_references!(columns) do
    has_references? =
      Enum.any?(columns, fn
        {_, _, %EctoOne.Migration.Reference{}, _} -> true
        _other                                 -> false
      end)

    if has_references? do
      IO.puts "[warning] MongoDB adapter does not support references, and will not enforce foreign_key constraints"
    end
  end

  ## Mongo specific calls

  @doc """
  Drops all the collections in current database.

  Skips system collections and `schema_migrations` collection.
  Especially usefull in testing.

  Returns list of dropped collections.
  """
  @spec truncate(EctoOne.Repo.t, Keyword.t) :: [String.t]
  def truncate(repo, opts \\ []) do
    opts = Keyword.put(opts, :log, false)

    Enum.map(list_collections(repo, opts), fn collection ->
      truncate_collection(repo, collection, opts)
      collection
    end)
  end

  @doc """
  Runs a command in the database.

  ## Usage

      Mongo.EctoOne.command(Repo, drop: "collection")

  ## Options

    * `:database` - run command against a specific database
      (default: repo's database)
    * `:log` - should command queries be logged (default: true)

  For list of available commands plese see: http://docs.mongodb.org/manual/reference/command/
  """
  @spec command(EctoOne.Repo.t, BSON.document, Keyword.t) :: BSON.document
  def command(repo, command, opts \\ []) do
    normalized = NormalizedQuery.command(command, opts)

    Connection.command(repo.__mongo_pool__, normalized, opts)
  end

  special_regex = %BSON.Regex{pattern: "\\.system|\\$", options: ""}
  @migration EctoOne.Migration.SchemaMigration.__schema__(:source)
  migration_regex = %BSON.Regex{pattern: @migration, options: ""}

  @list_collections_query ["$and": [[name: ["$not": special_regex]],
                                    [name: ["$not": migration_regex]]]]

  def list_collections(repo, opts \\ []) do
    ver = db_version(repo)

    list_collections(ver, repo, opts)
  end

  defp list_collections(_ = 3, repo, opts) do
    colls = command(repo, %{"listCollections": 1}, opts)

    colls["cursor"]["firstBatch"]
    |> Enum.map(&Map.fetch!(&1, "name"))
    |> Enum.reject(&@migration == &1)
  end

  defp list_collections(_,repo, opts) do
    query = %ReadQuery{coll: "system.namespaces", query: @list_collections_query}
    opts = Keyword.put(opts, :log, false)

    Connection.read(repo.__mongo_pool__, query, opts)
    |> Enum.map(&Map.fetch!(&1, "name"))
    |> Enum.map(fn collection ->
      collection |> String.split(".", parts: 2) |> Enum.at(1)
    end)
  end

  defp truncate_collection(repo, collection, opts) do
    query = %WriteQuery{coll: collection, query: %{}}
    Connection.delete_all(repo.__mongo_pool__, query, opts)
  end

  defp namespace(repo, coll) do
    "#{repo.config[:database]}.#{coll}"
  end

  defp db_version(repo) do
    version = command(repo, %{"buildinfo": 1}, [])["versionArray"]

    Enum.fetch!(version, 0)
  end

  @doc false
  def log(repo, :ok, queue_time, query_time, fun, args) do
    log(repo, {:ok, nil}, queue_time, query_time, fun, args)
  end
  def log(repo, return, queue_time, query_time, fun, args) do
    entry =
      %EctoOne.LogEntry{query: &format_log(&1, fun, args), params: [],
                     result: return, query_time: query_time, queue_time: queue_time}
    repo.log(entry)
  end

  defp format_log(_entry, :run_command, [command, _opts]) do
    ["COMMAND " | inspect(command)]
  end
  defp format_log(_entry, :insert_one, [coll, doc, _opts]) do
    ["INSERT", format_part("coll", coll), format_part("document", doc)]
  end
  defp format_log(_entry, :insert_many, [coll, docs, _opts]) do
    ["INSERT", format_part("coll", coll), format_part("documents", docs)]
  end
  defp format_log(_entry, :delete_one, [coll, filter, _opts]) do
    ["DELETE", format_part("coll", coll), format_part("filter", filter),
     format_part("many", false)]
  end
  defp format_log(_entry, :delete_many, [coll, filter, _opts]) do
    ["DELETE", format_part("coll", coll), format_part("filter", filter),
     format_part("many", true)]
  end
  defp format_log(_entry, :replace_one, [coll, filter, doc, _opts]) do
    ["REPLACE", format_part("coll", coll), format_part("filter", filter),
     format_part("document", doc)]
  end
  defp format_log(_entry, :update_one, [coll, filter, update, _opts]) do
    ["UPDATE", format_part("coll", coll), format_part("filter", filter),
     format_part("update", update), format_part("many", false)]
  end
  defp format_log(_entry, :update_many, [coll, filter, update, _opts]) do
    ["UPDATE", format_part("coll", coll), format_part("filter", filter),
     format_part("update", update), format_part("many", true)]
  end
  defp format_log(_entry, :find, [coll, query, projection, _opts]) do
    ["FIND", format_part("coll", coll), format_part("query", query),
     format_part("projection", projection)]
  end
  defp format_log(_entry, :find_rest, [coll, cursor, _opts]) do
    ["GET_MORE", format_part("coll", coll), format_part("cursor_id", cursor)]
  end
  defp format_log(_entry, :kill_cursors, [cursors, _opts]) do
    ["KILL_CURSORS", format_part("cursor_ids", cursors)]
  end

  defp format_part(name, value) do
    [" ", name, "=" | inspect(value)]
  end
end
