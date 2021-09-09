defmodule Ecto.Migration.SystemTable.Index.Migration do
  use Ecto.Migration
  def up do
    create table(:ecto_auto_migration_index) do
      add :tablename, :string
      add :index, :string
      add :name, :string
      add :concurrently, :string
      add :unique, :boolean
      add :using, :string
    end
  end
end

defmodule Ecto.Migration.SystemTable.Index do
  use Ecto.Schema
  @primary_key {:tablename, :string, []}
  schema "ecto_auto_migration_index" do
    field :index, :string
    field :name, :string
    field :concurrently, :boolean
    field :unique, :boolean
    field :using, :string
  end
end

defmodule Ecto.Migration.SystemTable.Migration do
  use Ecto.Migration
  def up do
    create table(:ecto_auto_migration) do
      add :tablename, :string
      add :metainfo, :string, size: 2040
    end
  end
end

defmodule Ecto.Migration.SystemTable do
  use Ecto.Schema
  @primary_key {:tablename, :string, []}
  schema "ecto_auto_migration" do
    field :metainfo, :string
  end
end
