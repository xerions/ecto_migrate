defmodule Exd.Migration.SystemTable do
    use Ecto.Migration
    def up do
        create table(:exd_migration) do
            add :tablename, :string
            add :metainfo, :string
        end
    end
end

defmodule Exd.Schema.SystemTable do
  use Ecto.Model
    @primary_key {:tablename, :string, []}
  schema "exd_migration" do
#            field :tablename, :string
            field :metainfo, :string
  end
end
