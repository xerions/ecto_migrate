# We use this for testing of the renaming table. The ecto_migrate_test.exs
# contains the same module but with the other table name and set of the
# schema fields.
defmodule TestModel do
  use Ecto.Model
  use Ecto.Migration.Auto.Index

  index(:l, using: "hash")
  index(:f)

  schema "test_table_2" do
    field :f, :string
    field :l, :boolean
  end
  
  def old_tablename do
    "ecto_migrate_test_table"
  end
end
