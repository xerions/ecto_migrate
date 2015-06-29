defmodule Ecto.Migration.Auto.Index do
  import Ecto.Query
  alias Ecto.Migration.SystemTable.Index

  defmacro __using__(_opts) do
    quote do
      import Ecto.Migration.Auto.Index
      @indexes []
      @before_compile Ecto.Migration.Auto.Index
    end
  end

  defmacro index(columns, opts \\ []) do
    quote do
      @indexes [{unquote(List.wrap(columns)), unquote(opts)} | @indexes]
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def __indexes__ do
        @indexes
      end
    end
  end

  @doc """
  Update meta information in repository
  """
  def update_meta(_repo, _module, _tablename, {[], []}), do: nil
  def update_meta(repo, module, tablename, _) do
    (from s in Index, where: s.tablename == ^tablename) |> repo.delete_all
    for {columns, opts} <- all(module) do
      repo.insert!(Map.merge(%Index{tablename: tablename, index: Enum.join(columns, ",")}, :maps.from_list(opts)))
    end
  end

  @doc """
  Check database indexes with actual models indexes and gives the difference
  """
  def check(old_indexes, tablename, module) do
    new_indexes = all(module) |> Enum.map(&merge_default/1)
    old_indexes = old_indexes |> Enum.map(&transform_from_db/1)

    create_indexes = (new_indexes -- old_indexes) |> create(tablename)
    delete_indexes = (old_indexes -- new_indexes) |> delete(tablename)

    {create_indexes, delete_indexes}
  end

  defp merge_default({index, opts}) do
    {index, Keyword.merge(default_index_opts, opts) |> List.keysort(0)}
  end

  defp transform_from_db(index) do
    columns = String.split(index.index, ",") |> Enum.map(&String.to_atom(&1))
    {columns, get_opts(index)}
  end

  defp create(create_indexes, tablename) do
    quoted_indexes(create_indexes, tablename) |> Enum.map(fn(index) -> (quote do: create unquote(index)) end)
  end

  defp delete(delete_indexes, tablename) do
    quoted_indexes(delete_indexes, tablename) |> Enum.map(fn(index) -> (quote do: drop unquote(index)) end)
  end

  defp quoted_indexes(indexes, tablename) do
    for {fields, opts} <- indexes do
      quote do: index(unquote(tablename), unquote(fields), unquote(opts))
    end
  end

  def all(module) do
    case :erlang.function_exported(module, :__indexes__, 0) do
      true ->
        module.__indexes__()
      _ ->
        []
    end
  end

  defp get_opts(index) do
    # in sort order
    [{:concurrently, index.concurrently}, {:name, index.name}, {:unique, index.unique}, {:using, index.using}]
  end

  defp default_index_opts do
    [concurrently: nil, name: nil, unique: nil, using: nil]
  end
end
