defmodule Arc.Storage.GCS do
  @moduledoc """
  This is a wrapper around calls to `Google.Api.Storage.V1` to simplify the
  tasks of this library.
  """

  @full_control_scope "https://www.googleapis.com/auth/devstorage.full_control"

  @library_version Mix.Project.config() |> Keyword.get(:version, "")

  alias GoogleApi.Gax.{Request, Response}
  alias GoogleApi.Storage.V1.Connection
  alias GoogleApi.Storage.V1.Api.Objects
  alias GoogleApi.Storage.V1.Model.Object

  @type object_or_error :: {:ok, GoogleApi.Storage.V1.Model.Object.t} | {:error, Tesla.Env.t}

  @doc """
  Put an Arc file in a Google Cloud Storage bucket.
  """
  def put(definition, version, meta) do
    path = path_for(definition, version, meta)
    acl = definition.acl(version, meta)
    insert(conn(), bucket(definition), path, data(meta), acl)
  end

  @doc """
  Delete a file from a Google Cloud Storage bucket.
  """
  def delete(definition, version, meta) do
    Objects.storage_objects_delete(
      conn(),
      bucket(definition),
      path_for(definition, version, meta)
    )
  end

  @doc """
  Retrieve the public URL for a file in a Google Cloud Storage bucket.
  """
  def url(definition, version, meta, opts \\ []) do
    Arc.Google.V2Signer.url(definition, version, meta, opts)
  end

  @doc """
  Constructs a new connection object with scoped authentication. If no scope is
  provided, the `devstorage.full_control` scope is used as a default.
  """
  @spec conn(String.t) :: Tesla.Env.client
  def conn(scope \\ @full_control_scope) do
    {:ok, token} = Goth.Token.for_scope(scope)
    Connection.new(token.token)
  end

  @doc """
  If given a tuple of the form `{:system, var}`, this will return the value of
  the system's environment variable for `var`. Otherwise, this returns the same
  value it is given.
  """
  @spec var(any) :: any
  def var({:system, var}), do: System.get_env(var)
  def var(name), do: name

  @doc """
  Returns the bucket for file uploads.
  """
  @spec bucket(Map.t) :: String.t
  def bucket(definition), do: var(definition.bucket())

  @doc """
  Converts a `{file, scope}` tuple to a data tuple that can be used by
  `insert/4`.
  """
  @spec data(Map.t) :: {:file | :binary, String.t}
  def data({%{binary: nil, path: path}, _}), do: {:file, path}
  def data({%{binary: data}, _}), do: {:binary, data}

  @doc """
  Returns the storage directory **within a bucket** to store the file under.
  """
  def storage_dir(definition, version, meta) do
    version
    |> definition.storage_dir(meta)
    |> var()
  end

  @doc """
  Returns the full file path for the upload destination.
  """
  def path_for(definition, version, meta) do
    definition
    |> storage_dir(version, meta)
    |> Path.join(definition.filename(version, meta))
  end

  @spec insert(Tesla.Env.client, String.t, String.t, {:file | :binary, String.t}, String.t) :: object_or_error
  defp insert(conn, bucket, name, {:file, path}, acl) do
    Objects.storage_objects_insert_simple(
      conn,
      bucket,
      "multipart",
      %Object{name: name, acl: acl},
      path
    )
  end
  defp insert(conn, bucket, name, {:binary, data}, acl) do
    # For some reason, the Elixir library for Google Cloud Storage **DOES NOT**
    # support binary data uploads. Their code always assumes that a path to a
    # file is being passed to it and constructs the request as such.
    # Infuriatingly, Tesla, the HTTP library being used under-the-hood, converts
    # file paths to streaming binary data anyway for the request, so adding the
    # data to a temporary file would mean we are doing the following:
    # 1. Receive binary data (maybe from a stream).
    # 2. Write the binary data to a temporary file.
    # 3. Tesla opens the temporary file as a stream.
    # 4. The request is made.
    # 5. Delete the temporary file.
    # The extra steps are ridiculous so the following code is a modified version
    # of `storage_objects_insert_simple` where the "file content" is added to a
    # Tesla Multipart structure and then added to the request directly.
    body = Tesla.Multipart.new()
    |> Tesla.Multipart.add_field(
      :metadata,
      Poison.encode!(%Object{name: name, acl: acl}),
      headers: [{:"Content-Type", "application/json"}]
    )
    |> Tesla.Multipart.add_file_content(data, :data)

    request = Request.new()
    |> Request.method(:post)
    |> Request.url("/upload/storage/v1/b/{bucket}/o", %{
      "bucket" => URI.encode(bucket, &URI.char_unreserved?/1)
    })
    |> Request.add_param(:query, :uploadType, "multipart")
    |> Request.add_param(:body, :body, body)
    |> Request.library_version(@library_version)

    conn
    |> Connection.execute(request)
    |> Response.decode([struct: %Object{}])
  end
end
