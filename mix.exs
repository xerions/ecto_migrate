defmodule EctoMigrate.Mixfile do
  use Mix.Project
  @version "0.6.3"
  @github "https://github.com/xerions/ecto_migrate"

  def project do
    [app: :ecto_migrate,
     version: @version,

     description: description,
     package: package,

     # Docs
     name: "Ecto Auto Migrate",
     docs: [source_ref: "v#{@version}",
            source_url: @github],
     deps: deps]
  end

  defp description do
    """
    Ecto auto migration library. It allows to generate and run migrations for initial
    and update migrations.
    """
  end

  defp package do
    [maintainers: ["Dmitry Russ(Aleksandrov)", "Yury Gargay"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => @github}]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [{:postgrex, ">= 0.0.0", optional: true},
     {:mariaex, ">= 0.0.0", optional: true},
     {:ecto, "~> 1.0"},
     {:ecto_it, "~> 0.2.0", optional: true}]
  end
end
