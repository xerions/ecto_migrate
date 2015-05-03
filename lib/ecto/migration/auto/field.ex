defmodule Ecto.Migration.Auto.Field do
  alias Ecto.Migration.SystemTable

  @doc """
  Update meta information in repository
  """
  def update_meta(repo, module, tablename, assocs) do
    metainfo = module.__schema__(:fields) |> Stream.map(&field_to_meta(&1, module, assocs)) |> Enum.join(",")
    updated_info = %SystemTable{tablename: tablename, metainfo: metainfo}
    if repo.get(SystemTable, tablename) do
      repo.update(updated_info)
    else
      repo.insert(updated_info)
    end
  end

  defp field_to_meta(field, module, assocs) do
    case List.keyfind(assocs, field, 0) do
      nil ->
        (field |> Atom.to_string) <> ":" <> (module.__schema__(:field, field) |> Atom.to_string)
      {_, _, assoc_table} ->
        (field |> Atom.to_string) <> ":" <>  (assoc_table |> Atom.to_string)
    end
  end

  @doc """
  Check database fields with actual models fields and gives
  """
  def check(old_fields, _tablename, module, for_opts) do
    assocs = associations(module)
    metainfo = old_keys(old_fields)
    new_fields = module.__schema__(:fields)

    add_fields = add(module, new_fields, metainfo, assocs, for_opts)
    remove_fields = remove(new_fields, metainfo)

    {{old_fields == nil, remove_fields ++ add_fields}, assocs}
  end

  defp old_keys(nil), do: []
  defp old_keys(%{metainfo: fields_string}) do
    fields_string
    |> String.split(",")
    |> Stream.map(&String.split(&1, ":"))
    |> Enum.map(fn(field_type) -> field_type |> Enum.map(&String.to_atom/1) |> List.to_tuple end)
  end

  defp associations(module) do
    module.__schema__(:associations) |> Enum.flat_map(fn(association) ->
      case module.__schema__(:association, association) do
        %Ecto.Association.BelongsTo{owner_key: field, assoc: assoc_module} ->
          [{field, assoc_module, assoc_module.__schema__(:source) |> String.to_atom}]
        _ ->
          []
      end
    end)
  end

  defp add(module, all_fields, fields_in_db, assocs, {assoc_key, assoc_mod}) when is_list(all_fields) do
    for name <- all_fields, name != :id do
      case List.keyfind(assocs, name, 0) do
        nil ->
          unless name == assoc_key do
            type = type(module.__schema__(:field, name))
            opts = get_attribute_opts(module, name)
            add(name, type, fields_in_db, quote do: [unquote(type), unquote(opts)])
          else
            association_table = assoc_mod.__schema__(:source) |> String.to_atom
            add(name, association_table, fields_in_db, quote do: [Ecto.Migration.references(unquote(association_table))])
          end
        {assoc_field_name, mod, association_table} ->
          opts = get_attribute_opts(module, assoc_field_name)
          add(name, association_table, fields_in_db, quote do: [Ecto.Migration.references(unquote(association_table)), unquote(opts)])
      end
    end |> List.flatten
  end

  defp add(name, type, fields_in_db, quoted_type) do
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

  defp remove(all_fields, fields_in_db) do
    fields_in_db
    |> Stream.filter(fn({name, _}) -> not Enum.member?(all_fields, name) end)
    |> Enum.map(fn({name, _}) -> quote do: remove(unquote(name)) end)
  end

  def type(data) do
    case :erlang.function_exported(data, :type, 0) do
      true  -> data.type
      false -> data
    end
  end

  defp get_attribute_opts(module, name) do
    case :erlang.function_exported(module, :__attribute_option__, 1) do
      true -> module.__attribute_option__(name)
      _    -> []
    end
  end
end
