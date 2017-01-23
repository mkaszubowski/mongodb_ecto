defmodule Mongo.EctoOne.JavaScript do
  @moduledoc """
  An EctoOne type to represent MongoDB's JavaScript functions

  ## Using in queries

      javascript = Mongo.EctoOne.Helpers.javascript("this.visits === count", count: 1)
      from p in Post, where: ^javascript
  """

  @behaviour EctoOne.Type

  defstruct BSON.JavaScript |> Map.from_struct |> Enum.to_list
  @type t :: %__MODULE__{code: String.t, scope: %{}}

  @doc """
  The EctoOne primitive type.
  """
  def type, do: :any

  @doc """
  Casts to database format
  """
  def cast(%BSON.JavaScript{} = js),
    do: {:ok, js}
  def cast(_),
    do: :error

  @doc """
  Converts a `Mongo.EctoOne.JavaScript` into `BSON.JavaScript`
  """
  def dump(%__MODULE__{} = js),
    do: {:ok, Map.put(js, :__struct__, BSON.JavaScript)}
  def dump(_),
    do: :error

  @doc """
  Converts a `BSON.JavaScript` into `Mongo.EctoOne.JavaScript`
  """
  def load(%BSON.JavaScript{} = js),
    do: {:ok, Map.put(js, :__struct__, __MODULE__)}
  def load(_),
    do: :error
end
