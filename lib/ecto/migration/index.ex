defmodule Exd.Index do
  import Ecto.Migration
  defmacro index(tbl, columns, opts \\ []) do
    quote do
      def build_index do
        {unquote(tbl), unquote(columns), unquote(opts)}
      end
    end
  end
end
