defmodule TestModel do
  use Ecto.Schema
  use Ecto.Migration.Auto.Index

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
  use Ecto.Migration.Auto.Index

  index(:tag_id, using: "hash")
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
    field :c, Ecto.DateTime
    has_many :my_model_tags, {"my_model_tags", Ecto.Taggable}, [foreign_key: :tag_id]
  end

  def __sources__, do: ["my_model", "my_model_2"]

end

defmodule EctoMigrateTest do
  use ExUnit.Case
  import Ecto.Query
  alias EctoIt.Repo

  setup do
    :ok = :application.start(:ecto_it)
    on_exit fn -> :application.stop(:ecto_it) end
  end

  test "ecto_migrate with tags test" do
    Ecto.Migration.Auto.migrate(EctoIt.Repo, TestModel)
    query = from t in Ecto.Migration.SystemTable, select: t
    [result] = Repo.all(query)
    assert result.metainfo == "id:id,f:string,i:BIGINT,l:boolean"
    assert result.tablename == "ecto_migrate_test_table"

    Ecto.Migration.Auto.migrate(Repo, MyModel)
    Ecto.Migration.Auto.migrate(Repo, Ecto.Taggable, [for: MyModel])

    Repo.insert!(%MyModel{a: "foo"})
    Repo.insert!(%MyModel{a: "bar"})
    %MyModel{a: "foo"} |> Ecto.Model.put_source("my_model_2") |> Repo.insert!

    model = %MyModel{}
    new_tag = Ecto.Model.build(model, :my_model_tags)
    new_tag = %{new_tag | tag_id: 2, name: "test_tag", model: MyModel |> to_string}
    EctoIt.Repo.insert!(new_tag)

    query = from c in MyModel, where: c.id == 2, preload: [:my_model_tags]
    [result] = EctoIt.Repo.all(query)
    [tags] = result.my_model_tags

    assert tags.id == 1
    assert tags.model == "Elixir.MyModel"
    assert tags.name  == "test_tag"
  end
end
