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

defmodule Ecto.Taggable do
  use Ecto.Model
  schema "this is not a valid schema name and it will never be used" do
    field :name, :string
    field :model, :string
    field :tag_id, :integer
  end
end

defmodule MyModel do
  use Ecto.Model
  schema "my_model" do
    field :a, :string
    field :b, :integer
    has_many :tags, {"my_model_tags", Ecto.Taggable}, [foreign_key: :tag_id]
  end
end

defmodule EctoMigrateTest do
  use ExUnit.Case
  import Ecto.Query

  test "ecto_migrate with tags test" do
    :ok = :application.start(:ecto_it)
 
    Ecto.Migration.Auto.migrate(EctoIt.Repo, TestModel)
    query = from t in Ecto.Migration.SystemTable, select: t
    [result] = EctoIt.Repo.all(query)
    assert result.metainfo == "f:string,i:integer,l:boolean"
    assert result.tablename == "ecto_migrate_test_table"

    Ecto.Migration.Auto.migrate(EctoIt.Repo, MyModel)
    Ecto.Migration.Auto.migrate(EctoIt.Repo, Ecto.Taggable, [for: MyModel])
    
    EctoIt.Repo.insert(%MyModel{a: "foo"})
    EctoIt.Repo.insert(%MyModel{a: "bar"})

    model = %MyModel{}
    new_tag = Ecto.Model.build(model, :tags)
    new_tag = %{new_tag | tag_id: 2, name: "test_tag", model: MyModel |> to_string}
    EctoIt.Repo.insert(new_tag)

    query = from c in MyModel, where: c.id == 2, preload: [:tags]
    [result] = EctoIt.Repo.all(query)
    [tags] = result.tags

    assert tags.id == 1
    assert tags.model == "Elixir.MyModel"
    assert tags.name  == "test_tag"
 
    :ok = :application.stop(:ecto_it)
  end
end
