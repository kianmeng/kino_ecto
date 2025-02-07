defmodule KinoEcto.QueryBuilder do
  defstruct [:sql_query]
  import Ecto.Query
  alias KinoEcto.QueryBuilder.Renderer

  defmodule MyParser do
    import NimbleParsec

    @alphanumeric [?a..?z, ?A..?Z, ?0..?9, ?_, ?*, ?.]
    @string_prefix [?']

    whitespace = ascii_string([?\s, ?\n], min: 1)
    select_choice = choice([string("SELECT"), string("select")])
    from_choice = choice([string("FROM"), string("from")])
    join_choice = choice([string("JOIN"), string("join")])
    on_choice = choice([string("ON"), string("on")])
    where_choice = choice([string("WHERE"), string("where")])
    comparisson_choice = choice([string("="), string(">="), string("<="), string("<>")])

    from_part =
      select_choice
      |> ignore(whitespace)
      |> ascii_string(@alphanumeric, min: 1)
      |> ignore(whitespace)
      |> optional(from_choice)
      |> ignore(whitespace)
      |> optional(ascii_string(@alphanumeric, min: 1))

    join_part =
      ignore(from_part)
      |> ignore(whitespace)
      |> optional(join_choice)
      |> ignore(whitespace)
      |> ascii_string(@alphanumeric, min: 1)
      |> ignore(whitespace)
      |> optional(on_choice)
      |> ignore(whitespace)
      |> ascii_string(@alphanumeric, min: 1)
      |> ignore(whitespace)
      |> string("=")
      |> ignore(whitespace)
      |> ascii_string(@alphanumeric, min: 1)
      |> optional(ignore(whitespace))

    where_part =
      ignore(from_part)
      |> optional(ignore(join_part))
      |> ignore(whitespace)
      |> optional(where_choice)
      |> ignore(whitespace)
      |> ascii_string(@alphanumeric, min: 1)
      |> ignore(whitespace)
      |> optional(comparisson_choice)
      |> ignore(whitespace)
      |> optional(ascii_string(@string_prefix, min: 0, max: 1))
      |> ascii_string(@alphanumeric, min: 1)
      |> optional(ascii_string(@string_prefix, min: 0, max: 1))

    defparsec(:from_part, from_part)
    defparsec(:join_part, optional(join_part))
    defparsec(:where_part, where_part)
  end

  def test(query) do
    from_part = MyParser.from_part(query)
    join_part = MyParser.join_part(query)
    where_part = MyParser.where_part(query)

    [elem(from_part, 1), elem(join_part, 1), elem(where_part, 1)]
  end

  def call(%__MODULE__{sql_query: query}) do
    from_part = MyParser.from_part(query)
    join_part = MyParser.join_part(query)
    where_part = MyParser.where_part(query)

    from = elem(from_part, 1)
    join_part = elem(join_part, 1)
    where_part = elem(where_part, 1)
    # [, elem(join_part, 1), elem(where_part, 1)]

    build_from(from)
    |> build_join(join_part)
    |> build_where(where_part)
    |> Renderer.call()
  end

  defp build_from(from_part) do
    result = %Ecto.Query{
      from: %Ecto.Query.FromExpr{
        source: get_source(List.last(from_part))
      }
    }

    Ecto.Query.from(result)
  end

  defp build_join(query, []), do: query

  defp build_join(query, _join_part) do
    query
  end

  defp build_where(query, []), do: query

  defp build_where(query, [_where, field_name, "=" | tail]) do
    tail = tail |> Enum.join() |> String.replace("'", "")

    query
    |> where([t], field(t, ^String.to_atom(field_name)) == ^tail)
  end

  defp get_source(table_name) do
    {:ok, modules} = :application.get_key(:kino_ecto, :modules)

    modules
    |> Enum.filter(&({:__schema__, 1} in &1.__info__(:functions)))
    |> Enum.find(fn module -> module.__schema__(:source) == table_name end)
    |> then(fn schema -> {table_name, schema} end)
  end

  # defimpl Ecto.Queryable, for: KinoEcto.QueryBuilder do
  #   def to_query(query_builder) do
  #     [fields | tail] =
  #       query_builder.sql_query
  #       |> String.split("from")

  #     translate_query(tail)
  #   end

  #   defp translate_query(query) do
  #     [table_name | tail] = String.split(" ") |> Enum.map(&String.trim/1)

  #     table_name
  #     |> build_query()
  #     |> add_join(tail)
  #     |> add_where(tail)
  #   end

  #   defp build_query(table_name) do
  #     %Ecto.Query{from: %Ecto.Query.FromExpr{source: get_source(table_name)}}
  #   end

  #   defp add_join(ecto_query, query) do
  #     ecto_query
  #   end

  #   defp add_where(ecto_query, query) do
  #     %Ecto.Query.BooleanExpr{
  #   end

  #   defp get_source(table_name) do
  #     {:ok, modules} = :application.get_key(:kino_ecto, :modules)

  #     modules
  #     |> Enum.filter(&({:__schema__, 1} in &1.__info__(:functions)))
  #     |> Enum.find(fn module -> module.__schema__(:source) == table_name end)
  #     |> IO.inspect()
  #     |> then(fn schema -> {table_name, schema} end)
  #   end
  # end
end
