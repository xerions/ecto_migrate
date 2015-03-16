import Ecto.Query

defmodule Exd.Model.Migration do

  def migrate(repo, module) do
    table_name = module.__schema__(:source)
    Ecto.Migrator.up(repo, :crypto.rand_uniform(0, 1099511627775), extend_module_name(module, ".Migration"))
  end

  def compile_migrate(repo, module, module_adds) do
    api_mod = ((module |> Atom.to_string) <> ".Api") |> String.to_atom
    table_name = api_mod.__tablename__(module) |> Atom.to_string
    # get or create system table
    system_tbl_resp = try do
                        query = from table in Exd.Schema.SystemTable, where: table.tablename == ^table_name, select: table
                        case repo.all(query) do
                          [] ->
                            []
                          [data] ->
                            data.metainfo
                        end
                      catch
                        _x, _y ->
                          # we have no system table - 'exd_migration', let's create it
                          Ecto.Migrator.up(repo, :crypto.rand_uniform(0, 1099511627775), Exd.Migration.SystemTable)
                          []
                      end
    #
    # Execute migration
    #
    case Exd.Model.Migration.generate(module, system_tbl_resp, repo) do
      [] ->
        :nothing_migrate
      mod ->
        mod |> Code.eval_quoted
        migrate(repo, module)
    end
  end

  def generate(model, fields_in_db, repo) do
    table_name = table_name(model)
    # build module name for migration module
    module_name = extend_module_name(model, ".Migration")
    # get correct primary key
    key? = model.__schema__(:primary_key) == :id
    # get all assoications from the schema
    assocs = model.__schema__(:associations) |> Enum.flat_map(fn(association) ->
      case model.__schema__(:association, association) do
        %Ecto.Association.BelongsTo{owner_key: field, assoc: assoc_model} ->
          [{field, table_name(assoc_model), assoc_model}]
        _ ->
          []
      end
    end)

    # get all fields from schema
    all_fields = model.__schema__(:fields)

    # build meta string for system table and insert it to the database
    fields_in_db = case fields_in_db do
      [] ->
        repo.insert(%Exd.Schema.SystemTable{tablename: (table_name |> Atom.to_string),  metainfo: system_table_meta(all_fields, model, assocs)})

        []
      _ ->
        # we already have metainfo for the current table in the system table
        # need to transform it to the [{name, type}]
        pre = String.split(fields_in_db, ",") |> Enum.map(&String.split(&1, ":"))
        Enum.map(pre, fn(elem) ->
          case elem do
            [name, type] ->
              {name |> String.to_atom, type |> String.to_atom}
            _ ->
              []
          end
        end) |> :lists.flatten
    end

    add_fields = for name <- all_fields, name != :id do
      case List.keyfind(assocs, name, 0) do
        nil ->
          type = model.__schema__(:field, name)
          opts = case :erlang.function_exported(model, :__atrribute_option__, 1) do
                   true -> model.__attribute_option__(name)
                   _ -> []
                 end
          case fields_in_db do
            [] ->
               quote do: add(unquote(name), unquote(type), unquote(opts))
            _ ->
              case List.keyfind(fields_in_db, name, 0) do
                nil ->
                  # we have no this field in the db, so let's add it
                  quote do: add(unquote(name), unquote(type), unquote(opts))
                {_maybe_new_name, new_type} ->
                  # check that type changed
                  case new_type == type do
                    true ->
                      # type didn't change
                      []
                    false ->
                      # old field but with new type, let's modify it
                      quote do: modify(unquote(name), unquote(new_type), unquote(opts))
                  end
              end
          end # endof fields_in_db
        {_assoc_field_name, association_table, _mod} ->
          case fields_in_db do
            [] ->
              quote do: add(unquote(name), Ecto.Migration.references(unquote(association_table)))
            _ ->
              case List.keyfind(fields_in_db, name, 0) do
                nil ->
                  quote do: add(unquote(name), Ecto.Migration.references(unquote(association_table)))
                {_maybe_new_name, new_type} ->
                  case new_type == association_table do
                    true ->
                      []
                    _ ->
                      quote do: modify(unquote(name), Ecto.Migration.references(unquote(association_table)))
                  end
              end
          end
      end # endof case assocs
    end |> List.flatten

    # get fields to remove
    remove_fields = for {name, _} <- fields_in_db do
      case Enum.member?(all_fields, name) do
        false ->
          quote do: remove(unquote(name))
        _ ->
          []
      end
    end |> List.flatten

    last_fields = remove_fields ++ add_fields

    case last_fields do
      [] ->
        []
      _ ->
        tbl = table_name |> Atom.to_string
        [delete] = repo.all(from d in Exd.Schema.SystemTable, where: d.tablename == ^tbl)
        repo.delete(delete)
        repo.insert(%Exd.Schema.SystemTable{tablename: tbl,  metainfo: system_table_meta(all_fields, model, assocs)})

        # generate migration module
        case fields_in_db do
          [] ->
            quote do
              defmodule unquote(module_name) do
                use Ecto.Migration
                def up do
                  create table(unquote(table_name), primary_key: unquote(key?)) do
                    unquote(add_fields)
                  end
                end
                def down do
                  drop table(unquote table_name)
                end
              end
            end
          _ ->
            quote do
              defmodule unquote(module_name) do
                use Ecto.Migration
                def up do
                  alter table(unquote(table_name)) do
                    unquote(last_fields)
                  end
                end

                def down do
                  drop table(unquote table_name)
                end
              end
            end
        end #endof case fields_in_db
    end #endof case last_fields
  end #endof generate

  defp system_table_meta(all_fields, model, assocs) do
    Enum.reduce(all_fields, "",
                fn(x, acc) ->
                  case x do
                    :id ->
                      acc <> ""
                    _ ->
                      case List.keyfind(assocs, x, 0) do
                        nil ->
                          acc <> (x |> Atom.to_string) <> ":" <>  (model.__schema__(:field, x) |> Atom.to_string) <> ","
                        {_, assoc_table, _} ->
                          acc <> (x |> Atom.to_string) <> ":" <>  (assoc_table |> Atom.to_string) <> ","
                      end
                  end
                end)
  end

  def extend_module_name(model, str) do
    ((model |> to_string) <> str) |> String.to_atom
  end

  def table_name(model) do
    model.__schema__(:source) |> String.to_atom
  end
end
