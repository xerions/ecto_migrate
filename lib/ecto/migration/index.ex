defmodule Ecto.Migration.Index do
  import Ecto.Query
  defmacro __using__(_opts) do
    quote do
      import Ecto.Migration.Index
      @indexes []
      @before_compile Ecto.Migration.Index
    end
  end

  defmacro index(columns, opts \\ []) do
    quote do
      @indexes [{unquote(List.wrap(columns)), unquote(opts)} | @indexes]
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def get_indexes do
        @indexes
      end
    end
  end

  def create(tablename, all_indexes, true) when length(all_indexes) > 0 do
    for {fields, opts} <- all_indexes do
      quote do
        create index(unquote(tablename), unquote(fields), unquote(opts))
      end
    end
  end

  def create(_, _, _), do: ""

  def delete(false, _, _, _, _), do: ""

  def delete(true, tablename, module, repo, indexes_from_db) do
    deletion = for db_index <- indexes_from_db do
      old_index_fields = Enum.map(String.split(db_index.index, ","), &String.to_atom(&1))
      old_index_opts = get_opts(db_index)
      quote do
        drop index(unquote(tablename |> String.to_atom), unquote(old_index_fields), unquote(old_index_opts))
      end
    end
    # remove all old indexes from the system table
    from(i in Ecto.Migration.SystemTable.Index, where: i.tablename == ^tablename) |> repo.delete_all
    # insert new indexes to the system table
    for {fields, opts} <- get_all(module) do
      repo.insert(Map.merge(%Ecto.Migration.SystemTable.Index{tablename: tablename, index: Enum.join(fields, ",")}, :maps.from_list(opts)))
    end
    deletion
  end

  def get_all(module) do
    case :erlang.function_exported(module, :get_indexes, 0) do
      true ->
        module.get_indexes()
      _ ->
        []
    end
  end

  def updated?(_, nil) do
    true
  end

  # Compare actual index from model with indexes stored in the
  # system index table. Returns true if something changed.
  def updated?(all_actual_indexes, indexes_from_db) do
    deleted?(indexes_from_db, all_actual_indexes) or
    changed?(indexes_from_db, all_actual_indexes)
  end

  defp deleted?([], []) do
    false
  end

  defp deleted?([index_from_db | indexes_from_db], [_ | _] = all_actual_indexes) do
    case List.keyfind(all_actual_indexes, String.split(index_from_db.index, ",") |> Enum.map(&String.to_atom(&1)) , 0) do
      nil ->
        # we have no actual index in the database, so index deleted
        true
      {index, _} ->
        deleted?(indexes_from_db, List.keydelete(all_actual_indexes, index, 0))
    end
  end

  defp deleted?(_, _) do
    true
  end

  defp changed?([], _) do
    false
  end

  defp changed?([index_from_db | indexes_from_db], all_actual_indexes) do
    case compare_indexes(index_from_db, get_opts(index_from_db), all_actual_indexes) do
      {true, all_actual_indexes} ->
        changed?(indexes_from_db, all_actual_indexes)
      _ ->
        true
    end
  end

  # index & options are the same in db and in given index
  defp compare_indexes(_, _, []), do: true

  defp compare_indexes(index_from_db, opts_in_db, [{indexes, actual_index} | all_actual_indexes]) do
    opts_in_db = opts_in_db -- default_index_opts
    actual_index = actual_index -- default_index_opts
    case opts_in_db == actual_index and (String.split(index_from_db.index, ",") |> Enum.map(&String.to_atom(&1))) == indexes do
      true ->
        {true, all_actual_indexes}
      _ ->
        compare_indexes(index_from_db, opts_in_db, all_actual_indexes)
    end
  end

  defp get_opts(index) do
    [{:name, index.name}, {:concurrently, index.concurrently}, {:unique, index.unique}, {:using, index.using}]
  end

  defp default_index_opts do
    [name: nil, concurrently: nil, unique: nil, using: nil]
  end
end
