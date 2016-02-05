defmodule Ecto.Migration.Auto do
  @moduledoc """
  This module provide function for doing automigration of models.

  ## Examples

  ### Configuration for Repo, only for iex try taste, please use supervisor in your application

      :application.set_env(:example, Repo, [adapter: Ecto.Adapters.MySQL, database: "example", username: "root"])
      defmodule Repo, do: (use Ecto.Repo, otp_app: :example)
      Repo.start_link

  ### The same example for postgres

      :application.set_env(:example, Repo, [adapter: Ecto.Adapters.Postgres, database: "example", username: "postgres"])
      defmodule Repo, do: (use Ecto.Repo, otp_app: :example)
      Repo.start_link

  ### Usage

      import Ecto.Query

      defmodule Weather do # is for later at now
        use Ecto.Model

        schema "weather" do
          field :city
          field :temp_lo, :integer
          field :temp_hi, :integer
          field :prcp,    :float, default: 0.0
        end
      end

      Ecto.Migration.Auto.migrate(Repo, Weather)

      %Weather{city: "Berlin", temp_lo: 20, temp_hi: 25} |> Repo.insert
      Repo.all(from w in Weather, where: w.city == "Berlin")

  """
  import Ecto.Query
  alias Ecto.Migration.Auto.Index
  alias Ecto.Migration.Auto.Field
  alias Ecto.Migration.SystemTable

  @doc """
  Runs an up migration on the given repository for the given model.

  ## Options

      * :for - used for models, which are used as custom source

  ## Examples

      iex> Ecto.Migration.Auto.migrate(Repo, Model)

      iex> Ecto.Migration.Auto.migrate(Repo, Tag, for: Model)
  """
  def migrate(repo, module, opts \\ []) do
    ensure_exists(repo)
    for tablename <- sources(module) do
      {related_field, tablename} = get_tablename(module, tablename, opts)
      tableatom = tablename |> String.to_atom
      for_opts = {related_field, opts[:for]}

      {fields_changes, relateds} = repo.get(SystemTable, tablename) |> Field.check(tableatom, module, for_opts)
      index_changes  = (from s in SystemTable.Index, where: ^tablename == s.tablename) |> repo.all |> Index.check(tableatom, module)

      if migration_module = check_gen(tableatom, module, fields_changes, index_changes, opts) do
         Ecto.Migrator.up(repo, random, migration_module)
         Field.update_meta(repo, module, tablename, relateds) # May be in transaction?
         Index.update_meta(repo, module, tablename, index_changes)
      end
    end
  end

  def sources(module) do
    tablename = module.__schema__(:source)
    case function_exported?(module, :__sources__, 0) do
      true  -> module.__sources__()
      false -> [tablename]
    end
  end

  def migrated?(repo, model) do
    tablename = model.__schema__(:source)
    try do
      query = from t in Ecto.Migration.SystemTable, select: t, where: t.tablename == ^tablename
      case repo.all(query) do
        [] -> false
        [%Ecto.Migration.SystemTable{tablename: tablename}] -> true
      end
    catch _, _ ->
      false
    end
  end

  defp get_tablename(_module, tablename, []) do
    {nil, tablename}
  end
  defp get_tablename(module, _, [for: mod]) do
    %Ecto.Association.Has{related_key: related_key, queryable: {tablename, _}} = find_related_field(module, mod)
    {related_key, tablename}
  end

  defp find_related_field(module, mod) do
    (mod.__schema__(:associations)
    |> Stream.map(&mod.__schema__(:association, &1))
    |> Enum.find(&related_mod?(&1, module))) || raise(ArgumentError, message: "association in #{m2s(mod)} for #{m2s(module)} not found")
  end

  defp related_mod?(%Ecto.Association.Has{related: mod, queryable: {_, _}}, mod), do: true
  defp related_mod?(_, _), do: false

  defp check_gen(_tablename, _module, {false, []}, {[], []}, _opts), do: nil
  defp check_gen(tablename, module, {create?, changed_fields}, {create_indexes, delete_indexes}, opts) do
    migration_module = migration_module(module, opts)
    up = gen_up(module, tablename, create?, changed_fields, create_indexes, delete_indexes)
    quote do
      defmodule unquote(migration_module) do
        use Ecto.Migration
        def up do
          unquote(up)
        end
        def down do
          drop table(unquote tablename)
        end
      end
    end |> Code.eval_quoted
    migration_module
  end

  defp gen_up(module, tablename, create?, changed_fields, create_indexes, delete_indexes) do
    up_table = gen_up_table(module, tablename, create?, changed_fields)
    up_indexes = gen_up_indexes(create_indexes, delete_indexes)
    quote do
      unquote(up_table)
      unquote(up_indexes)
    end
  end

  defp gen_up_table(module, tablename, true, changed_fields) do
    key? = module.__schema__(:primary_key) == [:id]
    quote do
      create table(unquote(tablename), primary_key: unquote(key?)) do
        unquote(changed_fields)
      end
    end
  end

  defp gen_up_table(_module, tablename, false, changed_fields) do
    quote do
      alter table(unquote(tablename)) do
        unquote(changed_fields)
      end
    end
  end

  defp gen_up_indexes(create_indexes, delete_indexes) do
    quote do
      unquote(delete_indexes)
      unquote(create_indexes)
    end
  end

  @migration_tables [{SystemTable.Index, SystemTable.Index.Migration}, {SystemTable, SystemTable.Migration}]
  defp ensure_exists(repo) do
    for {model, migration} <- @migration_tables do
      ensure_exists(repo, model, migration)
    end
  end

  defp ensure_exists(repo, model, migration) do
    try do
      repo.get(model, "test")
    catch
      _, _ ->
        Ecto.Migrator.up(repo, random, migration)
    end
  end

  defp random, do: :crypto.rand_uniform(0, 1099511627775)

  defp migration_module(module, []),         do: Module.concat(module, Migration)
  defp migration_module(module, [for: mod]), do: Module.concat([module, mod, Migration])

  defp m2s(mod) do
    case to_string(mod) do
      "Elixir." <> modstring -> modstring
      modstring -> modstring
    end
  end
end
