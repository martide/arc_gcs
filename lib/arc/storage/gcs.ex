defmodule Arc.Storage.GCS do
  alias Goth.Token
  import SweetXml

  @endpoint "storage.googleapis.com"
  @full_control_scope "https://www.googleapis.com/auth/devstorage.full_control"

  def put(definition, version, {file, _scope} =file_and_scope) do
    path = gcs_key(definition, version, file_and_scope)
    acl = definition.acl(version, file_and_scope)
    gcs_options =
      get_gcs_options(definition, version, file_and_scope)
      |> ensure_keyword_list
      |> Keyword.put(:x_goog_acl, acl)
      |> transform_headers

    do_put(file, path, gcs_options)
  end

  def url(definition, version, file_and_scope, options) do
    key = gcs_key(definition, version, file_and_scope)
    case Keyword.get(options, :signed, false) do
      true -> build_signed_url(key)
      false -> build_url(key)
    end
  end

  defp build_signed_url(endpoint) do
    {:ok, client_id} = Goth.Config.get("client_email")
    expiration = System.os_time(:seconds) + 86_400
    path = "/#{bucket()}/#{endpoint}"
    base_url = build_url(endpoint)
    signature_string = url_to_sign("GET", "", "", expiration, "", path)
    url_encoded_signature = base64_sign_url(signature_string)
    "#{base_url}?GoogleAccessId=#{client_id}&Expires=#{expiration}&Signature=#{url_encoded_signature}"
  end

  def delete(definition, version, file_and_scope) do
    url =
      gcs_key(definition, version, file_and_scope)
      |> build_url

    case HTTPoison.delete!(url, default_headers()) do
      %{status_code: 204} -> :ok
      _ -> :error
    end
  end

  defp do_put(%{binary: nil} = file, path, gcs_options) do
    do_put(path, {:file, file.path}, gcs_options, file.file_name)
  end

  defp do_put(%{binary: binary} = file, path, gcs_options)
    when is_binary(binary)
  do
    do_put(path, binary, gcs_options, file.file_name)
  end

  defp do_put(path, body, gcs_options, file_name) do
    url = build_url(path)
    headers = gcs_options ++ default_headers()

    case HTTPoison.put!(url, body, headers) do
      %{status_code: 200} ->
        {:ok, file_name}
      %{body: body} ->
        error = xpath(body, ~x"//Details/text()"S)
        {:error, error}
    end
  end

  defp transform_headers(headers) do
    Enum.map(headers, fn {key, val} ->
      {to_string(key) |> String.replace("_", "-"), val}
    end)
  end

  defp get_token do
    {:ok, %{token: token}} = Token.for_scope(@full_control_scope)
    token
  end

  defp bucket do
    case Application.fetch_env!(:arc, :bucket) do
      {:system, env_var} when is_binary(env_var) -> System.get_env(env_var)
      name -> name
    end
  end

  defp gcs_key(definition, version, file_and_scope) do
    definition
    |> do_gcs_key(version, file_and_scope)
    |> URI.encode
  end

  defp do_gcs_key(definition, version, file_and_scope) do
    Path.join([
      definition.storage_dir(version, file_and_scope),
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

  defp default_headers do
    [{"Authorization", "Bearer #{get_token()}"}]
  end

  defp build_url(path) do
    "https://#{@endpoint}/#{bucket()}/#{path}"
  end

  defp ensure_keyword_list(list) when is_list(list), do: list
  defp ensure_keyword_list(map) when is_map(map), do: Map.to_list(map)


  defp url_to_sign(verb, md5, type, expiration, headers, resource) do
    "#{verb}\n#{md5}\n#{type}\n#{expiration}\n#{headers}#{resource}"
  end

  defp base64_sign_url(plaintext) do
    {:ok, pem_bin} = Goth.Config.get("private_key")
    [pem_key_data] = :public_key.pem_decode(pem_bin)
    pem_key = :public_key.pem_entry_decode(pem_key_data)
    rsa_key = :public_key.der_decode(:'RSAPrivateKey', elem(pem_key, 3))

    plaintext
    |> :public_key.sign(:sha256, rsa_key)
    |> Base.encode64
    |> URI.encode_www_form
  end
end
