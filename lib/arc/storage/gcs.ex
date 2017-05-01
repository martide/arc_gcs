defmodule Arc.Storage.GCS do
  alias Goth.Token
  import SweetXml

  @endpoint "storage.googleapis.com"
  @full_control_scope "https://www.googleapis.com/auth/devstorage.full_control"


  def put(definition, version, {file, scope}) do
    path =
      definition.storage_dir(version, {file, scope})
      |> Path.join(file.file_name)

    acl = definition.acl(version, {file, scope})

    gcs_options =
      get_gcs_options(definition, version, {file, scope})
      |> ensure_keyword_list
      |> Keyword.put(:x_goog_acl, acl)
      |> transform_headers

    do_put(file, path, gcs_options)
  end

  defp transform_headers(headers) do
    Enum.map(headers, fn {key, val} ->
      {to_string(key) |> String.replace("_", "-"), val}
    end)
  end

  defp do_put(%{binary: file_binary} = file, path)
    when is_binary(file_binary)
  do
    # TODO
  end

  defp do_put(file, path, gcs_options) do
    body = {:file, file.file_name}
    headers = gcs_options ++ [{"Authorization", "Bearer #{get_token()}"}]
    url = "#{@endpoint}/#{bucket()}/#{path}"

    case HTTPoison.request!(:put, url, body, headers, []) do
      %{status_code: 200} ->
        {:ok, file.file_name}
      %{body: body} ->
        error = xpath(body, ~x"//Details/text()"S)
        {:error, error}
    end
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

  defp get_gcs_options(definition, version, {file, scope}) do
    try do
      apply(definition, :gcs_object_headers, [version, {file, scope}])
    rescue
      UndefinedFunctionError ->
        []
    end
  end

  defp ensure_keyword_list(list) when is_list(list), do: list
  defp ensure_keyword_list(map) when is_map(map), do: Map.to_list(map)
end
