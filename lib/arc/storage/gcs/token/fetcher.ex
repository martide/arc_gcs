defmodule Arc.Storage.GCS.Token.Fetcher do
  @callback get_token(binary | [binary]) :: binary
end
