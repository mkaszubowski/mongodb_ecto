# Mongo.EctoOne

[![Travis Build Status](https://img.shields.io/travis/michalmuskala/mongodb_ecto_one.svg)](https://travis-ci.org/michalmuskala/mongodb_ecto_one)
[![Coveralls Coverage](https://img.shields.io/coveralls/michalmuskala/mongodb_ecto_one.svg)](https://coveralls.io/github/michalmuskala/mongodb_ecto_one)
[![Inline docs](http://inch-ci.org/github/michalmuskala/mongodb_ecto_one.svg?branch=master)](http://inch-ci.org/github/michalmuskala/mongodb_ecto_one)

`Mongo.EctoOne` is a MongoDB adapter for EctoOne.

For detailed information read the documentation for the `Mongo.EctoOne` module,
or check out examples below.

## Example
```elixir
# In your config/config.exs file
config :my_app, Repo,
  database: "ecto_one_simple",
  username: "mongodb",
  password: "mongosb",
  hostname: "localhost"

# In your application code
defmodule Repo do
  use EctoOne.Repo,
    otp_app: :my_app,
    adapter: Mongo.EctoOne
end

defmodule Weather do
  use EctoOne.Model

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "weather" do
    field :city     # Defaults to type :string
    field :temp_lo, :integer
    field :temp_hi, :integer
    field :prcp,    :float, default: 0.0
  end
end

defmodule Simple do
  import EctoOne.Query

  def sample_query do
    query = from w in Weather,
          where: w.prcp > 0 or is_nil(w.prcp),
         select: w
    Repo.all(query)
  end
end
```

## Usage

Add Mongo.EctoOne as a dependency in your `mix.exs` file.
```elixir
def deps do
  [{:mongodb_ecto_one, "~> 0.1"}]
end
```

You should also update your applications to include both projects.
```elixir
def application do
  [applications: [:logger, :mongodb_ecto_one, :ecto_one]]
end
```

To use the adapter in your repo:
```elixir
defmodule MyApp.Repo do
  use EctoOne.Repo,
    otp_app: :my_app,
    adapter: Mongo.EctoOne
end
```

For additional information on usage please see the documentation for [EctoOne](http://hexdocs.pm/ecto_one).

## Data Type Mapping

|   BSON                |EctoOne|
|   ----------          |------|
|   double              |`:float`|
|   string              |`:string`|
|   object              |`:map`|
|   array               |`{:array, subtype}`|
|   binary data         |`:binary`|
|   binary data (uuid)  |`EctoOne.UUID`|
|   object id           |`:binary_id`|
|   boolean             |`:boolean`|
|   date                |`EctoOne.DateTime`|
|   regular expression  |`Mongo.EctoOne.Regex`|
|   JavaScript          |`Mongo.EctoOne.JavaScript`|
|   symbol              |(see below)|
|   32-bit integer      |`:integer`|
|   timestamp           |`BSON.Timestamp`|
|   64-bit integer      |`:integer`|

Symbols are deprecated by the
[BSON specification](http://bsonspec.org/spec.html). They will be converted
to simple strings on reads. There is no possibility of persisting them to
the database.

Additionally special values are translated as follows:

|	BSON        |     	EctoOne|
|	----------  |      	------|
|    null     |           `nil`|
|    min key  |           `:BSON_min`|
|    max key  |           `:BSON_max`|




## Supported Mongo versions

The adapter and the driver are tested against most recent versions from 3
branches: 2.4.x, 2.6.x, 3.0.x

## Contributing

To contribute you need to compile `Mongo.EctoOne` from source and test it:

```
$ git clone https://github.com/michalmuskala/mongodb_ecto_one.git
$ cd mongodb_ecto_one
$ mix test
```

## License

Copyright 2015 Michał Muskała

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
