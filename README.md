Ecto Migrate [![Build Status](https://travis-ci.org/xerions/ecto_migrate.svg)](https://travis-ci.org/xerions/ecto_migrate)
============

Ecto migrate brings automatic migrations to ecto, instead of defining and writing manual diffing
from current model and old model. It saves the representation of
a model in the database and checks if current model has changed compared to the previously saved definition.

To test, use EctoIt:

```
iex -S mix
```

After, it should be possible:

```elixir
:application.start(:ecto_it)
alias EctoIt.Repo

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

```

Let's redefine the same model in a shell and migrate it

```elixir

defmodule Weather do # is for later at now
  use Ecto.Model

  schema "weather" do
    field :city
    field :temp_lo, :integer
    field :temp_hi, :integer
    field :prcp,    :float, default: 0.0
    field :wind,    :float, default: 0.0
  end
end

Ecto.Migration.Auto.migrate(Repo, Weather)
Repo.all(from w in Weather, where: w.city == "Berlin")

```

Let's use references

```elixir

defmodule Post do
  use Ecto.Model

  schema "posts" do
    field :title, :string
    field :public, :boolean, default: true
    field :visits, :integer
    has_many :comments, Comment
  end
end

defmodule Comment do
  use Ecto.Model

  schema "comments" do
    field :text, :string
    belongs_to :post, Post
  end
end

Ecto.Migration.Auto.migrate(Repo, Post)
Ecto.Migration.Auto.migrate(Repo, Comment)

```

`ecto_migrate` also provides additional `migrate/3` API, or use with custom source defined models. Example:

```elixir
defmodule Taggable do
  use Ecto.Model

  schema "this is not a valid schema name and it will never be used" do
    field :tag_id, :integer
  end
end

defmodule MyModel do
  use Ecto.Model
  schema "my_model" do
    field :a, :string
    has_many :my_model_tags, {"my_model_tags", Taggable}, [foreign_key: :tag_id]
  end
end
```

Now we can migrate `my_model_tags` table with:

```elixir
Ecto.Migration.Auto.migrate(Repo, MyModel)
Ecto.Migration.Auto.migrate(Repo, Taggable, [for: MyModel])
```

It will generate and migrate `my_model_tags` table to the database which will be associated with `my_model` table.

Indexes
-------

`ecto_migrate` has support of indexes:

```elixir
defmodule Weather do # is for later at now
  use Ecto.Model
  use Ecto.Migration.Auto.Index

  index(:city, unique: true)
  index(:prcp)
  schema "weather" do
    field :city
    field :temp_lo, :integer
    field :temp_hi, :integer
    field :prcp,    :float, default: 0.0
  end
end
```

If you do not want to use DSL for defining indexes, macro index doing no more, as generate function:

```elixir
defmodule Weather do # is for later at now
  use Ecto.Model

  schema "weather" do
    field :city
    field :temp_lo, :integer
    field :temp_hi, :integer
    field :prcp,    :float, default: 0.0
  end

  def __indexes__ do
    [{[:city], [unique: true]},
     {[:prpc], []}]
  end
end
```

Extra attribute options
-----------------------

```elixir
defmodule Weather do # is for later at now
  use Ecto.Model
  use Ecto.Migration.Auto.Index

  schema "weather" do
    field :city
    field :temp_lo, :integer
    field :temp_hi, :integer
    field :prcp,    :float, default: 0.0
  end

  def __attribute_option__(:city), do: [size: 40]
  def __attribute_option__(_),     do: []
end
```

Possibility to have more sources
--------------------------------

If the same model used by different sources, it is possible to define callback for it

```elixir
defmodule Weather do # is for later at now
  use Ecto.Model
  use Ecto.Migration.Auto.Index

  schema "weather" do
    field :city
    field :temp_lo, :integer
    field :temp_hi, :integer
    field :prcp,    :float, default: 0.0
  end

  def __sources__, do: ["weather", "history_weather"]
end
```

Upgrades in 0.3.x versions
--------------------------

If you have installed version before 0.3.2, use 0.3.2 or 0.3.3 for upgrading the table, after that it is possible to
upgrade higher versions.
