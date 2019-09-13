# Arc Google Cloud Storage

[![CircleCI](https://circleci.com/gh/martide/arc_gcs.svg?style=svg)](https://circleci.com/gh/martide/arc_gcs)
[![codecov](https://codecov.io/gh/martide/arc_gcs/branch/master/graph/badge.svg)](https://codecov.io/gh/martide/arc_gcs)

Arc GCS Provides an [`Arc`](https://github.com/stavro/arc) storage back-end for [`Google Cloud Storage`](https://cloud.google.com/storage/).


## Installation

Add the latest stable release to your `mix.exs` file:

```elixir
defp deps do
  [
    {:arc_gcs, "~> 0.1.0"}
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
  json: "/path/to/json" |> Path.expand() |> File.read!()
```

The bucket may also be set using environment variables:

```elixir
config :arc, bucket: {:system, "ARC_BUCKET"}
```


### Tests

To run the tests:

1. Ensure you (a) have a Google Cloud Platform account, (b) have a service
account with read/write (i.e. admin) access to Cloud Storage, and (c) have the
service account's credentials (the JSON file it has you download) available on
the machine running the code.
2. Set your environment variables: `ARC_BUCKET` and `GCP_CREDENTIALS` must both
be set for the tests to work. `GCP_CREDENTIALS` should be the **contents** of
your Google Cloud credentials JSON file (e.g. `cat creds.json`).
3. Run `mix test`.

**Note**: Because you will need your own Google Cloud Platform account and
because you will be uploading files to Cloud Storage, you may incur costs
associated with testing if you aren't ensuring proper cleanup. Although there is
a cleanup function that executes after the test suite has completed, it is not
guaranteed to always remove your files. If a test fails or if the cleanup fails,
it is possible that your storage usage will increase as you perform testing and
could cause you to be charged at the end of the month. Please check your test
bucket (whatever `ARC_BUCKET` is set to) after running your tests and delete any
leftover objects that weren't automatically deleted.


### Notes

Basic functionality from [`Arc`](https://github.com/stavro/arc) including

1. Store with ACL
2. Delete
3. Generate URL and sign URL (V2)


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
