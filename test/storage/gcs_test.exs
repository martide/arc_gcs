defmodule Arc.Storage.GCSTest do
  use ExUnit.Case, async: true

  alias Arc.Storage.GCS, as: GCS
  alias GoogleApi.Storage.V1.Api.Objects

  @img_name "image.png"
  @img_path "test/support/#{@img_name}"
  @bucket "arc-test"
  @dir "arc-test"

  def random_name(_) do
    name = 8 |> :crypto.strong_rand_bytes() |> Base.encode16() |> Kernel.<>(".png")
    %{name: name, path: "#{@dir}/#{name}"}
  end

  def arc_file(_), do: %{arc: Arc.File.new(@img_path)}

  def upload(%{arc: file, name: name}) do
    {:ok, _} = GCS.put(DummyDefinition, :original, {file, name})
    :ok
  end

  def get_by_name(definition \\ DummyDefinition, name) do
    Objects.storage_objects_get(
      GCS.conn(),
      GCS.bucket(definition),
      "#{@dir}/#{name}"
    )
  end

  describe "wrapper functions" do
    setup [:arc_file]

    test "conn/1 returns a Google Tesla client" do
      assert %Tesla.Client{} = GCS.conn()
    end

    test "var/1 retrieves system variable" do
      key = "ARC_TEST_BUCKET"
      val = "some test value"
      System.put_env(key, val)
      assert val == GCS.var({:system, key})
    end

    test "var/1 returns other value" do
      val = :anything
      assert val == GCS.var(val)
    end

    test "bucket/1 returns a bucket based on configuration" do
      Application.put_env(:arc, :bucket, @bucket)
      assert @bucket == GCS.bucket(DummyDefinition)
      Application.put_env(:arc, :bucket, {:system, "ARC_BUCKET"})
    end

    test "bucket/1 returns a bucket based on definition override" do
      assert "dummy-arc-test" = GCS.bucket(DummyDefinitionWithBucket)
    end

    test "data/1 returns either {:binary, _} or {:file, _}" do
      bin = "this is a test"
      assert {:binary, ^bin} = GCS.data({%Arc.File{binary: bin}, nil})
      assert {:file, @img_path} = GCS.data({Arc.File.new(@img_path), nil})
    end

    test "storage_dir/3 returns the root storage directory for uploads" do
      meta = {Arc.File.new(@img_path), "test.jpg"}
      assert @dir == GCS.storage_dir(DummyDefinition, :original, meta)
    end

    test "path_for/3 returns the full file path for the upload" do
      meta = {Arc.File.new(@img_path), "test.jpg"}
      assert "#{@dir}/test.jpg" == GCS.path_for(DummyDefinition, :original, meta)
    end
  end

  describe "arc functions without remote file" do
    setup [:random_name, :arc_file]

    test "put/3 with a custom filename", %{arc: file, name: name, path: path} do
      assert {:ok, %{name: ^path}} = GCS.put(DummyDefinition, :original, {file, name})
      assert {:ok, %{name: ^path}} = get_by_name(name)
    end

    test "put/3 with default filename", %{arc: file} do
      path = "arc-test/#{@img_name}"
      assert {:ok, %{name: ^path}} = GCS.put(DummyDefinition, :original, {file, :private})
      assert {:ok, %{name: ^path}} = get_by_name(@img_name)
    end

    test "put/3 with binary data", %{name: name, path: path} do
      file = %Arc.File{binary: File.read!(@img_path)}
      assert {:ok, %{name: ^path}} = GCS.put(DummyDefinition, :original, {file, name})
      assert {:ok, %{name: ^path}} = get_by_name(name)
    end
  end

  describe "arc functions with remote file" do
    setup [:random_name, :arc_file, :upload]

    test "delete/3 deletes the remote file", %{arc: file, name: name, path: path} do
      assert {:ok, %{name: ^path}} = get_by_name(name)
      assert {:ok, _} = GCS.delete(DummyDefinition, :original, {file, name})
      assert {:error, %{status: 404}} = get_by_name(name)
    end

    test "url/3 generates an appropriate URL", %{arc: file, name: name, path: path} do
      assert GCS.url(DummyDefinition, :original, {file, name}) =~ "/#{path}"
    end

    test "url/3 generates a signed URL (v2)", %{arc: file, name: name} do
      assert GCS.url(DummyDefinition, :original, {file, name}, signed: true) =~ "Signature="
    end
  end
end
