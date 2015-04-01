defmodule Ecto.Migration.Index do

  defmacro index(tbl, columns, opts \\ []) do
    quote do
      def build_index do
        {unquote(tbl), unquote(columns), unquote(opts)}
      end
    end
  end

  def generate_index(_, false) do
    ""
  end

  def create_index(module, true) do
    case :erlang.function_exported(module, :build_index, 0) do
      true ->
        {tablename, columns, opts} = module.build_index()
        quote do
          create index(unquote(tablename), unquote(columns), unquote(opts))
        end
      false ->
        ""
    end
  end

  def update_index_in_system_table(repo, module, table_name) do
    {index, index_name, concurently, unique, index_type} = get_index_fields(module)
    table = repo.get(Ecto.Migration.SystemTable, table_name |> Atom.to_string)
    repo.update(%Ecto.Migration.SystemTable{table | index: index, index_name: index_name, concurently: concurently, 
                                            unique: unique, index_type: index_type})
  end

  def is_index_updated(_, nil) do
    true
  end

  # true if something changed in index
  def is_index_updated(module, all_system_fields) do
    case :erlang.function_exported(module, :build_index, 0) do
      false ->
        # It means that we have no index in the actual model, so
        # we need to check, maybe it deleted
        # --
        # returns true if index deleted
        is_index_deleted(all_system_fields)
      true ->
        # returns true if index changed
        is_index_changed(module, all_system_fields)
    end
  end

  def delete_old_index_from_db(false, _, _, _) do
    ""
  end

  def delete_old_index_from_db(_, table_name, module, repo) do
    fields_from_db   = Ecto.Migration.Auto.get_existings_fields(repo, module)
    old_index_fields = Ecto.Migration.Auto.get_index_fields_from_db(fields_from_db)
    old_index_opts = get_index_opts_from_db(fields_from_db)
    case fields_from_db.index do
      "" ->
        ""
      _ ->
        update_index_in_system_table(repo, module, table_name)
        quote do
          drop index(unquote(table_name), unquote(old_index_fields), unquote(old_index_opts))
        end
    end
  end

  def get_index_fields(module) do
    case :erlang.function_exported(module, :build_index, 0) do
      true ->
        case module.build_index do
          "" ->
            {"", "", false, false, ""}
          {_tbl, fields, opts} ->
            {index_name, concurently, unique, index_type} = get_index_helper(opts)
            {Enum.join(fields, ","), index_name, concurently, unique, index_type}
        end
      _ ->
        {"", "", false, false, ""}
    end
  end

  defp get_index_info_with_fields_names(_module, opts, fields_from_db) do
    index = get_index_fields_from_db(fields_from_db)
    {index_name, concurently, unique, index_type} = get_index_helper(opts)
    [index: index, index_name: index_name, concurently: concurently, unique: unique, index_type: index_type] |> :lists.sort
  end

  defp get_index_helper(opts) do
    {_, index_name}  = List.keyfind(opts, :name, 0, {:nothing, ""})
    {_, concurently} = List.keyfind(opts, :concurrently, 0, {:nothing, false})
    {_, unique}      = List.keyfind(opts, :unique, 0, {:nothing, false})
    {_, index_type}  = List.keyfind(opts, :using, 0, {:nothing, ""})
    {index_name, concurently, unique, index_type}
  end

  defp get_index_fields_from_db(fields_from_db) do
    for field <- String.split(fields_from_db.index) do
      String.to_atom(field)
    end
  end

  defp get_index_opts_from_db(fields_from_db) do
    available_index_opts = [:index_name, :index_type, :concurently, :unique]
    Enum.reduce(available_index_opts, [], fn(opt, acc) ->
      [{opt, fields_from_db[opt]} | acc]
    end)
  end

  defp is_index_deleted(all_system_fields) do
    all_system_fields.index != ""
  end

  defp is_index_changed(module, all_system_fields) do
    # get index from actual model
    {_tablename, columns, opts} = module.build_index()
    case Enum.join(columns, ",") == all_system_fields.index do
      false ->
        true
      _ ->
        opts_in_db = [index: get_index_fields_from_db(all_system_fields),
                      index_name: all_system_fields.index_name,
                      concurently: all_system_fields.concurently,
                      index_type: all_system_fields.index_type,
                      unique: all_system_fields.unique] |> :lists.sort
        get_index_info_with_fields_names(module, opts, all_system_fields) != opts_in_db
    end
  end
end
