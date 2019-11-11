use Mix.Config

config :arc, [
  bucket: {:system, "ARC_BUCKET"},
  storage: Arc.Storage.GCS,
]

config :goth, json: {:system, "GCP_CREDENTIALS"}

import_config "#{Mix.env()}.exs"
