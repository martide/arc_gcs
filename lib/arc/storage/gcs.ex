defmodule Arc.Storage.GCS do
  alias GoogleApi.Storage.V1.{Api.Objects, Connection, Model.Object}
  alias GoogleApi.Gax.{Request, Response}

  @default_expiry_time 60 * 5
  @endpoint "storage.googleapis.com"
  @library_version Mix.Project.config() |> Keyword.get(:version, "")

  # available options resource settings
  # https://cloud.google.com/storage/docs/json_api/v1/objects#resource
  @object_attrs [
    "acl",
    "cacheControl",
    "contentDisposition",
    "contentEncoding",
    "contentLanguage",
    "contentType",
    "crc32c",
    "etag",
    "kmsKeyName",
    "md5Hash",
    "mediaLink",
    "storageClass",
    "temporaryHold",
    "timeCreated",
    "timeDeleted",
    "timeStorageClassUpdated",
    "updated"
  ]

  def put(definition, version, {file, _scope} = file_and_scope) do
    # Path must be calculated within put function as file.file_name has
    # already been modified by arc/arc-ecto to reflect
    # the definition's filename function
    path =
      definition
      |> get_storage_dir(version, file_and_scope)
      |> Path.join(file.file_name)

    gcs_options =
      get_gcs_options(definition, version, file_and_scope)
      |> Enum.to_list()
      |> Keyword.put(:acl, definition.acl(version, file_and_scope))
      |> transform_headers()
      |> to_object_attrs()

    do_put(definition, file, path, gcs_options)
  end

  def url(definition, version, file_and_scope, options) do
    key = gcs_key(definition, version, file_and_scope)

    case Keyword.get(options, :signed, false) do
      true -> build_signed_url(definition, key, options)
      false -> build_url(definition, key)
    end
  end

  defp build_signed_url(definition, endpoint, options) do
    {:ok, client_id} = Goth.Config.get("client_email")

    expiration = System.os_time(:second) + Keyword.get(options, :expires_in, @default_expiry_time)

    path = build_path(definition, endpoint)

    signature_string = url_to_sign("GET", "", "", expiration, "", path)
    url_encoded_signature = base64_sign_url(signature_string)

    base_url = build_url(definition, endpoint)

    "#{base_url}?GoogleAccessId=#{client_id}&Expires=#{expiration}&Signature=#{url_encoded_signature}"
  end

  def delete(definition, version, file_and_scope) do
    key = gcs_key(definition, version, file_and_scope)
    bucket = bucket_name(definition)
    Objects.storage_objects_delete(conn(), bucket, key)
  end

  defp get_storage_dir(definition, version, file_and_scope) do
    version
    |> definition.storage_dir(file_and_scope)
    |> gcs_storage_dir()
  end

  defp gcs_storage_dir({:system, env_value}) when is_binary(env_value) do
    System.get_env(env_value)
  end

  defp gcs_storage_dir(name) do
    name
  end

  defp do_put(definition, %Arc.File{binary: nil} = file, path, gcs_options) do
    obj = build_object({file, path}, gcs_options)
    bucket = bucket_name(definition)

    insert_opts =
      case obj.acl do
        false -> []
        acl -> [predefinedAcl: acl]
      end

    Objects.storage_objects_insert_simple(
      conn(),
      bucket,
      "multipart",
      obj,
      file.path,
      insert_opts
    )
  end

  defp do_put(definition, %Arc.File{binary: binary} = file, path, gcs_options) do
    obj = build_object({file, path}, gcs_options)
    bucket = bucket_name(definition)

    body =
      Tesla.Multipart.new()
      |> Tesla.Multipart.add_field(
        "metadata",
        Poison.encode!(obj),
        headers: [{:"Content-Type", "application/json"}]
      )
      |> Tesla.Multipart.add_file_content(binary, "data")

    request =
      Request.new()
      |> Request.method(:post)
      |> Request.url("/upload/storage/v1/b/{bucket}/o", %{
        "bucket" => URI.encode(bucket, &URI.char_unreserved?/1)
      })
      |> Request.add_param(:query, :uploadType, "multipart")
      |> Request.add_param(:body, :body, body)
      |> add_acl_param(obj.acl)
      |> Request.library_version(@library_version)

    conn()
    |> Connection.execute(request)
    |> Response.decode(struct: %Object{})
  end

  defp add_acl_param(request, false), do: request

  defp add_acl_param(request, acl) do
    Request.add_optional_params(request, %{predefinedAcl: :query}, predefinedAcl: acl)
  end

  defp transform_headers(headers) do
    Enum.map(headers, &transform_header/1)
  end

  defp transform_header({key, val}) when key in [:acl, "acl"] and val != false do
    {camelize(key), camelize(val)}
  end

  defp transform_header({key, val}) do
    {camelize(key), val}
  end

  defp to_object_attrs(headers) do
    Enum.reduce(headers, [], &to_object_attrs/2)
  end

  defp to_object_attrs({key, val}, acc) when key in @object_attrs do
    [{String.to_atom(key), val} | acc]
  end

  defp to_object_attrs(_, acc) do
    acc
  end

  defp endpoint do
    case Application.fetch_env(:arc, :asset_host) do
      :error -> @endpoint
      {:ok, {:system, env_var}} when is_binary(env_var) -> System.get_env(env_var)
      {:ok, endpoint} -> endpoint
    end
  end

  defp gcs_key(definition, version, file_and_scope) do
    definition
    |> do_gcs_key(version, file_and_scope)
  end

  defp do_gcs_key(definition, version, file_and_scope) do
    Path.join([
      get_storage_dir(definition, version, file_and_scope),
      Arc.Definition.Versioning.resolve_file_name(definition, version, file_and_scope)
    ])
  end

  defp get_gcs_options(definition, version, {file, scope}) do
    try do
      apply(definition, :gcs_object_headers, [version, {file, scope}])
    rescue
      UndefinedFunctionError ->
        []
    end
  end

  defp build_url(definition, path) do
    %URI{
      host: endpoint(),
      path: build_path(definition, path),
      scheme: "https"
    }
    |> URI.to_string()
  end

  defp build_path(definition, path) do
    case bucket_name(definition) do
      nil -> path
      value -> Path.join(value, path)
    end
    |> prepend_slash()
    |> URI.encode()
  end

  defp bucket_name(definition) do
    with {:system, env_var} <- definition.bucket() do
      System.get_env(to_string(env_var))
    end
  end

  defp prepend_slash("/" <> _rest = path), do: path
  defp prepend_slash(path), do: "/#{path}"

  defp url_to_sign(verb, md5, type, expiration, headers, resource) do
    "#{verb}\n#{md5}\n#{type}\n#{expiration}\n#{headers}#{resource}"
  end

  defp base64_sign_url(plaintext) do
    {:ok, pem_bin} = Goth.Config.get("private_key")
    [pem_key_data] = :public_key.pem_decode(pem_bin)
    otp_release = System.otp_release() |> String.to_integer()

    rsa_key =
      case otp_release do
        n when n >= 21 ->
          :public_key.pem_entry_decode(pem_key_data)

        n when n <= 20 ->
          pem_key = :public_key.pem_entry_decode(pem_key_data)
          :public_key.der_decode(:RSAPrivateKey, elem(pem_key, 3))
      end

    plaintext
    |> :public_key.sign(:sha256, rsa_key)
    |> Base.encode64()
    |> URI.encode_www_form()
  end

  defp build_object({%Arc.File{file_name: file_name}, name}, opts) do
    opts
    |> Keyword.put(:name, name)
    |> Keyword.put_new(:contentType, MIME.from_path(file_name))
    |> (&struct(Object, &1)).()
  end

  defp conn(), do: Connection.new(&for_scope/1)

  defp camelize(word) do
    case Regex.split(~r/(?:^|[-_])|(?=[A-Z])/, to_string(word), trim: true) do
      [h] -> [String.downcase(h)]
      [h | t] -> [String.downcase(h), Enum.map(t, &String.capitalize/1)]
      [] -> []
    end
    |> Enum.join()
  end

  defp for_scope(scopes) do
    token_store = Application.get_env(:arc, :token_fetcher, Arc.Storage.GCS.Token.DefaultFetcher)
    token_store.get_token(scopes)
  end
end
