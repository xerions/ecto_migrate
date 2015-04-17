defmodule Ecto.Migration.Auto do
  import Ecto.Query
  alias Ecto.Migration.Index
  alias Ecto.Migration.SystemTable

  def migrate(repo, module) do
    table_name = module.__schema__(:source)
    # already stored fields of the model in the system table
    all_system_fields = get_existings_fields(repo, table_name)
    # already stored indexes of the model in the system table
    all_system_indexes = get_existings_indexes(repo, table_name)
    if execute(module, all_system_fields, all_system_indexes, repo) do
      Ecto.Migrator.up(repo, random, extend_module_name(module, ".Migration"))
    end
  end

  defp execute(module, all_system_fields, all_system_indexes, repo) do
    metainfo =  all_system_fields[:metainfo] |> transform_existing_keys()
    assocs = get_associations(module)
    all_fields = module.__schema__(:fields)
    add_fields = add_fields(module, all_fields, metainfo, assocs)
    remove_fields = remove_fields(all_fields, metainfo)
    all_indexes = Index.get_all(module)
    update_index = Index.updated?(all_indexes, all_system_indexes)
    all_changes = remove_fields ++ add_fields
    update_metainfo(module, all_fields, assocs, repo)
    do_execute(module, all_changes, metainfo, update_index, all_indexes, all_system_indexes, repo)
  end

  defp do_execute(_module, [], _fields_in_db, false, _, _, _repo), do: nil

  defp do_execute(module, all_changes, fields_in_db, update_index, all_indexes, all_system_indexes, repo) do
    table_name = table_name(module)
    module_name = extend_module_name(module, ".Migration")
    updsl = gen_up_dsl(repo, module, table_name, all_changes, fields_in_db, all_indexes, all_system_indexes, update_index)
    res = quote do
      defmodule unquote(module_name) do
        use Ecto.Migration
        def up do
          unquote(updsl)
        end
        def down do
          drop table(unquote table_name)
        end
      end
    end
    res |> Macro.to_string |> IO.puts
    res |> Code.eval_quoted
  end

  # create new table
  defp gen_up_dsl(_repo, module, table_name, all_changes, [], all_indexes, _, update_index) do
    key? = module.__schema__(:primary_key) == [:id]
    index_creation = Index.create(module, all_indexes, update_index)
    quote do
      create table(unquote(table_name), primary_key: unquote(key?)) do
        unquote(all_changes)
      end
      unquote(index_creation)
    end
  end

  # updated or table or index or both
  defp gen_up_dsl(repo, module, table_name, all_changes, _, all_indexes, all_system_indexes, update_index) do
    index_deletion = Index.delete(update_index, table_name |> Atom.to_string, module, repo, all_system_indexes)
    index_creation = Index.create(module, all_indexes, update_index)
    alter = alter_table(all_changes, table_name)
    quote do
      unquote(alter)
      unquote(index_deletion)
      unquote(index_creation)
    end
  end

  defp alter_table([], _), do: ""
  defp alter_table(all_changes, tablename) do
    quote do
      alter table(unquote(tablename)) do
        unquote(all_changes)
      end
    end
  end

  defp update_metainfo(module, all_fields, assocs, repo) do
    table_name = module.__schema__(:source)
    metainfo = system_table_meta(module, all_fields, assocs)
    case repo.get(SystemTable, table_name) do
      nil ->
        repo.insert(%SystemTable{tablename: table_name, metainfo: metainfo})
    table ->
        repo.update(%SystemTable{table | metainfo: metainfo})
    end

    query = from s in SystemTable.Index, where: s.tablename == ^table_name, select: s
    # insert index info if need
    case repo.all(query) do
      [] ->
        # we have no anything with 'table_name' record in the SystemTable.Index
        # table, let's insert records about it
        all_indexes = Index.get_all(module)
        for {fields, opts} <- all_indexes do
          repo.insert(Map.merge(%SystemTable.Index{tablename: table_name, index: Enum.join(fields, ",")}, :maps.from_list(opts)))
        end
      _ ->
        # we can't update index information here, because table is not empty and
        # given index can be already stored in the SystemTable.Index table
        :ok
    end
  end

  def get_existings_indexes(repo, table_name) do
    try do
      repo.all(from s in SystemTable.Index, where: ^table_name == s.tablename)
    catch
      _x, _y ->
        Ecto.Migrator.up(repo, random, SystemTable.Index.Migration) # we have no system table - 'ecto_migration_auto_index', let's create it
        nil
    end
  end

  def get_existings_fields(repo, table_name) do
    try do
      repo.get(SystemTable, table_name)
    catch
      _x, _y ->
        Ecto.Migrator.up(repo, random, SystemTable.Migration) # we have no system table - 'ecto_migration_auto', let's create it
        nil
    end
  end

  defp get_associations(module) do
    module.__schema__(:associations) |> Enum.flat_map(fn(association) ->
      case module.__schema__(:association, association) do
        %Ecto.Association.BelongsTo{owner_key: field, assoc: assoc_module} ->
          [{field, table_name(assoc_module), assoc_module}]
        _ ->
          []
      end
    end)
  end

  defp get_attribute_opts(module, name) do
    case :erlang.function_exported(module, :__attribute_option__, 1) do
      true -> module.__attribute_option__(name)
      _    -> []
    end
  end

  defp add_field(name, fields_in_db, type, quoted_type) do
    case List.keyfind(fields_in_db, name, 0) do
      nil ->
        quote do: add(unquote(name), unquote_splicing(quoted_type))
      {_maybe_new_name, new_type} ->
        unless new_type == type do
          quote do: modify(unquote(name), unquote_splicing(quoted_type))
        else
          []
        end
    end
  end

  defp add_fields(module, all_fields, fields_in_db, assocs) do
    for name <- all_fields, name != :id do
      case List.keyfind(assocs, name, 0) do
        nil ->
          type = Migratable.type(module.__schema__(:field, name))
          opts = get_attribute_opts(module, name)
          add_field(name, fields_in_db, type, quote do: [unquote(type), unquote(opts)])
        {_assoc_field_name, association_table, _mod} ->
          add_field(name, fields_in_db, association_table, quote do: [Ecto.Migration.references(unquote(association_table))])
      end
    end |> List.flatten
  end

  defp remove_fields(all_fields, fields_in_db) do
    fields_in_db
    |> Stream.filter(fn({name, _}) -> not Enum.member?(all_fields, name) end)
    |> Enum.map(fn({name, _}) -> quote do: remove(unquote(name)) end)
  end

  defp transform_existing_keys(nil), do: []
  defp transform_existing_keys(fields_string) do
    fields_string
    |> String.split(",")
    |> Stream.map(&String.split(&1, ":"))
    |> Enum.map(fn(field_type) -> field_type |> Enum.map(&String.to_atom/1) |> List.to_tuple end)
  end

  defp system_table_meta(module, all_fields, assocs) do
    Stream.flat_map(all_fields, &field_to_meta(&1, module, assocs)) |> Enum.join(",")
  end

  defp field_to_meta(:id, _, _), do: []
  defp field_to_meta(field, module, assocs) do
    string = case List.keyfind(assocs, field, 0) do
      nil ->
        (field |> Atom.to_string) <> ":" <> (module.__schema__(:field, field) |> Atom.to_string)
      {_, assoc_table, _} ->
        (field |> Atom.to_string) <> ":" <>  (assoc_table |> Atom.to_string)
    end
    [string]
  end

  defp random, do: :crypto.rand_uniform(0, 1099511627775)

  defp extend_module_name(module, str) do
    ((module |> to_string) <> str) |> String.to_atom
  end

  defp table_name(module) do
    module.__schema__(:source) |> String.to_atom
  end
end
