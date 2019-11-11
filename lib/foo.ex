defmodule Foo do
  def init() do
    {:ok, _} = Goth.start(1, 1)
    url("image")
  end

  def url(name) do
    Arc.Storage.GCS.url(DummyDefinition, :original, {%Arc.File{file_name: name}, "#{name}.png"}, signed_urls: true)
  end
end
