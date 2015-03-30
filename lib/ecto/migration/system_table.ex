defmodule Ecto.Migration.SystemTable.Migration do
  use Ecto.Migration
  def up do
    create table(:ecto_auto_migration) do
      # These fields describe table and its fields
      add :tablename, :string
      add :metainfo, :string
      # These fields describe index
      add :index, :string
      add :index_name, :string
      add :concurently, :boolean
      add :unique, :boolean
      add :index_type, :string
    end
  end
end

defmodule Ecto.Migration.SystemTable do
  use Ecto.Model
  @derive [Access]
  @primary_key {:tablename, :string, []}
  schema "ecto_auto_migration" do
    field :metainfo, :string
    field :index, :string
    field :index_name, :string
    field :concurently, :boolean
    field :unique, :boolean
    field :index_type, :string
  end
end
