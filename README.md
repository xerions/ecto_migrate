EctoMigrate
===========

**TODO: Add description**

```elixir

# Configuration for Repo, only for iex try taste, please use supervisor in your application
:application.set_env(:example, Repo, [adapter: Ecto.Adapters.MySQL, database: "example", username: "root"])
defmodule Repo, do: (use Ecto.Repo, otp_app: :example)
Repo.start_link
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

Lets redefine the same model in a shell and migrate it

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
