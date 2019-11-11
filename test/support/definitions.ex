defmodule DefinitionTest do
  defmacro __using__(_) do
    quote do
      use Arc.Definition

      @acl :publicread

      def acl(_, {_, :private}), do: :private

      def filename(_, {file, :private}), do: file.file_name
      def filename(_, {file, name}) when is_binary(name), do: name

      defoverridable acl: 2, filename: 2
    end
  end
end

defmodule DummyDefinition do
  use DefinitionTest

  def storage_dir(_, _), do: "arc-test"
end
