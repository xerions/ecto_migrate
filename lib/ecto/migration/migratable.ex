defmodule Ecto.Migration.Migratable do
  defprotocol Migratable do
    def type(data)
  end

  defimpl Migratable, for: Atom do
    def type(data) do
      case :erlang.function_exported(data, :__struct__, 0) do
        true -> Migratable.type(data.__struct__)
        false -> data
      end
    end
  end

  defimpl Migratable, for: Ecto.DateTime do
    def type(_), do: :datetime
  end

  defimpl Migratable, for: Ecto.Date do
    def type(_), do: :datetime
  end

  defimpl Migratable, for: Ecto.Time do
    def type(_), do: :datetime
  end
end
