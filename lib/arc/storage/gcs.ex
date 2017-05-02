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

  def url(definition, version, file_and_scope, _options) do
    url =
      gcs_key(definition, version, file_and_scope, true)
      |> build_json_url

    case HTTPoison.get!(url, default_headers()) do
      %{status_code: 200, body: body} -> Poison.decode!(body)["mediaLink"]
      _ -> :error
    end
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

  defp gcs_key(definition, version, file_and_scope, escape \\ false)

  defp gcs_key(definition, version, file_and_scope, false) do
    do_gcs_key(definition, version, file_and_scope)
  end

  defp gcs_key(definition, version, file_and_scope, true) do
    do_gcs_key(definition, version, file_and_scope)
    |> URI.encode_www_form
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
    "#{@endpoint}/#{bucket()}/#{path}"
  end

  defp build_json_url(object) do
    "https://www.googleapis.com/storage/v1/b/#{bucket()}/o/#{object}"
  end

  defp ensure_keyword_list(list) when is_list(list), do: list
  defp ensure_keyword_list(map) when is_map(map), do: Map.to_list(map)
end
