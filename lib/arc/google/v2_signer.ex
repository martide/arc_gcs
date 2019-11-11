defmodule Arc.Google.V2Signer do
  @moduledoc """
  This is an implementation of the V2 URL signing for Google Cloud Storage. See
  [the Google documentation](https://cloud.google.com/storage/docs/access-control/signed-urls-v2)
  for more details.
  """

  alias Arc.Storage.GCS

  # Default expiration time is 3600 seconds, or 1 hour
  @default_expiry 3600

  # Maximum expiration time is 7 days from the creation of the signed URL
  @max_expiry 604800

  # The official Google Cloud Storage host
  @endpoint "storage.googleapis.com"

  def option(opts, key, default \\ nil) do
    case Keyword.get(opts, key) do
      nil -> Application.get_env(:arc, key, default)
      val -> val
    end
  end

  def expiry(opts \\ []) do
    case option(opts, :expires_in, @default_expiry) do
      val when val > @max_expiry -> @max_expiry
      val -> val
    end
  end

  def signed?(opts \\ []), do: option(opts, :signed, false)

  def url(definition, version, file_and_scope, options \\ []) do
    key = gcs_key(definition, version, file_and_scope)

    if signed?(options) do
      build_signed_url(definition, key, options)
    else
      build_url(definition, key)
    end
  end

  def build_url(definition, path) do
    %URI{
      host: endpoint(),
      path: build_path(definition, path),
      scheme: "https"
    }
    |> URI.to_string()
  end

  def build_signed_url(definition, endpoint, options) do
    {:ok, client_id} = Goth.Config.get("client_email")

    expiration = System.os_time(:second) + expiry(options)

    path = build_path(definition, endpoint)

    signature_string = url_to_sign("GET", "", "", expiration, "", path)
    url_encoded_signature = base64_sign_url(signature_string)

    base_url = build_url(definition, endpoint)

    "#{base_url}?GoogleAccessId=#{client_id}&Expires=#{expiration}&Signature=#{url_encoded_signature}"
  end

  def build_path(definition, path) do
    case GCS.bucket(definition) do
      nil -> path
      value -> Path.join(value, path)
    end
    |> prepend_slash()
    |> URI.encode()
  end

  defp endpoint() do
    case Application.fetch_env(:arc, :asset_host) do
      :error -> @endpoint
      {:ok, {:system, env_var}} when is_binary(env_var) -> System.get_env(env_var)
      {:ok, endpoint} -> endpoint
    end
  end

  defp gcs_key(definition, version, file_and_scope) do
    definition
    |> GCS.storage_dir(version, file_and_scope)
    |> Path.join(Arc.Definition.Versioning.resolve_file_name(definition, version, file_and_scope))
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
end
