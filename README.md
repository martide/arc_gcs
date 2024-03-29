# Arc Google Cloud Storage

![Elixir](https://github.com/martide/arc_gcs/workflows/Elixir/badge.svg)
[![Coverage Status](https://coveralls.io/repos/github/martide/arc_gcs/badge.svg?branch=cover)](https://coveralls.io/github/martide/arc_gcs?branch=cover)

Arc GCS Provides an [`Arc`](https://github.com/stavro/arc) storage back-end for [`Google Cloud Storage`](https://cloud.google.com/storage/).

## Please note as Arc has not been updated or activly maintained we are now switching over to [Waffle](https://hex.pm/packages/waffle_gcs)

## Installation

Add the latest stable release to your `mix.exs` file:

```elixir
defp deps do
  [
    {:arc_gcs, "~> 0.2"}
  ]
end
```

Then run `mix deps.get` in your shell to fetch the dependencies.


### Configuration

```elixir
config :arc,
  storage: Arc.Storage.GCS,
  bucket: "gcs-bucket-name"

config :goth,
  json: "/path/to/json" |> Path.expand |> File.read!
```

#### Custom Token Generation ####

By default, the credentials provided to Goth will be used to generate tokens.
If you have multiple sets of credentials in Goth or otherwise need more control
over token generation, you can define your own module:

```elixir
defmodule MyCredentials do
  @behaviour Arc.Storage.GCS.TokenFetcher

  @impl Arc.Storage.GCS.TokenFetcher
  def get_token(scopes) when is_list(scopes), do: get_token(Enum.join(scopes, " "))

  @impl Arc.Storage.GCS.TokenFetcher
  def get_token(scope) when is_binary(scope) do
    {:ok, token} = Goth.Token.for_scope({"my-user@my-gcs-account.com", scope})
    token.token
  end
end
```

And configure it to use this new module instead of the default token generation:

```elixir
config :arc,
  storage: Arc.Storage.GCS,
  bucket: "gcs-bucket-name",
  token_fetcher: MyCredentials
```

### Tests

To run the tests you need to set the following

-   `ARC_TEST_BUCKET` - e.g `gcs-bucket-name`
-   `GOOGLE_CREDENTIAL` - your JSON credential from Google
-   Finally `mix test`


### Notes

Basic functionality from [`Arc`](https://github.com/stavro/arc) including
1. Store with ACL
2. Delete
3. Generate URL and sign URL


## License

Copyright 2017-2020 Martide Limited

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
