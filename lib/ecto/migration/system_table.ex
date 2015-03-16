defmodule Ecto.Migration.SystemTable.Migration do
  use Ecto.Migration
  def up do
    create table(:ecto_auto_migration) do
      add :tablename, :string
      add :metainfo, :string
    end
  end
end

defmodule Ecto.Migration.SystemTable do
  use Ecto.Model
  @derive [Access]
  @primary_key {:tablename, :string, []}
  schema "ecto_auto_migration" do
    field :metainfo, :string
  end
end
