defmodule TestModel do
  use Ecto.Schema
  use Ecto.Migration.Index
  index(:l, using: "hash")
  index(:f)
  schema "ecto_migrate_test_table" do
    field :f, :string
    field :i, :integer
    field :l, :boolean
  end
end

defmodule EctoMigrateTest do
  use ExUnit.Case
  import Ecto.Query
  test "ecto_migrate test" do
    :ok = :application.start(:ecto_it)
    Ecto.Migration.Auto.migrate(EctoIt.Repo, TestModel)
    query = from t in Ecto.Migration.SystemTable, select: t
    [result] = EctoIt.Repo.all(query)
    assert result.metainfo == "f:string,i:integer,l:boolean"
    assert result.tablename == "ecto_migrate_test_table"
    :ok = :application.stop(:ecto_it)
  end
end
