defmodule ArcTest.Storage.GCS do
  use ExUnit.Case, async: false

  @img "test/support/image.png"

  defmodule DummyDefinition do
    use Arc.Definition

    def __storage, do: Arc.Storage.GCS

    @acl :public_read
    def storage_dir(_, _), do: "arctest/uploads"
    def acl(_, {_, :private}), do: :private

    def gcs_object_headers(:original, {_, :with_content_type}), do: [content_type: "image/png"]
    def gcs_object_headers(:original, {_, :map}), do: %{content_type: "image/png"}
    def gcs_object_headers(:original, _), do: []
  end

  defmodule DefinitionWithThumbnail do
    use Arc.Definition

    def __storage, do: Arc.Storage.GCS

    @versions [:thumb]
    @acl :public_read

    def transform(:thumb, _) do
      {"convert", "-strip -thumbnail 100x100^ -gravity center -extent 100x100 -format jpg", :jpg}
    end
  end

  defmodule DefinitionWithScope do
    use Arc.Definition

    def __storage, do: Arc.Storage.GCS

    @acl :public_read
    def storage_dir(_, {_, scope}), do: "uploads/with_scopes/#{scope.id}"
  end

  def env_bucket do
    System.get_env("ARC_TEST_BUCKET")
  end

  defmacro delete_and_assert_not_found(definition, args) do
    quote bind_quoted: [definition: definition, args: args] do
      :ok = definition.delete(args)
      signed_url = DummyDefinition.url(args, signed: true)
      {:ok, {{_, code, msg}, _, _}} = :httpc.request(to_char_list(signed_url))
      assert 404 == code
      assert 'Not Found' == msg
    end
  end

  defmacro assert_header(definition, args, header, value) do
    quote bind_quoted: [definition: definition, args: args, header: header, value: value] do
      url = definition.url(args, signed: true)
      %{status_code: 200, headers: headers} = HTTPoison.get!(url)
      assert Enum.find(headers, fn {"Content-Type", "image/png"} -> true
                                   _ -> false end)
    end
  end

  defmacro assert_private(definition, args) do
    quote bind_quoted: [definition: definition, args: args] do
      url = definition.url(args, signed: false)
      assert %{status_code: 403} = HTTPoison.get!(url)
      signed_url = definition.url(args, signed: true)
      assert %{status_code: 200} = HTTPoison.get!(signed_url)
    end
  end

  defmacro assert_public(definition, args) do
    quote bind_quoted: [definition: definition, args: args] do
      url = definition.url(args, signed: true)
      assert %{status_code: 200} = HTTPoison.get!(url)
    end
  end

  defmacro assert_public_with_extension(definition, args, version, extension) do
    quote bind_quoted: [definition: definition, version: version, args: args, extension: extension] do
      url = definition.url(args, version, signed: true)
      assert %{status_code: 200} = HTTPoison.get!(url)
      assert URI.parse(url).path|> Path.extname == extension
    end
  end

  @tag timeout: 15000
  test "public put and get" do
    assert {:ok, "image.png"} == DummyDefinition.store(@img)
    assert_public(DummyDefinition, "image.png")
    delete_and_assert_not_found(DummyDefinition, "image.png")
  end

  @tag timeout: 15000
  test "public put with file-binary and get" do
    assert {:ok, "image.png"} = DummyDefinition.store(%{filename: "image.png", binary: File.read!(@img)})
    assert_public(DummyDefinition, "image.png")
    delete_and_assert_not_found(DummyDefinition, "image.png")
  end

  @tag timeout: 15000
  test "public put and get with System env" do
    Application.put_env(:arc, :bucket, {:system, "ARC_TEST_BUCKET"})
    assert {:ok, "image.png"} == DummyDefinition.store(@img)
    assert_public(DummyDefinition, "image.png")
    delete_and_assert_not_found(DummyDefinition, "image.png")
    Application.put_env(:arc, :bucket, System.get_env("ARC_TEST_BUCKET"))
  end

  @tag timeout: 15000
  test "private put" do
    #put the image as private
    assert {:ok, "image.png"} == DummyDefinition.store({@img, :private})
    assert_private(DummyDefinition, "image.png")
    delete_and_assert_not_found(DummyDefinition, "image.png")
  end

  @tag timeout: 15000
  test "content_type" do
    {:ok, "image.png"} = DummyDefinition.store({@img, :with_content_type})
    assert_header(DummyDefinition, "image.png", "content-type", "image/png")
    delete_and_assert_not_found(DummyDefinition, "image.png")
  end

  @tag timeout: 15000
  test "content_type map" do
    {:ok, "image.png"} = DummyDefinition.store({@img, :map})
    assert_header(DummyDefinition, "image.png", "content-type", "image/png")
    delete_and_assert_not_found(DummyDefinition, "image.png")
  end

  @tag timeout: 150000
  test "delete with scope" do
    scope = %{id: 1}
    {:ok, path} = DefinitionWithScope.store({"test/support/image.png", scope})
    assert DefinitionWithScope.url({path, scope}, signed: true) =~
      "storage.googleapis.com/#{env_bucket()}/uploads%2Fwith_scopes%2F1%2Fimage.png"
    assert_public(DefinitionWithScope, {path, scope})
    delete_and_assert_not_found(DefinitionWithScope, {path, scope})
  end

  @tag timeout: 150000
  test "put with error" do
    Application.put_env(:arc, :bucket, "unknown-bucket")
    {:error, res} = DummyDefinition.store("test/support/image.png")
    Application.put_env :arc, :bucket, env_bucket()
    assert res
  end

  @tag timeout: 150000
  test "put with converted version" do
    assert {:ok, "image.png"} == DefinitionWithThumbnail.store(@img)
    assert_public_with_extension(DefinitionWithThumbnail, "image.png", :thumb, ".jpg")
    delete_and_assert_not_found(DefinitionWithThumbnail, "image.png")
  end
end
