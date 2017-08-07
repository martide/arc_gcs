defmodule ArcTest.Storage.GCS do
  use ExUnit.Case, async: true

  @img_name "image space.png"
  @img_path "test/support/#{@img_name}"

  defmodule DummyDefinition do
    use Arc.Definition

    def __storage, do: Arc.Storage.GCS

    @acl :public_read
    def storage_dir(_, _), do: "arc test"

    def filename(_, {file, name}) do
      name || file.file_name
    end

    def acl(_, {_, :private}), do: :private

    def gcs_object_headers(:original, {_, :with_content_type}), do: [content_type: "image/png", 'cache-control': "no-store"]
    def gcs_object_headers(:original, {_, :map}), do: %{content_type: "image/png", 'cache-control': "no-store"}
    def gcs_object_headers(:original, _), do: ['cache-control': "no-store"]
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

  def random_name do
    8 |> :crypto.strong_rand_bytes |> Base.encode16
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
      url = definition.url(args, signed: false)
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

  setup do
    {:ok, name: random_name()}
  end

  @tag timeout: 15000
  test "public put and get", %{name: name} do
    assert {:ok, @img_name} == DummyDefinition.store({@img_path, name})
    assert_public(DummyDefinition, {@img_name, name})
    delete_and_assert_not_found(DummyDefinition, {@img_name, name})
  end

  @tag timeout: 15000
  test "public put with file-binary and get", %{name: name} do
    assert {:ok, @img_name} = DummyDefinition.store({%{filename: @img_name, binary: File.read!(@img_path)}, name})
    assert_public(DummyDefinition, {@img_name, name})
    delete_and_assert_not_found(DummyDefinition, {@img_name, name})
  end

  # @tag timeout: 15000
  # test "public put and get with System env", %{name: name} do
  #   Application.put_env(:arc, :bucket, {:system, "ARC_TEST_BUCKET"})
  #   assert {:ok, @img_name} == DummyDefinition.store({@img_path, name})
  #   assert_public(DummyDefinition, {@img_name, name})
  #   delete_and_assert_not_found(DummyDefinition, {@img_name, name})
  #   Application.put_env(:arc, :bucket, System.get_env("ARC_TEST_BUCKET"))
  # end

  @tag timeout: 15000
  test "private put" do
    #put the image as private
    assert {:ok, @img_name} == DummyDefinition.store({@img_path, :private})
    assert_private(DummyDefinition, {@img_name, :private})
    delete_and_assert_not_found(DummyDefinition, {@img_name, :private})
  end

  @tag timeout: 15000
  test "content_type" do
    {:ok, @img_name} = DummyDefinition.store({@img_path, :with_content_type})
    assert_header(DummyDefinition, {@img_name, :with_content_type}, "content-type", "image/png")
    delete_and_assert_not_found(DummyDefinition, {@img_name, :with_content_type})
  end

  @tag timeout: 15000
  test "content_type map" do
    {:ok, @img_name} = DummyDefinition.store({@img_path, :map})
    assert_header(DummyDefinition, {@img_name, :map}, "content-type", "image/png")
    delete_and_assert_not_found(DummyDefinition, {@img_name, :map})
  end

  @tag timeout: 150000
  test "delete with scope" do
    scope = %{id: 1}
    {:ok, path} = DefinitionWithScope.store({@img_path, scope})
    assert DefinitionWithScope.url({path, scope}, signed: true) =~
      "storage.googleapis.com/#{env_bucket()}/uploads/with_scopes/1/image%20space.png"
    assert_public(DefinitionWithScope, {path, scope})
    delete_and_assert_not_found(DefinitionWithScope, {path, scope})
  end

  @tag timeout: 150000
  test "put with error" do
    Application.put_env(:arc, :bucket, "unknown-bucket")
    {:error, res} = DummyDefinition.store(@img_path)
    Application.put_env :arc, :bucket, env_bucket()
    assert res
  end

  @tag timeout: 150000
  test "put with converted version", %{name: name} do
    assert {:ok, @img_name} == DefinitionWithThumbnail.store({@img_path, name})
    assert_public_with_extension(DefinitionWithThumbnail, {@img_name, name}, :thumb, ".jpg")
    delete_and_assert_not_found(DefinitionWithThumbnail, {@img_name, name})
  end
end
