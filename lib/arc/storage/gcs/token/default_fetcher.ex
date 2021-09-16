defmodule Arc.Storage.GCS.Token.DefaultFetcher do
  @behaviour Arc.Storage.GCS.Token.Fetcher

  alias Goth.Token

  @impl Arc.Storage.GCS.Token.Fetcher
  def get_token(scopes) when is_list(scopes) do
    scopes
    |> Enum.join(" ")
    |> get_token()
  end

  def get_token(scope) when is_binary(scope) do
    case Token.for_scope(scope) do
      {:ok, token} -> token.token
      _ -> ""
    end
  end
end
