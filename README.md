# Arc Google Cloud Storage

[![CircleCI](https://circleci.com/gh/martide/arc_gcs.svg?style=svg)](https://circleci.com/gh/martide/arc_gcs)
[![codecov](https://codecov.io/gh/martide/arc_gcs/branch/master/graph/badge.svg)](https://codecov.io/gh/martide/arc_gcs)

Arc GCS Provides an [`Arc`](https://github.com/stavro/arc) storage back-end for [`Google Cloud Storage`](https://cloud.google.com/storage/).

## Installation

Add the latest stable release to your `mix.exs` file:

```elixir
defp deps do
  [
    {:arc_gcs, "~> 0.0.8"}
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

Copyright 2017 Martide Limited

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
